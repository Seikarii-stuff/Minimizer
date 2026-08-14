-- ============================================================================
-- Minimizer - CastingBar.lua
-- Cast bars de nameplate: colores, objetivo del hechizo y marcador de corte.
-- ============================================================================

local _, Minimizer = ...
if not Minimizer or not Minimizer.Core then return end

local CastingBar = {}
Minimizer.CastingBar = CastingBar

local COLORS = Minimizer.Constants.CastColors

local function IsSpellTargetingPlayer(unit)
    if UnitIsSpellTarget then
        local targeted = UnitIsSpellTarget(unit, "player")
        return targeted
    end
    local target = unit and (unit .. "target")
    return target and UnitIsUnit(target, "player")
end


-- El proyecto deja el proveedor de cooldown desacoplado para que pueda
-- sustituirse por el sistema de interrupciones de cada clase/spec.
-- Duck-typing: en este cliente los widgets de nameplate son anónimos
-- (GetName() vacío) y no cuelgan de campos nombrados como .castBar/.CastBar.
-- Se localiza recorriendo los nietos de UnitFrame y descartando la healthbar
-- (confirmado por diagnóstico: la barra de cast es la única, aparte de la
-- healthbar, con SetStatusBarColor+GetValue, y su IsShown() solo es true
-- mientras la unidad está casteando).
function CastingBar:GetCastBar(nameplate)
    local unitFrame = nameplate and (nameplate.UnitFrame or nameplate)
    if not unitFrame or type(unitFrame.GetChildren) ~= "function" then return nil end

    local cached = nameplate.MinimizerCastBar
    if cached and type(cached.SetStatusBarColor) == "function"
        and type(cached.GetValue) == "function" then
        return cached
    end

    local healthBar = unitFrame.healthBar
    local children = { unitFrame:GetChildren() }
    for _, child in ipairs(children) do
        if type(child) == "table" and type(child.GetChildren) == "function" then
            local grandchildren = { child:GetChildren() }
            for _, grandchild in ipairs(grandchildren) do
                if type(grandchild) == "table"
                    and grandchild ~= healthBar
                    and type(grandchild.SetStatusBarColor) == "function"
                    and type(grandchild.GetValue) == "function" then
                    nameplate.MinimizerCastBar = grandchild
                    return grandchild
                end
            end
        end
    end
    return nil
end

function CastingBar:EnsureVisuals(castBar)
    if castBar.MinimizerCastVisuals then return castBar.MinimizerCastVisuals end

    local targetContainer = CreateFrame("Frame", nil, castBar)
    targetContainer:SetAllPoints(castBar)
    targetContainer:SetFrameLevel((castBar:GetFrameLevel() or 0) + 3)
    local border = targetContainer:CreateTexture(nil, "OVERLAY")
    border:SetPoint("TOPLEFT", targetContainer, "TOPLEFT", -3, 3)
    border:SetPoint("BOTTOMRIGHT", targetContainer, "BOTTOMRIGHT", 3, -3)
    border:SetColorTexture(1, 0.05, 0.05, 0.9)
    border:SetBlendMode("ADD")
    targetContainer:Hide()

    local pulse = border:CreateAnimationGroup()
    pulse:SetLooping("REPEAT")
    local fadeOut = pulse:CreateAnimation("Alpha")
    fadeOut:SetOrder(1)
    fadeOut:SetDuration(0.35)
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0.25)
    local fadeIn = pulse:CreateAnimation("Alpha")
    fadeIn:SetOrder(2)
    fadeIn:SetDuration(0.35)
    fadeIn:SetFromAlpha(0.25)
    fadeIn:SetToAlpha(1)

    castBar.MinimizerCastVisuals = {
        targetContainer = targetContainer,
        targetBorder = border,
        targetPulse = pulse,
    }

    -- Blizzard repinta la barra después de los eventos. Reaplicar aquí
    -- garantiza que el color se evalúa después del color nativo.
    if hooksecurefunc and not castBar.MinimizerColorHooked then
        castBar.MinimizerColorHooked = true
        hooksecurefunc(castBar, "SetStatusBarColor", function()
            local bar = castBar
            if bar.MinimizerApplyingColor then return end
            local unit = bar.MinimizerCastUnit
            if unit and UnitExists(unit) then
                local isCasting, _, uninterruptible = Minimizer.Cast.GetState(unit)
                local isChanneling = UnitChannelInfo(unit) ~= nil
                CastingBar:ApplyGreenColor(bar, unit, isCasting, isChanneling, Minimizer.Interrupt.IsReady(), uninterruptible)
            end
        end)
    end
    return castBar.MinimizerCastVisuals
end

function CastingBar:ApplyGreenColor(castBar, unit, isCasting, isChanneling, ready, uninterruptible)
    if not castBar or type(castBar.SetStatusBarColor) ~= "function" then return end
    local r, g, b, a = 1, 1, 1, 1
    if castBar.GetStatusBarColor then
        r, g, b, a = castBar:GetStatusBarColor()
    end
    if isChanneling and C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean then
        -- Channel interrumpible con corte disponible: verde; con corte abajo
        -- o no interrumpible: rosa claro.
        local channelR = C_CurveUtil.EvaluateColorValueFromBoolean(ready, COLORS.ready[1], COLORS.channel[1])
        local channelG = C_CurveUtil.EvaluateColorValueFromBoolean(ready, COLORS.ready[2], COLORS.channel[2])
        local channelB = C_CurveUtil.EvaluateColorValueFromBoolean(ready, COLORS.ready[3], COLORS.channel[3])
        r = C_CurveUtil.EvaluateColorValueFromBoolean(uninterruptible, COLORS.channel[1], channelR)
        g = C_CurveUtil.EvaluateColorValueFromBoolean(uninterruptible, COLORS.channel[2], channelG)
        b = C_CurveUtil.EvaluateColorValueFromBoolean(uninterruptible, COLORS.channel[3], channelB)
        a = 1
    elseif isChanneling then
        r, g, b = COLORS.channel[1], COLORS.channel[2], COLORS.channel[3]
        a = 1
    elseif isCasting and C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean then
        -- La firma selecciona el primer valor cuando state=true (patrón de
        -- Platynator: EvaluateColorValueFromBoolean(notInterruptible, 0, 1)).
        local greenR = C_CurveUtil.EvaluateColorValueFromBoolean(ready, COLORS.ready[1], r)
        local greenG = C_CurveUtil.EvaluateColorValueFromBoolean(ready, COLORS.ready[2], g)
        local greenB = C_CurveUtil.EvaluateColorValueFromBoolean(ready, COLORS.ready[3], b)
        r = C_CurveUtil.EvaluateColorValueFromBoolean(uninterruptible, r, greenR)
        g = C_CurveUtil.EvaluateColorValueFromBoolean(uninterruptible, g, greenG)
        b = C_CurveUtil.EvaluateColorValueFromBoolean(uninterruptible, b, greenB)
    end
    castBar.MinimizerApplyingColor = true
    castBar:SetStatusBarColor(r, g, b, a or 1)
    castBar.MinimizerApplyingColor = nil
end

function CastingBar:UpdateNamePlate(unit, nameplate)
    if not unit or not UnitExists(unit) then return end
    local castBar = self:GetCastBar(nameplate)
    if not castBar or type(castBar.SetStatusBarColor) ~= "function" then return end

    local visuals = self:EnsureVisuals(castBar)
    castBar.MinimizerCastUnit = unit
    local isCasting, _, uninterruptible = Minimizer.Cast.GetState(unit)
    local isChanneling = UnitChannelInfo(unit) ~= nil
    local ready = Minimizer.Interrupt.IsReady()

    self:ApplyGreenColor(castBar, unit, isCasting, isChanneling, ready, uninterruptible)

    local targeted = IsSpellTargetingPlayer(unit)
    if isCasting or isChanneling then
        visuals.targetContainer:Show()
        if visuals.targetContainer.SetAlphaFromBoolean then
            visuals.targetContainer:SetAlphaFromBoolean(targeted)
        end
        visuals.targetPulse:Play()
    else
        visuals.targetPulse:Stop()
        visuals.targetContainer:Hide()
    end
end

function CastingBar:OnNamePlateRemoved(_, nameplate)
    local castBar = nameplate and nameplate.MinimizerCastBar
    if not castBar then return end
    local visuals = castBar.MinimizerCastVisuals
    if visuals then
        visuals.targetPulse:Stop()
        visuals.targetContainer:Hide()
    end
    castBar.MinimizerCastUnit = nil
end

Minimizer.Core.RegisterModule("CastingBar", CastingBar)
