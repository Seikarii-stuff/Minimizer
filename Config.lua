-- Saved variables and defaults.
-- Se carga después de Bootstrap.lua. Las SavedVariables de WoW ya están
-- disponibles en este punto, así que Initialize() es segura aquí.
local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Config = Minimizer.Config or {}
Minimizer.Config.DEFAULTS = {
    simplifyEnabled = true,
    enableTargetMarkers = true,
    enableFocusMarkers = true,
    enableFocusFace = true,
    enableFocusArrows = true,
    enableMyDebuffOverlay = false,
    menuPosition = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
    },
}

Minimizer.Config.CHAR_DEFAULT_KEYS = {
    "pip1",
    "pip2",
}

function Minimizer.Config.Initialize()
    MinimizerDB = MinimizerDB or {}
    MinimizerCharDB = MinimizerCharDB or {}

    local defaults = Minimizer.Config.DEFAULTS
    for key, value in pairs(defaults) do
        if MinimizerDB[key] == nil then
            MinimizerDB[key] = value
        end
    end

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

function Minimizer.Config.IsSimplifyEnabled()
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
