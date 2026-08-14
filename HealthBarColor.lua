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
    -- En PvP dejamos la healthbar de Blizzard sin modificar.
    if Minimizer.Utils.IsPvPUnit(unit) then return end
    local healthBar = self:GetHealthBar(nameplate)
    if not healthBar or type(healthBar.SetStatusBarColor) ~= "function" then return end
    HookHealthBar(healthBar)
    
    local indicator = healthBar.totalAbsorbOverlay or healthBar.totalAbsorb
    if indicator then
        HookIndicator(indicator, healthBar)
    end

    -- Las nameplates se reutilizan; resetear el color persistente si cambia la unidad
    if nameplate.MinimizerHealthBarColorUnit ~= unit then
        nameplate.MinimizerHealthBarColorUnit = unit
        nameplate.MinimizerPersistentCastColorKind = nil
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

    local isCasting, uninterruptible, rawUninterruptible, isChanneling
    if snapshot then
        isCasting = snapshot.isCasting
        isChanneling = snapshot.isChanneling
        rawUninterruptible = snapshot.rawUninterruptible
        if rawUninterruptible == nil then rawUninterruptible = snapshot.isUninterruptible end
        if rawUninterruptible == nil then
            uninterruptible = false
        else
            if Minimizer and Minimizer.Utils and Minimizer.Utils.IsSecretValue and Minimizer.Utils.IsSecretValue(rawUninterruptible) then
                uninterruptible = nil
            else
                uninterruptible = (rawUninterruptible == true)
            end
        end
    else
        isCasting, uninterruptible, rawUninterruptible, isChanneling = Minimizer.Cast.GetState(unit)
    end
    if rawUninterruptible == nil then rawUninterruptible = false end
    if uninterruptible == nil then uninterruptible = false end

    local isActiveCastOrChannel = isCasting == true or isChanneling == true

    --[[
        LEYENDA M+ (NO MODIFICAR SIN PERMISO):
        Prioridad descendente — la primera regla que aplica gana:
          1. Focus    → amarillo, sin cambio de simplificacion.
          2. Aggro    → rojo gestionado por Blizzard, dessimp TEMPORAL.
          3. Shield   → rosa (absorb), dessimp TEMPORAL.
          4. Superior (boss/miniboss) casteando ininterrumpible → gris TEMPORAL.
          5. Inferior (cualquier no-superior) casteando interrumpible o canalizando
                      → verde PERSISTENTE (flag permanece tras el cast).
          6. Inferior casteando ininterrumpible → gris TEMPORAL (solo mientras castea).
        Los azules (caster/hasmana) NO siguen estas mismas reglas de cast, SOLO CAMBIA DE COLOR CON AGRO,FOCUS O SHIELD.
    ]]

    -- displayKind ya resuelve la prioridad focus > aggro > absorb > eliteType
    -- (calculado en Core.BuildSnapshot). Aqui solo leemos el resultado.
    local isSuperior = baseKind == "boss" or baseKind == "miniboss"
    -- 'Azules' (caster) no siguen las reglas de casteo; solo cambian por focus/aggro/absorb
    local isSpecial  = baseKind == "focus" or baseKind == "absorb" or baseKind == "aggro" or baseKind == "caster"

    if not isSpecial then
        if isSuperior then
            -- Regla 4: superior casteando/canalizando ininterrumpible -> gris TEMPORAL.
            -- Si la accion es interrumpible, el superior conserva su color base (morado).
            if isActiveCastOrChannel and uninterruptible then
                local c = COLORS.superiorUninterruptible
                r, g, b = c[1], c[2], c[3]
            end
        else
            -- Reglas 5 & 6: CUALQUIER inferior (melee, caster, trivial, etc.)
            if isActiveCastOrChannel then
                if uninterruptible then
                    -- Channel/cast ininterrumpible -> gris TEMPORAL. No tocar el flag persistente.
                    local c = COLORS.superiorUninterruptible
                    r, g, b = c[1], c[2], c[3]
                else
                    -- Channel/cast interrumpible -> verde PERSISTENTE.
                    nameplate.MinimizerPersistentCastColorKind = "castInterruptible"
                    local c = COLORS.castInterruptible
                    r, g, b = c[1], c[2], c[3]
                end
            elseif nameplate.MinimizerPersistentCastColorKind == "castInterruptible" then
                -- Ya casteo/canalizo algo interrumpible antes: mantener verde aunque ya no lo haga.
                local c = COLORS.castInterruptible
                r, g, b = c[1], c[2], c[3]
            end
        end
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
            if unit and not Minimizer.Utils.IsPvPUnit(unit) then
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
