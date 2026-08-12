-- Minimizer
-- 1) /simp 0-100: 0 = default de Blizzard, 100 = simplificado + escala 50%.
-- 2) Cualquier mob que empiece a castear se desimplifica y queda así mientras
--    siga vivo/en pantalla. En cuanto su nameplate desaparece de forma
--    natural (muere o sale de rango) se limpia su entrada -> sin memory leak.
-- 3) Flechas ">>" "<<" apuntando hacia dentro para target (blanco) y focus
--    (amarillo). La barra de vida del focus es amarilla SOLO si no tiene
--    aggro; si lo tiene, se ve el color default de Blizzard (threat).

local ADDON_NAME = ...

MinimizerDB = MinimizerDB or { simplifyPercent = 0 }

local Minimizer = CreateFrame("Frame", "MinimizerCore")

local MAX_SCALE_MULT = 1.0   -- escala en 0%
local MIN_SCALE_MULT = 0.5   -- escala en 100%

-- Convierte el porcentaje 0-100 en un multiplicador de escala 1.0 -> 0.5
local function GetScaleForPercent(percent)
	percent = math.max(0, math.min(100, percent))
	local t = percent / 100
	return MAX_SCALE_MULT - (MAX_SCALE_MULT - MIN_SCALE_MULT) * t
end

-- Si el focus no tiene aggro, forzamos amarillo para distinguirlo. Cuando sí
-- tiene aggro, dejamos que Blizzard recalcule el color por defecto del health
-- bar (rojo) y no hacemos nada extra.
local function ApplyFocusColor(unit, uf)
	if not uf or not uf.healthBar then return false end

	local hasThreat = false
	local threat = UnitThreatSituation("player", unit)
	if threat ~= nil and threat > 0 then
		hasThreat = true
	end

	if hasThreat then
		if CompactUnitFrame_UpdateHealthColor then
			CompactUnitFrame_UpdateHealthColor(uf)
		end
		return false
	end

	uf.healthBar:SetStatusBarColor(1, 1, 0, 1)
	return true
end

-- Crea (una sola vez por frame de nameplate reciclado) las 4 flechas.
local function EnsureMarkers(nameplate)
	if nameplate.MinimizerMarkers then return nameplate.MinimizerMarkers end

	local uf = nameplate.UnitFrame
	if not uf or not uf.healthBar then return nil end

	local function MakeArrow(text, point, relPoint, xOff, yOff, color)
		local fs = uf:CreateFontString(nil, "OVERLAY")
		fs:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
		fs:SetPoint(point, uf.healthBar, relPoint, xOff, yOff)
		fs:SetText(text)
		if color then
			fs:SetTextColor(color[1], color[2], color[3])
		end
		fs:Hide()
		return fs
	end

	local markers = {
		-- Target: fila superior, color blanco (default)
		targetLeft  = MakeArrow(">>", "RIGHT", "LEFT",  -2,  6),
		targetRight = MakeArrow("<<", "LEFT",  "RIGHT",  2,  6),
		-- Focus: fila inferior, amarillo
		focusLeft   = MakeArrow(">>", "RIGHT", "LEFT",  -2, -6, {1, 1, 0}),
		focusRight  = MakeArrow("<<", "LEFT",  "RIGHT",  2, -6, {1, 1, 0}),
		colorOverridden = false, -- si la última pasada forzamos amarillo
	}

	nameplate.MinimizerMarkers = markers
	return markers
end

-- Actualiza flechas de target/focus y el color del focus según aggro.
-- Cuando hay aggro, dejamos que Blizzard pinte la barra con su color por
-- defecto; solo forzamos amarillo cuando no hay aggro y el mob es focus.
local function UpdateTargetFocusMarkers(unit, nameplate)
	local markers = EnsureMarkers(nameplate)
	if not markers then return end

	local isTarget = UnitIsUnit(unit, "target")
	local isFocus = UnitIsUnit(unit, "focus")

	markers.targetLeft:SetShown(isTarget)
	markers.targetRight:SetShown(isTarget)
	markers.focusLeft:SetShown(isFocus)
	markers.focusRight:SetShown(isFocus)

	local uf = nameplate.UnitFrame
	if uf and uf.healthBar then
		if isFocus then
			markers.colorOverridden = ApplyFocusColor(unit, uf)
		elseif markers.colorOverridden then
			if CompactUnitFrame_UpdateHealthColor then
				CompactUnitFrame_UpdateHealthColor(uf)
			end
			markers.colorOverridden = false
		end
	end
end

-- Aplica simplificación + escala + marcadores a una unidad concreta.
-- Reglas:
-- 1) si el bicho está casteando: desimplificar permanentemente
-- 2) si el bicho tiene amenaza: desimplificar temporalmente hasta que Blizzard
--    recupere el aggro
-- 3) fuera de combate: dessimplificar para permitir targetear bien
-- 4) en combate y sin cast ni amenaza: aplicar el porcentaje de simplificación
local function ApplyToUnit(unit)
	if not unit or not UnitExists(unit) then return end

	-- Solo tocamos nameplates de enemigos (mobs), no jugadores ni aliados.
	if not UnitCanAttack("player", unit) then return end

	local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
	local forceUnsimplified = nameplate and nameplate.MinimizerNeverSimplify
	local inCombat = UnitAffectingCombat("player")
	local isCasting = UnitCastingInfo(unit) ~= nil or UnitChannelInfo(unit) ~= nil
	local hasThreat = UnitThreatSituation("player", unit) ~= nil and UnitThreatSituation("player", unit) > 0

	local shouldSimplify = false
	if inCombat and not forceUnsimplified and not isCasting and not hasThreat then
		shouldSimplify = MinimizerDB.simplifyPercent > 0
	end

	if C_NamePlateManager and C_NamePlateManager.SetNamePlateSimplified then
		C_NamePlateManager.SetNamePlateSimplified(unit, shouldSimplify)
	end

	local scalePercent = shouldSimplify and MinimizerDB.simplifyPercent or 0
	if nameplate then
		nameplate:SetScale(GetScaleForPercent(scalePercent))
		UpdateTargetFocusMarkers(unit, nameplate)
	end
end

-- Reaplica a todas las nameplates visibles actualmente
local function ApplyToAllNameplates()
	for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
		if nameplate.namePlateUnitToken then
			ApplyToUnit(nameplate.namePlateUnitToken)
		end
	end
end

-- Marca la nameplate como "no simplificar" en cuanto empieza a castear.
-- El flag vive en el propio frame de la nameplate, no en una tabla externa
-- por GUID (UnitGUID devuelve un "secret value" que no se puede usar como
-- clave de tabla en el cliente actual).
local function MarkNeverSimplify(unit)
	if not unit or not UnitExists(unit) then return end
	if not UnitCanAttack("player", unit) then return end

	local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
	if not nameplate then return end

	if not nameplate.MinimizerNeverSimplify then
		nameplate.MinimizerNeverSimplify = true
		ApplyToUnit(unit) -- refresco inmediato, no hace falta esperar al ticker
	end
end

-- Limpia el flag cuando la nameplate desaparece de forma natural (muerte,
-- salir de rango, cambio de zona...). Como el flag vive en el propio frame,
-- esto no requiere ninguna tabla que pueda acumular entradas.
local function ClearNeverSimplify(unit)
	if not unit then return end
	local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
	if nameplate then
		nameplate.MinimizerNeverSimplify = nil
	end
end

Minimizer:RegisterEvent("NAME_PLATE_UNIT_ADDED")
Minimizer:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
Minimizer:RegisterEvent("PLAYER_ENTERING_WORLD")
Minimizer:RegisterEvent("PLAYER_TARGET_CHANGED")
Minimizer:RegisterEvent("PLAYER_FOCUS_CHANGED")
Minimizer:RegisterEvent("UNIT_SPELLCAST_START")
Minimizer:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
Minimizer:RegisterEvent("UNIT_SPELLCAST_EMPOWER_START")
Minimizer:RegisterEvent("UNIT_THREAT_LIST_UPDATE")

Minimizer:SetScript("OnEvent", function(self, event, unit)
	if event == "NAME_PLATE_UNIT_ADDED" then
		ApplyToUnit(unit)
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		ClearNeverSimplify(unit)
	elseif event == "PLAYER_ENTERING_WORLD"
		or event == "PLAYER_TARGET_CHANGED"
		or event == "PLAYER_FOCUS_CHANGED" then
		ApplyToAllNameplates()
	elseif event == "UNIT_SPELLCAST_START"
		or event == "UNIT_SPELLCAST_CHANNEL_START"
		or event == "UNIT_SPELLCAST_EMPOWER_START" then
		MarkNeverSimplify(unit)
	elseif event == "UNIT_THREAT_LIST_UPDATE" then
		-- Reevalúa solo esta unidad (puede ser el focus ganando/perdiendo aggro)
		ApplyToUnit(unit)
	end
end)

-- Salvaguarda: Blizzard puede resetear escala/estado/color en ciertos
-- momentos. Reaplicamos cada segundo por si algo se nos "escapa" entre
-- eventos (no acumula nada, solo relee el estado actual).
C_Timer.NewTicker(1, ApplyToAllNameplates)

-- Comando /simp <0-100>
SLASH_MINIMIZER1 = "/simp"
SlashCmdList["MINIMIZER"] = function(msg)
	local value = tonumber(msg)

	if not value then
		print("|cff33ff99Minimizer|r: uso /simp <0-100>. Valor actual: " .. MinimizerDB.simplifyPercent .. "%")
		return
	end

	value = math.floor(math.max(0, math.min(100, value)))
	MinimizerDB.simplifyPercent = value

	print("|cff33ff99Minimizer|r: simplificación ajustada a " .. value .. "%")
	ApplyToAllNameplates()
end
