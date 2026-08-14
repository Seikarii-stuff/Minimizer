-- Shared interrupt spell provider used by CastingBar and Focus.
local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Interrupt = Minimizer.Interrupt or {}

local INTERRUPT_SPELLS = {
    WARRIOR = 6552, ROGUE = 1766, MAGE = 2139, SHAMAN = 57994,
    HUNTER = 147362, PRIEST = 15487, WARLOCK = 19647, MONK = 116705,
    DRUID = 106839, DEATHKNIGHT = 47528, PALADIN = 96231,
    DEMONHUNTER = 183752, EVOKER = 351338,
}

function Minimizer.Interrupt.GetSpellID()
    if MinimizerDB.interruptSpellID then return MinimizerDB.interruptSpellID end
    local _, classToken = UnitClass("player")
    local spellID = classToken and INTERRUPT_SPELLS[classToken]
    if spellID and ((C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook
        and C_SpellBook.IsSpellKnownOrInSpellBook(spellID))
        or (IsPlayerSpell and IsPlayerSpell(spellID))
        or (C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(spellID))
        or (IsSpellKnown and IsSpellKnown(spellID))) then
        return spellID
    end
    return nil
end

function Minimizer.Interrupt.IsReady()
    if type(MinimizerDB.interruptReady) == "boolean" then
        return MinimizerDB.interruptReady
    end
    local spellID = Minimizer.Interrupt.GetSpellID()
    if spellID and C_Spell and C_Spell.GetSpellCooldownDuration then
        local duration = C_Spell.GetSpellCooldownDuration(spellID)
        if duration then return duration:IsZero() end
    end
    return true
end
