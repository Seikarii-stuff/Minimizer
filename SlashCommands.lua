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

SLASH_MINIMIZER1 = "/mini"
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

    local function RequestUpdate()
        if Minimizer.Dispatcher and Minimizer.Dispatcher.RequestFullUpdate then
            Minimizer.Dispatcher.RequestFullUpdate()
        elseif Minimizer.Core and Minimizer.Core.ApplyToAll then
            Minimizer.Core.ApplyToAll()
        end
    end

    local value = tonumber(msg)
    if msg == "on" then
        if not MinimizerDB then MinimizerDB = {} end
        MinimizerDB.simplifyEnabled = true
        print("|cff33ff99Minimizer|r: simplificación habilitada")
        RequestUpdate()
        return
    end
    if msg == "off" then
        if not MinimizerDB then MinimizerDB = {} end
        MinimizerDB.simplifyEnabled = false
        print("|cff33ff99Minimizer|r: simplificación deshabilitada")
        RequestUpdate()
        return
    end

    if not value then
        print("|cff33ff99Minimizer|r: uso /mini menu, /mini on, /mini off, /mini <0-100>, /mini face, /mini arrows, /mini noface, /mini noarrows")
        return
    end

    value = ClampSimplifyPercent(value)
    if not MinimizerDB then MinimizerDB = {} end
    MinimizerDB.simplifyEnabled = (value > 0)
    print("|cff33ff99Minimizer|r: simplificación " .. (value > 0 and "habilitada" or "deshabilitada"))
    RequestUpdate()
end
