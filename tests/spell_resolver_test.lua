local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

T.fireAddonLoaded()

Mocks.playerSpells = {
    [111] = true,
    [222] = true,
    [333] = true,
    [123] = true,
    [456] = true,
    [1719] = true,
    [107574] = true,
    [642] = true,
}

check(type(addonTable.Spells) == "table", "Spells: modulo existe")
check(addonTable.Spells.IsKnown(1719) == true, "Spells: detecta spell conocido via C_SpellBook")
check(addonTable.Spells.IsKnown(999999) == false, "Spells: rechaza spell no conocido")

check(addonTable.Spells.Resolve(12345) == 12345, "Spells: numero aislado se devuelve tal cual")
check(addonTable.Spells.Resolve({111, 222, 333}, 1) == 111, "Spells: slot 1 devuelve el primer spell conocido")
check(addonTable.Spells.Resolve({111, 222, 333}, 2) == 222, "Spells: slot 2 devuelve el segundo spell conocido")
check(addonTable.Spells.Resolve({111, 222, 333}, 3) == 333, "Spells: slot 3 devuelve el tercer spell conocido")

local tableList = {
    { id = 123, name = "Alpha" },
    { id = 456, name = "Beta" },
}
check(addonTable.Spells.Resolve(tableList, 1) == 123, "Spells: acepta entradas {id, name}")

Mocks.playerSpells = {
    [111] = true,
    [222] = false,
    [333] = false,
}
check(addonTable.Spells.Resolve({111, 222, 333}, 2) == 222, "Spells: fallback conserva el entry N original si no hay suficientes conocidos")

Mocks.playerSpells = { [147362] = true, [187707] = false }
local firstResolved = addonTable.Spells.ResolveForClass(addonTable.Data.INTERRUPT_SPELLS, nil, 1, "HUNTER")
check(firstResolved == 147362, "Spells: cache inicial resuelve el spell conocido actual")
Mocks.playerSpells = { [147362] = false, [187707] = true }
addonTable.Spells.InvalidateCache()
local secondResolved = addonTable.Spells.ResolveForClass(addonTable.Data.INTERRUPT_SPELLS, nil, 1, "HUNTER")
check(secondResolved == 187707, "Spells: invalidar cache recalcula cuando cambia el estado del jugador")

Mocks.playerSpells = {
    [107574] = true,
    [1719] = true,
}
local classTable = {
    WARRIOR = {
        { id = 107574, name = "Avatar" },
        { id = 1719, name = "Recklessness" },
    },
}
check(addonTable.Spells.ResolveForClass(classTable, 1719, 1, "WARRIOR") == 1719, "Spells: override valido se respeta")
check(addonTable.Spells.ResolveForClass(classTable, 999999, 1, "WARRIOR") ~= 999999, "Spells: override invalido cae al auto")
check(addonTable.Spells.ResolveForClass(classTable, nil, 1, "WARRIOR") == 107574, "Spells: lista existente por clase resuelve al primer conocido")
check(addonTable.Spells.ResolveForClass({}, nil, 1, "ROGUE") == nil, "Spells: lista inexistente o vacia devuelve nil")

T.finish("SPELL RESOLVER TESTS")
