local _, Minimizer = ...
if not Minimizer then return end

local Target = {}
Minimizer.Target = Target

-- Reemplazamos la antigua insignia por un halo (anillo) enlazado al cooldown
-- real del spell ofensivo disponible para la clase del jugador.
local HALO_SIZE = 46
local offFrame = Minimizer.Widgets.CreateHalo("MinimizerTargetHalo", nil, HALO_SIZE)
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

    Minimizer.Widgets.UpdatePip(defPip, defID)

    if offID then
        Minimizer.Widgets.UpdateHalo(offFrame, offID)
        offFrame:ClearAllPoints()
        offFrame:SetPoint("BOTTOM", plate, "TOP", 0, 10)
    else
        offFrame:Hide()
    end
end

-- Throttle a 30 FPS (0.033s): visuales de target no necesitan repintarse más rápido.
Target.DebouncedUpdate = Minimizer.Utils.Throttle(function()
    Target:UpdateTargetCDs()
end, 0.030)

