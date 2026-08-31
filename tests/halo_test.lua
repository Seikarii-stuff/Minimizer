local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

T.fireAddonLoaded()
Mocks.playerSpells = { [147362] = true }
Mocks.cooldowns[147362] = { start = Mocks.time, duration = 15 }

local hostA = CreateFrame("Frame", "MinimizerHaloHostA", UIParent)
local haloA = addonTable.Halo.Create(hostA, { size = 64, cooldownName = "MinimizerTestHaloCooldown" })

check(type(addonTable.Halo) == "table" and haloA ~= nil, "Halo: se crea mediante Minimizer.Halo")
check(haloA.MinimizerHaloHost == hostA, "Halo: conserva el host proporcionado")
check(haloA.MinimizerHaloSize == 64, "Halo: conserva el tamaño configurado")
check(haloA.MinimizerHaloTexture ~= nil, "Halo: crea su textura")
check(haloA.MinimizerHaloCooldown ~= nil, "Halo: crea su cooldown")
check(haloA.MinimizerHaloCooldown.template == "CooldownFrameTemplate", "Halo: usa CooldownFrameTemplate")
check(haloA:IsShown() == false, "Halo: comienza oculto")
check(haloA:ShowFor(147362) == true and haloA:IsShown() == true, "Halo: ShowFor actualiza cooldown y muestra")
check(haloA:ShowFor(nil) == false and haloA:IsShown() == false, "Halo: invalida spell y oculta")

haloA:SetHost(nil)
check(haloA.MinimizerHaloHost == nil, "Halo: SetHost(nil) devuelve al host neutral")
haloA:SetHost(hostA)
check(haloA.MinimizerHaloHost == hostA, "Halo: puede recuperar un host existente")

local hostB = CreateFrame("Frame", "MinimizerHaloHostB", UIParent)
haloA:SetHost(hostB)
check(haloA.MinimizerHaloHost == hostB, "Halo: puede cambiar a otro consumidor/host")

local source = assert(io.open("Overlays/Halo.lua", "r")):read("*a")
check(not source:match("SetFrameStrata"), "Halo: no contiene politica de FrameStrata")
check(not source:match("if%s+target%s+then") and not source:match("if%s+wheel%s+then") and not source:match("if%s+mouse%s+then"), "Halo: no contiene logica especifica de consumidores")
check(source:match("cooldownFrameLevelOffset"), "Halo: permite al consumidor controlar el nivel relativo del cooldown")

local framesAfterCreate = #Mocks.frames
haloA:ShowFor(147362)
haloA:ShowFor(147362)
check(#Mocks.frames == framesAfterCreate, "Halo: las actualizaciones no crean instancias adicionales")

T.finish("HALO TESTS")
