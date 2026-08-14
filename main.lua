local addon = CreateFrame("Frame")

-- 1. Crear el marco principal
local portraitFrame = CreateFrame("Frame", "FocusPortraitIconFrame", UIParent)
portraitFrame:SetSize(40, 40)
portraitFrame:SetFrameStrata("HIGH")
portraitFrame:Hide()

-- Textura de la cara de tu personaje
local portraitTex = portraitFrame:CreateTexture(nil, "ARTWORK")
portraitTex:SetAllPoints(portraitFrame)

-- Borde del icono
local borderTex = portraitFrame:CreateTexture(nil, "OVERLAY")
borderTex:SetAllPoints(portraitFrame)
borderTex:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
borderTex:SetPoint("TOPLEFT", -6, 6)
borderTex:SetPoint("BOTTOMRIGHT", 6, -6)

-- 2. Marco de Cooldown NATIVO (el golpe/espiral rotatorio de Blizzard)
local cdFrame = CreateFrame("Cooldown", "FocusPortraitCooldownFrame", portraitFrame, "CooldownFrameTemplate")
cdFrame:SetAllPoints(portraitFrame)
cdFrame:SetDrawEdge(true)
cdFrame:SetSwipeTexture("Interface\\HUD\\UI-HUD-CoolDown-Swipe") -- Espiral oficial

local myInterruptSpellID = nil

-- Detección de habilidad de corte del jugador
local function FindPlayerInterruptSpell()
    local commonInterrupts = {
        6552, 96231, 147362, 1766, 15487, 47528, 57994, 2139, 19647, 116705, 106839, 183752, 351338
    }
    for _, spellID in ipairs(commonInterrupts) do
        if C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook then
            if C_SpellBook.IsSpellKnownOrInSpellBook(spellID) then return spellID end
        elseif IsSpellKnown and IsSpellKnown(spellID) then
            return spellID
        end
    end
    return nil
end

-- Actualiza la espiral rotatoria y el tono de la cara usando la API de Cooldown
local function UpdateCooldownState()
    if not myInterruptSpellID then
        myInterruptSpellID = FindPlayerInterruptSpell()
        if not myInterruptSpellID then return end
    end

    if C_Spell and C_Spell.GetSpellCooldown then
        local cd = C_Spell.GetSpellCooldown(myInterruptSpellID)
        if cd then
            -- Pasamos directamente la tabla de cooldown al CooldownFrame nativo de Blizzard
            -- Esto dibuja el barrido sombreado rotatorio SIN errores de Secret Value
            if cdFrame.SetCooldownFromExpression then
                cdFrame:SetCooldownFromExpression(myInterruptSpellID)
            elseif cdFrame.SetCooldownTable then
                cdFrame:SetCooldownTable(cd)
            end

            -- Si está en CD (y no es solo el GCD), oscurecemos/desaturamos la cara
            if cd.isActive and not cd.isOnGCD then
                portraitTex:SetDesaturated(true)
            else
                portraitTex:SetDesaturated(false)
            end
        end
    end
end

-- Actualización gráfica y posicionamiento
local function UpdateFocusPortrait()
    -- 1. Si no hay Focus o está muerto, ocultar todo
    if not UnitExists("focus") or UnitIsDead("focus") then
        portraitFrame:Hide()
        return
    end

    -- 2. Si el Focus no tiene Nameplate visible en pantalla, ocultar
    local focusPlate = C_NamePlate.GetNamePlateForUnit("focus")
    if not focusPlate then
        portraitFrame:Hide()
        return
    end

    -- 3. Renderizar siempre la cara del personaje y fijar a la Nameplate
    SetPortraitTexture(portraitTex, "player")
    portraitFrame:ClearAllPoints()
    portraitFrame:SetPoint("BOTTOM", focusPlate, "TOP", 0, 10)
    portraitFrame:Show()

    -- 4. Refrescar estado del sombreado/espiral de corte
    UpdateCooldownState()
end

-- Bucle de seguimiento para posicionamiento
local elapsedTimer = 0
portraitFrame:SetScript("OnUpdate", function(self, elapsed)
    elapsedTimer = elapsedTimer + elapsed
    if elapsedTimer >= 0.02 then
        UpdateFocusPortrait()
        elapsedTimer = 0
    end
end)

-- Eventos de actualización
addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("PLAYER_FOCUS_CHANGED")
addon:RegisterEvent("NAME_PLATE_UNIT_ADDED")
addon:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
addon:RegisterEvent("SPELL_UPDATE_COOLDOWN")

addon:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_LOGIN" then
        myInterruptSpellID = FindPlayerInterruptSpell()
    end
    UpdateFocusPortrait()
end)

print("|cFF00FF00[FocusInterrupt]|r Addon pulido con animación de Cooldown rotatoria.")