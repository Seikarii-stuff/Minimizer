local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

T.fireAddonLoaded()

local Spells = addonTable.Spells
check(type(Spells) == "table", "Caches: Spells module exists")

local function ResetModernSpellAPIs()
    _G.C_Spell = {
        GetBaseSpell = function(id) return id end,
        GetSpellInfo = function(id) return nil end,
        GetSpellCooldownDuration = function(id) return nil end,
        GetSpellCharges = function(id) return nil end,
        GetSpellDisplayCount = function(id) return nil end,
    }
    _G.C_ActionBar = {
        FindSpellActionButtons = function(baseID) return nil end,
        GetActionDisplayCount = function(actionID) return nil end,
    }
    _G.C_SpellActivationOverlay = {
        IsSpellOverlayed = function(id) return false end,
    }
    _G.C_SpellBook = {
        IsSpellKnownOrInSpellBook = function(id) return false end,
    }
end

ResetModernSpellAPIs()
Spells.InvalidateCache()

-- Base spell cache: call count and invalidation
local baseCalls = 0
_G.C_Spell.GetBaseSpell = function(id)
    baseCalls = baseCalls + 1
    return id
end
Spells.GetBaseSpellID(101)
Spells.GetBaseSpellID(101)
check(baseCalls == 1, "_base_spell_cache: GetBaseSpell called once for same id")

Spells.InvalidateCache()
Spells.GetBaseSpellID(101)
check(baseCalls == 2, "_base_spell_cache: InvalidateCache clears base cache")

-- Known cache: call count and invalidation on SPELLS_CHANGED
local knownCalls = 0
_G.C_SpellBook.IsSpellKnownOrInSpellBook = function(id)
    if id == 202 then
        knownCalls = knownCalls + 1
    end
    return Mocks.playerSpells and Mocks.playerSpells[id] == true
end
Mocks.playerSpells = { [202] = true }
Spells.InvalidateCache()
local k1 = Spells.IsKnown(202)
local k2 = Spells.IsKnown(202)
check(knownCalls == 1 and k1 == true and k2 == true, "_known_cache: IsSpellKnown called once and cached")

Mocks.playerSpells = { [202] = false }
Mocks.FireEvent("SPELLS_CHANGED")
local k3 = Spells.IsKnown(202)
check(knownCalls == 2 and k3 == false, "_known_cache: SPELLS_CHANGED invalidates known cache")

-- Resolution cache is invalidated when known state changes.
local resolutionCalls = 0
_G.C_SpellBook.IsSpellKnownOrInSpellBook = function(id)
    if id == 100 or id == 200 then
        resolutionCalls = resolutionCalls + 1
    end
    return Mocks.playerSpells and Mocks.playerSpells[id] == true
end
Mocks.playerSpells = { [100] = true, [200] = false }
local classTable = {
    HUNTER = { 100, 200 },
}
local resolvedBefore = Spells.ResolveForClass(classTable, nil, 1, "HUNTER")
local resolvedBeforeCached = Spells.ResolveForClass(classTable, nil, 1, "HUNTER")
check(resolutionCalls == 1 and resolvedBefore == 100 and resolvedBeforeCached == 100,
    "_resolution_cache: first resolution checks IsKnown and the second reuses the cached result")

Mocks.playerSpells = { [100] = false, [200] = true }
Mocks.FireEvent("PLAYER_SPECIALIZATION_CHANGED")
local resolvedAfter = Spells.ResolveForClass(classTable, nil, 1, "HUNTER")
check(resolutionCalls == 3 and resolvedAfter == 200,
    "_resolution_cache: PLAYER_SPECIALIZATION_CHANGED revalidates known-dependent resolution")

-- Talent/loadout style invalidation path on the existing event manager.
local talentCalls = 0
_G.C_SpellBook.IsSpellKnownOrInSpellBook = function(id)
    if id == 300 or id == 301 then
        talentCalls = talentCalls + 1
    end
    return Mocks.playerSpells and Mocks.playerSpells[id] == true
end
Mocks.playerSpells = { [300] = true, [301] = false }
local talentTable = { HUNTER = { 300, 301 } }
local talentBefore = Spells.ResolveForClass(talentTable, nil, 1, "HUNTER")
local talentBeforeCached = Spells.ResolveForClass(talentTable, nil, 1, "HUNTER")
check(talentCalls == 1 and talentBefore == 300 and talentBeforeCached == 300,
    "_resolution_cache: initial talent loadout resolves from current known state and then caches it")

Mocks.playerSpells = { [300] = false, [301] = true }
Mocks.FireEvent("ACTIVE_TALENT_GROUP_CHANGED")
local talentAfter = Spells.ResolveForClass(talentTable, nil, 1, "HUNTER")
check(talentCalls == 3 and talentAfter == 301,
    "_resolution_cache: ACTIVE_TALENT_GROUP_CHANGED refreshes known-dependent resolution")

T.finish("SPELLRESOLVER CACHE TESTS")
