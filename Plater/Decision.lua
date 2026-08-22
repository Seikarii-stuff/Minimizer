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
    if (Minimizer.Utils and Minimizer.Utils.IsFriendlyUnit and Minimizer.Utils.IsFriendlyUnit(unit))
       or (UnitCanAttack and not UnitCanAttack("player", unit)) then
        return false, "friendly"
    end

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

    if Minimizer.Decision.ShouldUnsimplify(unit, snapshot) then
        return false, "temporal"
    end

    local hasHadAbsorb = snapshot and snapshot.hasHadAbsorb
    if hasHadAbsorb == nil then
        local liveAbsorb = snapshot and snapshot.hasAbsorb
        if liveAbsorb == nil then
            liveAbsorb = Minimizer.Absorb and Minimizer.Absorb.HasAbsorb and Minimizer.Absorb.HasAbsorb(unit, nameplate)
        end
        hasHadAbsorb = (Minimizer.Absorb and Minimizer.Absorb.MarkSeen and Minimizer.Absorb.MarkSeen(unit, nameplate, liveAbsorb))
            or (Minimizer.Absorb and Minimizer.Absorb.MarkAbsorbSeen and Minimizer.Absorb.MarkAbsorbSeen(unit, nameplate, liveAbsorb))
            or false
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

function Minimizer.Decision.ShouldUnsimplify(unit, snapshot)
    if snapshot then
        local situation = snapshot.threatSituation
        if situation == nil then
            return snapshot.nilSince ~= nil and snapshot.inCombat
        end
        if snapshot.isPlayerTank then
            if not snapshot.inCombat then return false end
            if snapshot.otherTankAggro then return false end
            return situation == 0
        end
        return situation == 3
    end

    if not Minimizer.Threat or not Minimizer.Threat.GetThreatDetails then return false end
    local details = Minimizer.Threat.GetThreatDetails(unit)
    if not details then return false end

    local situation = details.situation
    if situation == nil then
        return details.nilSince ~= nil and Minimizer.Threat.IsInCombatWith(unit, details)
    end

    if Minimizer.Threat.IsPlayerTank and Minimizer.Threat.IsPlayerTank() then
        if not Minimizer.Threat.IsInCombatWith(unit, details) then return false end
        if details.otherTankAggro then return false end
        return situation == 0
    end
    return situation == 3
end

function Minimizer.Decision.ShouldLetBlizzardPaint(unit, snapshot)
    if snapshot then
        if not snapshot.isPlayerTank then return false end
        if snapshot.isNilSpecial then return false end
        if not snapshot.inCombat then return false end
        local situation = snapshot.threatSituation
        return (situation == 0 or situation == nil) and not snapshot.otherTankAggro
    end

    if not Minimizer.Threat or not Minimizer.Threat.IsPlayerTank or not Minimizer.Threat.IsPlayerTank() then return false end
    local isNilSpecial = Minimizer.Threat.IsNilSpecial and Minimizer.Threat.IsNilSpecial(unit)
    if isNilSpecial then return false end

    local details = Minimizer.Threat.GetThreatDetails and Minimizer.Threat.GetThreatDetails(unit)
    if not details or not Minimizer.Threat.IsInCombatWith or not Minimizer.Threat.IsInCombatWith(unit, details) then return false end

    local situation = details.situation
    return (situation == 0 or situation == nil) and not details.otherTankAggro
end
