---@diagnostic disable: undefined-global
---@diagnostic disable: lowercase-global

-- Add deps path with highest priority for require()
if addon and addon.path then
    package.path  = addon.path .. '/deps/?.lua;' ..
      addon.path .. '/deps/?/init.lua;' ..
      addon.path .. '/libs/?.lua;' ..
      addon.path .. '/libs/?/init.lua;' ..
      package.path
    package.cpath = addon.path .. '/deps/?.dll;' ..
      package.cpath
end

-- Addon info
local name     = 'captain'
local author   = 'zach2good, sruon'
local version  = '0.1' -- x-release-please-version
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
---@type Ashitav4Backend
backend                 = require('backend.backend')
utils                   = require('utils')
stats                   = require('stats')
---@type table<number, ColorData>
colors                  = require('colors')
local notifications     = require('notifications')
local database          = require('ffi.sqlite3')

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
    { cmd = '',       desc = 'Open configuration menu' },
    {
        cmd     = 'start',
        desc    = 'Start capturing',
        keybind =
        {
            key  = 'c',
            down = true,
            ctrl = true,
            alt  = true,
        },
    },
    {
        cmd     = 'stop',
        desc    = 'Stop capturing',
        keybind =
        {
            key  = 'v',
            down = true,
            ctrl = true,
            alt  = true,
        },
    },
    { cmd = 'toggle', desc = 'Start/stop capturing',         keybind = { key = 'x', down = true, ctrl = true } },
    { cmd = 'split',  desc = 'Stop and start a new capture', keybind = nil },
    { cmd = 'reload', desc = 'Reload captain',               keybind = { key = 'z', down = true, ctrl = true } },
}

---@param name string
---@param func function
---@param ... any
---@return boolean, any
local function safe_call(name, func, ...)
    ---@diagnostic disable-next-line: deprecated
    local unpack = unpack or table.unpack
    local args   = table.pack(...)
    local function handler(err)
        return debug.traceback(string.format('[%s] %s', name, tostring(err)), 2)
    end

    local ok, result = xpcall(function()
        return func(unpack(args, 1, args.n))
    end, handler)

    if not ok then
        backend.errMsg('captain', result)
    end

    return ok, result
end

-- Notify addons of a capture starting
local function StartCapture()
    if captain.isCapturing then
        backend.msg('captain', 'Already capturing')
        return
    end

    local date       = os.date('*t')
    local foldername = string.format('%d-%d-%d_%d_%d', date['year'], date['month'], date['day'], date['hour'],
        date['min'])
    local charname   = backend.player_name()
    if charname then
        local baseDir = string.format('captures/%s/%s/', foldername, charname)

        backend.msg('captain', 'Starting capture at ' .. baseDir)
        captain.isCapturing = true
        for addonName, addon in pairs(captain.addons) do
            if type(addon.onCaptureStart) == 'function' then
                utils.withPerformanceMonitoring(addonName .. '.onCaptureStart', function()
                    return safe_call(addonName .. '.onCaptureStart', addon.onCaptureStart,
                        string.format('%s%s/', baseDir, addonName))
                end)
            end
        end
    else
        backend.errMsg('captain', 'charname was nil, aborting capture')
    end
end

-- Notify addons of a capture stopping
local function StopCapture()
    if not captain.isCapturing then
        return
    end

    backend.msg('captain', 'Stopping capture')

    for addonName, addon in pairs(captain.addons) do
        if type(addon.onCaptureStop) == 'function' then
            utils.withPerformanceMonitoring(addonName .. '.onCaptureStop', function()
                return safe_call(addonName .. '.onCaptureStop', addon.onCaptureStop)
            end)
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
    local load_start_time = os.clock()
    local addon_timings   = {}
    -- Register captain keybinds
    for _, entry in pairs(commandsMap) do
        if entry.keybind then
            backend.registerKeyBind(entry.keybind, string.format('%s %s', addon.command, entry.cmd))
        end
    end

    -- Automagically load addons in the addons directory
    local fileList = backend.list_files('addons')

    for _, fileName in pairs(fileList) do
        local addonName, modulePath

        local normalizedFileName = fileName:gsub('\\', '/')

        -- addons/actionview.lua
        local rootAddon          = normalizedFileName:match('^([^/]+)%.lua$')
        if rootAddon then
            addonName  = rootAddon
            modulePath = string.format('addons/%s', rootAddon)
        else
            -- addons/actionview/actionview.lua
            local dirName, dirFile = normalizedFileName:match('^([^/]+)/([^/]+)%.lua$')
            if dirName and dirName == dirFile then
                addonName  = dirName
                modulePath = string.format('addons/%s/%s', dirName, dirFile)
            end
        end

        if addonName then
            local requirePath                     = modulePath:gsub('[/\\]', '.')

            local success, addon, require_elapsed = utils.withPerformanceMonitoring(addonName .. ' require', function()
                return pcall(require, requirePath)
            end, 0.01)

            if success and addon and type(addon) == 'table' then
                local parsedAddonName           = addon.name or addonName
                captain.addons[parsedAddonName] = addon
                table.insert(addon_timings, { name = parsedAddonName, time = require_elapsed, phase = 'load' })
            else
                backend.errMsg('captain',
                    'Failed to load ' .. addonName .. ':\n ' .. addon)
            end
        end
    end

    local addon_names = utils.getTableKeys(captain.addons)
    if #addon_names > 0 then
        backend.msg('captain', colors[ColorEnum.Purple].chatColorCode .. 'Enabled addons:')
        for i = 1, #addon_names, 6 do
            local chunk = {}
            for j = i, math.min(i + 5, #addon_names) do
                table.insert(chunk, addon_names[j])
            end
            backend.msg('captain', '  ' .. colors[ColorEnum.Seafoam].chatColorCode .. table.concat(chunk, ', '))
        end
    else
        backend.msg('captain', colors[ColorEnum.Purple].chatColorCode .. 'No addons enabled')
    end

    -- Force close any stale SQLite connections from previous crashes
    database.force_close_all_connections()

    for addonName, subAddon in pairs(captain.addons) do
        subAddon.settings = backend.loadConfig(addonName, subAddon.defaultSettings)

        -- Initialize addons
        if type(subAddon.onInitialize) == 'function' then
            local start_time = os.clock()
            safe_call(addonName .. '.onInitialize', subAddon.onInitialize, string.format('captures/%s/', addonName))
            local elapsed = os.clock() - start_time
            if elapsed > 0.1 then
                backend.warnMsg('captain', string.format('%s onInitialize took %.3fs', addonName, elapsed))
            end
            table.insert(addon_timings, { name = addonName, time = elapsed, phase = 'init' })
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

    -- Report total time and slowest operations
    local total_time = os.clock() - load_start_time

    -- Sort by time descending
    table.sort(addon_timings, function(a, b)
        return (a.time or 0) > (b.time or 0)
    end)

    local slow_ops = {}
    for i = 1, math.min(3, #addon_timings) do
        if (addon_timings[i].time or 0) > 0.01 then -- Only show if >10ms
            table.insert(slow_ops, string.format('%s %s (%.3fs)',
                addon_timings[i].name, addon_timings[i].phase, addon_timings[i].time or 0))
        end
    end

    local msg = string.format('Total load time: %.3fs', total_time)
    if #slow_ops > 0 then
        msg = msg .. ' - Slowest: ' .. table.concat(slow_ops, ', ')
    end
    backend.warnMsg('captain', msg)
end)

-- Unload event, removes keybinds
backend.register_event_unload(function()
    captain.reloadSignal = true
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
            utils.withPerformanceMonitoring(addonName .. '.onUnload', function()
                return safe_call(addonName .. '.onUnload', addon.onUnload)
            end)
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

    -- Close all open SQLite databases
    database.close_all()
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
                utils.withPerformanceMonitoring(addonName .. '.onCommand', function()
                    local commandArgs = table.pack(table.unpack(args, 2))
                    return safe_call(addonName .. '.onCommand', addon.onCommand, commandArgs)
                end)
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
                local ok, result = utils.withPerformanceMonitoring(addonName .. '.onIncomingPacket', function()
                    return safe_call(addonName .. '.onIncomingPacket', addon.onIncomingPacket, id, data, size)
                end)
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
                local ok, result = utils.withPerformanceMonitoring(addonName .. '.onOutgoingPacket', function()
                    return safe_call(addonName .. '.onOutgoingPacket', addon.onOutgoingPacket, id, data, size)
                end)
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
            utils.withPerformanceMonitoring(addonName .. '.onIncomingText', function()
                return safe_call(addonName .. '.onIncomingText', addon.onIncomingText, mode, text)
            end)
        end
    end
end)

-- Notify addons of zone change
backend.register_on_zone_change(function(zoneId)
    for addonName, addon in pairs(captain.addons) do
        if type(addon.onZoneChange) == 'function' then
            utils.withPerformanceMonitoring(addonName .. '.onZoneChange', function()
                return safe_call(addonName .. '.onZoneChange', addon.onZoneChange, zoneId)
            end)
        end
    end
end)

backend.register_on_client_ready(function(zoneId)
    for addonName, addon in pairs(captain.addons) do
        if type(addon.onClientReady) == 'function' then
            utils.withPerformanceMonitoring(addonName .. '.onClientReady', function()
                return safe_call(addonName .. '.onClientReady', addon.onClientReady, zoneId)
            end)
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
            utils.withPerformanceMonitoring(addonName .. '.onPrerender', function()
                return safe_call(addonName .. '.onPrerender', addon.onPrerender)
            end)
        end
    end
end)
