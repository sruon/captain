-- Campaign map tracking addon
-- Logs every campaign GP_SERV_COMMAND_INFLUENCE (mode 2) to CSV, and prints the nation summary to chat when it changes.
-- The 26 zones arrive in two packets of 13, so each row only fills the zones its packet carries.
-- Use /cap regiontrack poll for a steady series.
---@class CampaignTrackAddon : AddonInterface
local addon =
{
    name     = 'CampaignTrack',
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

local campaignMode = 2
local zoneCount    = 26

local nations = { 'Sandoria', 'Bastok', 'Windurst', 'Orc', 'Quadav', 'Yagudo', 'DarkKindred' }

local zoneFields =
{
    'Owner',
    'CurrentFortifications',
    'MaxFortifications',
    'CurrentResources',
    'MaxResources',
    'Heroism',
    'InfluenceSandoria',
    'InfluenceBastok',
    'InfluenceWindurst',
    'InfluenceBeastman',
    'unused00',
    'unused01',
}

local csvSchema = (function()
    local schema =
    {
        'Timestamp',
        'Unknown05',
        'Unknown08',
        'ZoneOffset',
        'AlliedNotes',
        'Controlled_Sandoria',
        'Controlled_Bastok',
        'Controlled_Windurst',
        'Controlled_Beastman',
    }
    for _, nation in ipairs(nations) do
        schema[#schema + 1] = nation .. '_Reconnaissance'
        schema[#schema + 1] = nation .. '_Morale'
        schema[#schema + 1] = nation .. '_Prosperity'
        schema[#schema + 1] = nation .. '_unused'
    end
    for zone = 1, zoneCount do
        for _, field in ipairs(zoneFields) do
            schema[#schema + 1] = string.format('Z%02d_%s', zone, field)
        end
    end
    return schema
end)()

addon.onIncomingPacket = function(id, data, size, packet)
    if not packet or packet.Mode ~= campaignMode then return end

    local campaign = packet.Data
    local entry    =
    {
        Timestamp           = os.time(),
        Unknown05           = packet.Unknown05,
        Unknown08           = campaign.Unknown08,
        ZoneOffset          = campaign.ZoneOffset,
        AlliedNotes         = campaign.AlliedNotes,
        Controlled_Sandoria = campaign.ControlledAreas.Sandoria,
        Controlled_Bastok   = campaign.ControlledAreas.Bastok,
        Controlled_Windurst = campaign.ControlledAreas.Windurst,
        Controlled_Beastman = campaign.ControlledAreas.Beastman,
    }

    local morale = {}
    for i, nation in ipairs(nations) do
        local nationData = campaign.Nations[i]
        entry[nation .. '_Reconnaissance'] = nationData.Reconnaissance
        entry[nation .. '_Morale']         = nationData.Morale
        entry[nation .. '_Prosperity']     = nationData.Prosperity
        entry[nation .. '_unused']         = nationData.unused
        morale[#morale + 1]                = string.format('%s %d/%d', nation, nationData.Morale, nationData.Prosperity)
    end

    for i, zone in ipairs(campaign.Zones) do
        local index = campaign.ZoneOffset + i
        for _, field in ipairs(zoneFields) do
            entry[string.format('Z%02d_%s', index, field)] = zone[field]
        end
    end

    if addon.csvFile then
        addon.csvFile:add_entry(entry)
        addon.csvFile:save()
    end

    local areas = campaign.ControlledAreas
    local line  = string.format('Areas S%d B%d W%d Bm%d | Morale/Prosperity: %s | Notes %d',
        areas.Sandoria, areas.Bastok, areas.Windurst, areas.Beastman,
        table.concat(morale, ', '),
        campaign.AlliedNotes)

    if line ~= addon.lastLine then
        addon.lastLine = line
        backend.msg('CampaignTrack', line)
    end
end

addon.onInitialize = function(rootDir)
    addon.csvFile = backend.csvOpen(
        string.format('%s%s_campaign.csv', rootDir, backend.player_name()),
        csvSchema)
end

addon.onUnload = function()
    if addon.csvFile then
        addon.csvFile:close()
        addon.csvFile = nil
    end
end

return addon
