local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

T.fireAddonLoaded()

local parent = CreateFrame("Frame", "TestSpellRendererParent")
local beforeFrames = #Mocks.frames

local renderer = addonTable.SpellRenderer and addonTable.SpellRenderer.Create and addonTable.SpellRenderer.Create(parent)
check(type(renderer) == "table", "SpellRenderer: Create returns a renderer table")
check(type(renderer._frame) == "table", "SpellRenderer: frame created")
check(type(renderer._icon) == "table", "SpellRenderer: icon texture created")

-- Render with provided state (should show and set overlay)
local testSpell = 1001
addonTable.Spells = addonTable.Spells or {}
addonTable.Spells.GetInfo = function(id)
    return { id = id, baseID = id, texture = "TestTexture" }
end
local state = { cooldown = { start = Mocks.time, duration = 10 }, currentCharges = 2, maxCharges = 2, displayCount = nil, isOverlayed = true }
addonTable.Spells.GetState = function(id) return state end

renderer:Render(testSpell, state)
check(renderer._frame:IsShown() == true, "SpellRenderer: Render shows frame")
check(renderer._glow:IsShown() == true, "SpellRenderer: Render with isOverlayed shows glow")

-- Ensure reuse: second render does not create additional frames
local midFrames = #Mocks.frames
local secondSpell = 2002
local state2 = { cooldown = { start = Mocks.time, duration = 5 }, currentCharges = 1, isOverlayed = false }
addonTable.Spells.GetInfo = function(id) return { id = id, baseID = id, texture = "Other" } end
renderer:Render(secondSpell, state2)
local afterFrames = #Mocks.frames
check(afterFrames == midFrames, "SpellRenderer: Render reuse does not create new frames")

-- Clear hides and resets
renderer:Clear()
check(renderer._frame:IsShown() == false, "SpellRenderer: Clear hides frame")
check(renderer._glow:IsShown() == false, "SpellRenderer: Clear hides glow")

-- Hide/Show API
renderer:Show()
check(renderer._frame:IsShown() == true, "SpellRenderer: Show makes frame visible")
renderer:Hide()
check(renderer._frame:IsShown() == false, "SpellRenderer: Hide hides frame")

-- If no state.cooldown provided, ApplyCooldownDuration is used
local applied = false
local origApply = addonTable.Widgets.ApplyCooldownDuration
addonTable.Widgets.ApplyCooldownDuration = function(cd, sid) applied = true; return true end
renderer:Render(testSpell, nil)
check(applied == true, "SpellRenderer: falls back to Widgets.ApplyCooldownDuration when no state.cooldown")
addonTable.Widgets.ApplyCooldownDuration = origApply

T.finish("SPELLRENDERER TESTS")
