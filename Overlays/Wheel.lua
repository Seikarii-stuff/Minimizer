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
local WHEEL_OFFSET_X = 0
local WHEEL_OFFSET_Y = 0

local wheelFrame = CreateFrame("Frame", "MinimizerPlayerWheel", UIParent)
wheelFrame:SetSize(WHEEL_SIZE, WHEEL_SIZE)
wheelFrame:SetFrameStrata("HIGH")
wheelFrame:Hide()

local wheelTexture = wheelFrame:CreateTexture(nil, "ARTWORK")
wheelTexture:SetAllPoints()
wheelTexture:SetTexture("Interface\\AddOns\\Minimizer\\assets\\halo_ring")
wheelTexture:SetBlendMode("BLEND")
wheelFrame.MinimizerWheelTexture = wheelTexture

local wheelPips = Minimizer.Pips and Minimizer.Pips.CreatePips(
    wheelFrame,
    "MinimizerPlayerWheelPip",
    PIP_RADIUS
)

-- El interrupt pertenece al Wheel y utiliza exactamente la misma resolución
-- y duración que Target/Focus.
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
    swipeTexture = "Interface\\AddOns\\Minimizer\\assets\\halo_ring",
    swipeColor = { 0.00, 0.00, 0.00, 0.75 },
})
wheelFrame.MinimizerWheelInterrupt = interruptCooldown

local function GetPlayerWorldAnchor()
    -- C_NamePlate.GetNamePlateForUnit("player") es el ancla UI que Blizzard
    -- mantiene asociada a la posición del personaje en el mundo 3D. No usamos
    -- PlayerFrame: el Wheel sigue al personaje, no a su retrato/barra de vida.
    if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        return C_NamePlate.GetNamePlateForUnit("player")
    end
    return nil
end

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
    local playerAnchor = GetPlayerWorldAnchor()
    if not playerAnchor then
        wheelFrame:Hide()
        return
    end

    -- El frame de la nameplate del player es solo el punto de anclaje: el
    -- Wheel no depende visualmente del PlayerFrame de la interfaz.
    wheelFrame:ClearAllPoints()
    wheelFrame:SetPoint("CENTER", playerAnchor, "CENTER", WHEEL_OFFSET_X, WHEEL_OFFSET_Y)
    wheelFrame:SetFrameLevel((playerAnchor:GetFrameLevel() or 0) + 10)

    UpdateInterrupt()
    UpdatePips()

    if wheelPips and Minimizer.Pips then
        Minimizer.Pips.SetFrameLevel(wheelPips, (wheelFrame:GetFrameLevel() or 0) + 5)
    end
    interruptCooldown:SetFrameLevel((wheelFrame:GetFrameLevel() or 0) + 10)

    local hasPips = false
    if wheelPips then
        for _, pip in ipairs(wheelPips) do
            if pip:IsShown() then
                hasPips = true
                break
            end
        end
    end

    if interruptCooldown:IsShown() or hasPips then
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

function Wheel:OnUnitChanged(unit, reason)
    if not unit or unit == "player" or reason == "added" or reason == "removed" then
        Wheel.DebouncedUpdate()
    end
end

if Minimizer.Overlays and Minimizer.Overlays.Register then
    Minimizer.Overlays.Register("Wheel", Wheel)
end
