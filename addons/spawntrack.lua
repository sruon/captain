-- Tracks respawn time and position
-- This works on all mobs even past the 50 yalms range relying on CHARREQ2 packet
-- Note: This is very detectable, use throw away accounts.
-- The PC capturing does not have to be the PC killing the mobs, it just needs to see the defeat messages.
---@class SpawnTrackAddon : AddonInterface
local addon =
{
    name            = 'SpawnTrack',
    filters         =
    {
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_BATTLE_MESSAGE] = true,
            [PacketId.GP_SERV_COMMAND_CHAR_NPC]       = true,
            [PacketId.GP_SERV_COMMAND_SCHEDULOR]      = true,
        },
    },
    settings        = {},
    defaultSettings =
    {
        thisWillGetMeBanned = false,
        interval            = 1,           -- How often to send a request until mob spawns.
        expectedRespawn     = 4 * 60 + 30, -- Start tracking around 4:30s
    },
    mobs            = {},
    files           =
    {
        global  = nil,
        capture = nil,
    },
}

local function secondsToTimeString(seconds)
    local hours   = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs    = seconds % 60

    if hours > 0 then
        return string.format('%d:%02d:%02d', hours, minutes, secs)
    else
        return string.format('%d:%02d', minutes, secs)
    end
end

local function trackMob(UniqueNo, ActIndex)
    if not addon.mobs[UniqueNo] then
        -- Stop looping if we're no longer tracking
        return
    end

    backend.schedule(function()
        backend.injectPacket(PacketId.GP_CLI_COMMAND_CHARREQ2,
            {
                PacketId.GP_CLI_COMMAND_CHARREQ2,        -- id
                0x00,                                    -- size
                0x00,                                    -- sync
                0x00,                                    -- sync
                bit.band(ActIndex, 0xFF),                -- ActIndex
                bit.band(bit.rshift(ActIndex, 8), 0xFF), -- ActIndex
                0x00,                                    -- padding00
                0x00,                                    -- padding00
                0x00,                                    -- UniqueNo2
                0x00,                                    -- UniqueNo2
                0x00,                                    -- UniqueNo2
                0x00,                                    -- UniqueNo2
                0x00,                                    -- UniqueNo3
                0x00,                                    -- UniqueNo3
                0x00,                                    -- UniqueNo3
                0x00,                                    -- UniqueNo3
                0x00,                                    -- Flg
                0x00,                                    -- Flg
                0x00,                                    -- Flg2
                0x00,                                    -- Flg2
            })

        -- Keep rescheduling until we're no longer tracking
        trackMob(UniqueNo, ActIndex)
    end, addon.settings.interval)
end

addon.onIncomingPacket = function(id, data, size)
    ---@type GP_SERV_COMMAND_BATTLE_MESSAGE | GP_SERV_COMMAND_CHAR_NPC | GP_SERV_COMMAND_SCHEDULOR
    local packet = backend.parsePacket('incoming', data)

    if not addon.settings.thisWillGetMeBanned then
        return
    end

    if id == PacketId.GP_SERV_COMMAND_BATTLE_MESSAGE then -- Mob Defeated. 6 == defeated, 20 == falls to the ground
        if
          packet and
          (packet.MessageNum == 6 or packet.MessageNum == 20) and
          packet.UniqueNoTar
        then
            local defeatedTime = os.time()
            local defeatedId   = packet.UniqueNoTar
            local mob          = backend.get_mob_by_index(packet.ActIndexTar)
            local mob_name     = mob and mob.name or tostring(defeatedId)
            local log_string   = string.format('Tracking %s (%d) defeated at %s', mob_name, defeatedId,
                os.date('%H:%M:%S', defeatedTime))
            if mob then
                backend.msg('SpawnTrack', log_string)

                if addon.files.global then
                    addon.files.global:append(log_string .. '\n')
                end

                if addon.files.capture then
                    addon.files.capture:append(log_string .. '\n')
                end

                addon.mobs[defeatedId] =
                {
                    defeatedTime = defeatedTime,
                    name         = mob_name,
                    x            = mob.x,
                    y            = mob.y,
                    z            = mob.z,
                }

                -- Start tracking respawn time and position around the expectedRespawn
                backend.schedule(function()
                    trackMob(packet.UniqueNoTar, packet.ActIndexTar)
                end, addon.settings.expectedRespawn)
            end
        end
    elseif id == PacketId.GP_SERV_COMMAND_CHAR_NPC then
        if addon.mobs[packet.UniqueNo] then
            -- Filter out unwanted packets
            if
              not packet.SendFlg.Position or                            -- Packet does not have position
              packet.server_status ~= 0 or                              -- Mob is not alive
              not addon.mobs[packet.UniqueNo].despawnTime or            -- Mob has not despawned
              os.time() < addon.mobs[packet.UniqueNo].defeatedTime + 20 -- Mob has not been defeated long enough
            then
                return
            end

            local outputLines      = {}
            local spawnTime        = os.time()
            local despawnTime      = addon.mobs[packet.UniqueNo].despawnTime
            local defeatedTime     = addon.mobs[packet.UniqueNo].defeatedTime
            local despawnTimeDiff  = spawnTime - despawnTime
            local defeatedTimeDiff = spawnTime - defeatedTime
            local xDiff            = packet.x - addon.mobs[packet.UniqueNo].x
            local yDiff            = packet.y - addon.mobs[packet.UniqueNo].y
            local zDiff            = packet.z - addon.mobs[packet.UniqueNo].z

            table.insert(outputLines,
                string.format('%s (%d) respawned at %s (X: %d, Y: %d, Z: %d)',
                    addon.mobs[packet.UniqueNo].name,
                    packet.UniqueNo, os.date('%H:%M:%S', spawnTime), packet.x, packet.y, packet.z))
            table.insert(outputLines,
                string.format('Defeat-to-spawn: %s, Despawn-to-spawn: %s, X diff: %d, Y diff: %d, Z diff: %d',
                    secondsToTimeString(defeatedTimeDiff), secondsToTimeString(despawnTimeDiff), xDiff, yDiff, zDiff))

            for _, line in ipairs(outputLines) do
                backend.msg('SpawnTrack', line)
            end

            addon.mobs[packet.UniqueNo] = nil
        end
    elseif id == PacketId.GP_SERV_COMMAND_SCHEDULOR then
        if packet.FourCCString ~= 'kesu' then
            return
        end

        if addon.mobs[packet.UniqueNoTar] then
            local despawnTime                          = os.time()
            addon.mobs[packet.UniqueNoTar].despawnTime = despawnTime
            backend.msg('SpawnTrack',
                string.format('%s (%d) despawned at %s',
                    addon.mobs[packet.UniqueNoTar].name,
                    packet.UniqueNoTar,
                    os.date('%H:%M:%S', despawnTime)))
        end
    end
end

addon.onCaptureStart   = function(captureDir)
    addon.captureDir    = captureDir
    addon.files.capture = backend.fileOpen(
        string.format('%s/%s.log',
            captureDir,
            backend.zone_name())
    )
end

addon.onCaptureStop    = function()
    addon.captureDir    = nil
    addon.files.capture = nil
end

addon.onInitialize     = function(rootDir)
    addon.rootDir      = rootDir
    addon.files.global = backend.fileOpen(
        string.format('%s/%s/%s.log',
            rootDir,
            backend.player_name(),
            backend.zone_name())
    )
end

addon.onClientReady    = function(zoneId)
    addon.mobs         = {}
    addon.files.global = backend.fileOpen(
        string.format('%s/%s/%s.log',
            addon.rootDir,
            backend.player_name(),
            backend.zone_name())
    )

    if addon.files.capture then
        addon.files.capture = backend.fileOpen(
            string.format('%s/%s.log',
                addon.captureDir,
                backend.zone_name())
        )
    end
end

addon.onConfigMenu     = function()
    return
    {
        {
            key         = 'thisWillGetMeBanned',
            title       = 'I understand this is highly detectable and will get me banned.',
            description = 'Addon will not work without checking this setting.',
            type        = 'checkbox',
            default     = addon.defaultSettings.thisWillGetMeBanned,
        },
        {
            key         = 'interval',
            title       = 'Interval',
            description = 'How often to send CHARREQ2 packets when monitoring respawn',
            type        = 'slider',
            min         = 1,
            max         = 20,
            steps       = 1,
            default     = addon.defaultSettings.interval,
        },
        {
            key         = 'expectedRespawn',
            title       = 'Expected respawn time',
            description = 'How soon after death we should start sending packets. Adjust based on zone respawn time.',
            type        = 'slider',
            min         = 5,
            max         = 30 * 60, -- 30 minutes max, may need to adjust
            steps       = 5,
            default     = addon.defaultSettings.expectedRespawn,
        },
    }
end

return addon
