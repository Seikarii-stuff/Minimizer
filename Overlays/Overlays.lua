local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Overlays = Minimizer.Overlays or {}
local Overlays = Minimizer.Overlays
Overlays.registry = Overlays.registry or {}

function Overlays.Register(name, module)
    if not name or not module then return end
    Overlays.registry[name] = module
end

function Overlays.Get(name)
    return Overlays.registry[name]
end

function Overlays.OnCooldownTick()
    for _, module in pairs(Overlays.registry) do
        if type(module.OnCooldownTick) == "function" then
            module:OnCooldownTick()
        elseif type(module.DebouncedUpdate) == "function" then
            module.DebouncedUpdate()
        end
    end
end

function Overlays.OnUnitChanged(unit, reason)
    for _, module in pairs(Overlays.registry) do
        if type(module.OnUnitChanged) == "function" then
            module:OnUnitChanged(unit, reason)
        end
    end
end