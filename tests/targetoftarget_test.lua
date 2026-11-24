local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

T.fireAddonLoaded()

Mocks.CreateTestUnit("target", { name = "Target Mob", faction = "Horde", guid = "target_guid" })
Mocks.CreateTestUnit("targettarget", { name = "Target of Target", faction = "Horde", guid = "tot_guid" })
local plate = Mocks.CreateTestNameplate("target")

addonTable.TargetOfTarget:UpdatePortrait()
local portrait = _G.MinimizerTargetOfTargetPortrait
check(portrait ~= nil and portrait:IsShown() == true, "TargetOfTarget: muestra retrato 36x36 sobre el target")
check(portrait:GetWidth() == 36 and portrait:GetHeight() == 36, "TargetOfTarget: usa las mismas dimensiones que focus")
check(portrait:GetParent() == plate, "TargetOfTarget: ancla el retrato a la nameplate del target actual")
check(portrait:GetFrameLevel() == (plate:GetFrameLevel() or 0) + 2, "TargetOfTarget: queda por encima del retrato de focus")
check(addonTable.Overlays.Get("TargetOfTarget") == addonTable.TargetOfTarget, "TargetOfTarget: esta registrado en Overlays")

Mocks.CreateTestUnit("focus", { name = "Shared Mob", faction = "Horde", guid = "tot_guid" })
addonTable.TargetOfTarget:UpdatePortrait()
check(portrait:IsShown() == true, "TargetOfTarget: permanece visible con targettarget y focus sin depender de comparaciones")

Mocks.units.focus = nil
addonTable.TargetOfTarget:UpdatePortrait()
check(portrait:IsShown() == true, "TargetOfTarget: sigue visible sin focus")

Mocks.units.targettarget = nil
addonTable.TargetOfTarget:UpdatePortrait()
check(portrait:IsShown() == false, "TargetOfTarget: se oculta sin targettarget")

local source = assert(io.open("Overlays/TargetOfTarget.lua", "r")):read("*a")
check(source:match('GetNamePlateForUnit%s*%(%s*["\']target["\']'), "TargetOfTarget: resuelve la nameplate del target permitido")
check(not source:match('GetNamePlateForUnit%s*%(%s*["\']targettarget'), "TargetOfTarget: no usa targettarget en GetNamePlateForUnit")
check(source:match('SetPortraitTexture%s*%(%s*portrait%s*,%s*["\']targettarget["\']'), "TargetOfTarget: dibuja el retrato de targettarget")
check(not source:match("UnitIsUnit"), "TargetOfTarget: no compara unidades secretas")
check(not source:match("UnitIsDead"), "TargetOfTarget: no prueba estados muertos secretos")

T.finish("TARGET OF TARGET TESTS")
