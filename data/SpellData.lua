local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Data = Minimizer.Data or {}

Minimizer.Data.INTERRUPT_SPELLS = {
    WARRIOR = {6552},
    ROGUE = {1766},
    MAGE = {2139},
    SHAMAN = {57994},
    HUNTER = {147362, 187707},
    PRIEST = {15487},
    WARLOCK = {19647, 119898, 171138},
    MONK = {116705},
    DRUID = {106839, 78675, 93985},
    DEATHKNIGHT = {47528},
    PALADIN = {96231},
    DEMONHUNTER = {183752},
    EVOKER = {351338},
}

Minimizer.Data.OFFENSIVE_CDS = {
    WARRIOR = {107574, 1719, 167105}, -- Avatar, Recklessness, Colossus Smash
    PALADIN = {31884, 231895}, -- Avenging Wrath, Crusade
    HUNTER = {193526, 19574, 266779}, -- Trueshot, Bestial Wrath, Coordinated Assault
    ROGUE = {13750, 121471, 192759, 280719}, -- Adrenaline Rush, Shadow Blades, Kingsbane, Secret Technique
    PRIEST = {10060, 228260, 200183}, -- Power Infusion, Void Eruption, Apotheosis
    DEATHKNIGHT = {439843, 51271, 275699, 49028}, -- Reaper's Mark, Pillar of Frost, Apocalypse, Dancing Rune Weapon
    SHAMAN = {114049, 204945, 191634}, -- Ascendance, Doom Winds, Stormkeeper
    MAGE = {190319, 12472, 365350}, -- Combustion, Icy Veins, Arcane Surge
    WARLOCK = {1122, 205180, 265187}, -- Infernal, Darkglare, Demonic Tyrant
    MONK = {137639, 123904, 132578, 322118}, -- SEF, Xuen, Niuzao, Yu'lon
    DRUID = {102558, 194223, 323764}, -- Incarnation, Celestial Alignment, Convoke
    DEMONHUNTER = {191427, 200166}, -- Metamorphosis
    EVOKER = {375087, 370960}, -- Dragonrage, Emerald Communion
}

Minimizer.Data.DEFENSIVE_CDS = {
    WARRIOR = {871, 118038, 184364}, -- Shield Wall, Die by the Sword, Enraged Regen
    PALADIN = {642, 31224, 86659}, -- Divine Shield, Ardent Defender, Guardian of Ancient Kings
    HUNTER = {186265, 264735}, -- Turtle, Survival of the Fittest
    ROGUE = {31224, 5277, 1966}, -- Cloak of Shadows, Evasion, Feint
    PRIEST = {47585, 33206, 19236}, -- Dispersion, Pain Suppression, Desperate Prayer
    DEATHKNIGHT = {55233, 48792}, -- Vampiric Blood (Blood), Icebound Fortitude (Frost/Unholy)
    SHAMAN = {108271}, -- Astral Shift
    MAGE = {45438, 110959}, -- Ice Block, Greater Invis
    WARLOCK = {104773}, -- Unending Resolve
    MONK = {122470, 115203}, -- Touch of Karma, Fortifying Brew
    DRUID = {61336, 22812}, -- Survival Instincts, Barkskin
    DEMONHUNTER = {198589, 212800}, -- Blur, Netherwalk
    EVOKER = {363916}, -- Obsidian Scales
}

Minimizer.Data.MASS_CC_SPELLS = {
    WARRIOR = {118000, 5246}, -- Shockwave, Intimidating Shout
    PALADIN = {115750}, -- Blinding Light
    HUNTER = {109248, 213691}, -- Binding Shot, Bursting Shot
    ROGUE = {2094}, -- Blind (Solo reference, no true mass CC available natively)
    PRIEST = {8122}, -- Psychic Scream
    DEATHKNIGHT = {207167, 108199}, -- Blinding Sleet, Gorefiend's Grasp
    SHAMAN = {192058}, -- Capacitor Totem
    MAGE = {31661, 113724}, -- Dragon's Breath, Ring of Frost
    WARLOCK = {30283, 5484}, -- Shadowfury, Howl of Terror
    MONK = {119381}, -- Leg Sweep
    DRUID = {102793, 99, 102359}, -- Ursol's Vortex, Incap Roar, Mass Entanglement
    DEMONHUNTER = {179057, 207684}, -- Chaos Nova, Sigil of Misery
    EVOKER = {358385, 357210}, -- Landslide, Deep Breath
}
