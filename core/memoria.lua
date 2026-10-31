-- Memoria, Vault's recorder plugin: it records every packet of every session to
-- xicap. Captain's release bundles a pinned build in deps/Memoria.dll (see
-- memoria.json), installs it into Ashita's plugins folder, and loads it when
-- captain loads, which is at boot, before character select: Memoria then
-- records from the first login. /cap start and /cap stop put a session xicap
-- in each capture folder.
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

---@return boolean loaded Memoria is loaded and recording
function memoria.loaded()
    return AshitaCore:GetPluginManager():IsLoaded('Memoria')
end

-- Puts the bundled build in plugins/ when the one there differs. A loaded DLL
-- cannot be overwritten but can be renamed, so a running Memoria keeps going
-- and the new one takes over at the next start.
local function install()
    local bundled = read(addon.path .. 'deps/Memoria.dll')
    if not bundled then
        return -- a git checkout without a release's deps: use whatever is installed
    end
    if read(plugin('Memoria.dll')) == bundled then
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

---Installs and loads Memoria. Runs once, when captain loads.
function memoria.start()
    if started or not AshitaCore then
        return
    end
    started = true
    install()
    if not memoria.loaded() and read(plugin('Memoria.dll')) then
        AshitaCore:GetPluginManager():Load('Memoria', '')
    end
end

---Places a note in Memoria's captures.
---@param text string
function memoria.note(text)
    command('/memoria note ' .. text)
end

---Starts a session xicap at path: the same packets as Memoria's own capture,
---until sessionStop.
---@param path string
function memoria.sessionStart(path)
    command('/memoria session start ' .. path)
end

function memoria.sessionStop()
    command('/memoria session stop')
end

return memoria
