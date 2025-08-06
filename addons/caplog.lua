-- Credits: sruon
---@class CapLogAddon : AddonInterface
---@field logs { global: File?, capture: File? }
local addon          =
{
    name     = 'CapLog',
    settings = {},
    logs     =
    {
        global  = nil,
        capture = nil,
    },
}

addon.onIncomingText = function(_, text)
    if not text then
        return
    end

    local tstamp = os.date('[%H:%M:%S]')
    if addon.logs.global then
        addon.logs.global:append(tstamp .. text .. '\n')
    end

    if addon.logs.capture then
        addon.logs.capture:append(tstamp .. text .. '\n')
    end
end

addon.onCaptureStop  = function()
    addon.logs.capture = nil
end

addon.onCaptureStart = function(captureDir)
    addon.logs.capture = backend.fileOpen(captureDir .. backend.player_name() .. '.log')
end

addon.onInitialize   = function(rootDir)
    addon.logs.global = backend.fileOpen(rootDir .. backend.player_name() .. '.log')
end

return addon
