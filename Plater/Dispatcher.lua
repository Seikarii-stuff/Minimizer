local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Dispatcher = Minimizer.Dispatcher or {}

local C_NamePlateManager = C_NamePlateManager

local _isApplying = false
local _pendingReentrantUnits = {}
-- The maximum number of reentrant passes allowed per ApplyToUnit cycle.
-- This guarantees that the system will eventually yield even if a module 
-- incorrectly triggers an infinite update loop (e.g., A updates B, B updates A).
-- Reaching this limit indicates a bug in module event handling.
local MAX_REENTRANT_PASSES = 10

local function IsPipelineRelevant(unit)
    if not unit or not UnitExists(unit) then return false end
    if Minimizer.Utils then
        if Minimizer.Utils.IsFriendlyUnit and Minimizer.Utils.IsFriendlyUnit(unit) then
            return false
        end
        -- PvP nameplates are owned by Blizzard; reuse the canonical PvP
        -- predicate that the rendering modules already use.
        if Minimizer.Utils.IsPvPUnit and Minimizer.Utils.IsPvPUnit(unit) then
            return false
        end
    end
    return true
end

-- Friendly and PvP nameplates are intentionally excluded before registration/snapshot/module work.
-- Target/Focus overlays resolve their plates directly and do not depend on ActiveNameplates.
Minimizer.Dispatcher.IsPipelineRelevant = IsPipelineRelevant

local function ApplyToUnitInternal(unit, forceUpdate)
    if not IsPipelineRelevant(unit) then return end

    local nameplate = Minimizer.Utils and Minimizer.Utils.GetNamePlateForUnit and Minimizer.Utils.GetNamePlateForUnit(unit)
    if not nameplate then return end
    local npToken = Minimizer.Utils and Minimizer.Utils.GetValidNamePlateToken and Minimizer.Utils.GetValidNamePlateToken(unit, nameplate)
    if not npToken then return end

    if Minimizer.Lifecycle and Minimizer.Lifecycle.RegisterNameplate then
        Minimizer.Lifecycle.RegisterNameplate(npToken, nameplate)
    else
        Minimizer.ActiveNameplates[npToken] = nameplate
    end

    local snapshot = Minimizer.Snapshot and Minimizer.Snapshot.Build and Minimizer.Snapshot.Build(npToken, nameplate)

    local shouldSimplify = false
    local reason = ""
    local currentGen = (Minimizer.Lifecycle and Minimizer.Lifecycle.GetGeneration and Minimizer.Lifecycle.GetGeneration(npToken)) or 0

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

function Minimizer.Dispatcher.ApplyToUnit(unit, forceUpdate)
    if not unit then return end
    if _isApplying then
        _pendingReentrantUnits[unit] = (forceUpdate == true) or (_pendingReentrantUnits[unit] == true) or false
        return
    end

    _isApplying = true
    ApplyToUnitInternal(unit, forceUpdate)

    local pass = 0
    while next(_pendingReentrantUnits) and pass < MAX_REENTRANT_PASSES do
        pass = pass + 1
        local currentBatch = _pendingReentrantUnits
        _pendingReentrantUnits = {}
        for queuedUnit, queuedForce in pairs(currentBatch) do
            ApplyToUnitInternal(queuedUnit, queuedForce)
        end
    end

    if pass >= MAX_REENTRANT_PASSES and next(_pendingReentrantUnits) then
        if Minimizer.Utils and Minimizer.Utils.LogGuardedError then
            Minimizer.Utils.LogGuardedError("Dispatcher", "Runaway recursion detected: MAX_REENTRANT_PASSES limit reached. Breaking loop to prevent crash.")
        else
            print("|cFFFF0000[Minimizer] Runaway recursion in Dispatcher. Breaking loop.|r")
        end
        wipe(_pendingReentrantUnits)
    end
    _isApplying = false
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

local monitorFrame
local monitorRunning = false
local monitorElapsed = 0
local monitorStep = 1
local monitorUnits = {}
local monitorCount = 0
local monitorState = {}
local monitorDirty = true

local function IsNameplateToken(unit)
    return type(unit) == "string" and unit:match("^nameplate%d+$") ~= nil
end

local function RebuildMonitorUnits()
    if not monitorDirty then return end
    monitorDirty = false
    wipe(monitorUnits)
    monitorCount = 0
    local activePlates = (Minimizer.Lifecycle and Minimizer.Lifecycle.GetActiveNameplates and Minimizer.Lifecycle.GetActiveNameplates())
        or Minimizer.ActiveNameplates
    if not activePlates then return end
    for unit in pairs(activePlates) do
        if IsNameplateToken(unit) then
            monitorCount = monitorCount + 1
            monitorUnits[monitorCount] = unit
        end
    end
    if monitorStep > monitorCount then monitorStep = 1 end
end

function Minimizer.Dispatcher.TrackUnit(unit)
    if IsNameplateToken(unit) then monitorDirty = true end
end

function Minimizer.Dispatcher.ForgetUnit(unit)
    if unit then
        if Minimizer.Lifecycle and Minimizer.Lifecycle.UnregisterNameplate then
            Minimizer.Lifecycle.UnregisterNameplate(unit)
        else
            Minimizer.ActiveNameplates[unit] = nil
        end
        monitorState[unit] = nil
        monitorDirty = true
    end
end

local function ProcessMonitoredUnit(unit)
    if not IsNameplateToken(unit) then return end
    local activePlates = (Minimizer.Lifecycle and Minimizer.Lifecycle.GetActiveNameplates and Minimizer.Lifecycle.GetActiveNameplates())
        or Minimizer.ActiveNameplates
    if not activePlates or not activePlates[unit] then
        monitorState[unit] = nil
        monitorDirty = true
        return
    end
    if not UnitExists(unit) then return end

    if not Minimizer.Threat or not Minimizer.Threat.GetUnitThreatState then return end
    local currentState = Minimizer.Threat.GetUnitThreatState(unit)
    if not currentState then return end

    local previousState = monitorState[unit]
    local changed = not previousState or not Minimizer.Threat.StatesEqual(currentState, previousState)
    if changed then
        monitorState[unit] = currentState
        Minimizer.Dispatcher.RequestUpdate(unit)
    end
end

local function OnMonitorUpdate(_, elapsed)
    RebuildMonitorUnits()
    if monitorCount == 0 then
        monitorElapsed = 0
        return
    end
    monitorElapsed = monitorElapsed + elapsed
    local interval = 0.25 / monitorCount
    if monitorElapsed < interval then return end
    monitorElapsed = monitorElapsed - interval
    if monitorStep > monitorCount then monitorStep = 1 end
    local unit = monitorUnits[monitorStep]
    monitorStep = monitorStep + 1
    ProcessMonitoredUnit(unit)
end

function Minimizer.Dispatcher.UpdateMonitorState()
    local enabled = Minimizer.Threat and Minimizer.Threat.IsThreatEnabled and Minimizer.Threat.IsThreatEnabled()
    if enabled then
        if not monitorFrame then
            monitorFrame = CreateFrame("Frame")
        end
        if not monitorRunning then
            monitorRunning = true
            monitorElapsed = 0
            monitorDirty = true
            monitorFrame:SetScript("OnUpdate", OnMonitorUpdate)
        end
    else
        if monitorRunning and monitorFrame then
            monitorRunning = false
            monitorFrame:SetScript("OnUpdate", nil)
        end
    end
end

function Minimizer.Dispatcher.StartMonitor()
    Minimizer.Dispatcher.UpdateMonitorState()
end
