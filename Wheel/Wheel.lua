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
local MIN_SIZE, MAX_SIZE = 120, 300
local MIN_PIP_RADIUS, MAX_PIP_RADIUS = 45, 105

local WHEEL_X = 0
local WHEEL_Y = -45

-- Player UI uses Blizzard's normal window strata. The host owns this context;
-- Halo only supplies the reusable visual representation.
local wheelFrame = CreateFrame("Frame", "MinimizerPlayerWheel", UIParent)
wheelFrame:SetSize(DEFAULT_SIZE, DEFAULT_SIZE)
wheelFrame:SetFrameStrata("MEDIUM")
wheelFrame:SetPoint("CENTER", UIParent, "CENTER", WHEEL_X, WHEEL_Y)

local wheelHalo = Minimizer.Halo.Create(wheelFrame, {
    size = DEFAULT_SIZE,
    cooldownName = "MinimizerPlayerWheelInterrupt",
    cooldownFrameLevelOffset = 10,
})
wheelHalo:SetFrameLevel((wheelFrame:GetFrameLevel() or 0) + 1)
wheelHalo:SetPoint("CENTER", wheelFrame, "CENTER")
wheelFrame.MinimizerWheelHalo = wheelHalo
wheelFrame.MinimizerWheelInterrupt = wheelHalo.MinimizerHaloCooldown

local wheelPips = Minimizer.Pips and Minimizer.Pips.CreatePips(
    wheelFrame,
    "MinimizerPlayerWheelPip",
    DEFAULT_PIP_RADIUS
)

Wheel._enabled = nil
Wheel._size = DEFAULT_SIZE
Wheel._pipRadius = DEFAULT_PIP_RADIUS

local function NormalizeSize(value)
    value = tonumber(value) or DEFAULT_SIZE
    value = math.floor(value + 0.5)
    if value < MIN_SIZE then return MIN_SIZE end
    if value > MAX_SIZE then return MAX_SIZE end
    return value
end

local function NormalizePipRadius(value)
    value = tonumber(value) or DEFAULT_PIP_RADIUS
    value = math.floor(value + 0.5)
    if value < MIN_PIP_RADIUS then return MIN_PIP_RADIUS end
    if value > MAX_PIP_RADIUS then return MAX_PIP_RADIUS end
    return value
end

local function ReadConfig()
    local db = MinimizerDB
    if not db then
        return true, DEFAULT_SIZE, DEFAULT_PIP_RADIUS
    end
    return db.wheelEnabled ~= false,
        NormalizeSize(db.wheelSize),
        NormalizePipRadius(db.wheelPipRadius)
end

local function UpdateInterrupt()
    local spellID = Minimizer.Interrupt and Minimizer.Interrupt.GetSpellID
        and Minimizer.Interrupt.GetSpellID()
    if not spellID or not Minimizer.Widgets.ApplyCooldownDuration then
        wheelHalo:Hide()
        return
    end

    wheelHalo:ShowFor(spellID)
end

local function UpdatePips()
    if wheelPips and Minimizer.Pips then
        Minimizer.Pips.UpdatePips(wheelPips)
    end
end

function Wheel:SetSize(size)
    size = NormalizeSize(size)
    if self._size == size then return false end

    self._size = size
    wheelFrame:SetSize(size, size)
    wheelHalo:SetSize(size, size)
    return true
end

function Wheel:SetPipRadius(radius)
    radius = NormalizePipRadius(radius)
    if self._pipRadius == radius then return false end

    self._pipRadius = radius
    if wheelPips and Minimizer.Pips and Minimizer.Pips.SetRadius then
        Minimizer.Pips.SetRadius(wheelPips, radius)
    end
    return true
end

function Wheel:SetEnabled(enabled)
    enabled = enabled == true
    if self._enabled == enabled then return false end

    self._enabled = enabled
    if not enabled then
        wheelFrame:Hide()
        wheelHalo:Hide()
        if wheelPips and Minimizer.Pips and Minimizer.Pips.HidePips then
            Minimizer.Pips.HidePips(wheelPips)
        end
        return true
    end

    wheelFrame:Show()
    return true
end

function Wheel:ApplyConfig()
    local enabled, size, radius = ReadConfig()
    local enabledChanged = self._enabled ~= enabled
    local sizeChanged = self._size ~= size
    local radiusChanged = self._pipRadius ~= radius

    if sizeChanged then self:SetSize(size) end
    if radiusChanged then self:SetPipRadius(radius) end
    if enabledChanged then self:SetEnabled(enabled) end

    if enabled and (enabledChanged or sizeChanged or radiusChanged) then
        self:Update()
    end
end

function Wheel:Update()
    if not self._enabled then return end

    UpdateInterrupt()
    UpdatePips()
end

Wheel.DebouncedUpdate = Minimizer.Utils.Throttle(function()
    Wheel:Update()
end, 0.033)

function Wheel:OnCooldownTick()
    if self._enabled then
        self.DebouncedUpdate()
    end
end

function Wheel:OnUnitChanged(unit, reason)
    if not self._enabled then return end
    if unit == "player" or reason == "added" or reason == "removed" then
        self.DebouncedUpdate()
    end
end

if Minimizer.Overlays and Minimizer.Overlays.Register then
    Minimizer.Overlays.Register("Wheel", Wheel)
end
