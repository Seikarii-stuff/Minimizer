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

Mocks.CreateTestUnit("t_melee", { level = 70, classification = "rare", faction = "Horde", powerType = 1 })
check(addonTable.Classification.GetEliteType("t_melee") == "melee", "Classification: melee no normal = melee")

Mocks.CreateTestUnit("t_normal", { level = 70, classification = "normal", faction = "Horde", powerType = 1 })
check(addonTable.Classification.GetEliteType("t_normal") == "normal", "Classification: normal melee = normal")

Mocks.CreateTestUnit("t_normal_caster", { level = 70, classification = "normal", faction = "Horde", powerType = 0 })
check(addonTable.Classification.GetEliteType("t_normal_caster") == "caster", "Classification: normal con mana conserva caster")

check(addonTable.Constants.HealthColors.normal[1] == 1.00 and addonTable.Constants.HealthColors.normal[2] == 0.55 and addonTable.Constants.HealthColors.normal[3] == 0.00, "Color: normal usa naranja")

local npNormal = Mocks.CreateTestNameplate("t_normal_display")
Mocks.CreateTestUnit("t_normal_display", { level = 70, classification = "normal", faction = "Horde", powerType = 1 })
local snapNormal = addonTable.Snapshot.Build("t_normal_display", npNormal)
check(snapNormal.eliteType == "normal", "Snapshot: eliteType conserva normal")
check(snapNormal.displayKind == "normal", "Snapshot: displayKind = normal sin estados superiores")

local focusData = { level = 70, classification = "normal", faction = "Horde", powerType = 1, guid = "guid_t_normal_focus" }
Mocks.CreateTestUnit("t_normal_focus", focusData)
Mocks.CreateTestUnit("focus", focusData)
local npFocus = Mocks.CreateTestNameplate("t_normal_focus")
check(addonTable.Snapshot.ComputeDisplayKind("t_normal_focus", npFocus) == "focus", "Snapshot: focus sobre normal")

Mocks.unitClassificationCallCounts = {}
Mocks.CreateTestUnit("t_cache_gen", { level = 70, classification = "normal", faction = "Horde", powerType = 1 })
local before = Mocks.unitClassificationCallCounts.t_cache_gen or 0
addonTable.Classification.GetEliteType("t_cache_gen")
addonTable.Classification.GetEliteType("t_cache_gen")
local after = Mocks.unitClassificationCallCounts.t_cache_gen or 0
check(after - before == 1, "Classification: memoiza dentro de la misma generacion")

T.finish("CLASSIFICATION TESTS")
