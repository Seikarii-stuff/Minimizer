-- tests/equivalence_test.lua
-- Test harness for verifying architectural equivalence and invariants.
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
-- 4. Dispatcher: ApplyToUnit, ApplyToAll, Debounce & SafetyNet
-- --------------------------------------------------------------------------
do
    print("\n--- Testing Dispatcher Execution ---")
    Mocks.units = {}
    Mocks.nameplates = {}

    Mocks.CreateTestUnit("nameplate4", { name = "Mob 4", level = 70, inCombat = true })
    Mocks.CreateTestUnit("nameplate5", { name = "Mob 5", level = 70, inCombat = true })
    local np4 = Mocks.CreateTestNameplate("nameplate4")
    local np5 = Mocks.CreateTestNameplate("nameplate5")

    Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate4")
    Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate5")

    local activePlates = addonTable.Lifecycle.GetActiveNameplates()
    assert_true(activePlates["nameplate4"] ~= nil, "Lifecycle: nameplate4 registered")
    assert_true(activePlates["nameplate5"] ~= nil, "Lifecycle: nameplate5 registered")

    -- ApplyToAll executes without errors
    addonTable.Dispatcher.ApplyToAll(true)
    assert_true(np4.MinimizerState ~= nil, "Dispatcher: nameplate4 processed")
    assert_true(np5.MinimizerState ~= nil, "Dispatcher: nameplate5 processed")
end

print(string.format("\n=== EQUIVALENCE TEST SUMMARY: %d/%d passed ===", testsRun - testsFailed, testsRun))
if testsFailed > 0 then
    os.exit(1)
end
