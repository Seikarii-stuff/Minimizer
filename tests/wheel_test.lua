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

MinimizerDB = {
    wheelEnabled = false,
    wheelSize = 220,
    wheelPipRadius = 88,
}
MinimizerCharDB = {}

-- Exercise the real lifecycle: Bootstrap receives ADDON_LOADED only after Wheel is loaded.
Mocks.FireEvent("ADDON_LOADED", ADDON_NAME)

local failures = 0
local function check(condition, description)
    if condition then
        print("OK: " .. description)
    else
        failures = failures + 1
        print("FAIL: " .. description)
    end
end

check(MinimizerDB.wheelEnabled == false, "Lifecycle: SavedVariables se conservan al inicializar")
check(MinimizerDB.wheelSize == 220, "Lifecycle: size configurado queda disponible tras inicialización")
check(MinimizerDB.wheelPipRadius == 88, "Lifecycle: radius configurado queda disponible tras inicialización")
check(addonTable.Wheel._enabled == false, "Lifecycle: ADDON_LOADED aplica Wheel después de cargar Wheel.lua")
check(_G.MinimizerPlayerWheel:IsShown() == false, "Wheel: wheelEnabled=false oculta la Wheel en la inicialización")
check(_G.MinimizerPlayerWheel.MinimizerWheelInterrupt:IsShown() == false,
    "Wheel: wheelEnabled=false oculta el interrupt cooldown en la inicialización")
check(addonTable.Wheel._size == 220, "Wheel: size se aplica inicialmente")
check(addonTable.Wheel._pipRadius == 88, "Wheel: pip radius se aplica inicialmente")

-- Enabling later through ApplyConfig must update the display without relying on cooldown events.
MinimizerDB.wheelEnabled = true
addonTable.Wheel:ApplyConfig()
check(_G.MinimizerPlayerWheel:IsShown() == true, "Wheel: ApplyConfig activa la Wheel posteriormente")
check(addonTable.Wheel._enabled == true, "Wheel: estado enabled queda cacheado")

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
check(setSizeCalls == 0, "Wheel: mismo size no llama repetidamente a SetSize")
check(setRadiusCalls == 0, "Wheel: mismo radius no llama repetidamente a SetPipRadius")

-- The Wheel owns one persistent Pips collection; updates/config changes must not create more frames.
local wheelPips = addonTable.Pips and _G.MinimizerPlayerWheel._children
local framesBeforeWheelUpdates = #Mocks.frames
addonTable.Wheel:Update()
addonTable.Wheel:Update()
addonTable.Wheel:OnCooldownTick()
MinimizerDB.wheelSize = 240
MinimizerDB.wheelPipRadius = 92
addonTable.Wheel:ApplyConfig()
addonTable.Wheel:Update()
check(#Mocks.frames == framesBeforeWheelUpdates,
    "Wheel: ApplyConfig/Update/OnCooldownTick no crean frames adicionales")
check(type(wheelPips) == "table" and #wheelPips >= 6,
    "Wheel: conserva la colección de Pips creada durante la inicialización")

-- Direct Pips component coverage.
local parent = CreateFrame("Frame", "MinimizerWheelTestParent")
parent:SetSize(180, 180)
check(type(addonTable.Pips) == "table" and type(addonTable.Pips.SLOTS) == "table",
    "Pips: modulo Minimizer.Pips y tabla SLOTS existen")
check(#addonTable.Pips.SLOTS == 6, "Pips: SLOTS define seis slots de Wheel")

local s1Color = addonTable.Pips.SLOTS[1].color
local s2Color = addonTable.Pips.SLOTS[2].color
check(s1Color and math.abs(s1Color.on[2] - 1.00) < 0.01 and math.abs(s1Color.on[1] - 0.10) < 0.01,
    "Pips: Pip 1 es VERDE")
check(s2Color and math.abs(s2Color.on[3] - 1.00) < 0.01 and math.abs(s2Color.on[1] - 0.20) < 0.01,
    "Pips: Pip 2 es AZUL")

local pips = addonTable.Pips.CreatePips(parent, "MinimizerWheelTestPip", 75)
local framesAfterCreate = #Mocks.frames
local firstPip = pips[1]
local oldAngles = {}
for index, pip in ipairs(pips) do oldAngles[index] = pip.MinimizerPipAngle end
check(#pips == #addonTable.Pips.SLOTS, "Pips: CreatePips crea un frame por slot")
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

MinimizerCharDB.pip1 = 118000
Mocks.cooldowns[118000] = { start = Mocks.time, duration = 45 }
check(addonTable.Pips.GetSpellID(1) == 118000, "Pips: GetSpellID resuelve el override del slot")
addonTable.Pips.UpdatePips(pips)
check(pips[1]:IsShown() == true, "Pips: UpdatePips muestra el pip con cooldown activo")
addonTable.Pips.HidePips(pips)
check(pips[1]:IsShown() == false and pips[2]:IsShown() == false,
    "Pips: HidePips oculta todos los pips")

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
check(MinimizerDB.wheelSize == 240 and MinimizerDB.wheelPipRadius == 92 and MinimizerDB.wheelEnabled == true,
    "Menu: Refresh no modifica SavedVariables")

MinimizerCharDB.pip1 = 1719
addonTable.Config.Initialize()
check(MinimizerCharDB.pip1 == 1719 and MinimizerDB.wheelSize == 240, "Config: conserva overrides")
check(addonTable.Overlays.Get("Wheel") == addonTable.Wheel, "Lifecycle: Wheel registrada en Overlays")
check(addonTable.Overlays.Get("Target") == addonTable.Target, "Lifecycle: Target registrado")
check(addonTable.Overlays.Get("Focus") == addonTable.Focus, "Lifecycle: Focus registrado")

if failures > 0 then os.exit(1) end
print("All Wheel tests passed.")
