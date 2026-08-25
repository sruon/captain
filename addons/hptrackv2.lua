-- Credits: Original addon by ibm2431, rewritten by sruon
-- This is more accurate than the original addon (handles procs/reacts) but not perfect.
-- Frankly its annoying to test but !getstats 1 a mob and see if it lines up.
-- Ensure you test: skillchains, procs, reacts (counter, retaliation, etc).
-- TODO: This code can be reused for the following:
-- - Calculating proc rates on weapons / items
---@class HpTrackAddon : AddonInterface
local addon                   =
{
    name            = 'HPTrack',
    filters         =
    {
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_BATTLE_MESSAGE] = true,
            [PacketId.GP_SERV_COMMAND_BATTLE2]        = true,
            [PacketId.GP_SERV_COMMAND_CHAR_NPC]       = true,
        },
    },
    settings        = {},
    defaultSettings =
    {
        color      =
        {
            system = ColorEnum.Purple,
        },
        debug_mode = false,
    },
    mobs            = {},
    hpp             = {}, -- last known HP% per entity id
    prevHpp         = {}, -- the one before it, to anchor a fight at its starting HP%
    files           =
    {
        global  = nil,
        capture = nil,
    },
}

-- [cmd_no][message] -> 1 = damage, -1 = healing, 0 = neither.
-- Anything missing is skipped and logged in debug mode, never counted as damage.
-- Names are the msg_basic.h enum in LSB.
local MSG_TYPES               =
{
    -- Melee attack
    [1]  =
    {
        [1]   = 1,  -- AttackHits
        [67]  = 1,  -- AttackCrit
        [15]  = 0,  -- AttackMisses
        [30]  = 0,  -- TargetAnticipates
        [31]  = 0,  -- ShadowAbsorb
        [32]  = 0,  -- TargetDodges
        [33]  = 0,  -- AttackCounteredDamage, lands on the actor, see REACT_EFFECTS
        [70]  = 0,  -- TargetParries
    },
    -- Ranged attack (finish)
    [2]  =
    {
        [157] = 1,  -- UsesBarrageTakesDamage
        [352] = 1,  -- RangedAttackHit
        [353] = 1,  -- RangedAttackCrit
        [576] = 1,  -- RangedAttackSquarely
        [577] = 1,  -- RangedAttackPummels
        [382] = -1, -- RangedAttackAbsorbs
        [31]  = 0,  -- ShadowAbsorb
        [354] = 0,  -- RangedAttackMiss
    },
    -- Weapon skill / job ability (finish)
    [3]  =
    {
        [135] = 1,  -- WS damage, client-side variant
        [185] = 1,  -- UsesSkillTakesDamage
        [187] = 1,  -- UsesSkillHPDrained
        [197] = 1,  -- UsesAbilityResistsDamage
        [264] = 1,  -- TargetTakesDamage
        [317] = 1,  -- UsesJobAbilityTakeDamage
        [379] = 1,  -- JA magic burst damage
        [102] = -1, -- UsesRecoversHP
        [103] = -1, -- SkillRecoversHP
        [238] = -1, -- UsesSkillRecoversHPAreaOfEffect
        [263] = -1, -- TargetRecoversHP2
        [318] = -1, -- UsesItemRecoversHPAreaOfEffect2
        [539] = -1, -- WS recovers HP
        [158] = 0,  -- AbilityMisses
        [186] = 0,  -- UsesSkillGainsEffect
        [188] = 0,  -- UsesSkillMisses
        [189] = 0,  -- UsesSkillNoEffect
        [194] = 0,  -- gains the effect of (value is a status id, not damage)
        [224] = 0,  -- UsesSkillRecoversMP
        [225] = 0,  -- UsesSkillMPDrained
        [226] = 0,  -- UsesSkillTPDrained
        [323] = 0,  -- UsesAbilityNoEffect
        [324] = 0,  -- UsesButMisses
    },
    -- Magic (finish)
    [4]  =
    {
        [2]   = 1,  -- MagicDamage
        [227] = 1,  -- MagicDrainsHP
        [252] = 1,  -- MagicBurstDamage
        [262] = 1,  -- Magic burst damage (variant)
        [264] = 1,  -- TargetTakesDamage
        [274] = 1,  -- MagicBurstDrainsHP
        [648] = 1,  -- Meteor damage
        [650] = 1,  -- Meteor burst damage
        [7]   = -1, -- MagicRecoversHP
        [263] = -1, -- TargetRecoversHP2
        [651] = -1, -- Meteor recovery
    },
    -- Weapon skill / monster TP move (start)
    [7]  =
    {
        [43]  = 0,  -- ReadiesWeaponskill
    },
    -- Job ability
    [6]  =
    {
        [110] = 1,  -- UsesAbilityTakesDamage
        [264] = 1,  -- TargetTakesDamage
        [317] = 1,  -- UsesJobAbilityTakeDamage
        [263] = -1, -- TargetRecoversHP2
        [318] = -1, -- UsesItemRecoversHPAreaOfEffect2
        [158] = 0,  -- AbilityMisses
        [323] = 0,  -- UsesAbilityNoEffect
        [324] = 0,  -- UsesButMisses
    },
    -- Monster TP move / trust action (finish)
    [11] =
    {
        [185] = 1,  -- UsesSkillTakesDamage
        [187] = 1,  -- UsesSkillHPDrained
        [197] = 1,  -- UsesAbilityResistsDamage
        [264] = 1,  -- TargetTakesDamage
        [238] = -1, -- UsesSkillRecoversHPAreaOfEffect
        [263] = -1, -- TargetRecoversHP2
        [43]  = 0,  -- ReadiesWeaponskill
        [186] = 0,  -- UsesSkillGainsEffect
        [188] = 0,  -- UsesSkillMisses
        [189] = 0,  -- UsesSkillNoEffect
        [194] = 0,  -- gains the effect of (value is a status id, not damage)
    },
    -- Pet ability
    [13] =
    {
        [110] = 1,  -- UsesAbilityTakesDamage
        [185] = 1,  -- UsesSkillTakesDamage
        [264] = 1,  -- TargetTakesDamage
        [317] = 1,  -- UsesJobAbilityTakeDamage
        [238] = -1, -- UsesSkillRecoversHPAreaOfEffect
        [263] = -1, -- TargetRecoversHP2
        [188] = 0,  -- UsesSkillMisses
        [189] = 0,  -- UsesSkillNoEffect
        [323] = 0,  -- UsesAbilityNoEffect
        [324] = 0,  -- UsesButMisses
    },
    -- Dancer job ability (waltzes, flourishes)
    [14] =
    {
        [110] = 1,  -- UsesAbilityTakesDamage
        [264] = 1,  -- TargetTakesDamage
        [102] = -1, -- UsesRecoversHP
        [103] = -1, -- SkillRecoversHP
        [263] = -1, -- TargetRecoversHP2
        [158] = 0,  -- AbilityMisses
        [319] = 0,  -- UsesAbilityGainsEffect
        [323] = 0,  -- UsesAbilityNoEffect
    },
    -- Rune Fencer effusion
    [15] =
    {
        [2]   = 1,  -- MagicDamage
        [110] = 1,  -- UsesAbilityTakesDamage
        [252] = 1,  -- MagicBurstDamage
        [264] = 1,  -- TargetTakesDamage
        [323] = 0,  -- UsesAbilityNoEffect
    },
}

-- Additional effect classifications for proc messages
local PROC_EFFECTS            =
{
    -- Skillchain effects
    [288] = 'Light',
    [289] = 'Darkness',
    [290] = 'Gravitation',
    [291] = 'Fragmentation',
    [292] = 'Distortion',
    [293] = 'Fusion',
    [294] = 'Compression',
    [295] = 'Liquefaction',
    [296] = 'Induration',
    [297] = 'Reverberation',
    [298] = 'Transfixion',
    [299] = 'Scission',
    [300] = 'Detonation',
    [301] = 'Impaction',
    [302] = 'Radiance',
    [767] = 'Radiance',
    [768] = 'Umbra',
    -- Enspells and RUN runes
    [229] = 'Enspell/Rune',
    -- Weapon additional effects
    [163] = 'Additional Effect',
}

-- Known proc messages we want to ignore (not log as unknown)
local KNOWN_NON_DAMAGE_PROCS  =
{
    [0]   = true, -- Haste Samba (No Message)
    [161] = true, -- Drain Samba, absorbs damage already dealt and adds none
    [162] = true, -- Aspir Samba
    [164] = true, -- Added Effect: Status
}

-- Additional effect classifications for react messages
local REACT_EFFECTS           =
{
    -- Spikes effects
    [44]  = 'Spikes/Reprisal',
    [132] = 'Dread Spikes',
    -- Counter effects
    [33]  = 'Counter',
    [536] = 'Retaliation',
}

-- Known react messages we want to ignore (not log as unknown)
local KNOWN_NON_DAMAGE_REACTS =
{
}

local function debug_msg(message, ...)
    if addon.settings.debug_mode then
        backend.msg('HPTrack', string.format(message, ...))
    end
end

local function isTrustedProcId(message_id)
    return PROC_EFFECTS[message_id] ~= nil
end

local function isKnownProc(message_id)
    return PROC_EFFECTS[message_id] ~= nil or KNOWN_NON_DAMAGE_PROCS[message_id] ~= nil
end

local function getProcEffectName(message_id)
    if PROC_EFFECTS[message_id] then
        return PROC_EFFECTS[message_id]
    elseif KNOWN_NON_DAMAGE_PROCS[message_id] then
        return 'Known Non-Damage (' .. message_id .. ')'
    else
        return 'Unknown (' .. message_id .. ')'
    end
end

local function isTrustedReactId(message_id)
    return REACT_EFFECTS[message_id] ~= nil
end

local function isKnownReact(message_id)
    return REACT_EFFECTS[message_id] ~= nil or KNOWN_NON_DAMAGE_REACTS[message_id] ~= nil
end

local function getReactEffectName(message_id)
    if REACT_EFFECTS[message_id] then
        return REACT_EFFECTS[message_id]
    elseif KNOWN_NON_DAMAGE_REACTS[message_id] then
        return 'Known Non-Damage (' .. message_id .. ')'
    else
        return 'Unknown (' .. message_id .. ')'
    end
end

-- Returns damage, healing
local function extractEffect(cmd_no, effect, mobId)
    local message = effect.message or 0
    local byCmd   = MSG_TYPES[cmd_no]
    local sign    = byCmd and byCmd[message]

    if sign == nil then
        debug_msg('Unclassified effect on mob %d: [cmd_no: %d, message: %d, kind: %d, sub_kind: %d, value: %d]',
            mobId, cmd_no, message, effect.kind or 0, effect.sub_kind or 0, effect.value or 0)
        return 0, 0
    end

    if sign == 1 then
        return effect.value, 0
    elseif sign == -1 then
        return 0, effect.value
    end

    return 0, 0
end

local function getTrackedMob(mobId)
    local trackedMob = addon.mobs[mobId]
    if not trackedMob then
        local hpp         = addon.hpp[mobId] or 100
        -- The current HP% may already include damage from an action packet we have not
        -- seen yet, so anchor on the higher of the last two
        local startHpp    = math.max(hpp, addon.prevHpp[mobId] or 0)
        trackedMob        =
        {
            id            = mobId,
            damageHistory = {},
            totalHealing  = 0,
            startHpp      = startHpp,
            hpp           = hpp,
            hpMin         = 1,
            hpMax         = nil, -- until the HP% stream proves one
            invalidCalcs  = 0,
        }
        addon.mobs[mobId] = trackedMob
    end

    return trackedMob
end

local function netDamageOf(trackedMob)
    local total = 0
    for _, entry in ipairs(trackedMob.damageHistory) do
        total = total + entry.damage
    end

    return total - trackedMob.totalHealing
end

-- Narrow the HP range from the mob's HP%. With hpp = floor(100 * hp / maxHp):
--   maxHp >= 100 * netDamage / dHpp    and    maxHp < 100 * netDamage / (dHpp - 1)
-- The 0.99999 keeps that upper bound strict when the division comes out even.
-- HP% and the action packet behind it arrive in the same frame in either order, so the
-- damage it was computed from is somewhere inside the last round: bound with both ends.
local function refineHpRange(trackedMob, roundDamage)
    local dHpp = trackedMob.startHpp - trackedMob.hpp

    -- 0% is post-mortem, 1% spans 0.001-1.999% so its bounds are not whole numbers
    if dHpp <= 0 or trackedMob.hpp <= 1 then
        return
    end

    local netDamage = netDamageOf(trackedMob)
    local minHp     = math.ceil((netDamage - roundDamage) * 100 / dHpp)
    local maxHp     = math.floor(netDamage * 100 / (dHpp - 0.99999))

    if maxHp < trackedMob.hpMin or (trackedMob.hpMax and minHp > trackedMob.hpMax) then
        trackedMob.invalidCalcs = trackedMob.invalidCalcs + 1
        debug_msg('Contradictory HP%% window on mob %d: %d~%d vs %d~%s (regen, DoT or a missed effect)',
            trackedMob.id, minHp, maxHp, trackedMob.hpMin, tostring(trackedMob.hpMax))
        return
    end

    trackedMob.hpMin = math.max(trackedMob.hpMin, minHp)
    trackedMob.hpMax = trackedMob.hpMax and math.min(trackedMob.hpMax, maxHp) or maxHp
end

local function processHealing(mobId, healing, actionData)
    local trackedMob = getTrackedMob(mobId)

    trackedMob.totalHealing = trackedMob.totalHealing + healing

    debug_msg('Healing on mob %d: %d [cmd_no: %d, message: %d]',
        mobId, healing, actionData.cmd_no, actionData.message or 0)
end

local function processDamage(mobId, damage, actionData)
    local trackedMob = getTrackedMob(mobId)

    table.insert(trackedMob.damageHistory,
        {
            damage    = damage,
            timestamp = os.time(),
        })

    debug_msg('Damage to mob %d: %d [cmd_no: %d, message: %d]',
        mobId, damage, actionData.cmd_no, actionData.message or 0)
end

local function calculateHpRange(trackedMob)
    if not trackedMob or #trackedMob.damageHistory == 0 then
        return 0, 0
    end

    local totalDamage = netDamageOf(trackedMob)

    if #trackedMob.damageHistory == 1 then
        return math.max(1, trackedMob.hpMin), math.min(totalDamage, trackedMob.hpMax or totalDamage)
    end

    -- Find the last non-proc non-react damage entry
    local lastDamage       = 0
    local additionalDamage = 0

    -- Work backwards through history to find last main hit and any proc/react hits after it
    for i = #trackedMob.damageHistory, 1, -1 do
        local entry = trackedMob.damageHistory[i]

        if entry.is_proc or entry.is_react then
            additionalDamage = additionalDamage + entry.damage
        else
            lastDamage = entry.damage
            break
        end
    end

    -- Combine the last main hit with any procs/reacts that followed it
    local lastCombinedDamage = lastDamage + additionalDamage

    -- The killing blow overkills by an unknown amount, so death alone only proves HP
    -- sat between everything but the last hit and everything
    local minHp              = totalDamage - lastCombinedDamage + 1
    local maxHp              = totalDamage

    -- Fold in what the HP% stream proved, which is usually far tighter
    local narrowedMin = math.max(minHp, trackedMob.hpMin)
    local narrowedMax = trackedMob.hpMax and math.min(maxHp, trackedMob.hpMax) or maxHp

    -- Trust the damage total when the two disagree, rather than print a backwards range
    if narrowedMin > narrowedMax then
        debug_msg('HP%% range %d~%s does not overlap the damage total range %d~%d on mob %d',
            trackedMob.hpMin, tostring(trackedMob.hpMax), minHp, maxHp, trackedMob.id)
        return minHp, maxHp
    end

    return narrowedMin, narrowedMax
end

local function processProcDamage(mobId, procData)
    local trackedMob = getTrackedMob(mobId)

    local entry =
    {
        damage    = procData.value,
        timestamp = os.time(),
        is_proc   = true,
        proc_type = getProcEffectName(procData.message),
    }

    table.insert(trackedMob.damageHistory, entry)

    debug_msg('Proc damage to mob %d: %d [type: %s]',
        mobId, procData.value, getProcEffectName(procData.message))
end

local function processReactDamage(_, actorId, reactData)
    local mobId      = actorId
    local damage     = reactData.value

    local trackedMob = getTrackedMob(mobId)

    local entry =
    {
        damage     = damage,
        timestamp  = os.time(),
        is_react   = true,
        react_type = getReactEffectName(reactData.message),
    }

    table.insert(trackedMob.damageHistory, entry)

    debug_msg('React damage to actor %d: %d [type: %s]',
        mobId, damage, getReactEffectName(reactData.message))
end

local function createActionData(cmd_no, effect, actor_id)
    return
    {
        cmd_no   = cmd_no,
        message  = effect.message or 0,
        info     = effect.info or 0,
        miss     = effect.miss or 0,
        actor_id = actor_id,
        kind     = effect.kind or 0,
        sub_kind = effect.sub_kind or 0,
        bit      = effect.bit or 0,
    }
end

local function createProcData(effect, mobId)
    if effect.has_proc and effect.proc then
        if not isKnownProc(effect.proc.message) then
            debug_msg('UNKNOWN Proc effect on mob %d: [kind: %d, info: %d, value: %d, message: %d]',
                mobId, effect.proc.kind, effect.proc.info, effect.proc.value, effect.proc.message)
        end

        if isTrustedProcId(effect.proc.message) then
            return
            {
                kind    = effect.proc.kind,
                info    = effect.proc.info,
                value   = effect.proc.value,
                message = effect.proc.message,
            }
        end
    end
    return nil
end

local function createReactData(effect, mobId, actorId)
    if effect.has_react and effect.react then
        if not isKnownReact(effect.react.message) then
            debug_msg('UNKNOWN React effect - Target: %d, Actor: %d [kind: %d, info: %d, value: %d, message: %d]',
                mobId, actorId, effect.react.kind, effect.react.info,
                effect.react.value, effect.react.message)
        end

        if isTrustedReactId(effect.react.message) then
            return
            {
                kind    = effect.react.kind,
                info    = effect.react.info,
                value   = effect.react.value,
                message = effect.react.message,
            }
        end
    end
    return nil
end

addon.onIncomingPacket = function(id, _, _, packet)
    if id == PacketId.GP_SERV_COMMAND_BATTLE2 then -- Action Message
        if not packet or not packet.target then return end
        local cmd_no    = packet.cmd_no
        local actor_id  = packet.m_uID
        local roundDamage = {}

        for _, target in pairs(packet.target) do
            local mobId = target.m_uID

            for _, effect in pairs(target.result) do
                local damage, healing = extractEffect(cmd_no, effect, mobId)

                if healing > 0 then
                    local actionData = createActionData(cmd_no, effect, actor_id)
                    processHealing(mobId, healing, actionData)
                    roundDamage[mobId] = (roundDamage[mobId] or 0) - healing
                elseif damage > 0 or (effect.has_react and effect.react and isTrustedReactId(effect.react.message)) then
                    local actionData = createActionData(cmd_no, effect, actor_id)

                    processDamage(mobId, damage, actionData)
                    roundDamage[mobId] = (roundDamage[mobId] or 0) + damage

                    local proc_data  = createProcData(effect, mobId)
                    local react_data = createReactData(effect, mobId, actor_id)

                    if proc_data then
                        processProcDamage(mobId, proc_data)
                        roundDamage[mobId] = roundDamage[mobId] + proc_data.value
                    end

                    if react_data then
                        processReactDamage(mobId, actor_id, react_data)
                        roundDamage[actor_id] = (roundDamage[actor_id] or 0) + react_data.value
                    end
                end
            end
        end

        -- Narrow once the whole packet is accounted for, so the round total is known
        for mobId, dealt in pairs(roundDamage) do
            local trackedMob = addon.mobs[mobId]
            if trackedMob then
                refineHpRange(trackedMob, math.max(dealt, 0))
            end
        end
    elseif id == PacketId.GP_SERV_COMMAND_CHAR_NPC then -- NPC update
        if packet and packet.SendFlg and packet.SendFlg.General and packet.UniqueNo then
            if addon.hpp[packet.UniqueNo] ~= packet.Hpp then
                addon.prevHpp[packet.UniqueNo] = addon.hpp[packet.UniqueNo]
                addon.hpp[packet.UniqueNo]     = packet.Hpp
            end

            local trackedMob = addon.mobs[packet.UniqueNo]
            if trackedMob then
                trackedMob.hpp = packet.Hpp
            end
        end
    elseif id == PacketId.GP_SERV_COMMAND_BATTLE_MESSAGE then -- Mob Defeated
        if packet and
          (packet.MessageNum == 6 or packet.MessageNum == 20) and -- 6 = defeats, 20 = falls to the ground
          packet.UniqueNoTar
        then
            local defeatedId = packet.UniqueNoTar
            local trackedMob = addon.mobs[defeatedId]

            if trackedMob then
                local minHp, maxHp = calculateHpRange(trackedMob)
                local totalHealing = trackedMob.totalHealing or 0

                local mob          = backend.get_mob_by_index(packet.ActIndexTar)
                local mob_name     = mob and mob.name or tostring(defeatedId)
                local log_string

                if totalHealing > 0 then
                    log_string = string.format('Defeated %s [%d]: %d~%d HP (healed %d)',
                        mob_name, defeatedId, minHp, maxHp, totalHealing)
                else
                    log_string = string.format('Defeated %s [%d]: %d~%d HP',
                        mob_name, defeatedId, minHp, maxHp)
                end

                backend.msg('HPTrack', log_string)

                if addon.files.global then
                    addon.files.global:append(log_string .. '\n')
                end

                if addon.files.capture then
                    addon.files.capture:append(log_string .. '\n')
                end

                addon.mobs[defeatedId] = nil
            end
        end
    end
end

addon.onCaptureStart   = function(captureDir)
    addon.captureDir    = captureDir
    addon.files.capture = backend.fileOpen(captureDir .. backend.zone_name() .. '.log')
end

addon.onCaptureStop    = function()
    addon.captureDir    = nil
    addon.files.capture = nil
end

addon.onInitialize     = function(rootDir)
    addon.rootDir      = rootDir
    addon.files.global = backend.fileOpen(rootDir .. backend.player_name() .. '/' .. backend.zone_name() .. '.log')
end

addon.onClientReady    = function()
    addon.mobs         = {}
    addon.hpp          = {}
    addon.prevHpp      = {}
    addon.files.global = backend.fileOpen(addon.rootDir .. backend.player_name() .. '/' .. backend.zone_name() .. '.log')
    if addon.files.capture then
        addon.files.capture = backend.fileOpen(addon.captureDir .. backend.zone_name() .. '.log')
    end
end

return addon
