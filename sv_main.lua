local VehiclesNOSData = {}

-- Utility to trim plates
local function TrimPlate(plate)
    if not plate then return "" end
    return plate:gsub("^%s*(.-)%s*$", "%1")
end

-- Check if player is authorized mechanic
local function IsAuthorizedMechanic(source)
    if not Config.MechanicOnlyInstallation then return true end
    local jobName = Framework.GetPlayerJob(source)
    if jobName then
        for _, job in ipairs(Config.AuthorizedJobs) do
            if jobName == job then return true end
        end
    end
    return false
end

-- Load NOS state from Database metadata
local function GetOrLoadNOSData(plate)
    local trimmed = TrimPlate(plate)
    if VehiclesNOSData[trimmed] then return VehiclesNOSData[trimmed] end

    local result = MySQL.single.await('SELECT * FROM npds_installed_nos WHERE plate = ?', {trimmed})
    if result then
        local bottles = { bottle1 = tonumber(result.bottle1) or 0.0, bottle2 = tonumber(result.bottle2) or 0.0 }
        local bottleTypes = { bottle1 = result.bottle1_type or "regular", bottle2 = result.bottle2_type or "regular" }
        local purgeConfig = result.purge_config and json.decode(result.purge_config) or { xOffset = 0.50, yOffset = 0.05, zOffset = 0.00, angle = 20, pitch = 40 }

        VehiclesNOSData[trimmed] = {
            system = result.system,
            bottles = bottles,
            bottleTypes = bottleTypes,
            purgeConfig = purgeConfig
        }
        return VehiclesNOSData[trimmed]
    end
    return nil
end

-- Save NOS state back to Database metadata
local function SaveNOSDataToDB(plate)
    local trimmed = TrimPlate(plate)
    local data = VehiclesNOSData[trimmed]
    if not data then return end

    MySQL.query([[
        INSERT INTO npds_installed_nos (plate, system, bottle1, bottle2, bottle1_type, bottle2_type, purge_config)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            system = VALUES(system),
            bottle1 = VALUES(bottle1),
            bottle2 = VALUES(bottle2),
            bottle1_type = VALUES(bottle1_type),
            bottle2_type = VALUES(bottle2_type),
            purge_config = VALUES(purge_config)
    ]], {
        trimmed,
        data.system,
        data.bottles.bottle1 or 0.0,
        data.bottles.bottle2 or 0.0,
        data.bottleTypes.bottle1 or "regular",
        data.bottleTypes.bottle2 or "regular",
        json.encode(data.purgeConfig or { xOffset = 0.50, yOffset = 0.05, zOffset = 0.00, angle = 20, pitch = 40 })
    })
end

-- Callback to retrieve or initialize NOS data for a spawned vehicle
lib.callback.register('npds_nos:server:getNOSData', function(source, plate, netId)
    local trimmed = TrimPlate(plate)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or not DoesEntityExist(entity) then return nil end

    local data = GetOrLoadNOSData(trimmed)
    if not data then
        -- Check if the state bag already has the data (e.g. resource restarted but vehicle still exists in game world)
        local stateData = Entity(entity).state.nosData
        if stateData then
            VehiclesNOSData[trimmed] = stateData
            data = stateData
        end
    end

    if data then
        -- Sync using FiveM Entity State Bag
        Entity(entity).state:set('nosData', data, true)
    end
    return data
end)

-- Server-side installation usable items
Framework.RegisterUsableItem(Config.System1Item, function(source)
    if not IsAuthorizedMechanic(source) then
        Notify(source, 'error', Locale('mechanic_only'))
        return
    end

    TriggerClientEvent('npds_nos:client:useSystemKit', source, 'single_nossystem')
end)

Framework.RegisterUsableItem(Config.System2Item, function(source)
    if not IsAuthorizedMechanic(source) then
        Notify(source, 'error', Locale('mechanic_only'))
        return
    end

    TriggerClientEvent('npds_nos:client:useSystemKit', source, 'dual_nossystem')
end)

Framework.RegisterUsableItem(Config.NOSRefillItem, function(source)
    if Config.MechanicOnlyRefill and not IsAuthorizedMechanic(source) then
        Notify(source, 'error', Locale('mechanic_only_refill'))
        return
    end

    TriggerClientEvent('npds_nos:client:useRefillBottle', source, false)
end)

Framework.RegisterUsableItem(Config.NOSEliteRefillItem, function(source)
    if Config.MechanicOnlyRefill and not IsAuthorizedMechanic(source) then
        Notify(source, 'error', Locale('mechanic_only_refill'))
        return
    end

    TriggerClientEvent('npds_nos:client:useRefillBottle', source, true)
end)

-- Install event called by client
RegisterNetEvent('npds_nos:server:installSystem', function(plate, netId, systemType)
    local src = source
    local trimmed = TrimPlate(plate)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or not DoesEntityExist(entity) then return end

    -- Check if system already exists
    local current = GetOrLoadNOSData(trimmed)
    if current and current.system then
        Notify(src, 'error', Locale('nos_already_installed'))
        return
    end

    -- Setup new system data
    local data = {
        system = systemType,
        bottles = { bottle1 = 0.0, bottle2 = 0.0 },
        bottleTypes = { bottle1 = "regular", bottle2 = "regular" }
    }
    VehiclesNOSData[trimmed] = data

    -- Consume item
    local itemName = (systemType == 'single_nossystem') and Config.System1Item or Config.System2Item
    Framework.RemoveInventoryItem(src, itemName, 1)

    -- Update state bag & save to DB
    Entity(entity).state:set('nosData', data, true)
    SaveNOSDataToDB(trimmed)

    local successMsg = (systemType == 'single_nossystem') and Locale('1bottle_installed') or Locale('2bottle_installed')
    Notify(src, 'success', successMsg)
end)

-- Refill callback picker registered for slots
lib.callback.register('npds_nos:server:refillBottleAction', function(source, plate, netId, slot, isElite)
    -- Verify player actually has the correct bottle item
    local refillItem = isElite and Config.NOSEliteRefillItem or Config.NOSRefillItem
    if not Framework.HasItem(source, refillItem) then return false end

    local trimmed = TrimPlate(plate)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or not DoesEntityExist(entity) then return false end

    local data = GetOrLoadNOSData(trimmed)
    if not data or not data.system then
        Notify(source, 'error', Locale('no_rack_present'))
        return false
    end

    data.bottleTypes = data.bottleTypes or { bottle1 = "regular", bottle2 = "regular" }

    -- Update slot levels and types
    if slot == 1 then
        data.bottles.bottle1 = 100.0
        data.bottleTypes.bottle1 = isElite and "elite" or "regular"
    elseif slot == 2 and data.system == 'dual_nossystem' then
        data.bottles.bottle2 = 100.0
        data.bottleTypes.bottle2 = isElite and "elite" or "regular"
    else
        return false
    end

    -- Remove item
    Framework.RemoveInventoryItem(source, refillItem, 1)

    -- Update state bag & save to DB
    Entity(entity).state:set('nosData', data, true)
    SaveNOSDataToDB(trimmed)

    if data.system == 'single_nossystem' then
        Notify(source, 'success', Locale('bottle_installed_single'))
    else
        Notify(source, 'success', Locale('bottle_swapped', slot))
    end

    return true
end)

-- Sync consumption level from client during active boosting
RegisterNetEvent('npds_nos:server:syncNOSLevel', function(plate, netId, b1, b2)
    local trimmed = TrimPlate(plate)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or not DoesEntityExist(entity) then return end

    local data = GetOrLoadNOSData(trimmed)
    if data then
        data.bottles.bottle1 = b1
        data.bottles.bottle2 = b2

        -- Update state bag and save
        Entity(entity).state:set('nosData', data, true)
        SaveNOSDataToDB(trimmed)
    end
end)

-- Event for mechanics to remove the system entirely
RegisterNetEvent('npds_nos:server:uninstallSystem', function(plate, netId)
    local src = source
    if not IsAuthorizedMechanic(src) then return end

    local trimmed = TrimPlate(plate)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or not DoesEntityExist(entity) then return end

    local data = GetOrLoadNOSData(trimmed)
    if not data or not data.system then
        Notify(src, 'error', Locale('no_rack_present'))
        return
    end

    -- Give the installation kit back to player
    local returnItem = (data.system == 'single_nossystem') and Config.System1Item or Config.System2Item
    Framework.AddInventoryItem(src, returnItem, 1)

    -- Clear state
    VehiclesNOSData[trimmed] = nil
    Entity(entity).state:set('nosData', nil, true)

    -- Clear database columns
    MySQL.update('DELETE FROM npds_installed_nos WHERE plate = ?', {trimmed})

    Notify(src, 'success', Locale('nos_removed'))
end)

-- Event for mechanics to save custom purge nozzle tuning
RegisterNetEvent('npds_nos:server:savePurgeTuning', function(plate, netId, config)
    local src = source
    if not IsAuthorizedMechanic(src) then return end

    local trimmed = TrimPlate(plate)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or not DoesEntityExist(entity) then return end

    local data = GetOrLoadNOSData(trimmed)
    if data then
        data.purgeConfig = config
        
        -- Sync to vehicle state bag for all players
        Entity(entity).state:set('nosData', data, true)
        
        -- Save persistently in database owned_vehicles.vehicle metadata
        SaveNOSDataToDB(trimmed)
        Notify(src, 'success', Locale('purge_alignment_saved'))
    end
end)

-- Callback to query dynamic rack kit items in player inventory
lib.callback.register('npds_nos:server:getAvailableKits', function(source)
    local hasSingle = Framework.HasItem(source, Config.System1Item)
    local hasDouble = Framework.HasItem(source, Config.System2Item)
    return { single = hasSingle, double = hasDouble }
end)


-- Server-Side Exports
exports('GetVehicleNOSData', function(plate)
    if not plate then return nil end
    return GetOrLoadNOSData(plate)
end)

exports('HasNOSSystem', function(plate)
    if not plate then return false end
    local data = GetOrLoadNOSData(plate)
    return (data and data.system ~= nil) or false
end)

exports('GetNOSSystemType', function(plate)
    if not plate then return nil end
    local data = GetOrLoadNOSData(plate)
    return data and data.system or nil
end)

exports('GetNOSLevels', function(plate)
    if not plate then return nil end
    local data = GetOrLoadNOSData(plate)
    if not data then return nil end
    return data.bottles
end)

