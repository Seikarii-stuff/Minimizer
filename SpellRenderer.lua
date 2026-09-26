-- ============================================================================
-- Minimizer - SpellRenderer.lua
-- Presentational renderer for spells (icon, cooldown, charges, glow).
-- ============================================================================
local _, Minimizer = ...
if not Minimizer then return end

Minimizer.SpellRenderer = Minimizer.SpellRenderer or {}

local SR = {}
Minimizer.SpellRenderer = SR

local DEFAULT_SIZE = 32

local function NewRenderer(parent, opts)
    opts = opts or {}
    local self = {}
    self._parent = parent
    self._size = opts.size or DEFAULT_SIZE
    self._spellID = nil
    self._overlayed = false

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(self._size, self._size)
    frame:Hide()

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()

    local cooldown = opts.existingCooldown or CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    if not opts.existingCooldown and Minimizer.Widgets and Minimizer.Widgets.MakeCooldownCircular then
        Minimizer.Widgets.MakeCooldownCircular(cooldown, false)
    end

    local countFS = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countFS:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    countFS:Hide()

    local glow = frame:CreateTexture(nil, "OVERLAY")
    glow:SetAllPoints()
    glow:SetBlendMode("ADD")
    glow:Hide()

    frame.MinimizerSpellRendererFrame = true

    self._frame = frame
    self._icon = icon
    self._cooldown = cooldown
    self._countFS = countFS
    self._glow = glow

    function self:SetSize(size)
        size = tonumber(size) or DEFAULT_SIZE
        if self._size == size then return false end
        self._size = size
        self._frame:SetSize(size, size)
        return true
    end

    local pulseTime = 0
    function self:Update(dt)
        if not self._overlayed then return end
        pulseTime = (pulseTime + (dt or 0)) % 1.5
        local alpha = 0.6 + 0.4 * math.abs(math.sin(pulseTime * math.pi * 2))
        self._glow:SetAlpha(alpha)
    end

    function self:SetOverlayed(active)
        self._overlayed = active == true
        if self._overlayed then
            self._glow:Show()
        else
            self._glow:Hide()
        end
    end

    function self:Show()
        self._frame:Show()
    end

    function self:Hide()
        self._frame:Hide()
    end

    function self:Clear()
        self._spellID = nil
        self._icon:SetTexture(nil)
        -- hide/reset cooldown
        if self._cooldown and self._cooldown.Hide then self._cooldown:Hide() end
        self._countFS:SetText(nil)
        self._countFS:Hide()
        self._glow:Hide()
        self._frame:Hide()
    end

    function self:Render(spellID, state)
        if not spellID then
            self:Clear()
            return
        end

        self._spellID = spellID
        local info = Minimizer.Spells and Minimizer.Spells.GetInfo and Minimizer.Spells.GetInfo(spellID) or nil
        if info and info.texture then
            self._icon:SetTexture(info.texture)
        else
            self._icon:SetTexture(nil)
        end

        -- apply cooldown: prefer provided state.cooldown to avoid re-resolving
        if state and state.cooldown and self._cooldown and self._cooldown.SetCooldownFromDurationObject then
            self._cooldown:SetCooldownFromDurationObject(state.cooldown)
        else
            if Minimizer.Widgets and Minimizer.Widgets.ApplyCooldownDuration then
                Minimizer.Widgets.ApplyCooldownDuration(self._cooldown, spellID)
            end
        end

        -- charges / display count
        local shownCount = nil
        if state then
            if state.displayCount and state.displayCount > 0 then
                shownCount = state.displayCount
            elseif state.currentCharges and state.currentCharges > 0 then
                shownCount = state.currentCharges
            end
        end
        if shownCount then
            self._countFS:SetText(tostring(shownCount))
            self._countFS:Show()
        else
            self._countFS:SetText(nil)
            self._countFS:Hide()
        end

        -- overlayed
        if state and state.isOverlayed then
            self:SetOverlayed(true)
        else
            self:SetOverlayed(false)
        end

        self._frame:Show()
    end

    return self
end

function SR.Create(parent, opts)
    if not parent then return nil end
    return NewRenderer(parent, opts)
end

return SR
