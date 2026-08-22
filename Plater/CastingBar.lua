-- ============================================================================
-- Minimizer - CastingBar.lua
-- Cast bars de nameplate: colores, objetivo del hechizo y marcador de corte.
-- ============================================================================

local _, Minimizer = ...
if not Minimizer or not Minimizer.Core then return end

local CastingBar = {}
Minimizer.CastingBar = CastingBar

local COLORS = Minimizer.Constants.CastColors
local UnitExists = UnitExists
local UnitIsUnit = UnitIsUnit
local UnitCanAttack = UnitCanAttack
local type = type

-- Tablas scratch reutilizadas para evitar allocar 2 tablas por llamada en
-- el hot path (ApplyCastColor corre por cada unidad casteando, sin throttle,
-- disparado directo desde eventos UNIT_SPELLCAST_*). Solo se leen dentro de
-- EvaluateColorRGB (no se guarda la referencia en ningun lado), asi que
-- reutilizarlas es seguro: no hay aliasing entre nameplates distintas porque
-- el resultado se copia a r,g,b inmediatamente después.
local _scratchDangerColor = {0, 0, 0}

local function IsSpellTargetingPlayer(unit)
    if UnitIsSpellTarget then
        local targeted = UnitIsSpellTarget(unit, "player")
        return targeted
    end
    local target = unit and (unit .. "target")
    return target and UnitIsUnit(target, "player")
end


function CastingBar:GetCastBar(nameplate)
    local cached = nameplate.MinimizerCastBar
    if cached and type(cached.SetStatusBarColor) == "function"
        and type(cached.GetValue) == "function" then
        return cached
    end

    if Minimizer.Widgets and Minimizer.Widgets.FindCastBar then
        local castBar = Minimizer.Widgets.FindCastBar(nameplate)
        if castBar then
            nameplate.MinimizerCastBar = castBar
            return castBar
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

    if not castBar.MinimizerColorHooked then
        if Minimizer.Utils and Minimizer.Utils.HookRepaintGuard then
            Minimizer.Utils.HookRepaintGuard(castBar, "MinimizerColorHooked", "MinimizerApplyingColor", function()
                local lastColor = castBar.MinimizerLastCastColor
                if lastColor then
                    Minimizer.Utils.GuardedCall(castBar, "MinimizerApplyingColor", function()
                        castBar:SetStatusBarColor(lastColor[1], lastColor[2], lastColor[3], lastColor[4])
                    end)
                end
            end)
        else
            castBar.MinimizerColorHooked = true
            if hooksecurefunc then
                hooksecurefunc(castBar, "SetStatusBarColor", function()
                    local bar = castBar
                    if bar.MinimizerApplyingColor then return end
                    local lastColor = bar.MinimizerLastCastColor
                    if lastColor then
                        Minimizer.Utils.GuardedCall(bar, "MinimizerApplyingColor", function()
                            bar:SetStatusBarColor(lastColor[1], lastColor[2], lastColor[3], lastColor[4])
                        end)
                    end
                end)
            end
        end
    end
    return castBar.MinimizerCastVisuals
end

function CastingBar:ApplyCastColor(castBar, unit, isCasting, isChanneling, ready, uninterruptible)
    if not castBar or type(castBar.SetStatusBarColor) ~= "function" then return end
    local r, g, b, a = 1, 1, 1, 1

    if isCasting or isChanneling then
        -- Misma leyenda para cast Y channel:
        --   interrumpible + corte listo -> verde
        --   interrumpible + corte en CD -> rosa (peligro)
        --   ininterrumpible             -> NO tocar (Blizzard ya pinta gris por defecto)
        -- 'uninterruptible' puede ser un valor secreto en Midnight/Secrets:
        -- nunca se compara con if/==, solo se pasa a EvaluateColorRGB (curve
        -- C-side de Blizzard).
        local dangerR, dangerG, dangerB = Minimizer.Utils.EvaluateColorRGB(ready, COLORS.ready, COLORS.channel)
        _scratchDangerColor[1], _scratchDangerColor[2], _scratchDangerColor[3] = dangerR, dangerG, dangerB
        r, g, b = Minimizer.Utils.EvaluateColorRGB(uninterruptible, Minimizer.Constants.HealthColors.superiorUninterruptible, _scratchDangerColor)
        a = 1
    end

    castBar.MinimizerLastCastColor = castBar.MinimizerLastCastColor or {}
    local lc = castBar.MinimizerLastCastColor
    lc[1], lc[2], lc[3], lc[4] = r, g, b, a or 1

    Minimizer.Utils.GuardedCall(castBar, "MinimizerApplyingColor", function()
        castBar:SetStatusBarColor(r, g, b, a or 1)
    end)
end

function CastingBar:UpdateNamePlate(unit, nameplate, snapshot)
    if not unit or not UnitExists(unit) then return end
    -- En PvP dejamos el castbar de Blizzard sin modificar.
    -- isPvP viene del snapshot compartido (Core.BuildSnapshot) en el pase
    -- normal; fallback a calculo directo si nos llaman sin snapshot.
    local isPvP = snapshot and snapshot.isPvP
    if isPvP == nil then isPvP = Minimizer.Utils.IsPvPUnit(unit) end
    if isPvP then return end
    -- Política del proyecto (parche 12.1): NO tocar nameplates amistosas;
    -- Blizzard las gestiona nativamente mejor que nosotros. Filtrar también
    -- unidades amistosas (no solo PvP) para evitar tocar castbars nativas.
    local isFriendly = snapshot and snapshot.isFriendly
    if isFriendly == nil then
        isFriendly = (Minimizer.Utils and Minimizer.Utils.IsFriendlyUnit and Minimizer.Utils.IsFriendlyUnit(unit))
            or (UnitCanAttack and not UnitCanAttack("player", unit))
    end
    if isFriendly then return end
    local castBar = self:GetCastBar(nameplate)
    if not castBar or type(castBar.SetStatusBarColor) ~= "function" then return end

    local visuals = self:EnsureVisuals(castBar)
    castBar.MinimizerCastUnit = unit

    -- Reusar el estado de cast ya leído por Core.BuildSnapshot en este mismo
    -- pase, en vez de volver a llamar a Cast.GetState (que repetiría
    -- UnitCastingInfo/UnitChannelInfo para la misma unidad en el mismo
    -- frame). snapshot.rawUninterruptible es el mismo valor -- potencialmente
    -- secreto -- que antes devolvía Cast.GetState como tercer retorno; se
    -- sigue pasando crudo a ApplyCastColor/EvaluateColorRGB, sin comparar.
    -- Fallback a Cast.GetState solo si nos llaman sin snapshot (hooks de
    -- repintado nativo fuera del pase normal, igual que isPvP arriba).
    local isCasting, isChanneling, uninterruptible
    if snapshot then
        isCasting = snapshot.isCasting
        isChanneling = snapshot.isChanneling
        uninterruptible = snapshot.rawUninterruptible
    else
        isCasting, _, uninterruptible, isChanneling = Minimizer.Cast.GetState(unit)
    end
    local ready = Minimizer.Interrupt.IsReady()

    self:ApplyCastColor(castBar, unit, isCasting, isChanneling, ready, uninterruptible)

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
    castBar.MinimizerLastCastColor = nil
end

Minimizer.Core.RegisterModule("CastingBar", CastingBar)
