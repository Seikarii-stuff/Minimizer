local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

T.fireAddonLoaded()

local Spells = addonTable.Spells
check(type(Spells) == "table", "Spells: modulo existe")

-- Case A: [A known, B known]
Mocks.playerSpells = { [101] = true, [202] = true }
check(Spells.Resolve({101, 202}, 1) == 101, "Resolve: slot 1 chooses first known spell")
check(Spells.Resolve({101, 202}, 2) == 202, "Resolve: slot 2 chooses second known spell")

-- Case B: [A unknown, B known, C known]
Mocks.playerSpells = { [101] = false, [202] = true, [303] = true }
Spells.InvalidateCache("known")
check(Spells.Resolve({101, 202, 303}, 1) == 202, "Resolve: skips unknown entries and selects first known")
check(Spells.Resolve({101, 202, 303}, 2) == 303, "Resolve: slot 2 resolves to next known spell")

-- Case C: all unknown
Mocks.playerSpells = { [404] = false, [505] = false }
Spells.InvalidateCache("known")
check(Spells.Resolve({404, 505}, 1) == 404, "Resolve: fallback preserves original first entry when all spells are unknown")

-- Case D: numeric input
check(Spells.Resolve(12345) == 12345, "Resolve: numeric input is returned unchanged")

-- Case E: invalid input
check(Spells.Resolve(nil) == nil, "Resolve: invalid input returns nil")

-- Case F: normalized table entries
local tableList = { { id = 123, name = "Alpha" }, { id = 456, name = "Beta" } }
check(Spells.Resolve(tableList, 1) == 123, "Resolve: table entries are normalized via id")

-- Case G: no knownList allocation in the hot path (behavioral check)
Mocks.playerSpells = { [101] = false, [202] = true, [303] = true }
Spells.InvalidateCache("known")
local lookupBefore = Spells.Resolve({101, 202, 303}, 1)
check(lookupBefore == 202, "Resolve: hot path resolves without building a legacy knownList")

-- Known-state change invalidates ResolveForClass resolution
Mocks.playerSpells = { [147362] = true, [187707] = false }
local firstResolved = Spells.ResolveForClass(addonTable.Data.INTERRUPT_SPELLS, nil, 1, "HUNTER")
check(firstResolved == 147362, "ResolveForClass: initial known-state resolution")
Mocks.playerSpells = { [147362] = false, [187707] = true }
Spells.InvalidateCache("known")
local secondResolved = Spells.ResolveForClass(addonTable.Data.INTERRUPT_SPELLS, nil, 1, "HUNTER")
check(secondResolved == 187707, "ResolveForClass: known-state invalidation recalculates stale resolution")

-- ResolveForClass: override and class validation
Mocks.playerSpells = { [107574] = true, [1719] = true }
local classTable = {
    WARRIOR = {
        { id = 107574, name = "Avatar" },
        { id = 1719, name = "Recklessness" },
    },
}
check(Spells.ResolveForClass(classTable, 1719, 1, "WARRIOR") == 1719, "ResolveForClass: valid override is respected")
check(Spells.ResolveForClass(classTable, 999999, 1, "WARRIOR") ~= 999999, "ResolveForClass: invalid override falls back to auto selection")
check(Spells.ResolveForClass(classTable, nil, 1, "WARRIOR") == 107574, "ResolveForClass: class table resolves first known spell")
check(Spells.ResolveForClass({}, nil, 1, "ROGUE") == nil, "ResolveForClass: empty/unknown class list returns nil")

-- ResolveForClass: lookup cache keeps the same table without full rebuilds on repeated calls
local lookupCalls = 0
local lookupTable = { 1001, 1002, 1003 }
local originalLookup = _G.C_SpellBook.IsSpellKnownOrInSpellBook
_G.C_SpellBook.IsSpellKnownOrInSpellBook = function(id)
    lookupCalls = lookupCalls + 1
    return id == 1001 or id == 1002
end
Spells.InvalidateCache()
local firstLookup = Spells.ResolveForClass({ HUNTER = lookupTable }, nil, 1, "HUNTER")
local secondLookup = Spells.ResolveForClass({ HUNTER = lookupTable }, nil, 1, "HUNTER")
check(firstLookup == 1001 and secondLookup == 1001 and lookupCalls == 1,
    "ResolveForClass: repeated lookups reuse cached known-state resolution without rechecking IsKnown")
_G.C_SpellBook.IsSpellKnownOrInSpellBook = originalLookup

T.finish("SPELL RESOLVER TESTS")
