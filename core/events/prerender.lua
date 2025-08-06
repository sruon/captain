-- Prerender event handler class
local utils = require('utils')
local backend = require('backend.backend')

---@class PrerenderHandler
---@field captain table The captain instance this handler is bound to
local PrerenderHandler = {}
PrerenderHandler.__index = PrerenderHandler

---Create a new PrerenderHandler instance
---@param captain table The captain instance to bind to this handler
---@return PrerenderHandler handler The new PrerenderHandler instance
function PrerenderHandler.new(captain)
    local self = setmetatable({}, PrerenderHandler)
    self.captain = captain
    return self
end

---Handle the prerender event - renders config menu, notifications, and notifies addons
---Called every frame before rendering to handle UI updates
function PrerenderHandler:handle()
    -- User requested config menu
    if self.captain.showConfig then
        backend.configMenu()
    end

    -- Render notifications
    self.captain.notificationMgr:render()

    -- Notify addons of render event
    for addonName, addon in pairs(self.captain.addons) do
        if type(addon.onPrerender) == 'function' then
            utils.withPerformanceMonitoring(addonName .. '.onPrerender', function()
                return utils.safe_call(addonName .. '.onPrerender', addon.onPrerender)
            end)
        end
    end
end

return PrerenderHandler