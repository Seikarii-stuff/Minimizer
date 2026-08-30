local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

T.fireAddonLoaded()

Mocks.CreateTestUnit("c_unit", {
    level = 70, faction = "Horde",
    cast = { name = "Test", startTime = 0, endTime = 2000, uninterruptible = false },
})
check(addonTable.Cast.GetState("c_unit") == true, "Cast: detecta casting activo")
Mocks.units.c_unit.cast = nil
check(addonTable.Cast.GetState("c_unit") == false, "Cast: lectura fresca refleja el estado real cambiado")
addonTable.Cast.InvalidateState("c_unit")
check(addonTable.Cast.GetState("c_unit") == false, "Cast: InvalidateState conserva la lectura fresca")

local token = "nameplate73"
Mocks.CreateTestUnit(token, {
    level = 70, classification = "normal", faction = "Horde", powerType = 1,
    cast = { name = "Reuse Check", startTime = 0, endTime = 2000, uninterruptible = false },
})
Mocks.CreateTestNameplate(token)
Mocks.unitCastingInfoCallCounts[token] = 0
Mocks.unitChannelInfoCallCounts[token] = 0
addonTable.Dispatcher.ApplyToUnit(token)
check(Mocks.unitCastingInfoCallCounts[token] == 1, "CastingBar: UnitCastingInfo se llama una vez por ApplyToUnit")
check(Mocks.unitChannelInfoCallCounts[token] == 1, "CastingBar: UnitChannelInfo se llama una vez por ApplyToUnit")

local castBar = Mocks.nameplates[token].UnitFrame.castBar
local r, g, b = castBar:GetStatusBarColor()
check(math.abs(r - addonTable.Constants.CastColors.ready[1]) < 0.01 and
      math.abs(g - addonTable.Constants.CastColors.ready[2]) < 0.01 and
      math.abs(b - addonTable.Constants.CastColors.ready[3]) < 0.01,
      "CastingBar: conserva el color correcto usando el snapshot")

T.finish("CAST TESTS")
