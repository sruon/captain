-- Logs mission and quest log updates
---@class MissionTrackAddon : AddonInterface
local addon                  =
{
    name            = 'MissionTrack',
    filters         =
    {
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_MISSION] = true,
        },
    },
    settings        = {},
    defaultSettings = {},
    files           =
    {
        global  = nil,
        capture = nil,
    },
    portData        = {},
    initializedPort = {},
}

local PORT_MAIN_MISSION      = 0xFFFF
local PORT_TVR               = 0xFFFE

local NationNames            =
{
    [0] = 'San d\'Oria',
    [1] = 'Bastok',
    [2] = 'Windurst',
}

-- Port 0xFFFF field mappings
local MainMissionFields      =
{
    [1] = 'Nation',
    [2] = 'Nation Mission',
    [3] = 'RotZ',
    [4] = 'CoP',
    [5] = 'CoP Extended',
    [6] = 'Addons/Tales',
    [7] = 'SoA',
    [8] = 'RoV',
}

local QuestOffer             =
{
    [0x0050] = 'San d\'Oria',
    [0x0058] = 'Bastok',
    [0x0060] = 'Windurst',
    [0x0068] = 'Jeuno',
    [0x0070] = 'Other Areas',
    [0x0078] = 'Outlands',
    [0x0080] = 'Aht Urhgan',
    [0x0088] = 'Crystal War',
    [0x00E0] = 'Abyssea',
    [0x00F0] = 'Adoulin',
    [0x0100] = 'Coalition',
}

local QuestComplete          =
{
    [0x0090] = 'San d\'Oria',
    [0x0098] = 'Bastok',
    [0x00A0] = 'Windurst',
    [0x00A8] = 'Jeuno',
    [0x00B0] = 'Other Areas',
    [0x00B8] = 'Outlands',
    [0x00C0] = 'Aht Urhgan',
    [0x00C8] = 'Crystal War',
    [0x00E8] = 'Abyssea',
    [0x00F8] = 'Adoulin',
    [0x0108] = 'Coalition',
}

local MissionComplete        =
{
    [0x0030] = 'Campaign (1-256)',
    [0x0038] = 'Campaign (257-512)',
    [0x00D0] = 'Nations/RotZ',
    [0x00D8] = 'ToAU/WoTG',
}

-- Port 0x0080 Data[5-8] are mission progress values, not bitflags
local AhtUrhganMissionFields =
{
    [5] = 'Assault',
    [6] = 'ToAU Mission',
    [7] = 'WoTG Mission',
    [8] = 'Campaign',
}

local function getPortType(port)
    if port == PORT_MAIN_MISSION then
        return 'Main Mission'
    elseif port == PORT_TVR then
        return 'TVR'
    elseif QuestOffer[port] then
        return 'Quest Offer', QuestOffer[port]
    elseif QuestComplete[port] then
        return 'Quest Complete', QuestComplete[port]
    elseif MissionComplete[port] then
        return 'Mission Complete', MissionComplete[port]
    else
        return 'Unknown', nil
    end
end

local function findChangedBits(oldVal, newVal)
    local xor     = bit.bxor(oldVal, newVal)
    local changed = {}
    for b = 0, 31 do
        if bit.band(xor, bit.lshift(1, b)) ~= 0 then
            local wasSet = bit.band(oldVal, bit.lshift(1, b)) ~= 0
            local nowSet = bit.band(newVal, bit.lshift(1, b)) ~= 0
            table.insert(changed, { bit = b, wasSet = wasSet, nowSet = nowSet })
        end
    end
    return changed
end

local function diffData(oldData, newData, useBitflags)
    local changes = {}
    for i = 1, 8 do
        local oldVal = oldData[i] or 0
        local newVal = newData[i] or 0
        if oldVal ~= newVal then
            local change = { index = i, old = oldVal, new = newVal }
            if useBitflags then
                change.bits = findChangedBits(oldVal, newVal)
            end
            table.insert(changes, change)
        end
    end
    return changes
end

local function isBitflagPort(port)
    return QuestOffer[port] ~= nil or QuestComplete[port] ~= nil or MissionComplete[port] ~= nil
end

local function isMissionCompletePort(port)
    return MissionComplete[port] ~= nil
end

local function calculateBitId(dataIndex, bitPos)
    return (dataIndex - 1) * 32 + bitPos
end

local function isAhtUrhganMissionField(port, dataIndex)
    return port == 0x0080 and dataIndex >= 5
end

-- Port 0x00D8: Data[1-2] = ToAU (0-63), Data[3-4] = WoTG (0-63)
local function getToAUWoTGMissionType(dataIndex)
    if dataIndex <= 2 then
        return 'ToAU'
    else
        return 'WoTG'
    end
end

local function calculateToAUWoTGMissionId(dataIndex, bitPos)
    if dataIndex <= 2 then
        return (dataIndex - 1) * 32 + bitPos
    else
        return (dataIndex - 3) * 32 + bitPos
    end
end

local function formatMainMissionChange(change)
    local fieldName = MainMissionFields[change.index] or string.format('Field %d', change.index)
    local detail    = ''

    if change.index == 1 then
        local oldNation = NationNames[change.old] or tostring(change.old)
        local newNation = NationNames[change.new] or tostring(change.new)
        detail          = string.format('%s -> %s', oldNation, newNation)
    elseif change.index == 6 then
        local oldAddons = bit.band(change.old, 0xFFFF)
        local newAddons = bit.band(change.new, 0xFFFF)
        local oldTales  = bit.rshift(change.old, 16)
        local newTales  = bit.rshift(change.new, 16)
        if oldAddons ~= newAddons and oldTales ~= newTales then
            detail = string.format('Addons: %d->%d, Tales: %d->%d', oldAddons, newAddons, oldTales, newTales)
        elseif oldAddons ~= newAddons then
            detail = string.format('Addons: %d -> %d', oldAddons, newAddons)
        else
            detail = string.format('Tales: %d -> %d', oldTales, newTales)
        end
    else
        detail = string.format('%d -> %d', change.old, change.new)
    end

    return fieldName, detail
end

local function writeLog(file, tstamp, title, notificationData)
    if file then
        file:append(string.format('[%s] %s\n%s\n\n', tstamp, title, utils.dump(notificationData)))
    end
end

local function notify(title, fields, player, tstamp)
    table.insert(fields, { 'X', player and player.x or '?' })
    table.insert(fields, { 'Y', player and player.y or '?' })
    table.insert(fields, { 'Z', player and player.z or '?' })
    table.insert(fields, { 'Zone', player and player.zoneName or '?' })
    table.insert(fields, { 'Timestamp', os.time() })

    writeLog(addon.files.global, tstamp, title, fields)
    writeLog(addon.files.capture, tstamp, title, fields)
    backend.notificationCreate('MissionTrack', title, fields)
end

addon.onInitialize     = function(rootDir)
    addon.files.global = backend.fileOpen(string.format('%s/%s_missions.log', rootDir, backend.player_name()))
end

addon.onCaptureStart   = function(captureDir)
    addon.files.capture = backend.fileOpen(string.format('%s/%s_missions.log', captureDir, backend.player_name()))
end

addon.onCaptureStop    = function()
    addon.files.capture = nil
end

addon.onIncomingPacket = function(id, data, size, packet)
    if id ~= PacketId.GP_SERV_COMMAND_MISSION or not packet then
        return
    end

    local port             = packet.Port
    local portType, region = getPortType(port)
    local isFirstUpdate    = not addon.initializedPort[port]

    local currentData      = {}
    if packet.Data then
        for i = 1, 8 do
            currentData[i] = packet.Data[i] or 0
        end
    else
        for i = 1, 8 do
            currentData[i] = 0
        end
    end

    local prevData = addon.portData[port] or {}

    if not isFirstUpdate then
        local useBitflags = isBitflagPort(port)
        local changes     = diffData(prevData, currentData, useBitflags)

        if #changes > 0 then
            local player = backend.get_player_entity_data()
            local tstamp = os.date('%Y-%m-%d %H:%M:%S')
            local title  = region and string.format('%s - %s', portType, region) or portType

            if port == PORT_MAIN_MISSION then
                for _, change in ipairs(changes) do
                    local fieldName, detail = formatMainMissionChange(change)
                    notify(title, { { 'Field', fieldName }, { 'Change', detail } }, player, tstamp)
                end
            elseif port == 0x00D8 then
                for _, change in ipairs(changes) do
                    if change.bits and #change.bits > 0 then
                        for _, bitChange in ipairs(change.bits) do
                            local missionType = getToAUWoTGMissionType(change.index)
                            local missionId   = calculateToAUWoTGMissionId(change.index, bitChange.bit)
                            local action      = bitChange.nowSet and 'Completed' or 'Reset'
                            notify(title, {
                                { 'Region', region or portType },
                                { 'Type', missionType },
                                { 'Mission', missionId },
                                { 'Action', action },
                            }, player, tstamp)
                        end
                    end
                end
            elseif port == 0x0080 then
                for _, change in ipairs(changes) do
                    if isAhtUrhganMissionField(port, change.index) then
                        local fieldName = AhtUrhganMissionFields[change.index] or string.format('Field %d', change.index)
                        notify(title, {
                            { 'Region', region or portType },
                            { 'Mission', fieldName },
                            { 'Progress', string.format('%d -> %d', change.old, change.new) },
                        }, player, tstamp)
                    elseif change.bits and #change.bits > 0 then
                        for _, bitChange in ipairs(change.bits) do
                            local questId = calculateBitId(change.index, bitChange.bit)
                            local action  = bitChange.nowSet and 'Accepted' or 'Removed'
                            notify(title, {
                                { 'Region', region or portType },
                                { 'Quest ID', questId },
                                { 'Action', action },
                            }, player, tstamp)
                        end
                    end
                end
            else
                local isMission       = isMissionCompletePort(port)
                local isQuestComplete = QuestComplete[port] ~= nil

                for _, change in ipairs(changes) do
                    if change.bits and #change.bits > 0 then
                        for _, bitChange in ipairs(change.bits) do
                            local bitId   = calculateBitId(change.index, bitChange.bit)
                            local idLabel = isMission and 'Mission ID' or 'Quest ID'
                            local action

                            if isMission or isQuestComplete then
                                action = bitChange.nowSet and 'Completed' or 'Reset'
                            else
                                action = bitChange.nowSet and 'Accepted' or 'Removed'
                            end

                            notify(title, {
                                { 'Region', region or portType },
                                { idLabel, bitId },
                                { 'Action', action },
                            }, player, tstamp)
                        end
                    end
                end
            end
        end
    end

    addon.portData[port]        = currentData
    addon.initializedPort[port] = true
end

return addon
