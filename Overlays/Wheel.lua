-- ============================================================================
-- Minimizer - Wheel.lua
-- Wheel periférico del personaje del jugador: interrupt + pips configurables.
-- ============================================================================
local _, Minimizer = ...
if not Minimizer then return end

local Wheel = {}
Minimizer.Wheel = Wheel

local WHEEL_SIZE = 68
local PIP_RADIUS = 34
local WHEEL_OFFSET_X = 0
local WHEEL_OFFSET_Y = 42

local wheelFrame = CreateFrame("Frame", "MinimizerPlayerWheel", WorldFrame)
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

local function GetPlayerWorldAnchor()
    -- El frame de la unidad player no es PlayerFrame ni una nameplate. Es el
    -- ancla de mundo de Blizzard que representa la posición 3D del personaje.
    if WorldFrame and WorldFrame.GetPlayerWorldPosition then
        return WorldFrame:GetPlayerWorldPosition()
    end

    -- WorldFrame no expone una API Lua estable para convertir UnitPosition()
    -- directamente a coordenadas de pantalla en todas las versiones. Si el
    -- cliente ofrece WorldToScreen, úsalo; nunca recurrimos a PlayerFrame ni a
    -- la nameplate del player como sustitutos.
    if WorldFrame and WorldFrame.WorldToScreen and UnitPosition then
        local x, y, z = UnitPosition("player")
        if x and y and z then
            return WorldFrame:WorldToScreen(x, y, z)
        end
    end

    return nil, nil
end

function Wheel:Update()
    local x, y = GetPlayerWorldAnchor()
    if not x or not y then
        wheelFrame:Hide()
        return
    end

    wheelFrame:ClearAllPoints()
    wheelFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x + WHEEL_OFFSET_X, y + WHEEL_OFFSET_Y)
    wheelFrame:SetFrameLevel((WorldFrame:GetFrameLevel() or 0) + 10)

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
