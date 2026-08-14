-- ============================================================================
-- Minimizer - Widgets.lua
-- Búsqueda de widgets en nameplates (ej. castbars anónimas)
-- ============================================================================
local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Widgets = Minimizer.Widgets or {}

local function FindCastBarInGrandchildren(healthBar, ...)
    for i = 1, select("#", ...) do
        local grandchild = select(i, ...)
        if type(grandchild) == "table"
            and grandchild ~= healthBar
            and type(grandchild.SetStatusBarColor) == "function"
            and type(grandchild.GetValue) == "function" then
            return grandchild
        end
    end
    return nil
end

local function FindCastBarInChildren(healthBar, ...)
    for i = 1, select("#", ...) do
        local child = select(i, ...)
        if type(child) == "table" and type(child.GetChildren) == "function" then
            local grandchild = FindCastBarInGrandchildren(healthBar, child:GetChildren())
            if grandchild then return grandchild end
        end
    end
    return nil
end

function Minimizer.Widgets.FindCastBar(nameplate)
    local unitFrame = nameplate and (nameplate.UnitFrame or nameplate)
    if not unitFrame or type(unitFrame.GetChildren) ~= "function" then return nil end
    local healthBar = Minimizer.Utils and Minimizer.Utils.GetHealthBar and Minimizer.Utils.GetHealthBar(nameplate)
    return FindCastBarInChildren(healthBar, unitFrame:GetChildren())
end

function Minimizer.Widgets.GetCDSpellID(dbTable)
    local _, classToken = UnitClass("player")
    local spellList = classToken and dbTable and dbTable[classToken]
    if not spellList then return nil end

    if type(spellList) == "number" then
        spellList = {spellList}
    end

    for _, spellID in ipairs(spellList) do
        if ((C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook and C_SpellBook.IsSpellKnownOrInSpellBook(spellID))
            or (IsPlayerSpell and IsPlayerSpell(spellID))
            or (C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(spellID))
            or (IsSpellKnown and IsSpellKnown(spellID))) then
            return spellID
        end
    end
    if spellList[1] then return spellList[1] end
    return nil
end

function Minimizer.Widgets.CreateCDWidget(name, size)
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetSize(size, size)
    frame:SetFrameStrata("HIGH")
    frame:Hide()
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    local cooldown = CreateFrame("Cooldown", name.."Cooldown", frame, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    cooldown:SetDrawEdge(true)
    if cooldown.SetDrawSwipe then cooldown:SetDrawSwipe(true) end
    if cooldown.SetDrawBling then cooldown:SetDrawBling(false) end
    if cooldown.SetReverse then cooldown:SetReverse(true) end
    cooldown:SetSwipeTexture("Interface\\HUD\\UI-HUD-CoolDown-Swipe")
    return frame, icon, cooldown
end

function Minimizer.Widgets.UpdateCDWidget(frame, icon, cooldown, spellID)
    if not spellID then frame:Hide(); return false end

    local tex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
    if not tex and GetSpellTexture then tex = GetSpellTexture(spellID) end
    if tex then icon:SetTexture(tex) end

    local ready = true
    if C_Spell and C_Spell.GetSpellCooldownDuration then
        local duration = C_Spell.GetSpellCooldownDuration(spellID)
        if duration then
            cooldown:SetCooldownFromDurationObject(duration)
            ready = duration:IsZero()
        end
    elseif C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if info then
            if cooldown.SetCooldownFromExpression then
                cooldown:SetCooldownFromExpression(spellID)
            elseif cooldown.SetCooldownTable then
                cooldown:SetCooldownTable(info)
            end
            if info.duration and info.duration > 0 then ready = false end
        end
    elseif GetSpellCooldown then
        local start, duration = GetSpellCooldown(spellID)
        if start and duration and duration > 0 then
            cooldown:SetCooldown(start, duration)
            ready = false
        else
            cooldown:SetCooldown(0, 0)
        end
    end

    local shade = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean and C_CurveUtil.EvaluateColorValueFromBoolean(ready, 1.0, 0.38) or (ready and 1.0 or 0.38)
    icon:SetVertexColor(shade, shade, shade, 1)

    frame:Show()
    return true
end
