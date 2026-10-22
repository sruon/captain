-- Besieged map tracking addon
-- Logs the Besieged half of every GP_SERV_COMMAND_CONQUEST to CSV, and prints it to chat when it changes.
-- The server sends it on zone-in, map open and Imperial Standing gains. Use /cap regiontrack poll for a steady series.
---@class BesiegedTrackAddon : AddonInterface
local addon =
{
    name     = 'BesiegedTrack',
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

local strongholds = { 'Mamook', 'Halvung', 'Arrapago' }

local strongholdOrders =
{
    [0] = 'Train',
    [1] = 'Advance',
    [2] = 'Attack',
    [3] = 'Retreat',
    [4] = 'Defend',
    [5] = 'Prepare',
}

local alZahbiOrders =
{
    [0] = 'Defend',
    [1] = 'Intercept',
    [2] = 'Infiltrate',
    [3] = 'Recover',
}

local csvSchema = (function()
    local schema = { 'Timestamp', 'AstralCandescence', 'AlZahbiOrders', 'OverviewUnknown' }
    for _, name in ipairs(strongholds) do
        schema[#schema + 1] = name .. '_OverviewLevel'
        schema[#schema + 1] = name .. '_OverviewOrders'
        schema[#schema + 1] = name .. '_Orders'
        schema[#schema + 1] = name .. '_Forces'
        schema[#schema + 1] = name .. '_Level'
        schema[#schema + 1] = name .. '_Mirrors'
        schema[#schema + 1] = name .. '_Unknown'
        schema[#schema + 1] = name .. '_Prisoners'
    end
    schema[#schema + 1] = 'ImperialStanding'
    return schema
end)()

addon.onIncomingPacket = function(id, data, size, packet)
    local besieged = packet and packet.Besieged
    if not besieged then
        backend.msg('BesiegedTrack', 'packet has no Besieged block')
        return
    end

    local overview = besieged.Overview
    local entry    =
    {
        Timestamp         = os.time(),
        AstralCandescence = overview.AstralCandescence,
        AlZahbiOrders     = overview.AlZahbiOrders,
        OverviewUnknown   = overview.Unknown,
        ImperialStanding  = besieged.ImperialStanding,
    }

    local parts = {}
    for i, name in ipairs(strongholds) do
        local stronghold = besieged.Strongholds[i]

        entry[name .. '_OverviewLevel']  = overview[name .. 'Level']
        entry[name .. '_OverviewOrders'] = overview[name .. 'Orders']
        entry[name .. '_Orders']         = stronghold.Orders
        entry[name .. '_Forces']         = stronghold.Forces
        entry[name .. '_Level']          = stronghold.Level
        entry[name .. '_Mirrors']        = stronghold.Mirrors
        entry[name .. '_Unknown']        = stronghold.Unknown
        entry[name .. '_Prisoners']      = stronghold.Prisoners

        parts[#parts + 1] = string.format('%s %s L%d F%d M%d P%d%s',
            name,
            strongholdOrders[stronghold.Orders] or tostring(stronghold.Orders),
            stronghold.Level,
            stronghold.Forces,
            stronghold.Mirrors,
            stronghold.Prisoners,
            stronghold.Unknown == 1 and ' Flag' or '')
    end

    if addon.csvFile then
        addon.csvFile:add_entry(entry)
        addon.csvFile:save()
    end

    local holder = overview.AstralCandescence == 0 and 'Al Zahbi' or strongholds[overview.AstralCandescence]
    local line   = string.format('AC: %s | Al Zahbi: %s | %s',
        holder,
        alZahbiOrders[overview.AlZahbiOrders],
        table.concat(parts, ' | '))

    if line ~= addon.lastLine then
        addon.lastLine = line
        backend.msg('BesiegedTrack', line)
    end
end

addon.onInitialize = function(rootDir)
    addon.csvFile = backend.csvOpen(
        string.format('%s%s_besieged.csv', rootDir, backend.player_name()),
        csvSchema)
end

addon.onUnload = function()
    if addon.csvFile then
        addon.csvFile:close()
        addon.csvFile = nil
    end
end

return addon
