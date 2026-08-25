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
    animationSubs   = {},
}

addon.onIncomingPacket = function(id, data, size, packet)
    if not packet then return end

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

        if packet.SubAnimation then
            addon.animationSubs[packet.ActIndex] = packet.SubAnimation
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

local lastIndex, lastLevel, lastModel, lastHitbox, lastSize, lastAnimSub, lastSpeed, lastBase
local lastX, lastY, lastZ, lastR, lastDistance
local titleTable = { { text = '', color = { 1.0, 0.65, 0.26, 1.0 } } }
local row1, row2, row3
local outputStr  = ''

addon.onPrerender      = function()
    local targetData = backend.get_target_entity_data()
    if not targetData then
        lastIndex = nil
        if addon.targetInfo then
            addon.targetInfo:hide()
        end

        return
    end

    local index     = targetData.targIndex
    local checkData = addon.checkData[index]
    local level     = checkData and checkData.level or nil

    if not checkData and not addon.pendingCheck[index] then
        if backend.is_mob(index) and addon.settings.sendCheck then
            backend.doCheck(index)
            addon.pendingCheck[index] = true
        end
    end

    local model   = addon.modelIds[index] or 0
    local hitbox  = addon.hitboxSizes[index] or 0
    local size    = addon.modelSizes[index] or 0
    local animSub = addon.animationSubs[index] or 0
    local speed   = addon.speeds[index] or 0
    local base    = addon.speedBases[index] or 0
    local dirty   = false

    if index ~= lastIndex or level ~= lastLevel then
        lastIndex, lastLevel = index, level
        dirty                = true

        local levelStr = 'Lv. ?'
        if level and level ~= -1 then
            levelStr = string.format('Lv. %d', level)
        end

        titleTable[1].text = string.format('%s[%d/%d] %s', targetData.name, targetData.serverId, index, levelStr)
    end

    if targetData.x ~= lastX or targetData.y ~= lastY or targetData.z ~= lastZ or targetData.r ~= lastR
      or targetData.distance ~= lastDistance then
        lastX, lastY, lastZ, lastR = targetData.x, targetData.y, targetData.z, targetData.r
        lastDistance               = targetData.distance
        dirty                      = true
        row1                       = string.format('X:%-7.3f Y:%-7.3f Z:%-7.3f R:%-3d D:%.3f',
            targetData.x, targetData.y, targetData.z, targetData.r, targetData.distance)
    end

    if model ~= lastModel or hitbox ~= lastHitbox or size ~= lastSize or animSub ~= lastAnimSub then
        lastModel, lastHitbox, lastSize, lastAnimSub = model, hitbox, size, animSub
        dirty                                        = true
        row2                                         = string.format('Model:%-4d Hitbox:%-2d Size:%-2d AnimSub:%d',
            model, hitbox, size, animSub)
    end

    if speed ~= lastSpeed or base ~= lastBase then
        lastSpeed, lastBase = speed, base
        dirty               = true
        row3                = string.format('Speed:%-3d Base:%-3d', speed, base)
    end

    if dirty then
        outputStr = row1 .. '\n' .. row2 .. '\n' .. row3
    end

    if addon.targetInfo then
        addon.targetInfo:updateTitle(titleTable)
        addon.targetInfo:updateText(outputStr)
        addon.targetInfo:show()
    end
end

addon.onInitialize     = function(_)
    addon.targetInfo = backend.textBox('target')
end

addon.onZoneChange     = function(_)
    addon.checkData      = {}
    addon.pendingCheck   = {}
    addon.hitboxSizes    = {}
    addon.modelSizes     = {}
    addon.modelIds       = {}
    addon.speeds         = {}
    addon.speedBases     = {}
    addon.animationSubs  = {}
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
