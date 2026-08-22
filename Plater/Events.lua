local _, Minimizer = ...
if not Minimizer or not Minimizer.Core then return end

local EventFrame = CreateFrame("Frame", "MinimizerEventFrame")
local lastInterruptReady

local function UpdateNameplates()
    if Minimizer.Dispatcher and Minimizer.Dispatcher.RequestApplyToAll then
        Minimizer.Dispatcher.RequestApplyToAll()
    end
end

local function InvalidateAllThreat()
    if Minimizer.Cache and Minimizer.Cache.InvalidateAll then
        Minimizer.Cache.InvalidateAll("threat")
    end
end

local handlers = {}

local function HandleFullRefreshEvent(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if C_NamePlate and C_NamePlate.GetNamePlates then
            for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
                nameplate.MinimizerDesimplifiedPersistent = nil
                nameplate.MinimizerDesimplifiedPersistentGen = nil
            end
        end
        InvalidateAllThreat()
    end
    if event == "PLAYER_REGEN_DISABLED" then
        InvalidateAllThreat()
    end
    if event == "PLAYER_ENTERING_WORLD" then
        if Minimizer.Threat and Minimizer.Threat.RefreshTankTokens then
            Minimizer.Threat.RefreshTankTokens()
        end
        if Minimizer.Threat and Minimizer.Threat.InvalidatePlayerTankCache then
            Minimizer.Threat.InvalidatePlayerTankCache()
        end
        InvalidateAllThreat()
        if Minimizer.Dispatcher and Minimizer.Dispatcher.UpdateMonitorState then
            Minimizer.Dispatcher.UpdateMonitorState()
        end
    end
    UpdateNameplates()
end
handlers["PLAYER_ENTERING_WORLD"] = HandleFullRefreshEvent
handlers["ZONE_CHANGED_NEW_AREA"] = HandleFullRefreshEvent
handlers["PLAYER_DIFFICULTY_CHANGED"] = HandleFullRefreshEvent
handlers["PLAYER_REGEN_DISABLED"] = HandleFullRefreshEvent
handlers["PLAYER_REGEN_ENABLED"] = HandleFullRefreshEvent

handlers["PLAYER_TARGET_CHANGED"] = function(self, event)
    HandleFullRefreshEvent(self, event)
    if Minimizer.Overlays and Minimizer.Overlays.OnUnitChanged then
        Minimizer.Overlays.OnUnitChanged("target", "target")
    elseif Minimizer.Target and Minimizer.Target.UpdateTargetCDs then
        Minimizer.Target:UpdateTargetCDs()
    end
end

handlers["PLAYER_FOCUS_CHANGED"] = function(self, event)
    HandleFullRefreshEvent(self, event)
    if Minimizer.Overlays and Minimizer.Overlays.OnUnitChanged then
        Minimizer.Overlays.OnUnitChanged("focus", "focus")
    elseif Minimizer.Focus and Minimizer.Focus.UpdateFace then
        Minimizer.Focus.UpdateFace()
    end
end


local function HandleUnitStateChange(self, event, unit)
    if unit and unit:match("^nameplate%d+$") then
        if Minimizer.Dispatcher and Minimizer.Dispatcher.ApplyToUnit then
            Minimizer.Dispatcher.ApplyToUnit(unit)
        end
    end
end
handlers["UNIT_DISPLAYPOWER"] = HandleUnitStateChange
handlers["UNIT_CLASSIFICATION_CHANGED"] = HandleUnitStateChange
handlers["UNIT_LEVEL"] = HandleUnitStateChange
handlers["UNIT_ABSORB_AMOUNT_CHANGED"] = function(self, event, unit)
    if unit and unit:match("^nameplate%d+$") then
        if Minimizer.Dispatcher and Minimizer.Dispatcher.ApplyToUnit then
            Minimizer.Dispatcher.ApplyToUnit(unit)
        end
    end
end

local function HandleThreatEvent(self, event, unit)
    if unit and unit:match("^nameplate%d+$") then
        if Minimizer.Threat and Minimizer.Threat.Invalidate then
            Minimizer.Threat.Invalidate(unit)
        elseif Minimizer.Cache and Minimizer.Cache.InvalidateUnit then
            Minimizer.Cache.InvalidateUnit(unit, "threat")
        end
        if Minimizer.Dispatcher and Minimizer.Dispatcher.ApplyToUnit then
            Minimizer.Dispatcher.ApplyToUnit(unit)
        end
    else
        InvalidateAllThreat()
        UpdateNameplates()
    end
end

handlers["UNIT_THREAT_SITUATION_UPDATE"] = HandleThreatEvent
handlers["UNIT_THREAT_LIST_UPDATE"] = HandleThreatEvent

local function HandleRosterOrSpecChange(self, event)
    if Minimizer.Threat and Minimizer.Threat.RefreshTankTokens then
        Minimizer.Threat.RefreshTankTokens()
    end
    if Minimizer.Threat and Minimizer.Threat.RefreshPlayerTankCache then
        Minimizer.Threat.RefreshPlayerTankCache()
    end
    InvalidateAllThreat()
    if Minimizer.Dispatcher and Minimizer.Dispatcher.UpdateMonitorState then
        Minimizer.Dispatcher.UpdateMonitorState()
    end
    if Minimizer.Widgets and Minimizer.Widgets.InvalidateCDSpellCache then
        Minimizer.Widgets.InvalidateCDSpellCache()
    end
    if Minimizer.Interrupt and Minimizer.Interrupt.InvalidateSpellIDCache then
        Minimizer.Interrupt.InvalidateSpellIDCache()
    end
    if Minimizer.Menu and Minimizer.Menu.Refresh and Minimizer.Menu.IsOpen and Minimizer.Menu.IsOpen() then
        Minimizer.Menu.Refresh()
    end
    UpdateNameplates()
end
handlers["PLAYER_ROLES_ASSIGNED"] = HandleRosterOrSpecChange
handlers["GROUP_ROSTER_UPDATE"] = HandleRosterOrSpecChange
handlers["PLAYER_TALENT_UPDATE"] = HandleRosterOrSpecChange
handlers["PLAYER_SPECIALIZATION_CHANGED"] = HandleRosterOrSpecChange

local function HandleCastEvent(self, event, unit)
    if not unit or not unit:match("^nameplate%d+$") then return end
    if Minimizer.Cast and Minimizer.Cast.InvalidateState then
        Minimizer.Cast.InvalidateState(unit)
    end
    if Minimizer.Dispatcher and Minimizer.Dispatcher.ApplyToUnit then
        Minimizer.Dispatcher.ApplyToUnit(unit)
    end
end
for _, evt in ipairs({
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_INTERRUPTIBLE",
    "UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_STOP",
    "UNIT_SPELLCAST_EMPOWER_UPDATE",
}) do
    handlers[evt] = HandleCastEvent
end

handlers["SPELL_UPDATE_COOLDOWN"] = function(self, event)
    if Minimizer.Interrupt and Minimizer.Interrupt.RefreshReadyCache then
        Minimizer.Interrupt.RefreshReadyCache()
    end
    local ready = Minimizer.Interrupt and Minimizer.Interrupt.IsReady and Minimizer.Interrupt.IsReady()
    if ready ~= nil and not Minimizer.Utils.IsSecretValue(ready) and ready ~= lastInterruptReady then
        lastInterruptReady = ready
        UpdateNameplates()
    end
    if Minimizer.Overlays and Minimizer.Overlays.OnCooldownTick then
        Minimizer.Overlays.OnCooldownTick()
    else
        if Minimizer.Target and Minimizer.Target.DebouncedUpdate then
            Minimizer.Target.DebouncedUpdate()
        end
        if Minimizer.Focus and Minimizer.Focus.DebouncedUpdate then
            Minimizer.Focus.DebouncedUpdate()
        end
    end
end

handlers["NAME_PLATE_UNIT_ADDED"] = function(self, event, unit)
    if unit and unit:match("^nameplate%d+$") then
        if Minimizer.Lifecycle and Minimizer.Lifecycle.IncrementGeneration then
            Minimizer.Lifecycle.IncrementGeneration(unit)
        end
        if Minimizer.Threat and Minimizer.Threat.ForgetUnit then
            Minimizer.Threat.ForgetUnit(unit)
        end
        if Minimizer.Dispatcher and Minimizer.Dispatcher.TrackUnit then
            Minimizer.Dispatcher.TrackUnit(unit)
        end
        if Minimizer.Threat and Minimizer.Threat.Invalidate then
            Minimizer.Threat.Invalidate(unit)
        end
        if Minimizer.Dispatcher and Minimizer.Dispatcher.ApplyToUnit then
            Minimizer.Dispatcher.ApplyToUnit(unit)
        end
        UpdateNameplates()
        if Minimizer.Overlays and Minimizer.Overlays.OnUnitChanged then
            Minimizer.Overlays.OnUnitChanged(unit, "added")
        else
            if Minimizer.Target and Minimizer.Target.UpdateTargetCDs then
                if not unit or UnitIsUnit(unit, "target") then
                    Minimizer.Target:UpdateTargetCDs()
                end
            end
            if Minimizer.Focus and Minimizer.Focus.UpdateFace then
                Minimizer.Focus.UpdateFace()
            end
        end
    end
end

handlers["NAME_PLATE_UNIT_REMOVED"] = function(self, event, unit)
    if Minimizer.Threat and Minimizer.Threat.ForgetUnit then
        Minimizer.Threat.ForgetUnit(unit)
    end
    if Minimizer.Dispatcher and Minimizer.Dispatcher.ForgetUnit then
        Minimizer.Dispatcher.ForgetUnit(unit)
    end
    if Minimizer.Overlays and Minimizer.Overlays.OnUnitChanged then
        Minimizer.Overlays.OnUnitChanged(unit, "removed")
    else
        if Minimizer.Target and Minimizer.Target.UpdateTargetCDs then
            if not unit or UnitIsUnit(unit, "target") then
                Minimizer.Target:UpdateTargetCDs()
            end
        end
        if Minimizer.Focus and Minimizer.Focus.UpdateFace then
            Minimizer.Focus.UpdateFace()
        end
    end
end

local function OnEvent(self, event, ...)
    local handler = handlers[event]
    if handler then
        handler(self, event, ...)
    end
end

EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
EventFrame:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
EventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
EventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
EventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
EventFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
EventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
EventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
EventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
EventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
EventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
EventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
EventFrame:RegisterEvent("UNIT_DISPLAYPOWER")
EventFrame:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
EventFrame:RegisterEvent("UNIT_LEVEL")
EventFrame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
EventFrame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
EventFrame:RegisterEvent("UNIT_SPELLCAST_START")
EventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
EventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
EventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
EventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
EventFrame:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
EventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
EventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
EventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
EventFrame:RegisterEvent("UNIT_SPELLCAST_EMPOWER_START")
EventFrame:RegisterEvent("UNIT_SPELLCAST_EMPOWER_STOP")
EventFrame:RegisterEvent("UNIT_SPELLCAST_EMPOWER_UPDATE")
EventFrame:SetScript("OnEvent", OnEvent)

if Minimizer.Dispatcher and Minimizer.Dispatcher.StartMonitor then
    Minimizer.Dispatcher.StartMonitor()
end

if NamePlateDriverFrame then
    hooksecurefunc(NamePlateDriverFrame, "OnNamePlateRemoved", function(_, unit)
        if not unit or not unit:match("^nameplate%d+$") then return end
        if Minimizer.Lifecycle and Minimizer.Lifecycle.ClearNeverSimplify then
            Minimizer.Lifecycle.ClearNeverSimplify(unit)
        end
    end)
end

if CompactUnitFrame_UpdateHealthColor then
    hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(unitFrame)
        if unitFrame and unitFrame.MinimizerLetBlizzardHealthColor then
            return
        end
        local unit = unitFrame and unitFrame.unit
        if unit and unit:match("^nameplate%d+$") then
            if Minimizer.Dispatcher and Minimizer.Dispatcher.ApplyToUnit then
                Minimizer.Dispatcher.ApplyToUnit(unit)
            end
        end
    end)
end
