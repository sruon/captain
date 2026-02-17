-- Credits: Original code written by ibm2431, rewritten/adapted by sruon
---@class EventViewAddon : AddonInterface
local addon            =
{
    name            = 'EventView',
    filters         =
    {
        incoming =
        {
            -- Event packets
            [PacketId.GP_SERV_COMMAND_LOGIN]          = true,
            [PacketId.GP_SERV_COMMAND_EVENT]          = true,
            [PacketId.GP_SERV_COMMAND_EVENTNUM]       = true,
            [PacketId.GP_SERV_COMMAND_EVENTMES]       = true,
            [PacketId.GP_SERV_COMMAND_EVENTSTR]       = true,
            [PacketId.GP_SERV_COMMAND_EVENTUCOFF]     = true,
            [PacketId.GP_SERV_COMMAND_PENDINGNUM]     = true,

            -- TODO: Everything below should probably live in their own addons
            -- Music packets
            [PacketId.GP_SERV_COMMAND_MUSIC]          = true,
            [PacketId.GP_SERV_COMMAND_MUSICVOLUME]    = true,

            -- Animation packets
            [PacketId.GP_SERV_COMMAND_SCHEDULOR]      = true,
            [PacketId.GP_SERV_COMMAND_MAPSCHEDULOR]   = true,
            [PacketId.GP_SERV_COMMAND_MAGICSCHEDULOR] = true,

            -- Message packets
            [PacketId.GP_SERV_COMMAND_TALKNUM]        = true,
            [PacketId.GP_SERV_COMMAND_TALKNUMWORK]    = true,
            [PacketId.GP_SERV_COMMAND_TALKNUMNAME]    = true,
            [PacketId.GP_SERV_COMMAND_TALKNUMWORK2]   = true,
            [PacketId.GP_SERV_COMMAND_SYSTEMMES]      = true,
        },

        outgoing =
        {
            [PacketId.GP_CLI_COMMAND_EVENTEND]    = true,
            [PacketId.GP_CLI_COMMAND_EVENTENDXZY] = true,
            [PacketId.GP_CLI_COMMAND_PASSWARDS]   = true,
        },
    },
    mappings        = -- Simplified structures to handle notifications without building complex templates
    {
        incoming =
        {
            -- TODO: May need to swap fields order for better readability
            [PacketId.GP_SERV_COMMAND_LOGIN]          = -- Test: !pos -283 0 -52 78
            {
                type               = 'GP_SERV_COMMAND_LOGIN',
                notificationFields =
                {
                    'EventPara',
                    'EventNum',
                    'EventMode',
                    'ZoneNo',
                },
                fieldLabels        =
                {
                    EventPara = 'EventPara (EventId)',
                },
            },
            [PacketId.GP_SERV_COMMAND_EVENT]          = -- Test: !pos 112 0 -8 231 (A.M.A.N Liaison)
            {
                type               = 'GP_SERV_COMMAND_EVENT',
                notificationFields =
                {
                    'UniqueNo',
                    'EventPara',
                    'EventNum',
                    'EventNum2',
                    'EventPara2',
                    'Mode',
                },
                fieldLabels        =
                {
                    EventPara = 'EventPara (EventId)',
                },
            },
            [PacketId.GP_SERV_COMMAND_EVENTNUM]       = -- Test: !pos 112 0 -8 231 (Explorer Moogle)
            {
                type               = 'GP_SERV_COMMAND_EVENTNUM',
                freeze             = true,
                notificationFields =
                {
                    'UniqueNo',
                    'EventPara',
                    'EventNum',
                    'EventNum2',
                    'EventPara2',
                    'Mode',
                    'num',
                },
                fieldLabels        =
                {
                    EventPara = 'EventPara (EventId)',
                },
            },
            [PacketId.GP_SERV_COMMAND_EVENTMES]       = -- Test: ?? Figure out on retail
            {
                type               = 'GP_SERV_COMMAND_EVENTMES',
                notificationFields =
                {
                    'UniqueNo',
                    'MessageNumber',
                    'UseEntityName',
                },
            },
            [PacketId.GP_SERV_COMMAND_EVENTSTR]       = -- Test: !pos 35.7 -7 43 50 (Tateeya)
            {
                type               = 'GP_SERV_COMMAND_EVENTSTR',
                notificationFields =
                {
                    'UniqueNo',
                    'EventPara',
                    'EventNum',
                    'Mode',
                    'String',
                    'Data',
                },
                fieldLabels        =
                {
                    EventPara = 'EventPara (EventId)',
                },
            },
            [PacketId.GP_SERV_COMMAND_EVENTUCOFF]     = -- Test: !release
            {
                type               = 'GP_SERV_COMMAND_EVENTUCOFF',
                notificationFields =
                {
                    'EventId',
                    'Mode',
                    'ModeType',
                },
            },
            [PacketId.GP_SERV_COMMAND_PENDINGNUM]     = -- Test: TBD
            {
                type               = 'GP_SERV_COMMAND_PENDINGNUM',
                notificationFields =
                {
                    'num',
                },
            },
            [PacketId.GP_SERV_COMMAND_SCHEDULOR]      = -- Test: !despawnmob
            {
                type               = 'GP_SERV_COMMAND_SCHEDULOR',
                notificationFields =
                {
                    'UniqueNoCas',
                    'UniqueNoTar',
                    'FourCCString',
                },
            },
            [PacketId.GP_SERV_COMMAND_MAPSCHEDULOR]   = -- Test: !zone 35
            {
                type               = 'GP_SERV_COMMAND_MAPSCHEDULOR',
                notificationFields =
                {
                    'UniqueNoCas',
                    'UniqueNoTar',
                    'FourCCString',
                },
            },
            [PacketId.GP_SERV_COMMAND_MAGICSCHEDULOR] = -- Test: !menu
            {
                type               = 'GP_SERV_COMMAND_MAGICSCHEDULOR',
                notificationFields =
                {
                    'UniqueNoCas',
                    'UniqueNoTar',
                    'fileNum',
                    'type',
                    'TypeName',
                },
            },
            [PacketId.GP_SERV_COMMAND_TALKNUM]        = -- Test: Any !cs with menu, then !release
            {
                type               = 'GP_SERV_COMMAND_TALKNUM',
                notificationFields =
                {
                    'UniqueNo',
                    'MesNum',
                    'Type',
                },
            },
            [PacketId.GP_SERV_COMMAND_TALKNUMWORK]    = -- Test: !messagespecial 1
            {
                type               = 'GP_SERV_COMMAND_TALKNUMWORK',
                notificationFields =
                {
                    'UniqueNo',
                    'MessageNumber',
                    'IgnoreValidation',
                    'Type',
                    'Flag',
                    'String',
                    'num',
                    'TypeLookup',
                    'SpeakerName',
                },
            },
            [PacketId.GP_SERV_COMMAND_TALKNUMNAME]    = -- Test: no idea!
            {
                type               = 'GP_SERV_COMMAND_TALKNUMNAME',
                notificationFields =
                {
                    'UniqueNo',
                    'MessageNumber',
                    'IgnoreValidation',
                    'Type',
                    'TypeLookup',
                    'sName',
                },
            },
            [PacketId.GP_SERV_COMMAND_TALKNUMWORK2]   = -- Test: !instance 7704
            {
                type               = 'GP_SERV_COMMAND_TALKNUMWORK2',
                notificationFields =
                {
                    'UniqueNo',
                    'MesNum',
                    'Type',
                    'Flags',
                    'Num1',
                    'Num2',
                    'String1',
                    'String2',
                    'SpeakerName',
                },
            },
            [PacketId.GP_SERV_COMMAND_SYSTEMMES]      = -- Test: Logout message as non-GM
            {
                type               = 'GP_SERV_COMMAND_SYSTEMMES',
                notificationFields =
                {
                    'para',
                    'para2',
                    'Number',
                },
            },
            [PacketId.GP_SERV_COMMAND_MUSIC]          =
            {
                type               = 'GP_SERV_COMMAND_MUSIC',
                notificationFields =
                {
                    'Slot',
                    'SlotDescription',
                    'MusicNum',
                },
            },
            [PacketId.GP_SERV_COMMAND_MUSICVOLUME]    =
            {
                type               = 'GP_SERV_COMMAND_MUSICVOLUME',
                notificationFields =
                {
                    'time',
                    'volume',
                    'VolumePercentage',
                },
            },
        },

        outgoing =
        {
            [PacketId.GP_CLI_COMMAND_EVENTEND]    = -- Test: !pos 112 0 -8 231 (A.M.A.N Liaison)
            {
                type               = 'GP_CLI_COMMAND_EVENTEND',
                notificationFields =
                {
                    'UniqueNo',
                    'EndPara',
                    'EventNum',
                    'EventPara',
                },
                fieldLabels        =
                {
                    EventPara = 'EventPara (EventId)',
                    EndPara   = 'EndPara (Option)',
                },
            },
            [PacketId.GP_CLI_COMMAND_EVENTENDXZY] = -- Test: !pos -283 0 -52 78
            {
                type               = 'GP_CLI_COMMAND_EVENTENDXZY',
                notificationFields =
                {
                    'UniqueNo',
                    'EndPara',
                    'EventNum',
                    'EventPara',
                    'Mode',
                    'x',
                    'y',
                    'z',
                    'dir',
                },
                fieldLabels        =
                {
                    EventPara = 'EventPara (EventId)',
                    EndPara   = 'EndPara (Option)',
                },
            },
            [PacketId.GP_CLI_COMMAND_PASSWARDS]   = -- Test: !zone 245, !cs 199
            {
                type               = 'GP_CLI_COMMAND_PASSWARDS',
                notificationFields =
                {
                    'UniqueNo',
                    'String',
                },
            },
        },
    },
    settings        = {},
    defaultSettings =
    {
    },
    files           =
    {
        simple  = nil,
        capture = nil,
    },
    lastMusic       = nil, -- Track last music packet for deduplication
}

-- LSB binding names for message packets
local LSBBindings =
{
    [PacketId.GP_SERV_COMMAND_TALKNUM]      = 'messageText',
    [PacketId.GP_SERV_COMMAND_TALKNUMNAME]  = 'messagePublic',
    [PacketId.GP_SERV_COMMAND_TALKNUMWORK2] = 'messageName',
    [PacketId.GP_SERV_COMMAND_SYSTEMMES]    = 'messageSystem',
}

-- Get dynamic LSB binding suffix for message packets
local function getLSBBinding(id, packet)
    local player   = backend.get_player_entity_data()
    local isPlayer = player and packet.UniqueNo == player.serverId

    -- TALKNUMWORK has different bindings for player vs npc
    if id == PacketId.GP_SERV_COMMAND_TALKNUMWORK then
        return isPlayer and 'player:messageSpecial' or 'npc:showText'
    end

    local binding = LSBBindings[id]
    if not binding then
        return nil
    end

    local prefix = isPlayer and 'player' or 'npc'
    return prefix .. ':' .. binding
end

addon.onClientReady    = function(zoneId)
    addon.files.simple  = backend.fileOpen(string.format('%s/%s/%s.log', addon.rootDir, backend.player_name(),
        backend.zone_name(zoneId)))
    if addon.files.capture then
        addon.files.capture = backend.fileOpen(string.format('%s/%s/%s.log', addon.captureDir, backend.player_name(),
            backend.zone_name(zoneId)))
    end

    -- Reset music deduplication state on zone change
    addon.lastMusic = nil
end

-- Shared function for processing both incoming and outgoing packets
addon.processPacket    = function(direction, id, data, packet)
    if not packet then
        backend.msg('EView', string.format('Could not parse packet %s', id))
        return
    end

    -- Only care about zone packets with events when direction is incoming
    if id == PacketId.GP_SERV_COMMAND_LOGIN and packet.EventNum == 0 then
        return
    end

    -- Deduplicate music packets (SE spams these in certain zones like Dynamis-Xarcabard)
    if id == PacketId.GP_SERV_COMMAND_MUSIC then
        local key = string.format('%d:%d', packet.Slot or 0, packet.MusicNum or 0)
        if addon.lastMusic == key then
            return
        end
        addon.lastMusic = key
    end

    local dirPrefix  = (direction == 'incoming') and '<< ' or '>> '
    local typeLabel  = addon.mappings[direction][id].type

    -- Dynamic type alias for EVENTEND based on Mode
    if id == PacketId.GP_CLI_COMMAND_EVENTEND then
        if packet.Mode == 0 then
            typeLabel = 'GP_CLI_COMMAND_EVENTEND (onEventFinish)'
        elseif packet.Mode == 1 then
            typeLabel = 'GP_CLI_COMMAND_EVENTEND (onEventUpdate)'
        end
    end

    local lsbBinding = getLSBBinding(id, packet)
    if lsbBinding then
        typeLabel = typeLabel .. ' (' .. lsbBinding .. ')'
    end

    local title      = string.format('%s%s',
        dirPrefix,
        typeLabel)

    local dataFields = {}

    -- Add all fields from the packet to the data fields based on the mappings
    local mapping = addon.mappings[direction][id]
    if mapping and mapping.notificationFields then
        local fieldLabels = mapping.fieldLabels or {}
        for i, fieldName in ipairs(mapping.notificationFields) do
            if packet[fieldName] ~= nil then
                local value       = packet[fieldName]
                local displayName = fieldLabels[fieldName] or fieldName

                -- Augment certain fields with actor names
                if fieldName == 'UniqueNo' then
                    local mob = backend.get_mob_by_index(packet.ActIndex)
                    if mob and mob.name then
                        value = string.format('%d (%s)', packet[fieldName], mob.name)
                    end
                elseif fieldName == 'UniqueNoCas' then
                    local mob = backend.get_mob_by_index(packet.ActIndexCast)
                    if mob and mob.name then
                        value = string.format('%d (%s)', packet[fieldName], mob.name)
                    end
                elseif fieldName == 'UniqueNoTar' then
                    local mob = backend.get_mob_by_index(packet.ActIndexTar)
                    if mob and mob.name then
                        value = string.format('%d (%s)', packet[fieldName], mob.name)
                    end
                elseif
                  fieldName == 'MesNum' or
                  fieldName == 'MessageNumber'
                then
                    -- Strip MSB for message IDs
                    value = bit.band(packet[fieldName], 0x7FFF)
                end

                table.insert(dataFields, { displayName, value })
            end
        end
    end

    -- Log packet information
    local tstamp   = os.date('%Y-%m-%d %H:%M:%S')
    local logTitle = title
    if addon.mappings[direction][id].legacyType then
        logTitle = logTitle .. ' - ' .. addon.mappings[direction][id].legacyType
    end
    addon.files.simple:append(string.format('[%s] %s\n%s\n\n', tstamp, logTitle, utils.dump(packet)))
    if addon.files.capture then
        addon.files.capture:append(string.format('[%s] %s\n%s\n\n', tstamp, logTitle, utils.dump(packet)))
    end

    backend.notificationCreate('EView', title, dataFields)
end

addon.onIncomingPacket = function(id, data, size, packet)
    addon.processPacket('incoming', id, data, packet)
end

addon.onOutgoingPacket = function(id, data, size, packet)
    addon.processPacket('outgoing', id, data, packet)
end

addon.onCaptureStart   = function(captureDir)
    addon.captureDir    = captureDir
    addon.files.capture = backend.fileOpen(string.format('%s/%s/%s.log', addon.captureDir, backend.player_name(),
        backend.zone_name()))
end

addon.onCaptureStop    = function()
    addon.captureDir    = nil
    addon.files.capture = nil
end

addon.onInitialize     = function(rootDir)
    addon.rootDir      = rootDir
    addon.files.simple = backend.fileOpen(string.format('%s/%s/%s.log', addon.rootDir, backend.player_name(),
        backend.zone_name()))
end

return addon
