local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Menu = Minimizer.Menu or {}
local Menu = Minimizer.Menu

local function GetClassToken()
    local _, classToken = UnitClass("player")
    return classToken
end

local function GetSavedPosition()
    local position = MinimizerDB and MinimizerDB.menuPosition or {}
    return {
        point = position.point or "CENTER",
        relativePoint = position.relativePoint or "CENTER",
        x = position.x or 0,
        y = position.y or 0,
    }
end

local function ApplyMenuPosition(frame)
    local position = GetSavedPosition()
    frame:ClearAllPoints()
    frame:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
end

local function SaveMenuPosition(frame)
    if not MinimizerDB then return end
    local point, _, relativePoint, x, y = frame:GetPoint()
    MinimizerDB.menuPosition = {
        point = point or "CENTER",
        relativePoint = relativePoint or "CENTER",
        x = x or 0,
        y = y or 0,
    }
end

local function GetWidgetText(frame)
    if not frame then
        return nil
    end
    local name = frame:GetName()
    if name and _G[name .. "Text"] then
        return _G[name .. "Text"]
    end
    return frame.Text or nil
end

local function BuildSpellOptions(tableKey)
    local classToken = GetClassToken()
    local source = Minimizer.Data and Minimizer.Data[tableKey] and Minimizer.Data[tableKey][classToken]
    local options = {
        { text = "Automático", value = nil },
    }
    if type(source) ~= "table" then
        return options
    end
    for _, spellID in ipairs(source) do
        local spellName = GetSpellInfo and GetSpellInfo(spellID) or ("Spell " .. tostring(spellID))
        table.insert(options, { text = spellName, value = spellID })
    end
    return options
end

local function CreateDropdown(frame, name, labelText, tableKey, dbKey)
    -- Interface 120100 sigue aceptando la API clásica UIDropDownMenuTemplate como la
    -- opción recomendada para menús simples, por compatibilidad y estabilidad con el
    -- resto de addons. No usamos MenuUtil/Selection templates aquí para evitar una
    -- dependencia innecesaria de un patrón más nuevo en un addon pequeño y legacy-safe.
    local dropdown = CreateFrame("Frame", name, frame, "UIDropDownMenuTemplate")
    dropdown:SetSize(160, 28)
    dropdown.label = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dropdown.label:SetPoint("BOTTOMLEFT", dropdown, "TOPLEFT", 18, 2)
    dropdown.label:SetText(labelText)

    dropdown.dbKey = dbKey
    dropdown.tableKey = tableKey

    dropdown.initialize = function()
        local selectedValue = MinimizerCharDB and MinimizerCharDB[dbKey]
        local info = UIDropDownMenu_CreateInfo()
        info.text = "Automático"
        info.value = nil
        info.checked = selectedValue == nil
        info.func = function()
            if MinimizerCharDB then MinimizerCharDB[dbKey] = nil end
            if Minimizer.Widgets and Minimizer.Widgets.InvalidateCDSpellCache then
                Minimizer.Widgets.InvalidateCDSpellCache()
            end
            if Minimizer.Core then Minimizer.Core.ApplyToAll() end
            Menu.Refresh()
        end
        UIDropDownMenu_AddButton(info)

        local options = BuildSpellOptions(tableKey)
        for _, entry in ipairs(options) do
            if entry.value ~= nil then
                local info2 = UIDropDownMenu_CreateInfo()
                info2.text = entry.text
                info2.value = entry.value
                info2.checked = selectedValue == entry.value
                info2.func = function()
                    if MinimizerCharDB then MinimizerCharDB[dbKey] = entry.value end
                    if Minimizer.Widgets and Minimizer.Widgets.InvalidateCDSpellCache then
                        Minimizer.Widgets.InvalidateCDSpellCache()
                    end
                    if Minimizer.Core then Minimizer.Core.ApplyToAll() end
                    Menu.Refresh()
                end
                UIDropDownMenu_AddButton(info2)
            end
        end
    end

    dropdown.Refresh = function()
        local selectedValue = MinimizerCharDB and MinimizerCharDB[dbKey]
        if selectedValue == nil then
            UIDropDownMenu_SetText(dropdown, "Automático")
            return
        end
        local foundName = GetSpellInfo and GetSpellInfo(selectedValue) or ("Spell " .. tostring(selectedValue))
        UIDropDownMenu_SetText(dropdown, foundName)
    end

    UIDropDownMenu_Initialize(dropdown, dropdown.initialize)
    dropdown.Refresh()
    return dropdown
end

local function EnsureFrame()
    if Menu.frame then
        return Menu.frame
    end

    local frame = CreateFrame("Frame", "MinimizerMenuFrame", UIParent)
    frame:SetSize(300, 250)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 11, top = 11, bottom = 11 },
        })
    end
    frame:SetScript("OnDragStart", function(self)
        if self:IsMovable() then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetUserPlaced(true)
        SaveMenuPosition(self)
    end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetText("Minimizer")
    title:SetPoint("TOP", frame, "TOP", 0, -16)

    local slider = CreateFrame("Slider", "MinimizerMenuSimplifySlider", frame, "OptionsSliderTemplate")
    slider:SetMinMaxValues(0, 100)
    slider:SetValueStep(1)
    slider:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -40)
    slider:SetWidth(240)
    slider:SetValue((MinimizerDB and MinimizerDB.simplifyPercent) or 0)
    local sliderText = GetWidgetText(slider)
    if sliderText then
        sliderText:SetText("Simplify %")
    end
    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value)
        if MinimizerDB then MinimizerDB.simplifyPercent = value end
        if Minimizer.Core then Minimizer.Core.ApplyToAll() end
        if slider.valueText then
            slider.valueText:SetText(value .. "%")
        end
    end)
    local sliderValueText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sliderValueText:SetPoint("RIGHT", slider, "RIGHT", -6, 0)
    sliderValueText:SetText(tostring(slider:GetValue()) .. "%")
    slider.valueText = sliderValueText

    local targetMarkers = CreateFrame("CheckButton", nil, frame, "ChatConfigCheckButtonTemplate")
    targetMarkers:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -20)
    targetMarkers:SetChecked(MinimizerDB and MinimizerDB.enableTargetMarkers ~= false)
    targetMarkers.text = GetWidgetText(targetMarkers)
    if targetMarkers.text then
        targetMarkers.text:SetText("Enable target markers")
    end
    targetMarkers:SetScript("OnClick", function(self)
        if MinimizerDB then MinimizerDB.enableTargetMarkers = self:GetChecked() end
        if Minimizer.Core then Minimizer.Core.ApplyToAll() end
    end)

    local focusMarkers = CreateFrame("CheckButton", nil, frame, "ChatConfigCheckButtonTemplate")
    focusMarkers:SetPoint("TOPLEFT", targetMarkers, "BOTTOMLEFT", 0, -10)
    focusMarkers:SetChecked(MinimizerDB and MinimizerDB.enableFocusMarkers ~= false)
    focusMarkers.text = GetWidgetText(focusMarkers)
    if focusMarkers.text then
        focusMarkers.text:SetText("Enable focus markers")
    end
    focusMarkers:SetScript("OnClick", function(self)
        if MinimizerDB then MinimizerDB.enableFocusMarkers = self:GetChecked() end
        if Minimizer.Core then Minimizer.Core.ApplyToAll() end
    end)

    local faceToggle = CreateFrame("CheckButton", nil, frame, "ChatConfigCheckButtonTemplate")
    faceToggle:SetPoint("TOPLEFT", focusMarkers, "BOTTOMLEFT", 0, -10)
    faceToggle:SetChecked(MinimizerDB and MinimizerDB.enableFocusFace == true)
    faceToggle.text = GetWidgetText(faceToggle)
    if faceToggle.text then
        faceToggle.text:SetText("Focus face enabled")
    end
    faceToggle:SetScript("OnClick", function(self)
        if Minimizer.Focus then
            Minimizer.Focus:SetFaceEnabled(self:GetChecked())
        else
            if MinimizerDB then MinimizerDB.enableFocusFace = self:GetChecked() end
        end
    end)

    local arrowsToggle = CreateFrame("CheckButton", nil, frame, "ChatConfigCheckButtonTemplate")
    arrowsToggle:SetPoint("TOPLEFT", faceToggle, "BOTTOMLEFT", 0, -10)
    arrowsToggle:SetChecked(MinimizerDB and MinimizerDB.enableFocusArrows == true)
    arrowsToggle.text = GetWidgetText(arrowsToggle)
    if arrowsToggle.text then
        arrowsToggle.text:SetText("Focus arrows enabled")
    end
    arrowsToggle:SetScript("OnClick", function(self)
        if Minimizer.Focus then
            Minimizer.Focus:SetArrowsEnabled(self:GetChecked())
        else
            if MinimizerDB then MinimizerDB.enableFocusArrows = self:GetChecked() end
        end
    end)

    local dropdowns = {
        CreateDropdown(frame, "MinimizerMenuTargetOffensiveDrop", "Target offensive CD", "OFFENSIVE_CDS", "targetOffensive"),
        CreateDropdown(frame, "MinimizerMenuTargetDefensiveDrop", "Target defensive CD", "DEFENSIVE_CDS", "targetDefensive"),
        CreateDropdown(frame, "MinimizerMenuFocusCCDrop", "Focus mass CC", "MASS_CC_SPELLS", "focusCC"),
    }

    dropdowns[1]:SetPoint("TOPLEFT", arrowsToggle, "BOTTOMLEFT", 0, -20)
    dropdowns[2]:SetPoint("TOPLEFT", dropdowns[1], "BOTTOMLEFT", 0, -18)
    dropdowns[3]:SetPoint("TOPLEFT", dropdowns[2], "BOTTOMLEFT", 0, -18)

    frame.MinimizerMenuControls = {
        slider = slider,
        targetMarkers = targetMarkers,
        focusMarkers = focusMarkers,
        faceToggle = faceToggle,
        arrowsToggle = arrowsToggle,
        dropdowns = dropdowns,
    }

    Menu.frame = frame
    ApplyMenuPosition(frame)
    frame:Hide()
    return frame
end

function Menu.Refresh()
    local frame = EnsureFrame()
    if not frame then return end
    if frame.MinimizerMenuControls and frame.MinimizerMenuControls.slider then
        frame.MinimizerMenuControls.slider:SetValue((MinimizerDB and MinimizerDB.simplifyPercent) or 0)
        if frame.MinimizerMenuControls.slider.valueText then
            frame.MinimizerMenuControls.slider.valueText:SetText(tostring(frame.MinimizerMenuControls.slider:GetValue()) .. "%")
        end
    end
    if frame.MinimizerMenuControls then
        frame.MinimizerMenuControls.targetMarkers:SetChecked(MinimizerDB and MinimizerDB.enableTargetMarkers ~= false)
        frame.MinimizerMenuControls.focusMarkers:SetChecked(MinimizerDB and MinimizerDB.enableFocusMarkers ~= false)
        frame.MinimizerMenuControls.faceToggle:SetChecked(MinimizerDB and MinimizerDB.enableFocusFace == true)
        frame.MinimizerMenuControls.arrowsToggle:SetChecked(MinimizerDB and MinimizerDB.enableFocusArrows == true)
    end
    for _, dropdown in ipairs(frame.MinimizerMenuControls and frame.MinimizerMenuControls.dropdowns or {}) do
        if dropdown and dropdown.Refresh then
            dropdown.Refresh()
        end
    end
end

function Menu.Toggle()
    local frame = EnsureFrame()
    if not frame then return end
    if frame:IsShown() then
        frame:Hide()
    else
        Menu.Refresh()
        frame:Show()
    end
end

function Menu.Open()
    local frame = EnsureFrame()
    if not frame then return end
    Menu.Refresh()
    frame:Show()
end

function Menu.Close()
    local frame = Menu.frame
    if frame then frame:Hide() end
end

function Menu.IsOpen()
    return Menu.frame and Menu.frame:IsShown() == true
end

Menu.frame = nil
