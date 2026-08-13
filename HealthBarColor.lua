-- ============================================================================
-- Minimizer - HealthBarColor.lua
-- Colores de salud por peligro/tipo de enemigo. Este archivo no modifica
-- frames protegidos ni la gestión de nameplates de Blizzard.
-- ============================================================================

local _, Minimizer = ...
if not Minimizer or not Minimizer.Core then return end

local HealthBarColor = {}
Minimizer.HealthBarColor = HealthBarColor

-- Leyenda, de menor a superior. Focus tiene prioridad sobre cualquier tipo.
local COLORS = {
    trivial = { 0.00, 0.00, 0.00 }, -- Menores/esbirros/triviales: negro
    melee = { 1.00, 1.00, 1.00 }, -- Melee: blanco
    caster = { 0.20, 0.55, 1.00 }, -- Caster: azul
    boss = { 0.65, 0.25, 1.00 }, -- Boss: morado
    miniboss = { 0.65, 0.25, 1.00 }, -- Miniboss: morado
    focus = { 1.00, 0.90, 0.00 }, -- Focus: amarillo
}

local function IsSecretValue(value)
    return issecretvalue and issecretvalue(value)
end

local function IsTrivial(unit, classification)
    if IsSecretValue(classification) then
        return false
    end
    if classification == "trivial" or classification == "minus" then
        return true
    end

    local unitLevel = UnitEffectiveLevel(unit)
    local playerLevel = UnitEffectiveLevel("player")
    if IsSecretValue(unitLevel) or IsSecretValue(playerLevel) then
        return false
    end
    return type(unitLevel) == "number"
        and type(playerLevel) == "number"
        and unitLevel > 0
        and unitLevel <= playerLevel - 10
end

local function GetSuperiorKind(unit, classification)
    if IsSecretValue(classification) then
        return nil
    end

    -- "elite" no significa boss: es la clasificación general de la unidad.
    -- Solo estas señales representan la división superior indicada por el
    -- proyecto: boss o miniboss dentro del conjunto de élites.
    if classification == "worldboss" then
        return "boss"
    end
    if UnitIsLieutenant and UnitIsLieutenant(unit) == true then
        return "miniboss"
    end
    return nil
end

local function HasMana(unit)
    if UnitHasPowerType and Enum and Enum.PowerType and Enum.PowerType.Mana then
        local hasMana = UnitHasPowerType(unit, Enum.PowerType.Mana)
        return not IsSecretValue(hasMana) and hasMana == true
    end

    local powerType = UnitPowerType(unit)
    return not IsSecretValue(powerType) and powerType == 0
end

function HealthBarColor:GetEliteType(unit)
    local classification = UnitClassification(unit)
    if IsTrivial(unit, classification) then
        return "trivial"
    end

    local superiorKind = GetSuperiorKind(unit, classification)
    if superiorKind then
        return superiorKind
    end
    if HasMana(unit) then
        return "caster"
    end
    return "melee"
end

function HealthBarColor:GetKind(unit)
    if UnitIsUnit(unit, "focus") then
        return "focus"
    end
    return self:GetEliteType(unit)
end

function HealthBarColor:GetHealthBar(nameplate)
    local unitFrame = nameplate and (nameplate.UnitFrame or nameplate)
    return unitFrame and (unitFrame.healthBar or unitFrame.HealthBar)
end

function HealthBarColor:UpdateNamePlate(unit, nameplate)
    if not unit or not UnitExists(unit) then return end

    local healthBar = self:GetHealthBar(nameplate)
    if not healthBar or type(healthBar.SetStatusBarColor) ~= "function" then return end

    local kind = self:GetKind(unit)
    local color = COLORS[kind]
    healthBar:SetStatusBarColor(color[1], color[2], color[3])
    nameplate.MinimizerHealthBarColorKind = kind
end

function HealthBarColor:OnNamePlateRemoved(_, nameplate)
    -- El frame se reutiliza; no conservar estado de la unidad anterior.
    if nameplate then
        nameplate.MinimizerHealthBarColorKind = nil
    end
end

Minimizer.Core.RegisterModule("HealthBarColor", HealthBarColor)
