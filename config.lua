Config = {}

Config.Locale = 'en'                  -- Default localization language ('en' or 'nl')
Config.TargetSystem = 'auto'          -- Targeting system: 'auto' (auto-detects ox_target / qb-target), 'ox_target', 'qb-target', or 'none'
Config.NotificationSystem = 'ox_lib'  -- Notification system: 'framework' (ESX/QB native), 'ox_lib', or 'chat'
Config.PerformanceMode = 'optimized'  -- Performance Mode: 'optimized' or 'uncapped'

-- Keybind Settings - Change these in the config.lua to your liking. 
Config.PurgeKey = 36                  -- Control ID: Left Control (INPUT_DUCK) inside vehicles
Config.BoostKey = 21                  -- Control ID: Left Shift (INPUT_FRONTEND_RDOWN / Sprint key in vehicle)

-- Installation Restrictions
Config.MechanicOnlyInstallation = true -- If true, only players with mechanic jobs can install the NOS systems (Marks)
Config.MechanicOnlyRefill = false      -- If true, only mechanics can swap/refill bottles. If false, anyone can do it if a rack is installed.
Config.RequireHoodOpen = true          -- If true, the vehicle hood must be open to install, refill, uninstall, or adjust purge nozzles.
Config.AuthorizedJobs = { 'mechanic', 'bennys', 'hayes' } -- Authorized jobs for installation/removal

-- Police Inspection Settings
Config.PoliceJobs = { 'police', 'sheriff' }     -- Authorized jobs allowed to use /checknos

-- Item Configuration
Config.System1Item = 'single_nossystem'        -- Item to install the 1-bottle system
Config.System2Item = 'dual_nossystem'          -- Item to install the 2-bottle system
Config.NOSRefillItem = 'nos_bottle'             -- Standard item used to mount/refill a bottle slot
Config.NOSEliteRefillItem = 'nos_elite_bottle'  -- Elite item (drains slower, heats engine slower)

-- Boost Behavior
Config.BoostMultiplier = 1.10                   -- Multiplier applied to vehicle speed/force during boost
Config.BoostForce = 0.2                         -- Physical push force applied to the vehicle (higher = faster acceleration, nerfed for realism)
Config.NOSDrainRate = 2.0                       -- How many percentage points of gas are consumed per second of boost (e.g. 2% per sec = 50s total boost)
Config.NOSDrainRateElite = 1.0                  -- Elite bottle drains at half rate (e.g. 1.0% per sec = 100s total boost)
Config.BoostCooldown = 1500                     -- Cooldown in milliseconds after boosting before you can boost again

-- Overheat Mechanics
Config.EngineHeatRateRegular = 12.5             -- Temperature increase per second during regular boost (8s to overheat)
Config.EngineHeatRateElite = 6.0                -- Temperature increase per second during elite boost (16.6s to overheat)
Config.EngineCoolDownRate = 3.5                 -- Slower natural cooldown rate per second of engine temperature (was 8.0)

-- Purge Mechanics
Config.PurgeDrainRate = 4.0                     -- Drains 4% pressure per second of active purge
Config.PurgeCoolDownRate = 20.0                 -- Cools engine extremely fast by 20% per second during active purge

-- Visual and Screen Effects
Config.ScreenEffect = true                      -- Enable warp screen effect during boost
Config.ScreenEffectForPassengers = true         -- Enable motion-blur warp screen effect for all passengers in the vehicle


