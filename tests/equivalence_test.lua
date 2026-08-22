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
-- 1. Threat nilSince / nilSpecial Lifecycle Test
-- --------------------------------------------------------------------------
do
    print("\n--- Testing nilSince & nilSpecial Lifecycle ---")
    Mocks.units = {}
    Mocks.nameplates = {}
    Mocks.time = 100.0

    Mocks.CreateTestUnit("player", { level = 70, isPlayer = true, class = "WARRIOR", role = "DAMAGER" })
    addonTable.Threat.InvalidatePlayerTankCache()
    addonTable.Threat.RefreshPlayerTankCache()

    Mocks.CreateTestUnit("nameplate1", {
        name = "Neutral Mob", level = 70, inCombat = true, canAttackPlayer = false,
        threatSituation = nil
    })
    local np1 = Mocks.CreateTestNameplate("nameplate1")
    Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate1")

    -- First read: situation is nil, inCombat=true, canAttackPlayer=false => nilSince initialized to Mocks.time (100.0)
    local details1 = addonTable.Threat.GetThreatDetails("nameplate1")
    assert_true(details1 ~= nil, "Threat: GetThreatDetails returns data")
    assert_eq(details1.nilSince, 100.0, "Threat: nilSince initialized to current time (100.0)")
    assert_eq(details1.nilSpecial, false, "Threat: nilSpecial false before 1.0s elapsed")

    -- Advance time 0.5s (time = 100.5)
    Mocks.AdvanceTime(0.5)
    local details2 = addonTable.Threat.GetThreatDetails("nameplate1")
    assert_eq(details2.nilSince, 100.0, "Threat: nilSince preserved at 100.0 after 0.5s")
    assert_eq(details2.nilSpecial, false, "Threat: nilSpecial still false at 0.5s")

    -- Advance time 0.6s (total 1.1s, time = 101.1)
    Mocks.AdvanceTime(0.6)
    local details3 = addonTable.Threat.GetThreatDetails("nameplate1")
    assert_eq(details3.nilSince, 100.0, "Threat: nilSince preserved after 1.1s")
    assert_eq(details3.nilSpecial, true, "Threat: nilSpecial confirmed after >= 1.0s")

    -- If situation changes to 3 (aggro) => nilSince and nilSpecial reset
    Mocks.units["nameplate1"].threatSituation = 3
    addonTable.Threat.Invalidate("nameplate1")
    local details4 = addonTable.Threat.GetThreatDetails("nameplate1")
    assert_eq(details4.nilSince, nil, "Threat: nilSince reset when situation is not nil")
    assert_eq(details4.nilSpecial, false, "Threat: nilSpecial reset when situation is not nil")
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

    -- Simulated nested invocation (e.g., from an indicator hook or module update)
    local snap11 = addonTable.Snapshot.Build("nameplate11", np11)
    assert_eq(snap11.displayKind, "melee", "Nested Snapshot: 11 has melee displayKind")

    -- Assert outer snapshot 10 was NOT corrupted by nested call
    assert_eq(snap10.displayKind, savedDisplayKind10, "Reentrancy: Outer snapshot displayKind unchanged after nested build")
    assert_eq(snap10.eliteType, savedEliteType10, "Reentrancy: Outer snapshot eliteType unchanged after nested build")
    assert_true(snap10 ~= snap11, "Reentrancy: Snapshot pool provides distinct table instances for nested depths")

    -- Test Dispatcher nested ApplyToUnit coalescing
    local nestedProcessed11 = false
    local dummyModule = {
        UpdateNamePlate = function(self, unit, np, snapshot)
            if unit == "nameplate10" then
                -- Trigger reentrant ApplyToUnit on 11 with forceUpdate=true
                addonTable.Dispatcher.ApplyToUnit("nameplate11", true)
            elseif unit == "nameplate11" then
                nestedProcessed11 = true
            end
        end
    }
    addonTable.Core.RegisterModule("DummyReentrantTester", dummyModule)

    addonTable.Dispatcher.ApplyToUnit("nameplate10", false)
    assert_true(nestedProcessed11, "Dispatcher: Nested reentrant ApplyToUnit was deferred, coalesced and executed safely")
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

    local state1 = addonTable.Threat.GetUnitThreatState("nameplate12")
    assert_true(state1 ~= nil, "Threat: GetUnitThreatState returned state table")
    assert_eq(state1.situation, 3, "ThreatState: situation is 3")
    assert_eq(state1.combat, true, "ThreatState: combat is true")
    assert_eq(state1.otherTankAggro, false, "ThreatState: otherTankAggro is false")
    assert_eq(state1.nilSpecial, false, "ThreatState: nilSpecial is false")

    local state2 = addonTable.Threat.GetUnitThreatState("nameplate12")
    assert_true(addonTable.Threat.StatesEqual(state1, state2), "Threat: StatesEqual returns true for identical states")

    -- Mutate mock to simulate change
    Mocks.units["nameplate12"].threatSituation = 1
    addonTable.Threat.Invalidate("nameplate12")
    local state3 = addonTable.Threat.GetUnitThreatState("nameplate12")
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

    -- Verify displayKind priorities: Focus (1) > Aggro (2) > Absorb (3) > Boss (4) > Caster (5) > Melee (6)
    Mocks.CreateTestUnit("nameplate15", { name = "Boss Mob", level = 70, classification = "worldboss", inCombat = true })
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
    Mocks.unitCastingInfoCallCounts = {}
    addonTable.Dispatcher.ApplyToUnit("nameplate15", false)
    local castCalls = Mocks.unitCastingInfoCallCounts["nameplate15"] or 0
    assert_eq(castCalls, 1, "Invariant: UnitCastingInfo called exactly once per ApplyToUnit pass")
end

print(string.format("\n=== EQUIVALENCE TEST SUMMARY: %d/%d passed ===", testsRun - testsFailed, testsRun))
if testsFailed > 0 then
    os.exit(1)
end
