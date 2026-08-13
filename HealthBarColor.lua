-- Minimizer - HealthBarColor.lua
-- Healthbar colors applied directly to Blizzard's StatusBar.

local _, Minimizer = ...
if not Minimizer or not Minimizer.Core then return end

local HealthBarColor = {}
Minimizer.HealthBarColor = HealthBarColor

local COLORS = {
    trivial = { 0.00, 0.00, 0.00 },
    melee = { 1.00, 1.00, 1.00 },
    caster = { 0.20, 0.55, 1.00 },
    boss = { 0.65, 0.25, 1.00 },
    miniboss = { 0.65, 0.25, 1.00 },
    focus = { 1.00, 0.90, 0.00 },
    absorb = { 1.00, 0.45, 0.75 }, -- Mob con absorb
    aggro = { 1.00, 0.00, 0.00 }, -- Aggro total: color nativo rojo
    castInterruptible = { 0.10, 1.00, 0.10 },
    dangerCast = { 0.28, 0.05, 0.38 },
}

local function IsSecretValue(value)
    return issecretvalue and issecretvalue(value)
end

local function IsTrivial(unit, classification)
    if IsSecretValue(classification) then return false end
    if classification == "trivial" or classification == "minus" then return true end
    local level = UnitEffectiveLevel(unit)
    local playerLevel = UnitEffectiveLevel("player")
    if IsSecretValue(level) or IsSecretValue(playerLevel) then return false end
    return type(level) == "number" and type(playerLevel) == "number"
        and level > 0 and level <= playerLevel - 10
end

local function GetSuperiorKind(unit, classification)
    if IsSecretValue(classification) then return nil end
    if classification == "worldboss" then return "boss" end
    if UnitIsLieutenant and UnitIsLieutenant(unit) == true then return "miniboss" end
    return nil
end

local function HasMana(unit)
    if UnitHasPowerType and Enum and Enum.PowerType and Enum.PowerType.Mana then
        local value = UnitHasPowerType(unit, Enum.PowerType.Mana)
        return not IsSecretValue(value) and value == true
    end
    local powerType = UnitPowerType(unit)
    return not IsSecretValue(powerType) and powerType == 0
end

function HealthBarColor:GetEliteType(unit)
    local classification = UnitClassification(unit)
    if IsTrivial(unit, classification) then return "trivial" end
    local superior = GetSuperiorKind(unit, classification)
    if superior then return superior end
    if HasMana(unit) then return "caster" end
    return "melee"
end

function HealthBarColor:GetKind(unit, nameplate)
    if UnitIsUnit(unit, "focus") then return "focus" end
    -- El aggro total conserva prioridad sobre el rosa del absorb.
    -- La excepción de aggro se basa en la situación del jugador; la rama de
    -- tanque se decide en Threat.IsPlayerTank(), no por el color de Blizzard.
    local threat = Minimizer.Threat and Minimizer.Threat.GetSituation
        and Minimizer.Threat.GetSituation(unit, "player")
    if threat == 3 then return "aggro" end
    if Minimizer.Absorb and Minimizer.Absorb.HasAbsorb(unit, nameplate) then return "absorb" end
    return self:GetEliteType(unit)
end

function HealthBarColor:GetHealthBar(nameplate)
    local unitFrame = nameplate and (nameplate.UnitFrame or nameplate)
    return unitFrame and (unitFrame.healthBar or unitFrame.HealthBar)
end

local HookHealthBar

function HealthBarColor:UpdateNamePlate(unit, nameplate)
    if not unit or not UnitExists(unit) then return end
    local healthBar = self:GetHealthBar(nameplate)
    if not healthBar or type(healthBar.SetStatusBarColor) ~= "function" then return end
    HookHealthBar(healthBar)
    local baseKind = self:GetKind(unit, nameplate)
    nameplate.MinimizerHasAbsorb = baseKind == "absorb"
    local color = COLORS[baseKind] or COLORS.melee
    local r, g, b = color[1], color[2], color[3]
    local isCasting, _, uninterruptible = Minimizer.Cast.GetState(unit)
    if uninterruptible == nil then uninterruptible = false end
    local isSuperior = baseKind == "caster" or baseKind == "boss" or baseKind == "miniboss"

    -- Direct StatusBar coloring only. Secret interruptibility is resolved
    -- channel-by-channel in C-side, as documented by project.md.
    if isCasting and baseKind ~= "focus" and baseKind ~= "absorb" and baseKind ~= "aggro"
        and C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean then
        local castColor = isSuperior and COLORS.dangerCast or COLORS.castInterruptible
        r = C_CurveUtil.EvaluateColorValueFromBoolean(uninterruptible, color[1], castColor[1])
        g = C_CurveUtil.EvaluateColorValueFromBoolean(uninterruptible, color[2], castColor[2])
        b = C_CurveUtil.EvaluateColorValueFromBoolean(uninterruptible, color[3], castColor[3])
    end

    healthBar.MinimizerHealthColorApplying = true
    healthBar:SetStatusBarColor(r, g, b)
    healthBar.MinimizerHealthColorApplying = nil
    nameplate.MinimizerHealthBarColorKind = baseKind
end

-- Blizzard puede volver a aplicar su color rojo al actualizar la unidad.
-- Reentrancia protegida: el hook solo reevalúa el color final del módulo.
HookHealthBar = function(healthBar)
    if not healthBar or healthBar.MinimizerHealthColorHooked then return end
    healthBar.MinimizerHealthColorHooked = true
    if hooksecurefunc then
        hooksecurefunc(healthBar, "SetStatusBarColor", function()
            if healthBar.MinimizerHealthColorApplying then return end
            local parent = healthBar:GetParent()
            local nameplate = parent and (parent.UnitFrame and parent or parent:GetParent())
            local unit = nameplate and (nameplate.namePlateUnitToken
                or (nameplate.UnitFrame and nameplate.UnitFrame.unit))
            if unit then
                HealthBarColor:UpdateNamePlate(unit, nameplate)
            end
        end)
    end
end

function HealthBarColor:OnNamePlateRemoved(_, nameplate)
    if nameplate then
        nameplate.MinimizerHealthBarColorKind = nil
        nameplate.MinimizerHealthBarColorUnit = nil
        nameplate.MinimizerPersistentCastColorKind = nil
        nameplate.MinimizerHasAbsorb = nil
    end
end

Minimizer.Core.RegisterModule("HealthBarColor", HealthBarColor)
