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

    elseif event == "NAME_PLATE_UNIT_ADDED" then
        -- NAME_PLATE_UNIT_ADDED garantiza que el token ya está asignado al frame.
        -- Es el momento canónico para aplicar la simplificación inicial.
        -- Filtramos tokens no-nameplate (ej. "preview" del panel de opciones).
        if unit and unit:match("^nameplate%d+$") then
            Minimizer.Core.ApplyToUnit(unit)
            UpdateNameplates()
        end

    elseif event == "UNIT_DISPLAYPOWER"
        or event == "UNIT_CLASSIFICATION_CHANGED"
        or event == "UNIT_LEVEL" then
        -- Solo actuar sobre nameplates reales
        if unit and unit:match("^nameplate%d+$") then
            Minimizer.Core.ApplyToUnit(unit)
        end

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
                -- Evento global de amenaza (sin token de nameplate): invalida todo
                -- pero no procesa unidades que no sean nameplates enemigas.
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
            if Minimizer.Widgets and Minimizer.Widgets.InvalidateCDSpellCache then
                Minimizer.Widgets.InvalidateCDSpellCache()
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
        -- Filtro explícito: solo nameplates enemigas. Descarta aliados, pets,
        -- party, boss frames que disparen estos eventos globalmente.
        if not unit or not unit:match("^nameplate%d+$") then return end
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

-- Eventos globales (no dependen de unidad específica)
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
-- NAME_PLATE_UNIT_ADDED: garantiza que el token ya está asignado al frame.
EventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
-- Eventos de unidad registrados globalmente. El filtro ^nameplate%d+$ en OnEvent
-- descarta aliados/pets/party. Es más robusto que RegisterUnitEvent por frame
-- en pulls masivos donde los frames pueden no estar listos aún.
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

-- Secure Hooks canónicos
if NamePlateDriverFrame then
    hooksecurefunc(NamePlateDriverFrame, "OnNamePlateAdded", function(_, unit)
        -- Blizzard también llama este hook para "preview" (panel de opciones).
        -- Filtrar cualquier token que no sea nameplate real.
        if not unit or not unit:match("^nameplate%d+$") then return end
        -- El apply lo gestiona NAME_PLATE_UNIT_ADDED, que garantiza que el token
        -- ya está asignado. Este hook solo se usa para limpiar estado residual.
    end)
    hooksecurefunc(NamePlateDriverFrame, "OnNamePlateRemoved", function(_, unit)
        -- Filtrar tokens no válidos (ej. "preview")
        if not unit or not unit:match("^nameplate%d+$") then return end
        Minimizer.Core.ClearNeverSimplify(unit)
    end)
end

if CompactUnitFrame_UpdateHealthColor then
    hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(unitFrame)
        local unit = unitFrame and unitFrame.unit
        -- Solo actuar si es una nameplate enemiga, no party frames ni retratos
        if unit and unit:match("^nameplate%d+$") then
            Minimizer.Core.ApplyToUnit(unit)
        end
    end)
end
