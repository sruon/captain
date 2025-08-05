-- Unified copas clients library
-- Handles event loop integration and exposes websocket/http clients

-- Add Ashita socket paths so copas can find all socket components
package.cpath           = package.cpath .. ';' .. ('%s/addons/libs/socket/?.dll;'):format(AshitaCore:GetInstallPath())
package.path            = package.path .. ';' .. ('%s/addons/libs/socket/?.lua;'):format(AshitaCore:GetInstallPath())

local copas             = require('copas')
local websocket         = require('websocket')
local copas_http_module = require('copas.http')
local json              = require('json')

local copas_clients     = {}

-- Centralized copas event loop management
local copas_started     = false

local function ensure_copas_processing()
    if not copas_started then
        copas_started = true

        -- Set copas.running flag as per documentation when using custom loop
        copas.running = true

        -- Use a simple recurring timer to process copas events
        backend.forever(function()
            -- Step copas to process any pending coroutines
            copas.step(0.01) -- 10ms processing window
        end, 0.05)           -- Check every 50ms
    end
end

-- WebSocket client factory
function copas_clients.websocket()
    ensure_copas_processing()
    return websocket.client.copas()
end

function copas_clients.websocket_connect(host, port, path)
    path          = path or '/'
    local ws      = copas_clients.websocket()
    local ws_url  = 'ws://' .. host .. ':' .. tostring(port) .. path
    local ok, err = ws:connect(ws_url)
    if not ok then
        return nil, err or 'Connection failed'
    end
    return ws
end

function copas_clients.http_request(url, body)
    ensure_copas_processing()
    return copas.addthread(function()
        return copas_http_module.request(url, body)
    end)
end

function copas_clients.webhook(url, data, options)
    ensure_copas_processing()
    options = options or {}

    copas.addthread(function()
        local json_data                           = json.encode(data)
        local success, body, status_code, headers = pcall(copas_http_module.request, url, json_data)

        if success then
            if options.on_success then
                options.on_success(status_code, headers)
            end
        else
            if options.on_error then
                options.on_error(body)
            end
        end
    end)
end

copas_clients.copas         = copas
copas_clients.http          = copas_http_module
copas_clients.websocket_lib = websocket

return copas_clients
