local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Snapshot = Minimizer.Snapshot or {}

local UnitIsUnit = UnitIsUnit
local UnitCanAttack = UnitCanAttack

local currentDepth = 0
local snapshotPool = {}

local function ResolveDisplayKind(unit, isFocus, isNilSpecial, hasAggro, hasHadAbsorb, eliteType)
    if isFocus then
        return "focus"
    elseif isNilSpecial then
        return "priority"
    elseif hasAggro then
        return "aggro"
    elseif hasHadAbsorb then
        return "absorb"
    else
        return eliteType
    end
end

Minimizer.Snapshot.ResolveDisplayKind = ResolveDisplayKind

function Minimizer.Snapshot.Build(unit, nameplate)
    currentDepth = currentDepth + 1
    if not snapshotPool[currentDepth] then
        snapshotPool[currentDepth] = {}
    end
    local s = snapshotPool[currentDepth]
    wipe(s)

    s.eliteType = Minimizer.Classification and Minimizer.Classification.GetEliteType and Minimizer.Classification.GetEliteType(unit)
    s.hasAbsorb = Minimizer.Absorb and Minimizer.Absorb.HasAbsorb and Minimizer.Absorb.HasAbsorb(unit, nameplate)
    s.hasHadAbsorb = (Minimizer.Absorb and Minimizer.Absorb.MarkSeen and Minimizer.Absorb.MarkSeen(unit, nameplate, s.hasAbsorb)) or false

    local details = Minimizer.Threat and Minimizer.Threat.GetThreatDetails and Minimizer.Threat.GetThreatDetails(unit)
    s.threatSituation = details and details.situation or nil
    s.otherTankAggro = details and details.otherTankAggro or false
    s.isNilSpecial = details and details.nilSpecial == true or false
    s.nilSince = details and details.nilSince or nil
    s.inCombat = (details and Minimizer.Threat and Minimizer.Threat.IsInCombatWith and Minimizer.Threat.IsInCombatWith(unit, details)) or false
    s.isPlayerTank = (Minimizer.Threat and Minimizer.Threat.IsPlayerTank and Minimizer.Threat.IsPlayerTank()) or false
    s.hasAggro = Minimizer.Threat and Minimizer.Threat.PlayerHasAggro and Minimizer.Threat.PlayerHasAggro(unit) or false

    s.isPvP = Minimizer.Utils and Minimizer.Utils.IsPvPUnit and Minimizer.Utils.IsPvPUnit(unit) or false
    s.isFriendly = (Minimizer.Utils and Minimizer.Utils.IsFriendlyUnit and Minimizer.Utils.IsFriendlyUnit(unit))
        or ((UnitCanAttack and not UnitCanAttack("player", unit)) or false)
    if Minimizer.Cast and Minimizer.Cast.GetState then
        s.isCasting, s.isUninterruptible, s.rawUninterruptible, s.isChanneling = Minimizer.Cast.GetState(unit)
    else
        s.isCasting, s.isUninterruptible, s.rawUninterruptible, s.isChanneling = false, false, false, false
    end

    s.displayKind = ResolveDisplayKind(unit, UnitIsUnit(unit, "focus"), s.isNilSpecial, s.hasAggro, s.hasHadAbsorb, s.eliteType)
    currentDepth = currentDepth - 1
    return s
end

function Minimizer.Snapshot.ComputeDisplayKind(unit, nameplate)
    if not unit then return nil end
    local isFocus = UnitIsUnit(unit, "focus")
    local isNilSpecial = Minimizer.Threat and Minimizer.Threat.IsNilSpecial and Minimizer.Threat.IsNilSpecial(unit) or false
    local hasAggro = Minimizer.Threat and Minimizer.Threat.PlayerHasAggro and Minimizer.Threat.PlayerHasAggro(unit) or false
    local hasAbsorbNow = Minimizer.Absorb and Minimizer.Absorb.HasAbsorb and Minimizer.Absorb.HasAbsorb(unit, nameplate)
    local hasHadAbsorb = (Minimizer.Absorb and Minimizer.Absorb.MarkSeen and Minimizer.Absorb.MarkSeen(unit, nameplate, hasAbsorbNow)) or false
    local eliteType = Minimizer.Classification and Minimizer.Classification.GetEliteType and Minimizer.Classification.GetEliteType(unit)
    return ResolveDisplayKind(unit, isFocus, isNilSpecial, hasAggro, hasHadAbsorb, eliteType)
end