-- ============================================================================
-- Minimizer - CastingBar.lua
-- Cast bars de nameplate: colores, objetivo del hechizo y marcador de corte.
-- ============================================================================

local _, Minimizer = ...
if not Minimizer or not Minimizer.Core then return end

local CastingBar = {}
Minimizer.CastingBar = CastingBar

local COLORS = Minimizer.Constants.CastColors

local function IsSpellTargetingPlayer(unit)
    if UnitIsSpellTarget then
        local targeted = UnitIsSpellTarget(unit, "player")
        return targeted
    end
    local target = unit and (unit .. "target")
    return target and UnitIsUnit(target, "player")
end


local function FindCastBarInGrandchildren(healthBar, ...)
    for i = 1, select("#", ...) do
        local grandchild = select(i, ...)
        if type(grandchild) == "table"
            and grandchild ~= healthBar
            and type(grandchild.SetStatusBarColor) == "function"
            and type(grandchild.GetValue) == "function" then
            return grandchild
        end
    end
    return nil
end

local function FindCastBarInChildren(healthBar, ...)
    for i = 1, select("#", ...) do
        local child = select(i, ...)
        if type(child) == "table" and type(child.GetChildren) == "function" then
            local grandchild = FindCastBarInGrandchildren(healthBar, child:GetChildren())
            if grandchild then return grandchild end
        end
    end
    return nil
end

function CastingBar:GetCastBar(nameplate)
    local unitFrame = nameplate and (nameplate.UnitFrame or nameplate)
    if not unitFrame or type(unitFrame.GetChildren) ~= "function" then return nil end

    local cached = nameplate.MinimizerCastBar
    if cached and type(cached.SetStatusBarColor) == "function"
        and type(cached.GetValue) == "function" then
        return cached
    end

    local healthBar = Minimizer.Utils.GetHealthBar(nameplate)
    local grandchild = FindCastBarInChildren(healthBar, unitFrame:GetChildren())
    if grandchild then
        nameplate.MinimizerCastBar = grandchild
        return grandchild
    end
    return nil
end

function CastingBar:EnsureVisuals(castBar)
    if castBar.MinimizerCastVisuals then return castBar.MinimizerCastVisuals end

    local targetContainer = CreateFrame("Frame", nil, castBar)
    targetContainer:SetAllPoints(castBar)
    targetContainer:SetFrameLevel((castBar:GetFrameLevel() or 0) + 3)
    local border = targetContainer:CreateTexture(nil, "OVERLAY")
    border:SetPoint("TOPLEFT", targetContainer, "TOPLEFT", -3, 3)
    border:SetPoint("BOTTOMRIGHT", targetContainer, "BOTTOMRIGHT", 3, -3)
    border:SetColorTexture(1, 0.05, 0.05, 0.9)
    border:SetBlendMode("ADD")
    targetContainer:Hide()

    local pulse = border:CreateAnimationGroup()
    pulse:SetLooping("REPEAT")
    local fadeOut = pulse:CreateAnimation("Alpha")
    fadeOut:SetOrder(1)
    fadeOut:SetDuration(0.35)
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0.25)
    local fadeIn = pulse:CreateAnimation("Alpha")
    fadeIn:SetOrder(2)
    fadeIn:SetDuration(0.35)
    fadeIn:SetFromAlpha(0.25)
    fadeIn:SetToAlpha(1)

    castBar.MinimizerCastVisuals = {
        targetContainer = targetContainer,
        targetBorder = border,
        targetPulse = pulse,
    }

    if hooksecurefunc and not castBar.MinimizerColorHooked then
        castBar.MinimizerColorHooked = true
        hooksecurefunc(castBar, "SetStatusBarColor", function()
            local bar = castBar
            if bar.MinimizerApplyingColor then return end
            local unit = bar.MinimizerCastUnit
            if unit and UnitExists(unit) then
                local isCasting, _, uninterruptible = Minimizer.Cast.GetState(unit)
                local isChanneling = UnitChannelInfo(unit) ~= nil
                CastingBar:ApplyGreenColor(bar, unit, isCasting, isChanneling, Minimizer.Interrupt.IsReady(), uninterruptible)
            end
        end)
    end
    return castBar.MinimizerCastVisuals
end

function CastingBar:ApplyGreenColor(castBar, unit, isCasting, isChanneling, ready, uninterruptible)
    if not castBar or type(castBar.SetStatusBarColor) ~= "function" then return end
    local r, g, b, a = 1, 1, 1, 1
    if castBar.GetStatusBarColor then
        r, g, b, a = castBar:GetStatusBarColor()
    end
    if isChanneling then
        local cR, cG, cB = Minimizer.Utils.EvaluateColorRGB(ready, COLORS.ready, COLORS.channel)
        r, g, b = Minimizer.Utils.EvaluateColorRGB(uninterruptible, COLORS.channel, {cR, cG, cB})
        a = 1
    elseif isCasting then
        local greenR, greenG, greenB = Minimizer.Utils.EvaluateColorRGB(ready, COLORS.ready, {r, g, b})
        r, g, b = Minimizer.Utils.EvaluateColorRGB(uninterruptible, {r, g, b}, {greenR, greenG, greenB})
    end
    Minimizer.Utils.GuardedCall(castBar, "MinimizerApplyingColor", function()
        castBar:SetStatusBarColor(r, g, b, a or 1)
    end)
end

function CastingBar:UpdateNamePlate(unit, nameplate)
    if not unit or not UnitExists(unit) then return end
    local castBar = self:GetCastBar(nameplate)
    if not castBar or type(castBar.SetStatusBarColor) ~= "function" then return end

    local visuals = self:EnsureVisuals(castBar)
    castBar.MinimizerCastUnit = unit
    local isCasting, _, uninterruptible = Minimizer.Cast.GetState(unit)
    local isChanneling = UnitChannelInfo(unit) ~= nil
    local ready = Minimizer.Interrupt.IsReady()

    self:ApplyGreenColor(castBar, unit, isCasting, isChanneling, ready, uninterruptible)

    local targeted = IsSpellTargetingPlayer(unit)
    if isCasting or isChanneling then
        visuals.targetContainer:Show()
        if visuals.targetContainer.SetAlphaFromBoolean then
            visuals.targetContainer:SetAlphaFromBoolean(targeted)
        end
        visuals.targetPulse:Play()
    else
        visuals.targetPulse:Stop()
        visuals.targetContainer:Hide()
    end
end

function CastingBar:OnNamePlateRemoved(_, nameplate)
    local castBar = nameplate and nameplate.MinimizerCastBar
    if not castBar then return end
    local visuals = castBar.MinimizerCastVisuals
    if visuals then
        visuals.targetPulse:Stop()
        visuals.targetContainer:Hide()
    end
    castBar.MinimizerCastUnit = nil
end

Minimizer.Core.RegisterModule("CastingBar", CastingBar)
