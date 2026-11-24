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

-- Doble cache: el consumidor y el resolver deben recalcular con estado actualizado.
Mocks.playerSpells = { [147362] = true, [187707] = false }
addonTable.Interrupt.InvalidateSpellIDCache()
check(addonTable.Interrupt.GetSpellID() == 147362, "Interrupt: primera resolución conserva el spell actual")
Mocks.playerSpells = { [147362] = false, [187707] = true }
Mocks.FireEvent("SPELLS_CHANGED")
addonTable.Interrupt.InvalidateSpellIDCache()
check(addonTable.Interrupt.GetSpellID() == 187707, "Interrupt: el cambio de disponibilidad del spell invalida el resolver y el consumidor")

MinimizerDB.interruptMode = "special"
MinimizerDB.interruptSpecialSpellID = 123456
addonTable.Interrupt.InvalidateSpellIDCache()
check(addonTable.Interrupt.GetSpellID() == 123456, "Interrupt: usa el ID especial configurado")

MinimizerDB.interruptMode = "special"
MinimizerDB.interruptSpecialSpellID = nil
addonTable.Interrupt.InvalidateSpellIDCache()
check(addonTable.Interrupt.GetSpellID() == nil, "Interrupt: sin ID especial no devuelve un interrupt")

T.finish("INTERRUPT TESTS")
