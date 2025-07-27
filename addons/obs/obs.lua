-- Automates OBS recording when capturing.
-- Requires the Websocket server to be enabled in OBS.
-- Requires OBS profile and scene to be configured correctly.
-- Splitting per zone requires Setting > Output > Output Mode: Advanced > Recording > Automatic File Splitting: Only split manually
local obs = require('libs/obs')
local utils = require('utils')

---@class OBSAddon : AddonInterface
---@field recording boolean
---@field client OBS | nil
local addon =
{
    name            = 'OBS',
    client          = nil,
    recording       = false,
    settings        = {},
    defaultSettings =
    {
        enabled           = false,
        host              = '127.0.0.1',
        port              = 4455,
        password          = '',
        recordWithCapture = false,
        recordPath        = '',
        profile           = 'Untitled',
        scene             = 'Scene',
        source            = 'Game Capture',
        splitPerZone      = false,
    },
}

local function isConnected()
    if not addon.settings.enabled then return false end
    if not addon.client then return false end

    -- Try to connect if not already connected
    if not addon.client.authenticated then
        local client, err = addon.client:connect()
        if not client then
            backend.msg('OBS', 'Connection failed: ' .. (err or 'unknown error'))
            return false
        end
    end

    local response, err = addon.client:GetStats()
    if not response then
        backend.msg('OBS', 'Connection check failed: ' .. (err or 'unknown error'))
        return false
    end

    return true
end

local function StartRecord()
    if not isConnected() then return false end

    local response, err = addon.client:StartRecord()
    if response then
        backend.msg('OBS', 'Recording started successfully')
        addon.recording = true
        return true
    else
        backend.msg('OBS', 'Error starting recording: ' .. (err or 'unknown error'))
        return false
    end
end

local function StopRecord()
    if not addon.settings.enabled or not addon.recording then return false end

    if not isConnected() then
        backend.msg('OBS', 'Cannot stop recording: Not connected')
        addon.recording = false
        return false
    end

    local response, err = addon.client:StopRecord()
    if response then
        backend.msg('OBS', 'Recording stopped successfully')
        if response.outputPath then
            backend.msg('OBS', 'Recording saved to: ' .. response.outputPath)
        end
        addon.recording = false
        return true
    else
        backend.msg('OBS', 'Error stopping recording: ' .. (err or 'unknown error'))
        addon.recording = false
        return false
    end
end

addon.onCaptureStart = function(captureDir)
    addon.client = obs.new(addon.settings.host, addon.settings.port, addon.settings.password)
    if not isConnected() then return end

    local success = true

    if addon.settings.profile ~= '' then
        local response, err = addon.client:SetCurrentProfile(addon.settings.profile)
        if response then
            backend.msg('OBS', 'Profile set to: ' .. addon.settings.profile)
        else
            backend.msg('OBS', 'Error setting profile: ' .. (err or 'unknown error'))
            success = false
        end
    end

    if success and addon.settings.scene ~= '' then
        local response, err = addon.client:SetCurrentProgramScene(addon.settings.scene)
        if response then
            backend.msg('OBS', 'Scene set to: ' .. addon.settings.scene)
        else
            backend.msg('OBS', 'Error setting scene: ' .. (err or 'unknown error'))
            success = false
        end
    end

    if success and addon.settings.source ~= '' then
        local process_path, window_name = utils.getProcessInfo()
        local exe_name = process_path:match('([^\\]+)$') or process_path
        local window_string = backend.player_name() .. ':FFXiClass:' .. exe_name

        local response, err = addon.client:SetInputSettings(addon.settings.source,
            {
                capture_mode = 'window',
                capture_cursor = true,
                allow_transparency = false,
                hook_rate = 0,
                limit_framerate = false,
                priority = 'title',
                window = window_string,
            })

        if response then
            backend.msg('OBS', 'Source ' .. addon.settings.source .. ' set to window: ' .. window_string)
        else
            backend.msg('OBS', 'Error setting source: ' .. (err or 'unknown error'))
            success = false
        end
    end

    if success and addon.settings.recordWithCapture then
        local recordingPath = string.format('%s/%s', backend.script_path(), captureDir)
        backend.create_dir(recordingPath)
        local response, err = addon.client:SetRecordDirectory(recordingPath)
        if response then
            backend.msg('OBS', 'Recording path set to: ' .. recordingPath)
        else
            backend.msg('OBS', 'Error setting recording path: ' .. (err or 'unknown error'))
            success = false
        end
    elseif success and addon.settings.recordPath ~= '' then
        local response, err = addon.client:SetRecordDirectory(addon.settings.recordPath)
        if response then
            backend.msg('OBS', 'Recording path set to: ' .. addon.settings.recordPath)
        else
            backend.msg('OBS', 'Error setting recording path: ' .. (err or 'unknown error'))
            success = false
        end
    end

    if success then
        StartRecord()
    end
end

addon.onCaptureStop = function()
    StopRecord()
end

addon.onZoneChange = function(_)
    if not addon.settings.enabled or not addon.settings.splitPerZone or not addon.recording then return end

    if not isConnected() then return end

    local response, err = addon.client:SplitRecordFile()
    if response then
        backend.msg('OBS', 'Split recording')
    else
        backend.msg('OBS', 'Error splitting recording: ' .. (err or 'unknown error'))
    end
end

addon.onConfigMenu = function()
    return
    {
        {
            key         = 'enabled',
            title       = 'Auto-Record',
            description = 'When enabled, OBS will automatically record when a capture starts',
            type        = 'checkbox',
            default     = addon.defaultSettings.enabled,
        },
        {
            key         = 'host',
            title       = 'OBS Host',
            description = 'Hostname or IP address of OBS WebSocket server',
            type        = 'text',
            default     = addon.defaultSettings.host,
        },
        {
            key         = 'port',
            title       = 'OBS Port',
            description = 'Port of OBS WebSocket server',
            type        = 'number',
            default     = addon.defaultSettings.port,
        },
        {
            key         = 'password',
            title       = 'OBS Password',
            description = 'Password for OBS WebSocket server (leave empty if none)',
            type        = 'text',
            default     = addon.defaultSettings.password,
        },
        {
            key         = 'profile',
            title       = 'OBS Profile',
            description = 'OBS profile to use when recording (leave empty to disable switching)',
            type        = 'text',
            default     = addon.defaultSettings.profile,
        },
        {
            key         = 'scene',
            title       = 'OBS Scene',
            description = 'OBS scene to use when recording (leave empty to disable switching)',
            type        = 'text',
            default     = addon.defaultSettings.scene,
        },
        {
            key         = 'source',
            title       = 'OBS Source',
            description =
            'OBS source to set to current window when recording (leave empty to disable automatic source switching)',
            type        = 'text',
            default     = addon.defaultSettings.source,
        },
        {
            key         = 'recordWithCapture',
            title       = 'Record With Capture',
            description = 'When enabled, OBS will record to the same directory as the capture',
            type        = 'checkbox',
            default     = addon.defaultSettings.recordWithCapture,
        },
        {
            key         = 'recordPath',
            title       = 'Recording Path',
            description = 'Path to save recordings when not using capture directory. Must be fully qualified.',
            type        = 'text',
            default     = addon.defaultSettings.recordPath,
        },
        {
            key         = 'splitPerZone',
            title       = 'Auto-Split on Zone Change',
            description =
            'When enabled, OBS will split the recording file when zoning. Must be enabled in the Output settings.',
            type        = 'checkbox',
            default     = addon.defaultSettings.splitPerZone,
        },
    }
end

return addon
