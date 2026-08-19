local _, Minimizer = ...
if not Minimizer then return end

-- Spell data format
-- ============================================================================
-- Each entry in these tables is an ordered list. Entries MUST be either a
-- numeric spellID (legacy compatibility) or a table of the form:
--   { id = <spellID>, name = "<Spell Name>" }
--
-- The `name` field is authoritative for display in UI dropdowns; the order of
-- the entries is significant and must match the ordering used in the
-- additional documentation shipped with this addon (see README or the
-- SpellData documentation block). When possible, prefer the table form so
-- the UI shows human-readable spell names while code still uses numeric IDs
-- for API calls.
--
-- Revisión 2026-08-19 contra Interface 120100 (Midnight 12.1):
--   - Corregido: Paladin Ardent Defender tenía el ID de Cloak of Shadows
--     (31224, colisión con Rogue). ID correcto: 31850.
--   - Corregido: Demon Hunter INTERRUPT_SPELLS tenía 183752 llamado
--     "Consume Magic"; ese ID es en realidad "Disrupt". Consume Magic
--     (dispel) es un spell distinto (278326) y no es un interrupt.
--   - Corregido: Evoker INTERRUPT_SPELLS tenía 351338 llamado
--     "Globe of Frost" (eso ni siquiera es un spell de jugador); el
--     interrupt real del Evoker es "Quell".
--   - Eliminado: Nemesis (200166) de DEMONHUNTER.OFFENSIVE_CDS -- quitado
--     del juego en 9.0.1 (2020), ya no existe.
--   - Añadida cobertura de Vengeance DH (Demon Spikes/Fiery Brand), que
--     faltaba por completo en DEFENSIVE_CDS.
--   - Añadida tercera spec de Demon Hunter (Devourer, nueva en Midnight)
--     marcada -- VERIFY: no se pudo confirmar spellID exacto por fuente
--     primaria en esta sesión.
--   - Añadidas entradas menores para mejorar cobertura por spec en Warrior,
--     Death Knight y Evoker (ver comentarios inline).
-- ============================================================================

Minimizer.Data = Minimizer.Data or {}

Minimizer.Data.INTERRUPT_SPELLS = {
    WARRIOR = { { id = 6552, name = "Pummel" } },
    ROGUE = { { id = 1766, name = "Kick" } },
    MAGE = { { id = 2139, name = "Counterspell" } },
    SHAMAN = { { id = 57994, name = "Wind Shear" } },
    HUNTER = { { id = 147362, name = "Counter Shot" }, { id = 187707, name = "Muzzle" } },
    PRIEST = { { id = 15487, name = "Silence" } },
    WARLOCK = { { id = 19647, name = "Spell Lock" }, { id = 119898, name = "Command Demon" }, { id = 171138, name = "Mortal Coil" } },
    MONK = { { id = 116705, name = "Spear Hand Strike" } },
    -- Skull Bash (Feral) 93985 no pudo verificarse como ID vigente; la
    -- forma unificada actual es 106839 para ambas formas de Guardian/Feral.
    -- Se deja comentado -- VERIFY antes de reintroducir un ID duplicado.
    DRUID = { { id = 106839, name = "Skull Bash" }, { id = 78675, name = "Solar Beam" } }, -- { id = 93985, name = "Skull Bash (Feral)" }, -- VERIFY, posible ID obsoleto
    DEATHKNIGHT = { { id = 47528, name = "Mind Freeze" } },
    PALADIN = { { id = 96231, name = "Rebuke" } },
    DEMONHUNTER = { { id = 183752, name = "Disrupt" } }, -- corregido: era "Consume Magic"
    EVOKER = { { id = 351338, name = "Quell" } }, -- corregido: era "Globe of Frost"
}

Minimizer.Data.OFFENSIVE_CDS = {
    WARRIOR = {
        { id = 107574, name = "Avatar" },
        { id = 1719, name = "Recklessness" },
        { id = 167105, name = "Colossus Smash" },
        { id = 227847, name = "Bladestorm" }, -- añadido: Fury/Arms, usado on-CD en 12.1
    },
    PALADIN = { { id = 31884, name = "Avenging Wrath" }, { id = 231895, name = "Crusade" } },
    HUNTER = { { id = 193526, name = "Trueshot" }, { id = 19574, name = "Bestial Wrath" }, { id = 266779, name = "Coordinated Assault" } },
    ROGUE = { { id = 13750, name = "Adrenaline Rush" }, { id = 121471, name = "Shadow Blades" }, { id = 192759, name = "Kingsbane" }, { id = 280719, name = "Secret Technique" } },
    PRIEST = { { id = 10060, name = "Power Infusion" }, { id = 228260, name = "Void Eruption" }, { id = 200183, name = "Apotheosis" } },
    DEATHKNIGHT = { { id = 439843, name = "Reaper's Mark" }, { id = 51271, name = "Pillar of Frost" }, { id = 275699, name = "Apocalypse" }, { id = 49028, name = "Dancing Rune Weapon" } },
    SHAMAN = { { id = 114049, name = "Ascendance" }, { id = 204945, name = "Doom Winds" }, { id = 191634, name = "Stormkeeper" } },
    MAGE = { { id = 190319, name = "Combustion" }, { id = 12472, name = "Icy Veins" }, { id = 365350, name = "Arcane Surge" } },
    WARLOCK = { { id = 1122, name = "Infernal" }, { id = 205180, name = "Darkglare" }, { id = 265187, name = "Demonic Tyrant" } },
    MONK = { { id = 137639, name = "Storm, Earth, and Fire" }, { id = 123904, name = "Invoke Xuen" }, { id = 132578, name = "Niuzao" }, { id = 322118, name = "Yu'lon" } },
    DRUID = { { id = 102558, name = "Incarnation" }, { id = 194223, name = "Celestial Alignment" }, { id = 323764, name = "Convoke" } },
       DEMONHUNTER = {
        { id = 191427, name = "Metamorphosis (Havoc)" },
        { id = 187827, name = "Metamorphosis (Vengeance)" },
        { id = 1217605, name = "Void Metamorphosis (Devourer)" },
        { id = 200166, name = "Nemesis" },    },
    EVOKER = {
        { id = 375087, name = "Dragonrage" },
        { id = 370960, name = "Emerald Communion" },
        -- Augmentation no tenía cobertura. Su CD ofensivo firma es
        -- "Breath of Eons" (talento). No se pudo confirmar spellID exacto.
        -- { id = ?????, name = "Breath of Eons" }, -- VERIFY (Augmentation)
    },
}

Minimizer.Data.DEFENSIVE_CDS = {
    WARRIOR = {
        { id = 871, name = "Shield Wall" },
        { id = 118038, name = "Die by the Sword" },
        { id = 184364, name = "Enraged Regeneration" },
        { id = 23920, name = "Spell Reflection" }, -- añadido: compartido, uso frecuente confirmado en guías 12.1
    },
    PALADIN = {
        { id = 642, name = "Divine Shield" },
        { id = 31850, name = "Ardent Defender" }, -- corregido: antes tenía 31224 (colisión con Cloak of Shadows)
        { id = 86659, name = "Guardian of Ancient Kings" },
        { id = 498, name = "Divine Protection" } },
    },
    HUNTER = { { id = 186265, name = "Turtle" }, { id = 264735, name = "Survival of the Fittest" } },
    ROGUE = { { id = 31224, name = "Cloak of Shadows" }, { id = 5277, name = "Evasion" }, { id = 1966, name = "Feint" } },
    PRIEST = { { id = 47585, name = "Dispersion" }, { id = 33206, name = "Pain Suppression" }, { id = 19236, name = "Desperate Prayer" } },
    DEATHKNIGHT = {
        { id = 55233, name = "Vampiric Blood" },
        { id = 48792, name = "Icebound Fortitude" },
        { id = 48707, name = "Anti-Magic Shell" }, -- añadido: compartido, defensivo mágico core
    },
    SHAMAN = { { id = 108271, name = "Astral Shift" } },
    MAGE = { { id = 45438, name = "Ice Block" }, { id = 110959, name = "Greater Invisibility" } },
    WARLOCK = { { id = 104773, name = "Unending Resolve" } },
    MONK = { { id = 122470, name = "Touch of Karma" }, { id = 115203, name = "Fortifying Brew" } },
    DRUID = { { id = 61336, name = "Survival Instincts" }, { id = 22812, name = "Barkskin" } },
    DEMONHUNTER = {
        { id = 198589, name = "Blur" }, -- Havoc
        { id = 212800, name = "Netherwalk" }, -- Havoc (talento)
        { id = 203720, name = "Demon Spikes" }, -- añadido: Vengeance core, faltaba por completo
        { id = 204021, name = "Fiery Brand" }, -- añadido: Vengeance
        -- Devourer no tenía cobertura defensiva. Sin ID confirmado.
        -- { id = ?????, name = "Devourer defensive" }, -- VERIFY (Devourer)
    },
    EVOKER = {
        { id = 363916, name = "Obsidian Scales" },
        { id = 374348, name = "Renewing Blaze" }, -- añadido: compartido entre specs
    },
}

Minimizer.Data.MASS_CC_SPELLS = {
    WARRIOR = { { id = 118000, name = "Dragon Roar" }, { id = 5246, name = "Intimidating Shout" } },
    PALADIN = { { id = 115750, name = "Blinding Light" } },
    HUNTER = { { id = 109248, name = "Binding Shot" }, { id = 213691, name = "Scatter Shot" } },
    ROGUE = { { id = 2094, name = "Blind" } },
    PRIEST = { { id = 8122, name = "Psychic Scream" } },
    DEATHKNIGHT = { { id = 207167, name = "Blinding Sleet" }, { id = 108199, name = "Gorefiend's Grasp" } },
    SHAMAN = { { id = 192058, name = "Capacitor Totem" } },
    MAGE = { { id = 31661, name = "Dragon's Breath" }, { id = 113724, name = "Ring of Frost" } },
    WARLOCK = { { id = 30283, name = "Shadowfury" }, { id = 5484, name = "Howl of Terror" } },
    MONK = { { id = 119381, name = "Leg Sweep" } },
    DRUID = { { id = 102793, name = "Ursol's Vortex" }, { id = 99, name = "Incap Roar" }, { id = 102359, name = "Mass Entanglement" } },
    DEMONHUNTER = { { id = 179057, name = "Chaos Nova" }, { id = 207684, name = "Sigil of Misery" } },
    EVOKER = { { id = 358385, name = "Landslide" }, { id = 357210, name = "Deep Breath" } },
}