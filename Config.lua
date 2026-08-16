-- Saved variables and defaults.
-- Se carga después de Bootstrap.lua. Las SavedVariables de WoW ya están
-- disponibles en este punto, así que Initialize() es segura aquí.
local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Config = Minimizer.Config or {}
Minimizer.Config.DEFAULTS = {
    -- Default simplification percent. Set to 100 by default so the addon
    -- simplifies nameplates unless the user opts out.
    simplifyPercent = 100,
    enableTargetMarkers = true,
    enableFocusMarkers = true,
    enableFocusFace = true,
    enableFocusArrows = true,
    menuPosition = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
    },
}

-- No hay valores por defecto reales que asignar (todas las claves son overrides
-- manuales de usuario, "sin override" YA es nil por ausencia). Se documenta la
-- lista de claves válidas aquí en vez de fingir defaults que nunca existieron.
Minimizer.Config.CHAR_DEFAULT_KEYS = {
    "targetOffensive",
    "targetDefensive",
    "focusCC",
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

    -- No se asignan defaults (no existen valores por defecto reales para estas
    -- claves, ver Minimizer.Config.CHAR_DEFAULT_KEYS). Se deja este bloque solo
    -- para dejar constancia explícita de qué claves gestiona MinimizerCharDB,
    -- sin fingir una inicialización que nunca tuvo efecto.

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
        MinimizerDB.enableFocusArrows = true
    end

    -- Las migraciones de este archivo se disparan comprobando la EXISTENCIA
    -- de la clave vieja (ej. MinimizerDB.focusIndicator ~= nil), no un número
    -- de versión — así funcionan igual de bien aunque un usuario salte varias
    -- versiones de golpe. Si en el futuro hace falta gatear una migración que
    -- NO se pueda detectar por presencia/ausencia de clave, reintroducir aquí
    -- un contador de versión que SÍ se lea en algún `if version < N`.

    return MinimizerDB, MinimizerCharDB
end


