local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

T.fireAddonLoaded()

local parent = CreateFrame("Frame", "TestSpellRendererParent")
local renderer = addonTable.SpellRenderer.Create(parent)
local createdFrames = #Mocks.frames
local frame, icon, cooldown, count, glow, flash = renderer._frame, renderer._icon,
    renderer._cooldown, renderer._count, renderer._glow, renderer._flash

check(type(renderer) == "table" and frame ~= nil, "SpellRenderer: Create creates renderer structure")
check(icon ~= nil and cooldown ~= nil and count ~= nil and glow ~= nil and flash ~= nil,
    "SpellRenderer: Create creates icon, cooldown, count and glow once")
check(cooldown.useCircularEdge == true, "SpellRenderer: cooldown uses Widgets circular configuration")

local getStateCalls = 0
addonTable.Spells.GetInfo = function(id)
    return { id = id, baseID = id, texture = "Texture" .. id }
end
addonTable.Spells.GetState = function()
    getStateCalls = getStateCalls + 1
    return nil
end

local firstState = {
    cooldown = { start = Mocks.time, duration = 10 },
    displayCount = 3,
    currentCharges = 2,
    maxCharges = 2,
    isOverlayed = true,
}
renderer:Render(1001, firstState)
check(frame:IsShown() and icon.texture == "Texture1001", "SpellRenderer: Render shows resolver icon")
check(cooldown.cooldownDuration == firstState.cooldown, "SpellRenderer: Render applies provided cooldown state")
check(count.text == "3" and count:IsShown(), "SpellRenderer: display count takes precedence over charges")
check(glow:IsShown() and flash:IsShown(), "SpellRenderer: overlay state enables glow")
check(getStateCalls == 0, "SpellRenderer: Render does not resolve state again")

local previousAlpha = glow:GetAlpha()
renderer:Update(0.2)
check(glow:GetAlpha() ~= previousAlpha, "SpellRenderer: glow pulse mutates existing visual state")

local secondState = { cooldown = { start = Mocks.time, duration = 5 }, currentCharges = 1, maxCharges = 2, isOverlayed = false }
renderer:Render(2002, secondState)
check(#Mocks.frames == createdFrames and renderer._frame == frame and renderer._icon == icon
    and renderer._cooldown == cooldown and renderer._count == count and renderer._glow == glow,
    "SpellRenderer: second Render reuses every visual object")
check(icon.texture == "Texture2002" and count.text == "1", "SpellRenderer: renders charges from resolved state")
check(not glow:IsShown() and not flash:IsShown(), "SpellRenderer: inactive overlay disables glow")

renderer:Clear()
check(not frame:IsShown() and icon.texture == nil and not count:IsShown(), "SpellRenderer: Clear resets and hides spell visuals")
check(cooldown.cleared == true and not cooldown:IsShown(), "SpellRenderer: Clear clears and hides cooldown")

renderer:Show()
check(frame:IsShown(), "SpellRenderer: Show preserves renderer")
renderer:Hide()
check(not frame:IsShown() and #Mocks.frames == createdFrames, "SpellRenderer: Hide does not recreate renderer")

local source = assert(io.open("SpellRenderer.lua", "r")):read("*a")
check(not source:match("C_Spell%.GetBaseSpell") and not source:match("FindSpellActionButtons")
    and not source:match("GetActionDisplayCount") and not source:match("GetSpellCharges")
    and not source:match("GetSpellDisplayCount"), "SpellRenderer: does not duplicate spell resolution")
check(not source:match("function self:Render.-CreateFrame") and not source:match("function self:Update.-CreateFrame"),
    "SpellRenderer: hot path does not create frames")

T.finish("SPELLRENDERER TESTS")
