-- Tracks level ranges of mobs from widescan data
---@class LevelRangeTrackAddon : AddonInterface
local addon                =
{
    name            = 'LevelRangeTrack',
    filters         =
    {
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_TRACKING_LIST] = true,
        },
    },
    settings        = {},
    defaultSettings =
    {
    },
    databases       =
    {
        global  = nil,
        capture = nil,
    },
    rootDir         = nil,
    captureDir      = nil,
    schema          =
    {
        UniqueNo  = 0,
        ActIndex  = 0,
        sName     = 'Unknown',
        Level_min = 255,
        Level_max = 0,
    },
}

local TrackingListTbl_Type =
{
    PLAYER   = 0,
    FRIENDLY = 1,
    ENEMY    = 2,
}

local function getAllDbs()
    local dbs = {}
    if addon.databases.global then
        table.insert(dbs, addon.databases.global)
    end
    if addon.databases.capture then
        table.insert(dbs, addon.databases.capture)
    end
    return dbs
end

addon.onIncomingPacket = function(id, data)
    if id == PacketId.GP_SERV_COMMAND_TRACKING_LIST then
        ---@type GP_SERV_COMMAND_TRACKING_LIST
        local packet = backend.parsePacket('incoming', data)
        if not packet then
            return
        end

        -- Only track enemies (mobs)
        if packet.Type ~= TrackingListTbl_Type.ENEMY then
            return
        end

        local act_index = packet.ActIndex
        local name      = packet.sName
        local level     = packet.Level

        if not act_index or level == nil or level < 0 then
            return
        end

        local dbs = getAllDbs()
        if #dbs == 0 then
            return
        end

        local unique_no = bit.lshift(backend.zone(), 12) + 0x1000000 + act_index
        local mob_id    = tostring(unique_no)

        -- Use global db as source of truth
        local existing  = addon.databases.global and addon.databases.global:get(mob_id)

        if existing then
            -- Only update if level range changed or name changed
            local needsUpdate = false

            if level < existing.Level_min then
                existing.Level_min = level
                needsUpdate        = true
            end

            if level > existing.Level_max then
                existing.Level_max = level
                needsUpdate        = true
            end

            -- Update name if it changed or was empty
            if name and name ~= '' and existing.sName ~= name then
                existing.sName = name
                needsUpdate    = true
            end

            -- Only write to database if something actually changed
            if needsUpdate then
                for _, db in ipairs(dbs) do
                    db:add_or_update(mob_id, existing)
                end
            end
        else
            -- Create new entry
            local entry = {
                UniqueNo  = unique_no,
                ActIndex  = act_index,
                sName     = name or 'Unknown',
                Level_min = level,
                Level_max = level,
            }
            for _, db in ipairs(dbs) do
                db:add_or_update(mob_id, entry)
            end
        end
    end
end

addon.onInitialize     = function(rootDir)
    addon.rootDir          = rootDir

    local zoneName         = backend.zone_name()
    addon.databases.global = backend.databaseOpen(
        string.format('%s/%s/%s.db', rootDir, backend.player_name(), zoneName),
        {
            schema = addon.schema,
        })
end

addon.onCaptureStart   = function(captureDir)
    addon.captureDir = captureDir

    if addon.databases.capture then
        addon.databases.capture:close()
        addon.databases.capture = nil
    end

    addon.databases.capture = backend.databaseOpen(
        string.format('%s/%s.db', captureDir, backend.zone_name()),
        {
            schema = addon.schema,
        })
end

addon.onCaptureStop    = function()
    if addon.databases.capture then
        addon.databases.capture:close()
        addon.databases.capture = nil
    end
    addon.captureDir = nil
end

addon.onClientReady    = function(zoneId)
    if addon.databases.global then
        addon.databases.global:close()
        addon.databases.global = nil
    end

    if addon.databases.capture then
        addon.databases.capture:close()
        addon.databases.capture = nil
    end

    if addon.rootDir then
        addon.databases.global = backend.databaseOpen(
            string.format('%s/%s/%s.db', addon.rootDir, backend.player_name(), backend.zone_name(zoneId)),
            {
                schema = addon.schema,
            })
    end

    if addon.captureDir then
        addon.databases.capture = backend.databaseOpen(
            string.format('%s/%s.db', addon.captureDir, backend.zone_name(zoneId)),
            {
                schema = addon.schema,
            })
    end
end

return addon
