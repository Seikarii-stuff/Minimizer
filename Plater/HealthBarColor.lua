local _, Minimizer = ...
if not Minimizer or not Minimizer.Core then return end

local HealthBarColor = {}
Minimizer.HealthBarColor = HealthBarColor

local COLORS = Minimizer.Constants.HealthColors

local UnitExists = UnitExists
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
local UnitHealthMax = UnitHealthMax
local UnitCanAttack = UnitCanAttack
local type = type

local OVERSHIELD_ALPHA = 1

local function EnsureOvershieldBar(healthBar)
    local bar = healthBar.MinimizerOvershieldBar
    if bar then return bar end
    bar = CreateFrame("StatusBar", nil, healthBar)
    bar:SetAllPoints(healthBar)
    bar:SetFrameLevel((healthBar:GetFrameLevel() or 0) + 1)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetStatusBarColor(1, 1, 1, OVERSHIELD_ALPHA)
    bar:SetOrientation("HORIZONTAL")
    bar:SetReverseFill(true)
    if type(bar.EnableMouse) == "function" then bar:EnableMouse(false) end
    bar:Hide()
    healthBar.MinimizerOvershieldBar = bar
    return bar
end

local function UpdateOvershieldBar(bar, absorb, maxHealth)
    local absorbIsSecret = Minimizer.Utils.IsSecretValue(absorb)
    local maxHealthIsSecret = Minimizer.Utils.IsSecretValue(maxHealth)
    if not absorbIsSecret and not maxHealthIsSecret then
        if bar:IsShown() and bar.MinimizerLastAbsorb == absorb and bar.MinimizerLastMaxHealth == maxHealth then return end
        bar.MinimizerLastAbsorb = absorb
        bar.MinimizerLastMaxHealth = maxHealth
    else
        bar.MinimizerLastAbsorb = nil
        bar.MinimizerLastMaxHealth = nil
    end
    bar:SetMinMaxValues(0, maxHealth)
    bar:SetValue(absorb)
    bar:Show()
end

function HealthBarColor:GetHealthBar(nameplate)
    return Minimizer.Utils.GetHealthBar(nameplate)
end

local HookHealthBar
local HookIndicator

local function LetBlizzardPaint(_, nameplate)
    nameplate.MinimizerLastAppliedColor = nil
    nameplate.MinimizerHealthBarColorKind = nil
    nameplate.MinimizerPersistentCastColor = nil
end

local function ShouldLetBlizzardPaint(unit, snapshot)
    if Minimizer.Decision and Minimizer.Decision.ShouldLetBlizzardPaint then
        return Minimizer.Decision.ShouldLetBlizzardPaint(unit, snapshot)
    end
    return false
end

local function GetSafeHealthColor(kind)
    if kind == "trivial" then return COLORS.trivial end
    if kind == "melee" then return COLORS.melee end
    if kind == "caster" then return COLORS.caster end
    if kind == "boss" then return COLORS.boss end
    if kind == "miniboss" then return COLORS.miniboss end
    if kind == "focus" then return COLORS.focus end
    if kind == "absorb" then return COLORS.absorb end
    if kind == "aggro" then return COLORS.aggro end
    if kind == "priority" then return COLORS.priority end
    return COLORS.melee
end

function HealthBarColor:UpdateNamePlate(unit, nameplate, snapshot)
    if not unit or not UnitExists(unit) then return end
    local isPvP = snapshot and snapshot.isPvP
    if isPvP == nil then isPvP = Minimizer.Utils.IsPvPUnit(unit) end
    if isPvP then return end
    local isFriendly = snapshot and snapshot.isFriendly
    if isFriendly == nil then
        isFriendly = (Minimizer.Utils and Minimizer.Utils.IsFriendlyUnit and Minimizer.Utils.IsFriendlyUnit(unit))
            or (UnitCanAttack and not UnitCanAttack("player", unit))
    end
    if isFriendly then return end

    local healthBar = self:GetHealthBar(nameplate)
    if not healthBar or type(healthBar.SetStatusBarColor) ~= "function" then return end

    if ShouldLetBlizzardPaint(unit, snapshot) then
        LetBlizzardPaint(healthBar, nameplate)
        return
    end

    HookHealthBar(healthBar)
    local indicator = healthBar.totalAbsorbOverlay or healthBar.totalAbsorb
    if indicator then HookIndicator(indicator, healthBar) end

    local isStale
    if Minimizer.Lifecycle and Minimizer.Lifecycle.IsGenerationStale then
        isStale = Minimizer.Lifecycle.IsGenerationStale(unit, nameplate.MinimizerHealthBarColorGen)
            or (nameplate.MinimizerHealthBarColorUnit ~= unit)
    else
        local currentGen = Minimizer.Core and Minimizer.Core.GetPlateGeneration and Minimizer.Core.GetPlateGeneration(unit) or 0
        isStale = (nameplate.MinimizerHealthBarColorGen ~= currentGen or nameplate.MinimizerHealthBarColorUnit ~= unit)
    end
    if isStale then
        local currentGen = (Minimizer.Lifecycle and Minimizer.Lifecycle.GetGeneration and Minimizer.Lifecycle.GetGeneration(unit))
            or (Minimizer.Core and Minimizer.Core.GetPlateGeneration and Minimizer.Core.GetPlateGeneration(unit)) or 0
        nameplate.MinimizerHealthBarColorUnit = unit
        nameplate.MinimizerHealthBarColorGen = currentGen
        nameplate.MinimizerPersistentCastColor = nil
    end

    local baseKind
    if snapshot then
        baseKind = snapshot.displayKind
    else
        baseKind = Minimizer.Core and Minimizer.Core.ComputeDisplayKind and Minimizer.Core.ComputeDisplayKind(unit, nameplate) or Minimizer.Classification.GetEliteType(unit)
    end

    nameplate.MinimizerHasAbsorb = baseKind == "absorb"
    local color = GetSafeHealthColor(baseKind)
    local r, g, b = color[1], color[2], color[3]

    local isCasting, isChanneling, safeUninterruptible, rawUninterruptible
    if snapshot then
        isCasting = snapshot.isCasting
        isChanneling = snapshot.isChanneling
        safeUninterruptible = snapshot.isUninterruptible
        rawUninterruptible = snapshot.rawUninterruptible
    else
        isCasting, safeUninterruptible, rawUninterruptible, isChanneling = Minimizer.Cast.GetState(unit)
    end
    local isActiveCastOrChannel = isCasting == true or isChanneling == true

    local hasHadAbsorb = snapshot and snapshot.hasHadAbsorb
    if hasHadAbsorb == nil then
        local liveAbsorb = snapshot and snapshot.hasAbsorb
        if liveAbsorb == nil then liveAbsorb = Minimizer.Absorb and Minimizer.Absorb.HasAbsorb and Minimizer.Absorb.HasAbsorb(unit, nameplate) end
        hasHadAbsorb = (Minimizer.Absorb and Minimizer.Absorb.MarkSeen and Minimizer.Absorb.MarkSeen(unit, nameplate, liveAbsorb))
            or (Minimizer.Core and Minimizer.Core.MarkAbsorbSeen and Minimizer.Core.MarkAbsorbSeen(unit, nameplate, liveAbsorb))
            or false
    end

    if hasHadAbsorb then
        local hasAbsorbNow = snapshot and snapshot.hasAbsorb
        if hasAbsorbNow == nil then hasAbsorbNow = Minimizer.Absorb and Minimizer.Absorb.HasAbsorb and Minimizer.Absorb.HasAbsorb(unit, nameplate) end
        local overshieldBar = EnsureOvershieldBar(healthBar)
        if hasAbsorbNow and Minimizer.Absorb and Minimizer.Absorb.GetTotalAbsorbs then
            UpdateOvershieldBar(overshieldBar, Minimizer.Absorb.GetTotalAbsorbs(unit), UnitHealthMax(unit))
        elseif overshieldBar:IsShown() then
            overshieldBar:Hide()
        end
    elseif healthBar.MinimizerOvershieldBar then
        healthBar.MinimizerOvershieldBar:Hide()
    end

    local eliteType = (snapshot and snapshot.eliteType) or Minimizer.Classification.GetEliteType(unit)
    local isSuperior = eliteType == "boss" or eliteType == "miniboss"
    local isCasterClass = eliteType == "caster"
    local isSpecial = baseKind == "focus" or baseKind == "aggro" or baseKind == "priority" or isCasterClass

    if not isSpecial and not isSuperior then
        if isActiveCastOrChannel then
            if safeUninterruptible == true then
                r, g, b = COLORS.superiorUninterruptible[1], COLORS.superiorUninterruptible[2], COLORS.superiorUninterruptible[3]
            else
                r, g, b = Minimizer.Utils.EvaluateColorRGB(rawUninterruptible, COLORS.superiorUninterruptible, COLORS.castInterruptible)
            end
            nameplate.MinimizerPersistentCastColor = nameplate.MinimizerPersistentCastColor or {}
            local p = nameplate.MinimizerPersistentCastColor
            p[1], p[2], p[3] = r, g, b
        elseif nameplate.MinimizerPersistentCastColor then
            local p = nameplate.MinimizerPersistentCastColor
            r, g, b = p[1], p[2], p[3]
        end
    end

    nameplate.MinimizerLastAppliedColor = nameplate.MinimizerLastAppliedColor or {}
    local lc = nameplate.MinimizerLastAppliedColor
    lc[1], lc[2], lc[3] = r, g, b

    Minimizer.Utils.GuardedCall(healthBar, "MinimizerHealthColorApplying", function()
        healthBar:SetStatusBarColor(r, g, b)
    end)
    nameplate.MinimizerHealthBarColorKind = baseKind
end

HookHealthBar = function(healthBar)
    if not healthBar or healthBar.MinimizerHealthColorHooked then return end
    if Minimizer.Utils and Minimizer.Utils.HookRepaintGuard then
        Minimizer.Utils.HookRepaintGuard(healthBar, "MinimizerHealthColorHooked", "MinimizerHealthColorApplying", function()
            local nameplate = Minimizer.Utils.GetNameplateFromHealthBar(healthBar)
            local lastColor = nameplate and nameplate.MinimizerLastAppliedColor
            if lastColor then
                Minimizer.Utils.GuardedCall(healthBar, "MinimizerHealthColorApplying", function()
                    healthBar:SetStatusBarColor(lastColor[1], lastColor[2], lastColor[3])
                end)
            end
        end)
    else
        healthBar.MinimizerHealthColorHooked = true
        if hooksecurefunc then
            hooksecurefunc(healthBar, "SetStatusBarColor", function()
                if healthBar.MinimizerHealthColorApplying then return end
                local nameplate = Minimizer.Utils.GetNameplateFromHealthBar(healthBar)
                local lastColor = nameplate and nameplate.MinimizerLastAppliedColor
                if lastColor then
                    Minimizer.Utils.GuardedCall(healthBar, "MinimizerHealthColorApplying", function()
                        healthBar:SetStatusBarColor(lastColor[1], lastColor[2], lastColor[3])
                    end)
                end
            end)
        end
    end
end

HookIndicator = function(indicator, healthBar)
    if not indicator or indicator.MinimizerAbsorbHooked then return end
    indicator.MinimizerAbsorbHooked = true
    if hooksecurefunc then
        local function triggerUpdate()
            if healthBar.MinimizerHealthColorApplying then return end
            local nameplate = Minimizer.Utils.GetNameplateFromHealthBar(healthBar)
            local unit = Minimizer.Utils.GetUnitFromNameplate(nameplate)
            if unit then
                if Minimizer and Minimizer.Dispatcher and Minimizer.Dispatcher.ApplyToUnit then
                    Minimizer.Dispatcher.ApplyToUnit(unit)
                elseif Minimizer and Minimizer.Core and Minimizer.Core.ApplyToUnit then
                    Minimizer.Core.ApplyToUnit(unit)
                else
                    HealthBarColor:UpdateNamePlate(unit, nameplate, nil)
                end
            end
        end
        hooksecurefunc(indicator, "Show", triggerUpdate)
        hooksecurefunc(indicator, "Hide", triggerUpdate)
    end
end

function HealthBarColor:OnNamePlateRemoved(_, nameplate)
    if nameplate then
        nameplate.MinimizerHealthBarColorKind = nil
        nameplate.MinimizerHealthBarColorUnit = nil
        nameplate.MinimizerHealthBarColorGen = nil
        nameplate.MinimizerPersistentCastColor = nil
        nameplate.MinimizerHasAbsorb = nil
        nameplate.MinimizerLastAppliedColor = nil
        local healthBar = self:GetHealthBar(nameplate)
        local bar = healthBar and healthBar.MinimizerOvershieldBar
        if bar then
            bar:Hide()
            bar.MinimizerLastAbsorb = nil
            bar.MinimizerLastMaxHealth = nil
        end
    end
end

Minimizer.Core.RegisterModule("HealthBarColor", HealthBarColor)
