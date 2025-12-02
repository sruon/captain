-- Client ready event handler class
local utils = require('utils')

---@class ClientReadyHandler
---@field captain table The captain instance this handler is bound to
local ClientReadyHandler = {}
ClientReadyHandler.__index = ClientReadyHandler

---Create a new ClientReadyHandler instance
---@param captain table The captain instance to bind to this handler
---@return ClientReadyHandler handler The new ClientReadyHandler instance
function ClientReadyHandler.new(captain)
    local self = setmetatable({}, ClientReadyHandler)
    self.captain = captain
    return self
end

---Handle the client ready event - initializes addons when client is ready and notifies addons
---@param zoneId number The zone ID the client is ready in
function ClientReadyHandler:handle(zoneId)
    -- If we deferred initialization from load event, do it now
    if self.captain.needsInitialization then
        self.captain.needsInitialization = false

        -- Run the full load process now that we're logged in
        self.captain.loadHandler:handle()
    end

    -- Call normal client ready handlers
    for addonName, addon in pairs(self.captain.addons) do
        if type(addon.onClientReady) == 'function' then
            utils.withPerformanceMonitoring(addonName .. '.onClientReady', function()
                return utils.safe_call(addonName .. '.onClientReady', addon.onClientReady, zoneId)
            end)
        end
    end
end

return ClientReadyHandler