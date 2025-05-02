local serpent = require('libs/serpent')

local function deep_clone(tbl)
    if type(tbl) ~= "table" then
        return tbl
    end
    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = deep_clone(v)
    end
    return copy
end

local function deep_merge(target, fragment)
    for k, v in pairs(fragment) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then
                target[k] = {}
            end
            deep_merge(target[k], v)
        else
            target[k] = v
        end
    end
end

local function table_diff(old, new, ignore_list, prefix)
    local diff = {}
    prefix = prefix or ""

    for k, v_new in pairs(new) do
        local v_old = old and old[k]
        local path = prefix .. tostring(k)

        -- Check if path should be ignored
        local should_ignore = false
        if ignore_list then
            for _, ignore_path in ipairs(ignore_list) do
                if ignore_path == path then
                    should_ignore = true
                    break
                end
            end
        end

        if not should_ignore then
            if type(v_new) == "table" and type(v_old) == "table" then
                local sub_diff = table_diff(v_old, v_new, ignore_list, path .. ".")
                if next(sub_diff) then
                    diff[k] = sub_diff
                end
            elseif v_new ~= v_old then
                diff[k] = { from = v_old, to = v_new }
            end
        end
    end

    return diff
end

local function make_sortkeys(preferred_keys)
    local priority = {}
    for i, key in ipairs(preferred_keys) do
        priority[key] = i
    end

    return function(keys, tbl)
        table.sort(keys, function(a, b)
            local pa, pb = priority[a], priority[b]
            if pa and pb then return pa < pb end
            if pa then return true end
            if pb then return false end
            return tostring(a) < tostring(b)
        end)
    end
end

-- Database
local Database = {}
Database.__index = Database

Database.RESULT_NEW     = 1
Database.RESULT_UPDATED = 2
Database.RESULT_NOOP    = 3

function Database.new(file, opts)
    return setmetatable({
        dirty = false,
        entries = {},
        file = file,
        ignore_updates = opts and opts.ignore_updates or {},
        max_history = opts and opts.max_history or nil,
        sort_keys = opts and opts.sort_keys or nil,
    }, Database)
end

function Database:add_or_update(id, fragment)
    local entry = self.entries[id]
    local is_new = false

    if not entry then
        entry = {
            version = 0,
            data = {},
            history = {},
            _serialized = nil,
            _dirty = true,
        }
        self.entries[id] = entry
        is_new = true
    end

    local old_data = deep_clone(entry.data)

    -- merge fragment
    deep_merge(entry.data, fragment)

    -- compute diff
    local changes = table_diff(old_data, entry.data, self.ignore_updates)

    if next(changes) then
        entry.version = entry.version + 1
        table.insert(entry.history, {
            time = os.time(),
            changes = changes
        })

        -- Mark dirty because data changed
        entry._dirty = true

        -- Enforce history size limit
        if self.max_history and #entry.history > self.max_history then
            local excess = #entry.history - self.max_history
            for i = 1, excess do
                table.remove(entry.history, 1)
            end
        end

        self.dirty = true
        return is_new and Database.RESULT_NEW or Database.RESULT_UPDATED
    else
        return Database.RESULT_NOOP
    end
end

function Database:get(id)
    if self.entries[id] and self.entries[id].data then
        return deep_clone(self.entries[id].data)
    end

    return nil
end

function Database:count()
    local count = 0
    for _, entry in pairs(self.entries) do
        if entry and entry.data then
            count = count + 1
        end
    end

    return count
end

function Database:find_by(path, expected)
    local segments = {}
    for segment in string.gmatch(path, "[^%.]+") do
        table.insert(segments, segment)
    end

    for id, entry in pairs(self.entries) do
        local value = entry.data
        for _, key in ipairs(segments) do
            value = value and value[key]
        end

        if value == expected then
            return self:get(id), id
        end
    end

    return nil, nil
end

function Database:save()
    if not self.dirty then
        return false
    end

    local data_sort = self.sort_keys and make_sortkeys(self.sort_keys) or nil
    local serpent_opts_data = { comment = false, compact = false, sparse = true, sortkeys = data_sort }
    local serpent_opts_history = { comment = false, compact = true, sparse = true }

    self.file.stream:write("return {\n")

    for id, entry in pairs(self.entries) do
        if entry then
            if not entry._dirty and entry._serialized then
                -- Use cached serialized line if not dirty
                self.file.stream:append(entry._serialized .. "\n")
            else
                -- Re-serialize because dirty
                local sorted_data = serpent.line(entry.data, serpent_opts_data)
                local history_line = serpent.line(entry.history, serpent_opts_history)

                local line = string.format(
                        "  ['%s'] = {version = %d, data = %s, history = %s},",
                        tostring(id), entry.version, sorted_data, history_line
                )

                entry._serialized = line
                entry._dirty = false

                self.file.stream:append(line .. "\n")
            end
        end
    end

    self.file.stream:append("}\n")
    self.dirty = false

    return true
end

function Database:close()
    self:save()
end

return Database
