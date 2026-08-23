local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Threat = Minimizer.Threat or {}
Minimizer.Threat.tankTokens = Minimizer.Threat.tankTokens or {}
local UnitExists = UnitExists
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitThreatSituation = UnitThreatSituation
local UnitAffectingCombat = UnitAffectingCombat
local UnitCanAttack = UnitCanAttack
local UnitInParty = UnitInParty
local wipe = wipe
local ipairs = ipairs
local IsInRaid = IsInRaid
local IsInGroup = IsInGroup
local GetSpecialization = GetSpecialization
local GetSpecializationRole = GetSpecializationRole
local C_SpecializationInfo = C_SpecializationInfo
local CreateFrame = CreateFrame
local GetTime = GetTime

local NIL_SPECIAL_CONFIRM = 1.0
local playerTankCache
local playerTankCacheValid = false
local nilState = {}
local unitThreatStateCache = {}

function Minimizer.Threat.RefreshTankTokens()
    local tokens = Minimizer.Threat.tankTokens
    wipe(tokens)
    local prefix, count
    if IsInRaid and IsInRaid() then prefix, count = "raid", 40
    elseif IsInGroup and IsInGroup() then prefix, count = "party", 4
    else return end
    for index = 1, count do
        local token = prefix .. index
        if UnitExists(token) and UnitGroupRolesAssigned(token) == "TANK" then tokens[#tokens + 1] = token end
    end
end

function Minimizer.Threat.RefreshPlayerTankCache()
    local isTank = false
    if UnitGroupRolesAssigned and UnitGroupRolesAssigned("player") == "TANK" then
        isTank = true
    else
        local specialization = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecialization()
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
    if playerTankCacheValid then return playerTankCache end
    return Minimizer.Threat.RefreshPlayerTankCache()
end

local function IsThreatEnabled()
    return (IsInGroup and IsInGroup()) or (IsInRaid and IsInRaid()) or Minimizer.Threat.IsPlayerTank()
end
Minimizer.Threat.IsThreatEnabled = IsThreatEnabled

local function UpdateNilState(unit, result, generation, inCombat)
    local now = GetTime()
    local state = nilState[unit]
    if not state or state.generation ~= generation then
        state = { generation = generation, nilSince = nil, nilSpecial = false }
        nilState[unit] = state
    end

    local canAttackPlayer = UnitCanAttack and UnitCanAttack(unit, "player")
    local isNilSpecialCandidate = canAttackPlayer == false

    if result.situation == nil and inCombat and isNilSpecialCandidate then
        if not state.nilSince then
            state.nilSince = now
        elseif not state.nilSpecial and (now - state.nilSince) >= NIL_SPECIAL_CONFIRM then
            state.nilSpecial = true
        end
    else
        state.nilSince = nil
        state.nilSpecial = false
    end

    result.nilSince = state.nilSince
    result.nilSpecial = state.nilSpecial
    return result
end

function Minimizer.Threat.GetThreatDetails(unit)
    if not IsThreatEnabled() then return nil end
    if not unit or not UnitExists(unit) then return nil end
    local cacheKey = "threat:details"
    if Minimizer.Cache and Minimizer.Cache.GetUnitKeyWithGeneration then
        local cached = Minimizer.Cache.GetUnitKeyWithGeneration(unit, cacheKey)
        if cached ~= nil then
            local generation = Minimizer.Lifecycle and Minimizer.Lifecycle.GetGeneration and Minimizer.Lifecycle.GetGeneration(unit) or 0
            local combat = Minimizer.Threat.IsInCombatWith(unit, cached)
            cached.combat = combat == true
            return UpdateNilState(unit, cached, generation, combat)
        end
    end
    local rawSituation = UnitThreatSituation("player", unit)
    local result = {
        situation = (Minimizer.Utils.IsSecretValue(rawSituation) or type(rawSituation) ~= "number") and nil or rawSituation,
        otherTankAggro = false,
    }
    if result.situation ~= 3 and result.situation ~= 2 and Minimizer.Threat.IsPlayerTank() then
        for _, tankUnit in ipairs(Minimizer.Threat.tankTokens) do
            local rawTankSit = UnitThreatSituation(tankUnit, unit)
            if not Minimizer.Utils.IsSecretValue(rawTankSit) and rawTankSit == 3 then
                result.otherTankAggro = true
                break
            end
        end
    end
    local generation = Minimizer.Lifecycle and Minimizer.Lifecycle.GetGeneration and Minimizer.Lifecycle.GetGeneration(unit) or 0
    local combat = Minimizer.Threat.IsInCombatWith(unit, result)
    result.combat = combat == true
    result = UpdateNilState(unit, result, generation, combat)
    if Minimizer.Cache and Minimizer.Cache.SetUnitKeyWithGeneration then Minimizer.Cache.SetUnitKeyWithGeneration(unit, cacheKey, result) end
    return result
end

function Minimizer.Threat.Invalidate(unit)
    if not unit then return end
    if Minimizer.Cache and Minimizer.Cache.InvalidateUnit then Minimizer.Cache.InvalidateUnit(unit, "threat") end
    unitThreatStateCache[unit] = nil
end

function Minimizer.Threat.IsInCombatWith(unit, threatDetails)
    if not IsThreatEnabled() then return false end
    if not unit or not UnitExists(unit) then return false end
    if UnitAffectingCombat(unit) then return true end
    local details = threatDetails or Minimizer.Threat.GetThreatDetails(unit)
    if details and details.situation ~= nil then return true end
    local target = unit .. "target"
    return UnitInParty and UnitInParty(target) == true or false
end

function Minimizer.Threat.GetSituation(unit, source)
    if not IsThreatEnabled() then return nil end
    if not unit or not UnitExists(unit) then return nil end
    source = source or "player"
    local cacheKey = "threat:" .. source
    if Minimizer.Cache and Minimizer.Cache.GetUnitKeyWithGeneration then
        local cached = Minimizer.Cache.GetUnitKeyWithGeneration(unit, cacheKey)
        if cached ~= nil then return cached end
    end
    local situation = UnitThreatSituation(source, unit)
    if Minimizer.Utils.IsSecretValue(situation) or type(situation) ~= "number" then situation = nil end
    if Minimizer.Cache and Minimizer.Cache.SetUnitKeyWithGeneration then Minimizer.Cache.SetUnitKeyWithGeneration(unit, cacheKey, situation) end
    return situation
end

function Minimizer.Threat.PlayerHasAggro(unit)
    if not IsThreatEnabled() then return false end
    if Minimizer.Threat.IsPlayerTank() then
        local threatDetails = Minimizer.Threat.GetThreatDetails(unit)
        if not threatDetails then return false end
        if not Minimizer.Threat.IsInCombatWith(unit, threatDetails) then return false end
        if threatDetails.otherTankAggro then return false end
        local situation = threatDetails.situation
        return situation == nil or situation == 0 or situation == 1 or situation == 2
    end
    return Minimizer.Threat.GetSituation(unit, "player") == 3
end

function Minimizer.Threat.GetTankSituation(unit)
    if not IsThreatEnabled() then return nil end
    local details = Minimizer.Threat.GetThreatDetails(unit)
    return details and details.situation or nil
end

function Minimizer.Threat.IsNilSpecial(unit)
    if not IsThreatEnabled() then return false end
    local details = Minimizer.Threat.GetThreatDetails(unit)
    return details and details.nilSpecial == true or false
end

function Minimizer.Threat.GetUnitThreatState(unit)
    if not Minimizer.Threat.IsThreatEnabled() then return nil end
    if not unit or not UnitExists(unit) then return nil end
    local details = Minimizer.Threat.GetThreatDetails(unit)
    if not details then return nil end

    local generation = (Minimizer.Lifecycle and Minimizer.Lifecycle.GetGeneration and Minimizer.Lifecycle.GetGeneration(unit)) or 0
    local situation = details.situation
    local otherTankAggro = details.otherTankAggro == true
    local combat = details.combat == true
    local nilSpecial = details.nilSpecial == true

    local state = unitThreatStateCache[unit]
    if state and state.generation == generation
        and state.situation == situation
        and state.otherTankAggro == otherTankAggro
        and state.combat == combat
        and state.nilSpecial == nilSpecial then
        return state
    end

    state = {
        generation     = generation,
        situation      = situation,
        otherTankAggro = otherTankAggro,
        combat         = combat,
        nilSpecial     = nilSpecial,
    }
    unitThreatStateCache[unit] = state
    return state
end

function Minimizer.Threat.StatesEqual(s1, s2)
    if s1 == s2 then return true end
    if not s1 or not s2 then return false end
    return s1.generation == s2.generation
        and s1.situation == s2.situation
        and s1.otherTankAggro == s2.otherTankAggro
        and s1.combat == s2.combat
        and s1.nilSpecial == s2.nilSpecial
end

function Minimizer.Threat.ForgetUnit(unit)
    if unit then
        nilState[unit] = nil
        unitThreatStateCache[unit] = nil
    end
end
