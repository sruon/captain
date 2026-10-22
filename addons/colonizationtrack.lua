-- Colonization map tracking addon
-- Logs every colonization GP_SERV_COMMAND_INFLUENCE (mode 3) to CSV, and prints it to chat when it changes.
-- Use /cap regiontrack poll for a steady series.
---@class ColonizationTrackAddon : AddonInterface
local addon =
{
    name     = 'ColonizationTrack',
    filters  =
    {
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_INFLUENCE] = true,
        },
        outgoing = {},
    },
    csvFile  = nil,
    lastLine = nil,
}

local colonizationMode = 3

local coalitions = { 'Pioneers', 'Peacekeepers', 'Couriers', 'Scouts', 'Inventors', 'Mummers' }

-- Zone slots in packet order. The first is unused.
local zones = { 'Unused', 'Yahse', 'Ceizak', 'Foret', 'Yorcia', 'Morimar', 'Marjami', 'Kamihr', 'RaKaznar' }

local csvSchema = (function()
    local schema = { 'Timestamp', 'Unknown05', 'Unknown08', 'Unknown0C', 'Bayld' }
    for _, coalition in ipairs(coalitions) do
        schema[#schema + 1] = 'Rank_' .. coalition
    end
    for _, zone in ipairs(zones) do
        schema[#schema + 1] = zone .. '_ColonizationRate'
        schema[#schema + 1] = zone .. '_CurrentBivouacs'
        schema[#schema + 1] = zone .. '_MaxBivouacs'
        schema[#schema + 1] = zone .. '_unused'
    end
    return schema
end)()

addon.onIncomingPacket = function(id, data, size, packet)
    if not packet or packet.Mode ~= colonizationMode then return end

    local colonization = packet.Data
    local entry        =
    {
        Timestamp = os.time(),
        Unknown05 = packet.Unknown05,
        Unknown08 = colonization.Unknown08,
        Unknown0C = colonization.Unknown0C,
        Bayld     = colonization.Bayld,
    }

    for _, coalition in ipairs(coalitions) do
        entry['Rank_' .. coalition] = colonization.Ranks[coalition]
    end

    local rates = {}
    for i, zone in ipairs(zones) do
        local zoneData = colonization.Zones[i]
        entry[zone .. '_ColonizationRate'] = zoneData.ColonizationRate
        entry[zone .. '_CurrentBivouacs']  = zoneData.CurrentBivouacs
        entry[zone .. '_MaxBivouacs']      = zoneData.MaxBivouacs
        entry[zone .. '_unused']           = zoneData.unused

        if i > 1 then
            rates[#rates + 1] = string.format('%s %d%% %d/%d', zone, zoneData.ColonizationRate, zoneData.CurrentBivouacs, zoneData.MaxBivouacs)
        end
    end

    if addon.csvFile then
        addon.csvFile:add_entry(entry)
        addon.csvFile:save()
    end

    local line = string.format('%s | Bayld %d', table.concat(rates, ', '), colonization.Bayld)

    if line ~= addon.lastLine then
        addon.lastLine = line
        backend.msg('ColonizationTrack', line)
    end
end

addon.onInitialize = function(rootDir)
    addon.csvFile = backend.csvOpen(
        string.format('%s%s_colonization.csv', rootDir, backend.player_name()),
        csvSchema)
end

addon.onUnload = function()
    if addon.csvFile then
        addon.csvFile:close()
        addon.csvFile = nil
    end
end

return addon
