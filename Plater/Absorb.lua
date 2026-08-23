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

local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs

function Minimizer.Absorb.GetTotalAbsorbs(unit)
    if not unit or not UnitExists(unit) then return 0 end
    if not UnitGetTotalAbsorbs then return 0 end
    local absorbs = UnitGetTotalAbsorbs(unit)
    if Minimizer.Utils and Minimizer.Utils.IsSecretValue and Minimizer.Utils.IsSecretValue(absorbs) then
        return absorbs
    end
    return absorbs or 0
end

function Minimizer.Absorb.MarkSeen(unit, nameplate, hasAbsorbNow)
    if not nameplate then return hasAbsorbNow == true end
    local isStale = (Minimizer.Lifecycle and Minimizer.Lifecycle.IsGenerationStale and Minimizer.Lifecycle.IsGenerationStale(unit, nameplate.MinimizerAbsorbPersistentGen))
    if isStale == nil then
        local currentGen = (Minimizer.Lifecycle and Minimizer.Lifecycle.GetGeneration and Minimizer.Lifecycle.GetGeneration(unit)) or 0
        isStale = nameplate.MinimizerAbsorbPersistentGen ~= currentGen
    end
    if isStale then
        local currentGen = (Minimizer.Lifecycle and Minimizer.Lifecycle.GetGeneration and Minimizer.Lifecycle.GetGeneration(unit)) or 0
        nameplate.MinimizerAbsorbPersistentGen = currentGen
        nameplate.MinimizerHasHadAbsorb = nil
    end
    if hasAbsorbNow then nameplate.MinimizerHasHadAbsorb = true end
    return nameplate.MinimizerHasHadAbsorb == true
end

