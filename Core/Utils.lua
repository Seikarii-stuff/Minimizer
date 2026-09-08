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
local GetTime = GetTime

local _guarded_log_throttle = {}
local _GUARDED_LOG_THROTTLE_SECONDS = 10

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

    -- CAMINO LENTO: itera TODAS las nameplates activas (C_NamePlate.GetNamePlates()
    -- aloca una tabla nueva en cada llamada). Solo debería llegar aquí un `unit`
    -- que NO sea un token nameplateN y que tampoco tenga ya un camino directo.
    -- Para "target"/"focus" específicamente, usa siempre
    -- C_NamePlate.GetNamePlateForUnit("target"/"focus") directo si Blizzard lo
    -- soporta (así lo hacen ya Target.lua y Focus.lua) en vez de pasar por aquí.
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
    if not healthBar or type(healthBar.GetParent) ~= "function" then return nil end
    local parent = healthBar:GetParent()
    -- Climb parent chain until we find the frame that holds the nameplate token
    while parent do
        if parent.namePlateUnitToken then
            return parent
        end
        if parent.UnitFrame then
            -- parent is the nameplate container
            return parent
        end
        if type(parent.GetParent) ~= "function" then break end
        parent = parent:GetParent()
    end
    return nil
end

function Minimizer.Utils.GetHealthBar(nameplate)
    local unitFrame = nameplate and (nameplate.UnitFrame or nameplate)
    return unitFrame and (unitFrame.healthBar or unitFrame.HealthBar)
end

function Minimizer.Utils.EvaluateColorRGB(state, colorTrue, colorFalse)
    if not C_CurveUtil or type(C_CurveUtil.EvaluateColorValueFromBoolean) ~= "function" then
        if Minimizer.Utils.IsSecretValue(state) then
            return colorFalse[1], colorFalse[2], colorFalse[3]
        end
        local c = (state == true) and colorTrue or colorFalse
        return c[1], c[2], c[3]
    end
    return C_CurveUtil.EvaluateColorValueFromBoolean(state, colorTrue[1], colorFalse[1]),
           C_CurveUtil.EvaluateColorValueFromBoolean(state, colorTrue[2], colorFalse[2]),
           C_CurveUtil.EvaluateColorValueFromBoolean(state, colorTrue[3], colorFalse[3])
end

function Minimizer.Utils.EvaluateBoolean(state, ifTrue, ifFalse)
    if not C_CurveUtil or type(C_CurveUtil.EvaluateColorValueFromBoolean) ~= "function" then
        if Minimizer.Utils.IsSecretValue(state) then return ifFalse end
        return (state == true) and ifTrue or ifFalse
    end
    return C_CurveUtil.EvaluateColorValueFromBoolean(state, ifTrue, ifFalse)
end

function Minimizer.Utils.GuardedCall(obj, flagName, fn)
    if obj[flagName] then return end
    obj[flagName] = true
    local ok, err = pcall(fn)
    obj[flagName] = nil
    if not ok then
        Minimizer.Utils.LogGuardedError(flagName, err)
    end
end

function Minimizer.Utils.LogGuardedError(flagName, err)
    if not flagName then flagName = "guarded" end
    local now = GetTime and GetTime() or 0
    local last = _guarded_log_throttle[flagName]
    if not last or (now - last) >= _GUARDED_LOG_THROTTLE_SECONDS then
        _guarded_log_throttle[flagName] = now
        print("|cffff4444Minimizer|r: Error in guarded call " .. tostring(flagName) .. ": " .. tostring(err))
    end
end

function Minimizer.Utils.ApplyReadyShade(texture, ready)
    if not texture or type(texture) ~= "table" then return false end

    local shade = 1.0
    if C_CurveUtil and type(C_CurveUtil.EvaluateColorValueFromBoolean) == "function" then
        shade = C_CurveUtil.EvaluateColorValueFromBoolean(ready, 1.0, 0.38)
    elseif Minimizer.Utils.IsSecretValue(ready) then
        shade = 0.38
    else
        shade = ready and 1.0 or 0.38
    end

    if type(texture.SetVertexColor) == "function" then
        texture:SetVertexColor(shade, shade, shade, 1)
    end

    return true
end

-- Devuelve true si la unidad es un jugador enemigo (PvP). En ese caso los
-- modulos de color deben dejar las barras de Blizzard sin tocar.
function Minimizer.Utils.IsPvPUnit(unit)
    return unit and UnitIsPlayer and UnitIsPlayer(unit) and UnitCanAttack and UnitCanAttack("player", unit) or false
end

-- Devuelve true si la unidad es amistosa hacia el jugador.
function Minimizer.Utils.IsFriendlyUnit(unit)
    if not unit then return false end
    return (UnitCanAttack and not UnitCanAttack("player", unit)) or false
end

-- Helper común para interceptar repintados nativos y reaplicar último color guardado
function Minimizer.Utils.HookRepaintGuard(statusBar, hookedFlag, applyingFlag, onRepaint)
    if not statusBar or statusBar[hookedFlag] then return end
    statusBar[hookedFlag] = true
    if hooksecurefunc then
        hooksecurefunc(statusBar, "SetStatusBarColor", function()
            if statusBar[applyingFlag] then return end
            onRepaint()
        end)
    end
end

function Minimizer.Utils.Debounce(fn)
    -- NOTA: esta version asume que `fn` siempre se invoca sin argumentos
    -- variables (confirmado por grep: el unico consumidor en el repo es
    -- Core.lua -> Minimizer.Core.RequestApplyToAll, siempre llamado como
    -- RequestApplyToAll() sin parametros). Si en el futuro se necesita pasar
    -- argumentos variables a traves de un Debounce, NO reintroducir la tabla
    -- `{...}` por llamada -- usar una tabla scratch reutilizada a nivel de
    -- closure en su lugar.
    local pending = false
    local afterCallback
    afterCallback = function()
        pending = false
        fn()
    end
    return function()
        if pending then return end
        pending = true
        C_Timer.After(0, afterCallback)
    end
end

-- Limita la frecuencia de ejecución a máximo 1 llamada cada `interval` segundos (ej. 0.033s para 30 FPS).
-- Si se producen llamadas intermedias, la última se pospone para ejecutarse cuando venza el intervalo.
function Minimizer.Utils.Throttle(fn, interval)
    interval = interval or 0.033
    local lastTime = 0
    local pending = false
    -- Closure de callback creada UNA sola vez (no en cada disparo de la rama
    -- "pending"). Antes se creaba una closure nueva por cada llamada que
    -- caia en esa rama -- con Target/Focus llamando esto ~25 veces/seg via
    -- SPELL_UPDATE_COOLDOWN, era basura constante.
    local afterCallback
    afterCallback = function()
        pending = false
        lastTime = GetTime()
        fn()
    end
    return function()
        local now = GetTime()
        local elapsed = now - lastTime
        if elapsed >= interval then
            lastTime = now
            fn()
        elseif not pending then
            pending = true
            local remaining = interval - elapsed
            if remaining < 0 then remaining = 0 end
            C_Timer.After(remaining, afterCallback)
        end
    end
end


