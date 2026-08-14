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

function Cache.InvalidateUnit(unit, kind)
    if not unit then return end
    local state = Cache.units[unit]
    if not state then return end
    if kind then
        state[kind] = nil
    else
        Cache.units[unit] = nil
    end
end

function Cache.InvalidateAll(kind)
    if kind then
        for _, state in pairs(Cache.units) do
            state[kind] = nil
        end
    else
        wipe(Cache.units)
    end
end
