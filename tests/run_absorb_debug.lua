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

local token = "nameplate99"
Mocks.CreateTestUnit(token, { level = 70, classification = "normal", faction = "Horde", powerType = 1 })
local np = Mocks.CreateTestNameplate(token)
np.UnitFrame.healthBar.totalAbsorbOverlay = CreateFrame("Frame")
np.UnitFrame.healthBar.totalAbsorbOverlay:Show()

print("Before ApplyToUnit: hooked=", np.UnitFrame.healthBar.MinimizerHealthColorHooked)
addonTable.Core.ApplyToUnit(token)
local hb = addonTable.Utils.GetHealthBar(np)
local r,g,b = hb:GetStatusBarColor()
print(string.format("After ApplyToUnit color = %.3f %.3f %.3f", r,g,b))
print("Hooked now=", hb.MinimizerHealthColorHooked)
local found = Minimizer.Utils.GetNameplateFromHealthBar(hb)
print("GetNameplateFromHealthBar ->", found)
print("np =", np)
local parent = hb:GetParent()
print("hb parent =", parent)
local p2 = parent and parent:GetParent()
print("hb parent:GetParent() =", p2)
local p3 = p2 and p2:GetParent()
print("hb parent:GetParent():GetParent() =", p3)
print("np.namePlateUnitToken =", np.namePlateUnitToken)

-- Simulate native repaint
hb:SetStatusBarColor(1,1,1,1)
local r2,g2,b2 = hb:GetStatusBarColor()
print(string.format("After native repaint color = %.3f %.3f %.3f", r2,g2,b2))
print("MinimizerHealthColorApplying flag =", hb.MinimizerHealthColorApplying)
print("MinimizerLastAppliedColor =", np.MinimizerLastAppliedColor and np.MinimizerLastAppliedColor[1])
