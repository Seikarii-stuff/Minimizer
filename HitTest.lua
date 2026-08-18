-- ============================================================================
-- Minimizer - HitTest.lua
-- Mantiene la región de clic (hit-test) de la nameplate sincronizada con el
-- healthBar real.
--
-- Root cause del bug original: C_NamePlateManager.SetNamePlateSimplified
-- redimensiona visualmente el healthBar (Core.lua -> ApplyToUnit), pero
-- Blizzard NO recalcula el hit-test solo. Sin esta llamada explícita, la
-- región de clic se queda pegada al tamaño que tenía la ÚLTIMA vez que algo
-- tocó el hit-test (normalmente el tamaño no-simplificado inicial), y el
-- healthbar visible deja de coincidir con donde realmente puedes hacer clic.
--
-- Verificado contra Platynator (Display/Initialize.lua, UpdateClickRegion /
-- GetCanChangeHitTestPoints): usan nameplate:SetAllHitTestPoints(frame) +
-- nameplate:CanChangeHitTestPoints() con reintento corto, porque justo tras
-- NAME_PLATE_UNIT_ADDED Blizzard a veces aún no permite mutar el hit-test.
-- Minimizer replica el mismo patrón pero apuntando directo al healthBar
-- nativo en vez de construir un clickRegion con tamaño calculado -- no lo
-- necesitamos porque no hacemos escalado propio, solo el toggle binario de
-- SetNamePlateSimplified.
-- ============================================================================
local _, Minimizer = ...
if not Minimizer then return end

Minimizer.HitTest = Minimizer.HitTest or {}

local MAX_RETRY_TICKS = 6
local RETRY_INTERVAL = 0.05
local pendingRetries = {}
local _hit_test_log_throttle = 0

local function LogHitTestError(err)
    if Minimizer.Utils and Minimizer.Utils.LogGuardedError then
        Minimizer.Utils.LogGuardedError("hitTest", err)
        return
    end

    local now = GetTime and GetTime() or 0
    if (now - _hit_test_log_throttle) < 10 then return end
    _hit_test_log_throttle = now
    print("|cffff4444Minimizer|r: Error in hit-test sync: " .. tostring(err))
end

local function CanChangeHitTestPoints(nameplate)
    if not nameplate or type(nameplate.CanChangeHitTestPoints) ~= "function" then
        return false, false
    end

    local ok, canChange = pcall(nameplate.CanChangeHitTestPoints, nameplate)
    if not ok then
        LogHitTestError(canChange)
    end
    return ok, ok and canChange == true
end

local function ScheduleRetry(unit)
    if pendingRetries[unit] then return end
    pendingRetries[unit] = MAX_RETRY_TICKS

    local function tick()
        local remaining = pendingRetries[unit]
        if not remaining then return end -- cancelado (OnNamePlateRemoved)

        local applied = Minimizer.HitTest.Sync(unit)
        if applied or remaining <= 1 then
            pendingRetries[unit] = nil
            return
        end

        pendingRetries[unit] = remaining - 1
        C_Timer.After(RETRY_INTERVAL, tick)
    end

    C_Timer.After(RETRY_INTERVAL, tick)
end

-- Sincroniza la región de clic de `unit` con su healthBar real.
-- Devuelve true si se aplicó, false si Blizzard aún no permite mutar el
-- hit-test para esta nameplate (en cuyo caso queda un reintento encolado).
function Minimizer.HitTest.Sync(unit, nameplate)
    if not unit then return false end

    nameplate = nameplate or Minimizer.Utils.GetNamePlateForUnit(unit)
    if not nameplate or type(nameplate.SetAllHitTestPoints) ~= "function" then
        -- Cliente sin esta API (o nameplate no resuelta todavía): nada que
        -- sincronizar. No es un error -- simplemente no aplica.
        return false
    end

    local ok, canChange = CanChangeHitTestPoints(nameplate)
    if not (ok and canChange) then
        ScheduleRetry(unit)
        return false
    end

    local healthBar = Minimizer.Utils.GetHealthBar(nameplate)
    if not healthBar then return false end

    nameplate:SetAllHitTestPoints(healthBar)
    pendingRetries[unit] = nil
    return true
end

-- Llamar desde Core.ClearNeverSimplify (o equivalente de limpieza) para que
-- un reintento pendiente no siga corriendo sobre un token reciclado.
function Minimizer.HitTest.CancelRetry(unit)
    if unit then pendingRetries[unit] = nil end
end
