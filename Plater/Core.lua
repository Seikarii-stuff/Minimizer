local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Core = Minimizer.Core or {}
Minimizer.Modules = Minimizer.Modules or {}
Minimizer.ModuleList = Minimizer.ModuleList or {}

local type = type
local pcall = pcall
local GetTime = GetTime

local _module_error_throttle = {}
local _MODULE_ERROR_THROTTLE_SECONDS = 10

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

-- ============================================================================
-- Backward Compatibility Aliases
-- All implementations have dedicated ownership in their respective components:
-- Lifecycle (generations, active nameplates, teardown)
-- Dispatcher (ApplyToUnit, ApplyToAll, RequestApplyToAll, SafetyNet)
-- Snapshot (BuildSnapshot, ComputeDisplayKind)
-- Absorb (MarkAbsorbSeen)
-- ============================================================================

-- Lifecycle aliases
Minimizer.Core.plateGeneration = (Minimizer.Lifecycle and Minimizer.Lifecycle.plateGeneration) or Minimizer.Core.plateGeneration or {}
Minimizer.Core.GetPlateGeneration = function(token)
    if Minimizer.Lifecycle and Minimizer.Lifecycle.GetGeneration then
        return Minimizer.Lifecycle.GetGeneration(token)
    end
    return 0
end
Minimizer.Core.IncrementPlateGeneration = function(token)
    if Minimizer.Lifecycle and Minimizer.Lifecycle.IncrementGeneration then
        return Minimizer.Lifecycle.IncrementGeneration(token)
    end
end
Minimizer.Core.ClearNeverSimplify = function(unit)
    if Minimizer.Lifecycle and Minimizer.Lifecycle.ClearNeverSimplify then
        return Minimizer.Lifecycle.ClearNeverSimplify(unit)
    end
end

-- Absorb aliases
Minimizer.Core.MarkAbsorbSeen = function(unit, nameplate, hasAbsorbNow)
    if Minimizer.Absorb and Minimizer.Absorb.MarkSeen then
        return Minimizer.Absorb.MarkSeen(unit, nameplate, hasAbsorbNow)
    end
    return hasAbsorbNow == true
end

-- Snapshot aliases
Minimizer.Core.BuildSnapshot = function(unit, nameplate)
    if Minimizer.Snapshot and Minimizer.Snapshot.Build then
        return Minimizer.Snapshot.Build(unit, nameplate)
    end
    return nil
end
Minimizer.Core.ComputeDisplayKind = function(unit, nameplate)
    if Minimizer.Snapshot and Minimizer.Snapshot.ComputeDisplayKind then
        return Minimizer.Snapshot.ComputeDisplayKind(unit, nameplate)
    end
    return nil
end

-- Dispatcher aliases
Minimizer.Core.ApplyToUnit = function(unit, forceUpdate)
    if Minimizer.Dispatcher and Minimizer.Dispatcher.ApplyToUnit then
        return Minimizer.Dispatcher.ApplyToUnit(unit, forceUpdate)
    end
end
Minimizer.Core.ApplyToAll = function(forceUpdate)
    if Minimizer.Dispatcher and Minimizer.Dispatcher.ApplyToAll then
        return Minimizer.Dispatcher.ApplyToAll(forceUpdate)
    end
end
Minimizer.Core.RequestApplyToAll = function(...)
    if Minimizer.Dispatcher and Minimizer.Dispatcher.RequestApplyToAll then
        return Minimizer.Dispatcher.RequestApplyToAll(...)
    end
end
Minimizer.Core.StartSafetyNet = function()
    if Minimizer.Dispatcher and Minimizer.Dispatcher.StartSafetyNet then
        return Minimizer.Dispatcher.StartSafetyNet()
    end
end
