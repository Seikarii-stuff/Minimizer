local _, Minimizer = ...
if not Minimizer then return end

local Target = {}
Minimizer.Target = Target

local HALO_SIZE = 46
local STRIPED_PATTERN_TEXTURE = "Interface\\AddOns\\Minimizer\\assets\\striped_pattern"
local STRIPED_PATTERN_ALPHA = 0.6

local haloFrame = Minimizer.Halo.Create(nil, {
    name = "MinimizerTargetHalo",
    size = HALO_SIZE,
})

local interruptCountdown = CreateFrame("Cooldown", "MinimizerTargetInterruptCountdown", haloFrame, "CooldownFrameTemplate")
interruptCountdown:SetAllPoints()
Minimizer.Widgets.ConfigureCooldownFrame(interruptCountdown, {
    drawEdge = false,
    useCircularEdge = false,
    drawSwipe = false,
    drawBling = false,
    reverse = false,
    hideCountdownNumbers = false,
})
interruptCountdown:SetFrameLevel((haloFrame:GetFrameLevel() or 0) + 10)

local stripedHealthBar
local stripedOverlay

local function EnsureStripedOverlay(healthBar)
    local overlay = healthBar.MinimizerTargetStripedOverlay
    if overlay then return overlay end

    overlay = CreateFrame("StatusBar", nil, healthBar)
    overlay:SetAllPoints(healthBar)
    local frameLevel = (healthBar:GetFrameLevel() or 0) + 2
    overlay:SetFrameLevel(frameLevel)

    overlay:SetStatusBarTexture(STRIPED_PATTERN_TEXTURE)
    overlay:SetStatusBarColor(1, 1, 1, STRIPED_PATTERN_ALPHA)
    overlay:SetOrientation("HORIZONTAL")
    overlay:SetReverseFill(false)
    if type(overlay.EnableMouse) == "function" then overlay:EnableMouse(false) end

    overlay.MinimizerFrameLevel = frameLevel
    overlay:Hide()
    healthBar.MinimizerTargetStripedOverlay = overlay
    return overlay
end

local function UpdateStripedOverlay(healthBar, unit)
    local overlay = EnsureStripedOverlay(healthBar)
    local maxHealth = UnitHealthMax(unit)
    local health = UnitHealth(unit)

    overlay:SetMinMaxValues(0, maxHealth)
    overlay:SetValue(health)
    overlay:Show()

    stripedHealthBar = healthBar
    stripedOverlay = overlay
end

local function HideStripedOverlay()
    if stripedOverlay then
        stripedOverlay:Hide()
    end
    stripedHealthBar = nil
    stripedOverlay = nil
end

local function ShowStripedOverlay(healthBar, unit)
    if stripedHealthBar and stripedHealthBar ~= healthBar and stripedOverlay then
        stripedOverlay:Hide()
    end

    UpdateStripedOverlay(healthBar, unit)
end

local function UpdateInterruptCountdown()
    local interruptSpellID = Minimizer.Interrupt and Minimizer.Interrupt.GetSpellID
        and Minimizer.Interrupt.GetSpellID()
    if not interruptSpellID or not Minimizer.Widgets.ApplyCooldownDuration then
        interruptCountdown:Hide()
        return
    end
    Minimizer.Widgets.ApplyCooldownDuration(interruptCountdown, interruptSpellID)
    interruptCountdown:Show()
end

local function HideHalo()
    haloFrame:Hide()
    interruptCountdown:Hide()
    haloFrame:SetHost(nil)
end

function Target:UpdateTargetCDs()
    if not UnitExists("target") or UnitIsDead("target") then
        HideHalo()
        HideStripedOverlay()
        return
    end

    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit("target")
    if not plate then
        HideHalo()
        HideStripedOverlay()
        return
    end

    local healthBar = Minimizer.Utils and Minimizer.Utils.GetHealthBar and Minimizer.Utils.GetHealthBar(plate)
    if healthBar then
        ShowStripedOverlay(healthBar, "target")
    else
        HideStripedOverlay()
    end

    local interruptSpellID = Minimizer.Interrupt and Minimizer.Interrupt.GetSpellID
        and Minimizer.Interrupt.GetSpellID()

    if interruptSpellID then
        haloFrame:SetHost(plate)
        haloFrame:ShowFor(interruptSpellID)
        haloFrame:ClearAllPoints()
        haloFrame:SetPoint("CENTER", plate, "BOTTOM", 0, 10 + (HALO_SIZE / 2))
        local plateLevel = (plate:GetFrameLevel() or 0)
        haloFrame:SetFrameLevel(plateLevel + 2)
        interruptCountdown:SetFrameLevel((haloFrame:GetFrameLevel() or 0) + 10)
        UpdateInterruptCountdown()
    else
        HideHalo()
    end
end

Target.DebouncedUpdate = Minimizer.Utils.Throttle(function()
    Target:UpdateTargetCDs()
end, 0.033)

function Target:OnCooldownTick()
    Target.DebouncedUpdate()
end

function Target:OnUnitChanged(unit, reason)
    if reason == "target" then
        Target:UpdateTargetCDs()
    elseif reason == "added" or reason == "removed" then
        if not unit or (UnitExists and UnitExists("target") and UnitIsUnit and UnitIsUnit(unit, "target")) then
            Target:UpdateTargetCDs()
        end
    end
end

if Minimizer.Overlays and Minimizer.Overlays.Register then
    Minimizer.Overlays.Register("Target", Target)
end
