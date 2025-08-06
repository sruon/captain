-- Unload event handler class
local utils           = require('utils')
local database        = require('ffi.sqlite3')

---@class UnloadHandler
---@field captain table The captain instance this handler is bound to
local UnloadHandler   = {}
UnloadHandler.__index = UnloadHandler

---Create a new UnloadHandler instance
---@param captain table The captain instance to bind to this handler
---@return UnloadHandler handler The new UnloadHandler instance
function UnloadHandler.new(captain)
    local self   = setmetatable({}, UnloadHandler)
    self.captain = captain
    return self
end

---Handle the unload event - stops capture, deregisters keybinds, notifies addons, and closes databases
---Performs cleanup operations when captain is being unloaded
function UnloadHandler:handle()
    self.captain.reloadSignal = true
    self.captain.commands:stopCapture()

    -- Deregister all keybinds
    self.captain.keyBinds:deregisterAll()

    -- Notify addons of unload
    for addonName, addon in pairs(self.captain.addons) do
        if type(addon.onUnload) == 'function' then
            utils.withPerformanceMonitoring(addonName .. '.onUnload', function()
                return utils.safe_call(addonName .. '.onUnload', addon.onUnload)
            end)
        end
    end

    -- Close all open SQLite databases
    database.close_all()
end

return UnloadHandler
