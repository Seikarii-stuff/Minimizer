-- tests/benchmark/benchmark.lua
-- Run from the project root:  lua tests/benchmark/benchmark.lua
local Mocks = dofile("tests/wow_mock.lua")

local ADDON_NAME = "Minimizer"
local addonTable = {}

local function LoadAddonFile(filepath)
    local func, err = loadfile(filepath)
    if not func then
        if filepath == "data/SpellData.lua" then
            addonTable.Data = addonTable.Data or { INTERRUPT_SPELLS = {} }
            return
        end
        error("Failed to load " .. filepath .. ": " .. tostring(err))
    end
    func(ADDON_NAME, addonTable)
end

-- 1. Load Addon (paths relative to project root)
local files = {
    "Bootstrap.lua", "Utils.lua", "Widgets.lua", "Config.lua",
    "Constants.lua", "data/SpellData.lua", "Cache.lua", "Threat.lua",
    "Absorb.lua", "Cast.lua", "ClassificationUtils.lua", "Decision.lua",
    "Interrupt.lua", "Core.lua", "Markers.lua", "HealthBarColor.lua",
    "CastingBar.lua", "Focus.lua", "Target.lua", "Events.lua", "SlashCommands.lua"
}
for _, file in ipairs(files) do LoadAddonFile(file) end

Mocks.FireEvent("ADDON_LOADED", ADDON_NAME)

-- 2. Setup Benchmark Data (50 Nameplates)
local NUM_NAMEPLATES = 50
for i = 1, NUM_NAMEPLATES do
    local unitId = "nameplate" .. i
    local isCasting = (i % 3 == 0)

    Mocks.CreateTestUnit(unitId, {
        name = "Test Mob " .. i,
        health = math.random(10, 100),
        healthMax = 100,
        level = 70,
        faction = "Horde",
        isPlayer = false,
        classification = (i % 10 == 0) and "elite" or "normal",
        threatSituation = math.random(0, 3),
        cast = isCasting and {
            name = "Test Spell",
            startTime = Mocks.time * 1000,
            endTime = (Mocks.time + 2) * 1000,
            uninterruptible = (i % 6 == 0),
        } or nil,
        auras = {
            { name = "Test Buff", icon = 123, count = 1, duration = 10,
              expirationTime = Mocks.time + 10, source = "player",
              helpful = false, harmful = true }
        }
    })
    Mocks.CreateTestNameplate(unitId)
    Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", unitId)
end

-- 3. Profile Modules
local moduleStats = {}
for name, module in pairs(addonTable.Modules) do
    if type(module.UpdateNamePlate) == "function" then
        moduleStats[name] = { count = 0, time = 0 }
        local orig = module.UpdateNamePlate
        module.UpdateNamePlate = function(self, unit, nameplate)
            local start = os.clock()
            orig(self, unit, nameplate)
            local elapsed = os.clock() - start
            moduleStats[name].count = moduleStats[name].count + 1
            moduleStats[name].time  = moduleStats[name].time  + elapsed
        end
    end
end

-- Core Profiling Wrapper
local coreStats = { count = 0, time = 0 }
local origApplyToAll = addonTable.Core.ApplyToAll
addonTable.Core.ApplyToAll = function()
    local start = os.clock()
    origApplyToAll()
    local elapsed = os.clock() - start
    coreStats.count = coreStats.count + 1
    coreStats.time  = coreStats.time  + elapsed
end

-- 4. Run Benchmark
local ITERATIONS = 1000
print(string.format("Running benchmark: %d iterations x %d nameplates...", ITERATIONS, NUM_NAMEPLATES))

local benchStart = os.clock()
for i = 1, ITERATIONS do
    Mocks.AdvanceTime(0.01)
    addonTable.Core.ApplyToAll()
end
local totalTime = os.clock() - benchStart

-- 5. Build Report
local lines = {}
local function line(s) lines[#lines + 1] = s end

local timestamp = os.date("%Y-%m-%d %H:%M:%S")
local avgFrameMs = (coreStats.count > 0) and (coreStats.time / coreStats.count) * 1000 or 0

line("")
line("=== Minimizer Benchmark Results ===")
line("Date       : " .. timestamp)
line(string.format("Iterations : %d frames", ITERATIONS))
line(string.format("Nameplates : %d units", NUM_NAMEPLATES))
line(string.format("Total Time : %.4f s", totalTime))
line(string.format("Avg/Frame  : %.6f ms  (ApplyToAll)", avgFrameMs))
line("")
line("--- Module Breakdown (sorted by total cost) ---")
line(string.format("%-22s %-12s %-14s %-10s %s", "Module", "Total (s)", "Avg/call (ms)", "Calls", "Share"))
line(string.rep("-", 72))

local sortedModules = {}
for name, stats in pairs(moduleStats) do
    table.insert(sortedModules, { name = name, stats = stats })
end
table.sort(sortedModules, function(a, b) return a.stats.time > b.stats.time end)

for _, mod in ipairs(sortedModules) do
    local s = mod.stats
    if s.count > 0 then
        local avgMs   = (s.time / s.count) * 1000
        local percent = (s.time / totalTime) * 100
        line(string.format("%-22s %-12.4f %-14.6f %-10d %5.2f%%",
            mod.name, s.time, avgMs, s.count, percent))
    end
end

line("")
line(string.rep("=", 72))
line("")

-- 6. Print to stdout
local report = table.concat(lines, "\n")
print(report)

-- 7. Save to tests/results/
local dateTag   = os.date("%Y%m%d_%H%M%S")
local outPath   = "tests/results/benchmark_" .. dateTag .. ".txt"
local fh, err   = io.open(outPath, "w")
if fh then
    fh:write(report)
    fh:close()
    print("Results saved to: " .. outPath)
else
    io.stderr:write("Warning: could not write results file: " .. tostring(err) .. "\n")
end
