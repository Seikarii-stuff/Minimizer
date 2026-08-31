-- tests/benchmark/benchmark.lua
-- Full benchmark entry point.
-- Usage:
--   lua tests/benchmark/benchmark.lua          -- Fast (default)
--   lua tests/benchmark/benchmark.lua fast
--   lua tests/benchmark/benchmark.lua deep
--   lua tests/benchmark/benchmark.lua --self-test

local function parseProfile()
    local value = arg and arg[1]
    if value == "--self-test" then return "self-test" end
    if value == "deep" or value == "--deep" then return "deep" end
    return "fast"
end

local function runSelfTests()
    local H = dofile("tests/benchmark/harness.lua")
    local failures = 0
    local function check(ok, message)
        if ok then print("OK: " .. message) else failures = failures + 1; print("FAIL: " .. message) end
    end

    check(math.abs(H.percentile({1, 2, 3, 4, 5}, 0.50) - 3) < 0.001, "median percentile")
    check(math.abs(H.percentile({1, 2, 3, 4, 5}, 0.90) - 5) < 0.001, "p90 percentile")
    local calls = 0
    local result = H.measure({ name = "self-test", unit = "call", warmup = 1, samples = 2, batch = 10,
        body = function(batch) for _ = 1, batch do calls = calls + 1 end end })
    check(calls == 30, "warmup + measured batch accounting")
    check(result.msPerOperation.p50 >= 0, "timing statistics are non-negative")
    check(result.profile == "fast", "default profile is fast")
    check(result.measurementSeconds >= 0, "measurement timing exists")
    check(result.setupSeconds >= 0 and result.cleanupSeconds >= 0, "harness overhead timing exists")

    H.setProfile("deep")
    check(H.getProfile().name == "deep", "deep profile selection")
    check(H.getProfile().samples > H.PROFILES.fast.samples, "deep uses more samples")
    H.setProfile("fast")
    if failures > 0 then os.exit(1) end
    print("=== Benchmark harness self-tests: PASS ===")
end

local profile = parseProfile()
if profile == "self-test" then
    runSelfTests()
    return
end

local H = dofile("tests/benchmark/harness.lua")
H.setProfile(profile)
local Scenarios = dofile("tests/benchmark/scenarios.lua")

local startedAt = os.date("!%Y-%m-%dT%H:%M:%SZ")
local runnerStart = os.clock()
local results, groupTimings = Scenarios.all()
local runnerSeconds = os.clock() - runnerStart

local measurementSeconds, setupSeconds, cleanupSeconds = 0, 0, 0
for _, r in ipairs(results) do
    measurementSeconds = measurementSeconds + (r.measurementSeconds or 0)
    setupSeconds = setupSeconds + (r.setupSeconds or 0)
    cleanupSeconds = cleanupSeconds + (r.cleanupSeconds or 0)
end
local harnessSeconds = math.max(0, runnerSeconds - measurementSeconds)

local function csvField(value)
    value = tostring(value == nil and "" or value)
    if value:find('[,\"]') then value = '"' .. value:gsub('"', '""') .. '"' end
    return value
end

local lines = {
    "# Minimizer benchmark suite v5",
    "profile=" .. profile,
    "timestamp=" .. startedAt,
    "benchmark_schema=v5",
    "total_runtime_seconds=" .. string.format("%.6f", runnerSeconds),
    "measurement_seconds=" .. string.format("%.6f", measurementSeconds),
    "harness_seconds=" .. string.format("%.6f", harnessSeconds),
    "setup_seconds=" .. string.format("%.6f", setupSeconds),
    "cleanup_seconds=" .. string.format("%.6f", cleanupSeconds),
    "timing=CPU time via os.clock; each sample times a batch of operations with adaptive batching for tiny/normal work; GC is stopped during timed work",
    "allocation=heap growth while GC is stopped; this is allocation pressure/net heap growth, not an exact allocation counter and does not prove zero allocations",
    "retained=heap delta after cleanup and forced collection; negative values are runtime noise and are not proof of a leak-free lifecycle",
    "fast=representative regression workload; deep=full scaling/microbenchmark/retention workload",
    "thresholds=disabled until a stable baseline is recorded for this exact profile/environment",
    "",
    "group,name,unit,mean_ms,p50_ms,p90_ms,p99_ms,max_ms,heap_growth_kb,heap_growth_kb_per_op,retained_kb,warmup,samples,batch,allocation_measured,retention_measured,measurement_seconds,metadata",
}

for _, r in ipairs(results) do
    local metadata = ""
    if r.metadata then
        local parts = {}
        for k, v in pairs(r.metadata) do parts[#parts + 1] = tostring(k) .. "=" .. tostring(v) end
        table.sort(parts)
        metadata = table.concat(parts, ";")
    end
    lines[#lines + 1] = table.concat({
        csvField(r.group), csvField(r.name), csvField(r.unit),
        string.format("%.9f", r.msPerOperation.mean),
        string.format("%.9f", r.msPerOperation.p50),
        string.format("%.9f", r.msPerOperation.p90),
        string.format("%.9f", r.msPerOperation.p99),
        string.format("%.9f", r.msPerOperation.max),
        r.heapGrowthKB and string.format("%.4f", r.heapGrowthKB) or "",
        r.heapGrowthKBPerOperation and string.format("%.6f", r.heapGrowthKBPerOperation) or "",
        r.retainedKB and string.format("%.4f", r.retainedKB) or "",
        r.warmup, r.samples, r.batch,
        tostring(r.allocationMeasured), tostring(r.retentionMeasured),
        string.format("%.6f", r.measurementSeconds or 0), csvField(metadata),
    }, ",")
end

local content = table.concat(lines, "\n") .. "\n"
local function write(path, value)
    local fh, err = io.open(path, "w")
    if not fh then io.stderr:write("Could not write " .. path .. ": " .. tostring(err) .. "\n"); return false end
    fh:write(value); fh:close(); return true
end

local stamp = os.date("!%Y%m%dT%H%M%SZ")
local latest = "tests/results/benchmark_suite_latest.csv"
local archive = "tests/results/benchmark_suite_" .. stamp .. "_" .. profile .. ".csv"
if not write(latest, content) then os.exit(1) end
if not write(archive, content) then os.exit(1) end

print(string.format("Benchmark suite complete: profile=%s scenarios=%d", profile, #results))
print(string.format("Timestamp: %s", startedAt))
print(string.format("Total benchmark time: %.3fs", runnerSeconds))
print(string.format("Measured operation time: %.3fs", measurementSeconds))
print(string.format("Harness overhead: %.3fs (setup %.3fs, cleanup %.3fs)", harnessSeconds, setupSeconds, cleanupSeconds))
print("Results: " .. latest)
print("Archive: " .. archive)
print("")
print("--- Group runtime ---")
for group, seconds in pairs(groupTimings) do print(string.format("%-16s %.3fs", group, seconds)) end
print("")
print("--- Hot-path candidates (ordered by measured mean, inclusive scenarios) ---")
table.sort(results, function(a, b) return a.msPerOperation.mean > b.msPerOperation.mean end)
for i = 1, math.min(15, #results) do
    local r = results[i]
    print(string.format("%2d. %-32s %10.6f ms/op  heap=%s  retained=%s", i, r.name, r.msPerOperation.mean,
        r.heapGrowthKBPerOperation and string.format("%.4f KB/op", r.heapGrowthKBPerOperation) or "n/a",
        r.retainedKB and string.format("%.4f KB", r.retainedKB) or "n/a"))
end
print("")
print("Status: PASS")
print("No regression threshold is asserted: a baseline must first be recorded for this exact suite/profile/environment.")
