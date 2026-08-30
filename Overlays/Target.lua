local _, Minimizer = ...
if not Minimizer then return end

local Target = {}
Minimizer.Target = Target

local HALO_SIZE = 46
local STRIPED_PATTERN_TEXTURE = "Interface\\AddOns\\Minimizer\\assets\\striped_pattern"
local STRIPED_PATTERN_ALPHA = 0.45

local haloFrame = Minimizer.Widgets.CreateHalo("MinimizerTargetHalo", nil, HALO_SIZE)

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

    overlay = CreateFrame("Frame", nil, healthBar)
    overlay:SetAllPoints(healthBar)
    local frameLevel = (healthBar:GetFrameLevel() or 0) + 2
    overlay:SetFrameLevel(frameLevel)

    local texture = overlay:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints(overlay)
    texture:SetTexture(STRIPED_PATTERN_TEXTURE)
    texture:SetAlpha(STRIPED_PATTERN_ALPHA)
    texture:SetBlendMode("BLEND")
    -- Keep the source and draw-order invariants inspectable in the lightweight
    -- test environment without depending on WoW's texture introspection APIs.
    texture.MinimizerTexturePath = STRIPED_PATTERN_TEXTURE
    texture.MinimizerDrawLayer = "OVERLAY"

    overlay.MinimizerTexture = texture
    overlay.MinimizerFrameLevel = frameLevel
    overlay:Hide()
    healthBar.MinimizerTargetStripedOverlay = overlay
    return overlay
end

local function HideStripedOverlay()
    if stripedOverlay then
        stripedOverlay:Hide()
    end
    stripedHealthBar = nil
    stripedOverlay = nil
end

local function ShowStripedOverlay(healthBar)
    if stripedHealthBar and stripedHealthBar ~= healthBar and stripedOverlay then
        stripedOverlay:Hide()
    end

    local overlay = EnsureStripedOverlay(healthBar)
    overlay:Show()
    stripedHealthBar = healthBar
    stripedOverlay = overlay
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

function Target:UpdateTargetCDs()
    if not UnitExists("target") or UnitIsDead("target") then
        haloFrame:Hide()
        interruptCountdown:Hide()
        HideStripedOverlay()
        return
    end

    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit("target")
    if not plate then
        haloFrame:Hide()
        interruptCountdown:Hide()
        HideStripedOverlay()
        return
    end

    local healthBar = Minimizer.Utils and Minimizer.Utils.GetHealthBar and Minimizer.Utils.GetHealthBar(plate)
    if healthBar then
        ShowStripedOverlay(healthBar)
    else
        HideStripedOverlay()
    end

    local interruptSpellID = Minimizer.Interrupt and Minimizer.Interrupt.GetSpellID
        and Minimizer.Interrupt.GetSpellID()

    if interruptSpellID then
        Minimizer.Widgets.UpdateHalo(haloFrame, interruptSpellID)
        haloFrame:ClearAllPoints()
        haloFrame:SetPoint("CENTER", plate, "BOTTOM", 0, 10 + (HALO_SIZE / 2))
        local plateLevel = (plate:GetFrameLevel() or 0)
        haloFrame:SetFrameLevel(plateLevel + 2)
        interruptCountdown:SetFrameLevel((haloFrame:GetFrameLevel() or 0) + 10)
        UpdateInterruptCountdown()
    else
        haloFrame:Hide()
        interruptCountdown:Hide()
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
