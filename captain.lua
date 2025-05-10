---@diagnostic disable: undefined-global
---@diagnostic disable: lowercase-global

-- Addon info
local name     = 'captain'
local author   = 'zach2good'
local version  = '0.1'
local commands = { 'captain', 'cap' }

if addon then
    addon.name     = name
    addon.author   = author
    addon.version  = version
    addon.command  = commands[2]
    addon.commands = commands
elseif _addon then
    _addon.name    = name
    _addon.author  = author
    _addon.version = version
    _addon.command = commands[1]
    addon          = _addon
end

-- Globals
---@type Ashitav4Backend|WindowerBackend
backend                 = require('backend/backend')
utils                   = require('utils')
stats                   = require('stats')
---@type table<number, ColorData>
colors                  = require('libs/colors/colors')
local notifications     = require('libs/notifications')

captain                 =
{
    addons          = {},
    isCapturing     = false,
    reloadSignal    = false,
    showConfig      = false,
    settings        = backend.loadConfig('captain', require('data/settings_schema').get_defaults()),
    notificationMgr = nil,
}

captain.notificationMgr = notifications.new(captain.settings.notifications or {})

---@type Command[]
local commandsMap       =
{
    { cmd = '',       desc = 'Open configuration menu (Ashita only)' },
    {
        cmd = 'start',
        desc = 'Start capturing',
        keybind =
        {
            key = 'c',
            down = true,
            ctrl = true,
            alt = true,
        },
    },
    {
        cmd = 'stop',
        desc = 'Stop capturing',
        keybind =
        {
            key = 'v',
            down = true,
            ctrl = true,
            alt = true,
        },
    },
    { cmd = 'toggle', desc = 'Start/stop capturing',                 keybind = { key = 'x', down = true, ctrl = true } },
    { cmd = 'split',  desc = 'Stop and start a new capture',         keybind = nil },
    { cmd = 'reload', desc = 'Reload captain',                       keybind = { key = 'z', down = true, ctrl = true } },
}

---@param name string
---@param func function
---@param ... any
---@return boolean, any
local function safe_call(name, func, ...)
    ---@diagnostic disable-next-line: deprecated
    local unpack = unpack or table.unpack
    local args = table.pack(...)
    local function handler(err)
        return debug.traceback(string.format('[%s] %s', name, tostring(err)), 2)
    end

    local ok, result = xpcall(function()
        return func(unpack(args, 1, args.n))
    end, handler)

    if not ok then
        backend.msg('captain', result)
    end

    return ok, result
end

-- Notify addons of a capture starting
local function StartCapture()
    if captain.isCapturing then
        backend.msg('captain', 'already capturing')
        return
    end

    local date = os.date('*t')
    local foldername = string.format('%d-%d-%d_%d_%d', date['year'], date['month'], date['day'], date['hour'],
        date['min'])
    local charname = backend.player_name()
    if charname then
        local baseDir = string.format('captures/%s/%s/', foldername, charname)

        backend.msg('captain', 'starting capture at ' .. baseDir)
        captain.isCapturing = true
        for addonName, addon in pairs(captain.addons) do
            if type(addon.onCaptureStart) == 'function' then
                safe_call(addonName .. '.onCaptureStart', addon.onCaptureStart,
                    string.format('%s%s/', baseDir, addonName))
            end
        end
    else
        backend.msg('captain', 'charname was nil, aborting capture')
    end
end

-- Notify addons of a capture stopping
local function StopCapture()
    if not captain.isCapturing then
        return
    end

    backend.msg('captain', 'stopping capture')

    for addonName, addon in pairs(captain.addons) do
        if type(addon.onCaptureStop) == 'function' then
            safe_call(addonName .. '.onCaptureStop', addon.onCaptureStop)
        end
    end

    captain.isCapturing = false
end

local function HelpCommand()
    backend.msg('captain', colors[ColorEnum.Purple].chatColorCode .. 'Packet capture and analysis')
    for _, entry in pairs(commandsMap) do
        backend.msg('captain',
            string.format('/%s %s %s [%s]', addon.command, colors[ColorEnum.Green].chatColorCode .. entry.cmd,
                colors[ColorEnum.Purple].chatColorCode .. entry.desc,
                entry.keybind and utils.keyBindToString(entry.keybind) or 'No bind'))
    end

    for addonName, subAddon in pairs(captain.addons) do
        local lowerName = addonName:lower()
        if type(subAddon.onCommand) == 'function' then
            if type(subAddon.onHelp) == 'function' then
                local succ, addonCommands = safe_call(addonName .. '.onHelp', subAddon.onHelp)
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

-- Hooks
backend.register_event_load(function()
    -- Register captain keybinds
    for _, entry in pairs(commandsMap) do
        if entry.keybind then
            backend.registerKeyBind(entry.keybind, string.format('%s %s', addon.command, entry.cmd))
        end
    end

    -- Automagically load addons in the addons directory
    for _, fileName in pairs(backend.list_files('addons')) do
        local addonName, modulePath

        local normalizedFileName = fileName:gsub('\\', '/')

        -- addons/actionview.lua
        local rootAddon = normalizedFileName:match('^([^/]+)%.lua$')
        if rootAddon then
            addonName = rootAddon
            modulePath = string.format('addons/%s', rootAddon)
        else
            -- addons/actionview/actionview.lua
            local dirName, dirFile = normalizedFileName:match('^([^/]+)/([^/]+)%.lua$')
            if dirName and dirName == dirFile then
                addonName = dirName
                modulePath = string.format('addons/%s/%s', dirName, dirFile)
            end
        end

        if addonName then
            local requirePath = modulePath:gsub('[/\\]', '.')
            local addon = require(requirePath)

            if addon and type(addon) == 'table' then
                local parsedAddonName = addon.name or addonName
                captain.addons[parsedAddonName] = addon
            else
                backend.msg('captain',
                    colors[ColorEnum.Purple].chatColorCode ..
                    'Failed to load addon: ' .. colors[ColorEnum.Seafoam].chatColorCode .. addonName)
            end
        end
    end

    backend.msg('captain',
        colors[ColorEnum.Purple].chatColorCode ..
        'Enabled addons: ' ..
        colors[ColorEnum.Seafoam].chatColorCode .. table.concat(utils.getTableKeys(captain.addons), ', '))

    for addonName, subAddon in pairs(captain.addons) do
        subAddon.settings = backend.loadConfig(addonName, subAddon.defaultSettings)

        -- Initialize addons
        if type(subAddon.onInitialize) == 'function' then
            safe_call(addonName .. '.onInitialize', subAddon.onInitialize, string.format('captures/%s/', addonName))
        end

        -- Check addon is publishing commands with optional keybinds
        if type(subAddon.onHelp) == 'function' then
            local succ, addonCommands = safe_call(addonName .. '.onHelp', subAddon.onHelp)
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
end)

-- Unload event, removes keybinds
backend.register_event_unload(function()
    StopCapture()

    -- captain keybinds
    for _, entry in pairs(commandsMap) do
        if entry.keybind then
            backend.deregisterKeyBind(entry.keybind)
        end
    end

    -- Remove addons keybinds
    for addonName, addon in pairs(captain.addons) do
        -- Notify addons of unload
        if type(addon.onUnload) == 'function' then
            safe_call(addonName .. '.onUnload', addon.onUnload)
        end

        if type(addon.onHelp) == 'function' then
            local succ, addonCommands = safe_call(addonName .. '.onHelp', addon.onHelp)
            if succ and addonCommands then
                for _, entry in pairs(addonCommands) do
                    if entry.keybind then
                        backend.deregisterKeyBind(entry.keybind)
                    end
                end
            end
        end
    end
end)

-- Register commands
-- Handle addon specific commands
backend.register_command(function(args)
    if #args == 0 then
        captain.showConfig = not captain.showConfig
    end

    for addonName, addon in pairs(captain.addons) do
        if args[1] == addonName:lower() then
            if type(addon.onCommand) == 'function' then
                local commandArgs = table.pack(table.unpack(args, 2))
                safe_call(addonName .. '.onCommand', addon.onCommand, commandArgs)
            end
        end
    end

    if args[1] == 'help' then
        HelpCommand()
    elseif args[1] == 'start' then
        StartCapture()
    elseif args[1] == 'stop' then
        StopCapture()
    elseif args[1] == 'toggle' then
        if captain.isCapturing then
            StopCapture()
        else
            StartCapture()
        end
    elseif args[1] == 'split' then
        StopCapture()
        StartCapture()
    elseif args[1] == 'reload' then
        backend.reload()
    end
end)

-- Notify addons of incoming packets, if their filters accept it
backend.register_event_incoming_packet(function(id, data, size)
    local shouldBlock = false
    for addonName, addon in pairs(captain.addons) do
        if
          (addon.filters and addon.filters.incoming and addon.filters.incoming[id]) or
          (addon.filters and addon.filters.incoming and addon.filters.incoming[0x255])
        then
            if type(addon.onIncomingPacket) == 'function' then
                _, result = safe_call(addonName .. '.onIncomingPacket', addon.onIncomingPacket, id, data, size)
                if result == true then
                    shouldBlock = true
                end
            end
        end
    end

    return shouldBlock
end)

-- Notify addons of outgoing packets, if their filters accept it
backend.register_event_outgoing_packet(function(id, data, size)
    local shouldBlock = false
    for addonName, addon in pairs(captain.addons) do
        if
          (addon.filters and addon.filters.outgoing and addon.filters.outgoing[id]) or
          (addon.filters and addon.filters.outgoing and addon.filters.outgoing[0x255])
        then
            if type(addon.onOutgoingPacket) == 'function' then
                _, result = safe_call(addonName .. '.onOutgoingPacket', addon.onOutgoingPacket, id, data, size)
                if result == true then
                    shouldBlock = true
                end
            end
        end
    end

    return shouldBlock
end)

-- Notify addons of chatlog text
backend.register_event_incoming_text(function(mode, text)
    for addonName, addon in pairs(captain.addons) do
        if type(addon.onIncomingText) == 'function' then
            safe_call(addonName .. '.onIncomingText', addon.onIncomingText, mode, text)
        end
    end
end)

-- Notify addons of zone change
backend.register_on_zone_change(function(zoneId)
    for addonName, addon in pairs(captain.addons) do
        if type(addon.onZoneChange) == 'function' then
            safe_call(addonName .. '.onZoneChange', addon.onZoneChange, zoneId)
        end
    end
end)

-- Render notifications, text boxes, if any. Notify addons of render event
backend.register_event_prerender(function()
    -- User requested config menu
    if captain.showConfig then
        backend.configMenu()
    end

    -- Render notifications
    captain.notificationMgr:render()

    -- Notify addons of render event
    for addonName, addon in pairs(captain.addons) do
        if type(addon.onPrerender) == 'function' then
            safe_call(addonName .. '.onPrerender', addon.onPrerender)
        end
    end
end)
