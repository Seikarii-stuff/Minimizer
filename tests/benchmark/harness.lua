-- tests/benchmark/harness.lua
-- Shared benchmark harness. It deliberately measures batches of operations so
-- Lua 5.1/LuaJIT's coarse os.clock resolution does not collapse p50/p90 to 0ms.
local TestHarness = dofile("tests/test_harness.lua")
local Mocks = TestHarness.Mocks
local Addon = TestHarness.addonTable

-- Match the lifecycle used by the functional suite: the addon is fully loaded
-- before any benchmark scenario mutates configuration or nameplates.
TestHarness.fireAddonLoaded()

local Harness = {}
Harness.Mocks = Mocks
Harness.Addon = Addon
Harness.ADDON_NAME = TestHarness.ADDON_NAME

Harness.DEFAULTS = {
    warmup = 3,
    samples = 9,
    batch = 100,
}

local function sorted(values)
    local copy = {}
    for i = 1, #values do copy[i] = values[i] end
    table.sort(copy)
    return copy
end

function Harness.percentile(values, p)
    if #values == 0 then return 0 end
    local s = sorted(values)
    local rank = math.floor((#s - 1) * p + 1.5)
    if rank < 1 then rank = 1 end
    if rank > #s then rank = #s end
    return s[rank]
end

function Harness.stats(samples)
    local total = 0
    local min, max
    for _, value in ipairs(samples) do
        total = total + value
        if not min or value < min then min = value end
        if not max or value > max then max = value end
    end
    local mean = #samples > 0 and total / #samples or 0
    return {
        mean = mean,
        min = min or 0,
        max = max or 0,
        p50 = Harness.percentile(samples, 0.50),
        p90 = Harness.percentile(samples, 0.90),
        p99 = Harness.percentile(samples, 0.99),
    }
end

local function forceCollect()
    collectgarbage("restart")
    collectgarbage("collect")
    collectgarbage("collect")
end

function Harness.heapKB()
    return collectgarbage("count")
end

function Harness.measure(spec)
    assert(type(spec) == "table" and type(spec.body) == "function", "benchmark spec/body required")
    local warmup = spec.warmup or Harness.DEFAULTS.warmup
    local samples = spec.samples or Harness.DEFAULTS.samples
    local batch = spec.batch or Harness.DEFAULTS.batch

    if spec.setup then spec.setup() end
    for _ = 1, warmup do
        spec.body(batch)
    end

    forceCollect()
    local retainedBefore = Harness.heapKB()
    local allocationStart = retainedBefore
    local timings = {}

    collectgarbage("stop")
    for _ = 1, samples do
        local start = os.clock()
        spec.body(batch)
        timings[#timings + 1] = os.clock() - start
    end
    local allocationEnd = Harness.heapKB()
    collectgarbage("restart")

    local timing = Harness.stats(timings)
    local retainedAfter
    if spec.cleanup then spec.cleanup() end
    forceCollect()
    retainedAfter = Harness.heapKB()

    local result = {
        name = spec.name or "unnamed",
        unit = spec.unit or "operation",
        batch = batch,
        samples = samples,
        warmup = warmup,
        secondsPerBatch = timing,
        msPerOperation = {
            mean = timing.mean * 1000 / batch,
            min = timing.min * 1000 / batch,
            max = timing.max * 1000 / batch,
            p50 = timing.p50 * 1000 / batch,
            p90 = timing.p90 * 1000 / batch,
            p99 = timing.p99 * 1000 / batch,
        },
        allocationKB = math.max(0, allocationEnd - allocationStart),
        allocationKBPerOperation = math.max(0, allocationEnd - allocationStart) / batch / samples,
        retainedKB = retainedAfter - retainedBefore,
    }
    if spec.metadata then
        result.metadata = spec.metadata
    end
    return result
end

function Harness.resetState()
    for key in pairs(Mocks.units) do
        if key ~= "player" then Mocks.units[key] = nil end
    end
    for key in pairs(Mocks.nameplates) do Mocks.nameplates[key] = nil end
    Mocks.time = 0
    Mocks.timers = {}
    Mocks.cooldowns = {}
    Mocks.unitClassificationCallCounts = {}
    Mocks.unitCastingInfoCallCounts = {}
    Mocks.unitChannelInfoCallCounts = {}

    if Addon.Lifecycle and Addon.Lifecycle.GetActiveNameplates then
        for unit in pairs(Addon.Lifecycle.GetActiveNameplates()) do
            Addon.Lifecycle.UnregisterNameplate(unit)
        end
    end
    if Addon.Cache and Addon.Cache.InvalidateAll then Addon.Cache.InvalidateAll() end
    if Addon.Threat and Addon.Threat.InvalidatePlayerTankCache then Addon.Threat.InvalidatePlayerTankCache() end

    if _G.MinimizerDB then
        _G.MinimizerDB.enableFocusFace = false
        _G.MinimizerDB.enableFocusArrows = false
        _G.MinimizerDB.wheelEnabled = false
    end
end

function Harness.makeUnits(count, options)
    options = options or {}
    for i = 1, count do
        local unit = "nameplate" .. i
        local casting = options.casters and i <= options.casters
        Mocks.CreateTestUnit(unit, {
            name = "Benchmark Mob " .. i,
            health = 100,
            healthMax = 100,
            level = 70,
            faction = "Horde",
            isPlayer = false,
            classification = options.classification or ((i % 10 == 0) and "elite" or "normal"),
            threatSituation = options.threatSituation or 0,
            inCombat = options.inCombat == true,
            absorbs = options.absorbs or 0,
            cast = casting and {
                name = "Benchmark Cast",
                startTime = Mocks.time * 1000,
                endTime = (Mocks.time + 2) * 1000,
                castID = i,
                uninterruptible = false,
            } or nil,
            auras = {},
        })
        Mocks.CreateTestNameplate(unit)
        if Addon.Lifecycle and Addon.Lifecycle.IncrementGeneration then Addon.Lifecycle.IncrementGeneration(unit) end
        if Addon.Dispatcher and Addon.Dispatcher.TrackUnit then Addon.Dispatcher.TrackUnit(unit) end
        if Addon.Threat and Addon.Threat.Invalidate then Addon.Threat.Invalidate(unit) end
        if Addon.Dispatcher and Addon.Dispatcher.ApplyToUnit then Addon.Dispatcher.ApplyToUnit(unit, true) end
    end
end

function Harness.activateThreat()
    Mocks.inGroup = true
    Mocks.inRaid = false
    if Addon.Threat and Addon.Threat.RefreshTankTokens then Addon.Threat.RefreshTankTokens() end
    if Addon.Threat and Addon.Threat.RefreshPlayerTankCache then Addon.Threat.RefreshPlayerTankCache() end
end

function Harness.fireUnitEvent(event, unit)
    Mocks.FireEvent(event, unit)
end

return Harness
