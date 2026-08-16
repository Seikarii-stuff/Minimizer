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
local type = type
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

function Minimizer.Threat.GetSituation(unit, source)
    if not unit or not UnitExists(unit) then return nil end
    source = source or "player"
    local cached
    if Minimizer.Cache and Minimizer.Cache.GetUnitKeyWithGeneration then
        cached = Minimizer.Cache.GetUnitKeyWithGeneration(unit, "threat:" .. source)
        if cached ~= nil then return cached end
    end

    local situation = UnitThreatSituation(source, unit)
    if Minimizer.Utils.IsSecretValue(situation) then return nil end
    if type(situation) ~= "number" then return nil end

    if Minimizer.Cache and Minimizer.Cache.SetUnitKeyWithGeneration then
        Minimizer.Cache.SetUnitKeyWithGeneration(unit, "threat:" .. source, situation)
    end
    return situation
end

function Minimizer.Threat.PlayerHasAggro(unit)
    if Minimizer.Threat.IsPlayerTank() then
        if not UnitAffectingCombat(unit) then return false end
        local situation = Minimizer.Threat.GetSituation(unit, "player")
        return situation == nil or situation < 3
    else
        return Minimizer.Threat.GetSituation(unit, "player") == 3
    end
end

function Minimizer.Threat.GetTankSituation(unit)
    local best = Minimizer.Threat.GetSituation(unit, "player")
    for _, token in ipairs(Minimizer.Threat.tankTokens) do
        local situation = Minimizer.Threat.GetSituation(unit, token)
        if situation == 3 then
            return situation
        end
        if best == nil or (situation and situation > best) then
            best = situation
        end
    end
    return best
end

function Minimizer.Threat.ShouldUnsimplify(unit)
    if Minimizer.Threat.IsPlayerTank() then
        if not UnitAffectingCombat(unit) then return false end
        local situation = Minimizer.Threat.GetTankSituation(unit)
        return situation == nil or situation == 0
    end
    return Minimizer.Threat.GetSituation(unit, "player") == 3
end
