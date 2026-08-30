-- tests/wheel_test.lua
-- Cobertura de configuración y lifecycle de Player Wheel/Pips.
local Mocks = dofile("tests/wow_mock.lua")
local ADDON_NAME = "Minimizer"
local addonTable = {}

local function Load(path)
    local func, err = loadfile(path)
    assert(func, err)
    func(ADDON_NAME, addonTable)
end

Load("Bootstrap.lua")
Load("Core/Utils.lua")
Load("Overlays/Widgets.lua")
Load("Config.lua")
Load("Core/Constants.lua")
Load("Data/SpellData.lua")
Load("Overlays/Pips.lua")
Load("Overlays/Overlays.lua")
Load("Overlays/Wheel.lua")

MinimizerDB = {}
MinimizerCharDB = {}
addonTable.Config.Initialize()

local failures = 0
local function check(condition, description)
    if condition then
        print("|cff00ff00OK|r: " .. description)
    else
        failures = failures + 1
        print("|cffff0000FAIL|r: " .. description)
    end
end

check(MinimizerDB.wheelEnabled == true, "Config: Wheel activada por defecto")
check(MinimizerDB.wheelSize == 180, "Config: tamaño por defecto = 180")
check(MinimizerDB.wheelPipRadius == 75, "Config: radio por defecto = 75")
check(MinimizerCharDB.pip1 == nil and MinimizerCharDB.pip6 == nil, "Config: slots de Pips no crean overrides por personaje")

MinimizerDB.wheelEnabled = false
MinimizerDB.wheelSize = 220
MinimizerDB.wheelPipRadius = 88
addonTable.Config.Initialize()
check(MinimizerDB.wheelEnabled == false and MinimizerDB.wheelSize == 220 and MinimizerDB.wheelPipRadius == 88,
    "Config: no sobrescribe preferencias globales existentes")
check(_G.MinimizerPlayerWheel:IsShown() == false, "Wheel: disabled oculta la Wheel")

MinimizerDB.wheelEnabled = true
addonTable.Wheel:ApplyConfig()
check(_G.MinimizerPlayerWheel:IsShown() == true, "Wheel: enabled vuelve a mostrar la Wheel")
check(_G.MinimizerPlayerWheel.MinimizerWheelSize == 220, "Wheel: aplica el tamaño configurado")

local framesBefore = #Mocks.frames
addonTable.Wheel:ApplyConfig()
addonTable.Wheel:ApplyConfig()
check(#Mocks.frames == framesBefore, "Wheel: actualizar configuración no crea frames duplicados")

local pips = addonTable.Pips.CreatePips(_G.MinimizerPlayerWheel, "MinimizerWheelTestPip", 75)
check(#pips == 6, "Pips: crea los seis slots")
local oldAngles = {}
for index, pip in ipairs(pips) do oldAngles[index] = pip.MinimizerPipAngle end
addonTable.Pips.SetRadius(pips, 91)
local radiusOK = true
local anglesOK = true
for index, pip in ipairs(pips) do
    if pip.MinimizerPipRadius ~= 91 then radiusOK = false end
    if pip.MinimizerPipAngle ~= oldAngles[index] then anglesOK = false end
end
check(radiusOK, "Pips: SetRadius reposiciona al nuevo radio")
check(anglesOK, "Pips: SetRadius conserva los ángulos/slots")
check(#Mocks.frames == framesBefore + 12, "Pips: SetRadius no crea frames adicionales")

MinimizerCharDB.pip1 = 1719
addonTable.Config.Initialize()
check(MinimizerCharDB.pip1 == 1719 and MinimizerDB.wheelSize == 220,
    "Config: conserva selección de Pip por personaje y preferencias globales")

if failures > 0 then
    os.exit(1)
end
print("All Wheel tests passed.")
