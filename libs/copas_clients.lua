-- Unified copas clients library
-- Handles event loop integration and exposes websocket/http clients

-- Add Ashita socket paths so copas can find all socket components
package.cpath           = package.cpath .. ';' .. ('%s/addons/libs/socket/?.dll;'):format(AshitaCore:GetInstallPath())
package.path            = package.path .. ';' .. ('%s/addons/libs/socket/?.lua;'):format(AshitaCore:GetInstallPath())

local copas             = require('copas')
local websocket         = require('websocket')
local copas_http_module = require('copas.http')
local json              = require('json')

---@class copas_clients
---@field copas table The copas library instance
---@field http table The copas HTTP module instance
---@field websocket_lib table The websocket library instance
local copas_clients     = {}

-- Centralized copas event loop management
local copas_started     = false

---Ensures that copas event loop processing is active
---Sets up a recurring timer to process copas coroutines if not already started
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

---WebSocket client factory
---Creates a new websocket client using copas coroutines
---@return table websocket_client A new websocket client instance
function copas_clients.websocket()
    ensure_copas_processing()
    return websocket.client.copas()
end

---Connect to a WebSocket server
---@param host string The hostname or IP address to connect to
---@param port number The port number to connect to
---@param path string|nil The WebSocket path (default: "/")
---@return table|nil websocket Connected websocket client or nil on failure
---@return string|nil error Error message if connection failed
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

---Make an HTTP request using copas
---@param url string The URL to request
---@param body string|nil The request body (for POST requests)
---@param options table|nil Optional callback configuration with on_success/on_error functions
---@return any result Returns coroutine handle if no options provided, otherwise executes async
function copas_clients.http_request(url, body, options)
    ensure_copas_processing()
    
    if not options then
        return copas.addthread(function()
            return copas_http_module.request(url, body)
        end)
    end
    
    -- Async version with callbacks
    copas.addthread(function()
        local success, response_body, status_code, headers = pcall(copas_http_module.request, url, body)
        
        if success and status_code >= 200 and status_code < 300 then
            if options.on_success then
                options.on_success(response_body, status_code, headers)
            end
        else
            if options.on_error then
                options.on_error(response_body or "Request failed", status_code, headers)
            end
        end
    end)
end

---Send data to a webhook endpoint as JSON
---@param url string The webhook URL to send data to
---@param data table The data to encode as JSON and send
---@param options table|nil Optional callback configuration with on_success/on_error functions
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
