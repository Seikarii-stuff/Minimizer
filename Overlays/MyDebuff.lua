local _, Minimizer = ...
if not Minimizer then return end

local MyDebuff = {}
Minimizer.MyDebuff = MyDebuff

local ORANGE = { 1.00, 0.35, 0.00, 0.55 }

-- Midnight: do not call GetAuraDataByIndex/GetDebuffDataByIndex from addon
-- code while unit-aura data is restricted. GetUnitAuras returns a safe
-- container; the HARMFUL|PLAYER filter is evaluated by Blizzard's API, so
-- we only test whether the filtered result contains an entry. We never read
-- or compare any aura field (spellId, sourceUnit, duration, etc.).
local function HasMyDebuff(unit)
    if not unit or not UnitExists(unit) then return false end
    if not C_UnitAuras or type(C_UnitAuras.GetUnitAuras) ~= "function" then
        return false
    end

    local auras = C_UnitAuras.GetUnitAuras(unit, "HARMFUL|PLAYER")
    return auras ~= nil and auras[1] ~= nil
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
    if MinimizerDB and MinimizerDB.enableMyDebuffOverlay == true and HasMyDebuff(unit) then
        overlay:Show()
    else
        overlay:Hide()
    end
end

function MyDebuff:OnUnitChanged(unit, reason)
    if reason == "removed" then return end
    if unit and unit:match("^nameplate%d+$") then
        local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit
            and C_NamePlate.GetNamePlateForUnit(unit)
        if plate then
            self:Update(unit, plate)
        end
    end
end

function MyDebuff:UpdateAll()
    local plates = (Minimizer.Lifecycle and Minimizer.Lifecycle.GetActiveNameplates
        and Minimizer.Lifecycle.GetActiveNameplates()) or Minimizer.ActiveNameplates
    if not plates then return end

    for unit, nameplate in pairs(plates) do
        self:Update(unit, nameplate)
    end
end

if Minimizer.Overlays and Minimizer.Overlays.Register then
    Minimizer.Overlays.Register("MyDebuff", MyDebuff)
end
