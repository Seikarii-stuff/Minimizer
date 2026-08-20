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

    local enabled
    if Minimizer.Config and Minimizer.Config.IsSimplifyEnabled then
        enabled = Minimizer.Config.IsSimplifyEnabled()
    else
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

    local eliteType = snapshot and snapshot.eliteType
    if eliteType == nil and Minimizer.Classification and Minimizer.Classification.GetEliteType then
        eliteType = Minimizer.Classification.GetEliteType(unit)
    end
    if eliteType == "boss" or eliteType == "miniboss" or eliteType == "caster" then
        return false, "no simp"
    end

    -- A persistent nil-special is a real unsimplify reason for every role.
    -- It becomes visible only after the threat state has remained nil for
    -- 1.0s and the additional 0.5s grace period has elapsed.
    if snapshot and snapshot.isNilSpecialReady then
        return false, "temporal"
    end

    if Minimizer.Threat.ShouldUnsimplify(unit) then
        return false, "temporal"
    end

    local hasHadAbsorb = snapshot and snapshot.hasHadAbsorb
    if hasHadAbsorb == nil then
        local liveAbsorb = snapshot and snapshot.hasAbsorb
        if liveAbsorb == nil then
            liveAbsorb = Minimizer.Absorb and Minimizer.Absorb.HasAbsorb and Minimizer.Absorb.HasAbsorb(unit, nameplate)
        end
        hasHadAbsorb = Minimizer.Core and Minimizer.Core.MarkAbsorbSeen and Minimizer.Core.MarkAbsorbSeen(unit, nameplate, liveAbsorb)
    end
    if hasHadAbsorb then return false, "no simp" end

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
            return false, "temporal"
        else
            return false, "no simp"
        end
    end

    return true, "simplify"
end
