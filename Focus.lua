local _, Minimizer = ...
if not Minimizer then return end
-- Config.Initialize() ya fue invocada por Bootstrap.lua tras ADDON_LOADED.

MinimizerDB = MinimizerDB or {}

local Focus = {}
Minimizer.Focus = Focus

local HALO_SIZE = 46
local PORTRAIT_RADIUS = 18
local frame = CreateFrame("Frame", "MinimizerFocusPortrait", UIParent)
frame:SetSize(40, 40)
frame:SetFrameStrata("HIGH")
frame:Hide()

local portrait = frame:CreateTexture(nil, "ARTWORK")
portrait:SetAllPoints()

local cooldown = CreateFrame("Cooldown", "MinimizerFocusCooldown", frame, "CooldownFrameTemplate")
cooldown:SetAllPoints()
Minimizer.Widgets.MakeCooldownCircular(cooldown, true)

local ccPip
if Minimizer.Widgets and Minimizer.Widgets.CreatePip then
    ccPip = Minimizer.Widgets.CreatePip("MinimizerFocusCCPip", frame, "cc", "TOPRIGHT", PORTRAIT_RADIUS)
end

local function UpdateCooldown()
    local interruptSpellID = Minimizer.Interrupt and Minimizer.Interrupt.GetSpellID
        and Minimizer.Interrupt.GetSpellID()
    if not interruptSpellID or not C_Spell then return end

    if Minimizer.Widgets and Minimizer.Widgets.ApplyCooldownDuration then
        Minimizer.Widgets.ApplyCooldownDuration(cooldown, interruptSpellID)
    end

    if Minimizer.Interrupt and Minimizer.Interrupt.IsReady and Minimizer.Utils and Minimizer.Utils.ApplyReadyShade then
        Minimizer.Utils.ApplyReadyShade(portrait, Minimizer.Interrupt.IsReady())
    end
end

function Focus:SetFaceEnabled(enabled)
    MinimizerDB.enableFocusFace = enabled == true
    if MinimizerDB.enableFocusFace ~= true then
        frame:Hide()
        if ccPip then ccPip:Hide() end
    end
    if Minimizer.Core then Minimizer.Core.ApplyToAll() end
end

function Focus:SetArrowsEnabled(enabled)
    MinimizerDB.enableFocusArrows = enabled == true
    if Minimizer.Core then Minimizer.Core.ApplyToAll() end
end

function Focus:SetMode(mode)
    if mode == "face" then
        self:SetFaceEnabled(true)
        return
    end
    if mode == "arrows" then
        self:SetArrowsEnabled(true)
        return
    end
    if mode == "noface" then
        self:SetFaceEnabled(false)
        return
    end
    if mode == "noarrows" then
        self:SetArrowsEnabled(false)
        return
    end
end

function Focus:UpdateFace()
    if MinimizerDB.enableFocusFace ~= true then
        frame:Hide()
        if ccPip then ccPip:Hide() end
        return
    end
    if not UnitExists("focus") or UnitIsDead("focus") then
        frame:Hide()
        if ccPip then ccPip:Hide() end
        return
    end

    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit("focus")
    if not plate then
        frame:Hide()
        if ccPip then ccPip:Hide() end
        return
    end

    SetPortraitTexture(portrait, "player")
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", plate, "TOP", 0, 10 + (HALO_SIZE / 2))
    frame:Show()
    UpdateCooldown()

    if ccPip and Minimizer.Widgets and Minimizer.Widgets.GetCDSpellID then
        local overrideSpell = MinimizerCharDB and MinimizerCharDB.focusCC
        local ccID = Minimizer.Widgets.GetCDSpellID(Minimizer.Data.MASS_CC_SPELLS, overrideSpell)
        Minimizer.Widgets.UpdatePip(ccPip, ccID)
    end
end

-- Throttle a 30 FPS (0.033s): visuales de focus no necesitan repintarse más rápido.
Focus.DebouncedUpdate = Minimizer.Utils.Throttle(function()
    Focus:UpdateFace()
end, 0.033)

