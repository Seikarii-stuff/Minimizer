local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

T.fireAddonLoaded()
Mocks.playerSpells = { [147362] = true }
Mocks.cooldowns[147362] = { start = Mocks.time, duration = 15 }
MinimizerDB.enableFocusFace = true

Mocks.CreateTestUnit("focus", { name = "Focus Mob", level = 70, faction = "Horde", guid = "focus_guid" })
Mocks.CreateTestNameplate("focus")
addonTable.Focus:UpdateFace()

local portrait = _G.MinimizerFocusPortrait
local cooldown = _G.MinimizerFocusCooldown
check(portrait ~= nil and portrait:IsShown() == true, "Focus: muestra portrait cuando esta habilitado y existe focus")
check(addonTable.Focus.Pips == nil, "Focus: no posee ni consume una coleccion de Pips")
check(addonTable.Focus.Halo == nil, "Focus: no consume el componente Halo")
check(addonTable.Overlays.Get("Focus") == addonTable.Focus, "Focus: esta registrado en Overlays")

local source = assert(io.open("Overlays/Focus.lua", "r")):read("*a")
check(source:match("frame:SetParent%(%s*plate%s*%)"), "Focus: portrait usa la nameplate como contexto")
check(not source:match("SetFrameStrata%s*%(%s*[\"']HIGH[\"']"), "Focus: no fuerza HIGH")
check(source:match("frame:SetFrameLevel%(%s*plateLevel%s*%+%s*1%s*%)"), "Focus: portrait conserva FrameLevel relativo")

MinimizerDB.enableFocusFace = false
addonTable.Focus:UpdateFace()
check(portrait:IsShown() == false, "Focus: se oculta cuando face esta deshabilitado")

T.finish("FOCUS TESTS")
