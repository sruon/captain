---@class BackendBase
---@class Ashitav4Backend : BackendBase, BackendInterface

local backend

--------------------------------
-- Load platform specific backends
--------------------------------
local isAshitav4 = ashita ~= nil and ashita.events ~= nil

if isAshitav4 ~= nil then
    backend = require('backend.backend_ashita_v4')
else
    print('Captain: COULD NOT FIND RELEVANT BACKEND!')
end

--------------------------------
-- Add additional _platform agnostic_ functions to supplement backends
--------------------------------
local packets              = require('packets.parser')
local serpent              = require('serpent')
local database             = require('ffi.sqlite3')
local csv                  = require('csv')
--------------------------------
-- Handles opening, or creating, a file object. Returns it.
--------------------------------
backend.fileOpen           = function(path)
    -- Replace spaces with underscores in the path
    path        = path:gsub('%s+', '_'):gsub(':', '_'):gsub('%?', 'qm'):gsub("'", '_'):gsub('"', '_')

    local file  =
    {
        path      = path, -- Store relative path
        full_path = backend.script_path() .. path,
        locked    = false,
        scheduled = false,
        buffer    = '',
    }

    file.append = function(self, text)
        backend.fileAppend(self, text)
    end

    file.flush  = function(self)
        backend.fileWrite(self)
    end

    file.clear  = function(self)
        backend.fileClear(self)
    end

    file.read   = function(self)
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
    file.locked    = true
    local to_write = file.buffer
    file.buffer    = ''
    file.scheduled = false

    if to_write and to_write ~= '' then
        local success = backend.append_file(file.path, to_write)
        if not success then
            print('[backend] Failed to write to file: ' .. file.path)
        end
    end

    file.locked = false
end

--------------------------------
-- Reads the entire file and returns it
--------------------------------
backend.fileRead           = function(file)
    local data = backend.read_file(file.path)
    if data == nil then
        print('[backend] Failed to read file: ' .. file.path)
        return ''
    end
    return data
end

--------------------------------
-- Zero out a file and empties the buffer
--------------------------------
backend.fileClear          = function(file)
    local success = backend.write_file(file.path, '')
    if not success then
        print('[backend] Failed to clear file: ' .. file.path)
    end
    file.buffer    = ''
    file.scheduled = false
end

backend.databaseOpen       = function(path, opts)
    -- For database, we need the full path, not relative
    local full_path = backend.script_path() .. path
    local db        = database.new({ path = full_path }, opts)
    return db
end

backend.csvOpen            = function(path, columns)
    local file    = backend.fileOpen(path)
    local csvFile = csv.new(file, columns)
    return csvFile
end

--------------------------------
-- Notification display
--------------------------------

backend.notificationCreate = function(emitter, title, dataFields)
    if not dataFields or type(dataFields) ~= 'table' then
        dataFields = {}
    end

    -- Temporary: Send notifications to chatlog, until we figure out a better mechanism
    if #dataFields > 0 then
        local fieldMsg = ''
        for i, field in ipairs(dataFields) do
            local value_str
            if type(field[2]) == 'table' then
                value_str = serpent.line(field[2], { comment = false, sortkeys = true })
            else
                value_str = tostring(field[2])
            end
            
            fieldMsg = fieldMsg .. string.format('%s: %s',
                colors[captain.settings.notifications.colors.key].chatColorCode .. field[1],
                colors[captain.settings.notifications.colors.value].chatColorCode .. value_str)
            if i < #dataFields then
                fieldMsg = fieldMsg .. ', '
            end
        end
        backend.msg(emitter,
            colors[captain.settings.notifications.colors.title].chatColorCode .. title .. '\n' .. fieldMsg)
    end

    -- Pass directly to the notification manager
    captain.notificationMgr:create(
        {
            title = title,
            data  = dataFields, -- Array of key-value pairs
        })
end

--------------------------------
-- Packets parsing
--------------------------------
backend.parsePacket        = function(dir, packet)
    return packets.parse(dir, packet)
end

return backend
