local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

T.fireAddonLoaded()
Mocks.CreateTestUnit("player", { level = 70, faction = "Alliance", isPlayer = true, class = "WARRIOR" })

Mocks.CreateTestUnit("t_trivial", { level = 5, classification = "normal", faction = "Horde" })
check(addonTable.Classification.GetEliteType("t_trivial") == "trivial", "Classification: nivel muy bajo = trivial")

Mocks.CreateTestUnit("t_trivial2", { level = 70, classification = "trivial", faction = "Horde" })
check(addonTable.Classification.GetEliteType("t_trivial2") == "trivial", "Classification: clasificacion nativa trivial")

Mocks.CreateTestUnit("t_boss_skull", { level = -1, classification = "elite", faction = "Horde", isLieutenant = false })
check(addonTable.Classification.GetEliteType("t_boss_skull") == "boss", "Classification: elite skull = boss")

Mocks.CreateTestUnit("t_miniboss_lt", { level = 70, classification = "normal", faction = "Horde", isLieutenant = true })
check(addonTable.Classification.GetEliteType("t_miniboss_lt") == "miniboss", "Classification: lieutenant = miniboss")

Mocks.CreateTestUnit("t_caster", { level = 70, classification = "normal", faction = "Horde", powerType = 0 })
check(addonTable.Classification.GetEliteType("t_caster") == "caster", "Classification: mana = caster")

Mocks.CreateTestUnit("t_melee", { level = 70, classification = "normal", faction = "Horde", powerType = 1 })
check(addonTable.Classification.GetEliteType("t_melee") == "melee", "Classification: sin mana = melee")

Mocks.unitClassificationCallCounts = {}
Mocks.CreateTestUnit("t_cache_gen", { level = 70, classification = "normal", faction = "Horde", powerType = 1 })
local before = Mocks.unitClassificationCallCounts.t_cache_gen or 0
addonTable.Classification.GetEliteType("t_cache_gen")
addonTable.Classification.GetEliteType("t_cache_gen")
local after = Mocks.unitClassificationCallCounts.t_cache_gen or 0
check(after - before == 1, "Classification: memoiza dentro de la misma generacion")

T.finish("CLASSIFICATION TESTS")
