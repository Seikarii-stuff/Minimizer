local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Classification = Minimizer.Classification or {}

local UnitEffectiveLevel = UnitEffectiveLevel
local UnitClassification = UnitClassification
local UnitIsLieutenant = UnitIsLieutenant
local UnitHasPowerType = UnitHasPowerType
local UnitPowerType = UnitPowerType
local MANA_POWER_TYPE = Enum and Enum.PowerType and Enum.PowerType.Mana

-- level/playerLevel se piden UNA sola vez en GetEliteType y se pasan como
-- parametro a IsTrivial/GetSuperiorKind -- antes cada funcion volvia a
-- llamar a UnitEffectiveLevel por su cuenta (hasta 4 llamadas nativas
-- donde bastan 2 por unidad/pase).
local function IsTrivial(classification, level, playerLevel)
    if Minimizer.Utils.IsSecretValue(classification) then return false end
    if classification == "trivial" or classification == "minus" then return true end
    if Minimizer.Utils.IsSecretValue(level) or Minimizer.Utils.IsSecretValue(playerLevel) then return false end
    return type(level) == "number" and type(playerLevel) == "number"
        and level > 0 and level <= playerLevel - 10
end

local function GetSuperiorKind(unit, classification, level, playerLevel)
    if Minimizer.Utils.IsSecretValue(classification) then return nil end
    if classification == "worldboss" then return "boss" end

    if classification == "elite" or classification == "rareelite" then
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
    if UnitHasPowerType and MANA_POWER_TYPE then
        local value = UnitHasPowerType(unit, MANA_POWER_TYPE)
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
    local level = UnitEffectiveLevel(unit)
    local playerLevel = UnitEffectiveLevel("player")

    local result
    if IsTrivial(classification, level, playerLevel) then
        result = "trivial"
    else
        local superior = GetSuperiorKind(unit, classification, level, playerLevel)
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
