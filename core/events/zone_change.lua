-- Zone change event handler class
local utils = require('utils')

---@class ZoneChangeHandler
---@field captain table The captain instance this handler is bound to
local ZoneChangeHandler = {}
ZoneChangeHandler.__index = ZoneChangeHandler

---Create a new ZoneChangeHandler instance
---@param captain table The captain instance to bind to this handler
---@return ZoneChangeHandler handler The new ZoneChangeHandler instance
function ZoneChangeHandler.new(captain)
    local self = setmetatable({}, ZoneChangeHandler)
    self.captain = captain
    return self
end

---Handle the zone change event - notifies all addons when player changes zones
---@param zoneId number The ID of the zone the player changed to
function ZoneChangeHandler:handle(zoneId)
    for addonName, addon in pairs(self.captain.addons) do
        if type(addon.onZoneChange) == 'function' then
            utils.withPerformanceMonitoring(addonName .. '.onZoneChange', function()
                return utils.safe_call(addonName .. '.onZoneChange', addon.onZoneChange, zoneId)
            end)
        end
    end
end

return ZoneChangeHandler