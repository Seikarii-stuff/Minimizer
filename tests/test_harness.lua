-- tests/test_harness.lua
local Mocks = dofile("tests/wow_mock.lua")

local M = {}
M.Mocks = Mocks
M.ADDON_NAME = "Minimizer"
M.addonTable = {}
M.testsRun = 0
M.testsFailed = 0

function M.LoadAddon()
    local function loadFile(path)
        local func, err = loadfile(path)
        assert(func, err)
        func(M.ADDON_NAME, M.addonTable)
    end

    local fh = assert(io.open("Minimizer.toc", "r"))
    for line in fh:lines() do
        local path = line:match("^%s*(.-)%s*$")
        if path ~= "" and not path:match("^#") and path:match("%.lua$") then
            loadFile(path:gsub("\\", "/"))
        end
    end
    fh:close()
    Mocks.FireEvent("ADDON_LOADED", M.ADDON_NAME)
end

function M.check(condition, description)
    M.testsRun = M.testsRun + 1
    if condition then
        print("|cff00ff00OK|r: " .. description)
    else
        M.testsFailed = M.testsFailed + 1
        print("|cffff0000FAIL|r: " .. description)
    end
end

function M.finish(label)
    print(string.format("=== %s: %d/%d passed ===", label, M.testsRun - M.testsFailed, M.testsRun))
    if M.testsFailed > 0 then
        error(M.testsFailed .. " test(s) failed")
    end
end

return M
