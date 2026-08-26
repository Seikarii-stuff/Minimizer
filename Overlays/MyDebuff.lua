local _, Minimizer = ...
if not Minimizer then return end

local MyDebuff = {}
Minimizer.MyDebuff = MyDebuff

local ORANGE = { 1.00, 0.35, 0.00, 0.55 }

-- Midnight / 12.1+: DO NOT query C_UnitAuras.GetUnitAuras from addon Lua.
-- While enemy auras are secret, that API itself can throw a taint error.
--
-- Instead we let Blizzard's AuraContainer do the predicate work entirely in
-- its native/secure aura pipeline:
--
--     HARMFUL|PLAYER
--
-- The single AuraSlot is visible iff Blizzard assigns a matching aura to it.
-- Our overlay texture is created from initializeFrame(), while the AuraButton
-- is still in its allowed initialization phase. After that we never inspect
-- the button's visibility or any aura data from Lua.

local function CreateOverlayContainer(unit, nameplate)
    if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return nil end
    if not C_NamePlate.GetNamePlateForUnit(unit) then return nil end
    if type(CreateFrame) ~= "function" then return nil end

    local healthBar = nameplate and Minimizer.Utils and Minimizer.Utils.GetHealthBar
        and Minimizer.Utils.GetHealthBar(nameplate)
    if not healthBar then return nil end

    local container = CreateFrame(
        "AuraContainer",
        nil,
        nameplate,
        "CustomAuraContainerTemplate"
    )
    if not container then return nil end

    -- The container only needs a renderable rect so Blizzard's aura engine
    -- processes it. The actual visual is the texture anchored to healthBar.
    container:SetSize(1, 1)
    container:ClearAllPoints()
    container:SetPoint("CENTER", nameplate, "CENTER", 0, 0)

    local healthLevel = healthBar.GetFrameLevel and healthBar:GetFrameLevel() or 0
    if container.SetFrameLevel then
        container:SetFrameLevel(healthLevel + 20)
    end

    local function InitializeAuraFrame(button)
        -- The callback runs before Blizzard applies the secret/forbidden
        -- restrictions to the AuraButton. This is the safe place to create
        -- our presentation region.
        button:SetSize(1, 1)

        local overlay = button:CreateTexture(nil, "OVERLAY")
        overlay:SetAllPoints(healthBar)
        overlay:SetColorTexture(ORANGE[1], ORANGE[2], ORANGE[3], ORANGE[4])
        overlay:SetAlpha(ORANGE[4])
    end

    -- AuraSlot is ideal here: it represents the presence of the first aura
    -- matching the filter without exposing that presence to addon Lua.
    local ok = pcall(function()
        container:AddAuraSlot("myDebuff", "HARMFUL|PLAYER", {
            candidateFilters = {},
            initializeFrame = InitializeAuraFrame,
        })
    end)
    if not ok then
        container:Hide()
        return nil
    end

    -- Blizzard's AuraContainer owns UNIT_AURA processing from this point on.
    -- SetUnit is deliberately done after the slot declaration.
    container:SetUnit(unit)

    if container.SetEnabled then
        container:SetEnabled(true)
    end
    container:Show()

    return container
end

function MyDebuff:Update(unit, nameplate)
    if not MinimizerDB or MinimizerDB.enableMyDebuffOverlay ~= true then
        return
    end
    if not unit or not unit:match("^nameplate%d+$") then return end
    if not nameplate then return end

    local container = nameplate.MinimizerMyDebuffAuraContainer
    if container then return end

    container = CreateOverlayContainer(unit, nameplate)
    if container then
        nameplate.MinimizerMyDebuffAuraContainer = container
    end
end

function MyDebuff:OnUnitChanged(unit, reason)
    if reason == "removed" then return end
    if unit and unit:match("^nameplate%d+$") then
        local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit
            and C_NamePlate.GetNamePlateForUnit(unit)
        if plate then
            self:Update(unit, plate)
        end
    end
end

function MyDebuff:UpdateAll()
    local plates = (Minimizer.Lifecycle and Minimizer.Lifecycle.GetActiveNameplates
        and Minimizer.Lifecycle.GetActiveNameplates()) or Minimizer.ActiveNameplates
    if not plates then return end

    for unit, nameplate in pairs(plates) do
        self:Update(unit, nameplate)
    end
end

if Minimizer.Overlays and Minimizer.Overlays.Register then
    Minimizer.Overlays.Register("MyDebuff", MyDebuff)
end
