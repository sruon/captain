-- Logs items sold and purchased by NPC shops
-- Can optionally automatically appraise all sellable items in inventory.
---@class ShopStockAddon : AddonInterface
---@field database Database | nil
local addon            =
{
    name               = 'ShopStock',
    filters            =
    {
        outgoing =
        {
            [PacketId.GP_CLI_COMMAND_ACTION] = true, -- Talking to NPCs
        },
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_SHOP_OPEN] = true, -- Opening a shop
            [PacketId.GP_SERV_COMMAND_SHOP_LIST] = true, -- Items sold by the NPC
            [PacketId.GP_SERV_COMMAND_SHOP_SELL] = true, -- Item appraisal
        },
    },
    settings           = {},
    defaultSettings    =
    {
        autoAppraise = false,
    },
    databases          =
    {
        global  =
        {
            buyList  = nil,
            sellList = nil,
        },

        capture =
        {
            buyList  = nil,
            sellList = nil,
        },
    },
    shopNpc            =
    {
        UniqueNo = 0,
        Name     = '',
    },
    expectedAppraisals = 0,
}

local makeDatabases    = function(baseDir)
    local buy  = backend.databaseOpen(
        string.format('%s/%s/BuyList.db', baseDir, backend.player_name()),
        {
            schema =
            {
                NpcUniqueNo = 1,
                NpcName     = '',
                NpcZone     = '',
                GuildInfo   = 1,
                ItemNo      = 1,
                ItemName    = '',
                ItemPrice   = 1,
                ShopIndex   = 1,
                Skill       = 1,
            },
        })
    local sell = backend.databaseOpen(
        string.format('%s/%s/SellList.db', baseDir, backend.player_name()),
        {
            schema =
            {
                NpcUniqueNo = 1,
                NpcName     = '',
                NpcZone     = '',
                ItemNo      = 1,
                ItemName    = '',
                Price       = 1,
            },
        })

    return buy, sell
end

addon.onInitialize     = function(rootDir)
    addon.databases.global.buyList, addon.databases.global.sellList = makeDatabases(rootDir)
end

addon.onUnload         = function()
    if addon.databases.global.buyList then
        addon.databases.global.buyList:close()
    end

    if addon.databases.global.sellList then
        addon.databases.global.sellList:close()
    end

    if addon.databases.capture.buyList then
        addon.databases.capture.buyList:close()
    end

    if addon.databases.capture.sellList then
        addon.databases.capture.sellList:close()
    end
end

addon.onCaptureStart   = function(captureDir)
    addon.databases.capture.buyList, addon.databases.capture.sellList = makeDatabases(captureDir)
end

addon.onCaptureStop    = function()
    if addon.databases.capture.buyList then
        addon.databases.capture.buyList:close()
        addon.databases.capture.buyList = nil
    end

    if addon.databases.capture.sellList then
        addon.databases.capture.sellList:close()
        addon.databases.capture.sellList = nil
    end
end

addon.onOutgoingPacket = function(id, data)
    if id == PacketId.GP_CLI_COMMAND_ACTION then
        local actionPacket = backend.parsePacket('outgoing', data)
        if actionPacket.ActionID == 0 then
            local npc = backend.get_mob_by_index(actionPacket.ActIndex)
            if npc then
                addon.shopNpc =
                {
                    UniqueNo = actionPacket.UniqueNo,
                    Name     = npc.name,
                }
            end
        end
    end
end

local function autoAppraise()
    local invItems = backend.get_inventory_items(0)

    if not invItems then
        return
    end

    backend.msg('ShopStock', 'Auto-appraising items in inventory')
    local uniqueItems = {}
    -- Find sellable items and dedupe
    for _, item in ipairs(invItems) do
        local flags = backend.get_item_flags(item.Id)
        if flags ~= 0 and bit.band(flags, 0x1000) == 0 then
            if not uniqueItems[item.Id] then
                uniqueItems[item.Id] = item.Index
            end
        end
    end

    local count = 0
    for itemNo, invIndex in pairs(uniqueItems) do
        local itemNum = 1
        backend.schedule(function()
            backend.injectPacket(PacketId.GP_CLI_COMMAND_SHOP_SELL_REQ,
                {
                    PacketId.GP_CLI_COMMAND_SHOP_SELL_REQ,
                    0x10, -- size
                    0x00, -- sync
                    0x00, -- sync
                    bit.band(itemNum, 0xFF),
                    bit.band(bit.rshift(itemNum, 8), 0xFF),
                    bit.band(bit.rshift(itemNum, 16), 0xFF),
                    bit.band(bit.rshift(itemNum, 24), 0xFF),
                    bit.band(itemNo, 0xFF),
                    bit.band(bit.rshift(itemNo, 8), 0xFF),
                    invIndex,
                    0x00, -- padding
                })
        end, count * 0.1)

        count = count + 1
    end
end

addon.onIncomingPacket = function(id, data)
    if not backend.is_retail() then
        return
    end

    if id == PacketId.GP_SERV_COMMAND_SHOP_OPEN then
        if addon.settings.autoAppraise then
            autoAppraise()
        end
    end

    if id == PacketId.GP_SERV_COMMAND_SHOP_LIST then
        if addon.shopNpc.UniqueNo == 0 then
            backend.errMsg('ShopStock', 'SHOP_LIST without NPC - talk to the NPC Shop again.')
            return
        end

        ---@type GP_SERV_COMMAND_SHOP_LIST
        local buyListPacket = backend.parsePacket('incoming', data)
        for _, item in ipairs(buyListPacket.ShopItemTbl) do
            if bit.band(item.ItemPrice, 0x80000000) ~= 0 then
                backend.msg('ShopStock', string.format('Item %s has MSB set - Unknown meaning.', backend.get_item_name(item.ItemNo)))
            end

            local itemKey   = string.format('%s-%d', addon.shopNpc.Name, item.ItemNo)
            local itemEntry =
            {
                NpcUniqueNo = addon.shopNpc.UniqueNo,
                NpcName     = addon.shopNpc.Name,
                NpcZone     = backend.zone_name(),
                GuildInfo   = item.GuildInfo,
                ItemNo      = item.ItemNo,
                ItemName    = backend.get_item_name(item.ItemNo),
                ItemPrice   = bit.band(item.ItemPrice, 0x3FFFFFFF), -- Not sure if MSB can be set in shop packets but just in case
                ShopIndex   = item.ShopIndex,
                Skill       = item.Skill,
            }
            if addon.databases.global.buyList then
                addon.databases.global.buyList:add_or_update(itemKey, itemEntry)
            end

            if addon.databases.capture.buyList then
                addon.databases.capture.buyList:add_or_update(itemKey, itemEntry)
            end
        end

        backend.msg('ShopStock',
            string.format('Recorded %d items sold by %s', #buyListPacket.ShopItemTbl, addon.shopNpc.Name))
    end

    if id == PacketId.GP_SERV_COMMAND_SHOP_SELL then
        if addon.shopNpc.UniqueNo == 0 then
            backend.errMsg('ShopStock', 'SHOP_SELL without NPC - talk to the NPC Shop again.')
            return
        end
        ---@type GP_SERV_COMMAND_SHOP_SELL
        local sellPacket = backend.parsePacket('incoming', data)
        if sellPacket.Type ~= 0 then -- We only care about appraisals
            return
        end

        local invItem = backend.get_inventory_item(0, sellPacket.PropertyItemIndex)
        if invItem then
            local itemKey   = string.format('%s-%d', addon.shopNpc.Name, invItem.Id)
            local itemEntry =
            {
                NpcUniqueNo = addon.shopNpc.UniqueNo,
                NpcName     = addon.shopNpc.Name,
                NpcZone     = backend.zone_name(),
                ItemNo      = invItem.Id,
                ItemName    = backend.get_item_name(invItem.Id),
                Price       = bit.band(sellPacket.Price, 0x3FFFFFFF), -- Not sure if MSB can be set in shop packets but just in case
            }
            if addon.databases.global.sellList then
                addon.databases.global.sellList:add_or_update(itemKey, itemEntry)
            end

            if addon.databases.capture.sellList then
                addon.databases.capture.sellList:add_or_update(itemKey, itemEntry)
            end

            backend.msg('ShopStock', string.format('Appraisal for %s: %dg', itemEntry.ItemName, itemEntry.Price))
        end
    end
end

addon.onConfigMenu     = function()
    return
    {
        {
            key         = 'autoAppraise',
            title       = 'Enable Auto-Appraisal',
            description = 'If enabled, will query price for every item in inventory when encountering shops.',
            type        = 'checkbox',
            default     = addon.defaultSettings.autoAppraise,
        },
    }
end

return addon
