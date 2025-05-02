---@type BackendBase
local backend

--------------------------------
-- Load platform specific backends
--------------------------------
local isWindowerv4 = windower ~= nil
local isAshitav4 = ashita ~= nil and ashita.events ~= nil

if isWindowerv4 then
    backend = require('backend/backend_windower_v4')
elseif isAshitav4 ~= nil then
    backend = require('backend/backend_ashita_v4')
else
    print('Captain: COULD NOT FIND RELEVANT BACKEND!')
end

--------------------------------
-- Add additional _platform agnostic_ functions to supplement backends
--------------------------------
local files             = require('backend/files')
local packets           = require('libs/packets/parser')
local boxes             = require('libs/boxes')
local database          = require('libs/database')

--------------------------------
-- Handles opening, or creating, a file object. Returns it.
--------------------------------
backend.fileOpen        = function(path)
    local file = {
        path = backend.script_path() .. path,
        stream = files.new(path, true),
        locked = false,
        scheduled = false,
        buffer = ''
    }
    return file
end

--------------------------------
-- Handles writing to a file (gently)
--------------------------------
backend.fileAppend      = function(file, text)
    if not file.locked then
        file.buffer = file.buffer .. text
        if not file.scheduled then
            file.scheduled = true
            backend.schedule(function() backend.fileWrite(file) end, 0.5)
        end
    else
        backend.schedule(function() backend.fileAppend(file, text) end, 0.1)
    end
end

--------------------------------
-- Writes to a file and empties the buffer
--------------------------------
backend.fileWrite       = function(file)
    file.locked = true
    local to_write = file.buffer
    file.buffer = ''
    file.scheduled = false
    file.stream:append(to_write)
    file.locked = false
end

--------------------------------
-- Zero out a file and empties the buffer
--------------------------------
backend.fileClear       = function(file)
    file.stream:write('')
    file.buffer = ''
    file.scheduled = false
end

backend.databaseOpen    = function(path, opts)
    local file = backend.fileOpen(path)
    local db = database.new(file, opts)
    return db
end

--------------------------------
-- Box display
--------------------------------
backend.boxCreate       = function(boxTemplate, boxData, freeze)
    if not captain.boxMgr then
        captain.boxMgr = boxes.new(backend.getSetting('box', {}))
    end

    if captain.boxMgr then
        local segments = captain.boxMgr:renderSegments(boxTemplate, boxData)
        captain.boxMgr:create(segments, freeze)
    end
end

--------------------------------
-- Packets parsing
--------------------------------
backend.parsePacket     = function(dir, packet)
    return packets.parse(dir, packet)
end

--------------------------------
-- Captain specific settings
--------------------------------
backend.getSetting      = function(keyPath, default)
    if not captain.settings then
        captain.settings = backend.loadConfig('captain', require('data/defaults'))
    end

    local value = captain.settings
    for key in string.gmatch(keyPath, "([^%.]+)") do
        if type(value) ~= "table" then return nil end
        value = value[key]
        if value == nil then
            return nil or default
        end
    end

    return value
end

backend.setSetting      = function(keyPath, value)
    if not captain.settings then
        captain.settings = backend.loadConfig('captain', require('data/defaults'))
    end

    local keys = {}
    for key in string.gmatch(keyPath, "([^%.]+)") do
        table.insert(keys, key)
    end

    if #keys == 1 then
        captain.settings[keys[1]] = value

        backend.saveConfig('captain')
        return true
    end

    local current = captain.settings
    for i = 1, #keys - 1 do
        local key = keys[i]
        if type(current[key]) ~= "table" then
            current[key] = {}
        end
        current = current[key]
    end

    current[keys[#keys]] = value

    backend.saveConfig('captain')
    return true
end

return backend
