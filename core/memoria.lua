-- Memoria, Vault's recorder plugin: captain installs it, keeps it current, and
-- loads it. Captain loads at boot, so Memoria records from the first login.
-- Releases are published at https://memoria.sruon.dev/latest.json.
local backend  = require('backend.backend')
local json     = require('json')

local memoria  = {}
local LATEST   = 'https://memoria.sruon.dev/latest.json'
local started  = false

local function path(name)
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

local function exists(p)
    local f = io.open(p, 'rb')
    if f then
        f:close()
        return true
    end
    return false
end

---@return boolean loaded Memoria is loaded and recording
function memoria.loaded()
    return AshitaCore:GetPluginManager():IsLoaded('Memoria')
end

-- Moves a downloaded Memoria.dll.new into place and records its hash.
local function install(sha256)
    os.remove(path('Memoria.dll.old'))
    os.rename(path('Memoria.dll'), path('Memoria.dll.old'))
    if not os.rename(path('Memoria.dll.new'), path('Memoria.dll')) then
        os.rename(path('Memoria.dll.old'), path('Memoria.dll')) -- put the old one back
        return false
    end
    write(path('Memoria.sha256'), sha256)
    os.remove(path('Memoria.dll.pending'))
    return true
end

-- Swaps in an update downloaded during an earlier session. Only before login:
-- unloading Memoria mid-session would split that session's capture.
local function applyPending()
    local pending = read(path('Memoria.dll.pending'))
    if not pending or not exists(path('Memoria.dll.new')) then
        return
    end
    if AshitaCore:GetMemoryManager():GetPlayer():GetLoginStatus() == 2 then
        return
    end
    if memoria.loaded() then
        AshitaCore:GetPluginManager():Unload('Memoria')
    end
    if install(pending) then
        backend.msg('captain', 'Memoria updated')
    end
end

local function load()
    if not memoria.loaded() and exists(path('Memoria.dll')) then
        AshitaCore:GetPluginManager():Load('Memoria', '')
    end
end

-- Downloads a newer Memoria in the background. A first install loads at once;
-- an update waits for the next start.
local function checkForUpdate()
    local copas = require('copas_clients')
    copas.http_request(LATEST, nil, {
        on_success = function(body)
            local ok, latest = pcall(json.decode, body)
            if not ok or type(latest) ~= 'table' or not latest.sha256 or not latest.url or not latest.size then
                return
            end
            if read(path('Memoria.sha256')) == latest.sha256 or read(path('Memoria.dll.pending')) == latest.sha256 then
                return
            end
            copas.http_request(latest.url, nil, {
                on_success = function(dll)
                    if #dll ~= latest.size or dll:sub(1, 2) ~= 'MZ' then
                        backend.errMsg('captain', 'Memoria download was incomplete; keeping what is installed')
                        return
                    end
                    if not write(path('Memoria.dll.new'), dll) then
                        return
                    end
                    write(path('Memoria.dll.pending'), latest.sha256)
                    if not exists(path('Memoria.dll')) then
                        -- Nothing recording yet, so nothing to split: install now.
                        if install(latest.sha256) then
                            load()
                            backend.msg('captain', 'Memoria ' .. latest.version .. ' installed: every session is recorded')
                        end
                    else
                        backend.msg('captain', 'Memoria ' .. latest.version .. ' downloaded; it takes over at the next start')
                    end
                end,
            })
        end,
    })
end

---Installs, updates, and loads Memoria. Runs once, when captain loads.
function memoria.start()
    if started or not AshitaCore then
        return
    end
    started = true
    applyPending()
    load()
    checkForUpdate()
end

---Places a note in Memoria's capture, such as the start of a captain session.
---@param text string
function memoria.note(text)
    if memoria.loaded() then
        AshitaCore:GetChatManager():QueueCommand(-1, '/memoria note ' .. text)
    end
end

return memoria
