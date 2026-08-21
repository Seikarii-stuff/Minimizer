local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Core = {}
Minimizer.Modules = Minimizer.Modules or {}
Minimizer.ModuleList = Minimizer.ModuleList or {}
Minimizer.ActiveNameplates = Minimizer.ActiveNameplates or {}
Minimizer.Core.plateGeneration = Minimizer.Core.plateGeneration or {}

local C_NamePlateManager = C_NamePlateManager
local UnitIsUnit = UnitIsUnit
local UnitCanAttack = UnitCanAttack
local type = type
local pcall = pcall
local GetTime = GetTime

function Minimizer.Core.GetPlateGeneration(token)
    if not token then return 0 end
    return Minimizer.Core.plateGeneration[token] or 0
end

function Minimizer.Core.MarkAbsorbSeen(unit, nameplate, hasAbsorbNow)
    if not nameplate then return hasAbsorbNow == true end
    local currentGen = Minimizer.Core.GetPlateGeneration(unit)
    if nameplate.MinimizerAbsorbPersistentGen ~= currentGen then
        nameplate.MinimizerAbsorbPersistentGen = currentGen
        nameplate.MinimizerHasHadAbsorb = nil
    end
    if hasAbsorbNow then nameplate.MinimizerHasHadAbsorb = true end
    return nameplate.MinimizerHasHadAbsorb == true
end

local SAFETY_NET_INTERVAL = 2.0
local _safetyNetStarted = false
function Minimizer.Core.StartSafetyNet()
    if _safetyNetStarted then return end
    _safetyNetStarted = true
    C_Timer.NewTicker(SAFETY_NET_INTERVAL, function() Minimizer.Core.ApplyToAll(false) end)
end

function Minimizer.Core.IncrementPlateGeneration(token)
    if not token then return end
    local g = Minimizer.Core.plateGeneration
    g[token] = (g[token] or 0) + 1
    return g[token]
end

local _module_error_throttle = {}
local _MODULE_ERROR_THROTTLE_SECONDS = 10
local scratchSnapshot = {}

function Minimizer.Core.RegisterModule(name, module)
    if type(name) ~= "string" or type(module) ~= "table" then return end
    Minimizer.Modules[name] = module
    module.MinimizerModuleName = name
    Minimizer.ModuleList[#Minimizer.ModuleList + 1] = module
end

function Minimizer.Core.UpdateModules(unit, nameplate, snapshot)
    local list = Minimizer.ModuleList
    for i = 1, #list do
        local module = list[i]
        if type(module.UpdateNamePlate) == "function" then
            local ok, err = pcall(module.UpdateNamePlate, module, unit, nameplate, snapshot)
            if not ok then
                local name = module.MinimizerModuleName or "?"
                local now = GetTime and GetTime() or 0
                local last = _module_error_throttle[name]
                if not last or (now - last) >= _MODULE_ERROR_THROTTLE_SECONDS then
                    _module_error_throttle[name] = now
                    print("|cffff4444Minimizer|r: Error in module " .. name .. ": " .. tostring(err))
                end
            end
        end
    end
end

local function BuildSnapshot(unit, nameplate)
    local s = scratchSnapshot
    s.eliteType = Minimizer.Classification.GetEliteType(unit)
    s.hasAbsorb = Minimizer.Absorb.HasAbsorb(unit, nameplate)
    s.hasHadAbsorb = Minimizer.Core.MarkAbsorbSeen(unit, nameplate, s.hasAbsorb)

    local details = Minimizer.Threat.GetThreatDetails(unit)
    s.threatSituation = details and details.situation or nil
    s.otherTankAggro = details and details.otherTankAggro or false
    s.isNilSpecial = details and details.nilSpecial == true or false
    s.isNonAttackable = details and details.cannotAttackPlayer == true or false
    s.hasAggro = Minimizer.Threat.PlayerHasAggro(unit)

    s.isPvP = Minimizer.Utils.IsPvPUnit(unit)
    s.isFriendly = UnitCanAttack and not UnitCanAttack("player", unit) or false
    s.isCasting, s.isUninterruptible, s.rawUninterruptible, s.isChanneling = Minimizer.Cast.GetState(unit)

    if UnitIsUnit(unit, "focus") then
        s.displayKind = "focus"
    elseif s.isNilSpecial or s.isNonAttackable then
        s.displayKind = "priority"
    elseif s.hasAggro then
        s.displayKind = "aggro"
    elseif s.hasHadAbsorb then
        s.displayKind = "absorb"
    else
        s.displayKind = s.eliteType
    end
    return s
end

function Minimizer.Core.ComputeDisplayKind(unit, nameplate)
    if not unit then return nil end
    if UnitIsUnit(unit, "focus") then return "focus" end
    if Minimizer.Threat and Minimizer.Threat.IsNonAttackable and Minimizer.Threat.IsNonAttackable(unit) then return "priority" end
    if Minimizer.Threat and Minimizer.Threat.IsNilSpecial and Minimizer.Threat.IsNilSpecial(unit) then return "priority" end
    if Minimizer.Threat and Minimizer.Threat.PlayerHasAggro and Minimizer.Threat.PlayerHasAggro(unit) then return "aggro" end
    local hasAbsorbNow = Minimizer.Absorb and Minimizer.Absorb.HasAbsorb and Minimizer.Absorb.HasAbsorb(unit, nameplate)
    if Minimizer.Core.MarkAbsorbSeen(unit, nameplate, hasAbsorbNow) then return "absorb" end
    if Minimizer.Classification and Minimizer.Classification.GetEliteType then return Minimizer.Classification.GetEliteType(unit) end
    return nil
end

function Minimizer.Core.ApplyToUnit(unit, forceUpdate)
    if not unit then return end
    local nameplate = Minimizer.Utils.GetNamePlateForUnit(unit)
    if not nameplate then return end
    local npToken = Minimizer.Utils.GetValidNamePlateToken(unit, nameplate)
    if not npToken then return end
    Minimizer.ActiveNameplates[npToken] = nameplate

    local snapshot = BuildSnapshot(npToken, nameplate)
    local shouldSimplify = false
    local reason = ""
    local currentGen = Minimizer.Core.GetPlateGeneration(npToken)

    if nameplate.MinimizerDesimplifiedPersistent and nameplate.MinimizerDesimplifiedPersistentGen ~= currentGen then
        nameplate.MinimizerDesimplifiedPersistent = nil
        nameplate.MinimizerDesimplifiedPersistentGen = nil
    end

    if nameplate.MinimizerDesimplifiedPersistent then
        shouldSimplify = false
        reason = "no simp (fast-path)"
    else
        shouldSimplify, reason = Minimizer.Decision.ShouldSimplifyUnit(npToken, nameplate, snapshot)
        if reason == "no simp" then
            nameplate.MinimizerDesimplifiedPersistent = true
            nameplate.MinimizerDesimplifiedPersistentGen = currentGen
        end
    end

    if Minimizer.Utils.IsSimplifiedAvailable() then
        if forceUpdate or nameplate.MinimizerState ~= shouldSimplify then
            C_NamePlateManager.SetNamePlateSimplified(npToken, shouldSimplify)
            nameplate.MinimizerState = shouldSimplify
            if Minimizer.HitTest and Minimizer.HitTest.Sync then Minimizer.HitTest.Sync(npToken, nameplate) end
        end
    end
    Minimizer.Core.UpdateModules(npToken, nameplate, snapshot)
end

function Minimizer.Core.ApplyToAll(forceUpdate)
    if Minimizer.Interrupt and Minimizer.Interrupt.RefreshReadyCache then Minimizer.Interrupt.RefreshReadyCache() end
    for token in pairs(Minimizer.ActiveNameplates) do Minimizer.Core.ApplyToUnit(token, forceUpdate) end
end

Minimizer.Core.RequestApplyToAll = Minimizer.Utils.Debounce(function() Minimizer.Core.ApplyToAll(true) end)

function Minimizer.Core.ClearNeverSimplify(unit)
    if not unit then return end
    if Minimizer.Cache and Minimizer.Cache.InvalidateUnit then Minimizer.Cache.InvalidateUnit(unit) end
    if Minimizer.Cast and Minimizer.Cast.InvalidateState then Minimizer.Cast.InvalidateState(unit) end
    if Minimizer.HitTest and Minimizer.HitTest.CancelRetry then Minimizer.HitTest.CancelRetry(unit) end
    if Minimizer.Threat and Minimizer.Threat.ForgetUnit then Minimizer.Threat.ForgetUnit(unit) end
    local nameplate = Minimizer.ActiveNameplates[unit] or Minimizer.Utils.GetNamePlateForUnit(unit)
    if nameplate then
        for name, module in pairs(Minimizer.Modules) do
            if type(module.OnNamePlateRemoved) == "function" then
                local ok, err = pcall(module.OnNamePlateRemoved, module, unit, nameplate)
                if not ok then
                    local now = GetTime and GetTime() or 0
                    local last = _module_error_throttle[name]
                    if not last or (now - last) >= _MODULE_ERROR_THROTTLE_SECONDS then
                        _module_error_throttle[name] = now
                        print("|cffff4444Minimizer|r: Error in module " .. name .. " OnNamePlateRemoved: " .. tostring(err))
                    end
                end
            end
        end
        nameplate.MinimizerDesimplifiedPersistent = nil
        nameplate.MinimizerDesimplifiedPersistentGen = nil
        nameplate.MinimizerState = nil
        nameplate.MinimizerCastBar = nil
        nameplate.MinimizerHasHadAbsorb = nil
        nameplate.MinimizerAbsorbPersistentGen = nil
    end
    Minimizer.ActiveNameplates[unit] = nil
end
