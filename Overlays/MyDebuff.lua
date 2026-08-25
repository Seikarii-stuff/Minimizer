local _, Minimizer = ...
if not Minimizer then return end

local MyDebuff = {}
Minimizer.MyDebuff = MyDebuff

local ORANGE = { 1.00, 0.35, 0.00, 0.55 }

-- Blizzard's modern aura API can return secret aura data. Calling
-- GetAuraDataByIndex from addon code can therefore raise a taint error.
-- Track only player-applied harmful auras from the combat log instead.
-- Combat-log GUIDs are plain event data; no aura fields are inspected or
-- compared, so this path never reads or compares secret aura values.
local playerGUID
local harmfulDebuffs = {}

local function GetPlayerGUID()
    if not playerGUID and UnitGUID then
        playerGUID = UnitGUID("player")
    end
    return playerGUID
end

local function GetDestDebuffs(destGUID)
    if not destGUID then return nil end
    local debuffs = harmfulDebuffs[destGUID]
    if not debuffs then
        debuffs = {}
        harmfulDebuffs[destGUID] = debuffs
    end
    return debuffs
end

local function SetDebuff(destGUID, spellID)
    if not destGUID or type(spellID) ~= "number" then return end
    local debuffs = GetDestDebuffs(destGUID)
    debuffs[spellID] = true
end

local function ClearDebuff(destGUID, spellID)
    local debuffs = destGUID and harmfulDebuffs[destGUID]
    if not debuffs then return end
    if type(spellID) == "number" then
        debuffs[spellID] = nil
    else
        harmfulDebuffs[destGUID] = nil
        return
    end
    if next(debuffs) == nil then
        harmfulDebuffs[destGUID] = nil
    end
end

local function HasMyDebuffGUID(destGUID)
    local debuffs = destGUID and harmfulDebuffs[destGUID]
    return debuffs ~= nil and next(debuffs) ~= nil
end

local function RefreshUnit(unit)
    if not unit or not unit:match("^nameplate%d+$") then return end
    local nameplate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
    if nameplate then
        MyDebuff:Update(unit, nameplate)
    end
end

local CombatLogFrame = CreateFrame("Frame", "MinimizerMyDebuffCombatLogFrame")
CombatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
CombatLogFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
CombatLogFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        playerGUID = UnitGUID and UnitGUID("player") or nil
        wipe(harmfulDebuffs)
        return
    end

    if not CombatLogGetCurrentEventInfo then return end
    local _, subEvent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellID = CombatLogGetCurrentEventInfo()
    if not sourceGUID or sourceGUID ~= GetPlayerGUID() or not destGUID then return end

    if subEvent == "SPELL_AURA_APPLIED"
        or subEvent == "SPELL_AURA_APPLIED_DOSE"
        or subEvent == "SPELL_AURA_REFRESH" then
        SetDebuff(destGUID, spellID)
    elseif subEvent == "SPELL_AURA_REMOVED"
        or subEvent == "SPELL_AURA_REMOVED_DOSE" then
        ClearDebuff(destGUID, spellID)
    elseif subEvent == "UNIT_DIED" or subEvent == "UNIT_DESTROYED" then
        ClearDebuff(destGUID)
    end

    local plates = (Minimizer.Lifecycle and Minimizer.Lifecycle.GetActiveNameplates and Minimizer.Lifecycle.GetActiveNameplates())
        or Minimizer.ActiveNameplates
    if plates then
        for unit, nameplate in pairs(plates) do
            if UnitGUID and UnitGUID(unit) == destGUID then
                MyDebuff:Update(unit, nameplate)
                break
            end
        end
    end
end)

function MyDebuff:HasMyDebuff(unit)
    if not unit or not UnitExists(unit) or not UnitGUID then return false end
    return HasMyDebuffGUID(UnitGUID(unit))
end

local function EnsureOverlay(healthBar)
    local overlay = healthBar.MinimizerMyDebuffOverlay
    if overlay then return overlay end

    overlay = healthBar:CreateTexture(nil, "OVERLAY")
    overlay:SetAllPoints(healthBar)
    overlay:SetColorTexture(ORANGE[1], ORANGE[2], ORANGE[3], ORANGE[4])
    overlay:Hide()
    healthBar.MinimizerMyDebuffOverlay = overlay
    return overlay
end

function MyDebuff:Update(unit, nameplate)
    local healthBar = nameplate and Minimizer.Utils and Minimizer.Utils.GetHealthBar
        and Minimizer.Utils.GetHealthBar(nameplate)
    if not healthBar then return end

    local overlay = EnsureOverlay(healthBar)
    if MinimizerDB and MinimizerDB.enableMyDebuffOverlay == true and self:HasMyDebuff(unit) then
        overlay:Show()
    else
        overlay:Hide()
    end
end

function MyDebuff:OnUnitChanged(unit, reason)
    if reason == "removed" then
        if unit and UnitGUID then
            harmfulDebuffs[UnitGUID(unit)] = nil
        end
        return
    end
    if unit and unit:match("^nameplate%d+$") then
        RefreshUnit(unit)
    end
end

function MyDebuff:UpdateAll()
    local plates = (Minimizer.Lifecycle and Minimizer.Lifecycle.GetActiveNameplates and Minimizer.Lifecycle.GetActiveNameplates())
        or Minimizer.ActiveNameplates
    if not plates then return end
    for unit, nameplate in pairs(plates) do
        self:Update(unit, nameplate)
    end
end

if Minimizer.Overlays and Minimizer.Overlays.Register then
    Minimizer.Overlays.Register("MyDebuff", MyDebuff)
end
