---@diagnostic disable: deprecated

local backend  = require('backend/backend')
local serpent  = require("deps/serpent")

local utils    = {}

-- Deep copy function for tables
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

-- Create a file name based on the current date and time
local date     = os.date('*t')
local name     = string.format('packets_%d_%d_%d_%d_%d_%d.txt', date['year'], date['month'], date['day'], date['hour'],
    date['min'], date['sec'])
local filename = backend.script_path() .. 'captures/' .. name

utils.log      = function(str, ...)
    backend.file_append(filename, str)
end

utils.hexdump  = function(str, align, indent)
    local ret = ''

    -- Loop the data string in steps..
    for x = 1, #str, align do
        local data = str:sub(x, x + 15)
        ret = ret .. string.rep(' ', indent)
        ret = ret .. data:gsub('.', function(c) return string.format('%02X ', string.byte(c)) end)
        ret = ret .. string.rep(' ', 3 * (16 - #data))
        ret = ret .. ' ' .. data:gsub('%c', '.')
        ret = ret .. '\n'
    end

    -- Fix percents from breaking string.format..
    ret = string.gsub(ret, '%%', '%%%%')
    ret = ret .. '\n'

    return ret
end

do
    -- Precompute hex string tables for lookups, instead of constant computation.
    local top_row = '        |  0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F      | 0123456789ABCDEF\n    ' ..
        string.rep('-', (16 + 1) * 3 + 2) .. '  ' .. string.rep('-', 16 + 6) .. '\n'

    local chars = {}
    for i = 0x00, 0xFF do
        if i >= 0x20 and i < 0x7F then
            chars[i] = string.char(i)
        else
            chars[i] = '.'
        end
    end
    chars[0x5C] = '\\\\'
    chars[0x25] = '%%'

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
        local length = size
        local str_table = {}
        local from = 1
        local to = 16
        for i = 0, math.floor((length - 1) / 0x10) do
            local partial_str = { str:byte(from, to) }
            local char_table = {
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
            local bytes = math.min(length - from + 1, 16)
            str_table[i + 1] = line_replace[bytes]
                :format(unpack(partial_str))
                :format(short_replace[bytes]:format(unpack(char_table)))
                :format(i, i)
            from = to + 1
            to = to + 0x10
        end
        return string.format('%s%s', top_row, table.concat(str_table))
    end
end

-- Rounds to prec decimal digits. Accepts negative numbers for precision.
function math.round(num, prec)
    local mult = 10 ^ (prec or 0)
    return math.floor(num * mult + 0.5) / mult
end

utils.round = math.round

utils.headingToByteRotation = function(oldHeading)
    local newHeading = oldHeading
    if newHeading < 0 then
        newHeading = (math.pi * 2) - (newHeading * -1)
    end
    return math.round((newHeading / (math.pi * 2)) * 256)
end

function string.fromhex(str)
    if str == nil then return "" end
    return (str:gsub('..', function(cc)
        return string.char(tonumber(cc, 16))
    end))
end

function string.tohex(str)
    if str == nil then return "" end
    return (str:gsub('.', function(c)
        return string.format('%02X ', string.byte(c))
    end))
end

utils.getTableKeys    = function(tab)
    local keyset = {}
    for k, v in pairs(tab) do
        keyset[#keyset + 1] = k
    end
    return keyset
end

utils.dump            = function(o, print)
    local d = serpent.block(o, { comment = false, sortkeys = true })

    if print then
        backend.msg('dump', d)
    end

    return d
end

utils.keyBindToString = function(keyBind)
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

utils.deepCopy        = function(original)
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

utils.getProcessInfo = function()
    local ffi = require('ffi')
    
    ffi.cdef[[
        int GetModuleFileNameA(void* hModule, char* lpFilename, int nSize);
        void* GetActiveWindow();
        int GetWindowTextA(void* hWnd, char* lpString, int nMaxCount);
    ]]
    
    -- Get process path
    local buffer = ffi.new("char[260]") -- MAX_PATH
    ffi.C.GetModuleFileNameA(nil, buffer, 260)
    local process_path = ffi.string(buffer)
    
    -- Get active window title
    local hwnd = ffi.C.GetActiveWindow()
    local window_buffer = ffi.new("char[256]")
    ffi.C.GetWindowTextA(hwnd, window_buffer, 256)
    local window_name = ffi.string(window_buffer)
    
    return process_path, window_name
end

return utils
