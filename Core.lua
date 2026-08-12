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
    enableFocusColor = true,
}

local CONSTANTS = {
    MAX_SCALE = 1.0,
    MIN_SCALE = 0.5,
}

-------------------------------------------------------------------------------
-- 2. HELPER UTILITIES (Anti-Taint & API Safety)
-------------------------------------------------------------------------------
Minimizer.Utils = {}

function Minimizer.Utils.IsSimplifiedAvailable()
    return C_NamePlateManager and type(C_NamePlateManager.SetNamePlateSimplified) == "function"
end

function Minimizer.Utils.GetScaleForPercent(percent)
    percent = math.max(0, math.min(100, percent or 0))
    local factor = percent / 100
    return CONSTANTS.MAX_SCALE - (CONSTANTS.MAX_SCALE - CONSTANTS.MIN_SCALE) * factor
end

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
-- 3. CACHE & STATE DETECTOR
-------------------------------------------------------------------------------
Minimizer.Cache = {}

function Minimizer.Cache.IsUnitCasting(unit)
    if not unit or not UnitExists(unit) then return false end
    return UnitCastingInfo(unit) ~= nil or UnitChannelInfo(unit) ~= nil
end

function Minimizer.Cache.ShouldSimplifyUnit(unit, nameplate)
    if not unit or not UnitExists(unit) then return false end

    local pct = MinimizerDB.simplifyPercent or 0
    if pct <= 0 then return false end

    if nameplate and nameplate.MinimizerNeverSimplify then
        return false
    end

    if Minimizer.Cache.IsUnitCasting(unit) then
        return false
    end

    return true
end

-------------------------------------------------------------------------------
-- 4. INDICADORES VISUALES Y COLOR DE FOCUS
-------------------------------------------------------------------------------
Minimizer.Markers = {}

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

    -- Aplicar color amarillo a la barra de vida del Focus
    local uf = nameplate.UnitFrame
    if uf and uf.healthBar and MinimizerDB.enableFocusColor ~= false then
        if isFocus then
            if not markers.colorOverridden then
                uf.healthBar:SetStatusBarColor(1, 1, 0, 1) -- Color amarillo para Focus
                markers.colorOverridden = true
            end
        elseif markers.colorOverridden then
            -- Restaurar el color original de la barra de vida según Blizzard (Amenaza/Reacción)
            if CompactUnitFrame_UpdateHealthColor then
                CompactUnitFrame_UpdateHealthColor(uf)
            end
            markers.colorOverridden = false
        end
    end
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

    -- 1. Simplificación (solo enemigos/mobs atacables)
    if UnitCanAttack("player", npToken) or UnitCanAttack("player", unit) then
        local shouldSimplify = Minimizer.Cache.ShouldSimplifyUnit(npToken, nameplate)

        if Minimizer.Utils.IsSimplifiedAvailable() then
            -- Solo invocar si el estado de simplificación cambia respecto a la última reevaluación
            if nameplate.MinimizerCurrentSimplify ~= shouldSimplify then
                C_NamePlateManager.SetNamePlateSimplified(npToken, shouldSimplify)
                nameplate.MinimizerCurrentSimplify = shouldSimplify
            end
        end

        -- 2. Escala (solo se modifica fuera de combate para evitar Taint en marcos protegidos)
        if not InCombatLockdown() then
            local scalePercent = shouldSimplify and (MinimizerDB.simplifyPercent or 0) or 0
            local targetScale = Minimizer.Utils.GetScaleForPercent(scalePercent)
            if nameplate:GetScale() ~= targetScale then
                nameplate:SetScale(targetScale)
            end
        end
    end

    -- 3. Actualizar Marcadores y Color de Focus
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
        nameplate.MinimizerCurrentSimplify = nil
        if nameplate.MinimizerMarkers then
            nameplate.MinimizerMarkers.colorOverridden = nil
        end
    end
end

-------------------------------------------------------------------------------
-- 6. EVENTOS & SECURE HOOKS (Sincronización por Eventos)
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
        MinimizerDB = MinimizerDB or {
            simplifyPercent = 0,
            enableTargetMarkers = true,
            enableFocusMarkers = true,
            enableFocusColor = true,
        }
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

-- Integración segura con NamePlateDriverFrame mediante hooksecurefunc
if NamePlateDriverFrame then
    hooksecurefunc(NamePlateDriverFrame, "OnNamePlateAdded", function(_, unit)
        if unit then Minimizer.Core.ApplyToUnit(unit) end
    end)
    hooksecurefunc(NamePlateDriverFrame, "OnNamePlateRemoved", function(_, unit)
        if unit then Minimizer.Core.ClearNeverSimplify(unit) end
    end)
end

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