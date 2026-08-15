---@class addonTablePlatynator
local addonTable = select(2, ...)

local GetOtherTanks = addonTable.Display.Utilities.GetOtherTanks
local IsTank = addonTable.Display.Utilities.IsTankRole
local GetRangeChecker = addonTable.Display.Utilities.GetRangeSpell

local function IsInCombatWith(unit)
  return UnitAffectingCombat(unit) and
    (
      UnitIsFriend("player", unit) and UnitInParty(unit) == true or
      addonTable.Cache:Get(unit, "threat").situation ~= nil or
      UnitInParty(unit .. "target") == true
    )
end

-- For clients other than Midnight
if not C_Secrets or not C_Secrets.HasSecretRestrictions() then
  local frame = CreateFrame("Frame")
  frame:SetScript("OnEvent", function()
    local _, subevent, _, playerGUID, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
    if subevent == "SPELL_INTERRUPT" then
      addonTable.CallbackRegistry:TriggerEvent("LegacyInterrupter", playerGUID, destGUID)
    end
  end)
  frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

addonTable.Display.CacheMixin = {}

local getter = {
  ["cast"] = function(oldState, unit, eventName, ...)
    local new, state, timer = nil, false, nil
    if eventName == "UNIT_SPELLCAST_INTERRUPTED" then
      local _, _, interrupterGUID = ...
      new, state, timer = {cast = {}, channel = {}, interrupted = {guid = interrupterGUID, time = GetTime() * 1000}}, true, addonTable.Config.Get(addonTable.Config.Options.CAST_INTERRUPTED_TIMEOUT)
    elseif eventName == "UNIT_SPELLCAST_CHANNEL_STOP" then
      local _, _, interrupterGUID = ...
      new, state, timer = {cast = {}, channel = {}, interrupted = interrupterGUID and {guid = interrupterGUID, time = GetTime() * 1000} or nil}, true, interrupterGUID and addonTable.Config.Get(addonTable.Config.Options.CAST_INTERRUPTED_TIMEOUT) or nil
    elseif eventName == "UNIT_SPELLCAST_EMPOWER_STOP" then
      local _, _, _, interrupterGUID = ...
      new, state, timer = {cast = {}, channel = {}, interrupted = interrupterGUID and {guid = interrupterGUID, time = GetTime() * 1000} or nil}, true, interrupterGUID and addonTable.Config.Get(addonTable.Config.Options.CAST_INTERRUPTED_TIMEOUT) or nil
    elseif eventName == "UNIT_SPELLCAST_DELAYED" and next(oldState.cast) == nil or eventName == "UNIT_SPELLCAST_CHANNEL_UPDATE" and next(oldState.channel) == nil then
      new, state = {cast = {}, channel = {}, interrupted = nil}, false
    else
      new, state = {cast = {UnitCastingInfo(unit)}, channel = {UnitChannelInfo(unit)}, interrupted = nil}, true
    end
    -- Using approximated milliseconds to avoid rounding errors breaking the time comparison
    if oldState and oldState.interrupted and math.ceil(GetTime()*1000) - math.floor(oldState.interrupted.time) < addonTable.Config.Get(addonTable.Config.Options.CAST_INTERRUPTED_TIMEOUT) * 1000 and next(new.cast) == nil and next(new.channel) == nil then
      new.interrupted = oldState.interrupted
    end
    if addonTable.Constants.IsSecretsActive then
      if new.cast[1] then
        new.castDuration = UnitCastingDuration(unit)
      end
      if new.channel[9] then
        new.empoweredDuration = UnitEmpoweredChannelDuration(unit, true)
      elseif new.channel[1] then
        new.channelDuration = UnitChannelDuration(unit)
      end
    end

    if oldState then
      if not UnitAffectingCombat(unit) and next(new.cast) == nil and next(new.channel) == nil then
        new.hasCasted = nil
        new.hasUninterruptableCasted = nil
      else
        new.hasCasted = oldState.hasCasted
        new.hasUninterruptableCasted = oldState.hasUninterruptableCasted
      end
    end

    if new.cast[1] ~= nil or new.channel[1] ~= nil or new.interrupted ~= nil then
      new.hasCasted = true
    end
    local notInterruptible = new.cast[8]
    if notInterruptible == nil then
      notInterruptible = new.channel[7]
    end
    if notInterruptible ~= nil then
      if not issecretvalue or not issecretvalue(notInterruptible) then
        if notInterruptible == true then
          new.hasUninterruptableCasted = true
        end
      else
        new.hasUninterruptableCasted = notInterruptible
      end
    end

    return new, state, timer
  end,
  ["threat"] = function(oldState, unit)
    local result = {situation = UnitThreatSituation("player", unit), otherTankAggro = false}
    if result.situation ~= 3 and result.situation ~= 2 and IsTank() then
      for _, tankUnit in ipairs(GetOtherTanks()) do
        if UnitThreatSituation(tankUnit, unit) == 3 then
          result.otherTankAggro = true
          break
        end
      end
    end
    return result, not oldState or result.situation ~= oldState.situation or result.otherTankAggro ~= oldState.otherTankAggro
  end,
  ["range"] = function(oldState, unit)
    local result = addonTable.Display.Utilities.GetRangeChecker()(unit)
    return result, result ~= oldState
  end,
  ["combat"] = function(oldState, unit)
    local inCombat = IsInCombatWith(unit)
    return inCombat, inCombat ~= oldState
  end,
  ["canAttack"] = function(oldState, unit)
    local canAttack = UnitCanAttack("player", unit)
    return canAttack, canAttack ~= oldState
  end,
  ["target"] = function(oldState, unit)
    local target = UnitIsUnit("target", unit)
    return target, target ~= oldState
  end,
  ["softTarget"] = function(oldState, unit)
    local target = not UnitIsUnit("target", unit) and (UnitIsUnit("softenemy", unit) or UnitIsUnit("softfriend", unit))
    return target, target ~= oldState
  end,
  ["mouseover"] = function(oldState, unit)
    local mouseover = UnitIsUnit("mouseover", unit)
    return mouseover, mouseover ~= oldState
  end,
  ["focus"] = function(oldState, unit)
    local focus = UnitIsUnit("focus", unit)
    return focus, focus ~= oldState
  end,
}

local eventsFromKind = {
  ["cast"] = {
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_INTERRUPTIBLE",
    "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_UPDATE",
  },
  ["threat"] = {
    "UNIT_THREAT_LIST_UPDATE",
  },
}
if addonTable.Constants.IsRetail then
  tAppendAll(eventsFromKind["cast"], {
    "UNIT_SPELLCAST_EMPOWER_START",
    "UNIT_SPELLCAST_EMPOWER_STOP",
    "UNIT_SPELLCAST_EMPOWER_UPDATE",
  })
end
local eventToKind = {}
for kind, events in pairs(eventsFromKind) do
  for _, e in ipairs(events) do
    eventToKind[e] = kind
  end
end

function addonTable.Display.CacheMixin:OnLoad()
  self:SetScript("OnEvent", self.OnEvent)

  -- Unit records are the single ownership boundary for cache state. Event
  -- state and polled state are deliberately kept in different tables so a
  -- polling tick cannot accidentally mutate event-driven bookkeeping.
  self.units = {}
  self.monitoringOrder = {}
  self.pollingCount = 0
  self.step = 1
  self.totalElapsed = 0
  self.mouseoverMonitor = false
  self.mouseoverMonitorElapsed = 0
  self.castExpiryQueue = {}
  self.castExpiryCount = 0

  for event in pairs(eventToKind) do
    self:RegisterEvent(event)
  end
  self:RegisterEvent("PLAYER_TARGET_CHANGED")
  self:RegisterEvent("PLAYER_SOFT_ENEMY_CHANGED")
  self:RegisterEvent("PLAYER_SOFT_FRIEND_CHANGED")

  self:RegisterEvent("PLAYER_FOCUS_CHANGED")
  self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")

  addonTable.CallbackRegistry:RegisterCallback("LegacyInterrupter", function(_, playerGUID, destGUID)
    for unit, record in pairs(self.units) do
      if record.monitoring.cast and UnitGUID(unit) == destGUID then
        self:Process("cast", unit, "UNIT_SPELLCAST_INTERRUPTED", nil, nil, playerGUID)
      end
    end
  end)
end

local polledKinds = {
  range = true,
  combat = true,
  canAttack = true,
}

function addonTable.Display.CacheMixin:UpdatePollingDriver()
  if self.pollingCount > 0 or self.mouseoverMonitor or self.castExpiryCount > 0 then
    if self:GetScript("OnUpdate") == nil then
      self.totalElapsed = 0
      self:SetScript("OnUpdate", self.OnUpdate)
    end
  elseif self:GetScript("OnUpdate") ~= nil then
    self.totalElapsed = 0
    self:SetScript("OnUpdate", nil)
  end
end

local tablePool = {}

local function AcquireTable()
  local t = table.remove(tablePool)
  if t then
    wipe(t)
    return t
  end
  return {}
end

local function ReleaseTable(t)
  if t then
    wipe(t)
    table.insert(tablePool, t)
  end
end

function addonTable.Display.CacheMixin:AddUnit(unit)
  if self.units[unit] then
    return
  end
  local record = {
    monitoring = AcquireTable(),
    eventState = AcquireTable(),
    polledState = AcquireTable(),
    -- Callback lists are intentionally not part of the generic state pool.
    -- They contain closures owned by display widgets; pooling the container
    -- can make a recycled unit inherit another unit's listeners.
    callbacks = {},
  }
  self.units[unit] = record
  table.insert(self.monitoringOrder, unit)
  for kind in pairs(getter) do
    record.callbacks[kind] = {}
  end
end

function addonTable.Display.CacheMixin:RegisterCallback(unit, kind, callback)
  local record = self.units[unit]
  if record and record.callbacks[kind] then
    local callbacks = record.callbacks[kind]
    for index = 1, #callbacks do
      if callbacks[index] == callback then
        return false
      end
    end
    callbacks[#callbacks + 1] = callback
    return true
  end
  return false
end

function addonTable.Display.CacheMixin:RemoveCallback(unit, kind, callback)
  local record = self.units[unit]
  if not record or not record.callbacks[kind] then
    return false
  end

  local callbacks = record.callbacks[kind]
  local nextCallbacks = {}
  local removed = false
  for index = 1, #callbacks do
    local registered = callbacks[index]
    if registered ~= callback then
      nextCallbacks[#nextCallbacks + 1] = registered
    else
      removed = true
    end
  end

  if removed then
    record.callbacks[kind] = nextCallbacks
  end
  return removed
end

function addonTable.Display.CacheMixin:RemoveUnit(unit)
  local record = self.units[unit]
  if record then
    for kind in pairs(polledKinds) do
      if record.monitoring[kind] then
        self.pollingCount = self.pollingCount - 1
      end
    end
    ReleaseTable(record.monitoring)
    ReleaseTable(record.eventState)
    ReleaseTable(record.polledState)
    record.callbacks = nil
    self.units[unit] = nil
  end
  local index = tIndexOf(self.monitoringOrder, unit)
  if index then
    table.remove(self.monitoringOrder, index)
  end
  self:UpdatePollingDriver()
end

function addonTable.Display.CacheMixin:Get(unit, kind)
  local record = self.units[unit]
  if not record then
    return nil
  end
  local state = polledKinds[kind] and record.polledState or record.eventState
  if record.monitoring[kind] then
    return state[kind]
  else
    local newState = getter[kind](nil, unit)
    state[kind] = newState
    record.monitoring[kind] = true
    if polledKinds[kind] then
      self.pollingCount = self.pollingCount + 1
      self:UpdatePollingDriver()
    end
    return newState
  end
end

function addonTable.Display.CacheMixin:Process(kind, unit, eventName, ...)
  local record = self.units[unit]
  if not record or not record.monitoring[kind] then
    return
  end

  local data, update, timer = getter[kind](record.eventState[kind], unit, eventName, ...)
  if update then
    record.eventState[kind] = data
    local callbacks = record.callbacks[kind]
    for index = 1, #callbacks do
      callbacks[index](data)
    end
  end
  if timer then
    local expiry = self.castExpiryQueue[self.castExpiryCount + 1]
    if not expiry then
      expiry = {}
      self.castExpiryQueue[self.castExpiryCount + 1] = expiry
    end
    expiry.kind = kind
    expiry.unit = unit
    expiry.time = GetTime() + timer
    self.castExpiryCount = self.castExpiryCount + 1
    self:UpdatePollingDriver()
  end
end

function addonTable.Display.CacheMixin:UpdateMouseover()
  for unit, record in pairs(self.units) do
    if record.monitoring.mouseover then
      self:Process("mouseover", unit, "UPDATE_MOUSEOVER_UNIT")
    end
  end

  if UnitExists("mouseover") then
    if not self.mouseoverMonitor then
      self.mouseoverMonitor = true
      self.mouseoverMonitorElapsed = 0
      self:UpdatePollingDriver()
    end
  elseif self.mouseoverMonitor then
    self.mouseoverMonitor = false
    self.mouseoverMonitorElapsed = 0
    self:UpdatePollingDriver()
    if IsMouseButtonDown() then -- Holding down the mouse button will remove the mouseover unit temporarily
      self:RegisterEvent("GLOBAL_MOUSE_UP")
    end
  end
end

function addonTable.Display.CacheMixin:OnEvent(eventName, unit, ...)
  if eventName == "PLAYER_TARGET_CHANGED" or eventName == "PLAYER_SOFT_FRIEND_CHANGED" or eventName == "PLAYER_SOFT_ENEMY_CHANGED" then
    for unit, record in pairs(self.units) do
      if record.monitoring.target then
        self:Process("target", unit, eventName, ...)
      end
      if record.monitoring.softTarget then
        self:Process("softTarget", unit, eventName, ...)
      end
    end
  elseif eventName == "UPDATE_MOUSEOVER_UNIT" or eventName == "GLOBAL_MOUSE_UP" then
    self:UnregisterEvent("GLOBAL_MOUSE_UP")
    self:UpdateMouseover()
  elseif eventName == "PLAYER_FOCUS_CHANGED" then
    for unit, record in pairs(self.units) do
      if record.monitoring.focus then
        self:Process("focus", unit, eventName, ...)
      end
    end
  else
    local kind = eventToKind[eventName]
    self:Process(kind, unit, eventName, ...)
  end
end

function addonTable.Display.CacheMixin:OnUpdate(elapsed)
  if self.castExpiryCount > 0 then
    local now = GetTime()
    local index = 1
    while index <= self.castExpiryCount do
      local expiry = self.castExpiryQueue[index]
      if expiry.time <= now then
        self:Process(expiry.kind, expiry.unit)
        expiry.kind = nil
        expiry.unit = nil
        expiry.time = nil
        local last = self.castExpiryQueue[self.castExpiryCount]
        self.castExpiryQueue[index] = last
        self.castExpiryQueue[self.castExpiryCount] = expiry
        self.castExpiryCount = self.castExpiryCount - 1
      else
        index = index + 1
      end
    end
    self:UpdatePollingDriver()
  end

  if self.mouseoverMonitor then
    self.mouseoverMonitorElapsed = self.mouseoverMonitorElapsed + elapsed
    if self.mouseoverMonitorElapsed >= 0.1 then
      self.mouseoverMonitorElapsed = 0
      if not UnitExists("mouseover") then
        self:UpdateMouseover()
      end
    end
  end

  local length = #self.monitoringOrder
  if length == 0 then
    return
  end
  if self.step > length then
    self.step = 1
  end
  self.totalElapsed = self.totalElapsed + elapsed
  if self.totalElapsed < 1 / 4 / length then
    return
  end
  local toProcess = self.totalElapsed * 4 * length
  self.totalElapsed = 0

  for i = self.step, math.min(length, self.step + toProcess - 1) do
    local unit = self.monitoringOrder[i]
    local record = self.units[unit]
    -- A unit may be removed by a callback during the same frame. Resolve the
    -- record at processing time instead of retaining stale state references.
    if record then
      local details = record.monitoring
      local state = record.polledState
      for kind in pairs(polledKinds) do
        if details[kind] then
          local data, update = getter[kind](state[kind], unit)
          state[kind] = data
          if update then
            local callbacks = record.callbacks[kind]
            for callbackIndex = 1, #callbacks do
              callbacks[callbackIndex](data)
            end
          end
        end
      end
    end
    self.step = self.step + 1
  end
end
