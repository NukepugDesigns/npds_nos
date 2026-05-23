Framework = {}
activeFramework = 'standalone'
local ESX = nil
local QBCore = nil

CreateThread(function()
    if GetResourceState('qbx_core') == 'started' then
        activeFramework = 'qbx'
        QBCore = exports['qb-core']:GetCoreObject()
        print('^2[NPDS NOS Client Bridge] Loaded successfully! Framework: QBX^7')
    elseif GetResourceState('qb-core') == 'started' then
        activeFramework = 'qb'
        QBCore = exports['qb-core']:GetCoreObject()
        print('^2[NPDS NOS Client Bridge] Loaded successfully! Framework: QB-Core^7')
    elseif GetResourceState('es_extended') == 'started' then
        activeFramework = 'esx'
        ESX = exports['es_extended']:getSharedObject()
        print('^2[NPDS NOS Client Bridge] Loaded successfully! Framework: ESX^7')
    end
end)

function Framework.GetActiveFramework()
    return activeFramework
end

function Framework.GetPlayerJob()
    if activeFramework == 'esx' then
        local data = ESX.GetPlayerData()
        return data and data.job and data.job.name or nil
    elseif activeFramework == 'qb' or activeFramework == 'qbx' then
        local data = QBCore.Functions.GetPlayerData()
        return data and data.job and data.job.name or nil
    end
    return nil
end

function Framework.Notify(type, message)
    local notifySys = Config.NotificationSystem or 'ox_lib'
    if notifySys == 'ox_lib' then
        lib.notify({
            title = 'NOS System',
            type = type,
            description = message
        })
    elseif notifySys == 'framework' then
        if activeFramework == 'esx' then
            TriggerEvent('esx:showNotification', message, type)
        elseif activeFramework == 'qb' or activeFramework == 'qbx' then
            QBCore.Functions.Notify(message, type)
        end
    else
        TriggerEvent('chat:addMessage', {
            args = { '^8[NOS System]^7', message }
        })
    end
end

Notify = Framework.Notify

function Framework.ProgressBar(duration, label, animDict, animClip, disableMove)
    return lib.progressBar({
        duration = duration,
        label = label,
        useWhileDead = false,
        canCancel = true,
        disable = { move = disableMove or false },
        anim = { dict = animDict, clip = animClip }
    })
end

function Framework.AddTargetVehicle(options)
    local targetSys = Config.TargetSystem or 'auto'
    if targetSys == 'auto' then
        if GetResourceState('ox_target') == 'started' then
            targetSys = 'ox_target'
        elseif GetResourceState('qb-target') == 'started' then
            targetSys = 'qb-target'
        else
            targetSys = 'none'
        end
    end

    if targetSys == 'ox_target' then
        local oxOptions = {}
        for _, opt in ipairs(options) do
            table.insert(oxOptions, {
                name = opt.name or opt.label,
                icon = opt.icon or 'fa-solid fa-gauge-high',
                label = opt.label,
                groups = opt.jobs,
                canInteract = function(entity, distance, coords, name, bone)
                    if opt.canInteract then
                        return opt.canInteract(entity)
                    end
                    return true
                end,
                onSelect = function(data)
                    if opt.action then
                        opt.action(data.entity)
                    end
                end
            })
        end
        exports.ox_target:addGlobalVehicle(oxOptions)
        
    elseif targetSys == 'qb-target' then
        local qbOptions = {}
        for _, opt in ipairs(options) do
            table.insert(qbOptions, {
                type = "client",
                action = function(entity)
                    if opt.action then
                        opt.action(entity)
                    end
                end,
                canInteract = function(entity)
                    -- Real-time job validation to bypass buggy qb-target job checks
                    if opt.jobs then
                        local jobName = Framework.GetPlayerJob()
                        local hasJob = false
                        if jobName then
                            for _, job in ipairs(opt.jobs) do
                                if jobName == job then
                                    hasJob = true
                                    break
                                end
                            end
                        end
                        if not hasJob then return false end
                    end

                    if opt.canInteract then
                        return opt.canInteract(entity)
                    end
                    return true
                end,
                icon = opt.icon or 'fas fa-gauge-high',
                label = opt.label
            })
        end
        exports['qb-target']:AddGlobalVehicle({
            options = qbOptions,
            distance = 2.5
        })
    end
end
