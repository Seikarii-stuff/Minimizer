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

-- Temporada de shields: marcar persistentemente si una nameplate mostro
-- alguna vez un shield para que el color (no la simplificacion) no se
-- pierda cuando Blizzard ocultara el indicador. SOLO afecta color.
function Minimizer.Core.MarkAbsorbSeen(unit, nameplate, hasAbsorbNow)
    if not nameplate then return hasAbsorbNow == true end
    local currentGen = Minimizer.Core.GetPlateGeneration(unit)
    if nameplate.MinimizerAbsorbPersistentGen ~= currentGen then
        nameplate.MinimizerAbsorbPersistentGen = currentGen
        nameplate.MinimizerHasHadAbsorb = nil
    end
    if hasAbsorbNow then
        nameplate.MinimizerHasHadAbsorb = true
    end
    return nameplate.MinimizerHasHadAbsorb == true
end

-- ============================================================================
-- Red de seguridad: ApplyToAll periodico de bajo coste.
--
-- Motivo: la arquitectura es 100% event-driven (threat, absorb, cast,
-- lifecycle de nameplate). Si por lo que sea un evento no llega a una
-- nameplate concreta (visto en pulls de 80+ mobs con varios escudos activos
-- a la vez, aun sin poder confirmar la causa exacta -- posible perdida de
-- UNIT_ABSORB_AMOUNT_CHANGED bajo carga, hook que no llega a instalarse a
-- tiempo, etc.) esa nameplate se queda con el color base indefinidamente:
-- no hay ningun otro trigger que la vuelva a tocar. Este timer es ese
-- "segundo intento": no reemplaza a los triggers instantaneos, los
-- respalda con una cota maxima de tiempo hasta que cualquier estado se
-- corrija solo.
--
-- Coste: segun benchmark, ~0.045ms promedio por ApplyToUnit. Con las
-- nameplates realmente visibles en pantalla (no las 80 del pull, solo las
-- que WoW renderiza a la vez), un ApplyToAll cada SAFETY_NET_INTERVAL
-- segundos es coste despreciable comparado con el volumen de eventos de
-- combate real.
-- ============================================================================
local SAFETY_NET_INTERVAL = 2.0
local _safetyNetStarted = false

function Minimizer.Core.StartSafetyNet()
    if _safetyNetStarted then return end
    _safetyNetStarted = true
    C_Timer.NewTicker(SAFETY_NET_INTERVAL, function()
        Minimizer.Core.ApplyToAll(false)
    end)
end

function Minimizer.Core.IncrementPlateGeneration(token)
    if not token then return end
    local g = Minimizer.Core.plateGeneration
    g[token] = (g[token] or 0) + 1
    return g[token]
end

local C_NamePlate = C_NamePlate
local C_NamePlateManager = C_NamePlateManager
local UnitIsUnit = UnitIsUnit
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
            -- pcall directo sobre la función + self + args: evita crear una
            -- closure nueva por módulo/nameplate/pase (esto corre decenas de
            -- veces por frame con nameplates activas).
            local ok, err = pcall(module.UpdateNamePlate, module, unit, nameplate, snapshot)
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
    -- persistente para color; Decision.lua sigue leyendo s.hasAbsorb vivo
    s.hasHadAbsorb = Minimizer.Core.MarkAbsorbSeen(unit, nameplate, s.hasAbsorb)
    s.hasAggro = Minimizer.Threat.PlayerHasAggro(unit)
    s.isPvP = Minimizer.Utils.IsPvPUnit(unit)
    s.isCasting, s.isUninterruptible, s.rawUninterruptible, s.isChanneling = Minimizer.Cast.GetState(unit)

    -- Prioridad focus > aggro > absorb > eliteType, calculada inline
    -- reutilizando lo que ya se acaba de leer arriba. NO llamar aqui a
    -- ComputeDisplayKind: esa funcion existe para los callers que NO tienen
    -- snapshot (fallback de hooks de repintado nativo en HealthBarColor.lua),
    -- y volveria a llamar a HasAbsorb/PlayerHasAggro desde cero -- doblando
    -- el coste de cada pase normal.
    if UnitIsUnit(unit, "focus") then
        s.displayKind = "focus"
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
    -- Note: nameplate is optional but passed through to HasAbsorb where needed
    if UnitIsUnit(unit, "focus") then
        return "focus"
    end
    if Minimizer.Threat and Minimizer.Threat.PlayerHasAggro and Minimizer.Threat.PlayerHasAggro(unit) then
        return "aggro"
    end
    local hasAbsorbNow = Minimizer.Absorb and Minimizer.Absorb.HasAbsorb and Minimizer.Absorb.HasAbsorb(unit, nameplate)
    if Minimizer.Core and Minimizer.Core.MarkAbsorbSeen and Minimizer.Core.MarkAbsorbSeen(unit, nameplate, hasAbsorbNow) then
        return "absorb"
    end
    if Minimizer.Classification and Minimizer.Classification.GetEliteType then
        return Minimizer.Classification.GetEliteType(unit)
    end
    return nil
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
