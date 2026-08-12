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

-- Obtiene la nameplate de manera segura filtrando tokens tipo boss1, target, focus, etc.[cite: 1, 3]
function Minimizer.Utils.GetNamePlateForUnit(unit)
    if not unit or not UnitExists(unit) then return nil end

    if C_NamePlate and C_NamePlate.GetNamePlateForUnit and type(unit) == "string" and unit:match("^nameplate%d+$") then
        return C_NamePlate.GetNamePlateForUnit(unit)
    end

    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
            local token = nameplate.namePlateUnitToken or (nameplate.UnitFrame and nameplate.UnitFrame.unit) or nameplate.unit
            if token and UnitIsUnit(token, unit) then
                return nameplate
            end
        end
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

    local name = UnitCastingInfo(unit)
    if name then return true end

    name = UnitChannelInfo(unit)
    if name then return true end

    return false
end

-- Evaluador principal de simplificación basado en reglas seguras de contexto[cite: 3]
function Minimizer.Cache.ShouldSimplifyUnit(unit, nameplate)
    if not unit or not UnitExists(unit) then return false end

    local pct = MinimizerDB.simplifyPercent or 0
    if pct <= 0 then return false end

    -- Regla 1: Mobs marcados como no simplificables (ej. iniciaron cast) no se simplifican[cite: 3]
    if nameplate and nameplate.MinimizerNeverSimplify then
        return false
    end

    -- Regla 2: Mobs que están casteando actualmente no se simplifican[cite: 3]
    if Minimizer.Cache.IsUnitCasting(unit) then
        return false
    end

    return true
end

-------------------------------------------------------------------------------
-- 4. INDICADORES VISUALES (Target & Focus Markers - Sin Taint)
-------------------------------------------------------------------------------
Minimizer.Markers = {}

-- Crea componentes visuales independientes anclados a la barra de vida[cite: 3]
function Minimizer.Markers.Ensure(nameplate)
    if not nameplate then return nil end
    if nameplate.MinimizerMarkers then return nameplate.MinimizerMarkers end

    local uf = nameplate.UnitFrame or nameplate
    local anchorFrame = uf.healthBar or uf.HealthBar or uf

    local function CreateArrow(text, point, relPoint, xOff, yOff, r, g, b)
        local fs = uf:CreateFontString(nil, "OVERLAY")
        fs:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
        fs:SetPoint(point, anchorFrame, relPoint, xOff, yOff)
        fs:SetText(text)
        fs:SetTextColor(r or 1, g or 1, b or 1)
        fs:Hide()
        return fs
    end

    local markers = {
        targetLeft  = CreateArrow(">>", "RIGHT", "LEFT",  -2,  4, 1, 1, 1),
        targetRight = CreateArrow("<<", "LEFT",  "RIGHT",  2,  4, 1, 1, 1),
        focusLeft   = CreateArrow(">>", "RIGHT", "LEFT",  -2, -4, 1, 1, 0),
        focusRight  = CreateArrow("<<", "LEFT",  "RIGHT",  2, -4, 1, 1, 0),
    }

    nameplate.MinimizerMarkers = markers
    return markers
end

-- Actualiza visibilidad de marcadores evaluando relaciones de target/focus de forma segura[cite: 3]
function Minimizer.Markers.Update(unit, nameplate)
    local markers = Minimizer.Markers.Ensure(nameplate)
    if not markers then return end

    local npToken = nameplate.namePlateUnitToken or (nameplate.UnitFrame and nameplate.UnitFrame.unit) or unit

    local enableTarget = MinimizerDB.enableTargetMarkers ~= false
    local enableFocus  = MinimizerDB.enableFocusMarkers ~= false

    local isTarget = enableTarget and UnitIsUnit(npToken, "target")
    local isFocus  = enableFocus and UnitIsUnit(npToken, "focus")

    markers.targetLeft:SetShown(isTarget == true)
    markers.targetRight:SetShown(isTarget == true)
    markers.focusLeft:SetShown(isFocus == true)
    markers.focusRight:SetShown(isFocus == true)
end

-------------------------------------------------------------------------------
-- 5. MOTOR CORE (Aplica Cambios & Maneja Estado)
-------------------------------------------------------------------------------
Minimizer.Core = {}

function Minimizer.Core.ApplyToUnit(unit)
    if not unit or not UnitExists(unit) then return end

    local nameplate = Minimizer.Utils.GetNamePlateForUnit(unit)
    if not nameplate then return end

    local npToken = nameplate.namePlateUnitToken or (nameplate.UnitFrame and nameplate.UnitFrame.unit) or unit

    -- Solo simplificamos si la unidad es un objetivo atacable / enemigo
    if UnitCanAttack("player", npToken) or UnitCanAttack("player", unit) then
        local shouldSimplify = Minimizer.Cache.ShouldSimplifyUnit(npToken, nameplate)

        if Minimizer.Utils.IsSimplifiedAvailable() then
            C_NamePlateManager.SetNamePlateSimplified(npToken, shouldSimplify)
        end

        local scalePercent = shouldSimplify and (MinimizerDB.simplifyPercent or 0) or 0
        local targetScale = Minimizer.Utils.GetScaleForPercent(scalePercent)

        if not InCombatLockdown() or not Minimizer.Utils.SafeIsSecret(targetScale) then
            nameplate:SetScale(targetScale)
        end
    end

    -- Los marcadores de Target/Focus se aplican a cualquier unidad válida en pantalla
    Minimizer.Markers.Update(npToken, nameplate)
end

function Minimizer.Core.ApplyToAll()
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
        local token = nameplate.namePlateUnitToken or (nameplate.UnitFrame and nameplate.UnitFrame.unit) or nameplate.unit
        if token then
            Minimizer.Core.ApplyToUnit(token)
        end
    end
end

function Minimizer.Core.MarkNeverSimplify(unit)
    if not unit or not UnitExists(unit) then return end

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

-- Ticker de respaldo para mantener la sincronización visual[cite: 3]
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