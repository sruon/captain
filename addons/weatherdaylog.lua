-- Prints a chat log message whenever the weather or the Vana'diel day changes.
-- Weather changes are read from server packets; day changes are polled from the
-- client's Vana'diel clock. Passive only, nothing is stored with the capture.
---@class WeatherDayLogAddon : AddonInterface
local addon          =
{
    name            = 'WeatherDayLog',
    filters         =
    {
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_LOGIN]   = true, -- Zone changes (carry weather)
            [PacketId.GP_SERV_COMMAND_WEATHER] = true, -- Weather updates
        },
    },
    settings        = {},
    defaultSettings = {},

    -- Weather number currently in effect, used to detect changes
    currentWeather  = nil,
    -- Vana'diel weekday (0-7) last observed, used to detect day changes
    lastWeekday     = nil,
    -- os.clock() of the last day poll, used to throttle polling
    lastDayPoll     = 0,
}

-- Display names indexed by weather number (matches in-game weather names)
local weatherNames   =
{
    [0]  = 'Clear',
    [1]  = 'Sunshine',
    [2]  = 'Clouds',
    [3]  = 'Fog',
    [4]  = 'Hot Spell',
    [5]  = 'Heat Wave',
    [6]  = 'Rain',
    [7]  = 'Squall',
    [8]  = 'Dust Storm',
    [9]  = 'Sandstorm',
    [10] = 'Wind',
    [11] = 'Gales',
    [12] = 'Snow',
    [13] = 'Blizzards',
    [14] = 'Thunder',
    [15] = 'Thunderstorms',
    [16] = 'Auroras',
    [17] = 'Stellar Glare',
    [18] = 'Gloom',
    [19] = 'Darkness',
}

local function weatherName(number)
    return weatherNames[number] or string.format('Unknown (%d)', number)
end

addon.onIncomingPacket = function(id, data, size, packet)
    if not packet then
        return
    end

    local newWeather

    if id == PacketId.GP_SERV_COMMAND_LOGIN then
        -- Zoning in: adopt the zone's weather as the baseline without announcing
        addon.currentWeather = packet.WeatherNumber
        return
    elseif id == PacketId.GP_SERV_COMMAND_WEATHER then
        newWeather = packet.WeatherNumber
    else
        return
    end

    -- First weather packet after a reload with no baseline yet: adopt silently
    if addon.currentWeather == nil then
        addon.currentWeather = newWeather
        return
    end

    if newWeather ~= addon.currentWeather then
        backend.msg('WeatherDayLog', string.format('%sWeather changed: %s%s%s -> %s%s',
            colors[ColorEnum.Purple].chatColorCode,
            colors[ColorEnum.Seafoam].chatColorCode, weatherName(addon.currentWeather),
            colors[ColorEnum.Purple].chatColorCode,
            colors[ColorEnum.Green].chatColorCode, weatherName(newWeather)))
        addon.currentWeather = newWeather
    end
end

addon.onPrerender      = function()
    -- The day only changes roughly once a minute of real time, so throttle the
    -- clock reads to once per second to avoid per-frame FFI calls.
    local now = os.clock()
    if now - addon.lastDayPoll < 1 then
        return
    end
    addon.lastDayPoll = now

    local weekday = backend.get_vana_weekday()

    -- Establish a baseline on the first read without announcing
    if addon.lastWeekday == nil then
        addon.lastWeekday = weekday
        return
    end

    if weekday ~= addon.lastWeekday then
        backend.msg('WeatherDayLog', string.format('%sDay changed to %s%s',
            colors[ColorEnum.Purple].chatColorCode,
            colors[ColorEnum.Green].chatColorCode, backend.get_vana_weekday_name()))
        addon.lastWeekday = weekday
    end
end

return addon
