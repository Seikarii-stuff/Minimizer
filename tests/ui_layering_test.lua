-- tests/ui_layering_test.lua
-- Architecture tests for component ownership and render-context policy.
local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

MinimizerDB = { wheelEnabled = true, wheelSize = 180, wheelPipRadius = 75, enableFocusFace = true }
MinimizerCharDB = {}
T.fireAddonLoaded()

check(type(addonTable.Halo) == "table", "Layering: Minimizer.Halo es un componente de primer nivel")
check(_G.MinimizerPlayerWheel.MinimizerWheelHalo ~= nil, "Layering: Wheel expone una instancia de Halo compartida")
check(_G.MinimizerPlayerWheel.MinimizerWheelHalo.MinimizerHaloCooldown == _G.MinimizerPlayerWheel.MinimizerWheelInterrupt, "Layering: Wheel reutiliza el cooldown de Halo")

local wheelSource = assert(io.open("Wheel/Wheel.lua", "r")):read("*a")
local pipsSource = assert(io.open("Wheel/Pips.lua", "r")):read("*a")
local haloSource = assert(io.open("Overlays/Halo.lua", "r")):read("*a")
local targetSource = assert(io.open("Overlays/Target.lua", "r")):read("*a")
local focusSource = assert(io.open("Overlays/Focus.lua", "r")):read("*a")
local widgetsSource = assert(io.open("Overlays/Widgets.lua", "r")):read("*a")

check(wheelSource:match("wheelFrame:SetFrameStrata%(%s*[\"']MEDIUM[\"']%s*%)"), "Layering: Wheel usa MEDIUM")
check(not wheelSource:match("SetFrameStrata%s*%(%s*[\"']HIGH[\"']"), "Layering: Wheel no usa HIGH")
check(not wheelSource:match("wheelFrame:SetFrameLevel%(%s*100%s*%)"), "Layering: Wheel no usa FrameLevel global arbitrario")
check(wheelSource:match("Minimizer%.Halo%.Create"), "Layering: Wheel consume Minimizer.Halo")
check(wheelSource:match("wheelHalo:ShowFor"), "Layering: Wheel delega cooldown a Halo")
check(not pipsSource:match("SetFrameStrata%s*%("), "Layering: Pips heredan strata del Wheel")
check(pipsSource:match("pip:SetFrameLevel%(%s*%(%s*parentFrame:GetFrameLevel"), "Layering: Pips mantienen solo nivel relativo")
check(not haloSource:match("SetFrameStrata"), "Layering: Halo no decide FrameStrata")
check(not widgetsSource:match("CreateHalo") and not widgetsSource:match("UpdateHalo"), "Layering: Widgets no contiene Halo")

Mocks.CreateTestUnit("target", { name = "Target Mob", level = 70, faction = "Horde", guid = "target_guid" })
Mocks.CreateTestNameplate("target")
addonTable.Target:UpdateTargetCDs()
local targetHalo = _G.MinimizerTargetHalo
check(targetHalo ~= nil and targetHalo.MinimizerHaloHost == Mocks.nameplates.target, "Layering: Target proporciona la nameplate como host")
check(targetSource:match("haloFrame:SetFrameLevel%(%s*plateLevel%s*%+%s*2%s*%)"), "Layering: Target usa FrameLevel relativo")
check(not targetSource:match("SetFrameStrata%s*%(%s*[\"']HIGH[\"']"), "Layering: Target no fuerza HIGH")

Mocks.CreateTestUnit("focus", { name = "Focus Mob", level = 70, faction = "Horde", guid = "focus_guid" })
Mocks.CreateTestNameplate("focus")
addonTable.Focus:UpdateFace()
check(addonTable.Focus.Halo == nil, "Layering: Focus no consume Halo")
check(focusSource:match("frame:SetParent%(%s*plate%s*%)"), "Layering: Focus portrait usa la nameplate como contexto")
check(focusSource:match("frame:SetFrameLevel%(%s*plateLevel%s*%+%s*1%s*%)"), "Layering: Focus usa FrameLevel relativo")
check(not focusSource:match("SetFrameStrata%s*%(%s*[\"']HIGH[\"']"), "Layering: Focus no fuerza HIGH")

local mouseFuture = CreateFrame("Frame", "MinimizerFutureMouseHost", UIParent)
mouseFuture:SetFrameStrata("HIGH")
check(mouseFuture ~= nil and not haloSource:match("SetFrameStrata"), "Layering: un host futuro puede elegir HIGH sin modificar Halo")

local framesBefore = #Mocks.frames
addonTable.Wheel:Update()
addonTable.Wheel:Update()
check(#Mocks.frames == framesBefore, "Layering: updates no crean nuevas instancias de Halo")

local toc = assert(io.open("Minimizer.toc", "r")):read("*a")
local haloPos = assert(toc:find("Overlays/Halo.lua", 1, true))
local wheelPos = assert(toc:find("Wheel/Wheel.lua", 1, true))
local targetPos = assert(toc:find("Overlays/Target.lua", 1, true))
check(haloPos < wheelPos and haloPos < targetPos, "Layering: TOC carga Halo antes de sus consumidores")

T.finish("UI LAYERING TESTS")
