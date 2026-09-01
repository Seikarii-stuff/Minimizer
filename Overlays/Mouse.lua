local _, Minimizer = ...
if not Minimizer then return end

local Mouse = {}
Minimizer.Mouse = Mouse

local GetCursorPosition = GetCursorPosition
local UIParent = UIParent

local HALO_SIZE = 46
local CURSOR_UPDATE_INTERVAL = 0.006944

local host = CreateFrame("Frame", "MinimizerMouseHost", UIParent)
host:SetSize(HALO_SIZE, HALO_SIZE)
host:SetFrameStrata("HIGH")
host:EnableMouse(false)
host:Hide()

local haloFrame = Minimizer.Halo.Create(host, {
    name = "MinimizerMouseHalo",
    size = HALO_SIZE,
    color = { 0.20, 0.55, 1.00 },
})
haloFrame:SetPoint("CENTER", host, "CENTER")
if haloFrame.MinimizerHaloCooldown then
    haloFrame.MinimizerHaloCooldown:Hide()
end

local cursorElapsed = 0
local enabled = false
local lastCursorX, lastCursorY

local function UpdateCursorPosition()
    local cursorX, cursorY = GetCursorPosition()
    if not cursorX or not cursorY then return end
    if cursorX == lastCursorX and cursorY == lastCursorY then return end

    local scale = UIParent:GetEffectiveScale()
    if not scale or scale <= 0 then return end

    lastCursorX, lastCursorY = cursorX, cursorY
    host:ClearAllPoints()
    host:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cursorX / scale, cursorY / scale)
end

local function OnUpdate(_, elapsed)
    cursorElapsed = cursorElapsed + elapsed
    if cursorElapsed < CURSOR_UPDATE_INTERVAL then return end
    cursorElapsed = 0
    UpdateCursorPosition()
end

function Mouse:SetEnabled(value)
    enabled = value == true
    if not enabled then
        host:SetScript("OnUpdate", nil)
        host:Hide()
        haloFrame:Hide()
        return
    end
    host:Show()
    haloFrame:Show()
    cursorElapsed = 0
    lastCursorX, lastCursorY = nil, nil
    UpdateCursorPosition()
    host:SetScript("OnUpdate", OnUpdate)
end

function Mouse:ApplyConfig()
    local desired = MinimizerDB and MinimizerDB.enableMouseHalo
    if desired == nil then desired = true end
    if enabled == (desired == true) then return end
    self:SetEnabled(desired == true)
end

if Minimizer.Overlays and Minimizer.Overlays.Register then
    Minimizer.Overlays.Register("Mouse", Mouse)
end
