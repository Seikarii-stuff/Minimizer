-- benchmark.lua
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

-- 1. Load Addon
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
    local isTarget = (i == 1)
    
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
            { name = "Test Buff", icon = 123, count = 1, duration = 10, expirationTime = Mocks.time + 10, source = "player", helpful = false, harmful = true }
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
            moduleStats[name].time = moduleStats[name].time + elapsed
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
    coreStats.time = coreStats.time + elapsed
end

-- 4. Run Benchmark
local ITERATIONS = 1000
print(string.format("Running benchmark for %d iterations over %d nameplates...", ITERATIONS, NUM_NAMEPLATES))

local benchStart = os.clock()

for i = 1, ITERATIONS do
    Mocks.AdvanceTime(0.01)
    addonTable.Core.ApplyToAll()
end

local benchEnd = os.clock()
local totalTime = benchEnd - benchStart

-- 5. Report
print("\n=== Benchmark Results ===")
print(string.format("Total Time: %.4f seconds", totalTime))
print(string.format("Frames: %d", ITERATIONS))
print(string.format("Avg Time per Frame (ApplyToAll): %.6f ms", (coreStats.time / coreStats.count) * 1000))

print("\n--- Module Breakdown ---")
local sortedModules = {}
for name, stats in pairs(moduleStats) do
    table.insert(sortedModules, { name = name, stats = stats })
end
table.sort(sortedModules, function(a, b) return a.stats.time > b.stats.time end)

for _, mod in ipairs(sortedModules) do
    local s = mod.stats
    if s.count > 0 then
        local avgTimeMs = (s.time / s.count) * 1000
        local percent = (s.time / totalTime) * 100
        print(string.format("%-20s: Total: %.4fs | Avg/call: %.6fms | Calls: %d | Total Share: %5.2f%%", 
            mod.name, s.time, avgTimeMs, s.count, percent))
    end
end
