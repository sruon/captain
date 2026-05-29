-- Conquest tracking addon
---@class ConquestTrackAddon : AddonInterface
local addon =
{
    name     = 'ConquestTrack',
    settings = {},
    filters  =
    {
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_CONQUEST] = true,
        },
        outgoing = {},
    },
    rootDir   = nil,
    polling   = false,
    pollKey   = 0,
    csvFile   = nil,
}

local csvSchema = (function()
    local schema = { 'Timestamp', 'Balance', 'Alliance' }
    for i = 0, 26 do
        schema[#schema + 1] = string.format('R%d_RankBst', i)
        schema[#schema + 1] = string.format('R%d_RankNoBst', i)
        schema[#schema + 1] = string.format('R%d_Gfx', i)
        schema[#schema + 1] = string.format('R%d_Owner', i)
    end
    schema[#schema + 1] = 'CurSandy'
    schema[#schema + 1] = 'CurBastok'
    schema[#schema + 1] = 'CurWindy'
    schema[#schema + 1] = 'CurSandyPct'
    schema[#schema + 1] = 'CurBastokPct'
    schema[#schema + 1] = 'CurWindyPct'
    schema[#schema + 1] = 'NextTally'
    schema[#schema + 1] = 'CP'
    schema[#schema + 1] = 'CurBeastmen'
    return schema
end)()

local function writeToCsv(csvFile, packet)
    if not csvFile then return end

    local entry = {
        Timestamp = os.time(),
        Balance = packet.Balance or 0,
        Alliance = packet.Alliance or 0,
        CurSandy = packet.CurrentRegionSandoria or 0,
        CurBastok = packet.CurrentRegionBastok or 0,
        CurWindy = packet.CurrentRegionWindurst or 0,
        CurSandyPct = packet.CurrentRegionSandoriaPct or 0,
        CurBastokPct = packet.CurrentRegionBastokPct or 0,
        CurWindyPct = packet.CurrentRegionWindurstPct or 0,
        NextTally = packet.NextTally or 0,
        CP = packet.ConquestPoints or 0,
        CurBeastmen = packet.CurrentRegionBeastmen or 0,
    }

    for i = 0, 26 do
        local r = packet.Regions and packet.Regions[i]
        if r then
            entry[string.format('R%d_RankBst', i)] = r.RankWithBeastmen or 0
            entry[string.format('R%d_RankNoBst', i)] = r.RankNoBeastmen or 0
            entry[string.format('R%d_Gfx', i)] = r.Graphics or 0
            entry[string.format('R%d_Owner', i)] = r.Owner or 0
        else
            entry[string.format('R%d_RankBst', i)] = 0
            entry[string.format('R%d_RankNoBst', i)] = 0
            entry[string.format('R%d_Gfx', i)] = 0
            entry[string.format('R%d_Owner', i)] = 0
        end
    end

    csvFile:add_entry(entry)
    csvFile:save()
end

addon.onIncomingPacket = function(id, data, size, packet)
    if id ~= PacketId.GP_SERV_COMMAND_CONQUEST then return end

    if not packet then
        backend.msg('ConquestTrack', 'packet is nil')
        return
    end

    if addon.csvFile then
        writeToCsv(addon.csvFile, packet)
    end

    backend.msg('ConquestTrack', string.format(
        'CP: %d | Sandy: %d/%d%% | Bastok: %d/%d%% | Windy: %d/%d%% | Beastmen: %d | Tally: %d | Balance: %d | Alliance: %d',
        packet.ConquestPoints or 0,
        packet.CurrentRegionSandoria or 0, packet.CurrentRegionSandoriaPct or 0,
        packet.CurrentRegionBastok or 0, packet.CurrentRegionBastokPct or 0,
        packet.CurrentRegionWindurst or 0, packet.CurrentRegionWindurstPct or 0,
        packet.CurrentRegionBeastmen or 0,
        packet.NextTally or 0,
        packet.Balance or 0,
        packet.Alliance or 0))
end

local function requestConquest()
    local packet = { 0x5A, 0x04, 0x00, 0x00 }
    backend.injectPacket(PacketId.GP_CLI_COMMAND_REQCONQUEST, packet)
end

local function startPolling()
    if addon.polling then return end
    addon.polling = true
    addon.pollKey = addon.pollKey + 1
    local key = addon.pollKey

    local function poll()
        if not addon.polling or addon.pollKey ~= key then return end
        requestConquest()
        ashita.tasks.once(10, poll)
    end

    poll()
    backend.msg('ConquestTrack', 'Polling started (every 10s).')
end

local function stopPolling()
    addon.polling = false
    addon.pollKey = addon.pollKey + 1
    backend.msg('ConquestTrack', 'Polling stopped.')
end

addon.onCommand = function(args)
    if not args or #args == 0 then
        backend.msg('ConquestTrack', 'Usage: /conquesttrack <request|poll|stop>')
        return
    end

    local cmd = args[1]:lower()
    if cmd == 'request' or cmd == 'req' then
        requestConquest()
        backend.msg('ConquestTrack', 'Requested conquest data.')
    elseif cmd == 'poll' or cmd == 'start' then
        startPolling()
    elseif cmd == 'stop' then
        stopPolling()
    end
end

addon.onInitialize = function(rootDir)
    addon.rootDir = rootDir
    addon.csvFile = backend.csvOpen(
        string.format('%s/%s_conquest.csv', rootDir, backend.player_name()),
        csvSchema)
end

addon.onUnload = function()
    addon.polling = false
    if addon.csvFile then
        addon.csvFile:close()
        addon.csvFile = nil
    end
end

return addon
