-- ============================================================================
-- Minimizer - Widgets.lua
-- Búsqueda de widgets en nameplates (ej. castbars anónimas)
-- ============================================================================
local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Widgets = Minimizer.Widgets or {}

local function FindCastBarInGrandchildren(healthBar, ...)
    for i = 1, select("#", ...) do
        local grandchild = select(i, ...)
        if type(grandchild) == "table"
            and grandchild ~= healthBar
            and type(grandchild.SetStatusBarColor) == "function"
            and type(grandchild.GetValue) == "function" then
            return grandchild
        end
    end
    return nil
end

local function FindCastBarInChildren(healthBar, ...)
    for i = 1, select("#", ...) do
        local child = select(i, ...)
        if type(child) == "table" and type(child.GetChildren) == "function" then
            local grandchild = FindCastBarInGrandchildren(healthBar, child:GetChildren())
            if grandchild then return grandchild end
        end
    end
    return nil
end

function Minimizer.Widgets.FindCastBar(nameplate)
    local unitFrame = nameplate and (nameplate.UnitFrame or nameplate)
    if not unitFrame or type(unitFrame.GetChildren) ~= "function" then return nil end
    local healthBar = Minimizer.Utils and Minimizer.Utils.GetHealthBar and Minimizer.Utils.GetHealthBar(nameplate)
    return FindCastBarInChildren(healthBar, unitFrame:GetChildren())
end

local cdSpellCache = setmetatable({}, { __mode = "k" }) -- weak keys, una entrada por dbTable+override

local function GetCooldownCacheKey(dbTable, override)
    if override == nil then
        return dbTable
    end
    return { dbTable = dbTable, override = override }
end

function Minimizer.Widgets.GetCDSpellID(dbTable, override)
    if not dbTable then return nil end

    local _, classToken = UnitClass("player")
    local spellList = classToken and dbTable[classToken]
    local cacheKey = GetCooldownCacheKey(dbTable, override)
    local cached = cdSpellCache[cacheKey]
    if cached ~= nil then
        if cached == false then return nil end
        return cached
    end

    if override ~= nil then
        local overrideAllowed = false
        if type(spellList) == "table" then
            for _, entry in ipairs(spellList) do
                local spellID = (type(entry) == "number") and entry or (type(entry) == "table" and entry.id)
                if spellID == override then
                    overrideAllowed = true
                    break
                end
            end
        end
        if overrideAllowed and Minimizer.Utils and Minimizer.Utils.IsSpellKnownByPlayer and Minimizer.Utils.IsSpellKnownByPlayer(override) then
            cdSpellCache[cacheKey] = override
            return override
        end
    end

    local result = Minimizer.Utils.FindKnownSpell(spellList)
    cdSpellCache[cacheKey] = result or false
    return result
end

-- Llamar en PLAYER_TALENT_UPDATE / PLAYER_SPECIALIZATION_CHANGED para que si
-- el jugador cambia de spec y eso afecta que spell tiene disponible, se
-- recalculen los CDs mostrados.
function Minimizer.Widgets.InvalidateCDSpellCache()
    cdSpellCache = setmetatable({}, { __mode = "k" })
end

function Minimizer.Widgets.ConfigureCooldownFrame(cooldown, opts)
    if not cooldown then return end
    opts = opts or {}

    if cooldown.SetDrawEdge then
        cooldown:SetDrawEdge(opts.drawEdge ~= nil and opts.drawEdge or false)
    end
    if cooldown.SetUseCircularEdge then
        cooldown:SetUseCircularEdge(opts.useCircularEdge ~= nil and opts.useCircularEdge or false)
    end
    if cooldown.SetDrawSwipe then
        cooldown:SetDrawSwipe(opts.drawSwipe ~= nil and opts.drawSwipe or true)
    end
    if cooldown.SetDrawBling then
        cooldown:SetDrawBling(opts.drawBling ~= nil and opts.drawBling or false)
    end
    if cooldown.SetReverse then
        cooldown:SetReverse(opts.reverse ~= nil and opts.reverse or false)
    end
    if cooldown.SetHideCountdownNumbers then
        cooldown:SetHideCountdownNumbers(opts.hideCountdownNumbers ~= nil and opts.hideCountdownNumbers or true)
    end
    if cooldown.SetSwipeTexture and opts.swipeTexture then
        cooldown:SetSwipeTexture(opts.swipeTexture)
    end
    if cooldown.SetSwipeColor and opts.swipeColor then
        cooldown:SetSwipeColor(opts.swipeColor[1], opts.swipeColor[2], opts.swipeColor[3], opts.swipeColor[4] or 1)
    end
end

function Minimizer.Widgets.MakeCooldownCircular(cooldown)
    if not cooldown then return end
    Minimizer.Widgets.ConfigureCooldownFrame(cooldown, {
        drawEdge = false,
        useCircularEdge = true,
        drawSwipe = true,
        drawBling = false,
        reverse = false,
        hideCountdownNumbers = true,
        swipeTexture = "Interface\\Masks\\CircleMaskScalable",
    })
end

function Minimizer.Widgets.ApplyCooldownDuration(cooldown, spellID)
    if not cooldown or not spellID then return false end

    if C_Spell and C_Spell.GetSpellCooldownDuration then
        local duration = C_Spell.GetSpellCooldownDuration(spellID)
        if duration and cooldown.SetCooldownFromDurationObject then
            cooldown:SetCooldownFromDurationObject(duration)
            return true
        end
    elseif C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if info then
            if cooldown.SetCooldownFromExpression then
                cooldown:SetCooldownFromExpression(spellID)
            elseif cooldown.SetCooldownTable then
                cooldown:SetCooldownTable(info)
            end
            return true
        end
    elseif GetSpellCooldown then
        local start, duration = GetSpellCooldown(spellID)
        if start and duration then
            cooldown:SetCooldown(start, duration)
            return true
        end
    end

    return false
end

-- CreateHalo: un anillo (halo) con textura que tiene el centro transparente.
-- name: nombre del frame.
-- parentFrame: frame donde se centrará posteriormente (puede ser nil; se
--   reposiciona desde el código que lo use, p.ej. Target:SetPoint(...)).
-- size: tamaño del halo (p. ej. 46).
function Minimizer.Widgets.CreateHalo(name, parentFrame, size)
    local frame = CreateFrame("Frame", name, parentFrame or UIParent)
    frame:SetSize(size, size)
    frame:SetFrameStrata("HIGH")
    frame:Hide()

    local tex = frame:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\AddOns\\Minimizer\\assets\\halo_ring")
    tex:SetBlendMode("BLEND")
    frame.MinimizerHaloTexture = tex

    local cooldown = CreateFrame("Cooldown", name .. "Cooldown", frame, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    Minimizer.Widgets.ConfigureCooldownFrame(cooldown, {
        drawEdge = false,
        useCircularEdge = true,
        drawSwipe = true,
        drawBling = false,
        reverse = false,
        hideCountdownNumbers = true,
        swipeTexture = "Interface\\AddOns\\Minimizer\\assets\\halo_ring",
        swipeColor = { 0.00, 0.00, 0.00, 0.75 },
    })
    frame.MinimizerHaloCooldown = cooldown

    return frame
end

function Minimizer.Widgets.UpdateHalo(frame, spellID)
    if not frame then return false end
    if not spellID then
        frame:Hide()
        return false
    end

    local cooldown = frame.MinimizerHaloCooldown
    if not cooldown then
        frame:Hide()
        return false
    end

    Minimizer.Widgets.ApplyCooldownDuration(cooldown, spellID)
    frame:Show()
    return true
end

-- ============================================================================
-- "Pips": indicadores circulares pequeños de cooldown (estilo "ultimate" de
-- LoL). Se anclan en la esquina de otro frame (retrato del focus, insignia
-- del target, etc). Sin icono de spell, sin números de cuenta atrás -- solo
-- un círculo de color que queda cubierto por un velo oscuro mientras el
-- spell está en cooldown, y se ve completamente brillante cuando está listo.
-- El propio Cooldown frame de Blizzard anima el barrido; el addon no
-- recalcula nada por frame, solo llama a UpdatePip cuando el spellID puede
-- haber cambiado (una vez por pase, igual que el resto de widgets).
--
-- Para añadir un pip de un color nuevo en el futuro:
--   1. Agregar la entrada on/off en Minimizer.Constants.PipColors (Constants.lua).
--   2. Llamar a Minimizer.Widgets.CreatePip(nombre, frame, "tuColorKind", esquina)
--      una vez al cargar el módulo.
--   3. Llamar a Minimizer.Widgets.UpdatePip(pip, spellID) en cada pase de update.
-- No hace falta tocar nada más.
-- ============================================================================

Minimizer.Widgets.PIP_SIZE = 6

-- name: nombre único del frame (string).
-- parentFrame: frame de Blizzard al que se ancla y del que hereda visibilidad.
-- colorKind: clave en Minimizer.Constants.PipColors (ej. "cc", "defensive").
-- anchorCorner: esquina de parentFrame donde centrar el pip (ej. "TOPRIGHT",
--   "TOPLEFT", "BOTTOMRIGHT", "BOTTOMLEFT"). Por defecto "TOPRIGHT".
-- xOff, yOff: offset extra opcional (por si en el futuro hace falta apilar
--   más de un pip en la misma esquina). Por defecto 0, 0.
function Minimizer.Widgets.CreatePip(name, parentFrame, colorKind, anchorCorner, xOff, yOff)
    local colors = Minimizer.Constants.PipColors
        and Minimizer.Constants.PipColors[colorKind]

    if not parentFrame or not colors then
        return nil
    end

    anchorCorner = anchorCorner or "TOPRIGHT"
    xOff = xOff or 0
    yOff = yOff or 0

    local pip = CreateFrame("Frame", name, parentFrame)
    pip:SetSize(Minimizer.Widgets.PIP_SIZE, Minimizer.Widgets.PIP_SIZE)
    pip:SetFrameStrata("HIGH")
    pip:SetFrameLevel((parentFrame:GetFrameLevel() or 0) + 5)

    pip:ClearAllPoints()
    pip:SetPoint("CENTER", parentFrame, anchorCorner, xOff, yOff)
    pip:Hide()

    -- ============================================================
    -- CIRCULAR BACKGROUND
    --
    -- No usar Texture:SetMask().
    -- CreateMaskTexture + AddMaskTexture es la API de máscara
    -- soportada para este tipo de geometría.
    -- ============================================================

    local bg = pip:CreateTexture(nil, "ARTWORK")
    bg:SetAllPoints()
    bg:SetColorTexture(
        colors.on[1],
        colors.on[2],
        colors.on[3],
        1
    )

    local mask = pip:CreateMaskTexture()
    mask:SetAllPoints(bg)
    mask:SetTexture(
        "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
        "CLAMPTOBLACKADDITIVE",
        "CLAMPTOBLACKADDITIVE"
    )

    bg:AddMaskTexture(mask)

    -- ============================================================
    -- COOLDOWN
    -- ============================================================

    local cooldown = CreateFrame(
        "Cooldown",
        name .. "Cooldown",
        pip,
        "CooldownFrameTemplate"
    )

    cooldown:SetAllPoints()
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

    pip.MinimizerPipBG = bg
    pip.MinimizerPipMask = mask
    pip.MinimizerPipCooldown = cooldown
    pip.MinimizerPipColorKind = colorKind

    return pip
end

-- Actualiza (o esconde) un pip creado con CreatePip. Igual que UpdateCDWidget
-- pero sin icono ni cálculo de shade -- el barrido lo anima Blizzard solo.
function Minimizer.Widgets.UpdatePip(pip, spellID)
    if not pip then
        return false
    end

    if not spellID then
        pip:Hide()
        return false
    end

    local cooldown = pip.MinimizerPipCooldown

    if not cooldown then
        pip:Hide()
        return false
    end

    Minimizer.Widgets.ApplyCooldownDuration(cooldown, spellID)

    pip:Show()

    return true
end
