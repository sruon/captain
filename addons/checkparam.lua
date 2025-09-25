local socket = require('socket')

-- Spams /checkparam <me>
---@class CheckParamAddon : AddonInterface
---@field csvFile CSV?
---@field currentEntry table
local addon  =
{
    name            = 'CheckParam',
    filters         =
    {
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_BATTLE_MESSAGE] = true,
        },
    },
    settings        = {},
    defaultSettings =
    {
        enabled = false,
        delay   = 1.000,
    },
    csvFile         = nil,
    currentEntry    =
    {
        recvTime = 0,
        acc      = 0,
        atk      = 0,
        offacc   = 0,
        offatk   = 0,
        rangeacc = 0,
        rangeatk = 0,
        eva      = 0,
        def      = 0,
    },
}


local function checkParam()
    backend.schedule(function()
        local ActIndex = backend.get_player_entity_data().targIndex
        local UniqueNo = backend.get_player_entity_data().serverId

        backend.injectPacket(PacketId.GP_CLI_COMMAND_EQUIP_INSPECT,
            {
                PacketId.GP_CLI_COMMAND_EQUIP_INSPECT,    -- id
                0x00,                                     -- size
                0x00,                                     -- sync
                0x00,                                     -- sync
                bit.band(UniqueNo, 0xFF),                 -- UniqueNo
                bit.band(bit.rshift(UniqueNo, 8), 0xFF),  -- UniqueNo
                bit.band(bit.rshift(UniqueNo, 16), 0xFF), -- UniqueNo
                bit.band(bit.rshift(UniqueNo, 24), 0xFF), -- UniqueNo
                bit.band(ActIndex, 0xFF),                 -- ActIndex
                bit.band(bit.rshift(ActIndex, 8), 0xFF),  -- ActIndex
                0x00,                                     -- ActIndex byte 2
                0x00,                                     -- ActIndex byte 3
                0x02,                                     -- Kind (/checkparam)
                0x00,                                     -- padding00
                0x00,                                     -- padding00
                0x00,                                     -- padding00
            })

        -- If we're still capturing and the addon is still enabled, schedule the next packet
        if captain.isCapturing and addon.settings.enabled then
            checkParam()
        end
    end, addon.settings.delay)
end

addon.onIncomingPacket = function(id, data, size)
    ---@type GP_SERV_COMMAND_BATTLE_MESSAGE
    local packet = backend.parsePacket('incoming', data)

    if not addon.settings.enabled or not captain.isCapturing then
        return false
    end

    -- Updates come over several messages, build the full dataset before saving
    -- Consider first packet time as the time for the full dataset
    if id == PacketId.GP_SERV_COMMAND_BATTLE_MESSAGE then -- Accuracy message
        -- We only care about message IDs:
        -- 712: Acc/Atk mainhand
        -- 713: Acc/Atk offhand
        -- 714: Acc/Atk ranged
        -- 715: Eva/Def
        -- 731 and 733 (NAME/ILVL) should be ignored
        if packet then                       -- We are going to tell Ashita to block the packet so it's not spamming the logs
            if packet.MessageNum == 733 then -- Name is the first packet
                addon.currentEntry.recvTime = socket.gettime()
                return true
            elseif packet.MessageNum == 731 then
                return true
            elseif packet.MessageNum == 712 then
                addon.currentEntry.acc = packet.Data
                addon.currentEntry.atk = packet.Data2
                return true
            elseif packet.MessageNum == 713 then
                addon.currentEntry.offacc = packet.Data
                addon.currentEntry.offatk = packet.Data2
                return true
            elseif packet.MessageNum == 714 then
                addon.currentEntry.rangeacc = packet.Data
                addon.currentEntry.rangeatk = packet.Data2
                return true
            elseif packet.MessageNum == 715 then
                addon.currentEntry.eva = packet.Data
                addon.currentEntry.def = packet.Data2
                addon.csvFile:add_entry(addon.currentEntry)
                addon.csvFile:save()
                return true
            end
        end

        -- Don't block any other message
        return false
    end
end

addon.onCaptureStart   = function(captureDir)
    addon.captureDir = captureDir
    if addon.settings.enabled then
        addon.csvFile = backend.csvOpen(string.format('%s/%s.csv', captureDir, backend.player_name()),
            {
                'recvTime',
                'acc',
                'atk',
                'offacc',
                'offatk',
                'rangeacc',
                'rangeatk',
                'eva',
                'def',
            })

        -- Schedule first iteration
        checkParam()
    end
end

addon.onCaptureStop    = function()
    addon.captureDir = nil
    if addon.csvFile then
        addon.csvFile:close()
        addon.csvFile = nil
    end
end

addon.onUnload         = function()
    if addon.csvFile then
        addon.csvFile:close()
    end
end

addon.onConfigMenu     = function()
    return
    {
        {
            key         = 'enabled',
            title       = 'Enable auto /checkparam <me>',
            description = 'If enabled, will send checkparam packets at the defined interval.',
            type        = 'checkbox',
            default     = addon.defaultSettings.enabled,
        },
        {
            key         = 'delay',
            title       = 'Interval',
            description = 'How often to send packets, in seconds. Use less than 1s at your own risk.',
            type        = 'slider',
            min         = 0.05,
            max         = 30,
            step        = 0.01,
            default     = addon.defaultSettings.delay,
        },
    }
end

return addon
