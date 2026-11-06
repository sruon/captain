-- Memoria, Vault's recorder plugin. The release bundles the build pinned in
-- memoria.json as deps/Memoria.dll.
local backend = require('backend.backend')

local memoria = {}
local started = false

local function plugin(name)
    return string.format('%s/plugins/%s', AshitaCore:GetInstallPath(), name)
end

local function read(p)
    local f = io.open(p, 'rb')
    if not f then
        return nil
    end
    local data = f:read('*a')
    f:close()
    return data
end

local function write(p, data)
    local f = io.open(p, 'wb')
    if not f then
        return false
    end
    f:write(data)
    f:close()
    return true
end

local function command(text)
    if memoria.loaded() then
        AshitaCore:GetChatManager():QueueCommand(-1, text)
    end
end

function memoria.loaded()
    return AshitaCore:GetPluginManager():IsLoaded('Memoria')
end

-- A build's version, from the text "Memoria/0.6.0-rc.1" (rc.3 and older) or
-- "Memoria 0.6.0-rc.4" it holds, as { major, minor, patch, rc }. A release sorts
-- after its pre-releases.
local function version(dll)
    local a, b, c, pre = dll:match('Memoria[/ ](%d+)%.(%d+)%.(%d+)%-?([%w%.]*)')
    if not a then
        return nil
    end
    -- Only the pre-release number counts (rc.2 == beta.2); Memoria only tags rc.N.
    return { tonumber(a), tonumber(b), tonumber(c), tonumber(pre:match('(%d+)$')) or math.huge }
end

local function older(x, y)
    for i = 1, 4 do
        if x[i] ~= y[i] then
            return x[i] < y[i]
        end
    end
    return false
end

-- Installs the bundled build when none is installed or the installed one is
-- older; a newer or unrecognised build stays. A loaded DLL cannot be
-- overwritten but can be renamed: a running Memoria keeps going and the new
-- build takes over at the next start.
local function install()
    local bundled = read(addon.path .. 'deps/Memoria.dll')
    local want = bundled and version(bundled)
    if not want then
        return
    end
    local installed = read(plugin('Memoria.dll'))
    if installed then
        local have = version(installed)
        if not have or not older(have, want) then
            return
        end
    end
    os.remove(plugin('Memoria.dll.old'))
    os.rename(plugin('Memoria.dll'), plugin('Memoria.dll.old'))
    if not write(plugin('Memoria.dll'), bundled) then
        os.rename(plugin('Memoria.dll.old'), plugin('Memoria.dll'))
        backend.errMsg('captain', 'Cannot install Memoria in ' .. plugin(''))
        return
    end
    if memoria.loaded() then
        backend.msg('captain', 'Memoria updated; the new version takes over at the next start')
    end
end

function memoria.start()
    if started then
        return
    end
    started = true
    install()
    if not memoria.loaded() and ashita.fs.exists(plugin('Memoria.dll')) then
        -- Addons cannot load a plugin through the plugin manager, so captain types the command a player would.
        AshitaCore:GetChatManager():QueueCommand(-1, '/load memoria')
    end
end

---@param text string
function memoria.note(text)
    command('/memoria note ' .. text)
end

---Writes the session's packets to path until sessionStop.
---@param path string
function memoria.sessionStart(path)
    command('/memoria session start ' .. path)
end

function memoria.sessionStop()
    command('/memoria session stop')
end

return memoria
