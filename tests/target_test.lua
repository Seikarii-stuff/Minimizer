local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

Mocks.playerSpells = { [107574] = true, [147362] = true }
Mocks.cooldowns[147362] = { start = Mocks.time, duration = 15 }
T.fireAddonLoaded()
if addonTable.Interrupt and addonTable.Interrupt.InvalidateSpellIDCache then
    addonTable.Interrupt.InvalidateSpellIDCache()
end

Mocks.CreateTestUnit("target", { name = "Target Mob", level = 70, faction = "Horde", guid = "target_guid" })
local plate = Mocks.CreateTestNameplate("target")
local healthBar = addonTable.Utils.GetHealthBar(plate)
local framesBeforeStripes = #Mocks.frames
local colorBefore = { healthBar:GetStatusBarColor() }
addonTable.Target:UpdateTargetCDs()

local halo = _G.MinimizerTargetHalo
local countdown = _G.MinimizerTargetInterruptCountdown
local stripes = healthBar.MinimizerTargetStripedOverlay
local stripeTexture = stripes and stripes.MinimizerTexture
check(halo ~= nil and halo:IsShown() == true, "Target: muestra halo cuando el target tiene interrupt")
check(type(addonTable.Halo) == "table" and halo ~= nil, "Target: usa el componente Halo compartido")
check(countdown ~= nil and countdown:IsShown() == true, "Target: muestra cooldown del interrupt")
check(stripes ~= nil and stripes:IsShown() == true, "Target: muestra rayas sobre la healthbar del target")
check(stripes and stripes:GetParent() == healthBar, "Target: rayas ancladas a la healthbar correcta")
check(stripeTexture ~= nil and stripeTexture.MinimizerTexturePath == "Interface\\AddOns\\Minimizer\\assets\\striped_pattern", "Target: rayas usan striped_pattern.tga")
check(stripeTexture and stripeTexture.MinimizerDrawLayer == "OVERLAY", "Target: rayas usan draw layer OVERLAY")
check(stripes and stripes.MinimizerFrameLevel == (healthBar:GetFrameLevel() or 0) + 2, "Target: rayas quedan por encima de la healthbar")
check(#Mocks.frames == framesBeforeStripes + 1, "Target: crea el contenedor visual de rayas una sola vez")
check(stripes and stripes.MinimizerTexture == stripeTexture, "Target: conserva la textura creada en el contenedor")
check(colorBefore[1] == healthBar:GetStatusBarColor(), "Target: no sustituye el color de la healthbar")

local targetSource = assert(io.open("Overlays/Target.lua", "r")):read("*a")
check(targetSource:match("Minimizer%.Halo%.Create"), "Target: crea el Halo mediante Minimizer.Halo")
check(targetSource:match("haloFrame:SetHost%(%s*plate%s*%)"), "Target: proporciona la plate como contexto")
check(not targetSource:match("SetFrameStrata%s*%(%s*[\"']HIGH[\"']"), "Target: no fuerza HIGH")

addonTable.Target:UpdateTargetCDs()
check(healthBar.MinimizerTargetStripedOverlay == stripes and stripes:IsShown() == true, "Target: reutiliza las rayas en actualizaciones posteriores")
check(#Mocks.frames == framesBeforeStripes + 1, "Target: no crea objetos visuales en actualizaciones posteriores")

Mocks.units.target = nil
addonTable.Target:UpdateTargetCDs()
check(stripes:IsShown() == false and halo:IsShown() == false and countdown:IsShown() == false, "Target: oculta indicadores cuando target deja de existir")
check(halo.MinimizerHaloHost == nil, "Target: recycling devuelve Halo al host neutral")

Mocks.nameplates.target = nil
Mocks.CreateTestUnit("nameplate_recycled", { name = "Recycled Mob", level = 70, faction = "Horde", guid = "recycled_guid" })
plate.namePlateUnitToken = "nameplate_recycled"
Mocks.nameplates.nameplate_recycled = plate
addonTable.Target:OnUnitChanged("target", "removed")
check(stripes:IsShown() == false, "Target: una nameplate reciclada no conserva rayas del target anterior")

Mocks.CreateTestUnit("target", { name = "New Target", level = 70, faction = "Horde", guid = "new_target_guid" })
Mocks.nameplates.nameplate_recycled = nil
plate.namePlateUnitToken = "target"
Mocks.nameplates.target = plate
addonTable.Target:OnUnitChanged("target", "target")
check(healthBar.MinimizerTargetStripedOverlay == stripes and stripes:IsShown() == true, "Target: muestra rayas para el nuevo target tras recycling")
check(#Mocks.frames == framesBeforeStripes + 1, "Target: recycling no crea un segundo contenedor visual")
check(halo.MinimizerHaloHost == plate, "Target: Halo recupera el contexto de la nueva plate")

check(addonTable.Target.Pips == nil, "Target: no posee ni consume una coleccion de Pips")
check(addonTable.Overlays.Get("Target") == addonTable.Target, "Target: esta registrado en Overlays")

T.finish("TARGET TESTS")
