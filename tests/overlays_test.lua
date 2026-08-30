local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

T.fireAddonLoaded()
MinimizerDB.simplifyEnabled = true

Mocks.CreateTestUnit("player", { name = "Player", level = 70, faction = "Alliance", isPlayer = true, class = "WARRIOR", guid = "player_guid" })

-- Friendly units must not be painted or hooked.
local friendly = "friendly_unit1"
Mocks.CreateTestUnit(friendly, {
    name = "Friendly NPC", level = 10, faction = "Alliance", classification = "normal",
    cast = { name = "VendorFlavor", startTime = 0, endTime = 2000, uninterruptible = false },
})
local friendlyNP = Mocks.CreateTestNameplate(friendly)
addonTable.Dispatcher.ApplyToUnit(friendly)
local friendlyHB = addonTable.Utils.GetHealthBar(friendlyNP)
check(friendlyHB.MinimizerHealthColorHooked ~= true, "Friendly: HealthBar no queda hookeada")
local r, g, b = friendlyHB:GetStatusBarColor()
check(math.abs(r - 1) < 0.01 and math.abs(g - 1) < 0.01 and math.abs(b - 1) < 0.01, "Friendly: HealthBar conserva color default")
check(friendlyNP.UnitFrame.castBar.MinimizerLastCastColor == nil, "Friendly: CastingBar no es pintada")
local _, reason = addonTable.Decision.ShouldSimplifyUnit(friendly, nil)
check(reason == "friendly", "Friendly: Decision devuelve reason friendly")

-- HealthBarColor legend: persistent interruptible cast, temporary uninterruptible cast, superior unchanged.
Mocks.CreateTestUnit("nameplate10", {
    level = 70, classification = "normal", faction = "Horde", powerType = 1,
    cast = { name = "Melee Spell", startTime = 0, endTime = 2000, uninterruptible = false },
})
local npMelee = Mocks.CreateTestNameplate("nameplate10")
addonTable.Cast.InvalidateState("nameplate10")
addonTable.Dispatcher.ApplyToUnit("nameplate10")
local hbMelee = addonTable.Utils.GetHealthBar(npMelee)
r, g, b = hbMelee:GetStatusBarColor()
check(math.abs(r - 0.10) < 0.01 and math.abs(g - 1) < 0.01 and math.abs(b - 0.10) < 0.01, "HealthBarColor: melee interruptible = verde")
Mocks.units.nameplate10.cast = nil
addonTable.Cast.InvalidateState("nameplate10")
addonTable.Dispatcher.ApplyToUnit("nameplate10")
r, g, b = hbMelee:GetStatusBarColor()
check(math.abs(r - 0.10) < 0.01 and math.abs(g - 1) < 0.01 and math.abs(b - 0.10) < 0.01, "HealthBarColor: verde persiste tras el cast")

Mocks.CreateTestUnit("nameplate13", {
    level = 70, classification = "normal", faction = "Horde", powerType = 0,
    cast = { name = "Caster Frostbolt", startTime = 0, endTime = 2500, uninterruptible = false },
})
local npCaster = Mocks.CreateTestNameplate("nameplate13")
addonTable.Cast.InvalidateState("nameplate13")
addonTable.Dispatcher.ApplyToUnit("nameplate13")
local hbCaster = addonTable.Utils.GetHealthBar(npCaster)
r, g, b = hbCaster:GetStatusBarColor()
check(math.abs(r - 0.20) < 0.01 and math.abs(g - 0.55) < 0.01 and math.abs(b - 1) < 0.01, "HealthBarColor: caster azul no cambia por cast interruptible")
Mocks.units.nameplate13.cast = nil
addonTable.Cast.InvalidateState("nameplate13")
addonTable.Dispatcher.ApplyToUnit("nameplate13")
r, g, b = hbCaster:GetStatusBarColor()
check(math.abs(r - 0.20) < 0.01 and math.abs(g - 0.55) < 0.01 and math.abs(b - 1) < 0.01, "HealthBarColor: caster azul conserva color tras cast")

Mocks.CreateTestUnit("nameplate14", {
    level = 70, classification = "normal", faction = "Horde", powerType = 1,
    cast = { name = "Unint Spell", startTime = 0, endTime = 2000, uninterruptible = true },
})
local npUnint = Mocks.CreateTestNameplate("nameplate14")
addonTable.Cast.InvalidateState("nameplate14")
addonTable.Dispatcher.ApplyToUnit("nameplate14")
local hbUnint = addonTable.Utils.GetHealthBar(npUnint)
r, g, b = hbUnint:GetStatusBarColor()
check(math.abs(r - 0.50) < 0.01 and math.abs(g - 0.50) < 0.01 and math.abs(b - 0.50) < 0.01, "HealthBarColor: melee uninterruptible = gris")

Mocks.CreateTestUnit("nameplate140", {
    level = 70, classification = "normal", faction = "Horde", powerType = 1,
    channel = { name = "Unint Channel", startTime = 0, endTime = 2000, uninterruptible = true },
})
local npChannel = Mocks.CreateTestNameplate("nameplate140")
addonTable.Cast.InvalidateState("nameplate140")
addonTable.Dispatcher.ApplyToUnit("nameplate140")
r, g, b = addonTable.Utils.GetHealthBar(npChannel):GetStatusBarColor()
check(math.abs(r - 0.50) < 0.01 and math.abs(g - 0.50) < 0.01 and math.abs(b - 0.50) < 0.01, "HealthBarColor: channel uninterruptible = gris")

Mocks.units.nameplate14.cast = nil
addonTable.Cast.InvalidateState("nameplate14")
addonTable.Dispatcher.ApplyToUnit("nameplate14")
r, g, b = hbUnint:GetStatusBarColor()
check(math.abs(r - 0.50) < 0.01 and math.abs(g - 0.50) < 0.01 and math.abs(b - 0.50) < 0.01, "HealthBarColor: gris persiste tras cast uninterruptible")

Mocks.CreateTestUnit("nameplate11", {
    level = -1, classification = "elite", faction = "Horde",
    cast = { name = "Boss MegaCast", startTime = 0, endTime = 2000, uninterruptible = true },
})
local npBossUnint = Mocks.CreateTestNameplate("nameplate11")
addonTable.Cast.InvalidateState("nameplate11")
addonTable.Dispatcher.ApplyToUnit("nameplate11")
local bossHB = addonTable.Utils.GetHealthBar(npBossUnint)
r, g, b = bossHB:GetStatusBarColor()
local boss = addonTable.Constants.HealthColors.boss
check(math.abs(r - boss[1]) < 0.01 and math.abs(g - boss[2]) < 0.01 and math.abs(b - boss[3]) < 0.01, "HealthBarColor: boss uninterruptible = morado")

Mocks.CreateTestUnit("nameplate12", {
    level = -1, classification = "elite", faction = "Horde",
    cast = { name = "Boss NormalCast", startTime = 0, endTime = 2000, uninterruptible = false },
})
local npBossInt = Mocks.CreateTestNameplate("nameplate12")
addonTable.Cast.InvalidateState("nameplate12")
addonTable.Dispatcher.ApplyToUnit("nameplate12")
r, g, b = addonTable.Utils.GetHealthBar(npBossInt):GetStatusBarColor()
check(math.abs(r - boss[1]) < 0.01 and math.abs(g - boss[2]) < 0.01 and math.abs(b - boss[3]) < 0.01, "HealthBarColor: boss interruptible = morado")

-- Priority: focus, aggro and absorb beat superior/boss coloring.
local token = "nameplate50"
Mocks.CreateTestUnit(token, { level = -1, classification = "elite", faction = "Horde" })
local bossGuid = Mocks.units[token].guid
Mocks.CreateTestUnit("focus", { guid = bossGuid, name = "Focus Boss" })
local np = Mocks.CreateTestNameplate(token)
addonTable.Dispatcher.ApplyToUnit(token)
r, g, b = addonTable.Utils.GetHealthBar(np):GetStatusBarColor()
local focusColor = addonTable.Constants.HealthColors.focus
check(math.abs(r - focusColor[1]) < 0.01 and math.abs(g - focusColor[2]) < 0.01 and math.abs(b - focusColor[3]) < 0.01, "Priority: focus gana a boss")
check(not (math.abs(r - boss[1]) < 0.01 and math.abs(g - boss[2]) < 0.01 and math.abs(b - boss[3]) < 0.01), "Priority: focus no queda morado")

Mocks.CreateTestUnit("nameplate51", { level = -1, classification = "elite", faction = "Horde", threatSituation = 3 })
local npAggro = Mocks.CreateTestNameplate("nameplate51")
addonTable.Dispatcher.ApplyToUnit("nameplate51")
r, g, b = addonTable.Utils.GetHealthBar(npAggro):GetStatusBarColor()
local aggro = addonTable.Constants.HealthColors.aggro
check(math.abs(r - aggro[1]) < 0.01 and math.abs(g - aggro[2]) < 0.01 and math.abs(b - aggro[3]) < 0.01, "Priority: aggro gana a boss")
check(not (math.abs(r - boss[1]) < 0.01 and math.abs(g - boss[2]) < 0.01 and math.abs(b - boss[3]) < 0.01), "Priority: aggro no queda morado")

Mocks.CreateTestUnit("nameplate52", { level = -1, classification = "elite", faction = "Horde" })
local npAbsorb = Mocks.CreateTestNameplate("nameplate52")
npAbsorb.UnitFrame.healthBar.totalAbsorbOverlay = CreateFrame("Frame")
npAbsorb.UnitFrame.healthBar.totalAbsorbOverlay:Show()
addonTable.Dispatcher.ApplyToUnit("nameplate52")
r, g, b = addonTable.Utils.GetHealthBar(npAbsorb):GetStatusBarColor()
local absorb = addonTable.Constants.HealthColors.absorb
check(math.abs(r - absorb[1]) < 0.01 and math.abs(g - absorb[2]) < 0.01 and math.abs(b - absorb[3]) < 0.01, "Priority: absorb gana a boss")
check(not (math.abs(r - boss[1]) < 0.01 and math.abs(g - boss[2]) < 0.01 and math.abs(b - boss[3]) < 0.01), "Priority: absorb no queda morado")

-- Secrets: preserve the old persistence assertions for both secret channel and cast paths.
local secretToken = "nameplate23"
Mocks.CreateTestUnit(secretToken, {
    level = 70, classification = "normal", faction = "Horde", powerType = 1,
    channel = { name = "Secret Channel", startTime = 0, endTime = 2000, uninterruptible = Mocks.Secret(true) },
})
local secretNP = Mocks.CreateTestNameplate(secretToken)
addonTable.Cast.InvalidateState(secretToken)
addonTable.Dispatcher.ApplyToUnit(secretToken)
r, g, b = addonTable.Utils.GetHealthBar(secretNP):GetStatusBarColor()
local grey = addonTable.Constants.HealthColors.superiorUninterruptible
check(math.abs(r - grey[1]) < 0.01 and math.abs(g - grey[2]) < 0.01 and math.abs(b - grey[3]) < 0.01, "Secrets: channel secreto ininterruptible pinta gris")
local persistent = secretNP.MinimizerPersistentCastColor
check(persistent ~= nil and math.abs(persistent[1] - grey[1]) < 0.01 and math.abs(persistent[2] - grey[2]) < 0.01 and math.abs(persistent[3] - grey[3]) < 0.01, "Secrets: channel secreto fija persistencia de color")
Mocks.units[secretToken].channel = nil
addonTable.Cast.InvalidateState(secretToken)
addonTable.Dispatcher.ApplyToUnit(secretToken)
r, g, b = addonTable.Utils.GetHealthBar(secretNP):GetStatusBarColor()
check(secretNP.MinimizerPersistentCastColor ~= nil and math.abs(r - grey[1]) < 0.01 and math.abs(g - grey[2]) < 0.01 and math.abs(b - grey[3]) < 0.01, "Secrets: gris persiste tras terminar channel")

local secretCast = "nameplate24"
Mocks.CreateTestUnit(secretCast, {
    level = 70, classification = "normal", faction = "Horde", powerType = 1,
    cast = { name = "Secret Cast", startTime = 0, endTime = 2000, uninterruptible = Mocks.Secret(false) },
})
local secretCastNP = Mocks.CreateTestNameplate(secretCast)
addonTable.Dispatcher.ApplyToUnit(secretCast)
r, g, b = addonTable.Utils.GetHealthBar(secretCastNP):GetStatusBarColor()
local green = addonTable.Constants.HealthColors.castInterruptible
check(math.abs(r - green[1]) < 0.01 and math.abs(g - green[2]) < 0.01 and math.abs(b - green[3]) < 0.01, "Secrets: cast secreto interruptible pinta verde")
persistent = secretCastNP.MinimizerPersistentCastColor
check(persistent ~= nil and math.abs(persistent[1] - green[1]) < 0.01 and math.abs(persistent[2] - green[2]) < 0.01 and math.abs(persistent[3] - green[3]) < 0.01, "Secrets: cast secreto fija persistencia de color")
Mocks.units[secretCast].cast = nil
addonTable.Cast.InvalidateState(secretCast)
addonTable.Dispatcher.ApplyToUnit(secretCast)
check(secretCastNP.MinimizerPersistentCastColor ~= nil, "Secrets: verde persiste tras terminar cast")

-- Dispatcher ownership and ActiveNameplates integration.
local a, bUnit = "nameplate80", "nameplate81"
Mocks.CreateTestUnit(a, { level = 70, classification = "normal", faction = "Horde" })
Mocks.CreateTestNameplate(a)
Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", a)
Mocks.CreateTestUnit(bUnit, { level = 70, classification = "normal", faction = "Horde" })
Mocks.CreateTestNameplate(bUnit)
Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", bUnit)
check(addonTable.ActiveNameplates[a] ~= nil and addonTable.ActiveNameplates[bUnit] ~= nil, "Dispatcher: ActiveNameplates registra ambas unidades")
check(pcall(addonTable.Dispatcher.ApplyToAll, true), "Dispatcher: ApplyToAll no falla")
check(addonTable.Utils.GetHealthBar(Mocks.nameplates[a]).MinimizerHealthColorHooked == true and addonTable.Utils.GetHealthBar(Mocks.nameplates[bUnit]).MinimizerHealthColorHooked == true, "Dispatcher: ApplyToAll procesa ambas nameplates")
NamePlateDriverFrame:OnNamePlateRemoved(a)
check(addonTable.ActiveNameplates[a] == nil, "Dispatcher: remover una unidad limpia su registro")
check(addonTable.ActiveNameplates[bUnit] ~= nil, "Dispatcher: remover una unidad no afecta a las demas")
check(pcall(addonTable.Dispatcher.ApplyToAll, true), "Dispatcher: ApplyToAll sigue funcionando tras remover")

T.finish("OVERLAYS TESTS")
