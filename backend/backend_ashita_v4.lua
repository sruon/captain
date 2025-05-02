-- Docs:
-- https://github.com/AshitaXI/Ashita-v4beta/blob/main/plugins/sdk/Ashita.h
-- https://github.com/AshitaXI/Ashita-v4beta/tree/main/addons
-- https://github.com/AshitaXI/example/blob/main/example.lua
---@type any
ashita = ashita
---@type any
AshitaCore = AshitaCore
---@type any
addon = addon

---@type Ashitav4Backend
local backend = {}

require('common')
local chat                             = require('chat')
local imgui                            = require('imgui')
local settings                         = require('settings')
local scaling                          = require('scaling')

local WHITE                            = { 1.0, 1.0, 1.0, 1.0 }
local CORAL                            = { 1.0, 0.65, 0.26, 1.0 }

local gui                              = {}

--------------------------------
-- Event hooks
-- https://docs.ashitaxi.com/dev/addons/events/
--------------------------------
backend.register_event_load            = function(func)
    ashita.events.register('load', 'load_cb', func)
end

backend.register_event_unload          = function(func)
    ashita.events.register('unload', 'unload_cb', func)
end

backend.register_command               = function(func)
    ashita.events.register('command', 'command_cb', function(e)
        local args = e.command:args()
        if
            #args < 1
        then
            return
        end

        for _, c in ipairs(addon.commands) do
            if args[1] == string.format('/%s', c) then
                local strippedArgs = { unpack(args, 2) }
                func(strippedArgs)
            end
        end
    end)
end

backend.register_event_incoming_packet = function(func)
    local adaptor = function(e)
        -- id, data, size
        func(e.id, e.data, e.size)
        return false
    end
    ashita.events.register('packet_in', 'packet_in_cb', adaptor)
end

backend.register_event_outgoing_packet = function(func)
    local adaptor = function(e)
        -- id, data, size
        func(e.id, e.data, e.size)
        return false
    end
    ashita.events.register('packet_out', 'packet_out_cb', adaptor)
end

backend.register_on_zone_change        = function(func)
    local adaptor = function(e)
        if (e.id == PacketId.GP_SERV_COMMAND_LOGIN) then
            local zonePacket = backend.parsePacket('incoming', e.data)
            func(zonePacket.ZoneNo)
        end
    end
    ashita.events.register('packet_in', 'packet_in_zone_cb', adaptor)
end

-- from logs addon
local cleanStr                         = function(str)
    -- Parse the strings auto-translate tags..
    str = AshitaCore:GetChatManager():ParseAutoTranslate(str, true);

    -- Strip FFXI-specific color and translate tags..
    str = str:strip_colors();
    str = str:strip_translate(true);

    -- Strip line breaks..
    while (true) do
        local hasN = str:endswith('\n');
        local hasR = str:endswith('\r');

        if (not hasN and not hasR) then
            break;
        end

        if (hasN) then str = str:trimend('\n'); end
        if (hasR) then str = str:trimend('\r'); end
    end

    -- Replace mid-linebreaks..
    return (str:gsub(string.char(0x07), '\n'));
end

backend.register_event_incoming_text   = function(func)
    local adaptor = function(e)
        -- mode, text
        func(e.mode, cleanStr(e.message))
        return false
    end
    ashita.events.register('text_in', 'text_in_cb', adaptor)
end

backend.register_event_prerender       = function(func)
    local customFont = backend.fontGet(backend.getSetting('box.text.font', 'Consolas'),
        backend.scale_font(backend.getSetting('box.text.size', 16)))

    local adaptor = function()
        imgui.PushFont(customFont)
        func()

        local flags = bit.bor(
            ImGuiWindowFlags_NoDecoration,
            ImGuiWindowFlags_AlwaysAutoResize,
            ImGuiWindowFlags_NoSavedSettings,
            ImGuiWindowFlags_NoFocusOnAppearing,
            ImGuiWindowFlags_NoNav)

        for _, box in pairs(gui) do
            imgui.SetNextWindowBgAlpha(0.6)
            imgui.SetNextWindowSize({ -1, -1, }, ImGuiCond_Always)
            imgui.SetNextWindowSizeConstraints({ -1, -1, }, { FLT_MAX, FLT_MAX, })

            if box.text ~= nil and box.visible and imgui.Begin(box.name, true, flags) then
                if box.title then
                    imgui.TextColored(CORAL, box.title)
                    imgui.Separator()
                end
                imgui.TextUnformatted(box.text)
                imgui.End()
            end
        end

        imgui.PopFont()
    end
    ashita.events.register('d3d_present', 'present_cb', adaptor)
end

--------------------------------
-- File IO
--------------------------------
backend.dir_exists                     = function(path)
    return ashita.fs.exists(path)
end

backend.file_exists                    = function(path)
    return ashita.fs.exists(path)
end

backend.create_dir                     = function(filename)
    ashita.fs.create_dir(filename)
end

backend.list_files                     = function(relPath)
    local path = addon.path .. relPath
    return ashita.fs.get_dir(path, '.*', true)
end

--------------------------------
-- Text Display
--------------------------------
textBoxIdCounter                       = 0

backend.textBox                        = function(_)
    local box = {}
    box.name = '' .. textBoxIdCounter
    box.title = nil
    box.text = nil
    box.visible = true

    textBoxIdCounter = textBoxIdCounter + 1

    box.show = function(self)
        self.visible = true
    end

    box.hide = function(self)
        self.visible = false
    end

    box.updateTitle = function(self, str)
        self.title = str or ''
    end

    box.updateText = function(self, str)
        self.text = str or ''
    end

    table.insert(gui, box)

    return box
end

--------------------------------
-- Misc
--------------------------------
backend.script_path                    = function()
    local path = addon.path

    path = string.gsub(path, '\\', '/')
    path = string.gsub(path, '//', '/')

    return path
end

backend.msg                            = function(header, message)
    print(chat.header(header):append(chat.message(message)))
end

backend.player_name                    = function()
    local player = GetPlayerEntity()
    if player ~= nil then
        return player.Name
    end
    return "Unknown"
end

backend.zone                           = function()
    local entityData = backend.get_player_entity_data()
    if entityData == nil then
        return 0
    end

    return entityData.zoneID
end

backend.zone_name                      = function(zone)
    local zoneId = zone or backend.zone()

    return AshitaCore:GetResourceManager():GetString('zones.names', zoneId)
end

backend.target_index                   = function()
    return AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(0)
end

backend.target_name                    = function()
    local index = backend.target_index()
    local target = GetEntity(index)

    if target == nil then
        return "Unknown"
    end

    return target.Name
end

backend.target_hpp                     = function()
    local index = backend.target_index()
    local target = GetEntity(index)

    if target == nil then
        return 0
    end

    return target.HPPercent
end

backend.get_player_entity_data         = function()
    local entity = AshitaCore:GetMemoryManager():GetEntity()
    local party = AshitaCore:GetMemoryManager():GetParty()
    local player = AshitaCore:GetMemoryManager():GetPlayer()
    local index = party:GetMemberTargetIndex(0)

    local playerZoneID = party:GetMemberZone(0)

    local playerEntityData =
    {
        name = party:GetMemberName(0),
        serverId = party:GetMemberServerId(0),
        mJob = AshitaCore:GetResourceManager():GetString("jobs.names_abbr", player:GetMainJob()),
        sJob = AshitaCore:GetResourceManager():GetString("jobs.names_abbr", player:GetSubJob()),
        mJobLevel = player:GetMainJobLevel(),
        sJobLevel = player:GetSubJobLevel(),
        zoneID = playerZoneID,
        zoneName = AshitaCore:GetResourceManager():GetString('zones.names', playerZoneID),
        targIndex = index,
        x = string.format('%+08.03f', entity:GetLocalPositionX(index)),
        y = string.format('%+08.03f', entity:GetLocalPositionY(index)),
        z = string.format('%+08.03f', entity:GetLocalPositionZ(index)),
        r = string.format('%03d', utils.headingToByteRotation(entity:GetLocalPositionYaw(index))),
    }
    return playerEntityData
end

backend.get_target_entity_data         = function()
    local target = GetEntity(AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(0))
    if target == nil then
        return nil
    end

    local index = AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(0)
    local targetEntityData =
    {
        name = AshitaCore:GetMemoryManager():GetEntity():GetName(index),
        serverId = AshitaCore:GetMemoryManager():GetEntity():GetServerId(index),
        targIndex = index,
        x = string.format('%+08.03f', AshitaCore:GetMemoryManager():GetEntity():GetLocalPositionX(index)),
        y = string.format('%+08.03f', AshitaCore:GetMemoryManager():GetEntity():GetLocalPositionY(index)),
        z = string.format('%+08.03f', AshitaCore:GetMemoryManager():GetEntity():GetLocalPositionZ(index)),
        r = utils.headingToByteRotation(AshitaCore:GetMemoryManager():GetEntity():GetLocalPositionYaw(index)),
    }
    return targetEntityData
end

backend.get_monster_ability_name       = function(id)
    return AshitaCore:GetResourceManager():GetString("monsters.abilities", id - 256):gsub('%z', '')
end

backend.get_job_ability_name           = function(id)
    local a = AshitaCore:GetResourceManager():GetAbilityById(id + 0x200)
    return (a and a.Name[1]) or 'Unknown Ability'
end

backend.get_weapon_skill_name          = function(id)
    local a = AshitaCore:GetResourceManager():GetAbilityById(id)
    return (a and a.Name[1]) or 'Unknown Weaponskill'
end

backend.get_spell_name                 = function(id)
    local s = AshitaCore:GetResourceManager():GetSpellById(id)
    return (s and s.Name[1]) or 'Unknown Spell'
end

backend.get_item_name                  = function(id)
    local s = AshitaCore:GetResourceManager():GetItemById(id)
    return (s and s.Name[1]) or 'Unknown Item'
end

backend.get_mob_by_index               = function(index)
    local mgr = AshitaCore:GetMemoryManager()
    local e = mgr:GetEntity(index)
    if e then
        local targetEntityData =
        {
            name      = e:GetName(index),
            serverId  = e:GetServerId(index),
            targIndex = index,
            x         = string.format('%+08.03f', e:GetLocalPositionX(index)),
            y         = string.format('%+08.03f', e:GetLocalPositionY(index)),
            z         = string.format('%+08.03f', e:GetLocalPositionZ(index)),
            r         = utils.headingToByteRotation(e:GetLocalPositionYaw(index)),
            hpp       = e:GetHPPercent(index),
        }

        return targetEntityData
    end

    return nil
end

backend.get_mob_by_id                  = function(id)
    local mgr = AshitaCore:GetMemoryManager()
    local target
    local tIdx = 0
    for x = 0, 2302 do
        local e = mgr:GetEntity(x);
        if (e and e:GetServerId(x) == id) then
            target = e;
            tIdx = x;
        end
    end

    if target == nil then
        return nil
    end

    local targetEntityData =
    {
        name      = target:GetName(tIdx),
        serverId  = target:GetServerId(tIdx),
        targIndex = tIdx,
        x         = string.format('%+08.03f', target:GetLocalPositionX(tIdx)),
        y         = string.format('%+08.03f', target:GetLocalPositionY(tIdx)),
        z         = string.format('%+08.03f', target:GetLocalPositionZ(tIdx)),
        r         = utils.headingToByteRotation(target:GetLocalPositionYaw(tIdx)),
        hpp       = target:GetHPPercent(tIdx),
    }

    return targetEntityData
end

backend.schedule                       = function(func, delay)
    ashita.tasks.once(delay, func)
end

-- sugar.loop does not support early exits
backend.forever                        = function(func, delay, ...)
    local args = { ... }

    ashita.tasks.once(0, function()
        while not captain.reloadSignal do
            func(table.unpack(args))

            local slept = 0
            while slept < delay and not captain.reloadSignal do
                coroutine.sleep(1)
                slept = slept + 1
            end
        end
    end)
end

backend.convert_int_to_float           = function(raw)
    return string.unpack("f", string.pack("I4", raw))
end

--------------------------------
-- Packets
--------------------------------
--------------------------------
-- Injects a widescan request packet
--------------------------------
backend.doWidescan                     = function()
    backend.injectPacket(PacketId.GP_CLI_COMMAND_TRACKING_LIST,
        { PacketId.GP_CLI_COMMAND_TRACKING_LIST, 0x04, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00 })
end

--------------------------------
-- Adds an arbitrary packet to the outgoing queue
--------------------------------
backend.injectPacket                   = function(id, content)
    AshitaCore:GetPacketManager():AddOutgoingPacket(id, content);
end

backend.registerKeyBind                = function(params, command)
    local kb = AshitaCore:GetInputManager():GetKeyboard()
    if not command:startswith("/") then
        command = "/" .. command
    end

    kb:Bind(
        kb:S2D(params.key),
        params.down and params.down or false,
        params.alt and params.alt or false,
        params.apps and params.apps or false,
        params.ctrl and params.ctrl or false,
        params.shift and params.shift or false,
        params.win and params.win or false,
        command
    )
end

backend.deregisterKeyBind              = function(params)
    local kb = AshitaCore:GetInputManager():GetKeyboard()
    kb:Unbind(
        kb:S2D(params.key),
        params.down and params.down or false,
        params.alt and params.alt or false,
        params.apps and params.apps or false,
        params.ctrl and params.ctrl or false,
        params.shift and params.shift or false,
        params.win and params.win or false
    )
end

backend.loadConfig                     = function(name, defaults)
    return settings.load(T(defaults) or T {}, name)
end

backend.saveConfig                     = function(name)
    return settings.save(name)
end

local fontCache                        = {}

backend.fontGet                        = function(fontName, fontSize)
    local key = fontName .. '_' .. fontSize
    if not fontCache[key] then
        local path = string.format('%s/fonts/%s.ttf', addon.path, fontName)
        fontCache[key] = imgui.AddFontFromFileTTF(path, fontSize)
    end

    return fontCache[key]
end

backend.boxDraw                        = function(box)
    local flags = bit.bor(
        ImGuiWindowFlags_NoDecoration,
        ImGuiWindowFlags_NoSavedSettings,
        ImGuiWindowFlags_NoFocusOnAppearing,
        ImGuiWindowFlags_NoNav
    )
    imgui.SetNextWindowPos({ box.x, box.y }, ImGuiCond_Always)

    imgui.SetNextWindowBgAlpha(box.bg.alpha / 255)

    local font_size = imgui.GetFontSize()
    local style = imgui.GetStyle()

    local avg_char_width = font_size * 0.55
    local line_height = font_size + style.ItemSpacing.y
    local width = (box.max_chars_per_line or 60) * avg_char_width + 8

    local line_count = 1
    for _, segment in ipairs(box.segments) do
        if segment.newline then
            line_count = line_count + 1
        end
    end

    local height = (box.max_lines or 5) * line_height

    imgui.SetNextWindowSize({ width, height }, ImGuiCond_Always)

    if imgui.Begin('##' .. box.id, true, flags) then
        imgui.PushStyleColor(ImGuiCol_WindowBg,
            { box.bg.red / 255, box.bg.green / 255, box.bg.blue / 255, box.bg.alpha / 255 })

        if imgui.IsWindowHovered() and imgui.IsMouseDragging(0) then
            local delta_x, delta_y = imgui.GetMouseDragDelta(0)

            -- Automatically save the new position
            backend.setSetting('box.pos.x', backend.getSetting('box.pos.x', 0) + delta_x)
            backend.setSetting('box.pos.y', backend.getSetting('box.pos.y', 0) + delta_y)
            backend.saveConfig('captain')

            imgui.ResetMouseDragDelta(0)
        end

        imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { style.ItemSpacing.x, 4 })

        local first_in_line = true
        for _, segment in ipairs(box.segments) do
            if segment.newline then
                imgui.Spacing()
                first_in_line = true
            elseif segment.text then
                if not first_in_line then
                    imgui.SameLine(0, 0)
                end
                if segment.color then
                    imgui.PushStyleColor(ImGuiCol_Text, {
                        segment.color[1] / 255,
                        segment.color[2] / 255,
                        segment.color[3] / 255,
                        1
                    })
                else
                    imgui.PushStyleColor(ImGuiCol_Text, WHITE)
                end

                imgui.TextUnformatted(segment.text)
                imgui.PopStyleColor()
                first_in_line = false
            end
        end

        imgui.PopStyleVar()
        imgui.PopStyleColor()

        imgui.End()

        return height -- Use our known value
    end

    return 0
end

backend.scale_font                     = scaling.scale_f
backend.scale_width                    = scaling.scale_w
backend.scale_height                   = scaling.scale_h

backend.reload                         = function()
    captain.reloadSignal = true
    backend.msg('captain', 'Reloading. Coroutines may take a moment to finish.')
    AshitaCore:GetChatManager():QueueCommand(-1, "/addon reload captain")
end

return backend
