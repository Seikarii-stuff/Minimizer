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
local _base_spell_cache = {}
local _known_cache = {}
local _spelllist_lookup_cache = {}

local function NormalizeSpellID(entry)
    local t = type(entry)
    if t == "number" then
        return entry
    end
    if t == "table" then
        local id = entry.id
        if type(id) == "number" then
            return id
        end
    end
    return nil
end

function Minimizer.Spells.InvalidateCache()
    wipe(_resolution_cache)
    wipe(_info_cache)
    wipe(_action_button_cache)
    wipe(_base_spell_cache)
    wipe(_known_cache)
    wipe(_spelllist_lookup_cache)
end

local function GetBaseSpellIDInternal(spellID)
    if not spellID then return nil end
    local cached = _base_spell_cache[spellID]
    if cached ~= nil then
        return cached
    end
    local baseID = nil
    if C_Spell and C_Spell.GetBaseSpell then
        baseID = C_Spell.GetBaseSpell(spellID)
        if not baseID or baseID <= 0 then
            baseID = spellID
        end
    else
        baseID = spellID
    end
    _base_spell_cache[spellID] = baseID
    return baseID
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
    -- Texture: use modern C_Spell.GetSpellInfo().iconID when available
    if C_Spell and C_Spell.GetSpellInfo then
        local si = C_Spell.GetSpellInfo(spellID)
        info.texture = si and si.iconID
    else
        info.texture = nil
    end
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
    local actionID
    local cachedInfo = _info_cache[spellID]
    if cachedInfo then
        actionID = cachedInfo.actionID
    end
    if actionID == nil then
        actionID = GetActionIDInternal(spellID)
    end
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
    local cached = _known_cache[spellID]
    if cached ~= nil then
        return cached
    end
    local known = false
    if C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook then
        known = C_SpellBook.IsSpellKnownOrInSpellBook(spellID) == true
    else
        known = false
    end
    _known_cache[spellID] = known
    return known
end

function Minimizer.Spells.Resolve(spellList, slotIndex)
    if not spellList then
        return nil
    end
    slotIndex = slotIndex or 1

    if type(spellList) == "number" then
        return (slotIndex == 1) and spellList or nil
    end

    local found = 0
    for i = 1, #spellList do
        local id = NormalizeSpellID(spellList[i])
        if id and Minimizer.Spells.IsKnown(id) then
            found = found + 1
            if found == slotIndex then
                return id
            end
        end
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
            local lookup = _spelllist_lookup_cache[spellList]
            if not lookup then
                lookup = {}
                for _, entry in ipairs(spellList) do
                    local sid = NormalizeSpellID(entry)
                    if sid then lookup[sid] = true end
                end
                _spelllist_lookup_cache[spellList] = lookup
            end
            if lookup[override] then
                overrideAllowed = true
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
