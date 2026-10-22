-- Region map polling addon
-- Requests the region map the way opening it does. Each answer is one GP_SERV_COMMAND_CONQUEST and two
-- GP_SERV_COMMAND_INFLUENCE, which ConquestTrack, BesiegedTrack, CampaignTrack and ColonizationTrack log.
---@class RegionTrackAddon : AddonInterface
local addon =
{
    name    = 'RegionTrack',
    pollKey = 0,
}

local defaultInterval = 10

local commands =
{
    { cmd = 'request', desc = 'Request the region map once.' },
    { cmd = 'poll [seconds]', desc = string.format('Request the region map every N seconds (default %d).', defaultInterval) },
    { cmd = 'stop', desc = 'Stop polling.' },
}

local function requestMap()
    local packet = { 0x5A, 0x04, 0x00, 0x00 }
    backend.injectPacket(PacketId.GP_CLI_COMMAND_REQCONQUEST, packet)
end

-- Bumping the key ends any running poll loop.
local function startPolling(interval)
    addon.pollKey = addon.pollKey + 1
    local key     = addon.pollKey

    local function poll()
        if addon.pollKey ~= key then return end
        requestMap()
        ashita.tasks.once(interval, poll)
    end

    poll()
    backend.msg('RegionTrack', string.format('Polling started (every %ds).', interval))
end

local function stopPolling()
    addon.pollKey = addon.pollKey + 1
    backend.msg('RegionTrack', 'Polling stopped.')
end

addon.onCommand = function(args)
    local cmd = args and args[1] and args[1]:lower()

    if cmd == 'request' or cmd == 'req' then
        requestMap()
        backend.msg('RegionTrack', 'Requested the region map.')
    elseif cmd == 'poll' or cmd == 'start' then
        local interval = tonumber(args[2]) or defaultInterval
        if interval < 1 then
            backend.msg('RegionTrack', 'Interval must be at least 1 second.')
            return
        end

        startPolling(interval)
    elseif cmd == 'stop' then
        stopPolling()
    else
        backend.msg('RegionTrack', 'Usage: /cap regiontrack <request|poll [seconds]|stop>')
    end
end

addon.onHelp = function()
    return commands
end

addon.onUnload = function()
    addon.pollKey = addon.pollKey + 1
end

return addon
