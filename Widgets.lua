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

local cdSpellCache = setmetatable({}, { __mode = "k" }) -- weak keys, una entrada por dbTable

function Minimizer.Widgets.GetCDSpellID(dbTable)
    if not dbTable then return nil end
    local cached = cdSpellCache[dbTable]
    if cached ~= nil then
        if cached == false then return nil end
        return cached
    end
    local _, classToken = UnitClass("player")
    local spellList = classToken and dbTable[classToken]
    local result = Minimizer.Utils.FindKnownSpell(spellList)
    cdSpellCache[dbTable] = result or false -- false = "ya se calculo, no hay resultado"
    return result
end

-- Llamar en PLAYER_TALENT_UPDATE / PLAYER_SPECIALIZATION_CHANGED para que si
-- el jugador cambia de spec y eso afecta que spell tiene disponible, se
-- recalculen los CDs mostrados.
function Minimizer.Widgets.InvalidateCDSpellCache()
    cdSpellCache = setmetatable({}, { __mode = "k" })
end

function Minimizer.Widgets.StyleCooldown(cooldown)
    cooldown:SetDrawEdge(true)
    if cooldown.SetDrawSwipe then cooldown:SetDrawSwipe(true) end
    if cooldown.SetDrawBling then cooldown:SetDrawBling(false) end
    if cooldown.SetReverse then cooldown:SetReverse(true) end
    cooldown:SetSwipeTexture("Interface\\HUD\\UI-HUD-CoolDown-Swipe")
end

function Minimizer.Widgets.CreateCDWidget(name, size)
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetSize(size, size)
    frame:SetFrameStrata("HIGH")
    frame:Hide()
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    local cooldown = CreateFrame("Cooldown", name.."Cooldown", frame, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    Minimizer.Widgets.StyleCooldown(cooldown)
    return frame, icon, cooldown
end

function Minimizer.Widgets.UpdateCDWidget(frame, icon, cooldown, spellID)
    if not spellID then frame:Hide(); return false end

    local tex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
    if not tex and GetSpellTexture then tex = GetSpellTexture(spellID) end
    if tex then icon:SetTexture(tex) end

    local ready = true
    if C_Spell and C_Spell.GetSpellCooldownDuration then
        local duration = C_Spell.GetSpellCooldownDuration(spellID)
        if duration then
            cooldown:SetCooldownFromDurationObject(duration)
            ready = duration:IsZero()
        end
    elseif C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if info then
            if cooldown.SetCooldownFromExpression then
                cooldown:SetCooldownFromExpression(spellID)
            elseif cooldown.SetCooldownTable then
                cooldown:SetCooldownTable(info)
            end
            if info.duration and info.duration > 0 then ready = false end
        end
    elseif GetSpellCooldown then
        local start, duration = GetSpellCooldown(spellID)
        if start and duration and duration > 0 then
            cooldown:SetCooldown(start, duration)
            ready = false
        else
            cooldown:SetCooldown(0, 0)
        end
    end

    local shade = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean and C_CurveUtil.EvaluateColorValueFromBoolean(ready, 1.0, 0.38) or (ready and 1.0 or 0.38)
    icon:SetVertexColor(shade, shade, shade, 1)

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

Minimizer.Widgets.PIP_SIZE = 5

-- name: nombre único del frame (string).
-- parentFrame: frame de Blizzard al que se ancla y del que hereda visibilidad.
-- colorKind: clave en Minimizer.Constants.PipColors (ej. "cc", "defensive").
-- anchorCorner: esquina de parentFrame donde centrar el pip (ej. "TOPRIGHT",
--   "TOPLEFT", "BOTTOMRIGHT", "BOTTOMLEFT"). Por defecto "TOPRIGHT".
-- xOff, yOff: offset extra opcional (por si en el futuro hace falta apilar
--   más de un pip en la misma esquina). Por defecto 0, 0.
function Minimizer.Widgets.CreatePip(name, parentFrame, colorKind, anchorCorner, xOff, yOff)
    local colors = Minimizer.Constants.PipColors and Minimizer.Constants.PipColors[colorKind]
    if not parentFrame or not colors then return nil end
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

    local bg = pip:CreateTexture(nil, "ARTWORK")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, 1)
    bg:SetVertexColor(colors.on[1], colors.on[2], colors.on[3], 1)
    if bg.SetMask then
        -- Máscara circular. Usamos esta en vez de "Interface\Masks\CircleMaskScalable"
        -- porque esa puede no resolver como textura válida en SetMask según
        -- versión de cliente (falla en silencio y deja el pip cuadrado).
        -- Esta es la máscara circular que usa el propio Blizzard para
        -- retratos redondos, disponible desde hace muchas versiones.
        bg:SetMask("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    end

    local cooldown = CreateFrame("Cooldown", name .. "Cooldown", pip, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    cooldown:SetDrawEdge(false)
    if cooldown.SetDrawSwipe then cooldown:SetDrawSwipe(true) end
    if cooldown.SetDrawBling then cooldown:SetDrawBling(false) end
    -- IMPORTANTE: false (no true). El brillo del pip depende ENTERAMENTE del
    -- swipe (no hay un vertex color aparte como en los widgets de icono), así
    -- que necesitamos el barrido "normal": cubierto al usar la habilidad,
    -- descubriéndose gradualmente hasta quedar brillante cuando está listo.
    -- Con true queda al revés (se cubre durante el CD y se destapa de golpe
    -- al terminar).
    if cooldown.SetReverse then cooldown:SetReverse(false) end
    if cooldown.SetHideCountdownNumbers then cooldown:SetHideCountdownNumbers(true) end
    if cooldown.SetSwipeColor then
        cooldown:SetSwipeColor(colors.off[1], colors.off[2], colors.off[3], 0.9)
    end

    pip.MinimizerPipBG = bg
    pip.MinimizerPipCooldown = cooldown
    return pip
end

-- Actualiza (o esconde) un pip creado con CreatePip. Igual que UpdateCDWidget
-- pero sin icono ni cálculo de shade -- el barrido lo anima Blizzard solo.
function Minimizer.Widgets.UpdatePip(pip, spellID)
    if not pip then return false end
    if not spellID then pip:Hide(); return false end

    local cooldown = pip.MinimizerPipCooldown
    if C_Spell and C_Spell.GetSpellCooldownDuration then
        local duration = C_Spell.GetSpellCooldownDuration(spellID)
        if duration and cooldown.SetCooldownFromDurationObject then
            cooldown:SetCooldownFromDurationObject(duration)
        end
    elseif C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if info then
            if cooldown.SetCooldownFromExpression then
                cooldown:SetCooldownFromExpression(spellID)
            elseif cooldown.SetCooldownTable then
                cooldown:SetCooldownTable(info)
            end
        end
    elseif GetSpellCooldown then
        local start, duration = GetSpellCooldown(spellID)
        if start and duration then
            cooldown:SetCooldown(start, duration)
        end
    end

    pip:Show()
    return true
end
