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
    for line in fh:lines() do
        local trimmed = line:match("^%s*(.-)%s*$")
        trimmed = trimmed:gsub("\\", "/")
        if trimmed ~= "" and not trimmed:match("^#") and not trimmed:match("^%.%.") then
            if trimmed:match("%.lua$") then table.insert(list, trimmed) end
        end
    end
    fh:close()
    return list
end
local files = GetFileListFromToc("Minimizer.toc")
for _, f in ipairs(files) do LoadAddonFile(f) end
Mocks.FireEvent("ADDON_LOADED", ADDON_NAME)

local token = "nameplate73"
Mocks.CreateTestUnit(token, {
    level = 70, classification = "normal", faction = "Horde", powerType = 1,
    cast = { name = "Reuse Check", startTime = 0, endTime = 2000, uninterruptible = false }
})
Mocks.CreateTestNameplate(token)
Mocks.unitCastingInfoCallCounts[token] = 0
Mocks.unitChannelInfoCallCounts[token] = 0

local s1, s2, s3, s4 = addonTable.Cast.GetState(token)
print("Cast.GetState before ApplyToUnit ->", s1, s2, s3 and "<secret>" or s3, s4)
print("Interrupt.IsReady() ->", addonTable.Interrupt.IsReady())

addonTable.Core.ApplyToUnit(token)

local castCalls = Mocks.unitCastingInfoCallCounts[token] or 0
local channelCalls = Mocks.unitChannelInfoCallCounts[token] or 0
print("UnitCastingInfo calls:", castCalls)
print("UnitChannelInfo calls:", channelCalls)
local np = Mocks.nameplates[token]
local castBar = np.UnitFrame.castBar
local r,g,b,a = castBar:GetStatusBarColor()
print(string.format("CastBar color = %.3f %.3f %.3f %.3f", r,g,b,a or 1))
local ready = addonTable.Constants.CastColors.ready
print(string.format("Expected ready color = %.3f %.3f %.3f", ready[1], ready[2], ready[3]))
print("castBar.MinimizerCastUnit =", castBar.MinimizerCastUnit)
local lc = castBar.MinimizerLastCastColor
if lc then print("MinimizerLastCastColor:", lc[1], lc[2], lc[3], lc[4]) else print("MinimizerLastCastColor = nil") end

-- Dump snapshot for token
local plate = addonTable.Utils.GetNamePlateForUnit(token)
local tokenValid = addonTable.Utils.GetValidNamePlateToken(token, plate)
print("Token valid:", tokenValid)
-- Try to rebuild snapshot by calling BuildSnapshot via ApplyToUnit already did it; can't access scratchSnapshot directly. End.
