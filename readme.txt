================================================================================
RESOURCE: npds_nos
AUTHOR: NukepugDesigns
VERSION: 1.1.0
DESCRIPTION: Premium Multi-Framework Nitrous Oxide (NOS) System & Purge Calibration
================================================================================

Welcome to the Premium Standalone & Multi-Framework NOS system! This resource is
compatible out-of-the-box with ESX, QB-Core, QBX, and Standalone servers. It
utilizes the state-of-the-art ox_lib UI and progress wrappers.

--------------------------------------------------------------------------------
1. KEY FEATURES
--------------------------------------------------------------------------------
* 🛠️ DUAL SYSTEM MOUNTS: 1-bottle and 2-bottle mount system support.
* 🚀 PREMIUM NUI HUD: Glassmorphic NUI layout showing active levels and engine temp.
* ⚡ ELITE CYLINDERS: Support for high-capacity 'Elite' bottles (drains slower, runs cooler).
* 💨 CALIBRATED PURGES: Mechanics can fully adjust nozzle direction, angle, and RGB gas colors.
* 👮 POLICE INSPECTION: Officers can run "/checknos" to inspect engines for illegal mods.
* ⚙️ ULTIMATE OPTIMIZATION: Dynamic loop sleeping (resting at 0.00-0.01ms).
* 🌐 MULTI-LANGUAGE: Fully localized in English ('en') and Dutch ('nl'), including all NUIs.

--------------------------------------------------------------------------------
2. DEPENDENCIES & REQUIREMENTS
--------------------------------------------------------------------------------
Ensure you have the following resources started on your server:
1. `ox_lib` (Required)
2. `oxmysql` (Required for persistent vehicle installation data)
3. One of the supported frameworks: `es_extended` OR `qb-core` OR `qbx_core`

--------------------------------------------------------------------------------
3. SQL SCHEMA INSTALLATION
--------------------------------------------------------------------------------
Execute the queries in `install.sql` in your database manager (HeidiSQL, phpMyAdmin).
This registers the persistent NOS installations table:

```sql
CREATE TABLE IF NOT EXISTS `npds_installed_nos` (
  `plate` varchar(50) NOT NULL,
  `system` varchar(50) DEFAULT NULL,
  `bottle1` float DEFAULT 0,
  `bottle2` float DEFAULT 0,
  `bottle1_type` varchar(50) DEFAULT 'regular',
  `bottle2_type` varchar(50) DEFAULT 'regular',
  `purge_config` longtext DEFAULT NULL,
  PRIMARY KEY (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

--------------------------------------------------------------------------------
4. CONFIGURING YOUR FRAMEWORK
--------------------------------------------------------------------------------
Open `config.lua` and adjust your preferences:

* **Config.Locale**: Set to `'en'` (English) or `'nl'` (Dutch).
* **Config.TargetSystem**: Set to `'auto'` (auto-detects ox_target/qb-target), `'ox_target'`, `'qb-target'`, or `'none'`.
* **Config.PerformanceMode**: Set to `'optimized'` (resting resmon 0.01ms) or `'uncapped'` (resting resmon 0.10ms).

--------------------------------------------------------------------------------
5. REGISTERING ITEMS
--------------------------------------------------------------------------------

### For QB-Core / QBX (`qb-core/shared/items.lua`):
```lua
['single_nossystem'] = {['name'] = 'single_nossystem', ['label'] = '1-Bottle NOS Rack', ['weight'] = 5000, ['type'] = 'item', ['image'] = 'single_nossystem.png', ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['combinable'] = nil, ['description'] = 'Single bottle mounting rack. Requires welding into chassis.'},
['dual_nossystem']   = {['name'] = 'dual_nossystem',   ['label'] = '2-Bottle NOS Rack', ['weight'] = 7500, ['type'] = 'item', ['image'] = 'dual_nossystem.png',   ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['combinable'] = nil, ['description'] = 'Dual bottle mounting rack. Requires welding into chassis.'},
['nos_bottle']        = {['name'] = 'nos_bottle',        ['label'] = 'Nitrous Cylinder',  ['weight'] = 3000, ['type'] = 'item', ['image'] = 'nos_bottle.png',        ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['combinable'] = nil, ['description'] = 'Pressurized nitrous oxide cylinder.'},
['nos_elite_bottle']  = {['name'] = 'nos_elite_bottle',  ['label'] = 'Elite Cylinder',    ['weight'] = 3500, ['type'] = 'item', ['image'] = 'nos_elite_bottle.png',  ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['combinable'] = nil, ['description'] = 'High-capacity elite nitrous cylinder.'},
```

### For ESX / Ox Inventory (`ox_inventory/data/items.lua`):
```lua
['single_nossystem'] = {
    label = '1-Bottle NOS Rack',
    weight = 5000,
    stack = true,
    close = true,
    description = 'Single bottle mounting rack. Requires welding into chassis.'
},
['dual_nossystem'] = {
    label = '2-Bottle NOS Rack',
    weight = 7500,
    stack = true,
    close = true,
    description = 'Dual bottle mounting rack. Requires welding into chassis.'
},
['nos_bottle'] = {
    label = 'Nitrous Cylinder',
    weight = 3000,
    stack = true,
    close = true,
    description = 'Pressurized nitrous oxide cylinder.'
},
['nos_elite_bottle'] = {
    label = 'Elite Cylinder',
    weight = 3500,
    stack = true,
    close = true,
    description = 'High-capacity elite nitrous cylinder.'
}
```

--------------------------------------------------------------------------------
6. COMMANDS
--------------------------------------------------------------------------------
* `/togglenoshud` - Toggles the visibility of the visual NOS HUD.
* `/movenoshud`  - Enters drag mode to reposition the HUD anywhere on your screen.
* `/resetnoshud` - Resets HUD position back to the default bottom-right area.
* `/removenos`   - Dismantles the brackets and recovers the system kit (Mechanic only).
* `/adjustpurge` - Opens the interactive calibration tuner for purge nozzles (Mechanics only).
* `/checknos`    - Performs a search on a vehicle engine bay for illegal mods (Police only).

--------------------------------------------------------------------------------
7. EXPORTS & STATE BAGS
--------------------------------------------------------------------------------

### Server-Side Exports:
* `exports['npds_nos']:GetVehicleNOSData(plate)` -> Returns full database/cached table.
* `exports['npds_nos']:HasNOSSystem(plate)` -> Returns boolean.
* `exports['npds_nos']:GetNOSSystemType(plate)` -> Returns string mount system.
* `exports['npds_nos']:GetNOSLevels(plate)` -> Returns bottle percentage levels table.

### Vehicle State Bag: `nosData`
Check whether a vehicle has NOS or query its current parameters.
```lua
local state = Entity(vehicle).state.nosData
if state then
    print("NOS system type: " .. tostring(state.system))
    print("Bottle 1 Level: " .. tostring(state.bottles.bottle1) .. "%")
end
```

================================================================================
Thank you for supporting NukepugDesigns! Share your feedback in our community!
================================================================================
