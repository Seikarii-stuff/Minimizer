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
    cachedSpellID = Minimizer.Spells and Minimizer.Spells.Resolve and Minimizer.Spells.Resolve(INTERRUPT_SPELLS[classToken], 1)
        or nil
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
    if spellID then
        if Minimizer.Spells and Minimizer.Spells.GetState then
            local state = Minimizer.Spells.GetState(spellID)
            if state and state.cooldown then
                -- If modern API provided an object with IsZero, use it; otherwise
                -- fall back to assuming non-zero unless the object explicitly
                -- reports zero via a field or method.
                if type(state.cooldown) == "table" and type(state.cooldown.IsZero) == "function" then
                    cachedReady = state.cooldown:IsZero()
                    return cachedReady
                end
                -- If legacy table with duration, consider zero duration as ready
                if state.cooldown.duration then
                    cachedReady = (state.cooldown.duration == 0)
                    return cachedReady
                end
            end
        end
    end
    cachedReady = true
    return cachedReady
end

-- Lee el valor cacheado. NO llama a ninguna API de Blizzard.
function Minimizer.Interrupt.IsReady()
    return cachedReady
end
