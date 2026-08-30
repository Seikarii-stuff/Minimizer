-- ============================================================================
-- Minimizer - Bootstrap.lua
-- Primer archivo cargado por el .toc. Inicializa la tabla compartida del addon
-- y el ciclo de vida de ADDON_LOADED antes de que ningún módulo se ejecute.
-- ============================================================================

local ADDON_NAME, Minimizer = ...

_G.Minimizer = _G.Minimizer or Minimizer

local bootstrapFrame = CreateFrame("Frame", "MinimizerBootstrapFrame")

bootstrapFrame:RegisterEvent("ADDON_LOADED")
bootstrapFrame:SetScript("OnEvent", function(_, event, name)
    if event ~= "ADDON_LOADED" or name ~= ADDON_NAME then return end
    bootstrapFrame:UnregisterEvent("ADDON_LOADED")

    if Minimizer.Config and Minimizer.Config.Initialize then
        Minimizer.Config.Initialize()
    end
    -- Config.lua is loaded before Wheel/Wheel.lua, so Wheel configuration is
    -- applied here, after the complete .toc has been loaded.
    if Minimizer.Wheel and Minimizer.Wheel.ApplyConfig then
        Minimizer.Wheel:ApplyConfig()
    end
    if Minimizer.Options and Minimizer.Options.Initialize then
        Minimizer.Options.Initialize()
    end
end)
