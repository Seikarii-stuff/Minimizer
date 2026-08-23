-- tests/friendly_filter_safety_net_test.lua
-- Focused regression tests for the friendly-nameplate pipeline filter and the
-- intentionally disabled Dispatcher safety net.
local Mocks = dofile("tests/wow_mock.lua")

local ADDON_NAME = "Minimizer"
local addonTable = {}

local function LoadAddonFile(filepath)
    local func, err = loadfile(filepath)
    if not func then
        if filepath == "data/SpellData.lua" or filepath == "Data/SpellData.lua" then
            addonTable.Data = addonTable.Data or { INTERRUPT_SPELLS = {} }
            return
        end
        error("Failed to load " .. filepath .. ": " .. tostring(err))
    end
    func(ADDON_NAME, addonTable)
end

local function GetFileListFromToc(tocPath)
    local list = {}
    local fh = assert(io.open(tocPath, "r"), "No se pudo abrir el .toc")
    for line in fh:lines() do
        local trimmed = line:match("^%s*(.-)%s*$")
        trimmed = trimmed:gsub("\\", "/")
        if trimmed ~= "" and not trimmed:match("^#") and trimmed:match("%.lua$") then
            list[#list + 1] = trimmed
        end
    end
    fh:close()
    return list
end

for _, file in ipairs(GetFileListFromToc("Minimizer.toc")) do
    LoadAddonFile(file)
end

Mocks.FireEvent("ADDON_LOADED", ADDON_NAME)

local testsRun = 0
local testsFailed = 0

local function check(condition, description)
    testsRun = testsRun + 1
    if not condition then
        testsFailed = testsFailed + 1
        print("|cffff0000FAIL|r: " .. description)
    else
        print("|cff00ff00OK|r: " .. description)
    end
end

-- --------------------------------------------------------------------------
-- 1. Safety Net is fully disabled: no public starter remains and bootstrap
--    does not schedule a ticker.
-- --------------------------------------------------------------------------
check(addonTable.Dispatcher.StartSafetyNet == nil,
    "Safety Net: Dispatcher no longer exposes StartSafetyNet")
check(#Mocks.timers == 0,
    "Safety Net: ADDON_LOADED does not create a periodic timer")

-- --------------------------------------------------------------------------
-- 2. Friendly player/NPC plates are excluded before ActiveNameplates,
--    Snapshot, Decision, and registered Modules.
-- --------------------------------------------------------------------------
Mocks.units = {}
Mocks.nameplates = {}
Mocks.time = 0

Mocks.CreateTestUnit("player", {
    name = "Player",
    level = 70,
    faction = "Alliance",
    isPlayer = true,
    class = "WARRIOR",
    guid = "player_guid",
})

local snapshotCalls = 0
local moduleCalls = 0
local originalSnapshotBuild = addonTable.Snapshot.Build
local originalUpdateModules = addonTable.Core.UpdateModules
addonTable.Snapshot.Build = function(...)
    snapshotCalls = snapshotCalls + 1
    return originalSnapshotBuild(...)
end
addonTable.Core.UpdateModules = function(...)
    moduleCalls = moduleCalls + 1
    return originalUpdateModules(...)
end

Mocks.CreateTestUnit("nameplate1", {
    name = "Friendly Player",
    level = 70,
    faction = "Alliance",
    isPlayer = true,
    classification = "normal",
})
Mocks.CreateTestNameplate("nameplate1")
Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate1")

check(addonTable.ActiveNameplates["nameplate1"] == nil,
    "Friendly player: no entra en ActiveNameplates")
check(snapshotCalls == 0,
    "Friendly player: no atraviesa Snapshot")
check(moduleCalls == 0,
    "Friendly player: no atraviesa Modules")

Mocks.CreateTestUnit("nameplate2", {
    name = "Friendly NPC",
    level = 70,
    faction = "Alliance",
    isPlayer = false,
    classification = "normal",
})
Mocks.CreateTestNameplate("nameplate2")
Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate2")

check(addonTable.ActiveNameplates["nameplate2"] == nil,
    "Friendly NPC: no entra en ActiveNameplates")
check(snapshotCalls == 0,
    "Friendly NPC: no atraviesa Snapshot")
check(moduleCalls == 0,
    "Friendly NPC: no atraviesa Modules")

-- --------------------------------------------------------------------------
-- 3. Enemy plates, including hostile PvP players, still enter the pipeline.
-- --------------------------------------------------------------------------
Mocks.CreateTestUnit("nameplate3", {
    name = "Enemy",
    level = 70,
    faction = "Horde",
    isPlayer = false,
    classification = "normal",
})
Mocks.CreateTestNameplate("nameplate3")
Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate3")

check(addonTable.ActiveNameplates["nameplate3"] ~= nil,
    "Enemy: sigue entrando en ActiveNameplates")
check(snapshotCalls > 0,
    "Enemy: sigue atravesando Snapshot")
check(moduleCalls > 0,
    "Enemy: sigue atravesando Modules")

Mocks.CreateTestUnit("nameplate6", {
    name = "Enemy Player",
    level = 70,
    faction = "Horde",
    isPlayer = true,
    classification = "normal",
})
Mocks.CreateTestNameplate("nameplate6")
Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate6")

check(addonTable.ActiveNameplates["nameplate6"] ~= nil,
    "PvP enemigo: sigue entrando en ActiveNameplates")
check(snapshotCalls > 1,
    "PvP enemigo: sigue atravesando Snapshot")
check(moduleCalls > 1,
    "PvP enemigo: sigue atravesando Modules")

-- --------------------------------------------------------------------------
-- 4. Target/Focus overlays remain event-driven even when their friendly plate
--    is excluded from the normal pipeline.
-- --------------------------------------------------------------------------
local originalOnUnitChanged = addonTable.Overlays.OnUnitChanged
local overlayEvents = {}
addonTable.Overlays.OnUnitChanged = function(unit, reason)
    overlayEvents[#overlayEvents + 1] = { unit = unit, reason = reason }
    return originalOnUnitChanged(unit, reason)
end

Mocks.CreateTestUnit("nameplate4", {
    name = "Friendly Target",
    level = 70,
    faction = "Alliance",
    isPlayer = false,
    classification = "normal",
    guid = "friendly_target_guid",
})
Mocks.CreateTestUnit("target", {
    name = "Friendly Target",
    level = 70,
    faction = "Alliance",
    isPlayer = false,
    guid = "friendly_target_guid",
})
Mocks.CreateTestNameplate("nameplate4")
Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate4")
Mocks.FireEvent("PLAYER_TARGET_CHANGED")
Mocks.FireEvent("NAME_PLATE_UNIT_REMOVED", "nameplate4")

check(addonTable.ActiveNameplates["nameplate4"] == nil,
    "Friendly target: permanece fuera de ActiveNameplates")
check(overlayEvents[1] and overlayEvents[1].reason == "added",
    "Target overlay: recibe el evento de alta de la placa friendly")
check(overlayEvents[2] and overlayEvents[2].reason == "target",
    "Target overlay: recibe PLAYER_TARGET_CHANGED")
check(overlayEvents[#overlayEvents] and overlayEvents[#overlayEvents].reason == "removed",
    "Target overlay: recibe la limpieza al retirar la placa friendly")

Mocks.CreateTestUnit("nameplate5", {
    name = "Friendly Focus",
    level = 70,
    faction = "Alliance",
    isPlayer = false,
    classification = "normal",
    guid = "friendly_focus_guid",
})
Mocks.CreateTestUnit("focus", {
    name = "Friendly Focus",
    level = 70,
    faction = "Alliance",
    isPlayer = false,
    guid = "friendly_focus_guid",
})
Mocks.CreateTestNameplate("nameplate5")
Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate5")
Mocks.FireEvent("PLAYER_FOCUS_CHANGED")
Mocks.FireEvent("NAME_PLATE_UNIT_REMOVED", "nameplate5")

check(addonTable.ActiveNameplates["nameplate5"] == nil,
    "Friendly focus: permanece fuera de ActiveNameplates")
check(overlayEvents[4] and overlayEvents[4].reason == "added",
    "Focus overlay: recibe el evento de alta de la placa friendly")
check(overlayEvents[5] and overlayEvents[5].reason == "focus",
    "Focus overlay: recibe PLAYER_FOCUS_CHANGED")
check(overlayEvents[#overlayEvents] and overlayEvents[#overlayEvents].reason == "removed",
    "Focus overlay: recibe la limpieza al retirar la placa friendly")

print(string.format("\nFriendly filter / safety net tests: %d run, %d failed", testsRun, testsFailed))
if testsFailed > 0 then
    error(string.format("%d test(s) failed", testsFailed))
end
