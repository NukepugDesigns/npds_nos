local currentVehicle = nil
local nosData = nil
local defaultBottleTypes = { bottle1 = "regular", bottle2 = "regular" }
local isBoosting = false
local hudDisabled = false
local showingHUD = false
local nosOverheat = 0.0
local isOverheated = false
local isPurging = false

local activeBoostingVehicles = {}

local function startExhaustFlames(vehicle)
    if activeBoostingVehicles[vehicle] then return end
    activeBoostingVehicles[vehicle] = true
    
    local exhaustBones = { "exhaust", "exhaust_2", "exhaust_3", "exhaust_4", "exhaust_5", "exhaust_6" }
    local bones = {}
    for _, boneName in ipairs(exhaustBones) do
        local bone = GetEntityBoneIndexByName(vehicle, boneName)
        if bone ~= -1 then
            table.insert(bones, bone)
        end
    end
    
    if #bones == 0 then
        local bone = GetEntityBoneIndexByName(vehicle, "chassis")
        if bone ~= -1 then
            table.insert(bones, bone)
        end
    end
    
    CreateThread(function()
        local ptfxAsset = "core"
        RequestNamedPtfxAsset(ptfxAsset)
        while not HasNamedPtfxAssetLoaded(ptfxAsset) do
            Wait(10)
        end
        
        local ptfxHandles = {}
        
        while activeBoostingVehicles[vehicle] and DoesEntityExist(vehicle) do
            for _, boneIndex in ipairs(bones) do
                UseParticleFxAssetNextCall(ptfxAsset)
                local ptfx = StartParticleFxLoopedOnEntityBone("veh_backfire", vehicle, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, boneIndex, 1.25, false, false, false)
                table.insert(ptfxHandles, ptfx)
            end
            
            Wait(150)
            
            for _, ptfx in ipairs(ptfxHandles) do
                StopParticleFxLooped(ptfx, false)
            end
            ptfxHandles = {}
        end
        
        for _, ptfx in ipairs(ptfxHandles) do
            StopParticleFxLooped(ptfx, false)
        end
    end)
end

local function stopExhaustFlames(vehicle)
    activeBoostingVehicles[vehicle] = nil
end

local activePurgingVehicles = {}
local activePurgeHandles = {}
local activePurgeSounds = {}

local function spawnPurgeFx(vehicle, config)
    if activePurgeHandles[vehicle] then
        for _, handle in ipairs(activePurgeHandles[vehicle]) do
            StopParticleFxLooped(handle, false)
        end
        activePurgeHandles[vehicle] = nil
    end

    local ptfxAsset = "core"
    if not HasNamedPtfxAssetLoaded(ptfxAsset) then
        RequestNamedPtfxAsset(ptfxAsset)
        while not HasNamedPtfxAssetLoaded(ptfxAsset) do
            Wait(0)
        end
    end

    local bone = GetEntityBoneIndexByName(vehicle, "bonnet")
    local purgeOffsetA
    if bone ~= -1 then
        local pos = GetWorldPositionOfEntityBone(vehicle, bone)
        purgeOffsetA = GetOffsetFromEntityGivenWorldCoords(vehicle, pos.x, pos.y, pos.z)
        purgeOffsetA = vector3(purgeOffsetA.x, purgeOffsetA.y + (config.yOffset or 0.05), purgeOffsetA.z + (config.zOffset or 0.00))
    else
        bone = GetEntityBoneIndexByName(vehicle, "engine")
        if bone ~= -1 then
            local pos = GetWorldPositionOfEntityBone(vehicle, bone)
            purgeOffsetA = GetOffsetFromEntityGivenWorldCoords(vehicle, pos.x, pos.y, pos.z)
            purgeOffsetA = vector3(purgeOffsetA.x, purgeOffsetA.y - 0.2 + (config.yOffset or 0.00), purgeOffsetA.z + 0.2 + (config.zOffset or 0.00))
        else
            purgeOffsetA = vector3(0.0, 1.25 + (config.yOffset or 0.00), 0.65 + (config.zOffset or 0.00))
        end
    end

    local xOff = (config.xOffset or 0.50) * 1.0
    local angle = (config.angle or 20.0) * 1.0
    local pitch = (config.pitch or 40.0) * 1.0
    local nozzles = tonumber(config.nozzles) or 2

    local handles = {}

    local colorName = config.color or "white"
    local r, g, b = 1.0, 1.0, 1.0
    if colorName == "red" then r, g, b = 1.0, 0.15, 0.15
    elseif colorName == "blue" then r, g, b = 0.0, 0.55, 1.0
    elseif colorName == "green" then r, g, b = 0.0, 1.0, 0.35
    elseif colorName == "purple" then r, g, b = 0.70, 0.15, 1.0
    elseif colorName == "orange" then r, g, b = 1.0, 0.45, 0.0
    elseif colorName == "pink" then r, g, b = 1.0, 0.35, 0.75
    end

    if nozzles == 4 then
        local yOff2 = config.yOffset2 or ((config.yOffset or 0.05) - 0.10)
        local zOff2 = config.zOffset2 or (config.zOffset or 0.00)
        
        local purgeOffsetB
        bone = GetEntityBoneIndexByName(vehicle, "bonnet")
        if bone ~= -1 then
            local pos = GetWorldPositionOfEntityBone(vehicle, bone)
            purgeOffsetB = GetOffsetFromEntityGivenWorldCoords(vehicle, pos.x, pos.y, pos.z)
            purgeOffsetB = vector3(purgeOffsetB.x, purgeOffsetB.y + yOff2, purgeOffsetB.z + zOff2)
        else
            bone = GetEntityBoneIndexByName(vehicle, "engine")
            if bone ~= -1 then
                local pos = GetWorldPositionOfEntityBone(vehicle, bone)
                purgeOffsetB = GetOffsetFromEntityGivenWorldCoords(vehicle, pos.x, pos.y, pos.z)
                purgeOffsetB = vector3(purgeOffsetB.x, purgeOffsetB.y - 0.2 + yOff2, purgeOffsetB.z + 0.2 + zOff2)
            else
                purgeOffsetB = vector3(0.0, 1.25 + yOff2, 0.65 + zOff2)
            end
        end

        local xOff2 = (config.xOffset2 or (xOff * 0.5)) * 1.0
        if xOff2 < 0.05 then xOff2 = 0.15 end
        
        local angle2 = (config.angle2 or (angle * 0.5)) * 1.0
        local pitch2 = (config.pitch2 or pitch) * 1.0

        -- Pair A (Outer Nozzles)
        UseParticleFxAssetNextCall(ptfxAsset)
        local ptfx1 = StartParticleFxLoopedOnEntity("ent_sht_steam", vehicle, purgeOffsetA.x - xOff, purgeOffsetA.y, purgeOffsetA.z, pitch, -angle, 0.0, 0.35, false, false, false)
        table.insert(handles, ptfx1)

        UseParticleFxAssetNextCall(ptfxAsset)
        local ptfx2 = StartParticleFxLoopedOnEntity("ent_sht_steam", vehicle, purgeOffsetA.x + xOff, purgeOffsetA.y, purgeOffsetA.z, pitch, angle, 0.0, 0.35, false, false, false)
        table.insert(handles, ptfx2)

        -- Pair B (Inner Nozzles)
        UseParticleFxAssetNextCall(ptfxAsset)
        local ptfx3 = StartParticleFxLoopedOnEntity("ent_sht_steam", vehicle, purgeOffsetB.x - xOff2, purgeOffsetB.y, purgeOffsetB.z, pitch2, -angle2, 0.0, 0.35, false, false, false)
        table.insert(handles, ptfx3)

        UseParticleFxAssetNextCall(ptfxAsset)
        local ptfx4 = StartParticleFxLoopedOnEntity("ent_sht_steam", vehicle, purgeOffsetB.x + xOff2, purgeOffsetB.y, purgeOffsetB.z, pitch2, angle2, 0.0, 0.35, false, false, false)
        table.insert(handles, ptfx4)
    else
        -- Symmetrical 2 Nozzles (Pair A only)
        UseParticleFxAssetNextCall(ptfxAsset)
        local ptfx1 = StartParticleFxLoopedOnEntity("ent_sht_steam", vehicle, purgeOffsetA.x - xOff, purgeOffsetA.y, purgeOffsetA.z, pitch, -angle, 0.0, 0.35, false, false, false)
        table.insert(handles, ptfx1)

        UseParticleFxAssetNextCall(ptfxAsset)
        local ptfx2 = StartParticleFxLoopedOnEntity("ent_sht_steam", vehicle, purgeOffsetA.x + xOff, purgeOffsetA.y, purgeOffsetA.z, pitch, angle, 0.0, 0.35, false, false, false)
        table.insert(handles, ptfx2)
    end

    for _, ptfx in ipairs(handles) do
        SetParticleFxLoopedColour(ptfx, r, g, b, 0)
    end

    activePurgeHandles[vehicle] = handles
end

local function startPurgeEffects(vehicle, isPreview, previewConfig)
    if not isPreview and activePurgingVehicles[vehicle] then return end
    if not isPreview then
        activePurgingVehicles[vehicle] = true
    end
    
    if not isPreview then
        CreateThread(function()
            if not activePurgeSounds[vehicle] then
                local soundId = GetSoundId()
                activePurgeSounds[vehicle] = soundId
                PlaySoundFromEntity(soundId, "RES_WASH_STEAM", vehicle, "CAR_WASH_SOUNDS", true, 0)
            end
        end)
    end

    local config = { xOffset = 0.50, yOffset = 0.05, zOffset = 0.00, angle = 20, pitch = 40, nozzles = 2 }
    if isPreview and previewConfig then
        config = previewConfig
    else
        local stateData = Entity(vehicle).state.nosData
        if stateData and stateData.purgeConfig then
            config = stateData.purgeConfig
        end
    end
    
    spawnPurgeFx(vehicle, config)
end

local function stopPurgeEffects(vehicle, isPreview)
    if not isPreview then
        activePurgingVehicles[vehicle] = nil
    end
    
    if activePurgeHandles[vehicle] then
        for _, handle in ipairs(activePurgeHandles[vehicle]) do
            StopParticleFxLooped(handle, false)
        end
        activePurgeHandles[vehicle] = nil
    end
    
    if not isPreview and activePurgeSounds[vehicle] then
        StopSound(activePurgeSounds[vehicle])
        ReleaseSoundId(activePurgeSounds[vehicle])
        activePurgeSounds[vehicle] = nil
    end
end

AddStateBagChangeHandler('nosData', nil, function(bagName, key, value, _unused, replicated)
    local entityNetId = bagName:gsub('entity:', '')
    local netId = tonumber(entityNetId)
    if not netId then return end

    if currentVehicle and NetworkGetNetworkIdFromEntity(currentVehicle) == netId then
        nosData = value
        UpdateHUDState(true)
    end
end)

AddStateBagChangeHandler('nosBoosting', nil, function(bagName, key, value, _unused, replicated)
    local entityNetId = bagName:gsub('entity:', '')
    local netId = tonumber(entityNetId)
    if not netId then return end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or not DoesEntityExist(vehicle) then return end

    if value == true then
        if cache.vehicle == vehicle then
            StartScreenWarp()
        end
        startExhaustFlames(vehicle)
    else
        if cache.vehicle == vehicle then
            StopScreenWarp()
        end
        stopExhaustFlames(vehicle)
    end
end)

AddStateBagChangeHandler('nosPurging', nil, function(bagName, key, value, _unused, replicated)
    local entityNetId = bagName:gsub('entity:', '')
    local netId = tonumber(entityNetId)
    if not netId then return end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or not DoesEntityExist(vehicle) then return end

    if value == true then
        startPurgeEffects(vehicle)
    else
        stopPurgeEffects(vehicle)
    end
end)

function StartScreenWarp()
    if Config.ScreenEffect then
        StartScreenEffect("FocusIn", 0, true)
        SetTimecycleModifier("rply_motionblur")
    end
end

function StopScreenWarp()
    StopScreenEffect("FocusIn")
    ClearTimecycleModifier()
end

local lastHUDUpdateTime = 0

function UpdateHUDState(forced)
    if hudDisabled or not currentVehicle or not nosData or not nosData.system then
        if showingHUD then
            SendNUIMessage({ type = "hide" })
            showingHUD = false
        end
        return
    end

    if not showingHUD then
        SendNUIMessage({
            type = "loadLocale",
            locales = Locales[Config.Locale or 'en']
        })
        SendNUIMessage({ type = "show" })
        showingHUD = true
    end

    local now = GetGameTimer()
    local interval = 250
    if Config.PerformanceMode == 'uncapped' then
        interval = 0
    elseif isBoosting or isPurging then
        interval = 50
    end

    if forced or (now - lastHUDUpdateTime > interval) then
        SendNUIMessage({
            type = "update",
            bottle1 = nosData.bottles.bottle1 or 0.0,
            bottle2 = nosData.bottles.bottle2 or 0.0,
            temp = nosOverheat,
            system = nosData.system,
            active = isBoosting
        })
        lastHUDUpdateTime = now
    end
end

lib.onCache('vehicle', function(value)
    if value then
        currentVehicle = value
        local plate = GetVehicleNumberPlateText(value)
        local netId = NetworkGetNetworkIdFromEntity(value)
        
        nosData = lib.callback.await('npds_nos:server:getNOSData', 200, plate, netId)
        
        local savedOverheat = Entity(value).state.nosOverheat or 0.0
        local savedTime = Entity(value).state.nosOverheatTime or 0
        local wasOverheated = Entity(value).state.nosWasOverheated or false
        
        if savedOverheat > 0.0 and savedTime > 0 then
            local elapsedSeconds = GetCloudTimeAsInt() - savedTime
            if elapsedSeconds > 0 then
                local cooledAmount = elapsedSeconds * Config.EngineCoolDownRate
                savedOverheat = math.max(0.0, savedOverheat - cooledAmount)
            end
        end
        
        nosOverheat = savedOverheat
        
        if wasOverheated then
            if nosOverheat < 30.0 then
                isOverheated = false
                SetVehicleUndriveable(value, false)
                Entity(value).state:set('nosWasOverheated', false, true)
            else
                isOverheated = true
                SetVehicleUndriveable(value, true)
            end
        else
            isOverheated = (nosOverheat >= 100.0)
        end
        
        UpdateHUDState(true)
    else
        if currentVehicle and DoesEntityExist(currentVehicle) then
            Entity(currentVehicle).state:set('nosOverheat', nosOverheat, true)
            Entity(currentVehicle).state:set('nosOverheatTime', GetCloudTimeAsInt(), true)
            Entity(currentVehicle).state:set('nosWasOverheated', isOverheated, true)
            
            if not isOverheated then
                SetVehicleUndriveable(currentVehicle, false)
            end
        end
        currentVehicle = nil
        nosData = nil
        isBoosting = false
        isPurging = false
        nosOverheat = 0.0
        isOverheated = false
        StopScreenWarp()
        SendNUIMessage({ type = "hide" })
        showingHUD = false
    end
end)


CreateThread(function()
    local lastSyncTime = 0
    
    while true do
        local sleep = 500
        
        if currentVehicle and nosData and nosData.system then
            local ped = cache.ped
            
            local isDead = IsEntityDead(currentVehicle) or GetVehicleEngineHealth(currentVehicle) <= 0 or GetEntityHealth(currentVehicle) <= 0
            if isDead then
                if nosData.bottles.bottle1 > 0.0 or nosData.bottles.bottle2 > 0.0 then
                    nosData.bottles.bottle1 = 0.0
                    nosData.bottles.bottle2 = 0.0
                    local netId = NetworkGetNetworkIdFromEntity(currentVehicle)
                    TriggerServerEvent('npds_nos:server:syncNOSLevel', GetVehicleNumberPlateText(currentVehicle), netId, 0.0, 0.0)
                    if isBoosting then
                        isBoosting = false
                        Entity(currentVehicle).state:set('nosBoosting', false, true)
                        StopScreenWarp()
                    end
                    if isPurging then
                        isPurging = false
                        Entity(currentVehicle).state:set('nosPurging', false, true)
                    end
                    UpdateHUDState()
                end
            end


            if not isDead and GetPedInVehicleSeat(currentVehicle, -1) == ped then
                if Config.PerformanceMode == 'uncapped' or isBoosting or isPurging then
                    sleep = 0
                else
                    sleep = 50
                end
                
                local b1 = nosData.bottles.bottle1 or 0.0
                local b2 = nosData.bottles.bottle2 or 0.0
                local types = nosData.bottleTypes or defaultBottleTypes
                local t1 = types.bottle1 or "regular"
                local t2 = types.bottle2 or "regular"
                local rate1 = (t1 == "elite") and Config.NOSDrainRateElite or Config.NOSDrainRate
                local rate2 = (t2 == "elite") and Config.NOSDrainRateElite or Config.NOSDrainRate
                local heat1 = (t1 == "elite") and Config.EngineHeatRateElite or Config.EngineHeatRateRegular
                local heat2 = (t2 == "elite") and Config.EngineHeatRateElite or Config.EngineHeatRateRegular

                local isBoostPressed = IsControlPressed(0, Config.BoostKey)
                local isPurgePressed = IsControlPressed(0, Config.PurgeKey) or IsControlPressed(0, 326) or IsControlPressed(0, 210) or IsControlPressed(0, 349)
                
                local hasGas = false
                local currentHeatRate = Config.EngineHeatRateRegular

                if isBoostPressed and not isOverheated and GetVehicleEngineHealth(currentVehicle) > 0 then
                    if isPurging then
                        isPurging = false
                        Entity(currentVehicle).state:set('nosPurging', false, true)
                    end

                    if nosData.system == 'dual_nossystem' then
                        local hasB1 = b1 > 0.0
                        local hasB2 = b2 > 0.0
                        
                        if hasB1 and hasB2 then
                            local drain1 = (rate1 * GetFrameTime()) / 2.0
                            local drain2 = (rate2 * GetFrameTime()) / 2.0
                            nosData.bottles.bottle1 = math.max(0.0, b1 - drain1)
                            nosData.bottles.bottle2 = math.max(0.0, b2 - drain2)
                            currentHeatRate = (heat1 + heat2) / 2.0
                            hasGas = true
                        elseif hasB1 then
                            nosData.bottles.bottle1 = math.max(0.0, b1 - (rate1 * GetFrameTime()))
                            currentHeatRate = heat1
                            hasGas = true
                        elseif hasB2 then
                            nosData.bottles.bottle2 = math.max(0.0, b2 - (rate2 * GetFrameTime()))
                            currentHeatRate = heat2
                            hasGas = true
                        end
                    else
                        if b1 > 0.0 then
                            nosData.bottles.bottle1 = math.max(0.0, b1 - (rate1 * GetFrameTime()))
                            currentHeatRate = heat1
                            hasGas = true
                        end
                    end

                    if hasGas then
                        if not isBoosting then
                            isBoosting = true
                            local netId = NetworkGetNetworkIdFromEntity(currentVehicle)
                            TriggerServerEvent('npds_nos:server:syncNOSLevel', GetVehicleNumberPlateText(currentVehicle), netId, nosData.bottles.bottle1, nosData.bottles.bottle2)
                            Entity(currentVehicle).state:set('nosBoosting', true, true)
                        end

                        local speed = GetEntitySpeed(currentVehicle)
                        if speed < 80.0 then -- speed cap
                            local force = Config.BoostForce or 0.20
                            ApplyForceToEntity(currentVehicle, 1, 0.0, force, 0.0, 0.0, 0.0, 0.0, true, true, true, true, true, true)
                        end

                        nosOverheat = math.min(100.0, nosOverheat + (currentHeatRate * GetFrameTime()))
                        if nosOverheat >= 100.0 then
                            isOverheated = true
                            isBoosting = false
                            Entity(currentVehicle).state:set('nosBoosting', false, true)
                            Entity(currentVehicle).state:set('nosOverheat', nosOverheat, true)
                            Entity(currentVehicle).state:set('nosOverheatTime', GetCloudTimeAsInt(), true)
                            Entity(currentVehicle).state:set('nosWasOverheated', true, true)
                            StopScreenWarp()
                            SetVehicleEngineOn(currentVehicle, false, true, true)
                            SetVehicleUndriveable(currentVehicle, true) -- Block ignition grinding!
                            TriggerEvent('esx:showNotification', "ENGINE OVERHEATED! NOS stalled the car.", "error")
                            local netId = NetworkGetNetworkIdFromEntity(currentVehicle)
                            TriggerServerEvent('npds_nos:server:syncNOSLevel', GetVehicleNumberPlateText(currentVehicle), netId, nosData.bottles.bottle1, nosData.bottles.bottle2)
                        end

                        if GetGameTimer() - lastSyncTime > 2000 then
                            local netId = NetworkGetNetworkIdFromEntity(currentVehicle)
                            TriggerServerEvent('npds_nos:server:syncNOSLevel', GetVehicleNumberPlateText(currentVehicle), netId, nosData.bottles.bottle1, nosData.bottles.bottle2)
                            Entity(currentVehicle).state:set('nosOverheat', nosOverheat, true)
                            Entity(currentVehicle).state:set('nosOverheatTime', GetCloudTimeAsInt(), true)
                            lastSyncTime = GetGameTimer()
                        end
                    else
                        if isBoosting then
                            isBoosting = false
                            Entity(currentVehicle).state:set('nosBoosting', false, true)
                            local netId = NetworkGetNetworkIdFromEntity(currentVehicle)
                            TriggerServerEvent('npds_nos:server:syncNOSLevel', GetVehicleNumberPlateText(currentVehicle), netId, nosData.bottles.bottle1, nosData.bottles.bottle2)
                        end
                    end

                elseif isPurgePressed and (b1 > 0.0 or (nosData.system == 'dual_nossystem' and b2 > 0.0)) then
                    if isBoosting then
                        isBoosting = false
                        Entity(currentVehicle).state:set('nosBoosting', false, true)
                        StopScreenWarp()
                    end

                    if not isPurging then
                        isPurging = true
                        Entity(currentVehicle).state:set('nosPurging', true, true)
                    end

                    local rate = Config.PurgeDrainRate
                    if nosData.system == 'dual_nossystem' then
                        local hasB1 = b1 > 0.0
                        local hasB2 = b2 > 0.0
                        if hasB1 and hasB2 then
                            local drain = (rate * GetFrameTime()) / 2.0
                            nosData.bottles.bottle1 = math.max(0.0, b1 - drain)
                            nosData.bottles.bottle2 = math.max(0.0, b2 - drain)
                        elseif hasB1 then
                            nosData.bottles.bottle1 = math.max(0.0, b1 - (rate * GetFrameTime()))
                        elseif hasB2 then
                            nosData.bottles.bottle2 = math.max(0.0, b2 - (rate * GetFrameTime()))
                        end
                    else
                        if b1 > 0.0 then
                            nosData.bottles.bottle1 = math.max(0.0, b1 - (rate * GetFrameTime()))
                        end
                    end

                    nosOverheat = math.max(0.0, nosOverheat - (Config.PurgeCoolDownRate * GetFrameTime()))
                    if isOverheated and nosOverheat < 30.0 then
                        isOverheated = false
                        SetVehicleUndriveable(currentVehicle, false) -- Enable driving again!
                        Entity(currentVehicle).state:set('nosWasOverheated', false, true)
                        TriggerEvent('esx:showNotification', "Engine cooled down. Ready to start.", "success")
                    end

                    if GetGameTimer() - lastSyncTime > 1500 then
                        local netId = NetworkGetNetworkIdFromEntity(currentVehicle)
                        TriggerServerEvent('npds_nos:server:syncNOSLevel', GetVehicleNumberPlateText(currentVehicle), netId, nosData.bottles.bottle1, nosData.bottles.bottle2)
                        Entity(currentVehicle).state:set('nosOverheat', nosOverheat, true)
                        Entity(currentVehicle).state:set('nosOverheatTime', GetCloudTimeAsInt(), true)
                        lastSyncTime = GetGameTimer()
                    end

                else
                    if isBoosting then
                        isBoosting = false
                        Entity(currentVehicle).state:set('nosBoosting', false, true)
                        StopScreenWarp()
                        local netId = NetworkGetNetworkIdFromEntity(currentVehicle)
                        TriggerServerEvent('npds_nos:server:syncNOSLevel', GetVehicleNumberPlateText(currentVehicle), netId, nosData.bottles.bottle1, nosData.bottles.bottle2)
                    end
                    if isPurging then
                        isPurging = false
                        Entity(currentVehicle).state:set('nosPurging', false, true)
                        local netId = NetworkGetNetworkIdFromEntity(currentVehicle)
                        TriggerServerEvent('npds_nos:server:syncNOSLevel', GetVehicleNumberPlateText(currentVehicle), netId, nosData.bottles.bottle1, nosData.bottles.bottle2)
                    end

                    nosOverheat = math.max(0.0, nosOverheat - (Config.EngineCoolDownRate * GetFrameTime()))
                    if isOverheated and nosOverheat < 30.0 then
                        isOverheated = false
                        SetVehicleUndriveable(currentVehicle, false) -- Enable driving again!
                        Entity(currentVehicle).state:set('nosWasOverheated', false, true)
                        TriggerEvent('esx:showNotification', "Engine cooled down. Ready to start.", "success")
                    end
                end

                if isOverheated then
                    SetVehicleEngineOn(currentVehicle, false, true, true)
                end

                if Config.PerformanceMode == 'uncapped' or isBoosting or isPurging or nosOverheat > 0.0 then
                    UpdateHUDState()
                end
            end
        end
        
        Wait(sleep)
    end
end)

local function IsHoodOpenCheckRequired(vehicle)
    if not Config.RequireHoodOpen then return true end
    if not DoesVehicleHaveDoor(vehicle, 4) then return true end
    if GetVehicleDoorAngleRatio(vehicle, 4) > 0.15 then return true end
    Notify('error', Locale('hood_must_be_open'))
    return false
end

local function IsHoodClosedCheckRequired(vehicle)
    if not Config.RequireHoodOpen then return true end
    if not DoesVehicleHaveDoor(vehicle, 4) then return true end
    if GetVehicleDoorAngleRatio(vehicle, 4) < 0.15 then return true end
    Notify('error', Locale('hood_must_be_closed'))
    return false
end

RegisterNetEvent('npds_nos:client:useSystemKit', function(systemType)
    local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), 5.0, false)
    if not vehicle or not DoesEntityExist(vehicle) then
        Notify('error', Locale('no_vehicle_nearby'))
        return
    end

    if not IsHoodOpenCheckRequired(vehicle) then return end

    SetNuiFocus(true, true)
    SendNUIMessage({
        type = "loadLocale",
        locales = Locales[Config.Locale or 'en']
    })
    SendNUIMessage({
        type = "openInstallModal",
        system = systemType
    })
end)

RegisterNetEvent('npds_nos:client:useRefillBottle', function(isElite)
    local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), 5.0, false)
    if not vehicle or not DoesEntityExist(vehicle) then
        Notify('error', Locale('no_vehicle_nearby'))
        return
    end

    if not IsHoodOpenCheckRequired(vehicle) then return end

    local plate = GetVehicleNumberPlateText(vehicle)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    local data = lib.callback.await('npds_nos:server:getNOSData', 200, plate, netId)
    if not data or not data.system then
        Notify('error', Locale('no_rack_present'))
        return
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        type = "loadLocale",
        locales = Locales[Config.Locale or 'en']
    })
    SendNUIMessage({
        type = "openRefillModal",
        bottle1 = data.bottles.bottle1 or 0.0,
        bottle2 = data.bottles.bottle2 or 0.0,
        system = data.system,
        isElite = isElite or false
    })
end)

RegisterCommand('removenos', function()
    local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), 5.0, false)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    
    if not IsHoodOpenCheckRequired(vehicle) then return end

    SetNuiFocus(true, true)
    SendNUIMessage({
        type = "loadLocale",
        locales = Locales[Config.Locale or 'en']
    })
    SendNUIMessage({
        type = "openUninstallModal"
    })
end, false)

RegisterNUICallback('confirmInstall', function(data, cb)
    cb('ok')
    SetNuiFocus(false, false)
    
    local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), 5.0, false)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    local plate = GetVehicleNumberPlateText(vehicle)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    
    local systemType = data.system
    if lib.progressBar({
        duration = 5000,
        label = (systemType == 'single_nossystem') and "Welding 1-Bottle NOS Mount..." or "Welding 2-Bottle NOS Mount...",
        useWhileDead = false,
        canCancel = true,
        disable = { move = true },
        anim = { dict = "mini@repair", clip = "fixing_a_ped" }
    }) then
        TriggerServerEvent('npds_nos:server:installSystem', plate, netId, systemType)
    end
end)

RegisterNUICallback('confirmRefill', function(data, cb)
    cb('ok')
    SetNuiFocus(false, false)
    
    local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), 5.0, false)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    local plate = GetVehicleNumberPlateText(vehicle)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    
    local slot = tonumber(data.slot) or 1
    local isElite = data.isElite or false
    local labelStr = isElite and "Refitting Elite Nitrous Pressure Cylinder..." or "Refitting Nitrous Pressure Cylinder..."
    
    if lib.progressBar({
        duration = 4000,
        label = labelStr,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true },
        anim = { dict = "mini@repair", clip = "fixing_a_ped" }
    }) then
        lib.callback.await('npds_nos:server:refillBottleAction', 200, plate, netId, slot, isElite)
    end
end)

RegisterNUICallback('confirmUninstall', function(data, cb)
    cb('ok')
    SetNuiFocus(false, false)
    
    local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), 5.0, false)
    if not vehicle then return end
    local plate = GetVehicleNumberPlateText(vehicle)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    
    if lib.progressBar({
        duration = 4000,
        label = "Uninstalling NOS System Racks...",
        useWhileDead = false,
        canCancel = true,
        disable = { move = true },
        anim = { dict = "mini@repair", clip = "fixing_a_ped" }
    }) then
        TriggerServerEvent('npds_nos:server:uninstallSystem', plate, netId)
    end
end)

RegisterNUICallback('closeModal', function(data, cb)
    cb('ok')
    SetNuiFocus(false, false)
end)

-- Command to manually toggle HUD visibility
RegisterCommand('togglenoshud', function()
    hudDisabled = not hudDisabled
    if hudDisabled then
        SendNUIMessage({ type = "hide" })
        Notify('info', Locale('hud_toggled_off'))
    else
        Notify('info', Locale('hud_toggled_on'))
        UpdateHUDState()
    end
end, false)

-- Command to enter NUI HUD repositioning mode
RegisterCommand('movenoshud', function()
    if not nosData or not nosData.system then
        Notify('error', "No NOS system installed in this vehicle.")
        return
    end
    
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = "enterDragMode"
    })
end, false)

-- Command to reset HUD repositioning mode
RegisterCommand('resetnoshud', function()
    SendNUIMessage({
        type = "resetPosition"
    })
    Notify('success', "NOS HUD position reset to default.")
end, false)

-- Command for Police Officers to inspect a vehicle for NOS
local function ShowPoliceInspectionReport(plate, data)
    local localesTable = {}
    if Locales and Locales[Config.Locale or 'en'] then
        localesTable = Locales[Config.Locale or 'en']
    end

    SetNuiFocus(true, true)
    
    SendNUIMessage({
        type = "loadLocale",
        locales = localesTable
    })
    
    local systemVal = nil
    local bottlesVal = nil
    local bottleTypesVal = nil
    
    if data then
        systemVal = data.system
        bottlesVal = data.bottles
        bottleTypesVal = data.bottleTypes
    end

    SendNUIMessage({
        type = "openPoliceReportModal",
        plate = plate,
        system = systemVal,
        bottles = bottlesVal,
        bottleTypes = bottleTypesVal
    })
end

RegisterCommand('checknos', function()
    CreateThread(function()
        local hasJob = false
        local jobName = Framework.GetPlayerJob()
        if jobName then
            for _, job in ipairs(Config.PoliceJobs or { 'police', 'sheriff' }) do
                if jobName == job then
                    hasJob = true
                    break
                end
            end
        end

        if not hasJob then
            Notify('error', Locale('police_only'))
            return
        end

        local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), 5.0, false)
        if not vehicle or vehicle == 0 then
            Notify('error', Locale('no_vehicle_nearby'))
            return
        end
        if Framework.ProgressBar(3000, Locale('searching_vehicle'), "mini@repair", "fixing_a_ped", true) then
            local plate = GetVehicleNumberPlateText(vehicle)
            local netId = NetworkGetNetworkIdFromEntity(vehicle)
            local success, result = pcall(function()
                return lib.callback.await('npds_nos:server:getNOSData', 5000, plate, netId)
            end)
            local data = success and result or nil
            
            ShowPoliceInspectionReport(plate, data)
        end
    end)
end, false)

local isPreviewingPurge = false
local previewVehicle = nil
local tuningCam = nil
local camActive = false
local angleX = 0.0
local angleY = 25.0
local radius = 3.5

local function CleanupTuningCamera()
    if camActive then
        RenderScriptCams(false, true, 800, true, true)
        if tuningCam then
            SetCamActive(tuningCam, false)
            DestroyCam(tuningCam, false)
            tuningCam = nil
        end
        camActive = false
    end
end

local function GetTunerTargetCoords(vehicle)
    local bone = GetEntityBoneIndexByName(vehicle, "bonnet")
    if bone ~= -1 then
        local pos = GetWorldPositionOfEntityBone(vehicle, bone)
        return vector3(pos.x, pos.y, pos.z + 0.1)
    else
        bone = GetEntityBoneIndexByName(vehicle, "engine")
        if bone ~= -1 then
            return GetWorldPositionOfEntityBone(vehicle, bone)
        else
            return GetOffsetFromEntityInWorldCoords(vehicle, 0.0, 1.0, 0.6)
        end
    end
end

local function StartTuningCameraLoop(vehicle)
    CreateThread(function()
        while camActive do
            Wait(0)
            
            local offset = vector3(
                radius * math.cos(math.rad(angleY)) * math.cos(math.rad(angleX)),
                radius * math.cos(math.rad(angleY)) * math.sin(math.rad(angleX)),
                radius * math.sin(math.rad(angleY))
            )
            
            local targetCoords = GetTunerTargetCoords(vehicle)
            local camPos = targetCoords + offset
            
            SetCamCoord(tuningCam, camPos.x, camPos.y, camPos.z)
            PointCamAtCoord(tuningCam, targetCoords.x, targetCoords.y, targetCoords.z)
            
            DisableControlAction(0, 1, true) -- Look Left/Right
            DisableControlAction(0, 2, true) -- Look Up/Down
            DisableControlAction(0, 24, true) -- Attack/Click in-game
            DisableControlAction(0, 75, true) -- Exit vehicle
        end
    end)
end

local function ToggleTuningCamera(vehicle)
    if camActive then
        CleanupTuningCamera()
    else
        angleX = GetEntityHeading(vehicle) + 90.0
        angleY = 25.0
        radius = 3.5
        
        tuningCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
        SetCamActive(tuningCam, true)
        
        local targetCoords = GetTunerTargetCoords(vehicle)
        local offset = vector3(
            radius * math.cos(math.rad(angleY)) * math.cos(math.rad(angleX)),
            radius * math.cos(math.rad(angleY)) * math.sin(math.rad(angleX)),
            radius * math.sin(math.rad(angleY))
        )
        local camPos = targetCoords + offset
        SetCamCoord(tuningCam, camPos.x, camPos.y, camPos.z)
        PointCamAtCoord(tuningCam, targetCoords.x, targetCoords.y, targetCoords.z)
        SetCamFov(tuningCam, 45.0)
        
        RenderScriptCams(true, true, 800, true, true)
        camActive = true
        
        StartTuningCameraLoop(vehicle)
    end
end

RegisterNUICallback('camMove', function(data, cb)
    if camActive then
        angleX = angleX - (data.x * 0.3)
        angleY = angleY + (data.y * 0.3)
        
        if angleY > 80.0 then angleY = 80.0 end
        if angleY < 5.0 then angleY = 5.0 end
    end
    cb('ok')
end)

RegisterNUICallback('camZoom', function(data, cb)
    if camActive then
        if data.direction > 0 then
            radius = math.min(6.0, radius + 0.25) -- Zoom out
        else
            radius = math.max(1.5, radius - 0.25) -- Zoom in
        end
    end
    cb('ok')
end)

RegisterNUICallback('toggleTuningCamera', function(data, cb)
    cb('ok')
    if previewVehicle and DoesEntityExist(previewVehicle) then
        ToggleTuningCamera(previewVehicle)
    end
end)

RegisterNUICallback('startPurgePreview', function(data, cb)
    cb('ok')
    local ped = cache.ped
    local vehicle = GetVehiclePedIsIn(ped, false)
    if not vehicle or vehicle == 0 then return end
    
    isPreviewingPurge = true
    previewVehicle = vehicle
    startPurgeEffects(vehicle, true, data)
end)

RegisterNUICallback('updatePurgePreview', function(data, cb)
    cb('ok')
    if isPreviewingPurge and previewVehicle and DoesEntityExist(previewVehicle) then
        startPurgeEffects(previewVehicle, true, data)
    end
end)

RegisterNUICallback('savePurgeTuning', function(data, cb)
    cb('ok')
    SetNuiFocus(false, false)
    isPreviewingPurge = false
    CleanupTuningCamera()
    
    if previewVehicle and DoesEntityExist(previewVehicle) then
        stopPurgeEffects(previewVehicle, true)
        
        local plate = GetVehicleNumberPlateText(previewVehicle)
        local netId = NetworkGetNetworkIdFromEntity(previewVehicle)
        TriggerServerEvent('npds_nos:server:savePurgeTuning', plate, netId, data)
        previewVehicle = nil
    end
end)

RegisterNUICallback('cancelPurgeTuning', function(data, cb)
    cb('ok')
    SetNuiFocus(false, false)
    isPreviewingPurge = false
    CleanupTuningCamera()
    
    if previewVehicle and DoesEntityExist(previewVehicle) then
        stopPurgeEffects(previewVehicle, true)
        previewVehicle = nil
    end
end)

-- Command to open interactive purge alignment tuner (Mechanic only)
RegisterCommand('adjustpurge', function()
    local ped = cache.ped
    local vehicle = GetVehiclePedIsIn(ped, false)
    if not vehicle or vehicle == 0 then
        Notify('error', "You must be sitting in the vehicle to adjust the purge nozzles.")
        return
    end

    if not IsHoodClosedCheckRequired(vehicle) then return end

    local hasJob = true
    if Config.MechanicOnlyInstallation then
        hasJob = false
        local jobName = Framework.GetPlayerJob()
        if jobName then
            for _, job in ipairs(Config.AuthorizedJobs) do
                if jobName == job then
                    hasJob = true
                    break
                end
            end
        end
    end

    if not hasJob then
        Notify('error', Locale('mechanic_only'))
        return
    end
    
    local plate = GetVehicleNumberPlateText(vehicle)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local data = lib.callback.await('npds_nos:server:getNOSData', 200, plate, netId)
    if not data or not data.system then
        Notify('error', Locale('no_nos_installed'))
        return
    end
    
    previewVehicle = vehicle
    isPreviewingPurge = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = "loadLocale",
        locales = Locales[Config.Locale or 'en']
    })
    SendNUIMessage({
        type = "openPurgeTuner",
        config = data.purgeConfig or { xOffset = 0.50, yOffset = 0.05, zOffset = 0.00, angle = 20, pitch = 40, nozzles = 2 }
    })
end, false)

CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/movenoshud', 'Enter drag-and-move mode to reposition the NOS HUD on your screen.')
    TriggerEvent('chat:addSuggestion', '/resetnoshud', 'Reset the NOS HUD position back to the default bottom-right corner.')
    TriggerEvent('chat:addSuggestion', '/togglenoshud', 'Toggle the visibility of the NOS HUD on your screen.')
    TriggerEvent('chat:addSuggestion', '/adjustpurge', 'Open the real-time interactive alignment panel to configure your hood purge nozzles (Mechanics only).')
    TriggerEvent('chat:addSuggestion', '/checknos', 'Perform a physical inspection of a vehicle engine bay for illegal nitrous modifications (Police only).')
end)

CreateThread(function()
    RequestScriptAudioBank("CAR_WASH_SOUNDS", false)
    RequestScriptAudioBank("DLC_HEISTS_GENERIC_SOUNDS", false)
    Wait(1000) 
    if cache.vehicle then
        currentVehicle = cache.vehicle
        local plate = GetVehicleNumberPlateText(currentVehicle)
        local netId = NetworkGetNetworkIdFromEntity(currentVehicle)
        
        nosData = lib.callback.await('npds_nos:server:getNOSData', 200, plate, netId)
        UpdateHUDState(true)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if currentVehicle and DoesEntityExist(currentVehicle) then
            SetVehicleUndriveable(currentVehicle, false)
        end
        CleanupTuningCamera()
        if isPreviewingPurge and previewVehicle and DoesEntityExist(previewVehicle) then
            stopPurgeEffects(previewVehicle, true)
        end
    end
end)

-- Client-Side Exports
exports('GetVehicleNOSData', function(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return nil end
    return Entity(vehicle).state.nosData
end)

exports('HasNOSSystem', function(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return false end
    local state = Entity(vehicle).state.nosData
    return (state and state.system ~= nil) or false
end)

exports('GetNOSSystemType', function(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return nil end
    local state = Entity(vehicle).state.nosData
    return state and state.system or nil
end)

exports('GetNOSLevels', function(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return nil end
    local state = Entity(vehicle).state.nosData
    if not state then return nil end
    return state.bottles
end)


CreateThread(function()
    Wait(1500) 
    
    Framework.AddTargetVehicle({
        {
            name = 'inspect_nos',
            icon = 'fa-solid fa-clipboard-check',
            label = 'Inspect Nitrous System',
            jobs = Config.PoliceJobs or { 'police', 'sheriff' },
            action = function(entity)
                CreateThread(function()
                    local jobName = Framework.GetPlayerJob()
                    local hasJob = false
                    if jobName then
                        for _, job in ipairs(Config.PoliceJobs or { 'police', 'sheriff' }) do
                            if jobName == job then
                                hasJob = true
                                break
                            end
                        end
                    end

                    if not hasJob then
                        Notify('error', Locale('police_only'))
                        return
                    end

                    if Framework.ProgressBar(3000, Locale('searching_vehicle'), "mini@repair", "fixing_a_ped", true) then
                        local plate = GetVehicleNumberPlateText(entity)
                        local netId = NetworkGetNetworkIdFromEntity(entity)
                        
                        local success, result = pcall(function()
                            return lib.callback.await('npds_nos:server:getNOSData', 5000, plate, netId)
                        end)
                        local data = success and result or nil
                        
                        ShowPoliceInspectionReport(plate, data)
                    end
                end)
            end
        },
        {
            name = 'install_nos_target',
            icon = 'fa-solid fa-screwdriver-wrench',
            label = 'Install Nitrous System',
            jobs = Config.AuthorizedJobs,
            canInteract = function(entity)
                local state = Entity(entity).state.nosData
                return not state or not state.system
            end,
            action = function(entity)
                local jobName = Framework.GetPlayerJob()
                local hasJob = false
                if jobName then
                    for _, job in ipairs(Config.AuthorizedJobs) do
                        if jobName == job then
                            hasJob = true
                            break
                        end
                    end
                end

                if not hasJob then
                    Notify('error', Locale('mechanic_only'))
                    return
                end

                if not IsHoodOpenCheckRequired(entity) then return end

                local kits = lib.callback.await('npds_nos:server:getAvailableKits', 200)
                if not kits.single and not kits.double then
                    Notify('error', Locale('no_kits_in_inventory'))
                    return
                end

                if kits.single and kits.double then
                    lib.registerContext({
                        id = 'nos_install_menu',
                        title = 'Install Nitrous System',
                        options = {
                            {
                                title = 'Single-Bottle System (1-Bottle)',
                                description = 'Welds a single-bottle nitrous mount rack inside chassis.',
                                icon = 'fa-solid fa-flask',
                                onSelect = function()
                                    TriggerEvent('npds_nos:client:useSystemKit', 'single_nossystem')
                                end
                            },
                            {
                                title = 'Dual-Bottle System (2-Bottle)',
                                description = 'Welds a dynamic two-bottle nitrous mount rack inside chassis.',
                                icon = 'fa-solid fa-flask-vial',
                                onSelect = function()
                                    TriggerEvent('npds_nos:client:useSystemKit', 'dual_nossystem')
                                end
                            }
                        }
                    })
                    lib.showContext('nos_install_menu')
                elseif kits.single then
                    TriggerEvent('npds_nos:client:useSystemKit', 'single_nossystem')
                else
                    TriggerEvent('npds_nos:client:useSystemKit', 'dual_nossystem')
                end
            end
        },
        {
            name = 'uninstall_nos',
            icon = 'fa-solid fa-wrench',
            label = 'Uninstall Nitrous System',
            jobs = Config.AuthorizedJobs,
            canInteract = function(entity)
                local state = Entity(entity).state.nosData
                return state and state.system ~= nil
            end,
            action = function(entity)
                local jobName = Framework.GetPlayerJob()
                local hasJob = false
                if jobName then
                    for _, job in ipairs(Config.AuthorizedJobs) do
                        if jobName == job then
                            hasJob = true
                            break
                        end
                    end
                end

                if not hasJob then
                    Notify('error', Locale('mechanic_only'))
                    return
                end

                if not IsHoodOpenCheckRequired(entity) then return end

                local plate = GetVehicleNumberPlateText(entity)
                local netId = NetworkGetNetworkIdFromEntity(entity)
                
                -- Verify system is installed
                local data = lib.callback.await('npds_nos:server:getNOSData', 200, plate, netId)
                if not data or not data.system then
                    Notify('error', Locale('no_nos_installed'))
                    return
                end

                if Framework.ProgressBar(4000, "Uninstalling NOS System Racks...", "mini@repair", "fixing_a_ped", true) then
                    TriggerServerEvent('npds_nos:server:uninstallSystem', plate, netId)
                end
            end
        },
        {
            name = 'adjust_purge_nos',
            icon = 'fa-solid fa-gauge-high',
            label = 'Calibrate Purge Nozzles',
            jobs = Config.AuthorizedJobs,
            canInteract = function(entity)
                local state = Entity(entity).state.nosData
                return state and state.system ~= nil
            end,
            action = function(entity)
                local jobName = Framework.GetPlayerJob()
                local hasJob = false
                if jobName then
                    for _, job in ipairs(Config.AuthorizedJobs) do
                        if jobName == job then
                            hasJob = true
                            break
                        end
                    end
                end

                if not hasJob then
                    Notify('error', Locale('mechanic_only'))
                    return
                end

                if not IsHoodClosedCheckRequired(entity) then return end

                local plate = GetVehicleNumberPlateText(entity)
                local netId = NetworkGetNetworkIdFromEntity(entity)
                local data = lib.callback.await('npds_nos:server:getNOSData', 200, plate, netId)
                if not data or not data.system then
                    Notify('error', Locale('no_nos_installed'))
                    return
                end

                previewVehicle = entity
                isPreviewingPurge = true
                SetNuiFocus(true, true)
                SendNUIMessage({
                    type = "loadLocale",
                    locales = Locales[Config.Locale or 'en']
                })
                SendNUIMessage({
                    type = "openPurgeTuner",
                    config = data.purgeConfig or { xOffset = 0.50, yOffset = 0.05, zOffset = 0.00, angle = 20, pitch = 40, nozzles = 2 }
                })
            end
        }
    })
end)

