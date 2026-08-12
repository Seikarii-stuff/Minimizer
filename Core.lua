-- ============================================================================
-- Minimizer - Nameplate Simplifier & Indicator Addon (WoW 12.1 Canon)
-- ============================================================================

local ADDON_NAME, Minimizer = ...
_G.Minimizer = Minimizer

-------------------------------------------------------------------------------
-- 1. CONFIGURACIÓN Y BASE DE DATOS
-------------------------------------------------------------------------------
MinimizerDB = MinimizerDB or {
    simplifyPercent = 0,
    enableTargetMarkers = true,
    enableFocusMarkers = true,
}

local CONSTANTS = {
    MAX_SCALE = 1.0,  -- Escala al 0% de simplificación
    MIN_SCALE = 0.5,  -- Escala al 100% de simplificación
    TICKER_INTERVAL = 1.0,
}

-------------------------------------------------------------------------------
-- 2. HELPER UTILITIES (Taint, Secret & API Safety)
-------------------------------------------------------------------------------
Minimizer.Utils = {}

-- Comprueba si la API nativa de simplificación está disponible en el cliente[cite: 3]
function Minimizer.Utils.IsSimplifiedAvailable()
    return C_NamePlateManager and type(C_NamePlateManager.SetNamePlateSimplified) == "function"
end

-- Verifica la presencia del sistema de restricciones por secretos en 12.1[cite: 3]
function Minimizer.Utils.IsSecretsActive()
    return C_Secrets and type(C_Secrets.HasSecretRestrictions) == "function" and C_Secrets.HasSecretRestrictions()
end

-- Comprueba de forma segura si un valor es secreto sin lanzar excepciones Lua[cite: 3]
function Minimizer.Utils.SafeIsSecret(value)
    if value == nil then return false end
    if type(issecretvalue) == "function" then
        return issecretvalue(value)
    end
    return false
end

-- Convierte el porcentaje (0-100) en el factor multiplicador de escala
function Minimizer.Utils.GetScaleForPercent(percent)
    percent = math.max(0, math.min(100, percent or 0))
    local factor = percent / 100
    return CONSTANTS.MAX_SCALE - (CONSTANTS.MAX_SCALE - CONSTANTS.MIN_SCALE) * factor
end

-- Obtiene la nameplate de manera segura mediante la API C nativa[cite: 3]
function Minimizer.Utils.GetNamePlateForUnit(unit)
    if not unit then return nil end
    if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        return C_NamePlate.GetNamePlateForUnit(unit)
    end
    return nil
end

-------------------------------------------------------------------------------
-- 3. CACHE & STATE DETECTOR (Cast, Combat & Threat Safety)
-------------------------------------------------------------------------------
Minimizer.Cache = {}

-- Determina si la unidad está casteando, canalizando o en spell potenciado[cite: 3]
function Minimizer.Cache.IsUnitCasting(unit)
    if not unit or not UnitExists(unit) then return false end

    local name, _, _, _, _, _, _, _, spellID = UnitCastingInfo(unit)
    if name then return true, spellID end

    name, _, _, _, _, _, _, spellID = UnitChannelInfo(unit)
    if name then return true, spellID end

    return false, nil
end

-- Evaluador principal de simplificación basado en reglas seguras de contexto[cite: 3]
function Minimizer.Cache.ShouldSimplifyUnit(unit, nameplate)
    if not unit or not UnitExists(unit) then return false end
    if not UnitCanAttack("player", unit) then return false end -- Solo enemigos

    -- Si el cliente restringe cambios en combate o los secretos impiden la reevaluación[cite: 3]
    local inCombat = UnitAffectingCombat("player")
    if not inCombat then return false end

    -- Regla 1: Mobs marcados como no simplificables (ej. iniciaron cast) no se simplifican[cite: 3]
    if nameplate and nameplate.MinimizerNeverSimplify then
        return false
    end

    -- Regla 2: Mobs que están casteando actualmente no se simplifican[cite: 3]
    local isCasting = Minimizer.Cache.IsUnitCasting(unit)
    if isCasting then
        return false
    end

    return (MinimizerDB.simplifyPercent or 0) > 0
end

-------------------------------------------------------------------------------
-- 4. INDICADORES VISUALES (Target & Focus Markers - Sin Taint)
-------------------------------------------------------------------------------
Minimizer.Markers = {}

-- Crea componentes visuales independientes sin mutar o pintar barras protegidas de Blizzard[cite: 3]
function Minimizer.Markers.Ensure(nameplate)
    if not nameplate then return nil end
    if nameplate.MinimizerMarkers then return nameplate.MinimizerMarkers end

    local parent = nameplate.UnitFrame or nameplate
    local function CreateArrow(text, point, relPoint, xOff, yOff, r, g, b)
        local fs = parent:CreateFontString(nil, "OVERLAY")
        fs:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
        fs:SetPoint(point, parent, relPoint, xOff, yOff)
        fs:SetText(text)
        fs:SetTextColor(r or 1, g or 1, b or 1)
        fs:Hide()
        return fs
    end

    local markers = {
        targetLeft  = CreateArrow(">>", "RIGHT", "LEFT",  -2,  6, 1, 1, 1),
        targetRight = CreateArrow("<<", "LEFT",  "RIGHT",  2,  6, 1, 1, 1),
        focusLeft   = CreateArrow(">>", "RIGHT", "LEFT",  -2, -6, 1, 1, 0),
        focusRight  = CreateArrow("<<", "LEFT",  "RIGHT",  2, -6, 1, 1, 0),
    }

    nameplate.MinimizerMarkers = markers
    return markers
end

-- Actualiza visibilidad de marcadores evaluando relaciones de target/focus de forma segura[cite: 3]
function Minimizer.Markers.Update(unit, nameplate)
    local markers = Minimizer.Markers.Ensure(nameplate)
    if not markers then return end

    -- Forzamos retorno booleano explícito (true/false) para evitar pasar 'nil' a APIs de Blizzard
    local enableTarget = MinimizerDB.enableTargetMarkers ~= false
    local enableFocus  = MinimizerDB.enableFocusMarkers ~= false

    local isTarget = enableTarget and (UnitIsUnit(unit, "target") == true)
    local isFocus  = enableFocus and (UnitIsUnit(unit, "focus") == true)

    -- Aplicación segura evaluando posibilidad de datos secretos[cite: 3]
    if markers.targetLeft.SetAlphaFromBoolean then
        markers.targetLeft:SetAlphaFromBoolean(isTarget)
        markers.targetRight:SetAlphaFromBoolean(isTarget)
        markers.focusLeft:SetAlphaFromBoolean(isFocus)
        markers.focusRight:SetAlphaFromBoolean(isFocus)
        markers.targetLeft:Show()
        markers.targetRight:Show()
        markers.focusLeft:Show()
        markers.focusRight:Show()
    else
        markers.targetLeft:SetShown(isTarget)
        markers.targetRight:SetShown(isTarget)
        markers.focusLeft:SetShown(isFocus)
        markers.focusRight:SetShown(isFocus)
    end
end

-------------------------------------------------------------------------------
-- 5. MOTOR CORE (Aplica Cambios & Maneja Estado)
-------------------------------------------------------------------------------
Minimizer.Core = {}

function Minimizer.Core.ApplyToUnit(unit)
    if not unit or not UnitExists(unit) then return end
    if not UnitCanAttack("player", unit) then return end

    local nameplate = Minimizer.Utils.GetNamePlateForUnit(unit)
    local shouldSimplify = Minimizer.Cache.ShouldSimplifyUnit(unit, nameplate)

    -- API nativa C de Blizzard para simplificación segura[cite: 3]
    if Minimizer.Utils.IsSimplifiedAvailable() then
        C_NamePlateManager.SetNamePlateSimplified(unit, shouldSimplify)
    end

    if nameplate then
        local scalePercent = shouldSimplify and MinimizerDB.simplifyPercent or 0
        local targetScale = Minimizer.Utils.GetScaleForPercent(scalePercent)

        if not InCombatLockdown() or not Minimizer.Utils.SafeIsSecret(targetScale) then
            nameplate:SetScale(targetScale)
        end

        Minimizer.Markers.Update(unit, nameplate)
    end
end

function Minimizer.Core.ApplyToAll()
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
        local token = nameplate.namePlateUnitToken or nameplate.unit
        if token then
            Minimizer.Core.ApplyToUnit(token)
        end
    end
end

function Minimizer.Core.MarkNeverSimplify(unit)
    if not unit or not UnitExists(unit) then return end
    if not UnitCanAttack("player", unit) then return end

    local nameplate = Minimizer.Utils.GetNamePlateForUnit(unit)
    if nameplate and not nameplate.MinimizerNeverSimplify then
        nameplate.MinimizerNeverSimplify = true
        Minimizer.Core.ApplyToUnit(unit)
    end
end

function Minimizer.Core.ClearNeverSimplify(unit)
    local nameplate = Minimizer.Utils.GetNamePlateForUnit(unit)
    if nameplate then
        nameplate.MinimizerNeverSimplify = nil
    end
end

-------------------------------------------------------------------------------
-- 6. EVENTOS & SECURE HOOKS
-------------------------------------------------------------------------------
local EventFrame = CreateFrame("Frame", "MinimizerEventFrame")

local function OnEvent(self, event, unit, ...)
    if event == "NAME_PLATE_UNIT_ADDED" then
        Minimizer.Core.ApplyToUnit(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        Minimizer.Core.ClearNeverSimplify(unit)
    elseif event == "PLAYER_ENTERING_WORLD"
        or event == "PLAYER_TARGET_CHANGED"
        or event == "PLAYER_FOCUS_CHANGED"
        or event == "PLAYER_REGEN_DISABLED"
        or event == "PLAYER_REGEN_ENABLED" then
        Minimizer.Core.ApplyToAll()
    elseif event == "UNIT_SPELLCAST_START"
        or event == "UNIT_SPELLCAST_CHANNEL_START"
        or event == "UNIT_SPELLCAST_EMPOWER_START" then
        Minimizer.Core.MarkNeverSimplify(unit)
    elseif event == "ADDON_LOADED" and unit == ADDON_NAME then
        MinimizerDB = MinimizerDB or { simplifyPercent = 0, enableTargetMarkers = true, enableFocusMarkers = true }
    end
end

EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
EventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
EventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
EventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
EventFrame:RegisterEvent("UNIT_SPELLCAST_START")
EventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
EventFrame:RegisterEvent("UNIT_SPELLCAST_EMPOWER_START")
EventFrame:SetScript("OnEvent", OnEvent)

-- Integración segura canónica con NamePlateDriverFrame mediante hooksecurefunc[cite: 3]
if NamePlateDriverFrame then
    hooksecurefunc(NamePlateDriverFrame, "OnNamePlateAdded", function(_, unit)
        if unit then Minimizer.Core.ApplyToUnit(unit) end
    end)
    hooksecurefunc(NamePlateDriverFrame, "OnNamePlateRemoved", function(_, unit)
        if unit then Minimizer.Core.ClearNeverSimplify(unit) end
    end)
end

-- Ticker de respaldo para sincronizar estado de visualización[cite: 3]
C_Timer.NewTicker(CONSTANTS.TICKER_INTERVAL, Minimizer.Core.ApplyToAll)

-------------------------------------------------------------------------------
-- 7. COMANDOS BARRA SLASH (/simp)
-------------------------------------------------------------------------------
SLASH_MINIMIZER1 = "/simp"
SlashCmdList["MINIMIZER"] = function(msg)
    local value = tonumber(msg)
    if not value then
        print("|cff33ff99Minimizer|r: uso /simp <0-100>. Valor actual: " .. (MinimizerDB.simplifyPercent or 0) .. "%")
        return
    end

    value = math.floor(math.max(0, math.min(100, value)))
    MinimizerDB.simplifyPercent = value

    print("|cff33ff99Minimizer|r: simplificación ajustada a " .. value .. "%")
    Minimizer.Core.ApplyToAll()
end