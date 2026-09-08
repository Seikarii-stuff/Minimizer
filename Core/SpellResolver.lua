local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Spells = Minimizer.Spells or {}

local type = type
local ipairs = ipairs
local table_insert = table.insert
local wipe = wipe

local _resolution_cache = {}

local function NormalizeSpellID(entry)
    if type(entry) == "number" then
        return entry
    end
    if type(entry) == "table" and type(entry.id) == "number" then
        return entry.id
    end
    return nil
end

function Minimizer.Spells.InvalidateCache()
    wipe(_resolution_cache)
end

function Minimizer.Spells.IsKnown(spellID)
    if type(spellID) ~= "number" then
        return false
    end

    if C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook and C_SpellBook.IsSpellKnownOrInSpellBook(spellID) then
        return true
    end
    if IsPlayerSpell and IsPlayerSpell(spellID) then
        return true
    end
    if C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(spellID) then
        return true
    end
    if IsSpellKnown and IsSpellKnown(spellID) then
        return true
    end
    return false
end

function Minimizer.Spells.Resolve(spellList, slotIndex)
    if not spellList then
        return nil
    end
    slotIndex = slotIndex or 1

    if type(spellList) == "number" then
        return (slotIndex == 1) and spellList or nil
    end

    local knownList = {}
    for _, entry in ipairs(spellList) do
        local spellID = NormalizeSpellID(entry)
        if spellID and Minimizer.Spells.IsKnown(spellID) then
            table_insert(knownList, spellID)
        end
    end

    if #knownList >= slotIndex then
        return knownList[slotIndex]
    end

    local fallbackEntry = spellList[slotIndex] or spellList[1]
    local fallbackID = NormalizeSpellID(fallbackEntry)
    if fallbackID then
        return fallbackID
    end
    return nil
end

function Minimizer.Spells.ResolveForClass(dbTable, override, slotIndex, classToken)
    if not dbTable then
        return nil
    end

    local spellList = classToken and dbTable[classToken]
    local index = slotIndex or 1
    local dbBucket = _resolution_cache[dbTable]
    if not dbBucket then
        dbBucket = {}
        _resolution_cache[dbTable] = dbBucket
    end

    local classBucket = dbBucket[classToken or false]
    if not classBucket then
        classBucket = {}
        dbBucket[classToken or false] = classBucket
    end

    local overrideBucket = classBucket[override or false]
    if not overrideBucket then
        overrideBucket = {}
        classBucket[override or false] = overrideBucket
    end

    local cached = overrideBucket[index]
    if cached ~= nil then
        if cached == false then
            return nil
        end
        return cached
    end

    if override ~= nil then
        local overrideAllowed = false
        if type(spellList) == "table" then
            for _, entry in ipairs(spellList) do
                if NormalizeSpellID(entry) == override then
                    overrideAllowed = true
                    break
                end
            end
        end
        if overrideAllowed and Minimizer.Spells.IsKnown(override) then
            overrideBucket[index] = override
            return override
        end
    end

    local result = Minimizer.Spells.Resolve(spellList, index)
    overrideBucket[index] = result or false
    return result
end
