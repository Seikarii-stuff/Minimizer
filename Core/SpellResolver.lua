local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Spells = Minimizer.Spells or {}

local type = type
local ipairs = ipairs
local table_insert = table.insert
local wipe = wipe

local _resolution_cache = {}
local _info_cache = {}
local _action_button_cache = {}

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
    wipe(_info_cache)
    wipe(_action_button_cache)
end

local function GetBaseSpellIDInternal(spellID)
    if not spellID then return nil end
    if C_Spell and C_Spell.GetBaseSpell then
        local baseID = C_Spell.GetBaseSpell(spellID)
        if baseID and baseID > 0 then
            return baseID
        end
    end
    return spellID
end

local function GetSpellTextureSafeInternal(spellID)
    if not spellID then return nil end
    if C_Spell and C_Spell.GetSpellTexture then
        local texture = C_Spell.GetSpellTexture(spellID)
        if texture then return texture end
    end
    if GetSpellTexture then
        return GetSpellTexture(spellID)
    end
    return nil
end

local function GetActionIDInternal(spellID)
    if not spellID or not C_ActionBar or not C_ActionBar.FindSpellActionButtons then
        return nil
    end

    local baseID = GetBaseSpellIDInternal(spellID)
    if not baseID then return nil end

    local cached = _action_button_cache[baseID]
    if cached ~= nil then
        if cached == false then return nil end
        return cached
    end

    local buttons = C_ActionBar.FindSpellActionButtons(baseID)
    local actionID = buttons and buttons[1] or false
    _action_button_cache[baseID] = actionID
    if not actionID then return nil end
    return actionID
end

function Minimizer.Spells.GetBaseSpellID(spellID)
    return GetBaseSpellIDInternal(spellID)
end

function Minimizer.Spells.GetActionID(spellID)
    return GetActionIDInternal(spellID)
end

function Minimizer.Spells.GetInfo(spellID)
    if type(spellID) ~= "number" then return nil end
    local cached = _info_cache[spellID]
    if cached then return cached end

    local info = { id = spellID }
    info.baseID = GetBaseSpellIDInternal(spellID)
    -- Resolve name safely, prefer modern C_Spell APIs then fallbacks
    do
        local resolvedName = nil
        if C_Spell then
            if C_Spell.GetSpellInfo then
                local s = C_Spell.GetSpellInfo(spellID)
                if s and type(s.name) == "string" and s.name ~= "" then
                    resolvedName = s.name
                end
            end
            if not resolvedName and C_Spell.GetSpellName then
                local n = C_Spell.GetSpellName(spellID)
                if type(n) == "string" and n ~= "" then
                    resolvedName = n
                end
            end
        end
        if not resolvedName and GetSpellInfo then
            local n = GetSpellInfo(spellID)
            if type(n) == "string" and n ~= "" then
                resolvedName = n
            end
        end
        info.name = resolvedName or ("Spell " .. tostring(spellID))
    end
    info.texture = GetSpellTextureSafeInternal(spellID)
    info.actionID = GetActionIDInternal(spellID)

    _info_cache[spellID] = info
    return info
end

function Minimizer.Spells.GetState(spellID)
    if type(spellID) ~= "number" then return nil end
    local state = {}

    -- Cooldown: support modern and legacy APIs. Do not cache dynamic state here.
    if C_Spell and C_Spell.GetSpellCooldownDuration then
        local duration = C_Spell.GetSpellCooldownDuration(spellID)
        if duration then
            state.cooldown = duration
        end
    elseif C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if info then state.cooldown = info end
    elseif GetSpellCooldown then
        local start, duration = GetSpellCooldown(spellID)
        if start and duration then state.cooldown = { start = start, duration = duration } end
    end

    -- Action display count (from action button) — independent from charges
    local actionID = GetActionIDInternal(spellID)
    if actionID and C_ActionBar and C_ActionBar.GetActionDisplayCount then
        state.displayCount = C_ActionBar.GetActionDisplayCount(actionID)
    end

    -- Charges: always attempt to read charges if API exists (do not discard when displayCount exists)
    if C_Spell and C_Spell.GetSpellCharges then
        local charges = C_Spell.GetSpellCharges(spellID)
        if charges then
            state.currentCharges = charges.currentCharges
            state.maxCharges = charges.maxCharges
        end
    end

    -- Fallback: if displayCount still nil, try C_Spell.GetSpellDisplayCount
    if state.displayCount == nil then
        if C_Spell and C_Spell.GetSpellDisplayCount then
            local dc = C_Spell.GetSpellDisplayCount(spellID)
            if dc ~= nil then state.displayCount = dc end
        end
    end

    -- Activation overlay / highlight
    if C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed then
        state.isOverlayed = C_SpellActivationOverlay.IsSpellOverlayed(spellID) == true
    else
        state.isOverlayed = false
    end

    return state
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
