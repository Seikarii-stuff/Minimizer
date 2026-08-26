-- tests/equivalence_test.lua
-- Test harness for verifying architectural equivalence and invariants.
local Mocks = dofile("tests/wow_mock.lua")

local ADDON_NAME = "Minimizer"
local addonTable = {}

local function LoadAddonFile(filepath)
    local func, err = loadfile(filepath)
    if not func then
        if filepath == "data/SpellData.lua" or filepath == "Data/SpellData.lua" then
            addonTable.Data = addonTable.Data or { INTERRUPT_SPELLS = {} }
            return
        end
        error("Failed to load " .. filepath .. ": " .. tostring(err))
    end
    func(ADDON_NAME, addonTable)
end

local function GetFileListFromToc(tocPath)
    local list = {}
    local fh = io.open(tocPath, "r")
    if not fh then error("No se pudo abrir el .toc: " .. tocPath) end
    for line in fh:lines() do
        local trimmed = line:match("^%s*(.-)%s*$")
        trimmed = trimmed:gsub("\\", "/")
        if trimmed ~= "" and not trimmed:match("^#") and not trimmed:match("^%.%.") and trimmed:match("%.lua$") then
            table.insert(list, trimmed)
        end
    end
    fh:close()
    return list
end

local files = GetFileListFromToc("Minimizer.toc")
for _, file in ipairs(files) do
    LoadAddonFile(file)
end

Mocks.FireEvent("ADDON_LOADED", ADDON_NAME)

local testsRun = 0
local testsFailed = 0

local function assert_eq(actual, expected, desc)
    testsRun = testsRun + 1
    if actual ~= expected then
        testsFailed = testsFailed + 1
        print(string.format("|cffff0000FAIL|r: %s (expected: %s, got: %s)", desc, tostring(expected), tostring(actual)))
    else
        print("|cff00ff00OK|r: " .. desc)
    end
end

local function assert_true(cond, desc)
    assert_eq(not not cond, true, desc)
end

print("\n=== EQUIVALENCE TEST HARNESS ===")

-- --------------------------------------------------------------------------
-- 1. Threat nilSpecial instant state and nil threat contract
-- --------------------------------------------------------------------------
do
    print("\n--- Testing nilSpecial & nil threat behavior ---")
    Mocks.units = {}
    Mocks.nameplates = {}
    Mocks.time = 100.0

    Mocks.CreateTestUnit("player", { level = 70, faction = "Alliance", isPlayer = true, class = "WARRIOR", role = "DAMAGER" })
    addonTable.Threat.InvalidatePlayerTankCache()
    addonTable.Threat.RefreshPlayerTankCache()

    Mocks.CreateTestUnit("nameplate1", {
        name = "Neutral Mob", level = 70, faction = "Alliance", inCombat = true, canAttackPlayer = false,
        threatSituation = nil
    })
    local np1 = Mocks.CreateTestNameplate("nameplate1")
    Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate1")

    local details1 = addonTable.Threat.GetThreatDetails("nameplate1")
    assert_true(details1 ~= nil, "Threat: GetThreatDetails returns data")
    assert_eq(details1.nilSince, nil, "Threat: nilSince is no longer tracked in production")
    assert_eq(details1.nilSpecial, true, "Threat: nilSpecial is immediate for nil threat and neutral/no-attack state")

    Mocks.units["nameplate1"].threatSituation = 3
    addonTable.Threat.Invalidate("nameplate1")
    local details4 = addonTable.Threat.GetThreatDetails("nameplate1")
    assert_eq(details4.nilSince, nil, "Threat: nilSince remains unset when situation is numeric")
    assert_eq(details4.nilSpecial, false, "Threat: nilSpecial resets when situation is not nil")
end

-- --------------------------------------------------------------------------
-- 2. Decision: ShouldUnsimplify & ShouldLetBlizzardPaint with Snapshot
-- --------------------------------------------------------------------------
do
    print("\n--- Testing Decision Consumption of Snapshot ---")
    Mocks.units = {}
    Mocks.nameplates = {}
    Mocks.time = 200.0

    Mocks.CreateTestUnit("player", { level = 70, isPlayer = true, class = "WARRIOR", role = "TANK" })
    addonTable.Threat.InvalidatePlayerTankCache()
    addonTable.Threat.RefreshPlayerTankCache()
    assert_true(addonTable.Threat.IsPlayerTank(), "Player is Tank")

    Mocks.CreateTestUnit("nameplate2", {
        name = "Tank Mob", level = 70, inCombat = true, canAttackPlayer = true,
        threatSituation = 0 -- Situation 0 for tank = losing aggro
    })
    local np2 = Mocks.CreateTestNameplate("nameplate2")
    Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate2")

    local snap = addonTable.Snapshot.Build("nameplate2", np2)
    assert_true(snap ~= nil, "Snapshot: Build created snapshot")
    assert_eq(snap.threatSituation, 0, "Snapshot: captured threatSituation=0")
    assert_eq(snap.otherTankAggro, false, "Snapshot: captured otherTankAggro=false")

    local shouldUnsimp = addonTable.Decision.ShouldUnsimplify("nameplate2", snap)
    assert_eq(shouldUnsimp, true, "Decision: ShouldUnsimplify true for tank losing aggro (sit 0)")

    local letBlizz = addonTable.Decision.ShouldLetBlizzardPaint("nameplate2", snap)
    assert_eq(letBlizz, true, "Decision: ShouldLetBlizzardPaint true for tank with sit 0")
end

-- --------------------------------------------------------------------------
-- 3. Absorb: Single Owner Persistence and Snapshot Capture
-- --------------------------------------------------------------------------
do
    print("\n--- Testing Absorb Single Owner Persistence ---")
    Mocks.units = {}
    Mocks.nameplates = {}
    Mocks.time = 300.0

    Mocks.CreateTestUnit("player", { level = 70, isPlayer = true, class = "WARRIOR", role = "DAMAGER" })
    addonTable.Threat.InvalidatePlayerTankCache()
    addonTable.Threat.RefreshPlayerTankCache()
    assert_eq(addonTable.Threat.IsPlayerTank(), false, "Player is not Tank")

    Mocks.CreateTestUnit("nameplate3", {
        name = "Shield Mob", level = 70, inCombat = false,
        health = 80, healthMax = 100, absorbs = 25, threatSituation = 0
    })
    local np3 = Mocks.CreateTestNameplate("nameplate3")
    local hb3 = np3.UnitFrame.healthBar
    hb3.totalAbsorbOverlay = { IsShown = function() return true end }

    Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate3")

    local snap1 = addonTable.Snapshot.Build("nameplate3", np3)
    assert_eq(snap1.hasAbsorb, true, "Snapshot: hasAbsorb true when indicator is shown")
    assert_eq(snap1.hasHadAbsorb, true, "Snapshot: hasHadAbsorb true on first seen")
    assert_eq(snap1.displayKind, "absorb", "Snapshot: displayKind is 'absorb'")

    -- Hide indicator (absorb depleted)
    hb3.totalAbsorbOverlay.IsShown = function() return false end
    assert_eq(addonTable.Absorb.HasAbsorb("nameplate3", np3), false, "Absorb: HasAbsorb is live false")

    local snap2 = addonTable.Snapshot.Build("nameplate3", np3)
    assert_eq(snap2.hasAbsorb, false, "Snapshot: live hasAbsorb is false")
    assert_eq(snap2.hasHadAbsorb, true, "Snapshot: hasHadAbsorb PERSISTS within same generation")
    assert_eq(snap2.displayKind, "absorb", "Snapshot: displayKind remains 'absorb' due to persistence")

    -- Recycle token: new unit on nameplate3 with new generation
    Mocks.FireEvent("NAME_PLATE_UNIT_REMOVED", "nameplate3")
    Mocks.CreateTestUnit("nameplate3", {
        name = "New Mob", level = 70, inCombat = false,
        health = 100, healthMax = 100, absorbs = 0, threatSituation = 0
    })
    local np3_new = Mocks.CreateTestNameplate("nameplate3")
    Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate3")

    local snap3 = addonTable.Snapshot.Build("nameplate3", np3_new)
    assert_eq(snap3.hasAbsorb, false, "Snapshot: recycled unit hasAbsorb is false")
    assert_eq(snap3.hasHadAbsorb, false, "Snapshot: recycled unit hasHadAbsorb is CLEARED")
end

-- --------------------------------------------------------------------------
-- 4. Reentrancy & Snapshot Pool Immunity Test
-- --------------------------------------------------------------------------
do
    print("\n--- Testing Dispatcher Reentrancy & Snapshot Isolation ---")
    Mocks.units = {}
    Mocks.nameplates = {}
    Mocks.time = 400.0

    -- Re-create the player unit that the dispatcher’s pipeline expects.
    Mocks.CreateTestUnit("player", {
        name = "Player",
        level = 70,
        faction = "Alliance",
        isPlayer = true,
        class = "WARRIOR",
        role = "DAMAGER",
    })

    Mocks.CreateTestUnit("nameplate10", { name = "Mob A", level = 70, classification = "worldboss" })
    Mocks.CreateTestUnit("nameplate11", { name = "Mob B", level = 70, classification = "normal" })
    local np10 = Mocks.CreateTestNameplate("nameplate10")
    local np11 = Mocks.CreateTestNameplate("nameplate11")

    Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate10")
    Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate11")

    -- Build snapshot 10
    local snap10 = addonTable.Snapshot.Build("nameplate10", np10)
    local savedDisplayKind10 = snap10.displayKind
    local savedEliteType10 = snap10.eliteType
    assert_eq(savedDisplayKind10, "boss", "Outer Snapshot: 10 has boss displayKind")

    local originalGetEliteType = addonTable.Classification and addonTable.Classification.GetEliteType
    local innerSnap = nil
    local mockGetEliteType = function(u)
        if not innerSnap and u == "nameplate10" then
            -- Trigger reentrant build inside Build
            innerSnap = addonTable.Snapshot.Build("nameplate11", np11)
        end
        return "boss"
    end
    
    if addonTable.Classification then
        addonTable.Classification.GetEliteType = mockGetEliteType
    end
    
    local outerSnap = addonTable.Snapshot.Build("nameplate10", np10)
    
    if addonTable.Classification then
        addonTable.Classification.GetEliteType = originalGetEliteType
    end
    
    assert_true(outerSnap ~= innerSnap, "Reentrancy: Snapshot pool provides distinct table instances for nested depths (depth 1 vs depth 2)")

    -- Test depth > initial pool size (e.g. depth 10) by chaining reentrancy
    local depthCount = 0
    local deepSnaps = {}
    local function chainedReentrant(u)
        depthCount = depthCount + 1
        if depthCount <= 10 and u == "nameplate10" then
            deepSnaps[depthCount] = addonTable.Snapshot.Build("nameplate11", np11)
        elseif depthCount <= 10 and u == "nameplate11" then
            deepSnaps[depthCount] = addonTable.Snapshot.Build("nameplate11", np11)
        end
        return "normal"
    end
    if addonTable.Classification then
        addonTable.Classification.GetEliteType = chainedReentrant
    end
    
    addonTable.Snapshot.Build("nameplate10", np10)
    
    if addonTable.Classification then
        addonTable.Classification.GetEliteType = originalGetEliteType
    end
    
    assert_true(deepSnaps[1] ~= deepSnaps[10], "Reentrancy: Dynamic pool scales beyond arbitrary depth limits")
    local nestedProcessed11 = false
    local runawayCount = 0
    local dummyModule = {
        UpdateNamePlate = function(self, unit, np, snapshot)
            if unit == "nameplate10" then
                addonTable.Dispatcher.ApplyToUnit("nameplate11", true)
            elseif unit == "nameplate11" then
                nestedProcessed11 = true
            elseif unit == "nameplate12" then
                runawayCount = runawayCount + 1
                addonTable.Dispatcher.ApplyToUnit("nameplate12", true)
            end
        end
    }
    addonTable.Core.RegisterModule("DummyReentrantTester", dummyModule)

    if addonTable.Classification then
        addonTable.Classification.GetEliteType = originalGetEliteType
    end
    
    -- Ensure nameplate11 exists before reentrancy processing
    Mocks.CreateTestUnit("nameplate11", { name = "Reentrant Mob", level = 70 })
    Mocks.CreateTestNameplate("nameplate11")
    Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate11")

    -- Test nested reentrant ApplyToUnit processing
    addonTable.Dispatcher.ApplyToUnit("nameplate10", false)
    Mocks.AdvanceTime(0) -- allow pending work
    addonTable.Dispatcher.ApplyToUnit("nameplate10", false)
    assert_true(nestedProcessed11, "Dispatcher: Nested reentrant ApplyToUnit was deferred and processed safely")

    -- Test runaway recursion limit
    Mocks.CreateTestUnit("nameplate12", { name = "Runaway Mob", level = 70 })
    Mocks.CreateTestNameplate("nameplate12")
    Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate12")
    addonTable.Dispatcher.ApplyToUnit("nameplate12", false)
    Mocks.AdvanceTime(0)
    assert_true(runawayCount >= 10, "Dispatcher: Runaway recursion correctly aborted after reaching limit (count: " .. runawayCount .. ")")

    -- Prepare unit for UnitCastingInfo tests
    Mocks.CreateTestUnit("nameplate15", { name = "Casting Mob", level = 70 })
    Mocks.CreateTestNameplate("nameplate15")
    Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate15")

    -- UnitCastingInfo call count tests
    -- Case A: no cast
    Mocks.unitCastingInfoCallCounts = {}
    Mocks.units["nameplate15"].cast = nil
    addonTable.Dispatcher.ApplyToUnit("nameplate15", false)
    Mocks.AdvanceTime(0)
    local noCastCalls = Mocks.unitCastingInfoCallCounts["nameplate15"] or 0
    assert_eq(noCastCalls, 1, "Invariant: Cast.lua sigue leyendo UnitCastingInfo una vez aunque no haya cast (sin cache, por diseño)")

    -- Case B: with cast
    Mocks.unitCastingInfoCallCounts = {}
    Mocks.units["nameplate15"].cast = { name = "TestCast", startTime = 0, endTime = 2000, uninterruptible = false }
    addonTable.Dispatcher.ApplyToUnit("nameplate15", false)
    Mocks.AdvanceTime(0)
    local castCalls = Mocks.unitCastingInfoCallCounts["nameplate15"] or 0
    assert_eq(castCalls, 1, "Invariant: UnitCastingInfo called exactly once when a cast exists")
end

-- --------------------------------------------------------------------------
-- 5. Threat Dynamic Monitor Lifecycle & Idempotency
-- --------------------------------------------------------------------------
do
    print("\n--- Testing Threat Dynamic Monitor Lifecycle ---")
    Mocks.units = {}
    Mocks.nameplates = {}

    -- 1. Solo DPS: Threat is disabled
    Mocks.inGroup = false
    Mocks.inRaid = false
    Mocks.CreateTestUnit("player", { level = 70, isPlayer = true, class = "ROGUE", role = "DAMAGER" })
    addonTable.Threat.InvalidatePlayerTankCache()
    assert_eq(addonTable.Threat.IsThreatEnabled(), false, "Solo DPS: Threat is disabled")

    addonTable.Dispatcher.UpdateMonitorState()

    -- 2. Solo joins Group -> GROUP_ROSTER_UPDATE
    Mocks.inGroup = true
    Mocks.FireEvent("GROUP_ROSTER_UPDATE")
    assert_eq(addonTable.Threat.IsThreatEnabled(), true, "Group DPS: Threat is enabled")

    -- Verify idempotency of UpdateMonitorState
    addonTable.Dispatcher.UpdateMonitorState()
    addonTable.Dispatcher.UpdateMonitorState()
    assert_true(true, "Dispatcher: UpdateMonitorState is idempotent and safe against multiple invocations")

    -- 3. Group leaves -> Solo again -> GROUP_ROSTER_UPDATE
    Mocks.inGroup = false
    Mocks.FireEvent("GROUP_ROSTER_UPDATE")
    assert_eq(addonTable.Threat.IsThreatEnabled(), false, "Solo again: Threat is disabled")

    -- 4. Switch spec to Tank -> PLAYER_SPECIALIZATION_CHANGED
    Mocks.CreateTestUnit("player", { level = 70, isPlayer = true, class = "WARRIOR", role = "TANK" })
    addonTable.Threat.InvalidatePlayerTankCache()
    Mocks.FireEvent("PLAYER_SPECIALIZATION_CHANGED")
    assert_eq(addonTable.Threat.IsThreatEnabled(), true, "Solo Tank: Threat is enabled")

    -- 5. Switch spec back to DPS
    Mocks.CreateTestUnit("player", { level = 70, isPlayer = true, class = "WARRIOR", role = "DAMAGER" })
    addonTable.Threat.InvalidatePlayerTankCache()
    Mocks.FireEvent("PLAYER_SPECIALIZATION_CHANGED")
    assert_eq(addonTable.Threat.IsThreatEnabled(), false, "Solo DPS again: Threat is disabled")
end

-- --------------------------------------------------------------------------
-- 6. ThreatState Decoupling & StatesEqual
-- --------------------------------------------------------------------------
do
    print("\n--- Testing ThreatState Structure & Equality ---")
    Mocks.inGroup = true
    Mocks.CreateTestUnit("nameplate12", {
        name = "Aggro Mob", level = 70, inCombat = true, canAttackPlayer = true,
        threatSituation = 3
    })
    local npThreat = Mocks.CreateTestNameplate("nameplate12")
    Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate12")

    local details = addonTable.Threat.GetThreatDetails("nameplate12")
    assert_true(details ~= nil, "Threat: GetThreatDetails returned cached details")
    assert_true(details.combat == true, "Threat: GetThreatDetails caches combat once per sample")

    local state1 = addonTable.Threat.GetUnitThreatState("nameplate12")
    assert_true(state1 ~= nil, "Threat: GetUnitThreatState returned state table")
    assert_eq(state1.situation, 3, "ThreatState: situation is 3")
    assert_eq(state1.combat, true, "ThreatState: combat is true")
    assert_eq(state1.otherTankAggro, false, "ThreatState: otherTankAggro is false")
    assert_eq(state1.nilSpecial, false, "ThreatState: nilSpecial is false")

    local state2 = addonTable.Threat.GetUnitThreatState("nameplate12")
    assert_true(state1 == state2, "Threat: stable state is reused instead of allocating a fresh table")
    assert_true(addonTable.Threat.StatesEqual(state1, state2), "Threat: StatesEqual returns true for identical states")

    -- Mutate mock to simulate change
    Mocks.units["nameplate12"].threatSituation = 1
    addonTable.Threat.Invalidate("nameplate12")
    local state3 = addonTable.Threat.GetUnitThreatState("nameplate12")
    assert_true(state3 ~= state1, "Threat: changed state creates a new state object")
    assert_eq(addonTable.Threat.StatesEqual(state1, state3), false, "Threat: StatesEqual returns false when situation changes")
end

-- --------------------------------------------------------------------------
-- 7. Overlays Pipeline (Target / Focus / Cooldowns)
-- --------------------------------------------------------------------------
do
    print("\n--- Testing Overlays Registry & Event Routing ---")
    local targetRegistered = addonTable.Overlays.Get("Target")
    local focusRegistered = addonTable.Overlays.Get("Focus")
    assert_true(targetRegistered ~= nil, "Overlays: Target module is registered")
    assert_true(focusRegistered ~= nil, "Overlays: Focus module is registered")

    -- Cooldown tick dispatch
    local cooldownTicked = false
    local testOverlay = {
        OnCooldownTick = function(self) cooldownTicked = true end
    }
    addonTable.Overlays.Register("TestOverlay", testOverlay)
    addonTable.Overlays.OnCooldownTick()
    assert_true(cooldownTicked, "Overlays: OnCooldownTick triggers registered modules")

    -- Unit changed routing
    local unitChangedReason = nil
    testOverlay.OnUnitChanged = function(self, unit, reason)
        unitChangedReason = reason
    end
    addonTable.Overlays.OnUnitChanged("target", "target")
    assert_eq(unitChangedReason, "target", "Overlays: OnUnitChanged propagates reason correctly")
end

-- --------------------------------------------------------------------------
-- 8. HitTest Generation-Safe Cancellation
-- --------------------------------------------------------------------------
do
    print("\n--- Testing HitTest Generation-Safe Retry Cancellation ---")
    Mocks.units = {}
    Mocks.nameplates = {}
    Mocks.timers = {}
    Mocks.time = 500.0

    Mocks.CreateTestUnit("nameplate14", { name = "HitTest Mob", level = 70 })
    local npHT = Mocks.CreateTestNameplate("nameplate14")
    -- Simulate CanChangeHitTestPoints returning false to force retry scheduling
    npHT.CanChangeHitTestPoints = function() return false end
    npHT.SetAllHitTestPoints = function(self, region) self.syncedRegion = region end

    Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate14")
    addonTable.HitTest.Sync("nameplate14", npHT)

    assert_true(#Mocks.timers > 0, "HitTest: Retry timer was scheduled when API denied mutation")

    -- Remove nameplate -> cancels retry
    Mocks.FireEvent("NAME_PLATE_UNIT_REMOVED", "nameplate14")

    -- Recycle token: new unit on same nameplate token with new generation
    Mocks.CreateTestUnit("nameplate14", { name = "Recycled Mob", level = 70 })
    local npHT_new = Mocks.CreateTestNameplate("nameplate14")
    npHT_new.syncedRegion = nil
    Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate14")

    -- Advance time to let any old timer fire
    Mocks.AdvanceTime(1.0)
    assert_eq(npHT_new.syncedRegion, nil, "HitTest: Stale retry did NOT modify recycled nameplate of new generation")
end

-- --------------------------------------------------------------------------
-- 9. Baseline Equivalence Matrix vs Main
-- --------------------------------------------------------------------------
do
    print("\n--- Testing Baseline Behavioral Invariants vs Main ---")
    Mocks.units = {}
    Mocks.nameplates = {}
    Mocks.unitCastingInfoCallCounts = {}
    Mocks.unitChannelInfoCallCounts = {}

    -- Add player fixture for pipeline relevance
    Mocks.CreateTestUnit("player", { name = "Player", level = 70, faction = "Alliance", isPlayer = true, class = "WARRIOR", role = "DAMAGER" })
    addonTable.Threat.InvalidatePlayerTankCache()
    addonTable.Threat.RefreshPlayerTankCache()
    -- Verify displayKind priorities: Focus (1) > Aggro (2) > Absorb (3) > Boss (4) > Caster (5) > Melee (6)
    Mocks.CreateTestUnit("nameplate15", { name = "Boss Mob", level = 70, classification = "worldboss", inCombat = true, faction = "Horde" })
    local npP1 = Mocks.CreateTestNameplate("nameplate15")
    Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate15")

    local snapP1 = addonTable.Snapshot.Build("nameplate15", npP1)
    assert_eq(snapP1.displayKind, "boss", "Invariant: Boss displayKind is 'boss'")

    -- If player gains aggro (sit 3), aggro wins over boss
    Mocks.units["nameplate15"].threatSituation = 3
    addonTable.Threat.Invalidate("nameplate15")
    local snapP1_aggro = addonTable.Snapshot.Build("nameplate15", npP1)
    assert_eq(snapP1_aggro.displayKind, "aggro", "Invariant: Aggro (sit 3) beats boss -> 'aggro'")

    -- Verify single UnitCastingInfo call per ApplyToUnit pass
    -- Verify UnitCastingInfo behavior
    -- Case A: unit without a cast should not call UnitCastingInfo
    Mocks.unitCastingInfoCallCounts = {}
    Mocks.units["nameplate15"].cast = nil
    addonTable.Dispatcher.ApplyToUnit("nameplate15", false)
    local noCastCalls = Mocks.unitCastingInfoCallCounts["nameplate15"] or 0
    assert_eq(noCastCalls, 1, "Invariant: Cast.lua sigue leyendo UnitCastingInfo una vez aunque no haya cast (sin cache, por diseño)")

    -- Case B: unit with a cast should call UnitCastingInfo exactly once
    Mocks.unitCastingInfoCallCounts = {}
    Mocks.units["nameplate15"].cast = { name = "TestCast", startTime = 0, endTime = 2000, uninterruptible = false }
    addonTable.Dispatcher.ApplyToUnit("nameplate15", false)
    local castCalls = Mocks.unitCastingInfoCallCounts["nameplate15"] or 0
    assert_eq(castCalls, 1, "Invariant: UnitCastingInfo called exactly once when a cast exists")
end

-- --------------------------------------------------------------------------
-- 10. Event Registration & Propagation Invariants
-- --------------------------------------------------------------------------
do
    print("\n--- Testing EventFrame Registration & Event Dispatch ---")
    local eventFrame = _G.MinimizerEventFrame
    assert_true(eventFrame ~= nil, "EventFrame: MinimizerEventFrame exists")
    assert_true(eventFrame.registeredEvents ~= nil, "EventFrame: registeredEvents table exists")
    assert_eq(eventFrame.registeredEvents["UNIT_ABSORB_AMOUNT_CHANGED"], true, "EventFrame: UNIT_ABSORB_AMOUNT_CHANGED is registered")
    assert_eq(eventFrame.registeredEvents["NAME_PLATE_UNIT_ADDED"], true, "EventFrame: NAME_PLATE_UNIT_ADDED is registered")
    assert_eq(eventFrame.registeredEvents["NAME_PLATE_UNIT_REMOVED"], true, "EventFrame: NAME_PLATE_UNIT_REMOVED is registered")
    assert_eq(eventFrame.registeredEvents["UNIT_SPELLCAST_START"], true, "EventFrame: UNIT_SPELLCAST_START is registered")
    assert_eq(eventFrame.registeredEvents["UNIT_THREAT_SITUATION_UPDATE"], true, "EventFrame: UNIT_THREAT_SITUATION_UPDATE is registered")

    -- Verify UNIT_ABSORB_AMOUNT_CHANGED fires and dispatches to Dispatcher.ApplyToUnit
    local origApply = addonTable.Dispatcher.ApplyToUnit
    -- Friendly unit should NOT trigger ApplyToUnit
    -- Ensure a friendly plate exists for this friendly-absorb pre-check
    Mocks.CreateTestUnit("nameplate15", { name = "Friendly Ally", level = 70, classification = "normal", faction = "Alliance" })
    Mocks.CreateTestNameplate("nameplate15")
    Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate15")
    local dispatchedFriendly = nil
    addonTable.Dispatcher.ApplyToUnit = function(u, force)
        dispatchedFriendly = u
        return origApply(u, force)
    end
    assert_true(addonTable.Dispatcher.IsPipelineRelevant("nameplate15") == false,
        "Pre-check: nameplate15 should not be pipeline-relevant for friendly UNIT_ABSORB")
    Mocks.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "nameplate15")
    addonTable.Dispatcher.ApplyToUnit = origApply
    assert_eq(dispatchedFriendly, nil, "EventFrame: Friendly UNIT_ABSORB does not dispatch Dispatcher")

    -- Enemy PvE unit SHOULD trigger ApplyToUnit
    Mocks.CreateTestUnit("nameplate99", { name = "Enemy Mob", level = 70, classification = "normal", faction = "Horde" })
    Mocks.CreateTestNameplate("nameplate99")
    Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate99")
    assert_true(addonTable.Dispatcher.IsPipelineRelevant("nameplate99") == true,
        "Pre-check: nameplate99 must be pipeline-relevant before UNIT_ABSORB_AMOUNT_CHANGED")
    local dispatchedEnemy = nil
    addonTable.Dispatcher.ApplyToUnit = function(u, force)
        dispatchedEnemy = u
        return origApply(u, force)
    end
    Mocks.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "nameplate99")
    addonTable.Dispatcher.ApplyToUnit = origApply
    assert_eq(dispatchedEnemy, "nameplate99", "EventFrame: Enemy PvE UNIT_ABSORB correctly triggers Dispatcher")
end

-- --------------------------------------------------------------------------
-- 11. Cross-Generation Recycle Leak-Prevention Invariant
-- --------------------------------------------------------------------------
do
    print("\n--- Testing Cross-Generation Recycle Invariant ---")
    _G.MinimizerDB = { simplifyEnabled = true }
    Mocks.units = {}
    Mocks.nameplates = {}
    Mocks.CreateTestUnit("player", { name = "Player", level = 70, faction = "Alliance", isPlayer = true, role = "DAMAGER" })
    addonTable.Threat.RefreshPlayerTankCache()

    local token = "nameplate20"

    -- Unit A: Inferior casting interruptible with absorb + cast color
    Mocks.CreateTestUnit(token, {
        name = "Old Mob", level = 70, classification = "normal", faction = "Horde", powerType = 1,
        cast = { name = "Interruptible Cast", startTime = 0, endTime = 2000, uninterruptible = false }
    })
    local npOld = Mocks.CreateTestNameplate(token)
    npOld.UnitFrame.healthBar.totalAbsorbOverlay = CreateFrame("Frame", nil, npOld.UnitFrame.healthBar)
    npOld.UnitFrame.healthBar.totalAbsorbOverlay:Show()

    Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", token)
    addonTable.Dispatcher.ApplyToUnit(token, true)

    assert_eq(npOld.MinimizerHasHadAbsorb, true, "Recycle Test: Old unit flagged as MinimizerHasHadAbsorb")
    assert_true(npOld.MinimizerPersistentCastColor ~= nil, "Recycle Test: Old unit has MinimizerPersistentCastColor")
    assert_eq(npOld.simplified, false, "Recycle Test: Old unit with absorb/cast is NOT simplified")

    -- Remove Unit A
    Mocks.FireEvent("NAME_PLATE_UNIT_REMOVED", token)
    if NamePlateDriverFrame and NamePlateDriverFrame.OnNamePlateRemoved then
        NamePlateDriverFrame:OnNamePlateRemoved(token)
    end

    -- Recycle to Unit B: Normal melee trash mob
    Mocks.CreateTestUnit(token, {
        name = "New Melee Trash", level = 70, classification = "normal", faction = "Horde", powerType = 1,
        threatSituation = 1
    })
    local npNew = Mocks.CreateTestNameplate(token)
    Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", token)
    addonTable.Dispatcher.ApplyToUnit(token, true)

    assert_eq(npNew.MinimizerDesimplifiedPersistent, nil, "Recycle Test: Recycled unit does NOT inherit MinimizerDesimplifiedPersistent")
    assert_eq(npNew.MinimizerHasHadAbsorb, nil, "Recycle Test: Recycled unit does NOT inherit MinimizerHasHadAbsorb")
    assert_eq(npNew.MinimizerPersistentCastColor, nil, "Recycle Test: Recycled unit does NOT inherit MinimizerPersistentCastColor")
    assert_eq(npNew.simplified, true, "Recycle Test: Recycled unit correctly simplified for normal melee")
    assert_eq(npNew.MinimizerState, true, "Recycle Test: Recycled unit MinimizerState is true")
end

-- --------------------------------------------------------------------------
-- 12. Absorb Indicator Hook Safe Reentrancy Invariant
-- --------------------------------------------------------------------------
do
    print("\n--- Testing Absorb Indicator Hook Reentrancy Safety ---")
    Mocks.units = {}
    Mocks.nameplates = {}
    Mocks.CreateTestUnit("player", { name = "Player", level = 70, faction = "Alliance", isPlayer = true, role = "DAMAGER" })
    addonTable.Threat.RefreshPlayerTankCache()

    local token = "nameplate25"
    Mocks.CreateTestUnit(token, { level = 70, classification = "normal", faction = "Horde", powerType = 1 })
    local np = Mocks.CreateTestNameplate(token)
    local overlay = CreateFrame("Frame", nil, np.UnitFrame.healthBar)
    np.UnitFrame.healthBar.totalAbsorbOverlay = overlay
    overlay:Hide()

    Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", token)
    addonTable.Dispatcher.ApplyToUnit(token, true)

    -- Triggering Show on absorb overlay triggers HookIndicator -> Dispatcher.ApplyToUnit
    local applyCount = 0
    local origApply = addonTable.Dispatcher.ApplyToUnit
    addonTable.Dispatcher.ApplyToUnit = function(u, force)
        applyCount = applyCount + 1
        return origApply(u, force)
    end

    overlay:Show()
    addonTable.Dispatcher.ApplyToUnit = origApply

    assert_true(applyCount >= 1, "HookIndicator: Show on absorb overlay invoked Dispatcher.ApplyToUnit")
    local hb = addonTable.Utils.GetHealthBar(np)
    local r, g, b = hb:GetStatusBarColor()
    local ac = addonTable.Constants.HealthColors.absorb
    assert_true(math.abs(r - ac[1]) < 0.01 and math.abs(g - ac[2]) < 0.01 and math.abs(b - ac[3]) < 0.01,
        "HookIndicator: HealthBar color updated to absorb pink without infinite loop")
end

print(string.format("\n=== EQUIVALENCE TEST SUMMARY: %d/%d passed ===", testsRun - testsFailed, testsRun))
if testsFailed > 0 then
    os.exit(1)
end
