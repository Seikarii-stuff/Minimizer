local T = dofile("tests/test_harness.lua")
local Mocks, addonTable, check = T.Mocks, T.addonTable, T.check

T.fireAddonLoaded()

-- Core registration invariants.
local moduleCount = 0
for _ in pairs(addonTable.Modules) do moduleCount = moduleCount + 1 end
check(moduleCount == #addonTable.ModuleList, "Core: ModuleList y Modules tienen el mismo numero de entradas")
local seen = {}
for _, module in ipairs(addonTable.ModuleList) do seen[module.MinimizerModuleName] = true end
local allFound = true
for name in pairs(addonTable.Modules) do if not seen[name] then allFound = false end end
check(allFound, "Core: todo modulo registrado aparece en ModuleList")

-- Config migrations
MinimizerDB = { version = 1, focusIndicator = "face", simplifyPercent = 25 }
addonTable.Config.Initialize()
check(MinimizerDB.enableFocusFace == true and MinimizerDB.enableFocusArrows == false, "Config: migra focusIndicator=face")
check(MinimizerDB.focusIndicator == nil, "Config: elimina focusIndicator legacy")

MinimizerDB = { version = 1, focusIndicator = "arrows" }
MinimizerCharDB = { focusCC = 118000, targetDefensive = 871, targetOffensive = 107574 }
addonTable.Config.Initialize()
check(MinimizerDB.enableFocusFace == false and MinimizerDB.enableFocusArrows == true, "Config: migra focusIndicator=arrows")
check(MinimizerCharDB.pip1 == 871 and MinimizerCharDB.targetDefensive == nil, "Config: targetDefensive migra a pip1")
check(MinimizerCharDB.pip2 == 118000 and MinimizerCharDB.focusCC == nil, "Config: focusCC migra a pip2")
check(MinimizerCharDB.targetOffensive == nil, "Config: elimina targetOffensive legacy")

MinimizerDB = nil
check(addonTable.Config.IsSimplifyEnabled() == true, "Config: DB nil conserva compatibilidad")
MinimizerDB = { simplifyPercent = "0" }
check(addonTable.Config.IsSimplifyEnabled() == false, "Config: simplifyPercent=0 desactiva")
MinimizerDB = { simplifyPercent = "25" }
check(addonTable.Config.IsSimplifyEnabled() == true, "Config: simplifyPercent positivo activa")
MinimizerDB = { simplifyEnabled = false }
check(addonTable.Config.IsSimplifyEnabled() == false, "Config: boolean moderno prevalece false")
MinimizerDB = { simplifyEnabled = true }
check(addonTable.Config.IsSimplifyEnabled() == true, "Config: boolean moderno prevalece true")

-- Token recycling invalidates generation-scoped state.
Mocks.CreateTestUnit("nameplate5", { level = 70, faction = "Horde", threatSituation = 3 })
Mocks.CreateTestNameplate("nameplate5")
Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate5")
addonTable.Dispatcher.ApplyToUnit("nameplate5")
local cachedBefore = addonTable.Cache.GetUnitKeyWithGeneration("nameplate5", "threat:player")
check(cachedBefore == 3, "Lifecycle: threat queda cacheado para la unidad inicial")
Mocks.CreateTestUnit("nameplate5", { level = 70, faction = "Horde", threatSituation = 0 })
Mocks.CreateTestNameplate("nameplate5")
Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate5")
addonTable.Dispatcher.ApplyToUnit("nameplate5")
check(addonTable.Threat.GetSituation("nameplate5", "player") == 0, "Lifecycle: token reciclado no hereda threat stale")

local unit = "nameplate70"
addonTable.Cache.SetUnitKeyWithGeneration(unit, "threat:player", 3)
addonTable.Cache.SetUnitKeyWithGeneration(unit, "threat:party1", 1)
addonTable.Cache.SetUnitKeyWithGeneration(unit, "eliteType", "melee")
addonTable.Cache.InvalidateUnit(unit, "threat")
check(addonTable.Cache.GetUnitKeyWithGeneration(unit, "threat:player") == nil, "Cache: InvalidateUnit borra threat:player")
check(addonTable.Cache.GetUnitKeyWithGeneration(unit, "threat:party1") == nil, "Cache: InvalidateUnit borra threat:party1")
check(addonTable.Cache.GetUnitKeyWithGeneration(unit, "eliteType") == "melee", "Cache: InvalidateUnit conserva otros kinds")

local unitA, unitB = "nameplate71", "nameplate72"
addonTable.Cache.SetUnitKeyWithGeneration(unitA, "threat:player", 2)
addonTable.Cache.SetUnitKeyWithGeneration(unitB, "threat:player", 3)
addonTable.Cache.SetUnitKeyWithGeneration(unitA, "eliteType", "boss")
addonTable.Cache.InvalidateAll("threat")
check(addonTable.Cache.GetUnitKeyWithGeneration(unitA, "threat:player") == nil and addonTable.Cache.GetUnitKeyWithGeneration(unitB, "threat:player") == nil, "Cache: InvalidateAll(threat) borra threat:* en todas las unidades")
check(addonTable.Cache.GetUnitKeyWithGeneration(unitA, "eliteType") == "boss", "Cache: InvalidateAll no toca otras claves")

-- Hit-test follows the active health bar and retries after Blizzard unlocks mutation.
local token = "nameplate60"
local np1 = Mocks.CreateTestNameplate(token)
local hb1 = addonTable.Utils.GetHealthBar(np1)
Mocks.CreateTestUnit(token, { level = 70, classification = "normal", faction = "Horde" })
Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", token)
addonTable.Dispatcher.ApplyToUnit(token)
check(np1.MinimizerHitTestRegion == hb1, "Lifecycle: hit-test apunta al healthBar actual")
Mocks.CreateTestUnit(token, { level = 70, classification = "normal", faction = "Horde" })
local npRecycled = Mocks.CreateTestNameplate(token)
local hbRecycled = addonTable.Utils.GetHealthBar(npRecycled)
Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", token)
addonTable.Dispatcher.ApplyToUnit(token)
check(npRecycled.MinimizerHitTestRegion == hbRecycled, "Lifecycle: token reciclado sincroniza nuevo hit-test")

local tokenRetry = "nameplate61"
local np3 = Mocks.CreateTestNameplate(tokenRetry)
local hb3 = addonTable.Utils.GetHealthBar(np3)
Mocks.CreateTestUnit(tokenRetry, { level = 70, classification = "normal", faction = "Horde" })
np3.CanChangeHitTestPoints = function() return false end
check(addonTable.HitTest.Sync(tokenRetry) == false, "Lifecycle: Sync devuelve false si Blizzard bloquea la mutacion")
check(np3.MinimizerHitTestRegion == nil, "Lifecycle: Sync no muta mientras esta bloqueado")
np3.CanChangeHitTestPoints = function() return true end
Mocks.AdvanceTime(0.05)
check(np3.MinimizerHitTestRegion == hb3, "Lifecycle: retry aplica el hit-test cuando se habilita")

-- Event registration and propagation.
local eventFrame = _G.MinimizerEventFrame
check(eventFrame ~= nil and eventFrame.registeredEvents ~= nil, "Events: MinimizerEventFrame existe")
check(eventFrame.registeredEvents["UNIT_ABSORB_AMOUNT_CHANGED"] == true, "Events: UNIT_ABSORB_AMOUNT_CHANGED esta registrado")
check(eventFrame.registeredEvents["NAME_PLATE_UNIT_ADDED"] == true and eventFrame.registeredEvents["NAME_PLATE_UNIT_REMOVED"] == true, "Events: nameplate lifecycle esta registrado")
check(eventFrame.registeredEvents["UNIT_SPELLCAST_START"] == true and eventFrame.registeredEvents["UNIT_THREAT_SITUATION_UPDATE"] == true, "Events: cast y threat estan registrados")

local eventUnit = "nameplate99"
Mocks.CreateTestUnit(eventUnit, { level = 70, classification = "normal", faction = "Horde" })
Mocks.CreateTestNameplate(eventUnit)
Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", eventUnit)
local calledUnit = nil
local originalApply = addonTable.Dispatcher.ApplyToUnit
addonTable.Dispatcher.ApplyToUnit = function(unit, force)
    calledUnit = unit
    return originalApply(unit, force)
end
Mocks.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", eventUnit)
addonTable.Dispatcher.ApplyToUnit = originalApply
check(calledUnit == eventUnit, "Events: UNIT_ABSORB_AMOUNT_CHANGED invoca Dispatcher.ApplyToUnit")

-- Final architecture ownership assertions.
check(type(addonTable.Dispatcher.StartMonitor) == "function" and type(addonTable.Dispatcher.TrackUnit) == "function" and type(addonTable.Dispatcher.ForgetUnit) == "function", "Architecture: Dispatcher owns monitor lifecycle")
check(type(addonTable.Threat.GetThreatDetails) == "function" and type(addonTable.Threat.PlayerHasAggro) == "function", "Architecture: Threat expone proveedor de datos")
check(type(addonTable.Decision.ShouldSimplifyUnit) == "function" and type(addonTable.Decision.ShouldUnsimplify) == "function" and type(addonTable.Decision.ShouldLetBlizzardPaint) == "function", "Architecture: Decision owns business rules")
check(type(addonTable.Absorb.MarkSeen) == "function" and type(addonTable.Absorb.GetTotalAbsorbs) == "function", "Architecture: Absorb owns MarkSeen y GetTotalAbsorbs")
check(addonTable.Absorb.MarkAbsorbSeen == nil, "Architecture: no legacy alias Absorb.MarkAbsorbSeen")
check(type(addonTable.Lifecycle.GetGeneration) == "function" and type(addonTable.Lifecycle.IsGenerationStale) == "function", "Architecture: Lifecycle owns generations")
check(addonTable.Lifecycle.GetPlateGeneration == nil and addonTable.Lifecycle.IncrementPlateGeneration == nil, "Architecture: no legacy Lifecycle aliases")
check(type(addonTable.Snapshot.Build) == "function" and type(addonTable.Snapshot.ComputeDisplayKind) == "function", "Architecture: Snapshot mantiene pipeline canonico y fallback explicito")

T.finish("LIFECYCLE TESTS")
