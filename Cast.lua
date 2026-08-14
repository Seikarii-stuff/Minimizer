local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Cast = Minimizer.Cast or {}

local UnitExists = UnitExists
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo

local function ReadCastState(unit)
    if not unit or not UnitExists(unit) then return false, false, nil, false end

    local castName, _, _, _, _, _, _, castUninterruptible = UnitCastingInfo(unit)
    local channelName, _, _, _, _, _, channelUninterruptible = UnitChannelInfo(unit)
    local isChanneling = channelName ~= nil
    local isCasting = castName ~= nil or isChanneling
    if not isCasting then return false, false, nil, false end

    local uninterruptible
    if castName ~= nil then
        uninterruptible = castUninterruptible
    elseif isChanneling then
        uninterruptible = channelUninterruptible
    end

    if Minimizer.Utils.IsSecretValue(uninterruptible) then
        return true, nil, uninterruptible, isChanneling
    end
    local safeValue = uninterruptible == true
    return true, safeValue, safeValue, isChanneling
end

local cachedCastUnit
local cachedIsCasting, cachedUninterruptible, cachedRawUninterruptible, cachedIsChanneling
local cachedCastValid = false

function Minimizer.Cast.InvalidateState(unit)
    if not unit or cachedCastUnit == unit then
        cachedCastUnit = nil
        cachedIsCasting, cachedUninterruptible, cachedRawUninterruptible, cachedIsChanneling = nil, nil, nil, nil
        cachedCastValid = false
    end
end

function Minimizer.Cast.GetState(unit)
    if cachedCastValid and cachedCastUnit == unit then
        return cachedIsCasting, cachedUninterruptible, cachedRawUninterruptible, cachedIsChanneling
    end
    local isCasting, uninterruptible, rawUninterruptible, isChanneling = ReadCastState(unit)
    cachedCastUnit = unit
    cachedIsCasting = isCasting
    cachedUninterruptible = uninterruptible
    cachedRawUninterruptible = rawUninterruptible
    cachedIsChanneling = isChanneling
    cachedCastValid = true
    return isCasting, uninterruptible, rawUninterruptible, isChanneling
end

function Minimizer.Cast.IsUnitCasting(unit)
    local isCasting = Minimizer.Cast.GetState(unit)
    return isCasting == true
end

function Minimizer.Cast.IsUnitCastUninterruptible(unit)
    local isCasting, isUninterruptible = Minimizer.Cast.GetState(unit)
    return isCasting == true and isUninterruptible == true
end
