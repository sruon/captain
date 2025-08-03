-- Displays notifications

---@class Notification
---@field title string?
---@field data table[]?

---@class NotificationParams
---@field title string?
---@field data table[]?
---@field freeze boolean?

---@class NotificationManager
---@field notifications table
---@field frozen boolean
---@field settings { show: boolean, max_num: number, autoHide: boolean, hideDelay: number, spacing: number, pos: { x: number, y: number }, bg: table, text: table }
---@field render fun(self: NotificationManager)
---@field create fun(self: NotificationManager, params: NotificationParams, freeze: boolean)
local notificationManager   = {}
notificationManager.__index = notificationManager

---@param settings { show: boolean, max_num: number, autoHide: boolean, hideDelay: number, spacing: number, pos: { x: number, y: number }, bg: { [string]: any }, text: { [string]: any } }
---@return NotificationManager
function notificationManager.new(settings)
    ---@type NotificationManager
    local self         = setmetatable({}, notificationManager)
    self.notifications = {}
    self.frozen        = false
    self.settings      = settings
    return self
end

function notificationManager:create(params, freeze)
    if not self.settings.show then
        return
    end

    self.frozen        = freeze

    local notification = {}

    if type(params) == 'table' and params.title then
        notification =
        {
            id    = ('%d-%d'):format(os.time(), math.random(100000, 999999)),
            title = params.title,
            data  = params.data, -- Array of key-value pairs
        }
    else
        notification =
        {
            id    = ('%d-%d'):format(os.time(), math.random(100000, 999999)),
            title = params,
        }
    end

    -- Add new notification at the end (newest)
    table.insert(self.notifications, notification)

    -- If we have too many notifications, handle removal with respect to frozen state
    while #self.notifications > self.settings.max_num do
        local function wait_for_max_unfreeze()
            if self.frozen then
                backend.schedule(wait_for_max_unfreeze, 1.0)
            else
                -- Only remove once we're not frozen
                if type(backend.notificationDestroy) == 'function' then
                    backend.notificationDestroy(self.notifications[1])
                end

                table.remove(self.notifications, 1)
            end
        end

        -- Start the wait/check process
        wait_for_max_unfreeze()
    end

    if self.settings.autoHide then
        local notification_ref = notification

        local function wait_for_unfreeze()
            if self.frozen then
                backend.schedule(wait_for_unfreeze, 1.0)
            else
                local function try_remove()
                    for i = #self.notifications, 1, -1 do
                        if self.notifications[i] == notification_ref then
                            if type(backend.notificationDestroy) == 'function' then
                                backend.notificationDestroy(self.notifications[i])
                            end

                            table.remove(self.notifications, i)
                            return
                        end
                    end
                end

                backend.schedule(try_remove, self.settings.hideDelay or 6.0)
            end
        end

        backend.schedule(wait_for_unfreeze, 1.0)
    end
end

function notificationManager:render()
    if not self.settings.show then
        return
    end

    -- Prepare notifications for rendering
    for i = 1, #self.notifications do
        local notification = self.notifications[i]
        notification.bg    = setmetatable({}, { __index = self.settings.bg })
        notification.text  = setmetatable({}, { __index = self.settings.text })
    end

    -- Render all notifications at once with the notifications renderer
    if type(backend.notificationsRender) == 'function' then
        backend.notificationsRender(self.notifications)
    else
        -- Fallback message if notifications renderer is not available
        backend.msg('captain', 'Notification renderer not available')
    end
end

return notificationManager
