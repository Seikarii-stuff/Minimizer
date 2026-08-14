local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Absorb = Minimizer.Absorb or {}

local UnitExists = UnitExists

function Minimizer.Absorb.HasAbsorb(unit, nameplate)
    if not unit or not UnitExists(unit) then return false end
    nameplate = nameplate or Minimizer.Utils.GetNamePlateForUnit(unit)
    
    local healthBar = Minimizer.Utils.GetHealthBar(nameplate)
    local indicator = healthBar and (healthBar.totalAbsorbOverlay or healthBar.totalAbsorb)
    return indicator and indicator.IsShown and indicator:IsShown() == true or false
end
