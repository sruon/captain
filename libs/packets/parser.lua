local breader     = require('libs/packets/bitreader')
local definitions = require('libs/packets/definitions')
---@type table
local bit         = bit or require('bit')

local parser      = {}

---@param reader BitReader
---@param layout table  -- The layout to parse
---@param context table -- The context for the layout
---@return any -- The parsed packet data
local function parse_layout(reader, layout, context)
    local result = {}
    for _, field in ipairs(layout) do
        if field.bits and field.type ~= 'float' and not field.conditional then
            local value = reader:read(field.bits)
            if field.signed then
                local sign_bit = bit.band(value, bit.lshift(1, field.bits - 1))
                if sign_bit ~= 0 then
                    value = bit.bor(value, bit.bnot(bit.lshift(1, field.bits) - 1))
                end
            end

            result[field.name] = value
        elseif field.bits and field.type == 'float' then
            local raw = reader:read(field.bits)
            result[field.name] = backend.convert_int_to_float(raw)
        elseif field.expr then
            result[field.name] = field.expr(result)
        elseif field.type == 'struct' then
            local sublayout = field.layout
            if type(sublayout) == 'function' then
                sublayout = sublayout(result)
            end
            result[field.name] = parse_layout(reader, sublayout, result)
        elseif field.type == 'array' then
            local count = result[field.count] or context[field.count] or field.count
            result[field.name] = {}
            for _ = 1, count do
                if #field.layout == 1 and field.layout[1].bits then
                    local value = reader:read(field.layout[1].bits)
                    if field.layout[1].signed then
                        local sign_bit = bit.band(value, bit.lshift(1, field.layout[1].bits - 1))
                        if sign_bit ~= 0 then
                            value = bit.bor(value, bit.bnot(bit.lshift(1, field.layout[1].bits) - 1))
                        end
                    end

                    result[field.name][#result[field.name]+1] = value
                elseif #field.layout == 1 and field.layout[1].type == 'string' then
                    -- Handle string arrays directly without nesting
                    local chars = {}
                    for _ = 1, field.layout[1].size do
                        chars[#chars+1] = string.char(reader:read(8))
                    end
                    local str = table.concat(chars):gsub('%z.*$', '')
                    result[field.name][#result[field.name]+1] = str
                else
                    -- Complex sub-struct
                    local nested_result = parse_layout(reader, field.layout, result)
                    result[field.name][#result[field.name]+1] = nested_result
                end
            end
        elseif field.type == 'string' then
            local chars = {}
            for _ = 1, field.size do
                chars[#chars+1] = string.char(reader:read(8))
            end
            result[field.name] = table.concat(chars):gsub('%z.*$', '')
        elseif field.type == 'raw' then
            local raw = {}
            for _ = 1, field.size do
                raw[#raw+1] = string.char(reader:read(8))
            end
            result[field.name] = table.concat(raw)
        elseif field.conditional then
            -- Read the conditional bit flag
            local has_flag = reader:read(field.bits)
            result[field.name] = has_flag > 0

            if result[field.name] then
                -- This is a nested struct format
                local struct_name = field.layout.name
                result[struct_name] = parse_layout(reader, field.layout.layout, result)
            end
        end
    end

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

    local newPacket = parse_layout(reader, definitions[dir][header.id], {})
    newPacket.header = header

    return newPacket
end

return parser
