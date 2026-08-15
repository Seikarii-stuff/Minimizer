---@class addonTablePlatynator
local addonTable = select(2, ...)

local IsTapped = addonTable.Display.Utilities.IsTappedUnit
local IsNeutral = addonTable.Display.Utilities.IsNeutralUnit
local IsUnfriendly = addonTable.Display.Utilities.IsUnfriendlyUnit
local IsInCombatWith = addonTable.Display.Utilities.IsInCombatWith

local GetInterruptSpells = addonTable.Display.Utilities.GetInterruptSpells

local transparency = {r = 1, g = 1, b = 1, a = 0}

local IsTankRole = addonTable.Display.Utilities.IsTankRole
local GetEliteType = addonTable.Display.Utilities.GetEliteType
local GetDelveType = addonTable.Display.Utilities.GetDelveType

local roleMap = {
  TANK = "tank",
  HEALER = "healer",
  DAMAGER = "damage",
  NONE = "damage",
}

local inRelevantThreatInstance, inRelevantEliteInstance, inRelevantDelveInstance = false, false, false

-- Checking for party members below the player's level which indicates the mobs will be shifted down one
-- Except when the dungeon is already at its minimum level, in which case the level won't shift.
local instanceTracker = CreateFrame("Frame")
instanceTracker:RegisterEvent("PLAYER_ENTERING_WORLD")
instanceTracker:RegisterEvent("PLAYER_LEVEL_UP")
instanceTracker:RegisterEvent("ZONE_CHANGED_NEW_AREA")
instanceTracker:RegisterEvent("INSTANCE_GROUP_SIZE_CHANGED")
instanceTracker:SetScript("OnEvent", function(_, event)
  inRelevantThreatInstance = addonTable.Display.Utilities.IsInRelevantInstance({dungeon = true, raid = true, delve = true, pvp = true})
  inRelevantEliteInstance = addonTable.Display.Utilities.IsInRelevantInstance({dungeon = true, raid = true})
  inRelevantDelveInstance = addonTable.Display.Utilities.IsInRelevantInstance({delve = true})
end)

local kindToEvent = {
  reaction = {"UNIT_FACTION"},
  tapped = {"UNIT_HEALTH"},
  execute = {"UNIT_HEALTH"},
  eliteType = {"UNIT_CLASSIFICATION_CHANGED", "UNIT_FACTION"},
  rarity = {"UNIT_CLASSIFICATION_CHANGED"},
  delveType = {"UNIT_CLASSIFICATION_CHANGED", "UNIT_FACTION"},
  party = {"GROUP_ROSTER_UPDATE"},
  isCast = {"UNIT_HEALTH"},
  uninterruptableCast = {"UNIT_HEALTH"},
}
local kindToCallback = {
  quest = {"QuestInfoUpdate"},
  threat = {"RoleChange"},
}
local kindToCache = {
  threat = {"combat", "threat"},
  threatIgnoreRole = {"combat", "threat"},
  inCombat = {"combat"},
  interruptReady = {"cast"},
  interruptNotReady = {"cast"},
  uninterruptableCast = {"cast"},
  castTargetsYou = {"cast"},
  importantCast = {"cast"},
  cast = {"cast"},
  notCast = {"cast"},
  isCast = {"cast"},
  inRange = {"range"},
  outOfRange = {"range"},
  target = {"target"},
  notTarget = {"target"},
  softTarget = {"softTarget"},
  mouseover = {"target", "mouseover"},
  notMouseover = {"target", "mouseover"},
  focus = {"focus"},
}

local UnitIsPlayer = UnitIsPlayer
local UnitTreatAsPlayerForDisplay = UnitTreatAsPlayerForDisplay
local UnitCanAttack = UnitCanAttack
local UnitIsEnemy = UnitIsEnemy
local UnitIsFriend = UnitIsFriend
local UnitClassification = UnitClassification
local UnitClass = UnitClass
local UnitIsUnit = UnitIsUnit
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitPowerType = UnitPowerType
local UnitInParty = UnitInParty
local GetGuildInfo = GetGuildInfo
local issecretvalue = issecretvalue
local C_CurveUtil = C_CurveUtil
local C_ClassColor = C_ClassColor
local C_Spell = C_Spell
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local ipairs = ipairs
local pairs = pairs

local forcedUpdates = table.create(0, 40)
local forcedUpdateDriver = CreateFrame("Frame")
local forcedUpdateElapsed = 0
local FORCED_UPDATE_INTERVAL = 0.1
local forcedUpdateCount = 0

local function OnForcedUpdate(_, elapsed)
  forcedUpdateElapsed = forcedUpdateElapsed + elapsed
  if forcedUpdateElapsed >= FORCED_UPDATE_INTERVAL then
    forcedUpdateElapsed = 0
    for frame in pairs(forcedUpdates) do
      frame:ColorEventHandler("FORCED")
    end
  end
end

local function UpdateForcedUpdateTicker()
  if forcedUpdateCount > 0 then
    if forcedUpdateDriver:GetScript("OnUpdate") == nil then
      forcedUpdateElapsed = 0
      forcedUpdateDriver:SetScript("OnUpdate", OnForcedUpdate)
    end
  elseif forcedUpdateDriver:GetScript("OnUpdate") ~= nil then
    forcedUpdateElapsed = 0
    forcedUpdateDriver:SetScript("OnUpdate", nil)
  end
end

local function SetFrequentUpdate(frame, enabled)
  if enabled then
    if forcedUpdates[frame] == nil then
      forcedUpdates[frame] = true
      forcedUpdateCount = forcedUpdateCount + 1
      UpdateForcedUpdateTicker()
    end
  elseif forcedUpdates[frame] then
    forcedUpdates[frame] = nil
    forcedUpdateCount = forcedUpdateCount - 1
    UpdateForcedUpdateTicker()
  end
end

function addonTable.Display.UnregisterForColorEvents(frame)
  if frame.colorState then
    for _, e in ipairs(frame.colorState.callbacks) do
      addonTable.CallbackRegistry:UnregisterCallback(e, frame.colorState)
    end
    SetFrequentUpdate(frame, false)
  end

  frame.ColorEventHandler = nil
  frame.colorState = nil
end

function addonTable.Display.RegisterForColorEvents(frame, settings, defaultColor)
  local events = { FORCED = true }
  frame.colorState = {
    frequentUpdater = {},
    isPlayer = UnitIsPlayer(frame.unit) or UnitTreatAsPlayerForDisplay and UnitTreatAsPlayerForDisplay(frame.unit),
    hostile = UnitCanAttack("player", frame.unit) and UnitIsEnemy(frame.unit, "player"),
    callbacks = {},
    caches = {},
  }
  frame.colorState.defaultColor = defaultColor or transparency
  for _, s in ipairs(settings) do
    local es = kindToEvent[s.kind]
    if es then
      for _, e in ipairs(es) do
        events[e] = true
        if C_EventUtils.IsEventValid(e) then
          if e:match("^UNIT") then
            frame:RegisterUnitEvent(e, frame.unit)
          else
            frame:RegisterEvent(e)
          end
        end
      end
    end
    local ec = kindToCallback[s.kind]
    if ec then
      for _, e in ipairs(ec) do
        table.insert(frame.colorState.callbacks, e)
        addonTable.CallbackRegistry:RegisterCallback(e, function()
          frame:SetColor(addonTable.Display.GetColor(settings, frame.colorState, frame.unit))
        end, frame.colorState)
      end
    end
    local cc = kindToCache[s.kind]
    if cc then
      for _, c in ipairs(cc) do
        if not frame.colorState.caches[c] then
          frame.colorState.caches[c] = true
          addonTable.Cache:RegisterCallback(frame.unit, c, function()
            if frame.unit then -- Shield against deactivation of the widget
              frame:ColorEventHandler("FORCED")
            end
          end)
        end
      end
    end
  end

  function frame:ColorEventHandler(eventName)
    if events[eventName] then
      self:SetColor(addonTable.Display.GetColor(settings, self.colorState, self.unit))
      if next(self.colorState.frequentUpdater) then
        SetFrequentUpdate(self, true)
      else
        SetFrequentUpdate(self, false)
      end
    end
  end

  -- Set the color at least once
  frame:ColorEventHandler("FORCED")
end

local function SplitEvaluate(state, r1, g1, b1, a1, r2, g2, b2, a2)
  return C_CurveUtil.EvaluateColorValueFromBoolean(state, r1, r2),
    C_CurveUtil.EvaluateColorValueFromBoolean(state, g1, g2),
    C_CurveUtil.EvaluateColorValueFromBoolean(state, b1, b2),
    C_CurveUtil.EvaluateColorValueFromBoolean(state, a1 or 1, a2 or 1)
end

local function PrepareColorQueue(state)
  local colorQueue = state.colorQueue
  if not colorQueue then
    colorQueue = {}
    state.colorQueue = colorQueue
    colorQueue.entries = {}
  end
  colorQueue.count = 0
  return colorQueue
end

local function PrepareEvaluationCache(state)
  local evaluationCache = state.colorEvaluationCache
  if not evaluationCache then
    evaluationCache = {
      values = {},
      version = {},
      generation = 0,
    }
    state.colorEvaluationCache = evaluationCache
  end
  evaluationCache.generation = evaluationCache.generation + 1
  return evaluationCache
end

local function GetEvaluationCache(evaluationCache, unit, kind)
  if evaluationCache.version[kind] ~= evaluationCache.generation then
    evaluationCache.values[kind] = addonTable.Cache:Get(unit, kind)
    evaluationCache.version[kind] = evaluationCache.generation
  end
  return evaluationCache.values[kind]
end

local function PushColor(colorQueue, color)
  local index = colorQueue.count + 1
  colorQueue.count = index
  local entry = colorQueue.entries[index]
  if not entry then
    entry = {}
    colorQueue.entries[index] = entry
  end
  entry.state = nil
  entry.color = color
  colorQueue[index] = entry
end

local function PushStateColor(colorQueue, color)
  local index = colorQueue.count + 1
  colorQueue.count = index
  local entry = colorQueue.entries[index]
  if not entry then
    entry = {conditions = {}, conditionEntries = {}}
    colorQueue.entries[index] = entry
  end
  entry.conditions = entry.conditions or {}
  entry.conditionEntries = entry.conditionEntries or {}
  local state = entry.conditions
  for conditionIndex = #state, 1, -1 do
    state[conditionIndex] = nil
  end
  entry.state = state
  entry.color = color
  colorQueue[index] = entry
  return entry
end

local function PushCondition(entry, value, invert)
  local index = #entry.state + 1
  local condition = entry.conditionEntries[index]
  if not condition then
    condition = {}
    entry.conditionEntries[index] = condition
  end
  condition.value = value
  condition.invert = invert
  entry.state[index] = condition
end

function addonTable.Display.GetColor(settings, state, unit)
  local colorQueue = PrepareColorQueue(state)
  local evaluationCache = PrepareEvaluationCache(state)
  for _, s in ipairs(settings) do
    if s.kind == "tapped" then
      if IsTapped(unit) then
        PushColor(colorQueue, s.colors.tapped)
        break
      end
    elseif s.kind == "target" then
      if GetEvaluationCache(evaluationCache, unit, "target") then
        PushColor(colorQueue, s.colors.target)
        break
      end
    elseif s.kind == "notTarget" then
      if not GetEvaluationCache(evaluationCache, unit, "target") then
        PushColor(colorQueue, s.colors.notTarget)
        break
      end
    elseif s.kind == "softTarget" then
      if GetEvaluationCache(evaluationCache, unit, "softTarget") then
        PushColor(colorQueue, s.colors.softTarget)
        break
      end
    elseif s.kind == "focus" then
      if GetEvaluationCache(evaluationCache, unit, "focus") then
        PushColor(colorQueue, s.colors.focus)
        break
      end
    elseif s.kind == "mouseover" then
      if GetEvaluationCache(evaluationCache, unit, "mouseover") and (s.includeTarget or not GetEvaluationCache(evaluationCache, unit, "target")) then
        PushColor(colorQueue, s.colors.mouseover)
        break
      end
    elseif s.kind == "notMouseover" then
      if not (GetEvaluationCache(evaluationCache, unit, "mouseover") and (s.includeTarget or not GetEvaluationCache(evaluationCache, unit, "target"))) then
        PushColor(colorQueue, s.colors.notMouseover)
        break
      end
    elseif s.kind == "threat" then
      local threatDetails = GetEvaluationCache(evaluationCache, unit, "threat")
      local threat = threatDetails.situation
      local doesOtherTankHaveAggro = threatDetails.otherTankAggro
      local hostile = state.hostile
      local isTank = IsTankRole()
      if not state.isPlayer and (inRelevantThreatInstance or not s.instancesOnly) and (threat or (hostile and not s.combatOnly) or IsInCombatWith(unit)) and (not s.tanksOnly or isTank) then
        if (isTank and (threat == 0 or threat == nil) and (not s.useOffTankColor or not doesOtherTankHaveAggro)) or (not isTank and threat == 3) then
          PushColor(colorQueue, s.colors.warning)
          break
        elseif threat == 1 or threat == 2 then
          PushColor(colorQueue, s.colors.transition)
          break
        elseif s.useSafeColor and ((isTank and threat == 3) or (not isTank and (threat == 0 or threat == nil))) then
          PushColor(colorQueue, s.colors.safe)
          break
        elseif s.useOffTankColor and isTank and (threat == 0 or threat == nil) and doesOtherTankHaveAggro then
          PushColor(colorQueue, s.colors.offtank)
          break
        end
      end
    elseif s.kind == "threatIgnoreRole" then
      local threatDetails = GetEvaluationCache(evaluationCache, unit, "threat")
      local threat = threatDetails.situation
      local hostile = state.hostile
      local isTank = IsTankRole()
      if not state.isPlayer and (inRelevantThreatInstance or not s.instancesOnly) and (threat or (hostile and not s.combatOnly) or IsInCombatWith(unit)) and (not s.tanksOnly or isTank) then
        if threat == 3 then
          PushColor(colorQueue, s.colors.hasThreat)
          break
        elseif threat == 1 or threat == 2 then
          PushColor(colorQueue, s.colors.transition)
          break
        elseif s.useNoThreatColor then
          PushColor(colorQueue, s.colors.noThreat)
          break
        end
      end
    elseif s.kind == "rarity" then
      local classification = UnitClassification(unit)

      if classification == "rare" then
        PushColor(colorQueue, s.colors.rare)
      elseif classification == "rareelite" then
        PushColor(colorQueue, s.colors.rareElite)
      end
    elseif s.kind == "eliteType" then
      if (inRelevantEliteInstance or not s.instancesOnly) and not addonTable.Display.Utilities.IsNeutralUnit(unit) then
        local t = GetEliteType(unit, s.applyCasterAlways)
        if t and s.enabled[t] then
          PushColor(colorQueue, s.colors[t])
          break
        end
      end
    elseif s.kind == "delveType" then
      if (inRelevantDelveInstance and s.delves or not inRelevantThreatInstance and s.outsideInstances) and not addonTable.Display.Utilities.IsNeutralUnit(unit) then
        local t = GetDelveType(unit)
        if t and s.enabled[t] then
          PushColor(colorQueue, s.colors[t])
          break
        end
      end
    elseif s.kind == "quest" then
      if #addonTable.Display.Utilities.GetQuestInfo(unit) > 0 then
        if IsNeutral(unit) then
          PushColor(colorQueue, s.colors.neutral)
          break
        elseif UnitIsFriend("player", unit) then
          PushColor(colorQueue, s.colors.friendly)
          break
        else
          PushColor(colorQueue, s.colors.hostile)
          break
        end
      end
    elseif s.kind == "guild" then
      if UnitIsPlayer(unit) then
        local playerGuild, _, _, playerRealm = GetGuildInfo("player")
        local unitGuild, _, _, unitRealm = GetGuildInfo(unit)
        if playerGuild ~= nil and playerGuild == unitGuild and playerRealm == unitRealm then
          PushColor(colorQueue, s.colors.guild)
          break
        end
      end
    elseif s.kind == "classColors" then
      if state.isPlayer then
        local _, class = UnitClass(unit)
        if issecretvalue(class) then
          local color = C_ClassColor.GetClassColor(class)
          if s.colors.class then
            color.a = s.colors.class.a
          end
          PushColor(colorQueue, color)
        else
          PushColor(colorQueue, s.colors[class] or RAID_CLASS_COLORS[class])
        end
        break
      end
    elseif s.kind == "reaction" then
      if IsNeutral(unit) then
        PushColor(colorQueue, s.colors.neutral)
      elseif IsUnfriendly(unit) then
        PushColor(colorQueue, s.colors.unfriendly)
      elseif UnitIsFriend("player", unit) and not UnitCanAttack("player", unit) then
        PushColor(colorQueue, s.colors.friendly)
      else
        PushColor(colorQueue, s.colors.hostile)
      end
      break
    elseif s.kind == "difficulty" then
      PushColor(colorQueue, s.colors[addonTable.Display.Utilities.GetUnitDifficulty(unit)])
      break
    elseif s.kind == "interruptReady" then
      local cacheInfo = GetEvaluationCache(evaluationCache, unit, "cast")
      local castInfo = cacheInfo.cast
      local channelInfo = cacheInfo.channel
      local notInterruptible = castInfo[8]
      if notInterruptible == nil then
        notInterruptible = channelInfo[7]
      end
      state.frequentUpdater.interruptReady = nil
      if castInfo[1] or channelInfo[1] then
        if notInterruptible == nil then
          notInterruptible = false
        end
        local interruptSpells = GetInterruptSpells()
        state.frequentUpdater.interruptReady = true
        if C_Spell.GetSpellCooldownDuration then
          for _, spellID in ipairs(interruptSpells) do
            local duration = C_Spell.GetSpellCooldownDuration(spellID)
            local entry = PushStateColor(colorQueue, s.colors.ready)
            PushCondition(entry, duration:IsZero())
            PushCondition(entry, notInterruptible, true)
          end
        elseif notInterruptible ~= true then
          local any = false
          for _, spellID in ipairs(interruptSpells) do
            local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
            if cooldownInfo.startTime == 0 then
              any = true
              PushColor(colorQueue, s.colors.ready)
              break
            end
          end
          if any then
            break
          end
        end
      end
    elseif s.kind == "interruptNotReady" then
      local cacheInfo = GetEvaluationCache(evaluationCache, unit, "cast")
      local castInfo = cacheInfo.cast
      local channelInfo = cacheInfo.channel
      local notInterruptible = castInfo[8]
      if notInterruptible == nil then
        notInterruptible = channelInfo[7]
      end
      state.frequentUpdater.interruptNotReady = nil
      if castInfo[1] or channelInfo[1] then
        if notInterruptible == nil then
          notInterruptible = false
        end
        local spells = GetInterruptSpells()
        if #spells > 0 then
          state.frequentUpdater.interruptNotReady = true
          if C_Spell.GetSpellCooldownDuration then
            local entry = PushStateColor(colorQueue, s.colors.notReady)
            PushCondition(entry, notInterruptible, true)
            for _, spellID in ipairs(spells) do
              local duration = C_Spell.GetSpellCooldownDuration(spellID)
              PushCondition(entry, duration:IsZero(), true)
            end
          elseif notInterruptible ~= true then
            local any = false
            for _, spellID in ipairs(spells) do
              local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
              if cooldownInfo.startTime == 0 then
                any = true
                break
              end
            end
            if not any then
              PushColor(colorQueue, s.colors.notReady)
              break
            end
          end
        end
      end
    elseif s.kind == "castTargetsYou" then
      local cacheInfo = GetEvaluationCache(evaluationCache, unit, "cast")
      local castInfo = cacheInfo.cast
      local channelInfo = cacheInfo.channel
      local name = castInfo[1]
      if name == nil then
        name = channelInfo[1]
      end
      if name ~= nil then
        if UnitIsSpellTarget then
          local entry = PushStateColor(colorQueue, s.colors.targeted)
          PushCondition(entry, UnitIsSpellTarget(unit, "player"))
        elseif UnitIsUnit(unit .. "target", "player") then
          PushColor(colorQueue, s.colors.targeted)
          break
        end
      end
    elseif s.kind == "uninterruptableCast" then
      local cacheInfo = GetEvaluationCache(evaluationCache, unit, "cast")
      local castInfo = cacheInfo.cast
      local channelInfo = cacheInfo.channel
      local uninterruptable = castInfo[8]
      if uninterruptable == nil then
        uninterruptable = channelInfo[7]
      end
      if s.persistent and cacheInfo.hasUninterruptableCasted ~= nil and not UnitIsDeadOrGhost(unit) then
        local entry = PushStateColor(colorQueue, s.colors.uninterruptable)
        PushCondition(entry, cacheInfo.hasUninterruptableCasted)
      elseif uninterruptable ~= nil then
        local entry = PushStateColor(colorQueue, s.colors.uninterruptable)
        PushCondition(entry, uninterruptable)
      end
    elseif s.kind == "importantCast" then
      if C_Spell.IsSpellImportant then
        local cacheInfo = GetEvaluationCache(evaluationCache, unit, "cast")
        local castInfo = cacheInfo.cast
        local channelInfo = cacheInfo.channel
        local spellID = castInfo[9]
        local isChannel = false
        if spellID == nil then
          spellID = channelInfo[8]
          isChannel = true
        end
        if spellID ~= nil then
          local isImportant = C_Spell.IsSpellImportant(spellID)
          if isChannel then
            local entry = PushStateColor(colorQueue, s.colors.channel)
            PushCondition(entry, isImportant)
          else
            local entry = PushStateColor(colorQueue, s.colors.cast)
            PushCondition(entry, isImportant)
          end
        end
      end
    elseif s.kind == "cast" then
      local cacheInfo = GetEvaluationCache(evaluationCache, unit, "cast")
      local castInfo = cacheInfo.cast
      local channelInfo = cacheInfo.channel
      local text = castInfo[1]
      local isChannel, isEmpowered = false, false
      if text == nil then
        text = channelInfo[1]
        isChannel = true
        isEmpowered = channelInfo[9]
      end
      if text ~= nil then
        PushColor(colorQueue, isEmpowered and s.colors.empowered or isChannel and s.colors.channel or s.colors.cast)
        break
      elseif cacheInfo.interrupted then
        PushColor(colorQueue, s.colors.interrupted)
        break
      end
    elseif s.kind == "notCast" then
      local cacheInfo = GetEvaluationCache(evaluationCache, unit, "cast")
      local castInfo = cacheInfo.cast
      local channelInfo = cacheInfo.channel
      if castInfo[1] == nil and channelInfo[1] == nil and cacheInfo.interrupted == nil then
        PushColor(colorQueue, s.colors.notCast)
        break
      end
    elseif s.kind == "isCast" then
      local cacheInfo = GetEvaluationCache(evaluationCache, unit, "cast")
      local castInfo = cacheInfo.cast
      local channelInfo = cacheInfo.channel
      local isCastingNow = castInfo[1] ~= nil or channelInfo[1] ~= nil or cacheInfo.interrupted ~= nil
      local isPersistentMatch = s.persistent and cacheInfo.hasCasted and not UnitIsDeadOrGhost(unit)
      if isCastingNow or isPersistentMatch then
        PushColor(colorQueue, s.colors.isCast)
        break
      end
    elseif s.kind == "fixed" then
      PushColor(colorQueue, s.colors.fixed)
      break
    elseif s.kind == "execute" then
      local executeRange = addonTable.Display.Utilities.GetExecuteRange()
      if executeRange > 0 and IsInCombatWith(unit) then
        if UnitHealthPercent then
          local curve = addonTable.Display.Utilities.GetExecuteCurve()
          curve:ClearPoints()
          curve:AddPoint(0, CreateColor(s.colors.execute.r ,s.colors.execute.g, s.colors.execute.b, s.colors.execute.a))
          curve:AddPoint(executeRange, CreateColor(s.colors.inCombat.r ,s.colors.inCombat.g, s.colors.inCombat.b, s.colors.inCombat.a))
          local color = UnitHealthPercent(unit, nil, curve)
          PushColor(colorQueue, color)
          break
        else
          local percent = UnitHealth(unit) / UnitHealthMax(unit)
          if percent <= executeRange then
            PushColor(colorQueue, s.colors.execute)
            break
          else
            PushColor(colorQueue, s.colors.inCombat)
          end
        end
      end
    elseif s.kind == "inCombat" then
      if IsInCombatWith(unit) then
        PushColor(colorQueue, s.colors.inCombat)
        break
      end
    elseif s.kind == "energy" then
      local kind = UnitPowerType(unit)
      local mapped = addonTable.Constants.PowerMap[kind]
      if s.colors[mapped] then
        PushColor(colorQueue, s.colors[mapped])
        break
      end
    elseif s.kind == "inRange" then
      local range = GetEvaluationCache(evaluationCache, unit, "range")
      if range then
        PushColor(colorQueue, s.colors.inRange)
        break
      end
    elseif s.kind == "outOfRange" then
      local range = GetEvaluationCache(evaluationCache, unit, "range")
      if not range then
        PushColor(colorQueue, s.colors.outOfRange)
        break
      end
    elseif s.kind == "party" then
      if UnitInParty(unit) then
        if UnitGroupRolesAssigned then
          local role = UnitGroupRolesAssigned(unit)
          if role then
            PushColor(colorQueue, s.colors[roleMap[role]])
            break
          end
        end

        PushColor(colorQueue, s.colors.damage)
        break
      end
    elseif s.kind == "myClassColor" then
      local _, class = UnitClass("player")
      PushColor(colorQueue, s.colors[class] or RAID_CLASS_COLORS[class])
    end
  end

  if colorQueue.count == 0 then
    return nil
  end

  local defaultColor = state.defaultColor
  if C_CurveUtil then
    local r, g, b, a = defaultColor.r, defaultColor.g, defaultColor.b, defaultColor.a or 1
    for index = colorQueue.count, 1, -1 do
      local details = colorQueue[index]
      local c = details.color
      if details.state == nil then
        r, g, b, a = c.r, c.g, c.b, c.a or 1
      else
        local r0, g0, b0, a0 = c.r, c.g, c.b, c.a
        for _, s in ipairs(details.state) do
          if s.invert then
            r0, g0, b0, a0 = SplitEvaluate(s.value, r, g, b, a, r0, g0, b0, a0)
          else
            r0, g0, b0, a0 = SplitEvaluate(s.value, r0, g0, b0, a0, r, g, b, a)
          end
        end
        r, g, b, a = r0, g0, b0, a0
      end
    end
    return r, g, b, a
  else
    local color = defaultColor
    for index = colorQueue.count, 1, -1 do
      local details = colorQueue[index]
      if details.state == nil then
        color = details.color
      else
        local color0 = details.color
        for _, s in ipairs(details.state) do
          if s.invert then
            color0 = s.value and color or color0
          else
            color0 = s.value and color0 or color
          end
        end
        color = color0
      end
    end

    return color.r, color.g, color.b, color.a or 1
  end
end
