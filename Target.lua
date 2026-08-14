local _, Minimizer = ...
if not Minimizer then return end

local Target = {}
Minimizer.Target = Target

local offFrame, offIcon, offCooldown = Minimizer.Widgets.CreateCDWidget("MinimizerTargetOffensiveCD", 30)
local defFrame, defIcon, defCooldown = Minimizer.Widgets.CreateCDWidget("MinimizerTargetDefensiveCD", 30)

function Target:UpdateTargetCDs()
    if not UnitExists("target") or UnitIsDead("target") then 
        offFrame:Hide()
        defFrame:Hide()
        return 
    end
    
    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit("target")
    if not plate then 
        offFrame:Hide()
        defFrame:Hide()
        return 
    end

    local offID = Minimizer.Widgets.GetCDSpellID(Minimizer.Data.OFFENSIVE_CDS)
    local defID = Minimizer.Widgets.GetCDSpellID(Minimizer.Data.DEFENSIVE_CDS)

    local showOff = Minimizer.Widgets.UpdateCDWidget(offFrame, offIcon, offCooldown, offID)
    local showDef = Minimizer.Widgets.UpdateCDWidget(defFrame, defIcon, defCooldown, defID)

    -- Positioning relative to target plate's top
    -- We can put them side by side
    offFrame:ClearAllPoints()
    defFrame:ClearAllPoints()

    if showOff and showDef then
        offFrame:SetPoint("BOTTOMRIGHT", plate, "TOP", -5, 10)
        defFrame:SetPoint("BOTTOMLEFT", plate, "TOP", 5, 10)
    elseif showOff then
        offFrame:SetPoint("BOTTOM", plate, "TOP", 0, 10)
    elseif showDef then
        defFrame:SetPoint("BOTTOM", plate, "TOP", 0, 10)
    end
end

-- Throttle a 30 FPS (0.033s): visuales de target no necesitan repintarse más rápido.
Target.DebouncedUpdate = Minimizer.Utils.Throttle(function()
    Target:UpdateTargetCDs()
end, 0.033)

