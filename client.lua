local spawnedPeds = {}
local spawnedBlips = {}
local isLaundering = false
local currentLaunderLocation = nil
local nuiOpen = false

local function DebugPrint(message)
    if Config.Debug then
        print(('[%s:client] %s'):format(Config.ResourceName, message))
    end
end

local function Notify(message, status, duration)
    status = status or 'info'
    duration = duration or 5000

    if Config.Notify.useDistortionzNotify and GetResourceState('distortionz_notify') == 'started' then
        local ok = pcall(function()
            exports['distortionz_notify']:Notify(message, status, duration)
        end)

        if ok then return end

        ok = pcall(function()
            exports['distortionz_notify']:Send(message, status, duration)
        end)

        if ok then return end

        ok = pcall(function()
            TriggerEvent('distortionz_notify:client:notify', message, status, duration)
        end)

        if ok then return end
    end

    lib.notify({
        title = Config.Notify.title,
        description = message,
        type = status,
        duration = duration
    })
end

RegisterNetEvent('distortionz_moneylaundering:client:notify', function(message, status, duration)
    Notify(message, status, duration)
end)

local function LoadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)

    if not IsModelInCdimage(hash) then
        DebugPrint(('Invalid model: %s'):format(tostring(model)))
        return nil
    end

    RequestModel(hash)

    local timeout = GetGameTimer() + 10000

    while not HasModelLoaded(hash) do
        Wait(25)

        if GetGameTimer() > timeout then
            DebugPrint(('Model load timeout: %s'):format(tostring(model)))
            return nil
        end
    end

    return hash
end

local function LoadAnimDict(dict)
    RequestAnimDict(dict)

    local timeout = GetGameTimer() + 8000

    while not HasAnimDictLoaded(dict) do
        Wait(25)

        if GetGameTimer() > timeout then
            DebugPrint(('Anim dict timeout: %s'):format(dict))
            return false
        end
    end

    return true
end

local function DeleteEntitySafe(entity)
    if entity and DoesEntityExist(entity) then
        SetEntityAsMissionEntity(entity, true, true)
        DeleteEntity(entity)
    end
end

local function RemoveBlipSafe(blip)
    if blip and DoesBlipExist(blip) then
        RemoveBlip(blip)
    end
end

local function CloseLaunderUI()
    nuiOpen = false
    SetNuiFocus(false, false)

    SendNUIMessage({
        action = 'close'
    })
end

local function OpenLaunderUI(locationIndex)
    if isLaundering then
        Notify('You are already laundering money.', 'warning')
        return
    end

    if not locationIndex then
        Notify('Missing laundering location index.', 'error')
        return
    end

    local data = lib.callback.await('distortionz_moneylaundering:server:getLaunderData', false, locationIndex)

    if not data then
        Notify('Server did not return laundering data.', 'error', 7000)
        return
    end

    if not data.success then
        Notify(data.message or 'Unable to open laundering menu.', data.status or 'error', 7000)
        return
    end

    currentLaunderLocation = locationIndex
    nuiOpen = true

    SetNuiFocus(true, true)

    SendNUIMessage({
        action = 'open',
        data = data
    })
end

local function CreateLocationBlip(location)
    if not location.blip or not location.blip.enabled then return nil end

    local coords = location.coords
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)

    SetBlipSprite(blip, location.blip.sprite)
    SetBlipColour(blip, location.blip.color)
    SetBlipScale(blip, location.blip.scale)
    SetBlipAsShortRange(blip, location.blip.shortRange)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(location.blip.label)
    EndTextCommandSetBlipName(blip)

    return blip
end

local function StartLaunderAnimations(locationIndex)
    local playerPed = PlayerPedId()
    local contactPed = spawnedPeds[locationIndex]

    -- Player money counting / cash handling animation
    local playerDict = 'anim@heists@money_grab@duffel'
    local playerAnim = 'loop'

    if LoadAnimDict(playerDict) then
        TaskPlayAnim(
            playerPed,
            playerDict,
            playerAnim,
            8.0,
            -8.0,
            -1,
            49,
            0.0,
            false,
            false,
            false
        )
    end

    -- Laundering ped checks records / clipboard
    if contactPed and DoesEntityExist(contactPed) then
        ClearPedTasksImmediately(contactPed)

        TaskStartScenarioInPlace(
            contactPed,
            'WORLD_HUMAN_CLIPBOARD',
            0,
            true
        )
    end
end

local function StopLaunderAnimations(locationIndex)
    local playerPed = PlayerPedId()
    local contactPed = spawnedPeds[locationIndex]

    ClearPedTasks(playerPed)

    if contactPed and DoesEntityExist(contactPed) then
        ClearPedTasksImmediately(contactPed)

        local location = Config.Locations[locationIndex]

        if location and location.scenario and location.scenario ~= '' then
            TaskStartScenarioInPlace(contactPed, location.scenario, 0, true)
        end
    end
end

local function StartStayNearCheck(locationIndex)
    CreateThread(function()
        while isLaundering and Config.Laundering.requireStayNearPed do
            Wait(1000)

            local location = Config.Locations[locationIndex]
            if not location then return end

            local playerCoords = GetEntityCoords(PlayerPedId())
            local dist = #(playerCoords - vector3(location.coords.x, location.coords.y, location.coords.z))

            if dist > Config.Laundering.cancelDistance then
                isLaundering = false

                StopLaunderAnimations(locationIndex)

                TriggerServerEvent('distortionz_moneylaundering:server:cancelLaunder')
                Notify('You walked away. Laundering cancelled.', 'error', 6000)
                return
            end
        end
    end)
end

local function BeginLaunderProgress(amount, locationIndex)
    isLaundering = true
    currentLaunderLocation = locationIndex

    StartLaunderAnimations(locationIndex)
    StartStayNearCheck(locationIndex)

    Notify(('Cleaning $%s dirty money. Stay close.'):format(amount), 'info', 6000)

    local progressSuccess = lib.progressCircle({
        duration = Config.Laundering.processTime * 1000,
        label = 'Cleaning dirty money...',
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
            sprint = true
        }
    })

    StopLaunderAnimations(locationIndex)

    if not isLaundering then
        return
    end

    if not progressSuccess then
        isLaundering = false
        currentLaunderLocation = nil

        TriggerServerEvent('distortionz_moneylaundering:server:cancelLaunder')
        Notify('Laundering cancelled.', 'error')
        return
    end

    TriggerServerEvent('distortionz_moneylaundering:server:finishLaunder')

    isLaundering = false
    currentLaunderLocation = nil
end

local function SpawnLocationPed(location, index)
    local model = LoadModel(location.pedModel)
    if not model then return end

    local coords = location.coords

    local ped = CreatePed(
        0,
        model,
        coords.x,
        coords.y,
        coords.z,
        coords.w,
        false,
        false
    )

    if not ped or ped == 0 or not DoesEntityExist(ped) then
        DebugPrint(('Failed to create laundering ped at location index %s'):format(index))
        SetModelAsNoLongerNeeded(model)
        return
    end

    SetEntityAsMissionEntity(ped, true, true)
    PlaceObjectOnGroundProperly(ped)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)

    -- Protect this scripted ped from distortionz_robped
    Entity(ped).state:set('distortionz_protected_ped', true, true)
    Entity(ped).state:set('distortionz_contact_ped', true, true)
    Entity(ped).state:set('distortionz_launder_ped', true, true)

    if location.scenario and location.scenario ~= '' then
        TaskStartScenarioInPlace(ped, location.scenario, 0, true)
    end

    exports.ox_target:addLocalEntity(ped, {
        {
            name = ('distortionz_moneylaundering_clean_%s'):format(index),
            icon = location.target.icon,
            label = location.target.label,
            distance = location.target.distance,
            onSelect = function()
                OpenLaunderUI(index)
            end
        }
    })

    spawnedPeds[index] = ped

    local blip = CreateLocationBlip(location)

    if blip then
        spawnedBlips[#spawnedBlips + 1] = blip
    end

    SetModelAsNoLongerNeeded(model)
end

RegisterNUICallback('close', function(_, cb)
    CloseLaunderUI()
    cb({ success = true })
end)

RegisterNUICallback('startLaunder', function(data, cb)
    local amount = tonumber(data.amount)
    local locationIndex = tonumber(currentLaunderLocation)

    if not amount or amount <= 0 then
        cb({
            success = false,
            message = 'Invalid amount.'
        })

        return
    end

    if not locationIndex then
        cb({
            success = false,
            message = 'Invalid laundering location.'
        })

        return
    end

    local result = lib.callback.await('distortionz_moneylaundering:server:startLaunder', false, amount, locationIndex)

    if not result then
        cb({
            success = false,
            message = 'Laundering failed to start.'
        })

        return
    end

    cb(result)

    if not result.success then
        return
    end

    CloseLaunderUI()

    CreateThread(function()
        BeginLaunderProgress(amount, locationIndex)
    end)
end)

RegisterNetEvent('distortionz_moneylaundering:client:policeAlert', function(alertData)
    local coords = alertData.coords

    Notify(alertData.message or 'Suspicious laundering activity reported.', 'warning', 7500)

    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)

    SetBlipSprite(blip, Config.Police.alertBlip.sprite)
    SetBlipColour(blip, Config.Police.alertBlip.color)
    SetBlipScale(blip, Config.Police.alertBlip.scale)
    SetBlipAsShortRange(blip, false)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Suspicious Laundering')
    EndTextCommandSetBlipName(blip)

    CreateThread(function()
        Wait(Config.Police.alertBlip.duration * 1000)
        RemoveBlipSafe(blip)
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    CloseLaunderUI()

    if isLaundering and currentLaunderLocation then
        StopLaunderAnimations(currentLaunderLocation)
    end

    for _, ped in pairs(spawnedPeds) do
        DeleteEntitySafe(ped)
    end

    for _, blip in ipairs(spawnedBlips) do
        RemoveBlipSafe(blip)
    end
end)

CreateThread(function()
    Wait(1000)

    for index, location in ipairs(Config.Locations) do
        SpawnLocationPed(location, index)
    end
end)