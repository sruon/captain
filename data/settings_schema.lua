-- Settings schema - combines UI configuration and default values in one structure
--
-- This schema defines both the UI configuration for settings and their default values.
-- Settings are defined in a nested structure matching how they'll appear in the final config.
--
-- For settings that should appear in the UI, add a 'ui' field with configuration metadata:
--   {
--     default = <value>,     -- The default value for this setting
--     ui = {                 -- UI metadata (only needed for configurable settings)
--       title = "Setting Name",
--       type = "slider",     -- Currently only sliders are supported
--       min = 0,
--       max = 100,
--       step = 1,
--       description = "Help text shown in tooltip"
--     }
--   }
--
-- For settings that don't need to appear in the UI:
--   {
--     default = <value>      -- Just specify the default value
--   }

local settings_schema =
{
    -- Core settings definition - everything in one place
    settings        =
    {
        core          =
        {
            witsec =
            {
                default = false,
                ui      =
                {
                    title       = 'Enable Witness Protection',
                    type        = 'checkbox',
                    description = 'Enable auto-randomization of player name',
                },
            },
        },
        notifications =
        {
            -- Config menu items have a 'ui' field
            max_num   =
            {
                default = 4,
                ui      =
                {
                    title       = 'Max',
                    type        = 'slider',
                    min         = 3,
                    max         = 10,
                    step        = 1,
                    description = 'Maximum number of notifications to display',
                },
            },
            hideDelay =
            {
                default = 5,
                ui      =
                {
                    title       = 'Auto-hide delay',
                    type        = 'slider',
                    min         = 1,
                    max         = 10,
                    step        = 1,
                    description = 'Time in seconds before notifications auto-hide',
                },
            },
            spacing   =
            {
                default = 8,
                ui      =
                {
                    title       = 'Spacing',
                    type        = 'slider',
                    min         = 0,
                    max         = 20,
                    step        = 1,
                    description = 'Vertical spacing between notifications',
                },
            },
            scale     =
            {
                default = 1.0,
                ui      =
                {
                    title       = 'Scale',
                    type        = 'slider',
                    min         = 0.1,
                    max         = 5.0,
                    step        = 0.05,
                    description = 'Size scaling factor for notifications',
                },
            },
            offset    =
            {
                x =
                {
                    default = 20,
                    ui      =
                    {
                        title       = 'Offset X (from bottom right)',
                        type        = 'slider',
                        min         = 0,
                        max         = backend.get_resolution_width(),
                        step        = 5,
                        description = 'Horizontal offset from screen edge',
                    },
                },
                y =
                {
                    default = 20,
                    ui      =
                    {
                        title       = 'Offset Y (from bottom right)',
                        type        = 'slider',
                        min         = 0,
                        max         = backend.get_resolution_height(),
                        step        = 5,
                        description = 'Vertical offset from screen edge',
                    },
                },
            },
            -- Non-UI settings just have default values
            show      = { default = true },
            autoHide  = { default = true },
            colors    =
            {
                title = { default = ColorEnum.SoftBlue },
                key   = { default = ColorEnum.Purple },
                value = { default = ColorEnum.Seafoam },
            },
            pos       =
            {
                x = { default = 200 },
                y = { default = 50 },
            },
            text      =
            {
                alpha = { default = 255 },
                red   = { default = 255 },
                green = { default = 255 },
                blue  = { default = 255 },
            },
            flags     =
            {
                right     = { default = false },
                bottom    = { default = false },
                bold      = { default = false },
                italic    = { default = false },
                draggable = { default = true },
            },
            padding   = { default = 0 },
            bg        =
            {
                red   = { default = 30 },
                green = { default = 30 },
                blue  = { default = 60 },
                alpha = { default = 230 },
            },
        },
        textBox       =
        {
            scale    =
            {
                default = 1.0,
                ui      =
                {
                    title       = 'Scale',
                    type        = 'slider',
                    min         = 0.5,
                    max         = 5.0,
                    step        = 0.1,
                    description = 'Size scaling factor for text boxes',
                },
            },
            defaults =
            {
                pos     =
                {
                    x = { default = 290 },
                    y = { default = 0 },
                },
                bg      =
                {
                    alpha   = { default = 64 },
                    red     = { default = 0 },
                    green   = { default = 0 },
                    blue    = { default = 0 },
                    visible = { default = true },
                },
                flags   =
                {
                    right     = { default = false },
                    bottom    = { default = false },
                    bold      = { default = false },
                    italic    = { default = false },
                    draggable = { default = true },
                },
                padding = { default = 3 },
            },
        },
    },

    -- UI category definitions
    categories      =
    {
        {
            id    = 'core',
            title = 'Captain',
        },
        {
            id    = 'textBox',
            title = 'TextBox',
        },
        {
            id    = 'notifications',
            title = 'Notifications',
        },
    },

    -- Build default settings from the schema
    build_defaults  = function(self)
        local function extract_defaults(schema, result)
            result = result or {}

            for k, v in pairs(schema) do
                if type(v) == 'table' then
                    if v.default ~= nil then
                        -- This is a leaf setting with a default value
                        result[k] = v.default
                    else
                        -- This is a branch, recurse
                        result[k] = {}
                        extract_defaults(v, result[k])
                    end
                else
                    -- Direct value assignment (rare case)
                    result[k] = v
                end
            end

            return result
        end

        return extract_defaults(self.settings)
    end,

    -- Get UI-configurable settings for a category
    get_ui_settings = function(self, category_id)
        -- Define the order of UI elements for each category
        local ui_order =
        {
            core          =
            {
                'witsec',
            },
            notifications =
            {
                'max_num',
                'hideDelay',
                'spacing',
                'scale',
                'offset.x',
                'offset.y',
            },
            textBox       =
            {
                'scale',
            },
        }

        local result   = {}

        -- Function to find a setting by path
        local function find_setting_by_path(schema, path)
            local parts = {}
            for part in string.gmatch(path, '[^%.]+') do
                table.insert(parts, part)
            end

            local current = schema
            for i, part in ipairs(parts) do
                if current[part] == nil then
                    return nil
                end
                current = current[part]
            end

            return current
        end

        -- Process settings in order
        if ui_order[category_id] and self.settings[category_id] then
            for _, path in ipairs(ui_order[category_id]) do
                local setting = find_setting_by_path(self.settings[category_id], path)

                if setting and setting.ui then
                    table.insert(result,
                        {
                            path    = path,
                            default = setting.default,
                            ui      = setting.ui,
                        })
                end
            end
        end

        return result
    end,
}

-- Build the default settings when this module is required
local module          = settings_schema

-- Add a function to explicitly get defaults
module.get_defaults   = function()
    return module:build_defaults()
end

return module
