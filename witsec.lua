-- Witness Protection. Randomize names found in packets.
-- Credits: https://github.com/lili-ffxi/FFXI-Addons/blob/master/witnessprotection/witnessprotection.lua
local sha    = require('ffi.sha')
local witsec = {}

local function generateName(id)
    local hash = sha.sha256(tostring(id))
    local name = 'Player' .. hash:sub(1, 9)
    return name:sub(1, 15)
end

witsec.rewritePacket = function(id, data)
    if id == PacketId.GP_SERV_COMMAND_LOGIN then
        ---@type GP_SERV_COMMAND_LOGIN
        local loginPacket = backend.parsePacket('incoming', data)

        local name        = generateName(loginPacket.PosHead.UniqueNo)
        name              = name .. string.rep('\0', 16 - #name)
        data              = data:sub(1, 0x84) .. name .. data:sub(0x85 + 16)
        return data
    end

    if id == PacketId.GP_SERV_COMMAND_CHAR_PC then
        ---@type GP_SERV_COMMAND_CHAR_PC
        local pcPacket = backend.parsePacket('incoming', data)
        if not pcPacket.SendFlg.Name then
            return
        end

        local name = tostring(pcPacket.ActIndex)
        name       = name .. string.rep('\0', 16 - #name)
        data       = data:sub(1, 0x5A) ..
        name .. data:sub(0x5B + 16)                                   -- aware this doesn't line up but targid is 4 digits at most
        return data
    end

    return nil
end

return witsec
