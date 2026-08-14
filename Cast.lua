local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Cast = Minimizer.Cast or {}

local UnitExists = UnitExists
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo

local function ReadCastState(unit)
    if not unit or not UnitExists(unit) then return false, false end

    local castName, _, _, _, _, _, _, castUninterruptible = UnitCastingInfo(unit)
    local channelName, _, _, _, _, _, channelUninterruptible = UnitChannelInfo(unit)
    local isCasting = castName ~= nil or channelName ~= nil
    if not isCasting then return false, false end

    local uninterruptible
    if castName ~= nil then
        uninterruptible = castUninterruptible
    elseif channelName ~= nil then
        uninterruptible = channelUninterruptible
    end

    if Minimizer.Utils.IsSecretValue(uninterruptible) then
        return true, nil, uninterruptible
    end
    local safeValue = uninterruptible == true
    return true, safeValue, safeValue
end

local cachedCastUnit
local cachedIsCasting, cachedUninterruptible, cachedRawUninterruptible
local cachedCastValid = false

function Minimizer.Cast.InvalidateState(unit)
    if not unit or cachedCastUnit == unit then
        cachedCastUnit = nil
        cachedIsCasting, cachedUninterruptible, cachedRawUninterruptible = nil, nil, nil
        cachedCastValid = false
    end
end

function Minimizer.Cast.GetState(unit)
    if cachedCastValid and cachedCastUnit == unit then
        return cachedIsCasting, cachedUninterruptible, cachedRawUninterruptible
    end
    local isCasting, uninterruptible, rawUninterruptible = ReadCastState(unit)
    cachedCastUnit = unit
    cachedIsCasting = isCasting
    cachedUninterruptible = uninterruptible
    cachedRawUninterruptible = rawUninterruptible
    cachedCastValid = true
    return isCasting, uninterruptible, rawUninterruptible
end

function Minimizer.Cast.IsUnitCasting(unit)
    local isCasting = Minimizer.Cast.GetState(unit)
    return isCasting == true
end

function Minimizer.Cast.IsUnitCastUninterruptible(unit)
    local isCasting, isUninterruptible = Minimizer.Cast.GetState(unit)
    return isCasting == true and isUninterruptible == true
end
