local _, Minimizer = ...
if not Minimizer then return end

local Target = {}
Minimizer.Target = Target

local HALO_SIZE = 46
local PORTRAIT_RADIUS = 18
local haloFrame = Minimizer.Widgets.CreateHalo("MinimizerTargetHalo", nil, HALO_SIZE)
local targetPips = Minimizer.Pips and Minimizer.Pips.CreatePips(haloFrame, "MinimizerTargetPip", PORTRAIT_RADIUS)

-- Solo el número de cuenta atrás del corte.
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
        if targetPips and Minimizer.Pips then Minimizer.Pips.HidePips(targetPips) end
        return
    end
    
    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit("target")
    if not plate then 
        haloFrame:Hide()
        interruptCountdown:Hide()
        if targetPips and Minimizer.Pips then Minimizer.Pips.HidePips(targetPips) end
        return
    end

    local interruptSpellID = Minimizer.Interrupt and Minimizer.Interrupt.GetSpellID
        and Minimizer.Interrupt.GetSpellID()

    if targetPips and Minimizer.Pips then
        Minimizer.Pips.UpdatePips(targetPips)
    end

    if interruptSpellID then
        Minimizer.Widgets.UpdateHalo(haloFrame, interruptSpellID)
        haloFrame:ClearAllPoints()
        haloFrame:SetPoint("CENTER", plate, "BOTTOM", 0, 10 + (HALO_SIZE / 2))
        -- Poner el halo justo por encima del portrait (nivel relativo a la placa)
        local plateLevel = (plate:GetFrameLevel() or 0)
        haloFrame:SetFrameLevel(plateLevel + 2)
        if targetPips and Minimizer.Pips then
            Minimizer.Pips.SetFrameLevel(targetPips, (haloFrame:GetFrameLevel() or 0) + 5)
        end
        interruptCountdown:SetFrameLevel((haloFrame:GetFrameLevel() or 0) + 10)
        UpdateInterruptCountdown()
    else
        haloFrame:Hide()
        interruptCountdown:Hide()
    end
end

-- Throttle a 30 FPS (0.033s): visuales de target no necesitan repintarse más rápido.
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


