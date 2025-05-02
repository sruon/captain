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
backend.register_event_load = function(func)
    windower.register_event('load', func)
end

backend.register_event_unload = function(func)
    windower.register_event('unload', func)
end

backend.register_command = function(func)
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

backend.register_on_zone_change = function(func)
    windower.register_event('zone change', func)
end

backend.register_event_incoming_text = function(func)
    local adaptor = function(original, modified, original_mode, modified_mode)
        -- replace autotranslate tags with brackets
        original = (original:gsub(string.char(0xEF) .. '[' .. string.char(0x27) .. ']', '{'));
        original = (original:gsub(string.char(0xEF) .. '[' .. string.char(0x28) .. ']', '}'));
        func(original_mode, original:strip_colors())
    end
    windower.register_event('incoming text', adaptor)
end

backend.register_event_prerender = function(func)
    windower.register_event('prerender', func)
end

backend.register_event_postrender = function(func)
    windower.register_event('postrender', func)
end

--------------------------------
-- File IO
--------------------------------
backend.dir_exists = function(path)
    return windower.dir_exists(path)
end

backend.file_exists = function(path)
    return windower.file_exists(path)
end

backend.create_dir = function(filename)
    windower.create_dir(backend.script_path() .. filename)
end

backend.list_files = function(path)
    return windower.get_dir(backend.script_path() .. path)
end

--------------------------------
-- Text Display
--------------------------------

-- Override texts.new and texts.destroy to enable
-- movement only on shift+click
local texts_settings = T {}
texts.oldnew = texts.new
texts.new = function(str, settings, root_settings)
    settings = settings or { flags = { draggable = false } }
    settings.flags = settings.flags or { draggable = false }
    settings.flags.draggable = false
    local ret = texts.oldnew(str, settings, root_settings)
    texts_settings[ret._name] = settings
    return ret
end

texts.destroy = function(t)
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
    local box                          = {}

    captain.settings.textBox.store[id] = captain.settings.textBox.store[id] or
        utils.deepCopy(captain.settings.textBox.defaults)
    box.impl                           = texts.new('', captain.settings.textBox.store[id], captain.settings)

    box.title                          = ''
    box.text                           = ''

    box.show                           = function(self)
        self.impl:show()
    end

    box.hide                           = function(self)
        self.impl:hide()
    end

    box.updateTitle                    = function(self, str)
        self.title = str
        texts.text(self.impl, self.title .. '\n' .. self.text)
    end

    box.updateText                     = function(self, str)
        self.text = str
        texts.text(self.impl, self.title .. '\n' .. self.text)
    end

    box.updatePos                      = function(self, x, y)
        texts.pos(self.impl, x, y)
    end

    box.applySettings                  = function(self, settings)
        if settings.bg then
            texts.bg_alpha(self.impl, settings.bg.alpha)
            texts.bg_color(self.impl, settings.bg.red, settings.bg.green, settings.bg.blue)
            texts.bg_visible(self.impl, settings.bg.visible)
        end

        if settings.text then
            texts.color(self.impl, settings.text.red, settings.text.green, settings.text.blue)
            texts.alpha(self.impl, settings.text.alpha)
            texts.font(self.impl, settings.text.font)
            texts.size(self.impl, settings.text.size)
        end

        texts.pad(self.impl, settings.padding)

        if settings.flags then
            texts.italic(self.impl, settings.flags.italic)
            texts.bold(self.impl, settings.flags.bold)
            texts.right_justified(self.impl, settings.flags.right)
            texts.bottom_justified(self.impl, settings.flags.bottom)
        end

        if settings.text.stroke then
            texts.stroke_width(self.impl, settings.text.stroke.width)
            texts.stroke_color(self.impl, settings.text.stroke.red, settings.text.stroke.green, settings.text.stroke
            .blue)
            texts.stroke_alpha(self.impl, settings.text.stroke.alpha)
        end
    end

    box:applySettings(captain.settings.textBox.store[id])
    box:updateText('')
    box:show()
    config.reload(captain.settings)

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

backend.registerKeyBind   = function(params, command)
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

backend.deregisterKeyBind = function(params)
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


backend.convert_int_to_float     = function(raw)
    return string.pack('I', raw):unpack('f')
end

local notificationBoxes          = nil

backend.boxDestroy               = function(box)

    if notificationBoxes and box and box._impl then
        box._impl:hide()
    end
end

local function strip_colors(s)
    return s:gsub("\\cs%(%d+,%d+,%d+%)", "")
end

backend.boxDraw           = function(box)
    -- Precreate boxes
    if not notificationBoxes then
        notificationBoxes = {}
        local font_size = captain.settings.box.text.size or 10
        local line_count = 5
        local line_spacing = 2
        local box_padding = 50 -- as determined by the scientific process of incrementing and retrying
        local height = (font_size * line_count) + (line_spacing * (line_count - 1)) + box_padding

        local base_x = captain.settings.textBox.store.box.pos.x or captain.settings.box.pos.x
        local base_y = captain.settings.textBox.store.box.pos.y or captain.settings.box.pos.y

        for i = 1, captain.settings.box.max_num do
            local nb = backend.textBox('box')
            nb:applySettings(captain.settings.box)
            local y_pos = base_y + (i - 1) * height
            nb:updatePos(base_x, y_pos)
            nb:hide()
            notificationBoxes[i] = nb
        end
    end

    local c = ''
    local lines = {}
    local current_line = ""

    for _, segment in ipairs(box.segments) do
        if segment.newline then
            table.insert(lines, current_line)
            current_line = ""
        elseif segment.text then
            if segment.color then
                current_line = current_line ..
                    string.format('\\cs(%d,%d,%d)', segment.color[1], segment.color[2], segment.color[3]) .. segment
                    .text
            else
                current_line = current_line .. segment.text
            end
        end
    end

    -- Add last line if leftover
    if current_line ~= "" or #lines == 0 then
        table.insert(lines, current_line)
    end

    -- Ensure first line has at least 50 visible chars (exclude color codes)
    if lines[1] then
        local visible_len = #strip_colors(lines[1])
        if visible_len < 50 then
            lines[1] = lines[1] .. string.rep(' ', 50 - visible_len)
        end
    else
        lines[1] = string.rep(' ', 50)
    end

    -- Ensure we have at least 5 lines
    while #lines < 5 do
        table.insert(lines, "")
    end

    c = table.concat(lines, '\n')
    local nb = notificationBoxes[box.displayIndex]
    if nb then
        nb:updateText(c)
        nb:show()
        box._impl = nb
    end

    return 0
end

backend.loadConfig        = function(name, defaults)
    return config.load('data/' .. name .. '.xml', defaults)
end

backend.scale_font        = function(height)
    return height
end

backend.scale_width       = function(width)
    return width
end

backend.scale_height      = function(height)
    return height
end

backend.reload            = function()
    captain.reloadSignal = true
    backend.msg('captain', 'Reloading. Coroutines may take a moment to finish.')
    windower.send_command('lua reload captain')
end

return backend
