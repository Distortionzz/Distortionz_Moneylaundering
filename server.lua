print('[distortionz_moneylaundering] server.lua is loading...')

local activeLaunders = {}
local cooldowns = {}

local function DebugPrint(message)
    if Config.Debug then
        print(('[%s:server] %s'):format(Config.ResourceName, message))
    end
end

local function Notify(src, message, status, duration)
    TriggerClientEvent(
        'distortionz_moneylaundering:client:notify',
        src,
        message,
        status or 'info',
        duration or 5000
    )
end

local function GetPlayer(src)
    if GetResourceState('qbx_core') == 'started' then
        local ok, player = pcall(function()
            return exports.qbx_core:GetPlayer(src)
        end)

        if ok and player then
            return player
        end
    end

    if GetResourceState('qb-core') == 'started' then
        local ok, QBCore = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)

        if ok and QBCore then
            return QBCore.Functions.GetPlayer(src)
        end
    end

    return nil
end

local function GetCitizenId(src)
    local player = GetPlayer(src)

    if not player then
        return ('source:%s'):format(src)
    end

    if player.PlayerData and player.PlayerData.citizenid then
        return player.PlayerData.citizenid
    end

    if player.citizenid then
        return player.citizenid
    end

    return ('source:%s'):format(src)
end

local function GetPlayerJob(src)
    local player = GetPlayer(src)

    if not player then
        return nil
    end

    if player.PlayerData and player.PlayerData.job and player.PlayerData.job.name then
        return player.PlayerData.job.name
    end

    if player.job and player.job.name then
        return player.job.name
    end

    return nil
end

local function AddCleanCash(src, amount)
    amount = math.floor(tonumber(amount) or 0)

    if amount <= 0 then
        return false
    end

    if GetResourceState('qbx_core') == 'started' then
        local player = GetPlayer(src)

        if player and player.Functions and player.Functions.AddMoney then
            local ok, result = pcall(function()
                return player.Functions.AddMoney('cash', amount, 'distortionz-money-laundering')
            end)

            if ok then
                return result ~= false
            end
        end

        local ok, result = pcall(function()
            return exports.qbx_core:AddMoney(src, 'cash', amount, 'distortionz-money-laundering')
        end)

        if ok then
            return result ~= false
        end
    end

    if GetResourceState('qb-core') == 'started' then
        local player = GetPlayer(src)

        if player and player.Functions and player.Functions.AddMoney then
            local ok, result = pcall(function()
                return player.Functions.AddMoney('cash', amount, 'distortionz-money-laundering')
            end)

            if ok then
                return result ~= false
            end
        end
    end

    return false
end

local function IsOnCooldown(citizenId)
    local expires = cooldowns[citizenId]

    if not expires then
        return false, 0
    end

    local now = os.time()

    if now >= expires then
        cooldowns[citizenId] = nil
        return false, 0
    end

    return true, expires - now
end

local function SetCooldown(citizenId)
    cooldowns[citizenId] = os.time() + Config.Laundering.cooldown
end

local function FormatTime(seconds)
    seconds = tonumber(seconds) or 0

    local minutes = math.floor(seconds / 60)
    local remainingSeconds = seconds % 60

    if minutes <= 0 then
        return ('%ss'):format(remainingSeconds)
    end

    return ('%sm %ss'):format(minutes, remainingSeconds)
end

local function CalculateCleanAmount(dirtyAmount)
    dirtyAmount = math.floor(tonumber(dirtyAmount) or 0)

    local rate = tonumber(Config.Laundering.cleanRate) or 75

    return math.floor(dirtyAmount * (rate / 100))
end

local function CalculateFeeAmount(dirtyAmount)
    dirtyAmount = math.floor(tonumber(dirtyAmount) or 0)

    return math.floor(dirtyAmount - CalculateCleanAmount(dirtyAmount))
end

local function ValidateLocation(locationIndex)
    locationIndex = tonumber(locationIndex)

    if not locationIndex then
        return nil
    end

    if not Config.Locations or not Config.Locations[locationIndex] then
        return nil
    end

    return Config.Locations[locationIndex]
end

local function GetDirtyMoneyCount(src)
    local ok, count = pcall(function()
        return exports.ox_inventory:Search(src, 'count', Config.Items.dirtyMoney)
    end)

    if not ok then
        print(('[%s] ox_inventory Search failed for source %s'):format(Config.ResourceName, src))
        return 0
    end

    return tonumber(count) or 0
end

local function RemoveDirtyMoney(src, amount)
    amount = math.floor(tonumber(amount) or 0)

    if amount <= 0 then
        return false
    end

    local ok, removed = pcall(function()
        return exports.ox_inventory:RemoveItem(src, Config.Items.dirtyMoney, amount)
    end)

    if not ok then
        print(('[%s] ox_inventory RemoveItem failed for source %s'):format(Config.ResourceName, src))
        return false
    end

    return removed == true or removed == amount
end

local function AddDirtyMoney(src, amount)
    amount = math.floor(tonumber(amount) or 0)

    if amount <= 0 then
        return false
    end

    local ok, added = pcall(function()
        return exports.ox_inventory:AddItem(src, Config.Items.dirtyMoney, amount)
    end)

    if not ok then
        print(('[%s] ox_inventory AddItem failed for source %s'):format(Config.ResourceName, src))
        return false
    end

    return added ~= false
end

local function AlertPolice(coords)
    if not Config.Police or not Config.Police.enabled then
        return
    end

    local roll = math.random(1, 100)

    if roll > Config.Police.alertChance then
        return
    end

    local players = GetPlayers()

    for _, playerId in ipairs(players) do
        local playerSrc = tonumber(playerId)
        local job = GetPlayerJob(playerSrc)

        if job and Config.Police.jobs[job] then
            TriggerClientEvent('distortionz_moneylaundering:client:policeAlert', playerSrc, {
                coords = coords,
                message = 'Anonymous tip: suspicious money laundering activity reported.'
            })
        end
    end
end

lib.callback.register('distortionz_moneylaundering:server:getLaunderData', function(src, locationIndex)
    local location = ValidateLocation(locationIndex)

    if not location then
        return {
            success = false,
            status = 'error',
            message = 'Invalid laundering location.'
        }
    end

    local citizenId = GetCitizenId(src)
    local onCooldown, remaining = IsOnCooldown(citizenId)

    if onCooldown then
        return {
            success = false,
            status = 'warning',
            message = ('Contact is laying low. Come back in %s.'):format(FormatTime(remaining))
        }
    end

    local dirtyCount = GetDirtyMoneyCount(src)

    local minAmount = tonumber(Config.Laundering.minAmount) or 1000
    local maxAmount = tonumber(Config.Laundering.maxAmount) or 50000
    local cleanRate = tonumber(Config.Laundering.cleanRate) or 75
    local feeRate = 100 - cleanRate

    local maxCleanable = math.min(dirtyCount, maxAmount)

    return {
        success = true,

        locationName = location.name or 'Unknown Location',

        dirtyMoney = dirtyCount,
        minAmount = minAmount,
        maxAmount = maxAmount,
        maxCleanable = maxCleanable,

        cleanRate = cleanRate,
        feeRate = feeRate,

        processTime = tonumber(Config.Laundering.processTime) or 20,
        cooldown = tonumber(Config.Laundering.cooldown) or 600,

        preview = {
            dirtyAmount = maxCleanable,
            cleanAmount = CalculateCleanAmount(maxCleanable),
            feeAmount = CalculateFeeAmount(maxCleanable)
        }
    }
end)

lib.callback.register('distortionz_moneylaundering:server:startLaunder', function(src, amount, locationIndex)
    amount = math.floor(tonumber(amount) or 0)

    if activeLaunders[src] then
        return {
            success = false,
            status = 'warning',
            message = 'You are already laundering money.'
        }
    end

    local location = ValidateLocation(locationIndex)

    if not location then
        return {
            success = false,
            status = 'error',
            message = 'Invalid laundering location.'
        }
    end

    local minAmount = tonumber(Config.Laundering.minAmount) or 1000
    local maxAmount = tonumber(Config.Laundering.maxAmount) or 50000

    if amount < minAmount then
        return {
            success = false,
            status = 'error',
            message = ('Minimum laundering amount is $%s.'):format(minAmount)
        }
    end

    if amount > maxAmount then
        return {
            success = false,
            status = 'error',
            message = ('Maximum laundering amount is $%s.'):format(maxAmount)
        }
    end

    local citizenId = GetCitizenId(src)
    local onCooldown, remaining = IsOnCooldown(citizenId)

    if onCooldown then
        return {
            success = false,
            status = 'warning',
            message = ('Contact is laying low. Come back in %s.'):format(FormatTime(remaining))
        }
    end

    local dirtyCount = GetDirtyMoneyCount(src)

    if dirtyCount < amount then
        return {
            success = false,
            status = 'error',
            message = ('You do not have $%s dirty money.'):format(amount)
        }
    end

    if Config.Laundering.removeDirtyMoneyOnStart then
        local removed = RemoveDirtyMoney(src, amount)

        if not removed then
            return {
                success = false,
                status = 'error',
                message = 'Failed to collect dirty money.'
            }
        end
    end

    local cleanAmount = CalculateCleanAmount(amount)
    local feeAmount = CalculateFeeAmount(amount)
    local processTime = tonumber(Config.Laundering.processTime) or 20

    activeLaunders[src] = {
        citizenId = citizenId,
        dirtyAmount = amount,
        cleanAmount = cleanAmount,
        fee = feeAmount,
        locationIndex = tonumber(locationIndex),
        startedAt = os.time(),
        finishesAt = os.time() + processTime
    }

    AlertPolice(location.coords)

    DebugPrint(('Started laundering for %s | dirty %s | clean %s | fee %s'):format(
        src,
        amount,
        cleanAmount,
        feeAmount
    ))

    return {
        success = true,
        dirtyAmount = amount,
        cleanAmount = cleanAmount,
        fee = feeAmount,
        message = 'Laundering started.'
    }
end)

RegisterNetEvent('distortionz_moneylaundering:server:finishLaunder', function()
    local src = source
    local launder = activeLaunders[src]

    if not launder then
        Notify(src, 'No active laundering process found.', 'error')
        return
    end

    if os.time() < launder.finishesAt - 2 then
        Notify(src, 'Laundering finished too quickly. Transaction cancelled.', 'error')

        if Config.Laundering.removeDirtyMoneyOnStart then
            AddDirtyMoney(src, launder.dirtyAmount)
        end

        activeLaunders[src] = nil
        return
    end

    if not Config.Laundering.removeDirtyMoneyOnStart then
        local removed = RemoveDirtyMoney(src, launder.dirtyAmount)

        if not removed then
            activeLaunders[src] = nil
            Notify(src, 'Dirty money was missing. Laundering cancelled.', 'error')
            return
        end
    end

    local addedCash = AddCleanCash(src, launder.cleanAmount)

    if not addedCash then
        if Config.Laundering.removeDirtyMoneyOnStart then
            AddDirtyMoney(src, launder.dirtyAmount)
        end

        activeLaunders[src] = nil
        Notify(src, 'Clean cash payment failed. Dirty money returned.', 'error')
        return
    end

    activeLaunders[src] = nil
    SetCooldown(launder.citizenId)

    Notify(
        src,
        ('Laundering complete. You received $%s clean cash. Fee taken: $%s.'):format(
            launder.cleanAmount,
            launder.fee
        ),
        'success',
        8000
    )

    DebugPrint(('Finished laundering for %s | paid %s clean cash'):format(src, launder.cleanAmount))
end)

RegisterNetEvent('distortionz_moneylaundering:server:cancelLaunder', function()
    local src = source
    local launder = activeLaunders[src]

    if not launder then
        return
    end

    if Config.Laundering.removeDirtyMoneyOnStart then
        AddDirtyMoney(src, launder.dirtyAmount)
    end

    activeLaunders[src] = nil

    DebugPrint(('Cancelled laundering for %s | returned %s dirty money'):format(
        src,
        launder.dirtyAmount
    ))
end)

AddEventHandler('playerDropped', function()
    local src = source
    local launder = activeLaunders[src]

    if not launder then
        return
    end

    if Config.Laundering.removeDirtyMoneyOnStart then
        AddDirtyMoney(src, launder.dirtyAmount)
    end

    activeLaunders[src] = nil
end)

CreateThread(function()
    Wait(1000)
    print(('^5[%s]^7 ^2v%s loaded — locations=%d cleanRate=%d%%^7'):format(
        Config.ResourceName,
        Config.CurrentVersion,
        #Config.Locations,
        Config.Laundering.cleanRate
    ))
end)