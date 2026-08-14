-- Shared interrupt spell provider used by CastingBar and Focus.
local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Interrupt = Minimizer.Interrupt or {}

local INTERRUPT_SPELLS = Minimizer.Data.INTERRUPT_SPELLS

function Minimizer.Interrupt.GetSpellID()
    local _, classToken = UnitClass("player")
    local spellList = classToken and INTERRUPT_SPELLS[classToken]
    if not spellList then return nil end

    if type(spellList) == "number" then
        spellList = {spellList}
    end

    for _, spellID in ipairs(spellList) do
        if ((C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook
            and C_SpellBook.IsSpellKnownOrInSpellBook(spellID))
            or (IsPlayerSpell and IsPlayerSpell(spellID))
            or (C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(spellID))
            or (IsSpellKnown and IsSpellKnown(spellID))) then
            return spellID
        end
    end
    return nil
end

function Minimizer.Interrupt.IsReady()
    local spellID = Minimizer.Interrupt.GetSpellID()
    if spellID and C_Spell and C_Spell.GetSpellCooldownDuration then
        local duration = C_Spell.GetSpellCooldownDuration(spellID)
        if duration then return duration:IsZero() end
    end
    return true
end
