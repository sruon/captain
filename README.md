# 👨‍✈️ captain

A suite of packet capture and analysis tools for FFXI targeting Windower v4, and Ashita v4.

`captain` sends packets when not normally possible, or at a rate greater than the game client is capable of. 

This is detectable and may cause your account to be sanctioned, up to a permanent ban.

By using `captain` you acknowledge you are aware of the risks.

## Goal

Windower and Ashita are both great, but they offer different APIs for inspecting and interacting with FFXI.

- `captain` - The logic for capturing and analyzing packets.
- `backend` - A "cross-platform" set of functions that can be used in both Windower and Ashita.

### Ashita v4

![Ashita v4 screenshot](_images/ashitav4.png)

### Windower v4

![Windower v4 screenshot](_images/windowerv4.png)

## Features
### Addons

Several addons ported from the original capture addon are available:
- `actionview`   - Logs Mob TP moves, spells, and other actions. Displays notifications.
- `caplog`       - Logs chatlog messages to a file.
- `eventview`    - Logs NPC events, cutscenes, and other events. Displays notifications.
- `hptrack`      - Logs defeated mobs estimated HP values.
- `npclogger`    - Logs detected NPCs, along with their widescan data.
- `packetviewer` - Logs packets to several files, split by incoming/outgoing and per IDs.
- `playerinfo`   - Displays basic information about player in a floating text box.
- `targetinfo`   - Displays basic information about current target in a floating text box.

### Other
- A library to parse packets
- Structured data saving with history
- Notifications display
- Textbox display
- Simple interface to create addons

## Instructions

### Windower

- Download and place in `<Windower folder>/addons`
- Either:
  - Add to `scripts/init.txt` to auto-load when you log in
  - Load on demand with `//lua load captain`
- Unload with `//lua unload captain`

### Ashita

- Download and place in `<Ashita folder>/addons`
- Either:
  - Add to `scripts/Default.txt` to auto-load when you log in
  - Load on demand with `/addon load captain`
- Unload with `/addon unload captain`

### General

- `/cap hide` to stop showing the GUI elements
- `/cap show`  to show the GUI elements
- `/cap start` (`CTRL + ALT + C`) to begin a capture
- `/cap stop` (`CTRL + ALT + V`) to end a capture
- `/cap toggle` (`CTRL + X`) to toggle recording
- `/cap split` to roll over to a new capture
- `/cap reload` (`CTRL + Z`) to reload captain
- `SHIFT + DRAG` to drag text boxes around

### Differences with Windower capture
- Data is stored in a slightly different format
- Uses XiPacket field names where applicable. Certain legacy fields have been kept.
- Lot less customization options
- The existing addons commands (customization) were not ported. Customization happens through config files.
- No concept of PASSIVE/OFF mode. The backend is either capturing or it's not.
- Not all infos that were available in the text box were ported over. Moon phase etc.
- PlayerInfo displays current ZoneServer IP/port. It is also logged in the capture folders.

### TODO
- Witness protection
- Retail testing
- Compare with Windower capture addon
- Rewrite HPTrack
- EventView zone events

### Development

- TODO

```bat
C:\ffxi>mklink /D C:\ffxi\Ashita\addons\captain C:\ffxi\captain
symbolic link created for C:\ffxi\Ashita\addons\captain <<===>> C:\ffxi\captain

C:\ffxi>mklink /D C:\ffxi\Windower\addons\captain C:\ffxi\captain
symbolic link created for C:\ffxi\Windower\addons\captain <<===>> C:\ffxi\captain
```

## Based on & made possible by

- [Windower](https://www.windower.net/)
- [Ashita](https://ashitaxi.com/)
- `Packeteer` by atom0s
- `XiPackets` by atom0s
- `capture` by ibm2431
- `PacketViewer` by Arcon
