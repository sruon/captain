-- Simple CSV library
-- Handles creating CSV files with defined columns and adding entries

---@class CSV
---@field columns string[] Table of column names
---@field entries table[] Array of entries to be written
---@field file File The file object to write to
local CSV   = {}
CSV.__index = CSV

---Create a new CSV writer
---@param file File The file object to write to
---@param columns string[] Table of column names
---@return CSV instance
function CSV.new(file, columns)
    local self   = setmetatable({}, CSV)
    self.columns = columns
    self.entries = {}
    self.file    = file

    self:write_headers()

    return self
end

---Write headers to the CSV file
---@return boolean true on success, false on error
function CSV:write_headers()
    if not self.file then
        return false
    end

    -- Write the headers
    self.file:append(table.concat(self.columns, ',') .. '\n')
    return true
end

---Add a row to the CSV
---@param entry table Table with keys matching column names
---@param decimal_places number? Number of decimal places to round numeric values (default: 3)
---@return boolean true on success, false on error
function CSV:add_entry(entry, decimal_places)
    if type(entry) ~= 'table' then
        return false
    end

    decimal_places = decimal_places or 3

    local row      = {}
    for _, col in ipairs(self.columns) do
        local value = entry[col] or ''

        -- Round numerical values
        if type(value) == 'number' then
            local mult = 10 ^ decimal_places
            value      = math.floor(value * mult + 0.5) / mult
        end

        -- Escape quotes and wrap fields with commas in quotes
        if type(value) == 'string' and (value:find(',') or value:find('"')) then
            value = value:gsub('"', '""')
            value = '"' .. value .. '"'
        end

        table.insert(row, tostring(value))
    end

    table.insert(self.entries, row)
    return true
end

---Save all entries to the CSV file
---@return boolean true on success, false on error
function CSV:save()
    if #self.entries == 0 then
        return true
    end

    local content = ''
    for _, row in ipairs(self.entries) do
        content = content .. table.concat(row, ',') .. '\n'
    end

    -- Append to the file
    self.file:append(content)

    -- Clear entries after save
    self.entries = {}
    return true
end

---Close the CSV writer and save any pending entries
function CSV:close()
    self:save()
end

return CSV
