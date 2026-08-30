-- tests/smoke_test.lua
-- Smoke/integration only: the behavioral/unit coverage lives in the focused files.
local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

MinimizerDB = {
    simplifyEnabled = true,
    wheelEnabled = false,
    wheelSize = 180,
    wheelPipRadius = 75,
}
MinimizerCharDB = {}

local ok, err = pcall(T.fireAddonLoaded)
check(ok, "Smoke: ADDON_LOADED procesa el addon sin errores" .. (err and (" (" .. tostring(err) .. ")") or ""))
check(type(addonTable.Dispatcher) == "table" and type(addonTable.Overlays) == "table", "Smoke: Dispatcher y Overlays quedan inicializados")

local unit = "nameplate1"
Mocks.CreateTestUnit(unit, {
    name = "Enemy Grunt",
    health = 50,
    healthMax = 100,
    level = 70,
    faction = "Horde",
    isPlayer = false,
    classification = "normal",
    cast = {
        name = "Fireball",
        startTime = Mocks.time * 1000,
        endTime = (Mocks.time + 2) * 1000,
        uninterruptible = false,
    },
})
local np = Mocks.CreateTestNameplate(unit)

ok, err = pcall(Mocks.FireEvent, "NAME_PLATE_UNIT_ADDED", unit)
check(ok, "Smoke: NAME_PLATE_UNIT_ADDED no lanza errores")
check(addonTable.ActiveNameplates[unit] == np, "Smoke: la nameplate entra en ActiveNameplates")

Mocks.AdvanceTime(0.5)
ok, err = pcall(addonTable.Dispatcher.ApplyToAll)
check(ok, "Smoke: Dispatcher.ApplyToAll ejecuta el flujo basico sin errores")

Mocks.AdvanceTime(0.5)
ok, err = pcall(Mocks.FireEvent, "NAME_PLATE_UNIT_REMOVED", unit)
check(ok, "Smoke: NAME_PLATE_UNIT_REMOVED no lanza errores")
check(addonTable.ActiveNameplates[unit] == nil, "Smoke: la nameplate sale de ActiveNameplates")

T.finish("SMOKE TEST RESULTS")
