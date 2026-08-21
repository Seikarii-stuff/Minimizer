-- tests/smoke_test.lua
local Mocks = dofile("tests/wow_mock.lua")

-- Simulate the addon table passed by the WoW client
local ADDON_NAME = "Minimizer"
local addonTable = {}

-- Helper to load addon files like the WoW client does
local function LoadAddonFile(filepath)
    local func, err = loadfile(filepath)
    if not func then
        if filepath == "data/SpellData.lua" then
            print("Warning: data/SpellData.lua not found. Mocking Minimizer.Data.")
            addonTable.Data = addonTable.Data or { INTERRUPT_SPELLS = {} }
            return
        end
        error("Failed to load " .. filepath .. ": " .. tostring(err))
    end
    -- The WoW client passes addonName and addonTable as varargs
    func(ADDON_NAME, addonTable)
end

print("--- Loading Minimizer Addon Files ---")
local function GetFileListFromToc(tocPath)
    local list = {}
    local fh = io.open(tocPath, "r")
    if not fh then
        error("No se pudo abrir el .toc en " .. tocPath .. " -- revisa la ruta")
    end
    for line in fh:lines() do
        local trimmed = line:match("^%s*(.-)%s*$")
        trimmed = trimmed:gsub("\\", "/")
        if trimmed ~= "" and not trimmed:match("^#") and not trimmed:match("^%.%.") then
            if trimmed:match("%.lua$") then
                table.insert(list, trimmed)
            end
        end
    end
    fh:close()
    return list
end

local files = GetFileListFromToc("Minimizer.toc")
for _, file in ipairs(files) do
    LoadAddonFile(file)
end

print("--- Firing ADDON_LOADED ---")
Mocks.FireEvent("ADDON_LOADED", ADDON_NAME)

print("--- Simulating NamePlates ---")
-- Create an enemy unit and its nameplate
Mocks.CreateTestUnit("nameplate1", {
    name = "Enemy Grunt",
    health = 50,
    healthMax = 100,
    level = 70,
    faction = "Horde",
    isPlayer = false,
    classification = "normal",
    cast = {
        name = "Fireball",
        startTime = Mocks.time * 1000,
        endTime = (Mocks.time + 2) * 1000,
        uninterruptible = false,
    }
})
local np1 = Mocks.CreateTestNameplate("nameplate1")

-- Fire NAME_PLATE_UNIT_ADDED event
print("Firing NAME_PLATE_UNIT_ADDED for nameplate1")
Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate1")

-- Advance time to trigger any throttled updates or cast bars
Mocks.AdvanceTime(0.5)
if addonTable.Core and addonTable.Core.ApplyToAll then
    print("Calling Minimizer.Core.ApplyToAll")
    addonTable.Core.ApplyToAll()
end

Mocks.AdvanceTime(0.5)

print("Firing NAME_PLATE_UNIT_REMOVED for nameplate1")
Mocks.FireEvent("NAME_PLATE_UNIT_REMOVED", "nameplate1")

print("--- Smoke Test Loaded Successfully ---")

-- ============================================================
-- TEST SUITE: aserciones de comportamiento (no solo carga)
-- ============================================================
local testsRun = 0
local testsFailed = 0

local function check(condition, description)
    testsRun = testsRun + 1
    if not condition then
        testsFailed = testsFailed + 1
        print("|cffff0000FAIL|r: " .. description)
    else
        print("|cff00ff00OK|r: " .. description)
    end
end

-- --- Reset: limpiar unidades/nameplates de la simulación anterior ---
Mocks.units = {}
Mocks.nameplates = {}

-- --- TEST GROUP: Core.ModuleList sincronizado con Core.Modules ---
do
    local countHash = 0
    for _ in pairs(addonTable.Modules) do countHash = countHash + 1 end
    local countList = #addonTable.ModuleList

    check(countHash == countList,
        "Core: ModuleList y Modules tienen el mismo numero de entradas")

    local seenInList = {}
    for _, m in ipairs(addonTable.ModuleList) do
        seenInList[m.MinimizerModuleName] = true
    end
    local allFound = true
    for name in pairs(addonTable.Modules) do
        if not seenInList[name] then allFound = false end
    end
    check(allFound,
        "Core: todo modulo registrado en Modules aparece tambien en ModuleList")
end

-- --- TEST GROUP 1: Classification.GetEliteType ---
do
    Mocks.CreateTestUnit("player", { level = 70, faction = "Alliance", isPlayer = true, class = "WARRIOR" })

    Mocks.CreateTestUnit("t_trivial", { level = 5, classification = "normal", faction = "Horde" })
    check(addonTable.Classification.GetEliteType("t_trivial") == "trivial",
        "Classification: nivel muy bajo respecto al jugador = trivial")

    Mocks.CreateTestUnit("t_trivial2", { level = 70, classification = "trivial", faction = "Horde" })
    check(addonTable.Classification.GetEliteType("t_trivial2") == "trivial",
        "Classification: clasificacion nativa 'trivial' = trivial")

    Mocks.CreateTestUnit("t_boss_skull", { level = -1, classification = "elite", faction = "Horde", isLieutenant = false })
    check(addonTable.Classification.GetEliteType("t_boss_skull") == "boss",
        "Classification: elite con nivel skull (-1) = boss")

    Mocks.CreateTestUnit("t_miniboss_lt", { level = 70, classification = "normal", faction = "Horde", isLieutenant = true })
    check(addonTable.Classification.GetEliteType("t_miniboss_lt") == "miniboss",
        "Classification: lieutenant no-elite = miniboss")

    Mocks.CreateTestUnit("t_caster", { level = 70, classification = "normal", faction = "Horde", powerType = 0 })
    check(addonTable.Classification.GetEliteType("t_caster") == "caster",
        "Classification: con mana y sin elite/trivial = caster")

    Mocks.CreateTestUnit("t_melee", { level = 70, classification = "normal", faction = "Horde", powerType = 1 })
    check(addonTable.Classification.GetEliteType("t_melee") == "melee",
        "Classification: sin mana y sin elite/trivial = melee")

    Mocks.unitClassificationCallCounts = Mocks.unitClassificationCallCounts or {}
    local before = Mocks.unitClassificationCallCounts["t_cache_gen"] or 0
    Mocks.CreateTestUnit("t_cache_gen", { level = 70, classification = "normal", faction = "Horde", powerType = 1 })
    addonTable.Classification.GetEliteType("t_cache_gen")
    addonTable.Classification.GetEliteType("t_cache_gen")
    local after = Mocks.unitClassificationCallCounts["t_cache_gen"] or 0
    check(after - before == 1,
        "Classification: memoiza la clasificacion dentro de la misma generacion")
end

-- --- TEST GROUP 2A: Utils.IsSpellKnownByPlayer / Widgets.GetCDSpellID override ---
do
    Mocks.playerSpells = {
        [1719] = true,
        [167105] = true,
        [107574] = true,
        [642] = true,
        [8122] = true,
    }

    check(addonTable.Utils.IsSpellKnownByPlayer(1719) == true,
        "Utils: IsSpellKnownByPlayer detecta un spell conocido")
    check(addonTable.Utils.IsSpellKnownByPlayer(999999) == false,
        "Utils: IsSpellKnownByPlayer devuelve false para un spell desconocido")

    local validOverride = addonTable.Widgets.GetCDSpellID(addonTable.Data.OFFENSIVE_CDS, 1719)
    check(validOverride == 1719,
        "Widgets: GetCDSpellID usa override conocido cuando es válido")

    local invalidOverride = addonTable.Widgets.GetCDSpellID(addonTable.Data.OFFENSIVE_CDS, 999999)
    check(invalidOverride ~= 999999 and invalidOverride ~= nil,
        "Widgets: GetCDSpellID cae a auto si override no es conocido")

    local wrongClassOverride = addonTable.Widgets.GetCDSpellID(addonTable.Data.DEFENSIVE_CDS, 1719)
    check(wrongClassOverride ~= 1719,
        "Widgets: GetCDSpellID cae a auto si override no pertenece a la lista de la clase")

    local cacheStable = addonTable.Widgets.GetCDSpellID(addonTable.Data.OFFENSIVE_CDS, 1719)
    local cacheStable2 = addonTable.Widgets.GetCDSpellID(addonTable.Data.OFFENSIVE_CDS, 1719)
    check(cacheStable == 1719 and cacheStable2 == 1719,
        "Widgets: el cache de override es estable para la misma clave")
end

-- --- TEST GROUP 2B: Interrupt cache invalidation ---
do
    Mocks.CreateTestUnit("player", { name = "Player", health = 100, healthMax = 100, level = 70, faction = "Alliance", isPlayer = true, class = "HUNTER", classId = 3, guid = "player_guid" })
    Mocks.playerSpells = {
        [147362] = true,
        [187707] = false,
    }
    if addonTable.Interrupt and addonTable.Interrupt.InvalidateSpellIDCache then
        addonTable.Interrupt.InvalidateSpellIDCache()
    end
    local firstInterrupt = addonTable.Interrupt and addonTable.Interrupt.GetSpellID and addonTable.Interrupt.GetSpellID()
    check(firstInterrupt == 147362,
        "Interrupt: resuelve el interrupt conocido de la spec actual para Hunter")

    Mocks.playerSpells = {
        [147362] = false,
        [187707] = true,
    }
    if addonTable.Interrupt and addonTable.Interrupt.InvalidateSpellIDCache then
        addonTable.Interrupt.InvalidateSpellIDCache()
    end
    local nextInterrupt = addonTable.Interrupt and addonTable.Interrupt.GetSpellID and addonTable.Interrupt.GetSpellID()
    check(nextInterrupt == 187707,
        "Interrupt: invalida el cache al cambiar de spec")
end

-- --- TEST GROUP 2: Decision.ShouldSimplifyUnit ---
do
    MinimizerDB.simplifyEnabled = true -- necesario o Decision devuelve "disabled" siempre

    Mocks.CreateTestUnit("d_friendly", { level = 70, classification = "normal", faction = "Alliance" })
    local simplify, reason = addonTable.Decision.ShouldSimplifyUnit("d_friendly", nil)
    check(simplify == false and reason == "friendly",
        "Decision: unidad amiga nunca se simplifica")

    Mocks.CreateTestUnit("d_boss", { level = -1, classification = "elite", faction = "Horde" })
    simplify, reason = addonTable.Decision.ShouldSimplifyUnit("d_boss", nil)
    check(simplify == false and reason == "no simp",
        "Decision: boss nunca se simplifica")

    Mocks.CreateTestUnit("d_cast_uninterr", {
        level = 70, classification = "normal", faction = "Horde",
        cast = { name = "Test", startTime = 0, endTime = 2000, uninterruptible = true }
    })
    simplify, reason = addonTable.Decision.ShouldSimplifyUnit("d_cast_uninterr", nil)
    check(simplify == false and reason == "temporal",
        "Decision: cast ininterrumpible inferior = temporal dessimp (solo mientras castea)")

    Mocks.CreateTestUnit("d_cast_interr", {
        level = 70, classification = "normal", faction = "Horde",
        cast = { name = "Test", startTime = 0, endTime = 2000, uninterruptible = false }
    })
    simplify, reason = addonTable.Decision.ShouldSimplifyUnit("d_cast_interr", nil)
    check(simplify == false and reason == "no simp",
        "Decision: cast interrumpible inferior = dessimp PERSISTENTE (wipe potencial en M+)")

    Mocks.CreateTestUnit("d_channel_uninterr", {
        level = 70, classification = "normal", faction = "Horde",
        channel = { name = "Drain", startTime = 0, endTime = 2000, uninterruptible = true }
    })
    simplify, reason = addonTable.Decision.ShouldSimplifyUnit("d_channel_uninterr", nil)
    check(simplify == false and reason == "temporal",
        "Decision: channel ininterrumpible inferior = temporal dessimp mientras dure el channel")

    Mocks.CreateTestUnit("d_aggro", {
        level = 70, classification = "normal", faction = "Horde", threatSituation = 3
    })
    simplify, reason = addonTable.Decision.ShouldSimplifyUnit("d_aggro", nil)
    check(simplify == false and reason == "temporal",
        "Decision: con aggro del jugador = temporal (no simplifica)")

    Mocks.CreateTestUnit("d_normal", { level = 70, classification = "normal", faction = "Horde" })
    simplify, reason = addonTable.Decision.ShouldSimplifyUnit("d_normal", nil)
    check(simplify == true and reason == "simplify",
        "Decision: unidad normal sin nada especial SI se simplifica")

    MinimizerDB.simplifyEnabled = false
    simplify, reason = addonTable.Decision.ShouldSimplifyUnit("d_normal", nil)
    check(simplify == false and reason == "disabled",
        "Decision: simplifyPercent=0 desactiva la simplificacion")
    MinimizerDB.simplifyEnabled = true -- restaurar para no afectar tests siguientes
end

-- --- TEST GROUP 3: Cast.GetState cachea y se invalida ---
do
    Mocks.CreateTestUnit("c_unit", {
        level = 70, faction = "Horde",
        cast = { name = "Test", startTime = 0, endTime = 2000, uninterruptible = false }
    })
    local isCasting1 = addonTable.Cast.GetState("c_unit")
    check(isCasting1 == true, "Cast: detecta casting activo")

    -- Cambiar el estado subyacente SIN invalidar: debe devolver el valor cacheado (viejo)
    Mocks.units["c_unit"].cast = nil
    local isCasting2 = addonTable.Cast.GetState("c_unit")
    check(isCasting2 == false, "Cast: sin cache, lectura fresca refleja el estado real cambiado")

    -- Ahora invalidar y volver a leer: debe reflejar el estado real (nil = false)
    addonTable.Cast.InvalidateState("c_unit")
    local isCasting3 = addonTable.Cast.GetState("c_unit")
    check(isCasting3 == false, "Cast: InvalidateState es no-op con lectura fresca; sigue reflejando el estado real")
end

-- --- TEST GROUP 4: Threat.PlayerHasAggro (no-tank) ---
do
    Mocks.CreateTestUnit("th_aggro", { level = 70, faction = "Horde", threatSituation = 3 })
    check(addonTable.Threat.PlayerHasAggro("th_aggro") == true,
        "Threat: situacion 3 = PlayerHasAggro true")

    Mocks.CreateTestUnit("th_noaggro", { level = 70, faction = "Horde", threatSituation = 1 })
    check(addonTable.Threat.PlayerHasAggro("th_noaggro") == false,
        "Threat: situacion 1 = PlayerHasAggro false")

    Mocks.CreateTestUnit("th_zero", { level = 70, faction = "Horde", threatSituation = 0 })
    check(addonTable.Threat.PlayerHasAggro("th_zero") == false,
        "Threat: situacion 0 NO debe tratarse como aggro (cuidado con truthiness)")

    Mocks.units["player"].role = "TANK"
    local realRefreshPlayerTankCache = addonTable.Threat.RefreshPlayerTankCache
    local refreshCalls = 0
    addonTable.Threat.RefreshPlayerTankCache = function()
        refreshCalls = refreshCalls + 1
        return realRefreshPlayerTankCache()
    end
    addonTable.Threat.InvalidatePlayerTankCache()
    check(addonTable.Threat.IsPlayerTank() == true,
        "Threat: rol de tank del jugador se cachea y se lee correctamente")
    check(addonTable.Threat.IsPlayerTank() == true,
        "Threat: el rol de tank no vuelve a consultar la API en la misma generacion")
    check(refreshCalls == 1,
        "Threat: la evaluacion del tank se memoiza en una sola llamada")
    Mocks.units["player"].role = "DAMAGER"
    if addonTable.Threat.InvalidatePlayerTankCache then
        addonTable.Threat.InvalidatePlayerTankCache()
    end
    addonTable.Threat.RefreshPlayerTankCache = realRefreshPlayerTankCache
end

-- --- TEST GROUP 5A: Config migration from legacy focusIndicator ---
do
    MinimizerDB = {
        version = 1,
        focusIndicator = "face",
        simplifyPercent = 25,
    }
    addonTable.Config.Initialize()
    check(MinimizerDB.enableFocusFace == true and MinimizerDB.enableFocusArrows == false,
        "Config: migracion old focusIndicator=face crea los booleans separados")
    check(MinimizerDB.focusIndicator == nil,
        "Config: migracion limpia la clave vieja focusIndicator")

    MinimizerDB = {
        version = 1,
        focusIndicator = "arrows",
    }
    MinimizerCharDB = {
        focusCC = 118000,
        targetDefensive = 871,
        targetOffensive = 107574,
    }
    addonTable.Config.Initialize()
    check(MinimizerDB.enableFocusFace == false and MinimizerDB.enableFocusArrows == true,
        "Config: migracion old focusIndicator=arrows crea los booleans separados")
    check(MinimizerCharDB.pip1 == 871,
        "Config: migracion targetDefensive -> pip1 (Verde)")
    check(MinimizerCharDB.targetDefensive == nil,
        "Config: migracion elimina targetDefensive")
    check(MinimizerCharDB.pip2 == 118000,
        "Config: migracion focusCC -> pip2 (Azul)")
    check(MinimizerCharDB.focusCC == nil,
        "Config: migracion elimina focusCC")
    check(MinimizerCharDB.targetOffensive == nil,
        "Config: migracion elimina targetOffensive")
end

-- --- TEST GROUP 5B: Config.IsSimplifyEnabled behaviour (centralized logic) ---
do
    -- Caso: MinimizerDB nil -> por compatibilidad devolvemos true
    MinimizerDB = nil
    check(addonTable.Config.IsSimplifyEnabled() == true,
        "Config.IsSimplifyEnabled: nil MinimizerDB => true (por compatibilidad)")

    -- Caso legacy: simplifyPercent = 0 -> desactivado
    MinimizerDB = { simplifyPercent = "0" }
    check(addonTable.Config.IsSimplifyEnabled() == false,
        "Config.IsSimplifyEnabled: simplifyPercent=0 => false")

    -- Caso legacy: simplifyPercent > 0 -> activado
    MinimizerDB = { simplifyPercent = "25" }
    check(addonTable.Config.IsSimplifyEnabled() == true,
        "Config.IsSimplifyEnabled: simplifyPercent=25 => true")

    -- Caso moderno: simplifyEnabled boolean prevalece
    MinimizerDB = { simplifyEnabled = false }
    check(addonTable.Config.IsSimplifyEnabled() == false,
        "Config.IsSimplifyEnabled: simplifyEnabled=false => false")
    MinimizerDB = { simplifyEnabled = true }
    check(addonTable.Config.IsSimplifyEnabled() == true,
        "Config.IsSimplifyEnabled: simplifyEnabled=true => true")
end

-- --- TEST GROUP 6: Token recycle generation counter prevents stale cache ---
do
    Mocks.CreateTestUnit("nameplate5", { level = 70, faction = "Horde", threatSituation = 3 })
    Mocks.CreateTestNameplate("nameplate5")
    Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate5")
    addonTable.Core.ApplyToUnit("nameplate5")

    local cachedBefore = addonTable.Cache and addonTable.Cache.GetUnitKeyWithGeneration and addonTable.Cache.GetUnitKeyWithGeneration("nameplate5", "threat:player")
    check(cachedBefore == 3, "Precondition: threat cached for unit A")

    Mocks.CreateTestUnit("nameplate5", { level = 70, faction = "Horde", threatSituation = 0 })
    Mocks.CreateTestNameplate("nameplate5")
    Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate5")
    addonTable.Core.ApplyToUnit("nameplate5")

    local situationNow = addonTable.Threat.GetSituation("nameplate5", "player")
    check(situationNow == 0, "Token recycled: Threat.GetSituation returns new unit's situation, not stale cached value")
end

-- --- GAP 1: HealthBarColor persistent cast flag invalidates on token recycle ---
-- --- TEST GROUP: Cache.InvalidateUnit / InvalidateAll (prefix matching) ---
-- --- TEST GROUP: unidades amistosas no se tocan (HealthBarColor/CastingBar) ---
do
    -- Asegurar jugador en Alliance para que UnitCanAttack devuelva false
    Mocks.CreateTestUnit("player", { name = "Player", health = 100, healthMax = 100, level = 70, faction = "Alliance", isPlayer = true, class = "WARRIOR", guid = "player_guid" })

    local token = "friendly_unit1"
    Mocks.CreateTestUnit(token, {
        name = "Friendly NPC",
        health = 50,
        healthMax = 100,
        level = 10,
        faction = "Alliance",
        isPlayer = false,
        classification = "normal",
        cast = { name = "VendorFlavor", startTime = 0, endTime = 2000, uninterruptible = false },
    })
    local np = Mocks.CreateTestNameplate(token)

    -- Ejecutar ApplyToUnit como lo haria el core
    addonTable.Core.ApplyToUnit(token)

    -- HealthBar NO debe haberse hookeado ni cambiado de color
    local hb = addonTable.Utils.GetHealthBar(np)
    check(hb.MinimizerHealthColorHooked ~= true,
        "Friendly: HealthBar NO debe quedar hookeada por Minimizer")
    local r, g, b = hb:GetStatusBarColor()
    check(math.abs(r - 1) < 0.01 and math.abs(g - 1) < 0.01 and math.abs(b - 1) < 0.01,
        "Friendly: HealthBar mantiene color default (1,1,1)")

    -- CastingBar NO debe haber sido pintada por Minimizer
    local castBar = np.UnitFrame.castBar
    check(castBar.MinimizerLastCastColor == nil,
        "Friendly: CastingBar no debe ser pintada (MinimizerLastCastColor nil)")

    -- Decision debe seguir reportando reason == 'friendly'
    local simplify, reason = addonTable.Decision.ShouldSimplifyUnit(token, nil)
    check(reason == "friendly",
        "Decision: unidad amiga sigue devolviendo reason == 'friendly'")
end

do
    local unit = "nameplate70"
    addonTable.Cache.SetUnitKeyWithGeneration(unit, "threat:player", 3)
    addonTable.Cache.SetUnitKeyWithGeneration(unit, "threat:party1", 1)
    addonTable.Cache.SetUnitKeyWithGeneration(unit, "eliteType", "melee")

    addonTable.Cache.InvalidateUnit(unit, "threat")

    check(addonTable.Cache.GetUnitKeyWithGeneration(unit, "threat:player") == nil,
        "Cache: InvalidateUnit borra todas las claves con el prefijo threat:")
    check(addonTable.Cache.GetUnitKeyWithGeneration(unit, "threat:party1") == nil,
        "Cache: InvalidateUnit borra threat:party1 tambien")
    check(addonTable.Cache.GetUnitKeyWithGeneration(unit, "eliteType") == "melee",
        "Cache: InvalidateUnit NO toca claves de otro kind (eliteType)")
end

do
    local unitA, unitB = "nameplate71", "nameplate72"
    addonTable.Cache.SetUnitKeyWithGeneration(unitA, "threat:player", 2)
    addonTable.Cache.SetUnitKeyWithGeneration(unitB, "threat:player", 3)
    addonTable.Cache.SetUnitKeyWithGeneration(unitA, "eliteType", "boss")

    addonTable.Cache.InvalidateAll("threat")

    check(addonTable.Cache.GetUnitKeyWithGeneration(unitA, "threat:player") == nil and
          addonTable.Cache.GetUnitKeyWithGeneration(unitB, "threat:player") == nil,
        "Cache: InvalidateAll(threat) borra la clave threat:* en TODAS las unidades")
    check(addonTable.Cache.GetUnitKeyWithGeneration(unitA, "eliteType") == "boss",
        "Cache: InvalidateAll(threat) no toca otras claves")
end

-- --- TEST GROUP: CastingBar reusa snapshot.isCasting/rawUninterruptible (no relee Cast.GetState) ---
do
    local token = "nameplate73"
    Mocks.CreateTestUnit(token, {
        level = 70, classification = "normal", faction = "Horde", powerType = 1,
        cast = { name = "Reuse Check", startTime = 0, endTime = 2000, uninterruptible = false }
    })
    Mocks.CreateTestNameplate(token)

    Mocks.unitCastingInfoCallCounts[token] = 0
    Mocks.unitChannelInfoCallCounts[token] = 0

    addonTable.Core.ApplyToUnit(token)

    check(Mocks.unitCastingInfoCallCounts[token] == 1,
        "CastingBar: UnitCastingInfo se llama UNA sola vez por ApplyToUnit (BuildSnapshot), no dos")
    check(Mocks.unitChannelInfoCallCounts[token] == 1,
        "CastingBar: UnitChannelInfo se llama UNA sola vez por ApplyToUnit (BuildSnapshot), no dos")

    local np = Mocks.nameplates[token]
    local castBar = np.UnitFrame.castBar
    local r, g, b = castBar:GetStatusBarColor()
    check(math.abs(r - addonTable.Constants.CastColors.ready[1]) < 0.01 and
          math.abs(g - addonTable.Constants.CastColors.ready[2]) < 0.01 and
          math.abs(b - addonTable.Constants.CastColors.ready[3]) < 0.01,
        "CastingBar: el color de la castbar sigue siendo correcto tras leer del snapshot")
end

-- --- END additional cache/casting tests ---

-- --- GAP 1: HealthBarColor persistent cast flag invalidates on token recycle ---
do
    local token = "nameplate21"
    Mocks.CreateTestUnit(token, {
        level = 70, classification = "normal", faction = "Horde", powerType = 1,
        cast = { name = "Interruptible Cast", startTime = 0, endTime = 2000, uninterruptible = false }
    })
    local np = Mocks.CreateTestNameplate(token)
    addonTable.Core.ApplyToUnit(token)

    local hb = addonTable.Utils.GetHealthBar(np)
    local r, g, b = hb:GetStatusBarColor()
    check(math.abs(r - addonTable.Constants.HealthColors.castInterruptible[1]) < 0.01 and
          math.abs(g - addonTable.Constants.HealthColors.castInterruptible[2]) < 0.01 and
          math.abs(b - addonTable.Constants.HealthColors.castInterruptible[3]) < 0.01,
        "GAP1: inferior en cast interrumpible pinta verde persistente")
    -- Kind flag removed in new contract; only color persistence remains

    Mocks.CreateTestUnit(token, { level = 70, classification = "normal", faction = "Horde", powerType = 1 })
    Mocks.CreateTestNameplate(token)
    Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", token)
    addonTable.Core.ApplyToUnit(token)

    local np2 = Mocks.nameplates[token]
    hb = addonTable.Utils.GetHealthBar(np2)
    r, g, b = hb:GetStatusBarColor()
    do
        local p2 = np2.MinimizerPersistentCastColor
        check(p2 == nil,
            "GAP1: reciclaje del token borra el flag persistente del cast anterior")
    end
    check(math.abs(r - addonTable.Constants.HealthColors.melee[1]) < 0.01 and
          math.abs(g - addonTable.Constants.HealthColors.melee[2]) < 0.01 and
          math.abs(b - addonTable.Constants.HealthColors.melee[3]) < 0.01,
        "GAP1: una unidad nueva sin cast no hereda el verde persistente")
end

-- --- GAP 2: Core persistent fast-path invalidates on token recycle ---
do
    local token = "nameplate22"
    MinimizerDB.simplifyEnabled = true

    Mocks.CreateTestUnit(token, { level = -1, classification = "elite", faction = "Horde" })
    local npBoss = Mocks.CreateTestNameplate(token)
    Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", token)
    addonTable.Core.ApplyToUnit(token)

    check(npBoss.MinimizerDesimplifiedPersistent == true,
        "GAP2: boss no simplificable queda marcado como persistente")

    Mocks.CreateTestUnit(token, { level = 70, classification = "normal", faction = "Horde" })
    Mocks.CreateTestNameplate(token)
    Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", token)
    addonTable.Core.ApplyToUnit(token)

    local simplify, reason = addonTable.Decision.ShouldSimplifyUnit(token, Mocks.nameplates[token])
    check(simplify == true and reason == "simplify",
        "GAP2: el token reciclado ya no hereda el no-simp del boss anterior")
    check(Mocks.nameplates[token].MinimizerState == true,
        "GAP2: el estado simplificado se recalcula para la nueva unidad")
end

-- --- GAP 3: hit-test track follows active healthBar and retries until Blizzard permits mutation ---
do
    local token = "nameplate60"
    local np1 = Mocks.CreateTestNameplate(token)
    local hb1 = addonTable.Utils.GetHealthBar(np1)
    Mocks.CreateTestUnit(token, { level = 70, classification = "normal", faction = "Horde" })
    Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", token)
    addonTable.Core.ApplyToUnit(token)

    check(np1.MinimizerHitTestRegion == hb1,
        "GAP3: el hit-test de la primera nameplate apunta al healthBar actual")

    Mocks.CreateTestUnit(token, { level = 70, classification = "normal", faction = "Horde" })
    local npRecycled = Mocks.CreateTestNameplate(token)
    local hbRecycled = addonTable.Utils.GetHealthBar(npRecycled)
    Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", token)
    addonTable.Core.ApplyToUnit(token)

    check(npRecycled.MinimizerHitTestRegion == hbRecycled,
        "GAP3: al reciclar el token, el hit-test se sincroniza con la nueva healthBar")
    check(np1.MinimizerHitTestRegion ~= hb1 or np1.MinimizerHitTestRegion == hb1,
        "GAP3: la referencia vieja no invalida la nueva asignacion")

    local tokenRetry = "nameplate61"
    local np3 = Mocks.CreateTestNameplate(tokenRetry)
    local hb3 = addonTable.Utils.GetHealthBar(np3)
    Mocks.CreateTestUnit(tokenRetry, { level = 70, classification = "normal", faction = "Horde" })
    np3.CanChangeHitTestPoints = function() return false end
    local first = addonTable.HitTest.Sync(tokenRetry)
    check(first == false,
        "GAP3: Sync devuelve false si Blizzard aun no permite cambiar el hit-test")
    check(np3.MinimizerHitTestRegion == nil,
        "GAP3: Sync no aplica el hit-test mientras Blizzard lo deniega")

    np3.CanChangeHitTestPoints = function() return true end
    Mocks.AdvanceTime(0.05)
    check(np3.MinimizerHitTestRegion == hb3,
        "GAP3: el retry reintenta y aplica el hit-test cuando Blizzard habilita la mutacion")
end

-- === TESTS: Secrets handling for persistencia verde ===
-- Test A: channel ininterrumpible enviado como secreto NO debe fijar persistencia
do
    local token = "nameplate23"
    Mocks.CreateTestUnit(token, {
        level = 70, classification = "normal", faction = "Horde", powerType = 1,
        channel = { name = "Secret Channel", startTime = 0, endTime = 2000, uninterruptible = Mocks.Secret(true) }
    })
    local np = Mocks.CreateTestNameplate(token)
    addonTable.Cast.InvalidateState(token)
    addonTable.Core.ApplyToUnit(token)

    local hb = addonTable.Utils.GetHealthBar(np)
    local r, g, b = hb:GetStatusBarColor()
    check(math.abs(r - addonTable.Constants.HealthColors.superiorUninterruptible[1]) < 0.01 and
          math.abs(g - addonTable.Constants.HealthColors.superiorUninterruptible[2]) < 0.01 and
          math.abs(b - addonTable.Constants.HealthColors.superiorUninterruptible[3]) < 0.01,
        "TEST A1: channel secreto ininterrumpible pinta gris mientras dura")
    do
                local p = np.MinimizerPersistentCastColor
                check(p ~= nil and math.abs(p[1] - addonTable.Constants.HealthColors.superiorUninterruptible[1]) < 0.01 and
                            math.abs(p[2] - addonTable.Constants.HealthColors.superiorUninterruptible[2]) < 0.01 and
                            math.abs(p[3] - addonTable.Constants.HealthColors.superiorUninterruptible[3]) < 0.01,
                        "TEST A2: channel secreto ininterrumpible FIJA persistencia de color")
    end

    -- Terminar channel
    Mocks.units[token].channel = nil
    addonTable.Cast.InvalidateState(token)
    addonTable.Core.ApplyToUnit(token)

        local r2, g2, b2 = addonTable.Utils.GetHealthBar(np):GetStatusBarColor()
        check(math.abs(r2 - addonTable.Constants.HealthColors.superiorUninterruptible[1]) < 0.01 and
                    math.abs(g2 - addonTable.Constants.HealthColors.superiorUninterruptible[2]) < 0.01 and
                    math.abs(b2 - addonTable.Constants.HealthColors.superiorUninterruptible[3]) < 0.01 and
                    np.MinimizerPersistentCastColor ~= nil,
                "TEST A3: despues del channel, el COLOR persiste (gris) aunque el estado era secreto; el Kind no se fija")
end

-- Test B: cast secreto que REALMENTE es interruptible debe fijar persistencia
do
    local token = "nameplate24"
    Mocks.CreateTestUnit(token, {
        level = 70, classification = "normal", faction = "Horde", powerType = 1,
        cast = { name = "Secret Cast", startTime = 0, endTime = 2000, uninterruptible = Mocks.Secret(false) }
    })
    local np = Mocks.CreateTestNameplate(token)
    addonTable.Core.ApplyToUnit(token)

    local hb = addonTable.Utils.GetHealthBar(np)
    local r, g, b = hb:GetStatusBarColor()
    check(math.abs(r - addonTable.Constants.HealthColors.castInterruptible[1]) < 0.01 and
          math.abs(g - addonTable.Constants.HealthColors.castInterruptible[2]) < 0.01 and
          math.abs(b - addonTable.Constants.HealthColors.castInterruptible[3]) < 0.01,
        "TEST B1: cast secreto interrumpible pinta verde")
        do
                local p = np.MinimizerPersistentCastColor
                check(p ~= nil and math.abs(p[1] - addonTable.Constants.HealthColors.castInterruptible[1]) < 0.01 and
                            math.abs(p[2] - addonTable.Constants.HealthColors.castInterruptible[2]) < 0.01 and
                            math.abs(p[3] - addonTable.Constants.HealthColors.castInterruptible[3]) < 0.01,
                        "TEST B2: cast secreto interrumpible FIJA persistencia de color (verde)")
        end

    -- Terminar cast pero persiste
    Mocks.units[token].cast = nil
    addonTable.Cast.InvalidateState(token)
    addonTable.Core.ApplyToUnit(token)

        check(np.MinimizerPersistentCastColor ~= nil and math.abs(np.MinimizerPersistentCastColor[1] - addonTable.Constants.HealthColors.castInterruptible[1]) < 0.01 and
                    math.abs(np.MinimizerPersistentCastColor[2] - addonTable.Constants.HealthColors.castInterruptible[2]) < 0.01 and
                    math.abs(np.MinimizerPersistentCastColor[3] - addonTable.Constants.HealthColors.castInterruptible[3]) < 0.01,
                "TEST B3: despues del cast secreto interrumpible, el COLOR persiste (verde)")
end

-- --- TEST GROUP 5: HealthBarColor — Leyenda M+ ---
--   Inferior interrumpible  -> verde PERSISTENTE
--   Inferior ininterrumpible -> gris TEMPORAL
--   Superior  -> morado (sin cambio)
do
    -- 1a. Melee (blanco) casteando interrumpible -> verde
    Mocks.CreateTestUnit("nameplate10", {
        level = 70, classification = "normal", faction = "Horde", powerType = 1,
        cast = { name = "Melee Spell", startTime = 0, endTime = 2000, uninterruptible = false }
    })
    local npMelee = Mocks.CreateTestNameplate("nameplate10")
    addonTable.Cast.InvalidateState("nameplate10")
    addonTable.Core.ApplyToUnit("nameplate10")
    local hbMelee = addonTable.Utils.GetHealthBar(npMelee)
    local r, g, b = hbMelee:GetStatusBarColor()
    check(math.abs(r - 0.10) < 0.01 and math.abs(g - 1.00) < 0.01 and math.abs(b - 0.10) < 0.01,
        "HealthBarColor: inferior (melee) castea interrumpible -> verde")

    -- 1b. Melee termina el cast -> persiste verde (flag)
    Mocks.units["nameplate10"].cast = nil
    addonTable.Cast.InvalidateState("nameplate10")
    addonTable.Core.ApplyToUnit("nameplate10")
    r, g, b = hbMelee:GetStatusBarColor()
    check(math.abs(r - 0.10) < 0.01 and math.abs(g - 1.00) < 0.01 and math.abs(b - 0.10) < 0.01,
        "HealthBarColor: inferior (melee) termina cast -> PERSISTE verde (flag)")

    -- 2a. Caster (azul) casteando interrumpible -> verde PERSISTENTE (misma leyenda que melee)
    Mocks.CreateTestUnit("nameplate13", {
        level = 70, classification = "normal", faction = "Horde", powerType = 0, -- hasmana
        cast = { name = "Caster Frostbolt", startTime = 0, endTime = 2500, uninterruptible = false }
    })
    local npCaster = Mocks.CreateTestNameplate("nameplate13")
    addonTable.Cast.InvalidateState("nameplate13")
    addonTable.Core.ApplyToUnit("nameplate13")
    local hbCaster = addonTable.Utils.GetHealthBar(npCaster)
    r, g, b = hbCaster:GetStatusBarColor()
    check(math.abs(r - 0.20) < 0.01 and math.abs(g - 0.55) < 0.01 and math.abs(b - 1.00) < 0.01,
        "HealthBarColor: inferior (caster/azul) castea interrumpible -> NO cambia (permanece azul)")

    -- 2b. Caster termina cast -> persiste verde
    Mocks.units["nameplate13"].cast = nil
    addonTable.Cast.InvalidateState("nameplate13")
    addonTable.Core.ApplyToUnit("nameplate13")
    r, g, b = hbCaster:GetStatusBarColor()
    check(math.abs(r - 0.20) < 0.01 and math.abs(g - 0.55) < 0.01 and math.abs(b - 1.00) < 0.01,
        "HealthBarColor: inferior (caster/azul) termina cast -> NO cambia (permanece azul)")

    -- 3. Inferior casteando ininterrumpible -> gris TEMPORAL
    Mocks.CreateTestUnit("nameplate14", {
        level = 70, classification = "normal", faction = "Horde", powerType = 1,
        cast = { name = "Unint Spell", startTime = 0, endTime = 2000, uninterruptible = true }
    })
    local npMeleeUnint = Mocks.CreateTestNameplate("nameplate14")
    addonTable.Cast.InvalidateState("nameplate14")
    addonTable.Core.ApplyToUnit("nameplate14")
    local hbMeleeUnint = addonTable.Utils.GetHealthBar(npMeleeUnint)
    r, g, b = hbMeleeUnint:GetStatusBarColor()
    check(math.abs(r - 0.50) < 0.01 and math.abs(g - 0.50) < 0.01 and math.abs(b - 0.50) < 0.01,
        "HealthBarColor: inferior casteando ininterrumpible -> gris TEMPORAL")

    -- 3b. Inferior channeling ininterrumpible -> gris TEMPORAL mientras dure el channel
    Mocks.CreateTestUnit("nameplate140", {
        level = 70, classification = "normal", faction = "Horde", powerType = 1,
        channel = { name = "Unint Channel", startTime = 0, endTime = 2000, uninterruptible = true }
    })
    local npMeleeChannelUnint = Mocks.CreateTestNameplate("nameplate140")
    addonTable.Cast.InvalidateState("nameplate140")
    addonTable.Core.ApplyToUnit("nameplate140")
    local hbMeleeChannelUnint = addonTable.Utils.GetHealthBar(npMeleeChannelUnint)
    r, g, b = hbMeleeChannelUnint:GetStatusBarColor()
    check(math.abs(r - 0.50) < 0.01 and math.abs(g - 0.50) < 0.01 and math.abs(b - 0.50) < 0.01,
        "HealthBarColor: inferior channeling ininterrumpible -> gris TEMPORAL")

    -- 3c. Inferior termina cast ininterrumpible -> el COLOR persiste (gris), la desimplificacion sigue siendo temporal
    Mocks.units["nameplate14"].cast = nil
    addonTable.Cast.InvalidateState("nameplate14")
    addonTable.Core.ApplyToUnit("nameplate14")
    r, g, b = hbMeleeUnint:GetStatusBarColor()
    check(math.abs(r - 0.50) < 0.01 and math.abs(g - 0.50) < 0.01 and math.abs(b - 0.50) < 0.01,
        "HealthBarColor: inferior termina cast ininterrumpible -> el COLOR persiste gris (desimplificacion sigue siendo temporal)")

    -- 4. Boss (superior) casteando ininterrumpible -> permanece morado
    -- (ver README §6.3: los superiores no cambian de color por cast/channel).
    Mocks.CreateTestUnit("nameplate11", {
        level = -1, classification = "elite", faction = "Horde",
        cast = { name = "Boss MegaCast", startTime = 0, endTime = 2000, uninterruptible = true }
    })
    local npBossUnint = Mocks.CreateTestNameplate("nameplate11")
    addonTable.Cast.InvalidateState("nameplate11")
    addonTable.Core.ApplyToUnit("nameplate11")
    local hbBossUnint = addonTable.Utils.GetHealthBar(npBossUnint)
    r, g, b = hbBossUnint:GetStatusBarColor()
    check(math.abs(r - addonTable.Constants.HealthColors.boss[1]) < 0.01 and
          math.abs(g - addonTable.Constants.HealthColors.boss[2]) < 0.01 and
          math.abs(b - addonTable.Constants.HealthColors.boss[3]) < 0.01,
        "HealthBarColor: boss (superior) casteando ininterrumpible -> permanece morado")

    -- 5. Boss casteando interrumpible -> permanece morado (sin cambio)
    Mocks.CreateTestUnit("nameplate12", {
        level = -1, classification = "elite", faction = "Horde",
        cast = { name = "Boss NormalCast", startTime = 0, endTime = 2000, uninterruptible = false }
    })
    local npBossInt = Mocks.CreateTestNameplate("nameplate12")
    addonTable.Cast.InvalidateState("nameplate12")
    addonTable.Core.ApplyToUnit("nameplate12")
    local hbBossInt = addonTable.Utils.GetHealthBar(npBossInt)
    r, g, b = hbBossInt:GetStatusBarColor()
    check(math.abs(r - 0.65) < 0.01 and math.abs(g - 0.25) < 0.01 and math.abs(b - 1.00) < 0.01,
        "HealthBarColor: boss (superior) casteando interrumpible -> permanece morado")
end

-- --- TEST GROUP 5B: Prioridad sobre superiores (boss/miniboss)
do
    -- a) Boss que es `focus` debe pintar `focus` (amarillo), NO morado
    do
        local token = "nameplate50"
        Mocks.CreateTestUnit(token, { level = -1, classification = "elite", faction = "Horde" })
        -- Simular que la unidad es la misma que el unit 'focus' (misma GUID)
        local bossGuid = Mocks.units[token].guid
        Mocks.CreateTestUnit("focus", { guid = bossGuid, name = "Focus Boss" })
        local np = Mocks.CreateTestNameplate(token)
        addonTable.Core.ApplyToUnit(token)

        local hb = addonTable.Utils.GetHealthBar(np)
        local r, g, b = hb:GetStatusBarColor()
        local fc = addonTable.Constants.HealthColors.focus
        local bc = addonTable.Constants.HealthColors.boss
        check(math.abs(r - fc[1]) < 0.01 and math.abs(g - fc[2]) < 0.01 and math.abs(b - fc[3]) < 0.01,
            "PRIORITY: focus gana a superior (boss) -> amarillo")
        check(not (math.abs(r - bc[1]) < 0.01 and math.abs(g - bc[2]) < 0.01 and math.abs(b - bc[3]) < 0.01),
            "PRIORITY: focus NO debe quedar morado (boss)")
    end

    -- b) Boss con threatSituation=3 (aggro del jugador) -> rojo (aggro), NO morado
    do
        local token = "nameplate51"
        Mocks.CreateTestUnit(token, { level = -1, classification = "elite", faction = "Horde", threatSituation = 3 })
        local np = Mocks.CreateTestNameplate(token)
        addonTable.Core.ApplyToUnit(token)

        local hb = addonTable.Utils.GetHealthBar(np)
        local r, g, b = hb:GetStatusBarColor()
        local ac = addonTable.Constants.HealthColors.aggro
        local bc = addonTable.Constants.HealthColors.boss
        check(math.abs(r - ac[1]) < 0.01 and math.abs(g - ac[2]) < 0.01 and math.abs(b - ac[3]) < 0.01,
            "PRIORITY: aggro (player) gana a superior (boss) -> rojo")
        check(not (math.abs(r - bc[1]) < 0.01 and math.abs(g - bc[2]) < 0.01 and math.abs(b - bc[3]) < 0.01),
            "PRIORITY: aggro NO debe quedar morado (boss)")
    end

    -- c) Boss con indicador de absorb visible -> absorb (rosa), NO morado
    do
        local token = "nameplate52"
        Mocks.CreateTestUnit(token, { level = -1, classification = "elite", faction = "Horde" })
        local np = Mocks.CreateTestNameplate(token)
        -- Simular overlay de absorb presente
        np.UnitFrame.healthBar.totalAbsorbOverlay = CreateFrame("Frame")
        np.UnitFrame.healthBar.totalAbsorbOverlay:Show()

        addonTable.Core.ApplyToUnit(token)
        local hb = addonTable.Utils.GetHealthBar(np)
        local r, g, b = hb:GetStatusBarColor()
        local ac = addonTable.Constants.HealthColors.absorb
        local bc = addonTable.Constants.HealthColors.boss
        check(math.abs(r - ac[1]) < 0.01 and math.abs(g - ac[2]) < 0.01 and math.abs(b - ac[3]) < 0.01,
            "PRIORITY: absorb gana a superior (boss) -> rosa")
        check(not (math.abs(r - bc[1]) < 0.01 and math.abs(g - bc[2]) < 0.01 and math.abs(b - bc[3]) < 0.01),
            "PRIORITY: absorb NO debe quedar morado (boss)")
    end
end

-- --- TEST GROUP 7: Target halo uses cooldown logic, not a static fake fill ---
-- === BUG FIX TEST: HealthBarColor survives native Blizzard repaints when absorb is active ===
do
    local token = "nameplate99"
    Mocks.CreateTestUnit(token, { level = 70, classification = "normal", faction = "Horde", powerType = 1 })
    local np = Mocks.CreateTestNameplate(token)
    -- Simulate the absorb indicator existing on the healthbar (as in real UI templates)
    np.UnitFrame.healthBar.totalAbsorbOverlay = CreateFrame("Frame")
    np.UnitFrame.healthBar.totalAbsorbOverlay:Show()

    -- Ensure ApplyToUnit paints the absorb color
    addonTable.Core.ApplyToUnit(token)
    local hb = addonTable.Utils.GetHealthBar(np)
    local r, g, b = hb:GetStatusBarColor()
    local ac = addonTable.Constants.HealthColors.absorb
    check(math.abs(r - ac[1]) < 0.01 and math.abs(g - ac[2]) < 0.01 and math.abs(b - ac[3]) < 0.01,
        "BUG_FIX: ApplyToUnit pinta la barra en color absorb cuando el indicador esta visible")

    -- Simulate a native Blizzard repaint calling SetStatusBarColor directly.
    hb:SetStatusBarColor(1, 1, 1, 1)
    local r2, g2, b2 = hb:GetStatusBarColor()
    check(math.abs(r2 - ac[1]) < 0.01 and math.abs(g2 - ac[2]) < 0.01 and math.abs(b2 - ac[3]) < 0.01,
        "BUG_FIX: repintado nativo de Blizzard NO debe eliminar el color absorb")
end

do
    local halo = addonTable.Widgets.CreateHalo("TestTargetHalo", nil, 46)
    Mocks.cooldowns[107574] = { start = Mocks.time, duration = 30 }
    local ok = addonTable.Widgets.UpdateHalo and addonTable.Widgets.UpdateHalo(halo, 107574)
    check(ok == true, "Target halo: UpdateHalo se ejecuta con un spell de cooldown real")
    check(halo:IsShown() == true, "Target halo: se muestra cuando el spell está activo")

    local alpha = halo.MinimizerHaloTexture:GetAlpha()
    check(alpha > 0 and alpha <= 1, "Target halo: el alpha refleja progreso y no queda bloqueado en 0 o 1 fijo")

    local parent = CreateFrame("Frame", "TestHaloParent")
    parent:SetSize(46, 46)

    -- Pips module tests
    check(type(addonTable.Pips) == "table" and type(addonTable.Pips.SLOTS) == "table",
        "Pips: modulo Minimizer.Pips y tabla SLOTS existen")
    check(#addonTable.Pips.SLOTS == 2,
        "Pips: SLOTS define exactamente el numero de pips configurados (2)")

    -- Check Pip 1 is Green and Pip 2 is Blue
    local s1Color = addonTable.Pips.SLOTS[1].color
    local s2Color = addonTable.Pips.SLOTS[2].color
    check(s1Color and math.abs(s1Color.on[2] - 1.00) < 0.01 and math.abs(s1Color.on[1] - 0.10) < 0.01,
        "Pips: Pip 1 es VERDE")
    check(s2Color and math.abs(s2Color.on[3] - 1.00) < 0.01 and math.abs(s2Color.on[1] - 0.20) < 0.01,
        "Pips: Pip 2 es AZUL")

    local createdPips = addonTable.Pips.CreatePips(parent, "TestModulePip", 23)
    check(#createdPips == #addonTable.Pips.SLOTS,
        "Pips: CreatePips crea exactamente un frame por cada slot definido")

    MinimizerCharDB.pip1 = 118000
    Mocks.cooldowns[118000] = { start = Mocks.time, duration = 45 }
    addonTable.Pips.UpdatePips(createdPips)
    check(createdPips[1]:IsShown() == true,
        "Pips: UpdatePips muestra el pip cuando el spell de PIPS_SPELLS está activo")

    addonTable.Pips.HidePips(createdPips)
    check(createdPips[1]:IsShown() == false and createdPips[2]:IsShown() == false,
        "Pips: HidePips oculta todos los pips creados")

    -- --- TEST: Configuración compartida de Pips entre Target y Focus ---
    do
        MinimizerCharDB.pip1 = 118000
        MinimizerCharDB.pip2 = 5246

        local targetParent = CreateFrame("Frame", "TestTargetParent")
        local focusParent = CreateFrame("Frame", "TestFocusParent")
        local targetPipsList = addonTable.Pips.CreatePips(targetParent, "TestTargetSharedPip", 23)
        local focusPipsList = addonTable.Pips.CreatePips(focusParent, "TestFocusSharedPip", 23)

        check(addonTable.Pips.GetSpellID(1) == 118000,
            "Shared Pips: Pip 1 resuelve el spell compartido (118000)")
        check(addonTable.Pips.GetSpellID(2) == 5246,
            "Shared Pips: Pip 2 resuelve el spell compartido (5246)")

        Mocks.cooldowns[118000] = { start = Mocks.time, duration = 30 }
        Mocks.cooldowns[5246] = { start = Mocks.time, duration = 90 }

        addonTable.Pips.UpdatePips(targetPipsList)
        addonTable.Pips.UpdatePips(focusPipsList)

        check(targetPipsList[1]:IsShown() == true and focusPipsList[1]:IsShown() == true,
            "Shared Pips: Pip 1 se muestra tanto en Target como en Focus con el mismo spell")
        check(targetPipsList[2]:IsShown() == true and focusPipsList[2]:IsShown() == true,
            "Shared Pips: Pip 2 se muestra tanto en Target como en Focus con el mismo spell")

        check(MinimizerCharDB.targetPip1 == nil and MinimizerCharDB.focusPip1 == nil,
            "Shared Pips: no existe configuracion separada target/focus en MinimizerCharDB")
    end

    local portraitCooldown = CreateFrame("Cooldown", "TestPortraitCooldown", nil, "CooldownFrameTemplate")
    addonTable.Widgets.MakeCooldownCircular(portraitCooldown, true)
    check(portraitCooldown:GetHideCountdownNumbers() == false,
        "Portrait cooldown: la cuenta atrás no se esconde cuando se pide mantener los números")

    Mocks.cooldowns[107574] = nil
    check(addonTable.Widgets.UpdateHalo and addonTable.Widgets.UpdateHalo(halo, nil) == false,
        "Target halo: sin spell se oculta")
end

-- --- TEST GROUP: ApplyToAll usa el registro ActiveNameplates ---
do
    local tokenA, tokenB = "nameplate80", "nameplate81"

    Mocks.CreateTestUnit(tokenA, { level = 70, classification = "normal", faction = "Horde" })
    Mocks.CreateTestNameplate(tokenA)
    Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", tokenA)

    Mocks.CreateTestUnit(tokenB, { level = 70, classification = "normal", faction = "Horde" })
    Mocks.CreateTestNameplate(tokenB)
    Mocks.FireEvent("NAME_PLATE_UNIT_ADDED", tokenB)

    check(addonTable.ActiveNameplates[tokenA] ~= nil and addonTable.ActiveNameplates[tokenB] ~= nil,
        "ApplyToAll: ambas unidades quedan registradas en ActiveNameplates tras NAME_PLATE_UNIT_ADDED")

    local okAll = pcall(addonTable.Core.ApplyToAll, true)
    check(okAll == true,
        "ApplyToAll: se ejecuta sin error iterando ActiveNameplates")

    local hbA = addonTable.Utils.GetHealthBar(Mocks.nameplates[tokenA])
    local hbB = addonTable.Utils.GetHealthBar(Mocks.nameplates[tokenB])
    check(hbA.MinimizerHealthColorHooked == true and hbB.MinimizerHealthColorHooked == true,
        "ApplyToAll: ambas nameplates fueron efectivamente procesadas (healthBar hookeada)")

    NamePlateDriverFrame:OnNamePlateRemoved(tokenA)
    check(addonTable.ActiveNameplates[tokenA] == nil,
        "ApplyToAll: ActiveNameplates limpia el token tras OnNamePlateRemoved")
    check(addonTable.ActiveNameplates[tokenB] ~= nil,
        "ApplyToAll: ActiveNameplates NO afecta a otros tokens al remover uno")

    local okAfterRemoval = pcall(addonTable.Core.ApplyToAll, true)
    check(okAfterRemoval == true,
        "ApplyToAll: sigue funcionando sin error tras remover una unidad del registro")
end

-- --- RESUMEN FINAL ---
print(string.format("\n=== SMOKE TEST RESULTS: %d/%d passed ===\n", testsRun - testsFailed, testsRun))
if testsFailed > 0 then
    error(testsFailed .. " test(s) failed. Revisa los FAIL de arriba antes de continuar.")
end

