-- Logs items sold and purchased by Guild shop NPCs
---@class GuildStockAddon : AddonInterface
---@field database Database | nil
local addon          =
{
    name            = 'GuildStock',
    filters         =
    {
        outgoing =
        {
            [PacketId.GP_CLI_COMMAND_ACTION] = true, -- Talking to NPCs
        },
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_GUILD_SELLLIST] = true, -- Items purchased by NPC
            [PacketId.GP_SERV_COMMAND_GUILD_BUYLIST]  = true, -- Items sold by NPC
        },
    },
    settings        = {},
    defaultSettings =
    {
    },
    rootDir         = nil,
    databases       =
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
    guildNpc        =
    {
        UniqueNo = 0,
        Name     = '',
    },
}

local makeDatabases  = function(baseDir)
    local buy  = backend.databaseOpen(
        string.format('%s/%s/BuyList.db', baseDir, backend.player_name()),
        {
            schema =
            {
                NpcUniqueNo = 1,
                NpcName     = '',
                NpcZone     = '',
                ItemNo      = 1,
                ItemName    = '',
                Count       = 1,
                Max         = 1,
                Price       = 1,
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
                Count       = 1,
                Max         = 1,
                Price       = 1,
            },
        })

    return buy, sell
end

addon.onInitialize   = function(rootDir)
    addon.databases.global.buyList, addon.databases.global.sellList = makeDatabases(rootDir)
end

addon.onUnload       = function()
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

addon.onCaptureStart = function(captureDir)
    addon.databases.capture.buyList, addon.databases.capture.sellList = makeDatabases(captureDir)
end

addon.onCaptureStop  = function()
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
                addon.guildNpc =
                {
                    UniqueNo = actionPacket.UniqueNo,
                    Name     = npc.name,
                }
            end
        end
    end
end

addon.onIncomingPacket = function(id, data)
    if not backend.is_retail() then
        return
    end

    if id == PacketId.GP_SERV_COMMAND_GUILD_BUYLIST then
        if addon.guildNpc.UniqueNo == 0 then
            backend.errMsg('GuildStock', 'GUILD_BUYLIST without NPC - talk to the Guild Shop again.')
            return
        end

        ---@type GP_SERV_COMMAND_GUILD_BUYLIST
        local buyListPacket = backend.parsePacket('incoming', data)
        for i = 1, buyListPacket.Count do
            local itemEntry = buyListPacket.List[i]
            local itemKey   = string.format('%s-%d', addon.guildNpc.Name, itemEntry.ItemNo)
            local dbEntry   =
            {
                NpcUniqueNo = addon.guildNpc.UniqueNo,
                NpcName     = addon.guildNpc.Name,
                NpcZone     = backend.zone_name(),
                ItemNo      = itemEntry.ItemNo,
                ItemName    = backend.get_item_name(itemEntry.ItemNo),
                Count       = itemEntry.Count,
                Max         = itemEntry.Max,
                Price       = itemEntry.Price,
            }
            if addon.databases.global.buyList then
                addon.databases.global.buyList:add_or_update(itemKey, dbEntry)
            end

            if addon.databases.capture.buyList then
                addon.databases.capture.buyList:add_or_update(itemKey, dbEntry)
            end
        end

        backend.msg('GuildStock',
            string.format('Recorded %d items sold by %s', buyListPacket.Count, addon.guildNpc.Name))
    end

    if id == PacketId.GP_SERV_COMMAND_GUILD_SELLLIST then
        if addon.guildNpc.UniqueNo == 0 then
            backend.errMsg('GuildStock', 'GUILD_SELLLIST without NPC - talk to the Guild Shop again.')
            return
        end

        ---@type GP_SERV_COMMAND_GUILD_SELLLIST
        local sellListPacket = backend.parsePacket('incoming', data)
        for i = 1, sellListPacket.Count do
            local itemEntry = sellListPacket.List[i]
            local itemKey   = string.format('%s-%d', addon.guildNpc.Name, itemEntry.ItemNo)
            local dbEntry   =
            {
                NpcUniqueNo = addon.guildNpc.UniqueNo,
                NpcName     = addon.guildNpc.Name,
                NpcZone     = backend.zone_name(),
                ItemNo      = itemEntry.ItemNo,
                ItemName    = backend.get_item_name(itemEntry.ItemNo),
                Count       = itemEntry.Count,
                Max         = itemEntry.Max,
                Price       = itemEntry.Price,
            }

            if addon.databases.global.sellList then
                addon.databases.global.sellList:add_or_update(itemKey, dbEntry)
            end

            if addon.databases.capture.sellList then
                addon.databases.capture.sellList:add_or_update(itemKey, dbEntry)
            end
        end

        backend.msg('GuildStock',
            string.format('Recorded %d items purchased by %s', sellListPacket.Count, addon.guildNpc.Name))
    end
end

return addon
