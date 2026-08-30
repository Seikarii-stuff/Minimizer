-- ============================================================================
-- Minimizer - Wheel.lua
-- UI propia del jugador: interrupt + pips configurables.
-- ============================================================================
local _, Minimizer = ...
if not Minimizer then return end

local Wheel = {}
Minimizer.Wheel = Wheel

local DEFAULT_SIZE = 180
local DEFAULT_PIP_RADIUS = 75

-- 0, 0 = centro de la pantalla.
local WHEEL_X = 0
local WHEEL_Y = -45

local wheelFrame = CreateFrame("Frame", "MinimizerPlayerWheel", UIParent)
wheelFrame:SetSize(DEFAULT_SIZE, DEFAULT_SIZE)
wheelFrame:SetFrameStrata("HIGH")
wheelFrame:SetPoint("CENTER", UIParent, "CENTER", WHEEL_X, WHEEL_Y)

local wheelTexture = wheelFrame:CreateTexture(nil, "ARTWORK")
wheelTexture:SetAllPoints()
wheelTexture:SetTexture("Interface\\AddOns\\Minimizer\\assets\\halo_ring")
wheelTexture:SetBlendMode("BLEND")
wheelFrame.MinimizerWheelTexture = wheelTexture

local wheelPips = Minimizer.Pips and Minimizer.Pips.CreatePips(
    wheelFrame,
    "MinimizerPlayerWheelPip",
    DEFAULT_PIP_RADIUS
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

local function GetWheelConfig()
    local db = MinimizerDB or {}
    return {
        enabled = db.wheelEnabled ~= false,
        size = tonumber(db.wheelSize) or DEFAULT_SIZE,
        pipRadius = tonumber(db.wheelPipRadius) or DEFAULT_PIP_RADIUS,
    }
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

function Wheel:SetSize(size)
    size = tonumber(size) or DEFAULT_SIZE
    wheelFrame:SetSize(size, size)
    wheelFrame.MinimizerWheelSize = size
end

function Wheel:SetPipRadius(radius)
    radius = tonumber(radius) or DEFAULT_PIP_RADIUS
    if wheelPips and Minimizer.Pips and Minimizer.Pips.SetRadius then
        Minimizer.Pips.SetRadius(wheelPips, radius)
    end
end

function Wheel:SetEnabled(enabled)
    if enabled == true then
        wheelFrame:Show()
        self:Update()
    else
        wheelFrame:Hide()
        interruptCooldown:Hide()
        if wheelPips and Minimizer.Pips and Minimizer.Pips.HidePips then
            Minimizer.Pips.HidePips(wheelPips)
        end
    end
end

function Wheel:ApplyConfig()
    local config = GetWheelConfig()
    self:SetSize(config.size)
    self:SetPipRadius(config.pipRadius)
    self:SetEnabled(config.enabled)
end

function Wheel:Update()
    local config = GetWheelConfig()
    if not config.enabled then
        wheelFrame:Hide()
        interruptCooldown:Hide()
        if wheelPips and Minimizer.Pips and Minimizer.Pips.HidePips then
            Minimizer.Pips.HidePips(wheelPips)
        end
        return
    end

    self:SetSize(config.size)
    self:SetPipRadius(config.pipRadius)

    wheelFrame:ClearAllPoints()
    wheelFrame:SetPoint("CENTER", UIParent, "CENTER", WHEEL_X, WHEEL_Y)
    wheelFrame:SetFrameLevel(100)

    UpdateInterrupt()
    UpdatePips()

    if wheelPips and Minimizer.Pips then
        Minimizer.Pips.SetFrameLevel(wheelPips, 105)
    end
    interruptCooldown:SetFrameLevel(110)
    wheelFrame:Show()
end

Wheel.DebouncedUpdate = Minimizer.Utils.Throttle(function()
    Wheel:Update()
end, 0.033)

function Wheel:OnCooldownTick()
    if GetWheelConfig().enabled then
        Wheel.DebouncedUpdate()
    end
end

function Wheel:OnUnitChanged(unit, reason)
    if not GetWheelConfig().enabled then return end
    if unit == "player" or reason == "added" or reason == "removed" then
        Wheel.DebouncedUpdate()
    end
end

if Minimizer.Overlays and Minimizer.Overlays.Register then
    Minimizer.Overlays.Register("Wheel", Wheel)
end
