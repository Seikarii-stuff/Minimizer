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
