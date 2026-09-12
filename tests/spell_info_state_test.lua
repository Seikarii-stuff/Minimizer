local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

T.fireAddonLoaded()

local Spells = addonTable.Spells
check(type(Spells) == "table", "SpellInfo: Spells module exists")
check(type(Spells.GetInfo) == "function", "SpellInfo: GetInfo exists")
check(type(Spells.GetState) == "function", "SpellInfo: GetState exists")

-- Base spell resolution: modern API
-- Modern C_Spell provides base and iconID
_G.C_Spell = {
    GetBaseSpell = function(id) return 999 end,
    GetSpellInfo = function(id) return { iconID = "modernIcon" } end,
}
local info = Spells.GetInfo(123)
check(info and info.id == 123, "GetInfo: returns id")
check(info.baseID == 999, "GetInfo: uses C_Spell.GetBaseSpell when available")
check(info.texture == "modernIcon", "GetInfo: uses C_Spell.GetSpellInfo().iconID for texture")

-- Action button mapping and action display count
_G.C_ActionBar = {
    FindSpellActionButtons = function(baseID) return { 42 } end,
    GetActionDisplayCount = function(actionID) if actionID == 42 then return 7 end end,
}
-- ensure modern C_Spell base resolver returns base equal to input
_G.C_Spell = { GetBaseSpell = function(id) return id end }
Spells.InvalidateCache()
local info3 = Spells.GetInfo(321)
check(info3.actionID == 42, "GetInfo: resolves actionID via C_ActionBar.FindSpellActionButtons")
local state = Spells.GetState(321)
check(state.displayCount == 7, "GetState: reads displayCount from action bar when available")

-- Absence of action button
_G.C_ActionBar = nil
Spells.InvalidateCache()
local info4 = Spells.GetInfo(400)
check(info4.actionID == nil, "GetInfo: nil actionID when no action buttons exist")

-- Charges fallback
_G.C_Spell = {
    GetBaseSpell = function(id) return id end,
    GetSpellCharges = function(id) return { currentCharges = 2, maxCharges = 3 } end,
}
Spells.InvalidateCache()
local st2 = Spells.GetState(500)
check(st2.currentCharges == 2 and st2.maxCharges == 3, "GetState: reads charges from C_Spell.GetSpellCharges")

-- Coexistence: displayCount from action bar and charges from C_Spell
_G.C_ActionBar = {
    FindSpellActionButtons = function(baseID) return { 77 } end,
    GetActionDisplayCount = function(actionID) if actionID == 77 then return 2 end end,
}
_G.C_Spell = {
    GetBaseSpell = function(id) return id end,
    GetSpellCharges = function(id) return { currentCharges = 2, maxCharges = 3 } end,
}
Spells.InvalidateCache()
local st_coexist = Spells.GetState(910)
check(st_coexist.displayCount == 2 and st_coexist.currentCharges == 2 and st_coexist.maxCharges == 3,
    "GetState: preserves displayCount and charges when both are available")

-- Display count fallback
_G.C_ActionBar = nil
_G.C_Spell = {
    GetBaseSpell = function(id) return id end,
    GetSpellDisplayCount = function(id) return 4 end,
}
Spells.InvalidateCache()
local st3 = Spells.GetState(600)
check(st3.displayCount == 4, "GetState: falls back to C_Spell.GetSpellDisplayCount when no action count and no charges")

-- Cooldown and overlay
print("DEBUG displayCount for 600:", st3.displayCount)
check(st3.displayCount == 4, "GetState: falls back to C_Spell.GetSpellDisplayCount when no action count and no charges")
_G.C_Spell = {
    GetBaseSpell = function(id) return id end,
    GetSpellCooldownDuration = function(id) return { IsZero = function() return false end } end,
}
_G.C_SpellActivationOverlay = { IsSpellOverlayed = function(id) return true end }
local st4 = Spells.GetState(700)
check(st4.cooldown ~= nil, "GetState: returns cooldown when modern API present")
check(st4.isOverlayed == true, "GetState: returns overlay state from C_SpellActivationOverlay")

-- Cooldown fallback to C_Spell.GetSpellCooldown
_G.C_Spell = {
    GetBaseSpell = function(id) return id end,
    GetSpellCooldown = function(id) return { start = 1, duration = 5 } end,
}
_G.C_SpellActivationOverlay = { IsSpellOverlayed = function(id) return false end }
local st_cd2 = Spells.GetState(701)
check(type(st_cd2.cooldown) == "table", "GetState: reads cooldown from C_Spell.GetSpellCooldown fallback")
check(st_cd2.isOverlayed == false, "GetState: overlay false is handled")

-- Legacy fallback to global GetSpellCooldown
_G.C_Spell = nil
_G.GetSpellCooldown = function(id) return 2, 10 end
local st_cd3 = Spells.GetState(702)
check(type(st_cd3.cooldown) == "table" and st_cd3.cooldown.duration == 10, "GetState: reads cooldown from legacy GetSpellCooldown")

-- Absent overlay API should be safe
_G.C_SpellActivationOverlay = nil
local st_overlay_none = Spells.GetState(703)
check(st_overlay_none.isOverlayed == false, "GetState: absent overlay API is safe and false")

-- Cache invalidation: action button cache should update after InvalidateCache
_G.C_ActionBar = { FindSpellActionButtons = function() return { 1 } end }
_G.C_Spell = { GetBaseSpell = function(id) return id end }
Spells.InvalidateCache()
local before = Spells.GetInfo(800).actionID
_G.C_ActionBar = { FindSpellActionButtons = function() return { 2 } end }
Spells.InvalidateCache()
local after = Spells.GetInfo(800).actionID
check(before ~= after and after == 2, "InvalidateCache: action button cache invalidated and refreshed")

T.finish("SPELL INFO/STATE TESTS")

