local _, Minimizer = ...
if not Minimizer then return end

local Marks = {}
Minimizer.Marks = Marks

local active = false
local generation = 0
local ticker

local PARTY_TOKENS = { "party1", "party2", "party3", "party4" }

local function IsMouseoverPartyUnit(unit)
    if not unit or not UnitExists(unit) then return false end
    if not UnitExists("mouseover") then return false end
    return UnitIsUnit("mouseover", unit) == true
end

local function EnsureMarker(nameplate)
    if not nameplate then return nil end
    if nameplate.MinimizerMarksSquare then
        return nameplate.MinimizerMarksSquare
    end

    local parent = nameplate.UnitFrame or nameplate
    local marker = CreateFrame("Frame", nil, parent)
    marker:SetSize(24, 24)
    marker:SetPoint("TOP", parent, "TOP", 0, 2)
    marker:SetFrameStrata("TOOLTIP")
    marker:SetFrameLevel(math.min(parent:GetFrameLevel() + 20, 9999))

    local texture = marker:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints()
    texture:SetColorTexture(1, 1, 1, 1)

    marker.texture = texture
    marker:Hide()
    nameplate.MinimizerMarksSquare = marker
    return marker
end

local function FindMouseoverPartyUnit()
    if not UnitExists("mouseover") then return nil end

    for i = 1, #PARTY_TOKENS do
        local unit = PARTY_TOKENS[i]
        if IsMouseoverPartyUnit(unit) then
            return unit
        end
    end

    return nil
end

-- C_NamePlate.GetNamePlateForUnit() rechaza party/raid tokens.
-- Por eso buscamos entre las nameplates visibles y comparamos su unidad.
local function FindNamePlateForPartyUnit(partyUnit)
    if not partyUnit then return nil end

    local plates = C_NamePlate.GetNamePlates()
    for i = 1, #plates do
        local nameplate = plates[i]
        local token = nameplate and nameplate.namePlateUnitToken

        if token and UnitExists(token) and UnitIsUnit(token, partyUnit) == true then
            return nameplate
        end

        -- Fallback para clientes/layouts donde el token no está expuesto
        -- directamente en namePlateUnitToken.
        local unitFrame = nameplate and nameplate.UnitFrame
        local frameToken = unitFrame and unitFrame.unit
        if frameToken and UnitExists(frameToken) and UnitIsUnit(frameToken, partyUnit) == true then
            return nameplate
        end
    end

    return nil
end

local function Update()
    if not active then return end

    local partyUnit = FindMouseoverPartyUnit()
    if not partyUnit then return end

    local nameplate = FindNamePlateForPartyUnit(partyUnit)
    if not nameplate then return end

    local marker = EnsureMarker(nameplate)
    if marker then
        marker:Show()
    end
end

function Marks:Start()
    generation = generation + 1
    local myGeneration = generation
    active = true

    if ticker then
        ticker:Cancel()
        ticker = nil
    end

    Update()

    ticker = C_Timer.NewTicker(0.05, function()
        if not active or myGeneration ~= generation then return end
        Update()
    end)

    C_Timer.After(5, function()
        if myGeneration ~= generation then return end

        active = false
        if ticker then
            ticker:Cancel()
            ticker = nil
        end

        -- Los cuadrados ya colocados NO se ocultan: son permanentes.
        -- Desde aquí no se vuelve a comprobar el mouseover.
    end)
end

-- /mini ya existe en SlashCommands.lua. Lo envolvemos para añadir únicamente
-- el subcomando "marks" sin romper los comandos existentes.
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
