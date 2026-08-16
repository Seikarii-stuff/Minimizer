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
    -- o si el token fue reciclado y la generacion del plate cambio.
    local currentGen = Minimizer.Core and Minimizer.Core.GetPlateGeneration and Minimizer.Core.GetPlateGeneration(unit) or 0
    if nameplate.MinimizerHealthBarColorGen ~= currentGen or nameplate.MinimizerHealthBarColorUnit ~= unit then
        nameplate.MinimizerHealthBarColorUnit = unit
        nameplate.MinimizerHealthBarColorGen = currentGen
        nameplate.MinimizerPersistentCastColor = nil
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

    local isCasting, isChanneling, safeUninterruptible, rawUninterruptible
    if snapshot then
        isCasting = snapshot.isCasting
        isChanneling = snapshot.isChanneling
        safeUninterruptible = snapshot.isUninterruptible -- nil | bool (NUNCA secreto)
        rawUninterruptible = snapshot.rawUninterruptible   -- posible secreto: SOLO para pasar a Evaluate*
    else
        isCasting, safeUninterruptible, rawUninterruptible, isChanneling = Minimizer.Cast.GetState(unit)
    end
    -- rawUninterruptible SOLO se pasa a EvaluateColorRGB (sink directo).
    -- NUNCA se compara ni se le aplica EvaluateBoolean()==N: ambas formas de
    -- "leer" un secreto siguen devolviendo un valor tainted y Lua revienta
    -- (attempt to compare ... tainted) en cuanto se intenta un if/== sobre
    -- ese resultado. Ver seccion "Persistent Green Fix (v2)" en el README.

    local isActiveCastOrChannel = isCasting == true or isChanneling == true

    --[[
        LEYENDA M+ (v2 -- ver README para el porque del cambio):
        Prioridad descendente — la primera regla que aplica gana:
          1. Focus    → amarillo, sin cambio de simplificacion.
          2. Aggro    → rojo gestionado por Blizzard, dessimp TEMPORAL.
          3. Shield   → rosa (absorb), dessimp TEMPORAL.
          4. Superior (boss/miniboss) → SIEMPRE morado, NUNCA cambia de color
                      por cast/channel (DEPRECATED desde v2: antes se ponia
                      gris temporal si el cast era ininterrumpible; se quito
                      porque forzaba a comparar un booleano potencialmente
                      secreto y ademas ya es obvio en pantalla cuando un
                      superior esta casteando). La desimplificacion SIGUE
                      siendo "no simp" persistente para superiores, eso no
                      cambia -- solo se toca el color.
          5. Inferior (cualquier no-superior) casteando interrumpible o canalizando
                      → verde PERSISTENTE (el color persiste tal y como salio
                      del ultimo EvaluateColorRGB, ver Utils mas abajo).
          6. Inferior casteando ininterrumpible → gris, TAMBIEN PERSISTENTE
                      en color (ver nota "Cambio de contrato" mas abajo);
                      la DESIMPLIFICACION sigue siendo TEMPORAL para este caso
                      (vuelve a poder simplificarse en cuanto termina el cast).
        Los azules (caster/hasmana) NO siguen estas mismas reglas de cast, SOLO CAMBIA DE COLOR CON AGRO,FOCUS O SHIELD.

        NOTA -- Cambio de contrato de "persistente" para el COLOR (v2):
        Antes solo el verde persistia (via un flag "kind"); el gris volvia al
        color base del bicho al terminar el cast. Eso obligaba a decidir en
        Lua "¿el ultimo cast fue interrumpible o no?" comparando un valor que
        casi siempre llega como secreto -> de ahi el bug historico donde un
        bicho que SOLO casteaba gris terminaba pintado de verde persistente.
        Ahora el color que se persiste es EXACTAMENTE el que ya se renderizo
        (gris o verde, lo que haya calculado EvaluateColorRGB), sin comparar
        nada. Consecuencia aceptada: el gris tambien queda persistente en el
        COLOR de la barra (antes era temporal). La DESIMPLIFICACION del gris
        sigue siendo temporal (eso vive en Decision.lua, sin cambios) -- solo
        el color de la barra se queda pegado hasta que el bicho vuelva a
        castear algo o desaparezca la nameplate.
    ]]

    -- displayKind ya resuelve la prioridad focus > aggro > absorb > eliteType
    -- (calculado en Core.BuildSnapshot). Aqui solo leemos el resultado.
    local isSuperior = baseKind == "boss" or baseKind == "miniboss"
    -- 'Azules' (caster) no siguen las reglas de casteo; solo cambian por focus/aggro/absorb
    local isSpecial  = baseKind == "focus" or baseKind == "absorb" or baseKind == "aggro" or baseKind == "caster"

    if not isSpecial and not isSuperior then
        -- Regla 5 & 6: CUALQUIER inferior (melee, caster ya excluido arriba
        -- por isSpecial, trivial, etc.)
        if isActiveCastOrChannel then
                -- Resolver color usando rawUninterruptible COMO SINK (no comparar secretos).
                if safeUninterruptible == true then
                    r, g, b = COLORS.superiorUninterruptible[1], COLORS.superiorUninterruptible[2], COLORS.superiorUninterruptible[3]
                else
                    r, g, b = Minimizer.Utils.EvaluateColorRGB(rawUninterruptible, COLORS.superiorUninterruptible, COLORS.castInterruptible)
                end
                -- Persistir siempre el color que ya se aplicó (verde o gris). No
                -- dependemos de comparar el valor secreto: guardamos el RGB final.
                nameplate.MinimizerPersistentCastColor = nameplate.MinimizerPersistentCastColor or {}
                local p = nameplate.MinimizerPersistentCastColor
                p[1], p[2], p[3] = r, g, b
                -- Solo el "kind" mantiene semántica adicional cuando sabemos que
                -- era explícitamente interruptible (safeUninterruptible == false).
                if safeUninterruptible == false then
                    nameplate.MinimizerPersistentCastColorKind = "castInterruptible"
                else
                    nameplate.MinimizerPersistentCastColorKind = nil
                end
        elseif nameplate.MinimizerPersistentCastColor then
            local p = nameplate.MinimizerPersistentCastColor
            r, g, b = p[1], p[2], p[3]
        else
            nameplate.MinimizerPersistentCastColorKind = nil
        end
    end
    -- isSuperior: sin rama de color por cast/channel. Se queda con el color
    -- base (COLORS.boss / COLORS.miniboss) siempre, cast o no. Ver nota
    -- "DEPRECATED desde v2" arriba.

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
        nameplate.MinimizerHealthBarColorGen = nil
        nameplate.MinimizerPersistentCastColor = nil
        nameplate.MinimizerPersistentCastColorKind = nil
        nameplate.MinimizerHasAbsorb = nil
    end
end

Minimizer.Core.RegisterModule("HealthBarColor", HealthBarColor)