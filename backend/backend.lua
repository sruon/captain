---@class BackendBase
---@class Ashitav4Backend : BackendBase, BackendInterface
---@class WindowerBackend : BackendBase, BackendInterface

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
local files                = require('backend/files')
local packets              = require('libs/packets/parser')
local database             = require('libs/database')
local csv                  = require('libs/csv')
--------------------------------
-- Handles opening, or creating, a file object. Returns it.
--------------------------------
backend.fileOpen           = function(path)
    -- Replace spaces with underscores in the path
    path = path:gsub("%s+", "_"):gsub(":", "_"):gsub("%?", "qm"):gsub("'", "_"):gsub('"', "_")
    
    local file =
    {
        path = backend.script_path() .. path,
        stream = files.new(path, true),
        locked = false,
        scheduled = false,
        buffer = '',
    }

    file.append = function(self, text)
        backend.fileAppend(self, text)
    end

    file.flush = function(self)
        backend.fileWrite(self)
    end

    file.clear = function(self)
        backend.fileClear(self)
    end

    file.read = function(self)
        return backend.fileRead(self)
    end

    return file
end

--------------------------------
-- Handles writing to a file (gently)
--------------------------------
backend.fileAppend         = function(file, text)
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
backend.fileWrite          = function(file)
    file.locked = true
    local to_write = file.buffer
    file.buffer = ''
    file.scheduled = false
    file.stream:append(to_write)
    file.locked = false
end

--------------------------------
-- Reads the entire file and returns it
--------------------------------
backend.fileRead           = function(file)
    local data = file.stream:read('*all*')
    if data == nil then
        return ''
    end
    return data
end

--------------------------------
-- Zero out a file and empties the buffer
--------------------------------
backend.fileClear          = function(file)
    file.stream:write('')
    file.buffer = ''
    file.scheduled = false
end

backend.databaseOpen       = function(path, opts)
    local file = backend.fileOpen(path)
    local db = database.new(file, opts)
    db:load()
    return db
end

backend.csvOpen = function(path, columns)
    local file = backend.fileOpen(path)
    local csvFile = csv.new(file, columns)
    return csvFile
end

--------------------------------
-- Notification display
--------------------------------

backend.notificationCreate = function(emitter, title, dataFields, frozen)
    if not dataFields or type(dataFields) ~= 'table' then
        dataFields = {}
    end

    -- Temporary: Send notifications to chatlog, until we figure out a better mechanism
    if #dataFields > 0 then
        local fieldMsg = ''
        for i, field in ipairs(dataFields) do
            fieldMsg = fieldMsg .. string.format('%s: %s',
                colors[captain.settings.notifications.colors.key].chatColorCode .. field[1],
                colors[captain.settings.notifications.colors.value].chatColorCode .. tostring(field[2]))
            if i < #dataFields then
                fieldMsg = fieldMsg .. ', '
            end
        end
        backend.msg(emitter, colors[captain.settings.notifications.colors.title].chatColorCode .. title .. '\n' .. fieldMsg)
    end

    -- Pass directly to the notification manager
    captain.notificationMgr:create(
        {
            title = title,
            data = dataFields, -- Array of key-value pairs
        }, frozen or false)
end

--------------------------------
-- Packets parsing
--------------------------------
backend.parsePacket        = function(dir, packet)
    return packets.parse(dir, packet)
end

return backend
