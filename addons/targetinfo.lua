-- Credits: zach2good
---@class TargetInfoAddon : AddonInterface
---@field targetInfo TextBox?
local addon = {
    name       = 'TargetInfo',
    targetInfo = nil,
    settings   = {},
}

addon.onPrerender = function()
    local targetData = backend.get_target_entity_data()
    local targetTitleStr = ''
    local targetOutputStr = ''
    if targetData then
        targetTitleStr = string.format('%s[%d/%d]', targetData.name, targetData.serverId, targetData.targIndex)

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

addon.onInitialize = function(_)
    addon.targetInfo = backend.textBox('target')
end

return addon
