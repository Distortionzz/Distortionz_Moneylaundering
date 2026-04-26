local function PrintVersionMessage(message)
    print(('[%s] %s'):format(Config.ResourceName, message))
end

local function ParseVersion(version)
    local major, minor, patch = tostring(version):match('v?(%d+)%.(%d+)%.(%d+)')

    return {
        major = tonumber(major) or 0,
        minor = tonumber(minor) or 0,
        patch = tonumber(patch) or 0
    }
end

local function IsRemoteNewer(localVersion, remoteVersion)
    local localParsed = ParseVersion(localVersion)
    local remoteParsed = ParseVersion(remoteVersion)

    if remoteParsed.major > localParsed.major then return true end
    if remoteParsed.major < localParsed.major then return false end

    if remoteParsed.minor > localParsed.minor then return true end
    if remoteParsed.minor < localParsed.minor then return false end

    if remoteParsed.patch > localParsed.patch then return true end

    return false
end

local function RunVersionCheck()
    if not Config.VersionCheck or not Config.VersionCheck.enabled then
        return
    end

    if not Config.VersionCheck.url or Config.VersionCheck.url == '' then
        PrintVersionMessage('Version check skipped: no version URL configured.')
        return
    end

    PerformHttpRequest(Config.VersionCheck.url, function(statusCode, response)
        if statusCode ~= 200 or not response then
            PrintVersionMessage(('Version check failed. HTTP status: %s'):format(statusCode))
            return
        end

        local ok, data = pcall(json.decode, response)

        if not ok or not data then
            PrintVersionMessage('Version check failed: invalid version.json.')
            return
        end

        local remoteVersion = data.version

        if not remoteVersion then
            PrintVersionMessage('Version check failed: version missing from version.json.')
            return
        end

        if IsRemoteNewer(Config.CurrentVersion, remoteVersion) then
            PrintVersionMessage('====================================================')
            PrintVersionMessage(('Update available: %s -> %s'):format(Config.CurrentVersion, remoteVersion))

            if data.changelog then
                PrintVersionMessage(('Changelog: %s'):format(data.changelog))
            end

            if data.download then
                PrintVersionMessage(('Download: %s'):format(data.download))
            end

            PrintVersionMessage('====================================================')
        else
            PrintVersionMessage(('You are running the latest version: %s'):format(Config.CurrentVersion))
        end
    end, 'GET')
end

CreateThread(function()
    if Config.VersionCheck and Config.VersionCheck.checkOnStart then
        Wait(2500)
        RunVersionCheck()
    end
end)