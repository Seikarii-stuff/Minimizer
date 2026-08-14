-- Minimizer - HealthBarColor.lua
-- Healthbar colors applied directly to Blizzard's StatusBar.

local _, Minimizer = ...
if not Minimizer or not Minimizer.Core then return end

local HealthBarColor = {}
Minimizer.HealthBarColor = HealthBarColor

local COLORS = Minimizer.Constants.HealthColors

function HealthBarColor:GetEliteType(unit)
    return Minimizer.Classification.GetEliteType(unit)
end

function HealthBarColor:GetKind(unit, nameplate)
    if UnitIsUnit(unit, "focus") then return "focus" end
    -- El aggro total conserva prioridad sobre el rosa del absorb.
    -- La excepción de aggro se basa en la situación del jugador; la rama de
    -- tanque se decide en Threat.IsPlayerTank(), no por el color de Blizzard.
    -- Ser tanque sólo cambia la regla de simplificación. El rojo se reserva
    -- estrictamente para aggro sólido del jugador (situación 3).
    if Minimizer.Threat and Minimizer.Threat.PlayerHasAggro
        and Minimizer.Threat.PlayerHasAggro(unit) then
        return "aggro"
    end
    if Minimizer.Absorb and Minimizer.Absorb.HasAbsorb(unit, nameplate) then return "absorb" end
    return self:GetEliteType(unit)
end

function HealthBarColor:GetHealthBar(nameplate)
    local unitFrame = nameplate and (nameplate.UnitFrame or nameplate)
    return unitFrame and (unitFrame.healthBar or unitFrame.HealthBar)
end

local HookHealthBar
local HookIndicator

function HealthBarColor:UpdateNamePlate(unit, nameplate)
    if not unit or not UnitExists(unit) then return end
    local healthBar = self:GetHealthBar(nameplate)
    if not healthBar or type(healthBar.SetStatusBarColor) ~= "function" then return end
    HookHealthBar(healthBar)
    
    local indicator = healthBar.totalAbsorbOverlay or healthBar.totalAbsorb
    if indicator then
        HookIndicator(indicator, healthBar)
    end

    local baseKind = self:GetKind(unit, nameplate)
    nameplate.MinimizerHasAbsorb = baseKind == "absorb"
    local color = COLORS[baseKind] or COLORS.melee
    local r, g, b = color[1], color[2], color[3]
    local isCasting, _, uninterruptible = Minimizer.Cast.GetState(unit)
    if uninterruptible == nil then uninterruptible = false end
    local isSuperior = baseKind == "boss" or baseKind == "miniboss"

    -- Direct StatusBar coloring only. Secret interruptibility is resolved
    -- channel-by-channel in C-side, as documented by project.md.
    if isCasting and isSuperior and baseKind ~= "focus" and baseKind ~= "absorb" and baseKind ~= "aggro"
        and C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean then
        local castColor = COLORS.superiorUninterruptible
        r = C_CurveUtil.EvaluateColorValueFromBoolean(uninterruptible, castColor[1], color[1])
        g = C_CurveUtil.EvaluateColorValueFromBoolean(uninterruptible, castColor[2], color[2])
        b = C_CurveUtil.EvaluateColorValueFromBoolean(uninterruptible, castColor[3], color[3])
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

HookIndicator = function(indicator, healthBar)
    if not indicator or indicator.MinimizerAbsorbHooked then return end
    indicator.MinimizerAbsorbHooked = true
    if hooksecurefunc then
        local function triggerUpdate()
            if healthBar.MinimizerHealthColorApplying then return end
            local parent = healthBar:GetParent()
            local nameplate = parent and (parent.UnitFrame and parent or parent:GetParent())
            local unit = nameplate and (nameplate.namePlateUnitToken
                or (nameplate.UnitFrame and nameplate.UnitFrame.unit))
            if unit then
                if Minimizer and Minimizer.Core and Minimizer.Core.ApplyToUnit then
                    Minimizer.Core.ApplyToUnit(unit)
                else
                    HealthBarColor:UpdateNamePlate(unit, nameplate)
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
