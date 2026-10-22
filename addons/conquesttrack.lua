-- Conquest tracking addon
-- Use /cap regiontrack poll for a steady series.
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
    csvFile  = nil,
    lastLine = nil,
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
    if not packet then
        backend.msg('ConquestTrack', 'packet is nil')
        return
    end

    if addon.csvFile then
        writeToCsv(addon.csvFile, packet)
    end

    local line = string.format(
        'CP: %d | Sandy: %d/%d%% | Bastok: %d/%d%% | Windy: %d/%d%% | Beastmen: %d | Tally: %d | Balance: %d | Alliance: %d',
        packet.ConquestPoints or 0,
        packet.CurrentRegionSandoria or 0, packet.CurrentRegionSandoriaPct or 0,
        packet.CurrentRegionBastok or 0, packet.CurrentRegionBastokPct or 0,
        packet.CurrentRegionWindurst or 0, packet.CurrentRegionWindurstPct or 0,
        packet.CurrentRegionBeastmen or 0,
        packet.NextTally or 0,
        packet.Balance or 0,
        packet.Alliance or 0)

    if line ~= addon.lastLine then
        addon.lastLine = line
        backend.msg('ConquestTrack', line)
    end
end

addon.onInitialize = function(rootDir)
    addon.csvFile = backend.csvOpen(
        string.format('%s%s_conquest.csv', rootDir, backend.player_name()),
        csvSchema)
end

addon.onUnload = function()
    if addon.csvFile then
        addon.csvFile:close()
        addon.csvFile = nil
    end
end

return addon
