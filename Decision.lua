local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Decision = Minimizer.Decision or {}

local UnitExists = UnitExists
local UnitCanAttack = UnitCanAttack

function Minimizer.Decision.ShouldSimplifyUnit(unit, nameplate, snapshot)
    if not unit or not UnitExists(unit) then return false, "invalid" end

    if UnitIsUnit(unit, "target") then return false, "target" end
    if UnitIsUnit(unit, "focus") then return false, "focus" end

    if not UnitCanAttack("player", unit) then return false, "friendly" end

    local pct = MinimizerDB and MinimizerDB.simplifyPercent or 0
    if pct <= 0 then return false, "disabled" end

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

    local hasAggro = snapshot and snapshot.hasAggro
    if hasAggro == nil then hasAggro = Minimizer.Threat.ShouldUnsimplify(unit) end
    -- OJO: ShouldUnsimplify y PlayerHasAggro NO son la misma funcion (ver
    -- Threat.lua: ShouldUnsimplify tiene rama especial para tanks). No
    -- sustituyas ShouldUnsimplify por snapshot.hasAggro sin mas -- mantenlos
    -- separados. Este chequeo especifico sigue llamando a ShouldUnsimplify
    -- directamente, NO usa el snapshot para esto.
    if Minimizer.Threat.ShouldUnsimplify(unit) then
        return false, "temporal"
    end

    local hasAbsorb = snapshot and snapshot.hasAbsorb
    if hasAbsorb == nil then hasAbsorb = Minimizer.Absorb.HasAbsorb(unit, nameplate) end
    if hasAbsorb then
        return false, "temporal"
    end

    local isCasting, isUninterruptible
    if snapshot then
        isCasting, isUninterruptible = snapshot.isCasting, snapshot.isUninterruptible
    else
        isCasting, isUninterruptible = Minimizer.Cast.GetState(unit)
    end
    if isCasting then
        if isUninterruptible == true then
            -- Cast ininterrumpible: desimplificar TEMPORALMENTE solo mientras dure el cast.
            return false, "temporal"
        else
            -- Cast interrumpible o canal: unidad peligrosa de forma PERSISTENTE
            -- (en M+ cualquier inferior que castee es wipe potencial).
            return false, "no simp"
        end
    end

    return true, "simplify"
end
