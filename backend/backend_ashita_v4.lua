-- Docs:
-- https://github.com/AshitaXI/Ashita-v4beta/blob/main/plugins/sdk/Ashita.h
-- https://github.com/AshitaXI/Ashita-v4beta/tree/main/addons
-- https://github.com/AshitaXI/example/blob/main/example.lua
---@type any
ashita        = ashita
---@type any
AshitaCore    = AshitaCore
---@type any
addon         = addon

local backend = {}

require('common')
local chat                             = require('chat')
local imgui                            = require('imgui')
local settings                         = require('settings')

local CORAL                            = { 1.0, 0.65, 0.26, 1.0 }

local gui                              = {}

local ffi                              = require('ffi')
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
        local modifiedData      = nil
        e.blocked, modifiedData = func(e.id, e.data, e.size)

        -- Allow certain features to rewrite the packets
        if modifiedData then
            local buff = ffi.new('uint8_t[?]', #modifiedData)
            for i = 1, #modifiedData do
                buff[i - 1] = modifiedData:byte(i)
            end
            ffi.copy(e.data_modified_raw, buff, #modifiedData)
        end

        return e.blocked
    end

    ashita.events.register('packet_in', 'packet_in_cb', adaptor)
end

backend.register_event_outgoing_packet = function(func)
    local adaptor = function(e)
        e.blocked = func(e.id, e.data, e.size)
        return e.blocked
    end

    ashita.events.register('packet_out', 'packet_out_cb', adaptor)
end

backend.register_on_zone_change        = function(func)
    local incomingAdaptor = function(e)
        -- Track when zoning in
        if (e.id == PacketId.GP_SERV_COMMAND_LOGIN) then
            ---@type GP_SERV_COMMAND_LOGIN
            local zonePacket = backend.parsePacket('incoming', e.data)
            func(zonePacket.ZoneNo)
        end

        -- Track the IP on zone out packet, so we can check if we're on retail.
        if (e.id == PacketId.GP_SERV_COMMAND_LOGOUT) then
            ---@type GP_SERV_COMMAND_LOGOUT
            local zoneOutPacket = backend.parsePacket('incoming', e.data)
            serverIp            = zoneOutPacket.GP_SERV_LOGOUTSUB.ip
        end
    end

    ashita.events.register('packet_in', 'packet_in_zone_cb', incomingAdaptor)
end

backend.register_on_client_ready       = function(func)
    local expectedZone    = nil
    local incomingAdaptor = function(e)
        -- Track when zoning in
        if (e.id == PacketId.GP_SERV_COMMAND_LOGIN) then
            ---@type GP_SERV_COMMAND_LOGIN
            local zonePacket = backend.parsePacket('incoming', e.data)
            expectedZone     = zonePacket.ZoneNo
        end
    end

    local outgoingAdaptor = function(e)
        -- Track when zoning in
        if (e.id == PacketId.GP_CLI_COMMAND_GAMEOK) then
            if expectedZone then
                func(expectedZone)
            end

            expectedZone = nil
        end
    end

    ashita.events.register('packet_in', 'packet_in_clientrdy_cb', incomingAdaptor)
    ashita.events.register('packet_out', 'packet_out_clientrdy_cb', outgoingAdaptor)
end

backend.is_retail                      = function()
    local zoneIp = backend.get_server_ip()
    if zoneIp == 0 then
        return false
    end

    -- SE IP range 124.150.152.0/21
    return zoneIp >= 2090244096 and zoneIp <= 2090246143
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

local function colored_text(fragments)
    -- Handle string input
    if type(fragments) == 'string' then
        imgui.Text(fragments)
        return
    end

    -- Handle table input
    for i, fragment in ipairs(fragments) do
        if i > 1 then imgui.SameLine() end

        if fragment.color then
            imgui.TextColored(fragment.color, fragment.text)
        else
            imgui.Text(fragment.text)
        end
    end
end

backend.register_event_prerender = function(func)
    local adaptor = function()
        -- Use default ImGui font, scaling is applied per-window
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
                    colored_text(box.title)
                    imgui.Separator()
                end
                colored_text(box.text)
                imgui.End()
            end
        end
    end
    ashita.events.register('d3d_present', 'present_cb', adaptor)
end

--------------------------------
-- File IO
--------------------------------
-- Pure Lua file existence check
local function file_exists_check(filepath)
    local file = io.open(filepath, 'r')
    if file then
        file:close()
        return true
    end
    return false
end

-- Pure Lua directory creation (recursive)
local function create_dir_recursive(dirpath)
    -- Use the existing Ashita function, but only as last resort
    -- Try to create parent directories first
    local parent = dirpath:match('(.+)[/\\][^/\\]*$')
    if parent and not ashita.fs.exists(parent) then
        create_dir_recursive(parent)
    end
    ashita.fs.create_dir(dirpath)
end

backend.dir_exists               = function(dirpath)
    return ashita.fs.exists(backend.script_path() .. dirpath)
end

backend.file_exists              = function(filepath)
    return file_exists_check(backend.script_path() .. filepath)
end

backend.create_dir               = function(dirpath)
    -- Check if path is already absolute
    local full_path
    if dirpath:match('^[A-Za-z]:') or dirpath:match('^/') then
        -- Already absolute path
        full_path = dirpath
    else
        -- Relative path - prepend script path
        full_path = backend.script_path() .. dirpath
    end
    create_dir_recursive(full_path)
end

backend.read_file                = function(filepath)
    local full_path = backend.script_path() .. filepath
    local file      = io.open(full_path, 'r')
    if not file then return nil end
    local content = file:read('*all')
    file:close()

    -- Remove UTF-8 BOM if present
    if content and content:sub(1, 3) == string.char(0xEF, 0xBB, 0xBF) then
        content = content:sub(4)
    end

    return content
end

backend.write_file               = function(filepath, content)
    local full_path = backend.script_path() .. filepath

    -- Create directory if needed
    local directory = full_path:match('(.+)[/\\][^/\\]*$')
    if directory and not ashita.fs.exists(directory) then
        create_dir_recursive(directory)
    end

    local file = io.open(full_path, 'w')
    if not file then return false end

    if type(content) == 'table' then
        content = table.concat(content)
    end

    file:write(content)
    file:close()
    return true
end

backend.append_file              = function(filepath, content)
    local full_path = backend.script_path() .. filepath

    -- Create directory if needed
    local directory = full_path:match('(.+)[/\\][^/\\]*$')
    if directory and not ashita.fs.exists(directory) then
        create_dir_recursive(directory)
    end

    local file = io.open(full_path, 'a')
    if not file then return false end

    if type(content) == 'table' then
        content = table.concat(content)
    end

    file:write(content)
    file:close()
    return true
end

backend.read_lines               = function(filepath)
    local content = backend.read_file(filepath)
    if not content then return nil end

    local lines = {}
    for line in content:gmatch('[^\r\n]+') do
        table.insert(lines, line)
    end
    return lines
end

backend.list_files               = function(relPath)
    local full_path = addon.path .. relPath
    return ashita.fs.get_dir(full_path, '.*', true)
end

--------------------------------
-- Text Display
--------------------------------
local textBoxIdCounter           = 0

backend.textBox                  = function(_)
    local box        = {}
    box.name         = '' .. textBoxIdCounter
    box.title        = nil
    box.text         = nil
    box.visible      = true

    textBoxIdCounter = textBoxIdCounter + 1

    box.show         = function(self)
        self.visible = true
    end

    box.hide         = function(self)
        self.visible = false
    end

    box.updateTitle  = function(self, str)
        self.title = str or ''
    end

    box.updateText   = function(self, str)
        self.text = str or ''
    end

    table.insert(gui, box)

    return box
end

--------------------------------
-- Misc
--------------------------------
backend.script_path              = function()
    local path = addon.path

    path       = string.gsub(path, '\\', '/')
    path       = string.gsub(path, '//', '/')

    return path
end

backend.msg                      = function(header, message)
    print(chat.header(header):append(chat.message(message)))
end

backend.warnMsg                  = function(header, message)
    print(chat.header(header):append(chat.color1(5, message)))
end

backend.errMsg                   = function(header, message)
    print(chat.header(header):append(chat.error(message)))
end

backend.player_name              = function()
    local player = GetPlayerEntity()
    if player ~= nil then
        return player.Name
    end

    return nil
end

backend.zone                     = function()
    local entityData = backend.get_player_entity_data()
    if entityData == nil then
        return 0
    end

    return entityData.zoneID
end

backend.zone_name                = function(zone)
    local zoneId = zone or backend.zone()

    return AshitaCore:GetResourceManager():GetString('zones.names', zoneId)
end

backend.target_index             = function()
    return AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(0)
end

backend.target_name              = function()
    local index  = backend.target_index()
    local target = GetEntity(index)

    if target == nil then
        return 'Unknown'
    end

    return target.Name
end

backend.target_hpp               = function()
    local index  = backend.target_index()
    local target = GetEntity(index)

    if target == nil then
        return 0
    end

    return target.HPPercent
end

backend.get_player_entity_data   = function()
    local entity           = AshitaCore:GetMemoryManager():GetEntity()
    local party            = AshitaCore:GetMemoryManager():GetParty()
    local player           = AshitaCore:GetMemoryManager():GetPlayer()
    local index            = party:GetMemberTargetIndex(0)

    local playerZoneID     = party:GetMemberZone(0)

    local playerEntityData =
    {
        name      = party:GetMemberName(0),
        serverId  = party:GetMemberServerId(0),
        mJob      = AshitaCore:GetResourceManager():GetString('jobs.names_abbr', player:GetMainJob()),
        sJob      = AshitaCore:GetResourceManager():GetString('jobs.names_abbr', player:GetSubJob()),
        mJobLevel = player:GetMainJobLevel(),
        sJobLevel = player:GetSubJobLevel(),
        zoneID    = playerZoneID,
        zoneName  = AshitaCore:GetResourceManager():GetString('zones.names', playerZoneID),
        targIndex = index,
        x         = string.format('%+08.03f', entity:GetLocalPositionX(index)),
        y         = string.format('%+08.03f', entity:GetLocalPositionY(index)),
        z         = string.format('%+08.03f', entity:GetLocalPositionZ(index)),
        r         = string.format('%03d', utils.headingToByteRotation(entity:GetLocalPositionYaw(index))),
    }
    return playerEntityData
end

backend.get_target_entity_data   = function()
    local target = GetEntity(AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(0))
    if target == nil then
        return nil
    end

    local index            = AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(0)
    local targetEntityData =
    {
        name      = AshitaCore:GetMemoryManager():GetEntity():GetName(index),
        serverId  = AshitaCore:GetMemoryManager():GetEntity():GetServerId(index),
        targIndex = index,
        x         = string.format('%+08.03f', AshitaCore:GetMemoryManager():GetEntity():GetLocalPositionX(index)),
        y         = string.format('%+08.03f', AshitaCore:GetMemoryManager():GetEntity():GetLocalPositionY(index)),
        z         = string.format('%+08.03f', AshitaCore:GetMemoryManager():GetEntity():GetLocalPositionZ(index)),
        r         = utils.headingToByteRotation(AshitaCore:GetMemoryManager():GetEntity():GetLocalPositionYaw(index)),
    }
    return targetEntityData
end

backend.get_monster_ability_name = function(id)
    return AshitaCore:GetResourceManager():GetString('monsters.abilities', id - 256):gsub('%z', '')
end

backend.get_job_ability_name     = function(id)
    local a = AshitaCore:GetResourceManager():GetAbilityById(id + 0x200)
    return (a and a.Name[1]) or 'Unknown Ability'
end

backend.get_weapon_skill_name    = function(id)
    local a = AshitaCore:GetResourceManager():GetAbilityById(id)
    return (a and a.Name[1]) or 'Unknown Weaponskill'
end

backend.get_spell_name           = function(id)
    local s = AshitaCore:GetResourceManager():GetSpellById(id)
    return (s and s.Name[1]) or 'Unknown Spell'
end

backend.get_key_item_name        = function(id)
    local s = AshitaCore:GetResourceManager():GetString('keyitems.names', id)
    return s or 'Unknown Key Item'
end

backend.get_item_name            = function(id)
    local s = AshitaCore:GetResourceManager():GetItemById(id)
    return (s and s.Name[1]) or 'Unknown Item'
end

backend.get_item_flags           = function(id)
    local s = AshitaCore:GetResourceManager():GetItemById(id)
    return (s and s.Flags) or 0
end

backend.get_mob_by_index         = function(index)
    local mgr = AshitaCore:GetMemoryManager()
    local e   = mgr:GetEntity(index)
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

backend.get_mob_by_id            = function(id)
    local mgr  = AshitaCore:GetMemoryManager()
    local target
    local tIdx = 0
    for x = 0, 2302 do
        local e = mgr:GetEntity(x)
        if (e and e:GetServerId(x) == id) then
            target = e
            tIdx   = x
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

backend.get_inventory_item       = function(container, index)
    local inv   = AshitaCore:GetMemoryManager():GetInventory()
    local iitem = inv:GetContainerItem(container, index)

    return iitem
end

backend.get_inventory_items      = function(container)
    local ret = {}
    local inv = AshitaCore:GetMemoryManager():GetInventory()
    local cnt = inv:GetContainerCount(container)

    for i = 0, cnt do
        local iitem = inv:GetContainerItem(container, i)
        table.insert(ret, iitem)
    end

    return ret
end

-- credits: atom0s accounts lib
backend.get_server_ip            = function()
    local main_sys = ashita.memory.find('FFXiMain.dll', 0, '8B0D????????8D04808B8481????????C3', 0, 0)
    if not main_sys then
        return 0
    end

    local ptr  = ashita.memory.read_uint32(main_sys + 0x02)
    local ret  = ashita.memory.read_uint32(ptr)
    local leIP = ashita.memory.read_uint32(ret)
    local beIP = bit.bor(
        bit.lshift(bit.band(leIP, 0x000000FF), 24),
        bit.lshift(bit.band(leIP, 0x0000FF00), 8),
        bit.rshift(bit.band(leIP, 0x00FF0000), 8),
        bit.rshift(bit.band(leIP, 0xFF000000), 24)
    )

    return beIP
end

-- credits: atom0s
backend.get_client_build_string  = function()
    local sig      = ashita.memory.find('FFXiMain.dll', 0, '68????????E8????????83C4046AFF', 0, 0)
    local ptr      = ashita.memory.read_uint32(sig + 0x01)
    local buildStr = ashita.memory.read_string(ptr, 48)

    return buildStr
end

-- credits: Thorny
backend.is_mob                   = function(index)
    if (index >= 0x400) then
        return false
    end

    return (bit.band(AshitaCore:GetMemoryManager():GetEntity():GetSpawnFlags(index), 0x10) ~= 0)
end

backend.is_npc                   = function(index)
    if (index >= 0x400) then
        return false
    end

    return (bit.band(AshitaCore:GetMemoryManager():GetEntity():GetSpawnFlags(index), 0x2) ~= 0)
end

-- scheduling coroutines makes reloading impossible
-- unless we're checking constantly for the reload signal
backend.schedule                 = function(func, delay)
    ashita.tasks.once(0, function()
        while not captain.reloadSignal do
            if delay <= 1 then
                coroutine.sleep(delay)
                func()
                return
            else
                local slept = 0
                while slept < delay and not captain.reloadSignal do
                    coroutine.sleep(0.1)
                    slept = slept + 0.1
                end

                func()
                return
            end
        end
    end)
end

-- sugar.loop does not support early exits
backend.forever                  = function(func, delay, ...)
    local args = { ... }

    ashita.tasks.once(0, function()
        while not captain.reloadSignal do
            func(table.unpack(args))

            local slept = 0
            while slept < delay and not captain.reloadSignal do
                coroutine.sleep(0.1)
                slept = slept + 0.1
            end
        end
    end)
end

backend.convert_int_to_float     = function(raw)
    return string.unpack('f', string.pack('I4', raw))
end

--------------------------------
-- Packets
--------------------------------
--------------------------------
-- Injects a widescan request packet
--------------------------------
backend.doWidescan               = function()
    backend.injectPacket(PacketId.GP_CLI_COMMAND_TRACKING_LIST,
        { PacketId.GP_CLI_COMMAND_TRACKING_LIST, 0x04, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00 })
end

backend.doCheck                  = function(targetIndex)
    local mob = backend.get_mob_by_index(targetIndex)
    if mob == nil or mob.serverId == 0 then
        return
    end

    backend.injectPacket(PacketId.GP_CLI_COMMAND_EQUIP_INSPECT,
        {
            PacketId.GP_CLI_COMMAND_EQUIP_INSPECT,
            0x10, -- size
            0x00, -- sync
            0x00, -- sync
            bit.band(mob.serverId, 0xFF),
            bit.band(bit.rshift(mob.serverId, 8), 0xFF),
            bit.band(bit.rshift(mob.serverId, 16), 0xFF),
            bit.band(bit.rshift(mob.serverId, 24), 0xFF),
            bit.band(targetIndex, 0xFF),
            bit.band(bit.rshift(targetIndex, 8), 0xFF),
            bit.band(bit.rshift(targetIndex, 16), 0xFF),
            bit.band(bit.rshift(targetIndex, 24), 0xFF),
            0x00, -- kind
        })
end

--------------------------------
-- Adds an arbitrary packet to the outgoing queue
--------------------------------
backend.injectPacket             = function(id, content)
    AshitaCore:GetPacketManager():AddOutgoingPacket(id, content)
end

backend.registerKeyBind          = function(params, command)
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

backend.deregisterKeyBind        = function(params)
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

backend.loadConfig               = function(name, defaults)
    return settings.load(T(defaults) or T {}, name)
end

backend.saveConfig               = function(name)
    return settings.save(name)
end



backend.notificationsRender = function(notifications)
    local vp_size            =
    {
        x = backend.get_resolution_width(),
        y = backend.get_resolution_height(),
    }

    local NOTIFY_TOAST_FLAGS = bit.bor(
        ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoScrollbar,
        ImGuiWindowFlags_NoCollapse, ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoSavedSettings, ImGuiWindowFlags_NoFocusOnAppearing
    )

    local height             = 0

    -- Push styles for the notifications
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 8, 8 })
    imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 2, 2 })
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { 4, 4 })

    -- Calculate width for uniform notifications
    local avg_char_width = imgui.GetFontSize() * 0.5
    local uniform_width  = (80 * avg_char_width * captain.settings.notifications.scale) + 20

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

    local KEY_COLOR    = normalizeColor(captain.settings.notifications.colors.key)
    local VALUE_COLOR  = normalizeColor(captain.settings.notifications.colors.value)
    local TITLE_COLOR  = normalizeColor(captain.settings.notifications.colors.title)
    local WHITE_COLOR  = { 1.0, 1.0, 1.0, 1.0 }
    local TRANSPARENT  = { 0.0, 0.0, 0.0, 0.0 }

    local typeHandlers =
    {
        ['table']   = function(fieldName, value)
            local values = {}
            for i, v in ipairs(value) do table.insert(values, tostring(v)) end
            if #values == 0 then
                for k, v in pairs(value) do table.insert(values, tostring(k) .. '=' .. tostring(v)) end
            end
            return fieldName .. '[]', table.concat(values, ', ')
        end,

        ['nil']     = function(fieldName, _) return fieldName, 'nil' end,

        ['number']  = function(fieldName, value)
            return fieldName, math.floor(value) == value and tostring(value) or string.format('%.2f', value)
        end,

        ['string']  = function(fieldName, value)
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

        -- Skip invalid notifications
        if not toast or not toast.id then
            goto continue
        end

        -- Prepare notification background
        local opacity  = toast.bg.alpha / 255
        local bg_color =
        {
            toast.bg.red / 255, toast.bg.green / 255, toast.bg.blue / 255, opacity,
        }

        -- Position notification
        imgui.SetNextWindowPos(
            {
                vp_size.x - captain.settings.notifications.offset.x,
                vp_size.y - captain.settings.notifications.offset.y - height,
            },
            ImGuiCond_Always, { 1.0, 1.0 }
        )

        -- Set window style
        imgui.PushStyleColor(ImGuiCol_WindowBg, bg_color)
        imgui.PushStyleColor(ImGuiCol_Border, TRANSPARENT)
        imgui.SetNextWindowSizeConstraints(
            { uniform_width, 0 }, { vp_size.x * 0.7, vp_size.y * 0.8 }
        )

        -- Create window with stable ID based on notification ID
        local window_id = string.format('##TOAST_%s', toast.id or i)
        if imgui.Begin(window_id, { true }, NOTIFY_TOAST_FLAGS) then
            imgui.SetWindowFontScale(captain.settings.notifications.scale)
            imgui.PushTextWrapPos(uniform_width)

            -- Handle dragging
            if imgui.IsWindowHovered() and imgui.IsMouseDragging(0) then
                local delta_x, delta_y                  = imgui.GetMouseDragDelta(0)
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
                local max_line_width     = uniform_width
                local current_line_width = 0
                local is_first_in_line   = true
                local grouped_data       = {}

                -- Preprocess data
                for i, pair in ipairs(toast.data) do
                    local key, value = processFieldValue(pair[1], pair[2])
                    local key_size   = { imgui.CalcTextSize(key) }
                    local colon_size = { imgui.CalcTextSize(': ') }
                    local value_size = { imgui.CalcTextSize(value) }

                    table.insert(grouped_data,
                        {
                            key        = key,
                            value      = value,
                            width      = key_size[1] + colon_size[1] + value_size[1] + 15,
                            orig_index = i,
                        })
                end

                -- Render data items
                for _, item in ipairs(grouped_data) do
                    local key, value, width = item.key, item.value, item.width
                    local is_array          = key:match('%[%]$') ~= nil
                    local is_long_value     = width > (max_line_width * 0.8)
                    local needs_new_line    = (is_array or is_long_value) or
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
                        is_first_in_line   = false
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

        ::continue::
    end

    imgui.PopStyleVar(3)
    return height
end


backend.get_resolution_width  = function()
    return AshitaCore:GetConfigurationManager():GetUInt32('boot', 'ffxi.registry', '0001', 1920)
end

backend.get_resolution_height = function()
    return AshitaCore:GetConfigurationManager():GetUInt32('boot', 'ffxi.registry', '0002', 1080)
end

backend.reload                = function()
    captain.reloadSignal = true
    backend.msg('captain', 'Reloading. Coroutines may take a moment to finish.')
    AshitaCore:GetChatManager():QueueCommand(-1, '/addon reload captain')
end

backend.configMenu            = function()
    -- If config is not being shown, return early
    if not captain.showConfig then
        return
    end

    -- Load settings schema which contains both UI configuration and default values for captain
    local settings_schema = require('data/settings_schema')

    -- Helper function to render settings UI for a given set of settings
    local function renderSettings(settings_list, settingsRoot, getDefaultValue, saveConfigFunc, category_id)
        for _, setting in ipairs(settings_list) do
            -- Process setting path
            local parts = {}
            local path  = setting.path or setting.key -- Support both formats
            for part in string.gmatch(path, '[^%.]+') do
                table.insert(parts, part)
            end

            -- Navigate to the setting in the configuration
            local settingRef = settingsRoot
            for i = 1, #parts - 1 do
                if not settingRef[parts[i]] then
                    settingRef[parts[i]] = {}
                end
                settingRef = settingRef[parts[i]]
            end
            local lastPart = parts[#parts]

            -- If the setting doesn't exist yet, initialize it with the default
            if settingRef[lastPart] == nil then
                local defaultValue = getDefaultValue(setting, parts)
                if defaultValue ~= nil then
                    settingRef[lastPart] = defaultValue
                end
            end

            -- Display the setting name
            local title       = setting.ui and setting.ui.title or setting.title

            -- Get UI properties
            local ui          = setting.ui or setting
            local settingType = ui.type or 'slider'

            -- For checkboxes, put the title on the same line as the control
            if settingType == 'checkbox' then
                -- For checkboxes, show colored title first, then the checkbox on same line
                imgui.TextColored(CORAL, title)
                imgui.SameLine()

                -- Create checkbox without title text
                local buffer       = { settingRef[lastPart] }
                -- Make control ID more unique by including the full path and category
                local controlID    = string.format('##setting_%s_%s', category_id or 'unknown',
                    path:gsub(' ', '_'):gsub('%.', '_'):lower())

                -- Create checkbox without title
                local valueChanged = imgui.Checkbox(controlID, buffer)

                -- Apply changes if the value changed
                if valueChanged then
                    settingRef[lastPart] = buffer[1]
                    saveConfigFunc()
                end

                -- Add reset button on the same line
                imgui.SameLine()
                local resetID = string.format('Reset##reset_%s', path:gsub('[%.]', '_'):lower())

                if imgui.Button(resetID) then
                    -- Reset to default value
                    local defaultValue = getDefaultValue(setting, parts)
                    if defaultValue ~= nil then
                        settingRef[lastPart] = defaultValue
                        saveConfigFunc()
                    end
                end
            else
                -- For non-checkbox controls, display title first
                imgui.TextColored(CORAL, title)

                -- Create buffer with current value
                local buffer       = { settingRef[lastPart] }
                local controlID    = string.format('##setting_%s_%s', category_id or 'unknown',
                    path:gsub(' ', '_'):gsub('%.', '_'):lower())

                local valueChanged = false

                -- Use a relative width based on the window width
                imgui.PushItemWidth(imgui.GetWindowWidth() * 0.8)

                -- Create appropriate control based on type
                if settingType == 'slider' then
                    -- Determine if it's an integer slider
                    local step      = ui.step or 1
                    local isInteger = step and step == math.floor(step) and step == 1
                    local min       = ui.min or 0
                    local max       = ui.max or 100

                    if isInteger then
                        valueChanged = imgui.SliderInt(
                            controlID,
                            buffer,
                            math.floor(min),
                            math.floor(max),
                            '%d',
                            ImGuiSliderFlags_AlwaysClamp
                        )
                    else
                        -- Format based on step size
                        local format = '%.1f'
                        if step < 0.1 then
                            format = '%.2f'
                        elseif step < 0.01 then
                            format = '%.3f'
                        end

                        valueChanged = imgui.SliderFloat(
                            controlID,
                            buffer,
                            min,
                            max,
                            format,
                            ImGuiSliderFlags_AlwaysClamp
                        )
                    end
                elseif settingType == 'text' then
                    valueChanged = imgui.InputText(
                        controlID,
                        buffer,
                        256
                    )
                elseif settingType == 'number' then
                    valueChanged = imgui.InputInt(
                        controlID,
                        buffer
                    )
                end

                imgui.PopItemWidth()

                -- Apply changes if the value changed
                if valueChanged then
                    settingRef[lastPart] = buffer[1]
                    saveConfigFunc()
                end

                -- Add reset button on the same line
                imgui.SameLine()
                local resetID = string.format('Reset##reset_%s', path:gsub('[%.]', '_'):lower())

                if imgui.Button(resetID) then
                    -- Reset to default value
                    local defaultValue = getDefaultValue(setting, parts)
                    if defaultValue ~= nil then
                        settingRef[lastPart] = defaultValue
                        saveConfigFunc()
                    end
                end
            end

            -- Show tooltip on hover (for both checkbox and non-checkbox)
            if imgui.IsItemHovered() then
                imgui.BeginTooltip()
                local description = ui.description or setting.description
                if description then
                    imgui.Text(description)
                    imgui.Separator()
                end

                local defaultValue = getDefaultValue(setting, parts)
                if defaultValue ~= nil then
                    imgui.Text(string.format('Default: %s', tostring(defaultValue)))
                end
                imgui.EndTooltip()
            end
        end
    end

    local isOpen = { true }

    if imgui.Begin('captain Configuration', isOpen, ImGuiWindowFlags_AlwaysAutoResize) then
        if not isOpen[1] then
            captain.showConfig = false
        end

        local current_tab = nil

        if imgui.BeginTabBar('##captain_config_tabbar', ImGuiTabBarFlags_NoCloseWithMiddleMouseButton) then
            -- Captain core settings - combined in one tab
            if imgui.BeginTabItem('Captain') then
                current_tab = 'Captain'
                imgui.BeginGroup()

                -- Render all captain settings with separators
                for i, category in ipairs(settings_schema.categories) do
                    -- Add section header in red
                    imgui.TextColored({ 1.0, 0.2, 0.2, 1.0 }, category.title)
                    imgui.Separator()
                    imgui.Spacing()

                    -- Get all UI-configurable settings for this category
                    local ui_settings = settings_schema:get_ui_settings(category.id)

                    -- Render captain settings
                    renderSettings(
                        ui_settings,
                        captain.settings[category.id],
                        -- Function to get default value
                        function(setting, _)
                            return setting.default
                        end,
                        -- Function to save config
                        function()
                            backend.saveConfig('captain')
                        end,
                        category.id -- Pass category ID for unique control IDs
                    )

                    -- Add spacing between sections (but not after the last one)
                    if i < #settings_schema.categories then
                        imgui.Spacing()
                        imgui.Spacing()
                    end
                end

                imgui.EndGroup()
                imgui.EndTabItem()
            end

            -- Addon settings
            local addonNames = utils.getTableKeys(captain.addons)
            for _, addonName in ipairs(addonNames) do
                local addon = captain.addons[addonName]
                -- Check if addon has a config menu
                if type(addon.onConfigMenu) == 'function' then
                    local addonConfig = addon.onConfigMenu()

                    -- Skip if no config is returned
                    if addonConfig and #addonConfig > 0 then
                        -- Create a tab for this addon
                        if imgui.BeginTabItem(addonName) then
                            current_tab = addonName
                            imgui.BeginGroup()

                            -- Render addon settings
                            renderSettings(
                                addonConfig,
                                addon.settings,
                                -- Function to get default value from addon's defaultSettings
                                function(setting, parts)
                                    -- Debug: Check if we're getting the setting's own default first
                                    if setting.default ~= nil then
                                        return setting.default
                                    end

                                    -- Fall back to navigating defaultSettings
                                    local defaultRef = addon.defaultSettings
                                    for _, part in ipairs(parts) do
                                        if defaultRef and type(defaultRef) == 'table' then
                                            defaultRef = defaultRef[part]
                                        else
                                            defaultRef = nil
                                            break
                                        end
                                    end
                                    return defaultRef
                                end,
                                -- Function to save config
                                function()
                                    backend.saveConfig(addonName)
                                end,
                                addonName -- Pass addon name for unique control IDs
                            )

                            imgui.EndGroup()
                            imgui.EndTabItem()
                        end
                    end
                end
            end

            imgui.EndTabBar()
        end

        -- Footer buttons - shown on all pages
        imgui.Separator()
        imgui.Spacing()

        -- Center the buttons using automatic sizing
        local window_width   = imgui.GetWindowWidth()
        local button_spacing = 20

        -- Calculate button sizes (only Reset Tab and Close)
        local reset_size     = { imgui.CalcTextSize('Reset Tab') }
        local close_size     = { imgui.CalcTextSize('Close') }

        -- Add padding to button sizes
        local padding        = 20
        reset_size[1]        = reset_size[1] + padding
        close_size[1]        = close_size[1] + padding

        local total_width    = reset_size[1] + close_size[1] + button_spacing
        local start_x        = (window_width - total_width) * 0.5

        imgui.SetCursorPosX(start_x)

        if imgui.Button('Reset Tab', reset_size) then
            if current_tab == 'Captain' then
                -- Reset only captain settings
                captain.settings = require('data/settings_schema').get_defaults()
                backend.saveConfig('captain')
            elseif current_tab and captain.addons[current_tab] then
                -- Reset only the current addon's settings
                local addon = captain.addons[current_tab]
                if addon.defaultSettings then
                    -- Deep copy defaultSettings to avoid reference issues
                    addon.settings = utils.deepcopy(addon.defaultSettings)
                    backend.saveConfig(current_tab)
                end
            end
        end

        imgui.SameLine(0, button_spacing)
        if imgui.Button('Close', close_size) then
            captain.showConfig = false
        end

        imgui.End()
    else
        captain.showConfig = false
    end
end

return backend
