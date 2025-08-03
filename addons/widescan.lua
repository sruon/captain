-- Sends a widescan packet every N seconds
-- Logic pulled out of npclogger so that the packet is sent just once for many addons
-- TODO: This could be moved to captain itself and updates vended as a new event onWidescanUpdate
---@class WidescanAddon : AddonInterface
local addon            =
{
    name             = 'AutoWidescan',
    filters          =
    {
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_TRACKING_LIST]  = true, -- Widescan updates
            [PacketId.GP_SERV_COMMAND_TRACKING_STATE] = true, -- Widescan state updates
            [PacketId.GP_SERV_COMMAND_LOGOUT]         = true, -- Zone out
            [PacketId.GP_SERV_COMMAND_ENTERZONE]      = true, -- Zone in
        },
        outgoing =
        {
            [PacketId.GP_CLI_COMMAND_GAMEOK] = true, -- Client is ready to receive additional packets
        },
    },
    settings         = {},
    defaultSettings  =
    {
        widescan =
        {
            enabled = true,
            delay   = 60,
        },
    },
    coroutinesSetup  = false,
    lastWidescanTime = os.time(),
    entitiesCount    = 0,
    zonedOut         = false,
}

addon.onIncomingPacket = function(id, data)
    local packet = backend.parsePacket('incoming', data)
    if id == PacketId.GP_SERV_COMMAND_TRACKING_STATE then
        ---@type GP_SERV_COMMAND_TRACKING_STATE
        packet = packet
        if packet.State == GP_TRACKING_STATE.GP_TRACKING_STATE_LIST_START then
            addon.entitiesCount = 0
        elseif packet.State == GP_TRACKING_STATE.GP_TRACKING_STATE_LIST_END then
            backend.msg('AutoWidescan', string.format('Received updates for %d entities.', addon.entitiesCount))
        end
    elseif id == PacketId.GP_SERV_COMMAND_TRACKING_LIST then
        addon.entitiesCount = addon.entitiesCount + 1
    elseif id == PacketId.GP_SERV_COMMAND_LOGOUT then
        -- Client is zoning out / logging out
        addon.zonedOut = true
    end
end

addon.onOutgoingPacket = function(id, data)
    -- Client is ready to receive additional packets
    if id == PacketId.GP_CLI_COMMAND_GAMEOK then
        addon.zonedOut         = false
        addon.lastWidescanTime = os.time()
    end
end

addon.onPrerender      = function()
    if not addon.settings.widescan.enabled then
        return
    end

    local player = backend.get_player_entity_data()
    if player.serverId == 0 then
        return
    end

    if addon.zonedOut then
        return
    end

    local currentTime = os.time()
    if currentTime - addon.lastWidescanTime > addon.settings.widescan.delay then
        backend.doWidescan()
        addon.lastWidescanTime = currentTime
    end
end

addon.onConfigMenu     = function()
    return
    {
        {
            key         = 'widescan.enabled',
            title       = 'Enable Auto Widescan',
            description = 'If enabled, this addon will send widescan packets even when client does not allow it.',
            type        = 'checkbox',
            default     = addon.defaultSettings.widescan.enabled,
        },
        {
            key         = 'widescan.delay',
            title       = 'Widescan Delay',
            description = 'Time in seconds between widescan packets',
            type        = 'slider',
            min         = 5,
            max         = 60,
            step        = 5,
            default     = addon.defaultSettings.widescan.delay,
        },
    }
end

return addon
