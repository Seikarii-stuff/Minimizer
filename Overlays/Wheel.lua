-- ============================================================================
-- Minimizer - Wheel.lua
-- Wheel periférico del personaje del jugador: interrupt + pips configurables.
--
-- El Wheel NO se ancla al PlayerFrame, a una nameplate ni a una posición 3D.
-- Su posición se define mediante X/Y respecto al centro de la pantalla y se
-- hace coincidir manualmente con la posición visual del personaje.
-- ============================================================================
local _, Minimizer = ...
if not Minimizer then return end

local Wheel = {}
Minimizer.Wheel = Wheel

local WHEEL_SIZE = 68
local PIP_RADIUS = 34

-- 0, 0 = centro de UIParent. Estos son los valores que se ajustan para hacer
-- coincidir el Wheel con el personaje del jugador.
local WHEEL_X = 0
local WHEEL_Y = 0

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

local function PositionWheel()
    wheelFrame:ClearAllPoints()
    wheelFrame:SetPoint("CENTER", UIParent, "CENTER", WHEEL_X, WHEEL_Y)
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
    PositionWheel()

    wheelFrame:SetFrameLevel(100)
    UpdateInterrupt()
    UpdatePips()

    if wheelPips and Minimizer.Pips then
        Minimizer.Pips.SetFrameLevel(wheelPips, 105)
    end
    interruptCooldown:SetFrameLevel(110)

    local hasPips = false
    if wheelPips then
        for _, pip in ipairs(wheelPips) do
            if pip:IsShown() then
                hasPips = true
                break
            end
        end
    end

    wheelFrame:SetShown(interruptCooldown:IsShown() or hasPips)
end

Wheel.DebouncedUpdate = Minimizer.Utils.Throttle(function()
    Wheel:Update()
end, 0.033)

function Wheel:OnCooldownTick()
    Wheel.DebouncedUpdate()
end

function Wheel:OnUnitChanged(unit, reason)
    -- Los eventos de unidades solo refrescan contenido; la posición del Wheel
    -- es exclusivamente la coordenada X/Y configurada arriba.
    if unit == "player" or reason == "added" or reason == "removed" then
        Wheel.DebouncedUpdate()
    end
end

if Minimizer.Overlays and Minimizer.Overlays.Register then
    Minimizer.Overlays.Register("Wheel", Wheel)
end
