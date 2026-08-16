-- Small event-invalidated cache shared by decision functions.
local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Cache = Minimizer.Cache or {}
local Cache = Minimizer.Cache
Cache.units = Cache.units or {}

-- Prefijos precalculados para los `kind` conocidos usados en InvalidateUnit/
-- InvalidateAll, para no concatenar "kind .. ':'" en cada llamada (se
-- dispara por cada UNIT_THREAT_SITUATION_UPDATE/UNIT_THREAT_LIST_UPDATE).
-- Si se añade un `kind` nuevo en el futuro, agregar su entrada aqui; el
-- fallback (`kind .. ':'` inline) se mantiene por si el kind no esta en esta
-- tabla, asi que no rompe nada si alguien olvida actualizarla.
local _KNOWN_PREFIXES = {
    threat = "threat:",
}

local function GetPrefixForKind(kind)
    return _KNOWN_PREFIXES[kind] or (kind .. ":")
end

function Cache.GetUnitState(unit)
    if not unit then return nil end
    local state = Cache.units[unit]
    if not state then
        state = {}
        Cache.units[unit] = state
    end
    return state
end

-- Helpers para almacenar/leer entradas con generación adjunta.
function Cache.GetUnitKeyWithGeneration(unit, key)
    if not unit or not key then return nil end
    local state = Cache.units[unit]
    if not state then return nil end
    local entry = state[key]
    if not entry then return nil end
    local gen = Minimizer.Core and Minimizer.Core.GetPlateGeneration and Minimizer.Core.GetPlateGeneration(unit) or 0
    if type(entry) == "table" and entry.gen == gen then
        return entry.value
    end
    return nil
end

function Cache.SetUnitKeyWithGeneration(unit, key, value)
    if not unit or not key then return end
    local state = Cache.units[unit]
    if not state then
        state = {}
        Cache.units[unit] = state
    end
    local gen = Minimizer.Core and Minimizer.Core.GetPlateGeneration and Minimizer.Core.GetPlateGeneration(unit) or 0
    -- Reutilizar la entry existente en vez de crear una tabla nueva en cada
    -- escritura: esta función se llama por cada unidad/clave/pase, así que
    -- una tabla nueva por llamada es basura constante e innecesaria.
    local entry = state[key]
    if type(entry) == "table" then
        entry.value = value
        entry.gen = gen
    else
        state[key] = { value = value, gen = gen }
    end
end

function Cache.InvalidateUnit(unit, kind)
    if not unit then return end
    local state = Cache.units[unit]
    if not state then return end
    if kind then
        local prefix = GetPrefixForKind(kind)
        for k in pairs(state) do
            if k == kind or k:find(prefix, 1, true) == 1 then
                state[k] = nil
            end
        end
    else
        Cache.units[unit] = nil
    end
end

function Cache.InvalidateAll(kind)
    if kind then
        local prefix = GetPrefixForKind(kind)
        for _, state in pairs(Cache.units) do
            for k in pairs(state) do
                if k == kind or k:find(prefix, 1, true) == 1 then
                    state[k] = nil
                end
            end
        end
    else
        wipe(Cache.units)
    end
end
