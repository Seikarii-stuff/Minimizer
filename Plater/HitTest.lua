-- ============================================================================
-- Minimizer - HitTest.lua
-- Mantiene la región de clic (hit-test) de la nameplate sincronizada con el
-- healthBar real.

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
    local gen = (Minimizer.Lifecycle and Minimizer.Lifecycle.GetGeneration and Minimizer.Lifecycle.GetGeneration(unit)) or 0
    pendingRetries[unit] = { remaining = MAX_RETRY_TICKS, gen = gen }

    local function tick()
        local retry = pendingRetries[unit]
        if not retry then return end -- cancelado (OnNamePlateRemoved / CancelRetry)

        if Minimizer.Lifecycle and Minimizer.Lifecycle.IsGenerationStale then
            if Minimizer.Lifecycle.IsGenerationStale(unit, retry.gen) then
                pendingRetries[unit] = nil
                return
            end
        end

        local applied = Minimizer.HitTest.Sync(unit)
        if applied or retry.remaining <= 1 then
            pendingRetries[unit] = nil
            return
        end

        retry.remaining = retry.remaining - 1
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
