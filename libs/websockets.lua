-- Vibecoded websockets library, don't @ me
local socket = require('socket')
local bit = require('bit')
local base64 = require('mime')

---Apply or remove WebSocket masking
---@param payload string The data to mask/unmask
---@param mask string The 4-byte masking key
---@return string The masked/unmasked data
local function mask_payload(payload, mask)
  local result = {}
  for i = 1, #payload do
    local mask_byte = string.byte(mask, ((i - 1) % 4) + 1)
    local payload_byte = string.byte(payload, i)
    result[i] = string.char(bit.bxor(payload_byte, mask_byte))
  end
  return table.concat(result)
end

---Generate random WebSocket key
---@return string base64 encoded key
local function generate_random_key()
  local key = ''
  for i = 1, 16 do
    key = key .. string.char(math.random(0, 255))
  end
  return base64.b64(key)
end

---Create WebSocket handshake request
---@param host string Server hostname
---@param port number|string Server port
---@param key string WebSocket key
---@return string The HTTP handshake request
local function create_handshake(host, port, key)
  return table.concat(
  {
    'GET / HTTP/1.1',
    'Host: ' .. host .. ':' .. port,
    'Upgrade: websocket',
    'Connection: Upgrade',
    'Sec-WebSocket-Key: ' .. key,
    'Sec-WebSocket-Version: 13',
    '',
    '',
  }, '\r\n')
end

---Verify server's handshake response
---@param sock table Socket connection
---@return boolean success Whether handshake succeeded
---@return string? error Error message on failure
local function verify_handshake(sock)
  local status_line, err = sock:receive('*l')
  if not status_line or not status_line:match(' 101 ') then
    return false, 'WebSocket handshake failed'
  end

  local headers = {}
  while true do
    local line, err = sock:receive('*l')
    if not line then return false, 'Failed to read headers' end
    if line == '' then break end

    local key, value = line:match('^([^:]+):%s*(.+)')
    if key then headers[key:lower()] = value end
  end

  if not headers['upgrade'] or headers['upgrade']:lower() ~= 'websocket' then
    return false, 'WebSocket upgrade failed'
  end

  return true
end

---Create WebSocket client with its methods
---@param sock table Socket connection
---@return table WebSocket client
local function create_websocket_client(sock)
  local ws =
  {
    socket = sock,
  }

  ---Send a message to the server
  ---@param message string The message to send
  ---@return number|nil bytes Bytes sent or nil on error
  ---@return string? error Error message on failure
  function ws:send(message)
    local frame = self:encode_frame(message)
    return self.socket:send(frame)
  end

  ---Receive a message from the server
  ---@return string|nil message The received message or nil on error
  ---@return string? error Error message on failure
  function ws:receive()
    return self:receive_frame()
  end

  ---Close the WebSocket connection
  function ws:close()
    if self.socket then
      self.socket:close()
      self.socket = nil
    end
  end

  function ws:encode_frame(message)
    local header = { string.char(0x81) }

    local mask = ''
    for i = 1, 4 do
      mask = mask .. string.char(math.random(0, 255))
    end

    local len = #message
    if len < 126 then
      header[2] = string.char(bit.bor(0x80, len))
    elseif len < 65536 then
      header[2] = string.char(bit.bor(0x80, 126))
      header[3] = string.char(bit.band(bit.rshift(len, 8), 0xFF))
      header[4] = string.char(bit.band(len, 0xFF))
    else
      header[2] = string.char(bit.bor(0x80, 127))
      for i = 1, 8 do
        header[10 - i] = string.char(bit.band(bit.rshift(len, (i - 1) * 8), 0xFF))
      end
    end

    header[#header+1] = mask

    local masked_payload = mask_payload(message, mask)

    return table.concat(header) .. masked_payload
  end

  function ws:receive_frame()
    local header, err = self.socket:receive(2)
    if not header then return nil, 'Failed to read frame' end

    local byte1, byte2 = string.byte(header, 1, 2)
    local fin = bit.band(byte1, 0x80) ~= 0
    local opcode = bit.band(byte1, 0x0F)
    local masked = bit.band(byte2, 0x80) ~= 0
    local payload_len = bit.band(byte2, 0x7F)

    if payload_len == 126 then
      local len_bytes, err = self.socket:receive(2)
      if not len_bytes then return nil, 'Failed to read length' end
      payload_len = bit.bor(bit.lshift(string.byte(len_bytes, 1), 8), string.byte(len_bytes, 2))
    elseif payload_len == 127 then
      local len_bytes, err = self.socket:receive(8)
      if not len_bytes then return nil, 'Failed to read length' end

      payload_len = 0
      for i = 1, 8 do
        payload_len = bit.bor(bit.lshift(payload_len, 8), string.byte(len_bytes, i))
      end
    end

    local mask
    if masked then
      mask, err = self.socket:receive(4)
      if not mask then return nil, 'Failed to read mask' end
    end

    local payload, err = self.socket:receive(payload_len)
    if not payload then return nil, 'Failed to read payload' end

    if masked and mask then
      payload = mask_payload(payload, mask)
    end

    if opcode == 0x8 then -- Close frame
      self:close()
      return nil, 'Connection closed by server'
    elseif opcode == 0x9 then -- Ping frame
      return self:receive_frame()
    elseif opcode == 0xA then -- Pong frame
      return self:receive_frame()
    end

    return payload
  end

  return ws
end

local WebSocket = {}

---Connect to a WebSocket server
---@param host string Server hostname (default: 'localhost')
---@param port number|string Server port (default: 80)
---@return table|nil websocket WebSocket client or nil on error
---@return string? error Error message on failure
function WebSocket.connect(host, port)
  host = host or 'localhost'
  port = port or 80

  local sock = socket.tcp()
  sock:settimeout(10)
  local success, err = sock:connect(host, port)
  if not success then
    return nil, 'Connection failed: ' .. (err or 'unknown error')
  end

  local key = generate_random_key()
  local handshake = create_handshake(host, port, key)

  if not sock:send(handshake) then
    sock:close()
    return nil, 'Failed to send handshake'
  end

  local success, err = verify_handshake(sock)
  if not success then
    sock:close()
    return nil, err
  end

  return create_websocket_client(sock)
end

return WebSocket
