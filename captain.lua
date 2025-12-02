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
local version  = '1.6.1' -- x-release-please-version
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
backend                       = require('backend.backend')
utils                         = require('utils')
stats                         = require('stats')
---@type table<number, ColorData>
colors                        = require('colors')
local notifications           = require('notifications')
local Commands                = require('core.commands')
local KeyBinds                = require('core.keybinds')
local config                  = require('core.config')

-- Event handler classes
local LoadHandler             = require('core.events.load')
local UnloadHandler           = require('core.events.unload')
local ClientReadyHandler      = require('core.events.client_ready')
local PrerenderHandler        = require('core.events.prerender')
local ZoneChangeHandler       = require('core.events.zone_change')
local IncomingPacketHandler   = require('core.events.incoming_packet')
local OutgoingPacketHandler   = require('core.events.outgoing_packet')
local IncomingTextHandler     = require('core.events.incoming_text')

captain                       =
{
    addons              = {},
    isCapturing         = false,
    reloadSignal        = false,
    showConfig          = false,
    needsInitialization = false,
    captureName         = nil,
    settings            = require('settings_schema').get_defaults(), -- Load defaults, actual settings loaded in load handler
    notificationMgr     = nil,
    keyBinds            = KeyBinds.new(config.commandsMap),
    commands            = Commands.new(config.commandsMap),
}

captain.notificationMgr       = notifications.new(captain.settings.notifications or {})
captain.loadHandler           = LoadHandler.new(captain)
captain.unloadHandler         = UnloadHandler.new(captain)
captain.clientReadyHandler    = ClientReadyHandler.new(captain)
captain.prerenderHandler      = PrerenderHandler.new(captain)
captain.zoneChangeHandler     = ZoneChangeHandler.new(captain)
captain.incomingPacketHandler = IncomingPacketHandler.new(captain)
captain.outgoingPacketHandler = OutgoingPacketHandler.new(captain)
captain.incomingTextHandler   = IncomingTextHandler.new(captain)

-- Event registrations
backend.register_event_load(function() captain.loadHandler:handle() end)
backend.register_event_unload(function() captain.unloadHandler:handle() end)
captain.commands:register()
backend.register_event_incoming_packet(function(id, data, size)
    return captain.incomingPacketHandler:handle(id, data,
        size)
end)
backend.register_event_outgoing_packet(function(id, data, size)
    return captain.outgoingPacketHandler:handle(id, data,
        size)
end)
backend.register_event_incoming_text(function(mode, text) captain.incomingTextHandler:handle(mode, text) end)
backend.register_on_zone_change(function(zoneId) captain.zoneChangeHandler:handle(zoneId) end)
backend.register_on_client_ready(function(zoneId) captain.clientReadyHandler:handle(zoneId) end)
backend.register_event_prerender(function() captain.prerenderHandler:handle() end)
