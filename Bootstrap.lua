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
_G.Minimizer = Minimizer

-- ── Registro de módulos pendientes ──────────────────────────────────────────
-- Los módulos que necesitan ejecutar código DESPUÉS de ADDON_LOADED (cuando
-- MinimizerDB ya está disponible) llaman a Minimizer.OnLoad(fn).
-- Bootstrap los invoca en orden de registro una vez que la BD está lista.
local pendingCallbacks = {}
local loaded           = false

---Registra una función para que se ejecute justo después de que la BD
---esté disponible (tras ADDON_LOADED). Si ya se cargó, la ejecuta inmediatamente.
---@param fn function
function Minimizer.OnLoad(fn)
    if type(fn) ~= "function" then return end
    if loaded then
        fn()
    else
        pendingCallbacks[#pendingCallbacks + 1] = fn
    end
end

-- ── Frame de arranque ────────────────────────────────────────────────────────
local bootstrapFrame = CreateFrame("Frame", "MinimizerBootstrapFrame")

bootstrapFrame:RegisterEvent("ADDON_LOADED")
bootstrapFrame:SetScript("OnEvent", function(_, event, name)
    if event ~= "ADDON_LOADED" or name ~= ADDON_NAME then return end
    bootstrapFrame:UnregisterEvent("ADDON_LOADED")

    -- 1. Inicializar la BD de SavedVariables
    if Minimizer.Config and Minimizer.Config.Initialize then
        Minimizer.Config.Initialize()
    end

    -- 2. Marcar como cargado antes de los callbacks por si alguno consulta
    loaded = true

    -- 3. Ejecutar callbacks en orden de registro
    for i = 1, #pendingCallbacks do
        local ok, err = pcall(pendingCallbacks[i])
        if not ok then
            print("|cffff4444Minimizer Bootstrap|r: error en callback #" .. i .. ": " .. tostring(err))
        end
    end
    pendingCallbacks = nil  -- liberar memoria; ya no se necesitan
end)
