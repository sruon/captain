---@diagnostic disable: deprecated

local backend  = require('backend.backend')
local serpent  = require('serpent')

local utils    = {}

---Deep copy function for tables
---@param orig any The original value to copy
---@return any copy Deep copy of the original value
utils.deepcopy = function(orig)
    local copy
    if type(orig) == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[utils.deepcopy(orig_key)] = utils.deepcopy(orig_value)
        end
        setmetatable(copy, utils.deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

do
    -- Precompute hex string tables for lookups, instead of constant computation.
    local top_row = '        |  0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F      | 0123456789ABCDEF\n    ' ..
      string.rep('-', (16 + 1) * 3 + 2) .. '  ' .. string.rep('-', 16 + 6) .. '\n'

    local chars   = {}
    for i = 0x00, 0xFF do
        if i >= 0x20 and i < 0x7F then
            chars[i] = string.char(i)
        else
            chars[i] = '.'
        end
    end
    chars[0x5C]        = '\\\\'
    chars[0x25]        = '%%'

    local line_replace = {}
    for i = 0x01, 0x10 do
        line_replace[i] = '    %%%%3X |' ..
          string.rep(' %.2X', i) .. string.rep(' --', 0x10 - i) .. '  %%%%3X | ' .. '%%s\n'
    end
    local short_replace = {}
    for i = 0x01, 0x10 do
        short_replace[i] = string.rep('%s', i) .. string.rep('-', 0x10 - i)
    end

    -- Receives a byte string and returns a table-formatted string with 16 columns.
    string.hexformat_file = function(str, size, byte_colors)
        local length    = size
        local str_table = {}
        local from      = 1
        local to        = 16
        for i = 0, math.floor((length - 1) / 0x10) do
            local partial_str = { str:byte(from, to) }
            local char_table  =
            {
                [0x01] = chars[partial_str[0x01]],
                [0x02] = chars[partial_str[0x02]],
                [0x03] = chars[partial_str[0x03]],
                [0x04] = chars[partial_str[0x04]],
                [0x05] = chars[partial_str[0x05]],
                [0x06] = chars[partial_str[0x06]],
                [0x07] = chars[partial_str[0x07]],
                [0x08] = chars[partial_str[0x08]],
                [0x09] = chars[partial_str[0x09]],
                [0x0A] = chars[partial_str[0x0A]],
                [0x0B] = chars[partial_str[0x0B]],
                [0x0C] = chars[partial_str[0x0C]],
                [0x0D] = chars[partial_str[0x0D]],
                [0x0E] = chars[partial_str[0x0E]],
                [0x0F] = chars[partial_str[0x0F]],
                [0x10] = chars[partial_str[0x10]],
            }
            local bytes       = math.min(length - from + 1, 16)
            str_table[i + 1]  = line_replace[bytes]
              :format(unpack(partial_str))
              :format(short_replace[bytes]:format(unpack(char_table)))
              :format(i, i)
            from              = to + 1
            to                = to + 0x10
        end
        return string.format('%s%s', top_row, table.concat(str_table))
    end
end

---Rounds to prec decimal digits. Accepts negative numbers for precision.
---@param num number The number to round
---@param prec number|nil Number of decimal places (default: 0)
---@return number rounded The rounded number
function math.round(num, prec)
    local mult = 10 ^ (prec or 0)
    return math.floor(num * mult + 0.5) / mult
end

utils.round                 = math.round

---Converts a heading angle to byte rotation value
---@param oldHeading number The heading angle in radians
---@return number rotation The byte rotation value (0-256)
utils.headingToByteRotation = function(oldHeading)
    local newHeading = oldHeading
    if newHeading < 0 then
        newHeading = (math.pi * 2) - (newHeading * -1)
    end
    return math.round((newHeading / (math.pi * 2)) * 256)
end

---Converts hexadecimal string to binary string
---@param str string|nil The hex string to convert
---@return string binary The binary string representation
function string.fromhex(str)
    if str == nil then return '' end
    return (str:gsub('..', function(cc)
        return string.char(tonumber(cc, 16))
    end))
end

---Converts binary string to hexadecimal representation
---@param str string|nil The binary string to convert
---@return string hex The hexadecimal string representation
function string.tohex(str)
    if str == nil then return '' end
    return (str:gsub('.', function(c)
        return string.format('%02X ', string.byte(c))
    end))
end

---Gets all keys from a table and returns them sorted
---@param tab table The table to get keys from
---@return string[] keys Array of sorted keys
utils.getTableKeys              = function(tab)
    local keyset = {}
    for k, v in pairs(tab) do
        keyset[#keyset+1] = k
    end
    table.sort(keyset)
    return keyset
end

---Safely calls a function with error handling and traceback
---@param name string Name for error reporting
---@param func function The function to call
---@param ... any Arguments to pass to the function
---@return boolean ok Whether the call succeeded
---@return any result The function result or error message
utils.safe_call                 = function(name, func, ...)
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

---Dumps a value to a formatted string using serpent
---@param o any The value to dump
---@param print boolean|nil Whether to print the result (default: false)
---@return string formatted The formatted string representation
utils.dump                      = function(o, print)
    local d = serpent.block(o, { comment = false, sortkeys = true })

    if print then
        backend.msg('dump', d)
    end

    return d
end

---Converts a keybind table to a human-readable string
---@param keyBind table Keybind table with ctrl, alt, shift, win, key fields
---@return string readable Human-readable keybind string (e.g. "Ctrl+Alt+C")
utils.keyBindToString           = function(keyBind)
    local res = ''
    if keyBind.ctrl then
        res = res .. 'Ctrl+'
    end
    if keyBind.alt then
        res = res .. 'Alt+'
    end
    if keyBind.shift then
        res = res .. 'Shift+'
    end
    if keyBind.win then
        res = res .. 'Win+'
    end

    res = res .. keyBind.key:upper()

    return res
end

---Deep copy function for tables (alternative implementation)
---@param original any The original value to copy
---@return any copy Deep copy of the original value
utils.deepCopy                  = function(original)
    local copy

    if type(original) == 'table' then
        copy = {}
        for key, value in pairs(original) do
            copy[key] = utils.deepCopy(value)
        end

        if getmetatable(original) then
            setmetatable(copy, utils.deepCopy(getmetatable(original)))
        end
    else
        copy = original
    end

    return copy
end

---Gets process path and active window information using Windows API
---@return string process_path Full path to the current process executable
---@return string window_name Title of the active window
utils.getProcessInfo            = function()
    local ffi = require('ffi')

    ffi.cdef [[
        int GetModuleFileNameA(void* hModule, char* lpFilename, int nSize);
        void* GetActiveWindow();
        int GetWindowTextA(void* hWnd, char* lpString, int nMaxCount);
    ]]

    -- Get process path
    local buffer = ffi.new('char[260]') -- MAX_PATH
    ffi.C.GetModuleFileNameA(nil, buffer, 260)
    local process_path  = ffi.string(buffer)

    -- Get active window title
    local hwnd          = ffi.C.GetActiveWindow()
    local window_buffer = ffi.new('char[256]')
    ffi.C.GetWindowTextA(hwnd, window_buffer, 256)
    local window_name = ffi.string(window_buffer)

    return process_path, window_name
end

---Performance monitoring wrapper that warns if execution exceeds threshold
---Wraps a function call and warns if execution takes longer than threshold
---@param name string Name for performance reporting
---@param func function The function to monitor
---@param threshold number|nil Warning threshold in seconds (default: 0.10)
---@return any ... All function results plus elapsed_time as last return value
utils.withPerformanceMonitoring = function(name, func, threshold)
    threshold        = threshold or 0.10 -- Default 100ms
    local start_time = os.clock()
    local result     = table.pack(func())
    local elapsed    = os.clock() - start_time

    if elapsed > threshold then
        backend.warnMsg('captain', string.format('%s took %.3fs', name, elapsed))
    end

    -- Add elapsed time to the end of results
    result[result.n + 1] = elapsed
    result.n             = result.n + 1

    return table.unpack(result, 1, result.n)
end

---Converts a 32-bit integer IP address to human-readable dotted decimal format
---@param ipAddr number 32-bit integer IP address
---@return string ip Human-readable IP address (e.g. "192.168.1.1")
utils.humanReadableIP           = function(ipAddr)
    local byte1 = bit.band(bit.rshift(ipAddr, 24), 0xFF)
    local byte2 = bit.band(bit.rshift(ipAddr, 16), 0xFF)
    local byte3 = bit.band(bit.rshift(ipAddr, 8), 0xFF)
    local byte4 = bit.band(ipAddr, 0xFF)

    return string.format('%d.%d.%d.%d', byte1, byte2, byte3, byte4)
end

return utils
