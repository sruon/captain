# OBS automated recording

This addon is not enabled by default.

## Requirements

### OBS
OBS must be installed and running. You may need to run it as Administrator for FFXI capture to work.

### OBS WebSocket Server
1. Go to Tools > WebSocket Server Settings
2. Configure the following:
   - Check "Enable WebSocket server"
   - Update port or leave 4455 default
   - Get the password through "Show Connect Info"
     - Alternatively, authentication can be disabled by unchecking "Enable Authentication" but this is not recommended.
3. Click "Apply" > "OK"

### Working Profile / Scene
Default profiles and scenes can be used. You only need to make sure OBS is correctly capturing FFXI.

To set up FFXI capture:
1. Go to Sources > + > Game Capture
2. Configure:
   - Mode: Capture specific window
   - Window: Your FFXI window
   - Everything else can be left to their default values
   - You may want to enable "Capture Audio"

### Split Recordings on Zone Changes (Optional)
1. Go to Settings > Output
2. Set Output Mode to "Advanced"
3. Under Recording, check "Automatic File Splitting" and select "Only split manually"

## Configuration

- Use `/cap` to open the configuration, then update fields in the OBS tab
- Make sure to set your password
- `Scene`, `Profile` and `Password` can be left empty to disable the associated features


## Notes
- OBS will not start a record if OBS settings are open
- If not saving with capture, the recording will be saved in the path set in your profile
- This addon modifies the profile when saving with capture. Use a dedicated Profile if needed.
- This does not automatically set up the Game Capture in OBS
- This does not automatically select appropriate recording parameters (encoder, fps). This is your responsability.
