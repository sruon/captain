-- Credits: sruon
-- Asks the server for all entities in the static range
-- Only use with throw-away accounts. Must accept the disclaimer in settings.
---@class ZoneDumpAddon : AddonInterface
local addon        =
{
    name            = 'ZoneDump',
    settings        = {},
    defaultSettings =
    {
        thisWillGetMeBanned = false,
        watchInterval       = 3,
    },
    filters         =
    {
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_CHAR_NPC] = true,
        },
        outgoing =
        {
            [PacketId.GP_CLI_COMMAND_POS] = true,
        },
    },
    pendingWhereIs  = {},
    watched         = {},
}

local function requestEntity(actIndex, uniqueNo)
    backend.injectPacket(PacketId.GP_CLI_COMMAND_CHARREQ2,
        {
            PacketId.GP_CLI_COMMAND_CHARREQ2,         -- id
            0x00,                                     -- size
            0x00,                                     -- sync
            0x00,                                     -- sync
            bit.band(actIndex, 0xFF),                 -- ActIndex
            bit.band(bit.rshift(actIndex, 8), 0xFF),  -- ActIndex
            0x00,                                     -- padding00
            0x00,                                     -- padding00
            bit.band(uniqueNo, 0xFF),                 -- UniqueNo2
            bit.band(bit.rshift(uniqueNo, 8), 0xFF),  -- UniqueNo2
            bit.band(bit.rshift(uniqueNo, 16), 0xFF), -- UniqueNo2
            bit.band(bit.rshift(uniqueNo, 24), 0xFF), -- UniqueNo2
            0x00,                                     -- UniqueNo3
            0x00,                                     -- UniqueNo3
            0x00,                                     -- UniqueNo3
            0x00,                                     -- UniqueNo3
            0x00,                                     -- Flg
            0x00,                                     -- Flg
            0x00,                                     -- Flg2
            0x00,                                     -- Flg2
        })
end

-- A far away entity answers with a zeroed position, and a dead one with a status
local function isSpawned(packet)
    if packet.server_status ~= 0 then
        return false
    end

    if packet.x == 0 and packet.y == 0 and packet.z == 0 then
        return false
    end

    -- Hpp and Flags1 only carry a value when the general block is present
    if packet.SendFlg.General and (packet.Hpp == 0 or packet.Flags1.HideFlag == 1) then
        return false
    end

    return true
end

local function entityName(uniqueNo)
    local mob = backend.get_mob_by_id(uniqueNo)
    return mob and mob.name or string.format('UniqueNo %d', uniqueNo)
end

local function accepted()
    if addon.settings.thisWillGetMeBanned then
        return true
    end

    backend.msg('ZoneDump', 'Must accept disclaimer in settings before executing.')
    return false
end

addon.onCommand    = function(cmdArgs)
    local rootCmd = cmdArgs[1]

    if rootCmd == 'run' then
        if not accepted() then
            return
        end

        for actIndex = 1, 1023 do
            backend.schedule(function()
                requestEntity(actIndex, 0)
                if actIndex == 1023 then
                    backend.msg('ZoneDump', 'All requests sent.')
                end
            end, actIndex * 0.02)
        end

        backend.msg('ZoneDump', 'Staggering entities requests over the next 10 seconds. Please wait.')

    elseif rootCmd == 'whereis' then
        if not accepted() then
            return
        end

        local uniqueNo = tonumber(cmdArgs[2])
        if not uniqueNo then
            backend.msg('ZoneDump', 'Usage: /captain zonedump whereis <UniqueNo>')
            return
        end

        addon.pendingWhereIs[uniqueNo] = true
        requestEntity(0, uniqueNo)

        backend.msg('ZoneDump', string.format('Requesting position for UniqueNo %d...', uniqueNo))

    elseif rootCmd == 'watch' then
        if not accepted() then
            return
        end

        local uniqueNo = tonumber(cmdArgs[2])
        if not uniqueNo then
            backend.msg('ZoneDump', 'Usage: /captain zonedump watch <UniqueNo>')
            return
        end

        addon.watched[uniqueNo] =
        {
            spawned     = nil, -- unknown until the first answer comes back
            lastRequest = 0,
        }

        backend.msg('ZoneDump', string.format('Watching UniqueNo %d. Will announce when it spawns.', uniqueNo))

    elseif rootCmd == 'unwatch' then
        if cmdArgs[2] == 'all' then
            addon.watched = {}
            backend.msg('ZoneDump', 'Stopped watching everything.')
            return
        end

        local uniqueNo = tonumber(cmdArgs[2])
        if not uniqueNo then
            backend.msg('ZoneDump', 'Usage: /captain zonedump unwatch <UniqueNo|all>')
            return
        end

        addon.watched[uniqueNo] = nil
        backend.msg('ZoneDump', string.format('Stopped watching UniqueNo %d.', uniqueNo))

    elseif rootCmd == 'watching' then
        local count = 0
        for uniqueNo, entry in pairs(addon.watched) do
            local state = 'unknown'
            if entry.spawned ~= nil then
                state = entry.spawned and 'spawned' or 'not spawned'
            end

            backend.msg('ZoneDump', string.format('%s (%d): %s', entityName(uniqueNo), uniqueNo, state))
            count = count + 1
        end

        if count == 0 then
            backend.msg('ZoneDump', 'Not watching anything.')
        end
    end
end

-- Ride the client's own position updates so the requests follow natural traffic
addon.onOutgoingPacket = function(id)
    if id ~= PacketId.GP_CLI_COMMAND_POS then
        return
    end

    local now, oldest, oldestId = os.time(), nil, nil
    for uniqueNo, entry in pairs(addon.watched) do
        if now - entry.lastRequest >= addon.settings.watchInterval and (not oldest or entry.lastRequest < oldest) then
            oldest, oldestId = entry.lastRequest, uniqueNo
        end
    end

    if oldestId then
        addon.watched[oldestId].lastRequest = now
        requestEntity(0, oldestId)
    end
end

addon.onIncomingPacket = function(id, data, size, packet)
    if id ~= PacketId.GP_SERV_COMMAND_CHAR_NPC or not packet then
        return
    end

    local spawned = isSpawned(packet)

    if addon.pendingWhereIs[packet.UniqueNo] then
        addon.pendingWhereIs[packet.UniqueNo] = nil

        backend.msg('ZoneDump', string.format('%s (UniqueNo: %d)', entityName(packet.UniqueNo), packet.UniqueNo))
        backend.msg('ZoneDump', string.format('Position: X=%.2f, Y=%.2f, Z=%.2f', packet.x, packet.y, packet.z))
        backend.msg('ZoneDump', string.format('Spawned: %s (Hpp: %d%%, Status: %d)',
            tostring(spawned), packet.Hpp, packet.server_status))
    end

    local watch = addon.watched[packet.UniqueNo]
    if watch then
        -- Announce the rising edge only, the polling answers every interval
        if spawned and not watch.spawned then
            backend.msg('ZoneDump', string.format('%s (%d) spawned at X=%.2f, Y=%.2f, Z=%.2f',
                entityName(packet.UniqueNo), packet.UniqueNo, packet.x, packet.y, packet.z))
        end

        watch.spawned = spawned
    end
end

addon.onClientReady    = function()
    -- UniqueNos are zone scoped
    addon.watched        = {}
    addon.pendingWhereIs = {}
end

local commands     =
{
    { cmd = 'run', desc = 'Query all static entities in zone.' },
    { cmd = 'whereis <UniqueNo>', desc = 'Query position of a mob by UniqueNo.' },
    { cmd = 'watch <UniqueNo>', desc = 'Poll a mob and announce when it spawns.' },
    { cmd = 'unwatch <UniqueNo|all>', desc = 'Stop watching a mob.' },
    { cmd = 'watching', desc = 'List watched mobs and their state.' },
}

addon.onHelp       = function()
    return commands
end

addon.onConfigMenu = function()
    return
    {
        {
            key         = 'thisWillGetMeBanned',
            title       = 'I understand this is highly detectable.',
            description = 'Required to execute commands.',
            type        = 'checkbox',
            default     = addon.defaultSettings.thisWillGetMeBanned,
        },
        {
            key         = 'watchInterval',
            title       = 'Watch Polling Interval',
            description = 'Seconds between requests for each watched mob.',
            type        = 'slider',
            min         = 1,
            max         = 30,
            steps       = 1,
            default     = addon.defaultSettings.watchInterval,
        },
    }
end

return addon
