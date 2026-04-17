-- Credits: sruon
---@class FishMonAddon : AddonInterface

local FISH_OFFSETS      = require('addons.fishmon.offsets')
local FISH_MSG          = require('addons.fishmon.messages').MSG

local addon             =
{
    name           = 'FishMon',
    settings       = {},
    filters        =
    {
        incoming =
        {
            [0x115] = true, -- Fish stats on bite
            [0x027] = true, -- TALKNUMWORK2 (catch result)
            [0x036] = true, -- TALKNUM (fishing messages)
            [0x02A] = true, -- TALKNUMWORK (keen sense)
            [0x029] = true, -- BATTLE_MESSAGE (skill ups)
        },
        outgoing =
        {
            [0x01A] = true, -- ACTION (fishing cast)
            [0x110] = true, -- Fishing action (reel/release)
        },
    },
    databases      = { global = nil, capture = nil },
    pendingDbWrite = nil,
    rootDir        = nil,
    captureDir     = nil,
    state          = {},
}

local SLOT_RANGE        = 0x02
local SLOT_AMMO         = 0x03
local SKILL_FISHING     = 0

local BITE_TYPE_STRINGS =
{
    [FISH_MSG.HOOKED_SMALL]   = 'SMALL',
    [FISH_MSG.HOOKED_LARGE]   = 'LARGE',
    [FISH_MSG.HOOKED_ITEM]    = 'ITEM',
    [FISH_MSG.HOOKED_MONSTER] = 'MONSTER',
}

local FEELING_STRINGS   =
{
    [FISH_MSG.GOOD_FEELING]             = 'GOOD',
    [FISH_MSG.BAD_FEELING]              = 'BAD',
    [FISH_MSG.TERRIBLE_FEELING]         = 'TERRIBLE',
    [FISH_MSG.NOSKILL_FEELING]          = 'NOSKILL',
    [FISH_MSG.NOSKILL_SURE_FEELING]     = 'NOSKILL_SURE',
    [FISH_MSG.NOSKILL_POSITIVE_FEELING] = 'NOSKILL_POSITIVE',
    [FISH_MSG.EPIC_CATCH]               = 'EPIC',
}

local RESULT_STRINGS    =
{
    [FISH_MSG.CATCH]             = 'CATCH',
    [FISH_MSG.CATCH_MULTI]       = 'CATCH_MULTI',
    [FISH_MSG.CATCH_CHEST]       = 'CATCH_CHEST',
    [FISH_MSG.LOST]              = 'LOST',
    [FISH_MSG.LOST_TOOBIG]       = 'LOST_TOOBIG',
    [FISH_MSG.LOST_TOOSMALL]     = 'LOST_TOOSMALL',
    [FISH_MSG.LOST_LOWSKILL]     = 'LOST_LOWSKILL',
    [FISH_MSG.LINEBREAK]         = 'LINEBREAK',
    [FISH_MSG.RODBREAK]          = 'RODBREAK',
    [FISH_MSG.RODBREAK_TOOBIG]   = 'RODBREAK_TOOBIG',
    [FISH_MSG.RODBREAK_TOOHEAVY] = 'RODBREAK_TOOHEAVY',
    [FISH_MSG.NOCATCH]           = 'NOCATCH',
    [FISH_MSG.MONSTER]           = 'MONSTER',
    [FISH_MSG.GIVEUP]            = 'GIVEUP',
    [FISH_MSG.GIVEUP_BAITLOSS]   = 'GIVEUP_BAITLOSS',
}

local DB_SCHEMA         =
{
    signature            = '',
    zone_id              = 0,
    pos_x                = 0.0,
    pos_y                = 0.0,
    pos_z                = 0.0,
    fishing_skill        = 0,
    moon_phase           = 0,
    moon_percent         = 0,
    rod_id               = 0,
    rod_name             = '',
    bait_id              = 0,
    bait_name            = '',
    item_id              = 0,
    item_name            = '',
    item_count           = 0,
    stamina              = 0,
    arrow_delay          = 0,
    regen                = 0,
    move_frequency       = 0,
    arrow_damage         = 0,
    arrow_regen          = 0,
    time                 = 0,
    angler_sense         = 0,
    intuition            = 0,
    bite_delay           = 0,
    bite_type            = '',
    bite_feeling         = '',
    result_type          = '',
    keen_sense_fish_id   = 0,
    keen_sense_fish_name = '',
    skill_up             = 0.0,
    skill_level          = 0,
    caught_at            = 0,
}

local function decode_fishing_message(zone_id, message_id)
    local offset = FISH_OFFSETS[zone_id]
    if not offset then return nil end
    return message_id - offset
end

local function get_equipped_item(slot)
    local inv   = AshitaCore:GetMemoryManager():GetInventory()
    local eitem = inv:GetEquippedItem(slot)
    if not eitem or eitem.Index == 0 then return nil, nil end

    local container = bit.band(eitem.Index, 0xFF00) / 0x0100
    local index     = eitem.Index % 0x0100
    local iitem     = inv:GetContainerItem(container, index)
    if not iitem or iitem.Id == 0 or iitem.Id == 65535 then return nil, nil end

    local name = backend.get_item_name(iitem.Id)
    return iitem.Id, name
end

local function get_fishing_skill()
    local player = AshitaCore:GetMemoryManager():GetPlayer()
    if not player then return 0 end
    local skill = player:GetCraftSkill(SKILL_FISHING)
    return skill and skill:GetSkill() or 0
end

local function format_time(ms)
    if not ms then return '?.??s' end
    return string.format('%.2fs', ms / 1000)
end

local function make_signature(zone_id, rod_id, bait_id, arrow_delay, regen, move_frequency)
    return string.format('%d_%d_%d_%d_%d_%d',
        zone_id or 0, rod_id or 0, bait_id or 0,
        arrow_delay or 0, regen or 0, move_frequency or 0)
end

local function predict_fish(zone_id, rod_id, bait_id, arrow_delay, regen, move_frequency)
    if not addon.databases.global then return nil end
    local sig   = make_signature(zone_id, rod_id, bait_id, arrow_delay, regen, move_frequency)
    local entry = addon.databases.global:find_by('signature', sig)
    if entry and entry.item_id and entry.item_id > 0 then
        return
        {
            item_id   = entry.item_id,
            item_name = backend.get_item_name(entry.item_id) or 'Unknown',
            stamina   = entry.stamina or 0,
        }
    end
    return nil
end

local function schedule_db_write(id, data)
    addon.pendingDbWrite =
    {
        id       = id,
        data     = data,
        write_at = os.clock() + 12.0,
    }
end

local function check_pending_db_write()
    if not addon.pendingDbWrite or os.clock() < addon.pendingDbWrite.write_at then return end
    local id, data = addon.pendingDbWrite.id, addon.pendingDbWrite.data
    if addon.databases.global then
        addon.databases.global:add_or_update(id, data)
    end
    if addon.databases.capture then
        addon.databases.capture:add_or_update(id, data)
    end
    addon.pendingDbWrite = nil
end

addon.onIncomingPacket = function(id, data, size)
    -- 0x036: TALKNUM (fishing messages)
    if id == 0x036 then
        local packet = backend.parsePacket('incoming', data)
        if not packet then return end

        local message_id = bit.band(packet.MesNum, 0x7FFF)
        local msg_type   = decode_fishing_message(addon.state.zone_id, message_id)

        local player     = backend.get_player_entity_data()
        if not player or packet.UniqueNo ~= player.serverId then return end

        if msg_type then
            if BITE_TYPE_STRINGS[msg_type] then
                addon.state.bite_type = BITE_TYPE_STRINGS[msg_type]
            elseif FEELING_STRINGS[msg_type] then
                addon.state.bite_feeling = FEELING_STRINGS[msg_type]
            elseif RESULT_STRINGS[msg_type] then
                addon.state.result_type = RESULT_STRINGS[msg_type]
                if addon.pendingDbWrite then
                    addon.pendingDbWrite.data.result_type = RESULT_STRINGS[msg_type]
                end
            end
        end
        return
    end

    -- 0x02A: TALKNUMWORK (keen sense)
    if id == 0x02A then
        local packet = backend.parsePacket('incoming', data)
        if not packet then return end

        local player = backend.get_player_entity_data()
        if not player or packet.UniqueNo ~= player.serverId then return end

        local msg_type = decode_fishing_message(addon.state.zone_id, packet.MesNum)
        if msg_type == FISH_MSG.KEEN_ANGLERS_SENSE and packet.Num1 and packet.Num1[1] then
            local entry   = packet.Num1[1]
            local fish_id = type(entry) == 'table' and entry.value or entry
            if fish_id and fish_id > 0 then
                addon.state.keen_sense_fish = fish_id
                backend.notificationCreate(addon.name, 'Keen Sense: ' .. (backend.get_item_name(fish_id) or 'Unknown'),
                    {
                        { 'fish_id', fish_id },
                    })
            end
        end
        return
    end

    -- 0x029: BATTLE_MESSAGE (skill ups)
    if id == 0x029 then
        local packet = backend.parsePacket('incoming', data)
        if not packet then return end

        local player = backend.get_player_entity_data()
        if not player or packet.UniqueNoCas ~= player.serverId then return end

        if packet.Data == 48 then -- fishing skill
            local skill_up          = (packet.Data2 or 0) / 10.0
            local new_level         = get_fishing_skill()
            addon.state.skill_up    = skill_up
            addon.state.skill_level = new_level
            if addon.pendingDbWrite then
                addon.pendingDbWrite.data.skill_up = skill_up
            end
        end
        return
    end

    -- 0x115: Fish stats on bite
    if id == 0x115 then
        local packet = backend.parsePacket('incoming', data)
        if not packet then return end

        local now                 = os.clock() * 1000
        local bite_delay          = addon.state.cast_time and (now - addon.state.cast_time) or nil
        addon.state.bite_time     = now

        addon.state.pending_catch =
        {
            zone_id        = addon.state.zone_id,
            pos_x          = addon.state.pos_x,
            pos_y          = addon.state.pos_y,
            pos_z          = addon.state.pos_z,
            bite_delay     = bite_delay,
            fishing_skill  = addon.state.fishing_skill,
            moon_phase     = addon.state.moon_phase,
            moon_percent   = addon.state.moon_percent,
            rod_id         = addon.state.rod_id,
            rod_name       = addon.state.rod_name,
            bait_id        = addon.state.bait_id,
            bait_name      = addon.state.bait_name,
            stamina        = packet.stamina or 0,
            arrow_delay    = packet.arrow_delay or 0,
            regen          = packet.regen or 0,
            move_frequency = packet.move_frequency or 0,
            arrow_damage   = packet.arrow_damage or 0,
            arrow_regen    = packet.arrow_regen or 0,
            time           = packet.time or 0,
            angler_sense   = packet.angler_sense or 0,
            intuition      = packet.intuition or 0,
        }

        local prediction          = predict_fish(
            addon.state.zone_id,
            addon.state.rod_id,
            addon.state.bait_id,
            packet.arrow_delay,
            packet.regen,
            packet.move_frequency
        )

        local notificationData    =
        {
            { 'delay',          format_time(bite_delay) },
            { 'stamina',        packet.stamina or 0 },
            { 'arrow_delay',    packet.arrow_delay or 0 },
            { 'regen',          packet.regen or 0 },
            { 'move_frequency', packet.move_frequency or 0 },
            { 'arrow_damage',   packet.arrow_damage or 0 },
            { 'arrow_regen',    packet.arrow_regen or 0 },
            { 'time',           packet.time or 0 },
            { 'angler_sense',   packet.angler_sense or 0 },
            { 'intuition',      packet.intuition or 0 },
        }

        if prediction then
            table.insert(notificationData, 1, { 'prediction', prediction.item_name })
        end

        backend.notificationCreate(addon.name, '<< GP_SERV_COMMAND_FISHING', notificationData)
        return
    end

    -- 0x027: TALKNUMWORK2 (catch result with item ID)
    if id == 0x027 then
        local packet = backend.parsePacket('incoming', data)
        if not packet then return end

        local player = backend.get_player_entity_data()
        if not player or packet.UniqueNo ~= player.serverId then return end

        local result_message_id   = bit.band(packet.MesNum, 0x7FFF)
        local result_message_type = decode_fishing_message(addon.state.zone_id, result_message_id)
        local result_type         = RESULT_STRINGS[result_message_type]

        if addon.state.pending_catch and packet.Num1 and packet.Num1[1] then
            local entry   = packet.Num1[1]
            local item_id = type(entry) == 'table' and entry.value or entry
            if type(item_id) == 'number' and item_id > 0 and item_id < 65535 then
                local catch      = addon.state.pending_catch
                local item_name  = backend.get_item_name(item_id)

                local item_count = 1
                if result_message_type == FISH_MSG.CATCH_MULTI and packet.Num1[2] then
                    local count_entry = packet.Num1[2]
                    local count_val   = type(count_entry) == 'table' and count_entry.value or count_entry
                    if type(count_val) == 'number' and count_val > 0 then
                        item_count = count_val
                    end
                end

                local keen_sense_fish_name = addon.state.keen_sense_fish and addon.state.keen_sense_fish > 0
                  and backend.get_item_name(addon.state.keen_sense_fish) or nil

                local sig                  = make_signature(catch.zone_id, catch.rod_id, catch.bait_id, catch
                    .arrow_delay, catch.regen, catch.move_frequency)
                local catch_id             = string.format('%d_%d', os.time(), math.random(100000, 999999))

                schedule_db_write(catch_id,
                    {
                        signature            = sig,
                        zone_id              = catch.zone_id or 0,
                        pos_x                = catch.pos_x or 0,
                        pos_y                = catch.pos_y or 0,
                        pos_z                = catch.pos_z or 0,
                        fishing_skill        = catch.fishing_skill or 0,
                        moon_phase           = catch.moon_phase or 0,
                        moon_percent         = catch.moon_percent or 0,
                        rod_id               = catch.rod_id or 0,
                        rod_name             = catch.rod_name or '',
                        bait_id              = catch.bait_id or 0,
                        bait_name            = catch.bait_name or '',
                        item_id              = item_id,
                        item_name            = item_name or 'Unknown',
                        item_count           = item_count,
                        stamina              = catch.stamina or 0,
                        arrow_delay          = catch.arrow_delay or 0,
                        regen                = catch.regen or 0,
                        move_frequency       = catch.move_frequency or 0,
                        arrow_damage         = catch.arrow_damage or 0,
                        arrow_regen          = catch.arrow_regen or 0,
                        time                 = catch.time or 0,
                        angler_sense         = catch.angler_sense or 0,
                        intuition            = catch.intuition or 0,
                        bite_delay           = catch.bite_delay or 0,
                        bite_type            = addon.state.bite_type or '',
                        bite_feeling         = addon.state.bite_feeling or '',
                        result_type          = result_type or '',
                        keen_sense_fish_id   = addon.state.keen_sense_fish or 0,
                        keen_sense_fish_name = keen_sense_fish_name or '',
                        skill_up             = 0,
                        skill_level          = catch.fishing_skill or 0,
                        caught_at            = os.time(),
                    })

                addon.state.pending_catch   = nil
                addon.state.bite_type       = nil
                addon.state.bite_feeling    = nil
                addon.state.result_type     = nil
                addon.state.keen_sense_fish = nil
                addon.state.skill_up        = nil
                addon.state.skill_level     = nil
            end
        end
    end
end

addon.onOutgoingPacket = function(id, data, size)
    -- 0x01A: ACTION (fishing cast)
    if id == 0x01A then
        local packet = backend.parsePacket('outgoing', data)
        if not packet or packet.ActionID ~= 14 then return end

        addon.state.cast_time                      = os.clock() * 1000
        addon.state.bite_time                      = nil
        addon.state.pending_catch                  = nil
        addon.state.bite_type                      = nil
        addon.state.bite_feeling                   = nil
        addon.state.result_type                    = nil
        addon.state.keen_sense_fish                = nil
        addon.state.skill_up                       = nil
        addon.state.skill_level                    = nil

        addon.state.rod_id, addon.state.rod_name   = get_equipped_item(SLOT_RANGE)
        addon.state.bait_id, addon.state.bait_name = get_equipped_item(SLOT_AMMO)
        addon.state.fishing_skill                  = get_fishing_skill()
        addon.state.moon_phase                     = backend.get_moon_phase()
        addon.state.moon_percent                   = backend.get_moon_percent()

        local playerData                           = backend.get_player_entity_data()
        if playerData then
            addon.state.pos_x = tonumber(playerData.x) or 0
            addon.state.pos_y = tonumber(playerData.y) or 0
            addon.state.pos_z = tonumber(playerData.z) or 0
        end
        return
    end

    -- 0x110: Fishing action (reel/release)
    if id == 0x110 then
        local packet = backend.parsePacket('outgoing', data)
        if not packet then return end
        if packet.mode == 4 or packet.mode == 5 then
            addon.state.pending_catch = nil
        end
    end
end

addon.onPrerender      = function()
    check_pending_db_write()
end

addon.onZoneChange     = function(zone_id)
    addon.state.zone_id       = zone_id
    addon.state.cast_time     = nil
    addon.state.bite_time     = nil
    addon.state.pending_catch = nil
end

addon.onInitialize     = function(rootDir)
    addon.rootDir          = rootDir
    addon.state.zone_id    = backend.zone()
    addon.databases.global = backend.databaseOpen(rootDir .. 'fishmon.db', { schema = DB_SCHEMA })
end

addon.onCaptureStart   = function(captureDir)
    addon.captureDir        = captureDir
    addon.databases.capture = backend.databaseOpen(captureDir .. 'fishmon.db', { schema = DB_SCHEMA })
end

addon.onCaptureStop    = function()
    addon.captureDir = nil
    if addon.databases.capture then
        addon.databases.capture:close()
        addon.databases.capture = nil
    end
end

return addon
