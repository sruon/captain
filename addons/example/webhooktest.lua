-- Sends zone change notifications to a webhook
---@class WebhookTestAddon : AddonInterface
local addon         =
{
    name            = 'WebhookTest',
    settings        = {},
    defaultSettings =
    {
        webhook_url = 'https://eo5wt8q3y961isv.m.pipedream.net',
        enabled     = true,
    },
}

local copas_clients = require('copas_clients')

-- Send zone change notification
local function sendZoneNotification(zone_id, zone_name)
    if not addon.settings.enabled or not addon.settings.webhook_url then
        return
    end

    local data =
    {
        event     = 'zone_change',
        player    = backend.player_name(),
        zone_id   = zone_id,
        zone_name = zone_name,
        timestamp = os.time(),
        server    = 'Unknown',
    }

    -- Fire-and-forget POST using copas_http
    backend.msg('webhook', string.format('Sending webhook for zone: %s', zone_name))

    copas_clients.webhook(addon.settings.webhook_url, data,
        {
            timeout    = 10,
            on_success = function(response, headers)
                backend.msg('webhook', string.format('Webhook SUCCESS for %s: status=%s', zone_name, tostring(response)))
            end,
            on_error   = function(error_msg)
                backend.msg('webhook', string.format('Webhook FAILED for %s: %s', zone_name, error_msg))
            end,
        })
end

addon.onZoneChange = function(zone_id)
    local zone_name = backend.zone_name(zone_id)
    backend.msg('webhook', string.format('Zone changed to: %s (%d)', zone_name, zone_id))
    sendZoneNotification(zone_id, zone_name)
end

addon.onConfigMenu = function()
    return
    {
        {
            key         = 'webhook_url',
            title       = 'Webhook URL',
            description = 'URL to send zone change notifications to',
            type        = 'input',
            default     = addon.defaultSettings.webhook_url,
        },
        {
            key         = 'enabled',
            title       = 'Enable Webhooks',
            description = 'Send zone change notifications via webhook',
            type        = 'checkbox',
            default     = addon.defaultSettings.enabled,
        },
    }
end

return addon
