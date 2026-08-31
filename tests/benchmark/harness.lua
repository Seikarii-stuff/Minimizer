-- tests/benchmark/harness.lua
-- Shared benchmark harness. The runner uses profile-driven sampling so the
-- normal suite stays fast without turning very cheap operations into timer-noise.
local TestHarness = dofile("tests/test_harness.lua")
local Mocks = TestHarness.Mocks
local Addon = TestHarness.addonTable

TestHarness.fireAddonLoaded()

local PROFILES = {
    fast = {
        name = "fast",
        warmup = 2,
        samples = 7,
        batch = { tiny = 1000, normal = 200, heavy = 25, cold = 8 },
        minSampleSeconds = 0.002,
        maxBatch = { tiny = 100000, normal = 5000, heavy = 100, cold = 16 },
        allocation = false,
        retention = false,
    },
    deep = {
        name = "deep",
        warmup = 3,
        samples = 15,
        batch = { tiny = 1000, normal = 200, heavy = 25, cold = 8 },
        minSampleSeconds = 0.003,
        maxBatch = { tiny = 250000, normal = 10000, heavy = 250, cold = 32 },
        allocation = true,
        retention = true,
    },
}

local Harness = {}
Harness.Mocks = Mocks
Harness.Addon = Addon
Harness.ADDON_NAME = TestHarness.ADDON_NAME
Harness.PROFILES = PROFILES
Harness.profile = PROFILES.fast

function Harness.setProfile(name)
    local profile = PROFILES[name]
    assert(profile, "unknown benchmark profile: " .. tostring(name))
    Harness.profile = profile
end

function Harness.getProfile()
    return Harness.profile
end

function Harness.profileValue(key, default)
    local value = Harness.profile[key]
    if value == nil then return default end
    return value
end

function Harness.batch(kind)
    local batches = Harness.profile.batch
    return batches[kind or "normal"] or batches.normal
end

local function maxBatch(kind)
    local batches = Harness.profile.maxBatch
    return batches[kind or "normal"] or batches.normal
end

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

local function calibrateBatch(spec, batch)
    -- Explicit batches are part of the public harness contract (and are used
    -- by the self-test). Only profile-selected tiny/normal work is calibrated.
    if spec.batch ~= nil or spec.cost == "heavy" or spec.cost == "cold" then return batch end

    local target = Harness.profile.minSampleSeconds
    local cap = maxBatch(spec.cost)
    local start = os.clock()
    spec.body(batch)
    local elapsed = os.clock() - start
    if elapsed <= 0 or elapsed < target then
        local multiplier = elapsed > 0 and math.ceil(target / elapsed) or 10
        if multiplier < 2 then multiplier = 2 end
        batch = math.min(cap, batch * multiplier)
    end
    return batch
end

function Harness.measure(spec)
    assert(type(spec) == "table" and type(spec.body) == "function", "benchmark spec/body required")
    local profile = Harness.profile
    local warmup = spec.warmup or profile.warmup
    local samples = spec.samples or profile.samples
    local batch = spec.batch or Harness.batch(spec.cost)
    local allocation = spec.allocation
    if allocation == nil then allocation = profile.allocation end
    local retention = spec.retention
    if retention == nil then retention = profile.retention end

    local setupStart = os.clock()
    if spec.setup then spec.setup() end
    local setupSeconds = os.clock() - setupStart

    for _ = 1, warmup do spec.body(batch) end
    batch = calibrateBatch(spec, batch)

    -- Full GC is deliberately not part of every Fast measurement. It was one
    -- of the largest sources of runner overhead in the previous suite. The
    -- timed operation still runs with GC stopped; isolated allocation/retention
    -- scenarios opt back into the full collection protocol.
    local retainedBefore
    if allocation or retention then
        forceCollect()
        retainedBefore = Harness.heapKB()
    end

    local timings = {}
    collectgarbage("stop")
    local measureStart = os.clock()
    for _ = 1, samples do
        local start = os.clock()
        spec.body(batch)
        timings[#timings + 1] = os.clock() - start
    end
    local measureSeconds = os.clock() - measureStart
    local heapGrowthEnd = allocation and Harness.heapKB() or nil
    collectgarbage("restart")

    local cleanupStart = os.clock()
    if spec.cleanup then spec.cleanup() end
    local cleanupSeconds = os.clock() - cleanupStart

    local retainedAfter
    if retention then
        forceCollect()
        retainedAfter = Harness.heapKB()
    end

    local timing = Harness.stats(timings)
    local heapGrowthKB = allocation and math.max(0, heapGrowthEnd - retainedBefore) or nil
    local retainedKB = retention and (retainedAfter - retainedBefore) or nil
    local result = {
        profile = profile.name,
        name = spec.name or "unnamed",
        unit = spec.unit or "operation",
        batch = batch,
        samples = samples,
        warmup = warmup,
        secondsPerBatch = timing,
        measurementSeconds = measureSeconds,
        setupSeconds = setupSeconds,
        cleanupSeconds = cleanupSeconds,
        allocationMeasured = allocation == true,
        retentionMeasured = retention == true,
        msPerOperation = {
            mean = timing.mean * 1000 / batch,
            min = timing.min * 1000 / batch,
            max = timing.max * 1000 / batch,
            p50 = timing.p50 * 1000 / batch,
            p90 = timing.p90 * 1000 / batch,
            p99 = timing.p99 * 1000 / batch,
        },
        -- This is net heap growth while GC is stopped, not an exact allocation
        -- counter. A zero/negative net result cannot prove zero allocations.
        heapGrowthKB = heapGrowthKB,
        heapGrowthKBPerOperation = allocation and heapGrowthKB / (batch * samples) or nil,
        retainedKB = retainedKB,
    }
    if spec.metadata then result.metadata = spec.metadata end
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
