-- Core keybind handling class for captain

---@class KeyBinds
---@field commandsMap table[] Array of command configuration entries
local KeyBinds = {}
KeyBinds.__index = KeyBinds

---Create a new KeyBinds instance
---@param commandsMap table[]|nil Array of command configuration entries
---@return KeyBinds keybinds The new KeyBinds instance
function KeyBinds.new(commandsMap)
    local self = setmetatable({}, KeyBinds)
    self.commandsMap = commandsMap or {}
    return self
end

---Register captain core keybinds from the commands map
---Registers keybinds for all captain core commands that have keybind configurations
function KeyBinds:registerCaptainKeybinds()
    for _, entry in pairs(self.commandsMap) do
        if entry.keybind then
            backend.registerKeyBind(entry.keybind, string.format('%s %s', addon.command, entry.cmd))
        end
    end
end

---Register addon keybinds by querying each addon's onHelp function
---Calls onHelp for each addon to get their command definitions and registers keybinds
function KeyBinds:registerAddonKeybinds()
    for addonName, subAddon in pairs(captain.addons) do
        -- Check addon is publishing commands with optional keybinds
        if type(subAddon.onHelp) == 'function' then
            local succ, addonCommands = utils.safe_call(addonName .. '.onHelp', subAddon.onHelp)
            if succ and addonCommands then
                for _, entry in pairs(addonCommands) do
                    if entry.keybind then
                        backend.registerKeyBind(entry.keybind,
                            string.format('%s %s %s', addon.command, addonName:lower(), entry.cmd))
                    end
                end
            end
        end
    end
end

---Deregister captain core keybinds
---Removes all captain core keybinds that were previously registered
function KeyBinds:deregisterCaptainKeybinds()
    for _, entry in pairs(self.commandsMap) do
        if entry.keybind then
            backend.deregisterKeyBind(entry.keybind)
        end
    end
end

---Deregister addon keybinds
---Removes all addon keybinds that were previously registered
function KeyBinds:deregisterAddonKeybinds()
    for addonName, addon in pairs(captain.addons) do
        if type(addon.onHelp) == 'function' then
            local succ, addonCommands = utils.safe_call(addonName .. '.onHelp', addon.onHelp)
            if succ and addonCommands then
                for _, entry in pairs(addonCommands) do
                    if entry.keybind then
                        backend.deregisterKeyBind(entry.keybind)
                    end
                end
            end
        end
    end
end

---Register all keybinds (captain + addons)
---Convenience method to register both captain and addon keybinds
function KeyBinds:registerAll()
    self:registerCaptainKeybinds()
    self:registerAddonKeybinds()
end

---Deregister all keybinds (captain + addons)
---Convenience method to remove both captain and addon keybinds
function KeyBinds:deregisterAll()
    self:deregisterCaptainKeybinds()
    self:deregisterAddonKeybinds()
end

return KeyBinds