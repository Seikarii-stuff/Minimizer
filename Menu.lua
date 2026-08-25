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

local function BuildSpellOptions(tableKey)
    local classToken = GetClassToken()
    local source = Minimizer.Data and Minimizer.Data[tableKey] and Minimizer.Data[tableKey][classToken]
    local options = { { text = "Automático", value = nil } }
    if type(source) ~= "table" then return options end
    for _, entry in ipairs(source) do
        if type(entry) == "number" then
            table.insert(options, { text = ResolveSpellName(entry), value = entry })
        elseif type(entry) == "table" and type(entry.id) == "number" then
            table.insert(options, { text = entry.name or ResolveSpellName(entry.id), value = entry.id })
        end
    end
    return options
end

local function RequestFullUpdate()
    if Minimizer.Dispatcher and Minimizer.Dispatcher.RequestFullUpdate then
        Minimizer.Dispatcher.RequestFullUpdate()
    end
    if Minimizer.MyDebuff and Minimizer.MyDebuff.UpdateAll then
        Minimizer.MyDebuff:UpdateAll()
    end
end

local function CreateDropdown(frame, name, labelText, tableKey, dbKey)
    local dropdown = CreateFrame("Frame", name, frame, "UIDropDownMenuTemplate")
    dropdown:SetSize(160, 28)
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
            Menu.Refresh()
        end
        UIDropDownMenu_AddButton(info)

        for _, entry in ipairs(BuildSpellOptions(tableKey)) do
            if entry.value ~= nil then
                local info2 = UIDropDownMenu_CreateInfo()
                info2.text = entry.text
                info2.value = entry.value
                info2.checked = selectedValue == entry.value
                info2.func = function()
                    if MinimizerCharDB then MinimizerCharDB[dbKey] = entry.value end
                    if Minimizer.Widgets and Minimizer.Widgets.InvalidateCDSpellCache then Minimizer.Widgets.InvalidateCDSpellCache() end
                    RequestFullUpdate()
                    Menu.Refresh()
                end
                UIDropDownMenu_AddButton(info2)
            end
        end
    end)

    dropdown.Refresh = function()
        local selectedValue = MinimizerCharDB and MinimizerCharDB[dbKey]
        if selectedValue == nil then
            UIDropDownMenu_SetText(dropdown, "Automático")
            return
        end
        UIDropDownMenu_SetText(dropdown, ResolveSpellName(selectedValue))
    end

    dropdown.Refresh()
    return dropdown
end

local LEGEND_SWATCH_SIZE = 14
local LEGEND_ROW_SPACING = 8

local function CreateLegendRow(parent, colorRGB, labelText, anchorFrame)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(LEGEND_SWATCH_SIZE)
    if anchorFrame then
        row:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -LEGEND_ROW_SPACING)
        row:SetPoint("TOPRIGHT", anchorFrame, "BOTTOMRIGHT", 0, -LEGEND_ROW_SPACING)
    else
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
        row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    end
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

local function EnsureFrame()
    if Menu.frame then return Menu.frame end

    local FRAME_WIDTH = 460
    local FRAME_HEIGHT = 400
    local CONTENT_WIDTH = 230
    local frame = CreateFrame("Frame", "MinimizerMenuFrame", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
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

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -36)
    content:SetSize(CONTENT_WIDTH, FRAME_HEIGHT - 50)

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    local simplifyToggle = CreateFrame("CheckButton", "MinimizerMenuSimplifyToggle", content, "ChatConfigCheckButtonTemplate")
    simplifyToggle:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -40)
    simplifyToggle.text = GetWidgetText(simplifyToggle)
    if simplifyToggle.text then simplifyToggle.text:SetText("Enable simplify") end
    simplifyToggle:SetChecked(Minimizer.Config and Minimizer.Config.IsSimplifyEnabled and Minimizer.Config.IsSimplifyEnabled())
    simplifyToggle:SetScript("OnClick", function(self)
        if MinimizerDB then MinimizerDB.simplifyEnabled = self:GetChecked() end
        RequestFullUpdate()
    end)

    local targetMarkers = CreateFrame("CheckButton", nil, content, "ChatConfigCheckButtonTemplate")
    targetMarkers:SetPoint("TOPLEFT", simplifyToggle, "BOTTOMLEFT", 0, -20)
    targetMarkers:SetChecked(MinimizerDB and MinimizerDB.enableTargetMarkers ~= false)
    targetMarkers.text = GetWidgetText(targetMarkers)
    if targetMarkers.text then targetMarkers.text:SetText("Enable target markers") end
    targetMarkers:SetScript("OnClick", function(self)
        if MinimizerDB then MinimizerDB.enableTargetMarkers = self:GetChecked() end
        RequestFullUpdate()
    end)

    local focusMarkers = CreateFrame("CheckButton", nil, content, "ChatConfigCheckButtonTemplate")
    focusMarkers:SetPoint("TOPLEFT", targetMarkers, "BOTTOMLEFT", 0, -10)
    focusMarkers:SetChecked(MinimizerDB and MinimizerDB.enableFocusMarkers ~= false)
    focusMarkers.text = GetWidgetText(focusMarkers)
    if focusMarkers.text then focusMarkers.text:SetText("Enable focus markers") end
    focusMarkers:SetScript("OnClick", function(self)
        if MinimizerDB then MinimizerDB.enableFocusMarkers = self:GetChecked() end
        RequestFullUpdate()
    end)

    local myDebuffToggle = CreateFrame("CheckButton", nil, content, "ChatConfigCheckButtonTemplate")
    myDebuffToggle:SetPoint("TOPLEFT", focusMarkers, "BOTTOMLEFT", 0, -10)
    myDebuffToggle:SetChecked(MinimizerDB and MinimizerDB.enableMyDebuffOverlay == true)
    myDebuffToggle.text = GetWidgetText(myDebuffToggle)
    if myDebuffToggle.text then myDebuffToggle.text:SetText("Overlay naranja si tiene perjuicios (míos)") end
    myDebuffToggle:SetScript("OnClick", function(self)
        if MinimizerDB then MinimizerDB.enableMyDebuffOverlay = self:GetChecked() end
        RequestFullUpdate()
    end)

    local faceToggle = CreateFrame("CheckButton", nil, content, "ChatConfigCheckButtonTemplate")
    faceToggle:SetPoint("TOPLEFT", myDebuffToggle, "BOTTOMLEFT", 0, -10)
    faceToggle:SetChecked(MinimizerDB and MinimizerDB.enableFocusFace == true)
    faceToggle.text = GetWidgetText(faceToggle)
    if faceToggle.text then faceToggle.text:SetText("Focus face enabled") end
    faceToggle:SetScript("OnClick", function(self)
        if Minimizer.Focus then Minimizer.Focus:SetFaceEnabled(self:GetChecked()) elseif MinimizerDB then MinimizerDB.enableFocusFace = self:GetChecked() end
    end)

    local arrowsToggle = CreateFrame("CheckButton", nil, content, "ChatConfigCheckButtonTemplate")
    arrowsToggle:SetPoint("TOPLEFT", faceToggle, "BOTTOMLEFT", 0, -10)
    arrowsToggle:SetChecked(MinimizerDB and MinimizerDB.enableFocusArrows == true)
    arrowsToggle.text = GetWidgetText(arrowsToggle)
    if arrowsToggle.text then arrowsToggle.text:SetText("Focus arrows enabled") end
    arrowsToggle:SetScript("OnClick", function(self)
        if Minimizer.Focus then Minimizer.Focus:SetArrowsEnabled(self:GetChecked()) elseif MinimizerDB then MinimizerDB.enableFocusArrows = self:GetChecked() end
    end)

    local slots = (Minimizer.Pips and Minimizer.Pips.SLOTS) or {{ id = 1, name = "Pip 1" }, { id = 2, name = "Pip 2" }}
    local dropdowns = {}
    for index, slot in ipairs(slots) do
        local slotId = slot.id or index
        local drop = CreateDropdown(content, "MinimizerMenuPip" .. slotId .. "Drop", slot.name or ("Pip " .. slotId), "PIPS_SPELLS", "pip" .. slotId)
        if #dropdowns == 0 then drop:SetPoint("TOPLEFT", arrowsToggle, "BOTTOMLEFT", 0, -20) else drop:SetPoint("TOPLEFT", dropdowns[#dropdowns], "BOTTOMLEFT", 0, -18) end
        table.insert(dropdowns, drop)
    end

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOP", content, "TOPRIGHT", 9, 2)
    divider:SetPoint("BOTTOM", content, "BOTTOMRIGHT", 9, 0)
    divider:SetWidth(1)
    divider:SetColorTexture(1, 1, 1, 0.15)

    local legend = CreateFrame("Frame", nil, frame)
    legend:SetPoint("TOPLEFT", content, "TOPRIGHT", 18, 0)
    legend:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 14)
    BuildLegend(legend)

    frame.MinimizerMenuControls = {
        simplifyToggle = simplifyToggle,
        targetMarkers = targetMarkers,
        focusMarkers = focusMarkers,
        myDebuffToggle = myDebuffToggle,
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
    local controls = frame.MinimizerMenuControls
    if not controls then return end
    controls.simplifyToggle:SetChecked(Minimizer.Config and Minimizer.Config.IsSimplifyEnabled and Minimizer.Config.IsSimplifyEnabled())
    controls.targetMarkers:SetChecked(MinimizerDB and MinimizerDB.enableTargetMarkers ~= false)
    controls.focusMarkers:SetChecked(MinimizerDB and MinimizerDB.enableFocusMarkers ~= false)
    controls.myDebuffToggle:SetChecked(MinimizerDB and MinimizerDB.enableMyDebuffOverlay == true)
    controls.faceToggle:SetChecked(MinimizerDB and MinimizerDB.enableFocusFace == true)
    controls.arrowsToggle:SetChecked(MinimizerDB and MinimizerDB.enableFocusArrows == true)
    for _, dropdown in ipairs(controls.dropdowns or {}) do
        if dropdown and dropdown.Refresh then dropdown.Refresh() end
    end
end

function Menu.Toggle()
    local frame = EnsureFrame()
    if not frame then return end
    if frame:IsShown() then frame:Hide() else Menu.Refresh(); frame:Show() end
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
