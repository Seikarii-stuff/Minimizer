local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

MinimizerDB = {
    wheelEnabled = true,
    wheelSize = 240,
    wheelPipRadius = 92,
}
MinimizerCharDB = { pip1 = 118000 }
T.fireAddonLoaded()

local framesBeforeOpen = #Mocks.frames
addonTable.Menu.Open()
local menuFrame = addonTable.Menu.frame
check(menuFrame ~= nil, "Menu: EnsureFrame es singleton")
check(menuFrame.tabs and menuFrame.tabs.Plater and menuFrame.tabs.Wheel, "Menu: existen tabs Plater y Wheel")
check(menuFrame.activeTab == "Plater", "Menu: abre en Plater")
check(menuFrame.MinimizerMenuControls.plater.legend ~= nil, "Menu: legend pertenece a Plater")
check(menuFrame.MinimizerMenuControls.plater.divider ~= nil, "Menu: divider se crea en Menu.lua")

local wheelButton = menuFrame.tabs.Wheel.button
wheelButton:GetScript("OnClick")(wheelButton)
check(menuFrame.activeTab == "Wheel", "Menu: cambia a Wheel")

for _ = 1, 10 do
    addonTable.Menu.Open()
    addonTable.Menu.Close()
end
addonTable.Menu.Refresh()
check(#Mocks.frames == framesBeforeOpen + #menuFrame._children, "Menu: abrir/cerrar/Refresh reutiliza la UI")
check(MinimizerDB.wheelSize == 240 and MinimizerDB.wheelPipRadius == 92 and MinimizerDB.wheelEnabled == true,
    "Menu: Refresh no modifica SavedVariables")

MinimizerCharDB.pip1 = 1719
addonTable.Config.Initialize()
check(MinimizerCharDB.pip1 == 1719 and MinimizerDB.wheelSize == 240, "Config: conserva override de Pip")

T.finish("MENU TESTS")
