local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

T.fireAddonLoaded()
Mocks.playerSpells = { [107574] = true, [147362] = true }
Mocks.cooldowns[147362] = { start = Mocks.time, duration = 15 }

Mocks.CreateTestUnit("target", { name = "Target Mob", level = 70, faction = "Horde", guid = "target_guid" })
local plate = Mocks.CreateTestNameplate("target")
addonTable.Target:UpdateTargetCDs()

local halo = _G.MinimizerTargetHalo
local countdown = _G.MinimizerTargetInterruptCountdown
check(halo ~= nil and halo:IsShown() == true, "Target: muestra halo cuando el target tiene interrupt")
check(countdown ~= nil and countdown:IsShown() == true, "Target: muestra cooldown del interrupt")
check(addonTable.Target.Pips == nil, "Target: no posee ni consume una coleccion de Pips")
check(addonTable.Overlays.Get("Target") == addonTable.Target, "Target: esta registrado en Overlays")

Mocks.units.target = nil
addonTable.Target:UpdateTargetCDs()
check(halo:IsShown() == false and countdown:IsShown() == false, "Target: oculta indicadores cuando target deja de existir")

T.finish("TARGET TESTS")
