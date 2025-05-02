require('libs/packets/packetId')

local TrackingListTbl_Type =
{
    PLAYER   = 0,
    FRIENDLY = 1,
    ENEMY    = 2,
}

-- Definitions _must_ match structures defined in the XiPackets documents
-- Definitions start from the 5th byte of the packet, as the first 4 bytes are reserved for the header.
-- There cannot be any gap in between fields as the parser will read a continuous stream of bits. This does not support arbitrary offsets.
-- Computed fields do not consume bits from the reader, and thus can be used to provide arbitrary aliases or helpers.
-- A computed field is defined by a function (expr) that returns a value.
-- Nested structs and layouts are supported.
-- Add the offsets in comments to help with cross-referencing with PVLV.
---@type { incoming: table<number, table>, outgoing: table<number, table> }
---@class PacketField
---@field name string                -- Field name, this will set the key in the table
---@field bits? integer              -- Number of bits to read
---@field size? integer              -- String only: Number of bytes to read
---@field count? integer|string      -- Array only: Number of elements in the array. Either numeric or a key in current context, for example if the count is provided in a separate field in the packet
---@field signed? boolean            -- Whether the field is signed or not. Most fields in XI packets are unsigned.
---@field type? string               -- Special field type handling, when the underlying value is not uint. Can be "string", "raw", "array", "struct", or "float"
---@field conditional? boolean       -- If set, will read 1 bit to determine if the nested struct should be read or not. Mostly for action packets that share the same space for different results.
---@field expr? fun():any            -- optional computed field function
---@field layout? table<PacketField> -- optional layout for nested structs, array

---@alias PacketLayout PacketField[]

---@class PacketDefinitions
---@field incoming table<PacketId, PacketLayout>
---@field outgoing table<PacketId, PacketLayout>

---@type PacketDefinitions
local definitions =
{
    incoming =
    {
        [PacketId.GP_SERV_COMMAND_PACKETCONTROL] =
        {
            { name = 'PacketCnt', bits = 32 }, -- 0x04
            {
                name = 'padding00',            -- 0x08 - 0x18
                type = 'array',
                count = 5,
                layout =
                {
                    { name = 'value', bits = 32 },
                },
            },
        },
        [PacketId.GP_SERV_COMMAND_ENTERZONE] =
        {
            {
                name = 'EnterZoneTbl', -- 0x04 - 0x33
                type = 'array',
                count = 48,
                layout =
                {
                    { name = 'value', bits = 8 },
                },
            },
        },
        [PacketId.GP_SERV_COMMAND_MESSAGE] =
        {
            { name = 'UniqueNo', bits = 32 }, -- 0x04
            { name = 'ActIndex', bits = 16 }, -- 0x08
            { name = 'MesNo',    bits = 16 }, -- 0x0A
            { name = 'Attr',     bits = 8 },  -- 0x0C
            -- TODO: Data field is a variable-length array
        },
        [PacketId.GP_SERV_COMMAND_LOGIN] =
        {
            {
                name = 'PosHead',
                type = 'struct',
                layout =
                {
                    { name = 'UniqueNo',      bits = 32 },                 -- 0x04-0x07
                    { name = 'ActIndex',      bits = 16 },                 -- 0x08-0x09
                    { name = 'padding00',     bits = 8 },                  -- 0x0A
                    { name = 'dir',           bits = 8,  signed = true },  -- 0x0B
                    { name = 'x',             bits = 32, type = 'float' }, -- 0x0C-0x0F
                    { name = 'z',             bits = 32, type = 'float' }, -- 0x10-0x13 Note that LSB and Game have this reversed with Y
                    { name = 'y',             bits = 32, type = 'float' }, -- 0x14-0x17
                    { name = 'flags1',        bits = 32 },                 -- 0x18-0x1B
                    { name = 'Speed',         bits = 8 },                  -- 0x1C
                    { name = 'SpeedBase',     bits = 8 },                  -- 0x1D
                    { name = 'HpMax',         bits = 8 },                  -- 0x1E
                    { name = 'server_status', bits = 8 },                  -- 0x1F
                    { name = 'flags2',        bits = 32 },                 -- 0x20-0x23
                    { name = 'flags3',        bits = 32 },                 -- 0x24-0x27
                    { name = 'flags4',        bits = 32 },                 -- 0x28-0x2B
                    { name = 'BtTargetID',    bits = 32 },                 -- 0x2C-0x2F
                },
            },
            { name = 'ZoneNo',    bits = 32 }, -- 0x30-0x33
            { name = 'ntTime',    bits = 32 }, -- 0x34-0x37
            { name = 'ntTimeSec', bits = 32 }, -- 0x38-0x3B
            { name = 'GameTime',  bits = 32 }, -- 0x3C-0x3F
            { name = 'EventNo',   bits = 16 }, -- 0x40-0x41
            { name = 'MapNumber', bits = 16 }, -- 0x42-0x43
            {
                name = 'GrapIDTbl',
                type = 'array',
                count = 9,
                layout =
                {
                    { name = 'value', bits = 16 },
                },
            }, -- 0x44-0x55
            {
                name = 'MusicNum',
                type = 'array',
                count = 5,
                layout =
                {
                    { name = 'value', bits = 16 },
                },
            },                                                          -- 0x56-0x5F
            { name = 'SubMapNumber',      bits = 16 },                  -- 0x60-0x61
            { name = 'EventNum',          bits = 16 },                  -- 0x62-0x63
            { name = 'EventPara',         bits = 16 },                  -- 0x64-0x65
            { name = 'EventMode',         bits = 16 },                  -- 0x66-0x67
            { name = 'WeatherNumber',     bits = 16 },                  -- 0x68-0x69
            { name = 'WeatherNumber2',    bits = 16 },                  -- 0x6A-0x6B
            { name = 'WeatherTime',       bits = 32 },                  -- 0x6C-0x6F
            { name = 'WeatherTime2',      bits = 32 },                  -- 0x70-0x73
            { name = 'WeatherOffsetTime', bits = 32 },                  -- 0x74-0x77
            { name = 'ShipStart',         bits = 32 },                  -- 0x78-0x7B
            { name = 'ShipEnd',           bits = 16 },                  -- 0x7C-0x7D
            { name = 'IsMonstrosity',     bits = 16 },                  -- 0x7E-0x7F
            { name = 'LoginState',        bits = 32 },                  -- 0x80-0x83
            { name = 'name',              type = 'string', size = 16 }, -- 0x84-0x93
            {
                name = 'certificate',
                type = 'array',
                count = 2,
                layout =
                {
                    { name = 'value', bits = 32 },
                },
            },                                                        -- 0x94-0x9B
            { name = 'unknown00',          bits = 16 },               -- 0x9C-0x9D
            { name = 'ZoneSubNo',          bits = 16 },               -- 0x9E-0x9F
            { name = 'PlayTime',           bits = 32 },               -- 0xA0-0xA3
            { name = 'DeadCounter',        bits = 32 },               -- 0xA4-0xA7
            { name = 'MyroomSubMapNumber', bits = 8 },                -- 0xA8
            { name = 'unknown01',          bits = 8 },                -- 0xA9
            { name = 'MyroomMapNumber',    bits = 16 },               -- 0xAA-0xAB
            { name = 'SendCount',          bits = 16 },               -- 0xAC-0xAD
            { name = 'MyRoomExitBit',      bits = 8 },                -- 0xAE
            { name = 'MogZoneFlag',        bits = 8 },                -- 0xAF
            { name = 'Dancer',             type = 'raw', size = 80 }, -- 0xB0-0xFF
            { name = 'ConfData',           type = 'raw', size = 12 }, -- 0x100-0x10B
            { name = 'Ex',                 bits = 32 },               -- 0x10C-0x10F
        },
        [PacketId.GP_SERV_COMMAND_LOGOUT] =
        {
            { name = 'LogoutState', bits = 32 }, -- 0x04-0x07

            {
                name = 'Iwasaki', -- 0x08-0x17
                type = 'array',
                count = 16,
                layout =
                {
                    { name = 'byte', bits = 8 },
                },
            },
            {
                name = 'GP_SERV_LOGOUTSUB', -- Derived from Iwasaki
                type = 'struct',
                expr = function(ctx)
                    local i = ctx.Iwasaki
                    if not i then
                        return { ip = '0.0.0.0', port = 0 }
                    end
                    return
                    {
                        ip = string.format('%d.%d.%d.%d', i[1] or 0, i[2] or 0, i[3] or 0, i[4] or 0),
                        port = (i[8] or 0) * 0x1000000 +
                          (i[7] or 0) * 0x10000 +
                          (i[6] or 0) * 0x100 +
                          (i[5] or 0),
                    }
                end,
            },
            { name = 'cliErrCode',  bits = 32 }, -- 0x18-0x1B
        },
        [PacketId.GP_SERV_COMMAND_TALKNUMWORK2] =
        {
            { name = 'UniqueNo',  bits = 32 }, -- 0x04
            { name = 'ActIndex',  bits = 16 }, -- 0x08
            { name = 'MesNum',    bits = 16 }, -- 0x0A
            { name = 'Type',      bits = 16 }, -- 0x0C
            { name = 'Flags',     bits = 8 },  -- 0x0E
            { name = 'padding00', bits = 8 },  -- 0x0F
            {
                name = 'Num1',
                type = 'array',
                count = 4,
                layout =
                {
                    { name = 'value', bits = 32 },
                },
            },                                                -- 0x10-0x1F
            { name = 'String1', type = 'string', size = 32 }, -- 0x20-0x3F
            { name = 'String2', type = 'string', size = 16 }, -- 0x40-0x4F
            {
                name = 'Num2',
                type = 'array',
                count = 8,
                layout =
                {
                    { bits = 32 },
                },
            }, -- 0x50-0x6F
            {
                name = 'SpeakerName',
                expr = function(ctx)
                    -- Local variable to store the name
                    local name = ''

                    -- Check if MesNum flag is not set
                    if bit.band(ctx.MesNum, 0x80000) == 0 then
                        -- Use String1 as the name initially
                        name = ctx.String1

                        -- Check if String2 has a valid string value or if Flags is set to 1
                        if (ctx.String2 and ctx.String2 ~= '' and ctx.String2:len() > 0) or (ctx.Flags and bit.band(ctx.Flags, 1) ~= 0) then
                            -- Check if the packet server id is a mob/npc
                            if bit.band(ctx.UniqueNo, 0xFF000000) ~= 0 then
                                local mob = backend.get_mob_by_index(ctx.ActIndex)
                                if mob then
                                    name = mob.name
                                end
                            elseif ctx.String2 and ctx.String2 ~= '' and ctx.String2:len() > 0 then
                                -- Use the String2 value if it's set as an override
                                name = ctx.String2
                            else
                                local pc = backend.get_mob_by_index(ctx.ActIndex)
                                if pc then
                                    name = pc.name
                                end
                            end
                        end
                        -- If MesNum flag is set, check if String2 should be used as the name
                    elseif ctx.String2 and ctx.String2 ~= '' and ctx.String2:len() > 0 and (ctx.Flags and bit.band(ctx.Flags, 2) ~= 0) then
                        name = ctx.String2
                    end

                    return name
                end,
            },
        },
        [PacketId.GP_SERV_COMMAND_TALKNUMWORK] =
        {
            { name = 'UniqueNo', bits = 32 },  -- 0x04 - The message entity server id
            {
                name = 'num',                  -- 0x08 - 0x17 - The message number parameters
                type = 'array',
                count = 4,
                layout =
                {
                    { name = 'value', bits = 32, signed = true },
                },
            },
            { name = 'ActIndex', bits = 16 },                   -- 0x18 - The message entity target index
            { name = 'MesNum',   bits = 16 },                   -- 0x1A - The message number and flag
            { name = 'Type',     bits = 8 },                    -- 0x1C - The message type
            { name = 'Flag',     bits = 8 },                    -- 0x1D - The message flag
            { name = 'String',   type = 'string', size = 32 },  -- 0x1E - The message string parameter
            {
                name = 'MessageNumber',
                expr = function(ctx)
                    return bit.band(ctx.MesNum or 0, 0x7FFF)
                end,
            },
            {
                name = 'IgnoreValidation',
                expr = function(ctx)
                    return bit.band(ctx.MesNum or 0, 0x8000) ~= 0
                end,
            },
            {
                name = 'TypeLookup',
                expr = function(ctx)
                    local type_lookup =
                    {
                        [0] = 0x8E,
                        [1] = 0xA1,
                        [2] = 0x90,
                        [3] = 0x91,
                        [4] = 0x92,
                        [5] = 0xA1,
                        [6] = 0x94,
                        [7] = 0x95,
                    }

                    if ctx.Type and ctx.Type < 8 then
                        return type_lookup[ctx.Type]
                    else
                        return type_lookup[0] -- Default to 0 for invalid types
                    end
                end,
            },
            {
                name = 'SpeakerName',
                expr = function(ctx)
                    -- Local variable to store the name
                    local name = ''

                    -- Skip event name setup check
                    if ctx.String and ctx.String ~= '' and ctx.Flag and not ctx.UniqueNo then
                        return ctx.String
                    end

                    -- Check if the MesNum flag is not set
                    if not ctx.IgnoreValidation then
                        -- We'd normally get entity name from ActIndex here
                        local entity = backend.get_mob_by_index(ctx.ActIndex)
                        if entity then
                            name = entity.name
                        end
                    elseif ctx.String and ctx.String ~= '' and ctx.Flag and not ctx.UniqueNo then
                        -- Use String as the entity name
                        name = ctx.String
                    end

                    return name
                end,
            },
        },
        [PacketId.GP_SERV_COMMAND_TALKNUM] =
        {
            { name = 'UniqueNo',  bits = 32 }, -- 0x04
            { name = 'ActIndex',  bits = 16 }, -- 0x08
            { name = 'MesNum',    bits = 16 }, -- 0x0A
            { name = 'Type',      bits = 8 },  -- 0x0C
            { name = 'padding00', bits = 8 },  -- 0x0D
            { name = 'padding01', bits = 16 }, -- 0x0E
        },
        [PacketId.GP_SERV_COMMAND_PENDINGNUM] =
        {
            {
                name = 'num', -- 0x04 - 0x23
                type = 'array',
                count = 8,
                layout =
                {
                    { name = 'value', bits = 32, signed = true },
                },
            },
        },
        [PacketId.GP_SERV_COMMAND_EVENTNUM] =
        {
            { name = 'UniqueNo',   bits = 32 }, -- 0x04
            {
                name = 'num',                   -- 0x08 - 0x27
                type = 'array',
                count = 8,
                layout =
                {
                    { name = 'value', bits = 32, signed = true },
                },
            },
            { name = 'ActIndex',   bits = 16 }, -- 0x28
            { name = 'EventNum',   bits = 16 }, -- 0x2A
            { name = 'EventPara',  bits = 16 }, -- 0x2C
            { name = 'Mode',       bits = 16 }, -- 0x2E
            { name = 'EventNum2',  bits = 16 }, -- 0x30
            { name = 'EventPara2', bits = 16 }, -- 0x32
        },
        [PacketId.GP_SERV_COMMAND_WPOS] =
        {
            { name = 'x',         bits = 32, type = 'float' }, -- 0x04
            { name = 'y',         bits = 32, type = 'float' }, -- 0x08
            { name = 'z',         bits = 32, type = 'float' }, -- 0x0C
            { name = 'UniqueNo',  bits = 32 },                 -- 0x10
            { name = 'ActIndex',  bits = 16 },                 -- 0x14
            { name = 'Mode',      bits = 8 },                  -- 0x16
            { name = 'dir',       bits = 8,  signed = true },  -- 0x17
            { name = 'padding00', bits = 32 },                 -- 0x18
        },
        [PacketId.GP_SERV_COMMAND_EVENT] =
        {
            { name = 'UniqueNo',   bits = 32 }, -- 0x04
            { name = 'ActIndex',   bits = 16 }, -- 0x08
            { name = 'EventNum',   bits = 16 }, -- 0x0A
            { name = 'EventPara',  bits = 16 }, -- 0x0C
            { name = 'Mode',       bits = 16 }, -- 0x0E
            { name = 'EventNum2',  bits = 16 }, -- 0x10
            { name = 'EventPara2', bits = 16 }, -- 0x12
        },
        [PacketId.GP_SERV_COMMAND_EVENTSTR] =
        {
            { name = 'UniqueNo',  bits = 32 }, -- 0x04 - The event entity server id
            { name = 'ActIndex',  bits = 16 }, -- 0x08 - The event entity target index
            { name = 'EventNum',  bits = 16 }, -- 0x0A - The event number
            { name = 'EventPara', bits = 16 }, -- 0x0C - The event param
            { name = 'Mode',      bits = 16 }, -- 0x0E - The event mode
            {
                name = 'String',               -- 0x10 - 0x4F - The event string parameters
                type = 'array',
                count = 4,
                layout =
                {
                    { name = 'value', type = 'string', size = 16 },
                },
            },
            {
                name = 'Data', -- 0x50 - 0x6F - The event data
                type = 'array',
                count = 8,
                layout =
                {
                    { name = 'value', bits = 32 },
                },
            },
        },
        [PacketId.GP_SERV_COMMAND_SCHEDULOR] =
        {
            { name = 'UniqueNoCas',  bits = 32 }, -- 0x04 - The caster entity server id
            { name = 'UniqueNoTar',  bits = 32 }, -- 0x08 - The target entity server id
            { name = 'id',           bits = 32 }, -- 0x0C - The 'FourCC' code tag for the scheduler to load
            { name = 'ActIndexCast', bits = 16 }, -- 0x10 - The caster entity target index
            { name = 'ActIndexTar',  bits = 16 }, -- 0x12 - The target entity target index
            {
                name = 'FourCCString',
                expr = function(ctx)
                    if not ctx.id then return 'NONE' end

                    -- Convert the 32-bit integer to a 4-character string (FourCC)
                    local b1 = bit.band(ctx.id, 0xFF)
                    local b2 = bit.band(bit.rshift(ctx.id, 8), 0xFF)
                    local b3 = bit.band(bit.rshift(ctx.id, 16), 0xFF)
                    local b4 = bit.band(bit.rshift(ctx.id, 24), 0xFF)

                    return string.char(b1, b2, b3, b4)
                end,
            },
        },
        [PacketId.GP_SERV_COMMAND_MAPSCHEDULOR] =
        {
            { name = 'UniqueNoCas',  bits = 32 }, -- 0x04 - The caster entity server id
            { name = 'UniqueNoTar',  bits = 32 }, -- 0x08 - The target entity server id
            { name = 'id',           bits = 32 }, -- 0x0C - The 'FourCC' code tag for the scheduler to load
            { name = 'ActIndexCast', bits = 16 }, -- 0x10 - The caster entity target index
            { name = 'ActIndexTar',  bits = 16 }, -- 0x12 - The target entity target index
            {
                name = 'FourCCString',
                expr = function(ctx)
                    if not ctx.id then return 'NONE' end

                    -- Convert the 32-bit integer to a 4-character string (FourCC)
                    local b1 = bit.band(ctx.id, 0xFF)
                    local b2 = bit.band(bit.rshift(ctx.id, 8), 0xFF)
                    local b3 = bit.band(bit.rshift(ctx.id, 16), 0xFF)
                    local b4 = bit.band(bit.rshift(ctx.id, 24), 0xFF)

                    return string.char(b1, b2, b3, b4)
                end,
            },
        },
        [PacketId.GP_SERV_COMMAND_MAGICSCHEDULOR] =
        {
            { name = 'UniqueNoCas',  bits = 32 }, -- 0x04 - The caster entity server id
            { name = 'UniqueNoTar',  bits = 32 }, -- 0x08 - The target entity server id
            { name = 'ActIndexCast', bits = 16 }, -- 0x0C - The caster entity target index
            { name = 'ActIndexTar',  bits = 16 }, -- 0x0E - The target entity target index
            { name = 'fileNum',      bits = 16 }, -- 0x10 - The scheduler file id to be loaded
            { name = 'type',         bits = 8 },  -- 0x12 - The scheduler type
            { name = 'padding00',    bits = 8 },  -- 0x13 - Padding; unused
            {
                name = 'TypeName',
                expr = function(ctx)
                    local type_names =
                    {
                        [0x00] = '0x00 - Cast Spell',
                        [0x01] = '0x01 - Use Item',
                        [0x02] = '0x02 - Ability',
                        [0x03] = '0x03 - Event Related (Misc events, banner announcements)',
                        [0x04] = '0x04 - Event Related (Misc events, NPC weaponskills)',
                        [0x05] = '0x05 - Unknown (Misc abilities, banners)',
                        [0x06] = '0x06 - Weapon Skills',
                        [0x07] = '0x07 - Unknown',
                        [0x08] = '0x08 - Unknown (Misc abilities, banners)',
                        [0x09] = '0x09 - Monster Skills',
                        [0x0A] = '0x0A - Unknown (Warping animations)',
                        [0x0B] = '0x0B - Unknown (Banner announcements)',
                        [0x0C] = '0x0C - Unknown (Casting animations)',
                    }

                    if ctx.type and ctx.type <= 0x0C then
                        return type_names[ctx.type]
                    end

                    return string.format('0x%02X - Unknown', ctx.type or 0)
                end,
            },
        },
        [PacketId.GP_SERV_COMMAND_EVENTMES] =
        {
            { name = 'UniqueNo', bits = 32 },  -- 0x04 - The message entities server id
            { name = 'ActIndex', bits = 16 },  -- 0x08 - The message entities target index
            { name = 'Number',   bits = 16 },  -- 0x0A - The message number
            {
                name = 'MessageNumber',
                expr = function(ctx)
                    return bit.band(ctx.Number or 0, 0x7FFF)
                end,
            },
            {
                name = 'UseEntityName',
                expr = function(ctx)
                    return bit.band(ctx.Number or 0, 0x8000) ~= 0
                end,
            },
        },
        [PacketId.GP_SERV_COMMAND_TALKNUMNAME] =
        {
            { name = 'UniqueNo',  bits = 32 },                   -- 0x04 - The message entity server id
            { name = 'ActIndex',  bits = 16 },                   -- 0x08 - The message entity target index
            { name = 'MesNum',    bits = 16 },                   -- 0x0A - The message number
            { name = 'Type',      bits = 8 },                    -- 0x0C - The message type
            { name = 'padding00', bits = 8 },                    -- 0x0D - Padding; unused
            { name = 'padding01', bits = 16 },                   -- 0x0E - Padding; unused
            { name = 'sName',     type = 'string', size = 16 },  -- 0x10 - The message name
            {
                name = 'MessageNumber',
                expr = function(ctx)
                    return bit.band(ctx.MesNum or 0, 0x7FFF)
                end,
            },
            {
                name = 'IgnoreValidation',
                expr = function(ctx)
                    return bit.band(ctx.MesNum or 0, 0x8000) ~= 0
                end,
            },
            {
                name = 'TypeLookup',
                expr = function(ctx)
                    local type_lookup =
                    {
                        [0] = 0x8E,
                        [1] = 0xA1,
                        [2] = 0x90,
                        [3] = 0x91,
                        [4] = 0x92,
                        [5] = 0xA1,
                        [6] = 0x94,
                        [7] = 0x95,
                    }

                    if ctx.Type and ctx.Type < 8 then
                        return type_lookup[ctx.Type]
                    else
                        return type_lookup[0] -- Default to 0 for invalid types
                    end
                end,
            },
        },
        [PacketId.GP_SERV_COMMAND_CHAR_PC] =
        {
            { name = 'UniqueNo', bits = 32 }, -- 0x04-0x07
            { name = 'ActIndex', bits = 16 }, -- 0x08-0x09

            -- sendflags_t (bitfield at 0x0A)
            {
                name = 'SendFlg_num',
                bits = 8, -- 0x0A
            },
            {
                name = 'SendFlg',
                expr = function(ctx)
                    local flags       = {}

                    flags.Position    = bit.band(ctx.SendFlg_num, 0x01) ~= 0 -- 0x0A.0
                    flags.ClaimStatus = bit.band(ctx.SendFlg_num, 0x02) ~= 0 -- 0x0A.1
                    flags.General     = bit.band(ctx.SendFlg_num, 0x04) ~= 0 -- 0x0A.2
                    flags.Name        = bit.band(ctx.SendFlg_num, 0x08) ~= 0 -- 0x0A.3
                    flags.Model       = bit.band(ctx.SendFlg_num, 0x10) ~= 0 -- 0x0A.4
                    flags.Despawn     = bit.band(ctx.SendFlg_num, 0x20) ~= 0 -- 0x0A.5
                    flags.unused      = bit.band(ctx.SendFlg_num, 0xC0) ~= 0 -- 0x0A.6-0x0A.7

                    return flags
                end,
            },

            { name = 'dir', bits = 8 },                  -- 0x0B
            { name = 'x',   bits = 32, type = 'float' }, -- 0x0C-0x0F
            { name = 'z',   bits = 32, type = 'float' }, -- 0x10-0x13
            { name = 'y',   bits = 32, type = 'float' }, -- 0x14-0x17

            {
                name = 'Flags0_num',
                bits = 32, -- 0x18-0x1B
            },
            {
                name = 'Flags0',
                expr = function(ctx)
                    local flags       = {}

                    flags.MovTime     = bit.band(ctx.Flags0_num, 0x1FFF)                 -- 0x18.0-0x18.4, 0x19.0-0x19.7 (bits 0-12, 13 bits)
                    flags.RunMode     = bit.band(bit.rshift(ctx.Flags0_num, 13), 0x01)   -- 0x19.5 (bit 13)
                    flags.unknown_1_6 = bit.band(bit.rshift(ctx.Flags0_num, 14), 0x01)   -- 0x19.6 (bit 14)
                    flags.GroundFlag  = bit.band(bit.rshift(ctx.Flags0_num, 15), 0x01)   -- 0x19.7 (bit 15)
                    flags.KingFlag    = bit.band(bit.rshift(ctx.Flags0_num, 16), 0x01)   -- 0x1A.0 (bit 16)
                    flags.facetarget  = bit.band(bit.rshift(ctx.Flags0_num, 17), 0x7FFF) -- 0x1A.1-0x1A.7, 0x1B.0-0x1B.7 (bits 17-31, 15 bits)

                    return flags
                end,
            },

            { name = 'Speed',         bits = 8 }, -- 0x1C
            { name = 'SpeedBase',     bits = 8 }, -- 0x1D
            { name = 'Hpp',           bits = 8 }, -- 0x1E
            { name = 'server_status', bits = 8 }, -- 0x1F

            {
                name = 'Flags1_num',
                bits = 32, -- 0x20-0x23
            },
            {
                name = 'Flags1',
                expr = function(ctx)
                    local flags           = {}
                    local n               = ctx.Flags1_num

                    flags.MonsterFlag     = bit.band(bit.rshift(n, 0), 0x01)  -- 0x20.0 (bit 0)
                    flags.HideFlag        = bit.band(bit.rshift(n, 1), 0x01)  -- 0x20.1 (bit 1)
                    flags.SleepFlag       = bit.band(bit.rshift(n, 2), 0x01)  -- 0x20.2 (bit 2)
                    flags.unknown_0_3     = bit.band(bit.rshift(n, 3), 0x01)  -- 0x20.3 (bit 3)
                    flags.unknown_0_4     = bit.band(bit.rshift(n, 4), 0x01)  -- 0x20.4 (bit 4)
                    flags.ChocoboIndex    = bit.band(bit.rshift(n, 5), 0x07)  -- 0x20.5-0x20.7 (bits 5-7, 3 bits)
                    flags.CliPosInitFlag  = bit.band(bit.rshift(n, 8), 0x01)  -- 0x21.0 (bit 8)
                    flags.GraphSize       = bit.band(bit.rshift(n, 9), 0x03)  -- 0x21.1-0x21.2 (bits 9-10, 2 bits)
                    flags.LfgFlag         = bit.band(bit.rshift(n, 11), 0x01) -- 0x21.3 (bit 11)
                    flags.AnonymousFlag   = bit.band(bit.rshift(n, 12), 0x01) -- 0x21.4 (bit 12)
                    flags.YellFlag        = bit.band(bit.rshift(n, 13), 0x01) -- 0x21.5 (bit 13)
                    flags.AwayFlag        = bit.band(bit.rshift(n, 14), 0x01) -- 0x21.6 (bit 14)
                    flags.Gender          = bit.band(bit.rshift(n, 15), 0x01) -- 0x21.7 (bit 15)
                    flags.PlayOnelineFlag = bit.band(bit.rshift(n, 16), 0x01) -- 0x22.0 (bit 16)
                    flags.LinkShellFlag   = bit.band(bit.rshift(n, 17), 0x01) -- 0x22.1 (bit 17)
                    flags.LinkDeadFlag    = bit.band(bit.rshift(n, 18), 0x01) -- 0x22.2 (bit 18)
                    flags.TargetOffFlag   = bit.band(bit.rshift(n, 19), 0x01) -- 0x22.3 (bit 19)
                    flags.TalkUcoffFlag   = bit.band(bit.rshift(n, 20), 0x01) -- 0x22.4 (bit 20)
                    flags.unknown_2_5     = bit.band(bit.rshift(n, 21), 0x01) -- 0x22.5 (bit 21)
                    flags.unknown_2_6     = bit.band(bit.rshift(n, 22), 0x01) -- 0x22.6 (bit 22)
                    flags.unknown_2_7     = bit.band(bit.rshift(n, 23), 0x01) -- 0x22.7 (bit 23)
                    flags.GmLevel         = bit.band(bit.rshift(n, 24), 0x07) -- 0x23.0-0x23.2 (bits 24-26, 3 bits)
                    flags.HackMove        = bit.band(bit.rshift(n, 27), 0x01) -- 0x23.3 (bit 27)
                    flags.unknown_3_4     = bit.band(bit.rshift(n, 28), 0x01) -- 0x23.4 (bit 28)
                    flags.InvisFlag       = bit.band(bit.rshift(n, 29), 0x01) -- 0x23.5 (bit 29)
                    flags.TurnFlag        = bit.band(bit.rshift(n, 30), 0x01) -- 0x23.6 (bit 30)
                    flags.BazaarFlag      = bit.band(bit.rshift(n, 31), 0x01) -- 0x23.7 (bit 31)

                    return flags
                end,
            },

            {
                name = 'Flags2_num',
                bits = 32, -- 0x24-0x27
            },
            {
                name = 'Flags2',
                expr = function(ctx)
                    local flags         = {}
                    local n             = ctx.Flags2_num

                    flags.r             = bit.band(bit.rshift(n, 0), 0xFF)  -- 0x24.0-0x24.7 (bits 0-7)
                    flags.g             = bit.band(bit.rshift(n, 8), 0xFF)  -- 0x25.0-0x25.7 (bits 8-15)
                    flags.b             = bit.band(bit.rshift(n, 16), 0xFF) -- 0x26.0-0x26.7 (bits 16-23)
                    flags.PvPFlag       = bit.band(bit.rshift(n, 24), 0x01) -- 0x27.0 (bit 24)
                    flags.ShadowFlag    = bit.band(bit.rshift(n, 25), 0x01) -- 0x27.1 (bit 25)
                    flags.ShipStartMode = bit.band(bit.rshift(n, 26), 0x01) -- 0x27.2 (bit 26)
                    flags.CharmFlag     = bit.band(bit.rshift(n, 27), 0x01) -- 0x27.3 (bit 27)
                    flags.GmIconFlag    = bit.band(bit.rshift(n, 28), 0x01) -- 0x27.4 (bit 28)
                    flags.NamedFlag     = bit.band(bit.rshift(n, 29), 0x01) -- 0x27.5 (bit 29)
                    flags.SingleFlag    = bit.band(bit.rshift(n, 30), 0x01) -- 0x27.6 (bit 30)
                    flags.AutoPartyFlag = bit.band(bit.rshift(n, 31), 0x01) -- 0x27.7 (bit 31)

                    return flags
                end,
            },

            {
                name = 'Flags3_num',
                bits = 32, -- 0x28-0x2B
            },
            {
                name = 'Flags3',
                expr = function(ctx)
                    local flags            = {}
                    local n                = ctx.Flags3_num

                    flags.TrustFlag        = bit.band(bit.rshift(n, 0), 0x01)  -- 0x28.0 (bit 0)
                    flags.LfgMasterFlag    = bit.band(bit.rshift(n, 1), 0x01)  -- 0x28.1 (bit 1)
                    flags.PetNewFlag       = bit.band(bit.rshift(n, 2), 0x01)  -- 0x28.2 (bit 2)
                    flags.unknown_0_3      = bit.band(bit.rshift(n, 3), 0x01)  -- 0x28.3 (bit 3)
                    flags.MotStopFlag      = bit.band(bit.rshift(n, 4), 0x01)  -- 0x28.4 (bit 4)
                    flags.CliPriorityFlag  = bit.band(bit.rshift(n, 5), 0x01)  -- 0x28.5 (bit 5)
                    flags.PetFlag          = bit.band(bit.rshift(n, 6), 0x01)  -- 0x28.6 (bit 6)
                    flags.OcclusionoffFlag = bit.band(bit.rshift(n, 7), 0x01)  -- 0x28.7 (bit 7)
                    flags.BallistaTeam     = bit.band(bit.rshift(n, 8), 0xFF)  -- 0x29.0-0x29.7 (bits 8-15)
                    flags.MonStat          = bit.band(bit.rshift(n, 16), 0x07) -- 0x2A.0-0x2A.2 (bits 16-18, 3 bits)
                    flags.unknown_2_3      = bit.band(bit.rshift(n, 19), 0x01) -- 0x2A.3 (bit 19)
                    flags.unknown_2_4      = bit.band(bit.rshift(n, 20), 0x01) -- 0x2A.4 (bit 20)
                    flags.SilenceFlag      = bit.band(bit.rshift(n, 21), 0x01) -- 0x2A.5 (bit 21)
                    flags.unknown_2_6      = bit.band(bit.rshift(n, 22), 0x01) -- 0x2A.6 (bit 22)
                    flags.NewCharacterFlag = bit.band(bit.rshift(n, 23), 0x01) -- 0x2A.7 (bit 23)
                    flags.MentorFlag       = bit.band(bit.rshift(n, 24), 0x01) -- 0x2B.0 (bit 24)
                    flags.unknown_3_1      = bit.band(bit.rshift(n, 25), 0x01) -- 0x2B.1 (bit 25)
                    flags.unknown_3_2      = bit.band(bit.rshift(n, 26), 0x01) -- 0x2B.2 (bit 26)
                    flags.unknown_3_3      = bit.band(bit.rshift(n, 27), 0x01) -- 0x2B.3 (bit 27)
                    flags.unknown_3_4      = bit.band(bit.rshift(n, 28), 0x01) -- 0x2B.4 (bit 28)
                    flags.unknown_3_5      = bit.band(bit.rshift(n, 29), 0x01) -- 0x2B.5 (bit 29)
                    flags.unknown_3_6      = bit.band(bit.rshift(n, 30), 0x01) -- 0x2B.6 (bit 30)
                    flags.unknown_3_7      = bit.band(bit.rshift(n, 31), 0x01) -- 0x2B.7 (bit 31)

                    return flags
                end,
            },

            { name = 'BtTargetID',   bits = 32 }, -- 0x2C-0x2F

            -- New fields in GP_SERV_CHAR_PC
            { name = 'CostumeId',    bits = 16 }, -- 0x30-0x31
            { name = 'BallistaInfo', bits = 8 },  -- 0x32

            {
                name = 'Flags4_num',
                bits = 8, -- 0x33
            },
            {
                name = 'Flags4',
                expr = function(ctx)
                    local flags         = {}
                    local n             = ctx.Flags4_num

                    flags.unknown_0_0   = bit.band(bit.rshift(n, 0), 0x01) -- 0x33.0 (bit 0)
                    flags.TrialFlag     = bit.band(bit.rshift(n, 1), 0x01) -- 0x33.1 (bit 1)
                    flags.unknown_0_2   = bit.band(bit.rshift(n, 2), 0x03) -- 0x33.2-0x33.3 (bits 2-3, 2 bits)
                    flags.unknown_0_4   = bit.band(bit.rshift(n, 4), 0x03) -- 0x33.4-0x33.5 (bits 4-5, 2 bits)
                    flags.JobMasterFlag = bit.band(bit.rshift(n, 6), 0x01) -- 0x33.6 (bit 6)
                    flags.unknown_0_7   = bit.band(bit.rshift(n, 7), 0x01) -- 0x33.7 (bit 7)

                    return flags
                end,
            },

            {
                name = 'CustomProperties', -- 0x34-0x3B
                type = 'array',
                count = 2,
                layout =
                {
                    { name = 'value', bits = 32 },
                },
            },

            { name = 'PetActIndex',        bits = 16 }, -- 0x3C-0x3D
            { name = 'MonstrosityFlags',   bits = 16 }, -- 0x3E-0x3F
            { name = 'MonstrosityNameId1', bits = 8 },  -- 0x40
            { name = 'MonstrosityNameId2', bits = 8 },  -- 0x41

            {
                name = 'Flags5_num',
                bits = 8, -- 0x42
            },
            {
                name = 'Flags5',
                expr = function(ctx)
                    local flags          = {}
                    local n              = ctx.Flags5_num

                    flags.GeoIndiElement = bit.band(bit.rshift(n, 0), 0x0F) -- 0x42.0-0x42.3 (bits 0-3, 4 bits)
                    flags.GeoIndiSize    = bit.band(bit.rshift(n, 4), 0x03) -- 0x42.4-0x42.5 (bits 4-5, 2 bits)
                    flags.GeoIndiFlag    = bit.band(bit.rshift(n, 6), 0x01) -- 0x42.6 (bit 6)
                    flags.unknown_0_7    = bit.band(bit.rshift(n, 7), 0x01) -- 0x42.7 (bit 7)

                    return flags
                end,
            },

            { name = 'ModelHitboxSize', bits = 8 }, -- 0x43

            {
                name = 'Flags6_num',
                bits = 32, -- 0x44-0x47
            },
            {
                name = 'Flags6',
                expr = function(ctx)
                    local flags       = {}
                    local n           = ctx.Flags6_num

                    flags.GateId      = bit.band(bit.rshift(n, 0), 0x0F)     -- 0x44.0-0x44.3 (bits 0-3, 4 bits)
                    flags.MountIndex  = bit.band(bit.rshift(n, 4), 0xFF)     -- 0x44.4-0x44.7, 0x45.0-0x45.3 (bits 4-11, 8 bits)
                    flags.unknown_1_3 = bit.band(bit.rshift(n, 12), 0xFFFFF) -- 0x45.4-0x45.7, 0x46.0-0x46.7, 0x47.0-0x47.7 (bits 12-31, 20 bits)

                    return flags
                end,
            },

            {
                name = 'GrapIDTbl', -- 0x48-0x59
                type = 'array',
                count = 9,
                layout =
                {
                    { name = 'value', bits = 16 },
                },
            },

            { name = 'name',            type = 'string', size = 16 }, -- 0x5A-0x69
        },
        [PacketId.GP_SERV_COMMAND_CHAR_NPC] =
        {
            { name = 'UniqueNo', bits = 32 }, -- 0x04-0x07
            { name = 'ActIndex', bits = 16 }, -- 0x08-0x09

            -- sendflags_t (bitfield at 0x0A)
            {
                name = 'SendFlg_num',
                bits = 8, -- 0x0A
            },
            {
                name = 'SendFlg',
                expr = function(ctx)
                    local flags       = {}

                    flags.Position    = bit.band(ctx.SendFlg_num, 0x01) ~= 0 -- 0x0A.0
                    flags.ClaimStatus = bit.band(ctx.SendFlg_num, 0x02) ~= 0 -- 0x0A.1
                    flags.General     = bit.band(ctx.SendFlg_num, 0x04) ~= 0 -- 0x0A.2
                    flags.Name        = bit.band(ctx.SendFlg_num, 0x08) ~= 0 -- 0x0A.3
                    flags.Model       = bit.band(ctx.SendFlg_num, 0x10) ~= 0 -- 0x0A.4
                    flags.Despawn     = bit.band(ctx.SendFlg_num, 0x20) ~= 0 -- 0x0A.5
                    flags.Name2       = bit.band(ctx.SendFlg_num, 0x40) ~= 0 -- 0x0A.6
                    flags.unused      = bit.band(ctx.SendFlg_num, 0x80) ~= 0 -- 0x0A.7

                    return flags
                end,
            },

            { name = 'dir', bits = 8 },                  -- 0x0B
            { name = 'x',   bits = 32, type = 'float' }, -- 0x0C-0x0F
            { name = 'z',   bits = 32, type = 'float' }, -- 0x10-0x13
            { name = 'y',   bits = 32, type = 'float' }, -- 0x14-0x17

            {
                name = 'Flags0_num',
                bits = 32, -- 0x18-0x1B
            },
            {
                name = 'Flags0',
                expr = function(ctx)
                    local flags       = {}

                    flags.MovTime     = bit.band(ctx.Flags0_num, 0x1FFF)                 -- 0x18.0-0x18.4, 0x19.0-0x19.7 (bits 0-12, 13 bits)
                    flags.RunMode     = bit.band(bit.rshift(ctx.Flags0_num, 13), 0x01)   -- 0x19.5 (bit 13)
                    flags.unknown_1_6 = bit.band(bit.rshift(ctx.Flags0_num, 14), 0x01)   -- 0x19.6 (bit 14)
                    flags.GroundFlag  = bit.band(bit.rshift(ctx.Flags0_num, 15), 0x01)   -- 0x19.7 (bit 15)
                    flags.KingFlag    = bit.band(bit.rshift(ctx.Flags0_num, 16), 0x01)   -- 0x1A.0 (bit 16)
                    flags.facetarget  = bit.band(bit.rshift(ctx.Flags0_num, 17), 0x7FFF) -- 0x1A.1-0x1A.7, 0x1B.0-0x1B.7 (bits 17-31, 15 bits)

                    return flags
                end,
            },
            { name = 'Speed',         bits = 8 }, -- 0x1C
            { name = 'SpeedBase',     bits = 8 }, -- 0x1D
            { name = 'Hpp',           bits = 8 }, -- 0x1E
            { name = 'server_status', bits = 8 }, -- 0x1F

            {
                name = 'Flags1_num',
                bits = 32, -- 0x20-0x23
            },
            {
                name = 'Flags1',
                expr = function(ctx)
                    local flags           = {}
                    local n               = ctx.Flags1_num

                    flags.MonsterFlag     = bit.band(bit.rshift(n, 0), 0x01)  -- 0x20.0 (bit 0)
                    flags.HideFlag        = bit.band(bit.rshift(n, 1), 0x01)  -- 0x20.1 (bit 1)
                    flags.SleepFlag       = bit.band(bit.rshift(n, 2), 0x01)  -- 0x20.2 (bit 2)
                    flags.unknown_0_3     = bit.band(bit.rshift(n, 3), 0x01)  -- 0x20.3 (bit 3)
                    flags.unknown_0_4     = bit.band(bit.rshift(n, 4), 0x01)  -- 0x20.4 (bit 4)
                    flags.ChocoboIndex    = bit.band(bit.rshift(n, 5), 0x07)  -- 0x20.5-0x20.7 (bits 5-7, 3 bits)
                    flags.CliPosInitFlag  = bit.band(bit.rshift(n, 8), 0x01)  -- 0x21.0 (bit 8)
                    flags.GraphSize       = bit.band(bit.rshift(n, 9), 0x03)  -- 0x21.1-0x21.2 (bits 9-10, 2 bits)
                    flags.LfgFlag         = bit.band(bit.rshift(n, 11), 0x01) -- 0x21.3 (bit 11)
                    flags.AnonymousFlag   = bit.band(bit.rshift(n, 12), 0x01) -- 0x21.4 (bit 12)
                    flags.YellFlag        = bit.band(bit.rshift(n, 13), 0x01) -- 0x21.5 (bit 13)
                    flags.AwayFlag        = bit.band(bit.rshift(n, 14), 0x01) -- 0x21.6 (bit 14)
                    flags.Gender          = bit.band(bit.rshift(n, 15), 0x01) -- 0x21.7 (bit 15)
                    flags.PlayOnelineFlag = bit.band(bit.rshift(n, 16), 0x01) -- 0x22.0 (bit 16)
                    flags.LinkShellFlag   = bit.band(bit.rshift(n, 17), 0x01) -- 0x22.1 (bit 17)
                    flags.LinkDeadFlag    = bit.band(bit.rshift(n, 18), 0x01) -- 0x22.2 (bit 18)
                    flags.TargetOffFlag   = bit.band(bit.rshift(n, 19), 0x01) -- 0x22.3 (bit 19)
                    flags.TalkUcoffFlag   = bit.band(bit.rshift(n, 20), 0x01) -- 0x22.4 (bit 20)
                    flags.unknown_2_5     = bit.band(bit.rshift(n, 21), 0x01) -- 0x22.5 (bit 21)
                    flags.unknown_2_6     = bit.band(bit.rshift(n, 22), 0x01) -- 0x22.6 (bit 22)
                    flags.unknown_2_7     = bit.band(bit.rshift(n, 23), 0x01) -- 0x22.7 (bit 23)
                    flags.GmLevel         = bit.band(bit.rshift(n, 24), 0x07) -- 0x23.0-0x23.2 (bits 24-26, 3 bits)
                    flags.HackMove        = bit.band(bit.rshift(n, 27), 0x01) -- 0x23.3 (bit 27)
                    flags.unknown_3_4     = bit.band(bit.rshift(n, 28), 0x01) -- 0x23.4 (bit 28)
                    flags.InvisFlag       = bit.band(bit.rshift(n, 29), 0x01) -- 0x23.5 (bit 29)
                    flags.TurnFlag        = bit.band(bit.rshift(n, 30), 0x01) -- 0x23.6 (bit 30)
                    flags.BazaarFlag      = bit.band(bit.rshift(n, 31), 0x01) -- 0x23.7 (bit 31)

                    return flags
                end,
            },

            {
                name = 'Flags2_num',
                bits = 32, -- 0x24-0x27
            },
            {
                name = 'Flags2',
                expr = function(ctx)
                    local flags         = {}
                    local n             = ctx.Flags2_num

                    flags.r             = bit.band(bit.rshift(n, 0), 0xFF)  -- 0x24.0-0x24.7 (bits 0-7)
                    flags.g             = bit.band(bit.rshift(n, 8), 0xFF)  -- 0x25.0-0x25.7 (bits 8-15)
                    flags.b             = bit.band(bit.rshift(n, 16), 0xFF) -- 0x26.0-0x26.7 (bits 16-23)
                    flags.PvPFlag       = bit.band(bit.rshift(n, 24), 0x01) -- 0x27.0 (bit 24)
                    flags.ShadowFlag    = bit.band(bit.rshift(n, 25), 0x01) -- 0x27.1 (bit 25)
                    flags.ShipStartMode = bit.band(bit.rshift(n, 26), 0x01) -- 0x27.2 (bit 26)
                    flags.CharmFlag     = bit.band(bit.rshift(n, 27), 0x01) -- 0x27.3 (bit 27)
                    flags.GmIconFlag    = bit.band(bit.rshift(n, 28), 0x01) -- 0x27.4 (bit 28)
                    flags.NamedFlag     = bit.band(bit.rshift(n, 29), 0x01) -- 0x27.5 (bit 29)
                    flags.SingleFlag    = bit.band(bit.rshift(n, 30), 0x01) -- 0x27.6 (bit 30)
                    flags.AutoPartyFlag = bit.band(bit.rshift(n, 31), 0x01) -- 0x27.7 (bit 31)

                    return flags
                end,
            },

            {
                name = 'Flags3_num',
                bits = 32, -- 0x28-0x2B
            },
            {
                name = 'Flags3',
                expr = function(ctx)
                    local flags            = {}
                    local n                = ctx.Flags3_num

                    flags.TrustFlag        = bit.band(bit.rshift(n, 0), 0x01)  -- 0x28.0 (bit 0)
                    flags.LfgMasterFlag    = bit.band(bit.rshift(n, 1), 0x01)  -- 0x28.1 (bit 1)
                    flags.PetNewFlag       = bit.band(bit.rshift(n, 2), 0x01)  -- 0x28.2 (bit 2)
                    flags.unknown_0_3      = bit.band(bit.rshift(n, 3), 0x01)  -- 0x28.3 (bit 3)
                    flags.MotStopFlag      = bit.band(bit.rshift(n, 4), 0x01)  -- 0x28.4 (bit 4)
                    flags.CliPriorityFlag  = bit.band(bit.rshift(n, 5), 0x01)  -- 0x28.5 (bit 5)
                    flags.PetFlag          = bit.band(bit.rshift(n, 6), 0x01)  -- 0x28.6 (bit 6)
                    flags.OcclusionoffFlag = bit.band(bit.rshift(n, 7), 0x01)  -- 0x28.7 (bit 7)
                    flags.BallistaTeam     = bit.band(bit.rshift(n, 8), 0xFF)  -- 0x29.0-0x29.7 (bits 8-15)
                    flags.MonStat          = bit.band(bit.rshift(n, 16), 0x07) -- 0x2A.0-0x2A.2 (bits 16-18, 3 bits)
                    flags.unknown_2_3      = bit.band(bit.rshift(n, 19), 0x01) -- 0x2A.3 (bit 19)
                    flags.unknown_2_4      = bit.band(bit.rshift(n, 20), 0x01) -- 0x2A.4 (bit 20)
                    flags.SilenceFlag      = bit.band(bit.rshift(n, 21), 0x01) -- 0x2A.5 (bit 21)
                    flags.unknown_2_6      = bit.band(bit.rshift(n, 22), 0x01) -- 0x2A.6 (bit 22)
                    flags.NewCharacterFlag = bit.band(bit.rshift(n, 23), 0x01) -- 0x2A.7 (bit 23)
                    flags.MentorFlag       = bit.band(bit.rshift(n, 24), 0x01) -- 0x2B.0 (bit 24)
                    flags.unknown_3_1      = bit.band(bit.rshift(n, 25), 0x01) -- 0x2B.1 (bit 25)
                    flags.unknown_3_2      = bit.band(bit.rshift(n, 26), 0x01) -- 0x2B.2 (bit 26)
                    flags.unknown_3_3      = bit.band(bit.rshift(n, 27), 0x01) -- 0x2B.3 (bit 27)
                    flags.unknown_3_4      = bit.band(bit.rshift(n, 28), 0x01) -- 0x2B.4 (bit 28)
                    flags.unknown_3_5      = bit.band(bit.rshift(n, 29), 0x01) -- 0x2B.5 (bit 29)
                    flags.unknown_3_6      = bit.band(bit.rshift(n, 30), 0x01) -- 0x2B.6 (bit 30)
                    flags.unknown_3_7      = bit.band(bit.rshift(n, 31), 0x01) -- 0x2B.7 (bit 31)

                    return flags
                end,
            },
            {
                name = 'SubAnimation', -- Derived field, no offset
                expr = function(ctx)
                    if ctx.Flags3.MonsterFlag == 1 or ctx.Flags3.unknown_3_2 == 1 then
                        -- Using full 3 bits
                        return ctx.Flags3.MonStat
                    else
                        -- Only using lower 2 bits
                        return bit.band(ctx.Flags3.MonStat or 0, 0x3)
                    end
                end,
            },
            { name = 'BtTargetID', bits = 32 }, -- 0x2C-0x2F
            { name = 'SubKind',    bits = 3 },  -- 0x30.0-0x30.2
            { name = 'Status',     bits = 13 }, -- 0x30.3-0x31.7
            {
                name = 'Data',                  -- 0x32+ (size varies)
                type = 'struct',
                layout = function(ctx)
                    local fields = {}
                    -- Model Handling
                    if ctx.SendFlg.Model then
                        if ctx.SubKind == 0 or ctx.SubKind == 5 or ctx.SubKind == 6 then
                            table.insert(fields, { name = 'model_id', bits = 16 }) -- 0x32-0x33
                        elseif ctx.SubKind == 1 or ctx.SubKind == 7 then
                            table.insert(fields,
                                {
                                    name = 'GrapIDTbl', -- 0x32-0x43
                                    type = 'array',
                                    count = 9,
                                    layout = { { name = 'value', bits = 16 } },
                                })
                        end
                    end

                    -- Rename Handling
                    if (ctx.SubKind == 0 or ctx.SubKind == 1 or ctx.SubKind == 5 or ctx.SubKind == 6 or ctx.SubKind == 7) and ctx.SendFlg.Name and ctx.ActIndex and ctx.ActIndex >= 1792 then
                        table.insert(fields, { name = 'data', bits = 16 })                  -- Varies based on prior fields
                        table.insert(fields, { name = 'Name', type = 'string', size = 16 }) -- 16 bytes after data
                    elseif ctx.SubKind == 1 and ctx.SendFlg.Name2 and ctx.ActIndex and ctx.ActIndex >= 1792 then
                        table.insert(fields, { name = 'data', type = 'raw', size = 18 })    -- Varies
                        table.insert(fields, { name = 'Name', type = 'string', size = 16 }) -- 16 bytes after data
                    elseif ctx.SubKind == 1 and ctx.SendFlg.Name2 and ctx.ActIndex and ctx.ActIndex < 1024 then
                        table.insert(fields, { name = 'data', type = 'raw', size = 18 })    -- Varies
                        table.insert(fields, { name = 'Name', type = 'string', size = 16 }) -- 16 bytes after data
                    elseif ctx.ActIndex and ctx.ActIndex < 1024 and ctx.SendFlg.Name then
                        table.insert(fields, { name = 'data', bits = 16 })                  -- Varies
                        table.insert(fields, { name = 'Name', type = 'string', size = 16 }) -- 16 bytes after data
                    end

                    -- SubKind-specific handling (doors, elevators)
                    if ctx.SubKind == 2 then
                        table.insert(fields, { name = 'unused', bits = 16 })  -- Varies
                        table.insert(fields, { name = 'DoorId', bits = 32 })  -- 2 bytes after unused
                    elseif ctx.SubKind == 3 or ctx.SubKind == 4 then
                        table.insert(fields, { name = 'unused', bits = 16 })  -- Varies
                        table.insert(fields, { name = 'DoorId', bits = 32 })  -- 2 bytes after unused
                        table.insert(fields, { name = 'Time', bits = 32 })    -- 4 bytes after DoorId
                        table.insert(fields, { name = 'EndTime', bits = 32 }) -- 4 bytes after Time
                    end

                    if #fields == 0 then
                        fields =
                        {
                            { name = 'Raw', type = 'raw', size = 24 }, -- Varies
                        }
                    end

                    return fields
                end,
            },
            {
                name = 'NPCType', -- Derived field, no offset
                expr = function(ctx)
                    local subKindsMap =
                    {
                        [0] = 'Fixed-Model NPC',
                        [1] = 'Equipped NPC',
                        [2] = 'Door',
                        [3] = 'Elevator',
                        [4] = 'Transport',
                        [5] = 'Unknown Fixed-Model NPC',
                        [6] = 'Automaton', -- Trolls? Lamia?
                        [7] = 'Unknown Equipped NPC',
                    }

                    return subKindsMap[ctx.SubKind] or 'Unknown NPC Type'
                end,
            },
        },
        [PacketId.GP_SERV_COMMAND_GM] =
        {
            -- TODO: Mes field is a variable-length string
        },
        [PacketId.GP_SERV_COMMAND_GMCOMMAND] =
        {
            { name = 'GMUniqueNo', bits = 32 }, -- 0x04-0x07
            -- TODO: Mes field is a variable-length array
        },
        [PacketId.GP_SERV_COMMAND_BATTLE2] =
        {
            {
                name = 'info_size',
                bits = 8,
            },
            {
                name = 'm_uID',
                bits = 32,
            },
            {
                name = 'trg_sum',
                bits = 6,
            },
            {
                name = 'res_sum',
                bits = 4,
            },
            {
                name = 'cmd_no',
                bits = 4,
            },
            {
                name = 'ActionType',
                expr = function(ctx)
                    local cmd_names =
                    {
                        [0] = 'None',             -- None.
                        [1] = 'Attack',           -- Basic Attack
                        [2] = 'R.Attack (F)',     -- Finish: Ranged Attack
                        [3] = 'WeaponSkill (F)',  -- Finish: Player Weapon Skills (Some job abilities use this such as Mug.)
                        [4] = 'Magic (F)',        -- Finish: Player and Monster Magic Casts
                        [5] = 'Item (F)',         -- Finish: Item Use
                        [6] = 'JobAbility (F)',   -- Finish: Player Job Abilities, DNC Reverse Flourish
                        [7] = 'Mon/WepSkill (S)', -- Start: Monster Skill, Weapon Skill
                        [8] = 'Magic (S)',        -- Start: Player and Monster Magic Casts
                        [9] = 'Item (S)',         -- Start: Item Use
                        [10] = 'JobAbility (S)',  -- Start: Job Ability
                        [11] = 'MonSkill (F)',    -- Finish: Monster Skill
                        [12] = 'R.Attack (S)',    -- Start: Ranged Attack
                        [14] = 'Dancer',          -- Dancer Flourish, Samba, Step, Waltz
                        [15] = 'RuneFencer',      -- Rune Fencer Effusion, Ward
                    }

                    return cmd_names[ctx.cmd_no]
                end,
            },
            {
                name = 'cmd_arg',
                bits = 32,
            },
            {
                name = 'info',
                bits = 32,
            },
            {
                name = 'target',
                type = 'array',
                count = 'trg_sum',
                layout =
                {
                    {
                        name = 'm_uID',
                        bits = 32,
                    },
                    {
                        name = 'result_sum',
                        bits = 4,
                    },
                    {
                        name = 'result',
                        type = 'array',
                        count = 'result_sum',
                        layout =
                        {
                            {
                                name = 'miss',
                                bits = 3,
                            },
                            {
                                name = 'kind',
                                bits = 2,
                            },
                            {
                                name = 'sub_kind',
                                bits = 12,
                            },
                            {
                                name = 'info',
                                bits = 5,
                            },
                            {
                                name = 'scale',
                                bits = 5,
                            },
                            {
                                name = 'value',
                                bits = 17,
                            },
                            {
                                name = 'message',
                                bits = 10,
                            },
                            {
                                name = 'bit',
                                bits = 31,
                            },
                            {
                                name = 'has_proc',
                                bits = 1,
                                conditional = true,
                                layout =
                                {
                                    {
                                        name = 'proc_kind',
                                        bits = 6,
                                    },
                                    {
                                        name = 'proc_info',
                                        bits = 4,
                                    },
                                    {
                                        name = 'proc_value',
                                        bits = 17,
                                    },
                                    {
                                        name = 'proc_message',
                                        bits = 10,
                                    },
                                },
                            },
                            {
                                name = 'has_react',
                                bits = 1,
                                conditional = true,
                                layout =
                                {
                                    {
                                        name = 'react_kind',
                                        bits = 6,
                                    },
                                    {
                                        name = 'react_info',
                                        bits = 4,
                                    },
                                    {
                                        name = 'react_value',
                                        bits = 14,
                                    },
                                    {
                                        name = 'react_message',
                                        bits = 10,
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
        [PacketId.GP_SERV_COMMAND_BATTLE_MESSAGE] =
        {
            { name = 'UniqueNoCas', bits = 32 }, -- 0x04
            { name = 'UniqueNoTar', bits = 32 }, -- 0x08
            { name = 'Data',        bits = 32 }, -- 0x0C
            { name = 'Data2',       bits = 32 }, -- 0x10
            { name = 'ActIndexCas', bits = 16 }, -- 0x14
            { name = 'ActIndexTar', bits = 16 }, -- 0x16
            { name = 'MessageNum',  bits = 16 }, -- 0x18
            { name = 'Type',        bits = 8 },  -- 0x1A
            { name = 'padding00',   bits = 8 },  -- 0x1B
        },
        [PacketId.GP_SERV_COMMAND_TRACKING_LIST] =
        {
            -- TrackingListTbl
            { name = 'ActIndex', bits = 16 },                  -- 0x04
            { name = 'Level',    bits = 8 },                   -- 0x06
            { name = 'Type',     bits = 3 },                   -- 0x07 (partial)
            { name = 'unused',   bits = 5 },                   -- 0x07 (rest)
            { name = 'x',        bits = 16 },                  -- 0x08
            { name = 'z',        bits = 16 },                  -- 0x0A
            { name = 'sName',    type = 'string', size = 16 }, -- 0x0C
            {
                name = 'DotColor',
                expr = function(ctx)
                    local type = ctx.Type
                    if type == TrackingListTbl_Type.PLAYER then
                        return 'None/Blue'
                    elseif type == TrackingListTbl_Type.FRIENDLY then
                        return 'Green'
                    elseif type == TrackingListTbl_Type.ENEMY then
                        return 'Red'
                    end
                end,
            },
            {
                name = 'Hidden',
                expr = function(ctx)
                    if ctx.Type == TrackingListTbl_Type.PLAYER then
                        if ctx.sName == '' then
                            return true
                        end
                    end

                    return false
                end,
            },
        },
        [PacketId.GP_SERV_COMMAND_TALKNUMNAME] =
        {
            { name = 'UniqueNo',  bits = 32 },                   -- 0x04 - The message entity server id
            { name = 'ActIndex',  bits = 16 },                   -- 0x08 - The message entity target index
            { name = 'MesNum',    bits = 16 },                   -- 0x0A - The message number
            { name = 'Type',      bits = 8 },                    -- 0x0C - The message type
            { name = 'padding00', bits = 8 },                    -- 0x0D - Padding; unused
            { name = 'padding01', bits = 16 },                   -- 0x0E - Padding; unused
            { name = 'sName',     type = 'string', size = 16 },  -- 0x10 - The message name
            {
                name = 'MessageNumber',
                expr = function(ctx)
                    return bit.band(ctx.MesNum or 0, 0x7FFF)
                end,
            },
            {
                name = 'IgnoreValidation',
                expr = function(ctx)
                    return bit.band(ctx.MesNum or 0, 0x8000) ~= 0
                end,
            },
            {
                name = 'TypeLookup',
                expr = function(ctx)
                    local type_lookup =
                    {
                        [0] = 0x8E,
                        [1] = 0xA1,
                        [2] = 0x90,
                        [3] = 0x91,
                        [4] = 0x92,
                        [5] = 0xA1,
                        [6] = 0x94,
                        [7] = 0x95,
                    }

                    if ctx.Type and ctx.Type < 8 then
                        return type_lookup[ctx.Type]
                    else
                        return type_lookup[0] -- Default to 0 for invalid types
                    end
                end,
            },
        },
        [PacketId.GP_SERV_COMMAND_EVENTUCOFF] =
        {
            { name = 'Mode', bits = 32 }, -- 0x04 - The user control mode value
            {
                name = 'ModeType',
                expr = function(ctx)
                    return bit.band(ctx.Mode or 0, 0xFF)
                end,
            },
            {
                name = 'EventId',
                expr = function(ctx)
                    -- For Mode 2, the upper bits contain the event ID
                    if bit.band(ctx.Mode or 0, 0xFF) == 2 then
                        return bit.rshift(ctx.Mode or 0, 8)
                    end
                    return nil
                end,
            },
            {
                name = 'ModeDescription',
                expr = function(ctx)
                    local mode_descriptions =
                    {
                        [0] = 'Standard control adjust (Reset event flags)',
                        [1] = 'Reset event receive pending flag',
                        [2] = 'Cancel current event',
                        [3] = 'Cancel numerical/string input',
                        [4] = 'Release from fishing event lock',
                    }

                    local mode = bit.band(ctx.Mode or 0, 0xFF)
                    if mode_descriptions[mode] then
                        return mode_descriptions[mode]
                    end

                    return 'Unknown mode type: ' .. tostring(mode)
                end,
            },
        },
        [PacketId.GP_SERV_COMMAND_SYSTEMMES] =
        {
            { name = 'para',      bits = 32 }, -- 0x04 - The message parameter (1)
            { name = 'para2',     bits = 32 }, -- 0x08 - The message parameter (2)
            { name = 'Number',    bits = 16 }, -- 0x0C - The message number
            { name = 'padding00', bits = 16 }, -- 0x0E - Padding; unused
        },
        [PacketId.GP_SERV_COMMAND_MUSIC] =
        {
            { name = 'Slot',     bits = 16 }, -- 0x04 - The music slot to be updated (0-7)
            { name = 'MusicNum', bits = 16 }, -- 0x06 - The music ID to play
            {
                name = 'SlotDescription',
                expr = function(ctx)
                    local slot_descriptions = {
                        [0] = 'Zone (Day)',
                        [1] = 'Zone (Night)',
                        [2] = 'Combat (Solo)',
                        [3] = 'Combat (Party)',
                        [4] = 'Mount',
                        [5] = 'Dead',
                        [6] = 'Mog House',
                        [7] = 'Fishing'
                    }
                    
                    if ctx.Slot and slot_descriptions[ctx.Slot] then
                        return slot_descriptions[ctx.Slot]
                    end
                    
                    return 'Unknown Slot'
                end,
            },
        },
        [PacketId.GP_SERV_COMMAND_MUSICVOLUME] =
        {
            { name = 'time',   bits = 16 }, -- 0x04 - The time to reach the target volume (linear interpolation)
            { name = 'volume', bits = 16 }, -- 0x06 - The target volume level (0-127)
            {
                name = 'VolumePercentage',
                expr = function(ctx)
                    if ctx.volume and ctx.volume >= 0 and ctx.volume <= 127 then
                        return math.floor((ctx.volume / 127) * 100) .. '%'
                    end
                    
                    return 'Invalid Volume'
                end,
            },
        },
    },
    outgoing =
    {
        [PacketId.GP_CLI_COMMAND_EVENTEND] =
        {
            { name = 'UniqueNo',  bits = 32 }, -- 0x04
            { name = 'EndPara',   bits = 32 }, -- 0x08
            { name = 'ActIndex',  bits = 16 }, -- 0x0C
            { name = 'Mode',      bits = 16 }, -- 0x0E
            { name = 'EventNum',  bits = 16 }, -- 0x10
            { name = 'EventPara', bits = 16 }, -- 0x12
        },
        [PacketId.GP_CLI_COMMAND_EVENTENDXZY] =
        {
            { name = 'x',         bits = 32, type = 'float' }, -- 0x04 - The local clients X position
            { name = 'y',         bits = 32, type = 'float' }, -- 0x08 - The local clients Y position
            { name = 'z',         bits = 32, type = 'float' }, -- 0x0C - The local clients Z position
            { name = 'UniqueNo',  bits = 32 },                 -- 0x10 - The event server id
            { name = 'EndPara',   bits = 32 },                 -- 0x14 - The event end parameter
            { name = 'EventNum',  bits = 16 },                 -- 0x18 - The event number
            { name = 'EventPara', bits = 16 },                 -- 0x1A - The event parameter
            { name = 'ActIndex',  bits = 16 },                 -- 0x1C - The event target index
            { name = 'Mode',      bits = 8 },                  -- 0x1E - The packet mode (always 1)
            { name = 'dir',       bits = 8, signed = true },   -- 0x1F - The local clients heading direction
        },
        [PacketId.GP_CLI_COMMAND_PASSWARDS] =
        {
            { name = 'UniqueNo',  bits = 32 },                  -- 0x04 - The event server id
            { name = 'ActIndex',  bits = 16 },                  -- 0x08 - The event target index
            { name = 'padding00', bits = 16 },                  -- 0x0A - Padding; unused
            { name = 'String',    type = 'string', size = 16 }, -- 0x0C - The string input value from the client
        },
    },
}

return definitions
