-- Captain core configuration
local config = {}

---@type Command[]
config.commandsMap =
{
    { cmd = '',       desc = 'Open configuration menu' },
    {
        cmd     = 'start',
        desc    = 'Start capturing',
        keybind =
        {
            key  = 'c',
            down = true,
            ctrl = true,
            alt  = true,
        },
    },
    {
        cmd     = 'stop',
        desc    = 'Stop capturing',
        keybind =
        {
            key  = 'v',
            down = true,
            ctrl = true,
            alt  = true,
        },
    },
    { cmd = 'toggle', desc = 'Start/stop capturing',         keybind = { key = 'x', down = true, ctrl = true } },
    { cmd = 'split',  desc = 'Stop and start a new capture', keybind = nil },
    { cmd = 'reload', desc = 'Reload captain',               keybind = { key = 'z', down = true, ctrl = true } },
}

return config