local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

T.fireAddonLoaded()
MinimizerDB.simplifyEnabled = true

Mocks.CreateTestUnit("d_friendly", { level = 70, classification = "normal", faction = "Alliance" })
local simplify, reason = addonTable.Decision.ShouldSimplifyUnit("d_friendly", nil)
check(simplify == false and reason == "friendly", "Decision: unidad amiga nunca se simplifica")

Mocks.CreateTestUnit("d_boss", { level = -1, classification = "elite", faction = "Horde" })
simplify, reason = addonTable.Decision.ShouldSimplifyUnit("d_boss", nil)
check(simplify == false and reason == "no simp", "Decision: boss nunca se simplifica")

Mocks.CreateTestUnit("d_cast_uninterr", {
    level = 70, classification = "normal", faction = "Horde",
    cast = { name = "Test", startTime = 0, endTime = 2000, uninterruptible = true },
})
simplify, reason = addonTable.Decision.ShouldSimplifyUnit("d_cast_uninterr", nil)
check(simplify == false and reason == "temporal", "Decision: cast ininterrumpible inferior = temporal")

Mocks.CreateTestUnit("d_cast_interr", {
    level = 70, classification = "normal", faction = "Horde",
    cast = { name = "Test", startTime = 0, endTime = 2000, uninterruptible = false },
})
simplify, reason = addonTable.Decision.ShouldSimplifyUnit("d_cast_interr", nil)
check(simplify == false and reason == "no simp", "Decision: cast interrumpible inferior = no simp persistente")

Mocks.CreateTestUnit("d_channel_uninterr", {
    level = 70, classification = "normal", faction = "Horde",
    channel = { name = "Drain", startTime = 0, endTime = 2000, uninterruptible = true },
})
simplify, reason = addonTable.Decision.ShouldSimplifyUnit("d_channel_uninterr", nil)
check(simplify == false and reason == "temporal", "Decision: channel ininterrumpible inferior = temporal")

Mocks.CreateTestUnit("d_aggro", { level = 70, classification = "normal", faction = "Horde", threatSituation = 3 })
simplify, reason = addonTable.Decision.ShouldSimplifyUnit("d_aggro", nil)
check(simplify == false and reason == "temporal", "Decision: con aggro del jugador = temporal")

Mocks.CreateTestUnit("d_normal", { level = 70, classification = "normal", faction = "Horde" })
simplify, reason = addonTable.Decision.ShouldSimplifyUnit("d_normal", nil)
check(simplify == true and reason == "simplify", "Decision: unidad normal se simplifica")

MinimizerDB.simplifyEnabled = false
simplify, reason = addonTable.Decision.ShouldSimplifyUnit("d_normal", nil)
check(simplify == false and reason == "disabled", "Decision: simplificacion desactivada")

T.finish("DECISION TESTS")
