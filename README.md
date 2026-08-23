# Minimizer

> Simplifica nameplates enemigas usando las APIs nativas de Blizzard (`C_NamePlateManager`), y añade encima color de healthbar/castbar según una leyenda de prioridades ("M+"), marcadores de target/focus, y widgets de cooldown (halo de target, retrato de focus, pips compartidos) — todo diseñado para sobrevivir a los "secretos" (Secrets/Midnight) sin taintear la UI.

Este documento es la **referencia técnica canónica** del addon: arquitectura actual, contratos entre módulos, comportamiento verificado por tests, y guía de uso de la suite de tests/benchmark. Refleja el estado del proyecto **tras el split arquitectónico** (Lifecycle → Dispatcher → Snapshot → Decision → Rendering), no el diseño previo a esa migración.

**Qué NO pretende hacer:** no reemplaza Plater ni ningún addon de nameplates completo; no gestiona friendly/PvP (las deja sin tocar deliberadamente); no implementa su propio panel de opciones más allá de un menú mínimo de desarrollo/fallback (`Menu.lua`, `/mini menu`); no persigue exactitud milimétrica en unidades fuera de combate justo al aparecer (ver [§13 Known Issues](#13-known-issues)).

---

## Índice

1. [Qué es Minimizer](#1-qué-es-minimizer)
2. [Arquitectura actual](#2-arquitectura-actual)
3. [Pipeline de una nameplate](#3-pipeline-de-una-nameplate)
4. [Snapshot / estado](#4-snapshot--estado)
5. [Threat Monitor](#5-threat-monitor)
6. [Cast y Absorb](#6-cast-y-absorb)
7. [Dispatcher y reentrancy](#7-dispatcher-y-reentrancy)
8. [Recycling de nameplates y seguridad de generación](#8-recycling-de-nameplates-y-seguridad-de-generación)
9. [Filtrado friendly / PvP](#9-filtrado-friendly--pvp)
10. [Eventos](#10-eventos)
11. [SpellData: formato y uso](#11-spelldata-formato-y-uso)
12. [Taint / Secrets: checklist canónico](#12-taint--secrets-checklist-canónico)
13. [Known Issues](#13-known-issues)
14. [Testing](#14-testing)
15. [Benchmarking](#15-benchmarking)
16. [Performance: qué garantiza el código vs. qué observa el benchmark](#16-performance-qué-garantiza-el-código-vs-qué-observa-el-benchmark)
17. [Mapa de módulos y orden de carga](#17-mapa-de-módulos-y-orden-de-carga)
18. [Leyenda de color M+ (prioridades)](#18-leyenda-de-color-m-prioridades)

---

## 1. Qué es Minimizer

Minimizer usa `C_NamePlateManager.SetNamePlateSimplified(unit, bool)` para colapsar nameplates enemigas "sin nada interesante" a una versión reducida, y deja las importantes (target, focus, jefes, unidades casteando algo peligroso, unidades con aggro, etc.) en su tamaño completo. Sobre esa base añade:

- **Color de healthbar y castbar** según una leyenda de prioridad fija ([§18](#18-leyenda-de-color-m-prioridades)): quién tiene tu aggro, quién mostró un escudo, quién es un jefe, quién está casteando algo interrumpible.
- **Marcadores de flecha** sobre target y (opcionalmente) focus.
- **Halo de cooldown ofensivo** sobre el target y **retrato con cooldown de interrupt** sobre el focus, más **pips** compartidos (CDs secundarios) en ambos.
- **Sincronización del hit-test** (región de clic) de la nameplate con la healthbar real tras cada cambio de estado de simplificación.

Todo el trabajo se hace intentando nunca comparar en Lua un valor que la API de WoW pueda entregar como "secreto" (Secrets/Midnight) — ver [§12](#12-taint--secrets-checklist-canónico).

---

## 2. Arquitectura actual

El pipeline de procesamiento de una nameplate es unidireccional:

```
Lifecycle  →  Dispatcher  →  Snapshot  →  Decision  →  Rendering (Core.UpdateModules / Overlays)
```

- **`Plater/Lifecycle.lua`** (`Minimizer.Lifecycle`): única autoridad sobre qué nameplates están activas (`Minimizer.ActiveNameplates`) y sobre el contador de generación por token (`plateGeneration`). Expone `GetGeneration`, `IncrementGeneration`, `IsGenerationStale`, `RegisterNameplate`/`UnregisterNameplate`, `GetActiveNameplates`, y `ClearNeverSimplify` (teardown genérico al remover una nameplate).
- **`Plater/Dispatcher.lua`** (`Minimizer.Dispatcher`): motor de orquestación. Decide **cuándo** se reprocesa una unidad (`ApplyToUnit`) o todas (`ApplyToAll`), filtra unidades irrelevantes para el pipeline (`IsPipelineRelevant`, ver [§9](#9-filtrado-friendly--pvp)), gestiona una cola de reentrancia coalescida ([§7](#7-dispatcher-y-reentrancy)), y aloja el **monitor dinámico de Threat** ([§5](#5-threat-monitor)).
- **`Plater/Snapshot.lua`** (`Minimizer.Snapshot`): construye, una vez por unidad por pase, el estado combinado (`eliteType`, `hasAbsorb`/`hasHadAbsorb`, datos de threat, `isPvP`/`isFriendly`, estado de cast/channel, `displayKind`) usando un **pool de tablas por profundidad de recursión** ([§4](#4-snapshot--estado)).
- **`Plater/Decision.lua`** (`Minimizer.Decision`): reglas de negocio puras — `ShouldSimplifyUnit`, `ShouldUnsimplify`, `ShouldLetBlizzardPaint` — que consumen el Snapshot cuando está disponible.
- **Rendering**: `Plater/Core.lua` mantiene el registro de módulos visuales (`RegisterModule`/`UpdateModules`) que consumen el Snapshot: `HealthBarColor`, `CastingBar`, `Markers`. `Overlays/Overlays.lua` hace lo propio para los overlays de unidad especial (`Target`, `Focus`), que **no** iteran nameplates y no pasan por `Core.RegisterModule` (ver más abajo).
- **`Plater/HitTest.lua`**: sincroniza la región de clic con la healthbar real tras cada aplicación de `SetNamePlateSimplified`, con reintentos generation-safe si Blizzard aún no permite mutar el hit-test.
- **`Core/Cache.lua`**: cache genérico `unit -> key -> valor`, atado a `Lifecycle.GetGeneration` (una entrada cuya generación no coincide con la actual se trata como cache-miss). Lo usan `Classification` y `Threat`.

`Plater/Core.lua` **ya no** contiene lifecycle, snapshot, dispatch ni decisión — quedó reducido a registro y fan-out de módulos visuales (`RegisterModule`, `UpdateModules`), manteniendo ese nombre por motivos históricos/compatibilidad con los tests, que siguen accediendo a `addonTable.Core.*`.

**Overlays (`Target`/`Focus`) frente a Módulos de Plater (`HealthBarColor`/`CastingBar`/`Markers`):** ambos consumen infraestructura común (Widgets, Interrupt, Pips), pero tienen ciclos de vida distintos y deliberadamente separados:

- Los **módulos de Plater** se registran en `Core.RegisterModule` y se actualizan para **cada** nameplate activa, dentro de `Dispatcher.ApplyToUnit` → `Core.UpdateModules`.
- Los **overlays** (`Target`, `Focus`) se registran en `Overlays.Register` y atienden **una única unidad especial cada uno** (el target actual, el focus actual). Se actualizan vía `Overlays.OnUnitChanged(unit, reason)` (cambios de target/focus, altas/bajas de nameplate) y `Overlays.OnCooldownTick()` (throttle a 30 FPS enganchado a `SPELL_UPDATE_COOLDOWN`). No recorren `ActiveNameplates` ni dependen de que su unidad esté en el pipeline principal — por eso siguen funcionando incluso si esa unidad es friendly ([§9](#9-filtrado-friendly--pvp)).

---

## 3. Pipeline de una nameplate

**Aparición (`NAME_PLATE_UNIT_ADDED`):**

1. `Events.lua` incrementa la generación del token (`Lifecycle.IncrementGeneration`) y limpia cualquier estado residual de Threat para ese token (`Threat.ForgetUnit`).
2. Se comprueba `Dispatcher.IsPipelineRelevant(unit)` (filtra friendly y PvP, ver [§9](#9-filtrado-friendly--pvp)):
   - Si es relevante: `Dispatcher.TrackUnit(unit)` (marca el monitor de Threat como "dirty" para que reconstruya su lista), `Threat.Invalidate(unit)`, `Dispatcher.ApplyToUnit(unit)` inmediato, y además se programa un pase completo debounced (`Dispatcher.RequestApplyToAll` vía `UpdateNameplates()`) para mitigar el caso de unidades fuera de combate repintadas por Blizzard al final del mismo frame ([§13](#13-known-issues)).
   - Si NO es relevante: `Dispatcher.ForgetUnit(unit)` — importante para que un token reciclado no herede el estado de monitor de Threat de la unidad anterior que ocupó ese mismo token.
3. `Overlays.OnUnitChanged(unit, "added")` — Target/Focus reevalúan si la unidad que acaba de aparecer es su unidad especial, independientemente de si entró o no al pipeline principal.

**`Dispatcher.ApplyToUnit(unit, forceUpdate)` (vía `ApplyToUnitInternal`):**

1. `IsPipelineRelevant(unit)` — si es friendly o PvP, no hace nada más (ver [§9](#9-filtrado-friendly--pvp)).
2. Resuelve `nameplate` y el token válido; registra la nameplate en Lifecycle (`Lifecycle.RegisterNameplate`, que alimenta `ActiveNameplates`).
3. `Snapshot.Build(unit, nameplate)` — un snapshot por esta invocación, aislado de cualquier invocación anidada ([§4](#4-snapshot--estado)).
4. Fast-path de "no simplificar": si `nameplate.MinimizerDesimplifiedPersistent` sigue vigente para la generación actual, se salta `Decision.ShouldSimplifyUnit` y se asume `false` directamente. Si no hay fast-path vigente, se llama a `Decision.ShouldSimplifyUnit(unit, nameplate, snapshot)`; si la razón devuelta es `"no simp"`, se activa el fast-path para el resto de esta generación.
5. Si `C_NamePlateManager.SetNamePlateSimplified` está disponible y (`forceUpdate` o cambió el estado deseado): se llama a la API nativa, se actualiza `nameplate.MinimizerState`, y se sincroniza el hit-test (`HitTest.Sync`).
6. `Core.UpdateModules(unit, nameplate, snapshot)` — fan-out a `HealthBarColor`, `CastingBar`, `Markers`.

**Actualización continua:** eventos de WoW (`UNIT_SPELLCAST_*`, `UNIT_THREAT_*`, `UNIT_ABSORB_AMOUNT_CHANGED`, `UNIT_DISPLAYPOWER`, etc. — ver [§10](#10-eventos)) disparan `Dispatcher.ApplyToUnit(unit)` para la unidad concreta; eventos globales (cambio de zona, roster, dificultad) programan un pase completo debounced. El **monitor de Threat** ([§5](#5-threat-monitor)), cuando está activo, también puede solicitar un reproceso puntual de una unidad si detecta un cambio de estado de amenaza que ningún evento explícito haya cubierto.

**Retirada (`NAME_PLATE_UNIT_REMOVED`):**

1. El handler del evento limpia el estado de Threat (`Threat.ForgetUnit`) y del monitor del Dispatcher (`Dispatcher.ForgetUnit`), y notifica a los overlays (`Overlays.OnUnitChanged(unit, "removed")`).
2. Por separado, un `hooksecurefunc` sobre `NamePlateDriverFrame:OnNamePlateRemoved` (no hay evento nativo fiable de "esta nameplate específica ya desapareció") dispara `Lifecycle.ClearNeverSimplify(unit)`: invalida el `Cache` genérico, cancela reintentos de `HitTest`, olvida el estado de Threat, ejecuta `OnNamePlateRemoved` de cada módulo de Plater registrado (cada uno limpia sus propios campos en la nameplate), limpia los campos genéricos de Lifecycle (`MinimizerDesimplifiedPersistent*`, `MinimizerState`, `MinimizerCastBar`, `MinimizerHasHadAbsorb`, `MinimizerAbsorbPersistentGen`) y borra el token de `ActiveNameplates`.

**Reciclaje (misma nameplate, unidad nueva):** ver [§8](#8-recycling-de-nameplates-y-seguridad-de-generación).

---

## 4. Snapshot / estado

`Minimizer.Snapshot.Build(unit, nameplate)` produce, una vez por invocación, una tabla con:

- `eliteType` (`Classification.GetEliteType`), `hasAbsorb` (lectura **live** del indicador visual), `hasHadAbsorb` (persistente, ver [§6](#6-cast-y-absorb)).
- Datos de threat: `threatSituation`, `otherTankAggro`, `isNilSpecial`, `nilSince`, `inCombat`, `isPlayerTank`, `hasAggro`.
- `isPvP`, `isFriendly`.
- Estado de cast/channel (`isCasting`, `isUninterruptible`, `rawUninterruptible`, `isChanneling`) leído en vivo desde `Cast.GetState` — sin cache, ver [§6](#6-cast-y-absorb).
- `displayKind`: el color/prioridad visual resuelto por `ResolveDisplayKind` (focus > prioridad especial de threat > aggro > absorb > `eliteType`), la **única** implementación de esa tabla de prioridad usada por el pase normal.

**Pooling y aislamiento frente a reentrancia:** `Snapshot.Build` mantiene un contador `currentDepth` que se incrementa al entrar y decrementa al salir. Cada profundidad de recursión tiene su propia tabla en `snapshotPool[depth]` (creada perezosamente si no existe), que se limpia (`wipe`) antes de rellenarla. Esto significa que si, durante la construcción o el consumo del snapshot de una unidad A, algo dispara una construcción anidada de snapshot para la unidad B (p. ej. un módulo que fuerza el reprocesamiento de otra unidad), ambas tablas son instancias distintas — no hay corrupción de datos entre ellas. Esto está cubierto explícitamente por tests de reentrancia (`tests/equivalence_test.lua`, grupo 4), que verifican que instancias en profundidades distintas (incluida profundidad ≥10) son objetos distintos.

**Restricción importante, no relajada por el pooling:** el snapshot de una unidad **solo es válido durante el pase síncrono que lo construyó**. Ningún consumidor debe guardar la referencia para usarla en un pase posterior o de otra unidad; si un consumidor necesita datos para trabajo diferido, debe copiarlos/congelarlos explícitamente.

**Fallback sin Snapshot:** `Minimizer.Snapshot.ComputeDisplayKind(unit, nameplate)` reimplementa el mismo cálculo de `displayKind` para los casos en que un módulo se invoca **fuera** del pase normal (hooks de repintado nativo de Blizzard, donde no hay snapshot disponible). Esta duplicación es conocida y está documentada como deuda residual — ver `revision.md` §1.

---

## 5. Threat Monitor

El monitor de Threat vive en `Plater/Dispatcher.lua` (no en `Threat.lua`, que quedó como proveedor de datos puro).

**Activación/desactivación dinámica:** `Dispatcher.UpdateMonitorState()` habilita el monitor (crea/relanza el `OnUpdate` de `monitorFrame`) solo si `Threat.IsThreatEnabled()` es verdadero — es decir, el jugador está en grupo, en raid, o es tank — y lo detiene (`SetScript("OnUpdate", nil)`) en caso contrario. Esto significa que, en solo (sin grupo, sin ser tank), el monitor **no consume ciclos de CPU en absoluto**: no hay ningún `OnUpdate` corriendo. `UpdateMonitorState` es idempotente — llamarla repetidamente con el mismo estado no crea frames ni scripts duplicados (cubierto por `tests/equivalence_test.lua`, grupo 5).

`UpdateMonitorState()` se invoca desde `Events.lua` en los eventos que pueden cambiar la respuesta de `IsThreatEnabled()`: `PLAYER_ENTERING_WORLD`, cambios de roster/rol/especialización (`HandleRosterOrSpecChange`), y explícitamente desde `Dispatcher.StartMonitor()` (llamada una vez al cargar `Events.lua`).

**Selección de unidades a vigilar:** `RebuildMonitorUnits` reconstruye, solo cuando `monitorDirty` está activo, la lista `monitorUnits` a partir de `Lifecycle.GetActiveNameplates()`, filtrando por tokens con forma `nameplate%d+`. `Dispatcher.TrackUnit(unit)`/`Dispatcher.ForgetUnit(unit)` marcan la lista como sucia cuando una unidad entra o sale del pipeline.

**Cadencia:** round-robin, una unidad cada `0.25 / monitorCount` segundos (si hay más unidades vigiladas, se procesan más rápido en conjunto, pero cada una individual se revisita con la misma frecuencia agregada de 4 veces por segundo repartida entre todas). Esta fórmula es un invariante a preservar.

**Detección de cambio — estado estable sin generar basura:** `Threat.GetUnitThreatState(unit)` construye (o reutiliza) una tabla `{generation, situation, otherTankAggro, combat, nilSpecial}` por unidad, cacheada en `unitThreatStateCache`. Solo se crea una tabla **nueva** cuando alguno de esos campos difiere del estado previamente cacheado para esa unidad (comparando también la generación de plate, para invalidar automáticamente en un reciclaje de token); si nada cambió, se devuelve la **misma referencia** ya existente. `Threat.StatesEqual(s1, s2)` compara dos de estas tablas campo a campo (incluida la generación).

`ProcessMonitoredUnit` compara el estado actual contra el último estado procesado (`monitorState[unit]`) usando `StatesEqual`; solo si difieren, actualiza `monitorState[unit]` y llama a `Dispatcher.RequestUpdate(unit)` (que termina en `ApplyToUnit(unit, false)`). Es decir: **el monitor de Threat no fuerza un reprocesamiento en cada tick** — solo cuando el estado de amenaza de esa unidad concreta realmente cambió desde la última vez que se miró.

Este diseño (reutilizar tablas de estado cuando no hay cambios, en vez de crear una tabla nueva por tick por unidad) es lo que valida `tests/threat_monitor/stable_state_test.lua`: 1000 ticks de `ApplyToAll` sobre una unidad estática no deben generar más de 5 KB de deriva de memoria acumulada.

**Integración con Snapshot/Decision:** el monitor **nunca** llama directamente a `Decision` ni pinta nada — solo decide, a través del Dispatcher, si vale la pena reprocesar una unidad. El propio `Dispatcher.ApplyToUnit` es quien construye un snapshot fresco y deja que `Decision`/`Core.UpdateModules` hagan el resto, exactamente igual que si el reproceso viniera de un evento normal.

---

## 6. Cast y Absorb

**Cast (`Plater/Cast.lua`):** lectura **siempre fresca**, deliberadamente sin cache. `Cast.GetState(unit)` llama a `UnitCastingInfo`/`UnitChannelInfo` en cada invocación. `Cast.InvalidateState(unit)` es un no-op mantenido solo por compatibilidad de API (varios call-sites históricos la siguen llamando). Esta decisión de diseño evita una clase entera de bug de reciclaje de token que existía con una versión anterior con cache de una sola entrada (el estado de una unidad podía "filtrarse" a la unidad siguiente que ocupara el mismo token de nameplate si la invalidación no corría exactamente antes de la siguiente lectura). `UnitCastingInfo`/`UnitChannelInfo` son lo bastante baratas como para no valer la pena ese riesgo.

Invariante verificado por tests (`tests/equivalence_test.lua` y `tests/smoke_test.lua`): `UnitCastingInfo` se llama **exactamente una vez** por `ApplyToUnit`, tanto si la unidad está casteando como si no — porque `Snapshot.Build` es el único punto que llama a `Cast.GetState` en el pase normal, y los módulos de rendering (`CastingBar`, `HealthBarColor`, `Decision`) reutilizan `snapshot.isCasting`/`isUninterruptible`/`rawUninterruptible`/`isChanneling` en vez de volver a leer el estado. Solo cuando un módulo se invoca **sin** snapshot (hook de repintado nativo fuera de pase) vuelve a llamar a `Cast.GetState` directamente.

**Absorb (`Plater/Absorb.lua`):** única fuente de verdad para dos conceptos relacionados pero distintos:

- `Absorb.HasAbsorb(unit, nameplate)` — booleano **live**: ¿el indicador visual nativo (`totalAbsorbOverlay`/`totalAbsorb`) está `:IsShown()` ahora mismo? No se lee el número de absorb para esto, para no arriesgarse a comparar un valor potencialmente secreto.
- `Absorb.MarkSeen(unit, nameplate, hasAbsorbNow)` — persistencia: una vez que una unidad mostró absorb, `nameplate.MinimizerHasHadAbsorb` queda en `true` de forma persistente, invalidado únicamente cuando la generación de la nameplate (`Lifecycle.IsGenerationStale`) indica que el token fue reciclado. `MarkSeen` es la **única** función que escribe este flag; `Snapshot.Build` la llama una vez por pase y expone el resultado como `snapshot.hasHadAbsorb`.
- `Absorb.GetTotalAbsorbs(unit)` expone el valor numérico (usado únicamente por `HealthBarColor` para dimensionar la barra de overshield), propagando el valor tal cual si viniera marcado como secreto.

Mientras exista al menos un consumidor que pueda ser invocado sin snapshot (los hooks de repintado nativo de `HealthBarColor`/`Decision`), esos caminos siguen llamando a `Absorb.HasAbsorb` + `Absorb.MarkSeen` directamente como fallback — ver `revision.md` §4 para el estado de esa consolidación pendiente.

**Consecuencia de diseño aceptada, no un bug:** el color asociado a un cast (verde interrumpible / gris ininterrumpible) puede persistir visualmente en la healthbar después de que el cast termine, incluso aunque la simplificación ya vuelva a estar disponible para el caso ininterrumpible. Es intencional (ver [§18](#18-leyenda-de-color-m-prioridades)) y no debe "arreglarse" quitando la persistencia de color.

---

## 7. Dispatcher y reentrancy

`Dispatcher.ApplyToUnit` es la única entrada al pipeline normal por unidad; `Dispatcher.ApplyToAll` es la entrada para un pase completo (itera `Lifecycle.GetActiveNameplates()`).

**Protección contra reentrancia:** una variable module-level `_isApplying` marca si ya hay un `ApplyToUnit` en curso. Si, mientras se procesa la unidad A, algo (un hook de repintado nativo, un módulo visual, etc.) llama a `Dispatcher.ApplyToUnit` para la unidad B, esa llamada **no se ejecuta inmediatamente** — se encola en `_pendingReentrantUnits[B]`. Si la unidad B ya estaba encolada con `forceUpdate=false` y la nueva petición pide `forceUpdate=true`, domina el `true` (nunca se pierde una petición de forzado por coalescing).

Una vez termina el procesamiento de la unidad que disparó la reentrancia, el propio `ApplyToUnit` de nivel superior drena la cola: procesa todas las unidades pendientes en un "pase" y, si esas llamadas generaron **más** peticiones pendientes, repite el proceso hasta un máximo de `MAX_REENTRANT_PASSES = 10` pasadas. Si se alcanza ese límite y aún quedan unidades pendientes, se registra un error (`Utils.LogGuardedError` o `print` de emergencia) y se descarta la cola restante — esto indica un bug de un módulo que dispara actualizaciones en bucle, y el límite existe exactamente para evitar un desbordamiento de pila o un cuelgue por recursión infinita, no para ser alcanzado en operación normal. Este comportamiento (incluido el disparo del límite ante una recursión artificial de prueba) está cubierto por `tests/equivalence_test.lua`, grupo 4.

**No existe ya un "safety net" con ticker periódico.** Versiones anteriores de la arquitectura contemplaban un `C_Timer.NewTicker` de 2s que forzaba un pase completo incondicional como red de seguridad; ese mecanismo **ha sido eliminado**. `Minimizer.Dispatcher.StartSafetyNet` no existe, y no se crea ningún timer periódico al cargar el addon — confirmado explícitamente por `tests/friendly_filter_safety_net_test.lua` (`Dispatcher.StartSafetyNet == nil`, `#Mocks.timers == 0` tras `ADDON_LOADED`). La actualización de nameplates depende exclusivamente de eventos, del monitor dinámico de Threat, y de las peticiones explícitas de pase completo (`RequestApplyToAll`, debounced a 0 frames vía `Utils.Debounce`).

---

## 8. Recycling de nameplates y seguridad de generación

Blizzard reutiliza los mismos tokens de nameplate (`"nameplate3"`, etc.) para unidades distintas a lo largo de una sesión: un mob muere, su nameplate desaparece, y el mismo token puede asignarse poco después a un mob completamente distinto. Si el estado que Minimizer guarda "colgado" de la nameplate (flags de color persistente, de simplificación persistente, de absorb visto, de estado de monitor de Threat) no se invalida correctamente en ese momento, la unidad nueva puede heredar visualmente el estado de la anterior — dos unidades con condiciones reales opuestas mostrando el mismo color o el mismo estado de simplificación.

La defensa es un contador de generación por token (`Lifecycle.plateGeneration[token]`), incrementado en `NAME_PLATE_UNIT_ADDED`, contra el que se comparan varios flags persistentes:

- `nameplate.MinimizerDesimplifiedPersistentGen` (fast-path de "no simplificar", en `Dispatcher`).
- `nameplate.MinimizerAbsorbPersistentGen` (persistencia de `hasHadAbsorb`, en `Absorb.MarkSeen`).
- `nameplate.MinimizerHealthBarColorGen` (persistencia de color de cast, en `HealthBarColor`).
- El propio `Core/Cache.lua` (usado por `Classification`/`Threat`) trata una entrada como cache-miss si su generación guardada no coincide con la actual.
- `Threat.GetUnitThreatState` incluye la generación como parte de la tabla de estado comparada por `StatesEqual`, así que un cambio de generación por sí solo ya invalida el "estado estable" cacheado por el monitor.

`Lifecycle.IsGenerationStale(tokenOrNameplate, storedGen)` centraliza la comparación (acepta tanto un token string como una nameplate, de la que intenta derivar el token). Aun así, **cada consumidor sigue guardando su propio campo de generación** en vez de apoyarse en un único mecanismo — ver `revision.md` §5 para el estado de esa unificación pendiente; no se debe intentar colapsar estos campos sin pruebas de equivalencia cruzada por cada uno (absorb, color persistente, fast-path de simplificación).

Cubierto extensivamente por tests: `tests/smoke_test.lua` (grupos "Token recycle", "GAP1", "GAP2", tests de secrets A/B) y `tests/equivalence_test.lua` (sección "Cross-Generation Recycle Leak-Prevention Invariant", y el reciclaje de `hasHadAbsorb` en la sección de Absorb).

---

## 9. Filtrado friendly / PvP

`Dispatcher.IsPipelineRelevant(unit)` es el predicado canónico y único punto de exclusión: una unidad se considera **no relevante** para el pipeline principal si es friendly (`Utils.IsFriendlyUnit`, basado en `UnitCanAttack`) o si es un jugador enemigo en PvP (`Utils.IsPvPUnit` — jugador + puede atacar al jugador). Blizzard ya gestiona nativamente esas nameplates mejor de lo que Minimizer podría, así que se dejan sin tocar.

Efecto concreto de la exclusión (verificado por `tests/friendly_filter_safety_net_test.lua`):

- La unidad **nunca entra** en `Lifecycle.ActiveNameplates`.
- **No se construye Snapshot** para ella (`Snapshot.Build` no se llama).
- **No se ejecuta ningún módulo registrado** (`Core.UpdateModules` no se llama) — ni `HealthBarColor`, ni `CastingBar`, ni `Markers` la tocan.
- Si el token que ocupaba se recicla más tarde hacia una unidad enemiga, el `Dispatcher.ForgetUnit` disparado cuando la unidad friendly llegó (en vez de `TrackUnit`) asegura que el monitor de Threat no arrastre estado del token.

Las unidades enemigas normales (PvE) siguen entrando en el pipeline con normalidad; solo se excluyen friendly y PvP enemigo.

**Los overlays Target/Focus no dependen de esta exclusión.** Resuelven su nameplate directamente vía `C_NamePlate.GetNamePlateForUnit("target"/"focus")`, no a través de `ActiveNameplates`, así que siguen reaccionando correctamente a `PLAYER_TARGET_CHANGED`/`PLAYER_FOCUS_CHANGED` y a las altas/bajas de nameplate (`Overlays.OnUnitChanged`) **incluso si la unidad en cuestión es friendly** y por tanto nunca pasó por el pipeline principal. Esto es intencional: puedes tener de focus a un compañero de grupo y seguir viendo su halo/retrato con normalidad.

---

## 10. Eventos

Un único `EventFrame` (`MinimizerEventFrame`, en `Plater/Events.lua`) centraliza el registro de eventos de WoW y traduce cada uno a una llamada al Dispatcher (o a una invalidación de cache de dominio). Categorías, sin listar cada evento individual:

- **Pase completo debounced** (`Dispatcher.RequestApplyToAll`): cambios de zona/dificultad, entrar/salir de combate, cambio de roster/rol/especialización (que además invalidan caches de Threat/Widgets/Interrupt y refrescan el estado del monitor de Threat).
- **Reproceso inmediato de una unidad concreta** (`Dispatcher.ApplyToUnit(unit)`): eventos de cast (`UNIT_SPELLCAST_*`), threat con unidad específica, `UNIT_DISPLAYPOWER`, `UNIT_CLASSIFICATION_CHANGED`, `UNIT_LEVEL`, `UNIT_ABSORB_AMOUNT_CHANGED` — todos pasan primero por `IsPipelineRelevant` para no procesar friendly/PvP.
- **`NAME_PLATE_UNIT_ADDED`/`NAME_PLATE_UNIT_REMOVED`**: gestión de lifecycle (incremento de generación, registro/olvido en Dispatcher y Threat) y notificación a Overlays, según el flujo descrito en [§3](#3-pipeline-de-una-nameplate).
- **`SPELL_UPDATE_COOLDOWN`**: refresca el cache de "interrupt listo" (`Interrupt.RefreshReadyCache`) y, si cambió el estado de "listo", dispara un pase completo; además llama a `Overlays.OnCooldownTick()` para que Target/Focus repinten (con su propio throttle a 30 FPS).
- **Hooks globales** (no eventos, pero parte del mismo modelo de "escuchar, no interceptar"): `hooksecurefunc(NamePlateDriverFrame, "OnNamePlateRemoved", ...)` dispara el teardown de Lifecycle; `hooksecurefunc("CompactUnitFrame_UpdateHealthColor", ...)` dispara `Dispatcher.ApplyToUnit(unit)` para que Minimizer reafirme su color inmediatamente después de que Blizzard repinte nativamente.

Todo evento relacionado con el ciclo de vida de nameplates o de unidades entra exclusivamente por este `EventFrame`; ningún otro archivo registra sus propios eventos de WoW para este propósito.

---

## 11. SpellData: formato y uso

Minimizer centraliza las listas de spells usadas por widgets en `Data/SpellData.lua`. El archivo admite dos formatos de entrada en cada lista:

- Entrada legacy (número): `12345`.
- Entrada enriquecida (recomendada): `{ id = 12345, name = "Avatar" }`.

Reglas:

- El campo `name` (cuando está presente) se muestra en los dropdowns de `Menu.lua`.
- El orden de las entradas es significativo: `Utils.FindKnownSpell` elige el **primer** `spellID` conocido por el jugador en ese orden.
- `Utils.FindKnownSpell` y `Widgets.GetCDSpellID` aceptan ambos formatos y siempre devuelven el `spellID` numérico.

Para añadir/corregir spells por clase, ver `Docs/debt.md`.

---

## 12. Taint / Secrets: checklist canónico

1. **Nunca evaluar un valor potencialmente secreto con `and/or`, `not`, `==`, `>`, etc.** directamente en Lua. Comprobar primero con `issecretvalue(value)` (envuelto en `Utils.IsSecretValue`).
2. **Si el valor es secreto, no lo conviertas a booleano.** Propágalo crudo hacia un sink C-side (`SetAlphaFromBoolean`, `C_CurveUtil.EvaluateColorValueFromBoolean`, etc.).
3. **Cuando no exista una API C-side para el dato secreto**, comprobar si Blizzard ya expone la misma información en un widget nativo (`indicator:IsShown()` — así es como Absorb evita leer el número).
4. `EvaluateColorValueFromBoolean` es **escalar**: `(state, valueIfTrue, valueIfFalse)`; `Utils.EvaluateColorRGB` la envuelve para resolver un color de 3 canales.
5. **Nunca llamar directamente** a `NamePlateDriverFrame:OnNamePlateAdded/Removed`. Solo escuchar con `hooksecurefunc` o eventos.
6. **Proteger hooks de auto-repintado con guardas de reentrancia** (`Utils.GuardedCall`, `Utils.HookRepaintGuard`).
7. **Solo simplificar/tocar nameplates a través de** `C_NamePlateManager.SetNamePlateSimplified`, con guard de disponibilidad (`Utils.IsSimplifiedAvailable`).
8. **Aplicar `SetNamePlateSimplified` solo cuando el estado deseado cambia** (o hay `forceUpdate` explícito).
9. **Toda lectura de threat situation debe verificar `issecretvalue` y `type(x) == "number"`** antes de comparar contra `3`.
10. **Todo dato cacheado debe invalidarse explícitamente** — por evento, o por contador de generación de plate (`Core/Cache.lua`, `Lifecycle.IsGenerationStale`). `Cast.lua` es la única excepción deliberada (no cachea nada, ver [§6](#6-cast-y-absorb)).
11. **No resolver un secreto con `EvaluateBoolean(x,1,0)==1` para luego compararlo.** El resultado de un sink C-side sigue tainted; compararlo revienta el cliente. Los sinks son de un solo sentido, hacia la API C-side final (`SetStatusBarColor`, `SetVertexColor`, `SetAlpha`), no hacia más lógica en Lua.

---

## 13. Known Issues

**Unidades fuera de combate al aparecer (mitigado, no cerrado).** Una unidad recién aparecida puede evaluarse a "simplificar" en su primer `ApplyToUnit`, pero Blizzard puede repintarla maximizada al final de ese mismo frame de inicialización. `NAME_PLATE_UNIT_ADDED` dispara tanto un `ApplyToUnit` inmediato como un pase completo debounced (`forceUpdate=true`) para mitigarlo, pero el propio código reconoce que no está cerrado del todo.

**Target/Focus siempre desimplificados por diseño.** `Decision.ShouldSimplifyUnit` devuelve explícitamente `false, "target"` / `false, "focus"` para alinear el comportamiento del addon con el hecho de que Blizzard ya fuerza esas nameplates a tamaño completo. No es un bug.

**Nameplates que no aparecen en pulls masivos:** limitación del motor de WoW, no de Minimizer. Blizzard tiene un pool interno limitado de nameplates simultáneas; una unidad sin nameplate asignada (`GetNamePlateForUnit` devuelve `nil`) simplemente no tiene widget que pintar hasta que Blizzard le asigne una. En cuanto ocurre (`NAME_PLATE_UNIT_ADDED`), el pipeline normal la procesa sin delay perceptible.

**Persistencia de color de cast tras terminar el cast:** ver [§6](#6-cast-y-absorb) — comportamiento de producto intencional, no un bug.

**Duplicaciones arquitectónicas residuales conocidas y toleradas** (no bloquean funcionalidad, documentadas con más detalle en `revision.md`): `Snapshot.ComputeDisplayKind` como fallback duplicado de la lógica normal de `displayKind`; fallbacks sin Snapshot en `Decision`/`HealthBarColor` que aún llaman a `Threat`/`Absorb`/`Cast` directamente; varios campos de generación ad-hoc (`MinimizerDesimplifiedPersistentGen`, `MinimizerAbsorbPersistentGen`, `MinimizerHealthBarColorGen`) en vez de un único mecanismo.

---

## 14. Testing

Runner principal:

```bash
lua tests/test_all.lua
```

Ejecuta, en procesos separados, y reporta solo los fallos al final:

- `tests/equivalence_test.lua`
- `tests/smoke_test.lua`
- `tests/friendly_filter_safety_net_test.lua`
- `tests/threat_monitor/stable_state_test.lua`
- `tests/benchmark/benchmark.lua`

Cada uno también puede ejecutarse suelto, p. ej. `lua tests/smoke_test.lua`.

Qué garantiza cada familia:

- **`equivalence_test.lua`** — batería de invariantes arquitectónicos post-split: lifecycle de `nilSince`/`nilSpecial` en Threat; `Decision.ShouldUnsimplify`/`ShouldLetBlizzardPaint` consumiendo Snapshot correctamente; persistencia y reciclaje de `hasHadAbsorb` (dueño único: `Absorb`); aislamiento del pool de Snapshot frente a reentrancia (incluida profundidad >10 y el límite de recursión del Dispatcher); ciclo de vida dinámico del monitor de Threat (activo/inactivo según grupo/rol) e idempotencia de `UpdateMonitorState`; estructura y comparación (`StatesEqual`) del estado de Threat; enrutamiento de eventos en `Overlays`; cancelación de reintentos de `HitTest` al reciclar generación; matriz de invariantes de comportamiento (prioridad de `displayKind`, número de llamadas a `UnitCastingInfo`); registro y despacho de eventos (incluyendo que `UNIT_ABSORB_AMOUNT_CHANGED` sí dispara `Dispatcher.ApplyToUnit` para enemigos pero no para friendly); prevención de fugas en reciclaje cross-generación; seguridad de reentrancia del hook de indicador de absorb.
- **`smoke_test.lua`** — suite más amplia y original del proyecto: clasificación (`Classification.GetEliteType`), invalidación de cache de Interrupt en cambio de spec, reglas completas de `Decision.ShouldSimplifyUnit`, lectura de `Cast.GetState`, ambas ramas de `Threat.PlayerHasAggro`, migración de configuración legacy, `Cache.InvalidateUnit`/`InvalidateAll`, reutilización del snapshot por `CastingBar` (sin doble lectura de `UnitCastingInfo`), invalidación de flags persistentes en reciclaje de token (grupos "GAP1"/"GAP2"/"GAP3"), manejo de valores secretos en persistencia de color, toda la tabla de prioridad de color ("PRIORITY"), halo/pips de target, registro `ActiveNameplates` usado por `ApplyToAll`, y una serie final de comprobaciones de "ownership" arquitectónico (qué módulo es dueño de qué responsabilidad).
- **`friendly_filter_safety_net_test.lua`** — confirma que el safety-net por ticker **ya no existe** (`Dispatcher.StartSafetyNet == nil`, cero timers tras `ADDON_LOADED`), y que el filtro friendly/PvP excluye correctamente del pipeline principal (`ActiveNameplates`, Snapshot, Modules) sin afectar a Overlays.
- **`threat_monitor/stable_state_test.lua`** — verifica que 1000 ticks de `ApplyToAll` sobre una unidad con threat estático no generan más de 5 KB de deriva de memoria — valida que la reutilización de tablas de estado en `Threat.GetUnitThreatState` funciona como se espera.
- **`benchmark/benchmark.lua`** — ver [§15](#15-benchmarking); también actúa como test de regresión (falla el proceso si se supera el umbral de rendimiento).

---

## 15. Benchmarking

```bash
lua tests/benchmark/benchmark.lua            # ejecución estándar
lua tests/benchmark/benchmark.lua compare     # además guarda una copia con timestamp y "benchmark_latest.txt"
```

**Qué simula:** 50 nameplates con datos aleatorios (nivel, salud, clasificación, cast inicial, aura). Ejecuta 6 corridas independientes (semillas distintas derivadas de `os.time()`), cada una de 1000 "frames" simulados. En cada frame se avanza el reloj mock 0.01s y se disparan entre 1 y 5 `ApplyToUnit` sobre unidades elegidas al azar (con un 2% de probabilidad de "ráfaga": entre 10 y 30 actualizaciones simultáneas, simulando un pull grande o un cambio de estado masivo). El estado de cada unidad (cast, absorb, threat) se muta aleatoriamente con cierta probabilidad en cada actualización, para ejercitar invalidaciones de cache y flags persistentes, no solo el camino "sin cambios".

**Qué mide, por corrida:**

- `Avg ApplyToUnit` — tiempo medio (ms) por llamada a `Dispatcher.ApplyToUnit`.
- `P50/P90/P99/Max` — percentiles de tiempo por llamada individual. **Nota de resolución:** el reloj de Lua puro (`os.clock()`) tiene granularidad insuficiente para medir llamadas de microsegundos de forma fiable por percentil individual; los números agregados por módulo/función (ver más abajo) son más representativos que estos percentiles crudos.
- `Basura generada (GC)` — KB totales asignados durante la ventana medida (con el recolector detenido explícitamente durante esa ventana, para que el número refleje asignación bruta y no el neto tras recolecciones automáticas a mitad de camino) y KB por llamada a `ApplyToUnit`.
- **Module Breakdown** — tiempo total/por-llamada de cada módulo registrado (`HealthBarColor`, `CastingBar`, `Markers`), mediante wrapping de `UpdateNamePlate`.
- **Funciones no-módulo instrumentadas** — `Decision.ShouldSimplifyUnit`, `Classification.GetEliteType`, `Threat.PlayerHasAggro`, `Absorb.HasAbsorb`, envueltas individualmente porque no aparecerían en el desglose de módulos.
- **Throttle check Target/Focus** — simula 100 eventos `SPELL_UPDATE_COOLDOWN` en ~1s y cuenta cuántas veces se ejecuta realmente `Target:UpdateTargetCDs()`/`Focus:UpdateFace()`; sirve para confirmar que el throttle a 30 FPS sigue limitando el repintado real.
- Un bloque adicional mide de forma aislada el coste de asignación de `Dispatcher.ApplyToAll` en sí mismo (200 muestras, GC detenido), para poder rastrear si iterar `ActiveNameplates` introduce alguna asignación por llamada.

**Agregación y umbral:** tras las 6 corridas, se calcula la **mediana** de `p90`, `avgApplyToUnit` y KB/llamada. Si la mediana de `p90` supera `REGRESSION_THRESHOLD_MS = 2.5` ms, el script termina con `os.exit(1)` — esto es lo que convierte al benchmark en un test de regresión de rendimiento, no solo en una herramienta de medición.

**Dónde se guardan los resultados:**

- Ejecución estándar (`lua tests/benchmark/benchmark.lua`, sin argumento): sobreescribe `tests/results/benchmark_aggregated.txt` con el reporte completo de las 6 corridas más el resumen agregado.
- Con el argumento `compare`: además de lo anterior con otro nombre, escribe una copia con timestamp (`tests/results/benchmark_pre_<fecha>_<hora>.txt`) y una copia sin versionar `tests/results/benchmark_latest.txt`, pensadas para diffear una corrida "antes" contra una corrida "después" de un cambio.
- El `.gitignore` del repositorio preserva explícitamente los archivos `tests/results/BASELINE_*.txt` si existieran, como snapshots de referencia manual.

**Flujo recomendado antes de optimizar algo:** correr el benchmark, guardar el resultado como baseline, cambiar **una** cosa, volver a correrlo, comparar contra el baseline y contra `REGRESSION_THRESHOLD_MS`. No optimizar a ciegas ni interpretar ruido de una sola corrida como una regresión real — por eso se agregan 6 corridas por mediana.

---

## 16. Performance: qué garantiza el código vs. qué observa el benchmark

**Garantías de diseño (verificadas por tests, no solo observadas en benchmark):**

- `UnitCastingInfo`/`UnitChannelInfo` se llaman como máximo una vez por `ApplyToUnit` en el pase normal (ver [§6](#6-cast-y-absorb)).
- El monitor de Threat no genera trabajo de CPU en absoluto cuando está deshabilitado (solo/no-tank), y no fuerza reprocesamiento de unidades cuyo estado de threat no cambió (ver [§5](#5-threat-monitor)).
- El Dispatcher nunca permite recursión sin límite; el techo es `MAX_REENTRANT_PASSES = 10` (ver [§7](#7-dispatcher-y-reentrancy)).
- No existe ningún ticker periódico incondicional (el "safety net" fue eliminado, ver [§7](#7-dispatcher-y-reentrancy)).

**Observaciones de benchmark (estado actual, no una promesa de hardware/runtime futuro):** las últimas corridas agregadas guardadas en `tests/results/benchmark_aggregated.txt` y `tests/results/benchmark_latest.txt` muestran, de forma consistente entre ejecuciones:

- Mediana de `p90` en `0.0000 ms` (muy por debajo del umbral de `2.5 ms`) y `avgApplyToUnit` en torno a `0.06 ms` por llamada.
- Basura generada en torno a `0.86 KB` por llamada a `ApplyToUnit`.
- `HealthBarColor` y `CastingBar` como los módulos más caros (en torno a `8–12 µs`/llamada según la corrida), `Markers` consistentemente el más barato.
- El throttle de Target/Focus reduce ~100 eventos simulados de `SPELL_UPDATE_COOLDOWN` a ~25 repintados reales.

Estos números son el resultado de un entorno de test en Lua puro con mocks, no del cliente real de WoW — sirven como indicador de tendencia y como red de regresión relativa (comparar una corrida contra otra), no como cifra de rendimiento en juego. Si una corrida puntual difiere mucho de las guardadas, no se debe asumir automáticamente una regresión sin repetir la medición.

---

## 17. Mapa de módulos y orden de carga

Orden de carga tal como aparece en `Minimizer.toc` (el orden importa: cada archivo asume que las dependencias que declara arriba en esta lista ya existen):

```
Bootstrap.lua              Minimizer (namespace global, ADDON_LOADED -> Config.Initialize + Options.Initialize)
Core/Utils.lua             Minimizer.Utils (helpers puros, guardas de secretos, debounce/throttle)
Overlays/Widgets.lua       Minimizer.Widgets (castbars, halos, pips, cooldowns, cache de override de CD)
Plater/HitTest.lua         Minimizer.HitTest (sincroniza hit-test con healthBar, retry generation-safe)
Config.lua                 Minimizer.Config (SavedVariables, defaults, migraciones legacy)
Core/Constants.lua         Minimizer.Constants (paletas de color)
Data/SpellData.lua         Minimizer.Data (spellIDs por clase)
Plater/Lifecycle.lua       Minimizer.Lifecycle (ActiveNameplates, generación de plates, teardown genérico)
Core/Cache.lua             Minimizer.Cache (cache genérico gen-gated vía Lifecycle)
Plater/Dispatcher.lua      Minimizer.Dispatcher (orquestación, reentrancia, monitor dinámico de Threat)
Plater/Threat.lua          Minimizer.Threat (datos de threat/tank, ThreatState desacoplado)
Plater/Absorb.lua          Minimizer.Absorb (dueño único de absorb live + persistente)
Plater/Cast.lua            Minimizer.Cast (lectura SIN cache de cast/channel)
Plater/Classification.lua  Minimizer.Classification (boss/miniboss/caster/melee/trivial)
Plater/Snapshot.lua        Minimizer.Snapshot (pool por profundidad, Build, ComputeDisplayKind fallback)
Plater/Decision.lua        Minimizer.Decision (ShouldSimplifyUnit, ShouldUnsimplify, ShouldLetBlizzardPaint)
Plater/Interrupt.lua       Minimizer.Interrupt (spellID de interrupt + cache "listo" por pase)
Plater/Core.lua            Minimizer.Core (registro/fan-out de módulos visuales, RegisterModule/UpdateModules)
Plater/Markers.lua         módulo registrado: flechas de target/focus
Plater/HealthBarColor.lua  módulo registrado: color de healthbar nativa + overshield
Plater/CastingBar.lua      módulo registrado: color de castbar nativa + borde "me apunta a mí"
Overlays/Pips.lua          Minimizer.Pips (pips compartidos por Target y Focus)
Overlays/Overlays.lua      Minimizer.Overlays (registro y enrutamiento: OnCooldownTick, OnUnitChanged)
Overlays/Focus.lua         Minimizer.Focus (retrato de focus, CD de interrupt, pip)
Overlays/Target.lua        Minimizer.Target (halo de CD ofensivo + pip sobre el target)
Menu.lua                   Minimizer.Menu (frame propio de opciones, dev/fallback, /mini menu)
Options.lua                Minimizer.Options (panel de Blizzard Settings que abre Menu)
Plater/Events.lua          EventFrame centralizado, traducción de eventos al Dispatcher
SlashCommands.lua          /mini
```

---

## 18. Leyenda de color M+ (prioridades)

Prioridad descendente — la primera regla que aplica gana. Implementada una sola vez en `Snapshot.ResolveDisplayKind` y consumida por `Decision` y por los módulos de rendering vía `snapshot.displayKind`.

| Prioridad | Condición | Color | Simplificación |
|-----------|-----------|-------|-----------------|
| 1 | **Focus** | Amarillo | Sin cambio (focus no altera simplificación) |
| 2 | **Prioridad especial de threat** (`nilSpecial`: no puede atacarte y lleva ≥1s de threat `nil` en combate) | Naranja | — |
| 3 | **Aggro** (situación 3, o rama especial de tank) | Rojo gestionado por Blizzard | TEMPORAL (mientras dura) |
| 4 | **Shield/Absorb** visto alguna vez | Rosa (`absorb`), **PERSISTENTE** | **PERSISTENTE** (desimp y color) |
| 5 | **Superior** (boss/miniboss) | Morado, SIEMPRE, cast o no | "no simp" **PERSISTENTE** |
| 6 | **Caster** (inferior con maná) | Azul, no cambia por cast/channel | **PERSISTENTE** (nunca fue simplificable) |
| 7 | **Inferior** (melee/trivial) + cast/channel **interrumpible** | Verde, **PERSISTENTE** (color) | **PERSISTENTE** ("no simp") |
| 8 | **Inferior** + cast/channel **ininterrumpible** | Gris, **PERSISTENTE** (color) | **TEMPORAL** (vuelve a poder simplificarse al terminar el cast) |

Definiciones: **superior** = `boss`/`miniboss` (nivel skull, worldboss, o elite + 2 niveles por encima del jugador). **Inferior** = cualquier unidad que no sea superior. **Persistente** = el flag/color permanece incluso después de terminar la condición que lo causó, hasta reciclaje de token. **Temporal** = desaparece en cuanto desaparece la condición.

**Rationale M+:** en Mythic+, cualquier inferior que castee algo interrumpible es wipe potencial si no se para; el verde persistente le dice al grupo que esa unidad ya demostró capacidad de castear y merece seguir priorizada aunque el cast actual haya terminado. El gris (ininterrumpible) es peligroso pero no accionable — no hace falta mantenerlo desimplificado una vez termina. El absorb, una vez visto, queda en el "historial visual" de la plate: tanto el color como la desimplificación persisten para no perder esa información al reciclar la plate o ante un repintado nativo. Los superiores son siempre peligrosos; su color no depende de si su cast es interrumpible porque el grupo ya sabe que hay que interrumpirlos de todas formas. Los casters (azules) intencionalmente no siguen la regla de cast — solo cambian de color por focus/aggro/absorb.
