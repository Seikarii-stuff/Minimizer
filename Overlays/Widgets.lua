-- ============================================================================
-- Minimizer - Widgets.lua
-- Utilidades de UI reutilizables (cooldowns y descubrimiento de widgets).
-- ============================================================================
local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Widgets = Minimizer.Widgets or {}

local function FindCastBarInGrandchildren(healthBar, ...)
    for i = 1, select("#", ...) do
        local grandchild = select(i, ...)
        if type(grandchild) == "table"
            and grandchild ~= healthBar
            and type(grandchild.SetStatusBarColor) == "function"
            and type(grandchild.GetValue) == "function" then
            return grandchild
        end
    end
    return nil
end

local function FindCastBarInChildren(healthBar, ...)
    for i = 1, select("#", ...) do
        local child = select(i, ...)
        if type(child) == "table" and type(child.GetChildren) == "function" then
            local grandchild = FindCastBarInGrandchildren(healthBar, child:GetChildren())
            if grandchild then return grandchild end
        end
    end
    return nil
end

function Minimizer.Widgets.FindCastBar(nameplate)
    local unitFrame = nameplate and (nameplate.UnitFrame or nameplate)
    if not unitFrame or type(unitFrame.GetChildren) ~= "function" then return nil end
    local healthBar = Minimizer.Utils and Minimizer.Utils.GetHealthBar and Minimizer.Utils.GetHealthBar(nameplate)
    return FindCastBarInChildren(healthBar, unitFrame:GetChildren())
end

-- Cache anidado: cdSpellCache[dbTable][override or false][slotIndex] = spellID or false.
-- Todas las claves son valores estables; el hot path no necesita tostring/concat ni
-- construir tablas temporales por llamada una vez que el bucket está creado.
local cdSpellCache = {}

function Minimizer.Widgets.GetCDSpellID(dbTable, override, slotIndex)
    if not dbTable then return nil end

    local bucket = cdSpellCache[dbTable]
    if not bucket then
        bucket = {}
        cdSpellCache[dbTable] = bucket
    end

    local overrideKey = override or false
    local overrideBucket = bucket[overrideKey]
    if not overrideBucket then
        overrideBucket = {}
        bucket[overrideKey] = overrideBucket
    end

    local index = slotIndex or 1
    local cached = overrideBucket[index]
    if cached ~= nil then
        if cached == false then return nil end
        return cached
    end

    local _, classToken = UnitClass("player")
    local spellList = classToken and dbTable[classToken]

    if override ~= nil then
        local overrideAllowed = false
        if type(spellList) == "table" then
            for _, entry in ipairs(spellList) do
                local spellID = (type(entry) == "number") and entry or (type(entry) == "table" and entry.id)
                if spellID == override then
                    overrideAllowed = true
                    break
                end
            end
        end
        if overrideAllowed and Minimizer.Utils and Minimizer.Utils.IsSpellKnownByPlayer and Minimizer.Utils.IsSpellKnownByPlayer(override) then
            overrideBucket[index] = override
            return override
        end
    end

    local result = Minimizer.Utils.FindKnownSpell(spellList, index)
    overrideBucket[index] = result or false
    return result
end

function Minimizer.Widgets.InvalidateCDSpellCache()
    cdSpellCache = {}
end

function Minimizer.Widgets.ConfigureCooldownFrame(cooldown, opts)
    if not cooldown then return end
    opts = opts or {}

    local function boolOption(key, default)
        local value = opts[key]
        if value == nil then return default end
        return value == true
    end

    if cooldown.SetDrawEdge then
        cooldown:SetDrawEdge(boolOption("drawEdge", false))
    end
    if cooldown.SetUseCircularEdge then
        cooldown:SetUseCircularEdge(boolOption("useCircularEdge", false))
    end
    if cooldown.SetDrawSwipe then
        cooldown:SetDrawSwipe(boolOption("drawSwipe", true))
    end
    if cooldown.SetDrawBling then
        cooldown:SetDrawBling(boolOption("drawBling", false))
    end
    if cooldown.SetReverse then
        cooldown:SetReverse(boolOption("reverse", false))
    end
    if cooldown.SetHideCountdownNumbers then
        cooldown:SetHideCountdownNumbers(boolOption("hideCountdownNumbers", true))
    end
    if cooldown.SetSwipeTexture and opts.swipeTexture then
        cooldown:SetSwipeTexture(opts.swipeTexture)
    end
    if cooldown.SetSwipeColor and opts.swipeColor then
        cooldown:SetSwipeColor(opts.swipeColor[1], opts.swipeColor[2], opts.swipeColor[3], opts.swipeColor[4] or 1)
    end
end

function Minimizer.Widgets.MakeCooldownCircular(cooldown, showCountdownNumbers)
    if not cooldown then return end
    Minimizer.Widgets.ConfigureCooldownFrame(cooldown, {
        drawEdge = false,
        useCircularEdge = true,
        drawSwipe = true,
        drawBling = false,
        reverse = false,
        hideCountdownNumbers = not (showCountdownNumbers == true),
        swipeTexture = "Interface\\Masks\\CircleMaskScalable",
    })
end

function Minimizer.Widgets.ApplyCooldownDuration(cooldown, spellID)
    if not cooldown or not spellID then return false end

    if C_Spell and C_Spell.GetSpellCooldownDuration then
        local duration = C_Spell.GetSpellCooldownDuration(spellID)
        if duration and cooldown.SetCooldownFromDurationObject then
            cooldown:SetCooldownFromDurationObject(duration)
            return true
        end
    elseif C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if info then
            if cooldown.SetCooldownFromExpression then
                cooldown:SetCooldownFromExpression(spellID)
            elseif cooldown.SetCooldownTable then
                cooldown:SetCooldownTable(info)
            end
            return true
        end
    elseif GetSpellCooldown then
        local start, duration = GetSpellCooldown(spellID)
        if start and duration then
            cooldown:SetCooldown(start, duration)
            return true
        end
    end

    return false
end
