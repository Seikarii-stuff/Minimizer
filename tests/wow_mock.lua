-- tests/wow_mock.lua
-- Mock environment for World of Warcraft UI API

_G = _G or {}
local Mocks = {}
_G.Mocks = Mocks

-- WoW globals
_G.tinsert = table.insert
_G.tremove = table.remove
_G.bit = require("bit") -- Requires LuaJIT or lua-bitop
_G.Enum = {
    PowerType = {
        Mana = 0,
        Rage = 1,
        Focus = 2,
        Energy = 3,
        ComboPoints = 4,
        Runes = 5,
        RunicPower = 6,
        SoulShards = 7,
        LunarPower = 8,
        HolyPower = 9,
        Alternate = 10,
        Maelstrom = 11,
        Chi = 12,
        Insanity = 13,
        Obsolete = 14,
        Obsolete2 = 15,
        ArcaneCharges = 16,
        Fury = 17,
        Pain = 18,
    }
}
_G.SlashCmdList = {}

-- Mocks data state
Mocks.units = {}
Mocks.nameplates = {}
Mocks.time = 0
Mocks.frames = {}
Mocks.events = {}
Mocks.timers = {}
Mocks.cooldowns = {}
Mocks.unitClassificationCallCounts = {}
-- Counters for UnitCastingInfo/UnitChannelInfo to assert we don't double-call
Mocks.unitCastingInfoCallCounts = {}
Mocks.unitChannelInfoCallCounts = {}

function _G.GetTime()
    return Mocks.time
end

function _G.GetSpellCooldownDuration(spellID)
    local cd = Mocks.cooldowns[spellID]
    if not cd then return nil end
    return cd.duration or nil
end

function _G.GetSpellCooldown(spellID)
    local cd = Mocks.cooldowns[spellID]
    if not cd then return nil, nil end
    return cd.start or 0, cd.duration or 0
end

function Mocks.AdvanceTime(seconds)
    Mocks.time = Mocks.time + seconds
    local i = 1
    while i <= #Mocks.timers do
        local t = Mocks.timers[i]
        if Mocks.time >= t.fireTime then
            table.remove(Mocks.timers, i)
            t.callback()
        else
            i = i + 1
        end
    end
end

-- Frames
local FrameMixin = {}

function FrameMixin:RegisterEvent(event)
    local reg = rawget(self, "registeredEvents")
    if not reg then
        reg = {}
        rawset(self, "registeredEvents", reg)
    end
    reg[event] = true
    
    Mocks.events[event] = Mocks.events[event] or {}
    table.insert(Mocks.events[event], self)
end

function FrameMixin:UnregisterEvent(event)
    local reg = rawget(self, "registeredEvents")
    if reg then
        reg[event] = nil
    end
end

function FrameMixin:SetScript(handlerType, func)
    local scripts = rawget(self, "scripts")
    if not scripts then
        scripts = {}
        rawset(self, "scripts", scripts)
    end
    scripts[handlerType] = func
end

function FrameMixin:GetScript(handlerType)
    local scripts = rawget(self, "scripts")
    return scripts and scripts[handlerType]
end

function FrameMixin:HookScript(handlerType, func)
    local scripts = rawget(self, "scripts")
    if not scripts then
        scripts = {}
        rawset(self, "scripts", scripts)
    end
    local oldFunc = scripts[handlerType]
    scripts[handlerType] = function(...)
        if oldFunc then oldFunc(...) end
        func(...)
    end
end

function FrameMixin:Hide() self.shown = false end
function FrameMixin:Show() self.shown = true end
function FrameMixin:IsShown() return self.shown end
function FrameMixin:SetAlpha(alpha) self.alpha = alpha end
function FrameMixin:GetAlpha() return self.alpha or 1 end
function FrameMixin:SetStatusBarColor(r, g, b, a) self.statusBarColor = { r, g, b, a or 1 } end
function FrameMixin:GetStatusBarColor()
    if self.statusBarColor then
        return self.statusBarColor[1], self.statusBarColor[2], self.statusBarColor[3], self.statusBarColor[4]
    end
    return 1, 1, 1, 1
end
function FrameMixin:SetHideCountdownNumbers(value) self.hideCountdownNumbers = value == true end
function FrameMixin:GetHideCountdownNumbers() return self.hideCountdownNumbers == true end
function FrameMixin:GetParent()
    return rawget(self, "parent")
end

function FrameMixin:GetChildren()
    local ch = rawget(self, "_children")
    if not ch or #ch == 0 then return end
    return unpack(ch)
end

-- Explicit dummy methods instead of catch-all __index
local function dummyMethod() end
local function dummyCreateObject(self)
    local obj = {}
    setmetatable(obj, { __index = FrameMixin })
    return obj
end
FrameMixin.CreateTexture = dummyCreateObject
FrameMixin.CreateFontString = dummyCreateObject
FrameMixin.CreateMaskTexture = dummyCreateObject
-- Smart __index for FrameMixin to auto-mock WoW UI methods
setmetatable(FrameMixin, {
    __index = function(t, k)
        if type(k) == "string" then
            if k:match("^Create") then
                return dummyCreateObject
            elseif k:match("^Set") or k:match("^Clear") or k:match("^Play") or k:match("^Stop") or k:match("^Hook") then
                return dummyMethod
            elseif k:match("^Get") then
                return function() return 1, 1, 1, 1 end
            elseif k:match("^Is") or k:match("^Can") then
                return function() return true end
            elseif k:match("^Add") then
                return dummyMethod
            end
        end
        return nil -- Return nil for custom addon fields (like MinimizerHealthColorIndicator)
    end
})

function _G.CreateFrame(frameType, name, parent, template)
    local frame = {
        type = frameType,
        name = name,
        parent = parent,
        template = template,
        shown = true,
        alpha = 1,
    }
    setmetatable(frame, { __index = FrameMixin })
    if name then _G[name] = frame end
    -- register as child of parent frame for GetChildren() to work
    if parent and type(parent) == "table" then
        parent._children = parent._children or {}
        table.insert(parent._children, frame)
    end
    table.insert(Mocks.frames, frame)
    return frame
end

_G.C_Timer = {
    After = function(duration, callback)
        if duration <= 0 then
            callback()
        else
            table.insert(Mocks.timers, {
                fireTime = Mocks.time + duration,
                callback = callback,
            })
        end
    end,
}

_G.C_Timer.NewTicker = function(interval, callback)
    local ticker = { cancelled = false }
    local function reschedule()
        if ticker.cancelled then return end
        table.insert(Mocks.timers, {
            fireTime = Mocks.time + interval,
            callback = function()
                callback(ticker)
                reschedule()
            end,
        })
    end
    reschedule()
    function ticker:Cancel() self.cancelled = true end
    return ticker
end

_G.C_CurveUtil = {
    EvaluateColorValueFromBoolean = function(state, valueIfTrue, valueIfFalse)
        local resolved = state
        if type(state) == "table" and state.__minimizerMockSecret then
            resolved = state.__value
        end
        if resolved == true then
            return valueIfTrue
        else
            return valueIfFalse
        end
    end
}

Mocks.playerSpells = {
    [107574] = true,
    [1719] = true,
    [171138] = true,
    [8122] = true,
    [642] = true,
    [118000] = true,
}

_G.C_SpellBook = {
    IsSpellKnownOrInSpellBook = function(spellID)
        return Mocks.playerSpells[spellID] == true
    end,
    IsSpellKnown = function(spellID)
        return Mocks.playerSpells[spellID] == true
    end,
}

_G.IsPlayerSpell = function(spellID)
    return Mocks.playerSpells[spellID] == true
end

_G.IsSpellKnown = function(spellID)
    return Mocks.playerSpells[spellID] == true
end

-- Mock secret helper used by tests to simulate Midnight/Secrets values.
function Mocks.Secret(value)
    return { __minimizerMockSecret = true, __value = value }
end

-- Global issecretvalue used by Minimizer.Utils.IsSecretValue()
_G.issecretvalue = function(v)
    return type(v) == "table" and v.__minimizerMockSecret == true
end

function _G.hooksecurefunc(table, funcName, hook)
    if type(table) == "string" then
        hook = funcName
        funcName = table
        table = _G
    end
    local orig = table[funcName]
    table[funcName] = function(...)
        local result = nil
        if orig then
            result = orig(...)
        end
        hook(...)
        return result
    end
end

function Mocks.FireEvent(event, ...)
    if Mocks.events[event] then
        for _, frame in ipairs(Mocks.events[event]) do
            if frame.registeredEvents and frame.registeredEvents[event] then
                local onEvent = frame:GetScript("OnEvent")
                if onEvent then
                    onEvent(frame, event, ...)
                end
            end
        end
    end
end

-- NamePlates
_G.C_NamePlate = {
    GetNamePlates = function()
        local nps = {}
        for _, np in pairs(Mocks.nameplates) do
            table.insert(nps, np)
        end
        return nps
    end,
    GetNamePlateForUnit = function(unit)
        for _, np in pairs(Mocks.nameplates) do
            if np.namePlateUnitToken == unit then
                return np
            end
        end
        return nil
    end,
}

_G.C_NamePlateManager = {
    SetNamePlateSimplified = function(unit, simplified)
        local np = _G.C_NamePlate.GetNamePlateForUnit(unit)
        if np then
            np.simplified = simplified
        end
    end
}

-- Unit API
local function getUnit(unitId)
    return Mocks.units[unitId]
end

function _G.UnitExists(unit)
    return getUnit(unit) ~= nil
end

function _G.UnitName(unit)
    local u = getUnit(unit)
    return u and u.name or "Unknown"
end

function _G.UnitHealth(unit)
    local u = getUnit(unit)
    return u and u.health or 0
end

function _G.UnitHealthMax(unit)
    local u = getUnit(unit)
    return u and u.healthMax or 100
end

function _G.UnitLevel(unit)
    local u = getUnit(unit)
    return u and u.level or 1
end

function _G.UnitEffectiveLevel(unit)
    return _G.UnitLevel(unit)
end

function _G.UnitClassification(unit)
    local u = getUnit(unit)
    -- Count calls for tests that want to assert how often this API is used.
    Mocks.unitClassificationCallCounts[unit] = (Mocks.unitClassificationCallCounts[unit] or 0) + 1
    return u and u.classification or "normal"
end

function _G.UnitIsLieutenant(unit)
    local u = getUnit(unit)
    return u and u.isLieutenant or false
end

function _G.UnitCanAttack(unit1, unit2)
    local u1 = getUnit(unit1)
    local u2 = getUnit(unit2)
    if not u1 or not u2 then return false end
    return u1.faction ~= u2.faction
end

function _G.UnitAffectingCombat(unit)
    local u = getUnit(unit)
    if not u then return false end
    return u.inCombat == true
end

function _G.UnitGroupRolesAssigned(unit)
    local u = getUnit(unit)
    if not u then return nil end
    return u.role or "NONE"
end

function _G.IsInRaid()
    return false
end

function _G.IsInGroup()
    return false
end

function _G.UnitIsUnit(unit1, unit2)
    if unit1 == unit2 then return true end
    local u1 = getUnit(unit1)
    local u2 = getUnit(unit2)
    if u1 and u2 and u1.guid == u2.guid then return true end
    return false
end

function _G.UnitThreatSituation(source, target)
    -- WoW API: UnitThreatSituation("player", "nameplate1")
    -- returns the threat SITUATION of `source` on `target`.
    -- In our mock, the threat is stored on the TARGET unit.
    local u = getUnit(target)
    if not u then return nil end
    -- Only return the threat if the source is the player
    if source == "player" then
        return u.threatSituation
    end
    return 0
end

function _G.UnitCastingInfo(unit)
    Mocks.unitCastingInfoCallCounts[unit] = (Mocks.unitCastingInfoCallCounts[unit] or 0) + 1
    local u = getUnit(unit)
    if u and u.cast then
        return u.cast.name, nil, nil, u.cast.startTime, u.cast.endTime, nil, u.cast.castID, u.cast.uninterruptible
    end
    return nil
end

function _G.UnitChannelInfo(unit)
    Mocks.unitChannelInfoCallCounts[unit] = (Mocks.unitChannelInfoCallCounts[unit] or 0) + 1
    local u = getUnit(unit)
    if u and u.channel then
        return u.channel.name, nil, nil, u.channel.startTime, u.channel.endTime, nil, u.channel.uninterruptible
    end
    return nil
end

function _G.UnitAura(unit, index, filter)
    local u = getUnit(unit)
    if not u or not u.auras then return nil end
    local count = 0
    for _, aura in ipairs(u.auras) do
        local match = true
        if filter then
            -- simplified filter check
            if string.match(filter, "HELPFUL") and not aura.helpful then match = false end
            if string.match(filter, "HARMFUL") and not aura.harmful then match = false end
            if string.match(filter, "PLAYER") and aura.source ~= "player" then match = false end
        end
        if match then
            count = count + 1
            if count == index then
                return aura.name, aura.icon, aura.count, aura.debuffType, aura.duration, aura.expirationTime, aura.source, aura.isStealable, aura.nameplateShowPersonal, aura.spellId
            end
        end
    end
    return nil
end

_G.AuraUtil = {
    ForEachAura = function(unit, filter, maxCount, func, useAuraInstanceID)
        local u = getUnit(unit)
        if not u or not u.auras then return end
        local count = 0
        for _, aura in ipairs(u.auras) do
            local match = true
            if filter then
                if string.match(filter, "HELPFUL") and not aura.helpful then match = false end
                if string.match(filter, "HARMFUL") and not aura.harmful then match = false end
                if string.match(filter, "PLAYER") and aura.source ~= "player" then match = false end
            end
            if match then
                count = count + 1
                local result = func(aura.name, aura.icon, aura.count, aura.debuffType, aura.duration, aura.expirationTime, aura.source, aura.isStealable, aura.nameplateShowPersonal, aura.spellId)
                if result == true or (maxCount and count >= maxCount) then
                    break
                end
            end
        end
    end
}

function _G.UnitIsPlayer(unit)
    local u = getUnit(unit)
    return u and u.isPlayer or false
end

function _G.UnitIsDead(unit)
    local u = getUnit(unit)
    return u and (u.health and u.health <= 0 or u.isDead) or false
end

function _G.SetPortraitTexture(texture, unit)
    if texture and texture.SetTexture then
        texture:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    end
end

function _G.UnitClass(unit)
    local u = getUnit(unit)
    if not u then return nil, nil, 0 end
    return u.classLocal, u.class, u.classId
end

function _G.UnitGetTotalAbsorbs(unit)
    local u = getUnit(unit)
    return u and u.absorbs or 0
end

function _G.UnitHasPowerType(unit, powerType)
    local u = getUnit(unit)
    return u and u.powerType == powerType or false
end

function _G.UnitPowerType(unit)
    local u = getUnit(unit)
    return u and u.powerType or 0
end

-- Helpers to create test data
function Mocks.CreateTestUnit(unitId, data)
    Mocks.units[unitId] = data
    data.guid = data.guid or ("guid_" .. unitId)
end

function Mocks.CreateTestNameplate(unitId)
    local np = _G.CreateFrame("Frame", "NamePlate_" .. unitId)
    np.namePlateUnitToken = unitId
    np.UnitFrame = _G.CreateFrame("Frame", nil, np)
    -- Create an intermediate container so healthBar and castBar are
    -- grandchildren of UnitFrame (matches many real templates and allows
    -- Widgets.FindCastBar to locate castbars via GetChildren()/grandchildren).
    local container = _G.CreateFrame("Frame", nil, np.UnitFrame)
    np.UnitFrame.healthBar = _G.CreateFrame("StatusBar", nil, container)
    np.UnitFrame.castBar = _G.CreateFrame("StatusBar", nil, container)
    Mocks.nameplates[unitId] = np
    return np
end

_G.NamePlateDriverFrame = _G.CreateFrame("Frame", "NamePlateDriverFrame")
function _G.NamePlateDriverFrame:OnNamePlateAdded(unit) end
function _G.NamePlateDriverFrame:OnNamePlateRemoved(unit) end
function _G.CompactUnitFrame_UpdateHealthColor(frame) end

-- Fake player unit
Mocks.CreateTestUnit("player", {
    name = "Player",
    health = 100,
    healthMax = 100,
    level = 70,
    faction = "Alliance",
    isPlayer = true,
    class = "WARRIOR",
    classId = 1,
    guid = "player_guid",
})

return Mocks
