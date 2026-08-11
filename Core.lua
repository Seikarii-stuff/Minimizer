-- Minimizer: función core única para probar viabilidad.
-- 0   = comportamiento default de Blizzard (sin tocar nada).
-- 100 = simplificado + escala al 50% (el "doble" de reducción).
-- Interpola linealmente entre ambos extremos.

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

-- Aplica simplificación + escala a una unidad concreta de nameplate
local function ApplyToUnit(unit)
	if not unit or not UnitExists(unit) then return end

	-- Solo tocamos nameplates de enemigos (mobs), no jugadores ni aliados.
	if not UnitCanAttack("player", unit) then return end

	local percent = MinimizerDB.simplifyPercent

	if C_NamePlateManager and C_NamePlateManager.SetNamePlateSimplified then
		C_NamePlateManager.SetNamePlateSimplified(unit, percent > 0)
	end

	local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
	if nameplate then
		nameplate:SetScale(GetScaleForPercent(percent))
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

Minimizer:RegisterEvent("NAME_PLATE_UNIT_ADDED")
Minimizer:RegisterEvent("PLAYER_ENTERING_WORLD")

Minimizer:SetScript("OnEvent", function(self, event, unit)
	if event == "NAME_PLATE_UNIT_ADDED" then
		ApplyToUnit(unit)
	elseif event == "PLAYER_ENTERING_WORLD" then
		ApplyToAllNameplates()
	end
end)

-- Salvaguarda: Blizzard puede resetear escala/estado del frame en ciertos
-- momentos (cambio de zona, reload de CVars, etc). Reaplicamos cada segundo.
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
