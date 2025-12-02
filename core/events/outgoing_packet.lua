-- Outgoing packet event handler class
local utils = require('utils')

---@class OutgoingPacketHandler
---@field captain table The captain instance this handler is bound to
local OutgoingPacketHandler = {}
OutgoingPacketHandler.__index = OutgoingPacketHandler

---Create a new OutgoingPacketHandler instance
---@param captain table The captain instance to bind to this handler
---@return OutgoingPacketHandler handler The new OutgoingPacketHandler instance
function OutgoingPacketHandler.new(captain)
    local self = setmetatable({}, OutgoingPacketHandler)
    self.captain = captain
    return self
end

---Handle outgoing packet events - processes packets through addon filters and handlers
---@param id number The packet ID
---@param data integer[] The raw packet data
---@param size number The packet size in bytes
---@return boolean shouldBlock Whether the packet should be blocked
function OutgoingPacketHandler:handle(id, data, size)

    local shouldBlock = false
    for addonName, addon in pairs(self.captain.addons) do
        if
          (addon.filters and addon.filters.outgoing and addon.filters.outgoing[id]) or
          (addon.filters and addon.filters.outgoing and addon.filters.outgoing[0x255])
        then
            if type(addon.onOutgoingPacket) == 'function' then
                local ok, result = utils.withPerformanceMonitoring(addonName .. '.onOutgoingPacket', function()
                    return utils.safe_call(addonName .. '.onOutgoingPacket', addon.onOutgoingPacket, id, data, size)
                end)
                if result == true then
                    shouldBlock = true
                end
            end
        end
    end

    return shouldBlock
end

return OutgoingPacketHandler