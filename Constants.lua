-- Static data shared by visual modules.
local _, Minimizer = ...
if not Minimizer then return end

Minimizer.Constants = Minimizer.Constants or {}
Minimizer.Constants.HealthColors = {
    trivial = { 0.00, 0.00, 0.00 },
    melee = { 1.00, 1.00, 1.00 },
    caster = { 0.20, 0.55, 1.00 },
    boss = { 0.65, 0.25, 1.00 },
    miniboss = { 0.65, 0.25, 1.00 },
    focus = { 1.00, 0.90, 0.00 },
    absorb = { 1.00, 0.45, 0.75 },
    aggro = { 1.00, 0.00, 0.00 },
    castInterruptible = { 0.10, 1.00, 0.10 },
    dangerCast = { 0.28, 0.05, 0.38 },
    superiorUninterruptible = { 0.00, 0.00, 0.00 },
}
Minimizer.Constants.CastColors = {
    ready = { 0.10, 1.00, 0.10 },
    channel = { 1.00, 0.55, 0.75 },
}
