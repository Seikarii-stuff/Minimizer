local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Lifecycle = Minimizer.Lifecycle or {}
Minimizer.ActiveNameplates = Minimizer.ActiveNameplates or {}
Minimizer.Lifecycle.plateGeneration = Minimizer.Lifecycle.plateGeneration or {}

local plateGeneration = Minimizer.Lifecycle.plateGeneration
local pcall = pcall
local type = type
local GetTime = GetTime

local _module_error_throttle = {}
local _MODULE_ERROR_THROTTLE_SECONDS = 10

function Minimizer.Lifecycle.GetGeneration(token)
    if not token then return 0 end
    return plateGeneration[token] or 0
end

function Minimizer.Lifecycle.IncrementGeneration(token)
    if not token then return end
    plateGeneration[token] = (plateGeneration[token] or 0) + 1
    return plateGeneration[token]
end

function Minimizer.Lifecycle.IsGenerationStale(tokenOrNameplate, storedGen, tokenFallback)
    if storedGen == nil then return true end
    local token
    if type(tokenOrNameplate) == "string" then
        token = tokenOrNameplate
    elseif type(tokenOrNameplate) == "table" then
        token = tokenOrNameplate.namePlateUnitToken or tokenOrNameplate.unit or tokenFallback
        if not token and Minimizer.Utils and Minimizer.Utils.GetUnitFromNameplate then
            token = Minimizer.Utils.GetUnitFromNameplate(tokenOrNameplate)
        end
    end
    token = token or tokenFallback
    if not token then return false end
    local currentGen = Minimizer.Lifecycle.GetGeneration(token)
    return storedGen ~= currentGen
end

function Minimizer.Lifecycle.RegisterNameplate(token, nameplate)
    if not token or not nameplate then return end
    Minimizer.ActiveNameplates[token] = nameplate
end

function Minimizer.Lifecycle.UnregisterNameplate(token)
    if not token then return end
    Minimizer.ActiveNameplates[token] = nil
end

function Minimizer.Lifecycle.GetActiveNameplates()
    return Minimizer.ActiveNameplates
end

function Minimizer.Lifecycle.ClearNeverSimplify(unit)
    if not unit then return end
    if Minimizer.Cache and Minimizer.Cache.InvalidateUnit then Minimizer.Cache.InvalidateUnit(unit) end
    if Minimizer.Cast and Minimizer.Cast.InvalidateState then Minimizer.Cast.InvalidateState(unit) end
    if Minimizer.HitTest and Minimizer.HitTest.CancelRetry then Minimizer.HitTest.CancelRetry(unit) end
    if Minimizer.Threat and Minimizer.Threat.ForgetUnit then Minimizer.Threat.ForgetUnit(unit) end

    local nameplate = Minimizer.ActiveNameplates[unit] or (Minimizer.Utils and Minimizer.Utils.GetNamePlateForUnit and Minimizer.Utils.GetNamePlateForUnit(unit))
    if nameplate then
        if Minimizer.Modules then
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