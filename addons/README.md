## Extending captain

Each addon is a self-contained module that gets called by `captain` depending on the implemented methods.

Addons are automatically collected if present in this directory and using the right naming scheme.

The only requirement is that the addon returns **a table**, with a `name` field.

## Creating an addon

### Minimal example

```lua
-- my_addon.lua
local addon =
{
    name = 'my_addon'
}

return addon
```

### File layout

```lua
addons/my_addon.lua            -- This will be collected
addons/my_addon/my_addon.lua   -- This will be collected
addons/my_addon/otherstuff.lua -- This will not be collected but can be require'd in your addon
```

### Requiring other files

Paths are relative to captain root directory.

```lua
-- addons/my_addon/my_addon.lua
local addon_values = require('addons.my_addon.otherstuff')
```

## Opt-in to events

If you want to receive events from `captain`, you may opt in to selected events.

Packets aside, simply implementing the function will enable the events.

```lua
-- my_addon.lua
local addon =
{
    name = 'my_addon'
}

-- Opt-in to initialization, chat messages, and rendering events
addon.onInitialize = function(rootDir)
end

addon.onIncomingText = function(mode, text)
end

addon.onPrerender = function()
end

return addon
```

The full list of events is defined in [example/interface.lua](example/interface.lua)

### About packets

Packets require defining exactly which packets you wish to receive in `addon.filters`.
A global `PacketId` table is available to define the packet IDs.

A special value of `PacketId.MAGIC_ALL_PACKETS` indicates the addon receives all packet types.

```lua
-- my_addon.lua
local addon =
{
    name = 'my_addon',
    filters =
    {
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_CHAR_NPC] = true, -- Receive inbound NPC updates
        },

        outgoing =
        {
            [PacketId.MAGIC_ALL_PACKETS]        = true, -- Receive ALL outgoing packets
        },
    }
}

addon.onIncomingPacket = function(id, data)
end

addon.onOutgoingPacket = function(id, data)
end

return addon
```

## Interacting with captain and FFXI

A global `backend` object is available to all addons. This object contains various methods for interacting with the
client.

### Querying information about entities

```lua
-- my_addon.lua
local addon =
{
    name = 'my_addon',
}

addon.onInitialize = function(rootDir)
    -- Full list of methods is defined in backend/backend_interface.lua
    local playerName = backend.player_name()
    local zoneName   = backend.zone_name()
    local mob        = backend.get_mob_by_index(200)
end
```

### Creating files

```lua
-- my_addon.lua
local addon =
{
    name = 'my_addon',
    file = nil,
}

addon.onIncomingPacket = function(id, data)
    if addon.file then
        addon.file:append('received packet: ' .. id .. '\n')
    end
end

addon.onCaptureStart = function(captureDir)
    addon.file = backend.fileCreate(string.format('%s/logs/my_addon.txt', captureDir))
end
```

#### A note about file paths

`onInitialization(rootDir: string)` is first called, if implemented, when the addon is first loaded.
`rootDir` corresponds to a folder scoped to the addon. Example: `'captures/my_addon'`

`onCaptureStart(captureDir: string)` is called whenever a capture starts, if implemented.
`captureDir` corresponds to a folder scoped to the capture. Example:
`'captures/2023-10-01_12-00-00/<character_name>/my_addon'`

### Settings

You may define a set of default settings. `captain` will automatically merge them with local user settings for your
addon and inject it in `addon.settings`

Settings are saved and loaded from the following location:

- `<ashita_root>/config/addons/captain/<char_name>/<addon_name>.lua`

```lua
-- my_addon.lua
local addon =
{
    name = 'my_addon',
    settings = {},
    defaultSettings =
    {
        magicNumber = 10,
    }
}

addon.onIncomingPacket = function(id, data)
    print('Magic number: ' .. addon.settings.magicNumber)
    addon.settings.magicNumber = addon.settings.magicNumber + 1
    backend.saveConfig(addon.name)
end

return addon
```

### Parsing packets

A library is included to parse packets into tables matching structures defined
in [XiPackets](https://github.com/atom0s/XiPackets/) documentation.

Not all packet types are supported at this time.

```lua
-- my_addon.lua
local addon =
{
    name = 'my_addon',
    filters =
    {
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_TRACKING_LIST] = true, -- Receive widescan updates
        },
    }
}

addon.onIncomingPacket = function(id, data)
    if id == PacketId.GP_SERV_COMMAND_TRACKING_LIST then
        local packet = backend.parsePacket('incoming', data)
        if packet then
            print(packet.Level)
            -- utils.dump(packet) will print the entire table to the chatlog
        end
    end
end

return addon
```

### Displaying floating text boxes

The text boxes can be dragged around the screen.

```lua
local addon =
{
    name            = 'PlayerInfo',
    playerInfo      = nil,
}

addon.onPrerender = function()
    addon.playerInfo:updateTitle(playerData.name)
    addon.playerInfo:updateText(backend.zone_name())
end

addon.onInitialize = function(_)
    addon.playerInfo = backend.textBox('PlayerInfo')
end

return addon
```

### Creating notifications

This is an example template for creating notifications:

```lua
addon.template =
{
    { color = addon.color.notification.NAME,      text = "${name|%s}" },
    { newline = true },
    { color = addon.color.notification.SYSTEM,    text = "Actor: " },
    { color = addon.color.notification.ACTOR,     text = "${actor|%s}",     padLeft = 11 },
    { newline = true },
    { color = addon.color.notification.SYSTEM,    text = "C: " },
    { color = addon.color.notification.CATEGORY,  text = "${category|%s}",  padLeft = 5 },
    { color = addon.color.notification.SYSTEM,    text = " ID: " },
    { color = addon.color.notification.ID,        text = "${id|%s}",        padLeft = 5 },
    { color = addon.color.notification.SYSTEM,    text = " Anim: " },
    { color = addon.color.notification.ANIMATION, text = "${animation|%s}", padLeft = 4 },
    { color = addon.color.notification.SYSTEM,    text = " Msg: " },
    { color = addon.color.notification.MESSAGE,   text = "${message|%s}",   padLeft = 3 },
}
```

Then, when you have data to display:

```lua
local data = { name = "Name", actor = 5, category = 10, id = 15, animation = 20, message = 25 }
-- Freeze: If true, will prevent the notification from being closed until another notification unfreezes it
backend.notificationCreate(addon.template, data, false)
```

### Storing structured data

This is a slightly different spin on how the Windower addon stored captured data in "databases".

The key difference being that it is addon-agnostic and tracks changes for a given key. This is powered by SQLite.

```lua
-- my_addon.lua
local addon =
{
    name = 'my_addon',
    database = nil,
}

addon.onZoneChange = function(zoneId)
    if addon.database then
        addon.database:add_or_update(zoneId, { time = os.time(), player_name = backend.player_name() })
    end

    -- You can also retrieve existing items by "primary key"
    local entry = addon.database:get(zoneId)
    -- entry will be either a copy of the entry or nil if not found

    -- Or by field value
    -- Note: will return first found
    local entry, entryId = addon.database:find_by('player_name', backend.player_name())
    -- entryId is the primary key of the entry
    -- entry will be either a copy of the entry or nil if not found
end

addon.onInitialize = function(rootDir)
    -- A schema must always be passed so the appropriate columns can be created
    -- File name must end in .db
    addon.databases = backend.databaseOpen(string.format('%s/zone_changes.db', rootDir),
        {
            schema      = { time = 1, player_name = 'Test' },
        })
    -- Certain parameters can be passed to change the default behavior
    addon.database = backend.databaseOpen(string.format('%s/zone_changes.db', rootDir),
    {
        schema         = { time = 1, player_name = 'Test' },
        ignore_updates = { 'time' },  -- Fields to ignore when checking for changes
        max_history    = 10,          -- Maximum number of history entries to keep for each row
    })
end

return addon
```

### Logging data points
```lua
-- File name, followed by a table of columns
addon.csvFiles[packet.UniqueNo] = backend.csvOpen(
                string.format('%s/%s/%s/%s/%s.csv',
                    baseDir,
                    backend.player_name(),
                    backend.zone_name(),
                    mob.name,
                    packet.UniqueNo),
                { 'leg', 'x', 'y', 'z', 'dir', 'delta' })

csvFile:add_entry(
            {
                leg = 1, x = x, y = y, z = z, dir = dir, delta = 0,
            })
csvFile:save()
```

### A note about coroutines

An arbitrary amount of coroutines can be created.

The only restriction is that they cannot be created in the `onInitialize` method.
Doing so will cause `captain` to never complete loading.

The preferred pattern is to check if coroutines have been started in the `onPrerender` event.

```lua
-- my_addon.lua
local addon =
{
    name = 'my_addon',
    coroutinesSetup = false,
}

addon.onPrerender = function()
    if not addon.coroutinesSetup then
        backend.forever(function()
            backend.doWidescan()
        end, 10)

        addon.coroutinesSetup = true
    end
end

return addon
```

### Complete list

The full list of backend methods is defined in [backend/backend_interface.lua](../backend/backend_interface.lua)
