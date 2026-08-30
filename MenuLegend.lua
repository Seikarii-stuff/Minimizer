local _, Minimizer = ...
if not Minimizer or not Minimizer.Menu then return end

local Menu = Minimizer.Menu
local originalOpen = Menu.Open
local originalToggle = Menu.Toggle

local function FixLegend()
    local frame = Menu.frame
    local controls = frame and frame.MinimizerMenuControls
    local legend = controls and controls.plater and controls.plater.legend
    if not frame or not legend then return end

    legend:ClearAllPoints()
    legend:SetPoint("TOPLEFT", frame, "TOPLEFT", 278, -76)
    legend:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 18)

    if not frame.MinimizerMenuLegendDivider then
        local divider = frame:CreateTexture(nil, "ARTWORK")
        divider:SetPoint("TOP", legend, "TOPLEFT", -14, 2)
        divider:SetPoint("BOTTOM", legend, "BOTTOMLEFT", -14, 0)
        divider:SetWidth(1)
        divider:SetColorTexture(1, 1, 1, 0.15)
        frame.MinimizerMenuLegendDivider = divider
    end
end

function Menu.Open(...)
    local result = originalOpen(...)
    FixLegend()
    return result
end

function Menu.Toggle(...)
    local result = originalToggle(...)
    FixLegend()
    return result
end
