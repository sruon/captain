-- Logs synthesis results
---@class CraftTrackAddon : AddonInterface
local addon =
{
    name            = 'CraftTrack',
    filters         =
    {
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_COMBINE_ANS] = true, -- Personal synthesis results
            [PacketId.GP_SERV_COMMAND_EFFECT]      = true, -- Synthesis Animations
        },
    },
    settings        = {},
    defaultSettings =
    {
    },
    csvFiles        =
    {
        global  = nil,
        capture = nil,
    },
    rootDir         = nil,
    captureDir      = nil,
    lastEffect      = nil, -- Last effect packet received for the player
    csvSchema       =
    {
        'Timestamp',
        'Result',
        'Result_Text',
        'Grade',
        'Count',
        'ItemNo',
        'ItemNo_Name',
        'CrystalNo',
        'CrystalNo_Name',
        'MaterialNo_1',
        'MaterialNo_1_Name',
        'MaterialNo_2',
        'MaterialNo_2_Name',
        'MaterialNo_3',
        'MaterialNo_3_Name',
        'MaterialNo_4',
        'MaterialNo_4_Name',
        'MaterialNo_5',
        'MaterialNo_5_Name',
        'MaterialNo_6',
        'MaterialNo_6_Name',
        'MaterialNo_7',
        'MaterialNo_7_Name',
        'MaterialNo_8',
        'MaterialNo_8_Name',
        'BreakNo_1',
        'BreakNo_1_Name',
        'BreakNo_2',
        'BreakNo_2_Name',
        'BreakNo_3',
        'BreakNo_3_Name',
        'BreakNo_4',
        'BreakNo_4_Name',
        'BreakNo_5',
        'BreakNo_5_Name',
        'BreakNo_6',
        'BreakNo_6_Name',
        'BreakNo_7',
        'BreakNo_7_Name',
        'BreakNo_8',
        'BreakNo_8_Name',
        'UpKind_1',
        'UpLevel_1',
        'UpKind_2',
        'UpLevel_2',
        'UpKind_3',
        'UpLevel_3',
        'UpKind_4',
        'UpLevel_4',
        'Effect_EffectNum',
        'Effect_Type',
        'Effect_Quality', -- Human-readable animation quality
        'Effect_Status',
        'Effect_Timer',
    },
}

local function getItemName(id)
    if not id or id == 0 then
        return ''
    end
    local name = backend.get_item_name(id)
    if name == 'Unknown Item' then
        return tostring(id)
    end
    return name
end


addon.onInitialize   = function(rootDir)
    addon.rootDir         = rootDir

    addon.csvFiles.global = backend.csvOpen(
        string.format('%s/%s.csv', rootDir, backend.player_name()),
        addon.csvSchema)
end

addon.onCaptureStart = function(captureDir)
    addon.captureDir       = captureDir

    addon.csvFiles.capture = backend.csvOpen(
        string.format('%s/%s.csv', captureDir, backend.player_name()),
        addon.csvSchema)
end

addon.onCaptureStop  = function()
    addon.captureDir = nil

    if addon.csvFiles.capture then
        addon.csvFiles.capture:close()
        addon.csvFiles.capture = nil
    end
end


-- Result codes for synthesis
local RESULT_CODES      =
{
    [0x00] = 'Success',              -- Successful synthesis; displays the item information sub-window
    [0x01] = 'Fail: Lost Crystal',   -- Synthesis failed. You lost the crystal you were using
    [0x02] = 'Fail: Interrupted',    -- Synthesis interrupted. You lost the crystal and materials you were using
    [0x03] = 'Fail: Invalid Combo',  -- Synthesis canceled. That combination of materials cannot be synthesized
    [0x04] = 'Fail: Canceled',       -- Synthesis canceled
    [0x06] = 'Fail: Skill Too Low',  -- Synthesis canceled. That formula is beyond your current craft skill level
    [0x07] = 'Fail: Inventory Full', -- Synthesis canceled. You cannot hold more than one item of that type
    [0x0C] = 'Success',              -- Successful synthesis; displays the item information sub-window
    [0x0D] = 'Fail: Too Soon',       -- You must wait longer before repeating that action
    [0x0E] = 'Fail: Interrupted',    -- Synthesis interrupted. You lost the crystal and materials you were using
}

-- Animation quality results (from Effect_Type field)
local ANIMATION_QUALITY =
{
    [0] = 'Normal Quality',
    [1] = 'Break',
    [2] = 'High-Quality',
    [3] = 'High-Quality',
    [4] = 'High-Quality',
}

addon.onIncomingPacket  = function(id, data, size, packet)
    if not packet then
        return
    end

    if id == PacketId.GP_SERV_COMMAND_EFFECT then
        -- Only track effects for the player
        local player = backend.get_player_entity_data()
        if player and packet.UniqueNo == player.serverId then
            -- Store the last effect packet for this player
            addon.lastEffect =
            {
                EffectNum = packet.EffectNum,
                Type      = packet.Type,
                Status    = packet.Status,
                Timer     = packet.Timer,
            }
        end
    elseif id == PacketId.GP_SERV_COMMAND_COMBINE_ANS then

        -- Only log actual synthesis attempts (0x00 success, 0x01 fail, 0x0C success)
        if packet.Result ~= 0x00 and packet.Result ~= 0x01 and packet.Result ~= 0x0C then
            return
        end

        local timestamp  = os.time()
        local resultText = RESULT_CODES[packet.Result] or string.format('Unknown(%d)', packet.Result)

        -- Prepare CSV entry
        local csvEntry   =
        {
            Timestamp        = timestamp,
            Result           = packet.Result or 0,
            Result_Text      = resultText,
            Grade            = packet.Grade or 0,
            Count            = packet.Count or 0,
            ItemNo           = packet.ItemNo or 0,
            ItemNo_Name      = getItemName(packet.ItemNo),
            CrystalNo        = packet.CrystalNo or 0,
            CrystalNo_Name   = getItemName(packet.CrystalNo),
            Effect_EffectNum = addon.lastEffect and addon.lastEffect.EffectNum or 0,
            Effect_Type      = addon.lastEffect and addon.lastEffect.Type or 0,
            Effect_Quality   = addon.lastEffect and
            (ANIMATION_QUALITY[addon.lastEffect.Type] or string.format('Unknown(%d)', addon.lastEffect.Type)) or '',
            Effect_Status    = addon.lastEffect and addon.lastEffect.Status or 0,
            Effect_Timer     = addon.lastEffect and addon.lastEffect.Timer or 0,
        }

        -- Add MaterialNo information
        for i = 1, 8 do
            if packet.MaterialNo and packet.MaterialNo[i] then
                local matId                                      = packet.MaterialNo[i] or 0
                csvEntry[string.format('MaterialNo_%d', i)]      = matId
                csvEntry[string.format('MaterialNo_%d_Name', i)] = getItemName(matId)
            else
                csvEntry[string.format('MaterialNo_%d', i)]      = 0
                csvEntry[string.format('MaterialNo_%d_Name', i)] = ''
            end
        end

        -- Add BreakNo (items lost during synthesis)
        for i = 1, 8 do
            if packet.BreakNo and packet.BreakNo[i] then
                local breakId                                 = packet.BreakNo[i] or 0
                csvEntry[string.format('BreakNo_%d', i)]      = breakId
                csvEntry[string.format('BreakNo_%d_Name', i)] = getItemName(breakId)
            else
                csvEntry[string.format('BreakNo_%d', i)]      = 0
                csvEntry[string.format('BreakNo_%d_Name', i)] = ''
            end
        end

        -- Add UpKind and UpLevel information
        for i = 1, 4 do
            if packet.UpKind and packet.UpKind[i] then
                csvEntry[string.format('UpKind_%d', i)] = packet.UpKind[i] or 0
            else
                csvEntry[string.format('UpKind_%d', i)] = 0
            end

            if packet.UpLevel and packet.UpLevel[i] then
                csvEntry[string.format('UpLevel_%d', i)] = packet.UpLevel[i] or 0
            else
                csvEntry[string.format('UpLevel_%d', i)] = 0
            end
        end

        -- Log to CSV files
        if addon.csvFiles.global then
            addon.csvFiles.global:add_entry(csvEntry)
            addon.csvFiles.global:save()
        end

        if addon.csvFiles.capture then
            addon.csvFiles.capture:add_entry(csvEntry)
            addon.csvFiles.capture:save()
        end

        -- Clear the last effect after logging
        addon.lastEffect = nil
    end
end

return addon
