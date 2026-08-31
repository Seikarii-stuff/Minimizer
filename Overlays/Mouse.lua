-- ============================================================================
-- Minimizer - Mouse.lua
-- Cursor overlay: halo azul + cooldown del interrupt opcional.
-- No muestra recursos. El hot path es exclusivamente el seguimiento del cursor.
-- ============================================================================
local _, Minimizer = ...
if not Minimizer then return end

local Mouse = {}
Minimizer.Mouse = Mouse

local MODE_INTERRUPT = "interrupt"
local MODE_VISUAL = "visual"
local MODE_HIDDEN = "hidden"
local DEFAULT_MODE = MODE_INTERRUPT

local HALO_SIZE = 46
local CURSOR_UPDATE_INTERVAL = 1 / 144
local CURSOR_Y_OFFSET = -1
local BLUE = { 0.08, 0.55, 1.00, 0.95 }
local BLUE_SWIPE = { 0.04, 0.32, 0.95, 0.70 }

local mode
local halo
local eventFrame
local cursorElapsed = 0
local cursorScale = 1

local function NormalizeMode(value)
    if value == MODE_INTERRUPT or value == MODE_VISUAL or value == MODE_HIDDEN then
        return value
    end
    return DEFAULT_MODE
end

local function GetMode()
    return NormalizeMode(MinimizerDB and MinimizerDB.mouseHaloMode)
end

local function SaveMode(value)
    if MinimizerDB then
        MinimizerDB.mouseHaloMode = value
    end
    mode = value
end

local function GetInterruptSpellID()
    local interrupt = Minimizer.Interrupt
    if not interrupt or not interrupt.GetSpellID then return nil end

    local spellID = interrupt.GetSpellID()
    if not spellID then return nil end

    -- Interrupt.GetSpellID() deliberately has a compatibility fallback to the
    -- first configured spell. Mouse must be stricter: if the current class/spec
    -- does not actually know that spell, it is not a valid interrupt here.
    if Minimizer.Utils and Minimizer.Utils.IsSpellKnownByPlayer
        and not Minimizer.Utils.IsSpellKnownByPlayer(spellID) then
        return nil
    end

    return spellID
end

local function EnsureEventFrame()
    if eventFrame then return eventFrame end

    eventFrame = CreateFrame("Frame", "MinimizerMouseEventFrame")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "UI_SCALE_CHANGED" then
            cursorScale = UIParent:GetEffectiveScale()
            return
        end

        if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
            if Minimizer.Interrupt and Minimizer.Interrupt.InvalidateSpellIDCache then
                Minimizer.Interrupt.InvalidateSpellIDCache()
            end
        end

        if mode == MODE_INTERRUPT then
            Mouse:UpdateInterrupt()
        end
    end)
    return eventFrame
end

local function RegisterEvents()
    local frame = EnsureEventFrame()
    frame:RegisterEvent("UI_SCALE_CHANGED")
    frame:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
    frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
    frame:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    frame:UnregisterEvent("PLAYER_TALENT_UPDATE")

    if mode == MODE_INTERRUPT then
        frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        frame:RegisterEvent("PLAYER_TALENT_UPDATE")
    end
end

local function UpdateCursorPosition()
    if not halo or not halo:IsShown() then return end
    if not GetCursorPosition then return end

    local cursorX, cursorY = GetCursorPosition()
    if not cursorX or not cursorY or not cursorScale or cursorScale <= 0 then return end

    halo:ClearAllPoints()
    halo:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cursorX / cursorScale, cursorY / cursorScale + CURSOR_Y_OFFSET)
end

function Mouse:UpdateInterrupt()
    if mode ~= MODE_INTERRUPT or not halo then return end

    local spellID = GetInterruptSpellID()
    if not spellID then
        -- Explicit guard requested by the feature: classes/specs without an
        -- available interrupt automatically fall back to visual-only mode.
        SaveMode(MODE_VISUAL)
        RegisterEvents()
        halo:Show()
        halo.MinimizerHaloCooldown:Hide()
        return
    end

    halo:ShowFor(spellID)
end

local function EnsureHalo()
    if halo then return halo end

    halo = Minimizer.Halo.Create(nil, {
        name = "MinimizerMouseHalo",
        size = HALO_SIZE,
        cooldownName = "MinimizerMouseInterruptCooldown",
        cooldownFrameLevelOffset = 10,
    })
    halo:SetFrameStrata("HIGH")
    halo:SetFrameLevel(1)
    halo.MinimizerHaloTexture:SetVertexColor(BLUE[1], BLUE[2], BLUE[3], BLUE[4])

    local cooldown = halo.MinimizerHaloCooldown
    if cooldown and cooldown.SetSwipeColor then
        cooldown:SetSwipeColor(BLUE_SWIPE[1], BLUE_SWIPE[2], BLUE_SWIPE[3], BLUE_SWIPE[4])
    end

    return halo
end

local function StopRuntime()
    if eventFrame then
        eventFrame:UnregisterAllEvents()
    end
    if halo then
        halo:Hide()
        halo:SetScript("OnUpdate", nil)
    end
    cursorElapsed = 0
end

local function StartRuntime()
    local frame = EnsureHalo()
    cursorScale = UIParent:GetEffectiveScale()
    RegisterEvents()

    frame:SetScript("OnUpdate", function(_, elapsed)
        cursorElapsed = cursorElapsed + elapsed
        if cursorElapsed < CURSOR_UPDATE_INTERVAL then return end
        cursorElapsed = 0
        UpdateCursorPosition()
    end)

    if mode == MODE_VISUAL then
        frame:Show()
        frame.MinimizerHaloCooldown:Hide()
    else
        frame:Show()
        Mouse:UpdateInterrupt()
    end

    UpdateCursorPosition()
end

function Mouse:SetMode(newMode)
    newMode = NormalizeMode(newMode)
    if mode == newMode and ((newMode == MODE_HIDDEN) or halo) then
        return false
    end

    SaveMode(newMode)
    StopRuntime()

    if newMode ~= MODE_HIDDEN then
        StartRuntime()
    end
    return true
end

function Mouse:GetMode()
    return GetMode()
end

function Mouse:ApplyConfig()
    return self:SetMode(GetMode())
end

function Mouse.GetModeOptions()
    return {
        { value = MODE_INTERRUPT, text = "Halo + interrupt" },
        { value = MODE_VISUAL, text = "Solo halo" },
        { value = MODE_HIDDEN, text = "No mostrar" },
    }
end

local function InstallMenuControls()
    if Mouse._menuControls or not Minimizer.Menu or not Minimizer.Menu.frame then return end

    local plater = Minimizer.Menu.frame.tabs
        and Minimizer.Menu.frame.tabs.Plater
        and Minimizer.Menu.frame.tabs.Plater.panel
    local anchor = plater and plater.controls and plater.controls.arrowsToggle
    if not plater or not anchor then return end

    local holder = CreateFrame("Frame", "MinimizerMenuMouseHalo", plater)
    holder:SetSize(210, 54)
    holder:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)

    local label = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", holder, "TOPLEFT", 16, 10)
    label:SetText("Mouse halo")

    local dropdown = CreateFrame("Frame", "MinimizerMenuMouseHaloDrop", holder, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", holder, "TOPLEFT", -8, -4)
    dropdown:SetSize(210, 28)

    local function RefreshDropdown()
        local selected = Mouse:GetMode()
        for _, option in ipairs(Mouse.GetModeOptions()) do
            if option.value == selected then
                UIDropDownMenu_SetText(dropdown, option.text)
                return
            end
        end
        UIDropDownMenu_SetText(dropdown, "Halo + interrupt")
    end

    UIDropDownMenu_Initialize(dropdown, function()
        local selected = Mouse:GetMode()
        for _, option in ipairs(Mouse.GetModeOptions()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.value = option.value
            info.checked = selected == option.value
            info.func = function()
                Mouse:SetMode(option.value)
                RefreshDropdown()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    holder.Refresh = RefreshDropdown
    Mouse._menuControls = holder
    RefreshDropdown()
end

if Minimizer.Menu and hooksecurefunc then
    hooksecurefunc(Minimizer.Menu, "Open", InstallMenuControls)
    hooksecurefunc(Minimizer.Menu, "Refresh", function()
        if Mouse._menuControls and Mouse._menuControls.Refresh then
            Mouse._menuControls.Refresh()
        end
    end)
end
