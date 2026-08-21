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

-- NO CACHE. Habia un slot unico (scalar, no tabla por unidad) que dependia
-- de que Cast.InvalidateState() se disparase SIEMPRE antes de que un token
-- de nameplate reciclado (ej. "nameplate3" pasando de un mob muerto a uno
-- nuevo) fuera vuelto a leer. Esa invalidacion vive en un hook distinto
-- (NamePlateDriverFrame.OnNamePlateRemoved) del que lee el estado nuevo
-- (NAME_PLATE_UNIT_ADDED / hooks de SetStatusBarColor), sin garantia dura de
-- orden entre ambos. Si esa carrera se perdia una sola vez, una unidad podia
-- heredar el rawUninterruptible de la unidad ANTERIOR que ocupo el mismo
-- token -- dos mobs con estados reales opuestos mostrando el mismo color.
-- UnitCastingInfo/UnitChannelInfo son baratas: no vale la pena el riesgo por
-- un cache que en la practica casi nunca se reutilizaba (BuildSnapshot solo
-- llama una vez por unidad por pase; las llamadas fuera de pase vienen de
-- hooks de Blizzard repintando barras, casi siempre para unidades distintas
-- de todos modos). Leer siempre fresco elimina la clase de bug entera, no
-- solo el sintoma.
function Minimizer.Cast.InvalidateState(_unit)
    -- No-op: se mantiene como funcion valida porque Core.lua y Events.lua
    -- la llaman en varios sitios. Sin cache no hay nada que invalidar.
end

function Minimizer.Cast.GetState(unit)
    return ReadCastState(unit)
end

function Minimizer.Cast.IsUnitCasting(unit)
    local isCasting = Minimizer.Cast.GetState(unit)
    return isCasting == true
end

function Minimizer.Cast.IsUnitCastUninterruptible(unit)
    local isCasting, isUninterruptible = Minimizer.Cast.GetState(unit)
    return isCasting == true and isUninterruptible == true
end