# UI layering architecture

## Regla de ownership

Un componente visual reutilizable construye y controla su representación, pero no decide arbitrariamente su `FrameStrata` global.

```text
Component
  -> visual behaviour

Consumer / Host
  -> parent / render context / strata / level / anchoring / lifecycle
```

`HIGH` **no es la strata por defecto de Minimizer**. Solo un host que necesite quedar por encima de la UI normal debe elegirla.

## Componentes y consumidores

```text
Target -> Minimizer.Halo -> nameplate context
Wheel  -> Minimizer.Halo -> player UI context
Focus  -> portrait propio -> nameplate context
Mouse  -> futuro -> podrá elegir HIGH en su host
```

### Halo

`Overlays/Halo.lua` es el único propietario de `Minimizer.Halo`. `Halo.Create(parent, options)` crea el frame, textura `halo_ring` y `CooldownFrameTemplate`, y expone `SetHost`, `SetCooldown` y `ShowFor`.

Las opciones `size`, `texture`, `swipeTexture`, `swipeColor`, `cooldownName` y `cooldownFrameLevelOffset` permiten conservar diferencias legítimas de representación y orden relativo. Halo no contiene lógica específica de Target, Wheel o Mouse y **nunca** llama a `SetFrameStrata`.

### Widgets

`Overlays/Widgets.lua` contiene únicamente utilities genéricas de cooldown, aplicación de duración, cache/búsqueda de spell IDs y descubrimiento de castbars. No crea ni actualiza Halo.

### Target

Target crea una única instancia de `Minimizer.Halo` y proporciona la nameplate como host. Las stripes permanecen separadas y siguen siendo hijas de la healthbar.

```text
Nameplate
├── HealthBar
│   └── Target stripes
└── Target Halo
    └── circular cooldown
```

El countdown numérico existente continúa siendo un cooldown separado hijo del Halo.

### Wheel

Wheel conserva su frame como host de UI normal del jugador y consume `Minimizer.Halo` como hijo. El Halo contiene el anillo y el interrupt cooldown; el Wheel no mantiene una implementación paralela.

```text
Wheel [MEDIUM]
├── Halo
│   └── interrupt cooldown
└── Pips
```

El antiguo `HIGH` y el `FrameLevel(100)` global han desaparecido.

### Focus

Focus **no consume Halo**. Su portrait y cooldown siguen siendo componentes propios, pero el portrait usa la nameplate como parent/contexto y un `FrameLevel` relativo.

### Pips

Los Pips son hijos del Wheel. No fijan `FrameStrata`; heredan el contexto del Wheel. Solo conservan `Wheel + 5` para su orden visual local.

## Política de renderizado

| Componente | Parent / contexto | Strata | FrameLevel | Motivo |
| --- | --- | --- | --- | --- |
| Halo de Target | nameplate | heredada | `plate + 2` | contexto de nameplate |
| Target stripes | healthbar | heredada | `healthbar + 2` | overlay local de healthbar |
| Countdown de Target | Halo | heredada | `Halo + 10` | prioridad sobre el anillo |
| Portrait de Focus | nameplate | heredada | `plate + 1` | portrait propio dentro de la plate |
| Wheel | `UIParent` / player UI | `MEDIUM` | default | UI normal, debajo de ventanas superiores |
| Halo de Wheel | Wheel | heredada | `Wheel + 1` | componente común sin elevar contexto |
| Interrupt cooldown de Wheel | Halo | heredada | `Halo + 10` | conserva prioridad visual |
| Pips | Wheel | heredada | `Wheel + 5` | orden local sobre Wheel |

Una ventana normal de Blizzard (por ejemplo `DIALOG`) queda por encima de Wheel. Target y Focus heredan el contexto que proporciona la nameplate. Un consumidor futuro como Mouse puede escoger `HIGH` en su propio host sin modificar Halo.

## Lifecycle / recycling

No se introducen timers, polling ni `OnUpdate` para layering.

Target oculta Halo y countdown cuando el target/plate deja de ser válido y `SetHost(nil)` devuelve Halo a `UIParent`. Al reutilizar una plate se establece el nuevo host antes de anclar y mostrar el Halo.

Focus aplica el mismo patrón a su portrait. Wheel crea su Halo una sola vez y lo reutiliza durante todos los updates y cambios de configuración.

## OverlayHost

No se introduce `OverlayHost`: la nameplate ya proporciona el contexto necesario para Target/Focus y Wheel tiene un host estable. Un framework adicional sería desproporcionado.

## Load order

`Minimizer.toc` carga `Overlays/Halo.lua` después de `Overlays/Widgets.lua` y antes de `Wheel/Wheel.lua`, `Overlays/Focus.lua` y `Overlays/Target.lua`, haciendo explícita la dependencia.

## Tests

Los tests funcionales siguen separados de los de arquitectura.

- `tests/halo_test.lua`: creación, tamaño, textura, cooldown, show/hide, cambio de host, host `HIGH` futuro y ausencia de nuevas instancias.
- `tests/target_test.lua`: Halo compartido, host/strata/FrameLevel, stripes y recycling.
- `tests/wheel_test.lua`: consumo de Halo, `MEDIUM`, countdown, Pips, ventana Blizzard superior y hot path sin allocations de frames.
- `tests/focus_test.lua`: Focus no consume Halo; portrait y cooldown conservan contexto de nameplate.
- `tests/ui_layering_test.lua`: contrato completo de ownership/contexto y regresiones de strata.
