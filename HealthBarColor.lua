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

    local isCasting, rawUninterruptible, isChanneling
    if snapshot then
        isCasting = snapshot.isCasting
        isChanneling = snapshot.isChanneling
        rawUninterruptible = snapshot.rawUninterruptible
        if not Minimizer.Utils.IsSecretValue(rawUninterruptible) and rawUninterruptible == nil then
            rawUninterruptible = snapshot.isUninterruptible
        end
    else
        isCasting, _, rawUninterruptible, isChanneling = Minimizer.Cast.GetState(unit)
    end
    -- rawUninterruptible NUNCA se compara directamente (puede ser un valor
    -- secreto en Midnight/Secrets). Solo se pasa a EvaluateColorRGB/
    -- EvaluateBoolean, que lo resuelven vía C_CurveUtil (C-side) sin taintear
    -- el addon. No forzamos un default aquí: los helpers manejan nil/secret.

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
            -- Regla 4: superior casteando/canalizando -> gris TEMPORAL si es
            -- ininterrumpible, si no conserva su color base (morado). Nunca persiste.
            if isActiveCastOrChannel then
                r, g, b = Minimizer.Utils.EvaluateColorRGB(rawUninterruptible, COLORS.superiorUninterruptible, {r, g, b})
            end
        else
            -- Reglas 5 & 6: CUALQUIER inferior (melee, caster, trivial, etc.)
            if isActiveCastOrChannel then
                r, g, b = Minimizer.Utils.EvaluateColorRGB(rawUninterruptible, COLORS.superiorUninterruptible, COLORS.castInterruptible)

                -- Decidir si el flag persistente (verde) debe quedar marcado.
                -- NUNCA se compara rawUninterruptible directamente: se resuelve
                -- primero a un numero plano (0/1) via el curve evaluator de
                -- Blizzard (misma API C-side que EvaluateColorRGB, ver Utils.lua
                -- EvaluateBoolean), y SOLO ese numero ya resuelto (no secreto)
                -- se compara con ==. Esto es el mismo patron que usa Platynator
                -- en Cache.lua (hasUninterruptableCasted) y Colors.lua
                -- (PushCondition con el valor crudo, nunca un if directo).
                local wasInterruptible = Minimizer.Utils.EvaluateBoolean(rawUninterruptible, 0, 1)
                if wasInterruptible == 1 then
                    nameplate.MinimizerPersistentCastColorKind = "castInterruptible"
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
