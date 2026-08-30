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

check(addonTable.Utils.IsSpellKnownByPlayer(1719) == true, "Utils: detecta spell conocido")
check(addonTable.Utils.IsSpellKnownByPlayer(999999) == false, "Utils: rechaza spell desconocido")

local validOverride = addonTable.Widgets.GetCDSpellID(addonTable.Data.OFFENSIVE_CDS, 1719)
check(validOverride == 1719, "Widgets: usa override conocido cuando es valido")

local invalidOverride = addonTable.Widgets.GetCDSpellID(addonTable.Data.OFFENSIVE_CDS, 999999)
check(invalidOverride ~= 999999 and invalidOverride ~= nil, "Widgets: override desconocido cae a auto")

local wrongClassOverride = addonTable.Widgets.GetCDSpellID(addonTable.Data.DEFENSIVE_CDS, 1719)
check(wrongClassOverride ~= 1719, "Widgets: override fuera de la lista de clase cae a auto")

local first = addonTable.Widgets.GetCDSpellID(addonTable.Data.OFFENSIVE_CDS, 1719)
local second = addonTable.Widgets.GetCDSpellID(addonTable.Data.OFFENSIVE_CDS, 1719)
check(first == 1719 and second == 1719, "Widgets: cache de override estable")

T.finish("UTILS TESTS")
