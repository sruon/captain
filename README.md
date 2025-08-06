# 👨‍✈️ captain

A suite of packet capture and analysis tools for FFXI targeting Ashita v4.

## A note about account safety
`captain` sends packets when not normally possible, or at a rate greater than the game client is capable of.

This is detectable and may cause your account to be sanctioned, up to a permanent ban.

By using `captain` you acknowledge you are aware of the risks.

Certain actions are known to be relatively safe and are enabled by default (such as Auto Wide Scan), others are explicitly opt-in.

## A note about privacy
Captures contain the full dump of packets emitted and received by your client. This includes chat messages and other information you may wish to keep private.

Captain captures the remote server IP to allow verifying if a capture was obtained from the official FFXI game servers.

Understand that making captures available to the public may leak such information.

## Goal

While the original `captain` attempted to bridge the gap between Windower and Ashita, it is not a stated goal of this fork as maintaining, creating addons and testing while accounting for the quirks of several launchers is not feasible at this time.

The key objective is to provide a high-quality suite of tools for analyzing FFXI entities, events, packets and other with the primary target being `LandSandBoat` development.

## Project philosophy

### Event-driven
`captain` works off an event-driven model, where `captain` takes care of setting up the appropriate hooks with Ashita and vends events to each addon implementing the related methods.

### Batteries included
`captain` provides capabilities for common tasks such as storing data or performing statistical analysis, reducing the need to implement it for each addon.

Several known well-maintained dependencies are included or implicitly relied on.

When evaluating options for new dependencies, keep this list order in mind:

- Ashita included libraries
- Lua-only libraries
- DLLs with FFI wrappers

Compiled Lua libraries are unfortunately very hard to integrate given everything needs to target Windows 32 bits.

### Fat framework, thin addons
Addons are intended to be lightweight to maximize maintainability, aiming for 300-400 LOCs at most.

Several capture scenario will require their own addons as one-offs and that's fine. We would rather deal with 50 small addons than 3 unmaintainable God-Addons.

### XiPackets as the source of truth
Every packet definition and data storage nomenclature is aligned on `XiPackets`.

This is the only accepted source of truth for packets related informations.

### LandSandBoat is the primary target
`captain` development is made with LandSandBoat in mind. The framework can be used for other types of data collection and analysis but it will never be a primary objective.

## Differences with the existing Windower suite
`captain` was heavily inspired by the existing Windower suite, however it differs in the following ways:
- Commonly re-used patterns (notifications, databases...) are part of the framework instead of being tightly coupled to the addons
- Nomenclatures were reworked to align with XiPackets as much as possible
- Optional features not deemed essential have been dropped
- Several addons known to be incorrect were fixed.
- Data collection has been aligned on SQLite for structured data and CSV for data points.

## Features
### Core
#### Player information
Green checkmark indicates this is a legitimate retail server. Notifies if currently capturing as well.
<img width="1072" height="88" alt="image" src="https://github.com/user-attachments/assets/fc655419-a0d2-48d4-bfc0-0499da7e880d" />

#### Target information
<img width="696" height="91" alt="image" src="https://github.com/user-attachments/assets/ee31b665-0a1e-4dd4-98b8-2d719f5aca9d" />

#### Event notifications
Also displayed in the chatlog
<img width="1048" height="107" alt="image" src="https://github.com/user-attachments/assets/f5c1fd7a-94f9-4b93-a3a3-4eb003004116" />

### Addons
#### PacketLogger
- Captures all received/emitted packets, by ID and by stream direction.
- Format is compatible with PVLP/VieweD.

#### PacketBridge
Re-emits all received/emitted packets to any UDP port.

#### CapLog
- Captures the content of the chatlog.
- Strings are stripped of auto-translate tags and colors.

#### Widescan
Emits recurring Widescan packets, to be consumed by other addons.

```
[19:35:04][AutoWidescan] Received updates for 36 entities.
```

#### NPCLogger
Captures NPC entities packet informations.

```
[19:35:11][NPCLogger] Database updated. 12 NPCs (0 new, 59 updates, 16 WS updates)
```

#### EventView
- Notifies and captures all event informations, including the event number and all parameters.
- This has been extended to include more packet types (music, release, animations etc.)

```
[19:35:34][EView] << [0x034] CEventPacket* (GP_SERV_COMMAND_EVENTNUM)
UniqueNo: 16883801 (Home Point #1), EventPara: 8700, EventNum: 26, EventPara2: 0, EventNum2: 26, Mode: 8, num: {0, -1, -1, -1, 67108863, 20950, 4095, 131136}
[19:35:35][EView] >> [0x05B] GP_CLI_COMMAND_EVENTEND (GP_CLI_COMMAND_EVENTEND)
UniqueNo: 16883801 (Home Point #1), EndPara: 8, Mode: 1, EventNum: 26, EventPara: 8700
[19:35:35][EView] << [0x05C] CEventUpdatePacket (GP_SERV_COMMAND_PENDINGNUM)
num: {-1, -1, 255, 0, 67108863, 20950, 4095, 131136}
[19:35:36][EView] << [0x052] CReleasePacket (GP_SERV_COMMAND_EVENTUCOFF)
Mode: 1, ModeType: 1
[19:35:36]A home point can be set as a spot for you to return to Vana'diel when you have been knocked out. You can also use a home point to teleport to other home points.
[19:35:36][19:35:36] A home point can be set as a spot for you to return to Vana'diel when you have been knocked out. You can also use a home point to teleport to other home points.
[19:35:36][19:35:36] A home point can be set as a spot for you to return to Vana'diel when you have been knocked out. You can also use a home point to teleport to other home points.
[19:35:36]You may teleport from here to any other home point you have registered.
[19:35:36][19:35:36] You may teleport from here to any other home point you have registered.
[19:35:36][19:35:36] You may teleport from here to any other home point you have registered.
[19:35:40]It costs 100 gil to teleport to Home Point #1 in Southern San d'Oria.
[19:35:40][19:35:40] It costs 100 gil to teleport to Home Point #1 in Southern San d'Oria.
[19:35:40][19:35:40] It costs 100 gil to teleport to Home Point #1 in Southern San d'Oria.
[19:35:41][EView] >> [0x05B] GP_CLI_COMMAND_EVENTEND (GP_CLI_COMMAND_EVENTEND)
UniqueNo: 16883801 (Home Point #1), EndPara: 2, Mode: 1, EventNum: 26, EventPara: 8700
[19:35:42][EView] << [0x05C] CEventUpdatePacket (GP_SERV_COMMAND_PENDINGNUM)
num: {77, 1, 255, 0, 67108863, 20950, 4095, 131136}
[19:35:42][EView] << [0x052] CReleasePacket (GP_SERV_COMMAND_EVENTUCOFF)
Mode: 1, ModeType: 1
[19:35:47][EView] >> [0x05B] GP_CLI_COMMAND_EVENTEND (GP_CLI_COMMAND_EVENTEND)
UniqueNo: 16883801 (Home Point #1), EndPara: 2, Mode: 0, EventNum: 26, EventPara: 8700
```

#### HPTrack
- Notifies and logs deducted HP from defeated enemies.
- This has been corrected to include all sources of damage such as Enspells, Skillchains and Spikes.

```
[01:24:33][HPTrack] Defeated Lesser Colibri: 3203~3613 HP
```

#### KITrack
- Displays and logs obtained/lost key items along with the position.

```
[00:58:45][KITrack] Obtained Key Item
ID: 3212, Name: moglophone, X: -000.104, Y: +116.867, Z: +008.000, Zone: Rabao, Timestamp: 1754377125
```

#### PathLog
- Tracks and captures the path of the player and NPC/mobs.
- Legs are automatically created based on customizable position/time difference.

```csv
leg,x,y,z,dir,delta
1,306.807,-10.02,27.514,215,0
1,307.878,-10.02,29.349,207,2
1,306.974,-10.143,28.922,110,2
2,306.475,-10.083,27.845,14,44
2,309.51,-10.083,26.746,16,46
3,309.51,-10.041,27.216,191,86
4,308.975,-9.994,28.061,169,142
4,307.695,-10.196,29.842,163,143
4,305.082,-10.196,32.871,163,145
5,305.41,-9.985,32.567,34,207
5,308.041,-9.985,29.555,35,208
5,308.923,-10.111,28.891,173,210
5,307.125,-10.111,32.464,173,212
6,305.776,-10.239,33.935,71,255
6,305.092,-10.239,29.994,71,256
6,305.389,-10.506,27.465,38,258
6,307.772,-10.506,24.252,38,259
7,308.839,-10.16,22.612,164,302
7,306.378,-10.16,25.765,165,304
7,307.498,-10.048,26.743,3,306
```

#### AttackDelay
- Summarize the delay between melee action packets from enemies.
- Attempts to reverse calculate the delay from TP gained on being hit.

```
[01:24:33][AttackDelay] Lesser Colibri (24 hits) - Delay: 192-460
[01:24:33][AttackDelay]   Avg: 238 | Med: 219 | StdDev: 58
[01:24:33][AttackDelay]   TP-Delay: 240 (3 samples)
[01:24:33][AttackDelay]   Multi-hits: 1-hit: 100%
```

#### ShopStock
- Captures all items offered for sale by NPCs.
- Can **optionally** automatically appraise all items in your inventory.

```
[01:20:55][ShopStock] Recorded 19 items sold by Teerth
[01:20:55]Teerth : Welcome to the Goldsmiths' Guild shop.
What can I do for you?
[01:20:55][ShopStock] Recorded 19 items sold by Teerth
[01:20:56][ShopStock] Recorded 5 items sold by Teerth
```

```
[01:20:55][ShopStock] Auto-appraising items in inventory
[01:20:55][ShopStock] Appraisal for Prism Powder: 350g
[01:20:55][ShopStock] Appraisal for Meat Jerky: 30g
[01:20:56][ShopStock] Appraisal for Pickaxe: 50g
[01:20:56][ShopStock] Appraisal for Holy Water: 145g
```

#### GuildStock
- Captures all items offered for sale by Guild Shops.
- Captures all items purchased by the Guild Shop.

```
[00:57:52][EView] << [0x036] CMessageTextPacket (GP_SERV_COMMAND_TALKNUM)
UniqueNo: 17739789 (Visala), MesNum: 7714, Type: 2
[00:57:52][EView] << [0x052] CReleasePacket (GP_SERV_COMMAND_EVENTUCOFF)
Mode: 0, ModeType: 0
[00:57:52]Visala : Welcome to the Goldsmiths' Guild shop.
How may I help you?
[00:57:56][GuildStock] Recorded 30 items sold by Visala
[00:57:56][GuildStock] Recorded 30 items sold by Visala
[00:57:57][GuildStock] Recorded 15 items sold by Visala
[00:58:02][GuildStock] Recorded 30 items purchased by Visala
[00:58:02][GuildStock] Recorded 30 items purchased by Visala
[00:58:02][GuildStock] Recorded 30 items purchased by Visala
[00:58:03][GuildStock] Recorded 30 items purchased by Visala
[00:58:03][GuildStock] Recorded 5 items purchased by Visala
```

#### WeatherTrack
- Captures previous and current weather on zoning in.
- Captures any subsequent weather event.

#### OBS
- Automates the start of a recording with OBS through the WebSocket interface.
- Support 
- Recordings can optionally be saved in the capture directory.
- Will automatically attempt to set OBS source to the current window.

<img width="591" height="439" alt="image" src="https://github.com/user-attachments/assets/7852b394-3114-4950-9349-0f130d91c354" />

### Other
- UI configuration
- Packets parser
- SQLite3 structured data storage with diff tracking
- CSV data points logging
- Async HTTP(S) and WebSocket clients
- Statistical functions

## Instructions

- Download the [latest release](https://github.com/sruon/captain/releases) `captain.zip` and place in `<Ashita folder>/addons`
- Either:
  - Add to `scripts/Default.txt` to auto-load when you log in
  - Load on demand with `/addon load captain`
- Unload with `/addon unload captain`

### General

- `/cap` to show the configuration menu
- `/cap start` (`CTRL + ALT + C`) to begin a capture
- `/cap stop` (`CTRL + ALT + V`) to end a capture
- `/cap toggle` (`CTRL + X`) to toggle recording
- `/cap split` to roll over to a new capture
- `/cap reload` (`CTRL + Z`) to reload captain

### TODO
- EventView zone events

### Development: Addons
See [Addons Guide](./addons/README.md)

### Development: captain

- TODO

```bat
C:\ffxi>mklink /D C:\ffxi\Ashita\addons\captain C:\ffxi\captain
symbolic link created for C:\ffxi\Ashita\addons\captain <<===>> C:\ffxi\captain

C:\ffxi>mklink /D C:\ffxi\Windower\addons\captain C:\ffxi\captain
symbolic link created for C:\ffxi\Windower\addons\captain <<===>> C:\ffxi\captain
```

## Compatibility

Event methods ("addon hooks") are expected to be stable.

Dependencies and backend methods **may change without notice** until the project is considered stable.

## Q&A
### Will this ever be available for Windower
The code was built in a way to make this possible but I cannot realistically commit to supporting two launchers.

If you're interested about maintaining compatibility with Windower, please reach out.

### Will this get me banned

With the features provided out of the box, _probably not_ but consider it as a very real possibility.

Use a trial/burner account if you're concerned (Retail) or seek permission from the server owner (PServer).

## Based on & made possible by

- [Windower](https://www.windower.net/)
- [Ashita](https://ashitaxi.com/)
- `Packeteer` by atom0s
- [XiPackets](https://github.com/atom0s/XiPackets) by atom0s
- `capture` by ibm2431
- `PacketViewer` by Arcon
- [pathlog](https://github.com/Dukilles/pathlog) by Duke
- [weatherwatch](https://github.com/cocosolos/WeatherWatch) by cocosolos
- [VieweD](https://github.com/ZeromusXYZ/VieweD) by ZeromusXYZ
- The FFXI Captures community
- [LandSandBoat](https://github.com/LandSandBoat/server) and its numerous contributors

## Powered by
- [SQLite](https://www.sqlite.org)
- [copas](https://lunarmodules.github.io/copas/) (MIT)
- [lua-websockets](https://github.com/lipp/lua-websockets) (MIT)
- [serpent](https://github.com/pkulchenko/serpent) (MIT)
- [json.lua](https://github.com/rxi/json.lua) (MIT)
