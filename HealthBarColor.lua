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
    castInterruptible = { 0.10, 1.00, 0.10 }, -- Cast interrumpible persistente
    castUninterruptible = { 0.45, 0.45, 0.45 }, -- Cast ininterrumpible persistente
    dangerCast = { 0.28, 0.05, 0.38 }, -- Caster/superior en cast peligroso
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

function HealthBarColor:EnsureCastOverlays(healthBar)
    if healthBar.MinimizerCastOverlays then
        return healthBar.MinimizerCastOverlays
    end

    local gray = healthBar:CreateTexture(nil, "OVERLAY")
    gray:SetAllPoints(healthBar)
    gray:SetColorTexture(0.45, 0.45, 0.45, 1)
    gray:Hide()

    local danger = healthBar:CreateTexture(nil, "OVERLAY")
    danger:SetAllPoints(healthBar)
    danger:SetColorTexture(0.28, 0.05, 0.38, 1)
    danger:Hide()

    healthBar.MinimizerCastOverlays = { gray = gray, danger = danger }
    return healthBar.MinimizerCastOverlays
end

local function SetSecretAlpha(texture, value)
    if value == nil then
        texture:SetAlpha(0)
        return
    end
    if texture.SetAlphaFromBoolean then
        texture:SetAlphaFromBoolean(value)
    elseif not IsSecretValue(value) then
        texture:SetAlpha(value and 1 or 0)
    end
end

function HealthBarColor:UpdateNamePlate(unit, nameplate)
    if not unit or not UnitExists(unit) then return end

    -- Las nameplates se reutilizan; nunca arrastrar el color de otra unidad.
    if nameplate.MinimizerHealthBarColorUnit ~= unit then
        nameplate.MinimizerHealthBarColorUnit = unit
        nameplate.MinimizerPersistentCastColorKind = nil
    end

    local healthBar = self:GetHealthBar(nameplate)
    if not healthBar or type(healthBar.SetStatusBarColor) ~= "function" then return end

    local baseKind = self:GetKind(unit)
    local isCasting, _, uninterruptibleValue = Minimizer.Cast.GetState(unit)
    local overlays = self:EnsureCastOverlays(healthBar)
    overlays.gray:Hide()
    overlays.danger:Hide()

    local isCasterOrSuperior = baseKind == "caster"
        or baseKind == "boss"
        or baseKind == "miniboss"
    local kind = baseKind

    if baseKind == "focus" then
        -- El focus conserva siempre la prioridad amarilla.
    elseif isCasterOrSuperior then
        -- El overlay usa C-side SetAlphaFromBoolean para aceptar el booleano
        -- secreto sin probarlo en Lua. Sólo se muestra mientras casteando.
        if isCasting then
            overlays.danger:Show()
            SetSecretAlpha(overlays.danger, uninterruptibleValue)
        end
        nameplate.MinimizerPersistentCastColorKind = nil
    elseif isCasting then
        -- El color base verde es persistente. El overlay gris queda con la
        -- alpha calculada por C-side a partir de la interruptibilidad secreta.
        kind = "castInterruptible"
        nameplate.MinimizerPersistentCastColorKind = kind
        overlays.gray:Show()
        SetSecretAlpha(overlays.gray, uninterruptibleValue)
    elseif nameplate.MinimizerPersistentCastColorKind then
        kind = nameplate.MinimizerPersistentCastColorKind
        overlays.gray:Show()
    end

    local color = COLORS[kind] or COLORS.melee
    healthBar:SetStatusBarColor(color[1], color[2], color[3])
    nameplate.MinimizerHealthBarColorKind = kind
end

function HealthBarColor:OnNamePlateRemoved(_, nameplate)
    -- El frame se reutiliza; no conservar estado de la unidad anterior.
    if nameplate then
        nameplate.MinimizerHealthBarColorKind = nil
        nameplate.MinimizerHealthBarColorUnit = nil
        nameplate.MinimizerPersistentCastColorKind = nil
        local healthBar = self:GetHealthBar(nameplate)
        if healthBar and healthBar.MinimizerCastOverlays then
            healthBar.MinimizerCastOverlays.gray:Hide()
            healthBar.MinimizerCastOverlays.danger:Hide()
        end
    end
end

Minimizer.Core.RegisterModule("HealthBarColor", HealthBarColor)
