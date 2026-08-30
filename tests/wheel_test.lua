local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

MinimizerDB = {
    wheelEnabled = false,
    wheelSize = 220,
    wheelPipRadius = 88,
}
MinimizerCharDB = {}
T.fireAddonLoaded()

check(MinimizerDB.wheelEnabled == false, "Lifecycle: SavedVariables se conservan")
check(addonTable.Wheel._enabled == false, "Lifecycle: ADDON_LOADED aplica Wheel con enabled=false")
check(addonTable.Wheel._size == 220, "Lifecycle: ADDON_LOADED aplica size")
check(addonTable.Wheel._pipRadius == 88, "Lifecycle: ADDON_LOADED aplica radius")
check(_G.MinimizerPlayerWheel:IsShown() == false, "Wheel: disabled oculta la Wheel")
check(_G.MinimizerPlayerWheel.MinimizerWheelInterrupt:IsShown() == false, "Wheel: disabled oculta interrupt")

MinimizerDB.wheelEnabled = true
addonTable.Wheel:ApplyConfig()
check(addonTable.Wheel._enabled == true and _G.MinimizerPlayerWheel:IsShown() == true, "Wheel: ApplyConfig activa la Wheel")

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
check(setSizeCalls == 0 and setRadiusCalls == 0, "Wheel: ApplyConfig con mismos valores hace early-out")
MinimizerDB.wheelSize = 240
MinimizerDB.wheelPipRadius = 92
addonTable.Wheel:ApplyConfig()
check(setSizeCalls == 1, "Wheel: cambio de size llama SetSize una vez")
check(setRadiusCalls == 1, "Wheel: cambio de radius llama SetPipRadius una vez")
addonTable.Wheel:ApplyConfig()
check(setSizeCalls == 1 and setRadiusCalls == 1, "Wheel: repetir ApplyConfig no repite operaciones")

local framesBeforeUpdates = #Mocks.frames
addonTable.Wheel:Update()
addonTable.Wheel:Update()
check(#Mocks.frames == framesBeforeUpdates, "Wheel: Update no crea frames")

-- Disabled Wheel must be a true hot-path early-out.
MinimizerDB.wheelEnabled = false
addonTable.Wheel:ApplyConfig()
local updateCalls = 0
local originalUpdate = addonTable.Wheel.Update
addonTable.Wheel.Update = function(self)
    updateCalls = updateCalls + 1
    return originalUpdate(self)
end
addonTable.Wheel:OnCooldownTick()
check(updateCalls == 0, "Wheel: OnCooldownTick hace early-out cuando disabled")

-- Hot path: SPELL_UPDATE_COOLDOWN reaches Overlays -> Wheel -> throttle -> Update.
MinimizerDB.wheelEnabled = true
addonTable.Wheel:ApplyConfig()
updateCalls = 0
Mocks.AdvanceTime(0.034)
Mocks.FireEvent("SPELL_UPDATE_COOLDOWN")
check(updateCalls == 1, "Wheel hot path: SPELL_UPDATE_COOLDOWN llega a Wheel:Update")
Mocks.FireEvent("SPELL_UPDATE_COOLDOWN")
check(updateCalls == 1, "Wheel hot path: llamadas consecutivas quedan throttleadas")
Mocks.AdvanceTime(0.034)
check(updateCalls == 2, "Wheel hot path: throttle permite la siguiente actualizacion tras el intervalo")

-- Persistent Pips are created once and reused by Update/config changes.
local wheelPips = _G.MinimizerPlayerWheel._children
check(type(wheelPips) == "table" and #wheelPips >= 6, "Wheel: conserva la coleccion persistente de Pips")
local framesBeforeFinalUpdates = #Mocks.frames
addonTable.Wheel:Update()
addonTable.Wheel:OnCooldownTick()
addonTable.Wheel:ApplyConfig()
check(#Mocks.frames == framesBeforeFinalUpdates, "Wheel: hot path y ApplyConfig no crean frames adicionales")
check(addonTable.Overlays.Get("Wheel") == addonTable.Wheel, "Wheel: registrada en Overlays")

T.finish("WHEEL TESTS")
