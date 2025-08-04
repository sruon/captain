-- Logs items sold and purchased by Guild shop NPCs
-- Passive only.
---@class GuildStockAddon : AddonInterface
---@field database Database | nil
local addon            =
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
    guildNpc        =
    {
        UniqueNo = 0,
        Name     = '',
    },
}

addon.onInitialize     = function(rootDir)
    addon.rootDir = rootDir
end

addon.onUnload         = function()
    if addon.database then
        addon.database:close()
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
    -- Only support capturing from retail. You may need to rezone before this passes.
    if not backend.is_retail() then
        return
    end

    if id == PacketId.GP_SERV_COMMAND_GUILD_BUYLIST then
        if addon.guildNpc.UniqueNo == 0 then
            backend.errMsg('GuildStock', 'GUILD_BUYLIST without NPC - talk to the Guild Shop again.')
            return
        end

        local db            = backend.databaseOpen(
            string.format('%s/%s/%s/ForSale.db', addon.rootDir, backend.zone_name(), addon.guildNpc.Name),
            {
                schema =
                {
                    ItemNo   = 1,
                    ItemName = '',
                    Count    = 1,
                    Max      = 1,
                    Price    = 1,
                },
            })

        ---@type GP_SERV_COMMAND_GUILD_BUYLIST
        local buyListPacket = backend.parsePacket('incoming', data)
        for i = 1, buyListPacket.Count do
            local itemEntry = buyListPacket.List[i]
            db:add_or_update(itemEntry.ItemNo,
                {
                    ItemNo   = itemEntry.ItemNo,
                    ItemName = backend.get_item_name(itemEntry.ItemNo),
                    Count    = itemEntry.Count,
                    Max      = itemEntry.Max,
                    Price    = itemEntry.Price,
                })
        end

        db:close()
        backend.msg('GuildStock',
            string.format('Recorded %d items sold by %s', buyListPacket.Count, addon.guildNpc.Name))
    end

    if id == PacketId.GP_SERV_COMMAND_GUILD_SELLLIST then
        if addon.guildNpc.UniqueNo == 0 then
            backend.errMsg('GuildStock', 'GUILD_SELLLIST without NPC - talk to the Guild Shop again.')
            return
        end

        local db             = backend.databaseOpen(
            string.format('%s/%s/%s/IsBuying.db', addon.rootDir, backend.zone_name(), addon.guildNpc.Name),
            {
                schema =
                {
                    ItemNo   = 1,
                    ItemName = '',
                    Count    = 1,
                    Max      = 1,
                    Price    = 1,
                },
            })

        ---@type GP_SERV_COMMAND_GUILD_SELLLIST
        local sellListPacket = backend.parsePacket('incoming', data)
        for i = 1, sellListPacket.Count do
            local itemEntry = sellListPacket.List[i]
            db:add_or_update(itemEntry.ItemNo,
                {
                    ItemNo   = itemEntry.ItemNo,
                    ItemName = backend.get_item_name(itemEntry.ItemNo),
                    Count    = itemEntry.Count,
                    Max      = itemEntry.Max,
                    Price    = itemEntry.Price,
                })
        end

        db:close()
        backend.msg('GuildStock',
            string.format('Recorded %d items purchased by %s', sellListPacket.Count, addon.guildNpc.Name))
    end
end

return addon
