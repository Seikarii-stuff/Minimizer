-- Saved variables and defaults.
local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Config = Minimizer.Config or {}
Minimizer.Config.DEFAULTS = {
    simplifyEnabled = true,

    -- These indicators are always enabled and intentionally not persisted.
    -- Do not add them back to SavedVariables: they are hardcoded behavior.

    enableMouseHalo = true,

    menuPosition = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
    },
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

    -- Estos flags fueron opciones configurables, pero ahora son comportamiento fijo.
    -- Eliminarlos aquí limpia SavedVariables existentes y evita persistirlos de nuevo.
    MinimizerDB.enableTargetMarkers = nil
    MinimizerDB.enableFocusMarkers = nil
    -- Migrate legacy focusIndicator to modern booleans when present
    if MinimizerDB.focusIndicator ~= nil then
        if MinimizerDB.enableFocusFace == nil and MinimizerDB.enableFocusArrows == nil then
            MinimizerDB.enableFocusFace = (MinimizerDB.focusIndicator == "face")
            MinimizerDB.enableFocusArrows = (MinimizerDB.focusIndicator == "arrows")
        end
    end

    -- Legacy focus indicator is no longer used because both focus indicators are fixed on.
    MinimizerDB.focusIndicator = nil

    -- Wheel y sus pip slots fueron eliminados.
    MinimizerDB.wheelEnabled = nil
    MinimizerDB.wheelSize = nil
    MinimizerDB.wheelPipRadius = nil
    for index = 1, 6 do
        MinimizerCharDB["pip" .. index] = nil
    end

    -- Clean legacy Wheel/Pip keys left by previous versions.
    MinimizerCharDB.targetDefensive = nil
    MinimizerCharDB.targetPip1 = nil
    MinimizerCharDB.targetPip2 = nil
    MinimizerCharDB.targetOffensive = nil
    MinimizerCharDB.focusCC = nil
    MinimizerCharDB.focusPip1 = nil
    MinimizerCharDB.focusPip2 = nil

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
