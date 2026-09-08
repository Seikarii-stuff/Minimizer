local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

T.fireAddonLoaded()
Mocks.playerSpells = {
    [1719] = true,
    [167105] = true,
    [107574] = true,
    [642] = true,
    [8122] = true,
}

check(type(addonTable.Spells) == "table", "Spells: modulo existe")
check(addonTable.Spells.IsKnown(1719) == true, "Spells: detecta spell conocido")
check(addonTable.Spells.IsKnown(999999) == false, "Spells: rechaza spell desconocido")

local _, classToken = UnitClass("player")
local validOverride = addonTable.Spells.ResolveForClass(addonTable.Data.OFFENSIVE_CDS, 1719, 1, classToken)
check(validOverride == 1719, "Spells: usa override conocido cuando es valido")

local invalidOverride = addonTable.Spells.ResolveForClass(addonTable.Data.OFFENSIVE_CDS, 999999, 1, classToken)
check(invalidOverride ~= 999999 and invalidOverride ~= nil, "Spells: override desconocido cae a auto")

local wrongClassOverride = addonTable.Spells.ResolveForClass(addonTable.Data.DEFENSIVE_CDS, 1719, 1, classToken)
check(wrongClassOverride ~= 1719, "Spells: override fuera de la lista de clase cae a auto")

local first = addonTable.Spells.ResolveForClass(addonTable.Data.OFFENSIVE_CDS, 1719, 1, classToken)
local second = addonTable.Spells.ResolveForClass(addonTable.Data.OFFENSIVE_CDS, 1719, 1, classToken)
check(first == 1719 and second == 1719, "Spells: cache de override estable")

T.finish("SPELL RESOLVER TESTS")
