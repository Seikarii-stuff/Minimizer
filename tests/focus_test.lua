local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

T.fireAddonLoaded()
Mocks.playerSpells = { [147362] = true }
Mocks.cooldowns[147362] = { start = Mocks.time, duration = 15 }
MinimizerDB.enableFocusFace = true

Mocks.CreateTestUnit("focus", { name = "Focus Mob", level = 70, faction = "Horde", guid = "focus_guid" })
Mocks.CreateTestNameplate("focus")
addonTable.Focus:UpdateFace()

check(_G.MinimizerFocusPortrait ~= nil and _G.MinimizerFocusPortrait:IsShown() == true, "Focus: muestra portrait cuando esta habilitado y existe focus")
check(addonTable.Focus.Pips == nil, "Focus: no posee ni consume una coleccion de Pips")
check(addonTable.Overlays.Get("Focus") == addonTable.Focus, "Focus: esta registrado en Overlays")

MinimizerDB.enableFocusFace = false
addonTable.Focus:UpdateFace()
check(_G.MinimizerFocusPortrait:IsShown() == false, "Focus: se oculta cuando face esta deshabilitado")

T.finish("FOCUS TESTS")
