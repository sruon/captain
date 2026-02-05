-- Credits: sruon
-- Polls all mobs in zone via CHARREQ2 and logs positions.
-- HIGHLY DETECTABLE - Only use with throw-away accounts.

---@class TurboPathLogAddon : AddonInterface
local addon          =
{
    name            = 'TurboPathLog',
    filters         =
    {
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_CHAR_NPC] = true,
        },
    },
    settings        = {},
    defaultSettings =
    {
        thisWillGetMeBanned = false,
        pollInterval        = 5.0,
    },
    csvFiles        = {},
    lastPositions   = {},
    trackedMobs     = {},
    mobStats        = {},
    pendingRequests = {},
    polling         = false,
    discoveryMode   = false,
    lastStatsTime   = 0,
    statsInterval   = 30,
}

addon.onInitialize   = function(rootDir)
    addon.rootDir = rootDir
end

addon.onCaptureStart = function(captureDir)
    addon.closeAllFiles()
    addon.csvFiles      = {}
    addon.lastPositions = {}
    addon.trackedMobs   = {}
    addon.mobStats      = {}
    addon.captureDir    = captureDir
end

addon.onCaptureStop  = function()
    addon.stopPolling()
    addon.closeAllFiles()
    addon.csvFiles      = {}
    addon.lastPositions = {}
    addon.trackedMobs   = {}
    addon.mobStats      = {}
    addon.captureDir    = nil
end

addon.onZoneChange   = function()
    addon.stopPolling()
    addon.closeAllFiles()
    addon.csvFiles      = {}
    addon.lastPositions = {}
    addon.trackedMobs   = {}
    addon.mobStats      = {}
end

addon.closeAllFiles  = function()
    for _, csvFile in pairs(addon.csvFiles) do
        if csvFile then
            csvFile:close()
        end
    end
end

addon.stopPolling    = function()
    addon.polling       = false
    addon.discoveryMode = false
end

local startDiscoverySweep
local startPollingLoop

local function printMobStats()
    local currentTime = os.time()
    if currentTime - addon.lastStatsTime < addon.statsInterval then
        return
    end
    addon.lastStatsTime = currentTime

    backend.msg('TurboPathLog', '--- Mob Stats ---')

    local mobList = {}
    for _, mobData in pairs(addon.trackedMobs) do
        local stats = addon.mobStats[mobData.uniqueNo]
        if stats then
            table.insert(mobList, {
                name     = mobData.name,
                posCount = stats.posCount or 0,
            })
        end
    end

    table.sort(mobList, function(a, b) return a.posCount > b.posCount end)

    local limit = math.min(#mobList, 10)
    for i = 1, limit do
        local m = mobList[i]
        backend.msg('TurboPathLog', string.format('  %s: %d pos', m.name, m.posCount))
    end

    if #mobList > limit then
        backend.msg('TurboPathLog', string.format('  ... and %d more mobs', #mobList - limit))
    end

    local totalPos = 0
    for _, m in ipairs(mobList) do
        totalPos = totalPos + m.posCount
    end
    backend.msg('TurboPathLog', string.format('Total: %d mobs, %d positions recorded', #mobList, totalPos))
end

local function sendCharReq2(actIndex, uniqueNo2, uniqueNo3)
    actIndex  = actIndex or 0
    uniqueNo2 = uniqueNo2 or 0
    uniqueNo3 = uniqueNo3 or 0

    backend.injectPacket(PacketId.GP_CLI_COMMAND_CHARREQ2,
        {
            PacketId.GP_CLI_COMMAND_CHARREQ2,
            0x00, 0x00, 0x00,
            bit.band(actIndex, 0xFF),
            bit.band(bit.rshift(actIndex, 8), 0xFF),
            0x00, 0x00,
            bit.band(uniqueNo2, 0xFF),
            bit.band(bit.rshift(uniqueNo2, 8), 0xFF),
            bit.band(bit.rshift(uniqueNo2, 16), 0xFF),
            bit.band(bit.rshift(uniqueNo2, 24), 0xFF),
            bit.band(uniqueNo3, 0xFF),
            bit.band(bit.rshift(uniqueNo3, 8), 0xFF),
            bit.band(bit.rshift(uniqueNo3, 16), 0xFF),
            bit.band(bit.rshift(uniqueNo3, 24), 0xFF),
            0x00, 0x00,
            0x00, 0x00,
        })
end

startDiscoverySweep = function()
    addon.discoveryMode   = true
    addon.discoveredCount = 0
    addon.trackedMobs     = {}

    backend.msg('TurboPathLog', 'Starting discovery sweep...')

    for actIndex = 1, 1023 do
        backend.schedule(function()
            if addon.discoveryMode then
                sendCharReq2(actIndex, 0, 0)
            end
        end, (actIndex - 1) * 0.01)
    end

    backend.schedule(function()
        addon.discoveryMode = false
        local mobCount = 0
        for _ in pairs(addon.trackedMobs) do
            mobCount = mobCount + 1
        end

        backend.msg('TurboPathLog', string.format('Discovery complete. Found %d mobs.', mobCount))

        if mobCount > 0 and addon.polling then
            startPollingLoop()
        elseif mobCount == 0 then
            backend.msg('TurboPathLog', 'No mobs found.')
            addon.polling = false
        end
    end, 11)
end

startPollingLoop = function()
    if not addon.polling then
        return
    end

    local mobCount = 0
    for _ in pairs(addon.trackedMobs) do
        mobCount = mobCount + 1
    end

    if mobCount == 0 then
        backend.msg('TurboPathLog', 'No mobs to poll. Stopping.')
        addon.polling = false
        return
    end

    local currentTime = os.time()
    local dueMobs = {}

    for _, mobData in pairs(addon.trackedMobs) do
        local stats = addon.mobStats[mobData.uniqueNo]

        if not stats then
            addon.mobStats[mobData.uniqueNo] = {
                sleepUntil      = 0,
                posCount        = 0,
                nextPollTime    = currentTime,
                staleCount      = 0,
                currentInterval = addon.settings.pollInterval,
            }
            stats = addon.mobStats[mobData.uniqueNo]
        end

        if stats.sleepUntil and currentTime < stats.sleepUntil then
            -- sleeping
        elseif not stats.nextPollTime or currentTime >= stats.nextPollTime then
            table.insert(dueMobs, mobData)
            stats.nextPollTime = currentTime + 60
        end
    end

    for i, mobData in ipairs(dueMobs) do
        backend.schedule(function()
            if addon.polling then
                addon.pendingRequests[mobData.uniqueNo] = true
                sendCharReq2(mobData.actIndex, mobData.uniqueNo, 0)
            end
        end, (i - 1) * 0.02)
    end

    printMobStats()

    backend.schedule(function()
        if addon.polling then
            startPollingLoop()
        end
    end, 1)
end

local function trackPosition(uniqueNo, x, y, z, dir, mobName)
    if x == 0 and y == 0 and z == 0 then
        return
    end

    local currentTime = os.time()

    if not addon.mobStats[uniqueNo] then
        addon.mobStats[uniqueNo] = {
            sleepUntil      = 0,
            posCount        = 0,
            nextPollTime    = currentTime,
            staleCount      = 0,
            currentInterval = addon.settings.pollInterval,
        }
    end
    local stats = addon.mobStats[uniqueNo]

    local lastPos = addon.lastPositions[uniqueNo]
    if lastPos and lastPos.x == x and lastPos.y == y and lastPos.z == z and lastPos.dir == dir then
        stats.staleCount = (stats.staleCount or 0) + 1
        if stats.staleCount >= 3 then
            local newInterval = math.min((stats.currentInterval or addon.settings.pollInterval) * 2, 30)
            stats.currentInterval = newInterval
        end
        return
    end

    stats.staleCount = 0
    stats.currentInterval = addon.settings.pollInterval
    stats.posCount = stats.posCount + 1

    if not addon.csvFiles[uniqueNo] then
        local baseDir            = addon.captureDir or addon.rootDir
        addon.csvFiles[uniqueNo] = backend.csvOpen(
            string.format('%s/%s/%s/%s/%s.csv',
                baseDir,
                backend.player_name(),
                backend.zone_name(),
                mobName,
                uniqueNo),
            { 'x', 'y', 'z', 'dir', 'timestamp' })
    end

    addon.csvFiles[uniqueNo]:add_entry({
        x         = x,
        y         = y,
        z         = z,
        dir       = dir,
        timestamp = currentTime,
    })
    addon.csvFiles[uniqueNo]:save()

    addon.lastPositions[uniqueNo] = { x = x, y = y, z = z, dir = dir }
end

addon.onCommand      = function(cmdArgs)
    local rootCmd = cmdArgs[1]

    if rootCmd == 'start' then
        if not addon.settings.thisWillGetMeBanned then
            backend.msg('TurboPathLog', 'Must accept disclaimer in settings.')
            return
        end

        if addon.polling then
            backend.msg('TurboPathLog', 'Already running.')
            return
        end

        addon.polling = true
        startDiscoverySweep()

    elseif rootCmd == 'stop' then
        if not addon.polling and not addon.discoveryMode then
            backend.msg('TurboPathLog', 'Not running.')
            return
        end

        addon.stopPolling()
        backend.msg('TurboPathLog', 'Stopped.')

    elseif rootCmd == 'status' then
        local mobCount = 0
        for _ in pairs(addon.trackedMobs) do
            mobCount = mobCount + 1
        end

        local fileCount = 0
        for _ in pairs(addon.csvFiles) do
            fileCount = fileCount + 1
        end

        backend.msg('TurboPathLog', string.format(
            'Status: %s | Tracking %d mobs | %d files | Zone: %s',
            addon.polling and 'POLLING' or (addon.discoveryMode and 'DISCOVERING' or 'STOPPED'),
            mobCount,
            fileCount,
            backend.zone_name() or 'Unknown'))
    end
end

addon.onIncomingPacket = function(id, data, size, packet)
    if id == PacketId.GP_SERV_COMMAND_CHAR_NPC then
        if not packet then
            return
        end

        if addon.discoveryMode then
            if packet.Flags1 and packet.Flags1.MonsterFlag == 1 then
                local mob     = backend.get_mob_by_index(packet.ActIndex)
                local mobName = mob and mob.name or string.format('Mob_%d', packet.ActIndex)

                addon.trackedMobs[packet.ActIndex] =
                {
                    uniqueNo = packet.UniqueNo,
                    actIndex = packet.ActIndex,
                    name     = mobName,
                }

                local mobCount = 0
                for _ in pairs(addon.trackedMobs) do mobCount = mobCount + 1 end
                local stagger = (mobCount % math.floor(addon.settings.pollInterval))
                addon.mobStats[packet.UniqueNo] = {
                    sleepUntil      = 0,
                    posCount        = 0,
                    nextPollTime    = os.time() + stagger,
                    staleCount      = 0,
                    currentInterval = addon.settings.pollInterval,
                }
            end
            return
        end

        if not addon.polling then
            return
        end

        local mobData = addon.trackedMobs[packet.ActIndex]
        if not mobData then
            return
        end

        if not packet.SendFlg or not packet.SendFlg.Position then
            return
        end

        local mob     = backend.get_mob_by_index(packet.ActIndex)
        local mobName = mob and mob.name or mobData.name

        local currentTime = os.time()
        if not addon.mobStats[packet.UniqueNo] then
            addon.mobStats[packet.UniqueNo] = {
                sleepUntil      = 0,
                posCount        = 0,
                nextPollTime    = currentTime,
                staleCount      = 0,
                currentInterval = addon.settings.pollInterval,
            }
        end
        local stats = addon.mobStats[packet.UniqueNo]

        if addon.pendingRequests[packet.UniqueNo] then
            addon.pendingRequests[packet.UniqueNo] = nil
            local interval = stats.currentInterval or addon.settings.pollInterval
            stats.nextPollTime = currentTime + interval
        end

        if packet.Hpp and packet.Hpp == 0 then
            stats.sleepUntil = currentTime + 5
            return
        end

        if packet.BtTargetID and packet.BtTargetID ~= 0 then
            return
        end

        local fastMobs = { ['Goblin Bounty Hunter'] = true }
        if packet.Speed and packet.SpeedBase and packet.Speed ~= packet.SpeedBase then
            if not fastMobs[mobName] then
                return
            end
        end

        trackPosition(
            packet.UniqueNo,
            packet.x,
            packet.z,
            packet.y,
            packet.dir,
            mobName
        )
    end
end

local commands       =
{
    { cmd = 'start', desc = 'Start polling.' },
    { cmd = 'stop', desc = 'Stop polling.' },
    { cmd = 'status', desc = 'Show status.' },
}

addon.onHelp         = function()
    return commands
end

addon.onConfigMenu   = function()
    return
    {
        {
            key         = 'thisWillGetMeBanned',
            title       = 'I understand this is highly detectable.',
            description = 'Required to execute commands.',
            type        = 'checkbox',
            default     = addon.defaultSettings.thisWillGetMeBanned,
        },
        {
            key         = 'pollInterval',
            title       = 'Poll Interval (s)',
            description = 'Seconds between polls.',
            type        = 'slider',
            min         = 1,
            max         = 10,
            step        = 1,
            default     = addon.defaultSettings.pollInterval,
        },
    }
end

return addon
