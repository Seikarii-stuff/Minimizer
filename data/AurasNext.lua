---@class addonTablePlatynator
local addonTable = select(2, ...)

local LSM = LibStub("LibSharedMedia-3.0")

local auraFormatter = addonTable.Display.Utilities.GetAuraNumericFormatter()
local AuraLayoutCache = addonTable.Display.Auras.AuraLayoutCache
local AuraGroupBuilder = addonTable.Display.Auras.AuraGroupBuilder
local AuraSetupConfigBuilder = addonTable.Display.Auras.AuraSetupConfigBuilder

-- Immutable descriptors shared by all modern aura containers.
local candidateIMPORTANTDefault = {}
local candidateIMPORTANTNoEnrage = {excludeDispelTypes = {[""] = true}}
local candidateENRAGEDefault = {includeDispelTypes = {[""] = true}}
local candidateSTEALABLEDefault = {isStealable = true}
local candidateSTEALABLENoEnrage = {
  isStealable = true,
  excludeDispelTypes = {[""] = true},
}

function addonTable.Display.StyleAura(auraFrame, details)
  auraFrame.kind = details.kind

  auraFrame:EnableMouseMotion(details.showTooltips)

  auraFrame.CountFrame.Count:SetFontObject(addonTable.CurrentFont)
  auraFrame.CountFrame.Count:ClearAllPoints()
  addonTable.Display.ApplyAnchor(auraFrame.CountFrame.Count, details.texts.stacks.anchor, addonTable.CurrentFontUsesSmoothing and 1/details.texts.stacks.scale or 1)
  if addonTable.CurrentFontUsesSmoothing then
    auraFrame.CountFrame.Count:SetTextScale(1)
    auraFrame.CountFrame.Count:SetScale(details.texts.stacks.scale)
  else
    auraFrame.CountFrame.Count:SetTextScale(details.texts.stacks.scale)
    auraFrame.CountFrame.Count:SetScale(1)
  end
  local c1 = details.texts.stacks.color
  auraFrame.CountFrame.Count:SetTextColor(c1.r, c1.g, c1.b)
  auraFrame.CountFrame.Count:SetShown(details.texts.stacks.visible);

  auraFrame.Cooldown:SetHideCountdownNumbers(not details.texts.countdown.visible)

  if details.texts.countdown.visible then
    auraFrame.Cooldown.Text:SetFontObject(addonTable.CurrentFont)
    auraFrame.Cooldown.Text:ClearAllPoints()
    addonTable.Display.ApplyAnchor(auraFrame.Cooldown.Text, details.texts.countdown.anchor, addonTable.CurrentFontUsesSmoothing and 1/details.texts.countdown.scale or 1)
    if addonTable.CurrentFontUsesSmoothing then
      auraFrame.Cooldown.Text:SetTextScale(1)
      auraFrame.Cooldown.Text:SetScale(details.texts.countdown.scale)
    else
      auraFrame.Cooldown.Text:SetTextScale(details.texts.countdown.scale)
      auraFrame.Cooldown.Text:SetScale(1)
    end
    local c2 = details.texts.countdown.color
    auraFrame.Cooldown.Text:SetTextColor(c2.r, c2.g, c2.b)
    if addonTable.Constants.IsCooldownFormattingAvailable then
      if details.texts.countdown.showFractions then
        auraFrame.Cooldown:SetCountdownFormatter(auraFormatter)
      else
        auraFrame.Cooldown:SetCountdownFormatter(nil)
        auraFrame.Cooldown:SetCountdownAbbrevThreshold(20)
      end
    end
  end

  if auraFrame.CountFrame.Count.SetSmoothScaling then
    auraFrame.CountFrame.Count:SetSmoothScaling(addonTable.CurrentFontUsesSmoothing)
    auraFrame.Cooldown.Text:SetSmoothScaling(addonTable.CurrentFontUsesSmoothing)
  end

  auraFrame.Cooldown:SetDrawEdge(details.showSwipe)
  auraFrame.Cooldown:SetDrawSwipe(details.showSwipe)

  PixelUtil.SetSize(auraFrame, 20, 20 * details.height)
  PixelUtil.SetSize(auraFrame.Border, 20, 20 * details.height)
  PixelUtil.SetSize(auraFrame.Icon, 20, 20 * details.height)
  local texBase = 0.95 * (1 - details.height) / 2
  auraFrame.Icon:SetTexCoord(0.05, 0.95, 0.05 + texBase, 0.95 - texBase)

  auraFrame.Dispel:SetShown(details.showType)
end

local function GetAurasInitializerModern(container)
  local borderAsset = LSM:Fetch("nineslice", "Platy: 1px")
  local dispelAsset = LSM:Fetch("nineslice", "Platy: 4px")
  return function(frame)
    table.insert(container.frames, frame)
    frame:SetFlattensRenderLayers(true)
    frame:SetSize(20, 20)
    frame.Icon = frame:CreateTexture(nil, "ARTWORK")
    frame.Icon:SetSize(20, 20)
    frame.Icon:SetPoint("CENTER")
    frame.Cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.Cooldown:SetDrawBling(false)
    frame.Cooldown:SetHideCountdownNumbers(false)
    frame.Cooldown:SetDrawEdge(true)
    frame.Cooldown:SetReverse(true)
    frame.CountFrame = CreateFrame("Frame", nil, frame)
    frame.CountFrame:SetAllPoints()
    frame.CountFrame:SetFrameLevel(500)
    frame.CountFrame.Count = frame.CountFrame:CreateFontString(nil, nil, "GameFontHighlight")
    frame.CountFrame.Count:SetPoint("BOTTOMRIGHT", 3, -2)

    frame.Border = frame:CreateTexture(nil, "OVERLAY")
    frame.Border:SetAllPoints(true)
    frame.Border:SetScale(borderAsset.scaleModifier)
    frame.Border:SetTexture(borderAsset.file)
    frame.Border:SetTextureSliceMargins(borderAsset.margins.left, borderAsset.margins.top, borderAsset.margins.right, borderAsset.margins.bottom)
    frame.Border:SetVertexColor(0, 0, 0)
    frame.Cooldown.Text = frame.Cooldown:GetCountdownFontString()
    frame.Dispel = CreateFrame("Frame", nil, frame)
    frame.Dispel:SetAllPoints()
    do
      local dispelTexture = frame.Dispel:CreateTexture()
      dispelTexture:SetAllPoints()
      dispelTexture:SetScale(dispelAsset.scaleModifier)
      dispelTexture:SetTexture(dispelAsset.file)
      dispelTexture:SetTextureSliceMargins(dispelAsset.margins.left, dispelAsset.margins.top, dispelAsset.margins.right, dispelAsset.margins.bottom)
      dispelTexture:SetVertexColor(1, 0, 0)
      frame.Dispel.Border = dispelTexture
    end

    frame:SetApplicationCount(frame.CountFrame.Count, {})
    frame:SetIcon(frame.Icon)
    frame:SetDurationCooldown(frame.Cooldown)
    frame:SetAuraBorder(frame.Dispel.Border, {showIcon = false, showWhenHarmful = true, showWhenHelpful = true, style = 1})

    if container.details then
      addonTable.Display.StyleAura(frame, container.details)
    end
  end
end

addonTable.Display.AurasManagerNextMixin = {}

function addonTable.Display.AurasManagerNextMixin:OnLoad()
  self.buffs = CreateFrame("AuraContainer", nil, self, "CustomAuraContainerTemplate")
  self.debuffs = CreateFrame("AuraContainer", nil, self, "CustomAuraContainerTemplate")
  self.crowdControl = CreateFrame("AuraContainer", nil, self, "CustomAuraContainerTemplate")

  self.buffs:SetEnabled(false)
  self.debuffs:SetEnabled(false)
  self.crowdControl:SetEnabled(false)

  self.buffs.platynatorGroups = {}
  self.debuffs.platynatorGroups = {}
  self.crowdControl.platynatorGroups = {}

  self.crowdControl.frames = {}

  self.buffs.frames = {}

  self.buffs.candidateIMPORTANTDefault = candidateIMPORTANTDefault
  self.buffs.candidateIMPORTANTNoEnrage = candidateIMPORTANTNoEnrage
  self.buffs.candidateENRAGEDefault = candidateENRAGEDefault
  self.buffs.candidateSTEALABLEDefault = candidateSTEALABLEDefault
  self.buffs.candidateSTEALABLENoEnrage = candidateSTEALABLENoEnrage

  self.debuffs.frames = {}

  self.buffs.initializeFrame = GetAurasInitializerModern(self.buffs)
  self.debuffs.initializeFrame = GetAurasInitializerModern(self.debuffs)
  self.crowdControl.initializeFrame = GetAurasInitializerModern(self.crowdControl)
end

local directionMap = {
  LEFT = "RIGHT",
  CENTER = "CENTER",
  RIGHT = "LEFT",
}

local anchorMap = {
  LEFT = "TOPRIGHT",
  CENTER = "TOPLEFT",
  RIGHT = "TOPLEFT",
}

local processedSpells = {}
local auraSetupPlanCache = setmetatable({}, {__mode = "k"})
addonTable.CallbackRegistry:RegisterCallback("SettingChanged", function(_, settingName)
  if settingName == addonTable.Config.Options.AURA_FILTERS or settingName == addonTable.Config.Options.DESIGNS then
    wipe(processedSpells)
    wipe(auraSetupPlanCache)
  end
end)

-- Modern AuraContainer updates can arrive in bursts during nameplate churn.
-- Queue the SetUnit handoff and apply it at 30 FPS so we collapse repeated
-- container rebuilds and reflows without introducing a timer-heavy hot path.
local auraNextUpdateDriver = CreateFrame("Frame")
local auraNextUpdateElapsed = 0
local AURA_NEXT_UPDATE_INTERVAL = 1 / 30
local AURA_MANAGERS_PER_TICK = 1
local pendingAuraNextManagers = {}
local pendingAuraNextQueue = {}
local pendingAuraNextHead = 1
local pendingAuraNextTail = 0
local OnAuraNextUpdate

local function QueueAuraManager(manager)
  if manager.auraFlushInProgress then
    return
  end
  if not pendingAuraNextManagers[manager] then
    pendingAuraNextManagers[manager] = true
    pendingAuraNextTail = pendingAuraNextTail + 1
    pendingAuraNextQueue[pendingAuraNextTail] = manager
  end
  if auraNextUpdateDriver:GetScript("OnUpdate") == nil then
    auraNextUpdateElapsed = 0
    auraNextUpdateDriver:SetScript("OnUpdate", OnAuraNextUpdate)
  end
end

local function FlushAuraNextUpdates()
  local processed = 0
  while processed < AURA_MANAGERS_PER_TICK and pendingAuraNextHead <= pendingAuraNextTail do
    local queueIndex = pendingAuraNextHead
    local manager = pendingAuraNextQueue[queueIndex]
    pendingAuraNextQueue[queueIndex] = nil
    pendingAuraNextHead = queueIndex + 1

    if pendingAuraNextManagers[manager] then
      pendingAuraNextManagers[manager] = nil
      processed = processed + 1
      manager.auraFlushInProgress = true

      local configured = true
      if manager.pendingAuraParent then
        local parent = manager.pendingAuraParent
        local auraDetails = manager.pendingAuraDetails
        manager.pendingAuraParent = nil
        manager.pendingAuraDetails = nil
        configured = manager:ApplyWidgetConfiguration(parent, auraDetails)
      end

      local pendingUnit = manager.pendingUnitUpdate
      manager.pendingUnitUpdate = nil
      if not configured then
        pendingUnit = nil
      end

      if manager.pendingAuraGroupLayout then
        local queuedLayouts = manager.pendingAuraGroupLayout
        manager.pendingAuraGroupLayout = nil
        for container, jobsByName in pairs(queuedLayouts) do
          for _, job in pairs(jobsByName) do
            container:SetAuraGroupMaxFrameCount(job.name, job.maxCount)
            container:SetAuraGroupLayout(job.name, {elementSpacingX = job.padding, elementSpacingY = job.padding})
            if job.filters then
              container:SetAuraGroupCandidateFilters(job.name, job.filters)
            end
            AuraLayoutCache.Set(container, job.name, job.maxCount, job.padding, job.filters)
          end
        end
      end

      manager:ProcessPendingUnitUpdate(pendingUnit)
      manager.auraFlushInProgress = nil
    end
  end

  auraNextUpdateElapsed = 0
  if pendingAuraNextHead > pendingAuraNextTail then
    wipe(pendingAuraNextQueue)
    pendingAuraNextHead = 1
    pendingAuraNextTail = 0
    auraNextUpdateDriver:SetScript("OnUpdate", nil)
  end
end

OnAuraNextUpdate = function(_, elapsed)
  auraNextUpdateElapsed = auraNextUpdateElapsed + elapsed
  if auraNextUpdateElapsed >= AURA_NEXT_UPDATE_INTERVAL then
    FlushAuraNextUpdates()
  end
end

local function QueueAuraNextUpdate(manager, unit)
  if not unit then
    manager.pendingUnitUpdate = nil
    manager.pendingAuraDetails = nil
    return
  end

  manager.pendingUnitUpdate = unit
  QueueAuraManager(manager)
end

local auraGroupBuilder = AuraGroupBuilder.Create({
  layoutCache = AuraLayoutCache,
  queueUpdate = QueueAuraNextUpdate,
})

local function PrepareAuraContainer(container, details)
  container.details = details
  if container.styleDetails == nil then
    -- Newly created frames are styled by GetAurasInitializerModern.
    -- Existing frames are restyled only when the details actually change.
    container.styleDetails = details
  end
end

local function RestyleAuraContainer(container, details)
  if container.styleDetails == details then
    return
  end
  if addonTable.Utilities.IsChangesRestricted() then
    return
  end
  for _, frame in ipairs(container.frames) do
    addonTable.Display.StyleAura(frame, details)
  end
  container.styleDetails = details
end

local function GetSpecializationFilters()
  local allFilters = addonTable.Config.Get(addonTable.Config.Options.AURA_FILTERS)
  local specializationID = addonTable.Display.Utilities.GetSpecializationID()
  
  -- Initialize aura filters if they don't exist for this specialization
  if not allFilters[specializationID] then
    allFilters[specializationID] = {
      buffs = { include = {}, exclude = {} },
      debuffs = { include = {}, exclude = {} },
      crowdControl = { include = {}, exclude = {} },
    }
  end
  
  return allFilters[specializationID]
end

local function ProcessSpells(kind, specializationFilters)
  local settings = specializationFilters[kind]
  if not settings then
    settings = { include = {}, exclude = {} }
    specializationFilters[kind] = settings
  end
  
  local cached = processedSpells[kind]
  if cached and cached.settings == settings then
    return cached.include, cached.exclude
  end

  local include = {}
  local exclude = {}

  for spellID, priority in pairs(settings.include) do
    exclude[spellID] = true
    if not include[priority] then
      include[priority] = {}
    end
    include[priority][spellID] = true
  end

  for spellID in pairs(settings.exclude) do
    exclude[spellID] = true
  end

  processedSpells[kind] = {
    settings = settings,
    include = include,
    exclude = exclude,
  }
  return include, exclude
end

local function GetAuraSetupPlan(auraDetails, specializationFilters)
  local plansBySpecialization = auraSetupPlanCache[auraDetails]
  if not plansBySpecialization then
    plansBySpecialization = setmetatable({}, {__mode = "k"})
    auraSetupPlanCache[auraDetails] = plansBySpecialization
  end

  local plan = plansBySpecialization[specializationFilters]
  if plan then
    return plan
  end

  plan = {
    crowdControl = auraDetails.crowdControl and AuraSetupConfigBuilder.ComputeCrowdControl(
      auraDetails.crowdControl.filters,
      auraDetails.crowdControl.limit
    ),
    debuffs = auraDetails.debuffs and AuraSetupConfigBuilder.ComputeDebuffs(
      auraDetails.debuffs.filters,
      auraDetails.debuffs.limit
    ),
    buffs = auraDetails.buffs and AuraSetupConfigBuilder.ComputeBuffs(auraDetails.buffs.filters, auraDetails.buffs.limit, {
      importantDefault = candidateIMPORTANTDefault,
      importantNoEnrage = candidateIMPORTANTNoEnrage,
      enrageDefault = candidateENRAGEDefault,
      stealableDefault = candidateSTEALABLEDefault,
    }),
    spells = {},
  }

  for _, kind in ipairs({"crowdControl", "debuffs", "buffs"}) do
    local include, exclude = ProcessSpells(kind, specializationFilters)
    plan.spells[kind] = {include = include, exclude = exclude}
  end

  plansBySpecialization[specializationFilters] = plan
  return plan
end

function addonTable.Display.AurasManagerNextMixin:ApplyWidgetConfiguration(parent, auraDetails)
  if not parent or not auraDetails then
    self.auraDetails = nil
    self.buffs:SetEnabled(false)
    self.debuffs:SetEnabled(false)
    self.crowdControl:SetEnabled(false)
    self.buffs:Hide()
    self.debuffs:Hide()
    self.crowdControl:Hide()
    return false
  end

  self.auraDetails = auraDetails
  local specializationFilters = GetSpecializationFilters()
  local setupPlan = GetAuraSetupPlan(auraDetails, specializationFilters)
  self.buffs:ClearAllPoints()
  self.debuffs:ClearAllPoints()
  self.crowdControl:ClearAllPoints()

  PrepareAuraContainer(self.buffs, auraDetails.buffs)
  PrepareAuraContainer(self.debuffs, auraDetails.debuffs)
  PrepareAuraContainer(self.crowdControl, auraDetails.crowdControl)

  if auraDetails.crowdControl then
    self.crowdControl:SetParent(parent.CrowdControlDisplay)
    self.crowdControl:SetScale(auraDetails.crowdControl.scale)
    self.crowdControl:SetPoint(directionMap[auraDetails.crowdControl.direction])
    self.crowdControl:SetFlowLayoutAnchorPoint(anchorMap[auraDetails.crowdControl.direction])
    local padding = PixelUtil.ConvertPixelsToUIForRegion(20 * auraDetails.crowdControl.padding, self.crowdControl)

    local include, exclude = setupPlan.spells.crowdControl.include, setupPlan.spells.crowdControl.exclude
    local activeGroups = {ALL = true, PLAYER_ONLY = true}
    auraGroupBuilder.EnsureCrowdControl(self, "ALL")
    auraGroupBuilder.EnsureCrowdControl(self, "PLAYER_ONLY")
    for i = 1, 3 do
      if include[i] then
        local key = tostring(i)
        activeGroups[key] = true
        auraGroupBuilder.EnsureCrowdControl(self, key)
      end
    end
    auraGroupBuilder.DisableUnused(self.crowdControl, activeGroups)

    local crowdControlLimits = setupPlan.crowdControl
    for name, count in pairs(crowdControlLimits) do
      AuraLayoutCache.Invalidate(self.crowdControl, name)
      self.crowdControl:SetAuraGroupMaxFrameCount(name, count)
    end
    auraGroupBuilder.ApplyLayout(self, self.crowdControl, "ALL", auraDetails.crowdControl.limit, padding, {excludeSpellIDs = exclude})
    auraGroupBuilder.ApplyLayout(self, self.crowdControl, "PLAYER_ONLY", auraDetails.crowdControl.limit, padding, {excludeSpellIDs = exclude})

    for i = 1, 3 do
      if include[i] then
        auraGroupBuilder.ApplyLayout(self, self.crowdControl, tostring(i), auraDetails.crowdControl.limit, padding, {includeSpellIDs = include[i]})
      end
    end


    RestyleAuraContainer(self.crowdControl, auraDetails.crowdControl)

    if auraDetails.crowdControl.direction == "LEFT" then
      self.crowdControl:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Left, AnchorUtil.FlowDirection.Up)
    else
      self.crowdControl:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Up)
    end

    self.crowdControl:Show()
  else
    self.crowdControl:Hide()
  end

  if auraDetails.debuffs then
    self.debuffs:SetParent(parent.DebuffDisplay)
    self.debuffs:SetScale(auraDetails.debuffs.scale)
    self.debuffs:SetPoint(directionMap[auraDetails.debuffs.direction])
    self.debuffs:SetFlowLayoutAnchorPoint(anchorMap[auraDetails.debuffs.direction])
    local padding = PixelUtil.ConvertPixelsToUIForRegion(20 * auraDetails.debuffs.padding, self.debuffs)
    local setup = setupPlan.debuffs

    local include, exclude = setupPlan.spells.debuffs.include, setupPlan.spells.debuffs.exclude
    local activeGroups = {}
    for key, count in pairs(setup) do
      activeGroups[key] = true
      auraGroupBuilder.EnsureDebuff(self, key)
      auraGroupBuilder.ApplyLayout(self, self.debuffs, key, count, padding, {excludeSpellIDs = exclude, nameplateShowPersonal = key:match("PERSONAL") and true or nil})
    end

    for i = 1, 3 do
      if include[i] then
        local key = tostring(i)
        activeGroups[key] = true
        auraGroupBuilder.EnsureDebuff(self, key)
        auraGroupBuilder.ApplyLayout(self, self.debuffs, key, auraDetails.debuffs.limit, padding, {includeSpellIDs = include[i]})
      end
    end
    auraGroupBuilder.DisableUnused(self.debuffs, activeGroups)

    RestyleAuraContainer(self.debuffs, auraDetails.debuffs)

    if auraDetails.debuffs.direction == "LEFT" then
      self.debuffs:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Left, AnchorUtil.FlowDirection.Up)
    else
      self.debuffs:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Up)
    end

    self.debuffs:Show()
  else
    self.debuffs:Hide()
  end

  if auraDetails.buffs then
    self.buffs:SetParent(parent.BuffDisplay)
    self.buffs:SetScale(auraDetails.buffs.scale)
    self.buffs:SetPoint(directionMap[auraDetails.buffs.direction])
    self.buffs:SetFlowLayoutAnchorPoint(anchorMap[auraDetails.buffs.direction])
    local padding = PixelUtil.ConvertPixelsToUIForRegion(20 * auraDetails.buffs.padding, self.buffs)
    local setup = setupPlan.buffs
    local include, exclude = setupPlan.spells.buffs.include, setupPlan.spells.buffs.exclude
    local activeGroups = {}
    for key, info in pairs(setup) do
      activeGroups[key] = true
      auraGroupBuilder.EnsureBuff(self, key)
      local filters = AuraSetupConfigBuilder.WithExclude(info[2], exclude)
      auraGroupBuilder.ApplyLayout(self, self.buffs, key, info[1], padding, filters)
    end

    for i = 1, 3 do
      if include[i] then
        local key = tostring(i)
        activeGroups[key] = true
        auraGroupBuilder.EnsureBuff(self, key)
        auraGroupBuilder.ApplyLayout(self, self.buffs, key, auraDetails.buffs.limit, padding, {includeSpellIDs = include[i]})
      end
    end
    auraGroupBuilder.DisableUnused(self.buffs, activeGroups)

    RestyleAuraContainer(self.buffs, auraDetails.buffs)

    if auraDetails.buffs.direction == "LEFT" then
      self.buffs:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Left, AnchorUtil.FlowDirection.Up)
    else
      self.buffs:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Up)
    end

    self.buffs:Show()
  else
    self.buffs:Hide()
  end

  return true
end

function addonTable.Display.AurasManagerNextMixin:InitializeWidgets(parent, auraDetails)
  self.pendingAuraParent = parent
  self.pendingAuraDetails = auraDetails
  QueueAuraManager(self)
end

function addonTable.Display.AurasManagerNextMixin:ProcessPendingUnitUpdate(unit)
  local auraDetails = self.pendingAuraDetails or self.auraDetails
  self.pendingAuraDetails = nil

  if not unit then
    self.buffs:SetEnabled(false)
    self.debuffs:SetEnabled(false)
    self.crowdControl:SetEnabled(false)
    self.buffs:Hide()
    self.debuffs:Hide()
    self.crowdControl:Hide()
    self.unit = nil
    return
  end

  self.unit = unit
  self.buffs:SetEnabled(true)
  self.debuffs:SetEnabled(true)
  self.crowdControl:SetEnabled(true)

  self.auraDetails = auraDetails

  if auraDetails then
    self.buffs:SetShown(auraDetails.buffs ~= nil)
    self.debuffs:SetShown(auraDetails.debuffs ~= nil)
    self.crowdControl:SetShown(auraDetails.crowdControl ~= nil)
  end

  self.buffs:SetUnit(unit)
  self.debuffs:SetUnit(unit)
  self.crowdControl:SetUnit(unit)
end

function addonTable.Display.AurasManagerNextMixin:SetUnit(unit, parent, auraDetails)
  if not unit then
    self.pendingUnitUpdate = nil
    self.pendingAuraParent = nil
    self.pendingAuraDetails = nil
    pendingAuraNextManagers[self] = nil
    self:ProcessPendingUnitUpdate(nil)
    return
  end

  -- A queued widget configuration owns pendingAuraDetails until it is
  -- applied.  SetUnit must not overwrite it with the previous style's
  -- details (or nil) before the configuration flush runs.
  if not self.pendingAuraParent then
    self.pendingAuraDetails = auraDetails or self.auraDetails
  end
  QueueAuraNextUpdate(self, unit)
end
