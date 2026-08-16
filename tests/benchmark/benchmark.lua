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

-- Compat shim: table.pack no existe en Lua 5.1, empaquetar valores y contar n.
local function pack_results(...)
    local t = {...}
    t.n = select('#', ...)
    return t
end

local function WrapFunction(namespace, fnName)
    if not namespace then return end
    local orig = namespace[fnName]
    if type(orig) ~= "function" then return end
    extraStats[fnName] = { count = 0, time = 0 }
    namespace[fnName] = function(...)
        local start = os.clock()
        -- table.pack conserva TODOS los valores de retorno (incluye .n para
        -- distinguir nils explícitos de "no hubo más valores"), a diferencia
        -- de `local a,b,c,d = orig(...)` que truncaba silenciosamente a 4.
        local results = (table.pack and table.pack(orig(...))) or pack_results(orig(...))
        local elapsed = os.clock() - start
        extraStats[fnName].count = extraStats[fnName].count + 1
        extraStats[fnName].time = extraStats[fnName].time + elapsed
        local unpack_fn = table.unpack or unpack
        return unpack_fn(results, 1, results.n)
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
-- Improved benchmark: realistic hot-path is ApplyToUnit per event/unit.
-- We simulate per-unit events, random state churn (casts/threat/absorbs), and
-- occasional bursts of simultaneous updates to exercise worst-cases.
local ITERATIONS = 1000
print(string.format("Running benchmark: %d iterations (simulated frames) x %d nameplates...", ITERATIONS, NUM_NAMEPLATES))

local perCallSamples = {} -- elapsed times (s) per ApplyToUnit call
local perFrameApplyCounts = {} -- number of ApplyToUnit calls per frame

local benchStart = os.clock()
for frame = 1, ITERATIONS do
    -- Advance a small time slice (simulate 100 FPS-ish)
    Mocks.AdvanceTime(0.01)

    -- Occasionally create a burst (simulate many nameplates recycled / many casts start)
    local burst = (math.random() < 0.02) -- 2% of frames are bursts
    local updatesThisFrame = burst and math.random(10, math.min(30, NUM_NAMEPLATES)) or math.random(1, 5)

    -- Choose random units to update this frame
    local calls = 0
    for j = 1, updatesThisFrame do
        local idx = math.random(1, NUM_NAMEPLATES)
        local unit = "nameplate" .. idx

        -- Introduce churn: with some probability mutate the unit state so
        -- code paths that invalidate caches and flip persistent flags are hit.
        local u = Mocks.units[unit]
        if u then
            -- End casts whose endTime passed
            if u.cast and (u.cast.endTime or 0) <= Mocks.time then
                u.cast = nil
            end
            -- Start a new cast sometimes
            if (not u.cast) and (math.random() < 0.05 or burst and math.random() < 0.3) then
                local dur = 0.8 + math.random() * 3.0
                u.cast = {
                    name = "Bench Spell",
                    startTime = Mocks.time * 1000,
                    endTime = (Mocks.time + dur) * 1000,
                    castID = math.random(1, 1000000),
                    uninterruptible = (math.random() < 0.1),
                }
            end
            -- Randomly toggle absorbs/threat to exercise Decision/Absorb/Threat
            if math.random() < 0.03 then
                u.absorbs = (math.random() < 0.5) and math.random(10, 500) or 0
            end
            if math.random() < 0.05 then
                u.threatSituation = math.random(0, 3)
            end
        end

        -- Measure ApplyToUnit (hot-path)
        local start = os.clock()
        addonTable.Core.ApplyToUnit(unit)
        local elapsed = os.clock() - start
        perCallSamples[#perCallSamples + 1] = elapsed
        calls = calls + 1
    end
    perFrameApplyCounts[#perFrameApplyCounts + 1] = calls
end

local totalTime = os.clock() - benchStart

-- 5. Build Report
local lines = {}
local function line(s) lines[#lines + 1] = s end

local timestamp = os.date("%Y-%m-%d %H:%M:%S")

-- Compute per-call statistics (ms) and percentiles
local totalCalls = #perCallSamples
local totalCallTime = 0
for _, v in ipairs(perCallSamples) do totalCallTime = totalCallTime + v end
local avgCallMs = (totalCalls > 0) and (totalCallTime / totalCalls) * 1000 or 0

local function ms(v) return v * 1000 end
local sortedSamples = {}
for i, v in ipairs(perCallSamples) do sortedSamples[i] = v end
table.sort(sortedSamples)
local function percentile(p)
    if #sortedSamples == 0 then return 0 end
    local idx = math.max(1, math.floor(#sortedSamples * p / 100 + 0.5))
    return sortedSamples[idx] * 1000
end
local p50 = percentile(50)
local p90 = percentile(90)
local p99 = percentile(99)
local maxCallMs = (#sortedSamples > 0) and (sortedSamples[#sortedSamples] * 1000) or 0

local worstFrameCalls = 0
for _, c in ipairs(perFrameApplyCounts) do if c > worstFrameCalls then worstFrameCalls = c end end

line("")
line("=== Minimizer Benchmark Results ===")
line("Date       : " .. timestamp)
line(string.format("Iterations : %d frames", ITERATIONS))
line(string.format("Nameplates : %d units", NUM_NAMEPLATES))
line(string.format("Total Time : %.4f s", totalTime))
line(string.format("Total ApplyToUnit calls : %d", totalCalls))
line(string.format("Avg ApplyToUnit  : %.6f ms", avgCallMs))
line(string.format("P50 / P90 / P99 / Max : %.3f ms / %.3f ms / %.3f ms / %.3f ms", p50, p90, p99, maxCallMs))
line(string.format("Worst frame (calls)   : %d", worstFrameCalls))
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
-- Regression threshold: use P90 per-ApplyToUnit as a conservative indicator.
local REGRESSION_THRESHOLD_MS = 2.5 -- ajustar tras confirmar el baseline post-refactor
if p90 > REGRESSION_THRESHOLD_MS then
    error(string.format(
        "REGRESION DE PERFORMANCE: p90 ApplyToUnit = %.4fms supera el umbral de %.4fms",
        p90, REGRESSION_THRESHOLD_MS))
end
print(string.format("Performance OK: p90 ApplyToUnit = %.4fms (umbral: %.4fms)", p90, REGRESSION_THRESHOLD_MS))
