-- Minimizer - HealthBarColor.lua
-- Healthbar colors applied directly to Blizzard's StatusBar.

local _, Minimizer = ...
if not Minimizer or not Minimizer.Core then return end

local HealthBarColor = {}
Minimizer.HealthBarColor = HealthBarColor

local COLORS = Minimizer.Constants.HealthColors

function HealthBarColor:GetHealthBar(nameplate)
    return Minimizer.Utils.GetHealthBar(nameplate)
end

local HookHealthBar
local HookIndicator

function HealthBarColor:UpdateNamePlate(unit, nameplate, snapshot)
    if not unit or not UnitExists(unit) then return end
    local healthBar = self:GetHealthBar(nameplate)
    if not healthBar or type(healthBar.SetStatusBarColor) ~= "function" then return end
    HookHealthBar(healthBar)
    
    local indicator = healthBar.totalAbsorbOverlay or healthBar.totalAbsorb
    if indicator then
        HookIndicator(indicator, healthBar)
    end

    -- Fallback defensivo: si por alguna razon se llama sin snapshot (no
    -- deberia pasar tras la Fase 3, pero por si acaso algun caller viejo
    -- queda suelto), recalcula localmente en vez de crashear.
    local baseKind
    if snapshot then
        baseKind = snapshot.displayKind
    else
        baseKind = Minimizer.Classification.GetEliteType(unit)
    end

    nameplate.MinimizerHasAbsorb = baseKind == "absorb"
    local color = COLORS[baseKind] or COLORS.melee
    local r, g, b = color[1], color[2], color[3]

    local isCasting, uninterruptible
    if snapshot then
        isCasting, uninterruptible = snapshot.isCasting, snapshot.isUninterruptible
    else
        isCasting, _, uninterruptible = Minimizer.Cast.GetState(unit)
    end
    if uninterruptible == nil then uninterruptible = false end
    local isSuperior = baseKind == "boss" or baseKind == "miniboss"

    if isCasting and isSuperior and baseKind ~= "focus" and baseKind ~= "absorb" and baseKind ~= "aggro" then
        local castColor = COLORS.superiorUninterruptible
        r, g, b = Minimizer.Utils.EvaluateColorRGB(uninterruptible, castColor, color)
    end

    Minimizer.Utils.GuardedCall(healthBar, "MinimizerHealthColorApplying", function()
        healthBar:SetStatusBarColor(r, g, b)
    end)
    nameplate.MinimizerHealthBarColorKind = baseKind
end

HookHealthBar = function(healthBar)
    if not healthBar or healthBar.MinimizerHealthColorHooked then return end
    healthBar.MinimizerHealthColorHooked = true
    if hooksecurefunc then
        hooksecurefunc(healthBar, "SetStatusBarColor", function()
            if healthBar.MinimizerHealthColorApplying then return end
            local nameplate = Minimizer.Utils.GetNameplateFromHealthBar(healthBar)
            local unit = Minimizer.Utils.GetUnitFromNameplate(nameplate)
            if unit then
                -- Sin snapshot disponible aqui (este hook se dispara fuera del pase
                -- normal de ApplyToUnit, p.ej. cuando Blizzard repinta la barra por
                -- su cuenta). UpdateNamePlate ya tiene fallback para snapshot=nil.
                HealthBarColor:UpdateNamePlate(unit, nameplate, nil)
            end
        end)
    end
end

HookIndicator = function(indicator, healthBar)
    if not indicator or indicator.MinimizerAbsorbHooked then return end
    indicator.MinimizerAbsorbHooked = true
    if hooksecurefunc then
        local function triggerUpdate()
            if healthBar.MinimizerHealthColorApplying then return end
            local nameplate = Minimizer.Utils.GetNameplateFromHealthBar(healthBar)
            local unit = Minimizer.Utils.GetUnitFromNameplate(nameplate)
            if unit then
                if Minimizer and Minimizer.Core and Minimizer.Core.ApplyToUnit then
                    Minimizer.Core.ApplyToUnit(unit)
                else
                    HealthBarColor:UpdateNamePlate(unit, nameplate, nil)
                end
            end
        end
        hooksecurefunc(indicator, "Show", triggerUpdate)
        hooksecurefunc(indicator, "Hide", triggerUpdate)
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
