-- ============================================================================
-- Minimizer - Diagnostic.lua
-- Uso in-game: /run Minimizer.Diagnostic.Run()
--
-- Objetivo: generar en UN solo pase toda la información necesaria para
-- verificar/actualizar project.md contra el cliente real:
--   1) Localizar el campo real del castbar por duck-typing (no por
--      GetObjectType, que puede no ser "StatusBar" en este cliente).
--   2) Confirmar la tupla cruda de UnitCastingInfo/UnitChannelInfo
--      (posiciones de notInterruptible/spellID).
--   3) Confirmar existencia real (y, cuando es seguro, comportamiento) de
--      cada API que project.md da por canónica.
-- ============================================================================

local _, Minimizer = ...
if not Minimizer then return end

local Diagnostic = {}
Minimizer.Diagnostic = Diagnostic

local PREFIX = "|cffff3333[Minimizer DIAG]|r "
local reportLines

-- ----------------------------------------------------------------------
-- Helpers base
-- ----------------------------------------------------------------------

local function SafeString(value)
    if value == nil then return "nil" end
    if issecretvalue and issecretvalue(value) then return "<SECRET>" end
    local ok, result = pcall(tostring, value)
    return ok and result or "<unprintable>"
end

local function Emit(text)
    local line = PREFIX .. text
    reportLines[#reportLines + 1] = line
end

local function Section(title)
    Emit("")
    Emit("==== " .. title .. " ====")
end

-- Llama a fn(...) protegido y devuelve una descripción imprimible del
-- resultado (o del error), sin romper el resto del diagnóstico.
local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return "<no es function>"
    end
    local results = { pcall(fn, ...) }
    local ok = table.remove(results, 1)
    if not ok then
        return "ERROR: " .. SafeString(results[1])
    end
    if #results == 0 then
        return "ok (sin valores de retorno)"
    end
    local parts = {}
    for i = 1, #results do
        parts[#parts + 1] = SafeString(results[i])
    end
    return "ok -> " .. table.concat(parts, ", ")
end

-- Comprueba existencia de root.path.to.field sin indexar nil en el camino.
-- pathSpec: {"C_NamePlateManager", "SetNamePlateSimplified"}
local function ResolvePath(pathSpec)
    local current = _G
    for _, key in ipairs(pathSpec) do
        if type(current) ~= "table" then return nil, false end
        current = current[key]
    end
    return current, current ~= nil
end

local function CheckAPI(pathSpec, note)
    local value, exists = ResolvePath(pathSpec)
    local label = table.concat(pathSpec, ".")
    local t = exists and type(value) or "nil"
    Emit(string.format("%-55s exists=%-5s type=%-10s %s",
        label, tostring(exists), t, note or ""))
end

-- ----------------------------------------------------------------------
-- Descubrimiento de barras por duck-typing
-- ----------------------------------------------------------------------

local BAR_METHOD_PROBE = {
    "SetStatusBarColor", "GetStatusBarColor", "GetValue", "GetMinMaxValues",
    "SetTimerDuration", "IsShown", "GetWidth",
}

local function DescribeBarCandidate(pathLabel, frame)
    if type(frame) ~= "table" then return end

    local hasColor = type(frame.SetStatusBarColor) == "function"
    local hasValue = type(frame.GetValue) == "function"
    local hasTimer = type(frame.SetTimerDuration) == "function"

    if not (hasColor or hasValue) then return end -- no parece una barra

    local objectType = "?"
    if frame.GetObjectType then
        local ok, ot = pcall(frame.GetObjectType, frame)
        objectType = ok and ot or "?"
    end

    local tag = ""
    if hasTimer then
        tag = "  **CASTBAR? (tiene SetTimerDuration)**"
    elseif hasColor and hasValue then
        tag = "  (candidata: color+value, probablemente healthbar/castbar)"
    end

    Emit("  BAR CANDIDATE " .. pathLabel .. " objType=" .. objectType .. tag)
    for _, method in ipairs(BAR_METHOD_PROBE) do
        Emit("    ." .. method .. " = " .. SafeString(type(frame[method])))
    end

    -- GetName(): aunque el campo Lua no tenga un nombre útil (child1, child2...),
    -- el frame XML subyacente casi seguro sí lo tiene (p.ej. "...CastingBar",
    -- "...PowerBar"). Esto identifica el widget sin tener que comparar colores
    -- entre dos casteos distintos.
    if frame.GetName then
        Emit("    .GetName() = " .. SafeCall(frame.GetName, frame))
    end
    if frame.GetParent then
        local ok, parent = pcall(frame.GetParent, frame)
        if ok and parent and parent.GetName then
            Emit("    .GetParent():GetName() = " .. SafeCall(parent.GetName, parent))
        end
    end

    -- Estado real: color e IsShown, para poder cruzar "¿cambia entre casting
    -- true/false?" y "¿cambia entre interrumpible/no interrumpible?" sin
    -- adivinar por posición en el árbol.
    if frame.GetStatusBarColor then
        Emit("    .GetStatusBarColor() = " .. SafeCall(frame.GetStatusBarColor, frame))
    end
    if frame.IsShown then
        Emit("    .IsShown() = " .. SafeCall(frame.IsShown, frame))
    end
    if frame.GetValue and frame.GetMinMaxValues then
        Emit("    .GetValue() = " .. SafeCall(frame.GetValue, frame))
        Emit("    .GetMinMaxValues() = " .. SafeCall(frame.GetMinMaxValues, frame))
    end
end

-- Escaneo plano con pairs(): encuentra campos nombrados aunque no cuelguen
-- del árbol visual de GetChildren().
local function ScanPairs(label, tbl)
    if type(tbl) ~= "table" then
        Emit(label .. " no es tabla (" .. SafeString(tbl) .. ")")
        return
    end
    local ok, err = pcall(function()
        for key, value in pairs(tbl) do
            if type(value) == "table" then
                DescribeBarCandidate(label .. "." .. tostring(key), value)
            end
        end
    end)
    if not ok then
        Emit("  ScanPairs(" .. label .. ") ERROR: " .. SafeString(err))
    end
end

-- Descenso recursivo por GetChildren()/GetRegions() buscando candidatas,
-- por si el campo no está expuesto como key directa de UnitFrame.
local function ScanChildrenRecursive(label, frame, depth, maxDepth, visited)
    if not frame or depth > maxDepth then return end
    visited = visited or {}
    if visited[frame] then return end
    visited[frame] = true

    if frame.GetChildren then
        local ok, children = pcall(function() return { frame:GetChildren() } end)
        if ok then
            for i, child in ipairs(children) do
                local childLabel = label .. ">child" .. i
                DescribeBarCandidate(childLabel, child)
                ScanChildrenRecursive(childLabel, child, depth + 1, maxDepth, visited)
            end
        end
    end
end

-- ----------------------------------------------------------------------
-- Volcado crudo de UnitCastingInfo / UnitChannelInfo
-- ----------------------------------------------------------------------

local function DumpCastingInfo(unit)
    Emit("  UnitCastingInfo(" .. SafeString(unit) .. "):")
    local r = { UnitCastingInfo(unit) }
    if #r == 0 then
        Emit("    <sin cast activo / nil>")
    else
        for i, v in ipairs(r) do
            Emit(string.format("    [%d] = %s", i, SafeString(v)))
        end
    end

    Emit("  UnitChannelInfo(" .. SafeString(unit) .. "):")
    local c = { UnitChannelInfo(unit) }
    if #c == 0 then
        Emit("    <sin channel activo / nil>")
    else
        for i, v in ipairs(c) do
            Emit(string.format("    [%d] = %s", i, SafeString(v)))
        end
    end
end

-- ----------------------------------------------------------------------
-- Sección: unidad concreta (castbar + cast info)
-- ----------------------------------------------------------------------

local function DescribeUnit(unit, nameplate, index)
    Emit("nameplate[" .. index .. "] unit=" .. SafeString(unit))
    if not unit or not UnitExists(unit) then
        Emit("  UnitExists=false")
        return
    end

    local casting = UnitCastingInfo(unit) ~= nil
    local channeling = UnitChannelInfo(unit) ~= nil
    Emit("  casting=" .. SafeString(casting) .. " channeling=" .. SafeString(channeling))

    if casting or channeling then
        DumpCastingInfo(unit)
    end

    local uf = nameplate.UnitFrame or nameplate
    Emit("  -- escaneo pairs(UnitFrame) --")
    ScanPairs("UnitFrame", uf)

    Emit("  -- escaneo recursivo GetChildren (profundidad 3) --")
    ScanChildrenRecursive("UnitFrame", uf, 1, 3)

    if nameplate ~= uf then
        Emit("  -- escaneo pairs(nameplate) --")
        ScanPairs("nameplate", nameplate)
        Emit("  -- escaneo recursivo GetChildren(nameplate) --")
        ScanChildrenRecursive("nameplate", nameplate, 1, 3)
    end

    -- Resultado de la heurística actual del addon, para comparar.
    local castBar = Minimizer.CastingBar and Minimizer.CastingBar.GetCastBar
        and Minimizer.CastingBar:GetCastBar(nameplate)
    Emit("  Minimizer.CastingBar:GetCastBar (heurística actual) = " .. SafeString(castBar))
end

-- ----------------------------------------------------------------------
-- Sección: verificación de APIs listadas en project.md
-- ----------------------------------------------------------------------

local function CheckProjectMdAPIs()
    Section("1. APIs de nameplate (project.md #1)")
    CheckAPI({ "C_NamePlateManager", "SetNamePlateSimplified" })
    CheckAPI({ "C_NamePlateManager", "SetNamePlateHitTestInsets" })
    CheckAPI({ "C_NamePlate", "GetNamePlateForUnit" })
    CheckAPI({ "C_NamePlate", "GetNamePlates" })
    CheckAPI({ "C_NamePlate", "SetNamePlateSize" })
    CheckAPI({ "C_NamePlate", "SetNamePlateEnemySize" })
    CheckAPI({ "C_NamePlate", "SetNamePlateFriendlySize" })
    CheckAPI({ "NamePlateDriverFrame" })
    CheckAPI({ "Enum", "NamePlateType", "Enemy" })
    Emit("issecure() = " .. SafeCall(issecure))

    Section("2. Cache de cast / duraciones (project.md #3)")
    CheckAPI({ "UnitCastingInfo" })
    CheckAPI({ "UnitChannelInfo" })
    CheckAPI({ "UnitCastingDuration" }, "objeto Duration, solo Secrets")
    CheckAPI({ "UnitChannelDuration" }, "objeto Duration, solo Secrets")
    CheckAPI({ "UnitEmpoweredChannelDuration" }, "solo Secrets")

    Section("3. Colores / interrupción (project.md #4)")
    CheckAPI({ "C_Spell", "GetSpellCooldown" })
    CheckAPI({ "C_Spell", "GetSpellCooldownDuration" }, "Midnight, objeto Duration")
    CheckAPI({ "C_Spell", "IsSpellImportant" })
    CheckAPI({ "C_CurveUtil", "EvaluateColorValueFromBoolean" })
    CheckAPI({ "C_CurveUtil", "CreateColorCurve" })
    CheckAPI({ "C_CurveUtil", "CreateCurve" })
    if C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean then
        -- Firma confirmada en corridas previas: (state, valueIfTrue:number,
        -- valueIfFalse:number) -> number (escalar, NO un color RGB de una vez).
        -- Se llama una vez por canal para construir el color completo.
        Emit("  Firma confirmada: EvaluateColorValueFromBoolean(state, numTrue, numFalse) -> number")
        Emit("  Prueba canal-por-canal, state=true, colorTrue={0.1,1,0.1} colorFalse={0.45,0.45,0.45}:")
        Emit("    R: " .. SafeCall(C_CurveUtil.EvaluateColorValueFromBoolean, true, 0.1, 0.45))
        Emit("    G: " .. SafeCall(C_CurveUtil.EvaluateColorValueFromBoolean, true, 1.0, 0.45))
        Emit("    B: " .. SafeCall(C_CurveUtil.EvaluateColorValueFromBoolean, true, 0.1, 0.45))
        Emit("  Misma prueba con state=false (debería devolver los valores 'False'):")
        Emit("    R: " .. SafeCall(C_CurveUtil.EvaluateColorValueFromBoolean, false, 0.1, 0.45))
        Emit("    G: " .. SafeCall(C_CurveUtil.EvaluateColorValueFromBoolean, false, 1.0, 0.45))
        Emit("    B: " .. SafeCall(C_CurveUtil.EvaluateColorValueFromBoolean, false, 0.1, 0.45))
    end
    CheckAPI({ "UnitIsSpellTarget" })
    CheckAPI({ "C_SpellBook", "IsSpellKnown" })
    CheckAPI({ "C_SpellBook", "IsSpellKnownOrInSpellBook" })
    CheckAPI({ "IsPlayerSpell" })

    Section("4. Taint / valores secretos (project.md #5)")
    CheckAPI({ "issecretvalue" })
    CheckAPI({ "C_Secrets", "HasSecretRestrictions" })
    CheckAPI({ "C_Secrets", "ShouldAurasBeSecret" })
    CheckAPI({ "C_Secrets", "ShouldUnitIdentityBeSecret" })
    CheckAPI({ "SetAlphaFromBoolean" }, "método de región, no global; comprobar por instancia")
    CheckAPI({ "InCombatLockdown" })
    CheckAPI({ "hooksecurefunc" })
    if C_Secrets and C_Secrets.HasSecretRestrictions then
        Emit("  C_Secrets.HasSecretRestrictions() = " .. SafeCall(C_Secrets.HasSecretRestrictions))
    end
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        Emit("  C_Secrets.ShouldAurasBeSecret() = " .. SafeCall(C_Secrets.ShouldAurasBeSecret))
    end
    Emit("  InCombatLockdown() = " .. SafeCall(InCombatLockdown))

    Section("5. Tipo de mob / salud (project.md #6)")
    CheckAPI({ "UnitClassification" })
    CheckAPI({ "UnitEffectiveLevel" })
    CheckAPI({ "UnitIsLieutenant" })
    CheckAPI({ "UnitHasPowerType" })
    CheckAPI({ "UnitPowerType" })
    CheckAPI({ "Enum", "PowerType", "Mana" })
    CheckAPI({ "C_ClassColor", "GetClassColor" })

    Section("6. Threat (project.md #5 del doc original)")
    CheckAPI({ "UnitThreatSituation" })
    Emit("  UnitThreatSituation('player','target') = " .. SafeCall(UnitThreatSituation, "player", "target"))

    Section("7. Target / focus / alpha (project.md #7)")
    CheckAPI({ "UnitIsUnit" })
    CheckAPI({ "PixelUtil", "SetSize" })
    CheckAPI({ "PixelUtil", "ConvertPixelsToUIForRegion" })

    Section("8. CVars de nameplate (project.md #11)")
    CheckAPI({ "C_CVar", "SetCVar" })
    CheckAPI({ "C_CVar", "GetCVar" })
    CheckAPI({ "C_CVar", "GetCVarInfo" })
    CheckAPI({ "C_CVar", "SetCVarBitfield" })
    CheckAPI({ "GetCVarBool" })

    Section("9. Utilidades varias")
    CheckAPI({ "C_EventUtils", "IsEventValid" })
    CheckAPI({ "C_Timer", "NewTicker" })
    CheckAPI({ "Mixin" })
    CheckAPI({ "CreateFramePool" })
    CheckAPI({ "C_TooltipInfo", "GetUnit" })
    CheckAPI({ "UnitGUID" })
end

-- ----------------------------------------------------------------------
-- Entry point
-- ----------------------------------------------------------------------

function Diagnostic.Run()
    reportLines = {}
    Emit("BEGIN - " .. date("!%Y-%m-%d %H:%M:%S UTC"))

    Section("0. Sanidad general")
    Emit("C_CurveUtil=" .. SafeString(C_CurveUtil))
    Emit("NamePlateDriverFrame=" .. SafeString(NamePlateDriverFrame))
    Emit("C_NamePlate.GetNamePlates=" .. SafeString(C_NamePlate and type(C_NamePlate.GetNamePlates)))
    Emit("CompactUnitFrame_UpdateHealthColor=" .. SafeString(type(CompactUnitFrame_UpdateHealthColor)))

    CheckProjectMdAPIs()

    Section("10. Nameplates activas - búsqueda de castbar real")
    local plates = C_NamePlate and C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates() or {}
    Emit("nameplates=" .. #plates)
    for index, nameplate in ipairs(plates) do
        local unit = nameplate.namePlateUnitToken
            or (nameplate.UnitFrame and nameplate.UnitFrame.unit)
        DescribeUnit(unit, nameplate, index)
    end

    Emit("")
    Emit("END - copia todo el bloque rojo del chat")

    local report = table.concat(reportLines, "\n")
    Diagnostic.LastReport = report

    -- Show() por sí solo abre un panel vacío. El manejador global de errores
    -- crea la entrada real y rellena el texto del ScriptErrorsFrame.
    if geterrorhandler then
        geterrorhandler()(report)
    elseif ScriptErrorsFrame and ScriptErrorsFrame.Show then
        ScriptErrorsFrame:Show()
        if ScriptErrorsFrame.message then
            ScriptErrorsFrame.message:SetText(report)
        end
    end
end
