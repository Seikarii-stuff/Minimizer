local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

MinimizerDB = {}
MinimizerCharDB = {}
T.fireAddonLoaded()

local host = _G.MinimizerMouseHost
check(addonTable.Overlays.Get("Mouse") == addonTable.Mouse, "Mouse: registrado en Overlays")
check(host:IsShown() == true, "Mouse: enabled por defecto muestra el host")
check(host:GetScript("OnUpdate") ~= nil, "Mouse: enabled por defecto registra OnUpdate")

local setPointCalls = 0
local lastPoint
host.SetPoint = function(self, point, relativeTo, relativePoint, x, y)
    setPointCalls = setPointCalls + 1
    lastPoint = { point, relativeTo, relativePoint, x, y }
end

Mocks.cursorPosition = { x = 200, y = 100 }
local onUpdate = host:GetScript("OnUpdate")
onUpdate(host, 0.02)
check(setPointCalls == 1, "Mouse: actualiza la posicion tras superar el intervalo")
check(lastPoint and lastPoint[1] == "CENTER" and lastPoint[2] == _G.UIParent
    and lastPoint[3] == "BOTTOMLEFT" and lastPoint[4] == 200 and lastPoint[5] == 100,
    "Mouse: sigue las coordenadas del cursor")

setPointCalls = 0
lastPoint = nil
onUpdate = host:GetScript("OnUpdate")
for _ = 1, 6 do
    onUpdate(host, 0.001)
end
check(setPointCalls == 0, "Mouse: throttle evita reposicionamiento a resolucion de frame")
onUpdate(host, 0.001)
check(setPointCalls == 1, "Mouse: acumulador permite actualizar al superar 0.006944s")

addonTable.Mouse:SetEnabled(false)
check(host:IsShown() == false, "Mouse: OFF oculta el host")
check(host:GetScript("OnUpdate") == nil, "Mouse: OFF elimina realmente OnUpdate")

addonTable.Mouse:SetEnabled(true)
check(host:IsShown() == true, "Mouse: reactivacion muestra el host")
check(host:GetScript("OnUpdate") ~= nil, "Mouse: reactivacion reengancha OnUpdate")

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

local haloSource = assert(io.open("Overlays/Halo.lua", "r")):read("*a")
check(not haloSource:match("SetFrameStrata"), "Halo: no conoce la strata")

T.finish("MOUSE TESTS")
