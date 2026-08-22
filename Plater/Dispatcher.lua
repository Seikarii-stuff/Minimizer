local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Dispatcher = Minimizer.Dispatcher or {}

local C_NamePlateManager = C_NamePlateManager

function Minimizer.Dispatcher.ApplyToUnit(unit, forceUpdate)
    if not unit then return end
    local nameplate = Minimizer.Utils and Minimizer.Utils.GetNamePlateForUnit and Minimizer.Utils.GetNamePlateForUnit(unit)
    if not nameplate then return end
    local npToken = Minimizer.Utils and Minimizer.Utils.GetValidNamePlateToken and Minimizer.Utils.GetValidNamePlateToken(unit, nameplate)
    if not npToken then return end

    if Minimizer.Lifecycle and Minimizer.Lifecycle.RegisterNameplate then
        Minimizer.Lifecycle.RegisterNameplate(npToken, nameplate)
    else
        Minimizer.ActiveNameplates[npToken] = nameplate
    end

    local snapshot = (Minimizer.Snapshot and Minimizer.Snapshot.Build and Minimizer.Snapshot.Build(npToken, nameplate))
        or (Minimizer.Core and Minimizer.Core.BuildSnapshot and Minimizer.Core.BuildSnapshot(npToken, nameplate))

    local shouldSimplify = false
    local reason = ""
    local currentGen = (Minimizer.Lifecycle and Minimizer.Lifecycle.GetGeneration and Minimizer.Lifecycle.GetGeneration(npToken))
        or (Minimizer.Core and Minimizer.Core.GetPlateGeneration and Minimizer.Core.GetPlateGeneration(npToken))
        or 0

    local isStale
    if Minimizer.Lifecycle and Minimizer.Lifecycle.IsGenerationStale then
        isStale = Minimizer.Lifecycle.IsGenerationStale(npToken, nameplate.MinimizerDesimplifiedPersistentGen)
    else
        isStale = nameplate.MinimizerDesimplifiedPersistentGen ~= currentGen
    end

    if nameplate.MinimizerDesimplifiedPersistent and isStale then
        nameplate.MinimizerDesimplifiedPersistent = nil
        nameplate.MinimizerDesimplifiedPersistentGen = nil
    end

    if nameplate.MinimizerDesimplifiedPersistent then
        shouldSimplify = false
        reason = "no simp (fast-path)"
    else
        if Minimizer.Decision and Minimizer.Decision.ShouldSimplifyUnit then
            shouldSimplify, reason = Minimizer.Decision.ShouldSimplifyUnit(npToken, nameplate, snapshot)
        end
        if reason == "no simp" then
            nameplate.MinimizerDesimplifiedPersistent = true
            nameplate.MinimizerDesimplifiedPersistentGen = currentGen
        end
    end

    if Minimizer.Utils and Minimizer.Utils.IsSimplifiedAvailable and Minimizer.Utils.IsSimplifiedAvailable() then
        if forceUpdate or nameplate.MinimizerState ~= shouldSimplify then
            C_NamePlateManager.SetNamePlateSimplified(npToken, shouldSimplify)
            nameplate.MinimizerState = shouldSimplify
            if Minimizer.HitTest and Minimizer.HitTest.Sync then Minimizer.HitTest.Sync(npToken, nameplate) end
        end
    end

    if Minimizer.Core and Minimizer.Core.UpdateModules then
        Minimizer.Core.UpdateModules(npToken, nameplate, snapshot)
    end
end

function Minimizer.Dispatcher.ApplyToAll(forceUpdate)
    if Minimizer.Interrupt and Minimizer.Interrupt.RefreshReadyCache then
        Minimizer.Interrupt.RefreshReadyCache()
    end
    local activePlates = (Minimizer.Lifecycle and Minimizer.Lifecycle.GetActiveNameplates and Minimizer.Lifecycle.GetActiveNameplates())
        or Minimizer.ActiveNameplates
    for token in pairs(activePlates) do
        Minimizer.Dispatcher.ApplyToUnit(token, forceUpdate)
    end
end

Minimizer.Dispatcher.RequestApplyToAll = Minimizer.Utils.Debounce(function()
    Minimizer.Dispatcher.ApplyToAll(true)
end)

function Minimizer.Dispatcher.RequestUpdate(unit)
    if not unit then return end
    Minimizer.Dispatcher.ApplyToUnit(unit, false)
end

function Minimizer.Dispatcher.RequestFullUpdate()
    Minimizer.Dispatcher.RequestApplyToAll()
end

local SAFETY_NET_INTERVAL = 2.0
local _safetyNetStarted = false

function Minimizer.Dispatcher.StartSafetyNet()
    if _safetyNetStarted then return end
    _safetyNetStarted = true
    C_Timer.NewTicker(SAFETY_NET_INTERVAL, function()
        Minimizer.Dispatcher.ApplyToAll(false)
    end)
end

-- Backward compatibility aliases on Minimizer.Core
Minimizer.Core = Minimizer.Core or {}
Minimizer.Core.ApplyToUnit = Minimizer.Dispatcher.ApplyToUnit
Minimizer.Core.ApplyToAll = Minimizer.Dispatcher.ApplyToAll
Minimizer.Core.RequestApplyToAll = Minimizer.Dispatcher.RequestApplyToAll
Minimizer.Core.StartSafetyNet = Minimizer.Dispatcher.StartSafetyNet