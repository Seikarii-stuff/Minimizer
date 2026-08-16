local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Core = {}
Minimizer.Modules = Minimizer.Modules or {}
Minimizer.ActiveNameplates = Minimizer.ActiveNameplates or {}
-- Monotonic generation counter por token de nameplate. Se incrementa cuando
-- una unidad LLEGA al token (NAME_PLATE_UNIT_ADDED / OnNamePlateAdded hook).
-- Las entradas no se limpian: el espacio es bounded por el pool fijo de tokens.
Minimizer.Core.plateGeneration = Minimizer.Core.plateGeneration or {}

function Minimizer.Core.GetPlateGeneration(token)
    if not token then return 0 end
    return Minimizer.Core.plateGeneration[token] or 0
end

function Minimizer.Core.IncrementPlateGeneration(token)
    if not token then return end
    local g = Minimizer.Core.plateGeneration
    g[token] = (g[token] or 0) + 1
    return g[token]
end

local C_NamePlate = C_NamePlate
local C_NamePlateManager = C_NamePlateManager
local type = type
local pcall = pcall
local GetTime = GetTime

local _module_error_throttle = {}
local _MODULE_ERROR_THROTTLE_SECONDS = 10

-- Table reutilizado para el snapshot de cada unidad. Se sobreescribe en cada
-- llamada a ApplyToUnit; NUNCA guardes una referencia a este table mas alla
-- de la duracion de esa llamada (no lo metas en nameplate.algo, no lo pases
-- a codigo asincrono).
local scratchSnapshot = {}

function Minimizer.Core.RegisterModule(name, module)
    if type(name) ~= "string" or type(module) ~= "table" then return end

    Minimizer.Modules[name] = module
    module.MinimizerModuleName = name

end

function Minimizer.Core.UpdateModules(unit, nameplate, snapshot)
    for name, module in pairs(Minimizer.Modules) do
        if type(module.UpdateNamePlate) == "function" then
            local ok, err = pcall(function()
                module:UpdateNamePlate(unit, nameplate, snapshot)
            end)
            if not ok then
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

-- Rellena scratchSnapshot con los datos calculados UNA sola vez para esta
-- unidad. Se llama siempre, con o sin fast-path.
local function BuildSnapshot(unit, nameplate)
    local s = scratchSnapshot
    s.eliteType = Minimizer.Classification.GetEliteType(unit)
    s.hasAbsorb = Minimizer.Absorb.HasAbsorb(unit, nameplate)
    s.hasAggro = Minimizer.Threat.PlayerHasAggro(unit)
    s.isCasting, s.isUninterruptible, s.rawUninterruptible, s.isChanneling = Minimizer.Cast.GetState(unit)
    -- displayKind: prioridad aggro > absorb > eliteType. Logica identica a la
    -- que antes vivia en HealthBarColor:GetKind, ahora centralizada aqui.
    if UnitIsUnit(unit, "focus") then
        s.displayKind = "focus"
    elseif s.hasAggro then
        s.displayKind = "aggro"
    elseif s.hasAbsorb then
        s.displayKind = "absorb"
    else
        s.displayKind = s.eliteType
    end
    return s
end

function Minimizer.Core.ApplyToUnit(unit, forceUpdate)
    if not unit then return end

    local nameplate = Minimizer.Utils.GetNamePlateForUnit(unit)
    if not nameplate then return end

    local npToken = Minimizer.Utils.GetValidNamePlateToken(unit, nameplate)
    if not npToken then return end
    Minimizer.ActiveNameplates[npToken] = nameplate

    -- El snapshot se calcula SIEMPRE, fast-path o no.
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
        end
    end

    if Minimizer.Markers and Minimizer.Markers.Update then
        Minimizer.Markers.Update(npToken, nameplate)
    end
    Minimizer.Core.UpdateModules(npToken, nameplate, snapshot)
end

function Minimizer.Core.ApplyToAll(forceUpdate)
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    -- Refrescar el estado global "interrupcion lista" UNA vez por pase,
    -- nunca dentro del loop de nameplates.
    if Minimizer.Interrupt and Minimizer.Interrupt.RefreshReadyCache then
        Minimizer.Interrupt.RefreshReadyCache()
    end
    for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
        local token = Minimizer.Utils.GetValidNamePlateToken(nil, nameplate)
        if token then
            Minimizer.Core.ApplyToUnit(token, forceUpdate)
        end
    end
end

Minimizer.Core.RequestApplyToAll = Minimizer.Utils.Debounce(function() Minimizer.Core.ApplyToAll(true) end)

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
                    local now = GetTime and GetTime() or 0
                    local last = _module_error_throttle[name]
                    if not last or (now - last) >= _MODULE_ERROR_THROTTLE_SECONDS then
                        _module_error_throttle[name] = now
                        print("|cffff4444Minimizer|r: Error in module " .. name .. " OnNamePlateRemoved: " .. tostring(err))
                    end
                end
            end
        end
        if Minimizer.Markers and Minimizer.Markers.Clear then
            Minimizer.Markers.Clear(nameplate)
        end
        nameplate.MinimizerDesimplifiedPersistent = nil
        nameplate.MinimizerDesimplifiedPersistentGen = nil
        nameplate.MinimizerState = nil
        nameplate.MinimizerCastBar = nil
    end
    Minimizer.ActiveNameplates[unit] = nil
end
