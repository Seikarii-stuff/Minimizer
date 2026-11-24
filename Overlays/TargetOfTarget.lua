local _, Minimizer = ...
if not Minimizer then return end

local TargetOfTarget = {}
Minimizer.TargetOfTarget = TargetOfTarget

local HALO_SIZE = 46
local frame = CreateFrame("Frame", "MinimizerTargetOfTargetPortrait", UIParent)
frame:SetSize(36, 36)
frame:Hide()

local portrait = frame:CreateTexture(nil, "ARTWORK")
portrait:SetAllPoints()

local function HidePortrait()
    frame:Hide()
    frame:ClearAllPoints()
    frame:SetParent(UIParent)
end

function TargetOfTarget:UpdatePortrait()
    if MinimizerDB and MinimizerDB.enableTargetOfTargetFace == false then
        HidePortrait()
        return
    end

    if not UnitExists("target") then
        HidePortrait()
        return
    end

    if not UnitExists("targettarget") then
        HidePortrait()
        return
    end

    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit
        and C_NamePlate.GetNamePlateForUnit("target")
    if not plate then
        HidePortrait()
        return
    end

    SetPortraitTexture(portrait, "targettarget")
    frame:ClearAllPoints()
    frame:SetParent(plate)
    frame:SetPoint("CENTER", plate, "BOTTOM", 0, 10 + (HALO_SIZE / 2))
    local plateLevel = (plate:GetFrameLevel() or 0)
    -- Focus.lua uses plateLevel + 1. Target-of-target stays on top, while
    -- the yellow focus glow remains visible outside the portrait bounds.
    frame:SetFrameLevel(plateLevel + 2)
    frame:Show()
end

TargetOfTarget.DebouncedUpdate = Minimizer.Utils.Throttle(function()
    TargetOfTarget:UpdatePortrait()
end, 0.033)

function TargetOfTarget:OnCooldownTick()
    TargetOfTarget.DebouncedUpdate()
end

function TargetOfTarget:OnUnitChanged(unit, reason)
    if reason == "target" or reason == "focus" or reason == "targettarget"
        or reason == "added" or reason == "removed" or reason == "targetchanged" then
        TargetOfTarget:UpdatePortrait()
    end
end

if Minimizer.Overlays and Minimizer.Overlays.Register then
    Minimizer.Overlays.Register("TargetOfTarget", TargetOfTarget)
end
