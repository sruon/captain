-- Core command handling class for captain

---@class Commands
---@field commandsMap table[] Array of command configuration entries
local Commands   = {}
Commands.__index = Commands

---Create a new Commands instance
---@param commandsMap table[]|nil Array of command configuration entries
---@return Commands commands The new Commands instance
function Commands.new(commandsMap)
    local self       = setmetatable({}, Commands)
    self.commandsMap = commandsMap or {}
    return self
end

---Save a file with basic client information in the capture directory
---@param captureDir string The directory path where the manifest should be saved
local function recordManifest(captureDir)
    local addons = {}
    for addonName, _ in pairs(captain.addons) do
        table.insert(addons, addonName)
    end

    local manifest =
    {
        StartTime = os.time(),
        FFXI      =
        {
            Build    = backend.get_client_build_string(),
            ZoneIP   = utils.humanReadableIP(backend.get_server_ip()),
            IsRetail = backend.is_retail(),
        },
        Captain   =
        {
            Version = addon.version,
            Addons  = addons,
        },
    }

    local mFile    = backend.fileOpen(captureDir .. 'manifest.txt')
    mFile:append(utils.dump(manifest))
    mFile:flush()
end

---Notify addons of a capture starting and set up capture directory
---Creates timestamped capture directory and calls onCaptureStart for all addons
---@param args string[]|nil Optional command arguments array
function Commands:startCapture(args)
    if captain.isCapturing then
        backend.msg('captain', 'Already capturing')
        return
    end

    local date       = os.date('*t')
    local foldername = string.format('%d-%d-%d_%d_%d', date['year'], date['month'], date['day'], date['hour'],
        date['min'])

    -- Prepend args if provided
    if args and #args > 0 then
        local argsPrefix = table.concat(args, '_')
        foldername       = argsPrefix .. '_' .. foldername
    end

    captain.captureName = foldername

    local charname      = backend.player_name()
    if charname then
        local baseDir = string.format('captures/%s/%s/', foldername, charname)

        backend.msg('captain', 'Starting capture at ' .. baseDir)
        recordManifest(baseDir)
        captain.isCapturing = true
        for addonName, addon in pairs(captain.addons) do
            if type(addon.onCaptureStart) == 'function' then
                utils.withPerformanceMonitoring(addonName .. '.onCaptureStart', function()
                    return utils.safe_call(addonName .. '.onCaptureStart', addon.onCaptureStart,
                        string.format('%s%s/', baseDir, addonName))
                end)
            end
        end
    else
        backend.errMsg('captain', 'charname was nil, aborting capture')
    end
end

---Notify addons of a capture stopping
---Calls onCaptureStop for all addons and marks capturing as false
function Commands:stopCapture()
    if not captain.isCapturing then
        return
    end

    backend.msg('captain', 'Stopping capture')

    for addonName, addon in pairs(captain.addons) do
        if type(addon.onCaptureStop) == 'function' then
            utils.withPerformanceMonitoring(addonName .. '.onCaptureStop', function()
                return utils.safe_call(addonName .. '.onCaptureStop', addon.onCaptureStop)
            end)
        end
    end

    captain.isCapturing = false
    captain.captureName = nil
end

---Build argument string for command help display
---@param entry table Command entry with optional args and varargs
---@return string argString Formatted argument string
local function buildArgString(entry)
    local argParts = {}
    
    if entry.args then
        for _, arg in ipairs(entry.args) do
            if arg.optional then
                table.insert(argParts, '[' .. arg.name .. ']')
            else
                table.insert(argParts, '<' .. arg.name .. '>')
            end
        end
    end
    
    if entry.varargs then
        table.insert(argParts, '[...]')
    end
    
    return #argParts > 0 and (' ' .. table.concat(argParts, ' ')) or ''
end

---Display help information for all captain and addon commands
---Shows available commands, descriptions, and keybinds for captain and loaded addons
function Commands:showHelp()
    backend.msg('captain', colors[ColorEnum.Purple].chatColorCode .. 'Packet capture and analysis')
    for _, entry in pairs(self.commandsMap) do
        local argString = buildArgString(entry)
        backend.msg('captain',
            string.format('/%s %s%s %s [%s]', addon.command, colors[ColorEnum.Green].chatColorCode .. entry.cmd,
                argString, colors[ColorEnum.Purple].chatColorCode .. entry.desc,
                entry.keybind and utils.keyBindToString(entry.keybind) or 'No bind'))
    end

    for addonName, subAddon in pairs(captain.addons) do
        local lowerName = addonName:lower()
        if type(subAddon.onCommand) == 'function' then
            if type(subAddon.onHelp) == 'function' then
                local succ, addonCommands = utils.safe_call(addonName .. '.onHelp', subAddon.onHelp)
                if succ and addonCommands then
                    for _, entry in pairs(addonCommands) do
                        backend.msg('captain',
                            string.format('/%s %s %s %s [%s]', addon.command,
                                colors[ColorEnum.Seafoam].chatColorCode .. lowerName,
                                colors[ColorEnum.Green].chatColorCode .. entry.cmd,
                                colors[ColorEnum.Purple].chatColorCode .. entry.desc,
                                entry.keybind and utils.keyBindToString(entry.keybind) or 'No bind'))
                    end
                end
            else
                backend.msg('captain',
                    string.format('/%s %s %s', addon.command, colors[ColorEnum.Seafoam].chatColorCode .. lowerName,
                        colors[ColorEnum.Purple].chatColorCode .. 'Accepts undocumented commands'))
            end
        end
    end
end

---Handle incoming commands and route them to appropriate handlers
---@param args string[] Array of command arguments
function Commands:handleCommand(args)
    if #args == 0 then
        captain.showConfig = not captain.showConfig
    end

    for addonName, addon in pairs(captain.addons) do
        if args[1] == addonName:lower() then
            if type(addon.onCommand) == 'function' then
                utils.withPerformanceMonitoring(addonName .. '.onCommand', function()
                    local commandArgs = table.pack(table.unpack(args, 2))
                    return utils.safe_call(addonName .. '.onCommand', addon.onCommand, commandArgs)
                end)
            end
        end
    end

    if args[1] == 'help' then
        self:showHelp()
    elseif args[1] == 'start' then
        local startArgs = { table.unpack(args, 2) }
        self:startCapture(startArgs)
    elseif args[1] == 'stop' then
        self:stopCapture()
    elseif args[1] == 'toggle' then
        if captain.isCapturing then
            self:stopCapture()
        else
            self:startCapture()
        end
    elseif args[1] == 'split' then
        self:stopCapture()
        self:startCapture()
    elseif args[1] == 'reload' then
        backend.reload()
    end
end

---Register the command handler with the backend
---Sets up the main command dispatcher for captain
function Commands:register()
    backend.register_command(function(args)
        self:handleCommand(args)
    end)
end

return Commands
