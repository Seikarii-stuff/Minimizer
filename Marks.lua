local _, Minimizer = ...
if not Minimizer then return end

local Marks = {}
Minimizer.Marks = Marks

local marker

local function EnsureMarker()
    if marker then return marker end

    local parent = UIParent
    marker = CreateFrame("Frame", "MinimizerTargetMark", parent)
    marker:SetSize(32, 32)
    marker:SetFrameStrata("TOOLTIP")
    marker:SetFrameLevel(9999)

    local texture = marker:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints()
    texture:SetColorTexture(1, 1, 1, 1)
    marker.texture = texture

    return marker
end

local function UpdateTargetMark()
    local target = UnitExists("target") and UnitGUID("target")
    if not target then
        if marker then marker:Hide() end
        return
    end

    local nameplate = C_NamePlate.GetNamePlateForUnit("target")
    if not nameplate then
        if marker then marker:Hide() end
        return
    end

    local targetFrame = nameplate.UnitFrame or nameplate
    local anchor = targetFrame.healthBar or targetFrame.HealthBar or targetFrame

    local mark = EnsureMarker()
    mark:ClearAllPoints()
    mark:SetPoint("TOP", anchor, "TOP", 0, 8)
    mark:Show()
end

function Marks:Start()
    -- Se invoca con /mini marks y, desde ese momento, el target actual queda marcado.
    -- No hay escaneo de party ni ventana temporal.
    UpdateTargetMark()
end

-- Mantener el comando /mini existente y añadir solo el subcomando marks.
local previousSlashHandler = SlashCmdList["MINIMIZER"]
SlashCmdList["MINIMIZER"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")

    if msg == "marks" then
        Marks:Start()
        return
    end

    if previousSlashHandler then
        previousSlashHandler(msg)
    end
end
