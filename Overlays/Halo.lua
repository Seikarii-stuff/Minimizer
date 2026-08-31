-- ============================================================================
-- Minimizer - Halo.lua
-- Componente visual reutilizable. El host/consumer posee el contexto de render.
-- ============================================================================
local _, Minimizer = ...
if not Minimizer then return end

local Halo = {}
Minimizer.Halo = Halo

local DEFAULT_SIZE = 46
local HALO_TEXTURE = "Interface\\AddOns\\Minimizer\\assets\\halo_ring"

function Halo.Create(parent, options)
    options = options or {}
    local name = options.name
    local size = tonumber(options.size) or DEFAULT_SIZE
    local frame = CreateFrame("Frame", name, parent or UIParent)
    frame:SetSize(size, size)
    frame.MinimizerHaloSize = size
    frame:Hide()

    local texture = frame:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints()
    texture:SetTexture(options.texture or HALO_TEXTURE)
    texture:SetBlendMode("BLEND")
    frame.MinimizerHaloTexture = texture

    local cooldownName = options.cooldownName
        or (name and (name .. "Cooldown") or nil)
    local cooldown = CreateFrame("Cooldown", cooldownName, frame, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    Minimizer.Widgets.ConfigureCooldownFrame(cooldown, {
        drawEdge = false,
        useCircularEdge = true,
        drawSwipe = true,
        drawBling = false,
        reverse = false,
        hideCountdownNumbers = true,
        swipeTexture = options.swipeTexture or HALO_TEXTURE,
        swipeColor = options.swipeColor or { 0.00, 0.00, 0.00, 0.75 },
    })
    frame.MinimizerHaloCooldown = cooldown
    frame.MinimizerHaloHost = parent

    local cooldownLevelOffset = tonumber(options.cooldownFrameLevelOffset) or 0
    if cooldownLevelOffset ~= 0 then
        cooldown:SetFrameLevel((frame:GetFrameLevel() or 0) + cooldownLevelOffset)
    end

    -- In WoW hiding the parent also hides its children. Keep that relationship
    -- explicit so the reusable component has deterministic lifecycle semantics.
    local originalHide = frame.Hide
    function frame:Hide()
        if self.MinimizerHaloCooldown then
            self.MinimizerHaloCooldown:Hide()
        end
        return originalHide(self)
    end

    function frame:SetHost(host)
        if self.MinimizerHaloHost == host then return end
        self:ClearAllPoints()
        self:SetParent(host or UIParent)
        self.MinimizerHaloHost = host
    end

    function frame:SetCooldown(spellID)
        if not spellID then
            self:Hide()
            return false
        end
        if not Minimizer.Widgets.ApplyCooldownDuration(self.MinimizerHaloCooldown, spellID) then
            self:Hide()
            return false
        end
        self:Show()
        return true
    end

    function frame:ShowFor(spellID)
        return self:SetCooldown(spellID)
    end

    return frame
end
