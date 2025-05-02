-- Credits: sruon
---@class CapLogAddon : AddonInterface
---@field logs { global: file?, capture: file? }
local addon =
{
    name     = 'CapLog',
    settings = {},
    logs     =
    {
        global = nil,
        capture = nil,
    }
}

addon.onIncomingText = function(mode, text)
    if not text then
        return
    end

    local tstamp = os.date('[%H:%M:%S]')
    if addon.logs.global then
        backend.fileAppend(addon.logs.global, tstamp .. text .. '\n')
    end

    if addon.logs.capture then
        backend.fileAppend(addon.logs.capture, tstamp .. text .. '\n')
    end
end

addon.onCaptureStop = function()
    addon.logs.capture = nil
end

addon.onCaptureStart = function(captureDir)
    addon.logs.capture = backend.fileOpen(captureDir .. backend.player_name() .. '.log')
end

addon.onInitialize = function(rootDir)
    addon.logs.global = backend.fileOpen(rootDir .. backend.player_name() .. '.log')
end

addon.onCommand = function(args)
end

local commands =
{
    { cmd = 'test', desc = 'Test command', keybind = { key = 'p', ctrl = true, down = true } }
}

addon.onHelp = function()
    return commands
end

return addon
