local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Classification = Minimizer.Classification or {}

local function IsTrivial(unit, classification)
    if Minimizer.Utils.IsSecretValue(classification) then return false end
    if classification == "trivial" or classification == "minus" then return true end
    local level = UnitEffectiveLevel(unit)
    local playerLevel = UnitEffectiveLevel("player")
    if Minimizer.Utils.IsSecretValue(level) or Minimizer.Utils.IsSecretValue(playerLevel) then return false end
    return type(level) == "number" and type(playerLevel) == "number"
        and level > 0 and level <= playerLevel - 10
end

local function GetSuperiorKind(unit, classification)
    if Minimizer.Utils.IsSecretValue(classification) then return nil end
    if classification == "worldboss" then return "boss" end

    if classification == "elite" or classification == "rareelite" then
        local level = UnitEffectiveLevel(unit)
        local playerLevel = UnitEffectiveLevel("player")
        
        if not Minimizer.Utils.IsSecretValue(level) and not Minimizer.Utils.IsSecretValue(playerLevel)
           and type(level) == "number" and type(playerLevel) == "number" then
            
            local isSkull = level == -1
            local aboveOne = level >= playerLevel + 1
            
            if isSkull or aboveOne then
                local aboveTwo = level >= playerLevel + 2
                local lieutenant = (not isSkull) and UnitIsLieutenant and UnitIsLieutenant(unit)
                
                if not lieutenant and (isSkull or aboveTwo) then
                    return "boss"
                else
                    return "miniboss"
                end
            end
        end
    end

    if UnitIsLieutenant and UnitIsLieutenant(unit) == true then return "miniboss" end
    return nil
end

local function HasMana(unit)
    if UnitHasPowerType and Enum and Enum.PowerType and Enum.PowerType.Mana then
        local value = UnitHasPowerType(unit, Enum.PowerType.Mana)
        return not Minimizer.Utils.IsSecretValue(value) and value == true
    end
    local powerType = UnitPowerType(unit)
    return not Minimizer.Utils.IsSecretValue(powerType) and powerType == 0
end

function Minimizer.Classification.GetEliteType(unit)
    local classification = UnitClassification(unit)
    if IsTrivial(unit, classification) then return "trivial" end
    local superior = GetSuperiorKind(unit, classification)
    if superior then return superior end
    if HasMana(unit) then return "caster" end
    return "melee"
end
