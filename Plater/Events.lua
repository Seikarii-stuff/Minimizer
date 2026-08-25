local _, Minimizer = ...
if not Minimizer then return end

local EventFrame = CreateFrame("Frame", "MinimizerEventFrame")
local lastInterruptReady

local function UpdateNameplates()
    if Minimizer.Dispatcher and Minimizer.Dispatcher.RequestApplyToAll then
        Minimizer.Dispatcher.RequestApplyToAll()
    end
    if Minimizer.MyDebuff and Minimizer.MyDebuff.UpdateAll then
        Minimizer.MyDebuff:UpdateAll()
    end
end

local function IsPipelineRelevant(unit)
    if Minimizer.Dispatcher and Minimizer.Dispatcher.IsPipelineRelevant then
        return Minimizer.Dispatcher.IsPipelineRelevant(unit)
    end
    return true
end

local function InvalidateAllThreat()
    if Minimizer.Cache and Minimizer.Cache.InvalidateAll then
        Minimizer.Cache.InvalidateAll("threat")
    end
end

local handlers = {}

local function HandleFullRefreshEvent(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        local activePlates = (Minimizer.Lifecycle and Minimizer.Lifecycle.GetActiveNameplates and Minimizer.Lifecycle.GetActiveNameplates()) or Minimizer.ActiveNameplates
        if activePlates then
            for _, nameplate in pairs(activePlates) do
                nameplate.MinimizerDesimplifiedPersistent = nil
                nameplate.MinimizerDesimplifiedPersistentGen = nil
            end
        end
        InvalidateAllThreat()
    end
    if event == "PLAYER_REGEN_DISABLED" then InvalidateAllThreat() end
    if event == "PLAYER_ENTERING_WORLD" then
        if Minimizer.Threat and Minimizer.Threat.RefreshTankTokens then Minimizer.Threat.RefreshTankTokens() end
        if Minimizer.Threat and Minimizer.Threat.InvalidatePlayerTankCache then Minimizer.Threat.InvalidatePlayerTankCache() end
        InvalidateAllThreat()
        if Minimizer.Dispatcher and Minimizer.Dispatcher.UpdateMonitorState then Minimizer.Dispatcher.UpdateMonitorState() end
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
    if Minimizer.Overlays and Minimizer.Overlays.OnUnitChanged then Minimizer.Overlays.OnUnitChanged("target", "target") end
end

handlers["PLAYER_FOCUS_CHANGED"] = function(self, event)
    HandleFullRefreshEvent(self, event)
    if Minimizer.Overlays and Minimizer.Overlays.OnUnitChanged then Minimizer.Overlays.OnUnitChanged("focus", "focus") end
end

local function HandleUnitStateChange(self, event, unit)
    if unit and unit:match("^nameplate%d+$") then
        if not IsPipelineRelevant(unit) then return end
        if Minimizer.Dispatcher and Minimizer.Dispatcher.ApplyToUnit then Minimizer.Dispatcher.ApplyToUnit(unit) end
        if Minimizer.MyDebuff then Minimizer.MyDebuff:OnUnitChanged(unit, "aura") end
    end
end
handlers["UNIT_DISPLAYPOWER"] = HandleUnitStateChange
handlers["UNIT_CLASSIFICATION_CHANGED"] = HandleUnitStateChange
handlers["UNIT_LEVEL"] = HandleUnitStateChange
handlers["UNIT_ABSORB_AMOUNT_CHANGED"] = HandleUnitStateChange
handlers["UNIT_AURA"] = HandleUnitStateChange

local function HandleThreatEvent(self, event, unit)
    if unit and unit:match("^nameplate%d+$") then
        if not IsPipelineRelevant(unit) then return end
        if Minimizer.Threat and Minimizer.Threat.Invalidate then Minimizer.Threat.Invalidate(unit)
        elseif Minimizer.Cache and Minimizer.Cache.InvalidateUnit then Minimizer.Cache.InvalidateUnit(unit, "threat") end
        if Minimizer.Dispatcher and Minimizer.Dispatcher.ApplyToUnit then Minimizer.Dispatcher.ApplyToUnit(unit) end
    else
        InvalidateAllThreat()
        UpdateNameplates()
    end
end
handlers["UNIT_THREAT_SITUATION_UPDATE"] = HandleThreatEvent
handlers["UNIT_THREAT_LIST_UPDATE"] = HandleThreatEvent

local function HandleRosterOrSpecChange(self, event)
    if Minimizer.Threat and Minimizer.Threat.RefreshTankTokens then Minimizer.Threat.RefreshTankTokens() end
    if Minimizer.Threat and Minimizer.Threat.RefreshPlayerTankCache then Minimizer.Threat.RefreshPlayerTankCache() end
    InvalidateAllThreat()
    if Minimizer.Dispatcher and Minimizer.Dispatcher.UpdateMonitorState then Minimizer.Dispatcher.UpdateMonitorState() end
    if Minimizer.Widgets and Minimizer.Widgets.InvalidateCDSpellCache then Minimizer.Widgets.InvalidateCDSpellCache() end
    if Minimizer.Interrupt and Minimizer.Interrupt.InvalidateSpellIDCache then Minimizer.Interrupt.InvalidateSpellIDCache() end
    if Minimizer.Menu and Minimizer.Menu.Refresh and Minimizer.Menu.IsOpen and Minimizer.Menu.IsOpen() then Minimizer.Menu.Refresh() end
    UpdateNameplates()
end
handlers["PLAYER_ROLES_ASSIGNED"] = HandleRosterOrSpecChange
handlers["GROUP_ROSTER_UPDATE"] = HandleRosterOrSpecChange
handlers["PLAYER_TALENT_UPDATE"] = HandleRosterOrSpecChange
handlers["PLAYER_SPECIALIZATION_CHANGED"] = HandleRosterOrSpecChange

local function HandleCastEvent(self, event, unit)
    if not unit or not unit:match("^nameplate%d+$") then return end
    if not IsPipelineRelevant(unit) then return end
    if Minimizer.Cast and Minimizer.Cast.InvalidateState then Minimizer.Cast.InvalidateState(unit) end
    if Minimizer.Dispatcher and Minimizer.Dispatcher.ApplyToUnit then Minimizer.Dispatcher.ApplyToUnit(unit) end
end
for _, evt in ipairs({
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_INTERRUPTIBLE",
    "UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_STOP",
    "UNIT_SPELLCAST_EMPOWER_UPDATE",
}) do handlers[evt] = HandleCastEvent end

handlers["SPELL_UPDATE_COOLDOWN"] = function(self, event)
    if Minimizer.Interrupt and Minimizer.Interrupt.RefreshReadyCache then Minimizer.Interrupt.RefreshReadyCache() end
    local ready = Minimizer.Interrupt and Minimizer.Interrupt.IsReady and Minimizer.Interrupt.IsReady()
    if ready ~= nil and not Minimizer.Utils.IsSecretValue(ready) and ready ~= lastInterruptReady then
        lastInterruptReady = ready
        UpdateNameplates()
    end
    if Minimizer.Overlays and Minimizer.Overlays.OnCooldownTick then Minimizer.Overlays.OnCooldownTick() end
end

handlers["NAME_PLATE_UNIT_ADDED"] = function(self, event, unit)
    if unit and unit:match("^nameplate%d+$") then
        if Minimizer.Lifecycle and Minimizer.Lifecycle.IncrementGeneration then Minimizer.Lifecycle.IncrementGeneration(unit) end
        if Minimizer.Threat and Minimizer.Threat.ForgetUnit then Minimizer.Threat.ForgetUnit(unit) end
        if IsPipelineRelevant(unit) then
            if Minimizer.Dispatcher and Minimizer.Dispatcher.TrackUnit then Minimizer.Dispatcher.TrackUnit(unit) end
            if Minimizer.Threat and Minimizer.Threat.Invalidate then Minimizer.Threat.Invalidate(unit) end
            if Minimizer.Dispatcher and Minimizer.Dispatcher.ApplyToUnit then Minimizer.Dispatcher.ApplyToUnit(unit) end
            UpdateNameplates()
        elseif Minimizer.Dispatcher and Minimizer.Dispatcher.ForgetUnit then
            Minimizer.Dispatcher.ForgetUnit(unit)
        end
        if Minimizer.Overlays and Minimizer.Overlays.OnUnitChanged then Minimizer.Overlays.OnUnitChanged(unit, "added") end
    end
end

handlers["NAME_PLATE_UNIT_REMOVED"] = function(self, event, unit)
    if Minimizer.Threat and Minimizer.Threat.ForgetUnit then Minimizer.Threat.ForgetUnit(unit) end
    if Minimizer.Dispatcher and Minimizer.Dispatcher.ForgetUnit then Minimizer.Dispatcher.ForgetUnit(unit) end
    if Minimizer.Overlays and Minimizer.Overlays.OnUnitChanged then Minimizer.Overlays.OnUnitChanged(unit, "removed") end
end

local function OnEvent(self, event, ...)
    local handler = handlers[event]
    if handler then handler(self, event, ...) end
end

for _, event in ipairs({
    "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_DIFFICULTY_CHANGED",
    "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "PLAYER_ROLES_ASSIGNED", "GROUP_ROSTER_UPDATE", "PLAYER_TALENT_UPDATE", "PLAYER_SPECIALIZATION_CHANGED",
    "SPELL_UPDATE_COOLDOWN", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UNIT_DISPLAYPOWER",
    "UNIT_CLASSIFICATION_CHANGED", "UNIT_LEVEL", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_AURA",
    "UNIT_THREAT_SITUATION_UPDATE", "UNIT_THREAT_LIST_UPDATE", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_INTERRUPTIBLE",
    "UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_STOP",
    "UNIT_SPELLCAST_EMPOWER_UPDATE",
}) do EventFrame:RegisterEvent(event) end
EventFrame:SetScript("OnEvent", OnEvent)

if Minimizer.Dispatcher and Minimizer.Dispatcher.StartMonitor then Minimizer.Dispatcher.StartMonitor() end

if NamePlateDriverFrame then
    hooksecurefunc(NamePlateDriverFrame, "OnNamePlateRemoved", function(_, unit)
        if not unit or not unit:match("^nameplate%d+$") then return end
        if Minimizer.Lifecycle and Minimizer.Lifecycle.ClearNeverSimplify then Minimizer.Lifecycle.ClearNeverSimplify(unit) end
    end)
end

if CompactUnitFrame_UpdateHealthColor then
    hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(unitFrame)
        local unit = unitFrame and unitFrame.unit
        if unit and unit:match("^nameplate%d+$") then
            if Minimizer.Dispatcher and Minimizer.Dispatcher.ApplyToUnit then Minimizer.Dispatcher.ApplyToUnit(unit) end
        end
    end)
end
