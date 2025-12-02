-- Credits: Original addon by zach2good/Siknoz, rewritten by sruon
-- This addon tracks the delay between basic attacks and estimates the monster's delay based on TP gain
-- The rate of Double Attack/Triple Attack etc are also tracked.
-- None of the data spit out by this addon is to be trusted on its own.
-- Specifically, the following conditions WILL impact the accuracy
-- - Store TP on mob/players
-- - Subtle Blow
-- - Hand to hand mobs
---@class AttackDelayAddon : AddonInterface
local addon =
{
    name            = 'AttackDelay',
    filters         =
    {
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_BATTLE_MESSAGE] = true, -- Battle messages
            [PacketId.GP_SERV_COMMAND_BATTLE2]        = true, -- Action packets
            [PacketId.GP_SERV_COMMAND_GROUP_ATTR]     = true, -- Char Update
        },
    },
    settings        = {},
    defaultSettings =
    {
        showWindow = true,
    },
    mobs            = {},
    charTp          = 0,
    delayWindow     = nil,
    files           =
    {
        global  = nil,
        capture = nil,
    },
}

local function secondsToFFXIDelay(seconds)
    local constant = 60.0 -- ~60 delay per second
    return math.floor(seconds * constant)
end

-- Estimate monster delay based on TP gain
-- Player gets 1/3rd of monster's TP
-- Rule of thumb: 21 TP/hit corresponds to a monster with 240 delay
local function estimateMonsterDelay(playerTpGain)
    return (playerTpGain / 21) * 240
end

local function updateDelayWindow()
    if not addon.settings.showWindow or not addon.delayWindow then
        return
    end

    local target = backend.get_target_entity_data()
    if not target or not backend.is_mob(target.targIndex) then
        addon.delayWindow:hide()
        return
    end

    local trackedMob = addon.mobs[target.serverId]
    if not trackedMob or #trackedMob.delays == 0 then
        addon.delayWindow:hide()
        return
    end

    local sample_count  = #trackedMob.delays
    local sorted_delays = utils.deepCopy(trackedMob.delays)
    table.sort(sorted_delays)

    local sum = 0
    for _, delay in ipairs(sorted_delays) do
        sum = sum + delay
    end

    local median      = stats.median(sorted_delays)

    local ffxi_min    = secondsToFFXIDelay(sorted_delays[1])
    local ffxi_max    = secondsToFFXIDelay(sorted_delays[#sorted_delays])
    local ffxi_median = secondsToFFXIDelay(median)

    -- Build output
    local output      = {}
    table.insert(output, string.format('%-18s %d-%d (Med: %d)', 'Delay:', ffxi_min, ffxi_max, ffxi_median))

    -- Add TP-derived delay if available
    if trackedMob.delayFromTpGain and #trackedMob.delayFromTpGain > 0 then
        local commonDelay = stats.mode(trackedMob.delayFromTpGain, 10)
        if commonDelay then
            table.insert(output, string.format('%-18s %.0f', 'Delay (TP Return):', commonDelay))
        end
    end

    -- Add multi-hit info
    if trackedMob.hitsByRound and #trackedMob.hitsByRound > 0 then
        local hitCounts = {}
        for _, hits in ipairs(trackedMob.hitsByRound) do
            hitCounts[hits] = (hitCounts[hits] or 0) + 1
        end

        local totalRounds = #trackedMob.hitsByRound
        local hit_stats   = {}
        for i = 1, 4 do
            if hitCounts[i] then
                table.insert(hit_stats, string.format('%d:%.0f%%', i, (hitCounts[i] / totalRounds * 100)))
            end
        end

        if #hit_stats > 0 then
            table.insert(output, string.format('%-18s %s', 'Multi:', table.concat(hit_stats, ' ')))
        end
    end

    addon.delayWindow:updateTitle({ { text = target.name, color = { 1.0, 0.65, 0.26, 1.0 } } })
    addon.delayWindow:updateText(table.concat(output, '\n'))
    addon.delayWindow:show()
end

addon.onIncomingPacket = function(id, data, size)
    local packet = backend.parsePacket('incoming', data)
    if not packet then return end

    if id == PacketId.GP_SERV_COMMAND_BATTLE2 then
        -- Calculate the delay in between two Basic Attack action packets
        -- Also keeps track of the number of hits per round (DA/TA/QA etc)
        -- This is _very_ inaccurate for a lot of reasons:
        -- - Network latency
        -- - Client packets processing logic/time
        -- - Server side ticks
        -- - Other actions may happen in between two basic attacks
        -- TODO: We can try and detect if the mob is H2H based on sub_kind
        if not packet or not packet.target then return end
        if packet.cmd_no == 1 then -- Basic Attack
            local knownMob = addon.mobs[packet.m_uID]
            if not knownMob then
                addon.mobs[packet.m_uID] =
                {
                    lastAttack      = os.clock(),
                    delays          = {},
                    isH2H           = false,
                    roundsTracked   = 0,
                    roundsWithKicks = 0,
                    hitsByRound     = {}, -- Track hit count per round
                    hitsBySlot      =
                    {
                        mainHand  = 0,      -- sub_kind 0
                        offHand   = 0,      -- sub_kind 1
                        rightKick = 0,      -- sub_kind 2
                        leftKick  = 0,      -- sub_kind 3
                    },
                    isTracking      = true, -- Track whether we should record delays
                }
            else
                -- Only record delay if we were tracking (not interrupted by spell/TP move)
                if not knownMob.isTracking then
                    -- Resume tracking after getting a melee hit
                    knownMob.isTracking = true
                    knownMob.lastAttack = os.clock()
                    -- Don't record this delay as it includes the spell/ability time
                else
                    local delay_seconds = os.clock() - knownMob.lastAttack
                    knownMob.lastAttack = os.clock()
                    table.insert(knownMob.delays, delay_seconds)
                    knownMob.roundsTracked = knownMob.roundsTracked + 1

                    -- Count hits by slot type and track per-round totals
                    local roundHitCount    = 0
                    local hadKick          = false

                    if packet.target[1] and packet.target[1].result then
                        for _, result in ipairs(packet.target[1].result) do
                            roundHitCount = roundHitCount + 1

                            if result.sub_kind == 0 then
                                knownMob.hitsBySlot.mainHand = knownMob.hitsBySlot.mainHand + 1
                            elseif result.sub_kind == 1 then
                                knownMob.hitsBySlot.offHand = knownMob.hitsBySlot.offHand + 1
                            elseif result.sub_kind == 2 then
                                knownMob.hitsBySlot.rightKick = knownMob.hitsBySlot.rightKick + 1
                                knownMob.isH2H                = true
                                hadKick                       = true
                            elseif result.sub_kind == 3 then
                                knownMob.hitsBySlot.leftKick = knownMob.hitsBySlot.leftKick + 1
                                knownMob.isH2H               = true
                                hadKick                      = true
                            end
                        end
                    end

                    -- Track this round's hit count
                    table.insert(knownMob.hitsByRound, roundHitCount)

                    -- Track if this round had kicks
                    if hadKick then
                        knownMob.roundsWithKicks = knownMob.roundsWithKicks + 1
                    end

                    -- Update window after tracking attack
                    updateDelayWindow()
                end
            end
            -- Handle spell casting and TP moves - pause tracking
        elseif packet.cmd_no == 4 or packet.cmd_no == 8 or packet.cmd_no == 11 then
            -- Category 4: Magic (finish), 8: Magic (start), 11: Mob TP moves
            local knownMob = addon.mobs[packet.m_uID]
            if knownMob then
                -- Pause tracking when mob uses spell or TP move
                knownMob.isTracking = false
            end
        end
    elseif id == PacketId.GP_SERV_COMMAND_GROUP_ATTR then -- Char Update
        -- Assume the TP gain comes from current target
        local curTarget = backend.get_target_entity_data()
        if not curTarget then
            return
        end
        -- Based on TP gain, try to estimate monster delay
        -- Note: This packet does not correlate to an attack, therefore it may be inaccurate for the following reasons:
        -- 1. The player may have been attacked by several monsters, not just the one we're tracking
        -- 2. The monster may have had multiple attacks in the same round
        -- 3. The TP gain may have originated from other sources, such as Meditate/Regain or being hit by a spell
        -- Note also that this does NOT account for:
        -- 1. Subtle blow on the monster
        -- 2. Store TP on the player
        -- 3. Hand-to-hand mobs
        ---@type GP_SERV_COMMAND_GROUP_ATTR
        packet       = packet
        local oldTp  = addon.charTp
        local newTp  = packet.Tp
        local tpDiff = newTp - oldTp
        addon.charTp = newTp

        -- Accept TP gains in the range for monster delays 100-600
        -- This should be roughly 8.75 - 52.5 TP
        -- Some low delay player weapons may get caught in this range.
        if tpDiff >= 9 and tpDiff <= 53 then
            local estimatedDelay = estimateMonsterDelay(tpDiff)
            local mob            = addon.mobs[curTarget.serverId]
            if not mob then
                return
            end

            if not mob.delayFromTpGain then
                mob.delayFromTpGain = {}
            end

            table.insert(mob.delayFromTpGain, estimatedDelay)

            -- Update window after TP gain
            updateDelayWindow()
        end
    elseif id == PacketId.GP_SERV_COMMAND_BATTLE_MESSAGE then
        -- Mob has been defeated, print and log the results
        -- 6 = defeated, 20 = falls to the ground
        if packet and (packet.MessageNum == 6 or packet.MessageNum == 20) and packet.UniqueNoTar then
            local defeatedId = packet.UniqueNoTar
            local trackedMob = addon.mobs[defeatedId]

            if trackedMob then
                local mob      = backend.get_mob_by_index(packet.ActIndexTar)
                local mob_name = mob and mob.name or tostring(defeatedId)

                if #trackedMob.delays > 0 then
                    local sample_count  = #trackedMob.delays

                    local sorted_delays = utils.deepCopy(trackedMob.delays)
                    table.sort(sorted_delays)

                    local sum = 0
                    for _, delay in ipairs(sorted_delays) do
                        sum = sum + delay
                    end

                    local mean         = sum / sample_count
                    local median       = stats.median(sorted_delays)
                    local std_dev      = stats.stddev(sorted_delays, mean)

                    local stats_result =
                    {
                        min     = sorted_delays[1],
                        max     = sorted_delays[#sorted_delays],
                        avg     = mean,
                        median  = median,
                        std_dev = std_dev,
                    }

                    local ffxi_stats   =
                    {
                        min     = secondsToFFXIDelay(stats_result.min),
                        max     = secondsToFFXIDelay(stats_result.max),
                        avg     = secondsToFFXIDelay(stats_result.avg),
                        median  = secondsToFFXIDelay(stats_result.median),
                        std_dev = secondsToFFXIDelay(stats_result.std_dev),
                    }

                    local output_lines = {}

                    -- Line 1: Entity name with sample count and delay range
                    table.insert(output_lines, string.format(
                        '%s (%d hits) - Delay: %d-%d',
                        mob_name, sample_count, ffxi_stats.min, ffxi_stats.max
                    ))

                    -- Line 2: Detailed statistics
                    table.insert(output_lines, string.format(
                        '  Avg: %d | Med: %d | StdDev: %d',
                        ffxi_stats.avg, ffxi_stats.median, ffxi_stats.std_dev
                    ))

                    -- Line 3: TP-derived delay if available
                    if trackedMob.delayFromTpGain and #trackedMob.delayFromTpGain > 0 then
                        local commonDelay = stats.mode(trackedMob.delayFromTpGain, 10)
                        if commonDelay then
                            table.insert(output_lines, string.format(
                                '  Reverse calculation: %.0f (%d samples)',
                                commonDelay, #trackedMob.delayFromTpGain
                            ))
                        end
                    end

                    -- Line 4: Multi-hit percentages
                    if trackedMob.hitsByRound and #trackedMob.hitsByRound > 0 then
                        -- Count rounds by number of hits
                        local hitCounts = {}
                        for _, hits in ipairs(trackedMob.hitsByRound) do
                            hitCounts[hits] = (hitCounts[hits] or 0) + 1
                        end

                        -- Build multi-hit statistics
                        local hit_stats       = {}
                        local totalRounds     = #trackedMob.hitsByRound

                        -- Show percentages for each hit count up to 8
                        local hit_stats_1to3  = {}
                        local hit_stats_4plus = {}

                        for i = 1, 3 do
                            if hitCounts[i] then
                                table.insert(hit_stats_1to3,
                                    string.format('%d-hit: %.0f%%', i, (hitCounts[i] / totalRounds * 100)))
                            end
                        end

                        for i = 4, 8 do
                            if hitCounts[i] then
                                table.insert(hit_stats_4plus,
                                    string.format('%d-hit: %.0f%%', i, (hitCounts[i] / totalRounds * 100)))
                            end
                        end

                        if #hit_stats_1to3 > 0 then
                            table.insert(output_lines,
                                string.format('  Multi-hit: %s', table.concat(hit_stats_1to3, ' | ')))
                        end
                        if #hit_stats_4plus > 0 then
                            table.insert(output_lines,
                                string.format('            %s', table.concat(hit_stats_4plus, ' | ')))
                        end

                        -- Line 5: Slot-based stats
                        if trackedMob.hitsBySlot then
                            local slot_stats = {}

                            -- Calculate hits per slot per round
                            if trackedMob.hitsBySlot.mainHand > 0 then
                                table.insert(slot_stats,
                                    string.format('MH:%.2f', trackedMob.hitsBySlot.mainHand / totalRounds))
                            end

                            if trackedMob.hitsBySlot.offHand > 0 then
                                table.insert(slot_stats,
                                    string.format('OH:%.2f', trackedMob.hitsBySlot.offHand / totalRounds))
                            end

                            -- Add individual kick slot stats
                            if trackedMob.hitsBySlot.rightKick > 0 then
                                table.insert(slot_stats,
                                    string.format('RK:%.2f', trackedMob.hitsBySlot.rightKick / totalRounds))
                            end

                            if trackedMob.hitsBySlot.leftKick > 0 then
                                table.insert(slot_stats,
                                    string.format('LK:%.2f', trackedMob.hitsBySlot.leftKick / totalRounds))
                            end

                            -- Add kick round percentage
                            if trackedMob.roundsWithKicks and trackedMob.roundsWithKicks > 0 then
                                table.insert(slot_stats,
                                    string.format('Kicks:%.0f%%', trackedMob.roundsWithKicks / totalRounds * 100))
                            end

                            if #slot_stats > 0 then
                                table.insert(output_lines,
                                    string.format('  Slots/rnd: %s', table.concat(slot_stats, ' ')))
                            end
                        end
                    end

                    for _, line in ipairs(output_lines) do
                        backend.msg('AttackDelay', line)
                    end

                    local log_text = table.concat(output_lines, '\n') .. '\n\n'

                    if addon.files.global then
                        addon.files.global:append(log_text)
                    end

                    if addon.files.capture then
                        addon.files.capture:append(log_text)
                    end
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
    addon.delayWindow  = backend.textBox('attackdelay')
end

addon.onClientReady    = function(zoneId)
    addon.mobs         = {}
    addon.files.global = backend.fileOpen(addon.rootDir .. backend.player_name() .. '/' .. backend.zone_name() .. '.log')
    if addon.files.capture then
        addon.files.capture = backend.fileOpen(addon.captureDir .. backend.zone_name() .. '.log')
    end
end

addon.onPrerender      = function()
    updateDelayWindow()
end

addon.onConfigMenu     = function()
    return
    {
        {
            key         = 'showWindow',
            title       = 'Show Attack Delay Window',
            description = 'If enabled, displays a window with current attack delay statistics while fighting.',
            type        = 'checkbox',
            default     = addon.defaultSettings.showWindow,
        },
    }
end

return addon
