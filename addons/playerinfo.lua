-- Credits: zach2good
-- Displays a floating text box with the player's job levels, coordinates, rotation, zone ID, capture state and server IP/port.
---@class PlayerInfoAddon : AddonInterface
---@field playerInfo TextBox?
---@field server { ip: string, port: number }
---@field databases { global: Database?, capture: Database? }

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
    databases       =
    {
        global  = nil,
        capture = nil,
    },
    
    -- Player info schema based on server data structure
    schema = {
        ip = "127.0.0.1",    -- Server IP address
        port = 54001         -- Server port number
    }
}

addon.onIncomingPacket = function(id, data)
    if id == PacketId.GP_SERV_COMMAND_LOGOUT then
        local zoneOutPacket = backend.parsePacket('incoming', data)
        if not zoneOutPacket then
            return
        end

        addon.server.ip = zoneOutPacket.GP_SERV_LOGOUTSUB.ip
        addon.server.port = zoneOutPacket.GP_SERV_LOGOUTSUB.port
        if addon.databases.global then
            addon.databases.global:add_or_update('ZoneServer', addon.server)
        end

        if addon.databases.capture then
            addon.databases.capture:add_or_update('ZoneServer', addon.server)
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
    if addon.playerInfo then
        addon.playerInfo:updateTitle(titleStr)
        addon.playerInfo:updateText(playerOutputStr)
    end
end

addon.onCaptureStop = function()
    if addon.databases.capture then
        addon.databases.capture:close()
        addon.databases.capture = nil
    end
end

addon.onCaptureStart = function(captureDir)
    addon.databases.capture = backend.databaseOpen(string.format('%s/%s.db', captureDir, backend.player_name()), {
        schema = addon.schema,
        max_history = addon.settings.database and addon.settings.database.max_history
    })
end

addon.onInitialize = function(rootDir)
    addon.playerInfo = backend.textBox('playerinfo')
    addon.databases.global = backend.databaseOpen(string.format('%s/databases/%s.db', rootDir, backend.player_name()), {
        schema = addon.schema,
        max_history = addon.settings.database and addon.settings.database.max_history
    })
end

return addon
