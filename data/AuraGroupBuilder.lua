---@class addonTablePlatynator
local addonTable = select(2, ...)

addonTable.Display = addonTable.Display or {}
addonTable.Display.Auras = addonTable.Display.Auras or {}

---@class PlatynatorAuraGroupBuilderDependencies
---@field layoutCache table
---@field queueUpdate fun(manager: table, unit: string|nil)

---@class PlatynatorAuraGroupBuilder
---@field Ensure fun(container: table, name: string, filter: string|table, options: table|nil)
---@field DisableUnused fun(container: table, activeGroups: table)
---@field ApplyLayout fun(manager: table|nil, container: table, name: string, maxCount: number, padding: number, filters: table|nil)
---@field EnsureCrowdControl fun(manager: table, name: string)
---@field EnsureDebuff fun(manager: table, name: string)
---@field EnsureBuff fun(manager: table, name: string)

local AuraGroupBuilder = {}

local CROWD_CONTROL_FILTERS = {
  ALL = "HARMFUL|CROWD_CONTROL",
  PLAYER_ONLY = "HARMFUL|CROWD_CONTROL|PLAYER",
}

local DEBUFF_FILTERS = {
  PLAYER_IMPORTANT = "HARMFUL|IMPORTANT|PLAYER|!CROWD_CONTROL",
  ANY_PLAYER_IMPORTANT = "HARMFUL|IMPORTANT|!CROWD_CONTROL",
  PLAYER_PERSONAL = "HARMFUL|!IMPORTANT|INCLUDE_NAME_PLATE_ONLY|PLAYER|!CROWD_CONTROL",
  ANY_PLAYER_PERSONAL = "HARMFUL|!IMPORTANT|INCLUDE_NAME_PLATE_ONLY|!CROWD_CONTROL",
  ALL_PLAYER = "HARMFUL|PLAYER|!CROWD_CONTROL",
  ALL = "HARMFUL|!CROWD_CONTROL",
}

local BUFF_FILTERS = {
  ALL = "HELPFUL|!PLAYER",
  PLAYER_ASSIST = "HELPFUL|PLAYER",
  IMPORTANT = "HELPFUL|IMPORTANT|!PLAYER",
  ENRAGE = "HELPFUL|!IMPORTANT|!PLAYER",
  STEALABLE = "HELPFUL|!IMPORTANT|!PLAYER",
  DEFENSIVE1 = "HELPFUL|BIG_DEFENSIVE|!PLAYER",
  DEFENSIVE2 = "HELPFUL|EXTERNAL_DEFENSIVE|!PLAYER",
  DEFENSIVE3 = "HELPFUL|RAID_IN_COMBAT|!PLAYER",
}

---@param dependencies PlatynatorAuraGroupBuilderDependencies
---@return PlatynatorAuraGroupBuilder
function AuraGroupBuilder.Create(dependencies)
  assert(dependencies and dependencies.layoutCache, "AuraGroupBuilder requires layoutCache")
  assert(dependencies.queueUpdate, "AuraGroupBuilder requires queueUpdate")

  local layoutCache = dependencies.layoutCache
  local queueUpdate = dependencies.queueUpdate

  ---@type PlatynatorAuraGroupBuilder
  local builder = {}

  function builder.Ensure(container, name, filter, options)
    if container.platynatorGroups[name] then
      return
    end

    options = options or {}
    options.initializeFrame = container.initializeFrame
    container:AddAuraGroup(name, filter, options)
    container.platynatorGroups[name] = true
  end

  function builder.DisableUnused(container, activeGroups)
    for name in pairs(container.platynatorGroups) do
      if not activeGroups[name] then
        container:SetAuraGroupMaxFrameCount(name, 0)
        layoutCache.Invalidate(container, name)
      end
    end
  end

  function builder.ApplyLayout(manager, container, name, maxCount, padding, filters)
    if layoutCache.IsEqual(layoutCache.Get(container, name), maxCount, padding, filters) then
      return
    end

    if manager then
      manager.pendingAuraGroupLayout = manager.pendingAuraGroupLayout or {}
      manager.pendingAuraGroupLayout[container] = manager.pendingAuraGroupLayout[container] or {}
      manager.pendingAuraGroupLayout[container][name] = {
        container = container,
        name = name,
        maxCount = maxCount,
        padding = padding,
        filters = filters,
      }
      queueUpdate(manager, manager.pendingUnitUpdate)
      return
    end

    container:SetAuraGroupMaxFrameCount(name, maxCount)
    container:SetAuraGroupLayout(name, {elementSpacingX = padding, elementSpacingY = padding})
    if filters then
      container:SetAuraGroupCandidateFilters(name, filters)
    end
    layoutCache.Set(container, name, maxCount, padding, filters)
  end

  function builder.EnsureCrowdControl(manager, name)
    local filter = CROWD_CONTROL_FILTERS[name] or "HARMFUL"
    builder.Ensure(manager.crowdControl, name, filter)
  end

  function builder.EnsureDebuff(manager, name)
    local options
    if name == "PLAYER_PERSONAL" or name == "ANY_PLAYER_PERSONAL" then
      options = {candidateFilters = {nameplateShowPersonal = true}}
    end
    builder.Ensure(manager.debuffs, name, DEBUFF_FILTERS[name] or "HARMFUL|PLAYER", options)
  end

  function builder.EnsureBuff(manager, name)
    builder.Ensure(manager.buffs, name, BUFF_FILTERS[name] or "HELPFUL|PLAYER")
  end

  return builder
end

addonTable.Display.Auras.AuraGroupBuilder = AuraGroupBuilder
