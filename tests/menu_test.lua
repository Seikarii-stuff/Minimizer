local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

MinimizerDB = { simplifyEnabled = true, enableMouseHalo = true }
MinimizerCharDB = {}
T.fireAddonLoaded()

addonTable.Menu.Open()
local frame = addonTable.Menu.frame
check(frame ~= nil, "Menu: crea el frame")
check(frame.tabs and frame.tabs.Plater and frame.tabs.Wheel == nil, "Menu: solo mantiene la tab Plater")
check(frame.activeTab == "Plater", "Menu: abre en Plater")
check(frame.MinimizerMenuControls.plater.legend ~= nil, "Menu: conserva la leyenda")
check(frame.MinimizerMenuControls.plater.mouseHaloToggle ~= nil, "Menu: conserva el toggle Mouse Halo")

local beforeRefresh = #Mocks.frames
addonTable.Menu.Refresh()
addonTable.Menu.Refresh()
check(#Mocks.frames == beforeRefresh, "Menu: Refresh es idempotente")
check(addonTable.Menu.frame == frame, "Menu: conserva la instancia")

T.finish("MENU TESTS")
