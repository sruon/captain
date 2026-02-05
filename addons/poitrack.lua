-- Credits: sruon
-- Tracks points of interest (NPCs/entities) and their positions

---@class POITrackAddon : AddonInterface
local addon            =
{
    name     = 'POITrack',
    filters  =
    {
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_CHAR_NPC] = true, -- NPC spawn packets
        },
    },
    rootDir  = nil,
    database = nil,
    schema   =
    {
        uniqueId = 0,
        name     = '',
        x        = 100.005,
        y        = 200.005,
        z        = 300.005,
    },
    -- POI names to track (add names here)
    poiNames =
    {
        ['Treasure Chest']      = true,
        ['Treasure Coffer']     = true,
        ['???']                 = true,
        ['Harvesting Point']    = true,
        ['Logging Point']       = true,
        ['Mining Point']        = true,
        ['Excavation Point']    = true,
        ['Warhorse Hoofprint']  = true,
    },
}

addon.onIncomingPacket = function(id, data, size, packet)
    if id ~= PacketId.GP_SERV_COMMAND_CHAR_NPC then
        return
    end

    if not packet then
        return
    end

    -- Get entity info
    local mob = backend.get_mob_by_index(packet.ActIndex)
    if not mob or not mob.name or mob.name == '' then
        return
    end

    -- Check if this is a POI we're tracking
    if not addon.poiNames[mob.name] then
        return
    end

    -- Check if packet contains position data
    if not packet.SendFlg or not packet.SendFlg.Position then
        return
    end

    local x = packet.x
    local y = packet.y
    local z = packet.z

    -- Skip zero positions
    if x == 0 and y == 0 and z == 0 then
        return
    end

    -- Round coordinates to nearest integer for key (to group nearby positions)
    local x_rounded = math.floor(x + 0.5)
    local y_rounded = math.floor(y + 0.5)
    local z_rounded = math.floor(z + 0.5)

    local db_key = string.format('%d-%s-%d-%d-%d', packet.UniqueNo, mob.name, x_rounded, y_rounded, z_rounded)

    if addon.database and addon.database:get(db_key) then
        return
    end

    local entry = {
        uniqueId = packet.UniqueNo or packet.ActIndex,
        name     = mob.name,
        x        = x,
        y        = y,
        z        = z,
    }

    if addon.database then
        addon.database:add_or_update(db_key, entry)
        backend.msg('POITrack', string.format('Found %s [%d] at (%.3f, %.3f, %.3f)', mob.name, entry.uniqueId, x, y, z))
    end
end

local function openDatabase()
    if addon.database then
        addon.database:close()
    end

    local zone_name = backend.zone_name()
    local db_path   = string.format('%s/%s/POI_%s.db', addon.rootDir, backend.player_name(), zone_name)
    addon.database  = backend.databaseOpen(db_path, { schema = addon.schema })
end

addon.onInitialize = function(rootDir)
    addon.rootDir = rootDir
    openDatabase()
end

addon.onClientReady = function()
    openDatabase()
end

addon.onZoneChange = function()
    openDatabase()
end

addon.onUnload = function()
    if addon.database then
        addon.database:close()
    end
end

return addon
