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
    },
    filters         =
    {
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_CHAR_NPC] = true,
        },
    },
    pendingWhereIs  = {},
}

addon.onCommand    = function(cmdArgs)
    local rootCmd = cmdArgs[1]

    if rootCmd == 'run' then
        if not addon.settings.thisWillGetMeBanned then
            backend.msg('ZoneDump', 'Must accept disclaimer in settings before executing.')
            return
        end

        for actIndex = 1, 1023 do
            backend.schedule(function()
                backend.injectPacket(PacketId.GP_CLI_COMMAND_CHARREQ2,
                    {
                        PacketId.GP_CLI_COMMAND_CHARREQ2,        -- id
                        0x00,                                    -- size
                        0x00,                                    -- sync
                        0x00,                                    -- sync
                        bit.band(actIndex, 0xFF),                -- ActIndex
                        bit.band(bit.rshift(actIndex, 8), 0xFF), -- ActIndex
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
                if actIndex == 1023 then
                    backend.msg('ZoneDump', 'All requests sent.')
                end
            end, actIndex * 0.02)
        end

        backend.msg('ZoneDump', 'Staggering entities requests over the next 10 seconds. Please wait.')

    elseif rootCmd == 'whereis' then
        if not addon.settings.thisWillGetMeBanned then
            backend.msg('ZoneDump', 'Must accept disclaimer in settings.')
            return
        end

        local uniqueNo = tonumber(cmdArgs[2])
        if not uniqueNo then
            backend.msg('ZoneDump', 'Usage: /captain zonedump whereis <UniqueNo>')
            return
        end

        addon.pendingWhereIs[uniqueNo] = true

        backend.injectPacket(PacketId.GP_CLI_COMMAND_CHARREQ2,
            {
                PacketId.GP_CLI_COMMAND_CHARREQ2,                -- id
                0x00,                                            -- size
                0x00,                                            -- sync
                0x00,                                            -- sync
                0x00,                                            -- ActIndex
                0x00,                                            -- ActIndex
                0x00,                                            -- padding
                0x00,                                            -- padding
                bit.band(uniqueNo, 0xFF),                        -- UniqueNo2
                bit.band(bit.rshift(uniqueNo, 8), 0xFF),         -- UniqueNo2
                bit.band(bit.rshift(uniqueNo, 16), 0xFF),        -- UniqueNo2
                bit.band(bit.rshift(uniqueNo, 24), 0xFF),        -- UniqueNo2
                0x00,                                            -- UniqueNo3
                0x00,                                            -- UniqueNo3
                0x00,                                            -- UniqueNo3
                0x00,                                            -- UniqueNo3
                0x00,                                            -- Flg
                0x00,                                            -- Flg
                0x00,                                            -- Flg2
                0x00,                                            -- Flg2
            })

        backend.msg('ZoneDump', string.format('Requesting position for UniqueNo %d...', uniqueNo))
    end
end

addon.onIncomingPacket = function(id, data, size, packet)
    if id == PacketId.GP_SERV_COMMAND_CHAR_NPC then
        if not packet then
            return
        end

        if addon.pendingWhereIs[packet.UniqueNo] then
            addon.pendingWhereIs[packet.UniqueNo] = nil

            local mob = backend.get_mob_by_id(packet.UniqueNo)
            local mobName = mob and mob.name or 'Unknown'
            local posIsZero = packet.x == 0 and packet.y == 0 and packet.z == 0
            local spawned = packet.server_status == 0 and not posIsZero

            backend.msg('ZoneDump', string.format('%s (UniqueNo: %d)', mobName, packet.UniqueNo))
            backend.msg('ZoneDump', string.format('Position: X=%.2f, Y=%.2f, Z=%.2f', packet.x, packet.y, packet.z))
            backend.msg('ZoneDump', string.format('Spawned: %s (Hpp: %d%%, Status: %d)',
                tostring(spawned), packet.Hpp, packet.server_status))
        end
    end
end

local commands     =
{
    { cmd = 'run', desc = 'Query all static entities in zone.' },
    { cmd = 'whereis <UniqueNo>', desc = 'Query position of a mob by UniqueNo.' },
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
    }
end

return addon
