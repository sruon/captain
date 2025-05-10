-- All credits: Duke https://github.com/Dukilles/pathlog
-- Logs NPCs and players movement. New points are logged when the entity moves a certain distance or rotates a certain amount.
-- Legs are created when the time delta between two points is above a certain threshold.
-- TODO: May need to track disappearance of entities
-- TODO: May need to reimplement some commands/configuration from pathlog
---@class PathLogAddon : AddonInterface
---@field rootDir? string
---@field captureDir? string
---@field lastCoords table<number, { x: number, y: number, z: number, dir: number, startTime: number, lastTime: number, leg: number }>
---@field csvFiles table<number, CSV>
local addon =
{
    name            = 'PathLog',
    filters         =
    {
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_CHAR_NPC] = true, -- NPC position updates
        },
        outgoing =
        {
            [PacketId.GP_CLI_COMMAND_POS] = true, -- Player movement
        },
    },
    settings        = {},
    defaultSettings =
    {
        cumulativeDiff = 5,
        xDiff          = 3,
        yDiff          = 0.5,
        zDiff          = 3,
        rDiff          = 5,
        timeDiff       = 4,
    },
    csvFiles        = {},
    lastCoords      = {},
}

addon.onInitialize = function(rootDir)
    addon.rootDir = rootDir
end

addon.onCaptureStart = function(captureDir)
    for _, csvFile in pairs(addon.csvFiles) do
        if csvFile then
            csvFile:close()
        end
    end

    addon.csvFiles   = {}
    addon.lastCoords = {}
    addon.captureDir = captureDir
end

addon.onCaptureStop = function()
    for _, csvFile in pairs(addon.csvFiles) do
        if csvFile then
            csvFile:close()
        end
    end

    addon.csvFiles   = {}
    addon.lastCoords = {}
    addon.captureDir = nil
end

addon.onZoneChange = function()
    for _, csvFile in pairs(addon.csvFiles) do
        if csvFile then
            csvFile:close()
        end
    end

    addon.csvFiles = {}
    addon.lastCoords = {}
end

---@param id number Entity ID
---@param x number X position
---@param y number Y position
---@param z number Z position
---@param dir number Direction
---@param csvFile CSV CSV file to write to
local function trackPosition(id, x, y, z, dir, csvFile)
    local currentTime = os.time()
    local lastCoords = addon.lastCoords[id]

    -- First position for this entity
    if not lastCoords then
        lastCoords =
        {
            x         = x,
            y         = y,
            z         = z,
            dir       = dir,
            startTime = currentTime,
            lastTime  = currentTime,
            leg       = 1,
        }
        addon.lastCoords[id] = lastCoords

        csvFile:add_entry(
            {
                leg = 1, x = x, y = y, z = z, dir = dir, delta = 0,
            })
        csvFile:save()
        return
    end

    -- Calculate differences
    local xDiff          = math.abs(x - lastCoords.x)
    local yDiff          = math.abs(y - lastCoords.y)
    local zDiff          = math.abs(z - lastCoords.z)
    local rotDiff        = math.abs(dir - lastCoords.dir)
    local cumulativeDiff = xDiff + yDiff + zDiff

    -- Time calculations
    local timeDiff       = currentTime - lastCoords.lastTime
    local totalDelta     = currentTime - lastCoords.startTime

    -- Check if position changed enough to log
    if
      xDiff >= addon.settings.xDiff or
      yDiff >= addon.settings.yDiff or
      zDiff >= addon.settings.zDiff or
      cumulativeDiff >= addon.settings.cumulativeDiff or
      rotDiff >= addon.settings.rDiff
    then
        -- Start new leg if enough time passed
        if timeDiff >= addon.settings.timeDiff then
            lastCoords.leg = lastCoords.leg + 1
        end

        -- Log the position
        csvFile:add_entry(
            {
                leg   = lastCoords.leg,
                x     = x,
                y     = y,
                z     = z,
                dir   = dir,
                delta = totalDelta,
            })

        -- Update tracking data
        lastCoords.x        = x
        lastCoords.y        = y
        lastCoords.z        = z
        lastCoords.dir      = dir
        lastCoords.lastTime = currentTime

        csvFile:save()
    end
end

addon.onIncomingPacket = function(id, data)
    if id == PacketId.GP_SERV_COMMAND_CHAR_NPC then
        local packet = backend.parsePacket('incoming', data)
        if not packet or not packet.SendFlg.Position then
            return
        end

        if
          not backend.is_mob(packet.ActIndex) and
          not backend.is_npc(packet.ActIndex)
        then
            return
        end

        local mob = backend.get_mob_by_index(packet.ActIndex)
        if not mob then
            return
        end

        if not addon.csvFiles[packet.UniqueNo] then
            local baseDir = addon.captureDir or addon.rootDir

            addon.csvFiles[packet.UniqueNo] = backend.csvOpen(
                string.format('%s/%s/%s/%s/%s.csv',
                    baseDir,
                    backend.player_name(),
                    backend.zone_name(),
                    mob.name,
                    packet.UniqueNo),
                { 'leg', 'x', 'y', 'z', 'dir', 'delta' })
        end

        trackPosition(
            packet.UniqueNo,
            packet.x,
            packet.z,
            packet.y,
            packet.dir,
            addon.csvFiles[packet.UniqueNo]
        )
    end
end

addon.onOutgoingPacket = function(id, data)
    if id == PacketId.GP_CLI_COMMAND_POS then
        local packet = backend.parsePacket('outgoing', data)
        if not packet then
            return
        end

        local player = backend.get_player_entity_data()
        if not player then return end

        if not addon.csvFiles[player.serverId] then
            local baseDir = addon.captureDir or addon.rootDir

            addon.csvFiles[player.serverId] = backend.csvOpen(
                string.format('%s/%s/PC_%s.csv',
                    baseDir,
                    backend.player_name(),
                    backend.zone_name()),
                { 'leg', 'x', 'y', 'z', 'dir', 'delta' })
        end

        trackPosition(
            player.serverId,
            packet.x,
            packet.z,
            packet.y,
            packet.dir,
            addon.csvFiles[player.serverId]
        )
    end
end

addon.onConfigMenu = function()
    return
    {
        {
            key         = 'cumulativeDiff',
            title       = 'Cumulative Difference',
            description = 'Minimum cumulative difference between points',
            type        = 'slider',
            min         = 1,
            max         = 10,
            step        = 0.5,
            default     = addon.defaultSettings.cumulativeDiff,
        },
        {
            key         = 'xDiff',
            title       = 'X Difference',
            description = 'Minimum X difference between points',
            type        = 'slider',
            min         = 1,
            max         = 10,
            step        = 0.5,
            default     = addon.defaultSettings.xDiff,
        },
        {
            key         = 'yDiff',
            title       = 'Y Difference',
            description = 'Minimum Y difference between points',
            type        = 'slider',
            min         = 0.1,
            max         = 2,
            step        = 0.1,
            default     = addon.defaultSettings.yDiff,
        },
        {
            key         = 'zDiff',
            title       = 'Z Difference',
            description = 'Minimum Z difference between points',
            type        = 'slider',
            min         = 1,
            max         = 10,
            step        = 0.5,
            default     = addon.defaultSettings.zDiff,
        },
        {
            key         = 'rDiff',
            title       = 'Rotation Difference',
            description = 'Minimum r difference between points',
            type        = 'slider',
            min         = 0,
            max         = 10,
            step        = 1,
            default     = addon.defaultSettings.rDiff,
        },
        {
            key         = 'timeDiff',
            title       = 'Time Difference',
            description = 'Minimum time difference between points',
            type        = 'slider',
            min         = 1,
            max         = 10,
            step        = 1,
            default     = addon.defaultSettings.timeDiff,
        },
    }
end

return addon
