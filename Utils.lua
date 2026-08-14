local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Utils = {}

local type = type
local ipairs = ipairs
local UnitExists = UnitExists
local UnitIsUnit = UnitIsUnit
local C_NamePlate = C_NamePlate
local C_NamePlateManager = C_NamePlateManager
local C_Timer = C_Timer
local C_CurveUtil = C_CurveUtil
local issecretvalue = issecretvalue
local pcall = pcall

function Minimizer.Utils.IsSecretValue(value)
    return issecretvalue and issecretvalue(value)
end

function Minimizer.Utils.IsSimplifiedAvailable()
    return C_NamePlateManager and type(C_NamePlateManager.SetNamePlateSimplified) == "function"
end

function Minimizer.Utils.GetNamePlateForUnit(unit)
    if not unit or type(unit) ~= "string" or not UnitExists(unit) then 
        return nil 
    end

    if unit:match("^nameplate%d+$") then
        return C_NamePlate.GetNamePlateForUnit(unit)
    end

    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
            local token = nameplate.namePlateUnitToken or (nameplate.UnitFrame and nameplate.UnitFrame.unit)
            if token and UnitIsUnit(token, unit) then
                return nameplate
            end
        end
    end

    return nil
end

function Minimizer.Utils.GetValidNamePlateToken(unit, nameplate)
    if type(unit) == "string" and unit:match("^nameplate%d+$") then
        return unit
    end
    if nameplate then
        local token = nameplate.namePlateUnitToken or (nameplate.UnitFrame and nameplate.UnitFrame.unit)
        if type(token) == "string" and token:match("^nameplate%d+$") then
            return token
        end
    end
    return nil
end

function Minimizer.Utils.GetUnitFromNameplate(nameplate)
    return nameplate and (nameplate.namePlateUnitToken or (nameplate.UnitFrame and nameplate.UnitFrame.unit))
end

function Minimizer.Utils.GetHealthBar(nameplate)
    local unitFrame = nameplate and (nameplate.UnitFrame or nameplate)
    return unitFrame and (unitFrame.healthBar or unitFrame.HealthBar)
end

function Minimizer.Utils.EvaluateColorRGB(state, colorTrue, colorFalse)
    if state == nil then state = false end
    if not C_CurveUtil or type(C_CurveUtil.EvaluateColorValueFromBoolean) ~= "function" then
        return colorFalse[1], colorFalse[2], colorFalse[3]
    end
    return C_CurveUtil.EvaluateColorValueFromBoolean(state, colorTrue[1], colorFalse[1]),
           C_CurveUtil.EvaluateColorValueFromBoolean(state, colorTrue[2], colorFalse[2]),
           C_CurveUtil.EvaluateColorValueFromBoolean(state, colorTrue[3], colorFalse[3])
end

function Minimizer.Utils.GuardedCall(obj, flagName, fn)
    if obj[flagName] then return end
    obj[flagName] = true
    fn()
    obj[flagName] = nil
end

function Minimizer.Utils.Debounce(fn)
    local pending = false
    return function(...)
        if pending then return end
        pending = true
        local args = {...}
        C_Timer.After(0, function()
            pending = false
            fn(unpack(args))
        end)
    end
end
