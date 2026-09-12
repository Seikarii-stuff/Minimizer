local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

T.fireAddonLoaded()

local Spells = addonTable.Spells
check(type(Spells) == "table", "Caches: Spells module exists")

-- Test base spell cache avoids repeated calls
local baseCalls = 0
_G.C_Spell = {
    GetBaseSpell = function(id) baseCalls = baseCalls + 1; return id end,
}
Spells.InvalidateCache()
Spells.GetBaseSpellID(101)
Spells.GetBaseSpellID(101)
check(baseCalls == 1, "_base_spell_cache: GetBaseSpell called once for same id")

-- Invalidate clears base cache
Spells.InvalidateCache()
Spells.GetBaseSpellID(101)
check(baseCalls == 2, "_base_spell_cache: InvalidateCache clears base cache")

-- Test known cache avoids repeated calls
local knownCalls = 0
_G.C_SpellBook = {
    IsSpellKnownOrInSpellBook = function(id) knownCalls = knownCalls + 1; return id == 202 end,
}
Spells.InvalidateCache()
local k1 = Spells.IsKnown(202)
local k2 = Spells.IsKnown(202)
check(knownCalls == 1 and k1 == true and k2 == true, "_known_cache: IsSpellKnown called once and cached")

-- Invalidate clears known cache
Spells.InvalidateCache()
local k3 = Spells.IsKnown(202)
check(knownCalls == 2 and k3 == true, "_known_cache: InvalidateCache clears known cache")

T.finish("SPELLRESOLVER CACHE TESTS")
