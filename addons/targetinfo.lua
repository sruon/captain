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
            [PacketId.GP_SERV_COMMAND_CHAR_NPC]       = true,
            [PacketId.GP_SERV_COMMAND_CHAR_PC]        = true,
        },
    },
    settings        = {},
    defaultSettings =
    {
        sendCheck = false,
    },
    checkData       = {},
    pendingCheck    = {},
    modelSizes      = {},
    hitboxSizes     = {},
    modelIds        = {},
    speeds          = {},
    speedBases      = {},
}

addon.onIncomingPacket = function(id, data)
    local packet = backend.parsePacket('incoming', data)

    if id == PacketId.GP_SERV_COMMAND_CHAR_PC then
        ---@type GP_SERV_COMMAND_CHAR_PC
        packet = packet

        if packet.ModelHitboxSize ~= 0 then
            addon.hitboxSizes[packet.ActIndex] = packet.ModelHitboxSize
        end

        if packet.Flags1.GraphSize ~= 0 then
            addon.modelSizes[packet.ActIndex] = packet.Flags1.GraphSize
        end

        if packet.Speed and packet.Speed ~= 0 then
            addon.speeds[packet.ActIndex] = packet.Speed
        end

        if packet.SpeedBase and packet.SpeedBase ~= 0 then
            addon.speedBases[packet.ActIndex] = packet.SpeedBase
        end
    elseif id == PacketId.GP_SERV_COMMAND_CHAR_NPC then
        ---@type GP_SERV_COMMAND_CHAR_NPC
        packet = packet

        if packet.Flags2.g ~= 0 then
            addon.hitboxSizes[packet.ActIndex] = packet.Flags2.g
        end

        if packet.Flags1.GraphSize ~= 0 then
            addon.modelSizes[packet.ActIndex] = packet.Flags1.GraphSize
        end

        if packet.Data and packet.Data.model_id and packet.Data.model_id ~= 0 then
            addon.modelIds[packet.ActIndex] = packet.Data.model_id
        end

        if packet.Speed and packet.Speed ~= 0 then
            addon.speeds[packet.ActIndex] = packet.Speed
        end

        if packet.SpeedBase and packet.SpeedBase ~= 0 then
            addon.speedBases[packet.ActIndex] = packet.SpeedBase
        end
    elseif id == PacketId.GP_SERV_COMMAND_BATTLE_MESSAGE then
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

        -- Row 1: Position and Distance (using monospace alignment)
        local row1      = string.format('X:%-7.3f Y:%-7.3f Z:%-7.3f R:%-3d D:%.3f',
            targetData.x, targetData.y, targetData.z, targetData.r, targetData.distance)
        -- Row 2: Model info
        local row2      = string.format('Model:%-4d Hitbox:%-2d Size:%d',
            addon.modelIds[targetData.targIndex] or 0,
            addon.hitboxSizes[targetData.targIndex] or 0,
            addon.modelSizes[targetData.targIndex] or 0)
        -- Row 3: Speed info
        local row3      = string.format('Speed:%-3d Base:%-3d',
            addon.speeds[targetData.targIndex] or 0,
            addon.speedBases[targetData.targIndex] or 0)

        targetOutputStr = row1 .. '\n' .. row2 .. '\n' .. row3
        if addon.targetInfo then
            addon.targetInfo:updateTitle({ { text = targetTitleStr, color = { 1.0, 0.65, 0.26, 1.0 } } })
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
    addon.hitboxSizes  = {}
    addon.modelSizes   = {}
    addon.modelIds     = {}
    addon.speeds       = {}
    addon.speedBases   = {}
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
