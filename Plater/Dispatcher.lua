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

local monitorFrame
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
    local details = Minimizer.Threat and Minimizer.Threat.GetThreatDetails and Minimizer.Threat.GetThreatDetails(unit)
    if not details then return end
    local combat = Minimizer.Threat and Minimizer.Threat.IsInCombatWith and Minimizer.Threat.IsInCombatWith(unit, details)
    local generation = (Minimizer.Lifecycle and Minimizer.Lifecycle.GetGeneration and Minimizer.Lifecycle.GetGeneration(unit))
        or (Minimizer.Core and Minimizer.Core.GetPlateGeneration and Minimizer.Core.GetPlateGeneration(unit))
        or 0
    local previous = monitorState[unit]
    local changed = not previous
        or previous.generation ~= generation
        or previous.situation ~= details.situation
        or previous.otherTankAggro ~= details.otherTankAggro
        or previous.combat ~= combat
        or previous.nilSpecial ~= details.nilSpecial
    if previous then
        previous.generation     = generation
        previous.situation      = details.situation
        previous.otherTankAggro = details.otherTankAggro
        previous.combat         = combat
        previous.nilSpecial     = details.nilSpecial
    else
        monitorState[unit] = {
            generation     = generation,
            situation      = details.situation,
            otherTankAggro = details.otherTankAggro,
            combat         = combat,
            nilSpecial     = details.nilSpecial,
        }
    end
    if changed then
        Minimizer.Dispatcher.RequestUpdate(unit)
    end
end

function Minimizer.Dispatcher.StartMonitor()
    if monitorFrame then return end
    if Minimizer.Threat and Minimizer.Threat.IsThreatEnabled and not Minimizer.Threat.IsThreatEnabled() then
        return
    end
    RebuildMonitorUnits()
    monitorFrame = CreateFrame("Frame")
    monitorFrame:SetScript("OnUpdate", function(_, elapsed)
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
    end)
end

-- Backward compatibility aliases on Minimizer.Core
Minimizer.Core = Minimizer.Core or {}
Minimizer.Core.ApplyToUnit = Minimizer.Dispatcher.ApplyToUnit
Minimizer.Core.ApplyToAll = Minimizer.Dispatcher.ApplyToAll
Minimizer.Core.RequestApplyToAll = Minimizer.Dispatcher.RequestApplyToAll
Minimizer.Core.StartSafetyNet = Minimizer.Dispatcher.StartSafetyNet