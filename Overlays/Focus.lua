local _, Minimizer = ...
if not Minimizer then return end
-- Config.Initialize() ya fue invocada por Bootstrap.lua tras ADDON_LOADED.

MinimizerDB = MinimizerDB or {}

local Focus = {}
Minimizer.Focus = Focus

local HALO_SIZE = 46
local frame = CreateFrame("Frame", "MinimizerFocusPortrait", UIParent)
frame:SetSize(36, 36)
frame:SetFrameStrata("HIGH")
frame:Hide()

local portrait = frame:CreateTexture(nil, "ARTWORK")
portrait:SetAllPoints()

local cooldown = CreateFrame("Cooldown", "MinimizerFocusCooldown", frame, "CooldownFrameTemplate")
cooldown:SetAllPoints()
Minimizer.Widgets.MakeCooldownCircular(cooldown, true)

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
    end
    if Minimizer.Dispatcher and Minimizer.Dispatcher.RequestFullUpdate then
        Minimizer.Dispatcher.RequestFullUpdate()
    elseif Minimizer.Dispatcher and Minimizer.Dispatcher.ApplyToAll then
        Minimizer.Dispatcher.ApplyToAll()
    end
end

function Focus:SetArrowsEnabled(enabled)
    MinimizerDB.enableFocusArrows = enabled == true
    if Minimizer.Dispatcher and Minimizer.Dispatcher.RequestFullUpdate then
        Minimizer.Dispatcher.RequestFullUpdate()
    elseif Minimizer.Dispatcher and Minimizer.Dispatcher.ApplyToAll then
        Minimizer.Dispatcher.ApplyToAll()
    end
end

function Focus:SetMode(mode)
    if mode == "face" then self:SetFaceEnabled(true); return end
    if mode == "arrows" then self:SetArrowsEnabled(true); return end
    if mode == "noface" then self:SetFaceEnabled(false); return end
    if mode == "noarrows" then self:SetArrowsEnabled(false); return end
end

function Focus:UpdateFace()
    if MinimizerDB.enableFocusFace ~= true then
        frame:Hide()
        return
    end
    if not UnitExists("focus") or UnitIsDead("focus") then
        frame:Hide()
        return
    end

    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit("focus")
    if not plate then
        frame:Hide()
        return
    end

    SetPortraitTexture(portrait, "player")
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", plate, "BOTTOM", 0, 10 + (HALO_SIZE / 2))
    local plateLevel = (plate:GetFrameLevel() or 0)
    frame:SetFrameLevel(plateLevel + 1)
    frame:Show()
    UpdateCooldown()
end

Focus.DebouncedUpdate = Minimizer.Utils.Throttle(function()
    Focus:UpdateFace()
end, 0.033)

function Focus:OnCooldownTick()
    Focus.DebouncedUpdate()
end

function Focus:OnUnitChanged(unit, reason)
    if reason == "focus" or reason == "added" or reason == "removed" then
        Focus:UpdateFace()
    end
end

if Minimizer.Overlays and Minimizer.Overlays.Register then
    Minimizer.Overlays.Register("Focus", Focus)
end
