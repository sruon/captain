-- Credits: zach2good
-- Displays a floating text box with the player's job levels, coordinates, rotation, zone ID, capture state and server IP/port.
---@class PlayerInfoAddon : AddonInterface
---@field playerInfo? any
---@field server { ip: string, port: number }
local addon =
{
    name            = 'PlayerInfo',
    playerInfo      = nil,
    filters         =
    {
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_LOGOUT] = true, -- Zone out
        }
    },
    server          =
    {
        ip = '0.0.0.0',
        port = 0,
    },
    settings        = {},
    defaultSettings =
    {
        database =
        {
            max_history = 10,
        },
    },
    database        =
    {
        global  = nil,
        capture = nil,
    }
}

addon.onIncomingPacket = function(id, data)
    if id == PacketId.GP_SERV_COMMAND_LOGOUT then
        local zoneOutPacket = backend.parsePacket('incoming', data)
        addon.server.ip = zoneOutPacket.GP_SERV_LOGOUTSUB.ip
        addon.server.port = zoneOutPacket.GP_SERV_LOGOUTSUB.port
        addon.database.global:add_or_update('ZoneServer', addon.server)
        addon.database.global:save()
        if addon.database.capture then
            addon.database.capture:add_or_update('ZoneServer', addon.server)
            addon.database.capture:save()
        end
    end
end

addon.onPrerender = function()
    local playerData = backend.get_player_entity_data()
    if playerData == nil then
        return
    end

    local playerJobString = '(99NIN/49WAR) '

    --  TODO: implement for Windower/Ashitav3
    if playerData.mJob then
        playerJobString = string.format("(%02d%s/%02d%s)", playerData.mJobLevel, playerData.mJob, playerData.sJobLevel,
            playerData.sJob)
    end

    local zoneInfo = string.format("%s (%03d)", backend.zone_name(), backend.zone())

    local playerOutputStr =
        'X: ' .. playerData.x .. ' ' ..
        'Y: ' .. playerData.y .. ' ' ..
        'Z: ' .. playerData.z .. ' ' ..
        'R: ' .. playerData.r .. ' ' ..
        'Capturing: ' .. tostring(captain.isCapturing)

    local titleStr = string.format('%s[%d/%d] %s - %s - %s:%d', playerData.name, playerData.serverId,
        playerData.targIndex, playerJobString, zoneInfo, addon.server.ip, addon.server.port)
    addon.playerInfo:updateTitle(titleStr)
    addon.playerInfo:updateText(playerOutputStr)
end

addon.onCaptureStop = function()
    if addon.database.capture then
        addon.database.capture:close()
        addon.database.capture = nil
    end
end

addon.onCaptureStart = function(captureDir)
    addon.database.capture = backend.databaseOpen(string.format('%s/%s.lua', captureDir, backend.player_name()))
end

addon.onInitialize = function(rootDir)
    addon.playerInfo = backend.textBox('player')
    addon.database.global = backend.databaseOpen(string.format('%s/databases/%s.lua', rootDir, backend.player_name()),
        addon.settings.database)
end

return addon
