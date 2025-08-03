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
                type               = 'CZoneInPacket',
                legacyType         = 'Zone CS (0x00A)',
                notificationFields =
                {
                    'EventPara',
                    'EventNum',
                    'EventMode',
                    'ZoneNo',
                },
            },
            [PacketId.GP_SERV_COMMAND_EVENT]          = -- Test: !pos 112 0 -8 231 (A.M.A.N Liaison)
            {
                type               = 'CEventPacket',
                legacyType         = 'CS Event (0x032)',
                notificationFields =
                {
                    'UniqueNo',
                    'EventPara',
                    'EventNum',
                    'EventPara2',
                    'EventNum2',
                    'Mode',
                },
            },
            [PacketId.GP_SERV_COMMAND_EVENTNUM]       = -- Test: !pos 112 0 -8 231 (Explorer Moogle)
            {
                type               = 'CEventPacket*',
                legacyType         = 'CS Event + Params (0x034)',
                freeze             = true,
                notificationFields =
                {
                    'UniqueNo',
                    'EventPara',
                    'EventNum',
                    'EventPara2',
                    'EventNum2',
                    'Mode',
                    'num',
                },
            },
            [PacketId.GP_SERV_COMMAND_EVENTMES]       = -- Test: ?? Figure out on retail
            {
                type               = 'CEventMesPacket (not implemented)',
                notificationFields =
                {
                    'UniqueNo',
                    'MessageNumber',
                    'UseEntityName',
                },
            },
            [PacketId.GP_SERV_COMMAND_EVENTSTR]       = -- Test: !pos 35.7 -7 43 50 (Tateeya)
            {
                type               = 'CEventStringPacket',
                legacyType         = 'CS Event + Strings (0x033)',
                notificationFields =
                {
                    'UniqueNo',
                    'EventNum',
                    'EventPara',
                    'Mode',
                    'String',
                    'Data',
                },
            },
            [PacketId.GP_SERV_COMMAND_EVENTUCOFF]     = -- Test: !release
            {
                type               = 'CReleasePacket',
                notificationFields =
                {
                    'EventId',
                    'Mode',
                    'ModeType',
                },
            },
            [PacketId.GP_SERV_COMMAND_PENDINGNUM]     = -- Test: TBD
            {
                type               = 'CEventUpdatePacket',
                legacyType         = 'Event Update (0x05C)',
                notificationFields =
                {
                    'num',
                },
            },
            [PacketId.GP_SERV_COMMAND_SCHEDULOR]      = -- Test: !despawnmob
            {
                type               = 'CEntityAnimationPacket',
                notificationFields =
                {
                    'UniqueNoCas',
                    'UniqueNoTar',
                    'FourCCString',
                },
            },
            [PacketId.GP_SERV_COMMAND_MAPSCHEDULOR]   = -- Test: !zone 35
            {
                type               = 'CEntityVisualPacket',
                notificationFields =
                {
                    'UniqueNoCas',
                    'UniqueNoTar',
                    'FourCCString',
                },
            },
            [PacketId.GP_SERV_COMMAND_MAGICSCHEDULOR] = -- Test: !menu
            {
                type               = 'CIndependentAnimationPacket',
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
                type               = 'CMessageTextPacket',
                legacyType         = 'NPC Chat (0x036)',
                notificationFields =
                {
                    'UniqueNo',
                    'MesNum',
                    'Type',
                },
            },
            [PacketId.GP_SERV_COMMAND_TALKNUMWORK]    = -- Test: !messagespecial 1
            {
                type               = 'CMessageSpecialPacket',
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
                type               = 'CCaughtMonsterPacket',
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
                type               = 'CMessageNamePacket',
                notificationFields =
                {
                    'UniqueNo',
                    'MesNum',
                    'Num1',
                    'Num2',
                    'String1',
                    'String2',
                    'SpeakerName',
                    'Type',
                    'Flags',
                },
            },
            [PacketId.GP_SERV_COMMAND_SYSTEMMES]      = -- Test: Logout message as non-GM
            {
                type               = 'CMessageSystemPacket',
                legacyType         = 'SYSTEMMES (0x053)',
                notificationFields =
                {
                    'para',
                    'para2',
                    'Number',
                },
            },
            [PacketId.GP_SERV_COMMAND_MUSIC]          =
            {
                type               = 'CChangeMusicPacket',
                notificationFields =
                {
                    'Slot',
                    'SlotDescription',
                    'MusicNum',
                },
            },
            [PacketId.GP_SERV_COMMAND_MUSICVOLUME]    =
            {
                type               = 'CMusicVolumePacket (not implemented)',
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
                legacyType         = 'Event Option (0x05B)',
                notificationFields =
                {
                    'UniqueNo',
                    'EndPara',
                    'Mode',
                    'EventNum',
                    'EventPara',
                },
            },
            [PacketId.GP_CLI_COMMAND_EVENTENDXZY] = -- Test: !pos -283 0 -52 78
            {
                type               = 'GP_CLI_COMMAND_EVENTENDXZY',
                legacyType         = 'Event Option + Pos (0x05C)',
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
            },
            [PacketId.GP_CLI_COMMAND_PASSWARDS]   = -- Test: !zone 245, !cs 199
            {
                type               = 'GP_CLI_COMMAND_PASSWARDS',
                legacyType         = 'String Input (0x060)',
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
}

addon.onZoneChange     = function(zoneId)
    addon.files.simple = backend.fileOpen(string.format('%s/%s/%s.log', addon.rootDir, backend.player_name(),
        backend.zone_name(zoneId)))
    if addon.files.capture then
        addon.files.capture = backend.fileOpen(string.format('%s/%s/%s.log', addon.captureDir, backend.player_name(),
            backend.zone_name(zoneId)))
    end
end

-- Shared function for processing both incoming and outgoing packets
addon.processPacket    = function(direction, id, data)
    local packet = backend.parsePacket(direction, data)
    if not packet then
        backend.msg('EView', string.format('Could not parse packet %s', id))
        return
    end

    -- Only care about zone packets with events when direction is incoming
    if id == PacketId.GP_SERV_COMMAND_LOGIN and packet.EventNum == 0 then
        return
    end

    local dirPrefix  = (direction == 'incoming') and '<< ' or '>> '
    local title      = string.format('%s[0x%03X] %s (%s)',
        dirPrefix,
        id,
        addon.mappings[direction][id].type,
        PacketIdToName[direction][id])

    local dataFields = {}

    -- Add all fields from the packet to the data fields based on the mappings
    if addon.mappings[direction][id] and addon.mappings[direction][id].notificationFields then
        for i, fieldName in ipairs(addon.mappings[direction][id].notificationFields) do
            if packet[fieldName] ~= nil then
                local value = packet[fieldName]

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
                end

                table.insert(dataFields, { fieldName, value })
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

    backend.notificationCreate('EView', title, dataFields, addon.mappings[direction][id].freeze)
end

addon.onIncomingPacket = function(id, data)
    addon.processPacket('incoming', id, data)
end

addon.onOutgoingPacket = function(id, data)
    addon.processPacket('outgoing', id, data)
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
