-- Simple example explaining the various events and showcasing how to capture widescan update packets and store in a log file
-- A handful of globals are available:
-- - backend: interact with FFXI launcher/client
-- - colors: list of color codes for chatlog and UI display
-- - packetId: list of packet IDs
-- - captain: global captain object
-- - utils: certain utility functions

---@class ExampleSimpleAddon : AddonInterface
local addon =
{
    -- Name of your addon (required)
    name            = 'ExampleSimple',

    -- Packet filters (optional)
    filters         =
    {
        incoming =
        {
            -- 0x0F4 is the widescan update packet
            [packetId.GP_SERV_COMMAND_TRACKING_LIST] = true, -- 0x0F4 is the widescan update packet
        },
    },

    -- Empty settings. captain will automatically inject a merge of defaultSettings and user specific settings
    settings        = {},
    defaultSettings =
    {
        widescanDelay = 10,
    },

    -- We're going to be opening a single logfile to store updates
    logFile         = nil,
}

-- All events are opt-in, so if you don't need them, don't implement them

-- captain notifies addons of zone changes.
-- This can be used to open a new log file for each zone
addon.onZoneChange = function(zoneId)
end

-- captain notifies addons they're being initialized.
-- rootDir will be a non-capture specific folder scoped to your addon
-- example: <captain_root>/captures/examplesimple/
addon.onInitialize = function(rootDir)
    -- Store rootDir if needed, or initialize log files directly...
    addon.logFile = backend.fileOpen(rootDir .. 'widescan.log')
end

-- captain notifies addons they're being unloaded
addon.onUnload = function()
end

-- captain notifiers addons of render events.
-- If you have any UI to update, this is where you would do it
addon.onPrerender = function()
end

-- captain notifies addons of capture start/stop events.
-- captureDir will be a folder scoped to your addon AND to the current capture
-- example: <captain_root>/captures/2025-4-29_23_54/<char_name>/examplesimple/
addon.onCaptureStart = function(captureDir)
end

-- This is where you would close any log files or clean up resources
addon.onCaptureStop = function()
end

-- captain notifies addons of incoming packets but only if you opted in to the specific ID (addon.filters)
-- This is where the bulk of your logic will go if dealing with packets
addon.onIncomingPacket = function(id, data)
    if id == PacketId.GP_SERV_COMMAND_TRACKING_LIST then
        -- This is the widescan update packet, we can parse it and store the data
        local packet = backend.parsePacket('incoming', data)
        if packet then
            -- The parser returned a table with all fields parsed
            -- Each packet type will look different, see libs/packets/definitions.lua
            -- The widescan packet contains: ActIndex, Level, Type among other things
            backend.fileAppend(addon.logFile,
                string.format('Widescan update: %d, %d, %d\n', packet.ActIndex, packet.Level, packet.Type))

            -- Optionally you can show a notification
            -- The first argument is a template for your notification
            -- The second argument is the data to fill in the template
            -- The third argument is whether or not the box will persist until the next notification

            local boxTemplate =
            {
                { text = 'Widescan update' },
                { newline = true },
                { text = 'ActIndex: ${ActIndex|%d}' },
                { text = 'Level: ${Level|%d}' }, -- No newline means this will on the same level as ActIndex
                { newline = true },
                { text = 'Type: ${Type|%d}' },
            }
            backend.boxCreate(boxTemplate, data, false)
        end
    end
end

-- captain notifies addons of outgoing packets but only if you opted in to the specific ID (addon.filters)
addon.onOutgoingPacket = function(id, data)
end

-- captain notifies addons of incoming text events
-- The text is already cleaned of colors and auto-translate tags
addon.onIncomingText = function(mode, text)
end

-- captain notifies addons of user commands
-- example: /cap examplesimple hello
-- args start after the addon name, so in this case args = { 'hello' }
addon.onCommand = function(args)
end

-- If you support commands, you should publish them here. They will show in /cap help
addon.onHelp = function()
    return
    {
        cmd = 'hello',
        desc = 'Hello world!',

        -- An optional keybind can be specified, here we bind it to Ctrl+X
        keybind = { key = 'x', down = true, ctrl = true },
    }
end

-- Make sure to return the addon
return addon
