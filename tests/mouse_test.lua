local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

MinimizerDB = {}
MinimizerCharDB = {}
T.fireAddonLoaded()

local host = _G.MinimizerMouseHost
local halo = _G.MinimizerMouseHalo
check(addonTable.Overlays.Get("Mouse") == addonTable.Mouse, "Mouse: registrado en Overlays")
check(host:IsShown() == true, "Mouse: enabled por defecto muestra el host")
check(host:GetScript("OnUpdate") ~= nil, "Mouse: enabled por defecto registra OnUpdate")

local setPointCalls = 0
local lastPoint
local originalSetPoint = host.SetPoint
host.SetPoint = function(self, point, relativeTo, relativePoint, x, y)
    setPointCalls = setPointCalls + 1
    lastPoint = { point, relativeTo, relativePoint, x, y }
    return originalSetPoint(self, point, relativeTo, relativePoint, x, y)
end

Mocks.cursorPosition = { x = 200, y = 100 }
local onUpdate = host:GetScript("OnUpdate")
onUpdate(host, 0.02)
check(setPointCalls == 1, "Mouse: actualiza la posicion tras superar el intervalo")
check(lastPoint and lastPoint[1] == "CENTER" and lastPoint[2] == _G.UIParent
    and lastPoint[3] == "BOTTOMLEFT" and lastPoint[4] == 200 and lastPoint[5] == 100,
    "Mouse: sigue las coordenadas del cursor")

onUpdate(host, 0.02)
check(setPointCalls == 1, "Mouse: cursor quieto no vuelve a llamar SetPoint")

Mocks.cursorPosition = { x = 201, y = 100 }
onUpdate(host, 0.02)
check(setPointCalls == 2, "Mouse: nuevo cursor vuelve a reposicionar")

setPointCalls = 0
lastPoint = nil
onUpdate = host:GetScript("OnUpdate")
Mocks.cursorPosition = { x = 300, y = 150 }
for _ = 1, 6 do
    onUpdate(host, 0.001)
end
check(setPointCalls == 0, "Mouse: throttle evita reposicionamiento a resolucion de frame")
onUpdate(host, 0.001)
check(setPointCalls == 1, "Mouse: acumulador permite actualizar al superar 0.006944s")

addonTable.Mouse:SetEnabled(false)
check(host:IsShown() == false, "Mouse: OFF oculta el host")
check(host:GetScript("OnUpdate") == nil, "Mouse: OFF elimina realmente OnUpdate")

local cooldownCallsWhenOff = 0
local originalDebouncedUpdate = addonTable.Mouse.DebouncedUpdate
addonTable.Mouse.DebouncedUpdate = function(...)
    cooldownCallsWhenOff = cooldownCallsWhenOff + 1
    return originalDebouncedUpdate(...)
end
addonTable.Mouse:OnCooldownTick()
addonTable.Mouse:OnCooldownTick()
addonTable.Mouse:OnCooldownTick()
check(cooldownCallsWhenOff == 0, "Mouse: OnCooldownTick hace early-out cuando disabled")
addonTable.Mouse.DebouncedUpdate = originalDebouncedUpdate

addonTable.Mouse:SetEnabled(true)
check(host:IsShown() == true, "Mouse: reactivacion muestra el host")
check(host:GetScript("OnUpdate") ~= nil, "Mouse: reactivacion reengancha OnUpdate")

Mocks.playerSpells = { [147362] = true }
Mocks.units.player.class = "HUNTER"
Mocks.cooldowns[147362] = { start = 0, duration = 10 }
addonTable.Interrupt.InvalidateSpellIDCache()
local cooldownCalls = 0
local receivedCooldown, receivedSpellID
local originalApplyCooldownDuration = Minimizer.Widgets.ApplyCooldownDuration
Minimizer.Widgets.ApplyCooldownDuration = function(cooldown, spellID)
    cooldownCalls = cooldownCalls + 1
    receivedCooldown = cooldown
    receivedSpellID = spellID
    return originalApplyCooldownDuration(cooldown, spellID)
end
addonTable.Mouse:OnCooldownTick()
check(cooldownCalls == 1, "Mouse: OnCooldownTick refleja el interrupt en el halo")
check(receivedCooldown == halo.MinimizerHaloCooldown, "Mouse: actualiza el cooldown propio del halo")
check(receivedSpellID == 147362, "Mouse: usa el spellID resuelto por Interrupt")
Minimizer.Widgets.ApplyCooldownDuration = originalApplyCooldownDuration

local positionBeforeCooldown = lastPoint
local setPointCallsBeforeCooldown = setPointCalls
addonTable.Mouse:OnCooldownTick()
addonTable.Mouse:OnCooldownTick()
addonTable.Mouse:OnCooldownTick()
check(setPointCalls == setPointCallsBeforeCooldown, "Mouse: OnCooldownTick no llama SetPoint de posicion")
check(lastPoint == positionBeforeCooldown, "Mouse: OnCooldownTick no altera el estado de posicion")

local framesBeforeApply = #Mocks.frames
local scriptBeforeApply = host:GetScript("OnUpdate")
addonTable.Mouse:ApplyConfig()
addonTable.Mouse:ApplyConfig()
check(#Mocks.frames == framesBeforeApply, "Mouse: ApplyConfig idempotente no crea frames")
check(host:GetScript("OnUpdate") == scriptBeforeApply, "Mouse: ApplyConfig idempotente no reengancha OnUpdate")

local source = assert(io.open("Overlays/Mouse.lua", "r")):read("*a")
check(source:match("Minimizer%.Halo%.Create"), "Mouse: usa Minimizer.Halo compartido")
check(not source:match("CreateMaskTexture"), "Mouse: no crea mascaras redundantes")
check(not source:match('CreateFrame%(%s*"Cooldown"'), "Mouse: no crea Cooldown propio")
check(source:match('SetFrameStrata%(%s*"HIGH"%s*%)'), "Mouse: HIGH esta en el host")
check(not source:match("RegisterEvent"), "Mouse: no registra eventos")
check(source:match("Minimizer%.Widgets%.ApplyCooldownDuration"), "Mouse: actualiza cooldown mediante Widgets")
check(not source:match("haloFrame:ShowFor"), "Mouse: no usa Halo:ShowFor para el interrupt")
check(not source:match("haloFrame:SetCooldown%("), "Mouse: no usa Halo:SetCooldown para el interrupt")

local haloSource = assert(io.open("Overlays/Halo.lua", "r")):read("*a")
check(not haloSource:match("SetFrameStrata"), "Halo: no conoce la strata")

T.finish("MOUSE TESTS")
