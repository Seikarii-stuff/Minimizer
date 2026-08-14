-- tests/smoke_test.lua
local Mocks = dofile("tests/wow_mock.lua")

-- Simulate the addon table passed by the WoW client
local ADDON_NAME = "Minimizer"
local addonTable = {}

-- Helper to load addon files like the WoW client does
local function LoadAddonFile(filepath)
    local func, err = loadfile(filepath)
    if not func then
        if filepath == "data/SpellData.lua" then
            print("Warning: data/SpellData.lua not found. Mocking Minimizer.Data.")
            addonTable.Data = addonTable.Data or { INTERRUPT_SPELLS = {} }
            return
        end
        error("Failed to load " .. filepath .. ": " .. tostring(err))
    end
    -- The WoW client passes addonName and addonTable as varargs
    func(ADDON_NAME, addonTable)
end

print("--- Loading Minimizer Addon Files ---")
-- Load files in roughly the order they appear in the .toc or dependency order
local files = {
    "Bootstrap.lua",
    "Utils.lua",
    "Widgets.lua",
    "Config.lua",
    "Constants.lua",
    "data/SpellData.lua",
    "Cache.lua",
    "Threat.lua",
    "Absorb.lua",
    "Cast.lua",
    "ClassificationUtils.lua",
    "Decision.lua",
    "Interrupt.lua",
    "Core.lua",
    "Markers.lua",
    "HealthBarColor.lua",
    "CastingBar.lua",
    "Focus.lua",
    "Target.lua",
    "Events.lua",
    "SlashCommands.lua"
}

for _, file in ipairs(files) do
    LoadAddonFile(file)
end

print("--- Firing ADDON_LOADED ---")
Mocks.FireEvent("ADDON_LOADED", ADDON_NAME)

print("--- Simulating NamePlates ---")
-- Create an enemy unit and its nameplate
Mocks.CreateTestUnit("nameplate1", {
    name = "Enemy Grunt",
    health = 50,
    healthMax = 100,
    level = 70,
    faction = "Horde",
    isPlayer = false,
    classification = "normal",
    cast = {
        name = "Fireball",
        startTime = Mocks.time * 1000,
        endTime = (Mocks.time + 2) * 1000,
        uninterruptible = false,
    }
})
local np1 = Mocks.CreateTestNameplate("nameplate1")

-- Fire NAME_PLATE_UNIT_ADDED event
print("Firing NAME_PLATE_UNIT_ADDED for nameplate1")
Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate1")

-- Advance time to trigger any throttled updates or cast bars
Mocks.AdvanceTime(0.5)
if addonTable.Core and addonTable.Core.ApplyToAll then
    print("Calling Minimizer.Core.ApplyToAll")
    addonTable.Core.ApplyToAll()
end

Mocks.AdvanceTime(0.5)

print("Firing NAME_PLATE_UNIT_REMOVED for nameplate1")
Mocks.FireEvent("NAME_PLATE_UNIT_REMOVED", "nameplate1")

print("--- Smoke Test Completed Successfully ---")
