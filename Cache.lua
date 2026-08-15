-- Small event-invalidated cache shared by decision functions.
local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Cache = Minimizer.Cache or {}
local Cache = Minimizer.Cache
Cache.units = Cache.units or {}

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
    state[key] = { value = value, gen = gen }
end

function Cache.InvalidateUnit(unit, kind)
    if not unit then return end
    local state = Cache.units[unit]
    if not state then return end
    if kind then
        -- Remove keys equal to kind or starting with kind..":" (e.g. "threat:player").
        for k in pairs(state) do
            if k == kind or k:match("^"..kind..":") then
                state[k] = nil
            end
        end
    else
        Cache.units[unit] = nil
    end
end

function Cache.InvalidateAll(kind)
    if kind then
        for _, state in pairs(Cache.units) do
            for k in pairs(state) do
                if k == kind or k:match("^"..kind..":") then
                    state[k] = nil
                end
            end
        end
    else
        wipe(Cache.units)
    end
end
