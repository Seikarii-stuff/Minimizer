local _, Minimizer = ...
if not Minimizer or not Minimizer.Core then return end

local EventFrame = CreateFrame("Frame", "MinimizerEventFrame")
local lastInterruptReady

local function UpdateNameplates()
    if Minimizer.Core.RequestApplyToAll then
        Minimizer.Core.RequestApplyToAll()
    end
end

local function OnEvent(self, event, unit, ...)
    if event == "PLAYER_ENTERING_WORLD"
        or event == "ZONE_CHANGED_NEW_AREA"
        or event == "PLAYER_DIFFICULTY_CHANGED"
        or event == "PLAYER_TARGET_CHANGED"
        or event == "PLAYER_FOCUS_CHANGED"
        or event == "PLAYER_REGEN_DISABLED"
        or event == "PLAYER_REGEN_ENABLED" then
        if event == "PLAYER_REGEN_ENABLED" then
            if C_NamePlate and C_NamePlate.GetNamePlates then
                for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
                    nameplate.MinimizerDesimplifiedPersistent = nil
                end
            end
        end
        if event == "PLAYER_ENTERING_WORLD" then
            if Minimizer.Threat and Minimizer.Threat.RefreshTankTokens then
                Minimizer.Threat.RefreshTankTokens()
            end
        end
        UpdateNameplates()
    elseif event == "UNIT_DISPLAYPOWER"
        or event == "UNIT_CLASSIFICATION_CHANGED"
        or event == "UNIT_LEVEL" then
        Minimizer.Core.ApplyToUnit(unit)
    elseif event == "UNIT_THREAT_SITUATION_UPDATE"
        or event == "UNIT_THREAT_LIST_UPDATE"
        or event == "PLAYER_ROLES_ASSIGNED"
        or event == "GROUP_ROSTER_UPDATE"
        or event == "PLAYER_TALENT_UPDATE"
        or event == "PLAYER_SPECIALIZATION_CHANGED" then
        if event == "UNIT_THREAT_SITUATION_UPDATE" or event == "UNIT_THREAT_LIST_UPDATE" then
            if unit and unit:match("^nameplate%d+$") then
                if Minimizer.Cache.InvalidateUnit then
                    Minimizer.Cache.InvalidateUnit(unit, "threat")
                end
                Minimizer.Core.ApplyToUnit(unit)
            else
                if Minimizer.Cache.InvalidateAll then
                    Minimizer.Cache.InvalidateAll("threat")
                end
                UpdateNameplates()
            end
        end
        if event == "PLAYER_ROLES_ASSIGNED" or event == "GROUP_ROSTER_UPDATE"
            or event == "PLAYER_TALENT_UPDATE" or event == "PLAYER_SPECIALIZATION_CHANGED" then
            if Minimizer.Threat and Minimizer.Threat.RefreshTankTokens then
                Minimizer.Threat.RefreshTankTokens()
            end
            UpdateNameplates()
        end
    elseif event == "UNIT_SPELLCAST_START"
        or event == "UNIT_SPELLCAST_STOP"
        or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_INTERRUPTED"
        or event == "UNIT_SPELLCAST_INTERRUPTIBLE"
        or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE"
        or event == "UNIT_SPELLCAST_CHANNEL_START"
        or event == "UNIT_SPELLCAST_CHANNEL_STOP"
        or event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
        or event == "UNIT_SPELLCAST_EMPOWER_START"
        or event == "UNIT_SPELLCAST_EMPOWER_STOP"
        or event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then
        if Minimizer.Cache.InvalidateUnit then
            Minimizer.Cache.InvalidateUnit(unit, "absorb")
        end
        if Minimizer.Cast and Minimizer.Cast.InvalidateState then
            Minimizer.Cast.InvalidateState(unit)
        end
        Minimizer.Core.ApplyToUnit(unit)
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        local interrupt = Minimizer.Interrupt
        local ready = interrupt and interrupt.IsReady and interrupt.IsReady()
        if ready ~= nil and not Minimizer.Utils.IsSecretValue(ready)
            and ready ~= lastInterruptReady then
            lastInterruptReady = ready
            UpdateNameplates()
        end
    end
end

-- Global events
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
EventFrame:SetScript("OnEvent", OnEvent)

-- Secure Hooks canónicos
if NamePlateDriverFrame then
    hooksecurefunc(NamePlateDriverFrame, "OnNamePlateAdded", function(_, unit)
        if unit then 
            C_Timer.After(0.01, function() Minimizer.Core.ApplyToUnit(unit) end) 
            
            local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
            if nameplate then
                if not nameplate.MinimizerEventFrame then
                    nameplate.MinimizerEventFrame = CreateFrame("Frame", nil, nameplate)
                    nameplate.MinimizerEventFrame:SetScript("OnEvent", function(self, event, evUnit, ...)
                        OnEvent(EventFrame, event, evUnit, ...)
                    end)
                end
                local ef = nameplate.MinimizerEventFrame
                ef:RegisterUnitEvent("UNIT_DISPLAYPOWER", unit)
                ef:RegisterUnitEvent("UNIT_CLASSIFICATION_CHANGED", unit)
                ef:RegisterUnitEvent("UNIT_LEVEL", unit)
                ef:RegisterUnitEvent("UNIT_THREAT_SITUATION_UPDATE", unit)
                ef:RegisterUnitEvent("UNIT_THREAT_LIST_UPDATE", unit)
                ef:RegisterUnitEvent("UNIT_SPELLCAST_START", unit)
                ef:RegisterUnitEvent("UNIT_SPELLCAST_STOP", unit)
                ef:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", unit)
                ef:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", unit)
                ef:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", unit)
                ef:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", unit)
                ef:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", unit)
                ef:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", unit)
                ef:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", unit)
                ef:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", unit)
                ef:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", unit)
                ef:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_UPDATE", unit)
            end
        end
    end)
    hooksecurefunc(NamePlateDriverFrame, "OnNamePlateRemoved", function(_, unit)
        if unit then 
            Minimizer.Core.ClearNeverSimplify(unit)
            local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
            if nameplate and nameplate.MinimizerEventFrame then
                nameplate.MinimizerEventFrame:UnregisterAllEvents()
            end
        end
    end)
end

if CompactUnitFrame_UpdateHealthColor then
    hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(unitFrame)
        local unit = unitFrame and unitFrame.unit
        if unit then Minimizer.Core.ApplyToUnit(unit) end
    end)
end
