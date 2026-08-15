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
    superiorUninterruptible = { 0.50, 0.50, 0.50 },
}
Minimizer.Constants.CastColors = {
    ready = { 0.10, 1.00, 0.10 },
    channel = { 1.00, 0.55, 0.75 },
}

-- Colores para "pips": círculos pequeños de estado de cooldown anclados en la
-- esquina de otro widget (ej. CC del focus, defensivo del target). Cada
-- entrada define:
--   on  = color brillante, mostrado cuando el spell está listo (100% visible).
--   off = color del velo oscuro que lo cubre mientras está en cooldown (el
--         "swipe" del Cooldown frame), va perdiendo cobertura hasta desaparecer
--         cuando el cooldown termina.
-- Para añadir un pip nuevo en el futuro: agrega aquí una entrada más con su
-- clave (ej. "interrupt" o el nombre que sea) y sus colores on/off. No hace
-- falta tocar Widgets.lua para que funcione.
Minimizer.Constants.PipColors = {
    cc = { on = {0.20, 0.55, 1.00}, off = {0.05, 0.10, 0.25} },        -- azul (CC focus)
    defensive = { on = {0.10, 1.00, 0.10}, off = {0.03, 0.20, 0.03} }, -- verde (defensivo target)
}
