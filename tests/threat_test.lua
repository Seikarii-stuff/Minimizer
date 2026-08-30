local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

T.fireAddonLoaded()
Mocks.CreateTestUnit("player", { name = "Player", level = 70, faction = "Alliance", isPlayer = true, role = "DAMAGER" })

Mocks.CreateTestUnit("th_aggro", { level = 70, faction = "Horde", threatSituation = 3 })
check(addonTable.Threat.PlayerHasAggro("th_aggro") == true, "Threat: situacion 3 = aggro")

Mocks.CreateTestUnit("th_noaggro", { level = 70, faction = "Horde", threatSituation = 1 })
check(addonTable.Threat.PlayerHasAggro("th_noaggro") == false, "Threat: situacion 1 = sin aggro")

Mocks.CreateTestUnit("th_zero", { level = 70, faction = "Horde", threatSituation = 0 })
check(addonTable.Threat.PlayerHasAggro("th_zero") == false, "Threat: situacion 0 no es aggro")

Mocks.units.player.role = "TANK"
local realRefresh = addonTable.Threat.RefreshPlayerTankCache
local refreshCalls = 0
addonTable.Threat.RefreshPlayerTankCache = function()
    refreshCalls = refreshCalls + 1
    return realRefresh()
end
addonTable.Threat.InvalidatePlayerTankCache()
check(addonTable.Threat.IsPlayerTank() == true, "Threat: detecta y cachea el rol tank")
check(addonTable.Threat.IsPlayerTank() == true, "Threat: no vuelve a consultar en la misma generacion")
check(refreshCalls == 1, "Threat: evaluacion de tank memoizada")
Mocks.units.player.role = "DAMAGER"
addonTable.Threat.InvalidatePlayerTankCache()
addonTable.Threat.RefreshPlayerTankCache = realRefresh

T.finish("THREAT TESTS")
