local _, Minimizer = ...
if not Minimizer or not Minimizer.Core then return end

local EventFrame = CreateFrame("Frame", "MinimizerEventFrame")
local lastInterruptReady

local function UpdateNameplates()
    if Minimizer.Core.RequestApplyToAll then
        Minimizer.Core.RequestApplyToAll()
    end
end

-- ============================================================
-- Handlers: cada uno recibe (self, event, ...) igual que OnEvent recibia.
-- ============================================================
local handlers = {}

local function HandleFullRefreshEvent(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if C_NamePlate and C_NamePlate.GetNamePlates then
            for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
                nameplate.MinimizerDesimplifiedPersistent = nil
                nameplate.MinimizerDesimplifiedPersistentGen = nil
            end
        end
    end
    if event == "PLAYER_ENTERING_WORLD" then
        if Minimizer.Threat and Minimizer.Threat.RefreshTankTokens then
            Minimizer.Threat.RefreshTankTokens()
        end
    end
    UpdateNameplates()
end
handlers["PLAYER_ENTERING_WORLD"] = HandleFullRefreshEvent
handlers["ZONE_CHANGED_NEW_AREA"] = HandleFullRefreshEvent
handlers["PLAYER_DIFFICULTY_CHANGED"] = HandleFullRefreshEvent
handlers["PLAYER_REGEN_DISABLED"] = HandleFullRefreshEvent
handlers["PLAYER_REGEN_ENABLED"] = HandleFullRefreshEvent

-- PLAYER_TARGET_CHANGED / PLAYER_FOCUS_CHANGED necesitan ADEMÁS del refresco
-- general de nameplates (HandleFullRefreshEvent) un refresco INMEDIATO de
-- Target.lua / Focus.lua. Si cambias de target/focus entre unidades que YA
-- tienen nameplate en pantalla, no se dispara NAME_PLATE_UNIT_ADDED (la
-- nameplate ya existía), así que sin esta llamada directa Target/Focus no se
-- repintan hasta que por casualidad llegue un SPELL_UPDATE_COOLDOWN -- de
-- ahí el retraso de varios segundos. El throttle nunca fue el problema: no
-- hay throttle que arregle una llamada que simplemente no se está haciendo.
handlers["PLAYER_TARGET_CHANGED"] = function(self, event)
    HandleFullRefreshEvent(self, event)
    if Minimizer.Target and Minimizer.Target.UpdateTargetCDs then
        Minimizer.Target:UpdateTargetCDs()
    end
end

handlers["PLAYER_FOCUS_CHANGED"] = function(self, event)
    HandleFullRefreshEvent(self, event)
    if Minimizer.Focus and Minimizer.Focus.UpdateFace then
        Minimizer.Focus:UpdateFace()
    end
end

handlers["NAME_PLATE_UNIT_ADDED"] = function(self, event, unit)
    if unit and unit:match("^nameplate%d+$") then
        -- Increment generation on arrival to prevent token-reuse races.
        if Minimizer.Core.IncrementPlateGeneration then
            Minimizer.Core.IncrementPlateGeneration(unit)
        end
        Minimizer.Core.ApplyToUnit(unit)
        UpdateNameplates()
    end
end

local function HandleUnitStateChange(self, event, unit)
    if unit and unit:match("^nameplate%d+$") then
        Minimizer.Core.ApplyToUnit(unit)
    end
end
handlers["UNIT_DISPLAYPOWER"] = HandleUnitStateChange
handlers["UNIT_CLASSIFICATION_CHANGED"] = HandleUnitStateChange
handlers["UNIT_LEVEL"] = HandleUnitStateChange

handlers["UNIT_THREAT_SITUATION_UPDATE"] = function(self, event, unit)
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
handlers["UNIT_THREAT_LIST_UPDATE"] = handlers["UNIT_THREAT_SITUATION_UPDATE"]

local function HandleRosterOrSpecChange(self, event)
    if Minimizer.Threat and Minimizer.Threat.RefreshTankTokens then
        Minimizer.Threat.RefreshTankTokens()
    end
    if Minimizer.Threat and Minimizer.Threat.RefreshPlayerTankCache then
        Minimizer.Threat.RefreshPlayerTankCache()
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
    -- Filtro explicito: solo nameplates enemigas.
    if not unit or not unit:match("^nameplate%d+$") then return end
    if Minimizer.Cast and Minimizer.Cast.InvalidateState then
        Minimizer.Cast.InvalidateState(unit)
    end
    Minimizer.Core.ApplyToUnit(unit)
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

-- SPELL_UPDATE_COOLDOWN: TRES comportamientos independientes, ver seccion
-- 6.1 del plan de refactor. NO fusionar el filtro de "ready cambio" con el
-- refresco de los widgets de Target/Focus.
handlers["SPELL_UPDATE_COOLDOWN"] = function(self, event)
    -- 1) Refrescar el cache de interrupcion (una vez por evento, no por nameplate).
    if Minimizer.Interrupt and Minimizer.Interrupt.RefreshReadyCache then
        Minimizer.Interrupt.RefreshReadyCache()
    end
    -- 2) Solo refrescar TODAS las nameplates si el estado de "listo" cambio.
    local ready = Minimizer.Interrupt and Minimizer.Interrupt.IsReady and Minimizer.Interrupt.IsReady()
    if ready ~= nil and not Minimizer.Utils.IsSecretValue(ready) and ready ~= lastInterruptReady then
        lastInterruptReady = ready
        UpdateNameplates()
    end
    -- 3) Target/Focus SIEMPRE se refrescan (con su propio debounce), sin
    --    importar si "ready" cambio o no -- sus cooldowns son independientes
    --    del interrupt.
    if Minimizer.Target and Minimizer.Target.DebouncedUpdate then
        Minimizer.Target.DebouncedUpdate()
    end
    if Minimizer.Focus and Minimizer.Focus.DebouncedUpdate then
        Minimizer.Focus.DebouncedUpdate()
    end
end

-- NAME_PLATE_UNIT_ADDED ya esta arriba (comparte logica con Core.ApplyToUnit),
-- pero Target/Focus tambien necesitan reaccionar a el para posicionar sus
-- widgets cuando aparece SU nameplate (target o focus respectivamente).
-- Se encadena aqui SIN reemplazar el handler de arriba.
local originalNamePlateAdded = handlers["NAME_PLATE_UNIT_ADDED"]
handlers["NAME_PLATE_UNIT_ADDED"] = function(self, event, unit)
    originalNamePlateAdded(self, event, unit)
    -- Regla 3 (seccion 6.1): Target SI filtra por unidad.
    if Minimizer.Target and Minimizer.Target.UpdateTargetCDs then
        if not unit or UnitIsUnit(unit, "target") then
            Minimizer.Target:UpdateTargetCDs()
        end
    end
    -- Regla 4 (seccion 6.1): Focus NO filtra, se llama siempre igual que antes.
    if Minimizer.Focus and Minimizer.Focus.UpdateFace then
        Minimizer.Focus:UpdateFace()
    end
end

-- NAME_PLATE_UNIT_REMOVED: NUEVO registro. Antes solo lo escuchaban los
-- drivers propios de Target/Focus -- ahora tiene que estar aqui o Target/
-- Focus dejan de ocultarse cuando su nameplate desaparece.
handlers["NAME_PLATE_UNIT_REMOVED"] = function(self, event, unit)
    if Minimizer.Target and Minimizer.Target.UpdateTargetCDs then
        if not unit or UnitIsUnit(unit, "target") then
            Minimizer.Target:UpdateTargetCDs()
        end
    end
    if Minimizer.Focus and Minimizer.Focus.UpdateFace then
        Minimizer.Focus:UpdateFace()
    end
end

local function OnEvent(self, event, ...)
    local handler = handlers[event]
    if handler then
        handler(self, event, ...)
    end
end

-- Eventos globales
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
EventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED") -- NUEVO
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

-- Secure Hooks canonicos (sin cambios respecto al original)
-- NOTA: OnNamePlateAdded NO se hookea. Toda la lógica de llegada (incremento
-- de generación + ApplyToUnit) vive en el handler de NAME_PLATE_UNIT_ADDED
-- (arriba en este archivo) para evitar doble incremento del mismo spawn en
-- el mismo frame. Solo OnNamePlateRemoved necesita hook propio porque no
-- existe un evento equivalente de "acaba de desaparecer" que dispare esta
-- limpieza específica de forma fiable.
if NamePlateDriverFrame then
    hooksecurefunc(NamePlateDriverFrame, "OnNamePlateRemoved", function(_, unit)
        if not unit or not unit:match("^nameplate%d+$") then return end
        Minimizer.Core.ClearNeverSimplify(unit)
    end)
end

if CompactUnitFrame_UpdateHealthColor then
    hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(unitFrame)
        local unit = unitFrame and unitFrame.unit
        if unit and unit:match("^nameplate%d+$") then
            Minimizer.Core.ApplyToUnit(unit)
        end
    end)
end
