-- Incoming packet event handler class
local utils = require('utils')

---@class IncomingPacketHandler
---@field captain table The captain instance this handler is bound to
local IncomingPacketHandler = {}
IncomingPacketHandler.__index = IncomingPacketHandler

---Create a new IncomingPacketHandler instance
---@param captain table The captain instance to bind to this handler
---@return IncomingPacketHandler handler The new IncomingPacketHandler instance
function IncomingPacketHandler.new(captain)
    local self = setmetatable({}, IncomingPacketHandler)
    self.captain = captain
    return self
end

---Handle incoming packet events - processes packets through addon filters and handlers
---@param id number The packet ID
---@param data integer[] The raw packet data
---@param size number The packet size in bytes
---@return boolean shouldBlock Whether the packet should be blocked
---@return integer[]|nil modifiedPacket Modified packet data if any addon modified it
function IncomingPacketHandler:handle(id, data, size)
    local shouldBlock    = false
    local modifiedPacket = nil

    for addonName, addon in pairs(self.captain.addons) do
        if
          (addon.filters and addon.filters.incoming and addon.filters.incoming[id]) or
          (addon.filters and addon.filters.incoming and addon.filters.incoming[0x255])
        then
            if type(addon.onIncomingPacket) == 'function' then
                local ok, result = utils.withPerformanceMonitoring(addonName .. '.onIncomingPacket', function()
                    return utils.safe_call(addonName .. '.onIncomingPacket', addon.onIncomingPacket, id,
                        modifiedPacket or data, size)
                end)
                if result == true then
                    shouldBlock = true
                end
            end
        end
    end

    return shouldBlock, modifiedPacket
end

return IncomingPacketHandler