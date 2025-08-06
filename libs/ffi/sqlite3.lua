local ffi             = require('ffi')
local json            = require('json')

-- Global registry to track all open databases
local _open_databases = {}
setmetatable(_open_databases, { __mode = 'v' }) -- weak references

-- Track databases by filename for force-closing
local _databases_by_file = {}

-- Define the functions first
ffi.cdef [[
typedef struct sqlite3 sqlite3;
typedef struct sqlite3_stmt sqlite3_stmt;
int sqlite3_open(const char *filename, sqlite3 **ppDb);
int sqlite3_close(sqlite3 *db);
int sqlite3_exec(sqlite3 *db, const char *sql, int (*callback)(void*,int,char**,char**), void *arg, char **errmsg);
int sqlite3_prepare_v2(sqlite3 *db, const char *zSql, int nByte, sqlite3_stmt **ppStmt, const char **pzTail);
int sqlite3_step(sqlite3_stmt *pStmt);
int sqlite3_finalize(sqlite3_stmt *pStmt);
int sqlite3_bind_text(sqlite3_stmt *pStmt, int idx, const char *val, int n, void(*free)(void*));
int sqlite3_bind_int(sqlite3_stmt *pStmt, int idx, int val);
const char *sqlite3_column_text(sqlite3_stmt *pStmt, int iCol);
int sqlite3_column_int(sqlite3_stmt *pStmt, int iCol);
void sqlite3_free(void *ptr);
const char *sqlite3_errmsg(sqlite3 *db);
const char *sqlite3_libversion(void);
]]

local sqlite            = ffi.load(addon.path .. '/deps/sqlite3')

---@class Database
---@field db sqlite3*
---@field ignore_updates table
---@field max_history number
---@field add_or_update fun(self, id: any, fragment: table): number
---@field get fun(self, id: any): table | nil
---@field count fun(self): number
---@field find_by fun(self, path: string, expected: any): table | nil, number | nil
---@field close fun(self)
local Database          = {}
Database.__index        = Database

Database.RESULT_NEW     = 1
Database.RESULT_UPDATED = 2
Database.RESULT_NOOP    = 3

-- SQLite wrapper methods
local function sqlite_exec(db, sql)
    local errmsg_ptr = ffi.new('char*[1]')
    local result     = sqlite.sqlite3_exec(db, sql, nil, nil, errmsg_ptr)

    if result ~= 0 then
        local errmsg = 'Unknown error'
        if errmsg_ptr[0] ~= nil then
            errmsg = ffi.string(errmsg_ptr[0])
            sqlite.sqlite3_free(errmsg_ptr[0])
        end
        error('SQL execution failed: ' .. errmsg)
    end
end

local function sqlite_prepare(db, sql)
    local stmt_ptr = ffi.new('sqlite3_stmt*[1]')
    local result   = sqlite.sqlite3_prepare_v2(db, sql, -1, stmt_ptr, nil)

    if result ~= 0 then
        local errmsg = ffi.string(sqlite.sqlite3_errmsg(db))
        error('SQL prepare failed: ' .. errmsg)
    end

    return stmt_ptr[0]
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
    local db_ptr = ffi.new('sqlite3*[1]')
    local result = sqlite.sqlite3_open(filename, db_ptr)

    if result ~= 0 then
        local db = db_ptr[0]
        if db ~= nil then
            local errmsg = ffi.string(sqlite.sqlite3_errmsg(db))
            sqlite.sqlite3_close(db)
            error('Failed to open database: ' .. errmsg)
        else
            error('Failed to open database: unknown error')
        end
    end

    local self = setmetatable(
        {
            db                  = db_ptr[0],
            ignore_updates      = opts and opts.ignore_updates or {},
            max_history         = opts and opts.max_history or nil,
            _transaction_active = false,
            _pending_operations = 0,
            _schema_columns     = {},
            _filename           = filename,
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
    local flat_data                    = self:_flatten_data(example)

    -- Build schema columns from flattened data
    self._schema_columns['id']         = 'TEXT PRIMARY KEY'
    self._schema_columns['version']    = 'INTEGER DEFAULT 0'
    self._schema_columns['created_at'] = "INTEGER DEFAULT (strftime('%s', 'now'))"
    self._schema_columns['updated_at'] = "INTEGER DEFAULT (strftime('%s', 'now'))"

    for key, value in pairs(flat_data) do
        self._schema_columns[key] = self:_infer_sql_type(value)
    end
end

function Database:_init_schema()
    -- Build CREATE TABLE statement with columns in specific order
    local columns        = {}

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
            version INTEGER,
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
    prefix       = prefix or ''
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

function Database:_compute_diff(old_data, new_data)
    local diff = {}

    if not old_data then
        return new_data -- First time, return everything
    end

    -- Check for changed/new fields
    for key, new_value in pairs(new_data) do
        local old_value = old_data[key]
        if old_value ~= new_value then
            diff[key] = new_value
        end
    end

    -- Check for removed fields (set to null in diff)
    for key, old_value in pairs(old_data) do
        if new_data[key] == nil then
            diff[key] = nil
        end
    end

    return diff
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

    local id_str        = tostring(id)
    local fragment_json = json.encode(fragment)

    -- Flatten nested data (schema already exists)
    local flat_data     = self:_flatten_data(fragment)

    -- Check if entry exists and get current version + current data
    local stmt          = sqlite_prepare(self.db, 'SELECT version FROM entries WHERE id = ?')
    sqlite.sqlite3_bind_text(stmt, 1, id_str, -1, nil)

    local version  = 0
    local is_new   = true
    local old_data = nil

    if sqlite.sqlite3_step(stmt) == 100 then -- SQLITE_ROW
        is_new   = false
        version  = sqlite.sqlite3_column_int(stmt, 0)
        -- Get current data for diff calculation
        old_data = self:get(id)
    end
    sqlite.sqlite3_finalize(stmt)

    version            = version + 1

    -- Build dynamic SQL for INSERT/UPDATE with all columns
    local columns      = {}
    local placeholders = {}
    local values       = {}

    -- Always include these base columns (skip _id since it's autoincrement)
    table.insert(columns, 'id')
    table.insert(placeholders, '?')
    table.insert(values, id_str)

    table.insert(columns, 'version')
    table.insert(placeholders, '?')
    table.insert(values, version)

    -- Add columns from flat_data (only if they exist in schema)
    for key, value in pairs(flat_data) do
        if self._schema_columns[key] then
            table.insert(columns, '"' .. key .. '"')
            table.insert(placeholders, '?')

            -- Convert boolean to integer
            if type(value) == 'boolean' then
                table.insert(values, value and 1 or 0)
            else
                table.insert(values, value)
            end
        end
    end

    if is_new then
        local sql = string.format('INSERT INTO entries (%s) VALUES (%s)',
            table.concat(columns, ', '), table.concat(placeholders, ', '))
        stmt      = sqlite_prepare(self.db, sql)
    else
        -- For updates, set updated_at and build SET clause
        local set_clauses   = { 'version = ?', "updated_at = strftime('%s', 'now')" }
        local update_values = { version }

        for i = 3, #columns do -- Skip id and version
            table.insert(set_clauses, columns[i] .. ' = ?')
            table.insert(update_values, values[i])
        end

        local sql = string.format('UPDATE entries SET %s WHERE id = ?', table.concat(set_clauses, ', '))
        stmt      = sqlite_prepare(self.db, sql)

        -- Bind update values + id at the end
        for i, value in ipairs(update_values) do
            if type(value) == 'string' then
                sqlite.sqlite3_bind_text(stmt, i, value, -1, nil)
            else
                sqlite.sqlite3_bind_int(stmt, i, value)
            end
        end
        sqlite.sqlite3_bind_text(stmt, #update_values + 1, id_str, -1, nil)

        sqlite.sqlite3_step(stmt)
        sqlite.sqlite3_finalize(stmt)

        -- Compute diff between old and new data
        local diff = self:_compute_diff(old_data, flat_data)
        if next(diff) then -- Only store if there are actual changes
            stmt = sqlite_prepare(self.db,
                'INSERT INTO history (entry_id, version, time, delta) VALUES (?, ?, ?, json(?))')
            sqlite.sqlite3_bind_text(stmt, 1, id_str, -1, nil)
            sqlite.sqlite3_bind_int(stmt, 2, version)
            sqlite.sqlite3_bind_int(stmt, 3, os.time())
            sqlite.sqlite3_bind_text(stmt, 4, json.encode(diff), -1, nil)
            sqlite.sqlite3_step(stmt)
            sqlite.sqlite3_finalize(stmt)
        end

        -- Auto-commit every 50 operations for maximum batching
        self._pending_operations = self._pending_operations + 1
        if self._pending_operations >= 50 then
            self:commit_transaction()
        end

        return Database.RESULT_UPDATED
    end

    -- Insert case - bind all values
    for i, value in ipairs(values) do
        if type(value) == 'string' then
            sqlite.sqlite3_bind_text(stmt, i, value, -1, nil)
        else
            sqlite.sqlite3_bind_int(stmt, i, value)
        end
    end

    sqlite.sqlite3_step(stmt)
    sqlite.sqlite3_finalize(stmt)

    -- For INSERT, store the complete data as the initial delta
    stmt = sqlite_prepare(self.db, 'INSERT INTO history (entry_id, version, time, delta) VALUES (?, ?, ?, json(?))')
    sqlite.sqlite3_bind_text(stmt, 1, id_str, -1, nil)
    sqlite.sqlite3_bind_int(stmt, 2, version)
    sqlite.sqlite3_bind_int(stmt, 3, os.time())
    sqlite.sqlite3_bind_text(stmt, 4, json.encode(flat_data), -1, nil)
    sqlite.sqlite3_step(stmt)
    sqlite.sqlite3_finalize(stmt)

    -- Enforce history limit using SQLite (if configured)
    if self.max_history then
        stmt = sqlite_prepare(self.db, [[
            DELETE FROM history
            WHERE entry_id = ? AND id NOT IN (
                SELECT id FROM history
                WHERE entry_id = ?
                ORDER BY version DESC
                LIMIT ?
            )
        ]])
        sqlite.sqlite3_bind_text(stmt, 1, id_str, -1, nil)
        sqlite.sqlite3_bind_text(stmt, 2, id_str, -1, nil)
        sqlite.sqlite3_bind_int(stmt, 3, self.max_history)
        sqlite.sqlite3_step(stmt)
        sqlite.sqlite3_finalize(stmt)
    end

    -- Auto-commit every 50 operations for maximum batching
    self._pending_operations = self._pending_operations + 1
    if self._pending_operations >= 50 then
        self:commit_transaction()
    end

    return Database.RESULT_NEW
end

function Database:get(id)
    local id_str  = tostring(id)

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

    local sql  = string.format('SELECT %s FROM entries WHERE id = ?', table.concat(columns, ', '))
    local stmt = sqlite_prepare(self.db, sql)
    sqlite.sqlite3_bind_text(stmt, 1, id_str, -1, nil)

    local result = nil
    if sqlite.sqlite3_step(stmt) == 100 then -- SQLITE_ROW
        result = {}
        for i, col_name in ipairs(columns) do
            local clean_name = col_name:gsub('"', '') -- Remove quotes
            local col_index  = i - 1                  -- SQLite uses 0-based indexing

            -- Get value based on column type
            local col_type   = self._schema_columns[clean_name]
            if col_type == 'INTEGER' then
                result[clean_name] = sqlite.sqlite3_column_int(stmt, col_index)
            elseif col_type == 'REAL' then
                -- For REAL columns, we need to get as text and convert
                local text_val = sqlite.sqlite3_column_text(stmt, col_index)
                if text_val ~= nil then
                    result[clean_name] = tonumber(ffi.string(text_val))
                end
            else -- TEXT
                local text_val = sqlite.sqlite3_column_text(stmt, col_index)
                if text_val ~= nil then
                    result[clean_name] = ffi.string(text_val)
                end
            end
        end
    end

    sqlite.sqlite3_finalize(stmt)
    return result
end

function Database:count()
    if not self.db then
        return 0 -- Return 0 if database is closed
    end

    local stmt  = sqlite_prepare(self.db, 'SELECT COUNT(*) FROM entries')
    local count = 0

    if sqlite.sqlite3_step(stmt) == 100 then -- SQLITE_ROW
        count = sqlite.sqlite3_column_int(stmt, 0)
    end

    sqlite.sqlite3_finalize(stmt)
    return count
end

function Database:find_by(path, expected)
    -- Convert dot notation path to flattened column name
    local column_name = path:gsub('%.', '_')

    -- Check if this column exists in our schema
    if not self._schema_columns[column_name] then
        return nil, nil -- Column doesn't exist
    end

    local stmt = sqlite_prepare(self.db, string.format('SELECT id FROM entries WHERE "%s" = ?', column_name))

    -- Handle different value types for SQLite binding
    if type(expected) == 'string' then
        sqlite.sqlite3_bind_text(stmt, 1, expected, -1, nil)
    elseif type(expected) == 'number' then
        sqlite.sqlite3_bind_int(stmt, 1, expected)
    elseif type(expected) == 'boolean' then
        sqlite.sqlite3_bind_int(stmt, 1, expected and 1 or 0)
    else
        sqlite.sqlite3_bind_text(stmt, 1, tostring(expected), -1, nil)
    end

    local result_id = nil
    if sqlite.sqlite3_step(stmt) == 100 then -- SQLITE_ROW
        result_id = ffi.string(sqlite.sqlite3_column_text(stmt, 0))
    end

    sqlite.sqlite3_finalize(stmt)

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
        sqlite.sqlite3_close(self.db)
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
Database._force_close_file           = function(filename)
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
Database.close_all                   = function()
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
    _open_databases    = {}
    _databases_by_file = {}
end

return Database
