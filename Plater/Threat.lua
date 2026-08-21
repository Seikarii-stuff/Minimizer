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
            local generation = Minimizer.Core and Minimizer.Core.GetPlateGeneration and Minimizer.Core.GetPlateGeneration(unit) or 0
            local combat = Minimizer.Threat.IsInCombatWith(unit, cached)
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
    local generation = Minimizer.Core and Minimizer.Core.GetPlateGeneration and Minimizer.Core.GetPlateGeneration(unit) or 0
    local combat = Minimizer.Threat.IsInCombatWith(unit, result)
    result = UpdateNilState(unit, result, generation, combat)
    if Minimizer.Cache and Minimizer.Cache.SetUnitKeyWithGeneration then Minimizer.Cache.SetUnitKeyWithGeneration(unit, cacheKey, result) end
    return result
end

function Minimizer.Threat.Invalidate(unit)
    if not unit then return end
    if Minimizer.Cache and Minimizer.Cache.InvalidateUnit then Minimizer.Cache.InvalidateUnit(unit, "threat") end
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

function Minimizer.Threat.ShouldLetBlizzardPaint(unit)
    if not IsThreatEnabled() or not Minimizer.Threat.IsPlayerTank() then return false end
    local details = Minimizer.Threat.GetThreatDetails(unit)
    if not details or not Minimizer.Threat.IsInCombatWith(unit, details) then return false end
    if details.nilSpecial then return false end
    local situation = details.situation
    return (situation == 0 or situation == nil) and not details.otherTankAggro
end

function Minimizer.Threat.ShouldUnsimplify(unit)
    if not IsThreatEnabled() then return false end
    local details = Minimizer.Threat.GetThreatDetails(unit)
    if not details then return false end

    if details.situation == nil then
        return details.nilSince ~= nil and Minimizer.Threat.IsInCombatWith(unit, details)
    end

    if Minimizer.Threat.IsPlayerTank() then
        if not Minimizer.Threat.IsInCombatWith(unit, details) then return false end
        if details.otherTankAggro then return false end
        return details.situation == 0
    end
    return details.situation == 3
end

local monitorFrame
local monitorElapsed = 0
local monitorStep = 1
local monitorUnits = {}
local monitorCount = 0
local monitorState = {}
local monitorDirty = true

local function IsNameplateToken(unit)
    return type(unit) == "string" and unit:match("^nameplate%d+$") ~= nil
end

local function RebuildMonitorUnits()
    if not monitorDirty then return end
    monitorDirty = false
    wipe(monitorUnits)
    monitorCount = 0
    if not Minimizer.ActiveNameplates then return end
    for unit in pairs(Minimizer.ActiveNameplates) do
        if IsNameplateToken(unit) then
            monitorCount = monitorCount + 1
            monitorUnits[monitorCount] = unit
        end
    end
    if monitorStep > monitorCount then monitorStep = 1 end
end

function Minimizer.Threat.TrackUnit(unit)
    if IsNameplateToken(unit) then monitorDirty = true end
end

function Minimizer.Threat.ForgetUnit(unit)
    if unit then
        monitorState[unit] = nil
        nilState[unit] = nil
        monitorDirty = true
    end
end

local function ProcessMonitoredUnit(unit)
    if not IsNameplateToken(unit) then return end
    if not Minimizer.ActiveNameplates or not Minimizer.ActiveNameplates[unit] then
        monitorState[unit] = nil
        nilState[unit] = nil
        monitorDirty = true
        return
    end
    if not UnitExists(unit) then return end
    local details = Minimizer.Threat.GetThreatDetails(unit)
    if not details then return end
    local combat = Minimizer.Threat.IsInCombatWith(unit, details)
    local generation = Minimizer.Core and Minimizer.Core.GetPlateGeneration and Minimizer.Core.GetPlateGeneration(unit) or 0
    local previous = monitorState[unit]
    local changed = not previous
        or previous.generation ~= generation
        or previous.situation ~= details.situation
        or previous.otherTankAggro ~= details.otherTankAggro
        or previous.combat ~= combat
        or previous.nilSpecial ~= details.nilSpecial
    if previous then
        previous.generation     = generation
        previous.situation      = details.situation
        previous.otherTankAggro = details.otherTankAggro
        previous.combat         = combat
        previous.nilSpecial     = details.nilSpecial
    else
        monitorState[unit] = {
            generation     = generation,
            situation      = details.situation,
            otherTankAggro = details.otherTankAggro,
            combat         = combat,
            nilSpecial     = details.nilSpecial,
        }
    end
    if changed and Minimizer.Core and Minimizer.Core.ApplyToUnit then Minimizer.Core.ApplyToUnit(unit) end
end

function Minimizer.Threat.StartMonitor()
    if monitorFrame or not IsThreatEnabled() then return end
    RebuildMonitorUnits()
    monitorFrame = CreateFrame("Frame")
    monitorFrame:SetScript("OnUpdate", function(_, elapsed)
        RebuildMonitorUnits()
        if monitorCount == 0 then
            monitorElapsed = 0
            return
        end
        monitorElapsed = monitorElapsed + elapsed
        local interval = 0.25 / monitorCount
        if monitorElapsed < interval then return end
        monitorElapsed = monitorElapsed - interval
        if monitorStep > monitorCount then monitorStep = 1 end
        local unit = monitorUnits[monitorStep]
        monitorStep = monitorStep + 1
        ProcessMonitoredUnit(unit)
    end)
end
