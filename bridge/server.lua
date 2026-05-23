Framework = {}
activeFramework = 'standalone'
local ESX = nil
local QBCore = nil

CreateThread(function()
    if GetResourceState('qbx_core') == 'started' then
        activeFramework = 'qbx'
        QBCore = exports['qb-core']:GetCoreObject()
        print('^2[NPDS NOS Server Bridge] Loaded successfully! Framework: QBX^7')
    elseif GetResourceState('qb-core') == 'started' then
        activeFramework = 'qb'
        QBCore = exports['qb-core']:GetCoreObject()
        print('^2[NPDS NOS Server Bridge] Loaded successfully! Framework: QB-Core^7')
    elseif GetResourceState('es_extended') == 'started' then
        activeFramework = 'esx'
        ESX = exports['es_extended']:getSharedObject()
        print('^2[NPDS NOS Server Bridge] Loaded successfully! Framework: ESX^7')
    end
end)

function Framework.GetActiveFramework()
    return activeFramework
end

function Framework.GetPlayerJob(source)
    if activeFramework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        return xPlayer and xPlayer.job and xPlayer.job.name or nil
    elseif activeFramework == 'qb' or activeFramework == 'qbx' then
        local Player = QBCore.Functions.GetPlayer(source)
        return Player and Player.PlayerData and Player.PlayerData.job and Player.PlayerData.job.name or nil
    end
    return nil
end

function Framework.Notify(target, type, message)
    local notifySys = Config.NotificationSystem or 'ox_lib'
    if notifySys == 'ox_lib' then
        TriggerClientEvent('ox_lib:notify', target, {
            title = 'NOS System',
            type = type,
            description = message
        })
    elseif notifySys == 'framework' then
        if activeFramework == 'esx' then
            TriggerClientEvent('esx:showNotification', target, message, type)
        elseif activeFramework == 'qb' or activeFramework == 'qbx' then
            TriggerClientEvent('QBCore:Notify', target, message, type)
        end
    else
        TriggerClientEvent('chat:addMessage', target, {
            args = { '^8[NOS System]^7', message }
        })
    end
end

Notify = Framework.Notify

function Framework.RegisterUsableItem(itemName, callback)
    CreateThread(function()
        while activeFramework == 'standalone' do Wait(100) end
        
        if activeFramework == 'esx' then
            ESX.RegisterUsableItem(itemName, callback)
        elseif activeFramework == 'qb' or activeFramework == 'qbx' then
            QBCore.Functions.CreateUseableItem(itemName, callback)
        end
    end)
end

function Framework.AddInventoryItem(source, itemName, count)
    count = count or 1
    if activeFramework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            xPlayer.addInventoryItem(itemName, count)
        end
    elseif activeFramework == 'qb' or activeFramework == 'qbx' then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            Player.Functions.AddItem(itemName, count)
            TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[itemName], "add")
        end
    end
end

function Framework.RemoveInventoryItem(source, itemName, count)
    count = count or 1
    if activeFramework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            xPlayer.removeInventoryItem(itemName, count)
        end
    elseif activeFramework == 'qb' or activeFramework == 'qbx' then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            Player.Functions.RemoveItem(itemName, count)
            TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[itemName], "remove")
        end
    end
end

function Framework.HasItem(source, itemName)
    if GetResourceState('ox_inventory') == 'started' then
        local count = exports.ox_inventory:GetItemCount(source, itemName)
        return count and count > 0 or false
    end

    if activeFramework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            local item = xPlayer.getInventoryItem(itemName)
            return item and item.count > 0 or false
        end
    elseif activeFramework == 'qb' or activeFramework == 'qbx' then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            local item = Player.Functions.GetItemByName(itemName)
            return item and item.amount > 0 or false
        end
    end
    return false
end
