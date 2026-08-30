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
    if not frame then return nil end
    local name = frame:GetName()
    if name and _G[name .. "Text"] then return _G[name .. "Text"] end
    return frame.Text or nil
end

local function ResolveSpellName(spellID)
    if type(spellID) ~= "number" then return nil end
    if C_Spell then
        if C_Spell.GetSpellInfo then
            local info = C_Spell.GetSpellInfo(spellID)
            if info and type(info.name) == "string" and info.name ~= "" then return info.name end
        end
        if C_Spell.GetSpellName then
            local name = C_Spell.GetSpellName(spellID)
            if type(name) == "string" and name ~= "" then return name end
        end
    end
    return "Spell " .. tostring(spellID)
end

local function RequestFullUpdate()
    if Minimizer.Dispatcher and Minimizer.Dispatcher.RequestFullUpdate then
        Minimizer.Dispatcher.RequestFullUpdate()
    end
end

local function ApplyWheelConfig()
    if Minimizer.Wheel and Minimizer.Wheel.ApplyConfig then
        Minimizer.Wheel:ApplyConfig()
    end
end

local function CreateDropdown(frame, name, labelText, tableKey, dbKey)
    local dropdown = CreateFrame("Frame", name, frame, "UIDropDownMenuTemplate")
    dropdown:SetSize(210, 28)
    dropdown.label = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dropdown.label:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 16, 12)
    dropdown.label:SetText(labelText)

    UIDropDownMenu_Initialize(dropdown, function(self, level)
        local selectedValue = MinimizerCharDB and MinimizerCharDB[dbKey]
        local info = UIDropDownMenu_CreateInfo()
        info.text = "Automático"
        info.value = nil
        info.checked = selectedValue == nil
        info.func = function()
            if MinimizerCharDB then MinimizerCharDB[dbKey] = nil end
            if Minimizer.Widgets and Minimizer.Widgets.InvalidateCDSpellCache then Minimizer.Widgets.InvalidateCDSpellCache() end
            RequestFullUpdate()
            ApplyWheelConfig()
            Menu.Refresh()
        end
        UIDropDownMenu_AddButton(info)

        local classToken = GetClassToken()
        local source = Minimizer.Data and Minimizer.Data[tableKey] and Minimizer.Data[tableKey][classToken]
        if type(source) ~= "table" then return end
        for _, entry in ipairs(source) do
            local id
            local text
            if type(entry) == "number" then
                id = entry
                text = ResolveSpellName(id)
            elseif type(entry) == "table" and type(entry.id) == "number" then
                id = entry.id
                text = entry.name or ResolveSpellName(id)
            end
            if id then
                local option = UIDropDownMenu_CreateInfo()
                option.text = text
                option.value = id
                option.checked = selectedValue == id
                option.func = function()
                    if MinimizerCharDB then MinimizerCharDB[dbKey] = id end
                    if Minimizer.Widgets and Minimizer.Widgets.InvalidateCDSpellCache then Minimizer.Widgets.InvalidateCDSpellCache() end
                    RequestFullUpdate()
                    ApplyWheelConfig()
                    Menu.Refresh()
                end
                UIDropDownMenu_AddButton(option)
            end
        end
    end)

    dropdown.Refresh = function()
        local selectedValue = MinimizerCharDB and MinimizerCharDB[dbKey]
        if selectedValue == nil then
            UIDropDownMenu_SetText(dropdown, "Automático")
            return
        end
        local classToken = GetClassToken()
        local source = Minimizer.Data and Minimizer.Data[tableKey] and Minimizer.Data[tableKey][classToken]
        local foundName
        if type(source) == "table" then
            for _, entry in ipairs(source) do
                local id = (type(entry) == "number") and entry or (type(entry) == "table" and entry.id)
                if id == selectedValue then
                    if type(entry) == "table" then foundName = entry.name end
                    break
                end
            end
        end
        UIDropDownMenu_SetText(dropdown, foundName or ResolveSpellName(selectedValue))
    end

    dropdown.Refresh()
    return dropdown
end

local function CreateCheckbox(parent, name, label, anchor, yOffset, checked, onClick)
    local check = CreateFrame("CheckButton", name, parent, "ChatConfigCheckButtonTemplate")
    check:SetPoint("TOPLEFT", anchor or parent, anchor and "BOTTOMLEFT" or "TOPLEFT", 0, yOffset or 0)
    check:SetChecked(checked == true)
    check.text = GetWidgetText(check)
    if check.text then check.text:SetText(label) end
    check:SetScript("OnClick", onClick)
    return check
end

local function CreateSlider(parent, name, label, minValue, maxValue, step, value, anchor, onChanged)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetWidth(210)
    slider:SetHeight(40)
    slider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -14)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    local text = GetWidgetText(slider)
    local low = _G[name .. "Low"]
    local high = _G[name .. "High"]
    if low then low:SetText(tostring(minValue)) end
    if high then high:SetText(tostring(maxValue)) end

    local function SetLabel(value)
        if text then
            text:SetText(label .. ": " .. tostring(math.floor((tonumber(value) or 0) + 0.5)))
        end
    end

    slider._refreshing = false
    slider:SetScript("OnValueChanged", function(self, newValue)
        newValue = tonumber(newValue) or value
        SetLabel(newValue)
        if self._refreshing then return end
        onChanged(newValue)
    end)

    slider.Refresh = function(newValue)
        newValue = tonumber(newValue) or value
        SetLabel(newValue)
        slider._refreshing = true
        slider:SetValue(newValue)
        slider._refreshing = false
    end

    slider.Refresh(value)
    return slider
end

local LEGEND_SWATCH_SIZE = 14
local LEGEND_ROW_SPACING = 8

local function CreateLegendRow(parent, colorRGB, labelText, anchorFrame)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(LEGEND_SWATCH_SIZE)
    row:SetPoint("TOPLEFT", anchorFrame or parent, anchorFrame and "BOTTOMLEFT" or "TOPLEFT", 0,
        anchorFrame and -LEGEND_ROW_SPACING or 0)
    row:SetPoint("TOPRIGHT", anchorFrame or parent, anchorFrame and "BOTTOMRIGHT" or "TOPRIGHT", 0,
        anchorFrame and -LEGEND_ROW_SPACING or 0)

    local swatch = row:CreateTexture(nil, "ARTWORK")
    swatch:SetSize(LEGEND_SWATCH_SIZE, LEGEND_SWATCH_SIZE)
    swatch:SetPoint("LEFT", row, "LEFT", 0, 0)
    swatch:SetColorTexture(colorRGB[1], colorRGB[2], colorRGB[3], 1)

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", swatch, "RIGHT", 6, 0)
    label:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    label:SetJustifyH("LEFT")
    label:SetText(labelText)
    return row
end

local HEALTH_LEGEND_ENTRIES = {
    { key = "focus", label = "Focus" },
    { key = "aggro", label = "Aggro (tuyo)" },
    { key = "absorb", label = "Shield / Absorb" },
    { key = "boss", label = "Boss / Miniboss" },
    { key = "caster", label = "Caster (maná)" },
    { key = "melee", label = "Melee" },
    { key = "trivial", label = "Trivial" },
    { key = "castInterruptible", label = "Cast interrumpible" },
    { key = "superiorUninterruptible", label = "Cast ininterrumpible" },
}
local CAST_LEGEND_ENTRIES = {
    { key = "ready", label = "Interrupt listo" },
    { key = "channel", label = "Channeling interrupt cooldown" },
}

local function BuildLegend(legend)
    local sectionTitle = legend:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sectionTitle:SetPoint("TOPLEFT", legend, "TOPLEFT", 0, 0)
    sectionTitle:SetPoint("TOPRIGHT", legend, "TOPRIGHT", 0, 0)
    sectionTitle:SetJustifyH("LEFT")
    sectionTitle:SetText("Leyenda: nameplate")
    local lastRow = sectionTitle

    local healthColors = Minimizer.Constants and Minimizer.Constants.HealthColors or {}
    for _, entry in ipairs(HEALTH_LEGEND_ENTRIES) do
        local color = healthColors[entry.key]
        if color then lastRow = CreateLegendRow(legend, color, entry.label, lastRow) end
    end

    local castTitle = legend:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    castTitle:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 0, -16)
    castTitle:SetPoint("TOPRIGHT", lastRow, "BOTTOMRIGHT", 0, -16)
    castTitle:SetJustifyH("LEFT")
    castTitle:SetText("Leyenda: cast bar")
    lastRow = castTitle

    local castColors = Minimizer.Constants and Minimizer.Constants.CastColors or {}
    for _, entry in ipairs(CAST_LEGEND_ENTRIES) do
        local color = castColors[entry.key]
        if color then lastRow = CreateLegendRow(legend, color, entry.label, lastRow) end
    end
end

local function BuildPlaterTab(parent)
    local left = CreateFrame("Frame", nil, parent)
    left:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    left:SetWidth(210)
    left:SetPoint("BOTTOM", parent, "BOTTOM", 0, 0)

    local legend = CreateFrame("Frame", nil, parent)
    legend:SetPoint("TOPLEFT", parent, "TOPLEFT", 250, 0)
    legend:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    local divider = parent:GetParent():CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOP", legend, "TOPLEFT", -16, 0)
    divider:SetPoint("BOTTOM", legend, "BOTTOMLEFT", -16, 0)
    divider:SetWidth(1)
    divider:SetColorTexture(1, 1, 1, 0.15)

    local simplifyToggle = CreateCheckbox(left, "MinimizerMenuSimplifyToggle", "Enable simplify", nil, 0,
        Minimizer.Config and Minimizer.Config.IsSimplifyEnabled and Minimizer.Config.IsSimplifyEnabled(), function(self)
            if MinimizerDB then MinimizerDB.simplifyEnabled = self:GetChecked() end
            RequestFullUpdate()
        end)
    local targetMarkers = CreateCheckbox(left, nil, "Enable target markers", simplifyToggle, -10,
        MinimizerDB and MinimizerDB.enableTargetMarkers ~= false, function(self)
            if MinimizerDB then MinimizerDB.enableTargetMarkers = self:GetChecked() end
            RequestFullUpdate()
        end)
    local focusMarkers = CreateCheckbox(left, nil, "Enable focus markers", targetMarkers, -10,
        MinimizerDB and MinimizerDB.enableFocusMarkers ~= false, function(self)
            if MinimizerDB then MinimizerDB.enableFocusMarkers = self:GetChecked() end
            RequestFullUpdate()
        end)
    local faceToggle = CreateCheckbox(left, nil, "Focus face enabled", focusMarkers, -10,
        MinimizerDB and MinimizerDB.enableFocusFace == true, function(self)
            if Minimizer.Focus then Minimizer.Focus:SetFaceEnabled(self:GetChecked())
            elseif MinimizerDB then MinimizerDB.enableFocusFace = self:GetChecked() end
        end)
    local arrowsToggle = CreateCheckbox(left, nil, "Focus arrows enabled", faceToggle, -10,
        MinimizerDB and MinimizerDB.enableFocusArrows == true, function(self)
            if Minimizer.Focus then Minimizer.Focus:SetArrowsEnabled(self:GetChecked())
            elseif MinimizerDB then MinimizerDB.enableFocusArrows = self:GetChecked() end
        end)

    BuildLegend(legend)
    parent.controls = {
        simplifyToggle = simplifyToggle,
        targetMarkers = targetMarkers,
        focusMarkers = focusMarkers,
        faceToggle = faceToggle,
        arrowsToggle = arrowsToggle,
        legend = legend,
        divider = divider,
    }
end

local function BuildWheelTab(parent)
    local wheelToggle = CreateCheckbox(parent, "MinimizerMenuWheelToggle", "Enable Wheel", nil, 0,
        MinimizerDB and MinimizerDB.wheelEnabled ~= false, function(self)
            if MinimizerDB then MinimizerDB.wheelEnabled = self:GetChecked() end
            ApplyWheelConfig()
        end)

    local sizeSlider = CreateSlider(parent, "MinimizerMenuWheelSize", "Wheel size", 120, 300, 5,
        tonumber(MinimizerDB and MinimizerDB.wheelSize) or 180, wheelToggle, function(value)
            if MinimizerDB then MinimizerDB.wheelSize = value end
            ApplyWheelConfig()
        end)

    local radiusSlider = CreateSlider(parent, "MinimizerMenuWheelPipRadius", "Pip radius", 45, 105, 1,
        tonumber(MinimizerDB and MinimizerDB.wheelPipRadius) or 75, sizeSlider, function(value)
            if MinimizerDB then MinimizerDB.wheelPipRadius = value end
            ApplyWheelConfig()
        end)

    local slots = (Minimizer.Pips and Minimizer.Pips.SLOTS) or {}
    local dropdowns = {}
    for index, slot in ipairs(slots) do
        local slotId = slot.id or index
        local drop = CreateDropdown(parent, "MinimizerMenuPip" .. slotId .. "Drop", slot.name or ("Pip " .. slotId), "PIPS_SPELLS", "pip" .. slotId)
        if #dropdowns == 0 then
            drop:SetPoint("TOPLEFT", radiusSlider, "BOTTOMLEFT", 0, -12)
        else
            drop:SetPoint("TOPLEFT", dropdowns[#dropdowns], "BOTTOMLEFT", 0, -18)
        end
        table.insert(dropdowns, drop)
    end

    parent.controls = {
        wheelToggle = wheelToggle,
        sizeSlider = sizeSlider,
        radiusSlider = radiusSlider,
        dropdowns = dropdowns,
    }
end

local function SetTab(frame, tabName)
    frame.activeTab = tabName
    local plater = frame.tabs and frame.tabs.Plater
    local wheel = frame.tabs and frame.tabs.Wheel
    if not plater or not wheel then return end
    plater.panel:SetShown(tabName == "Plater")
    wheel.panel:SetShown(tabName == "Wheel")
    plater.button:SetEnabled(tabName ~= "Plater")
    wheel.button:SetEnabled(tabName ~= "Wheel")
end

local function BuildTab(frame, name, xOffset, builder)
    local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    button:SetSize(130, 24)
    button:SetPoint("TOP", frame, "TOP", xOffset, -42)
    button:SetText(name)

    local panel = CreateFrame("Frame", nil, frame)
    panel:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -76)
    panel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 18)
    builder(panel)
    button:SetScript("OnClick", function() SetTab(frame, name) end)
    return { button = button, panel = panel }
end

local function EnsureFrame()
    if Menu.frame then return Menu.frame end

    local frame = CreateFrame("Frame", "MinimizerMenuFrame", UIParent, "BackdropTemplate")
    frame:SetSize(520, 620)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 11, top = 11, bottom = 11 },
        })
        frame:SetBackdropColor(0, 0, 0, 0.92)
        frame:SetBackdropBorderColor(1, 1, 1, 1)
    end
    frame:SetScript("OnDragStart", function(self) if self:IsMovable() then self:StartMoving() end end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetUserPlaced(true)
        SaveMenuPosition(self)
    end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetText("Minimizer")
    title:SetPoint("TOP", frame, "TOP", 0, -16)

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    frame.tabs = {}
    frame.tabs.Plater = BuildTab(frame, "Plater", -70, BuildPlaterTab)
    frame.tabs.Wheel = BuildTab(frame, "Wheel", 70, BuildWheelTab)
    frame.MinimizerMenuControls = {
        plater = frame.tabs.Plater.panel.controls,
        wheel = frame.tabs.Wheel.panel.controls,
    }

    Menu.frame = frame
    ApplyMenuPosition(frame)
    SetTab(frame, "Plater")
    frame:Hide()
    return frame
end

function Menu.Refresh()
    local frame = EnsureFrame()
    local controls = frame and frame.MinimizerMenuControls
    if not controls then return end

    controls.plater.simplifyToggle:SetChecked(Minimizer.Config and Minimizer.Config.IsSimplifyEnabled and Minimizer.Config.IsSimplifyEnabled())
    controls.plater.targetMarkers:SetChecked(MinimizerDB and MinimizerDB.enableTargetMarkers ~= false)
    controls.plater.focusMarkers:SetChecked(MinimizerDB and MinimizerDB.enableFocusMarkers ~= false)
    controls.plater.faceToggle:SetChecked(MinimizerDB and MinimizerDB.enableFocusFace == true)
    controls.plater.arrowsToggle:SetChecked(MinimizerDB and MinimizerDB.enableFocusArrows == true)

    controls.wheel.wheelToggle:SetChecked(MinimizerDB and MinimizerDB.wheelEnabled ~= false)
    controls.wheel.sizeSlider:Refresh(tonumber(MinimizerDB and MinimizerDB.wheelSize) or 180)
    controls.wheel.radiusSlider:Refresh(tonumber(MinimizerDB and MinimizerDB.wheelPipRadius) or 75)
    for _, dropdown in ipairs(controls.wheel.dropdowns or {}) do
        if dropdown.Refresh then dropdown.Refresh() end
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
