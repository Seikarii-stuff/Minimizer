-- ============================================================================
-- Minimizer - Wheel.lua
-- Wheel periférico del player: interrupt + pips configurables.
-- ============================================================================
local _, Minimizer = ...
if not Minimizer then return end

local Wheel = {}
Minimizer.Wheel = Wheel

local WHEEL_SIZE = 68
local PIP_RADIUS = 34
local WHEEL_OFFSET_Y = -8

local wheelFrame = Minimizer.Widgets.CreateHalo("MinimizerPlayerWheel", UIParent, WHEEL_SIZE)
local wheelPips = Minimizer.Pips and Minimizer.Pips.CreatePips(
    wheelFrame,
    "MinimizerPlayerWheelPip",
    PIP_RADIUS
)

-- El interrupt es parte del Wheel: usa exactamente la misma resolución y
-- duración que Target/Focus, pero se muestra como el cooldown circular central.
local interruptCooldown = CreateFrame(
    "Cooldown",
    "MinimizerPlayerWheelInterrupt",
    wheelFrame,
    "CooldownFrameTemplate"
)
interruptCooldown:SetAllPoints()
Minimizer.Widgets.ConfigureCooldownFrame(interruptCooldown, {
    drawEdge = false,
    useCircularEdge = true,
    drawSwipe = true,
    drawBling = false,
    reverse = false,
    hideCountdownNumbers = true,
    swipeTexture = "Interface\\Masks\\CircleMaskScalable",
    swipeColor = { 0.00, 0.00, 0.00, 0.75 },
})

local function UpdateInterrupt()
    local spellID = Minimizer.Interrupt and Minimizer.Interrupt.GetSpellID
        and Minimizer.Interrupt.GetSpellID()
    if not spellID or not Minimizer.Widgets.ApplyCooldownDuration then
        interruptCooldown:Hide()
        return
    end

    Minimizer.Widgets.ApplyCooldownDuration(interruptCooldown, spellID)
    interruptCooldown:Show()
end

local function UpdatePips()
    if wheelPips and Minimizer.Pips then
        Minimizer.Pips.UpdatePips(wheelPips)
    end
end

function Wheel:Update()
    -- El Wheel está ligado al player y no depende de nameplates.
    wheelFrame:ClearAllPoints()
    wheelFrame:SetPoint("CENTER", UIParent, "CENTER", 0, WHEEL_OFFSET_Y)
    wheelFrame:SetFrameLevel((UIParent:GetFrameLevel() or 0) + 10)

    UpdateInterrupt()
    UpdatePips()

    if wheelPips and Minimizer.Pips then
        Minimizer.Pips.SetFrameLevel(wheelPips, (wheelFrame:GetFrameLevel() or 0) + 5)
    end
    interruptCooldown:SetFrameLevel((wheelFrame:GetFrameLevel() or 0) + 10)

    if interruptCooldown:IsShown() or (wheelPips and #wheelPips > 0) then
        wheelFrame:Show()
    else
        wheelFrame:Hide()
    end
end

Wheel.DebouncedUpdate = Minimizer.Utils.Throttle(function()
    Wheel:Update()
end, 0.033)

function Wheel:OnCooldownTick()
    Wheel.DebouncedUpdate()
end

function Wheel:OnUnitChanged()
    Wheel.DebouncedUpdate()
end

if Minimizer.Overlays and Minimizer.Overlays.Register then
    Minimizer.Overlays.Register("Wheel", Wheel)
end
