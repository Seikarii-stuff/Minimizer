-- ============================================================================
-- Minimizer - Core.lua (WoW 12.1 Midnight Canonical & Taint-Free)
-- ============================================================================

local ADDON_NAME, Minimizer = ...
_G.Minimizer = Minimizer

-------------------------------------------------------------------------------
-- 1. DATABASE & CONFIGURATION
-------------------------------------------------------------------------------
if Minimizer.Config and Minimizer.Config.Initialize then
    Minimizer.Config.Initialize()
end

-------------------------------------------------------------------------------
-- 2. UTILITY HELPERS (Taint, Token & API Validation)
-------------------------------------------------------------------------------
Minimizer.Utils = {}

function Minimizer.Utils.IsSecretValue(value)
    return issecretvalue and issecretvalue(value)
end

-- Identifica si la API nativa C_NamePlateManager está disponible[cite: 3]
function Minimizer.Utils.IsSimplifiedAvailable()
    return C_NamePlateManager and type(C_NamePlateManager.SetNamePlateSimplified) == "function"
end

-- Resuelve y sanitiza la nameplate correspondiente para cualquier unit token[cite: 1, 3]
function Minimizer.Utils.GetNamePlateForUnit(unit)
    if not unit or type(unit) ~= "string" or not UnitExists(unit) then 
        return nil 
    end

    -- C_NamePlate.GetNamePlateForUnit solo permite tokens de tipo "nameplateN"[cite: 1]
    if unit:match("^nameplate%d+$") then
        return C_NamePlate.GetNamePlateForUnit(unit)
    end

    -- Para tokens como "target", "focus" o "bossN", se busca la nameplate activa[cite: 1]
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
            local token = nameplate.namePlateUnitToken or (nameplate.UnitFrame and nameplate.UnitFrame.unit)
            if token and UnitIsUnit(token, unit) then
                return nameplate
            end
        end
    end

    return nil
end

-- Normaliza la unidad obteniendo siempre un token valido de nameplate ("nameplateN")
function Minimizer.Utils.GetValidNamePlateToken(unit, nameplate)
    if type(unit) == "string" and unit:match("^nameplate%d+$") then
        return unit
    end
    if nameplate then
        local token = nameplate.namePlateUnitToken or (nameplate.UnitFrame and nameplate.UnitFrame.unit)
        if type(token) == "string" and token:match("^nameplate%d+$") then
            return token
        end
    end
    return nil
end

-------------------------------------------------------------------------------
-- 3. CACHE & DECISION ENGINE (Sin comparaciones inseguras)
-------------------------------------------------------------------------------
Minimizer.Cache = Minimizer.Cache or {}
Minimizer.Modules = Minimizer.Modules or {}
Minimizer.ActiveNameplates = Minimizer.ActiveNameplates or {}

-- Estado de amenaza. Mantiene la decisión separada de la presentación para
-- que futuros módulos (incluido CastingBar) puedan reutilizarla.
Minimizer.Threat = Minimizer.Threat or {}
Minimizer.Absorb = Minimizer.Absorb or {}
Minimizer.Threat.tankTokens = Minimizer.Threat.tankTokens or {}

function Minimizer.Threat.RefreshTankTokens()
    local tokens = Minimizer.Threat.tankTokens
    wipe(tokens)

    local prefix, count
    if IsInRaid and IsInRaid() then
        prefix, count = "raid", 40
    elseif IsInGroup and IsInGroup() then
        prefix, count = "party", 4
    else
        return
    end

    for index = 1, count do
        local token = prefix .. index
        if UnitExists(token) and UnitGroupRolesAssigned(token) == "TANK" then
            tokens[#tokens + 1] = token
        end
    end
end

function Minimizer.Threat.IsThreatContext()
    -- La amenaza se evalúa tanto en mazmorras como en mundo abierto.
    return true
end

function Minimizer.Absorb.HasAbsorb(unit, nameplate)
    if not unit or not UnitExists(unit) then return false end
    nameplate = nameplate or (Minimizer.Utils and Minimizer.Utils.GetNamePlateForUnit and Minimizer.Utils.GetNamePlateForUnit(unit))
    local absorbs = UnitGetTotalAbsorbs and UnitGetTotalAbsorbs(unit)

    -- En WoW 12.1 Midnight, valores numéricos y auras pueden ser secretos (IsSecretValue).
    -- NUNCA evaluar 'not absorbs' ni 'absorbs > 0' sin comprobar IsSecretValue primero para evitar taint.
    if Minimizer.Utils.IsSecretValue(absorbs) or absorbs == nil then
        local unitFrame = nameplate and (nameplate.UnitFrame or nameplate)
        local healthBar = unitFrame and (unitFrame.healthBar or unitFrame.HealthBar)
        local indicator = healthBar and (healthBar.totalAbsorbOverlay or healthBar.totalAbsorb)
        return indicator and indicator.IsShown and indicator:IsShown() == true or false
    end

    if type(absorbs) == "number" and absorbs > 0 then
        return true
    end

    local unitFrame = nameplate and (nameplate.UnitFrame or nameplate)
    local healthBar = unitFrame and (unitFrame.healthBar or unitFrame.HealthBar)
    local indicator = healthBar and (healthBar.totalAbsorbOverlay or healthBar.totalAbsorb)
    return indicator and indicator.IsShown and indicator:IsShown() == true or false
end

function Minimizer.Threat.IsPlayerTank()
    if UnitGroupRolesAssigned and UnitGroupRolesAssigned("player") == "TANK" then
        return true
    end
    local specialization = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization
        and C_SpecializationInfo.GetSpecialization()
    if specialization and C_SpecializationInfo.GetSpecializationInfo then
        local _, _, _, _, role = C_SpecializationInfo.GetSpecializationInfo(specialization)
        return role == "TANK"
    end
    if GetSpecialization and GetSpecializationRole then
        specialization = GetSpecialization()
        return specialization ~= nil and GetSpecializationRole(specialization) == "TANK"
    end
    return false
end

function Minimizer.Threat.GetSituation(unit, source)
    if not unit or not UnitExists(unit) then return nil end
    local state = Minimizer.Cache.GetUnitState and Minimizer.Cache.GetUnitState(unit)
    local key = "threat:" .. (source or "player")
    if state and state[key] ~= nil then return state[key] end
    local situation = UnitThreatSituation(source or "player", unit)
    -- La situación puede ser secreta en Midnight. Nunca la conviertas en una
    -- decisión Lua ni la trates como aggro por coerción: sólo el número 3 es
    -- aggro sólido según la API documentada.
    if issecretvalue and issecretvalue(situation) then return nil end
    if type(situation) ~= "number" then return nil end
    if state then state[key] = situation end
    return situation
end

function Minimizer.Threat.PlayerHasAggro(unit)
    if not Minimizer.Threat.IsThreatContext() then
        return false
    end
    if Minimizer.Threat.IsPlayerTank() then
        if not UnitAffectingCombat(unit) then return false end
        local situation = Minimizer.Threat.GetSituation(unit, "player")
        return situation == nil or situation < 3
    else
        return Minimizer.Threat.GetSituation(unit, "player") == 3
    end
end

function Minimizer.Threat.GetTankSituation(unit)
    local best = Minimizer.Threat.GetSituation(unit, "player")
    for _, token in ipairs(Minimizer.Threat.tankTokens) do
        local situation = Minimizer.Threat.GetSituation(unit, token)
        if situation == 3 then
            return situation
        end
        if best == nil or (situation and situation > best) then
            best = situation
        end
    end
    return best
end

function Minimizer.Threat.ShouldUnsimplify(unit)
    if not Minimizer.Threat.IsThreatContext() then
        return false
    end
    if Minimizer.Threat.IsPlayerTank() then
        if not UnitAffectingCombat(unit) then return false end
        -- En grupo, cualquier tanque puede estar gestionando la amenaza.
        local situation = Minimizer.Threat.GetTankSituation(unit)
        return situation == nil or situation == 0
    end

    -- Como no-tanque, conservarla si el jugador tiene aggro total.
    return Minimizer.Threat.GetSituation(unit, "player") == 3
end

-- Estado de casteo compartido por Core, HealthBarColor y el futuro
-- CastingBar. La forma de leerlo sigue los índices documentados en project.md.
Minimizer.Cast = Minimizer.Cast or {}

local function ReadCastState(unit)
    if not unit or not UnitExists(unit) then return false, false end

    local castName, _, _, _, _, _, _, castUninterruptible = UnitCastingInfo(unit)
    local channelName, _, _, _, _, _, channelUninterruptible = UnitChannelInfo(unit)
    local isCasting = castName ~= nil or channelName ~= nil
    if not isCasting then return false, false end

    -- En casts normales el indicador está en [8], en canales en [7].
    -- No usar `and/or` aquí: el valor puede ser un booleano secreto y una
    -- prueba Lua sobre él provoca taint en Midnight.
    local uninterruptible
    if castName ~= nil then
        uninterruptible = castUninterruptible
    elseif channelName ~= nil then
        uninterruptible = channelUninterruptible
    end

    -- Los secretos no se pueden inspeccionar desde Lua. En ese caso dejamos
    -- la clasificación indeterminada y devolvemos el valor sólo para APIs
    -- C-side como SetAlphaFromBoolean().
    if Minimizer.Utils.IsSecretValue(uninterruptible) then
        return true, nil, uninterruptible
    end
    local safeValue = uninterruptible == true
    return true, safeValue, safeValue
end

local cachedCastUnit
local cachedIsCasting, cachedUninterruptible, cachedRawUninterruptible
local cachedCastValid = false

function Minimizer.Cast.InvalidateState(unit)
    if not unit or cachedCastUnit == unit then
        cachedCastUnit = nil
        cachedIsCasting, cachedUninterruptible, cachedRawUninterruptible = nil, nil, nil
        cachedCastValid = false
    end
end

function Minimizer.Cast.GetState(unit)
    if cachedCastValid and cachedCastUnit == unit then
        return cachedIsCasting, cachedUninterruptible, cachedRawUninterruptible
    end
    local isCasting, uninterruptible, rawUninterruptible = ReadCastState(unit)
    cachedCastUnit = unit
    cachedIsCasting = isCasting
    cachedUninterruptible = uninterruptible
    cachedRawUninterruptible = rawUninterruptible
    cachedCastValid = true
    return isCasting, uninterruptible, rawUninterruptible
end

function Minimizer.Cast.IsUnitCasting(unit)
    local isCasting = Minimizer.Cast.GetState(unit)
    return isCasting == true
end

function Minimizer.Cast.IsUnitCastUninterruptible(unit)
    local isCasting, isUninterruptible = Minimizer.Cast.GetState(unit)
    return isCasting == true and isUninterruptible == true
end

function Minimizer.Cache.IsUnitCasting(unit)
    return Minimizer.Cast.IsUnitCasting(unit)
end

function Minimizer.Cache.ShouldSimplifyUnit(unit, nameplate)
    if not unit or not UnitExists(unit) then return false end

    -- Solo simplificar enemigos/atacables
    if not UnitCanAttack("player", unit) then return false end

    local pct = MinimizerDB.simplifyPercent or 0
    if pct <= 0 then return false end

    if Minimizer.Threat.ShouldUnsimplify(unit) then
        return false
    end

    if Minimizer.Absorb.HasAbsorb(unit, nameplate) then
        return false
    end

    -- No simplificar si fue marcado por cast
    if nameplate and nameplate.MinimizerNeverSimplify then
        return false
    end

    -- No simplificar si está casteando activamente
    if Minimizer.Cache.IsUnitCasting(unit) then
        return false
    end

    return true
end

-------------------------------------------------------------------------------
-- 4. VISUAL MARKERS (Target & Focus Highlights - 100% Overlay, 0% Taint)
-------------------------------------------------------------------------------
Minimizer.Markers = {}

function Minimizer.Markers.Ensure(nameplate)
    if not nameplate then return nil end
    if nameplate.MinimizerMarkers then return nameplate.MinimizerMarkers end

    local uf = nameplate.UnitFrame or nameplate
    local anchor = uf.healthBar or uf.HealthBar or uf

    local function CreateArrow(text, point, relPoint, xOff, yOff, r, g, b)
        local fs = uf:CreateFontString(nil, "OVERLAY")
        fs:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
        fs:SetPoint(point, anchor, relPoint, xOff, yOff)
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

    local token = Minimizer.Utils.GetValidNamePlateToken(unit, nameplate) or unit
    if not token or not UnitExists(token) then 
        markers.targetLeft:Hide()
        markers.targetRight:Hide()
        markers.focusLeft:Hide()
        markers.focusRight:Hide()
        return 
    end

    local isTarget = (MinimizerDB.enableTargetMarkers ~= false) and UnitIsUnit(token, "target")
    local isFocus  = (MinimizerDB.enableFocusMarkers ~= false) and UnitIsUnit(token, "focus")

    -- Futuro: añadir aquí el cooldown mayor de daño o defensivo sobre el target.
    markers.targetLeft:SetShown(isTarget == true)
    markers.targetRight:SetShown(isTarget == true)
    local showFocusArrows = MinimizerDB.focusIndicator ~= "face"
    markers.focusLeft:SetShown(isFocus == true and showFocusArrows)
    markers.focusRight:SetShown(isFocus == true and showFocusArrows)
end

function Minimizer.Markers.Clear(nameplate)
    local markers = nameplate and nameplate.MinimizerMarkers
    if not markers then return end
    markers.targetLeft:Hide()
    markers.targetRight:Hide()
    markers.focusLeft:Hide()
    markers.focusRight:Hide()
end

-------------------------------------------------------------------------------
-- 5. CORE ENGINE (Aplica Simplificación Canónica C-Side)
-------------------------------------------------------------------------------
Minimizer.Core = {}
local applyAllPending = false
Minimizer.Bench = Minimizer.Bench or { enabled = false, applyAll = 0, applyAllTime = 0, modules = {} }

function Minimizer.Bench.Reset()
    Minimizer.Bench.applyAll = 0
    Minimizer.Bench.applyAllTime = 0
    wipe(Minimizer.Bench.modules)
end

-- Los módulos visuales se registran aquí en vez de acoplarse al manejador de
-- eventos. Cada módulo puede implementar UpdateNamePlate y OnNamePlateRemoved.
function Minimizer.Core.RegisterModule(name, module)
    if type(name) ~= "string" or type(module) ~= "table" then return end

    Minimizer.Modules[name] = module
    module.MinimizerModuleName = name
    Minimizer.Core.ApplyToAll()
end

function Minimizer.Core.UpdateModules(unit, nameplate)
    for _, module in pairs(Minimizer.Modules) do
        if type(module.UpdateNamePlate) == "function" then
            local started = Minimizer.Bench.enabled and GetTimePreciseSec()
            module:UpdateNamePlate(unit, nameplate)
            if started then
                local stats = Minimizer.Bench.modules[module] or { name = module.MinimizerModuleName or "unknown", calls = 0, time = 0 }
                stats.calls = stats.calls + 1
                stats.time = stats.time + (GetTimePreciseSec() - started)
                Minimizer.Bench.modules[module] = stats
            end
        end
    end
end

function Minimizer.Core.ApplyToUnit(unit)
    if not unit then return end

    local nameplate = Minimizer.Utils.GetNamePlateForUnit(unit)
    if not nameplate then return end

    local npToken = Minimizer.Utils.GetValidNamePlateToken(unit, nameplate)
    if not npToken then return end
    Minimizer.ActiveNameplates[npToken] = nameplate

    -- 1. Evaluación de simplificación
    local shouldSimplify = Minimizer.Cache.ShouldSimplifyUnit(npToken, nameplate)

    -- 2. Aplicación vía API C nativa de Blizzard (evita modificar SetScale en SecureFrames)[cite: 3]
    if Minimizer.Utils.IsSimplifiedAvailable() then
        if nameplate.MinimizerState ~= shouldSimplify then
            C_NamePlateManager.SetNamePlateSimplified(npToken, shouldSimplify)
            nameplate.MinimizerState = shouldSimplify
        end
    end

    -- 3. Actualización de marcadores visuales overlay
    Minimizer.Markers.Update(npToken, nameplate)
    Minimizer.Core.UpdateModules(npToken, nameplate)
end

function Minimizer.Core.ApplyToAll()
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    local started = Minimizer.Bench.enabled and GetTimePreciseSec()
    for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
        local token = Minimizer.Utils.GetValidNamePlateToken(nil, nameplate)
        if token then
            Minimizer.Core.ApplyToUnit(token)
        end
    end
    if started then
        Minimizer.Bench.applyAll = Minimizer.Bench.applyAll + 1
        Minimizer.Bench.applyAllTime = Minimizer.Bench.applyAllTime + (GetTimePreciseSec() - started)
    end
end

-- Native events arrive in bursts. Coalesce full nameplate passes per frame.
function Minimizer.Core.RequestApplyToAll()
    if applyAllPending then return end
    applyAllPending = true
    C_Timer.After(0, function()
        applyAllPending = false
        Minimizer.Core.ApplyToAll()
    end)
end

function Minimizer.Core.MarkNeverSimplify(unit)
    if not unit then return end
    local nameplate = Minimizer.Utils.GetNamePlateForUnit(unit)
    if nameplate and not nameplate.MinimizerNeverSimplify then
        nameplate.MinimizerNeverSimplify = true
        Minimizer.Core.ApplyToUnit(unit)
    end
end

function Minimizer.Core.ClearNeverSimplify(unit)
    if not unit then return end
    if Minimizer.Cache.InvalidateUnit then
        Minimizer.Cache.InvalidateUnit(unit)
    end
    Minimizer.Cast.InvalidateState(unit)
    local nameplate = Minimizer.ActiveNameplates[unit] or Minimizer.Utils.GetNamePlateForUnit(unit)
    if nameplate then
        for _, module in pairs(Minimizer.Modules) do
            if type(module.OnNamePlateRemoved) == "function" then
                module:OnNamePlateRemoved(unit, nameplate)
            end
        end
        Minimizer.Markers.Clear(nameplate)
        nameplate.MinimizerNeverSimplify = nil
        nameplate.MinimizerState = nil
        nameplate.MinimizerCastBar = nil
    end
    Minimizer.ActiveNameplates[unit] = nil
end

-------------------------------------------------------------------------------
-- 6. EVENT MANAGEMENT & SECURE HOOKS
-------------------------------------------------------------------------------
local EventFrame = CreateFrame("Frame", "MinimizerEventFrame")
local lastInterruptReady

local function OnEvent(self, event, unit, ...)
    if event == "PLAYER_ENTERING_WORLD"
        or event == "ZONE_CHANGED_NEW_AREA"
        or event == "PLAYER_DIFFICULTY_CHANGED"
        or event == "PLAYER_TARGET_CHANGED"
        or event == "PLAYER_FOCUS_CHANGED"
        or event == "PLAYER_REGEN_DISABLED"
        or event == "PLAYER_REGEN_ENABLED" then
        if event == "PLAYER_ENTERING_WORLD" then
            Minimizer.Threat.RefreshTankTokens()
        end
        Minimizer.Core.RequestApplyToAll()
    elseif event == "UNIT_DISPLAYPOWER"
        or event == "UNIT_CLASSIFICATION_CHANGED"
        or event == "UNIT_LEVEL" then
        -- La clase de enemigo puede cambiar durante una transformacion.
        Minimizer.Core.ApplyToUnit(unit)
    elseif event == "UNIT_THREAT_SITUATION_UPDATE"
        or event == "UNIT_THREAT_LIST_UPDATE"
        or event == "UNIT_ABSORB_AMOUNT_CHANGED"
        or event == "UNIT_AURA"
        or event == "PLAYER_ROLES_ASSIGNED"
        or event == "GROUP_ROSTER_UPDATE"
        or event == "PLAYER_TALENT_UPDATE"
        or event == "PLAYER_SPECIALIZATION_CHANGED" then
        if event == "UNIT_THREAT_SITUATION_UPDATE" or event == "UNIT_THREAT_LIST_UPDATE" then
            if unit and unit:match("^nameplate%d+$") then
                if Minimizer.Cache.InvalidateUnit then
                    Minimizer.Cache.InvalidateUnit(unit, "threat:player")
                    for _, tankToken in ipairs(Minimizer.Threat.tankTokens) do
                        Minimizer.Cache.InvalidateUnit(unit, "threat:" .. tankToken)
                    end
                end
                Minimizer.Core.ApplyToUnit(unit)
            else
                if Minimizer.Cache.InvalidateAll then
                    Minimizer.Cache.InvalidateAll("threat:player")
                    for _, tankToken in ipairs(Minimizer.Threat.tankTokens) do
                        Minimizer.Cache.InvalidateAll("threat:" .. tankToken)
                    end
                end
                Minimizer.Core.RequestApplyToAll()
            end
        elseif (event == "UNIT_ABSORB_AMOUNT_CHANGED" or event == "UNIT_AURA") and unit then
            Minimizer.Core.ApplyToUnit(unit)
        elseif Minimizer.Cache.InvalidateAll then
            Minimizer.Cache.InvalidateAll("threat:player")
            Minimizer.Core.RequestApplyToAll()
        end
        if event == "PLAYER_ROLES_ASSIGNED" or event == "GROUP_ROSTER_UPDATE"
            or event == "PLAYER_TALENT_UPDATE" or event == "PLAYER_SPECIALIZATION_CHANGED" then
            Minimizer.Threat.RefreshTankTokens()
        end
        Minimizer.Core.RequestApplyToAll()
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
        Minimizer.Cast.InvalidateState(unit)
        if event == "UNIT_SPELLCAST_START"
            or event == "UNIT_SPELLCAST_CHANNEL_START"
            or event == "UNIT_SPELLCAST_EMPOWER_START" then
            Minimizer.Core.MarkNeverSimplify(unit)
        else
            Minimizer.Core.ApplyToUnit(unit)
        end
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        local interrupt = Minimizer.Interrupt
        local ready = interrupt and interrupt.IsReady and interrupt.IsReady()
        -- Secret booleans cannot be compared in Lua. In that case the native
        -- status-bar hook remains authoritative; ordinary booleans refresh
        -- only when the interrupt actually changes state.
        if ready ~= nil and not Minimizer.Utils.IsSecretValue(ready)
            and ready ~= lastInterruptReady then
            lastInterruptReady = ready
            Minimizer.Core.RequestApplyToAll()
        end
    elseif event == "ADDON_LOADED" and unit == ADDON_NAME then
        if Minimizer.Config and Minimizer.Config.Initialize then
            Minimizer.Config.Initialize()
        end
    end
end

EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
EventFrame:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
EventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
EventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
EventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
EventFrame:RegisterEvent("UNIT_DISPLAYPOWER")
EventFrame:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
EventFrame:RegisterEvent("UNIT_LEVEL")
EventFrame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
EventFrame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
EventFrame:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
EventFrame:RegisterEvent("UNIT_AURA")
EventFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
EventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
EventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
EventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
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
EventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
EventFrame:SetScript("OnEvent", OnEvent)

-- Secure Hooks canónicos según especificación de Platynator[cite: 3]
if NamePlateDriverFrame then
    hooksecurefunc(NamePlateDriverFrame, "OnNamePlateAdded", function(_, unit)
        if unit then Minimizer.Core.ApplyToUnit(unit) end
    end)
    hooksecurefunc(NamePlateDriverFrame, "OnNamePlateRemoved", function(_, unit)
        if unit then Minimizer.Core.ClearNeverSimplify(unit) end
    end)
end

-------------------------------------------------------------------------------
-- 7. SLASH COMMANDS (/simp)
-------------------------------------------------------------------------------
SLASH_MINIMIZER1 = "/simp"
SlashCmdList["MINIMIZER"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "bench" or msg == "bench start" then
        Minimizer.Bench.enabled = true
        Minimizer.Bench.Reset()
        print("|cff33ff99Minimizer|r: benchmark iniciado. Usa /simp bench stop para ver el informe.")
        return
    end
    if msg == "bench reset" then
        Minimizer.Bench.Reset()
        print("|cff33ff99Minimizer|r: benchmark reiniciado.")
        return
    end
    if msg == "bench stop" then
        Minimizer.Bench.enabled = false
        if UpdateAddOnMemoryUsage then UpdateAddOnMemoryUsage() end
        local memory = GetAddOnMemoryUsage and GetAddOnMemoryUsage(ADDON_NAME) or 0
        print(string.format("|cff33ff99Minimizer|r: ApplyToAll %d veces, %.3f ms total, memoria %.1f KB.",
            Minimizer.Bench.applyAll, Minimizer.Bench.applyAllTime * 1000, memory))
        for _, stats in pairs(Minimizer.Bench.modules) do
            print(string.format("|cff33ff99Minimizer|r: %s: %d llamadas, %.3f ms.",
                stats.name, stats.calls, stats.time * 1000))
        end
        return
    end
    if msg == "arrows" or msg == "face" then
        if Minimizer.Focus then
            Minimizer.Focus:SetMode(msg)
            print("|cff33ff99Minimizer|r: indicador de focus = " .. msg)
        end
        return
    end
    local value = tonumber(msg)
    if not value then
        print("|cff33ff99Minimizer|r: uso /simp <0-100>, /simp arrows, /simp face o /simp bench")
        return
    end

    value = math.floor(math.max(0, math.min(100, value)))
    MinimizerDB.simplifyPercent = value

    print("|cff33ff99Minimizer|r: simplificación ajustada a " .. value .. "%")
    Minimizer.Core.ApplyToAll()
end

-- Blizzard puede restaurar su color rojo al actualizar la healthbar. El hook
-- es seguro y sólo vuelve a ejecutar nuestro módulo visual para esa unidad.
if CompactUnitFrame_UpdateHealthColor then
    hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(unitFrame)
        local unit = unitFrame and unitFrame.unit
        if unit then Minimizer.Core.ApplyToUnit(unit) end
    end)
end
