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
local addon_values = require('addons/my_addon/otherstuff')
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
client. This object is intended to be launcher-agnostic and work across both Ashita and Windower.

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
    local zoneName = backend.zone_name()
    local mob = backend.get_mob_by_index(200)
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

Settings are saved and loaded from the following locations:

- Windower: `<captain_root>/data/<addon>.xml`
- Ashita: `<ashita_root>/config/addons/captain/<char_name>/<addon_name>.lua`

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

### Storing data in a structured way

This is a slightly different spin on how the Windower addon stored captured data in "databases".

The key difference being that it is addon-agnostic and tracks changes for a given key.

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

    -- You can save the database once done
    -- Note: This will overwrite the existing file
    local madeChanges = addon.database:save()
    -- madeChanges will be true if any write was necessary
end

addon.onInitialize = function(rootDir)
    addon.database = backend.databaseOpen(string.format('%s/databases/zone_changes.lua', rootDir))
    -- Certain parameters can be passed to change the default behavior
    addon.database = backend.databaseOpen(string.format('%s/databases/zone_changes.lua', rootDir), {
        ignore_updates = { 'time' },  -- Fields to ignore when checking for changes
        max_history = 10,             -- Maximum number of history entries to keep for each row
        sort_keys = { 'player_name' } -- Changes the order of fields when saving to file
    })
end

return addon
```

Example output

```lua
return {
  [16982134] = {version = 2, data = {UniqueNo = 16982134, polutils_name = "Kubhe Ijyuhla", type = "Equipped NPC", ActIndex = 118, Flags0 = {GroundFlag = 0, KingFlag = 0, MovTime = 1, RunMode = 0, facetarget = 0, unknown_1_6 = 0}, Flags1 = {AnonymousFlag = 1, AwayFlag = 0, BazaarFlag = 0, ChocoboIndex = 0, CliPosInitFlag = 1, Gender = 0, GmLevel = 0, GraphSize = 1, HackMove = 0, HideFlag = 0, InvisFlag = 0, LfgFlag = 1, LinkDeadFlag = 0, LinkShellFlag = 0, MonsterFlag = 0, PlayOnelineFlag = 0, SleepFlag = 0, TalkUcoffFlag = 0, TargetOffFlag = 0, TurnFlag = 0, YellFlag = 0, unknown_0_3 = 0, unknown_0_4 = 0, unknown_2_5 = 0, unknown_2_6 = 0, unknown_2_7 = 0, unknown_3_4 = 0}, Flags2 = {AutoPartyFlag = 0, CharmFlag = 0, GmIconFlag = 0, NamedFlag = 1, PvPFlag = 0, ShadowFlag = 0, ShipStartMode = 0, SingleFlag = 0, b = 0, g = 0, r = 0}, Flags3 = {BallistaTeam = 0, CliPriorityFlag = 0, LfgMasterFlag = 0, MentorFlag = 0, MonStat = 5, MotStopFlag = 0, NewCharacterFlag = 0, OcclusionoffFlag = 0, PetFlag = 0, PetNewFlag = 0, SilenceFlag = 0, TrustFlag = 0, unknown_0_3 = 0, unknown_2_3 = 0, unknown_2_4 = 0, unknown_2_6 = 0, unknown_3_1 = 0, unknown_3_2 = 0, unknown_3_3 = 0, unknown_3_4 = 0, unknown_3_5 = 0, unknown_3_6 = 0, unknown_3_7 = 0}, GrapIdTbl = {1803, 4096, 8199, 12295, 16391, 20487, 24576, 28672, 0}, Hpp = 100, Speed = 40, SpeedBase = 40, SubKind = 1, dir = 141, legacy = {animation = 0, animationsub = 1, flag = 1, flags = 27, look = "0001070B10002007300740075007600070000000", name_prefix = 32, namevis = 0, speed = 40, speedsub = 40, status = 0}, server_status = 0, ws = {Level = 0, Type = 1, sName = ""}, x = 23.256999969482422, y = 21.531999588012695, z = 0}, history = {{changes={ActIndex={to=118},Flags0={to={GroundFlag=0,KingFlag=0,MovTime=1,RunMode=0,facetarget=0,unknown_1_6=0}},Flags1={to={AnonymousFlag=1,AwayFlag=0,BazaarFlag=0,ChocoboIndex=0,CliPosInitFlag=1,Gender=0,GmLevel=0,GraphSize=1,HackMove=0,HideFlag=0,InvisFlag=0,LfgFlag=1,LinkDeadFlag=0,LinkShellFlag=0,MonsterFlag=0,PlayOnelineFlag=0,SleepFlag=0,TalkUcoffFlag=0,TargetOffFlag=0,TurnFlag=0,YellFlag=0,unknown_0_3=0,unknown_0_4=0,unknown_2_5=0,unknown_2_6=0,unknown_2_7=0,unknown_3_4=0}},Flags2={to={AutoPartyFlag=0,CharmFlag=0,GmIconFlag=0,NamedFlag=1,PvPFlag=0,ShadowFlag=0,ShipStartMode=0,SingleFlag=0,b=0,g=0,r=0}},Flags3={to={BallistaTeam=0,CliPriorityFlag=0,LfgMasterFlag=0,MentorFlag=0,MonStat=5,MotStopFlag=0,NewCharacterFlag=0,OcclusionoffFlag=0,PetFlag=0,PetNewFlag=0,SilenceFlag=0,TrustFlag=0,unknown_0_3=0,unknown_2_3=0,unknown_2_4=0,unknown_2_6=0,unknown_3_1=0,unknown_3_2=0,unknown_3_3=0,unknown_3_4=0,unknown_3_5=0,unknown_3_6=0,unknown_3_7=0}},GrapIdTbl={to={1803,4096,8199,12295,16391,20487,24576,28672,0}},Speed={to=40},SpeedBase={to=40},SubKind={to=1},UniqueNo={to=16982134},legacy={to={animation=0,animationsub=1,flag=1,flags=27,look="0001070B10002007300740075007600070000000",name_prefix=32,namevis=0,speed=40,speedsub=40,status=0}},polutils_name={to="Kubhe Ijyuhla"},server_status={to=0},type={to="Equipped NPC"}},time=1745990457},{changes={ws={to={Level=0,Type=1,sName=""}}},time=1745990476}}},
  [16982135] = {version = 2, data = {UniqueNo = 16982135, polutils_name = "Tohka Telposkha", type = "Equipped NPC", ActIndex = 119, Flags0 = {GroundFlag = 0, KingFlag = 0, MovTime = 21, RunMode = 0, facetarget = 0, unknown_1_6 = 0}, Flags1 = {AnonymousFlag = 1, AwayFlag = 0, BazaarFlag = 0, ChocoboIndex = 0, CliPosInitFlag = 1, Gender = 0, GmLevel = 0, GraphSize = 1, HackMove = 0, HideFlag = 0, InvisFlag = 0, LfgFlag = 1, LinkDeadFlag = 0, LinkShellFlag = 0, MonsterFlag = 0, PlayOnelineFlag = 0, SleepFlag = 0, TalkUcoffFlag = 0, TargetOffFlag = 0, TurnFlag = 0, YellFlag = 0, unknown_0_3 = 0, unknown_0_4 = 0, unknown_2_5 = 0, unknown_2_6 = 0, unknown_2_7 = 0, unknown_3_4 = 0}, Flags2 = {AutoPartyFlag = 0, CharmFlag = 0, GmIconFlag = 0, NamedFlag = 1, PvPFlag = 0, ShadowFlag = 0, ShipStartMode = 0, SingleFlag = 0, b = 0, g = 0, r = 0}, Flags3 = {BallistaTeam = 0, CliPriorityFlag = 0, LfgMasterFlag = 0, MentorFlag = 0, MonStat = 5, MotStopFlag = 0, NewCharacterFlag = 0, OcclusionoffFlag = 0, PetFlag = 0, PetNewFlag = 0, SilenceFlag = 0, TrustFlag = 0, unknown_0_3 = 0, unknown_2_3 = 0, unknown_2_4 = 0, unknown_2_6 = 0, unknown_3_1 = 0, unknown_3_2 = 0, unknown_3_3 = 0, unknown_3_4 = 0, unknown_3_5 = 0, unknown_3_6 = 0, unknown_3_7 = 0}, GrapIdTbl = {1796, 4096, 8196, 12292, 16388, 20484, 24576, 28672, 0}, Hpp = 100, Speed = 40, SpeedBase = 40, SubKind = 1, dir = 32, legacy = {animation = 0, animationsub = 1, flag = 21, flags = 27, look = "0001070410002004300440045004600070000000", name_prefix = 32, namevis = 0, speed = 40, speedsub = 40, status = 0}, server_status = 0, ws = {Level = 0, Type = 1, sName = ""}, x = 22.104999542236328, y = 22.759000778198242, z = 0}, history = {{changes={ActIndex={to=119},Flags0={to={GroundFlag=0,KingFlag=0,MovTime=21,RunMode=0,facetarget=0,unknown_1_6=0}},Flags1={to={AnonymousFlag=1,AwayFlag=0,BazaarFlag=0,ChocoboIndex=0,CliPosInitFlag=1,Gender=0,GmLevel=0,GraphSize=1,HackMove=0,HideFlag=0,InvisFlag=0,LfgFlag=1,LinkDeadFlag=0,LinkShellFlag=0,MonsterFlag=0,PlayOnelineFlag=0,SleepFlag=0,TalkUcoffFlag=0,TargetOffFlag=0,TurnFlag=0,YellFlag=0,unknown_0_3=0,unknown_0_4=0,unknown_2_5=0,unknown_2_6=0,unknown_2_7=0,unknown_3_4=0}},Flags2={to={AutoPartyFlag=0,CharmFlag=0,GmIconFlag=0,NamedFlag=1,PvPFlag=0,ShadowFlag=0,ShipStartMode=0,SingleFlag=0,b=0,g=0,r=0}},Flags3={to={BallistaTeam=0,CliPriorityFlag=0,LfgMasterFlag=0,MentorFlag=0,MonStat=5,MotStopFlag=0,NewCharacterFlag=0,OcclusionoffFlag=0,PetFlag=0,PetNewFlag=0,SilenceFlag=0,TrustFlag=0,unknown_0_3=0,unknown_2_3=0,unknown_2_4=0,unknown_2_6=0,unknown_3_1=0,unknown_3_2=0,unknown_3_3=0,unknown_3_4=0,unknown_3_5=0,unknown_3_6=0,unknown_3_7=0}},GrapIdTbl={to={1796,4096,8196,12292,16388,20484,24576,28672,0}},Speed={to=40},SpeedBase={to=40},SubKind={to=1},UniqueNo={to=16982135},legacy={to={animation=0,animationsub=1,flag=21,flags=27,look="0001070410002004300440045004600070000000",name_prefix=32,namevis=0,speed=40,speedsub=40,status=0}},polutils_name={to="Tohka Telposkha"},server_status={to=0},type={to="Equipped NPC"}},time=1745990457},{changes={ws={to={Level=0,Type=1,sName=""}}},time=1745990476}}},
}
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
