-- ============================================================================
-- Minimizer - Options.lua
-- Registra una entrada en el panel "AddOns" de Blizzard (Settings /
-- Interface Options) con un botón que abre el mismo menú que /mini.
-- No duplica ningún control: Menu.lua sigue siendo la única fuente de
-- verdad de las opciones configurables; este panel es solo un atajo de
-- descubrimiento para gente que nunca usa comandos de chat.
-- ============================================================================
local _, Minimizer = ...
if not Minimizer then return end

local function OpenMiniMenu()
    if Minimizer.Menu and Minimizer.Menu.Open then
        Minimizer.Menu.Open()
        return
    end
    print("|cffff4444Minimizer|r: menú no disponible en esta sesión")
end

local function CreateInterfaceOptionsPanel()
    -- API moderna de Settings (Dragonflight 10.0+, vigente en Midnight
    -- 12.1). InterfaceOptions_AddCategory fue retirada hace tiempo; si
    -- Settings.RegisterCanvasLayoutCategory no existe, no forzamos nada y
    -- simplemente no aparece el panel (el addon sigue siendo 100% funcional
    -- vía /mini).
    if type(Settings) ~= "table" or type(Settings.RegisterCanvasLayoutCategory) ~= "function" then
        return
    end

    local panel = CreateFrame("Frame", "MinimizerOptionsPanel", UIParent)
    panel.name = "Minimizer"

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Minimizer")

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    description:SetPoint("RIGHT", -16, 0)
    description:SetJustifyH("LEFT")
    description:SetText("Abre el menú flotante de Minimizer desde el panel de AddOns. También puedes usar /mini desde el chat en cualquier momento.")

    local openButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openButton:SetSize(150, 24)
    openButton:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -16)
    openButton:SetText("Open Mini Menu")
    openButton:SetScript("OnClick", OpenMiniMenu)

    local slashHint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    slashHint:SetPoint("TOPLEFT", openButton, "BOTTOMLEFT", 0, -12)
    slashHint:SetPoint("RIGHT", -16, 0)
    slashHint:SetJustifyH("LEFT")
    slashHint:SetText("Atajo de chat: /mini")

    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    -- Guardamos el ID de la categoría por si en el futuro algún comando
    -- quisiera reabrir este panel exacto vía Settings.OpenToCategory(...).
    panel.settingsCategory = category
    Settings.RegisterAddOnCategory(category)
end

-- Se registra en el mismo ciclo de vida que el resto del addon: no hace
-- falta esperar a nada especial, Settings ya está disponible en
-- ADDON_LOADED/PLAYER_LOGIN igual que en BloodShieldOverlay.
local optionsFrame = CreateFrame("Frame", "MinimizerOptionsBootstrapFrame")
optionsFrame:RegisterEvent("ADDON_LOADED")
optionsFrame:SetScript("OnEvent", function(self, event, name)
    if event ~= "ADDON_LOADED" or name ~= "Minimizer" then return end
    self:UnregisterEvent("ADDON_LOADED")
    CreateInterfaceOptionsPanel()
end)