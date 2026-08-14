local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Decision = Minimizer.Decision or {}

local UnitExists = UnitExists
local UnitCanAttack = UnitCanAttack

function Minimizer.Decision.ShouldSimplifyUnit(unit, nameplate)
    if not unit or not UnitExists(unit) then return false, "invalid" end

    if UnitIsUnit(unit, "target") then return false, "target" end
    if UnitIsUnit(unit, "focus") then return false, "focus" end

    if not UnitCanAttack("player", unit) then return false, "friendly" end

    local pct = MinimizerDB and MinimizerDB.simplifyPercent or 0
    if pct <= 0 then return false, "disabled" end

    if Minimizer.Classification and Minimizer.Classification.GetEliteType then
        local eliteType = Minimizer.Classification.GetEliteType(unit)
        if eliteType == "boss" or eliteType == "miniboss" or eliteType == "caster" then
            return false, "no simp"
        end
    end

    if Minimizer.Threat.ShouldUnsimplify(unit) then
        return false, "temporal"
    end
    if Minimizer.Absorb.HasAbsorb(unit, nameplate) then
        return false, "temporal"
    end

    local isCasting, isUninterruptible = Minimizer.Cast.GetState(unit)
    if isCasting then
        if isUninterruptible == false then
            return false, "persistent"
        else
            return false, "temporal"
        end
    end

    return true, "simplify"
end
