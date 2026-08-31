-- tests/test_all.lua
-- Global runner: each functional test executes in an independent Lua process.
-- The benchmark is intentionally a separate category: it is run after the
-- functional suite, its exit status is authoritative, and its summary is
-- reported without feeding benchmark stdout through the functional parser.

local tests = {
    "tests/smoke_test.lua",
    "tests/classification_test.lua",
    "tests/utils_test.lua",
    "tests/interrupt_test.lua",
    "tests/decision_test.lua",
    "tests/cast_test.lua",
    "tests/threat_test.lua",
    "tests/absorb_test.lua",
    "tests/lifecycle_test.lua",
    "tests/overlays_test.lua",
    "tests/target_test.lua",
    "tests/focus_test.lua",
    "tests/halo_test.lua",
    "tests/widgets_test.lua",
    "tests/pips_test.lua",
    "tests/wheel_test.lua",
    "tests/ui_layering_test.lua",
    "tests/menu_test.lua",
    "tests/equivalence_test.lua",
    "tests/friendly_filter_safety_net_test.lua",
    "tests/threat_monitor/stable_state_test.lua",
}

local failures = {}
local totalRun = 0
local totalPassed = 0

local function processSucceeded(ok, reason, code)
    if ok == true then return true end
    if ok == nil then return false end
    if reason == "exit" and tonumber(code) == 0 then return true end
    return false
end

local function parseFunctionalSummary(out)
    local passed, run = out:match("=== [^\n]*: (%d+)/(%d+) passed ===")
    if passed and run then return tonumber(passed), tonumber(run) end

    local friendlyRun, friendlyFailed = out:match("Friendly filter / safety net tests: (%d+) run, (%d+) failed")
    if friendlyRun then
        friendlyRun = tonumber(friendlyRun)
        friendlyFailed = tonumber(friendlyFailed)
        return friendlyRun - friendlyFailed, friendlyRun
    end
    return nil, nil
end

print("=== FUNCTIONAL TESTS ===")
for _, t in ipairs(tests) do
    io.write("- ", t, " ... ")
    io.flush()
    local cmd = string.format('lua "%s" 2>&1', t)
    local handle = io.popen(cmd)
    if not handle then
        print("FAIL")
        table.insert(failures, { test = t, output = "Could not start Lua process." })
    else
        local out = handle:read("*a") or ""
        local ok, reason, code = handle:close()
        local passed, run = parseFunctionalSummary(out)
        local processOK = processSucceeded(ok, reason, code)
        local functionalOK = processOK and ((not passed or not run) or passed == run)

        if run and passed then
            totalRun = totalRun + run
            totalPassed = totalPassed + passed
        end

        if functionalOK then
            print("OK")
        else
            print("FAIL")
            table.insert(failures, { test = t, output = out })
        end
    end
end

print("")
if totalRun > 0 then
    print(string.format("=== GLOBAL TEST RESULTS: %d/%d passed ===", totalPassed, totalRun))
else
    print("=== GLOBAL TEST RESULTS: no functional summaries collected ===")
end

local functionalFailed = #failures > 0 or (totalRun > 0 and totalPassed ~= totalRun)

print("")
print("=== BENCHMARK ===")
print("Profile: fast")
local benchmarkHandle = io.popen('lua "tests/benchmark/benchmark.lua" fast 2>&1')
local benchmarkOutput = ""
local benchmarkOK = false
if benchmarkHandle then
    benchmarkOutput = benchmarkHandle:read("*a") or ""
    local ok, reason, code = benchmarkHandle:close()
    benchmarkOK = processSucceeded(ok, reason, code)
else
    benchmarkOutput = "Could not start benchmark process."
end

local benchmarkSummaryKeys = {
    "Benchmark suite complete:",
    "Timestamp:",
    "Total benchmark time:",
    "Measured operation time:",
    "Harness overhead:",
    "Results:",
    "Archive:",
    "Status:",
}
for line in benchmarkOutput:gmatch("([^\n\r]+)") do
    for _, key in ipairs(benchmarkSummaryKeys) do
        if line:find("^" .. key, 1, false) then
            print(line)
            break
        end
    end
end
if not benchmarkOK then
    print("Benchmark process: FAIL")
    print("--- benchmark output ---")
    print(benchmarkOutput)
else
    local status = benchmarkOutput:match("Status:%s*(%S+)")
    if status ~= "PASS" then
        benchmarkOK = false
        print("Benchmark process: FAIL (missing Status: PASS)")
    else
        print("Benchmark process: PASS")
    end
end

print("")
if functionalFailed then
    print("=== FAILURES SUMMARY ===")
    for _, f in ipairs(failures) do
        print("\n-- " .. f.test)
        for line in f.output:gmatch("([^\n\r]+)") do
            if line:find("FAIL") or line:find("ERROR") or line:find("stack traceback") then
                print(line)
            end
        end
    end
end

-- `--self-test` remains an independent benchmark-harness check. Running it
-- here would duplicate benchmark startup work and is therefore intentionally
-- not part of test_all.lua.
if functionalFailed or not benchmarkOK then os.exit(1) end
print("All functional tests and Fast benchmark passed.")
os.exit(0)
