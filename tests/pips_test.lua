local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

T.fireAddonLoaded()
local Pips = addonTable.Pips
check(type(Pips) == "table" and type(Pips.SLOTS) == "table", "Pips: modulo y SLOTS existen")
check(#Pips.SLOTS == 6, "Pips: Wheel define seis slots")

local s1, s2 = Pips.SLOTS[1].color, Pips.SLOTS[2].color
check(s1 and math.abs(s1.on[1] - 0.10) < 0.01 and math.abs(s1.on[2] - 1) < 0.01, "Pips: slot 1 es verde")
check(s2 and math.abs(s2.on[1] - 0.20) < 0.01 and math.abs(s2.on[3] - 1) < 0.01, "Pips: slot 2 es azul")

local parent = CreateFrame("Frame", "MinimizerPipsTestParent")
parent:SetSize(180, 180)
local pips = Pips.CreatePips(parent, "MinimizerPipsTest", 75)
local framesAfterCreate = #Mocks.frames
check(#pips == #Pips.SLOTS, "Pips: CreatePips crea un frame por slot")

local oldAngles = {}
for i, pip in ipairs(pips) do oldAngles[i] = pip.MinimizerPipAngle end
check(Pips.SetRadius(pips, 75) == false, "Pips: mismo radius es early-out")
check(#Mocks.frames == framesAfterCreate, "Pips: mismo radius no crea frames")
check(Pips.SetRadius(pips, 91) == true, "Pips: cambio de radius reposiciona")
for i, pip in ipairs(pips) do
    check(pip.MinimizerPipRadius == 91 and pip.MinimizerPipAngle == oldAngles[i], "Pips: conserva slot y aplica radius " .. i)
end
check(pips[1] ~= nil and pips[1].MinimizerPipSlotId == 1, "Pips: conserva frames existentes")
check(#Mocks.frames == framesAfterCreate, "Pips: SetRadius no crea frames")

MinimizerCharDB.pip1 = 118000
Mocks.cooldowns[118000] = { start = Mocks.time, duration = 45 }
check(Pips.GetSpellID(1) == 118000, "Pips: GetSpellID resuelve override")
Pips.UpdatePips(pips)
check(pips[1]:IsShown() == true, "Pips: UpdatePips muestra slot con cooldown")
Pips.HidePips(pips)
check(pips[1]:IsShown() == false and pips[2]:IsShown() == false, "Pips: HidePips oculta todos")

T.finish("PIPS TESTS")
