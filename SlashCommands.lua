local _, Minimizer = ...
if not Minimizer or not Minimizer.Core then return end

local function ClampSimplifyPercent(value)
    value = tonumber(value) or 0
    return math.floor(math.max(0, math.min(100, value)))
end

local function ToggleMenu()
    if Minimizer.Menu and Minimizer.Menu.Toggle then
        Minimizer.Menu.Toggle()
        return
    end
    print("|cff33ff99Minimizer|r: menú no disponible en esta sesión")
end

SLASH_MINIMIZER1 = "/simp"
SlashCmdList["MINIMIZER"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")

    if msg == "" or msg == "menu" then
        ToggleMenu()
        return
    end

    if msg == "arrows" then
        if Minimizer.Focus then
            Minimizer.Focus:SetArrowsEnabled(true)
            print("|cff33ff99Minimizer|r: focus arrows habilitado")
        end
        return
    end
    if msg == "face" then
        if Minimizer.Focus then
            Minimizer.Focus:SetFaceEnabled(true)
            print("|cff33ff99Minimizer|r: focus face habilitado")
        end
        return
    end
    if msg == "noarrows" then
        if Minimizer.Focus then
            Minimizer.Focus:SetArrowsEnabled(false)
            print("|cff33ff99Minimizer|r: focus arrows desactivado")
        end
        return
    end
    if msg == "noface" then
        if Minimizer.Focus then
            Minimizer.Focus:SetFaceEnabled(false)
            print("|cff33ff99Minimizer|r: focus face desactivado")
        end
        return
    end

    local value = tonumber(msg)
    if msg == "on" then
        if not MinimizerDB then MinimizerDB = {} end
        MinimizerDB.simplifyEnabled = true
        print("|cff33ff99Minimizer|r: simplificación habilitada")
        Minimizer.Core.ApplyToAll()
        return
    end
    if msg == "off" then
        if not MinimizerDB then MinimizerDB = {} end
        MinimizerDB.simplifyEnabled = false
        print("|cff33ff99Minimizer|r: simplificación deshabilitada")
        Minimizer.Core.ApplyToAll()
        return
    end

    if not value then
        print("|cff33ff99Minimizer|r: uso /simp menu, /simp on, /simp off, /simp <0-100>, /simp face, /simp arrows, /simp noface, /simp noarrows")
        return
    end

    -- Compatibilidad legacy: se sigue aceptando /simp <0-100> por si algún
    -- usuario tiene el hábito o un perfil/macro viejo, pero internamente
    -- SIEMPRE se traduce a booleano y NUNCA se vuelve a escribir simplifyPercent.
    value = ClampSimplifyPercent(value)
    if not MinimizerDB then MinimizerDB = {} end
    MinimizerDB.simplifyEnabled = (value > 0)
    print("|cff33ff99Minimizer|r: simplificación " .. (value > 0 and "habilitada" or "deshabilitada"))
    Minimizer.Core.ApplyToAll()
end
