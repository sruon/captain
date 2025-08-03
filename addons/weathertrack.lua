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
    rootDir         = nil,
}

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

addon.onUnload         = function()
    if addon.database then
        addon.database:close()
    end
end

addon.onIncomingPacket = function(id, data)
    -- Only support capturing from retail. You may need to rezone before this passes.
    if not backend.is_retail() then
        return
    end

    if id == PacketId.GP_SERV_COMMAND_LOGIN then
        ---@type GP_SERV_COMMAND_LOGIN
        local zoneInPacket   = backend.parsePacket('incoming', data)
        local weatherDbEntry =
        {
            ZoneNo                    = zoneInPacket.ZoneNo,
            ZoneName                  = backend.zone_name(zoneInPacket.ZoneNo),
            PreviousWeatherNumber     = zoneInPacket.WeatherNumber2,
            PreviousWeatherStartTime  = zoneInPacket.WeatherTime2,
            PreviousWeatherOffsetTime = zoneInPacket.WeatherOffsetTime2,
            WeatherNumber             = zoneInPacket.WeatherNumber,
            StartTime                 = zoneInPacket.WeatherTime,
            WeatherOffsetTime         = zoneInPacket.WeatherOffsetTime,
        }

        backend.msg('WeatherTrack',
            string.format('[%s] WeatherNumber %d WeatherStartTime %d WeatherOffsetTime %d',
                backend.zone_name(zoneInPacket.ZoneNo),
                weatherDbEntry.WeatherNumber, weatherDbEntry.StartTime, weatherDbEntry.WeatherOffsetTime))

        -- Track current weather so we can add it to the subsequent DB entry
        addon.currentWeather =
        {
            WeatherNumber     = zoneInPacket.WeatherNumber,
            StartTime         = zoneInPacket.WeatherTime,
            WeatherOffsetTime = zoneInPacket.WeatherOffsetTime,
        }

        addon.database:add_or_update(os.time(), weatherDbEntry)
    end

    if id == PacketId.GP_SERV_COMMAND_WEATHER then
        ---@type GP_SERV_COMMAND_WEATHER
        local weatherPacket = backend.parsePacket('incoming', data)

        -- If we don't have weather tracked, treat this as starting point
        -- i.e. reloading captain without zoning
        if not addon.currentWeather then
            addon.currentWeather =
            {
                WeatherNumber     = weatherPacket.WeatherNumber,
                StartTime         = weatherPacket.StartTime,
                WeatherOffsetTime = weatherPacket.WeatherOffsetTime,
            }
            return
        end

        local weatherDbEntry =
        {
            ZoneNo                    = backend.zone(),
            ZoneName                  = backend.zone_name(),
            PreviousWeatherNumber     = addon.currentWeather.WeatherNumber,
            PreviousWeatherStartTime  = addon.currentWeather.StartTime,
            PreviousWeatherOffsetTime = addon.currentWeather.WeatherOffsetTime,
            WeatherNumber             = weatherPacket.WeatherNumber,
            StartTime                 = weatherPacket.StartTime,
            WeatherOffsetTime         = weatherPacket.WeatherOffsetTime,
        }
        backend.msg('WeatherTrack', string.format('[%s] WeatherNumber %d WeatherStartTime %d WeatherOffsetTime %d',
            backend.zone_name(),
            weatherDbEntry.WeatherNumber, weatherDbEntry.StartTime, weatherDbEntry.WeatherOffsetTime))
        addon.currentWeather =
        {
            WeatherNumber     = weatherPacket.WeatherNumber,
            StartTime         = weatherPacket.StartTime,
            WeatherOffsetTime = weatherPacket.WeatherOffsetTime,
        }

        addon.database:add_or_update(os.time(), weatherDbEntry)
    end
end

return addon
