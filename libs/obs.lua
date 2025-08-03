local copas_clients = require('copas_clients')
local json = require('json')
local sha = require('ffi.sha')

---@class OBS
---@field client table WebSocket client instance
---@field host string Server hostname or IP
---@field port number Server port
---@field password string Server password
---@field authenticated boolean Authentication status
---@field message_id number Counter for request IDs
---@field timeout number Socket timeout in seconds
---@field max_retries number Maximum retries for recoverable errors
local OBS = {}
OBS.__index = OBS

---Creates a new OBS WebSocket client
---@param host string Hostname or IP address of OBS WebSocket server
---@param port number Port of OBS WebSocket server
---@param password string|nil Password for authentication (or empty string)
---@param timeout number|nil Socket timeout in seconds (default: 0.5)
---@return OBS client The OBS client instance
function OBS.new(host, port, password, timeout)
    return setmetatable(
        {
            client        = nil,
            host          = host,
            port          = port,
            password      = password,
            authenticated = false,
            message_id    = 1,
            timeout       = timeout or 0.5,
            max_retries   = 1,
        }, OBS)
end

---Establishes connection to OBS WebSocket and authenticates
---@return OBS|nil client Client instance if successful, nil if failed
---@return string|nil error_message Error message if connection failed, nil if successful
function OBS:connect()
    if self.client then return self, nil end

    local client, err = copas_clients.websocket_connect(self.host, self.port)
    if not client then return nil, 'Connection error: ' .. (err or 'unknown error') end

    if client.socket then client.socket:settimeout(self.timeout) end
    self.client = client

    local success, auth_err = self:authenticate()
    if not success then
        self:close()
        return nil, auth_err
    end

    return self, nil
end

---Authenticates with the OBS WebSocket server
---@return boolean|nil success, string|nil error_message
function OBS:authenticate()
    if self.authenticated then return true end
    if not self.client then return nil, 'No connection established' end

    local hello_data, err = self.client:receive()
    if not hello_data then return nil, 'Failed to receive Hello: ' .. (err or 'Server not responding') end

    local success, parse_err = pcall(json.decode, hello_data)
    if not success or not parse_err or parse_err.op ~= 0 then return nil, 'Invalid Hello message' end

    local identify =
    {
        op = 1,
        d =
        {
            rpcVersion = 1,
            eventSubscriptions = 0,
        },
    }

    if parse_err.d and parse_err.d.authentication then
        if self.password == '' then return nil, 'Authentication required but no password provided' end

        local concat = self.password .. parse_err.d.authentication.salt
        local hash_bytes = sha.bin_to_base64(sha.hex_to_bin(sha.sha256(concat)))
        local combined = hash_bytes .. parse_err.d.authentication.challenge
        local auth_response = sha.bin_to_base64(sha.hex_to_bin(sha.sha256(combined)))
        identify.d.authentication = auth_response
    end

    local json_str = json.encode(identify)

    local success, err = self.client:send(json_str)
    if not success then return nil, 'Failed to send Identify: ' .. (err or 'Connection lost') end

    local identified_data, err = self.client:receive()
    if not identified_data then return nil, 'Failed to receive Identified: ' .. (err or 'Server not responding') end

    local success, id_parse_err = pcall(json.decode, identified_data)
    if not success or not id_parse_err or id_parse_err.op ~= 2 then return nil, 'Authentication failed' end

    self.authenticated = true
    return true
end

---Sends a request to OBS WebSocket server with automatic reconnection for specific errors
---@param request_name string The name of the request/action to perform
---@param request_data table|nil Optional data to include with the request
---@return table|nil response, string|nil error_message
function OBS:send_request(request_name, request_data)
    if not self.client then
        local success, err = self:connect()
        if not success then return nil, err end
    end

    if not self.authenticated then return nil, 'Not authenticated' end

    local request =
    {
        op = 6,
        d =
        {
            requestType = request_name,
            requestId = tostring(self.message_id),
            requestData = request_data or {},
        },
    }
    self.message_id = self.message_id + 1

    local json_str = json.encode(request)

    local success, err = self.client:send(json_str)
    if not success then
        self:close()
        return nil, 'Failed to send request: ' .. (err or 'Connection lost')
    end

    local response_data, err
    local retry_count = 0

    while retry_count <= self.max_retries do
        response_data, err = self.client:receive()

        if response_data or (err and err ~= 'Connection closed by server') then break end

        if err == 'Connection closed by server' then
            self:close()

            local success, connect_err = self:connect()
            if not success then
                return nil, 'Failed to reconnect after server closed connection: ' .. (connect_err or 'unknown error')
            end

            json_str = json.encode(request)
            success, err = self.client:send(json_str)
            if not success then
                self:close()
                return nil, 'Failed to resend request after reconnect: ' .. (err or 'Connection lost')
            end

            retry_count = retry_count + 1
        else
            break
        end
    end

    if not response_data then
        self:close()
        return nil, 'Failed to receive response: ' .. (err or 'Server not responding')
    end

    local success, response = pcall(json.decode, response_data)
    if not success or not response or response.op ~= 7 then return nil, 'Invalid response' end

    if response.d and response.d.requestStatus and response.d.requestStatus.result == false then
        local code = response.d.requestStatus.code or 'unknown'
        local message = response.d.requestStatus.comment or 'No error message provided'
        return nil, 'Request failed: ' .. message .. ' (code ' .. code .. ')'
    end

    return response.d and response.d.responseData or response.d
end

---Closes the connection to OBS WebSocket server
function OBS:close()
    if self.client then
        self.client:close()
        self.client = nil
        self.authenticated = false
    end
end

---Gets OBS statistics
---@return table|nil stats, string|nil error_message
function OBS:GetStats()
    return self:send_request('GetStats')
end

---Starts OBS recording
---@return table|nil response, string|nil error_message
function OBS:StartRecord()
    return self:send_request('StartRecord')
end

---Gets the current recording path
---@return table|nil response, string|nil error_message
function OBS:GetRecordPath()
    return self:send_request('GetRecordPath')
end

---Stops OBS recording
---@return table|nil response, string|nil error_message
function OBS:StopRecord()
    return self:send_request('StopRecord')
end

---Splits the current recording file
---@return table|nil response, string|nil error_message
function OBS:SplitRecordFile()
    return self:send_request('SplitRecordFile')
end

---Gets the current recording status
---@return table|nil response, string|nil error_message
function OBS:GetRecordStatus()
    return self:send_request('GetRecordStatus')
end

---Sets the recording directory
---@param path string Path to save recordings
---@return table|nil response, string|nil error_message
function OBS:SetRecordDirectory(path)
    return self:send_request('SetRecordDirectory', { recordDirectory = path })
end

---Sets the current program scene
---@param scene string Name of the scene to switch to
---@return table|nil response, string|nil error_message
function OBS:SetCurrentProgramScene(scene)
    return self:send_request('SetCurrentProgramScene', { sceneName = scene })
end

---Sets the current profile
---@param profile string Name of the profile to switch to
---@return table|nil response, string|nil error_message
function OBS:SetCurrentProfile(profile)
    return self:send_request('SetCurrentProfile', { profileName = profile })
end

---Sets a profile parameter
---@param cat string Parameter category
---@param name string Parameter name
---@param value string Parameter value
---@return table|nil response, string|nil error_message
function OBS:SetProfileParameter(cat, name, value)
    return self:send_request('SetProfileParameter',
        {
            parameterCategory = cat,
            parameterName = name,
            parameterValue = value,
        })
end

---Sets input settings for a source
---@param input_name string Name of the input source
---@param settings table Settings to apply
---@param overlay boolean|nil Whether to overlay on existing settings (default: true)
---@return table|nil response, string|nil error_message
function OBS:SetInputSettings(input_name, settings, overlay)
    return self:send_request('SetInputSettings', {
        inputName = input_name,
        inputSettings = settings,
        overlay = overlay ~= false -- Default to true
    })
end

return OBS
