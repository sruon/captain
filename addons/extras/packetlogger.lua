-- Credits: Based on zach2good original work, adapted by sruon
---@class PacketLoggerAddon : AddonInterface
---@field captureDir? string
local addon            =
{
    name       = 'PacketLogger',
    filters    =
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
    settings   = {},
    captureDir = nil,
    files      =
    {
        bothAll       = nil, -- All packets saved to one file
        outgoingPerId = {},  -- Outgoing packets saved to separate files
        incomingPerId = {},  -- Incoming packets saved to separate files
    },
}

local socket           = require('socket')

addon.onIncomingPacket = function(id, data, size, packet)
    if not captain.isCapturing then
        return
    end

    local time     = socket.gettime()
    local timestr  = os.date('%Y-%m-%d %H:%M:%S', math.floor(time)) ..
      string.format('.%03d', math.floor((time % 1) * 1000))
    local hexidstr = string.format('0x%.3X', id)
    local hexdump  = string.hexformat_file(data, size) .. '\n'

    if addon.files.bothAll then
        addon.files.bothAll:append(string.format('[%s] Incoming packet %s\n', timestr, hexidstr))
        addon.files.bothAll:append(hexdump)
    end

    if addon.files.incomingPerId[id] == nil then
        addon.files.incomingPerId[id] = backend.fileOpen(string.format('%s/incoming/%s.log',
            addon.captureDir, hexidstr))
    end

    addon.files.incomingPerId[id]:append(string.format('[%s] Packet %s\n', timestr, hexidstr))
    addon.files.incomingPerId[id]:append(hexdump)
end

addon.onOutgoingPacket = function(id, data, size, packet)
    if not captain.isCapturing then
        return
    end

    local time     = socket.gettime()
    local timestr  = os.date('%Y-%m-%d %H:%M:%S', math.floor(time)) ..
      string.format('.%03d', math.floor((time % 1) * 1000))
    local hexidstr = string.format('0x%.3X', id)
    local hexdump  = string.hexformat_file(data, size) .. '\n'

    if addon.files.bothAll then
        addon.files.bothAll:append(string.format('[%s] Outgoing packet %s\n', timestr, hexidstr))
        addon.files.bothAll:append(hexdump)
    end

    if addon.files.outgoingPerId[id] == nil then
        addon.files.outgoingPerId[id] = backend.fileOpen(string.format('%s/outgoing/%s.log',
            addon.captureDir, hexidstr))
    end

    addon.files.outgoingPerId[id]:append(string.format('[%s] Packet %s\n', timestr, hexidstr))
    addon.files.outgoingPerId[id]:append(hexdump)
end

addon.onCaptureStart   = function(captureDir)
    addon.captureDir          = captureDir

    -- Clear any existing per-ID file handles from previous capture
    addon.files.incomingPerId = {}
    addon.files.outgoingPerId = {}

    addon.files.bothAll       = backend.fileOpen(string.format('%s/full.log', addon.captureDir))
end

addon.onCaptureStop    = function()
    addon.files.bothAll       = nil

    -- Clear per-ID file handles
    addon.files.incomingPerId = {}
    addon.files.outgoingPerId = {}
end

return addon
