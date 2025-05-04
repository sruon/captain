local backend = {}

---@type any
windower = windower

local string = require('string')
local bit = require('bit')
local texts = require('texts')
local tables = require('tables')
local res = require('resources')
local packets = require('packets')
local files = require('files')
local actions = require('actions')
local chat = require('chat')
local config = require('config')
require('lists')
require('maths')
require('strings')
require('functions')
require('pack')

--------------------------------
-- Event hooks
-- https://github.com/Windower/Lua/wiki/Events
--------------------------------
backend.register_event_load            = function(func)
    windower.register_event('load', func)
end

backend.register_event_unload          = function(func)
    windower.register_event('unload', func)
end

backend.register_command               = function(func)
    windower.register_event('addon command', function(...)
        local args = { ... }
        func(args)
    end)
end

backend.register_event_incoming_packet = function(func)
    local adaptor = function(id, original, modified, injected, blocked)
        func(id, original, string.len(original))
    end
    windower.register_event('incoming chunk', adaptor)
end

backend.register_event_outgoing_packet = function(func)
    local adaptor = function(id, original, modified, injected, blocked)
        func(id, original, string.len(original))
    end
    windower.register_event('outgoing chunk', adaptor)
end

backend.register_on_zone_change        = function(func)
    windower.register_event('zone change', func)
end

backend.register_event_incoming_text   = function(func)
    local adaptor = function(original, modified, original_mode, modified_mode)
        -- replace autotranslate tags with brackets
        original = (original:gsub(string.char(0xEF) .. '[' .. string.char(0x27) .. ']', '{'))
        original = (original:gsub(string.char(0xEF) .. '[' .. string.char(0x28) .. ']', '}'))
        func(original_mode, original:strip_colors())
    end
    windower.register_event('incoming text', adaptor)
end

backend.register_event_prerender       = function(func)
    windower.register_event('prerender', func)
end

backend.register_event_postrender      = function(func)
    windower.register_event('postrender', func)
end

--------------------------------
-- File IO
--------------------------------
backend.dir_exists                     = function(path)
    return windower.dir_exists(path)
end

backend.file_exists                    = function(path)
    return windower.file_exists(path)
end

backend.create_dir                     = function(filename)
    windower.create_dir(backend.script_path() .. filename)
end

backend.list_files                     = function(path)
    return windower.get_dir(backend.script_path() .. path)
end

--------------------------------
-- Text Display
--------------------------------
--Override texts.new and texts.destroy to enable
--movement only on shift+click
local texts_settings                   = T {}
texts.oldnew                           = texts.new
texts.new                              = function(str, settings, root_settings)
    settings = settings or { flags = { draggable = false } }
    settings.flags = settings.flags or { draggable = false }
    settings.flags.draggable = false
    local ret = texts.oldnew(str, settings, root_settings)
    texts_settings[ret._name] = settings
    return ret
end

texts.destroy                          = function(t)
    texts_settings[t._name] = nil
end

windower.register_event('keyboard', function(dik, pressed, flags, blocked)
    if dik == 42 and not blocked then
        if pressed then
            texts_settings:map(function(settings)
                settings.flags = settings.flags or { draggable = true }
                settings.flags.draggable = true
            end)
        else
            texts_settings:map(function(settings)
                settings.flags = settings.flags or { draggable = false }
                settings.flags.draggable = false
            end)
        end
    end
end)

backend.textBox                  = function(id)
    local box       = {}
    local newConf   = config.load(string.format('data/%s_textbox.xml', id), captain.settings.textBox.defaults)

    box.impl        = texts.new('', newConf, newConf)

    box.title       = ''
    box.text        = ''

    box.show        = function(self)
        self.impl:show()
    end

    box.hide        = function(self)
        self.impl:hide()
    end

    box.updateTitle = function(self, str)
        self.title = str
        texts.text(self.impl, self.title .. '\n' .. self.text)
    end

    box.updateText  = function(self, str)
        self.text = str
        texts.text(self.impl, self.title .. '\n' .. self.text)
    end

    box:updateText('')
    box:show()
    box.impl:draggable(true)

    config.reload(newConf)

    return box
end

--------------------------------
-- Misc
--------------------------------
backend.script_path              = function()
    local path = windower.addon_path

    path = string.gsub(path, '\\', '/')
    path = string.gsub(path, '//', '/')

    return path
end

backend.player_name              = function()
    local player = windower.ffxi.get_player()
    if player ~= nil then
        return player.name
    end
    return nil
end

backend.zone                     = function()
    return windower.ffxi.get_info().zone
end

backend.zone_name                = function(zone)
    if not zone then
        zone = backend.zone()
    end

    return res.zones[zone].en
end

backend.target_index             = function()
    local player = windower.ffxi.get_player()
    if not player then
        return nil
    end

    if not player.target_index then
        return nil
    end

    return player.target_index
end

backend.target_name              = function()
    local index = backend.target_index()
    if not index then
        return nil
    end

    local mob = windower.ffxi.get_mob_by_index(index)
    if not mob then
        return nil
    end

    return mob.name
end

backend.target_hpp               = function()
    local index = backend.target_index()
    if not index then
        return nil
    end

    local mob = windower.ffxi.get_mob_by_index(index)
    if not mob then
        return nil
    end

    return mob.hpp
end

backend.get_player_entity_data   = function()
    local playerEntity = windower.ffxi.get_mob_by_target('me')
    if playerEntity == nil then
        return nil
    end
    local playerEntityData =
    {
        name = playerEntity.name,
        serverId = playerEntity.id,
        targIndex = playerEntity.index,
        x = string.format('%+08.03f', playerEntity.x),
        y = string.format('%+08.03f', playerEntity.z),
        z = string.format('%+08.03f', playerEntity.y),
        r = utils.headingToByteRotation(playerEntity.heading),
    }
    return playerEntityData
end

backend.get_target_entity_data   = function()
    local targetEntity = windower.ffxi.get_mob_by_target('t')
    if targetEntity == nil then
        return nil
    end
    local targetEntityData =
    {
        name = targetEntity.name,
        serverId = targetEntity.id,
        targIndex = targetEntity.index,
        x = string.format('%+08.03f', targetEntity.x),
        y = string.format('%+08.03f', targetEntity.z),
        z = string.format('%+08.03f', targetEntity.y),
        r = utils.headingToByteRotation(targetEntity.heading),
    }
    return targetEntityData
end

backend.get_monster_ability_name = function(id)
    return res.monster_abilities[id].en
end

backend.get_job_ability_name     = function(id)
    return res.job_abilities[id].en
end

backend.get_weapon_skill_name    = function(id)
    return res.weapon_skills[id].en
end

backend.get_spell                = function(id)
    return res.spells[id]
end

backend.get_spell_name           = function(id)
    return res.spells[id].en
end

backend.get_item_name            = function(id)
    return res.items[id].en
end

backend.get_mob_by_index         = function(index)
    return windower.ffxi.get_mob_by_index(index)
end

backend.get_mob_by_id            = function(id)
    return windower.ffxi.get_mob_by_id(id)
end

backend.schedule                 = function(func, delay)
    coroutine.schedule(func, delay)
end

backend.forever                  = function(func, delay, ...)
    local args = { ... }
    coroutine.schedule(function()
        while not captain.reloadSignal do
            func(table.unpack(args))

            local slept = 0
            while slept < delay and not captain.reloadSignal do
                coroutine.sleep(1)
                slept = slept + 1
            end
        end
    end, 0)
end

--------------------------------
-- Packets
--------------------------------
--------------------------------
-- Injects a widescan request packet
--------------------------------
backend.doWidescan               = function()
    backend.injectPacket(PacketId.GP_CLI_COMMAND_TRACKING_LIST, { ['Flags'] = 1 })
end

--------------------------------
-- Adds an arbitrary packet to the outgoing queue
--------------------------------
backend.injectPacket             = function(id, content)
    local packet = packets.new('outgoing', id, content)
    packets.inject(packet)
end

--------------------------------
-- Chat
--------------------------------
--------------------------------
-- Adds a message to the chatlog
--------------------------------
backend.msg                      = function(header, message)
    local logName = header or 'Unnamed addon'
    windower.add_to_chat(1, string.char(0x1F, 7) .. '[' .. logName .. '] ' .. message)
end

--------------------------------
-- Keybinds
--------------------------------

backend.registerKeyBind          = function(params, command)
    local modifiers = ''

    if params.ctrl then
        modifiers = modifiers .. '^'
    end
    if params.alt then
        modifiers = modifiers .. '!'
    end
    if params.shift then
        modifiers = modifiers .. '~'
    end
    if params.win then
        modifiers = modifiers .. '@'
    end

    local keybind = modifiers .. params.key

    windower.send_command(string.format('bind %s %s', keybind, command))
end

backend.deregisterKeyBind        = function(params)
    local modifiers = ''

    if params.ctrl then
        modifiers = modifiers .. '^'
    end
    if params.alt then
        modifiers = modifiers .. '!'
    end
    if params.shift then
        modifiers = modifiers .. '~'
    end
    if params.win then
        modifiers = modifiers .. '@'
    end

    local keybind = modifiers .. params.key

    windower.send_command(string.format('unbind %s', keybind))
end


backend.convert_int_to_float = function(raw)
    return string.pack('I', raw):unpack('f')
end

local function strip_colors(s)
    return s:gsub('\\cs%(%d+,%d+,%d+%)', '')
end

local notifications = {}
local notificationPositions = {}
local is_dragging = false
local drag_start = { x = 0, y = 0 }
local drag_notification_pos = { x = 0, y = 0 }
local dragged_notification = nil
local drag_event_id = nil
local move_event_id = nil
local override_rendering = false

-- Format text with color
local function colorize(text, color_rgb)
    return string.format('\\cs(%d,%d,%d)%s', color_rgb[1], color_rgb[2], color_rgb[3], text)
end

-- Centralized initialization for notifications
local function notificationInit()
    -- Basic validation
    if not colors or not captain.settings or not captain.settings.notifications then return end
    
    -- Clear existing notifications
    for _, notification in ipairs(notifications) do
        if notification then
            notification:hide()
            texts.destroy(notification)
        end
    end
    notifications = {}
    notificationPositions = {}
    
    -- Get screen dimensions and calculate scaled values
    local screen_width = backend.get_resolution_width()
    local screen_height = backend.get_resolution_height()
    local scale = captain.settings.notifications.scale or 1
    local scaled_width = 300 * scale
    local scaled_height = 80 * scale
    local scaled_spacing = (captain.settings.notifications.spacing or 8) * scale
    local text_size = (captain.settings.notifications.text.size or 12) * scale
    
    -- Create positions for notifications
    for i = 1, captain.settings.notifications.max_num do
        local pos_x = screen_width - scaled_width - captain.settings.notifications.offset.x
        local pos_y = screen_height - (scaled_height * i) - (scaled_spacing * (i-1)) - captain.settings.notifications.offset.y
        notificationPositions[i] = { x = pos_x, y = pos_y }
    end

    -- Create notification objects
    for i, pos in ipairs(notificationPositions) do
        -- Define base settings
        local base_settings = {
            pos = { x = pos.x, y = pos.y },
            text = { size = text_size },
            bg = { 
                alpha = captain.settings.notifications.bg.alpha or 230, 
                red = captain.settings.notifications.bg.red or 30, 
                green = captain.settings.notifications.bg.green or 30, 
                blue = captain.settings.notifications.bg.blue or 60, 
                visible = true 
            },
            flags = { right = false, draggable = false }
        }
        
        -- Create and configure notification
        local notification = texts.new('notification_' .. i, base_settings)
        if notification then
            table.insert(notifications, notification)
            texts.text(notification, "")
            texts.bg_alpha(notification, captain.settings.notifications.bg.alpha or 230)
            texts.bg_color(notification, 
                captain.settings.notifications.bg.red or 30, 
                captain.settings.notifications.bg.green or 30, 
                captain.settings.notifications.bg.blue or 60)
            notification:show()
        end
    end

    -- Clean up existing event handlers
    if drag_event_id then windower.unregister_event(drag_event_id) end
    if move_event_id then windower.unregister_event(move_event_id) end
    
    -- Register mouse down/up event handler
    drag_event_id = windower.register_event('mouse', function(type, x, y)
        -- Mouse down: start drag if hovering over a notification
        if type == 1 then
            for i, notification in ipairs(notifications) do
                if notification:hover(x, y) then
                    is_dragging = true
                    dragged_notification = notification
                    drag_start.x = x
                    drag_start.y = y
                    drag_notification_pos.x, drag_notification_pos.y = notification:pos()
                    override_rendering = true
                    return true
                end
            end
        end
        
        -- Mouse up: end drag and save new position
        if type == 2 and is_dragging and dragged_notification then
            local final_x, final_y = dragged_notification:pos()
            local screen_width = backend.get_resolution_width()
            local screen_height = backend.get_resolution_height()
            local scale = captain.settings.notifications.scale or 1
            
            -- Update offset settings
            captain.settings.notifications.offset.x = math.max(0, screen_width - final_x - (300 * scale))
            captain.settings.notifications.offset.y = math.max(0, screen_height - final_y - (80 * scale))
            backend.saveConfig(captain.settings)
            
            -- Reset state and recreate notifications
            is_dragging = false
            dragged_notification = nil
            override_rendering = false
            backend.schedule(notificationInit, 0.1)
            return true
        end
        
        return false
    end)
    
    -- Register mouse move event handler
    move_event_id = windower.register_event('mouse', function(type, x, y)
        if type == 0 and is_dragging and dragged_notification then
            -- Update position during drag
            local new_x = drag_notification_pos.x + (x - drag_start.x)
            local new_y = drag_notification_pos.y + (y - drag_start.y)
            texts.pos(dragged_notification, new_x, new_y)
            return true
        end
        return false
    end)
end

backend.notificationsRender = function(allNotifications)
    -- Skip rendering during drag operations
    if override_rendering then return end
    
    -- Initialize if needed
    if not notificationPositions[1] then notificationInit() end
    if #notifications == 0 then return end
    
    -- Hide all if no notifications to render
    if #allNotifications == 0 then
        for i, notification in ipairs(notifications) do
            if notification then 
                notification:hide()
                texts.text(notification, "")
            end
        end
        return
    end

    -- Reorder notifications so newest is at the bottom
    local displayOrder = {}
    for i = 1, #allNotifications do
        table.insert(displayOrder, {
            notification = allNotifications[i],
            displayIndex = #allNotifications - i + 1
        })
    end
    
    -- Get dimensions and scaling values
    local scale = captain.settings.notifications.scale or 1
    local scaled_spacing = (captain.settings.notifications.spacing or 8) * scale
    local screen_width = backend.get_resolution_width()
    local screen_height = backend.get_resolution_height()
    local font_size = (captain.settings.notifications.text.size or 12) * scale
    
    -- Calculate text width constraint
    local max_width = math.floor(screen_width * 0.67)
    local notification_width = math.min(max_width, 300 * scale)
    local chars_per_width = math.floor(notification_width / (font_size * 0.5))
    
    -- Process each notification
    for _, item in ipairs(displayOrder) do
        local notification = item.notification
        local displayIndex = item.displayIndex
        
        if displayIndex > #notifications then break end  -- Skip if no slot available
        
        -- Get color values from settings
        local title_rgb = colors[captain.settings.notifications.colors.title].rgb
        local key_rgb = colors[captain.settings.notifications.colors.key].rgb
        local value_rgb = colors[captain.settings.notifications.colors.value].rgb
        
        -- Format title
        local lines = {}
        local title = notification.title or 'Notification'
        table.insert(lines, colorize(title, title_rgb))
        
        -- Process data entries
        if notification.data and type(notification.data) == 'table' then
            local current_line = ''
            local line_length = 0
            
            for _, pair in ipairs(notification.data) do
                if pair[1] and pair[2] ~= nil then
                    -- Format value based on type
                    local key, value = pair[1], pair[2]
                    local is_array = type(value) == 'table'
                    
                    if is_array then
                        local values = {}
                        for i, v in ipairs(value) do table.insert(values, tostring(v)) end
                        if #values == 0 then
                            for k, v in pairs(value) do table.insert(values, tostring(k) .. '=' .. tostring(v)) end
                        end
                        value = table.concat(values, ', ')
                        key = key .. '[]'
                    elseif type(value) == 'number' then
                        value = math.floor(value) == value and tostring(value) or string.format('%.2f', value)
                    elseif type(value) == 'string' and #value > 60 then
                        value = value:sub(1, 57) .. '...'
                    else
                        value = tostring(value)
                    end
                    
                    -- Format key-value pair
                    local entry_width = #key + #value + 2
                    local formatted = colorize(key:gsub('%[%]$', ''), key_rgb) .. ': ' .. colorize(value, value_rgb)
                    local is_long = entry_width > (chars_per_width * 0.8)
                    
                    -- Determine if needs new line
                    if is_array or is_long or (line_length > 0 and line_length + entry_width > chars_per_width) then
                        if line_length > 0 then
                            table.insert(lines, current_line)
                        end
                        current_line = formatted
                        line_length = entry_width
                    else
                        if line_length > 0 then
                            current_line = current_line .. ' ' .. formatted
                        else
                            current_line = formatted
                        end
                        line_length = line_length + entry_width + (line_length > 0 and 1 or 0)
                    end
                    
                    -- Force new line after arrays or long values
                    if (is_array or is_long) and current_line ~= '' then
                        table.insert(lines, current_line)
                        current_line = ''
                        line_length = 0
                    end
                end
            end
            
            -- Add final line if not empty
            if current_line ~= '' then
                table.insert(lines, current_line)
            end
        end
        
        -- Update notification content and position
        local notification_obj = notifications[displayIndex]
        texts.text(notification_obj, table.concat(lines, '\n'))
        
        -- Calculate vertical positioning based on total height of previous notifications
        local total_used_height = 0
        for i = 1, displayIndex - 1 do
            if notifications[i] then
                local _, height = texts.extents(notifications[i])
                total_used_height = total_used_height + height + scaled_spacing
            end
        end
        
        -- Position the notification
        local scaled_width = 300 * scale
        local width, height = texts.extents(notification_obj)
        local target_x = screen_width - scaled_width - captain.settings.notifications.offset.x
        local target_y = screen_height - total_used_height - captain.settings.notifications.offset.y - height
        
        texts.pos(notification_obj, target_x, target_y)
        notification_obj:show()
    end
    
    -- Hide unused notification slots
    for i = #allNotifications + 1, #notifications do
        if notifications[i] then
            notifications[i]:hide()
        end
    end
end

backend.loadConfig          = function(name, defaults)
    return config.load('data/' .. name .. '.xml', defaults)
end

backend.saveConfig          = function(confTable)
    if not confTable then
        confTable = captain.settings
    end

    return config.save(confTable)
end

backend.scale_font          = function(height)
    return height
end

backend.scale_width         = function(width)
    return width
end

backend.scale_height        = function(height)
    return height
end

backend.get_resolution_width = function()
    local info = windower.get_windower_settings()
    return info.ui_x_res
end

backend.get_resolution_height = function()
    local info = windower.get_windower_settings()
    return info.ui_y_res
end

backend.reload              = function()
    captain.reloadSignal = true
    windower.send_command('captain stop')
    backend.msg('captain', 'Reloading. Coroutines may take a moment to finish.')
    backend.schedule(function() windower.send_command('lua reload captain') end, 2)
end

backend.configMenu          = function()
    -- Configuration menu not available for Windower
end

return backend
