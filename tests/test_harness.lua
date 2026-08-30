-- tests/test_harness.lua
-- Shared WoW/mock loader and assertion accounting for the test suite.
local Mocks = dofile("tests/wow_mock.lua")
local ADDON_NAME = "Minimizer"
local addonTable = {}

local function GetFileListFromToc(tocPath)
    local list = {}
    local fh = assert(io.open(tocPath, "r"), "No se pudo abrir el .toc: " .. tocPath)
    for line in fh:lines() do
        local trimmed = line:match("^%s*(.-)%s*$")
        trimmed = trimmed:gsub("\\\\", "/")
        if trimmed ~= "" and not trimmed:match("^#") and not trimmed:match("^%..") and trimmed:match("%.lua$") then
            table.insert(list, trimmed)
        end
    end
    fh:close()
    return list
end

local function LoadAddonFile(filepath)
    local func, err = loadfile(filepath)
    if not func then
        if filepath == "Data/SpellData.lua" or filepath == "data/SpellData.lua" then
            addonTable.Data = addonTable.Data or { INTERRUPT_SPELLS = {} }
            return
        end
        error("Failed to load " .. filepath .. ": " .. tostring(err))
    end
    func(ADDON_NAME, addonTable)
end

for _, file in ipairs(GetFileListFromToc("Minimizer.toc")) do
    LoadAddonFile(file)
end

local testsRun = 0
local testsFailed = 0

local function check(condition, description)
    testsRun = testsRun + 1
    if not condition then
        testsFailed = testsFailed + 1
        print("FAIL: " .. description)
    else
        print("OK: " .. description)
    end
end

local function finish(label)
    print(string.format("=== %s: %d/%d passed ===", label, testsRun - testsFailed, testsRun))
    if testsFailed > 0 then
        error(testsFailed .. " test(s) failed.")
    end
end

local function fireAddonLoaded()
    Mocks.FireEvent("ADDON_LOADED", ADDON_NAME)
end

return {
    Mocks = Mocks,
    addonTable = addonTable,
    ADDON_NAME = ADDON_NAME,
    check = check,
    finish = finish,
    fireAddonLoaded = fireAddonLoaded,
}
