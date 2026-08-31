# UI layering architecture

Los componentes visuales reutilizables construyen y controlan su representación, pero no eligen arbitrariamente el `FrameStrata` global. El host/consumer posee parent, contexto de render, `FrameStrata`, `FrameLevel`, posición y lifecycle.

## Components

- **Halo** (`Overlays/Halo.lua`): único propietario de `Minimizer.Halo`. Crea frame, textura y cooldown; expone `SetHost`, `SetCooldown` y `ShowFor`. Nunca llama a `SetFrameStrata`.
- **Widgets**: solo utilidades genéricas de cooldown, spell lookup/cache y descubrimiento de castbars. No crea ni actualiza Halo.
- **Target**: entrega la nameplate como host del Halo y conserva las stripes como hija de la healthbar.
- **Focus**: entrega la nameplate como parent de su portrait y usa `FrameLevel` relativo a la plate.
- **Wheel**: host de UI normal del jugador; usa `MEDIUM`, sin el antiguo `HIGH` ni el `FrameLevel(100)` global.
- **Pips**: hijos del Wheel; heredan su strata y solo fijan `Wheel + 5` para su orden relativo. Su cooldown sigue siendo hijo del pip.
- **Mouse futuro**: podrá escoger `HIGH` en su propio host sin modificar Halo.

## Rendering policy

| Componente | Parent/context | Strata | FrameLevel |
| --- | --- | --- | --- |
| Halo Target | nameplate | heredada | `plate + 2` |
| Target stripes | healthbar | heredada | `healthbar + 2` |
| Focus | nameplate | heredada | `plate + 1` |
| Wheel | `UIParent` / player UI | `MEDIUM` | default |
| Pips | Wheel | heredada | `Wheel + 5` |
| Target Countdown | Halo | heredada | `Halo + 10` |
| Wheel Countdown | Wheel | heredada | `Wheel + 10` |

`HIGH` no es una strata de Minimizer. Se reserva para un host que tenga una razón explícita para estar por encima de la UI normal.

## Recycling

Target y Focus ocultan el overlay y lo reparentan a `UIParent` cuando la plate deja de ser válida. Al recibir una plate nueva, el host se establece antes del anchoring y del `Show`. Esto evita conservar parent, nivel, anchor, Halo o cooldown visibles de una plate reciclada.

No se introducen timers, polling ni `OnUpdate` para el layering.

## OverlayHost

No se crea un `OverlayHost`: la nameplate real ya proporciona el contexto de render requerido y un framework adicional sería desproporcionado para este addon.

## Auditoría y tests

La auditoría cubre los patrones `CreateFrame`, `SetFrameStrata`, `GetFrameStrata`, `SetFrameLevel`, `GetFrameLevel`, `SetParent`, creación de texturas/masks/cooldowns y `UIParent` en `Core/`, `Overlays/`, `Plater/`, `Wheel/` y `tests/`. Los cambios se limitan a la arquitectura de layering: Halo, Target/Focus, Wheel/Pips, TOC y tests.

`tests/ui_layering_test.lua` verifica estructuralmente que Halo no impone `HIGH`, Widgets no posee Halo, Target/Focus entregan la plate como host, Wheel usa `MEDIUM`, Pips no fijan strata y el TOC carga Halo antes de sus consumidores. `tests/equivalence_test.lua` sigue cubriendo equivalencia funcional y recycling.
