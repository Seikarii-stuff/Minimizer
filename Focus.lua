local _, Minimizer = ...
if not Minimizer then return end

MinimizerDB = MinimizerDB or {}
MinimizerDB.focusIndicator = MinimizerDB.focusIndicator or "face"

local Focus = {}
Minimizer.Focus = Focus
local frame = CreateFrame("Frame", "MinimizerFocusPortrait", UIParent)
frame:SetSize(40, 40)
frame:SetFrameStrata("HIGH")
frame:Hide()
local portrait = frame:CreateTexture(nil, "ARTWORK")
portrait:SetAllPoints()
local cooldown = CreateFrame("Cooldown", "MinimizerFocusCooldown", frame, "CooldownFrameTemplate")
cooldown:SetAllPoints()
cooldown:SetDrawEdge(true)
if cooldown.SetDrawSwipe then cooldown:SetDrawSwipe(true) end
if cooldown.SetDrawBling then cooldown:SetDrawBling(false) end
if cooldown.SetReverse then cooldown:SetReverse(true) end
cooldown:SetSwipeTexture("Interface\\HUD\\UI-HUD-CoolDown-Swipe")

local function UpdateCooldown()
    local interruptSpellID = Minimizer.Interrupt and Minimizer.Interrupt.GetSpellID
        and Minimizer.Interrupt.GetSpellID()
    if not interruptSpellID or not C_Spell then return end
    local duration = C_Spell.GetSpellCooldownDuration
        and C_Spell.GetSpellCooldownDuration(interruptSpellID)
    if duration and cooldown.SetCooldownFromDurationObject then
        cooldown:SetCooldownFromDurationObject(duration)
        if duration.IsZero and cooldown.SetAlphaFromBoolean then
            cooldown:SetAlphaFromBoolean(duration:IsZero(), 0, 1)
        end
    elseif C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(interruptSpellID)
        if info and cooldown.SetCooldownFromExpression then
            cooldown:SetCooldownFromExpression(interruptSpellID)
        elseif info and cooldown.SetCooldownTable then
            cooldown:SetCooldownTable(info)
        end
    end
    if Minimizer.Interrupt and Minimizer.Interrupt.IsReady
        and C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean then
        local ready = Minimizer.Interrupt.IsReady()
        local shade = C_CurveUtil.EvaluateColorValueFromBoolean(ready, 1.0, 0.38)
        portrait:SetVertexColor(shade, shade, shade, 1)
    end
end

function Focus:UpdateFace()
    if MinimizerDB.focusIndicator ~= "face" then frame:Hide(); return end
    if not UnitExists("focus") or UnitIsDead("focus") then frame:Hide(); return end
    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit
        and C_NamePlate.GetNamePlateForUnit("focus")
    if not plate then frame:Hide(); return end
    SetPortraitTexture(portrait, "player")
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOM", plate, "TOP", 0, 10)
    frame:Show()
    UpdateCooldown()
end

function Focus:SetMode(mode)
    if mode ~= "arrows" and mode ~= "face" then return end
    MinimizerDB.focusIndicator = mode
    if mode ~= "face" then frame:Hide() end
    if Minimizer.Core then Minimizer.Core.ApplyToAll() end
end

local driver = CreateFrame("Frame")
local elapsed = 0
driver:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed >= 0.05 then elapsed = 0; Focus:UpdateFace() end
end)
driver:RegisterEvent("PLAYER_FOCUS_CHANGED")
driver:RegisterEvent("NAME_PLATE_UNIT_ADDED")
driver:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
driver:RegisterEvent("SPELL_UPDATE_COOLDOWN")
driver:SetScript("OnEvent", function() Focus:UpdateFace() end)
