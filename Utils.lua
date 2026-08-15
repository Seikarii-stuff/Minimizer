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

-- Reconstruye la nameplate a partir de un healthBar (usado por los hooks de
-- SetStatusBarColor/Show/Hide que solo reciben el widget, no la nameplate).
function Minimizer.Utils.GetNameplateFromHealthBar(healthBar)
    local parent = healthBar:GetParent()
    return parent and (parent.UnitFrame and parent or parent:GetParent())
end

function Minimizer.Utils.GetHealthBar(nameplate)
    local unitFrame = nameplate and (nameplate.UnitFrame or nameplate)
    return unitFrame and (unitFrame.healthBar or unitFrame.HealthBar)
end

function Minimizer.Utils.EvaluateColorRGB(state, colorTrue, colorFalse)
    if state == nil then state = false end
    if not C_CurveUtil or type(C_CurveUtil.EvaluateColorValueFromBoolean) ~= "function" then
        local c = (state == true) and colorTrue or colorFalse
        return c[1], c[2], c[3]
    end
    return C_CurveUtil.EvaluateColorValueFromBoolean(state, colorTrue[1], colorFalse[1]),
           C_CurveUtil.EvaluateColorValueFromBoolean(state, colorTrue[2], colorFalse[2]),
           C_CurveUtil.EvaluateColorValueFromBoolean(state, colorTrue[3], colorFalse[3])
end

function Minimizer.Utils.EvaluateBoolean(state, ifTrue, ifFalse)
    if state == nil then state = false end
    if not C_CurveUtil or type(C_CurveUtil.EvaluateColorValueFromBoolean) ~= "function" then
        return (state == true) and ifTrue or ifFalse
    end
    return C_CurveUtil.EvaluateColorValueFromBoolean(state, ifTrue, ifFalse)
end

function Minimizer.Utils.GuardedCall(obj, flagName, fn)
    if obj[flagName] then return end
    obj[flagName] = true
    fn()
    obj[flagName] = nil
end

-- Devuelve true si la unidad es un jugador enemigo (PvP). En ese caso los
-- modulos de color deben dejar las barras de Blizzard sin tocar.
function Minimizer.Utils.IsPvPUnit(unit)
    return unit and UnitIsPlayer(unit) and UnitCanAttack("player", unit)
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

-- Limita la frecuencia de ejecución a máximo 1 llamada cada `interval` segundos (ej. 0.033s para 30 FPS).
-- Si se producen llamadas intermedias, la última se pospone para ejecutarse cuando venza el intervalo.
function Minimizer.Utils.Throttle(fn, interval)
    interval = interval or 0.033
    local lastTime = 0
    local pending = false
    local lastArgs
    return function(...)
        local now = GetTime()
        lastArgs = {...}
        local elapsed = now - lastTime
        if elapsed >= interval then
            lastTime = now
            fn(unpack(lastArgs))
        elseif not pending then
            pending = true
            local remaining = interval - elapsed
            if remaining < 0 then remaining = 0 end
            C_Timer.After(remaining, function()
                pending = false
                lastTime = GetTime()
                if lastArgs then
                    fn(unpack(lastArgs))
                end
            end)
        end
    end
end

-- Busca el primer spellID de una lista que el jugador conozca.
-- spellList puede ser un numero suelto o una tabla de numeros.
-- Si ninguno esta "conocido" segun las APIs, devuelve el primero de la lista
-- como fallback (asumimos que aun no se ha aprendido pero existe).
function Minimizer.Utils.FindKnownSpell(spellList)
    if not spellList then return nil end
    if type(spellList) == "number" then
        spellList = {spellList}
    end
    for _, spellID in ipairs(spellList) do
        if ((C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook
            and C_SpellBook.IsSpellKnownOrInSpellBook(spellID))
            or (IsPlayerSpell and IsPlayerSpell(spellID))
            or (C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(spellID))
            or (IsSpellKnown and IsSpellKnown(spellID))) then
            return spellID
        end
    end
    return spellList[1]
end
