---@class addonTablePlatynator
local addonTable = select(2, ...)

addonTable.Display = addonTable.Display or {}
addonTable.Display.Auras = addonTable.Display.Auras or {}

---@class PlatynatorAuraLayoutCacheEntry
---@field maxCount number
---@field padding number
---@field filters table|nil

---@class PlatynatorAuraLayoutCache
local AuraLayoutCache = {}

local function CopyFilters(filters)
  if not filters then
    return nil
  end
  local copy = {}
  for key, value in pairs(filters) do
    copy[key] = value
  end
  return copy
end

local function FiltersEqual(left, right)
  if left == right then
    return true
  end
  if not left or not right then
    return false
  end
  for key, value in pairs(left) do
    if right[key] ~= value then
      return false
    end
  end
  for key, value in pairs(right) do
    if left[key] ~= value then
      return false
    end
  end
  return true
end

---@param container table
---@param name string
---@return PlatynatorAuraLayoutCacheEntry|nil
function AuraLayoutCache.Get(container, name)
  return container.platynatorLayoutCache and container.platynatorLayoutCache[name]
end

---@param entry PlatynatorAuraLayoutCacheEntry|nil
---@param maxCount number
---@param padding number
---@param filters table|nil
---@return boolean
function AuraLayoutCache.IsEqual(entry, maxCount, padding, filters)
  return entry ~= nil
    and entry.maxCount == maxCount
    and entry.padding == padding
    and FiltersEqual(entry.filters, filters)
end

---@param container table
---@param name string
---@param maxCount number
---@param padding number
---@param filters table|nil
function AuraLayoutCache.Set(container, name, maxCount, padding, filters)
  container.platynatorLayoutCache = container.platynatorLayoutCache or {}
  container.platynatorLayoutCache[name] = {
    maxCount = maxCount,
    padding = padding,
    filters = CopyFilters(filters),
  }
end

---@param container table
---@param name string
function AuraLayoutCache.Invalidate(container, name)
  if container.platynatorLayoutCache then
    container.platynatorLayoutCache[name] = nil
  end
end

addonTable.Display.Auras.AuraLayoutCache = AuraLayoutCache