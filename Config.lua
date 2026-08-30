-- Saved variables and defaults.
local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Config = Minimizer.Config or {}
Minimizer.Config.DEFAULTS = {
    simplifyEnabled = true,
    enableTargetMarkers = true,
    enableFocusMarkers = true,
    enableFocusFace = true,
    enableFocusArrows = true,

    -- Player Wheel: preferencias globales de UI, no por personaje.
    wheelEnabled = true,
    wheelSize = 180,
    wheelPipRadius = 75,

    menuPosition = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
    },
}

-- Las selecciones de spell de los seis slots sí dependen del personaje/spec.
Minimizer.Config.CHAR_DEFAULT_KEYS = {
    "pip1", "pip2", "pip3", "pip4", "pip5", "pip6",
}

local function CopyDefault(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, nested in pairs(value) do
        copy[key] = CopyDefault(nested)
    end
    return copy
end

function Minimizer.Config.Initialize()
    MinimizerDB = MinimizerDB or {}
    MinimizerCharDB = MinimizerCharDB or {}

    local defaults = Minimizer.Config.DEFAULTS
    for key, value in pairs(defaults) do
        if MinimizerDB[key] == nil then
            MinimizerDB[key] = CopyDefault(value)
        end
    end

    -- Legacy focus indicator -> dos flags independientes.
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

    -- Migración de pips legacy. No se modifica ningún override pipN existente.
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
    MinimizerCharDB.targetPip2 = nil
    MinimizerCharDB.focusPip2 = nil
    MinimizerCharDB.targetOffensive = nil

    -- Aplicar inmediatamente los nuevos defaults/config al componente Wheel.
    if Minimizer.Wheel and Minimizer.Wheel.ApplyConfig then
        Minimizer.Wheel:ApplyConfig()
    end

    return MinimizerDB, MinimizerCharDB
end

function Minimizer.Config.IsSimplifyEnabled()
    if MinimizerDB == nil then
        return true
    end
    if MinimizerDB.simplifyEnabled == nil then
        local legacy = tonumber(MinimizerDB.simplifyPercent)
        return (legacy == nil) or (legacy > 0)
    end
    return MinimizerDB.simplifyEnabled == true
end
