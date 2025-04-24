-- Credits: Based on zach2good original work, adapted by sruon
---@class PacketViewerAddon : AddonInterface
---@field files { incomingAll: file?, outgoingAll: file?, bothAll: file?, outgoingPerId: table<number, file>, incomingPerId: table<number, file> }
---@field captureDir? string
---@field windows { inputPacket: any, outputPacket: any }
local addon =
{
    name       = 'PacketViewer',
    filters    =
    {
        incoming =
        {
            [PacketId.MAGIC_ALL_PACKETS] = true, -- All packets
        },

        outgoing =
        {
            [PacketId.MAGIC_ALL_PACKETS] = true, -- All packets
        }
    },
    settings   = {},
    windows    =
    {
        inputPacket  = {},
        outputPacket = {}
    },
    captureDir = nil,
    files      =
    {
        incomingAll   = nil, -- All incoming packets saved to one file
        outgoingAll   = nil, -- All outgoing packets saved to one file
        bothAll       = nil, -- All packets saved to one file
        outgoingPerId = {},  -- Outgoing packets saved to separate files
        incomingPerId = {},  -- Incoming packets saved to separate files
    }
}

addon.onIncomingPacket = function(id, data, size)
    local timestr  = os.date('%Y-%m-%d %H:%M:%S')
    local hexidstr = string.format('0x%.3X', id)

    if captain.isCapturing then
        backend.fileAppend(addon.files.incomingAll, string.format('[%s] Packet %s\n', timestr, hexidstr))
        backend.fileAppend(addon.files.incomingAll, string.hexformat_file(data, size) .. '\n')
        backend.fileAppend(addon.files.bothAll, string.format('[%s] Incoming packet %s\n', timestr, hexidstr))
        backend.fileAppend(addon.files.bothAll, string.hexformat_file(data, size) .. '\n')
        if addon.files.incomingPerId[id] == nil then
            addon.files.incomingPerId[id] = backend.fileOpen(addon.captureDir ..
                'packetviewer/incoming/' .. hexidstr .. '.log')
        end

        backend.fileAppend(addon.files.incomingPerId[id], string.format('[%s] Packet %s\n', timestr, hexidstr))
        backend.fileAppend(addon.files.incomingPerId[id], string.hexformat_file(data, size) .. '\n')
    end

    --addon.windows.inputPacket:updateTitle(string.format('[%s] Incoming packet %s', timestr, hexidstr))
    --addon.windows.inputPacket:updateText(string.hexformat_file(data, size))
end

addon.onOutgoingPacket = function(id, data, size)
    local timestr = os.date('%Y-%m-%d %H:%M:%S')
    local hexidstr = string.format('0x%.3X', id)

    if captain.isCapturing then
        backend.fileAppend(addon.files.outgoingAll, string.format('[%s] Packet %s\n', timestr, hexidstr))
        backend.fileAppend(addon.files.outgoingAll, string.hexformat_file(data, size) .. '\n')
        backend.fileAppend(addon.files.bothAll, string.format('[%s] Outgoing packet %s\n', timestr, hexidstr))
        backend.fileAppend(addon.files.bothAll, string.hexformat_file(data, size) .. '\n')
        if addon.files.outgoingPerId[id] == nil then
            addon.files.outgoingPerId[id] = backend.fileOpen(addon.captureDir ..
                'packetviewer/outgoing/' .. hexidstr .. '.log')
        end

        backend.fileAppend(addon.files.outgoingPerId[id], string.format('[%s] Packet %s\n', timestr, hexidstr))
        backend.fileAppend(addon.files.outgoingPerId[id], string.hexformat_file(data, size) .. '\n')
    end

    --addon.windows.outputPacket:updateTitle(string.format('[%s] Outgoing packet %s', timestr, hexidstr))
    --addon.windows.outputPacket:updateText(string.hexformat_file(data, size))
end

addon.onCaptureStart = function(captureDir)
    addon.captureDir        = captureDir
    addon.files.incomingAll = backend.fileOpen(addon.captureDir .. 'packetviewer/incoming.log')
    addon.files.outgoingAll = backend.fileOpen(addon.captureDir .. 'packetviewer/outgoing.log')
    addon.files.bothAll     = backend.fileOpen(addon.captureDir .. 'packetviewer/full.log')
end

addon.onCaptureStop = function()
    addon.files.incomingAll = nil
    addon.files.outgoingAll = nil
    addon.files.bothAll     = nil
end

addon.onInitialize = function(_)
    addon.windows.inputPacket  = backend.textBox('out')
    addon.windows.outputPacket = backend.textBox('in')

    -- Kinda useless until we get some sort of filtering
    addon.windows.inputPacket:hide()
    addon.windows.outputPacket:hide()
end

return addon
