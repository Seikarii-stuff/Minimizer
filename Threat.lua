local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Threat = Minimizer.Threat or {}
Minimizer.Threat.tankTokens = Minimizer.Threat.tankTokens or {}

local UnitExists = UnitExists
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitThreatSituation = UnitThreatSituation
local UnitAffectingCombat = UnitAffectingCombat
local UnitInParty = UnitInParty
local wipe = wipe
local ipairs = ipairs
local IsInRaid = IsInRaid
local IsInGroup = IsInGroup
local GetSpecialization = GetSpecialization
local GetSpecializationRole = GetSpecializationRole
local C_SpecializationInfo = C_SpecializationInfo
local CreateFrame = CreateFrame

local playerTankCache
local playerTankCacheValid = false

function Minimizer.Threat.RefreshTankTokens()
    local tokens = Minimizer.Threat.tankTokens
    wipe(tokens)

    local prefix, count
    if IsInRaid and IsInRaid() then
        prefix, count = "raid", 40
    elseif IsInGroup and IsInGroup() then
        prefix, count = "party", 4
    else
        return
    end

    for index = 1, count do
        local token = prefix .. index
        if UnitExists(token) and UnitGroupRolesAssigned(token) == "TANK" then
            tokens[#tokens + 1] = token
        end
    end
end

function Minimizer.Threat.RefreshPlayerTankCache()
    local isTank = false
    if UnitGroupRolesAssigned and UnitGroupRolesAssigned("player") == "TANK" then
        isTank = true
    else
        local specialization = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization
            and C_SpecializationInfo.GetSpecialization()
        if specialization and C_SpecializationInfo.GetSpecializationInfo then
            local _, _, _, _, role = C_SpecializationInfo.GetSpecializationInfo(specialization)
            isTank = role == "TANK"
        elseif GetSpecialization and GetSpecializationRole then
            specialization = GetSpecialization()
            isTank = specialization ~= nil and GetSpecializationRole(specialization) == "TANK"
        end
    end
    playerTankCache = isTank
    playerTankCacheValid = true
    return playerTankCache
end

function Minimizer.Threat.InvalidatePlayerTankCache()
    playerTankCache = nil
    playerTankCacheValid = false
end

function Minimizer.Threat.IsPlayerTank()
    if playerTankCacheValid then
        return playerTankCache
    end
    return Minimizer.Threat.RefreshPlayerTankCache()
end

-- Keep Blizzard threat values opaque. This mirrors Platynator's cache: the
-- UnitThreatSituation result is stored unchanged and only compared with
-- literal threat states. Never coerce it with arithmetic or relational
-- operators because Midnight can expose secret threat-state values.
function Minimizer.Threat.GetThreatDetails(unit)
    if not unit or not UnitExists(unit) then return nil end

    local cacheKey = "threat:details"
    if Minimizer.Cache and Minimizer.Cache.GetUnitKeyWithGeneration then
        local cached = Minimizer.Cache.GetUnitKeyWithGeneration(unit, cacheKey)
        if cached ~= nil then
            return cached
        end
    end

    local result = {
        situation = UnitThreatSituation("player", unit),
        otherTankAggro = false,
    }

    -- Match Platynator: the off-tank check is only meaningful when we are not
    -- already in states 2/3. Equality checks are secret-safe.
    if result.situation ~= 3 and result.situation ~= 2 and Minimizer.Threat.IsPlayerTank() then
        for _, tankUnit in ipairs(Minimizer.Threat.tankTokens) do
            if UnitThreatSituation(tankUnit, unit) == 3 then
                result.otherTankAggro = true
                break
            end
        end
    end

    if Minimizer.Cache and Minimizer.Cache.SetUnitKeyWithGeneration then
        Minimizer.Cache.SetUnitKeyWithGeneration(unit, cacheKey, result)
    end
    return result
end

function Minimizer.Threat.Invalidate(unit)
    if not unit then return end
    if Minimizer.Cache and Minimizer.Cache.InvalidateUnit then
        Minimizer.Cache.InvalidateUnit(unit, "threat")
    end
end

-- Platynator deliberately treats combat as a polled state instead of relying
-- on a single combat event. Threat itself can be the evidence that a unit is
-- in a combat relationship even when UnitAffectingCombat() is not yet true.
-- This matters for newly spawned adds and boss mechanics.
function Minimizer.Threat.IsInCombatWith(unit, threatDetails)
    if not unit or not UnitExists(unit) then return false end

    if UnitAffectingCombat(unit) then
        return true
    end

    local details = threatDetails or Minimizer.Threat.GetThreatDetails(unit)
    if details and details.situation ~= nil then
        return true
    end

    local target = unit .. "target"
    return UnitInParty and UnitInParty(target) == true or false
end

function Minimizer.Threat.GetSituation(unit, source)
    if not unit or not UnitExists(unit) then return nil end
    source = source or "player"

    local cacheKey = "threat:" .. source
    if Minimizer.Cache and Minimizer.Cache.GetUnitKeyWithGeneration then
        local cached = Minimizer.Cache.GetUnitKeyWithGeneration(unit, cacheKey)
        if cached ~= nil then return cached end
    end

    local situation = UnitThreatSituation(source, unit)
    if Minimizer.Cache and Minimizer.Cache.SetUnitKeyWithGeneration then
        Minimizer.Cache.SetUnitKeyWithGeneration(unit, cacheKey, situation)
    end
    return situation
end

function Minimizer.Threat.PlayerHasAggro(unit)
    if Minimizer.Threat.IsPlayerTank() then
        local threatDetails = Minimizer.Threat.GetThreatDetails(unit)
        if not threatDetails then return false end

        -- Do not hide a threat state merely because UnitAffectingCombat() is
        -- temporarily false during a spawn/encounter transition. Platynator's
        -- combat predicate considers threat itself evidence of combat.
        if not Minimizer.Threat.IsInCombatWith(unit, threatDetails) then
            return false
        end

        if threatDetails.otherTankAggro then
            return false
        end

        local situation = threatDetails.situation
        return situation == nil or situation == 0 or situation == 1 or situation == 2
    end

    return Minimizer.Threat.GetSituation(unit, "player") == 3
end

function Minimizer.Threat.GetTankSituation(unit)
    local details = Minimizer.Threat.GetThreatDetails(unit)
    return details and details.situation or nil
end

function Minimizer.Threat.ShouldLetBlizzardPaint(unit)
    if not Minimizer.Threat.IsPlayerTank() then
        return false
    end

    local details = Minimizer.Threat.GetThreatDetails(unit)
    if not details or not Minimizer.Threat.IsInCombatWith(unit, details) then
        return false
    end

    local situation = details.situation
    return (situation == 0 or situation == nil) and not details.otherTankAggro
end

function Minimizer.Threat.ShouldUnsimplify(unit)
    if Minimizer.Threat.IsPlayerTank() then
        local details = Minimizer.Threat.GetThreatDetails(unit)
        if not details or not Minimizer.Threat.IsInCombatWith(unit, details) then
            return false
        end
        if details.otherTankAggro then return false end

        local situation = details.situation
        return situation == nil or situation == 0
    end
    return Minimizer.Threat.GetSituation(unit, "player") == 3
end

-- --------------------------------------------------------------------------
-- Platynator-style polling safety net
-- --------------------------------------------------------------------------
-- Threat events are the primary path. Combat is polled because there is no
-- single reliable per-nameplate combat event that covers all of the spawn /
-- encounter transitions we care about. The cadence mirrors Platynator's cache:
-- approximately four monitored units per second, distributed across the
-- active nameplates. A poll only repaints when threat/combat actually changes.
local monitorFrame
local monitorElapsed = 0
local monitorStep = 1
local monitorUnits = {}
local monitorCount = 0
local monitorState = {}

local function IsNameplateToken(unit)
    return type(unit) == "string" and unit:match("^nameplate%d+$") ~= nil
end

local function RebuildMonitorUnits()
    wipe(monitorUnits)
    monitorCount = 0
    if not Minimizer.ActiveNameplates then return end
    for unit in pairs(Minimizer.ActiveNameplates) do
        if IsNameplateToken(unit) then
            monitorCount = monitorCount + 1
            monitorUnits[monitorCount] = unit
        end
    end
    if monitorStep > monitorCount then
        monitorStep = 1
    end
end

function Minimizer.Threat.ForgetUnit(unit)
    if unit then
        monitorState[unit] = nil
        -- Rebuild is intentionally deferred to the next polling slice. The
        -- active-nameplate registry is authoritative and avoids doing table
        -- surgery inside Blizzard's nameplate removal callbacks.
    end
end

local function ProcessMonitoredUnit(unit)
    if not IsNameplateToken(unit) then return end
    if not Minimizer.ActiveNameplates or not Minimizer.ActiveNameplates[unit] then
        monitorState[unit] = nil
        return
    end
    if not UnitExists(unit) then return end

    -- The event path normally invalidates this. The polling path must do so
    -- itself, otherwise a missed event would only observe the stale cache.
    Minimizer.Threat.Invalidate(unit)
    local details = Minimizer.Threat.GetThreatDetails(unit)
    local combat = Minimizer.Threat.IsInCombatWith(unit, details)
    local generation = Minimizer.Core and Minimizer.Core.GetPlateGeneration
        and Minimizer.Core.GetPlateGeneration(unit) or 0
    local previous = monitorState[unit]

    local changed = not previous
        or previous.generation ~= generation
        or previous.situation ~= details.situation
        or previous.otherTankAggro ~= details.otherTankAggro
        or previous.combat ~= combat

    monitorState[unit] = {
        generation = generation,
        situation = details.situation,
        otherTankAggro = details.otherTankAggro,
        combat = combat,
    }

    if changed and Minimizer.Core and Minimizer.Core.ApplyToUnit then
        Minimizer.Core.ApplyToUnit(unit)
    end
end

function Minimizer.Threat.StartMonitor()
    if monitorFrame then return end

    RebuildMonitorUnits()
    monitorFrame = CreateFrame("Frame")
    monitorFrame:SetScript("OnUpdate", function(_, elapsed)
        RebuildMonitorUnits()
        if monitorCount == 0 then
            monitorElapsed = 0
            return
        end

        monitorElapsed = monitorElapsed + elapsed
        -- Platynator's scheduler processes roughly four units per second,
        -- regardless of whether 5 or 80 plates are visible.
        local interval = 0.25 / monitorCount
        if monitorElapsed < interval then return end
        monitorElapsed = monitorElapsed - interval

        if monitorStep > monitorCount then monitorStep = 1 end
        local unit = monitorUnits[monitorStep]
        monitorStep = monitorStep + 1
        ProcessMonitoredUnit(unit)
    end)
end
