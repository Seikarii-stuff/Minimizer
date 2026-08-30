-- ============================================================================
-- Minimizer - Pips.lua
-- Componentes radiales propiedad de Player Wheel.
-- ============================================================================
local _, Minimizer = ...
if not Minimizer then return end

local Pips = {}
Minimizer.Pips = Pips

Pips.SLOTS = {
    { id = 1, name = "Pip 1", angle = 90,  color = { on = {0.10, 1.00, 0.10}, off = {0.03, 0.20, 0.03} } },
    { id = 2, name = "Pip 2", angle = 30,  color = { on = {0.20, 0.55, 1.00}, off = {0.05, 0.10, 0.25} } },
    { id = 3, name = "Pip 3", angle = -30, color = { on = {1.00, 0.85, 0.10}, off = {0.25, 0.18, 0.03} } },
    { id = 4, name = "Pip 4", angle = -90, color = { on = {1.00, 0.35, 0.10}, off = {0.25, 0.06, 0.03} } },
    { id = 5, name = "Pip 5", angle = -150,color = { on = {0.75, 0.20, 1.00}, off = {0.18, 0.03, 0.25} } },
    { id = 6, name = "Pip 6", angle = 150, color = { on = {0.10, 1.00, 0.85}, off = {0.03, 0.20, 0.18} } },
}

Pips.PIP_SIZE = 15

function Pips.GetSpellID(slotIndex)
    local override = nil
    if MinimizerCharDB then
        override = MinimizerCharDB["pip" .. slotIndex]
    end
    local spellList = Minimizer.Data and Minimizer.Data.PIPS_SPELLS
    if not spellList or not Minimizer.Widgets or not Minimizer.Widgets.GetCDSpellID then
        return nil
    end
    return Minimizer.Widgets.GetCDSpellID(spellList, override, slotIndex)
end

local function PositionPip(pip, radius)
    local angle = tonumber(pip.MinimizerPipAngle) or 0
    local radians = math.rad(angle)
    local xOff = tonumber(pip.MinimizerPipXOffset) or 0
    local yOff = tonumber(pip.MinimizerPipYOffset) or 0
    local x = math.cos(radians) * radius + xOff
    local y = math.sin(radians) * radius + yOff
    pip:ClearAllPoints()
    pip:SetPoint("CENTER", pip:GetParent(), "CENTER", x, y)
    pip.MinimizerPipRadius = radius
end

function Pips.CreatePips(parentFrame, prefixName, radius, xOff, yOff)
    if not parentFrame then return {} end

    local pips = {}
    radius = radius or ((math.min(parentFrame:GetWidth() or 40, parentFrame:GetHeight() or 40)) * 0.45)
    xOff = xOff or 0
    yOff = yOff or 0

    for index, slot in ipairs(Pips.SLOTS) do
        local slotId = slot.id or index
        local angle = tonumber(slot.angle) or 0
        local colors = slot.color
            or (Minimizer.Constants and Minimizer.Constants.PipColors and Minimizer.Constants.PipColors[slotId])
            or (Minimizer.Constants and Minimizer.Constants.PipColors and Minimizer.Constants.PipColors.default)
            or { on = {0.10, 1.00, 0.10}, off = {0.03, 0.20, 0.03} }

        local pipFrameName = prefixName .. slotId
        local pip = CreateFrame("Frame", pipFrameName, parentFrame)
        pip:SetSize(Pips.PIP_SIZE, Pips.PIP_SIZE)
        pip:SetFrameStrata("HIGH")
        pip:SetFrameLevel((parentFrame:GetFrameLevel() or 0) + 5)
        pip.MinimizerPipRadius = radius
        pip.MinimizerPipAngle = angle
        pip.MinimizerPipSlotId = slotId
        pip.MinimizerPipXOffset = xOff
        pip.MinimizerPipYOffset = yOff
        PositionPip(pip, radius)
        pip:Hide()

        local bg = pip:CreateTexture(nil, "ARTWORK")
        bg:SetAllPoints()
        bg:SetColorTexture(colors.on[1], colors.on[2], colors.on[3], 1)

        local mask = pip:CreateMaskTexture()
        mask:SetAllPoints(bg)
        mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        bg:AddMaskTexture(mask)

        local cooldown = CreateFrame("Cooldown", pipFrameName .. "Cooldown", pip, "CooldownFrameTemplate")
        cooldown:SetAllPoints()
        if Minimizer.Widgets and Minimizer.Widgets.ConfigureCooldownFrame then
            Minimizer.Widgets.ConfigureCooldownFrame(cooldown, {
                drawEdge = false,
                useCircularEdge = true,
                drawSwipe = true,
                drawBling = false,
                reverse = false,
                hideCountdownNumbers = true,
                swipeTexture = "Interface\\Masks\\CircleMaskScalable",
                swipeColor = { colors.off[1], colors.off[2], colors.off[3], 0.9 },
            })
        end

        pip.MinimizerPipBG = bg
        pip.MinimizerPipMask = mask
        pip.MinimizerPipCooldown = cooldown
        table.insert(pips, pip)
    end

    return pips
end

function Pips.SetRadius(pips, radius)
    if not pips or type(pips) ~= "table" then return end
    radius = tonumber(radius)
    if not radius then return end
    for _, pip in ipairs(pips) do
        PositionPip(pip, radius)
    end
end

function Pips.UpdatePips(pips)
    if not pips or type(pips) ~= "table" then return end
    for index, pip in ipairs(pips) do
        local slot = Pips.SLOTS[index]
        local slotId = (slot and slot.id) or index
        local spellID = Pips.GetSpellID(slotId)
        if not spellID or not pip.MinimizerPipCooldown then
            pip:Hide()
        else
            if Minimizer.Widgets and Minimizer.Widgets.ApplyCooldownDuration then
                Minimizer.Widgets.ApplyCooldownDuration(pip.MinimizerPipCooldown, spellID)
            end
            pip:Show()
        end
    end
end

function Pips.HidePips(pips)
    if not pips or type(pips) ~= "table" then return end
    for _, pip in ipairs(pips) do pip:Hide() end
end

function Pips.SetFrameLevel(pips, level)
    if not pips or type(pips) ~= "table" then return end
    for _, pip in ipairs(pips) do pip:SetFrameLevel(level) end
end
