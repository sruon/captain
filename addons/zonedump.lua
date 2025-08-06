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
            end, actIndex * 0.01)
        end

        backend.msg('ZoneDump', 'Staggering entities requests over the next 10 seconds. Please wait.')
    end
end

local commands     =
{
    { cmd = 'run', desc = 'Query all static entities in zone.' },
}

addon.onHelp       = function()
    return commands
end

addon.onConfigMenu = function()
    return
    {
        {
            key         = 'thisWillGetMeBanned',
            title       = 'I understand this is highly detectable and will get me banned.',
            description = 'Command will not execute without checking this setting.',
            type        = 'checkbox',
            default     = addon.defaultSettings.thisWillGetMeBanned,
        },
    }
end

return addon
