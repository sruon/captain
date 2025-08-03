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

Compiled Lua libraries are unfortunately very hard to compile and integrate given everything needs to target Windows 32 bits.

### Fat framework, light addons
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
### Addons

#### Ported from Windower suite
- `actionview`   - Logs Mob TP moves, spells, and other actions. Displays notifications.
- `caplog`       - Logs chatlog messages to a file.
- `eventview`    - Logs NPC events, cutscenes, and other events. Displays notifications.
- `hptrack`      - Logs defeated mobs estimated HP values.
- `npclogger`    - Logs detected NPCs, along with their widescan data.
- `packetviewer` - Logs packets to several files, split by incoming/outgoing and per IDs.
- `playerinfo`   - Displays basic information about player in a floating text box.
- `targetinfo`   - Displays basic information about current target in a floating text box.

#### New additions
- `kitrack`      - Displays and logs obtained/lost Key Items, including the position of occurence.
- `attackdelay`  - Captures delay between attack rounds and displays on death. Includes reverse calculation from TP gains on hits.
- `pathlog`      - Logs player and NPC movements, with customizable leg detection.
- `packetbridge` - Re-emits received/sent packets to an arbitrary UDP endpoint.
- `weathertrack` - Logs weather changes in a database.
- `obs`          - Automates the management of OBS and saves recordings in the capture folder.

### Standard library
- UI configuration
- Packets parser
- SQLite3 structured data storage with diff tracking
- CSV data points logging
- Async HTTP(S) and WebSocket clients
- Notifications display
- Textbox display
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
- Witness protection
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
### What's the point of captures, anyway?
Captures allow us to understand FFXI official server behavior in various scenario and then to replicate it for emulation purposes.
For example, we can see the models used by enemies, the abilities they use and where they spawn.

While captures contain an incredible wealth of information, they are just one of many tools used for emulation as a large part of the game behavior is not directly available in packet form.

We can see a spell did hit for 500 points of damage, however we cannot _directly_ deduce the various numbers that went into calculating this number. Understanding the effect of various factors on calculations require running through specific test cases 1000, if not 10000s of times.

This framework can help with the collection and aggregation of data in such cases.

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