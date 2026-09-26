-- ============================================================================
-- Minimizer - SpellRenderer.lua
-- Presentational renderer for spells (icon, cooldown, charges and glow).
-- ============================================================================
local _, Minimizer = ...
if not Minimizer then return end

local SpellRenderer = {}
Minimizer.SpellRenderer = SpellRenderer

local DEFAULT_SIZE = 32
local GLOW_PULSE_SPEED = 3.2

function SpellRenderer.Create(parent, options)
    if not parent then return nil end
    options = options or {}

    local self = {
        _size = tonumber(options.size) or DEFAULT_SIZE,
        _spellID = nil,
        _overlayed = false,
        _glowPhase = 0,
        _showIcon = options.showIcon ~= false,
    }

    local frame = options.frame or CreateFrame("Frame", nil, parent)
    frame:SetSize(self._size, self._size)
    if not options.frame then frame:Hide() end

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local mask = frame:CreateMaskTexture()
    mask:SetAllPoints(icon)
    mask:SetTexture("Interface\\Masks\\CircleMaskScalable", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    icon:AddMaskTexture(mask)

    local cooldown = options.existingCooldown or CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    if options.cooldownOptions then
        Minimizer.Widgets.ConfigureCooldownFrame(cooldown, options.cooldownOptions)
    else
        Minimizer.Widgets.MakeCooldownCircular(cooldown, false)
    end

    local count = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    count:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    count:Hide()

    local glow = frame:CreateTexture(nil, "OVERLAY")
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetPoint("TOPLEFT", frame, "TOPLEFT", -7, 7)
    glow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 7, -7)
    glow:SetVertexColor(1.0, 0.55, 0.02, 1.0)
    glow:Hide()

    local flash = frame:CreateTexture(nil, "OVERLAY")
    flash:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    flash:SetBlendMode("ADD")
    flash:SetPoint("TOPLEFT", frame, "TOPLEFT", -11, 11)
    flash:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 11, -11)
    flash:SetVertexColor(1.0, 0.82, 0.15, 1.0)
    flash:Hide()

    self._frame = frame
    self._icon = icon
    self._mask = mask
    self._cooldown = cooldown
    self._count = count
    self._glow = glow
    self._flash = flash

    function self:SetSize(size)
        size = tonumber(size) or DEFAULT_SIZE
        if self._size == size then return false end
        self._size = size
        self._frame:SetSize(size, size)
        return true
    end

    function self:SetOverlayed(active)
        self._overlayed = active == true
        self._glowPhase = 0
        if self._overlayed then
            self._glow:SetAlpha(1)
            self._flash:SetAlpha(1)
            self._glow:Show()
            self._flash:Show()
        else
            self._glow:SetAlpha(0)
            self._flash:SetAlpha(0)
            self._glow:Hide()
            self._flash:Hide()
        end
    end

    function self:Update(elapsed)
        if not self._overlayed then return end
        self._glowPhase = self._glowPhase + (elapsed or 0) * GLOW_PULSE_SPEED
        local wave = (math.sin(self._glowPhase) + 1) * 0.5
        local flashWave = math.max(0, math.cos(self._glowPhase * 0.5))
        self._glow:SetAlpha(0.65 + wave * 0.35)
        self._flash:SetAlpha(0.12 + flashWave * 0.72)
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
        self._icon:Hide()
        self._count:SetText(nil)
        self._count:Hide()
        self:SetOverlayed(false)
        if self._cooldown.Clear then self._cooldown:Clear() end
        self._cooldown:Hide()
        self._frame:Hide()
    end

    function self:Render(spellID, state)
        if not spellID then
            self:Clear()
            return false
        end

        self._spellID = spellID
        if self._showIcon then
            local info = Minimizer.Spells.GetInfo(spellID)
            if not info or not info.texture then
                self:Clear()
                return false
            end
            self._icon:SetTexture(info.texture)
            self._icon:Show()
        else
            self._icon:SetTexture(nil)
            self._icon:Hide()
        end

        if state and state.cooldown and self._cooldown.SetCooldownFromDurationObject then
            self._cooldown:SetCooldownFromDurationObject(state.cooldown)
        else
            Minimizer.Widgets.ApplyCooldownDuration(self._cooldown, spellID)
        end
        self._cooldown:Show()

        local count = nil
        if state and state.displayCount ~= nil then
            count = state.displayCount
        elseif state and state.maxCharges and state.maxCharges > 1 then
            count = state.currentCharges
        end
        if count ~= nil then
            self._count:SetText(tostring(count))
            self._count:Show()
        else
            self._count:SetText(nil)
            self._count:Hide()
        end

        self:SetOverlayed(state and state.isOverlayed == true)
        self._frame:Show()
        return true
    end

    frame:SetScript("OnUpdate", function(_, elapsed)
        self:Update(elapsed)
    end)

    return self
end
