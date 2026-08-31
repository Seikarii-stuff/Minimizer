-- tests/benchmark/benchmark.lua
-- Full benchmark entry point.
-- Usage:
--   lua tests/benchmark/benchmark.lua
--   lua tests/benchmark/benchmark.lua --self-test
--
-- The suite is intentionally separate from tests/test_all.lua: benchmarks are
-- measurements, not pass/fail functional tests, and their timing must not be
-- contaminated by the normal test runner.
local function getCommitSHA()
    local pipe = io.popen("git rev-parse HEAD 2>/dev/null")
    if not pipe then return "unknown" end
    local sha = pipe:read("*l") or "unknown"
    pipe:close()
    return sha
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
    local result = H.measure({
        name = "self-test",
        unit = "call",
        warmup = 1,
        samples = 2,
        batch = 10,
        body = function(batch)
            for _ = 1, batch do calls = calls + 1 end
        end,
    })
    check(calls == 30, "warmup + measured batch accounting")
    check(result.msPerOperation.p50 >= 0, "timing statistics are non-negative")
    check(result.allocationKBPerOperation >= 0, "allocation accounting is non-negative")
    check(type(result.retainedKB) == "number", "retained memory accounting exists")
    if failures > 0 then os.exit(1) end
    print("=== Benchmark harness self-tests: PASS ===")
end

if arg and arg[1] == "--self-test" then
    runSelfTests()
    return
end

local H = dofile("tests/benchmark/harness.lua")
local Scenarios = dofile("tests/benchmark/scenarios.lua")

local sha = getCommitSHA()
local startedAt = os.date("!%Y-%m-%dT%H:%M:%SZ")
local results = Scenarios.all()

local function csvField(value)
    value = tostring(value == nil and "" or value)
    if value:find('[,\"]') then value = '"' .. value:gsub('"', '""') .. '"' end
    return value
end

local lines = {}
lines[#lines + 1] = "# Minimizer benchmark suite v2"
lines[#lines + 1] = "commit=" .. sha
lines[#lines + 1] = "started_at=" .. startedAt
lines[#lines + 1] = "timing=CPU time via os.clock; each sample times a batch of operations"
lines[#lines + 1] = "allocation=heap growth with GC stopped during measured batches; this is allocation pressure, not an exact allocation counter"
lines[#lines + 1] = "retained=heap delta after cleanup and two full collections; negative values are possible measurement noise and are not treated as leaks"
lines[#lines + 1] = "thresholds=disabled until a stable baseline is recorded for this suite/environment"
lines[#lines + 1] = ""
lines[#lines + 1] = table.concat({"group","name","unit","mean_ms","p50_ms","p90_ms","p99_ms","max_ms","allocation_kb","allocation_kb_per_op","retained_kb","warmup","samples","batch","metadata"}, ",")

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
        string.format("%.4f", r.allocationKB),
        string.format("%.6f", r.allocationKBPerOperation),
        string.format("%.4f", r.retainedKB),
        r.warmup, r.samples, r.batch, csvField(metadata),
    }, ",")
end

local function write(path, content)
    local fh, err = io.open(path, "w")
    if not fh then
        io.stderr:write("Could not write " .. path .. ": " .. tostring(err) .. "\n")
        return false
    end
    fh:write(content)
    fh:close()
    return true
end

local content = table.concat(lines, "\n") .. "\n"
local stamp = os.date("!%Y%m%dT%H%M%SZ")
local latest = "tests/results/benchmark_suite_latest.csv"
local archive = "tests/results/benchmark_suite_" .. (sha ~= "unknown" and sha:sub(1, 12) or stamp) .. ".csv"

assert(write(latest, content))
if sha ~= "unknown" then write(archive, content) end

print(string.format("Benchmark suite complete: %d scenarios", #results))
print("Commit: " .. sha)
print("Results: " .. latest)
if sha ~= "unknown" then print("Archive: " .. archive) end
print("")
print("--- Hot-path candidates (ordered by measured mean, inclusive scenarios) ---")
table.sort(results, function(a, b) return a.msPerOperation.mean > b.msPerOperation.mean end)
for i = 1, math.min(15, #results) do
    local r = results[i]
    print(string.format("%2d. %-32s %10.6f ms/op  alloc=%8.4f KB/op  retained=%8.4f KB",
        i, r.name, r.msPerOperation.mean, r.allocationKBPerOperation, r.retainedKB))
end
print("")
print("No regression threshold is asserted: a baseline must first be recorded for this exact suite/environment.")
