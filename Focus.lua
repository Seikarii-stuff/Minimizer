local _, Minimizer = ...
if not Minimizer then return end
-- Config.Initialize() ya fue invocada por Bootstrap.lua tras ADDON_LOADED.

local Focus = {}
Minimizer.Focus = Focus
local frame = CreateFrame("Frame", "MinimizerFocusPortrait", UIParent)
frame:SetSize(40, 40)
frame:SetFrameStrata("HIGH")
frame:Hide()
local portrait = frame:CreateTexture(nil, "ARTWORK")
portrait:SetAllPoints()
local cooldown = CreateFrame("Cooldown", "MinimizerFocusCooldown", frame, "CooldownFrameTemplate")
cooldown:SetAllPoints()
Minimizer.Widgets.StyleCooldown(cooldown)

-- El retrato es redondo (SetPortraitTexture) pero el swipe por defecto
-- de StyleCooldown ("UI-HUD-CoolDown-Swipe") es cuadrado y llega hasta
-- las esquinas del frame de 40x40 -- justo donde, cuando focus == target,
-- cae el anillo del Target por debajo. Lo confinamos a un circulo.
if cooldown.SetSwipeTexture then
    cooldown:SetSwipeTexture("Interface\\Masks\\CircleMaskScalable")
end
if cooldown.SetUseCircularEdge then
    cooldown:SetUseCircularEdge(true)
end

local ccPip
if Minimizer.Widgets and Minimizer.Widgets.CreatePip then
    ccPip = Minimizer.Widgets.CreatePip("MinimizerFocusCCPip", frame, "cc", "TOPRIGHT")
end

local function UpdateCooldown()
    local interruptSpellID = Minimizer.Interrupt and Minimizer.Interrupt.GetSpellID
        and Minimizer.Interrupt.GetSpellID()
    if not interruptSpellID or not C_Spell then return end
    local duration = C_Spell.GetSpellCooldownDuration
        and C_Spell.GetSpellCooldownDuration(interruptSpellID)
    if duration and cooldown.SetCooldownFromDurationObject then
        cooldown:SetCooldownFromDurationObject(duration)
        -- SetAlphaFromBoolean no se usa aquí: el cooldown frame gestiona su propio
        -- visual de cuenta atrás. El shade del retrato lo maneja EvaluateColorValueFromBoolean.
    elseif C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(interruptSpellID)
        if info and cooldown.SetCooldownFromExpression then
            cooldown:SetCooldownFromExpression(interruptSpellID)
        elseif info and cooldown.SetCooldownTable then
            cooldown:SetCooldownTable(info)
        end
    end
    -- Shade del retrato: 1.0 (brillante) cuando listo, 0.38 (gris) cuando en CD.
    -- EvaluateColorValueFromBoolean(state, valueIfTrue, valueIfFalse):
    --   ready=true  → shade 1.0 (corte disponible, retrato brillante)
    --   ready=false → shade 0.38 (corte en CD, retrato gris)
    if Minimizer.Interrupt and Minimizer.Interrupt.IsReady
        and C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean then
        local ready = Minimizer.Interrupt.IsReady()
        local shade = C_CurveUtil.EvaluateColorValueFromBoolean(ready, 1.0, 0.38)
        portrait:SetVertexColor(shade, shade, shade, 1)
    end
end


function Focus:UpdateFace()
    if MinimizerDB.focusIndicator ~= "face" then 
        frame:Hide()
        if ccPip then ccPip:Hide() end
        return 
    end
    if not UnitExists("focus") or UnitIsDead("focus") then 
        frame:Hide()
        if ccPip then ccPip:Hide() end
        return 
    end
    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit
        and C_NamePlate.GetNamePlateForUnit("focus")
    if not plate then 
        frame:Hide()
        if ccPip then ccPip:Hide() end
        return 
    end
    SetPortraitTexture(portrait, "player")
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOM", plate, "TOP", 0, 10)
    frame:Show()
    UpdateCooldown()

    if ccPip and Minimizer.Widgets and Minimizer.Widgets.GetCDSpellID then
        local ccID = Minimizer.Widgets.GetCDSpellID(Minimizer.Data.MASS_CC_SPELLS)
        Minimizer.Widgets.UpdatePip(ccPip, ccID)
    end
end

function Focus:SetMode(mode)
    if mode ~= "arrows" and mode ~= "face" then return end
    MinimizerDB.focusIndicator = mode
    if mode ~= "face" then 
        frame:Hide() 
        if ccPip then ccPip:Hide() end
    end
    if Minimizer.Core then Minimizer.Core.ApplyToAll() end
end

-- Throttle a 30 FPS (0.033s): visuales de focus no necesitan repintarse más rápido.
Focus.DebouncedUpdate = Minimizer.Utils.Throttle(function()
    Focus:UpdateFace()
end, 0.03)

