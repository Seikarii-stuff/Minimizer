local _, Minimizer = ...
if not Minimizer then return end

local Target = {}
Minimizer.Target = Target

-- "Insignia": el widget grande de siempre, ahora es el único widget grande
-- del target (el defensivo pasa a ser un pip anclado a esta misma insignia).
local offFrame, offIcon, offCooldown = Minimizer.Widgets.CreateCDWidget("MinimizerTargetInsignia", 30)
local defPip = Minimizer.Widgets.CreatePip("MinimizerTargetDefensivePip", offFrame, "defensive", "TOPLEFT")

function Target:UpdateTargetCDs()
    if not UnitExists("target") or UnitIsDead("target") then 
        offFrame:Hide()
        return 
    end
    
    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit("target")
    if not plate then 
        offFrame:Hide()
        return 
    end

    local offID = Minimizer.Widgets.GetCDSpellID(Minimizer.Data.OFFENSIVE_CDS)
    local defID = Minimizer.Widgets.GetCDSpellID(Minimizer.Data.DEFENSIVE_CDS)

    local showOff = Minimizer.Widgets.UpdateCDWidget(offFrame, offIcon, offCooldown, offID)
    -- El pip defensivo es hijo de offFrame (ver 4.1): se mueve solo con la
    -- insignia, no necesita posicionamiento propio relativo a la plate.
    Minimizer.Widgets.UpdatePip(defPip, defID)

    if showOff then
        offFrame:ClearAllPoints()
        offFrame:SetPoint("BOTTOM", plate, "TOP", 0, 10)
    else
        offFrame:Hide()
    end
end

-- Throttle a 30 FPS (0.033s): visuales de target no necesitan repintarse más rápido.
Target.DebouncedUpdate = Minimizer.Utils.Throttle(function()
    Target:UpdateTargetCDs()
end, 0.033)

