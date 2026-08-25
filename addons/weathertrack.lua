local socket = require('socket')

-- All credits: cocosolos WeatherWatch for Windower
-- Logs weather changes
-- Does not store with the capture, passive mode only!
---@class WeatherTrackAddon : AddonInterface
---@field database Database | nil
local addon            =
{
    name            = 'WeatherTrack',
    filters         =
    {
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_LOGIN]   = true, -- Zone changes
            [PacketId.GP_SERV_COMMAND_WEATHER] = true, -- Weather updates
        },
    },
    settings        = {},
    defaultSettings =
    {
    },
    database        = nil,
    currentWeather  = nil,
    currentDay      = nil,
    announceAt      = nil,
    rootDir         = nil,
}

-- Colored by element, single and double weather share a hue
local WEATHER          =
{
    [0]  = { 'None', ColorEnum.Slate },
    [1]  = { 'Sunshine', ColorEnum.LightYellow },
    [2]  = { 'Clouds', ColorEnum.Slate },
    [3]  = { 'Fog', ColorEnum.Ivory },
    [4]  = { 'Hot Spell', ColorEnum.Red },
    [5]  = { 'Heat Wave', ColorEnum.Crimson },
    [6]  = { 'Rain', ColorEnum.SoftBlue },
    [7]  = { 'Squall', ColorEnum.Blue },
    [8]  = { 'Dust Storm', ColorEnum.Tan },
    [9]  = { 'Sand Storm', ColorEnum.Yellow },
    [10] = { 'Wind', ColorEnum.Seafoam },
    [11] = { 'Gales', ColorEnum.Green },
    [12] = { 'Snow', ColorEnum.Aqua },
    [13] = { 'Blizzards', ColorEnum.Turquoise },
    [14] = { 'Thunder', ColorEnum.Orchid },
    [15] = { 'Thunderstorms', ColorEnum.Violet },
    [16] = { 'Auroras', ColorEnum.Ivory },
    [17] = { 'Stellar Glare', ColorEnum.White },
    [18] = { 'Gloom', ColorEnum.Slate },
    [19] = { 'Darkness', ColorEnum.Navy },
}

-- Indexed by backend.get_vana_weekday()
local DAYS             =
{
    [0] = { 'Firesday', ColorEnum.Red },
    [1] = { 'Earthsday', ColorEnum.Tan },
    [2] = { 'Watersday', ColorEnum.Blue },
    [3] = { 'Windsday', ColorEnum.Green },
    [4] = { 'Iceday', ColorEnum.Aqua },
    [5] = { 'Lightningday', ColorEnum.Violet },
    [6] = { 'Lightsday', ColorEnum.Ivory },
    [7] = { 'Darksday', ColorEnum.Navy },
}

local SYSTEM           = colors[ColorEnum.Purple].chatColorCode

-- The client prints its own zone banner just after the login packet, so let it go first
local ZONE_IN_DELAY    = 2

local function colored(names, key)
    local entry = names[key]
    if entry then
        return colors[entry[2]].chatColorCode .. entry[1]
    end

    local label = key and string.format('Unknown (%d)', key) or 'Unknown'
    return colors[ColorEnum.Slate].chatColorCode .. label
end

local function announceChange(label, names, from, to)
    backend.msg('WeatherTrack', string.format('%s%s changed from %s%s to %s',
        SYSTEM, label, colored(names, from), SYSTEM, colored(names, to)))
end

local function announceCurrent(weatherNumber)
    backend.msg('WeatherTrack', string.format('%sDay: %s%s Weather: %s',
        SYSTEM, colored(DAYS, backend.get_vana_weekday()), SYSTEM, colored(WEATHER, weatherNumber)))
end

addon.onInitialize     = function(rootDir)
    local dbPath   = string.format('%s/%s.db', rootDir, backend.player_name())
    addon.database = backend.databaseOpen(
        dbPath,
        {
            schema =
            {
                ZoneNo                    = 1,
                ZoneName                  = 'Test',
                PreviousWeatherStartTime  = 1,
                PreviousWeatherNumber     = 1,
                PreviousWeatherOffsetTime = 1,
                StartTime                 = 1,
                WeatherNumber             = 1,
                WeatherOffsetTime         = 1,
            },
        })
end

addon.onCaptureStart   = function()
    announceCurrent(addon.currentWeather and addon.currentWeather.WeatherNumber)
end

addon.onPrerender      = function()
    if not backend.is_retail() then
        return
    end

    if addon.announceAt and socket.gettime() >= addon.announceAt then
        addon.announceAt = nil
        announceCurrent(addon.currentWeather and addon.currentWeather.WeatherNumber)
    end

    local day = backend.get_vana_weekday()
    if addon.currentDay and day ~= addon.currentDay then
        announceChange('Day', DAYS, addon.currentDay, day)
    end

    addon.currentDay = day
end

addon.onUnload         = function()
    if addon.database then
        addon.database:close()
    end
end

addon.onIncomingPacket = function(id, data, size, packet)
    if not backend.is_retail() then
        return
    end

    if not packet then
        return
    end

    if id == PacketId.GP_SERV_COMMAND_LOGIN then
        local weatherDbEntry =
        {
            ZoneNo                    = packet.ZoneNo,
            ZoneName                  = backend.zone_name(packet.ZoneNo),
            PreviousWeatherNumber     = packet.WeatherNumber2,
            PreviousWeatherStartTime  = packet.WeatherTime2,
            PreviousWeatherOffsetTime = packet.WeatherOffsetTime2,
            WeatherNumber             = packet.WeatherNumber,
            StartTime                 = packet.WeatherTime,
            WeatherOffsetTime         = packet.WeatherOffsetTime,
        }

        -- Track current weather so we can add it to the subsequent DB entry
        addon.currentWeather =
        {
            WeatherNumber     = packet.WeatherNumber,
            StartTime         = packet.WeatherTime,
            WeatherOffsetTime = packet.WeatherOffsetTime,
        }

        addon.announceAt = socket.gettime() + ZONE_IN_DELAY

        addon.database:add_or_update(os.time(), weatherDbEntry)
    elseif id == PacketId.GP_SERV_COMMAND_WEATHER then
        -- If we don't have weather tracked, treat this as starting point
        -- i.e. reloading captain without zoning
        if not addon.currentWeather then
            addon.currentWeather =
            {
                WeatherNumber     = packet.WeatherNumber,
                StartTime         = packet.StartTime,
                WeatherOffsetTime = packet.WeatherOffsetTime,
            }
            return
        end

        if packet.WeatherNumber ~= addon.currentWeather.WeatherNumber then
            announceChange('Weather', WEATHER, addon.currentWeather.WeatherNumber, packet.WeatherNumber)
        end

        local weatherDbEntry =
        {
            ZoneNo                    = backend.zone(),
            ZoneName                  = backend.zone_name(),
            PreviousWeatherNumber     = addon.currentWeather.WeatherNumber,
            PreviousWeatherStartTime  = addon.currentWeather.StartTime,
            PreviousWeatherOffsetTime = addon.currentWeather.WeatherOffsetTime,
            WeatherNumber             = packet.WeatherNumber,
            StartTime                 = packet.StartTime,
            WeatherOffsetTime         = packet.WeatherOffsetTime,
        }

        addon.currentWeather =
        {
            WeatherNumber     = packet.WeatherNumber,
            StartTime         = packet.StartTime,
            WeatherOffsetTime = packet.WeatherOffsetTime,
        }

        addon.database:add_or_update(os.time(), weatherDbEntry)
    end
end

return addon
