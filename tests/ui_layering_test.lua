-- Architecture tests for component ownership and render-context policy.
local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

MinimizerDB = { enableFocusFace = true }
MinimizerCharDB = {}
T.fireAddonLoaded()

check(type(addonTable.Halo) == "table", "Layering: Minimizer.Halo es un componente de primer nivel")
check(addonTable.Wheel == nil, "Layering: Wheel fue eliminado")
check(_G.MinimizerPlayerWheel == nil, "Layering: no existe el frame Wheel")

local haloSource = assert(io.open("Overlays/Halo.lua", "r")):read("*a")
local targetSource = assert(io.open("Overlays/Target.lua", "r")):read("*a")
local focusSource = assert(io.open("Overlays/Focus.lua", "r")):read("*a")
check(not haloSource:match("SetFrameStrata"), "Layering: Halo no decide FrameStrata")

Mocks.CreateTestUnit("target", { name = "Target Mob", level = 70, faction = "Horde", guid = "target_guid" })
Mocks.CreateTestNameplate("target")
addonTable.Target:UpdateTargetCDs()
local targetHalo = _G.MinimizerTargetHalo
check(targetHalo ~= nil and targetHalo.MinimizerHaloHost == Mocks.nameplates.target, "Layering: Target proporciona la nameplate como host")
check(targetSource:find("haloFrame:SetFrameLevel", 1, true) ~= nil, "Layering: Target usa FrameLevel relativo")

Mocks.CreateTestUnit("focus", { name = "Focus Mob", level = 70, faction = "Horde", guid = "focus_guid" })
Mocks.CreateTestNameplate("focus")
addonTable.Focus:UpdateFace()
check(addonTable.Focus.Halo == nil, "Layering: Focus no consume Halo")
check(focusSource:find("frame:SetParent(plate)", 1, true) ~= nil, "Layering: Focus usa la nameplate como contexto")

T.finish("UI LAYERING TESTS")
