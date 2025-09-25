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
    files           =
    {
        global  = nil,
        capture = nil,
    },
}

-- Messages that indicate damage has been dealt
local DAMAGE_MESSAGES         =
{
    [2]   = true, -- Magic damage
    [252] = true, -- Magic burst damage
    [264] = true, -- AOE Magic damage
    [274] = true, -- Magic burst drain
    [648] = true, -- Meteor damage
    [650] = true, -- Meteor burst
}

-- Messages that indicate healing or recovery (not damage)
local HEAL_MESSAGES           =
{
    [7]   = true, -- Magic recovery
    [263] = true, -- AOE recovery
    [651] = true, -- Meteor recovery
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
    [161] = true, -- Drain Samba
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

local function extractDamage(cmd_no, effect)
    local damage  = 0
    local message = effect.message or 0

    if cmd_no == 1 then
        -- Basic attack, or weapon skill
        -- 1 = Melee Attack
        -- 67 = Melee Attack (Crit)
        if message == 1 or message == 67 then
            damage = effect.value
        end
    elseif cmd_no == 2 then
        -- Range Attack (Finish)
        -- 352 = Ranged Attack
        -- 353 = Ranged Attack (Crit)
        if message == 352 or message == 353 then
            damage = effect.value
        end
    elseif cmd_no == 3 then
        -- Skill (Finish)
        damage = effect.value
    elseif cmd_no == 4 then
        -- Magic - check if message type indicates damage
        if message and DAMAGE_MESSAGES[message] then
            damage = effect.value
        end
    elseif cmd_no == 11 then
        -- Trust Actions or Monster Skills
        local kind = effect.kind or 0

        if kind == 3 then
            -- Trust Attack - damage is in value directly
            damage = effect.value
        elseif kind == 2 then
            -- Monster Skill - similar to magic handling
            if message > 0 and not HEAL_MESSAGES[message] then
                -- Physical or magical damage
                if message == 1 or message == 67 or DAMAGE_MESSAGES[message] then
                    damage = effect.value
                end
            end
        end
    elseif cmd_no == 14 and message ~= 0 then
        -- Violent Flourish
        if effect.sub_kind == 25 then
            damage = effect.value
        end
    elseif cmd_no == 15 then
        -- Rune Fencer Effusion (Swipe/Lunge)
        if effect.sub_kind == 10 then
            damage = effect.value
        end
    end

    return damage
end

local function processDamage(mobId, damage, actionData)
    local trackedMob = addon.mobs[mobId]
    if not trackedMob then
        addon.mobs[mobId] =
        {
            id            = mobId,
            damageHistory = {},
        }
        trackedMob        = addon.mobs[mobId]
    end

    local entry =
    {
        damage    = damage,
        timestamp = os.time(),
    }

    table.insert(trackedMob.damageHistory, entry)

    debug_msg('Damage to mob %d: %d [cmd_no: %d, message: %d]',
        mobId, damage, actionData.cmd_no, actionData.message or 0)
end

local function calculateHpRange(trackedMob)
    if not trackedMob or #trackedMob.damageHistory == 0 then
        return 0, 0
    end

    local totalDamage = 0
    for i, entry in ipairs(trackedMob.damageHistory) do
        totalDamage = totalDamage + entry.damage
    end

    if #trackedMob.damageHistory == 1 then
        return 1, totalDamage
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

    -- Min HP = total damage without last combined hit + 1
    local minHp              = totalDamage - lastCombinedDamage + 1

    -- Max HP = total damage
    local maxHp              = totalDamage

    return minHp, maxHp
end

local function processProcDamage(mobId, procData)
    local trackedMob = addon.mobs[mobId]
    if not trackedMob then
        addon.mobs[mobId] =
        {
            id            = mobId,
            damageHistory = {},
        }
        trackedMob        = addon.mobs[mobId]
    end

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

-- Helper function to process react damage from battle actions
local function processReactDamage(targetMobId, actorId, reactData)
    local mobId      = actorId
    local damage     = reactData.value

    local trackedMob = addon.mobs[mobId]
    if not trackedMob then
        addon.mobs[mobId] =
        {
            id            = mobId,
            damageHistory = {},
        }
        trackedMob        = addon.mobs[mobId]
    end

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

-- Create action data from packet fields
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

-- Create proc data object from effect fields
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

-- Create react data object from effect fields
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



addon.onIncomingPacket = function(id, data, size)
    local packet = backend.parsePacket('incoming', data)

    if id == PacketId.GP_SERV_COMMAND_BATTLE2 then -- Action Message
        if not packet or not packet.target then return end
        local cmd_no   = packet.cmd_no
        local actor_id = packet.m_uID

        for _, target in pairs(packet.target) do
            local mobId = target.m_uID

            for _, effect in pairs(target.result) do
                local damage = extractDamage(cmd_no, effect)

                if damage > 0 or (effect.has_react and effect.react and isTrustedReactId(effect.react.message)) then
                    local actionData = createActionData(cmd_no, effect, actor_id)

                    processDamage(mobId, damage, actionData)

                    local proc_data  = createProcData(effect, mobId)
                    local react_data = createReactData(effect, mobId, actor_id)

                    if proc_data then
                        processProcDamage(mobId, proc_data)
                    end

                    if react_data then
                        processReactDamage(mobId, packet.m_uID, react_data)
                    end
                end
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

                local mob          = backend.get_mob_by_index(packet.ActIndexTar)
                local mob_name     = mob and mob.name or tostring(defeatedId)
                local log_string   = string.format('Defeated %s: %d~%d HP',
                    mob_name, minHp, maxHp)

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

addon.onClientReady    = function(zoneId)
    addon.mobs         = {}
    addon.files.global = backend.fileOpen(addon.rootDir .. backend.player_name() .. '/' .. backend.zone_name() .. '.log')
    if addon.files.capture then
        addon.files.capture = backend.fileOpen(addon.captureDir .. backend.zone_name() .. '.log')
    end
end

return addon
