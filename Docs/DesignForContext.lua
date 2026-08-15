---@class addonTablePlatynator
local addonTable = select(2, ...)

local IsNeutral = addonTable.Display.Utilities.IsNeutralUnit
local IsInRelevantInstance = addonTable.Display.Utilities.IsInRelevantInstance
local GetEliteType = addonTable.Display.Utilities.GetEliteType
local GetDelveType = addonTable.Display.Utilities.GetDelveType
local IsTankRole = addonTable.Display.Utilities.IsTankRole

local IsPlayer
if UnitTreatAsPlayerForDisplay then
  IsPlayer = function(unit)
    return UnitIsPlayer(unit) or UnitTreatAsPlayerForDisplay(unit)
  end
else
  IsPlayer = function(unit)
    return UnitIsPlayer(unit)
  end
end

local IsMinion
if UnitIsMinion then
  IsMinion = function(unit)
    return UnitIsMinion(unit)
  end
else
  IsMinion = function(unit)
    return UnitIsOtherPlayersPet(unit) or UnitIsUnit(unit, "pet")
  end
end

local function IsNPC(unit)
  return not IsPlayer(unit) and not IsMinion(unit)
end

local function GetAlignment(unit)
  if IsNeutral(unit) then
    return "neutral"
  elseif UnitIsFriend("player", unit) then
    return "friend"
  else
    return "hostile"
  end
end

local assignmentsPossibilities = {
  ["can-attack"] = { frequent = true, updates = "canAttack", check = function(state) return state.canAttack end },
  ["cannot-attack"] = { frequent = true, updates = "canAttack", check = function(state) return not state.canAttack end },

  ["in-combat"] = { frequent = true, updates = "inCombat", check = function(state) return state.inCombat end },
  ["out-combat"] = { frequent = true, updates = "inCombat", check = function(state) return not state.inCombat end },

  ["friend"] = { updates = "alignment", check = function(state) return state.alignment == "friend" end},
  ["hostile"] = { updates = "alignment", check = function(state) return state.alignment == "hostile" end},
  ["neutral"] = { updates = "alignment", check = function(state) return state.alignment == "neutral" end},

  ["player"] = { check = function(state) return state.isPlayer end },
  ["npc"] = { check = function(state) return state.isNPC end },
  ["minion"] = { check = function(state) return state.isMinion end },

  ["class-rare"] = { updates = "classification", check = function(state) local c = state.classification; return c == "rare" or c == "rareelite" end },
  ["class-elite"] = { updates = "classification", check = function(state) local c = state.classification; return c == "elite" or c == "rareelite" end },
  ["class-worldboss"] = { updates = "classification", check = function(state) return state.classification == "worldboss" end },
  ["class-normal"] = { updates = "classification", check = function(state) return state.classification == "normal" end },
  ["class-minor"] = { updates = "classification", check = function(state) return state.classification == "minus" end },
  ["class-trivial"] = { updates = "classification", check = function(state) return state.classification == "trivial" end },

  ["loc-world"] = { check = function(state) return state.location == "world" end },
  ["loc-dungeon"] = { check = function(state) return state.location == "dungeon" end },
  ["loc-raid"] = { check = function(state) return state.location == "raid" end },
  ["loc-pvp"] = { check = function(state) return state.location == "pvp" end },
  ["loc-delve"] = { check = function(state) return state.location == "delve" end },

  ["elite-boss"] = { updates = "classification", check = function(state) return state.eliteType == "boss" end },
  ["elite-miniboss"] = { updates = "classification", check = function(state) return state.eliteType == "miniboss" end },
  ["elite-caster"] = { updates = "classification", check = function(state) return state.eliteType == "caster" end },
  ["elite-melee"] = { updates = "classification", check = function(state) return state.eliteType == "melee" end },
  ["elite-trivial"] = { updates = "classification", check = function(state) return state.eliteType == "trivial" end },

  ["delve-boss"] = { updates = "classification", check = function(state) return state.delveType == "boss" end },
  ["delve-elite"] = { updates = "classification", check = function(state) return state.delveType == "elite" end },
  ["delve-rare"] = { updates = "classification", check = function(state) return state.delveType == "rare" end },
  ["delve-caster"] = { updates = "classification", check = function(state) return state.delveType == "caster" end },
  ["delve-melee"] = { updates = "classification", check = function(state) return state.delveType == "melee" end },
  ["delve-trivial"] = { updates = "classification", check = function(state) return state.delveType == "trivial" end },
}

local location
local instanceTracker = CreateFrame("Frame")
instanceTracker:RegisterEvent("PLAYER_ENTERING_WORLD")
instanceTracker:RegisterEvent("ZONE_CHANGED_NEW_AREA")
instanceTracker:RegisterEvent("INSTANCE_GROUP_SIZE_CHANGED")
instanceTracker:SetScript("OnEvent", function()
  if not IsInRelevantInstance({dungeon = true, raid = true, pvp = true, delve = true}) then
    location = "world"
  elseif IsInRelevantInstance({dungeon = true}) then
    location = "dungeon"
  elseif IsInRelevantInstance({raid = true}) then
    location = "raid"
  elseif IsInRelevantInstance({pvp = true}) then
    location = "pvp"
  elseif IsInRelevantInstance({delve = true}) then
    location = "delve"
  end
end)

local function GenerateState(unit)
  local isMinion = IsMinion(unit)
  return {
    canAttack = addonTable.Cache:Get(unit, "canAttack"),
    inCombat = addonTable.Cache:Get(unit, "combat"),
    alignment = GetAlignment(unit),
    isPlayer = IsPlayer(unit),
    isNPC = IsNPC(unit),
    isMinion = isMinion,
    classification = UnitClassification(unit),
    location = location,
    eliteType = GetEliteType(unit),
    delveType = GetDelveType(unit),

    updates = {},
  }
end

addonTable.Display.DesignForContextMixin = {}
function addonTable.Display.DesignForContextMixin:OnLoad()
  addonTable.CallbackRegistry:RegisterCallback("CustomiseDesignsAssigned", function()
    addonTable.CallbackRegistry:TriggerEvent("RefreshStateChange", {[addonTable.Constants.RefreshReason.DesignSelection] = true})
    local units = GetKeysArray(self.unitStates)
    for _, u in ipairs(units) do
      addonTable.CallbackRegistry:TriggerEvent("UnitDesignChange", u)
    end
  end)

  self.unitStates = {}
  self.unitsListening = {}

  self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
  self:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
  self:SetScript("OnEvent", self.OnEvent)
end

function addonTable.Display.DesignForContextMixin:EnsureUnitState(unit)
  local state = self.unitStates[unit]
  if not state then
    state = GenerateState(unit)
    self.unitStates[unit] = state
  end

  return state
end

function addonTable.Display.DesignForContextMixin:OnEvent(event, unit)
  if event == "UNIT_CLASSIFICATION_CHANGED" then
    if self.unitStates[unit] then
      local changes = self.unitStates[unit].updates.classification
      self.unitStates[unit].classification = UnitClassification(unit)
      if changes then
        addonTable.CallbackRegistry:TriggerEvent("UnitDesignChange", unit)
      end
    end
  elseif event == "UNIT_FACTION" then
    if self.unitStates[unit] then
      local changes = self.unitStates[unit].updates.alignment
      self.unitStates[unit].alignment = GetAlignment(unit)
      if changes then
        addonTable.CallbackRegistry:TriggerEvent("UnitDesignChange", unit)
      end
    end
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    self.unitStates[unit] = nil
    self.unitsListening[unit] = nil
  end
end

function addonTable.Display.DesignForContextMixin:RevokedUnitListeners(unit)
  self.unitsListening[unit] = nil
end

local function IsBoolTrue(val)
  if issecretvalue and issecretvalue(val) then
    return true
  end
  return val == true
end

local function ShouldUnsimplifyForThreat(unit, styleName)
  if not unit or UnitIsPlayer(unit) then return false end
  local threatDetails = addonTable.Cache:Get(unit, "threat")
  if not threatDetails then return false end

  local threat = threatDetails.situation
  local doesOtherTankHaveAggro = threatDetails.otherTankAggro
  local isTank = IsTankRole and IsTankRole() or false

  local design = addonTable.Core.GetDesignByName(styleName)
  if not design or not design.bars then return false end

  for _, bar in ipairs(design.bars) do
    if bar.kind == "health" and bar.autoColors then
      for _, s in ipairs(bar.autoColors) do
        if s.unsimplify then
          if s.kind == "threat" then
            local match = (isTank and (threat == 0 or threat == nil) and (not s.useOffTankColor or not doesOtherTankHaveAggro)) or (not isTank and threat == 3)
            if match then return true end
          elseif s.kind == "threatIgnoreRole" then
            if threat == 3 then return true end
          end
        end
      end
    end
  end

  return false
end

local function ShouldUnsimplifyForCast(unit, styleName)
  if not unit then return false end
  local cacheInfo = addonTable.Cache:Get(unit, "cast")
  if not cacheInfo then return false end

  local isDead = UnitIsDeadOrGhost(unit)
  local isCastingNow = cacheInfo.cast[1] ~= nil or cacheInfo.channel[1] ~= nil or cacheInfo.interrupted ~= nil
  local castInfo = cacheInfo.cast
  local channelInfo = cacheInfo.channel
  local uninterruptable = castInfo[8]
  if uninterruptable == nil then
    uninterruptable = channelInfo[7]
  end

  local design = addonTable.Core.GetDesignByName(styleName)
  if not design or not design.bars then return false end

  for _, bar in ipairs(design.bars) do
    if bar.kind == "health" and bar.autoColors then
      for _, s in ipairs(bar.autoColors) do
        if s.unsimplify then
          if s.kind == "isCast" then
            local match = isCastingNow or (s.persistent and cacheInfo.hasCasted and not isDead)
            if match then return true end
          elseif s.kind == "uninterruptableCast" then
            local match = (uninterruptable ~= nil) or (s.persistent and IsBoolTrue(cacheInfo.hasUninterruptableCasted) and not isDead)
            if match then return true end
          end
        end
      end
    end
  end

  return false
end

function addonTable.Display.DesignForContextMixin:GetAssignedDesign(unit)
  local state = self:EnsureUnitState(unit)
  if not self.unitsListening[unit] then
    addonTable.Cache:RegisterCallback(unit, "combat", function(inCombat)
      local state = self.unitStates[unit]
      if state then
        state.inCombat = inCombat
        if state.updates.inCombat then
          addonTable.CallbackRegistry:TriggerEvent("UnitDesignChange", unit)
        end
      end
    end)
    addonTable.Cache:RegisterCallback(unit, "canAttack", function(canAttack)
      local state = self.unitStates[unit]
      if state then
        state.canAttack = canAttack
        if state.updates.canAttack then
          addonTable.CallbackRegistry:TriggerEvent("UnitDesignChange", unit)
        end
      end
    end)
    addonTable.Cache:RegisterCallback(unit, "threat", function()
      local state = self.unitStates[unit]
      if state then
        addonTable.CallbackRegistry:TriggerEvent("UnitDesignChange", unit)
      end
    end)
    self.unitsListening[unit] = true
  end

  wipe(state.updates)

  return self:GetDesignFromState(state, unit)
end

function addonTable.Display.DesignForContextMixin:GetDefaultEnemyNPCDesign()
  return self:GetDesignFromState({
    canAttack = true,
    inCombat = true,
    alignment = "hostile",
    isPlayer = false,
    isNPC = true,
    isMinion = false,
    classification = "normal",
    location = "world",
    eliteType = "trivial",
    delveType = "melee",

    updates = {},
  })
end

function addonTable.Display.DesignForContextMixin:GetDefaultFriendlyPlayerDesign()
  return self:GetDesignFromState({
    canAttack = false,
    inCombat = false,
    alignment = "friend",
    isPlayer = true,
    isNPC = false,
    isMinion = false,
    classification = "normal",
    location = "dungeon",
    eliteType = nil,
    delveType = nil,

    updates = {},
  })
end

function addonTable.Display.DesignForContextMixin:GetDesignFromState(state, unit)
  local assignments = addonTable.Config.Get(addonTable.Config.Options.DESIGN_ASSIGNMENTS)
  for index, settings in ipairs(assignments) do
    local hit = true
    for _, criteria in ipairs(settings.criteria) do
      local details = assignmentsPossibilities[criteria]
      if details.updates then
        state.updates[details.updates] = true
      end
      if not details.check(state) then
        hit = false
        break
      end
    end

    if hit and (addonTable.Constants.IsSimplifiedAvailable or not settings.simplified) then
      local shouldSimplify = settings.simplified or false
      if shouldSimplify and unit and (ShouldUnsimplifyForCast(unit, settings.style) or ShouldUnsimplifyForThreat(unit, settings.style)) then
        shouldSimplify = false
      end
      return settings.style, settings.scale, shouldSimplify, index
    end
  end

  return "_deer", 1, false, 0
end
