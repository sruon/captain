-- Credits: zach2good
-- Displays target info in a floating textbox. UniqueNo/ActIndex/Position
-- Sends /check packets to get level if widescan has not been done yet
---@class TargetInfoAddon : AddonInterface
---@field targetInfo TextBox?
local addon            =
{
    name            = 'TargetInfo',
    targetInfo      = nil,
    filters         =
    {
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_BATTLE_MESSAGE] = true, -- /check
            [PacketId.GP_SERV_COMMAND_TRACKING_LIST]  = true, -- Widescan state updates
        },
    },
    settings        = {},
    defaultSettings =
    {
        sendCheck = false,
    },
    checkData       = {},
    pendingCheck    = {},
}

addon.onIncomingPacket = function(id, data)
    local packet = backend.parsePacket('incoming', data)
    if id == PacketId.GP_SERV_COMMAND_BATTLE_MESSAGE then
        ---@type GP_SERV_COMMAND_BATTLE_MESSAGE
        packet = packet

        -- 170: high-eva/high-def -> 178: low-eva/low-def
        -- 249: impossible to gauge
        if (packet.MessageNum >= 170 and packet.MessageNum <= 178) or packet.MessageNum == 249 then
            if not addon.pendingCheck[packet.ActIndexTar] then
                -- Disregard packets initiated by player
                return false
            end

            if packet.Data2 ~= 0 then
                addon.checkData[packet.ActIndexTar]    =
                {
                    level = packet.Data,
                }
                addon.pendingCheck[packet.ActIndexTar] = nil
            else
                addon.checkData[packet.ActIndexTar] =
                {
                    level = -1,
                }
            end

            return true
        end
    elseif id == PacketId.GP_SERV_COMMAND_TRACKING_LIST then
        ---@type GP_SERV_COMMAND_TRACKING_LIST
        packet                           = packet

        addon.checkData[packet.ActIndex] =
        {
            level = packet.Level,
        }
    end
end

addon.onPrerender      = function()
    local targetData      = backend.get_target_entity_data()
    local targetTitleStr  = ''
    local targetOutputStr = ''
    if targetData then
        local checkData = addon.checkData[targetData.targIndex]
        local levelStr  = 'Lv. ?'
        if checkData and checkData.level ~= -1 then
            levelStr = string.format('Lv. %d', checkData.level)
        elseif not addon.pendingCheck[targetData.targIndex] then
            if backend.is_mob(targetData.targIndex) and addon.settings.sendCheck then
                backend.doCheck(targetData.targIndex)
                addon.pendingCheck[targetData.targIndex] = true
            end
        end

        targetTitleStr  = string.format('%s[%d/%d] %s', targetData.name, targetData.serverId, targetData.targIndex,
            levelStr)

        targetOutputStr =
          'X: ' .. targetData.x .. ' ' ..
          'Y: ' .. targetData.y .. ' ' ..
          'Z: ' .. targetData.z .. ' ' ..
          'R: ' .. targetData.r
        if addon.targetInfo then
            addon.targetInfo:updateTitle(targetTitleStr)
            addon.targetInfo:updateText(targetOutputStr)
            addon.targetInfo:show()
        end
    else
        if addon.targetInfo then
            addon.targetInfo:hide()
        end
    end
end

addon.onInitialize     = function(_)
    addon.targetInfo = backend.textBox('target')
end

addon.onZoneChange     = function(_)
    addon.checkData    = {}
    addon.pendingCheck = {}
end

addon.onConfigMenu     = function()
    return
    {
        {
            key         = 'sendCheck',
            title       = 'Enable auto /check',
            description =
            'Sends /check packets when encountering a new target. Faster than widescan but does not work for NMs.',
            type        = 'checkbox',
            default     = addon.defaultSettings.sendCheck,
        },
    }
end

return addon
