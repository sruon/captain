local breader     = require('bitreader')
local definitions = require('packets.definitions')
---@type table
local bit         = bit or require('bit')

local parser      = {}

local function read_value(reader, bits, signed)
    local value = reader:read(bits)
    if signed then
        local sign_bit = bit.band(value, bit.lshift(1, bits - 1))
        if sign_bit ~= 0 then
            value = bit.bor(value, bit.bnot(bit.lshift(1, bits) - 1))
        end
    end
    return value
end

local parse_layout

local type_handlers = {}

type_handlers.numeric = function(reader, field, result, context, header, data)
    if field.type == 'float' then
        local raw = reader:read(field.bits)
        result[field.name] = backend.convert_int_to_float(raw)
    else
        result[field.name] = read_value(reader, field.bits, field.signed)
    end
end

-- Handler for computed expression fields
type_handlers.expr = function(reader, field, result, context, header, data)
    result[field.name] = field.expr(result, data, header)
end

-- Handler for struct types
type_handlers.struct = function(reader, field, result, context, header, data)
    local sublayout = field.layout
    if type(sublayout) == 'function' then
        sublayout = sublayout(result, data, header)
    end
    result[field.name] = parse_layout(reader, sublayout, result, header, data)
end

-- Handler for array types
type_handlers.array = function(reader, field, result, context, header, data)
    -- Determine the count
    local count
    if type(field.count) == 'function' then
        count = field.count(result, data, header)
    else
        count = result[field.count] or context[field.count] or field.count
    end

    result[field.name] = {}

    for i = 1, count do
        -- Simple array of primitive values
        if #field.layout == 1 and field.layout[1].bits and not field.layout[1].type then
            local value = read_value(reader, field.layout[1].bits, field.layout[1].signed)
            result[field.name][i] = value
            -- Array of strings
        elseif #field.layout == 1 and field.layout[1].type == 'string' then
            local chars = {}
            for _ = 1, field.layout[1].size do
                chars[#chars+1] = string.char(reader:read(8))
            end
            local str = table.concat(chars):gsub('%z.*$', '')
            result[field.name][i] = str
            -- Array of complex types (could be nested arrays, structs, etc.)
        else
            -- For complex layouts, we create a new context for each element
            local element_context = {}
            -- Copy over any fields from parent context that might be needed
            for k, v in pairs(context) do
                element_context[k] = v
            end
            -- Add array index to context
            element_context._index = i
            -- Add parent result to context
            element_context._parent = result

            -- Parse this array element
            local nested_result = parse_layout(reader, field.layout, element_context, header, data)
            result[field.name][i] = nested_result
        end
    end
end

type_handlers.string = function(reader, field, result, context, header, data)
    local chars = {}
    for _ = 1, field.size do
        chars[#chars+1] = string.char(reader:read(8))
    end
    result[field.name] = table.concat(chars):gsub('%z.*$', '')
end

type_handlers.raw = function(reader, field, result, context, header, data)
    local raw = {}
    for _ = 1, field.size do
        raw[#raw+1] = string.char(reader:read(8))
    end
    result[field.name] = table.concat(raw)
end

-- Handler for conditional types
type_handlers.conditional = function(reader, field, result, context, header, data)
    local has_flag = reader:read(field.bits)
    result[field.name] = has_flag > 0

    if result[field.name] then
        local struct_name = field.layout.name
        -- Create a new context for conditional fields
        local conditional_context = {}
        for k, v in pairs(context) do
            conditional_context[k] = v
        end
        conditional_context._parent = result

        result[struct_name] = parse_layout(reader, field.layout.layout, conditional_context, header, data)
    end
end

-- Main layout parser function
---@param reader BitReader
---@param layout table  -- The layout to parse
---@param context table -- The context for the layout
---@param header table  -- The packet header
---@param data table    -- The raw packet data
---@return any -- The parsed packet data
parse_layout = function(reader, layout, context, header, data)
    local result = {}

    -- Store a reference to parent context if needed
    if context._parent then
        result._parent = context._parent
    end

    -- Process each field in the layout
    for _, field in ipairs(layout) do
        -- Determine the field type and call the appropriate handler
        if field.expr then
            type_handlers.expr(reader, field, result, context, header, data)
        elseif field.conditional then
            type_handlers.conditional(reader, field, result, context, header, data)
        elseif field.type == 'struct' then
            type_handlers.struct(reader, field, result, context, header, data)
        elseif field.type == 'array' then
            type_handlers.array(reader, field, result, context, header, data)
        elseif field.type == 'string' then
            type_handlers.string(reader, field, result, context, header, data)
        elseif field.type == 'raw' then
            type_handlers.raw(reader, field, result, context, header, data)
        elseif field.bits then
            type_handlers.numeric(reader, field, result, context, header, data)
        else
            error('Unknown field type for field: ' .. (field.name or 'unnamed'))
        end
    end

    -- Clean up internal references before returning
    result._parent = nil

    return result
end

---@param dir string               -- 'outgoing' or 'incoming'
---@param packet string | number[] -- The raw packet data
---@return any | nil               -- The parsed packet data or nil if the packet is not recognized
parser.parse = function(dir, packet)
    local reader = breader:new()
    reader:set_data(packet)
    local header =
    {
        id   = reader:read(9),
        size = reader:read(7),
        sync = reader:read(16),
    }

    if not definitions[dir] or not definitions[dir][header.id] then
        return nil
    end

    local newPacket = parse_layout(reader, definitions[dir][header.id], {}, header, packet)
    newPacket.header = header

    return newPacket
end

return parser
