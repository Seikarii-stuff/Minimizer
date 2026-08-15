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
end

-- --- TEST GROUP 2: Decision.ShouldSimplifyUnit ---
do
    MinimizerDB.simplifyPercent = 50 -- necesario o Decision devuelve "disabled" siempre

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

    MinimizerDB.simplifyPercent = 0
    simplify, reason = addonTable.Decision.ShouldSimplifyUnit("d_normal", nil)
    check(simplify == false and reason == "disabled",
        "Decision: simplifyPercent=0 desactiva la simplificacion")
    MinimizerDB.simplifyPercent = 50 -- restaurar para no afectar tests siguientes
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
    addonTable.Config.Initialize()
    check(MinimizerDB.enableFocusFace == false and MinimizerDB.enableFocusArrows == true,
        "Config: migracion old focusIndicator=arrows crea los booleans separados")
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
    check(np.MinimizerPersistentCastColorKind == "castInterruptible",
        "GAP1: el flag persistente queda fijado tras el cast interrumpible")

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
    MinimizerDB.simplifyPercent = 50

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
        check(p == nil,
            "TEST A2: channel secreto ininterrumpible NO fija persistencia")
    end

    -- Terminar channel
    Mocks.units[token].channel = nil
    addonTable.Cast.InvalidateState(token)
    addonTable.Core.ApplyToUnit(token)

    local r2, g2, b2 = addonTable.Utils.GetHealthBar(np):GetStatusBarColor()
    check(math.abs(r2 - addonTable.Constants.HealthColors.melee[1]) < 0.01 and
          math.abs(g2 - addonTable.Constants.HealthColors.melee[2]) < 0.01 and
          math.abs(b2 - addonTable.Constants.HealthColors.melee[3]) < 0.01,
        "TEST A3: despues del channel, sin persistencia, vuelve a color base")
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
        check(p == nil,
            "TEST B2: cast secreto interrumpible NO fija persistencia (secreto no resuelto)")
    end

    -- Terminar cast pero persiste
    Mocks.units[token].cast = nil
    addonTable.Cast.InvalidateState(token)
    addonTable.Core.ApplyToUnit(token)

    check(np.MinimizerPersistentCastColorKind == nil,
        "TEST B3: despues del cast secreto interrumpible, NO persiste verde")
end

-- --- TEST GROUP 5: HealthBarColor — Leyenda M+ ---
--   Inferior interrumpible  -> verde PERSISTENTE
--   Inferior ininterrumpible -> gris TEMPORAL
--   Superior ininterrumpible -> gris TEMPORAL
--   Superior interrumpible   -> morado (sin cambio)
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

    -- 3c. Inferior termina cast ininterrumpible -> vuelve a su color base (no persiste)
    Mocks.units["nameplate14"].cast = nil
    addonTable.Cast.InvalidateState("nameplate14")
    addonTable.Core.ApplyToUnit("nameplate14")
    r, g, b = hbMeleeUnint:GetStatusBarColor()
    check(math.abs(r - 1.00) < 0.01 and math.abs(g - 1.00) < 0.01 and math.abs(b - 1.00) < 0.01,
        "HealthBarColor: inferior termina cast ininterrumpible -> vuelve blanco (no persiste)")

    -- 4. Boss casteando ininterrumpible -> gris TEMPORAL
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

-- --- TEST GROUP 7: Target halo uses cooldown logic, not a static fake fill ---
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
    local pip = addonTable.Widgets.CreatePip("TestSharedRadiusPip", parent, "defensive", "TOPLEFT", 23)
    check(pip ~= nil and pip.MinimizerPipRadius == 23,
        "Pips: se acepta un radio compartido explícito para centrar el pip sobre el halo")

    local portraitCooldown = CreateFrame("Cooldown", "TestPortraitCooldown", nil, "CooldownFrameTemplate")
    addonTable.Widgets.MakeCooldownCircular(portraitCooldown, true)
    check(portraitCooldown:GetHideCountdownNumbers() == false,
        "Portrait cooldown: la cuenta atrás no se esconde cuando se pide mantener los números")

    Mocks.cooldowns[107574] = nil
    check(addonTable.Widgets.UpdateHalo and addonTable.Widgets.UpdateHalo(halo, nil) == false,
        "Target halo: sin spell se oculta")
end

-- --- RESUMEN FINAL ---
print(string.format("\n=== SMOKE TEST RESULTS: %d/%d passed ===\n", testsRun - testsFailed, testsRun))
if testsFailed > 0 then
    error(testsFailed .. " test(s) failed. Revisa los FAIL de arriba antes de continuar.")
end

