-- Logs key items obtained and lost
---@class KITrackAddon : AddonInterface
---@field keyItemMap table<number, table<number, boolean>> Table to store key items by table index
---@field initializedTables table<number, boolean> Track which tables have been initialized
local addon =
{
    name              = 'KITrack',
    filters           =
    {
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_SCENARIOITEM] = true, -- Key item updates
        },
    },
    settings          = {},
    defaultSettings   =
    {
    },
    files             =
    {
        global = nil,
        capture = nil,
    },
    keyItemMap        = {}, -- Store key items by table index
    initializedTables = {}, -- Track which tables have been initialized
}

--- Converts bitfields to key item IDs
--- @param bitfields number[] Array of 32-bit integers representing key item flags
--- @param tableIndex number The key item table index from the packet
--- @return number[] Array of key item IDs that are set (1-indexed)
local function bitfieldsToKeyItemIds(bitfields, tableIndex)
    local keyItemIds = {}

    for i, value in ipairs(bitfields) do
        if value ~= 0 then
            local baseOffset = (tableIndex * 512) + (i - 1) * 32

            -- Check each bit in the 32-bit value
            for bitPosition = 0, 31 do
                -- If the bit is set (1), then the key item is obtained
                if bit.band(value, bit.lshift(1, bitPosition)) ~= 0 then
                    local keyItemId = baseOffset + bitPosition
                    table.insert(keyItemIds, keyItemId)
                end
            end
        end
    end

    return keyItemIds
end

--- Check for new and removed key items compared to previous state
--- @param keyItemIds number[] Array of current key item IDs
--- @param tableIndex number The key item table index
--- @return table newItems, table removedItems, boolean isFirstUpdate
local function checkKeyItemChanges(keyItemIds, tableIndex)
    local isFirstUpdate = not addon.initializedTables[tableIndex]

    if not addon.keyItemMap[tableIndex] then
        addon.keyItemMap[tableIndex] = {}
    end

    local currentMap = {}
    local newItems = {}
    local removedItems = {}

    -- Build current state map
    for _, id in ipairs(keyItemIds) do
        currentMap[id] = true

        -- Check if this is a new key item (only if not first update)
        if not isFirstUpdate and not addon.keyItemMap[tableIndex][id] then
            table.insert(newItems, id)
        end
    end

    -- Check for removed items (only if not first update)
    if not isFirstUpdate then
        for id, _ in pairs(addon.keyItemMap[tableIndex]) do
            if not currentMap[id] then
                table.insert(removedItems, id)
            end
        end
    end

    addon.keyItemMap[tableIndex] = currentMap

    -- Mark this table as initialized
    addon.initializedTables[tableIndex] = true

    return newItems, removedItems, isFirstUpdate
end

addon.onInitialize = function(rootDir)
    addon.files.global = backend.fileOpen(string.format('%s/%s.log', rootDir, backend.player_name()))
end

addon.onCaptureStart = function(captureDir)
    addon.files.capture = backend.fileOpen(string.format('%s/%s.log', captureDir, backend.player_name()))
end

addon.onCaptureStop = function()
    addon.files.capture = nil
end

addon.onIncomingPacket = function(id, data)
    if id == PacketId.GP_SERV_COMMAND_SCENARIOITEM then
        ---@type GP_SERV_COMMAND_SCENARIOITEM
        local packet = backend.parsePacket('incoming', data)

        -- Get all key item IDs from the bitfields
        local flagValues = {}
        for i, flag in ipairs(packet.GetItemFlag) do
            flagValues[i] = flag
        end

        local keyItemIds = bitfieldsToKeyItemIds(flagValues, packet.TableIndex)

        -- Check for changes
        local newItems, removedItems, isFirstUpdate = checkKeyItemChanges(keyItemIds, packet.TableIndex)

        local player = backend.get_player_entity_data()
        local dataFields =
        {
            x = player.x,
            y = player.y,
            z = player.z,
            zoneName = player.zoneName,
        }

        -- Only report changes if this is not the first update for this table
        if not isFirstUpdate then
            local tstamp = os.date('%Y-%m-%d %H:%M:%S')

            if #newItems > 0 then
                for _, kid in ipairs(newItems) do
                    local notificationData =
                    {
                        { 'ID',   kid },
                        { 'Name', backend.get_key_item_name(kid) },
                        { 'X',    dataFields.x },
                        { 'Y',    dataFields.y },
                        { 'Z',    dataFields.z },
                        { 'Zone', dataFields.zoneName },
                        { 'Timestamp', os.time() }
                    }
                    if addon.files.global then
                        addon.files.global:append(string.format('[%s] Obtained KI\n%s\n\n', tstamp, utils.dump(notificationData)))
                    end

                    if addon.files.capture then
                        addon.files.capture:append(string.format('[%s] Obtained KI\n%s\n\n', tstamp, utils.dump(notificationData)))
                    end

                    backend.notificationCreate('KITrack', 'Obtained Key Item', notificationData, false)
                end
            end

            if #removedItems > 0 then
                for _, kid in ipairs(removedItems) do
                    local notificationData =
                    {
                        { 'ID',   kid },
                        { 'Name', backend.get_key_item_name(kid) },
                        { 'X',    dataFields.x },
                        { 'Y',    dataFields.y },
                        { 'Z',    dataFields.z },
                        { 'Zone', dataFields.zoneName },
                    }
                    if addon.files.global then
                        addon.files.global:append(string.format('[%s] Lost KI\n%s\n\n', tstamp, utils.dump(notificationData)))
                    end

                    if addon.files.capture then
                        addon.files.capture:append(string.format('[%s] Lost KI\n%s\n\n', tstamp, utils.dump(notificationData)))
                    end

                    backend.notificationCreate('KITrack', 'Lost Key Item', notificationData, false)
                end
            end
        end
    end
end

return addon
