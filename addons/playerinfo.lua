-- Credits: zach2good
-- Displays a floating text box with the player's job levels, coordinates, rotation, zone ID, capture state and server IP.
---@class PlayerInfoAddon : AddonInterface
---@field playerInfo TextBox?
---@field server { ip: string, port: number }
---@field databases { global: Database?, capture: Database? }

local addon         =
{
    name            = 'PlayerInfo',
    playerInfo      = nil,
    isRetail        = false,
    frame           = 0,
    filters         =
    {
    },
    server          =
    {
        ip = 0,
    },
    settings        = {},
    defaultSettings =
    {
        database =
        {
            max_history = 10,
        },
    },
}

addon.onPrerender   = function()
    addon.frame      = addon.frame + 1
    local playerData = backend.get_player_entity_data()
    if playerData == nil then
        return
    end

    local playerJobString = '(99NIN/49WAR) '

    if playerData.mJob then
        playerJobString = string.format('(%02d%s/%02d%s)', playerData.mJobLevel, playerData.mJob, playerData.sJobLevel,
            playerData.sJob)
    end

    local zoneInfo    = string.format('%s (%03d)', backend.zone_name(), backend.zone())
    local retailCheck = { text = '\u{F057}', color = { 1.0, 0.0, 0.0, 1.0 } }
    if addon.isRetail then
        retailCheck = { text = '\u{F058}', color = { 0.0, 1.0, 0.0, 1.0 } }
    end

    local title =
    {
        {
            text  = string.format('%s[%d/%d] %s',
                playerData.name, playerData.serverId, playerData.targIndex, playerJobString),
            color = { 1.0, 0.65, 0.26, 1.0 },
        },
        retailCheck,
    }
    if captain.isCapturing then
        local alpha = (math.sin(addon.frame * 0.03) + 1) * 0.5
        table.insert(title, { text = '\u{F0C7}', color = { 1.0, 0.0, 0.0, alpha } })
    end

    local body =
    {
        { text = 'X: ' .. playerData.x .. ' ' },
        { text = 'Y: ' .. playerData.y .. ' ' },
        { text = 'Z: ' .. playerData.z .. ' ' },
        { text = 'R: ' .. playerData.r .. ' - ' },
        { text = zoneInfo },
    }

    if addon.playerInfo then
        addon.playerInfo:updateTitle(title)
        addon.playerInfo:updateText(body)
    end
end

addon.onInitialize  = function(rootDir)
    addon.isRetail   = backend.is_retail()
    addon.playerInfo = backend.textBox('playerinfo')
end

return addon
