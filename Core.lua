local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Core = {}
Minimizer.Modules = Minimizer.Modules or {}
Minimizer.ActiveNameplates = Minimizer.ActiveNameplates or {}

local C_NamePlate = C_NamePlate
local C_NamePlateManager = C_NamePlateManager
local type = type
local pcall = pcall

function Minimizer.Core.RegisterModule(name, module)
    if type(name) ~= "string" or type(module) ~= "table" then return end

    Minimizer.Modules[name] = module
    module.MinimizerModuleName = name
    Minimizer.Core.ApplyToAll()
end

function Minimizer.Core.UpdateModules(unit, nameplate)
    for name, module in pairs(Minimizer.Modules) do
        if type(module.UpdateNamePlate) == "function" then
            local ok, err = pcall(function()
                module:UpdateNamePlate(unit, nameplate)
            end)
            if not ok then
                print("|cffff4444Minimizer|r: Error in module " .. name .. ": " .. tostring(err))
            end
        end
    end
end

function Minimizer.Core.ApplyToUnit(unit)
    if not unit then return end

    local nameplate = Minimizer.Utils.GetNamePlateForUnit(unit)
    if not nameplate then return end

    local npToken = Minimizer.Utils.GetValidNamePlateToken(unit, nameplate)
    if not npToken then return end
    Minimizer.ActiveNameplates[npToken] = nameplate

    local shouldSimplify = false
    local reason = ""

    if nameplate.MinimizerDesimplifiedPersistent then
        shouldSimplify = false
        reason = "no simp (fast-path)"
    else
        shouldSimplify, reason = Minimizer.Decision.ShouldSimplifyUnit(npToken, nameplate)
        if reason == "no simp" then
            nameplate.MinimizerDesimplifiedPersistent = true
        end
    end

    if Minimizer.Utils.IsSimplifiedAvailable() then
        if nameplate.MinimizerState ~= shouldSimplify then
            C_NamePlateManager.SetNamePlateSimplified(npToken, shouldSimplify)
            nameplate.MinimizerState = shouldSimplify
        end
    end

    if Minimizer.Markers and Minimizer.Markers.Update then
        Minimizer.Markers.Update(npToken, nameplate)
    end
    Minimizer.Core.UpdateModules(npToken, nameplate)
end

function Minimizer.Core.ApplyToAll()
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
        local token = Minimizer.Utils.GetValidNamePlateToken(nil, nameplate)
        if token then
            Minimizer.Core.ApplyToUnit(token)
        end
    end
end

Minimizer.Core.RequestApplyToAll = Minimizer.Utils.Debounce(Minimizer.Core.ApplyToAll)

function Minimizer.Core.ClearNeverSimplify(unit)
    if not unit then return end
    if Minimizer.Cache and Minimizer.Cache.InvalidateUnit then
        Minimizer.Cache.InvalidateUnit(unit)
    end
    if Minimizer.Cast and Minimizer.Cast.InvalidateState then
        Minimizer.Cast.InvalidateState(unit)
    end
    local nameplate = Minimizer.ActiveNameplates[unit] or Minimizer.Utils.GetNamePlateForUnit(unit)
    if nameplate then
        for name, module in pairs(Minimizer.Modules) do
            if type(module.OnNamePlateRemoved) == "function" then
                local ok, err = pcall(function()
                    module:OnNamePlateRemoved(unit, nameplate)
                end)
                if not ok then
                    print("|cffff4444Minimizer|r: Error in module " .. name .. " OnNamePlateRemoved: " .. tostring(err))
                end
            end
        end
        if Minimizer.Markers and Minimizer.Markers.Clear then
            Minimizer.Markers.Clear(nameplate)
        end
        nameplate.MinimizerDesimplifiedPersistent = nil
        nameplate.MinimizerState = nil
        nameplate.MinimizerCastBar = nil
    end
    Minimizer.ActiveNameplates[unit] = nil
end
