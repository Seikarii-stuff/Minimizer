-- Saved variables and defaults.
-- Se carga después de Bootstrap.lua. Las SavedVariables de WoW ya están
-- disponibles en este punto, así que Initialize() es segura aquí.
local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Config = Minimizer.Config or {}
Minimizer.Config.VERSION = 1
Minimizer.Config.DEFAULTS = {
    simplifyPercent = 0,
    enableTargetMarkers = true,
    enableFocusMarkers = true,
    focusIndicator = "face",
}

function Minimizer.Config.Initialize()
    MinimizerDB = MinimizerDB or {}
    local defaults = Minimizer.Config.DEFAULTS
    for key, value in pairs(defaults) do
        if MinimizerDB[key] == nil then
            MinimizerDB[key] = value
        end
    end
    local version = tonumber(MinimizerDB.version) or 0
    if version < Minimizer.Config.VERSION then
        -- Future migrations belong here; keeping this explicit prevents old
        -- saved variables from silently skipping newly added defaults.
        MinimizerDB.version = Minimizer.Config.VERSION
    end
    return MinimizerDB
end

-- Llamar aquí es correcto: WoW hace disponibles las SavedVariables antes de
-- ejecutar los archivos del addon. Bootstrap.lua también lo invocará en
-- ADDON_LOADED como fallback defensivo.
Minimizer.Config.Initialize()
