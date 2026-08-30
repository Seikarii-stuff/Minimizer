-- tests/wheel_test.lua
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
Load("Overlays/Overlays.lua")
Load("Wheel/Pips.lua")
Load("Wheel/Wheel.lua")
Load("Overlays/Focus.lua")
Load("Overlays/Target.lua")
Load("Menu.lua")

MinimizerDB = {}
MinimizerCharDB = {}
addonTable.Config.Initialize()
addonTable.Wheel:ApplyConfig()

local failures = 0
local function check(condition, description)
    if condition then
        print("OK: " .. description)
    else
        failures = failures + 1
        print("FAIL: " .. description)
    end
end

check(MinimizerDB.wheelEnabled == true, "Config: Wheel activada por defecto")
check(MinimizerDB.wheelSize == 180, "Config: tamaño por defecto = 180")
check(MinimizerDB.wheelPipRadius == 75, "Config: radio por defecto = 75")
check(MinimizerCharDB.pip1 == nil and MinimizerCharDB.pip6 == nil, "Config: slots de Pips no crean overrides")
check(addonTable.Wheel._enabled == true, "Wheel: configuración aplicada después de Config.Initialize")

MinimizerDB.wheelEnabled = false
MinimizerDB.wheelSize = 220
MinimizerDB.wheelPipRadius = 88
addonTable.Config.Initialize()
addonTable.Wheel:ApplyConfig()
check(_G.MinimizerPlayerWheel:IsShown() == false, "Wheel: disabled oculta la Wheel")
check(_G.MinimizerPlayerWheel.MinimizerWheelInterrupt:IsShown() == false, "Wheel: disabled oculta el interrupt cooldown")

MinimizerDB.wheelEnabled = true
addonTable.Wheel:ApplyConfig()
check(_G.MinimizerPlayerWheel:IsShown() == true, "Wheel: enabled vuelve a mostrar la Wheel")
check(addonTable.Wheel._size == 220, "Wheel: aplica size")
check(addonTable.Wheel._pipRadius == 88, "Wheel: aplica radius")

local setSizeCalls, setRadiusCalls = 0, 0
local originalSetSize = addonTable.Wheel.SetSize
local originalSetPipRadius = addonTable.Wheel.SetPipRadius
addonTable.Wheel.SetSize = function(self, size)
    setSizeCalls = setSizeCalls + 1
    return originalSetSize(self, size)
end
addonTable.Wheel.SetPipRadius = function(self, radius)
    setRadiusCalls = setRadiusCalls + 1
    return originalSetPipRadius(self, radius)
end
addonTable.Wheel:ApplyConfig()
check(setSizeCalls == 0, "Wheel: mismo size no llama a SetSize")
check(setRadiusCalls == 0, "Wheel: mismo radius no llama a SetPipRadius")

local pips = addonTable.Pips.CreatePips(_G.MinimizerPlayerWheel, "MinimizerWheelTestPip", 75)
local framesAfterCreate = #Mocks.frames
local firstPip = pips[1]
local oldAngles = {}
for index, pip in ipairs(pips) do oldAngles[index] = pip.MinimizerPipAngle end
check(#pips == 6, "Pips: crea seis slots")
check(addonTable.Pips.SetRadius(pips, 75) == false, "Pips: mismo radius no hace trabajo")
check(#Mocks.frames == framesAfterCreate, "Pips: mismo radius no crea frames")
check(addonTable.Pips.SetRadius(pips, 91) == true, "Pips: cambio de radius reposiciona")
local radiusOK, anglesOK = true, true
for index, pip in ipairs(pips) do
    if pip.MinimizerPipRadius ~= 91 then radiusOK = false end
    if pip.MinimizerPipAngle ~= oldAngles[index] then anglesOK = false end
end
check(radiusOK, "Pips: aplica nuevo radius")
check(anglesOK, "Pips: conserva slots")
check(pips[1] == firstPip, "Pips: conserva los mismos frames")
check(#Mocks.frames == framesAfterCreate, "Pips: SetRadius no crea frames")

local framesBeforeMenu = #Mocks.frames
addonTable.Menu.Open()
local menuFrame = addonTable.Menu.frame
check(menuFrame ~= nil, "Menu: EnsureFrame es singleton")
check(menuFrame.tabs.Plater ~= nil and menuFrame.tabs.Wheel ~= nil, "Menu: existen ambas tabs")
check(menuFrame.activeTab == "Plater", "Menu: abre en Plater")
check(menuFrame.MinimizerMenuControls.plater.legend ~= nil, "Menu: legend pertenece a Plater")
check(menuFrame.MinimizerMenuControls.plater.divider ~= nil, "Menu: divider creado en Menu.lua")
addonTable.Menu.frame.tabs.Wheel.button:GetScript("OnClick")(addonTable.Menu.frame.tabs.Wheel.button)
check(addonTable.Menu.frame.activeTab == "Wheel", "Menu: cambia a Wheel")

for _ = 1, 10 do addonTable.Menu.Open(); addonTable.Menu.Close() end
addonTable.Menu.Refresh()
check(#Mocks.frames == framesBeforeMenu, "Menu: abrir/cerrar/Refresh no crea UI adicional")
check(MinimizerDB.wheelSize == 220 and MinimizerDB.wheelPipRadius == 88 and MinimizerDB.wheelEnabled == true,
    "Menu: Refresh no modifica SavedVariables")

MinimizerCharDB.pip1 = 1719
addonTable.Config.Initialize()
check(MinimizerCharDB.pip1 == 1719 and MinimizerDB.wheelSize == 220, "Config: conserva overrides")
check(addonTable.Overlays.Get("Wheel") == addonTable.Wheel, "Lifecycle: Wheel registrada en Overlays")
check(addonTable.Overlays.Get("Target") == addonTable.Target, "Lifecycle: Target registrado")
check(addonTable.Overlays.Get("Focus") == addonTable.Focus, "Lifecycle: Focus registrado")

if failures > 0 then os.exit(1) end
print("All Wheel tests passed.")
