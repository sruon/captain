-- Run from captain root directory
-- TODO: Nested structs
-- TODO: PVLV definitions
local definitions     = require('packets.definitions')

local lls_definitions = ''

local function processPacketLayout(packetId, packetLayout, direction)
    lls_definitions = lls_definitions ..
      string.format('---@class %s : ParsedPacket\n', PacketIdToName[direction][packetId])
    for _, field in ipairs(packetLayout) do
        if field.bits then
            lls_definitions = lls_definitions .. string.format('---@field %s number\n', field.name)
        elseif field.expr then
            -- TODO: Computed fields
            lls_definitions = lls_definitions .. string.format('---@field %s any -- Computed\n', field.name)
        elseif field.type == 'struct' then
            lls_definitions = lls_definitions .. string.format('---@field %s table -- Nested struct\n', field.name)
            -- TODO: Nested structs
        elseif field.type == 'array' then
            if #field.layout == 1 and field.layout[1].bits then
                lls_definitions = lls_definitions ..
                  string.format('---@field %s number[] -- Fixed size %d\n', field.name, field.count)
            elseif #field.layout == 1 and field.layout[1].type == 'string' then
                lls_definitions = lls_definitions ..
                  string.format('---@field %s string[] -- Fixed size %d\n', field.name, field.count)
            else
                lls_definitions = lls_definitions ..
                  string.format('---@field %s table[] -- Fixed size %s\n', field.name, field.count)
                -- TODO: Array of structs
            end
        elseif field.type == 'string' then
            lls_definitions = lls_definitions ..
              string.format('---@field %s string -- %d bytes\n', field.name, field.size)
        elseif field.type == 'raw' then
            if
              type(field.size) == 'number' or
              type(field.size) == 'string'
            then
                lls_definitions = lls_definitions ..
                  string.format('---@field %s any -- raw, %d bytes\n', field.name, field.size)
            elseif type(field.size) == 'function' then
                lls_definitions = lls_definitions ..
                  string.format('---@field %s any -- raw, computed bytes\n', field.name)
            end
        elseif field.conditional then
            lls_definitions = lls_definitions .. string.format('---@field %s boolean\n', field.name)
            for _, subfield in ipairs(field.layout) do
                lls_definitions = lls_definitions ..
                  string.format('---@field %s number? -- conditional based on %s\n', subfield.name, field.name)
            end
        end
    end
    lls_definitions = lls_definitions .. '\n'
end

local function main()
    lls_definitions = lls_definitions .. [[
---@class ParsedPacket
---@field header? { id: number, size: number, sync: number }

]]

    -- Process incoming packets
    for packetId, packetLayout in pairs(definitions.incoming) do
        processPacketLayout(packetId, packetLayout, 'incoming')
    end

    -- Process outgoing packets
    for packetId, packetLayout in pairs(definitions.outgoing) do
        processPacketLayout(packetId, packetLayout, 'outgoing')
    end

    local filePath = debug.getinfo(1, 'S').source:sub(2)
    local fileDir  = filePath:match('(.*/)')

    if not fileDir then
        fileDir = filePath:match('(.*\\)') or ''
    end

    local outputPath = fileDir .. 'packetTypes.lua'

    print('Output location: ' .. outputPath)

    local file = io.open(outputPath, 'w')
    if file then
        file:write(lls_definitions)
        file:close()
        print('Successfully generated packetTypes.lua')
    else
        print('Failed to create file at: ' .. outputPath)
        -- Fallback to current directory
        local file2 = io.open('packetTypes.lua', 'w')
        if file2 then
            file2:write(lls_definitions)
            file2:close()
            print('Fallback: Generated packetTypes.lua in current directory')
        else
            print('Failed to create file in any location')
        end
    end
end

main()
