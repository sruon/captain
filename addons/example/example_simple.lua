-- Simple example explaining the various events and showcasing how to capture widescan update packets and store in a log file
-- A handful of globals are available:
-- - backend: interact with FFXI launcher/client
-- - colors: list of color codes for chatlog and UI display
-- - PacketId: list of packet IDs
-- - captain: global captain object
-- - utils: certain utility functions

---@class ExampleSimpleAddon : AddonInterface
---@field logFile File?
local addon =
{
    -- Name of your addon (required)
    name            = 'ExampleSimple',

    -- Packet filters (optional)
    filters         =
    {
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_TRACKING_LIST] = true, -- 0x0F4 is the widescan update packet
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
-- Note: The client MAY NOT be ready at this time and will not render certain information. Prefer onClientReady.
addon.onZoneChange = function(zoneId)
end

-- captain notifies addons of zone changes AND client ready.
-- This can be used to open a new log file for each zone
addon.onClientReady = function(zoneId)
end

-- captain notifies addons they're being initialized.
-- rootDir will be a non-capture specific folder scoped to your addon
-- example: <captain_root>/captures/examplesimple/
-- DO NOT INITIALIZE COROUTINES IN THIS METHOD
addon.onInitialize = function(rootDir)
    -- Store rootDir if needed, or initialize log files directly...
    addon.logFile = backend.fileOpen(rootDir .. 'widescan.log')
end

-- captain notifies addons they're being unloaded
-- Clean up resources, if any, especially if they're locked.
addon.onUnload = function()
end

-- captain notifies addons of render events.
-- If you have any UI to update, this is where you would do it
-- You may also initialize any coroutine you need.
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
            addon.logFile:append(string.format('Widescan update: %d, %d, %d\n', packet.ActIndex, packet.Level,
                packet.Type))

            -- Optionally you can show a notification
            -- The first argument is a template for your notification
            -- The second argument is the data to fill in the template
            -- The third argument is whether or not the box will persist until the next notification

            -- TBD Doc update, see EventView for an example
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

        -- An optional keybind can be specified, here we bind it to Ctrl+Y
        keybind = { key = 'y', down = true, ctrl = true },
    }
end

-- Optionally return a list of settings keys that should be configurable
-- They will be added to the config menu under the addon name
addon.onConfigMenu = function()
    return
    {
        {
            key = 'widescanDelay',
            title = 'Widescan Delay',
            description = 'Time in seconds between widescan packets',
            type = 'slider',
            min = 1,
            max = 10,
            step = 1,
            default = addon.defaultSettings.widescanDelay,
        },
    }
end

-- Make sure to return the addon
return addon
