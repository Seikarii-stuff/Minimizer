-- ============================================================================
-- Minimizer - Bootstrap.lua
-- Primer archivo cargado por el .toc. Inicializa la tabla compartida del addon
-- y el ciclo de vida de ADDON_LOADED antes de que ningún módulo se ejecute.
-- ============================================================================

-- El engine de WoW inyecta (ADDON_NAME, addonTable) como los dos varargs del
-- archivo raíz. Todos los demás archivos del .toc comparten la MISMA tabla.
local ADDON_NAME, Minimizer = ...

-- ── Tabla compartida ─────────────────────────────────────────────────────────
-- Los módulos declaran sus sub-tablas usando Minimizer.X = Minimizer.X or {}
-- para que el orden de carga no importe. Bootstrap garantiza que la raíz
-- existe y expone el namespace global por si algún script externo lo necesita.
-- Expose global only if not already present to avoid clobbering other addons
_G.Minimizer = _G.Minimizer or Minimizer

-- ── Frame de arranque ────────────────────────────────────────────────────────
local bootstrapFrame = CreateFrame("Frame", "MinimizerBootstrapFrame")

bootstrapFrame:RegisterEvent("ADDON_LOADED")
bootstrapFrame:SetScript("OnEvent", function(_, event, name)
    if event ~= "ADDON_LOADED" or name ~= ADDON_NAME then return end
    bootstrapFrame:UnregisterEvent("ADDON_LOADED")

    if Minimizer.Config and Minimizer.Config.Initialize then
        Minimizer.Config.Initialize()
    end
    if Minimizer.Dispatcher and Minimizer.Dispatcher.StartSafetyNet then
        Minimizer.Dispatcher.StartSafetyNet()
    elseif Minimizer.Core and Minimizer.Core.StartSafetyNet then
        Minimizer.Core.StartSafetyNet()
    end
end)
