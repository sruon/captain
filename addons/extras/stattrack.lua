-- Logs character status updates to CSV
---@class StatTrackAddon : AddonInterface
local addon =
{
    name            = 'StatTrack',
    filters         =
    {
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_CLISTATUS] = true,
            [0x044] = true,
        },
    },
    settings        = {},
    defaultSettings =
    {
    },
    files           =
    {
        global  = nil,
        capture = nil,
        puppet_global = nil,
        puppet_capture = nil,
    },
    csvSchema       =
    {
        'timestamp',
        'hpmax',
        'mpmax',
        'mjob_no',
        'mjob_lv',
        'sjob_no',
        'sjob_lv',
        'STR',
        'DEX',
        'VIT',
        'AGI',
        'INT',
        'MND',
        'CHR',
    },
    puppetCsvSchema =
    {
        'timestamp',
        'maxhp',
        'maxmp',
        'maxmelee',
        'maxranged',
        'maxmagic',
        'str',
        'dex',
        'vit',
        'agi',
        'int',
        'mnd',
        'chr',
    },
}

addon.onInitialize     = function(rootDir)
    addon.files.global = backend.csvOpen(
        string.format('%s/%s.csv', rootDir, backend.player_name()),
        addon.csvSchema
    )
    addon.files.puppet_global = backend.csvOpen(
        string.format('%s/%s_puppetstats.csv', rootDir, backend.player_name()),
        addon.puppetCsvSchema
    )
end

addon.onCaptureStart   = function(captureDir)
    addon.files.capture = backend.csvOpen(
        string.format('%s/%s.csv', captureDir, backend.player_name()),
        addon.csvSchema
    )
    addon.files.puppet_capture = backend.csvOpen(
        string.format('%s/%s_puppetstats.csv', captureDir, backend.player_name()),
        addon.puppetCsvSchema
    )
end

addon.onCaptureStop    = function()
    addon.files.capture = nil
    addon.files.puppet_capture = nil
end

addon.onIncomingPacket = function(id, data)
    if id == PacketId.GP_SERV_COMMAND_CLISTATUS then
        ---@type GP_SERV_COMMAND_CLISTATUS
        local packet = backend.parsePacket('incoming', data)

        local csvRow =
        {
            timestamp = os.date('%Y-%m-%d %H:%M:%S'),
            hpmax     = packet.statusdata.hpmax,
            mpmax     = packet.statusdata.mpmax,
            mjob_no   = packet.statusdata.mjob_no,
            mjob_lv   = packet.statusdata.mjob_lv,
            sjob_no   = packet.statusdata.sjob_no,
            sjob_lv   = packet.statusdata.sjob_lv,
            STR       = packet.statusdata.bp_base[1],
            DEX       = packet.statusdata.bp_base[2],
            VIT       = packet.statusdata.bp_base[3],
            AGI       = packet.statusdata.bp_base[4],
            INT       = packet.statusdata.bp_base[5],
            MND       = packet.statusdata.bp_base[6],
            CHR       = packet.statusdata.bp_base[7],
        }

        -- local csvLine = string.format('%d,%d,%d,%d,%d,%d,%d,%d,%d',
        --     csvRow.hpmax,
        --     csvRow.mpmax,
        --     csvRow.STR,
        --     csvRow.DEX,
        --     csvRow.VIT,
        --     csvRow.AGI,
        --     csvRow.INT,
        --     csvRow.MND,
        --     csvRow.CHR
        -- )
        -- print(csvLine)

        if addon.files.global then
            addon.files.global:add_entry(csvRow)
            addon.files.global:save()
        end

        if addon.files.capture then
            addon.files.capture:add_entry(csvRow)
            addon.files.capture:save()
        end
    elseif id == 0x044 then
        local function readUInt16(data, offset)
            return struct.unpack('H', data, offset + 1)
        end

        local maxhp = readUInt16(data, 0x6A)

        if maxhp == 0 then
            return
        end

        local maxmp = readUInt16(data, 0x6E)
        local maxmelee = readUInt16(data, 0x72)
        local maxranged = readUInt16(data, 0x76)
        local maxmagic = readUInt16(data, 0x7A)
        local str = readUInt16(data, 0x80)
        local dex = readUInt16(data, 0x84)
        local vit = readUInt16(data, 0x88)
        local agi = readUInt16(data, 0x8C)
        local int = readUInt16(data, 0x90)
        local mnd = readUInt16(data, 0x94)
        local chr = readUInt16(data, 0x98)

        local csvRow =
        {
            timestamp = os.date('%Y-%m-%d %H:%M:%S'),
            maxhp = maxhp,
            maxmp = maxmp,
            maxmelee = maxmelee,
            maxranged = maxranged,
            maxmagic = maxmagic,
            str = str,
            dex = dex,
            vit = vit,
            agi = agi,
            int = int,
            mnd = mnd,
            chr = chr,
        }

        local csvLine = string.format('%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d',
            csvRow.maxhp,
            csvRow.maxmp,
            csvRow.maxmelee,
            csvRow.maxranged,
            csvRow.maxmagic,
            csvRow.str,
            csvRow.dex,
            csvRow.vit,
            csvRow.agi,
            csvRow.int,
            csvRow.mnd,
            csvRow.chr
        )

        if addon.files.puppet_global then
            addon.files.puppet_global:add_entry(csvRow)
            addon.files.puppet_global:save()
        end

        if addon.files.puppet_capture then
            addon.files.puppet_capture:add_entry(csvRow)
            addon.files.puppet_capture:save()
        end
    end
end

return addon
