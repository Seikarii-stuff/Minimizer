local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

T.fireAddonLoaded()
Mocks.CreateTestUnit("player", {
    name = "Player", level = 70, faction = "Alliance", isPlayer = true,
    class = "HUNTER", classId = 3, guid = "player_guid",
})

Mocks.playerSpells = { [147362] = true, [187707] = false }
addonTable.Interrupt.InvalidateSpellIDCache()
check(addonTable.Interrupt.GetSpellID() == 147362, "Interrupt: resuelve el interrupt conocido de Hunter")

Mocks.playerSpells = { [147362] = false, [187707] = true }
addonTable.Interrupt.InvalidateSpellIDCache()
check(addonTable.Interrupt.GetSpellID() == 187707, "Interrupt: invalida el cache al cambiar de spec")

T.finish("INTERRUPT TESTS")
