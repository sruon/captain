-- Credits: Original code by ibm2431, ported by sruon
---@class HpTrackAddon : AddonInterface
local addon =
{
    name            = 'HPTrack',
    filters         =
    {
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_CHAR_NPC]       = true,
            [PacketId.GP_SERV_COMMAND_BATTLE_MESSAGE] = true,
            [PacketId.GP_SERV_COMMAND_BATTLE2]        = true,
        },
    },
    settings        = {},
    defaultSettings =
    {
        color =
        {
            system = ColorEnum.Purple,
        }
    }
}

local function getMob(id)
    if not addon.db.mobs[id] then
        local mob = backend.get_mob_by_id(id)
        if mob then
            addon.db.mobs[id] = {
                ['id'] = id,
                ['intervals'] = {},
                ['total_damage'] = 0,
                ['process_damage'] = {},
                ['processing_hpp'] = {},
                ['hpp'] = mob.hpp,
                ['last_hpp'] = mob.hpp,
                ['starting_hpp'] = mob.hpp,
                ['name'] = mob.name,
                ['buffered_damage'] = 0,
                ['buffered_gap'] = 0,
            }
        end
    end

    return addon.db.mobs[id]
end

local function calculateIntervals(mob)
    local total_hpp_values = 0
    local total_intervals = 0
    local one_hpp = 0
    local total_dmgs = 0
    local total_hpps = 0
    for _, interval in ipairs(mob.intervals) do
        total_intervals = total_intervals + 1

        --one_hpp = interval.damage / interval.percent_gap
        --total_hpp_values = total_hpp_values + one_hpp

        total_dmgs = total_dmgs + interval.damage
        total_hpps = total_hpps + interval.percent_gap
    end
    if total_intervals > 0 then
        -- return math.floor((total_hpp_values / total_intervals) * 100)
        return math.floor((total_dmgs / total_hpps) * 100)
    else
        return false
    end
end

-- Processes a death _after_ we receive a defeated the X message.
---------------------------------------------------------------------
local function processDeath(mob_id)
    local mob = getMob(mob_id)
    mob.min_hp = mob.total_damage - mob.damage + 1
    mob.max_hp = mob.total_damage
    mob.method = 'I'
    local estimated_hp = calculateIntervals(mob)
    if ((not estimated_hp) or (estimated_hp < mob.min_hp) or (estimated_hp > mob.max_hp)) and (mob.min_hp > 1) then
        mob.method = 'L'
        estimated_hp = math.floor(((mob.min_hp - 1) / (mob.starting_hpp - mob.hpp)) * 100)
    end

    local log_string = "Killed " .. mob.id .. " (" .. mob.name .. "): "
    log_string = log_string .. mob.min_hp .. "~" .. mob.max_hp .. "HP"
    if estimated_hp and (estimated_hp >= mob.min_hp and estimated_hp <= mob.max_hp) then
        log_string = log_string .. ", Est.HP: " .. estimated_hp .. " (Mthd: " .. mob.method .. ")"
    end

    backend.msg('HPTrack', log_string)

    addon.file.simple:append(log_string .. "\n\n")

    if captain.isCapturing then
        addon.file.capture.simple:append(log_string .. "\n\n")
    end
end

local function processDamage(mob)
    local percent_gap = mob.buffered_gap
    if mob.hpp > 0 then
        if percent_gap > 1 then
            local new_interval_slice = {
                ['percent_gap'] = percent_gap,
                ['damage'] = mob.buffered_damage
            }
            table.insert(mob.intervals, new_interval_slice)
            mob.buffered_damage = 0
            mob.buffered_gap = 0
            mob.update_first = false
            mob.damage_first = false
        end
    end
end

local function dealDamage(id, damage)
    local mob = getMob(id)

    mob.damage = damage
    mob.total_damage = mob.total_damage + damage
    if mob.update_first and mob.hpp > 0 then
        -- The mob's new HPP came before this damage packet did
        mob.buffered_damage = mob.buffered_damage + damage
        processDamage(mob)
    else
        -- We haven't received the HPP update for this damage yet
        mob.damage_first = true
        mob.buffered_damage = mob.buffered_damage + damage
    end
end

local function parseAction(data)
    local action = backend.parsePacket('incoming', data)
    local test = function(action)
        local result = {}
        for _, target in pairs(action.target) do
            local mob_id = target.m_uID
            result[mob_id] = {
                dmg = 0
            }
            for i, effect in pairs(target.result) do
                local msg = addon.msg_types[action.cmd_no][effect.message]
                if msg and effect.value then
                    result[mob_id].msg_type = msg[1]
                    if msg[2] ~= 0 then
                        result[mob_id].dmg = result[mob_id].dmg + (effect.value * msg[2])
                    end
                end

                --local add_effect_message = effect.add_effect_message
                --[[
                if add_effect_message then
                  add_effect_message = addon.add_effect_types[action.category][add_effect_message]
                  if add_effect_message then
                    result[mob_id].dmg = result[mob_id].dmg + (effect.param * add_effect_message[2])
                  end
                end
                --]]

                --[[
                result[mob_id] = { msg_type = addon.msg_types[1][effect.message]}
                if effect.message ~= 15 then
                  result[mob_id].dmg = effect.param
                else -- Missed
                  result[mob_id].dmg = 0
                end
                --]]

                --if effect.spike_effect_param then
                --    if not result[action.actor_id] then
                --        result[action.actor_id] = {
                --            msg_type = 'Spikes / Counter',
                --            dmg = effect.spike_effect_param
                --        }
                --    else
                --        result[action.actor_id].dmg = result[action.actor_id].dmg + effect.spike_effect_param
                --    end
                --end
            end
        end
        return result
    end
    if addon.msg_types[action.cmd_no] then
        local result = test(action)
        if result then
            for mob_id, r in pairs(result) do
                if r.dmg ~= 0 then
                    dealDamage(mob_id, r.dmg)
                end
            end
            return result
        end
    elseif action.result and action.result[1] and action.result[1].message == 6 then
        local mob_id = action.target[1].m_uID
        processDeath(mob_id)
    end
end

-- Sets up tables and files for use in the current zone
--------------------------------------------------
local function setupZone(zone, zone_left)
    local zone_name = backend.zone_name(zone)

    addon.file.simple = backend.fileOpen(addon.rootDir .. 'simple/' .. zone_name .. '.log')

    if captain.isCapturing then
        addon.file.capture.simple = backend.fileOpen(addon.captureDir .. 'simple/' .. zone_name .. '.log')
    end
end

-- Checks an incoming chunk for a spawn packet
------------------------------------------------
local function checkChunk(id, data, modified, injected, blocked)
    if id == PacketId.GP_SERV_COMMAND_CHAR_NPC then
        local packet = backend.parsePacket('incoming', data)
        if packet.SendFlg.Position and packet.SendFlg.ClaimStatus and packet.SendFlg.General then
            local mob = getMob(packet.UniqueNo)
            local packet_hpp = packet.Hpp

            if mob and mob.hpp and packet_hpp > 0 then
                mob.last_hpp = mob.hpp
                mob.hpp = packet_hpp
                mob.buffered_gap = mob.buffered_gap + (mob.last_hpp - mob.hpp)
                if mob.damage_first then
                    -- The action packet came before this update packet, so we
                    -- can go ahead and process the Damage/HP% interval
                    processDamage(mob)
                else
                    -- This update packet is coming before the damage, we want to
                    -- buffer the very next damage to be applied to this new hpp loss
                    mob.update_first = true
                end
            end
        end
    elseif (id == PacketId.GP_SERV_COMMAND_BATTLE_MESSAGE) then                    -- Action Message Packet (Not to be confused with an Action)
        local action_message = backend.parsePacket('incoming', data)
        if (action_message.MessageNum == 6) then -- Mob defeated
            local defeated_id = action_message.UniqueNoTar
            processDeath(defeated_id)
            addon.db.mobs[defeated_id] = nil
        end
    end
end

---------------------------------------------------------------------------------
-- INITIALIZE
---------------------------------------------------------------------------------
local function initialize(rootDir)
    ---------------------------------------------------------------------------------
    -- DISPLAY COLORS AND LOG HEADERS
    ---------------------------------------------------------------------------------

    addon.rootDir = rootDir
    addon.color = {}
    addon.color.log =
    { -- Preformatted character codes for log colors.
        SYSTEM = colors[addon.settings.color.system].chatColorCode,
    }

    ---------------------------------------------------------------------------------
    -- VARIABLES AND TEMPLATES
    ---------------------------------------------------------------------------------

    addon.vars = {}
    addon.vars.my_name = backend.player_name()
    addon.db = {}
    addon.db.mobs = {}
    addon.vars.current_zone = 0

    addon.msg_types = {
        [1] = {
            [1] = { 'Melee Attack', 1 },
            [15] = { '(Miss) Melee Attack', 0 },
            [67] = { 'Melee Attack (Crit)', 1 },

        },
        [2] = {
            [352] = { 'Ranged Attack', 1 },
            [353] = { 'Ranged Attack (Crit)', 1 },
            [354] = { '(Miss) Ranged Attack', 0 },
            [576] = { 'Ranged Attack (Squarely)', 1 },
            [577] = { 'Ranged Attack (Truestrike)', 1 },
        },
        [3] = {
            [102] = { 'JA (Recover)', -1 },
            [103] = { 'WS (Recover', -1 },
            --[135] = {'WS', 1},
            --[142] = {'WS (Stat Down)', 1},
            --[159] = {'WS (Status Recover)', -1},
            [185] = { 'WS', 1 },
            --[186] = {'WS (Stat Down)', 1},
            [187] = { 'WS (HP Drain)', 1 },
            [188] = { '(Miss) WS', 0 },
            [189] = { 'WS (No Effect)', 0 },
            --[194] = {'WS (Status)', 1},
            [197] = { 'WS (Resisted)', 1 },
            --[224] = {'WS (Recover MP)', -1},
            --[225] = {'WS (MP Drain)', 1},
            --[226] = {'WS (TP Drain)', 1},
            [238] = { 'WS (Recover)', -1 },
            [263] = { 'AOE (Recovery)', -1 },
            [264] = { 'AOE Damage', 1 },
            [317] = { 'JA Hit', 1 },
            [318] = { 'JA (Recover)', -1 },
            [323] = { 'JA (No Effect)', 0 },
            [324] = { '(Miss) JA', 0 },
            [379] = { 'JA (Magic Burst)', 1 },
            [539] = { 'WS (Recover)', -1 },
        },
        [4] = {
            [2] = { 'Magic Damage', 1 },
            [7] = { 'Magic (Recovery)', -1 },
            [227] = { 'Magic (Drain)', 1 },
            [252] = { 'Magic (Burst)', 1 },
            [262] = { 'Magic (Burst)', 1 },
            [263] = { 'AOE (Recovery)', -1 },
            [264] = { 'AOE Damage', 1 },
            [274] = { 'Magic (Burst Drain)', 1 },
            [648] = { 'Meteor', 1 },
            [650] = { 'Meteor (Burst)', 1 },
            [651] = { 'Meteor (Recover)', -1 },
        },
        [6] = {
            [110] = { 'Ability Dmg', 1 },
            [263] = { 'AOE (Recovery)', -1 },
            [264] = { 'AOE Damage', 1 },
        }
    }

    addon.add_effect_types = {
        [3] = {
            [288] = { 'SC: Light', 1 },
            [289] = { 'SC: Darkness', 1 },
            [290] = { 'SC: Gravitation', 1 },
            [291] = { 'SC: Fragmentation', 1 },
            [292] = { 'SC: Distortion', 1 },
            [293] = { 'SC: Fusion', 1 },
            [294] = { 'SC: Compression', 1 },
            [295] = { 'SC: Liquefaction', 1 },
            [296] = { 'SC: Induration', 1 },
            [297] = { 'SC: Reverberation', 1 },
            [298] = { 'SC: Transfixion', 1 },
            [299] = { 'SC: Scission', 1 },
            [300] = { 'SC: Detonation', 1 },
            [301] = { 'SC: Impaction', 1 },
            [302] = { 'SC: Cosmic Elucidation', 1 },
            [767] = { 'SC: Radiance', 1 },
            [768] = { 'SC: Umbra', 1 },
        }
    }

    addon.file = T {}
    addon.file.capture = T {}
    addon.file.simple = backend.fileOpen(addon.rootDir .. backend.player_name() .. '/logs/simple.log')

    setupZone(backend.zone())
end

addon.onZoneChange = setupZone

addon.onIncomingPacket = function(id, data, size)
    if id == PacketId.GP_SERV_COMMAND_BATTLE2 then
        parseAction(data)
    else
        checkChunk(id, data)
    end
end

addon.onCaptureStart = function(captureDir)
    addon.captureDir = captureDir
    setupZone(backend.zone())
end

addon.onCaptureStop = function()
    addon.captureDir          = nil
    addon.file.capture.simple = nil
    addon.file.capture.raw    = nil
end

addon.onInitialize = initialize

return addon
