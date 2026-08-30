local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

MinimizerDB = {
    wheelEnabled = true,
    wheelSize = 240,
    wheelPipRadius = 92,
}
MinimizerCharDB = { pip1 = 118000 }
T.fireAddonLoaded()

addonTable.Menu.Open()
local frame1 = addonTable.Menu.frame
local framesAfterFirstOpen = #Mocks.frames
check(frame1 ~= nil, "Menu: EnsureFrame crea el frame inicial")

addonTable.Menu.Open()
local frame2 = addonTable.Menu.frame
check(frame1 == frame2, "Menu: EnsureFrame devuelve siempre la misma instancia")
check(frame1.tabs and frame1.tabs.Plater and frame1.tabs.Wheel, "Menu: existen tabs Plater y Wheel")
check(frame1.activeTab == "Plater", "Menu: abre en Plater")
check(frame1.MinimizerMenuControls.plater.legend ~= nil, "Menu: legend pertenece a Plater")
check(frame1.MinimizerMenuControls.plater.divider ~= nil, "Menu: divider se crea en Menu.lua")

local platerTab = frame1.tabs.Plater
local wheelTab = frame1.tabs.Wheel
local platerLegend = frame1.MinimizerMenuControls.plater.legend
local wheelToggle = frame1.MinimizerMenuControls.wheel.wheelToggle
local sizeSlider = frame1.MinimizerMenuControls.wheel.sizeSlider
local radiusSlider = frame1.MinimizerMenuControls.wheel.radiusSlider
local dropdowns = frame1.MinimizerMenuControls.wheel.dropdowns

local wheelButton = frame1.tabs.Wheel.button
wheelButton:GetScript("OnClick")(wheelButton)
check(frame1.activeTab == "Wheel", "Menu: cambia a Wheel")

local beforeRefresh = #Mocks.frames
addonTable.Menu.Refresh()
addonTable.Menu.Refresh()
addonTable.Menu.Refresh()
check(#Mocks.frames == beforeRefresh, "Menu: Refresh no crea frames adicionales")
check(frame1.tabs.Plater == platerTab and frame1.tabs.Wheel == wheelTab, "Menu: Refresh conserva referencias de tabs")
check(frame1.MinimizerMenuControls.plater.legend == platerLegend, "Menu: Refresh conserva referencia de legend")
check(frame1.MinimizerMenuControls.wheel.wheelToggle == wheelToggle, "Menu: Refresh conserva referencia de Wheel toggle")
check(frame1.MinimizerMenuControls.wheel.sizeSlider == sizeSlider, "Menu: Refresh conserva referencia de size slider")
check(frame1.MinimizerMenuControls.wheel.radiusSlider == radiusSlider, "Menu: Refresh conserva referencia de radius slider")
check(frame1.MinimizerMenuControls.wheel.dropdowns == dropdowns, "Menu: Refresh conserva referencia de dropdowns")

local beforeOpenToggle = #Mocks.frames
addonTable.Menu.Open()
addonTable.Menu.Toggle()
addonTable.Menu.Toggle()
addonTable.Menu.Open()
check(#Mocks.frames == beforeOpenToggle, "Menu: Open/Toggle no crea UI adicional")
check(addonTable.Menu.frame == frame1, "Menu: Open/Toggle conserva la misma instancia")

local afterRepeatedCalls = #Mocks.frames
addonTable.Menu.Refresh()
check(#Mocks.frames == afterRepeatedCalls, "Menu: Refresh repetido es idempotente respecto a frames")
check(MinimizerDB.wheelSize == 240 and MinimizerDB.wheelPipRadius == 92 and MinimizerDB.wheelEnabled == true,
    "Menu: Refresh no modifica SavedVariables")

MinimizerCharDB.pip1 = 1719
addonTable.Config.Initialize()
check(MinimizerCharDB.pip1 == 1719 and MinimizerDB.wheelSize == 240, "Config: conserva override de Pip")

T.finish("MENU TESTS")
