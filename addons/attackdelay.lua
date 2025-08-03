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
    },
    mobs            = {},
    charTp          = 0,
    files           =
    {
        global = nil,
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
                    lastAttack = os.clock(),
                    delays = {},
                    hitsPerRound = {},
                }
            else
                local delay_seconds = os.clock() - knownMob.lastAttack
                knownMob.lastAttack = os.clock()
                table.insert(knownMob.delays, delay_seconds)
                knownMob.hitsPerRound[packet.target[1].result_sum] = (knownMob.hitsPerRound[packet.target[1].result_sum] or 0) +
                  1
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
        packet = packet
        local oldTp = addon.charTp
        local newTp = packet.Tp
        local tpDiff = newTp - oldTp
        addon.charTp = newTp

        -- Accept TP gains in the range for monster delays 100-600
        -- This should be roughly 8.75 - 52.5 TP
        -- Some low delay player weapons may get caught in this range.
        if tpDiff >= 9 and tpDiff <= 53 then
            local estimatedDelay = estimateMonsterDelay(tpDiff)
            local mob = addon.mobs[curTarget.serverId]
            if not mob then
                return
            end

            if not mob.delayFromTpGain then
                mob.delayFromTpGain = {}
            end

            table.insert(mob.delayFromTpGain, estimatedDelay)
        end
    elseif id == PacketId.GP_SERV_COMMAND_BATTLE_MESSAGE then
        -- Mob has been defeated, print and log the results
        if packet and packet.MessageNum == 6 and packet.UniqueNoTar then
            local defeatedId = packet.UniqueNoTar
            local trackedMob = addon.mobs[defeatedId]

            if trackedMob then
                local mob = backend.get_mob_by_index(packet.ActIndexTar)
                local mob_name = mob and mob.name or tostring(defeatedId)

                if #trackedMob.delays > 0 then
                    local sample_count = #trackedMob.delays

                    local sorted_delays = utils.deepCopy(trackedMob.delays)
                    table.sort(sorted_delays)

                    local sum = 0
                    for _, delay in ipairs(sorted_delays) do
                        sum = sum + delay
                    end

                    local mean = sum / sample_count
                    local median = stats.median(sorted_delays)
                    local std_dev = stats.stddev(sorted_delays, mean)

                    local stats_result =
                    {
                        min = sorted_delays[1],
                        max = sorted_delays[#sorted_delays],
                        avg = mean,
                        median = median,
                        std_dev = std_dev,
                    }

                    local ffxi_stats =
                    {
                        min = secondsToFFXIDelay(stats_result.min),
                        max = secondsToFFXIDelay(stats_result.max),
                        avg = secondsToFFXIDelay(stats_result.avg),
                        median = secondsToFFXIDelay(stats_result.median),
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
                                '  TP-Delay: %.0f (%d samples)',
                                commonDelay, #trackedMob.delayFromTpGain
                            ))
                        end
                    end

                    -- Line 4: Multi-hit percentages if any
                    local hit_distribution = stats.distribution(trackedMob.hitsPerRound, nil, nil)

                    if next(hit_distribution) then
                        local hit_stats = {}
                        for rounds, percentage in pairs(hit_distribution) do
                            table.insert(hit_stats, string.format('%d-hit: %.0f%%', rounds, percentage))
                        end
                        table.insert(output_lines, string.format('  Multi-hits: %s', table.concat(hit_stats, ' | ')))
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

addon.onCaptureStart = function(captureDir)
    addon.captureDir = captureDir
    addon.files.capture = backend.fileOpen(captureDir .. backend.zone_name() .. '.log')
end

addon.onCaptureStop = function()
    addon.captureDir = nil
    addon.files.capture = nil
end

addon.onInitialize = function(rootDir)
    addon.rootDir = rootDir
    addon.files.global = backend.fileOpen(rootDir .. backend.player_name() .. '/' .. backend.zone_name() .. '.log')
end

addon.onClientReady = function(zoneId)
    addon.mobs = {}
    addon.files.global = backend.fileOpen(addon.rootDir .. backend.player_name() .. '/' .. backend.zone_name() .. '.log')
    if addon.files.capture then
        addon.files.capture = backend.fileOpen(addon.captureDir .. backend.zone_name() .. '.log')
    end
end

return addon
