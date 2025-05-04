-- Credits: Based on zach2good original work, adapted by sruon
---@class PacketViewerAddon : AddonInterface
---@field files { incomingAll: File?, outgoingAll: File?, bothAll: File?, outgoingPerId: table<number, File>, incomingPerId: table<number, File> }
---@field captureDir? string
---@field windows { inputPacket: any, outputPacket: any }
local addon =
{
    name       = 'PacketViewer',
    filters    =
    {
        incoming =
        {
            [PacketId.MAGIC_ALL_PACKETS] = true,
        },

        outgoing =
        {
            [PacketId.MAGIC_ALL_PACKETS] = true,
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
        if addon.files.incomingAll then
            addon.files.incomingAll:append(string.format('[%s] Packet %s\n', timestr, hexidstr))
            addon.files.incomingAll:append(string.hexformat_file(data, size) .. '\n')
        end

        if addon.files.bothAll then
            addon.files.bothAll:append(string.format('[%s] Incoming packet %s\n', timestr, hexidstr))
            addon.files.bothAll:append(string.hexformat_file(data, size) .. '\n')
        end

        if addon.files.incomingPerId[id] == nil then
            addon.files.incomingPerId[id] = backend.fileOpen(addon.captureDir ..
                'incoming/' .. hexidstr .. '.log')
        end

        addon.files.incomingPerId[id]:append(string.format('[%s] Packet %s\n', timestr, hexidstr))
        addon.files.incomingPerId[id]:append(string.hexformat_file(data, size) .. '\n')
    end

    --addon.windows.inputPacket:updateTitle(string.format('[%s] Incoming packet %s', timestr, hexidstr))
    --addon.windows.inputPacket:updateText(string.hexformat_file(data, size))
end

addon.onOutgoingPacket = function(id, data, size)
    local timestr = os.date('%Y-%m-%d %H:%M:%S')
    local hexidstr = string.format('0x%.3X', id)

    if captain.isCapturing then
        if addon.files.outgoingAll then
            addon.files.outgoingAll:append(string.format('[%s] Packet %s\n', timestr, hexidstr))
            addon.files.outgoingAll:append(string.hexformat_file(data, size) .. '\n')
        end

        if addon.files.bothAll then
            addon.files.bothAll:append(string.format('[%s] Outgoing packet %s\n', timestr, hexidstr))
            addon.files.bothAll:append(string.hexformat_file(data, size) .. '\n')
        end

        if addon.files.outgoingPerId[id] == nil then
            addon.files.outgoingPerId[id] = backend.fileOpen(addon.captureDir ..
                'outgoing/' .. hexidstr .. '.log')
        end

        addon.files.outgoingPerId[id]:append(string.format('[%s] Packet %s\n', timestr, hexidstr))
        addon.files.outgoingPerId[id]:append(string.hexformat_file(data, size) .. '\n')
    end

    --addon.windows.outputPacket:updateTitle(string.format('[%s] Outgoing packet %s', timestr, hexidstr))
    --addon.windows.outputPacket:updateText(string.hexformat_file(data, size))
end

addon.onCaptureStart = function(captureDir)
    addon.captureDir        = captureDir
    addon.files.incomingAll = backend.fileOpen(addon.captureDir .. 'incoming.log')
    addon.files.outgoingAll = backend.fileOpen(addon.captureDir .. 'outgoing.log')
    addon.files.bothAll     = backend.fileOpen(addon.captureDir .. 'full.log')
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
