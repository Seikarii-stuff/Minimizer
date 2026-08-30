local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

T.fireAddonLoaded()

local token = "nameplate99"
Mocks.CreateTestUnit(token, { level = 70, classification = "normal", faction = "Horde", powerType = 1 })
local np = Mocks.CreateTestNameplate(token)
np.UnitFrame.healthBar.totalAbsorbOverlay = CreateFrame("Frame")
np.UnitFrame.healthBar.totalAbsorbOverlay:Show()

addonTable.Dispatcher.ApplyToUnit(token)
local hb = addonTable.Utils.GetHealthBar(np)
local r, g, b = hb:GetStatusBarColor()
local absorb = addonTable.Constants.HealthColors.absorb
check(math.abs(r - absorb[1]) < 0.01 and math.abs(g - absorb[2]) < 0.01 and math.abs(b - absorb[3]) < 0.01,
    "Absorb: ApplyToUnit pinta el color absorb")

hb:SetStatusBarColor(1, 1, 1, 1)
r, g, b = hb:GetStatusBarColor()
check(math.abs(r - absorb[1]) < 0.01 and math.abs(g - absorb[2]) < 0.01 and math.abs(b - absorb[3]) < 0.01,
    "Absorb: un repaint nativo conserva el color absorb")

check(type(addonTable.Absorb.MarkSeen) == "function", "Absorb: MarkSeen es la API canonica")
check(type(addonTable.Absorb.GetTotalAbsorbs) == "function", "Absorb: GetTotalAbsorbs es publico")
check(addonTable.Absorb.MarkAbsorbSeen == nil, "Absorb: no queda alias legacy MarkAbsorbSeen")

T.finish("ABSORB TESTS")
