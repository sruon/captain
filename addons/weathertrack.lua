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
