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

-- A loaded DLL cannot be overwritten but can be renamed: a running Memoria
-- keeps going and the new build takes over at the next start.
local function install()
    local bundled = read(addon.path .. 'deps/Memoria.dll')
    if not bundled or read(plugin('Memoria.dll')) == bundled then
        return
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
        AshitaCore:GetPluginManager():Load('Memoria', '')
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
