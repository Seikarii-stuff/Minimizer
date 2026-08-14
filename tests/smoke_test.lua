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
    check(isCasting2 == true, "Cast: sin invalidar, devuelve el valor CACHEADO aunque el estado real cambio")

    -- Ahora invalidar y volver a leer: debe reflejar el estado real (nil = false)
    addonTable.Cast.InvalidateState("c_unit")
    local isCasting3 = addonTable.Cast.GetState("c_unit")
    check(isCasting3 == false, "Cast: tras InvalidateState, refleja el estado real actualizado")
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
    check(math.abs(r - 0.10) < 0.01 and math.abs(g - 1.00) < 0.01 and math.abs(b - 0.10) < 0.01,
        "HealthBarColor: inferior (caster/azul) castea interrumpible -> verde")

    -- 2b. Caster termina cast -> persiste verde
    Mocks.units["nameplate13"].cast = nil
    addonTable.Cast.InvalidateState("nameplate13")
    addonTable.Core.ApplyToUnit("nameplate13")
    r, g, b = hbCaster:GetStatusBarColor()
    check(math.abs(r - 0.10) < 0.01 and math.abs(g - 1.00) < 0.01 and math.abs(b - 0.10) < 0.01,
        "HealthBarColor: inferior (caster/azul) termina cast -> PERSISTE verde (flag)")

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

    -- 3b. Inferior termina cast ininterrumpible -> vuelve a su color base (no persiste)
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
    check(math.abs(r - 0.50) < 0.01 and math.abs(g - 0.50) < 0.01 and math.abs(b - 0.50) < 0.01,
        "HealthBarColor: boss (superior) casteando ininterrumpible -> gris TEMPORAL")

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

-- --- RESUMEN FINAL ---
print(string.format("\n=== SMOKE TEST RESULTS: %d/%d passed ===\n", testsRun - testsFailed, testsRun))
if testsFailed > 0 then
    error(testsFailed .. " test(s) failed. Revisa los FAIL de arriba antes de continuar.")
end

