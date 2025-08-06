-- Reports if a new captain version is available.
---@class VersCheckAddon : AddonInterface
local copas  = require('libs.copas_clients')
local json   = require('json')

local vAddon =
{
    name    = 'VersCheck',
    checked = false,
}

local function parseVersion(versionStr)
    local major, minor, patch = versionStr:match('(%d+)%.(%d+)%.(%d+)')
    if not major then return nil end
    return
    {
        major = tonumber(major),
        minor = tonumber(minor),
        patch = tonumber(patch),
    }
end

local function compareVersions(current, latest)
    local currentVer = parseVersion(current)
    local latestVer  = parseVersion(latest)

    if not currentVer or not latestVer then
        return false
    end

    if latestVer.major > currentVer.major then return true end
    if latestVer.major < currentVer.major then return false end

    if latestVer.minor > currentVer.minor then return true end
    if latestVer.minor < currentVer.minor then return false end

    if latestVer.patch > currentVer.patch then return true end
    return false
end

vAddon.onPrerender = function()
    if not vAddon.checked then
        local githubUrl = 'https://api.github.com/repos/sruon/captain/releases/latest'
        copas.http_request(githubUrl, nil,
            {
                on_success = function(body, status, headers)
                    local success, release = pcall(json.decode, body)
                    if success and release and release.tag_name then
                        local latestVersion  = release.tag_name:gsub('^v', '')
                        local currentVersion = addon and addon.version or 'unknown'

                        if compareVersions(currentVersion, latestVersion) then
                            backend.msg('captain', colors[ColorEnum.Yellow].chatColorCode ..
                                'New version available: ' .. latestVersion ..
                                ' (current: ' .. currentVersion .. ')')
                            backend.msg('captain', 'Download: https://github.com/sruon/captain/releases/latest')
                        end
                    end
                end,
            })
    end

    vAddon.checked = true
end

return vAddon
