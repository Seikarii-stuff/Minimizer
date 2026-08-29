-- Saved variables and defaults.
-- Se carga después de Bootstrap.lua. Las SavedVariables de WoW ya están
-- disponibles en este punto, así que Initialize() es segura aquí.
local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Config = Minimizer.Config or {}
Minimizer.Config.DEFAULTS = {
    -- Flag on/off: simplificación activada por defecto.
    -- `simplifyPercent` se mantiene para compatibilidad de lectura legacy
    -- en Decision.lua, pero internamente usamos `simplifyEnabled` como la
    -- fuente de verdad a partir de esta versión.
    simplifyEnabled = true,
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
-- lista de claves válidas del Player Wheel aquí en vez de fingir defaults que nunca existieron.
Minimizer.Config.CHAR_DEFAULT_KEYS = {
    "pip1",
    "pip2",
    "pip3",
    "pip4",
    "pip5",
    "pip6",
}

function Minimizer.Config.Initialize()
    MinimizerDB = MinimizerDB or {}
    MinimizerCharDB = MinimizerCharDB or {}

    -- Separación de persistencia:
    --   - MinimizerDB: preferencias de cuenta / UI globales; no dependen del personaje.
    --   - MinimizerCharDB: selección de spell por clase/spec para los slots del Player Wheel,
    --     además de cualquier ajuste que dependa del personaje o de la especialización actual.
    local defaults = Minimizer.Config.DEFAULTS
    for key, value in pairs(defaults) do
        if MinimizerDB[key] == nil then
            MinimizerDB[key] = value
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
        MinimizerDB.enableFocusArrows = true
    end

    -- Migración de pips: targetDefensive -> pip1, focusCC -> pip2,
    -- y eliminación de targetOffensive (el halo ahora representa el corte).
    if MinimizerCharDB.targetDefensive ~= nil then
        if MinimizerCharDB.pip1 == nil then
            MinimizerCharDB.pip1 = MinimizerCharDB.targetDefensive
        end
        MinimizerCharDB.targetDefensive = nil
    end

    if MinimizerCharDB.targetPip1 ~= nil then
        if MinimizerCharDB.pip1 == nil then
            MinimizerCharDB.pip1 = MinimizerCharDB.targetPip1
        end
        MinimizerCharDB.targetPip1 = nil
    end

    if MinimizerCharDB.focusCC ~= nil then
        if MinimizerCharDB.pip2 == nil then
            MinimizerCharDB.pip2 = MinimizerCharDB.focusCC
        end
        MinimizerCharDB.focusCC = nil
    end

    if MinimizerCharDB.focusPip1 ~= nil then
        if MinimizerCharDB.pip2 == nil then
            MinimizerCharDB.pip2 = MinimizerCharDB.focusPip1
        end
        MinimizerCharDB.focusPip1 = nil
    end

    if MinimizerCharDB.targetPip2 ~= nil then
        MinimizerCharDB.targetPip2 = nil
    end
    if MinimizerCharDB.focusPip2 ~= nil then
        MinimizerCharDB.focusPip2 = nil
    end

    if MinimizerCharDB.targetOffensive ~= nil then
        MinimizerCharDB.targetOffensive = nil
    end

    return MinimizerDB, MinimizerCharDB
end


-- Comprueba si la simplificación está activada, soportando la clave legacy
-- `simplifyPercent` como fallback. Centraliza la lógica usada por el
-- menú y la toma de decisiones para evitar duplicados en el código.
function Minimizer.Config.IsSimplifyEnabled()
    -- Si por alguna razon MinimizerDB no existe (tests, entorno aislado),
    -- asumimos el comportamiento por defecto previo: habilitado.
    if MinimizerDB == nil then
        return true
    end

    if MinimizerDB.simplifyEnabled == nil then
        local legacy = tonumber(MinimizerDB.simplifyPercent)
        return (legacy == nil) or (legacy > 0)
    else
        return MinimizerDB.simplifyEnabled == true
    end
end


