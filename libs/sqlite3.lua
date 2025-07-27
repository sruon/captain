-- SQLite3 Database wrapper using luasql-sqlite3
-- FFI version is commented out below for easy reverting

local luasql = require('luasql.sqlite3')
local json = require('json')

-- Global registry to track all open databases
local _open_databases = {}
setmetatable(_open_databases, { __mode = 'v' }) -- weak references

-- Track databases by filename for force-closing
local _databases_by_file = {}

-- SQLite environment
local env = luasql.sqlite3()

---@class Database
---@field db userdata
---@field ignore_updates table
---@field max_history number
---@field add_or_update fun(self, id: any, fragment: table): number
---@field get fun(self, id: any): table | nil
---@field count fun(self): number
---@field find_by fun(self, path: string, expected: any): table | nil, number | nil
---@field close fun(self)
local Database = {}
Database.__index = Database

Database.RESULT_NEW = 1
Database.RESULT_UPDATED = 2
Database.RESULT_NOOP = 3

-- SQLite wrapper methods using luasql
local function sqlite_exec(db, sql)
    local cursor, err = db:execute(sql)
    if not cursor then
        error('SQL execution failed: ' .. (err or 'Unknown error'))
    end
    if cursor ~= 0 then
        cursor:close()
    end
end

local function sqlite_prepare_and_execute(db, sql, params)
    local cursor, err = db:execute(sql, table.unpack(params or {}))
    if not cursor then
        error('SQL execution failed: ' .. (err or 'Unknown error'))
    end
    return cursor
end

function Database.new(file, opts)
    local filename = file.path or tostring(file)

    -- Require schema to be provided
    if not opts or not opts.schema then
        error('Database schema is required. Provide opts.schema with an example object.')
    end

    -- Create directory structure if needed
    local dir = filename:match('(.+)[/\\][^/\\]+$')
    if dir then
        backend.create_dir(dir)
    end

    -- Force close any existing connections to this file
    Database._force_close_file(filename)

    -- Open database
    local db, err = env:connect(filename)
    if not db then
        error('Failed to open database: ' .. (err or 'Unknown error'))
    end

    local self = setmetatable(
        {
            db = db,
            ignore_updates = opts and opts.ignore_updates or {},
            max_history = opts and opts.max_history or nil,
            _transaction_active = false,
            _pending_operations = 0,
            _schema_columns = {},
            _filename = filename,
        }, Database)

    -- Build schema from example object
    self:_build_schema_from_example(opts.schema)

    -- Initialize database schema
    self:_init_schema()

    -- Performance optimizations
    self:_setup_performance()

    -- Register in global database list
    table.insert(_open_databases, self)

    -- Track by filename for force-closing
    if not _databases_by_file[filename] then
        _databases_by_file[filename] = {}
    end
    table.insert(_databases_by_file[filename], self)

    return self
end

function Database:_build_schema_from_example(example)
    -- Flatten the example object to get all fields
    local flat_data = self:_flatten_data(example)

    -- Build schema columns from flattened data
    self._schema_columns['id'] = 'TEXT PRIMARY KEY'
    self._schema_columns['version'] = 'INTEGER DEFAULT 0'
    self._schema_columns['created_at'] = "INTEGER DEFAULT (strftime('%s', 'now'))"
    self._schema_columns['updated_at'] = "INTEGER DEFAULT (strftime('%s', 'now'))"

    for key, value in pairs(flat_data) do
        self._schema_columns[key] = self:_infer_sql_type(value)
    end
end

function Database:_init_schema()
    -- Build CREATE TABLE statement with columns in specific order
    local columns = {}

    -- Add system columns first in desired order
    local system_columns = { 'id', 'version', 'created_at', 'updated_at' }
    for _, col_name in ipairs(system_columns) do
        if self._schema_columns[col_name] then
            table.insert(columns, '"' .. col_name .. '" ' .. self._schema_columns[col_name])
        end
    end

    -- Add data columns (alphabetically sorted for consistency)
    local data_columns = {}
    for name, definition in pairs(self._schema_columns) do
        local is_system = false
        for _, sys_col in ipairs(system_columns) do
            if name == sys_col then
                is_system = true
                break
            end
        end
        if not is_system then
            table.insert(data_columns, { name, definition })
        end
    end

    -- Sort data columns alphabetically
    table.sort(data_columns, function(a, b) return a[1] < b[1] end)

    -- Add sorted data columns
    for _, col_data in ipairs(data_columns) do
        table.insert(columns, '"' .. col_data[1] .. '" ' .. col_data[2])
    end

    local create_sql = string.format([[
        CREATE TABLE IF NOT EXISTS entries (
            %s
        )
    ]], table.concat(columns, ',\n            '))

    sqlite_exec(self.db, create_sql)

    sqlite_exec(self.db, [[
        CREATE TABLE IF NOT EXISTS history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entry_id TEXT,
            time INTEGER,
            delta JSON,
            FOREIGN KEY (entry_id) REFERENCES entries(id) ON DELETE CASCADE
        )
    ]])

    sqlite_exec(self.db, [[
        CREATE INDEX IF NOT EXISTS idx_history_entry_id ON history(entry_id)
    ]])
end

function Database:_setup_performance()
    -- Disable journaling for maximum write speed
    sqlite_exec(self.db, 'PRAGMA journal_mode=OFF')

    -- No synchronization - maximum speed, no durability guarantees
    sqlite_exec(self.db, 'PRAGMA synchronous=OFF')

    -- Minimal cache (512KB per database)
    sqlite_exec(self.db, 'PRAGMA cache_size=128')

    -- Disable memory-mapped I/O
    sqlite_exec(self.db, 'PRAGMA mmap_size=0')

    -- Use disk for temp storage
    sqlite_exec(self.db, 'PRAGMA temp_store=FILE')

    -- Disable foreign key constraints for faster writes
    sqlite_exec(self.db, 'PRAGMA foreign_keys=OFF')

    -- Disable automatic indexing
    sqlite_exec(self.db, 'PRAGMA automatic_index=OFF')
end

function Database:_infer_sql_type(value)
    local t = type(value)
    if t == 'number' then
        return math.floor(value) == value and 'INTEGER' or 'REAL'
    elseif t == 'boolean' then
        return 'INTEGER' -- Store as 0/1
    else
        return 'TEXT'
    end
end

function Database:_flatten_data(data, prefix)
    prefix = prefix or ''
    local result = {}

    for key, value in pairs(data) do
        local full_key = prefix == '' and key or (prefix .. '_' .. key)

        if type(value) == 'table' then
            -- Flatten nested tables with underscore separator
            local nested = self:_flatten_data(value, full_key)
            for nested_key, nested_value in pairs(nested) do
                result[nested_key] = nested_value
            end
        else
            result[full_key] = value
        end
    end

    return result
end

function Database:begin_transaction()
    if not self._transaction_active then
        sqlite_exec(self.db, 'BEGIN TRANSACTION')
        self._transaction_active = true
        self._pending_operations = 0
    end
end

function Database:commit_transaction()
    if self._transaction_active then
        sqlite_exec(self.db, 'COMMIT')
        self._transaction_active = false
        self._pending_operations = 0
    end
end

function Database:add_or_update(id, fragment)
    -- Auto-begin transaction for batching
    self:begin_transaction()

    local id_str = tostring(id)
    local fragment_json = json.encode(fragment)

    -- Flatten nested data (schema already exists)
    local flat_data = self:_flatten_data(fragment)

    -- Check if entry exists and get current version
    local cursor = self.db:execute('SELECT version FROM entries WHERE id = ?', id_str)
    
    local version = 0
    local is_new = true

    if cursor then
        local row = cursor:fetch({}, "n")
        if row then
            is_new = false
            version = tonumber(row[1]) or 0
        end
        cursor:close()
    end

    version = version + 1

    -- Build dynamic SQL for INSERT/UPDATE with all columns
    local columns = {}
    local values = {}

    -- Always include these base columns
    table.insert(columns, 'id')
    table.insert(values, id_str)

    table.insert(columns, 'version')
    table.insert(values, version)

    -- Add columns from flat_data (only if they exist in schema)
    for key, value in pairs(flat_data) do
        if self._schema_columns[key] then
            table.insert(columns, '"' .. key .. '"')
            
            -- Convert boolean to integer
            if type(value) == 'boolean' then
                table.insert(values, value and 1 or 0)
            else
                table.insert(values, value)
            end
        end
    end

    if is_new then
        local placeholders = {}
        for i = 1, #values do
            table.insert(placeholders, '?')
        end
        local sql = string.format('INSERT INTO entries (%s) VALUES (%s)',
            table.concat(columns, ', '), table.concat(placeholders, ', '))
        self.db:execute(sql, table.unpack(values))
    else
        -- For updates, set updated_at and build SET clause
        local set_clauses = { 'version = ?', "updated_at = strftime('%s', 'now')" }
        local update_values = { version }

        for i = 3, #columns do -- Skip id and version
            table.insert(set_clauses, columns[i] .. ' = ?')
            table.insert(update_values, values[i])
        end

        local sql = string.format('UPDATE entries SET %s WHERE id = ?', table.concat(set_clauses, ', '))
        table.insert(update_values, id_str)
        self.db:execute(sql, table.unpack(update_values))

        -- Add history entry (delta only)
        self.db:execute('INSERT INTO history (entry_id, time, delta) VALUES (?, ?, ?)',
            id_str, os.time(), fragment_json)

        -- Auto-commit every 50 operations for maximum batching
        self._pending_operations = self._pending_operations + 1
        if self._pending_operations >= 50 then
            self:commit_transaction()
        end

        return Database.RESULT_UPDATED
    end

    -- Add history entry with delta only
    self.db:execute('INSERT INTO history (entry_id, time, delta) VALUES (?, ?, ?)',
        id_str, os.time(), fragment_json)

    -- Enforce history limit using SQLite
    if self.max_history then
        local delete_sql = [[
            DELETE FROM history
            WHERE entry_id = ? AND id NOT IN (
                SELECT id FROM history
                WHERE entry_id = ?
                ORDER BY time DESC
                LIMIT ?
            )
        ]]
        self.db:execute(delete_sql, id_str, id_str, self.max_history)
    end

    -- Auto-commit every 50 operations for maximum batching
    self._pending_operations = self._pending_operations + 1
    if self._pending_operations >= 50 then
        self:commit_transaction()
    end

    return is_new and Database.RESULT_NEW or Database.RESULT_UPDATED
end

function Database:get(id)
    local id_str = tostring(id)

    -- Get all data columns from schema (exclude internal columns)
    local columns = {}
    for col_name, _ in pairs(self._schema_columns) do
        if col_name ~= 'version' and col_name ~= 'created_at' and col_name ~= 'updated_at' then
            table.insert(columns, '"' .. col_name .. '"')
        end
    end

    if #columns == 0 then
        return nil -- No data columns exist
    end

    local sql = string.format('SELECT %s FROM entries WHERE id = ?', table.concat(columns, ', '))
    local cursor = self.db:execute(sql, id_str)

    local result = nil
    if cursor then
        local row = cursor:fetch({}, "n")
        if row then
            result = {}
            for i, col_name in ipairs(columns) do
                local clean_name = col_name:gsub('"', '') -- Remove quotes
                local value = row[i]
                
                -- Convert based on column type
                local col_type = self._schema_columns[clean_name]
                if col_type == 'INTEGER' and value then
                    result[clean_name] = tonumber(value)
                elseif col_type == 'REAL' and value then
                    result[clean_name] = tonumber(value)
                else
                    result[clean_name] = value
                end
            end
        end
        cursor:close()
    end

    return result
end

function Database:count()
    if not self.db then
        return 0 -- Return 0 if database is closed
    end

    local cursor = self.db:execute('SELECT COUNT(*) FROM entries')
    local count = 0

    if cursor then
        local row = cursor:fetch({}, "n")
        if row then
            count = tonumber(row[1]) or 0
        end
        cursor:close()
    end

    return count
end

function Database:find_by(path, expected)
    -- Convert dot notation path to flattened column name
    local column_name = path:gsub('%.', '_')

    -- Check if this column exists in our schema
    if not self._schema_columns[column_name] then
        return nil, nil -- Column doesn't exist
    end

    local sql = string.format('SELECT id FROM entries WHERE "%s" = ?', column_name)
    
    -- Handle different value types
    local search_value = expected
    if type(expected) == 'boolean' then
        search_value = expected and 1 or 0
    end

    local cursor = self.db:execute(sql, search_value)

    local result_id = nil
    if cursor then
        local row = cursor:fetch({}, "n")
        if row then
            result_id = row[1]
        end
        cursor:close()
    end

    -- If we found an ID, get the full record
    if result_id then
        local result_data = self:get(result_id)
        return result_data, result_id
    end

    return nil, nil
end

function Database:close()
    if self.db ~= nil then
        -- Commit any pending transaction before closing
        self:commit_transaction()
        self.db:close()
        self.db = nil

        -- Remove from filename tracking
        if self._filename and _databases_by_file[self._filename] then
            for i, db in ipairs(_databases_by_file[self._filename]) do
                if db == self then
                    table.remove(_databases_by_file[self._filename], i)
                    break
                end
            end
            if #_databases_by_file[self._filename] == 0 then
                _databases_by_file[self._filename] = nil
            end
        end
    end
end

-- Auto-close on garbage collection
function Database:__gc()
    self:close()
end

-- Force close any existing connections to a specific file
Database._force_close_file = function(filename)
    if _databases_by_file[filename] then
        for i = #_databases_by_file[filename], 1, -1 do
            local db = _databases_by_file[filename][i]
            if db and db.db then
                db:close()
            end
        end
        _databases_by_file[filename] = nil
    end
end

-- Global cleanup function to close all open databases
Database.close_all = function()
    for i = #_open_databases, 1, -1 do
        local db = _open_databases[i]
        if db and db.db then
            db:close()
        end
        _open_databases[i] = nil
    end

    -- Clear filename tracking
    _databases_by_file = {}
end

-- Force close all SQLite connections in the entire process
-- This releases file handles that might be preventing file deletion
Database.force_close_all_connections = function()
    -- Force garbage collection to clean up any unreferenced database objects
    collectgarbage('collect')
    collectgarbage('collect') -- Run twice to be thorough

    -- Clear all our tracking
    _open_databases = {}
    _databases_by_file = {}
    
    -- Close the luasql environment
    if env then
        env:close()
        env = luasql.sqlite3() -- Recreate for future use
    end
end

return Database