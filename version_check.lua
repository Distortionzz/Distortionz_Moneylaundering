local function trimVersion(version)
    if not version then return '0.0.0' end
    version = tostring(version):gsub('^v', ''):gsub('^V', '')
    return version
end

local function splitVersion(version)
    local parts = {}
    for part in trimVersion(version):gmatch('[^.]+') do
        parts[#parts + 1] = tonumber(part) or 0
    end
    return parts
end

local function isVersionNewer(remote, current)
    local r = splitVersion(remote)
    local c = splitVersion(current)

    local maxParts = math.max(#r, #c)
    for i = 1, maxParts do
        local rv = r[i] or 0
        local cv = c[i] or 0

        if rv > cv then
            return true
        elseif rv < cv then
            return false
        end
    end

    return false
end

local function versionCheck()
    if not Config.VersionCheck or not Config.VersionCheck.enabled then
        return
    end

    local resourceName = GetCurrentResourceName()
    local currentVersion = Config.CurrentVersion or GetResourceMetadata(resourceName, 'version', 0) or '0.0.0'
    local versionUrl = Config.VersionCheck.url

    if not versionUrl or versionUrl == '' then
        print(('^6[%s]^7 ^1Version check failed:^7 missing version URL.'):format(resourceName))
        return
    end

    PerformHttpRequest(versionUrl, function(statusCode, response)
        if statusCode ~= 200 then
            print(('^6[%s]^7 ^1Version check failed.^7 HTTP status: ^1%s^7'):format(resourceName, statusCode or 'unknown'))
            return
        end

        if not response or response == '' then
            print(('^6[%s]^7 ^1Version check failed:^7 empty response body.'):format(resourceName))
            return
        end

        local success, data = pcall(json.decode, response)
        if not success or not data then
            print(('^6[%s]^7 ^1Version check failed:^7 invalid JSON response.'):format(resourceName))
            return
        end

        local latestVersion = data.version or data.latest or '0.0.0'
        local changelog = data.changelog or 'No changelog provided.'
        local download = data.download or 'No download URL provided.'

        if isVersionNewer(latestVersion, currentVersion) then
            print(('^6[%s]^7 ^1Outdated version detected!^7 Current: ^1v%s^7 | Latest: ^2v%s^7'):format(
                resourceName, currentVersion, latestVersion
            ))
            print(('^6[%s]^7 ^1Please update this resource.^7'):format(resourceName))
            print(('^6[%s]^7 ^3Changelog:^7 %s'):format(resourceName, changelog))
            print(('^6[%s]^7 ^5Download:^7 %s'):format(resourceName, download))
        else
            print(('^6[%s]^7 ^2You are running the latest version.^7 v%s'):format(
                resourceName, currentVersion
            ))
        end
    end, 'GET')
end

CreateThread(function()
    Wait(2000)

    if Config.VersionCheck and Config.VersionCheck.checkOnStart then
        versionCheck()
    end
end)