-- Shared interrupt spell provider used by CastingBar and Focus.
local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Interrupt = Minimizer.Interrupt or {}

local INTERRUPT_SPELLS = Minimizer.Data.INTERRUPT_SPELLS

-- Cache: se recalcula cuando cambia la clase o la especializacion, porque
-- algunas clases tienen varios interrupt disponibles y el conocido cambia.
local cachedSpellID
local cachedSpellIDResolved = false

function Minimizer.Interrupt.InvalidateSpellIDCache()
    cachedSpellID = nil
    cachedSpellIDResolved = false
end

function Minimizer.Interrupt.GetSpellID()
    if cachedSpellIDResolved then
        return cachedSpellID
    end
    local _, classToken = UnitClass("player")
    cachedSpellID = Minimizer.Utils.FindKnownSpell(INTERRUPT_SPELLS[classToken])
    cachedSpellIDResolved = true
    return cachedSpellID
end

-- Cache de "esta listo": UNA sola entrada, recalculada explicitamente por
-- Core.ApplyToAll una vez por pase (NO por nameplate) y por Events.lua en
-- SPELL_UPDATE_COOLDOWN. Nunca debe llamarse a C_Spell dentro de un loop de
-- nameplates.
local cachedReady = true

function Minimizer.Interrupt.RefreshReadyCache()
    local spellID = Minimizer.Interrupt.GetSpellID()
    if spellID and C_Spell and C_Spell.GetSpellCooldownDuration then
        local duration = C_Spell.GetSpellCooldownDuration(spellID)
        if duration then
            cachedReady = duration:IsZero()
            return cachedReady
        end
    end
    cachedReady = true
    return cachedReady
end

-- Lee el valor cacheado. NO llama a ninguna API de Blizzard.
function Minimizer.Interrupt.IsReady()
    return cachedReady
end
