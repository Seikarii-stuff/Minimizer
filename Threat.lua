local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Threat = Minimizer.Threat or {}
Minimizer.Threat.tankTokens = Minimizer.Threat.tankTokens or {}

local UnitExists = UnitExists
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitThreatSituation = UnitThreatSituation
local UnitAffectingCombat = UnitAffectingCombat
local wipe = wipe
local ipairs = ipairs
local IsInRaid = IsInRaid
local IsInGroup = IsInGroup
local GetSpecialization = GetSpecialization
local GetSpecializationRole = GetSpecializationRole
local C_SpecializationInfo = C_SpecializationInfo

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

-- This deliberately follows Platynator's threat representation:
-- keep UnitThreatSituation's value as a VALUE inside a normal table and only
-- access it through literal keys. Never use a threat result as a table key and
-- never turn a secret threat value into a Lua number by filtering it.
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

    if result.situation ~= 3 and Minimizer.Threat.IsPlayerTank() then
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

-- Kept for callers that need the player's raw threat situation. The secret
-- value is returned unchanged, exactly like Platynator's Cache:Get(...).situation.
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
        if not UnitAffectingCombat(unit) then return false end

        local threatDetails = Minimizer.Threat.GetThreatDetails(unit)
        if not threatDetails then return false end

        -- If another tank owns the mob, do not manufacture an aggro state in
        -- Minimizer. This is the off-tank path used by Platynator.
        if threatDetails.otherTankAggro then
            return false
        end

        local situation = threatDetails.situation
        return situation == nil or situation < 3
    end

    return Minimizer.Threat.GetSituation(unit, "player") == 3
end

-- Compatibility helper. It returns the player's situation unless another
-- tank has definite aggro, in which case the caller can use otherTankAggro
-- from GetThreatDetails() to distinguish the off-tank case.
function Minimizer.Threat.GetTankSituation(unit)
    local details = Minimizer.Threat.GetThreatDetails(unit)
    return details and details.situation or nil
end

-- Canonical Platynator-style decision for the special Blizzard-owned color
-- path: for a tank, hand the healthbar back only when the player has no threat
-- (0/nil) AND no other tank owns the mob. This path is only valid while the
-- unit is in combat; out of combat we keep Minimizer's normal classification
-- colors instead of exposing Blizzard's default hostile red.
function Minimizer.Threat.ShouldLetBlizzardPaint(unit)
    if not Minimizer.Threat.IsPlayerTank() then
        return false
    end
    if not UnitAffectingCombat(unit) then
        return false
    end

    local details = Minimizer.Threat.GetThreatDetails(unit)
    if not details then return false end

    local situation = details.situation
    return (situation == 0 or situation == nil) and not details.otherTankAggro
end

function Minimizer.Threat.ShouldUnsimplify(unit)
    if Minimizer.Threat.IsPlayerTank() then
        if not UnitAffectingCombat(unit) then return false end

        local details = Minimizer.Threat.GetThreatDetails(unit)
        if not details then return false end
        if details.otherTankAggro then return false end

        local situation = details.situation
        return situation == nil or situation == 0
    end
    return Minimizer.Threat.GetSituation(unit, "player") == 3
end