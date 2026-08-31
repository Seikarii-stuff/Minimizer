-- tests/benchmark/scenarios.lua
local H = dofile("tests/benchmark/harness.lua")
local M = {}
local A = H.Addon
local Mocks = H.Mocks

local function bench(name, unit, body, metadata, options)
    options = options or {}
    options.name = name
    options.unit = unit
    options.body = body
    options.metadata = metadata
    return H.measure(options)
end

local function levels(deep, fast)
    return H.getProfile().name == "deep" and deep or fast
end

function M.coreScaling()
    local results = {}
    for _, n in ipairs(levels({1, 10, 25, 50, 100}, {1, 50, 100})) do
        H.resetState(); H.makeUnits(n)
        results[#results + 1] = bench("core.apply_to_all." .. n, "ApplyToUnit per active plate", function(batch)
            for _ = 1, batch do A.Dispatcher.ApplyToAll(false) end
        end, { subsystem = "Core/Dispatcher", units = n }, { cost = "heavy" })
    end
    return results
end

function M.decisionClassification()
    local results = {}
    H.resetState(); H.makeUnits(1)
    local unit, plate = "nameplate1", Mocks.nameplates.nameplate1
    results[#results + 1] = bench("classification.single", "GetEliteType", function(batch)
        for _ = 1, batch do A.Classification.GetEliteType(unit) end
    end, { subsystem = "Classification", units = 1 }, { cost = "tiny" })
    results[#results + 1] = bench("decision.single", "ShouldSimplifyUnit", function(batch)
        for _ = 1, batch do A.Decision.ShouldSimplifyUnit(unit, plate) end
    end, { subsystem = "Decision", units = 1 }, { cost = "tiny" })

    for _, n in ipairs(levels({10, 50, 100}, {50})) do
        H.resetState(); H.makeUnits(n)
        results[#results + 1] = bench("decision.apply_all." .. n, "ApplyToUnit per active plate", function(batch)
            for _ = 1, batch do A.Dispatcher.ApplyToAll(false) end
        end, { subsystem = "Decision + Snapshot + modules", units = n }, { cost = "heavy" })
    end
    return results
end

function M.threatScaling()
    local results = {}
    for _, n in ipairs(levels({1, 5, 10, 20, 50}, {10, 50})) do
        H.resetState(); H.activateThreat(); H.makeUnits(n, { inCombat = true, threatSituation = 1 })
        local units = {}
        for i = 1, n do units[i] = "nameplate" .. i end

        -- Per-unit query: deliberately isolates the cache/query cost. The
        -- `units` metadata must not be mistaken for work done per operation.
        results[#results + 1] = bench("threat.query." .. n, "GetUnitThreatState", function(batch)
            for i = 1, batch do A.Threat.GetUnitThreatState(units[((i - 1) % n) + 1]) end
        end, { subsystem = "Threat", units = n, workload = "single-unit query" }, { cost = "normal" })

        -- System-shaped workload: every logical operation processes the whole
        -- tracked set, so scaling the population changes the amount of Threat
        -- work rather than only changing which unit is queried.
        results[#results + 1] = bench("threat.multi_unit." .. n, "Threat query across all tracked units", function(batch)
            for _ = 1, batch do
                for i = 1, n do A.Threat.GetUnitThreatState(units[i]) end
            end
        end, { subsystem = "Threat", units = n, workload = "all tracked units" }, { cost = "heavy" })

        results[#results + 1] = bench("threat.invalidation." .. n, "Invalidate + GetUnitThreatState across all units", function(batch)
            for _ = 1, batch do
                for i = 1, n do
                    A.Threat.Invalidate(units[i])
                    A.Threat.GetUnitThreatState(units[i])
                end
            end
        end, { subsystem = "Threat", units = n, workload = "changed/event path for all units" }, { cost = "heavy", allocation = true })
    end
    return results
end

function M.dispatcherEvents()
    local results = {}
    for _, n in ipairs(levels({10, 50, 100}, {50})) do
        H.resetState(); H.activateThreat(); H.makeUnits(n, { inCombat = true, threatSituation = 1, casters = math.min(10, n) })
        local events = {
            { "UNIT_THREAT_SITUATION_UPDATE", "nameplate1" },
            { "UNIT_SPELLCAST_START", "nameplate1" },
            { "UNIT_ABSORB_AMOUNT_CHANGED", "nameplate2" },
            { "UNIT_CLASSIFICATION_CHANGED", "nameplate3" },
        }
        results[#results + 1] = bench("event_storm." .. n, "mixed unit events", function(batch)
            for i = 1, batch do
                local event = events[((i - 1) % #events) + 1]
                Mocks.FireEvent(event[1], event[2])
            end
        end, { subsystem = "Events + Dispatcher", units = n, workload = "mixed plausible unit events" }, { cost = "heavy" })
    end
    return results
end

function M.castScaling()
    local results = {}
    for _, casters in ipairs(levels({1, 5, 10, 20}, {10, 20})) do
        H.resetState(); H.makeUnits(casters, { casters = casters })
        local units = {}
        for i = 1, casters do units[i] = "nameplate" .. i end
        results[#results + 1] = bench("cast.query." .. casters, "Cast.GetState", function(batch)
            for i = 1, batch do A.Cast.GetState(units[((i - 1) % casters) + 1]) end
        end, { subsystem = "Cast", casters = casters, workload = "single-caster state query" }, { cost = "normal" })
        results[#results + 1] = bench("cast.pipeline." .. casters, "Update all active casters", function(batch)
            for _ = 1, batch do
                for i = 1, casters do
                    local unit = units[i]
                    A.Cast.GetState(unit)
                    A.Dispatcher.ApplyToUnit(unit, false)
                end
            end
        end, { subsystem = "Cast + integrated pipeline", casters = casters, workload = "state detection + castbar-related pipeline" }, { cost = "heavy" })
    end
    return results
end

function M.absorbScaling()
    local results = {}
    for _, n in ipairs(levels({1, 10, 50, 100}, {50})) do
        H.resetState(); H.makeUnits(n, { absorbs = 250 })
        local units = {}
        for i = 1, n do units[i] = "nameplate" .. i end
        results[#results + 1] = bench("absorb." .. n, "HasAbsorb + GetTotalAbsorbs", function(batch)
            for i = 1, batch do
                local unit = units[((i - 1) % n) + 1]
                local plate = Mocks.nameplates[unit]
                A.Absorb.HasAbsorb(unit, plate)
                A.Absorb.GetTotalAbsorbs(unit)
            end
        end, { subsystem = "Absorb", units = n }, { cost = "normal" })
    end
    return results
end

function M.haloAndWheel()
    local results = {}
    local host = _G.CreateFrame("Frame", nil, _G.UIParent)
    results[#results + 1] = bench("halo.cold", "Halo.Create", function(batch)
        for i = 1, batch do
            local halo = A.Halo.Create(host, { size = 46 })
            halo:ShowFor(107574); halo:Hide()
        end
    end, { subsystem = "Halo", path = "cold/create" }, { batch = H.batch("cold"), samples = H.getProfile().samples, cost = "cold", allocation = true })

    local halo = A.Halo.Create(host, { size = 46 })
    results[#results + 1] = bench("halo.hot", "ShowFor/Hide", function(batch)
        for _ = 1, batch do halo:ShowFor(107574); halo:Hide() end
    end, { subsystem = "Halo", path = "hot/reused" }, { cost = "normal" })

    _G.MinimizerDB.wheelEnabled = false; A.Wheel:ApplyConfig()
    results[#results + 1] = bench("wheel.disabled", "Wheel.Update", function(batch)
        for _ = 1, batch do A.Wheel:Update() end
    end, { subsystem = "Wheel", state = "disabled" }, { cost = "normal" })

    _G.MinimizerDB.wheelEnabled = true; A.Wheel:ApplyConfig()
    results[#results + 1] = bench("wheel.active", "Wheel.Update", function(batch)
        for _ = 1, batch do A.Wheel:Update() end
    end, { subsystem = "Wheel", state = "active" }, { cost = "normal" })
    return results
end

function M.pips()
    local results = {}
    local host = _G.CreateFrame("Frame", nil, _G.UIParent)
    local pips = A.Pips.CreatePips(host, "BenchmarkPip", 75)
    results[#results + 1] = bench("pips.hot", "UpdatePips", function(batch)
        for _ = 1, batch do A.Pips.UpdatePips(pips) end
    end, { subsystem = "Pips", path = "hot/reused" }, { cost = "normal" })
    results[#results + 1] = bench("pips.radius", "SetRadius", function(batch)
        for i = 1, batch do A.Pips.SetRadius(pips, 60 + (i % 20)) end
    end, { subsystem = "Pips", path = "layout/config" }, { cost = "normal" })
    return results
end

function M.targetFocus()
    local results = {}
    H.resetState()
    Mocks.CreateTestUnit("target", { name = "Target", health = 100, healthMax = 100, faction = "Horde", isPlayer = false, classification = "normal", threatSituation = 1 })
    Mocks.CreateTestNameplate("target")
    Mocks.CreateTestUnit("focus", { name = "Focus", health = 100, healthMax = 100, faction = "Horde", isPlayer = false, classification = "elite", threatSituation = 1 })
    Mocks.CreateTestNameplate("focus")
    Mocks.units.target.guid = "target-guid"; Mocks.units.focus.guid = "focus-guid"
    _G.MinimizerDB.enableFocusFace = true

    results[#results + 1] = bench("target.update", "Target:UpdateTargetCDs", function(batch)
        for _ = 1, batch do A.Target:UpdateTargetCDs() end
    end, { subsystem = "Target", halo = true }, { cost = "normal" })
    results[#results + 1] = bench("focus.update", "Focus:UpdateFace", function(batch)
        for _ = 1, batch do A.Focus:UpdateFace() end
    end, { subsystem = "Focus", halo = false, portrait = true }, { cost = "normal" })
    _G.MinimizerDB.enableFocusFace = false
    return results
end

function M.steadyState()
    local results = {}
    for _, n in ipairs(levels({10, 50, 100}, {50})) do
        H.resetState(); H.activateThreat(); H.makeUnits(n, { inCombat = true, threatSituation = 1, casters = 0 })
        results[#results + 1] = bench("steady_state." .. n, "ApplyToAll with unchanged state", function(batch)
            for _ = 1, batch do A.Dispatcher.ApplyToAll(false) end
        end, { subsystem = "Integrated", units = n, workload = "steady-state/no intentional changes" }, { cost = "heavy" })
    end
    return results
end

function M.recycling()
    local results = {}
    for _, n in ipairs(levels({1, 10, 100}, {1, 10})) do
        H.resetState()
        local cycles = n
        results[#results + 1] = bench("recycle." .. n, "add/update/remove/reuse lifecycle", function(batch)
            for cycle = 1, batch do
                local unit = "nameplate" .. (((cycle - 1) % cycles) + 1)
                if not Mocks.units[unit] then
                    H.makeUnits(1)
                    local created = "nameplate1"
                    if unit ~= created then
                        Mocks.units[unit] = Mocks.units[created]; Mocks.nameplates[unit] = Mocks.nameplates[created]
                        Mocks.units[created] = nil; Mocks.nameplates[created] = nil
                    end
                end
                local plate = Mocks.nameplates[unit]
                if A.Lifecycle then A.Lifecycle.IncrementGeneration(unit) end
                if A.Dispatcher then A.Dispatcher.TrackUnit(unit); A.Dispatcher.ApplyToUnit(unit, true) end
                if A.Lifecycle then A.Lifecycle.ClearNeverSimplify(unit) end
                if A.Dispatcher then A.Dispatcher.ForgetUnit(unit) end
                Mocks.units[unit] = { name = "Reused " .. unit, health = 100, healthMax = 100, faction = "Horde", isPlayer = false, classification = "normal", threatSituation = 1, guid = "reused-" .. cycle }
                Mocks.nameplates[unit] = plate; plate.namePlateUnitToken = unit
                if A.Lifecycle then A.Lifecycle.IncrementGeneration(unit) end
                if A.Dispatcher then A.Dispatcher.TrackUnit(unit); A.Dispatcher.ApplyToUnit(unit, true) end
            end
        end, { subsystem = "Lifecycle", cycles = cycles, workload = "repeated lifecycle; compare 1/10/100 cycles" }, { cost = "heavy", allocation = true, retention = true })
    end
    return results
end

function M.integratedWorkloads()
    local results = {}
    local workloads = {
        { name = "workload.normal", units = 10, casters = 1, threat = 1, recycle = false },
        { name = "workload.heavy", units = 50, casters = 10, threat = 2, recycle = true },
    }
    if H.getProfile().name == "fast" then workloads = { workloads[1], workloads[2] } end
    for _, w in ipairs(workloads) do
        H.resetState(); H.activateThreat(); H.makeUnits(w.units, { casters = w.casters, threatSituation = w.threat, inCombat = true })
        results[#results + 1] = bench(w.name, "representative event/update workload", function(batch)
            for i = 1, batch do
                local unit = "nameplate" .. (((i - 1) % w.units) + 1)
                if i % 4 == 0 then Mocks.FireEvent("UNIT_THREAT_SITUATION_UPDATE", unit)
                elseif i % 4 == 1 and w.casters > 0 then Mocks.FireEvent("UNIT_SPELLCAST_START", unit)
                elseif i % 4 == 2 then Mocks.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", unit)
                else A.Dispatcher.ApplyToUnit(unit, false) end
                if w.recycle and i % 17 == 0 then
                    A.Lifecycle.ClearNeverSimplify(unit); A.Dispatcher.ForgetUnit(unit); A.Lifecycle.IncrementGeneration(unit); A.Dispatcher.TrackUnit(unit)
                end
            end
        end, { subsystem = "Integrated", units = w.units, casters = w.casters, threat = w.threat, recycling = w.recycle }, { cost = "heavy", allocation = true })
    end
    return results
end

function M.all()
    local all = {}
    local groups = {
        { "core", M.coreScaling }, { "decision", M.decisionClassification }, { "threat", M.threatScaling },
        { "events", M.dispatcherEvents }, { "cast", M.castScaling }, { "absorb", M.absorbScaling },
        { "overlays", M.targetFocus }, { "halo_wheel", M.haloAndWheel }, { "pips", M.pips },
        { "steady", M.steadyState }, { "recycling", M.recycling }, { "integrated", M.integratedWorkloads },
    }
    local groupTimings = {}
    for _, group in ipairs(groups) do
        local start = os.clock()
        local results = group[2]()
        groupTimings[group[1]] = os.clock() - start
        for _, result in ipairs(results) do result.group = group[1]; all[#all + 1] = result end
    end
    return all, groupTimings
end

return M
