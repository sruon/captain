-- Credits: Original Windower code by ibm2431, ported by sruon
---@class EventViewAddon : AddonInterface
---@field file { simple: file?, raw: file?, capture: { simple: file?, raw: file? }? }
local addon =
{
    name            = 'EventView',
    filters         =
    {
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_LOGIN]      = true,
            [PacketId.GP_SERV_COMMAND_EVENT]      = true,
            [PacketId.GP_SERV_COMMAND_EVENTNUM]   = true,
            [PacketId.GP_SERV_COMMAND_PENDINGNUM] = true,
            [PacketId.GP_SERV_COMMAND_TALKNUM]    = true,
        },

        outgoing =
        {
            [PacketId.GP_CLI_COMMAND_EVENTEND] = true,
        }
    },
    settings        = {},
    defaultSettings =
    {
        color =
        {
            actor        = ColorEnum.Lavender, -- 01234567 (Name)
            event        = ColorEnum.White,    -- 123
            event_header = ColorEnum.SoftBlue, -- CS Event (0x032), CS Event + Params (0x034)
            event_option = ColorEnum.Tan,      -- Event Option (0x05B)
            event_update = ColorEnum.Tan,      -- Event Update (0x05C)
            incoming     = ColorEnum.Purple,   -- INCOMING
            message      = ColorEnum.White,    -- 12345
            npc_chat     = ColorEnum.Slate,    -- NPC Chat (0x036)
            option       = ColorEnum.Seafoam,  -- 1
            outgoing     = ColorEnum.Purple,   -- OUTGOING
            params       = ColorEnum.Seafoam,  -- 0, 1, 2, 3, 4, 5, 6, 7
            system       = ColorEnum.Purple,
        }
    },
    file            =
    {
        simple  = nil,
        raw     = nil,
        capture = nil,
    }
}

---------------------------------------------------------------------------------
-- METHODS
---------------------------------------------------------------------------------

-- Sets up tables and files for use in the current zone
--------------------------------------------------
local function setupZone(zone, _)
    local current_zone = backend.zone_name(zone)
    addon.file.simple = backend.fileOpen(addon.rootDir ..
        backend.player_name() .. '/simple/' .. current_zone .. '.log')
    addon.file.raw = backend.fileOpen(addon.rootDir ..
        backend.player_name() .. '/raw/' .. current_zone .. '.log')

    if captain.isCapturing then
        addon.file.capture.simple = backend.fileOpen(addon.captureDir .. 'simple/' .. current_zone .. '.log')
        addon.file.capture.raw = backend.fileOpen(addon.captureDir .. 'raw/' .. current_zone .. '.log')
    end
end

-- Builds a colorized chatlog string
--------------------------------------------------
local function buildChatlogString(info)
    local packet_type = addon.packets[info.id]
    local chatlog_string = addon.h.eventview

    local chatlog_info = packet_type.string_params(info)
    if chatlog_info[1] == info.actor then
        chatlog_info[1] = string.gsub(chatlog_info[1], ' ', ' ' .. addon.color.log.ACTOR)
    end
    if info.param_string then
        if chatlog_info[1] == info.param_string then
            chatlog_info[1] = string.gsub(chatlog_info[1], ' ', ' ' .. addon.color.log.PARAMS)
        elseif chatlog_info[3] == info.param_string then
            chatlog_info[3] = string.gsub(chatlog_info[3], ' ', ' ' .. addon.color.log.PARAMS)
        end
    end

    if info.dir == 'OUTGOING >' then
        chatlog_string = chatlog_string .. addon.color.log.OUTGOING .. info.dir .. ' '
    else
        chatlog_string = chatlog_string .. addon.color.log.INCOMING .. info.dir .. ' '
    end
    chatlog_string = chatlog_string .. packet_type.log_color .. packet_type.text .. packet_type.log_string

    chatlog_string = string.format(chatlog_string, unpack(chatlog_info))
    return chatlog_string
end

-- Builds a simple string for file logging
--------------------------------------------------
local function buildSimpleString(info)
    local packet_type = addon.packets[info.id]
    local simple_info = packet_type.string_params(info)

    -- Sanitize values
    for i = 1, #simple_info do
        local v = simple_info[i]
        if v == nil then
            simple_info[i] = "<nil>"
        elseif type(v) ~= "string" and type(v) ~= "number" then
            simple_info[i] = tostring(v)
        end
    end

    local fstring = info.dir .. ' ' .. packet_type.text .. packet_type.simple_string
    return string.format(fstring, unpack(simple_info))
end

-- Checks incoming chunks for event CSes or NPC chats and logs them
--------------------------------------------------
local function checkChunk(dir, id, data)
    local in_event = false
    if addon.packets[id] and (addon.packets[id].dir == dir) then
        local update_packet = {}
        local info = {
            id = id,
            dir = dir
        }
        if id == PacketId.GP_SERV_COMMAND_WPOS then
            update_packet = backend.parsePacket('outgoing', data)
            in_event = false
        else
            update_packet = backend.parsePacket('incoming', data)
        end

        if id == PacketId.GP_SERV_COMMAND_LOGIN and not (update_packet.EventNum > 0) then
            return
        end


        info.actor = update_packet.UniqueNo

        if info.actor then
            if id == PacketId.GP_SERV_COMMAND_LOGIN then
                info.actor = info.actor .. ' (' .. backend.zone_name(info.actor) .. ')'
            else
                local mob = backend.get_mob_by_index(update_packet.ActIndex)
                if mob and mob.name then
                    info.actor = info.actor .. ' (' .. mob.name .. ')'
                end
            end
        end

        if update_packet.MesNum then
            info.message = tostring(update_packet.MesNum)
        elseif update_packet.EndPara then
            in_event = false
            info.option = tostring(update_packet.EndPara)
            info.event = string.format('%X', tonumber(update_packet.EventPara, 16))
        else
            in_event = true

            if update_packet.EventPara then
                info.event = string.format('%X', tonumber(update_packet.EventPara, 16))
            end
            if update_packet.num then
                if (not update_packet['Menu Zone']) or (update_packet['Menu Zone'] <= 0) then
                    local t = {}
                    for i, v in ipairs(update_packet.num) do
                        info['p' .. i] = v
                        table.insert(t, v)
                    end

                    info.params = t
                    info.param_string = table.concat(t, ", ")
                end
            elseif id ~= PacketId.GP_SERV_COMMAND_EVENT then
                info.params = update_packet.EventNum
                if update_packet['EventPara'] then
                    info.param_string = '' .. update_packet.EventPara
                elseif update_packet['num'] then
                    local t = {}
                    for _, v in ipairs(update_packet.num) do
                        info['p' .. i] = v
                        table.insert(t, v)
                    end

                    info.param_string = table.concat(t, ", ")
                end
            end
        end

        local simple_string = buildSimpleString(info)
        backend.fileAppend(addon.file.simple, simple_string .. "\n\n")
        backend.fileAppend(addon.file.raw, simple_string .. '\n' .. string.hexformat_file(data, #data) .. '\n')

        if captain.isCapturing then
            backend.fileAppend(addon.file.capture.simple, simple_string .. "\n\n")
            backend.fileAppend(addon.file.capture.raw,
                simple_string .. '\n' .. data:hexformat_file(#data) .. '\n')
        end

        backend.msg('EView', buildChatlogString(info))
        local packet_type = addon.packets[info.id]
        local template = packet_type.template
        local copy = {}
        for i = 1, #packet_type.template do
            copy[i] = template[i]
        end
        -- Insert header in template, in reverse order
        table.insert(copy, 1, { newline = true })
        table.insert(copy, 1, { color = packet_type.box_color, text = packet_type.text, padRight = 31 })
        table.insert(copy, 1, { color = addon.color.box.SYSTEM, text = packet_type.dir .. ' ' })
        backend.boxCreate(copy, info, in_event)
    end
end

---------------------------------------------------------------------------------
-- INITIALIZE
---------------------------------------------------------------------------------
local function initialize(rootDir)
    ---------------------------------------------------------------------------------
    -- DISPLAY COLORS AND LOG HEADERS
    ---------------------------------------------------------------------------------

    addon.color        = {}
    addon.color.log    =
    { -- Preformatted character codes for log colors.
        SYSTEM       = colors[addon.settings.color.system].chatColorCode,
        INCOMING     = colors[addon.settings.color.incoming].chatColorCode,
        OUTGOING     = colors[addon.settings.color.outgoing].chatColorCode,
        EVENT_HEADER = colors[addon.settings.color.event_header].chatColorCode,
        EVENT_OPTION = colors[addon.settings.color.event_option].chatColorCode,
        EVENT_UPDATE = colors[addon.settings.color.event_update].chatColorCode,
        NPC_CHAT     = colors[addon.settings.color.npc_chat].chatColorCode,
        ACTOR        = colors[addon.settings.color.actor].chatColorCode,
        EVENT        = colors[addon.settings.color.event].chatColorCode,
        OPTION       = colors[addon.settings.color.option].chatColorCode,
        MESSAGE      = colors[addon.settings.color.message].chatColorCode,
        PARAMS       = colors[addon.settings.color.params].chatColorCode,
    }
    addon.color.box    =
    { -- \\cs(#,#,#) values for Windower text boxes
        SYSTEM       = colors[addon.settings.color.system].rgb,
        INCOMING     = colors[addon.settings.color.incoming].rgb,
        OUTGOING     = colors[addon.settings.color.outgoing].rgb,
        EVENT_HEADER = colors[addon.settings.color.event_header].rgb,
        EVENT_OPTION = colors[addon.settings.color.event_option].rgb,
        EVENT_UPDATE = colors[addon.settings.color.event_update].rgb,
        NPC_CHAT     = colors[addon.settings.color.npc_chat].rgb,
        ACTOR        = colors[addon.settings.color.actor].rgb,
        EVENT        = colors[addon.settings.color.event].rgb,
        OPTION       = colors[addon.settings.color.option].rgb,
        MESSAGE      = colors[addon.settings.color.message].rgb,
        PARAMS       = colors[addon.settings.color.params].rgb,
    }

    addon.h            =
    { -- Headers for log string. ex: NPC:
        eventview = addon.color.log.SYSTEM,
        actor     = addon.color.log.SYSTEM .. 'NPC: ' .. addon.color.log.ACTOR,
        event     = addon.color.log.SYSTEM .. 'Event: ' .. addon.color.log.EVENT,
        option    = addon.color.log.SYSTEM .. 'Option: ' .. addon.color.log.OPTION,
        message   = addon.color.log.SYSTEM .. 'Message: ' .. addon.color.log.MESSAGE,
        params    = addon.color.log.SYSTEM .. 'Params: ' .. addon.color.log.PARAMS,
        zone      = addon.color.log.SYSTEM .. 'Zone: ' .. addon.color.log.ACTOR,
    }

    ---------------------------------------------------------------------------------
    -- VARIABLES AND TEMPLATES
    ---------------------------------------------------------------------------------
    addon.rootDir      = rootDir
    addon.file         = {}
    addon.file.capture = {}
    addon.file.simple  = backend.fileOpen(addon.rootDir .. backend.player_name() .. '/logs/simple.log')
    addon.file.raw     = backend.fileOpen(addon.rootDir .. backend.player_name() .. '/logs/raw.log')

    ---------------------------------------------------------------------------------
    -- PACKET PARSING INFORMATION
    ---------------------------------------------------------------------------------

    addon.packets      = {
        [PacketId.GP_SERV_COMMAND_LOGIN] = {
            dir = 'INCOMING <',
            text = 'Zone CS (0x00A): ',
            box_color = addon.color.box.EVENT_HEADER,
            log_color = addon.color.log.EVENT_HEADER,
            log_string = addon.h.zone .. '%s, ' .. addon.h.event .. '%s\n',
            simple_string = ' Zone: %s\nEvent: %s',
            string_params = function(info) return { [1] = info.actor, [2] = info.event } end,
            template =
            {
                { color = addon.color.box.SYSTEM, text = "Event: " },
                { color = addon.color.box.PARAMS, text = "${event|%s}", padLeft = 6 },
                { newline = true },
                { color = addon.color.box.SYSTEM, text = "Zone: " },
                { color = addon.color.box.PARAMS, text = "${actor|%s}" },
                { newline = true },
            },
        },
        [PacketId.GP_SERV_COMMAND_EVENT] = {
            dir = 'INCOMING <',
            text = 'CS Event (0x032): ',
            box_color = addon.color.box.EVENT_HEADER,
            log_color = addon.color.log.EVENT_HEADER,
            log_string = addon.h.actor .. '%s, ' .. addon.h.event .. '%s\n',
            simple_string = ' NPC: %s\nEvent: %s',
            string_params = function(info) return { [1] = info.actor, [2] = info.event } end,
            template =
            {
                { color = addon.color.box.SYSTEM, text = "Event: " },
                { color = addon.color.box.PARAMS, text = "${event|%s}", padLeft = 6 },
                { color = addon.color.box.SYSTEM, text = " Actor: " },
                { color = addon.color.box.PARAMS, text = "${actor|%s}", padLeft = 8 },
                { newline = true },
            },
        },
        [PacketId.GP_SERV_COMMAND_EVENTNUM] = {
            dir = 'INCOMING <',
            text = 'CS Event + Params (0x034): ',
            box_color = addon.color.box.EVENT_HEADER,
            log_color = addon.color.log.EVENT_HEADER,
            log_string = addon.h.actor .. '%s, ' .. addon.h.event .. '%s, ' .. addon.h.params .. '%s',
            simple_string = ' NPC: %s\nEvent: %s\nParams: %s',
            string_params = function(info) return { [1] = info.actor, [2] = info.event, [3] = info.param_string } end,
            template =
            {
                { color = addon.color.box.SYSTEM, text = "Event: " },
                { color = addon.color.box.PARAMS, text = "${event|%s}", padLeft = 6 },
                { color = addon.color.box.SYSTEM, text = " Actor: " },
                { color = addon.color.box.PARAMS, text = "${actor|%s}", padLeft = 8 },
                { newline = true },
                { color = addon.color.box.SYSTEM, text = "P: " },
                { color = addon.color.box.PARAMS, text = "${p1|%d}",    padLeft = 11 },
                { color = addon.color.box.PARAMS, text = "${p2|%d}",    padLeft = 11 },
                { color = addon.color.box.PARAMS, text = "${p3|%d}",    padLeft = 11 },
                { color = addon.color.box.PARAMS, text = "${p4|%d}",    padLeft = 11 },
                { newline = true },
                { text = '   ' },
                { color = addon.color.box.PARAMS, text = "${p5|%d}",    padLeft = 11 },
                { color = addon.color.box.PARAMS, text = "${p6|%d}",    padLeft = 11 },
                { color = addon.color.box.PARAMS, text = "${p7|%d}",    padLeft = 11 },
                { color = addon.color.box.PARAMS, text = "${p8|%d}",    padLeft = 11 },
                { newline = true },
            },
        },
        [PacketId.GP_SERV_COMMAND_PENDINGNUM] = {
            dir = 'INCOMING <',
            text = 'Event Update (0x05C): ',
            box_color = addon.color.box.EVENT_UPDATE,
            log_color = addon.color.log.EVENT_UPDATE,
            log_string = addon.h.params .. '%s',
            simple_string = ' \nParams: %s',
            string_params = function(info) return { [1] = info.param_string } end,
            template =
            {
                { color = addon.color.box.SYSTEM, text = "P: " },
                { color = addon.color.box.PARAMS, text = "${p1|%d}", padLeft = 11 },
                { color = addon.color.box.PARAMS, text = "${p2|%d}", padLeft = 11 },
                { color = addon.color.box.PARAMS, text = "${p3|%d}", padLeft = 11 },
                { color = addon.color.box.PARAMS, text = "${p4|%d}", padLeft = 11 },
                { newline = true },
                { text = '   ' },
                { color = addon.color.box.PARAMS, text = "${p5|%d}", padLeft = 11 },
                { color = addon.color.box.PARAMS, text = "${p6|%d}", padLeft = 11 },
                { color = addon.color.box.PARAMS, text = "${p7|%d}", padLeft = 11 },
                { color = addon.color.box.PARAMS, text = "${p8|%d}", padLeft = 11 },
                { newline = true },
            },
        },
        [PacketId.GP_SERV_COMMAND_TALKNUM] = {
            dir = 'INCOMING <',
            text = 'NPC Chat (0x036): ',
            box_color = addon.color.box.NPC_CHAT,
            log_color = addon.color.log.NPC_CHAT,
            log_string = addon.h.actor .. '%s, ' .. addon.h.message .. '%s',
            simple_string = ' NPC: %s\nMessage: %s',
            string_params = function(info) return { [1] = info.actor, [2] = info.message } end,
            template =
            {
                { color = addon.color.box.SYSTEM, text = " Actor: " },
                { color = addon.color.box.PARAMS, text = "${actor|%s}",   padLeft = 8 },
                { newline = true },
                { color = addon.color.box.SYSTEM, text = "Message: " },
                { color = addon.color.box.PARAMS, text = "${message|%s}", padLeft = 5 },
                { newline = true },
            },
        },
        [PacketId.GP_CLI_COMMAND_EVENTEND] = {
            dir = 'OUTGOING >',
            text = 'Event Option (0x05B): ',
            box_color = addon.color.box.EVENT_OPTION,
            log_color = addon.color.log.EVENT_OPTION,
            log_string = addon.h.actor .. '%s, ' .. addon.h.event .. '%s, ' .. addon.h.option .. '%s',
            simple_string = ' NPC: %s\nEvent: %s\nOption: %s',
            string_params = function(info) return { [1] = info.actor, [2] = info.event, [3] = info.option } end,
            template =
            {
                { color = addon.color.box.SYSTEM, text = "Event: " },
                { color = addon.color.box.PARAMS, text = "${event|%s}",  padLeft = 6 },
                { color = addon.color.box.SYSTEM, text = " Actor: " },
                { color = addon.color.box.PARAMS, text = "${actor|%s}",  padLeft = 8 },
                { newline = true },
                { color = addon.color.box.SYSTEM, text = "Option: " },
                { color = addon.color.box.PARAMS, text = "${option|%s}", padLeft = 5 },
                { newline = true },
            },
        },
    }

    setupZone(backend.zone())
end

addon.onZoneChange = setupZone

addon.onIncomingPacket = function(id, data)
    checkChunk('INCOMING <', id, data)
end

addon.onOutgoingPacket = function(id, data)
    checkChunk('OUTGOING >', id, data)
end

addon.onCaptureStart = function(captureDir)
    addon.captureDir          = captureDir
    addon.file.capture.simple = backend.fileOpen(captureDir .. 'simple.log')
    addon.file.capture.raw    = backend.fileOpen(captureDir .. 'raw.log')
end

addon.onCaptureStop = function()
    addon.captureDir          = nil
    addon.file.capture.simple = nil
    addon.file.capture.raw    = nil
end

addon.onInitialize = initialize

return addon
