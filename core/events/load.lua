-- Load event handler class
local utils = require('utils')
local backend = require('backend.backend')
local colors = require('colors')
local database = require('ffi.sqlite3')

---@class LoadHandler
---@field captain table The captain instance this handler is bound to
local LoadHandler = {}
LoadHandler.__index = LoadHandler

---Create a new LoadHandler instance
---@param captain table The captain instance to bind to this handler
---@return LoadHandler handler The new LoadHandler instance
function LoadHandler.new(captain)
    local self = setmetatable({}, LoadHandler)
    self.captain = captain
    return self
end

---Handle the load event - initializes addons, registers keybinds, and reports performance
---Automatically loads all addons from the addons directory and sets up their configurations
function LoadHandler:handle()
    local load_start_time = os.clock()
    local addon_timings   = {}
    -- Register captain keybinds
    self.captain.keyBinds:registerCaptainKeybinds()

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
                self.captain.addons[parsedAddonName] = addon
                table.insert(addon_timings, { name = parsedAddonName, time = require_elapsed, phase = 'load' })
            else
                backend.errMsg('captain',
                    'Failed to load ' .. addonName .. ':\n ' .. addon)
            end
        end
    end

    local addon_names = utils.getTableKeys(self.captain.addons)
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

    -- Load settings and register keybinds, but don't initialize yet
    for addonName, subAddon in pairs(self.captain.addons) do
        subAddon.settings = backend.loadConfig(addonName, subAddon.defaultSettings)
    end

    -- Register addon keybinds
    self.captain.keyBinds:registerAddonKeybinds()

    -- Check if player is already loaded, if so initialize immediately
    if backend.player_name() ~= nil then
        for addonName, subAddon in pairs(self.captain.addons) do
            if type(subAddon.onInitialize) == 'function' then
                utils.withPerformanceMonitoring(addonName .. '.onInitialize', function()
                    return utils.safe_call(addonName .. '.onInitialize', subAddon.onInitialize,
                        string.format('captures/%s/', addonName))
                end)
            end
        end
        self.captain.needsInitialization = false
    else
        -- Mark that we need to initialize addons when client is ready
        self.captain.needsInitialization = true
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
end

return LoadHandler
