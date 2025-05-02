-- Credits: Original code written by ibm2431, ported by sruon
---@class ActionViewAddon : AddonInterface
---@field files { simple: File?, capture: { simple: File? } } File handles for logging
---@field rootDir string Directory where logs are stored
---@field captureDir string? Directory where capture logs are stored
---@field color { log: table, box: table, notification: table } Color settings for display
---@field h table Headers for log strings
---@field vars { zone_start: number, zone_end: number } Zone-specific variables
---@field databases { global: table, capture: table } Action databases
local addon =
{
    name            = 'ActionView',
    filters         =
    {
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_BATTLE2] = true,
        },
    },
    settings        = {},
    defaultSettings =
    {
        mobsOnly = true,
        category =
        {
            [1]  = false, -- Melee Attack
            [2]  = false, -- Ranged Attack execution
            [3]  = true,  -- WS or some damaging JAs; "ability IDs are unshifted, WS IDs shifted to +768"
            [4]  = true,  -- Casted magic
            [5]  = true,  -- Item Usage execution
            [6]  = true,  -- Most job abilities
            [7]  = true,  -- TP Move Start "Players: add 768, compare abils.xml. Mobs: -256, mabils.xml"
            [8]  = false, -- Spell Start
            [9]  = false, -- Item Usage initiation
            [10] = false, -- Unknown category
            [11] = true,  -- Mob TP moves
            [12] = false, -- Ranged Attack initiation
            [13] = true,  -- Pet TP Moves
            [14] = true,  -- Non-blinkable job abilities (Jigs, Sambas, Steps, Waltzes, Flourish)
            [15] = true,  -- Some RUN job abilities
        },
        color =
        {
            id        = 22, -- Red Lotus Blade
            name      = 24, -- 34
            actor     = 12, -- 01234567 (Name)
            animation = 20, -- 3
            category  = 11, -- 3
            message   = 25, -- 185
            system    = 19,
        },
        database =
        {
            max_history    = 10,
            sort_keys      =
            {
                'actor_name',
                'name',
            },
            ignore_updates =
            {
            },
        },
    },
    databases       =
    {
        global =
        {
            zone = {},
            category =
            {

            },
        },
        capture =
        {
            zone = nil,
            category =
            {
            },
        },
    },
    files           =
    {
        simple  = nil,
        capture =
        {
            simple = nil,
        },
    },
    category        =
    {
        ['1']  = 'Melee', -- Melee Attack
        ['2']  = 'RA',    -- Ranged Attack execution
        ['3']  = 'WS-JA', -- WS or some damaging JAs; "ability IDs are unshifted, WS IDs shifted to +768"
        ['4']  = 'MA',    -- Casted magic
        ['5']  = 'Item',  -- Item Usage execution
        ['6']  = 'JA',    -- Most job abilities
        ['7']  = 'TP-St', -- TP Move Start "Players: add 768, compare abils.xml. Mobs: -256, mabils.xml"
        ['8']  = 'MA-St', -- Spell Start
        ['9']  = 'Itm-S', -- Item Usage initiation
        ['10'] = 'Unkwn', -- Unknown category
        ['11'] = 'Mb-TP', -- Mob TP moves
        ['12'] = 'RA-St', -- Ranged Attack initiation
        ['13'] = 'Pt-TP', -- Pet TP Moves
        ['14'] = 'Nb-JA', -- Non-blinkable job abilities (Jigs, Sambas, Steps, Waltzes, Flourish)
        ['15'] = 'RN-JA', -- Some RUN job abilities
    },
}

-- Builds a colorized chatlog string
--------------------------------------------------
local function buildChatlogString(info)
    local chatlog_string = addon.h.name .. addon.h.category .. '%s ' ..
      addon.h.id .. '%s ' .. addon.h.animation .. '%s ' ..
      addon.h.message .. '%s'
    return string.format(chatlog_string, info.name, info.category, info.id, info.animation, info.message)
end

-- Builds a simple string for file logging
--------------------------------------------------
local function buildSimpleString(info)
    local simple_info = '[Actor: %s (%s)] %s > Cat: %s ID: %s Anim: %s Msg: %s'
    return string.format(simple_info, info.actor, info.actor_name, info.name, info.category, info.id, info.animation,
        info.message)
end

-- Checks if a mob ID belongs to a "mob" based on the current zone
---------------------------------------------------------------------
local function isMob(id)
    return (id >= addon.vars.zone_start) and (id <= addon.vars.zone_end)
end

local function parseAction(action)
    local result = {}

    local categories =
    {
        [1] = function(action)
            return 'Melee Attack'
        end,                                               -- Melee Attack
        [2] = function(action) return 'Ranged Attack' end, -- Ranged Attack execution
        [3] = function(action)                             -- WS or some damaging JAs
            local message = action.target[1].result[1].message
            if action.cmd_arg >= 257 then
                return backend.get_monster_ability_name(action.cmd_arg)
            elseif message == 317 or message == 324 then
                return backend.get_job_ability_name(action.cmd_arg)
            else
                return backend.get_weapon_skill_name(action.cmd_arg)
            end
        end,
        [4] = function(action) -- Casted magic
            return backend.get_spell_name(action.cmd_arg)
        end,
        [5] = function(action) return backend.get_item_name(action.cmd_arg) end, -- Item Usage execution
        [6] = function(action)                                                   -- Most job abilities; can include monster abilities
            if isMob(action.m_uID) then
                return backend.get_monster_ability_name(action.cmd_arg)
            else
                return backend.get_job_ability_name(action.cmd_arg)
            end
        end,
        [7] = function(action) -- OK
            if isMob(action.m_uID) then
                return backend.get_monster_ability_name(action.target[1].result[1].value)
            else
                return backend.get_weapon_skill_name(action.target[1].result[1].value)
            end
        end,                                                                                        -- TP Move Start
        [8] = function(action) return backend.get_spell_name(action.target[1].result[1].value) end, -- Spell Start
        [9] = function(action) return backend.get_item_name(action.target[1].result[1].value) end,  -- Item Usage initiation
        [11] = function(action)
            return backend.get_monster_ability_name(action.cmd_arg)
        end,
        [12] = function(action) return 'Ranged Attack (Start)' end,                      -- Ranged Attack initiation
        [13] = function(action) return backend.get_job_ability_name(action.cmd_arg) end, -- Pet TP Moves
        [14] = function(action) return backend.get_job_ability_name(action.cmd_arg) end, -- Non-blinkable job abilities (Jigs, Sambas, Steps, Waltzes, Flourish)
        [15] = function(action) return backend.get_job_ability_name(action.cmd_arg) end, -- Some RUN job abilities
    }
    result.ActionType = action.ActionType
    result.category = action.cmd_no
    result.actor = action.m_uID

    if result.category == 7 then -- TP Move Start has the ID in the target array
        result.id = action.target[1].result[1].value
    else
        result.id = action.cmd_arg
    end
    if action.target and action.target[1] then
        if action.target[1].result and action.target[1].result[1] then
            result.message = action.target[1].result[1].message
            result.animation = action.target[1].result[1].sub_kind
            if action.cmd_no == 8 then
                result.id = action.target[1].result[1].value
            end
        end
    end

    local str_info = {}
    for k, v in pairs(result) do
        str_info[k] = tostring(v)
    end

    local names = categories[action.cmd_no]
    if names then
        result.name = names(action)
        if not result.name then
            result.name = 'Unknown Ability'
        end
    else
        result.name = 'Unknown Ability'
    end
    str_info.name = result.name

    result.actor_name = ''
    local mob = backend.get_mob_by_id(action.m_uID)
    if mob and mob.name then
        result.actor_name = mob.name
    end
    str_info.actor_name = result.actor_name

    return result, str_info
end

-- Inserts an action into a category DB
---------------------------------------------------------------------
local function addActionToCategory(db, result)
    local category_db = db.category[result.category]

    local mt = getmetatable(category_db)
    local r = category_db:add_or_update(result.id, result)

    return r == mt.RESULT_NEW
end

-- Inserts an action into a zone mob DB
---------------------------------------------------------------------
local function addActionToMobList(db, result)
    local zone_db = db.zone

    local mob_key = string.format('%08d-%03d', result.actor, result.id)
    zone_db:add_or_update(mob_key, result)

    local cat_db = db.category[result.category]
    local mt = getmetatable(cat_db)
    local r = cat_db:add_or_update(mob_key, result)

    return r == mt.RESULT_NEW
end

local function recordAction(result, str_info)
    local new_mob_ability = addActionToMobList(addon.databases.global, result)

    local simple_string = buildSimpleString(str_info)
    addon.files.simple:append(simple_string .. '\n\n')

    if addon.databases.capture.zone then
        new_mob_ability = addActionToMobList(addon.databases.capture, result)
        addon.files.capture.simple:append(simple_string .. '\n\n')
    end
end

local function createActionNotification(result)
    -- Create title with ability name
    local title = string.format('%s [%s]', result.name, result.ActionType)

    -- Extract data fields from result - use array of key-value pairs to preserve order
    local dataFields = {}

    -- Add actor information
    local actorText = result.actor
    local mob = backend.get_mob_by_id(result.actor)
    if mob and mob.name then
        actorText = string.format('%d (%s)', result.actor, mob.name)
    end

    table.insert(dataFields, { 'Actor', actorText })

    -- Add important fields
    table.insert(dataFields, { 'ID', result.id })
    table.insert(dataFields, { 'Animation', result.animation })

    if result.message then
        table.insert(dataFields, { 'Message', result.message })
    end

    backend.notificationCreate('AView', title, dataFields, false)
end

local function checkAction(data)
    local action = backend.parsePacket('incoming', data)
    if not action then
        return
    end

    -- If we're interested in that particular action type
    if addon.settings.category[action.cmd_no] then
        if (not addon.settings.mobsOnly) or isMob(action.m_uID) then
            local result, str_info = parseAction(action)
            if result and (result.message ~= 84) then
                recordAction(result, str_info)

                -- Create notification with the new API
                createActionNotification(result)

                -- Notification already creates a chatlog string
                -- backend.msg('AView', buildChatlogString(str_info))
            end
        end
    end
end

-- Prepares master databases for all action categories
--------------------------------------------------
local function prepareCategoryDatabases()
    for i = 1, 15 do
        local path = string.format('%s/category/%s.lua', addon.rootDir, addon.category[tostring(i)])
        addon.databases.global.category[i] = backend.databaseOpen(path, addon.settings.database)

        -- Prepare category databases for a capture
        if captain.isCapturing then
            local capture_path = string.format('%s/category/%s.lua', addon.captureDir,
                addon.category[tostring(i)])
            addon.databases.capture.category[i] = backend.databaseOpen(capture_path, addon.settings.database)
        end
    end
end

-- Loads a zone database into memory
--------------------------------------------------
local function prepareZoneDatabase(zone)
    local path = string.format('%s/zone/%s.lua', addon.rootDir, backend.zone_name(zone))
    addon.databases.global.zone = backend.databaseOpen(path, addon.settings.database)

    if captain.isCapturing then
        local capture_path = string.format('%s/zone/%s.lua', addon.captureDir, backend.zone_name(zone))
        addon.databases.capture.zone = backend.databaseOpen(capture_path, addon.settings.database)
    end
end

-- Sets up tables and files for use in the current zone
--------------------------------------------------
local function setupZone(zone)
    local current_zone = backend.zone_name()
    prepareZoneDatabase(zone)

    addon.vars.zone_start = bit.lshift(zone, 12) + 0x1000000
    addon.vars.zone_end = addon.vars.zone_start + 1024 -- Full block of NPCs and mobs

    addon.files.simple = backend.fileOpen(addon.rootDir .. 'simple/' .. current_zone .. '.log')

    if captain.isCapturing then
        addon.files.capture.simple = backend.fileOpen(addon.captureDir .. 'simple/' .. current_zone .. '.log')
    end
end

---------------------------------------------------------------------------------
-- INITIALIZE
---------------------------------------------------------------------------------
local function initialize(rootDir)
    ---------------------------------------------------------------------------------
    -- DISPLAY COLORS AND LOG HEADERS
    ---------------------------------------------------------------------------------

    addon.rootDir = rootDir
    addon.color = {}
    addon.color.log =
    { -- Preformatted character codes for log colors.
        ID        = colors[addon.settings.color.id].chatColorCode,
        NAME      = colors[addon.settings.color.name].chatColorCode,
        ACTOR     = colors[addon.settings.color.actor].chatColorCode,
        ANIMATION = colors[addon.settings.color.animation].chatColorCode,
        CATEGORY  = colors[addon.settings.color.category].chatColorCode,
        MESSAGE   = colors[addon.settings.color.message].chatColorCode,
        SYSTEM    = colors[addon.settings.color.system].chatColorCode,
    }
    addon.color.notification =
    { -- \\cs(#,#,#) values for Windower text boxes
        SYSTEM    = colors[addon.settings.color.system].rgb,
        NAME      = colors[addon.settings.color.name].rgb,
        ACTOR     = colors[addon.settings.color.actor].rgb,
        CATEGORY  = colors[addon.settings.color.category].rgb,
        ID        = colors[addon.settings.color.id].rgb,
        ANIMATION = colors[addon.settings.color.animation].rgb,
        MESSAGE   = colors[addon.settings.color.message].rgb,
    }

    addon.h =
    { -- Headers for log string. ex: NPC:
        id        = addon.color.log.SYSTEM .. 'ID: ' .. addon.color.log.ID,
        name      = addon.color.log.NAME .. '%s' .. addon.color.log.SYSTEM .. ' > ',
        animation = addon.color.log.SYSTEM .. 'Anim: ' .. addon.color.log.ANIMATION,
        category  = addon.color.log.SYSTEM .. 'Cat: ' .. addon.color.log.CATEGORY,
        message   = addon.color.log.SYSTEM .. 'Msg: ' .. addon.color.log.MESSAGE,
    }

    ---------------------------------------------------------------------------------
    -- VARIABLES AND TEMPLATES
    ---------------------------------------------------------------------------------

    addon.vars = {}

    addon.files = {}
    addon.files.capture = {}
    addon.files.simple = backend.fileOpen(addon.rootDir .. backend.player_name() .. '/logs/simple.log')

    prepareCategoryDatabases()
    setupZone(backend.zone())
end

addon.onZoneChange = setupZone

addon.onIncomingPacket = function(id, data)
    checkAction(data)
end

addon.onCaptureStart = function(captureDir)
    addon.captureDir = captureDir

    prepareCategoryDatabases()
    setupZone(backend.zone())
end

addon.onCaptureStop = function()
    addon.captureDir = nil

    for _, db in ipairs(addon.databases.capture.category) do
        db:close()
    end
    addon.databases.capture.category = {}
    addon.databases.capture.zone:close()
    addon.databases.capture.zone = nil
end

addon.onInitialize = initialize

addon.onPrerender = function()
    if not addon.coroutinesSetup then
        backend.forever(function()
            local dbUpdated = {}
            table.insert(dbUpdated, addon.databases.global.zone:save())
            for _, db in ipairs(addon.databases.global.category) do
                table.insert(dbUpdated, db:save())
            end

            if addon.databases.capture.zone ~= nil then
                table.insert(dbUpdated, addon.databases.capture.zone:save())
                for _, db in ipairs(addon.databases.capture.category) do
                    table.insert(dbUpdated, db:save())
                end
            end

            for _, res in ipairs(dbUpdated) do
                if res == true then
                    backend.msg('AView', 'Databases saved!')
                    return
                end
            end
        end, 10)

        addon.coroutinesSetup = true
    end
end

return addon
