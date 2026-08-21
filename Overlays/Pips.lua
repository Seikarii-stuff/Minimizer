-- ============================================================================
-- Minimizer - Pips.lua
-- Módulo centralizado para la creación, configuración y actualización de pips
-- en widgets especiales (Target y Focus).
-- ============================================================================
local _, Minimizer = ...
if not Minimizer then return end

local Pips = {}
Minimizer.Pips = Pips

-- Definición centralizada y extensible de slots para Pips.
-- Target y Focus consumen exclusivamente esta lista para determinar
-- número de pips, identificador, nombre, esquina y propiedades visuales.
Pips.SLOTS = {
    { id = 1, name = "Pip 1", corner = "TOPLEFT" },
    { id = 2, name = "Pip 2", corner = "TOPRIGHT" },
}

Pips.PIP_SIZE = 10

-- Resuelve el spellID para una unidad y slot determinado
function Pips.GetSpellID(unitKey, slotIndex)
    local override = nil
    if MinimizerCharDB then
        override = MinimizerCharDB[unitKey .. "Pip" .. slotIndex]
    end
    local spellList = Minimizer.Data and Minimizer.Data.PIPS_SPELLS
    if not spellList or not Minimizer.Widgets or not Minimizer.Widgets.GetCDSpellID then
        return nil
    end
    return Minimizer.Widgets.GetCDSpellID(spellList, override, slotIndex)
end

-- Crea un conjunto de pips anclados a parentFrame basado en Pips.SLOTS
function Pips.CreatePips(parentFrame, prefixName, radius, xOff, yOff)
    if not parentFrame then return {} end

    local pips = {}
    local colors = (Minimizer.Constants and Minimizer.Constants.PipColors and Minimizer.Constants.PipColors.default)
        or { on = {0.20, 0.55, 1.00}, off = {0.05, 0.10, 0.25} }

    local parentSize = math.min(parentFrame:GetWidth() or 40, parentFrame:GetHeight() or 40)
    radius = radius or (parentSize * 0.45)
    xOff = xOff or 0
    yOff = yOff or 0

    for index, slot in ipairs(Pips.SLOTS) do
        local slotId = slot.id or index
        local corner = slot.corner or "TOPRIGHT"
        local signX = (corner:find("RIGHT") and 1) or -1
        local signY = (corner:find("TOP") and 1) or -1

        local pipFrameName = prefixName .. slotId
        local pip = CreateFrame("Frame", pipFrameName, parentFrame)
        pip:SetSize(Pips.PIP_SIZE, Pips.PIP_SIZE)
        pip:SetFrameStrata("HIGH")
        pip:SetFrameLevel((parentFrame:GetFrameLevel() or 0) + 5)

        pip:ClearAllPoints()
        pip:SetPoint("CENTER", parentFrame, "CENTER", signX * radius + xOff, signY * radius + yOff)
        pip.MinimizerPipRadius = radius
        pip.MinimizerPipAnchorCorner = corner
        pip.MinimizerPipSlotId = slotId
        pip:Hide()

        -- Circular background
        local bg = pip:CreateTexture(nil, "ARTWORK")
        bg:SetAllPoints()
        bg:SetColorTexture(colors.on[1], colors.on[2], colors.on[3], 1)

        local mask = pip:CreateMaskTexture()
        mask:SetAllPoints(bg)
        mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        bg:AddMaskTexture(mask)

        -- Cooldown frame
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

-- Actualiza todos los pips de un overlay para la unidad dada
function Pips.UpdatePips(pips, unitKey)
    if not pips or type(pips) ~= "table" then return end

    for index, pip in ipairs(pips) do
        local slot = Pips.SLOTS[index]
        local slotId = (slot and slot.id) or index
        local spellID = Pips.GetSpellID(unitKey, slotId)

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

-- Oculta todos los pips de la lista
function Pips.HidePips(pips)
    if not pips or type(pips) ~= "table" then return end
    for _, pip in ipairs(pips) do
        pip:Hide()
    end
end

-- Ajusta el frame level de todos los pips
function Pips.SetFrameLevel(pips, level)
    if not pips or type(pips) ~= "table" then return end
    for _, pip in ipairs(pips) do
        pip:SetFrameLevel(level)
    end
end
