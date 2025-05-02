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
    str = AshitaCore:GetChatManager():ParseAutoTranslate(str, true)

    -- Strip FFXI-specific color and translate tags..
    str = str:strip_colors()
    str = str:strip_translate(true)

    -- Strip line breaks..
    while (true) do
        local hasN = str:endswith('\n')
        local hasR = str:endswith('\r')

        if (not hasN and not hasR) then
            break
        end

        if (hasN) then
            str = str:trimend('\n')
        end
        if (hasR) then
            str = str:trimend('\r')
        end
    end

    -- Replace mid-linebreaks..
    return (str:gsub(string.char(0x07), '\n'))
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
    local customFont = backend.fontGet('Consolas', backend.scale_font(captain.settings.box.text.size))

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
            imgui.SetNextWindowSize({ -1, -1 }, ImGuiCond_Always)
            imgui.SetNextWindowSizeConstraints({ -1, -1 }, { FLT_MAX, FLT_MAX })

            if box.text ~= nil and box.visible and imgui.Begin(box.name, true, flags) then
                -- Apply scaling to content
                imgui.SetWindowFontScale(captain.settings.textBox.scale)

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
local textBoxIdCounter                 = 0

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
    return 'Unknown'
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
        return 'Unknown'
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
        mJob = AshitaCore:GetResourceManager():GetString('jobs.names_abbr', player:GetMainJob()),
        sJob = AshitaCore:GetResourceManager():GetString('jobs.names_abbr', player:GetSubJob()),
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
    return AshitaCore:GetResourceManager():GetString('monsters.abilities', id - 256):gsub('%z', '')
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
        local e = mgr:GetEntity(x)
        if (e and e:GetServerId(x) == id) then
            target = e
            tIdx = x
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
    return string.unpack('f', string.pack('I4', raw))
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
    AshitaCore:GetPacketManager():AddOutgoingPacket(id, content)
end

backend.registerKeyBind                = function(params, command)
    local kb = AshitaCore:GetInputManager():GetKeyboard()
    if not command:startswith('/') then
        command = '/' .. command
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

backend.notificationsRender            = function(notifications)
    local vp_size =
    {
        x = AshitaCore:GetConfigurationManager():GetUInt32('boot', 'ffxi.registry', '0001', 800),
        y = AshitaCore:GetConfigurationManager():GetUInt32('boot', 'ffxi.registry', '0002', 600),
    }

    local NOTIFY_TOAST_FLAGS = bit.bor(
        ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoScrollbar,
        ImGuiWindowFlags_NoCollapse, ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoSavedSettings, ImGuiWindowFlags_NoFocusOnAppearing
    )

    local height = 0

    -- Push styles for the notifications
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 8, 8 })
    imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 2, 2 })
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { 4, 4 })

    -- Calculate width for uniform notifications
    local avg_char_width = imgui.GetFontSize() * 0.5
    local uniform_width = (80 * avg_char_width * captain.settings.notifications.scale) + 20

    -- Define colors
    local function normalizeColor(colorEnum, alpha)
        return
        {
            colors[colorEnum].rgb[1] / 255,
            colors[colorEnum].rgb[2] / 255,
            colors[colorEnum].rgb[3] / 255,
            alpha or 1.0,
        }
    end

    local KEY_COLOR = normalizeColor(captain.settings.notifications.colors.key)
    local VALUE_COLOR = normalizeColor(captain.settings.notifications.colors.value)
    local TITLE_COLOR = normalizeColor(captain.settings.notifications.colors.title)
    local WHITE_COLOR = { 1.0, 1.0, 1.0, 1.0 }
    local TRANSPARENT = { 0.0, 0.0, 0.0, 0.0 }

    local typeHandlers =
    {
        ['table'] = function(fieldName, value)
            local values = {}
            for i, v in ipairs(value) do table.insert(values, tostring(v)) end
            if #values == 0 then
                for k, v in pairs(value) do table.insert(values, tostring(k) .. '=' .. tostring(v)) end
            end
            return fieldName .. '[]', table.concat(values, ', ')
        end,

        ['nil'] = function(fieldName, _) return fieldName, 'nil' end,

        ['number'] = function(fieldName, value)
            return fieldName, math.floor(value) == value and tostring(value) or string.format('%.2f', value)
        end,

        ['string'] = function(fieldName, value)
            return fieldName, #value > 40 and value:sub(1, 37) .. '...' or value
        end,

        ['default'] = function(fieldName, value)
            local strValue = tostring(value)
            return fieldName, #strValue > 40 and strValue:sub(1, 37) .. '...' or strValue
        end,
    }

    local function processFieldValue(fieldName, value)
        local handler = typeHandlers[type(value)] or typeHandlers['default']
        return handler(fieldName, value)
    end

    -- Process notifications from newest to oldest
    for i = #notifications, 1, -1 do
        local toast = notifications[i]

        -- Prepare notification background
        local opacity = toast.bg.alpha / 255
        local bg_color =
        {
            toast.bg.red / 255, toast.bg.green / 255, toast.bg.blue / 255, opacity,
        }

        -- Position notification
        imgui.SetNextWindowPos(
            { vp_size.x - captain.settings.notifications.offset.x, vp_size.y - captain.settings.notifications.offset.y - height },
            ImGuiCond_Always, { 1.0, 1.0 }
        )

        -- Set window style
        imgui.PushStyleColor(ImGuiCol_WindowBg, bg_color)
        imgui.PushStyleColor(ImGuiCol_Border, TRANSPARENT)
        imgui.SetNextWindowSizeConstraints(
            { uniform_width, 0 }, { vp_size.x * 0.7, vp_size.y * 0.8 }
        )

        -- Create window
        if imgui.Begin(string.format('##TOAST%d', i), { true }, NOTIFY_TOAST_FLAGS) then
            imgui.SetWindowFontScale(captain.settings.notifications.scale)
            imgui.PushTextWrapPos(uniform_width)

            -- Handle dragging
            if imgui.IsWindowHovered() and imgui.IsMouseDragging(0) then
                local delta_x, delta_y = imgui.GetMouseDragDelta(0)
                captain.settings.notifications.offset.x = captain.settings.notifications.offset.x - delta_x
                captain.settings.notifications.offset.y = captain.settings.notifications.offset.y - delta_y
                backend.saveConfig('captain')
                imgui.ResetMouseDragDelta(0)
            end

            -- Render title
            imgui.TextColored(TITLE_COLOR, tostring(toast.title))
            imgui.Spacing()

            -- Render data if available
            if toast.data and type(toast.data) == 'table' then
                local max_line_width = uniform_width
                local current_line_width = 0
                local is_first_in_line = true
                local grouped_data = {}

                -- Preprocess data
                for i, pair in ipairs(toast.data) do
                    local key, value = processFieldValue(pair[1], pair[2])
                    local key_size = { imgui.CalcTextSize(key) }
                    local colon_size = { imgui.CalcTextSize(': ') }
                    local value_size = { imgui.CalcTextSize(value) }

                    table.insert(grouped_data,
                        {
                            key = key,
                            value = value,
                            width = key_size[1] + colon_size[1] + value_size[1] + 15,
                            orig_index = i,
                        })
                end

                -- Render data items
                for _, item in ipairs(grouped_data) do
                    local key, value, width = item.key, item.value, item.width
                    local is_array = key:match('%[%]$') ~= nil
                    local is_long_value = width > (max_line_width * 0.8)
                    local needs_new_line = (is_array or is_long_value) or
                      (not is_first_in_line and current_line_width + width > max_line_width)

                    -- Start new line if needed
                    if needs_new_line and not is_first_in_line then
                        imgui.Spacing()
                        current_line_width, is_first_in_line = 0, true
                    end

                    -- Add spacing between items on the same line
                    if not is_first_in_line then
                        imgui.SameLine()
                        imgui.TextUnformatted(' ')
                        imgui.SameLine()
                    end

                    -- Render key-value pair
                    imgui.TextColored(KEY_COLOR, key)
                    imgui.SameLine(0, 0)
                    imgui.TextColored(WHITE_COLOR, ': ')
                    imgui.SameLine(0, 2)
                    imgui.TextColored(VALUE_COLOR, value)

                    -- Update line state
                    if is_array or is_long_value then
                        imgui.Spacing()
                        current_line_width, is_first_in_line = 0, true
                    else
                        current_line_width = current_line_width + width
                        is_first_in_line = false
                    end
                end

                -- Final spacing if needed
                if not is_first_in_line then imgui.Spacing() end
            end

            imgui.PopTextWrapPos()
            height = height + imgui.GetWindowHeight() + captain.settings.notifications.spacing
            imgui.End()
        end

        imgui.PopStyleColor(2)
    end

    imgui.PopStyleVar(3)
    return height
end

backend.scale_font                     = scaling.scale_f
backend.scale_width                    = scaling.scale_w
backend.scale_height                   = scaling.scale_h

backend.reload                         = function()
    captain.reloadSignal = true
    backend.msg('captain', 'Reloading. Coroutines may take a moment to finish.')
    AshitaCore:GetChatManager():QueueCommand(-1, '/addon reload captain')
end

backend.configMenu                     = function()
    -- TODO: Refactor in a generic fashion closer to the actual settings
    if not captain.showConfig then
        return
    end

    -- Load defaults for reset buttons
    local defaults = require('data/defaults')

    local configurableValues =
    {
        {
            title = 'Notifications',
            entries =
            {
                {
                    title = 'Max',
                    path = 'notifications.max_num',
                    min = 3,
                    max = 10,
                    incr = 1,
                },
                {
                    title = 'Auto-hide delay',
                    path = 'notifications.hideDelay',
                    min = 1,
                    max = 10,
                    incr = 1,
                },
                {
                    title = 'Spacing',
                    path = 'notifications.spacing',
                    min = 0,
                    max = 20,
                    incr = 1,
                },
                {
                    title = 'Offset X (from bottom right)',
                    path = 'notifications.offset.x',
                    min = 0,
                    max = AshitaCore:GetConfigurationManager():GetUInt32('boot', 'ffxi.registry', '0001', 1920),
                    incr = 5,
                },
                {
                    title = 'Offset Y (from bottom right)',
                    path = 'notifications.offset.y',
                    min = 0,
                    max = AshitaCore:GetConfigurationManager():GetUInt32('boot', 'ffxi.registry', '0002', 1080),
                    incr = 5,
                },
                {
                    title = 'Scale',
                    path = 'notifications.scale',
                    min = 0.1,
                    max = 5,
                    incr = 0.05,
                },
            },
        },
        {
            title = 'TextBox',
            entries =
            {
                {
                    title = 'Scale',
                    path = 'textBox.scale',
                    min = 0.5,
                    max = 5,
                    incr = 0.1,
                },
            },
        },
    }

    local isOpen = { true }

    if imgui.Begin('captain Configuration', isOpen, ImGuiWindowFlags_AlwaysAutoResize) then
        if not isOpen[1] then
            captain.showConfig = false
        end

        if imgui.BeginTabBar('##captain_config_tabbar', ImGuiTabBarFlags_NoCloseWithMiddleMouseButton) then
            for i, configCategory in ipairs(configurableValues) do
                if imgui.BeginTabItem(configCategory.title) then
                    imgui.BeginGroup()
                    for j, configEntry in ipairs(configCategory.entries) do
                        local parts = {}
                        for part in string.gmatch(configEntry.path, '[^%.]+') do
                            table.insert(parts, part)
                        end

                        local settingRef = captain.settings
                        for k = 1, #parts - 1 do
                            settingRef = settingRef[parts[k]]
                        end

                        -- Get default value from defaults
                        local defaultRef = defaults
                        for k = 1, #parts do
                            defaultRef = defaultRef[parts[k]]
                        end

                        imgui.TextColored(CORAL, string.format('%s', configEntry.title))

                        local buffer = { settingRef[parts[#parts]] }
                        local controlID = string.format('##captain_setting_%s_%s',
                            configCategory.title:gsub(' ', '_'):lower(),
                            configEntry.title:gsub(' ', '_'):lower())

                        local isInteger = configEntry.incr == math.floor(configEntry.incr) and configEntry.incr == 1
                        local valueChanged = false

                        -- Use a relative width based on the window width
                        imgui.PushItemWidth(imgui.GetWindowWidth() * 0.8)

                        if isInteger then
                            valueChanged = imgui.SliderInt(
                                controlID,
                                buffer,
                                math.floor(configEntry.min),
                                math.floor(configEntry.max),
                                '%d',
                                ImGuiSliderFlags_AlwaysClamp
                            )
                        else
                            local format = '%.1f'
                            if configEntry.incr < 0.1 then
                                format = '%.2f'
                            elseif configEntry.incr < 0.01 then
                                format = '%.3f'
                            end

                            valueChanged = imgui.SliderFloat(
                                controlID,
                                buffer,
                                configEntry.min,
                                configEntry.max,
                                format,
                                ImGuiSliderFlags_AlwaysClamp
                            )
                        end

                        imgui.PopItemWidth()

                        if valueChanged then
                            settingRef[parts[#parts]] = buffer[1]
                            backend.saveConfig('captain')
                        end

                        -- Add reset button on the same line
                        imgui.SameLine()
                        local resetID = string.format('Reset##captain_reset_%s_%s',
                            configCategory.title:gsub(' ', '_'):lower(),
                            configEntry.title:gsub(' ', '_'):lower())

                        if imgui.Button(resetID) and defaultRef ~= nil then
                            settingRef[parts[#parts]] = defaultRef
                            backend.saveConfig('captain')
                        end

                        -- Show tooltip on hover
                        if imgui.IsItemHovered() and defaultRef ~= nil then
                            imgui.BeginTooltip()
                            imgui.Text(string.format('Reset to default: %s', tostring(defaultRef)))
                            imgui.EndTooltip()
                        end
                    end

                    imgui.EndGroup()
                    imgui.EndTabItem()
                end
            end

            imgui.EndTabBar()
        end

        imgui.End()
    else
        captain.showConfig = false
    end
end

return backend
