local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Core = Minimizer.Core or {}
Minimizer.Modules = Minimizer.Modules or {}
Minimizer.ModuleList = Minimizer.ModuleList or {}
Minimizer.ActiveNameplates = Minimizer.ActiveNameplates or (Minimizer.Lifecycle and Minimizer.Lifecycle.ActiveNameplates) or {}
Minimizer.Core.plateGeneration = (Minimizer.Lifecycle and Minimizer.Lifecycle.plateGeneration) or Minimizer.Core.plateGeneration or {}

local C_NamePlateManager = C_NamePlateManager
local UnitIsUnit = UnitIsUnit
local UnitCanAttack = UnitCanAttack
local type = type
local pcall = pcall
local GetTime = GetTime

function Minimizer.Core.GetPlateGeneration(token)
    if Minimizer.Lifecycle and Minimizer.Lifecycle.GetGeneration then
        return Minimizer.Lifecycle.GetGeneration(token)
    end
    if not token then return 0 end
    return Minimizer.Core.plateGeneration[token] or 0
end

function Minimizer.Core.MarkAbsorbSeen(unit, nameplate, hasAbsorbNow)
    if not nameplate then return hasAbsorbNow == true end
    local isStale
    if Minimizer.Lifecycle and Minimizer.Lifecycle.IsGenerationStale then
        isStale = Minimizer.Lifecycle.IsGenerationStale(unit, nameplate.MinimizerAbsorbPersistentGen)
    else
        local currentGen = Minimizer.Core.GetPlateGeneration(unit)
        isStale = nameplate.MinimizerAbsorbPersistentGen ~= currentGen
    end
    if isStale then
        local currentGen = (Minimizer.Lifecycle and Minimizer.Lifecycle.GetGeneration and Minimizer.Lifecycle.GetGeneration(unit))
            or Minimizer.Core.GetPlateGeneration(unit)
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
    if Minimizer.Lifecycle and Minimizer.Lifecycle.IncrementGeneration then
        return Minimizer.Lifecycle.IncrementGeneration(token)
    end
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
    if Minimizer.Snapshot and Minimizer.Snapshot.Build then
        return Minimizer.Snapshot.Build(unit, nameplate)
    end
    return scratchSnapshot
end

function Minimizer.Core.ComputeDisplayKind(unit, nameplate)
    if Minimizer.Snapshot and Minimizer.Snapshot.ComputeDisplayKind then
        return Minimizer.Snapshot.ComputeDisplayKind(unit, nameplate)
    end
    return nil
end

function Minimizer.Core.ApplyToUnit(unit, forceUpdate)
    if Minimizer.Dispatcher and Minimizer.Dispatcher.ApplyToUnit then
        return Minimizer.Dispatcher.ApplyToUnit(unit, forceUpdate)
    end
end

function Minimizer.Core.ApplyToAll(forceUpdate)
    if Minimizer.Dispatcher and Minimizer.Dispatcher.ApplyToAll then
        return Minimizer.Dispatcher.ApplyToAll(forceUpdate)
    end
end

Minimizer.Core.RequestApplyToAll = function(...)
    if Minimizer.Dispatcher and Minimizer.Dispatcher.RequestApplyToAll then
        return Minimizer.Dispatcher.RequestApplyToAll(...)
    end
end

function Minimizer.Core.StartSafetyNet()
    if Minimizer.Dispatcher and Minimizer.Dispatcher.StartSafetyNet then
        return Minimizer.Dispatcher.StartSafetyNet()
    end
end

function Minimizer.Core.ClearNeverSimplify(unit)
    if Minimizer.Lifecycle and Minimizer.Lifecycle.ClearNeverSimplify then
        return Minimizer.Lifecycle.ClearNeverSimplify(unit)
    end
end
