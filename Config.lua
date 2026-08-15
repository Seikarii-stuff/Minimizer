-- Saved variables and defaults.
-- Se carga después de Bootstrap.lua. Las SavedVariables de WoW ya están
-- disponibles en este punto, así que Initialize() es segura aquí.
local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Config = Minimizer.Config or {}
Minimizer.Config.VERSION = 2
Minimizer.Config.DEFAULTS = {
    -- Default simplification percent. Set to 100 by default so the addon
    -- simplifies nameplates unless the user opts out.
    simplifyPercent = 100,
    enableTargetMarkers = true,
    enableFocusMarkers = true,
    enableFocusFace = true,
    enableFocusArrows = false,
    menuPosition = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
    },
}

Minimizer.Config.CHAR_DEFAULTS = {
    targetOffensive = nil,
    targetDefensive = nil,
    focusCC = nil,
}

function Minimizer.Config.Initialize()
    MinimizerDB = MinimizerDB or {}
    MinimizerCharDB = MinimizerCharDB or {}

    -- Separación de persistencia:
    --   - MinimizerDB: preferencias de cuenta / UI globales; no dependen del personaje.
    --   - MinimizerCharDB: selección de spell por clase/spec (override manual para target/focus),
    --     además de cualquier ajuste que dependa del personaje o de la especialización actual.
    local defaults = Minimizer.Config.DEFAULTS
    for key, value in pairs(defaults) do
        if MinimizerDB[key] == nil then
            MinimizerDB[key] = value
        end
    end

    local charDefaults = Minimizer.Config.CHAR_DEFAULTS
    for key, value in pairs(charDefaults) do
        if MinimizerCharDB[key] == nil then
            MinimizerCharDB[key] = value
        end
    end

    -- Migración real de la configuración legacy: si algún usuario tenía un único
    -- flag string de focus, convierte la intención al modelo nuevo de dos booleans,
    -- y elimina la clave antigua para no mantener datos obsoletos.
    if MinimizerDB.focusIndicator ~= nil then
        local legacyMode = MinimizerDB.focusIndicator
        MinimizerDB.enableFocusFace = (legacyMode == "face")
        MinimizerDB.enableFocusArrows = (legacyMode ~= "face")
        MinimizerDB.focusIndicator = nil
    end

    if MinimizerDB.enableFocusFace == nil then
        MinimizerDB.enableFocusFace = true
    end
    if MinimizerDB.enableFocusArrows == nil then
        MinimizerDB.enableFocusArrows = false
    end

    local version = tonumber(MinimizerDB.version) or 0
    if version < Minimizer.Config.VERSION then
        MinimizerDB.version = Minimizer.Config.VERSION
    end

    return MinimizerDB, MinimizerCharDB
end


