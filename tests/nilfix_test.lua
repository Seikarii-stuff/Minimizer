-- tests/nilfix_test.lua
-- Regression tests for the nil threatSituation simplification policy.
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
    local fh = assert(io.open(tocPath, "r"), "No se pudo abrir el .toc: " .. tocPath)
    for line in fh:lines() do
        local trimmed = line:match("^%s*(.-)%s*$"):gsub("\\", "/")
        if trimmed ~= "" and not trimmed:match("^#") and not trimmed:match("^%.%.") and trimmed:match("%.lua$") then
            table.insert(list, trimmed)
        end
    end
    fh:close()
    return list
end

for _, file in ipairs(GetFileListFromToc("Minimizer.toc")) do
    LoadAddonFile(file)
end
Mocks.FireEvent("ADDON_LOADED", ADDON_NAME)

local failures = 0
local function assert_eq(actual, expected, desc)
    if actual ~= expected then
        failures = failures + 1
        print(string.format("FAIL: %s (expected: %s, got: %s)", desc, tostring(expected), tostring(actual)))
    else
        print("OK: " .. desc)
    end
end

Mocks.units = {}
Mocks.nameplates = {}
Mocks.CreateTestUnit("player", {
    level = 70, isPlayer = true, class = "WARRIOR", role = "DAMAGER"
})
Mocks.CreateTestUnit("nameplate1", {
    name = "Threat Test Mob", level = 70, canAttackPlayer = true, inCombat = true
})
local np = Mocks.CreateTestNameplate("nameplate1")

local function decide(snapshot)
    return addonTable.Decision.ShouldSimplifyUnit("nameplate1", np, snapshot)
end

-- 1 & 2. nil threatSituation must never simplify, regardless of nilSpecial.
local ok, reason = decide({
    eliteType = "normal", threatSituation = nil, nilSpecial = false,
    nilSince = 100, inCombat = true, isPlayerTank = false, otherTankAggro = false,
    hasHadAbsorb = false, isCasting = false, isChanneling = false,
})
assert_eq(ok, false, "nil threatSituation + nilSpecial=false is not simplified")
assert_eq(reason, "no simp", "nil threatSituation + nilSpecial=false returns no simp")

ok, reason = decide({
    eliteType = "normal", threatSituation = nil, nilSpecial = true,
    nilSince = 100, inCombat = true, isPlayerTank = false, otherTankAggro = false,
    hasHadAbsorb = false, isCasting = false, isChanneling = false,
})
assert_eq(ok, false, "nil threatSituation + nilSpecial=true is not simplified")
assert_eq(reason, "no simp", "nil threatSituation + nilSpecial=true returns no simp")

-- 3. Existing numeric behavior remains unchanged for DPS: 0/1/2 simplify, 3 does not.
for _, situation in ipairs({ 0, 1, 2 }) do
    ok, reason = decide({
        eliteType = "normal", threatSituation = situation, nilSpecial = false,
        nilSince = nil, inCombat = true, isPlayerTank = false, otherTankAggro = false,
        hasHadAbsorb = false, isCasting = false, isChanneling = false,
    })
    assert_eq(ok, true, "DPS numeric situation " .. situation .. " still simplifies")
    assert_eq(reason, "simplify", "DPS numeric situation " .. situation .. " still returns simplify")
end

ok, reason = decide({
    eliteType = "normal", threatSituation = 3, nilSpecial = false,
    nilSince = nil, inCombat = true, isPlayerTank = false, otherTankAggro = false,
    hasHadAbsorb = false, isCasting = false, isChanneling = false,
})
assert_eq(ok, false, "DPS numeric situation 3 is still not simplified")
assert_eq(reason, "temporal", "DPS numeric situation 3 still returns temporal")

-- Tank numeric behavior: 0 unsimplifies; 1/2/3 simplify.
for _, situation in ipairs({ 0, 1, 2, 3 }) do
    local expected = situation ~= 0
    local expectedReason = expected and "simplify" or "temporal"
    ok, reason = decide({
        eliteType = "normal", threatSituation = situation, nilSpecial = false,
        nilSince = nil, inCombat = true, isPlayerTank = true, otherTankAggro = false,
        hasHadAbsorb = false, isCasting = false, isChanneling = false,
    })
    assert_eq(ok, expected, "Tank numeric situation " .. situation .. " preserves existing decision")
    assert_eq(reason, expectedReason, "Tank numeric situation " .. situation .. " preserves existing reason")
end

if failures > 0 then
    os.exit(1)
end
print("All nilfix tests passed.")
