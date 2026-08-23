# Arquitectura — revisión pendiente para el siguiente split

**Estado:** revisión posterior a la migración arquitectónica principal  
**Rama de referencia:** `main`  
**Propósito:** conservar las observaciones que quedan respecto a `Docs/arquitectura.md` para el siguiente split arquitectónico.  
**Criterio:** no son bloqueantes para la arquitectura actual ni justifican otro refactor inmediato.

---

## Resumen

La migración principal está **aprobada funcionalmente** y la arquitectura actual es estable. Los owners principales ya están separados:

```text
Lifecycle
    ↓
Dispatcher
    ↓
Snapshot
    ↓
Decision
    ↓
Rendering / Modules
```

`Core` queda como registro/fan-out y la suite existente valida la implementación actual.

La revisión final frente a `Docs/arquitectura.md` deja los siguientes puntos como **deuda arquitectónica residual** para un futuro split. Deben abordarse de forma aislada, preservando primero el comportamiento actual y ejecutando la suite de equivalencia después de cada cambio.

---

# 1. Snapshot: retirar la duplicación residual de `ComputeDisplayKind`

## Estado actual

La ruta normal ya es:

```text
Dispatcher
    ↓
Snapshot.Build
    ↓
ResolveDisplayKind
    ↓
snapshot.displayKind
```

`Snapshot.ComputeDisplayKind` sigue existiendo únicamente para un camino fallback de `HealthBarColor` cuando no dispone de un Snapshot.

## Problema arquitectónico

`ComputeDisplayKind` todavía reconstruye parte del estado que `Snapshot.Build` ya captura y puede volver a ejecutar lógica de Absorb (`MarkSeen`). Por tanto, aunque ya no es una segunda autoridad del pipeline normal, mantiene una duplicación de captura/cálculo que la arquitectura objetivo pretendía eliminar.

## Trabajo futuro

Antes de eliminarlo:

1. Identificar todos sus consumidores.
2. Determinar si el camino sin Snapshot puede recibir un Snapshot sin crear un segundo pipeline o reentrancia.
3. Si es posible, sustituir el fallback por el Snapshot existente.
4. Si no es posible, conservarlo como fallback pero reducirlo al mínimo necesario y documentar por qué debe existir.
5. No cambiar la prioridad de `displayKind`.

**Prioridad:** media.  
**Riesgo:** medio si se modifica sin comprobar hooks/repaints de Blizzard.

---

# 2. Dispatcher → Threat: dependencia residual del scheduler

## Estado actual

El scheduler y el monitor round-robin viven correctamente en `Dispatcher`. Threat ya no posee un scheduler independiente.

Sin embargo, durante el procesamiento del monitor, `Dispatcher` consulta directamente APIs de `Threat` para detectar cambios de estado.

Conceptualmente queda:

```text
Dispatcher
    └── consulta Threat
```

en lugar del contrato arquitectónico más puro:

```text
Threat
    └── invalida/notifica Dispatcher
```

## Problema arquitectónico

El ownership del scheduler está correctamente centralizado, pero el límite entre dominio y scheduling todavía no es completamente unidireccional.

## Trabajo futuro

Evaluar si el monitor puede seguir siendo propiedad de Dispatcher mientras la información de cambio de Threat se expone mediante una interfaz de invalidación más limpia.

No mover el scheduler de vuelta a Threat.

No modificar la cadencia actual (`0.25 / N`), `monitorStep`, `StatesEqual` ni la memoización del estado de tanque.

**Prioridad:** media-baja.  
**Riesgo:** alto si se toca el algoritmo de monitorización sin tests de equivalencia específicos.

---

# 3. Decision: eliminar gradualmente los fallbacks sin Snapshot

## Estado actual

Durante el pipeline normal `Decision` consume Snapshot correctamente.

Todavía existen caminos directos sin Snapshot que consultan dominio (`Threat`, `Absorb`, `Cast`) como fallback.

## Problema arquitectónico

El contrato final deseado es que Decision consuma el Snapshot como única fuente de estado del pipeline normal. Los fallbacks son actualmente compatibles y no constituyen un problema funcional, pero mantienen acoplamiento residual.

## Trabajo futuro

1. Inventariar cada caller de `Decision` sin Snapshot.
2. Determinar si todos pueden pasar por el pipeline normal.
3. Migrar los callers individualmente.
4. Eliminar los fallbacks únicamente cuando no quede un consumidor legítimo.

**Prioridad:** baja.  
**Riesgo:** medio.

---

# 4. Absorb: consolidar completamente `hasHadAbsorb`

## Estado actual

`Absorb.MarkSeen` es la API de dominio y `Snapshot.Build` la utiliza para producir `snapshot.hasHadAbsorb`.

La ruta normal no duplica el `MarkSeen` dentro de los consumidores de Snapshot.

Persisten, no obstante, llamadas a `MarkSeen` en caminos fallback sin Snapshot.

## Problema arquitectónico

La arquitectura objetivo pretende que la persistencia de `hasHadAbsorb` quede integrada en la construcción del Snapshot y que los consumidores no tengan que gestionar manualmente ese estado.

## Trabajo futuro

Eliminar las llamadas fallback a `MarkSeen` cuando todos los caminos de rendering/decision puedan garantizar Snapshot.

Mantener `Absorb.GetTotalAbsorbs` como API de dominio para el cálculo numérico del overshield; no convertir ese dato en estado persistente del Snapshot salvo que el diseño futuro lo requiera.

**Prioridad:** baja-media.  
**Riesgo:** medio por la semántica de persistencia y reciclaje.

---

# 5. Generation fields ad-hoc: unificación completa

## Estado actual

La comprobación de generación ya está centralizada mediante `Lifecycle.GetGeneration` / `Lifecycle.IsGenerationStale`.

Todavía existen campos específicos asociados a generaciones de distintos estados, por ejemplo:

- `MinimizerDesimplifiedPersistentGen`
- `MinimizerAbsorbPersistentGen`
- `MinimizerHealthBarColorGen`

## Problema arquitectónico

El algoritmo de validación de generación está centralizado, pero parte de la representación del estado sigue dispersa por consumidor.

## Trabajo futuro

Evaluar si esos campos pueden sustituirse por una representación común de generación sin perder:

- seguridad frente a reciclaje;
- persistencia correcta;
- comportamiento de `DesimplifiedPersistent`;
- estado de Absorb;
- estado persistente de color de healthbar.

No eliminar campos simplemente por estética. La seguridad de recycle tiene prioridad.

**Prioridad:** baja.  
**Riesgo:** alto si se modifica sin pruebas cross-generation.

---

# 6. Lifecycle: dependencias de teardown

## Estado actual

`Lifecycle` es el owner de generaciones y `ActiveNameplates`, pero `ClearNeverSimplify` todavía coordina limpieza de estado en otros módulos (`Cache`, `Cast`, `HitTest`, `Threat` y módulos registrados).

## Problema arquitectónico

La arquitectura objetivo describe Lifecycle con dependencias mínimas. El teardown actual es funcional, pero Lifecycle conoce varios dominios para limpiar estado asociado al nameplate.

## Trabajo futuro

Evaluar un mecanismo de teardown/fan-out más desacoplado, sin devolver ownership de generaciones a otros módulos.

Una posible dirección es que Lifecycle publique el cambio de lifecycle y que los módulos interesados limpien su propio estado.

No convertir esto en una reescritura de Lifecycle sin necesidad.

**Prioridad:** baja.  
**Riesgo:** medio-alto.

---

# 7. ADDON_LOADED: consolidación opcional

## Estado actual

La inicialización principal está centralizada en `Bootstrap`, pero existen listeners específicos de opciones/configuración que pueden responder al mismo evento.

## Problema arquitectónico

El objetivo ideal es que exista un único owner del bootstrap y que los consumidores reciban una llamada de inicialización explícita.

## Trabajo futuro

Solo consolidar listeners si aporta claridad real y no introduce orden de inicialización implícito.

Esta tarea es **opcional** y de prioridad baja.

---

# 8. HookIndicator — mantener hasta que exista evidencia de redundancia

## Estado actual

Se mantienen dos mecanismos:

```text
UNIT_ABSORB_AMOUNT_CHANGED
    ↓
Dispatcher.ApplyToUnit
```

```text
HookIndicator / overlay Show-Hide
    ↓
Dispatcher.ApplyToUnit
```

El segundo es un fallback de repaint/overlay y está protegido contra reentrada.

## Decisión

**No eliminar `HookIndicator` como parte del siguiente split sin una prueba concreta de redundancia.**

La existencia de ambos caminos no implica dos owners: ambos son invalidadores que terminan en Dispatcher.

## Trabajo futuro

Solo investigar si una versión futura de la API de Blizzard hace innecesario el hook.

**Prioridad:** informativa.  
**Estado:** mantener.

---

# 9. Invariantes que NO deben cambiar durante el siguiente split

Cualquier futuro cambio arquitectónico debe preservar explícitamente:

### Dispatcher / reentrancia

- Coalescing de reentrancia.
- Límite de seguridad de 10 pasadas.
- `ApplyToUnit` como entrada única del pipeline normal.
- `ApplyToAll` como entrada global.

### Threat

- Cadencia `0.25 / N`.
- `monitorStep`.
- `StatesEqual`.
- Memoización/refresh del estado de tanque.
- Limpieza al retirar nameplates.

### Cast

- Sin cache inseguro a través de recycle.
- Una lectura coherente del estado de cast por Snapshot.

### Lifecycle

- `ActiveNameplates`.
- Generación por token.
- Invalidación de generación.
- Seguridad cross-generation.

### Snapshot

- Pool por profundidad.
- `displayKind` y su prioridad.
- `hasAbsorb`.
- `hasHadAbsorb`.
- Estado de cast.
- Estado de friendly/PvP.

### Rendering / overlays

- HealthBarColor debe consumir Snapshot cuando esté disponible.
- HookIndicator debe terminar en Dispatcher.
- Target/Focus mantienen su throttle visual.
- Pips/Widgets mantienen su desacoplamiento del pipeline de decisión.

---

# 10. Criterio para el siguiente split arquitectónico

El siguiente split **no debe comenzar por una limpieza general**.

Orden recomendado:

1. Auditar `Snapshot.ComputeDisplayKind`.
2. Auditar la frontera Dispatcher ↔ Threat.
3. Eliminar fallbacks sin Snapshot cuando exista cobertura equivalente.
4. Revisar `hasHadAbsorb` y los campos de generación.
5. Solo después considerar el desacoplamiento del teardown de Lifecycle.
6. ADDON_LOADED queda como tarea opcional.

Cada paso debe ser pequeño, reversible y acompañado de equivalence tests.

---

## Estado de cierre de la migración actual

La migración principal queda **aprobada**. Este documento no representa bugs conocidos ni tareas bloqueantes; representa únicamente la diferencia entre la implementación estable actual y la forma más estricta/pura descrita por `Docs/arquitectura.md`.

La prioridad del siguiente split debe ser **reducir deuda arquitectónica sin alterar comportamiento**.
