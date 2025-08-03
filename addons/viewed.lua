---@class ViewedAddon : AddonInterface
local addon =
{
    name            = 'VieweD',
    filters         =
    {
        incoming =
        {
            [PacketId.MAGIC_ALL_PACKETS] = true,
        },

        outgoing =
        {
            [PacketId.MAGIC_ALL_PACKETS] = true,
        },
    },
    defaultSettings =
    {
        enabled = false,
        port    = 55555,
    },
    settings        = {},
    udp_socket      = nil,
}

-- UDP packet sending function
local function sendUDPPacket(rawData)
    if not addon.udp_socket then
        return false, 'UDP socket not initialized'
    end

    local result, err = addon.udp_socket:sendto(rawData, '127.0.0.1', 55555)

    return result, err
end

addon.onIncomingPacket = function(id, data, size)
    if not addon.settings.enabled then
        return
    end

    local rawData = string.char(0x00) .. string.sub(data, 1, size)

    backend.schedule(function() sendUDPPacket(rawData) end, 0)
end

addon.onOutgoingPacket = function(id, data, size)
    if not addon.settings.enabled then
        return
    end

    local rawData = string.char(0x01) .. string.sub(data, 1, size)

    backend.schedule(function() sendUDPPacket(rawData) end, 0)
end

addon.onInitialize     = function(_)
    local socket     = require('socket')
    addon.udp_socket = socket.udp()
end

addon.onUnload         = function()
    addon.settings.enabled = false

    if addon.udp_socket then
        addon.udp_socket:close()
        addon.udp_socket = nil
    end
end

addon.onConfigMenu     = function()
    return
    {
        {
            key         = 'enabled',
            title       = 'Enable VieweD bridge',
            description = 'If enabled, this addon will stream packets to VieweD.',
            type        = 'checkbox',
            default     = addon.defaultSettings.enabled,
        },
        {
            key         = 'port',
            title       = 'VieweD UDP port',
            description = 'VieweD UDP port to stream packets to.',
            type        = 'slider',
            min         = 1025,
            max         = 65535,
            step        = 1,
            default     = addon.defaultSettings.port,
        },
    }
end

return addon
