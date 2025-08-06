-- Incoming text event handler class
local utils = require('utils')

---@class IncomingTextHandler
---@field captain table The captain instance this handler is bound to
local IncomingTextHandler = {}
IncomingTextHandler.__index = IncomingTextHandler

---Create a new IncomingTextHandler instance
---@param captain table The captain instance to bind to this handler
---@return IncomingTextHandler handler The new IncomingTextHandler instance
function IncomingTextHandler.new(captain)
    local self = setmetatable({}, IncomingTextHandler)
    self.captain = captain
    return self
end

---Handle incoming text events - processes chat messages through addon handlers
---@param mode number The chat mode/channel
---@param text string The incoming text message
function IncomingTextHandler:handle(mode, text)
    for addonName, addon in pairs(self.captain.addons) do
        if type(addon.onIncomingText) == 'function' then
            utils.withPerformanceMonitoring(addonName .. '.onIncomingText', function()
                return utils.safe_call(addonName .. '.onIncomingText', addon.onIncomingText, mode, text)
            end)
        end
    end
end

return IncomingTextHandler