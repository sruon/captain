-- Credits: Original code written by ibm2431, rewritten/adapted by sruon
---@class NpcLoggerAddon : AddonInterface
---@field coroutinesSetup boolean
---@field notifications table
---@field rootDir? string
---@field captureDir? string
---@field databases { capture: Database?, global: Database? }
local addon          =
{
    name            = 'NPCLogger',
    filters         =
    {
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_CHAR_NPC]      = true, -- NPC updates
            [PacketId.GP_SERV_COMMAND_TRACKING_LIST] = true, -- Widescan updates
        },
    },
    settings        = {},
    defaultSettings =
    {
        database =
        {
            max_history    = 10,
            ignore_updates =
            {
                'x',
                'y',
                'z',
                'dir',
                'Flags0.MovTime',
                'Hpp',
                'legacy.flag',
                --- These are set when the NPC is moving
                'Flags1.CliPosInitFlag',
                'Flags1.Gender',
                'Flags1.GraphSize',
            },
        },
    },
    coroutinesSetup = false,
    notifications   =
    {
        wsUpdated  = {},
        npcUpdated = {},
        npcCreated = {},
    },
    databases       =
    {
        global  = nil,
        capture = nil,
    },
    rootDir         = nil,
    captureDir      = nil,

    -- NPC schema based on actual packet structure
    schema          =
    {
        UniqueNo      = 12345,
        ActIndex      = 123,
        SubKind       = 1,
        dir           = 1.5,
        x             = 100.5,
        y             = 200.0,
        z             = 300.5,
        Flags0        = 0,
        Flags1        = 0,
        Speed         = 40,
        SpeedBase     = 40,
        Hpp           = 100,
        server_status = 0,
        Flags2        = 0,
        Flags3        = 0,
        SubAnimation  = 0,
        GrapIdTbl     = { 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        model_id      = 123,
        Name          = 'Example NPC',
        DoorId        = 0,
        Time          = 0,
        EndTime       = 0,
        legacy        =
        {
            flag         = 0,
            speed        = 40,
            speedsub     = 40,
            status       = 0,
            animation    = 0,
            animationsub = 0,
            flags        = 0,
            name_prefix  = 0,
            namevis      = 0,
            look         = '0000000000000000000000000000000000000',
        },
        ws            = { Level = 50, sName = 'Example Monster', Type = 1 },
    },
}

addon.onCaptureStart = function(captureDir)
    addon.captureDir        = captureDir

    addon.databases.capture = backend.databaseOpen(
        string.format('%s/%s.db', captureDir, backend.zone_name()),
        {
            schema      = addon.schema,
            max_history = addon.settings.database and addon.settings.database.max_history,
        })
end

addon.onCaptureStop  = function()
    addon.captureDir = nil
    if addon.databases.capture then
        addon.databases.capture:close()
        addon.databases.capture = nil
    end
end

addon.onClientReady  = function(zoneId)
    if addon.databases.global then
        addon.databases.global:close()
    end

    addon.databases.global = backend.databaseOpen(
        string.format('%s/%s/%s.db', addon.rootDir, backend.player_name(), backend.zone_name(zoneId)),
        {
            schema      = addon.schema,
            max_history = addon.settings.database and addon.settings.database.max_history,
        })

    if addon.databases.capture then
        addon.databases.capture:close()
        addon.databases.capture = backend.databaseOpen(
            string.format('%s/%s.db', addon.captureDir, backend.zone_name(zoneId)),
            {
                schema      = addon.schema,
                max_history = addon.settings.database and addon.settings.database.max_history,
            })
    end
end

local function getCurrentDb()
    return addon.databases.capture or addon.databases.global
end

local function parseNpcUpdate(data)
    local packet = backend.parsePacket('incoming', data)
    if not packet then
        return
    end

    local db = getCurrentDb()
    if not db then
        return
    end

    local npc = db:get(packet.UniqueNo)
    if not npc then
        npc = { UniqueNo = packet.UniqueNo }
    end

    -- Always reassign, in case it changed
    npc.ActIndex = packet.ActIndex
    npc.SubKind  = packet.SubKind

    -- Depending on the flags set, we can capture different fields
    if packet.SendFlg.Position then
        npc.dir       = packet.dir
        npc.x         = packet.x
        npc.y         = packet.z -- Backward compatibility, this should be y!
        npc.z         = packet.y -- Backward compatibility, this should be z!
        npc.Flags0    = packet.Flags0_num
        npc.Flags1    = packet.Flags1_num
        npc.Speed     = packet.Speed
        npc.SpeedBase = packet.SpeedBase
    end

    if packet.SendFlg.General then
        npc.Hpp           = packet.Hpp
        npc.server_status = packet.server_status
        npc.Flags1        = packet.Flags1_num
        npc.Flags2        = packet.Flags2_num
        npc.Flags3        = packet.Flags3_num
        npc.SubAnimation  = packet.SubAnimation
    end

    if packet.SendFlg.Model then
        -- Determine the model type based on SubKind
        if packet.SubKind == 1 or packet.SubKind == 7 then
            -- Equipped NPCs (wearing gear)
            npc.GrapIdTbl = packet.Data.GrapIDTbl
        end
    end

    if packet.Data.model_id then
        npc.model_id = packet.Data.model_id
    end

    if packet.SendFlg.Name then
        npc.Name = packet.Data.Name
    end

    -- Doors, Elevators, Transports
    if packet.SubKind >= 2 and packet.SubKind <= 4 then
        npc.DoorId = packet.Data.DoorId
        if packet.Data.Time then
            npc.Time = packet.Data.Time
        end

        if packet.Data.EndTime then
            npc.EndTime = packet.Data.EndTime
        end
    end

    -- TODO: Fuck if I know
    --if packet.SendFlg.Name2 then
    --end

    -- Insert legacy fields
    npc.legacy = {}
    if packet.SendFlg.Position then
        npc.legacy.flag     = packet.Flags0_num
        npc.legacy.speed    = packet.Speed
        npc.legacy.speedsub = packet.SpeedBase
        npc.legacy.status   = bit.band(packet.Flags1_num, 0xFF) -- Backward compatibility, this should be Flags1! 0x20 (subset of Flags1)
    end

    if packet.SendFlg.General then
        npc.legacy.animation    = packet.server_status
        npc.legacy.animationsub = packet.SubAnimation
        npc.legacy.flags        = bit.rshift(packet.Flags1_num, 8)  -- Backward compatibility, this should be Flags1! 0x21-0x24 (subset of Flags1)
        npc.legacy.name_prefix  = bit.rshift(packet.Flags2_num, 24) -- Backward compatibility, this should be Flags2! 0x27 (subset of Flags2)
        npc.legacy.namevis      = bit.rshift(packet.Flags3_num, 24) -- Backward compatibility, this should be Flags3! 0x2B (subset of Flags3)
    end

    if packet.SendFlg.Model then
        if packet.SubKind == 1 or packet.SubKind == 7 then
            -- Create legacy_look string starting from 0x30 (SubKind and Status)
            -- First pack SubKind and Status into a 16-bit value
            local subkind_status = bit.bor(
                packet.SubKind,              -- First 3 bits
                bit.lshift(packet.Status, 3) -- Next 13 bits
            )

            -- Format as a 4-character hex string
            npc.legacy.look      = string.format('%04X', subkind_status)

            -- Add equipment data (0x32-0x43)
            for i = 1, 9 do
                -- Format each 16-bit value as a 4-character hex string
                local value     = packet.Data.GrapIDTbl[i] or 0
                npc.legacy.look = npc.legacy.look .. string.format('%04X', value)
            end
        elseif packet.SubKind == 0 or packet.SubKind == 5 or packet.SubKind == 6 then
            -- Create legacy_look string starting from 0x30 (SubKind and Status)
            local subkind_status = bit.bor(
                packet.SubKind,              -- First 3 bits
                bit.lshift(packet.Status, 3) -- Next 13 bits
            )

            -- Format as a 4-character hex string for SubKind+Status and another for model_id
            npc.legacy.look      = string.format('%04X%04X', subkind_status, packet.Data.model_id)
        end
    end

    npc.type  = packet.NPCType

    local mob = backend.get_mob_by_index(packet.ActIndex)
    if mob then
        npc.polutils_name = mob.name
    else
        npc.polutils_name = 'NotFound'
    end

    local mt     = getmetatable(db)
    local result = db:add_or_update(packet.UniqueNo, npc)
    if result == mt.RESULT_NEW then
        table.insert(addon.notifications.npcCreated, packet.UniqueNo)
    elseif result == mt.RESULT_UPDATED then
        table.insert(addon.notifications.npcUpdated, packet.UniqueNo)
    end
end

local function parseWidescanUpdate(data)
    ---@type GP_SERV_COMMAND_TRACKING_LIST?
    local packet = backend.parsePacket('incoming', data)
    if not packet then
        return
    end

    local db = getCurrentDb()
    if not db then
        return
    end

    -- WS Packet only contains the index of the NPC, so we need to look it up in the main NPC DB
    local npc, UniqueNo = db:find_by('ActIndex', packet.ActIndex)

    -- If it's a NPC we've already updated, or that we don't know of yet, ignore it
    if not npc or (npc.ws and npc.ws.Level) then
        return
    end

    npc.ws       =
    {
        Level = packet.Level,
        sName = packet.sName,
        Type  = packet.Type,
    }

    local mt     = getmetatable(db)
    local result = db:add_or_update(UniqueNo, npc)
    if result == mt.RESULT_UPDATED then
        table.insert(addon.notifications.wsUpdated, UniqueNo)
    end
end

addon.onIncomingPacket = function(id, data)
    if id == PacketId.GP_SERV_COMMAND_CHAR_NPC then
        parseNpcUpdate(data)
    elseif id == PacketId.GP_SERV_COMMAND_TRACKING_LIST then
        parseWidescanUpdate(data)
    end
end

addon.onInitialize     = function(rootDir)
    addon.rootDir          = rootDir

    addon.databases.global = backend.databaseOpen(
        string.format('%s/%s/%s.db', rootDir, backend.player_name(), backend.zone_name()),
        {
            schema      = addon.schema,
            max_history = addon.settings.database and addon.settings.database.max_history,
        })
end

addon.onPrerender      = function()
    if not addon.coroutinesSetup then
        backend.forever(function()
            local db = getCurrentDb()
            if db and (#addon.notifications.npcCreated > 0) then
                local report = string.format('Database updated. %d NPCs (%d new, %d updates, %d WS updates)', db:count(),
                    #addon.notifications.npcCreated, #addon.notifications.npcUpdated, #addon.notifications.wsUpdated)
                backend.msg('NPCLogger', report)
                addon.notifications.npcCreated = {}
                addon.notifications.npcUpdated = {}
                addon.notifications.wsUpdated  = {}
            end
        end, 60)

        addon.coroutinesSetup = true
    end
end

return addon
