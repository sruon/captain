-- Credits: Original code written by ibm2431, ported by sruon
local socket = require('socket')

---@class ActionViewAddon : AddonInterface
---@field files { simple: File?, capture: { simple: File? } } File handles for logging
---@field rootDir string Directory where logs are stored
---@field captureDir string? Directory where capture logs are stored
---@field color { log: table, box: table, notification: table } Color settings for display
---@field h table Headers for log strings
---@field vars { zone_start: number, zone_end: number } Zone-specific variables
---@field databases { global: table, capture: table } Action databases
local addon  =
{
    name             = 'ActionView',
    filters          =
    {
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_BATTLE2] = true,
        },
    },
    settings         = {},
    defaultSettings  =
    {
        mobsOnly  = true,
        showProcs = true,
        category  =
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
        color     =
        {
            id        = 22, -- Red Lotus Blade
            name      = 24, -- 34
            actor     = 12, -- 01234567 (Name)
            animation = 20, -- 3
            category  = 11, -- 3
            message   = 25, -- 185
            system    = 19,
        },
        database  =
        {
            max_history    = 10,
            ignore_updates =
            {
            },
        },
    },
    databases        =
    {
        global  = nil,
        capture = nil,
    },

    -- Action schema based on actual data structure
    schema           =
    {
        ActionType   = 'Physical',        -- Action type string
        category     = 1,                 -- Category number (cmd_no)
        actor        = 12345,             -- Actor ID (m_uID)
        id           = 123,               -- Action/ability ID
        message      = 1,                 -- Message ID from target result
        animation    = 456,               -- Animation ID (sub_kind)
        name         = 'Example Ability', -- Resolved action name
        actor_name   = 'Actor Name',      -- Resolved actor name
        knockback    = 0,                 -- Knockback value
        ready_time   = 0.0,               -- Ready time (ms) from start to finish
        info         = 0,                 -- Info field from target result
        proc_kind    = 0,                 -- Proc kind (added effect type)
        proc_info    = 0,                 -- Proc info
        proc_value   = 0,                 -- Proc value (damage/amount)
        proc_message = 0,                 -- Proc message ID
        max_range    = 0.0,               -- Maximum distance from mob to furthest target (for mob skills)
        max_spread   = 0.0,               -- Maximum distance between any two targets (for mob skills)
    },
    files            =
    {
        simple  = nil,
        capture =
        {
            simple = nil,
        },
    },
    category         =
    {
        ['1']  = 'Melee',  -- Melee Attack
        ['2']  = 'RA',     -- Ranged Attack execution
        ['3']  = 'WS-JA',  -- WS or some damaging JAs; "ability IDs are unshifted, WS IDs shifted to +768"
        ['4']  = 'MA',     -- Casted magic
        ['5']  = 'Item',   -- Item Usage execution
        ['6']  = 'JA',     -- Most job abilities
        ['7']  = 'TP-St',  -- TP Move Start "Players: add 768, compare abils.xml. Mobs: -256, mabils.xml"
        ['8']  = 'MA-St',  -- Spell Start
        ['9']  = 'Itm-S',  -- Item Usage initiation
        ['10'] = 'Unkwn',  -- Unknown category
        ['11'] = 'Mb-TP',  -- Mob TP moves
        ['12'] = 'RA-St',  -- Ranged Attack initiation
        ['13'] = 'Pt-TP',  -- Pet TP Moves
        ['14'] = 'Nb-JA',  -- Non-blinkable job abilities (Jigs, Sambas, Steps, Waltzes, Flourish)
        ['15'] = 'RN-JA',  -- Some RUN job abilities
    },
    actionStartTimes = {}, -- Track start times for actions (category 7/8/12 -> finish category)
}

-- Builds a simple string for file logging
--------------------------------------------------
local function buildSimpleString(info)
    local simple_info = '[Actor: %s (%s)] %s > Cat: %s ID: %s Anim: %s Msg: %s'
    local base_str    = string.format(simple_info, info.actor, info.actor_name, info.name, info.category, info.id,
        info.animation,
        info.message)

    -- Append range and spread for mob skills (category 11)
    if info.category == '11' then
        local max_range  = tonumber(info.max_range or 0)
        local max_spread = tonumber(info.max_spread or 0)
        if max_range > 0 then
            base_str = base_str .. string.format(' Range: %.2f', max_range)
        end
        if max_spread > 0 then
            base_str = base_str .. string.format(' Spread: %.2f', max_spread)
        end
    end

    return base_str
end

-- Checks if a mob ID belongs to a "mob" based on the current zone
---------------------------------------------------------------------
local function isMob(id)
    local zStart = bit.lshift(backend.zone(), 12) + 0x1000000
    return (id >= zStart) and (id <= zStart + 1024)
end

local function parseAction(action)
    local result      = {}

    local categories  =
    {
        [1]  = function(action)
            return 'Melee Attack'
        end,                                                -- Melee Attack
        [2]  = function(action) return 'Ranged Attack' end, -- Ranged Attack execution
        [3]  = function(action)                             -- WS or some damaging JAs
            local message = action.target[1].result[1].message
            if action.cmd_arg >= 257 then
                return backend.get_monster_ability_name(action.cmd_arg)
            elseif message == 317 or message == 324 then
                return backend.get_job_ability_name(action.cmd_arg)
            else
                return backend.get_weapon_skill_name(action.cmd_arg)
            end
        end,
        [4]  = function(action) -- Casted magic
            return backend.get_spell_name(action.cmd_arg)
        end,
        [5]  = function(action) return backend.get_item_name(action.cmd_arg) end, -- Item Usage execution
        [6]  = function(action)                                                   -- Most job abilities; can include monster abilities
            if isMob(action.m_uID) then
                return backend.get_monster_ability_name(action.cmd_arg)
            else
                return backend.get_job_ability_name(action.cmd_arg)
            end
        end,
        [7]  = function(action) -- OK
            if isMob(action.m_uID) then
                return backend.get_monster_ability_name(action.target[1].result[1].value)
            else
                return backend.get_weapon_skill_name(action.target[1].result[1].value)
            end
        end,                                                                                         -- TP Move Start
        [8]  = function(action) return backend.get_spell_name(action.target[1].result[1].value) end, -- Spell Start
        [9]  = function(action) return backend.get_item_name(action.target[1].result[1].value) end,  -- Item Usage initiation
        [11] = function(action)
            return backend.get_monster_ability_name(action.cmd_arg)
        end,
        [12] = function(action) return 'Ranged Attack (Start)' end,                      -- Ranged Attack initiation
        [13] = function(action) return backend.get_job_ability_name(action.cmd_arg) end, -- Pet TP Moves
        [14] = function(action) return backend.get_job_ability_name(action.cmd_arg) end, -- Non-blinkable job abilities (Jigs, Sambas, Steps, Waltzes, Flourish)
        [15] = function(action) return backend.get_job_ability_name(action.cmd_arg) end, -- Some RUN job abilities
    }
    result.ActionType = action.ActionType
    result.category   = action.cmd_no
    result.actor      = action.m_uID
    result.ready_time = 0 -- Initialize ready_time (0 = not tracked)

    -- Extract ID - some categories have ID in target array, others in cmd_arg
    if result.category == 7 then
        -- TP Move Start (7) has the ID in the target array
        if action.target and action.target[1] and action.target[1].result and action.target[1].result[1] then
            result.id = action.target[1].result[1].value
        else
            result.id = action.cmd_arg
        end
    else
        result.id = action.cmd_arg
    end

    -- Iterate over all targets and results
    result.message      = 0
    result.animation    = 0
    result.knockback    = 0
    result.info         = 0
    result.proc_kind    = 0
    result.proc_info    = 0
    result.proc_value   = 0
    result.proc_message = 0
    result.max_range    = 0.0
    result.max_spread   = 0.0

    if action.target then
        -- Get message and animation from first target's first result
        if action.target[1] and action.target[1].result and action.target[1].result[1] then
            result.message   = action.target[1].result[1].message
            result.animation = action.target[1].result[1].sub_kind

            -- Capture proc (added effect) data from first target's first result
            if action.target[1].result[1].proc then
                result.proc_kind    = action.target[1].result[1].proc.kind or 0
                result.proc_info    = action.target[1].result[1].proc.info or 0
                result.proc_value   = action.target[1].result[1].proc.value or 0
                result.proc_message = action.target[1].result[1].proc.message or 0
            end
        end

        -- Get actor position and collect target positions for distance calculations (mob skills only)
        local actorMob        = nil
        local targetPositions = {}
        if result.category == 11 then
            actorMob = backend.get_mob_by_id(action.m_uID)
        end

        -- Iterate over all targets and their results
        for i = 1, #action.target do
            local target = action.target[i]
            if target.result then
                for j = 1, #target.result do
                    local targetResult = target.result[j]

                    -- Capture highest knockback value
                    if targetResult.knockback and targetResult.knockback > result.knockback then
                        result.knockback = targetResult.knockback
                    end

                    -- Check if any result has critical bit set (bit 1)
                    if targetResult.info and bit.band(targetResult.info, 2) == 2 then
                        result.info = bit.bor(result.info, 2)
                    end
                end

                -- Collect target positions for mob skills (category 11)
                if result.category == 11 and actorMob then
                    local targetMob = backend.get_mob_by_id(target.m_uID)
                    if targetMob and targetMob.x then
                        table.insert(targetPositions,
                        {
                            x = tonumber(targetMob.x),
                            y = tonumber(targetMob.y),
                            z = tonumber(targetMob.z),
                        })
                    end
                end
            end
        end

        -- Calculate range and spread for mob skills
        if result.category == 11 and actorMob and #targetPositions > 0 then
            local actorX = tonumber(actorMob.x)
            local actorY = tonumber(actorMob.y)
            local actorZ = tonumber(actorMob.z)

            -- Calculate max range (mob to furthest target)
            for _, pos in ipairs(targetPositions) do
                local dx       = pos.x - actorX
                local dy       = pos.y - actorY
                local dz       = pos.z - actorZ
                local distance = math.sqrt(dx * dx + dy * dy + dz * dz)

                if distance > result.max_range then
                    result.max_range = distance
                end
            end

            -- Calculate max spread (distance between any two targets)
            for i = 1, #targetPositions do
                for j = i + 1, #targetPositions do
                    local dx       = targetPositions[j].x - targetPositions[i].x
                    local dy       = targetPositions[j].y - targetPositions[i].y
                    local dz       = targetPositions[j].z - targetPositions[i].z
                    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)

                    if distance > result.max_spread then
                        result.max_spread = distance
                    end
                end
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
    str_info.name     = result.name

    result.actor_name = ''
    local mob         = backend.get_mob_by_id(action.m_uID)
    if mob and mob.name then
        result.actor_name = mob.name
    end
    str_info.actor_name = result.actor_name

    return result, str_info
end

-- Inserts an action into a zone mob DB
---------------------------------------------------------------------
local function addActionToMobList(result)
    local mob_key = string.format('%08d-%03d', result.actor, result.id)

    -- For mob skills, track the maximum range and spread across all uses
    if result.category == 11 then
        if addon.databases.global then
            local existing = addon.databases.global:get(mob_key)
            if existing then
                if existing.max_range and result.max_range > 0 then
                    result.max_range = math.max(result.max_range, existing.max_range)
                end
                if existing.max_spread and result.max_spread > 0 then
                    result.max_spread = math.max(result.max_spread, existing.max_spread)
                end
            end
        end
    end

    if addon.databases.global then
        addon.databases.global:add_or_update(mob_key, result)
    end

    if addon.databases.capture then
        addon.databases.capture:add_or_update(mob_key, result)
    end
end

local function recordAction(result, str_info)
    addActionToMobList(result)

    local simple_string = buildSimpleString(str_info)
    addon.files.simple:append(simple_string .. '\n\n')

    if addon.captureDir then
        addActionToMobList(result)
        addon.files.capture.simple:append(simple_string .. '\n\n')
    end
end

local function createActionNotification(result)
    -- Create title with ability name
    local title      = string.format('%s [%s]', result.name, result.ActionType)

    -- Extract data fields from result - use array of key-value pairs to preserve order
    local dataFields = {}

    -- Add actor information
    local actorText  = result.actor
    local mob        = backend.get_mob_by_id(result.actor)
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

    if result.knockback > 0 then
        table.insert(dataFields, { 'Knockback', result.knockback })
    end

    -- Check if second bit of info is set for mob skills (11) and weapon skills (3)
    if (result.category == 11 or result.category == 3) and result.info then
        local infoBit1 = bit.band(result.info, 2)
        if infoBit1 == 2 then
            table.insert(dataFields, { 'Critical Hit', 'YES' })
        end
    end

    -- Display proc (added effect) information for melee attacks
    if addon.settings.showProcs and result.category == 1 and result.proc_message and result.proc_message > 0 then
        table.insert(dataFields, { 'Proc Kind', result.proc_kind })
        table.insert(dataFields, { 'Proc Info', result.proc_info })
        table.insert(dataFields, { 'Proc Value', result.proc_value })
        table.insert(dataFields, { 'Proc Message', result.proc_message })
    end

    if result.ready_time and result.ready_time > 0 then
        table.insert(dataFields, { 'Ready Time', string.format('%.0fms', result.ready_time) })
    end

    -- Display range and spread for mob skills
    if result.category == 11 then
        if result.max_range > 0 then
            table.insert(dataFields, { 'Range', string.format('%.2f', result.max_range) })
        end
        if result.max_spread > 0 then
            table.insert(dataFields, { 'Spread', string.format('%.2f', result.max_spread) })
        end
    end

    backend.notificationCreate('AView', title, dataFields)
end

local function checkAction(packet)
    if not packet then
        return
    end
    local action = packet

    local result, str_info = parseAction(action)
    if not result or result.message == 84 then
        return
    end

    -- Check if we should process this action
    local shouldProcess = false

    -- Always show if the category is enabled
    if addon.settings.category[action.cmd_no] then
        if (not addon.settings.mobsOnly) or isMob(action.m_uID) then
            shouldProcess = true
        end
    end

    -- Special case: Show melee attacks (category 1) if showProcs is enabled and there's a proc
    if addon.settings.showProcs and action.cmd_no == 1 and result.proc_message and result.proc_message > 0 then
        if (not addon.settings.mobsOnly) or isMob(action.m_uID) then
            shouldProcess = true
        end
    end

    if shouldProcess then
        -- Calculate ready time delta for finish actions (in milliseconds)
        if action.cmd_no == 11 or action.cmd_no == 4 or action.cmd_no == 2 then
            local key = tostring(action.m_uID)
            if addon.actionStartTimes[key] then
                result.ready_time           = (socket.gettime() * 1000) - addon.actionStartTimes[key]
                addon.actionStartTimes[key] = nil
            end
        end

        recordAction(result, str_info)

        createActionNotification(result)
    end
end


-- Sets up tables and files for use in the current zone
--------------------------------------------------
local function setupZone(zone)
    local current_zone = backend.zone_name()

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

    addon.rootDir            = rootDir
    addon.color              = {}
    addon.color.log          =
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

    addon.h                  =
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

    addon.vars               = {}

    addon.files              = {}
    addon.files.capture      = {}
    addon.files.simple       = backend.fileOpen(addon.rootDir .. backend.player_name() .. '/logs/simple.log')

    -- Create single actions database instead of 15 category databases
    local actions_path       = string.format('%s/%s/Actions.db', addon.rootDir, backend.player_name())
    addon.databases.global   = backend.databaseOpen(actions_path,
        {
            schema      = addon.schema,
            max_history = addon.settings.database and addon.settings.database.max_history,
        })

    setupZone(backend.zone())
end

addon.onClientReady    = setupZone

addon.onIncomingPacket = function(id, data, size, packet)
    -- Always track start times for timing purposes, even if category is disabled
    if packet then
        -- Track start times for timing (category 7: TP-St, 8: MA-St, 12: RA-St)
        if packet.cmd_no == 7 or packet.cmd_no == 8 or packet.cmd_no == 12 then
            -- Since only one action can be in progress per actor, key by actor ID only
            local key                   = tostring(packet.m_uID)
            addon.actionStartTimes[key] = socket.gettime() * 1000
        end
    end

    checkAction(packet)
end

addon.onCaptureStart   = function(captureDir)
    addon.captureDir           = captureDir

    -- Create single actions database for capture instead of 15 category databases
    local capture_actions_path = string.format('%s/%s/Actions.db', captureDir, backend.player_name())
    addon.databases.capture    = backend.databaseOpen(capture_actions_path,
        {
            schema      = addon.schema,
            max_history = addon.settings.database and addon.settings.database.max_history,
        })

    setupZone(backend.zone())
end

addon.onCaptureStop    = function()
    addon.captureDir = nil

    if addon.databases.capture then
        addon.databases.capture:close()
        addon.databases.capture = nil
    end
end

addon.onUnload         = function()
    addon.onCaptureStop()
    addon.databases.global:close()
end

addon.onInitialize     = initialize

addon.onConfigMenu     = function()
    return
    {
        {
            key         = 'mobsOnly',
            title       = 'Mobs Only',
            description =
            'If enabled, only displays notifications for mob actions. If disabled, shows player actions too.',
            type        = 'checkbox',
            default     = addon.defaultSettings.mobsOnly,
        },
        {
            key         = 'showProcs',
            title       = 'Show Procs (Added Effects)',
            description =
            'If enabled, displays proc information for melee attacks even if melee attack category is disabled.',
            type        = 'checkbox',
            default     = addon.defaultSettings.showProcs,
        },
        {
            key         = 'category.1',
            title       = 'Category 1: Melee Attack',
            description = 'Show notifications for melee attacks',
            type        = 'checkbox',
            default     = addon.defaultSettings.category[1],
        },
        {
            key         = 'category.2',
            title       = 'Category 2: Ranged Attack (Finish)',
            description = 'Show notifications for ranged attack execution',
            type        = 'checkbox',
            default     = addon.defaultSettings.category[2],
        },
        {
            key         = 'category.3',
            title       = 'Category 3: Weapon Skills / JAs',
            description = 'Show notifications for weapon skills and some damaging job abilities',
            type        = 'checkbox',
            default     = addon.defaultSettings.category[3],
        },
        {
            key         = 'category.4',
            title       = 'Category 4: Magic (Finish)',
            description = 'Show notifications for casted magic',
            type        = 'checkbox',
            default     = addon.defaultSettings.category[4],
        },
        {
            key         = 'category.5',
            title       = 'Category 5: Item Usage (Finish)',
            description = 'Show notifications for item usage execution',
            type        = 'checkbox',
            default     = addon.defaultSettings.category[5],
        },
        {
            key         = 'category.6',
            title       = 'Category 6: Job Abilities',
            description = 'Show notifications for most job abilities',
            type        = 'checkbox',
            default     = addon.defaultSettings.category[6],
        },
        {
            key         = 'category.7',
            title       = 'Category 7: TP Move (Start)',
            description = 'Show notifications for TP move start',
            type        = 'checkbox',
            default     = addon.defaultSettings.category[7],
        },
        {
            key         = 'category.8',
            title       = 'Category 8: Magic (Start)',
            description = 'Show notifications for spell start',
            type        = 'checkbox',
            default     = addon.defaultSettings.category[8],
        },
        {
            key         = 'category.9',
            title       = 'Category 9: Item Usage (Start)',
            description = 'Show notifications for item usage initiation',
            type        = 'checkbox',
            default     = addon.defaultSettings.category[9],
        },
        {
            key         = 'category.10',
            title       = 'Category 10: Unknown',
            description = 'Show notifications for unknown category',
            type        = 'checkbox',
            default     = addon.defaultSettings.category[10],
        },
        {
            key         = 'category.11',
            title       = 'Category 11: Mob TP Moves',
            description = 'Show notifications for mob TP moves',
            type        = 'checkbox',
            default     = addon.defaultSettings.category[11],
        },
        {
            key         = 'category.12',
            title       = 'Category 12: Ranged Attack (Start)',
            description = 'Show notifications for ranged attack initiation',
            type        = 'checkbox',
            default     = addon.defaultSettings.category[12],
        },
        {
            key         = 'category.13',
            title       = 'Category 13: Pet TP Moves',
            description = 'Show notifications for pet TP moves',
            type        = 'checkbox',
            default     = addon.defaultSettings.category[13],
        },
        {
            key         = 'category.14',
            title       = 'Category 14: Non-blinkable JAs',
            description = 'Show notifications for non-blinkable job abilities (Jigs, Sambas, Steps, Waltzes, Flourish)',
            type        = 'checkbox',
            default     = addon.defaultSettings.category[14],
        },
        {
            key         = 'category.15',
            title       = 'Category 15: RUN Job Abilities',
            description = 'Show notifications for some RUN job abilities',
            type        = 'checkbox',
            default     = addon.defaultSettings.category[15],
        },
    }
end

return addon
