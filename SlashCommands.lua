local _, Minimizer = ...
if not Minimizer or not Minimizer.Core then return end

SLASH_MINIMIZER1 = "/simp"
SlashCmdList["MINIMIZER"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    
    if msg == "arrows" or msg == "face" then
        if Minimizer.Focus then
            Minimizer.Focus:SetMode(msg)
            print("|cff33ff99Minimizer|r: indicador de focus = " .. msg)
        end
        return
    end
        
    local value = tonumber(msg)
    if not value then
        print("|cff33ff99Minimizer|r: uso /simp <0-100>, /simp arrows o /simp face")
        return
    end

    value = math.floor(math.max(0, math.min(100, value)))
    MinimizerDB.simplifyPercent = value

    print("|cff33ff99Minimizer|r: simplificación ajustada a " .. value .. "%")
    Minimizer.Core.ApplyToAll()
end
