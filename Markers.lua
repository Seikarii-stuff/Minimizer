local _, Minimizer = ...
if not Minimizer or not Minimizer.Core then return end

local Markers = {}
Minimizer.Markers = Markers

local UnitExists = UnitExists
local UnitIsUnit = UnitIsUnit

function Markers.Ensure(nameplate)
    if not nameplate then return nil end
    if nameplate.MinimizerMarkers then return nameplate.MinimizerMarkers end

    local uf = nameplate.UnitFrame or nameplate
    local anchor = uf.healthBar or uf.HealthBar or uf

    local function CreateArrow(text, point, relPoint, xOff, yOff, r, g, b)
        local fs = uf:CreateFontString(nil, "OVERLAY")
        fs:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
        fs:SetPoint(point, anchor, relPoint, xOff, yOff)
        fs:SetText(text)
        fs:SetTextColor(r or 1, g or 1, b or 1)
        fs:Hide()
        return fs
    end

    local markers = {
        targetLeft  = CreateArrow(">>", "RIGHT", "LEFT",  -2,  4, 1, 1, 1),
        targetRight = CreateArrow("<<", "LEFT",  "RIGHT",  2,  4, 1, 1, 1),
        focusLeft   = CreateArrow(">>", "RIGHT", "LEFT",  -2, -4, 1, 1, 0),
        focusRight  = CreateArrow("<<", "LEFT",  "RIGHT",  2, -4, 1, 1, 0),
    }

    nameplate.MinimizerMarkers = markers
    return markers
end

function Markers:UpdateNamePlate(unit, nameplate)
    local markers = Markers.Ensure(nameplate)
    if not markers then return end

    local token = Minimizer.Utils.GetValidNamePlateToken(unit, nameplate) or unit
    if not token or not UnitExists(token) then 
        markers.targetLeft:Hide()
        markers.targetRight:Hide()
        markers.focusLeft:Hide()
        markers.focusRight:Hide()
        return 
    end

    local isTarget = (MinimizerDB.enableTargetMarkers ~= false) and UnitIsUnit(token, "target")
    local isFocus  = (MinimizerDB.enableFocusMarkers ~= false) and UnitIsUnit(token, "focus")

    markers.targetLeft:SetShown(isTarget == true)
    markers.targetRight:SetShown(isTarget == true)
    local showFocusArrows = MinimizerDB.focusIndicator ~= "face"
    markers.focusLeft:SetShown(isFocus == true and showFocusArrows)
    markers.focusRight:SetShown(isFocus == true and showFocusArrows)
end

function Markers:OnNamePlateRemoved(unit, nameplate)
    local markers = nameplate and nameplate.MinimizerMarkers
    if not markers then return end
    markers.targetLeft:Hide()
    markers.targetRight:Hide()
    markers.focusLeft:Hide()
    markers.focusRight:Hide()
end

Minimizer.Core.RegisterModule("Markers", Markers)
