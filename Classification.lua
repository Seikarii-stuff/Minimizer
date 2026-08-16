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
    if not unit then return nil end

    if Minimizer.Cache and Minimizer.Cache.GetUnitKeyWithGeneration then
        local cached = Minimizer.Cache.GetUnitKeyWithGeneration(unit, "eliteType")
        if cached ~= nil then
            return cached
        end
    end

    local classification = UnitClassification(unit)
    local result
    if IsTrivial(unit, classification) then
        result = "trivial"
    else
        local superior = GetSuperiorKind(unit, classification)
        if superior then
            result = superior
        elseif HasMana(unit) then
            result = "caster"
        else
            result = "melee"
        end
    end

    if Minimizer.Cache and Minimizer.Cache.SetUnitKeyWithGeneration then
        Minimizer.Cache.SetUnitKeyWithGeneration(unit, "eliteType", result)
    end
    return result
end
