-- ============================================================================
-- Minimizer - CastingBar.lua
-- Cast bars de nameplate: colores, objetivo del hechizo y marcador de corte.
-- ============================================================================

local _, Minimizer = ...
if not Minimizer or not Minimizer.Core then return end

local CastingBar = {}
Minimizer.CastingBar = CastingBar

local COLORS = {
    ready = { 0.10, 1.00, 0.10 },
}

local function IsSecretValue(value)
    return issecretvalue and issecretvalue(value)
end

local function IsSpellTargetingPlayer(unit)
    if UnitIsSpellTarget then
        local targeted = UnitIsSpellTarget(unit, "player")
        if not IsSecretValue(targeted) and targeted == true then return true end
    end
    local target = unit and (unit .. "target")
    return target and UnitIsUnit(target, "player") == true
end

local function IsImportantSpell(spellID)
    if not spellID or IsSecretValue(spellID) then return false end
    return C_Spell and C_Spell.IsSpellImportant
        and C_Spell.IsSpellImportant(spellID) == true
end

-- El proyecto deja el proveedor de cooldown desacoplado para que pueda
-- sustituirse por el sistema de interrupciones de cada clase/spec.
Minimizer.Interrupt = Minimizer.Interrupt or {}
local INTERRUPT_SPELLS = {
    WARRIOR = 6552, ROGUE = 1766, MAGE = 2139, SHAMAN = 57994,
    HUNTER = 147362, PRIEST = 15487, WARLOCK = 19647, MONK = 116705,
    DRUID = 106839, DEATHKNIGHT = 47528, PALADIN = 96231,
    DEMONHUNTER = 183752, EVOKER = 351338,
}

function Minimizer.Interrupt.GetSpellID()
    if MinimizerDB.interruptSpellID then return MinimizerDB.interruptSpellID end
    local _, classToken = UnitClass("player")
    local spellID = classToken and INTERRUPT_SPELLS[classToken]
    if spellID and ((IsPlayerSpell and IsPlayerSpell(spellID))
        or (C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(spellID))) then
        return spellID
    end
    return nil
end

function Minimizer.Interrupt.IsReady()
    if type(MinimizerDB.interruptReady) == "boolean" then
        return MinimizerDB.interruptReady
    end
    local spellID = Minimizer.Interrupt.GetSpellID()
    if spellID and C_Spell and C_Spell.GetSpellCooldown then
        local cooldown = C_Spell.GetSpellCooldown(spellID)
        if cooldown and cooldown.startTime and cooldown.duration then
            return cooldown.startTime == 0 or cooldown.duration == 0
                or (GetTime() >= cooldown.startTime + cooldown.duration)
        end
    end
    -- Sin un spellID configurado no se puede inferir el corte sin adivinar la
    -- clase/spec; se conserva el estado disponible como "up".
    return true
end

function CastingBar:GetCastBar(nameplate)
    local unitFrame = nameplate and (nameplate.UnitFrame or nameplate)
    return (unitFrame and (unitFrame.castBar or unitFrame.CastBar or unitFrame.castbar))
        or (nameplate and (nameplate.castBar or nameplate.CastBar or nameplate.castbar))
end

function CastingBar:EnsureVisuals(castBar)
    if castBar.MinimizerCastVisuals then return castBar.MinimizerCastVisuals end

    local border = castBar:CreateTexture(nil, "OVERLAY")
    border:SetPoint("TOPLEFT", castBar, "TOPLEFT", -3, 3)
    border:SetPoint("BOTTOMRIGHT", castBar, "BOTTOMRIGHT", 3, -3)
    border:SetColorTexture(1, 0.05, 0.05, 0.9)
    border:SetBlendMode("ADD")
    border:Hide()

    local marker = castBar:CreateTexture(nil, "OVERLAY")
    marker:SetWidth(3)
    marker:SetColorTexture(1, 1, 1, 1)
    marker:Hide()

    castBar.MinimizerCastVisuals = { targetBorder = border, interruptMarker = marker }
    return castBar.MinimizerCastVisuals
end

function CastingBar:UpdateInterruptMarker(castBar, visuals, isCasting, ready)
    if not isCasting or not ready or not castBar.GetValue then
        visuals.interruptMarker:Hide()
        return
    end

    local value = castBar:GetValue()
    local minValue, maxValue = castBar:GetMinMaxValues()
    if IsSecretValue(value) or IsSecretValue(minValue) or IsSecretValue(maxValue)
        or type(value) ~= "number" or type(minValue) ~= "number"
        or type(maxValue) ~= "number" or maxValue <= minValue then
        visuals.interruptMarker:Hide()
        return
    end

    local progress = (value - minValue) / (maxValue - minValue)
    local width = castBar:GetWidth()
    if type(width) ~= "number" or width <= 0 then
        visuals.interruptMarker:Hide()
        return
    end
    visuals.interruptMarker:ClearAllPoints()
    visuals.interruptMarker:SetPoint("TOP", castBar, "TOPLEFT", width * progress, 0)
    visuals.interruptMarker:SetPoint("BOTTOM", castBar, "BOTTOMLEFT", width * progress, 0)
    visuals.interruptMarker:Show()
end

function CastingBar:UpdateNamePlate(unit, nameplate)
    if not unit or not UnitExists(unit) then return end
    local castBar = self:GetCastBar(nameplate)
    if not castBar or type(castBar.SetStatusBarColor) ~= "function" then return end

    local visuals = self:EnsureVisuals(castBar)
    local isCasting, isUninterruptible, uninterruptibleValue = Minimizer.Cast.GetState(unit)
    local ready = Minimizer.Interrupt.IsReady()

    -- Gris/ininterruptible y azul/corte en cooldown son colores nativos de
    -- Blizzard: no los sobrescribimos. Sólo aplicamos verde cuando el valor
    -- de interruptibilidad es seguro y el cast es inequívocamente cortable.
    local canColorGreen = isCasting and ready
        and not IsSecretValue(uninterruptibleValue)
        and isUninterruptible == false
    if canColorGreen and type(castBar.GetStatusBarColor) == "function" then
        if not castBar.MinimizerDefaultColor then
            local r, g, b, a = castBar:GetStatusBarColor()
            castBar.MinimizerDefaultColor = { r, g, b, a }
        end
        castBar:SetStatusBarColor(COLORS.ready[1], COLORS.ready[2], COLORS.ready[3])
    elseif castBar.MinimizerDefaultColor then
        local color = castBar.MinimizerDefaultColor
        castBar:SetStatusBarColor(color[1], color[2], color[3], color[4])
        castBar.MinimizerDefaultColor = nil
    end

    local targeted = IsSpellTargetingPlayer(unit)
    local spellID = select(9, UnitCastingInfo(unit)) or select(8, UnitChannelInfo(unit))
    local important = IsImportantSpell(spellID)
    if targeted and isCasting then
        visuals.targetBorder:Show()
    else
        visuals.targetBorder:Hide()
    end
    -- El cliente ya resalta los casts importantes; sólo conservamos el dato
    -- para futuras animaciones sin duplicar su indicador nativo.
    nameplate.MinimizerImportantCast = important
    self:UpdateInterruptMarker(castBar, visuals, isCasting, ready)
end

function CastingBar:OnCastEvent(unit, event)
    local nameplate = Minimizer.Utils.GetNamePlateForUnit(unit)
    if not nameplate then return end
    Minimizer.Core.ApplyToUnit(unit)
end

local EventFrame = CreateFrame("Frame", "MinimizerCastingBarEventFrame")
local CAST_EVENTS = {
    UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_STOP = true,
    UNIT_SPELLCAST_FAILED = true, UNIT_SPELLCAST_INTERRUPTED = true,
    UNIT_SPELLCAST_INTERRUPTIBLE = true, UNIT_SPELLCAST_NOT_INTERRUPTIBLE = true,
    UNIT_SPELLCAST_CHANNEL_START = true, UNIT_SPELLCAST_CHANNEL_STOP = true,
    UNIT_SPELLCAST_CHANNEL_UPDATE = true,
    UNIT_SPELLCAST_EMPOWER_START = true, UNIT_SPELLCAST_EMPOWER_STOP = true,
    UNIT_SPELLCAST_EMPOWER_UPDATE = true,
}
for event in pairs(CAST_EVENTS) do EventFrame:RegisterEvent(event) end
EventFrame:SetScript("OnEvent", function(_, event, unit)
    if unit and CAST_EVENTS[event] then CastingBar:OnCastEvent(unit, event) end
end)

local PulseFrame = CreateFrame("Frame")
PulseFrame:SetScript("OnUpdate", function(_, elapsed)
    CastingBar.pulse = (CastingBar.pulse or 0) + elapsed
    if CastingBar.pulse < 0.05 then return end
    CastingBar.pulse = 0
    local alpha = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(GetTime() * 8))
    for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
        local visuals = CastingBar:GetCastBar(nameplate)
        visuals = visuals and visuals.MinimizerCastVisuals
        if visuals and visuals.targetBorder:IsShown() then
            visuals.targetBorder:SetAlpha(alpha)
        end
    end
end)

Minimizer.Core.RegisterModule("CastingBar", CastingBar)
