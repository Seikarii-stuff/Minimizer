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
    
    if msg == "test" then
        print("|cff33ff99Minimizer|r: Iniciando tests sintéticos in-client...")
        
        local mockNameplate = CreateFrame("Frame")
        mockNameplate.namePlateUnitToken = "player"
        local mockUnitFrame = CreateFrame("Frame", nil, mockNameplate)
        mockUnitFrame.healthBar = CreateFrame("StatusBar", nil, mockUnitFrame)
        mockNameplate.UnitFrame = mockUnitFrame
        
        local passed = true
        
        local ok, err = pcall(function()
            Minimizer.Core.ApplyToUnit("player", mockNameplate)
        end)
        
        if not ok then
            print("|cffff4444[Error]|r ApplyToUnit falló: " .. tostring(err))
            passed = false
        end
        
        local ok2, err2 = pcall(function()
            if Minimizer.Cache and Minimizer.Cache.InvalidateAll then
                Minimizer.Cache.InvalidateAll("threat")
            end
        end)
        
        if not ok2 then
            print("|cffff4444[Error]|r InvalidateAll falló: " .. tostring(err2))
            passed = false
        end
        
        local ok3, err3 = pcall(function()
            Minimizer.Core.ClearNeverSimplify("player")
        end)
        
        if not ok3 then
            print("|cffff4444[Error]|r ClearNeverSimplify falló: " .. tostring(err3))
            passed = false
        end
        
        if passed then
            print("|cff33ff99Minimizer|r: Todos los tests sintéticos pasaron.")
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
