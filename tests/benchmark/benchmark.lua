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

-- 1. Load Addon (dynamic reading from Minimizer.toc)
local function GetFileListFromToc(tocPath)
    local list = {}
    local fh = io.open(tocPath, "r")
    if not fh then
        error("No se pudo abrir el .toc en " .. tocPath .. " -- revisa la ruta")
    end
    for line in fh:lines() do
        local trimmed = line:match("^%s*(.-)%s*$")
        trimmed = trimmed:gsub("\\", "/")
        if trimmed ~= "" and not trimmed:match("^#") and not trimmed:match("^%.%.") then
            if trimmed:match("%.lua$") then
                table.insert(list, trimmed)
            end
        end
    end
    fh:close()
    return list
end

local files = GetFileListFromToc("Minimizer.toc")
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
        module.UpdateNamePlate = function(self, unit, nameplate, snapshot)
            local start = os.clock()
            orig(self, unit, nameplate, snapshot)
            local elapsed = os.clock() - start
            moduleStats[name].count = moduleStats[name].count + 1
            moduleStats[name].time  = moduleStats[name].time  + elapsed
        end
    end
end

-- 3b. Profile Decision y Classification (no son modulos registrados, pero
-- consumen tiempo real dentro de Core.ApplyToUnit -> son invisibles en el
-- profiling de "Module Breakdown" de arriba si no se instrumentan aparte).
local extraStats = {}

local function WrapFunction(namespace, fnName)
    if not namespace then return end
    local orig = namespace[fnName]
    if type(orig) ~= "function" then return end
    extraStats[fnName] = { count = 0, time = 0 }
    namespace[fnName] = function(...)
        local start = os.clock()
        local a, b, c, d = orig(...)
        local elapsed = os.clock() - start
        extraStats[fnName].count = extraStats[fnName].count + 1
        extraStats[fnName].time = extraStats[fnName].time + elapsed
        return a, b, c, d
    end
end

WrapFunction(addonTable.Decision, "ShouldSimplifyUnit")
WrapFunction(addonTable.Classification, "GetEliteType")
WrapFunction(addonTable.Threat, "PlayerHasAggro")
WrapFunction(addonTable.Absorb, "HasAbsorb")

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
line("--- Funciones no-modulo instrumentadas (Decision/Classification/Threat/Absorb) ---")
line(string.format("%-22s %-12s %-14s %-10s %s", "Funcion", "Total (s)", "Avg/call (ms)", "Calls", "Share"))
line(string.rep("-", 72))
local sortedExtra = {}
for name, stats in pairs(extraStats) do
    table.insert(sortedExtra, { name = name, stats = stats })
end
table.sort(sortedExtra, function(a, b) return a.stats.time > b.stats.time end)
for _, item in ipairs(sortedExtra) do
    local s = item.stats
    if s.count > 0 then
        local avgMs = (s.time / s.count) * 1000
        local percent = (s.time / totalTime) * 100
        line(string.format("%-22s %-12.4f %-14.6f %-10d %5.2f%%",
            item.name, s.time, avgMs, s.count, percent))
    end
end

-- ============================================================
-- 9. Medicion de throttle: cuantas veces por segundo se repintan
--    realmente los widgets de Target/Focus bajo un rafagueo de
--    SPELL_UPDATE_COOLDOWN (simula combate real, donde este evento
--    puede dispararse muy seguido).
-- ============================================================
if addonTable.Target and addonTable.Focus then
    -- Crear una unidad target y focus falsas para que UpdateTargetCDs /
    -- UpdateFace tengan algo que pintar.
    Mocks.CreateTestUnit("target", { name = "Target Dummy", health = 100, healthMax = 100, faction = "Horde" })
    Mocks.CreateTestNameplate("target")
    Mocks.CreateTestUnit("focus", { name = "Focus Dummy", health = 100, healthMax = 100, faction = "Horde" })
    Mocks.CreateTestNameplate("focus")

    local targetPaintCount, focusPaintCount = 0, 0
    local origTargetUpdate = addonTable.Target.UpdateTargetCDs
    addonTable.Target.UpdateTargetCDs = function(...)
        targetPaintCount = targetPaintCount + 1
        return origTargetUpdate(...)
    end
    local origFocusUpdate = addonTable.Focus.UpdateFace
    addonTable.Focus.UpdateFace = function(...)
        focusPaintCount = focusPaintCount + 1
        return origFocusUpdate(...)
    end

    -- Simular una rafaga de 100 eventos SPELL_UPDATE_COOLDOWN en 1 segundo
    -- simulado (combate con muchos cooldowns rotando).
    local SIMULATED_EVENTS = 100
    for i = 1, SIMULATED_EVENTS do
        Mocks.AdvanceTime(0.01) -- 100 eventos repartidos en 1 segundo
        Mocks.FireEvent("SPELL_UPDATE_COOLDOWN")
    end

    line("")
    line("--- Throttle check: Target/Focus repaints bajo rafaga de eventos ---")
    line(string.format("Eventos SPELL_UPDATE_COOLDOWN simulados : %d (en ~1s simulado)", SIMULATED_EVENTS))
    line(string.format("Target:UpdateTargetCDs() llamadas reales: %d", targetPaintCount))
    line(string.format("Focus:UpdateFace() llamadas reales       : %d", focusPaintCount))
    line("(Si estos numeros son cercanos a " .. SIMULATED_EVENTS .. ", el debounce actual NO esta limitando el repintado real y hace falta un throttle explicito, p.ej. limitar a max 1 repintado cada 0.1s con C_Timer)")
    line("")
end

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

-- 8. Umbral de regresion automatica
local REGRESSION_THRESHOLD_MS = 2.5 -- ajustar tras confirmar el baseline post-refactor
if avgFrameMs > REGRESSION_THRESHOLD_MS then
    error(string.format(
        "REGRESION DE PERFORMANCE: %.4fms/frame supera el umbral de %.4fms/frame",
        avgFrameMs, REGRESSION_THRESHOLD_MS))
end
print(string.format("Performance OK: %.4fms/frame (umbral: %.4fms/frame)", avgFrameMs, REGRESSION_THRESHOLD_MS))
