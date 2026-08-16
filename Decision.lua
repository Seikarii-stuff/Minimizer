local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Decision = Minimizer.Decision or {}

local UnitExists = UnitExists
local UnitCanAttack = UnitCanAttack
local UnitIsUnit = UnitIsUnit

function Minimizer.Decision.ShouldSimplifyUnit(unit, nameplate, snapshot)
    if not unit or not UnitExists(unit) then return false, "invalid" end

    if UnitIsUnit(unit, "target") then return false, "target" end
    if UnitIsUnit(unit, "focus") then return false, "focus" end

    if not UnitCanAttack("player", unit) then return false, "friendly" end

    -- Simplify toggle: delegar la lógica al módulo de configuración.
    local enabled
    if Minimizer.Config and Minimizer.Config.IsSimplifyEnabled then
        enabled = Minimizer.Config.IsSimplifyEnabled()
    else
        -- Fallback seguro al comportamiento legacy si por alguna razón la
        -- función no existe (entornos de test aislados).
        if MinimizerDB == nil then
            enabled = true
        else
            if MinimizerDB.simplifyEnabled == nil then
                local legacy = tonumber(MinimizerDB.simplifyPercent)
                enabled = (legacy == nil) or (legacy > 0)
            else
                enabled = MinimizerDB.simplifyEnabled == true
            end
        end
    end
    if not enabled then return false, "disabled" end

    -- snapshot es opcional por compatibilidad hacia atras (p.ej. en tests que
    -- llaman a esta funcion directamente sin pasar snapshot); si no viene, se
    -- calcula localmente como fallback.
    local eliteType = snapshot and snapshot.eliteType
    if eliteType == nil and Minimizer.Classification and Minimizer.Classification.GetEliteType then
        eliteType = Minimizer.Classification.GetEliteType(unit)
    end
    if eliteType == "boss" or eliteType == "miniboss" or eliteType == "caster" then
        return false, "no simp"
    end

    -- OJO: ShouldUnsimplify y PlayerHasAggro NO son la misma funcion (ver
    -- Threat.lua: ShouldUnsimplify tiene rama especial para tanks). No
    -- sustituyas ShouldUnsimplify por snapshot.hasAggro sin mas -- mantenlos
    -- separados. Este chequeo especifico sigue llamando a ShouldUnsimplify
    -- directamente, NO usa el snapshot para esto.
    if Minimizer.Threat.ShouldUnsimplify(unit) then
        return false, "temporal"
    end

    -- Temporada de shields: la dessimplificacion por escudo ahora es
    -- PERSISTENTE (igual que boss/miniboss), no solo "mientras el
    -- indicador este visible". Usamos snapshot.hasHadAbsorb (persistente,
    -- gen-gated en Core.MarkAbsorbSeen), NO snapshot.hasAbsorb (vivo).
    local hasHadAbsorb = snapshot and snapshot.hasHadAbsorb
    if hasHadAbsorb == nil then
        local liveAbsorb = snapshot and snapshot.hasAbsorb
        if liveAbsorb == nil then
            liveAbsorb = Minimizer.Absorb and Minimizer.Absorb.HasAbsorb and Minimizer.Absorb.HasAbsorb(unit, nameplate)
        end
        hasHadAbsorb = Minimizer.Core and Minimizer.Core.MarkAbsorbSeen and Minimizer.Core.MarkAbsorbSeen(unit, nameplate, liveAbsorb)
    end
    if hasHadAbsorb then
        return false, "no simp"
    end

    local isCasting, isUninterruptible, _, isChanneling
    if snapshot then
        isCasting = snapshot.isCasting
        isUninterruptible = snapshot.isUninterruptible
        isChanneling = snapshot.isChanneling
    else
        isCasting, isUninterruptible, _, isChanneling = Minimizer.Cast.GetState(unit)
    end

    if isCasting or isChanneling then
        if isUninterruptible == true then
            -- Cast/channel ininterrumpible: desimplificar TEMPORALMENTE solo mientras dure la accion.
            return false, "temporal"
        else
            -- Cast/channel interrumpible: unidad peligrosa de forma PERSISTENTE
            -- (en M+ cualquier inferior que castee o canalice es wipe potencial).
            return false, "no simp"
        end
    end

    return true, "simplify"
end
