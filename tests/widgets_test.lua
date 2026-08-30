local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

T.fireAddonLoaded()

local halo = addonTable.Widgets.CreateHalo("TestTargetHalo", nil, 46)
Mocks.cooldowns[107574] = { start = Mocks.time, duration = 30 }
local ok = addonTable.Widgets.UpdateHalo(halo, 107574)
check(ok == true, "Widgets: UpdateHalo acepta un cooldown real")
check(halo:IsShown() == true, "Widgets: halo se muestra con spell activo")
local alpha = halo.MinimizerHaloTexture:GetAlpha()
check(alpha > 0 and alpha <= 1, "Widgets: alpha del halo refleja progreso")

local portraitCooldown = CreateFrame("Cooldown", "TestPortraitCooldown", nil, "CooldownFrameTemplate")
addonTable.Widgets.MakeCooldownCircular(portraitCooldown, true)
check(portraitCooldown:GetHideCountdownNumbers() == false, "Widgets: portrait conserva numeros cuando se solicita")

Mocks.cooldowns[107574] = nil
check(addonTable.Widgets.UpdateHalo(halo, nil) == false, "Widgets: halo sin spell se oculta")

check(type(addonTable.Overlays.OnCooldownTick) == "function", "Overlays: dispatcher de cooldown existe")
check(type(addonTable.Overlays.OnUnitChanged) == "function", "Overlays: dispatcher de cambios de unidad existe")

T.finish("WIDGETS TESTS")
