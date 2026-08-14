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
    -- Preparado para CDs ofensivos (1.5m/2m/3m por clase y spec)
}

Minimizer.Data.DEFENSIVE_CDS = {
    -- Preparado para CDs defensivos (personales de 1-2m por clase y spec)
}
