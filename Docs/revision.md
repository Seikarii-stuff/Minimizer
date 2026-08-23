# Arquitectura — revisión y deuda residual

**Estado:** revisión posterior al split arquitectónico principal (`Lifecycle → Dispatcher → Snapshot → Decision → Rendering`) y a la ronda posterior de optimización/estabilización de Threat Monitor, Snapshot y tooling de tests/benchmark.
**Rama de referencia:** `main`.
**Propósito:** este documento no es un README ni un changelog línea por línea. Es el registro de (a) qué quedó **aprobado y estable** en la arquitectura actual, (b) qué deuda arquitectónica **residual** queda identificada para un futuro split, y (c) qué invariantes **no deben romperse** al tocar cualquiera de esas áreas.
**Criterio:** ninguno de los puntos de deuda listados aquí es bloqueante para el estado actual del addon ni justifica, por sí solo, otro refactor inmediato.

---

## 0. Qué cambió desde la revisión anterior de este documento

La revisión anterior de `revision.md` asumía una arquitectura con `Core.StartSafetyNet` (ticker de 2s) todavía presente como wrapper de compatibilidad, y un Threat Monitor recién trasladado al Dispatcher pero sin la capa de activación/desactivación dinámica ni el estado estable (`GetUnitThreatState`/`StatesEqual`) descritos abajo. Desde entonces:

- **El safety-net por ticker fue eliminado por completo**, no solo desplazado. No existe `Dispatcher.StartSafetyNet`, y no se crea ningún `C_Timer.NewTicker` periódico al cargar el addon. Esto está verificado explícitamente por `tests/friendly_filter_safety_net_test.lua`. La actualización de nameplates depende exclusivamente de: eventos de WoW, el monitor dinámico de Threat, y peticiones explícitas de pase completo debounced.
- **El monitor de Threat ganó activación/desactivación dinámica** (`Dispatcher.UpdateMonitorState`, gateado por `Threat.IsThreatEnabled()`) y un mecanismo de "estado estable" (`Threat.GetUnitThreatState` + `StatesEqual`) que evita generar tablas nuevas en cada tick cuando nada cambió — cubierto por `tests/threat_monitor/stable_state_test.lua` (deriva de memoria ≤5 KB en 1000 ticks sobre una unidad estática).
- **El Snapshot ganó un pool por profundidad de recursión** (`snapshotPool[depth]`, `currentDepth`) en vez de una única tabla `scratch` reutilizada. Esto resuelve el riesgo, señalado en la revisión anterior, de que una construcción anidada de snapshot corrompiera el snapshot de la unidad que la disparó. Verificado por `tests/equivalence_test.lua` (sección de reentrancia, incluida profundidad ≥10).
- **El Dispatcher ganó una cola de reentrancia explícita y coalescida** (`_pendingReentrantUnits`, dominancia de `forceUpdate`, `MAX_REENTRANT_PASSES = 10`), reemplazando cualquier suposición implícita anterior sobre reentrancia segura.
- **Se añadió infraestructura de tests y benchmark significativamente más amplia:** `tests/test_all.lua` como runner unificado, `tests/equivalence_test.lua` como batería de invariantes arquitectónicos, `tests/friendly_filter_safety_net_test.lua`, `tests/threat_monitor/stable_state_test.lua`, y un `tests/benchmark/benchmark.lua` con modo `compare`, agregación por mediana de 6 corridas, y persistencia en `tests/results/` (`benchmark_aggregated.txt`, `benchmark_latest.txt`, y copias con timestamp bajo modo `compare`). El `.gitignore` preserva explícitamente cualquier `tests/results/BASELINE_*.txt`.

El resto de la arquitectura descrita en revisiones previas (Lifecycle como dueño único de generación/`ActiveNameplates`, Snapshot como fuente única de `displayKind` en el pase normal, Decision como dueño de las reglas de negocio, Absorb como dueño único de persistencia) se mantiene sin cambios de fondo y sigue siendo válida.

---

## 1. Snapshot: duplicación residual de `ComputeDisplayKind`

### Estado actual

La ruta normal sigue siendo:

```
Dispatcher.ApplyToUnit → Snapshot.Build → ResolveDisplayKind → snapshot.displayKind
```

`Snapshot.ComputeDisplayKind(unit, nameplate)` sigue existiendo únicamente como fallback para `HealthBarColor` cuando se la invoca **sin** snapshot (hooks de repintado nativo de Blizzard fuera del pase normal).

### Problema arquitectónico

`ComputeDisplayKind` reconstruye parte del estado que `Snapshot.Build` ya captura (incluida una llamada a `Absorb.MarkSeen`, que persiste `hasHadAbsorb` de forma independiente a la del pase normal). Ambas funciones comparten `ResolveDisplayKind` como núcleo de la tabla de prioridad — eso ya elimina el riesgo de que la *prioridad* diverja — pero la *captura de datos* previa a esa función sigue duplicada entre las dos rutas.

### Trabajo futuro

1. Inventariar todos los consumidores actuales de `ComputeDisplayKind` (a día de hoy: `HealthBarColor.UpdateNamePlate`, únicamente en su rama sin-snapshot).
2. Evaluar si esos caminos sin-snapshot pueden, en cambio, recibir un snapshot fresco construido bajo demanda (vía `Dispatcher.ApplyToUnit`) en vez de tener su propio camino paralelo — sin crear una segunda reentrancia hacia el Dispatcher desde dentro de un hook de repintado.
3. Si no es viable sin introducir reentrancia insegura, mantenerlo como fallback pero documentar explícitamente por qué debe existir, y minimizar cuánto estado recalcula.
4. No cambiar, bajo ningún concepto, la prioridad de `displayKind` en el proceso.

**Prioridad:** media. **Riesgo:** medio si se toca sin verificar los hooks de repintado de `HealthBarColor` contra los tests de "PRIORITY" de `tests/smoke_test.lua`.

---

## 2. Dispatcher ↔ Threat: frontera de scheduling todavía no puramente unidireccional

### Estado actual

El scheduler y el monitor round-robin viven correctamente centralizados en `Dispatcher` (`monitorFrame`, `RebuildMonitorUnits`, `ProcessMonitoredUnit`, `UpdateMonitorState`). `Threat.lua` ya no posee ningún `OnUpdate` propio.

Sin embargo, durante el procesamiento del monitor, `Dispatcher.ProcessMonitoredUnit` **consulta directamente** `Threat.GetUnitThreatState`/`Threat.StatesEqual` para decidir si una unidad cambió de estado. Conceptualmente:

```
Dispatcher  ──consulta──>  Threat
```

en vez del contrato más puro:

```
Threat  ──notifica/invalida──>  Dispatcher
```

### Problema arquitectónico

El *ownership* del scheduler ya está correctamente centralizado en Dispatcher (no hay dos dispatchers compitiendo). Lo que queda pendiente es que la frontera entre "quién sabe si algo de dominio cambió" (Threat) y "quién decide actuar en consecuencia" (Dispatcher) todavía requiere que Dispatcher conozca la forma interna del estado de Threat (`GetUnitThreatState`, `StatesEqual`), en vez de que Threat exponga una interfaz de invalidación más genérica y opaca.

### Trabajo futuro

Evaluar si el monitor puede seguir siendo propiedad de `Dispatcher` mientras la señal de "esto cambió" se expone mediante una interfaz de invalidación más neutra (p. ej. que Threat notifique un booleano de "cambio detectado" en vez de que Dispatcher compare dos snapshots de estado con conocimiento de su forma).

**No mover el scheduler de vuelta a `Threat.lua`.** No modificar la cadencia actual (`0.25 / monitorCount`), `monitorStep`, `StatesEqual`, ni la memoización del estado de tank (`playerTankCache`/`playerTankCacheValid`).

**Prioridad:** media-baja. **Riesgo:** alto si se toca el algoritmo de monitorización sin ejecutar antes `tests/threat_monitor/stable_state_test.lua` y la sección de "Threat Dynamic Monitor Lifecycle" de `tests/equivalence_test.lua`.

---

## 3. Decision: fallbacks sin Snapshot todavía presentes

### Estado actual

En el pipeline normal, `Decision.ShouldSimplifyUnit`/`ShouldUnsimplify`/`ShouldLetBlizzardPaint` consumen el Snapshot correctamente. Siguen existiendo, no obstante, ramas explícitas para el caso en que se les llama **sin** snapshot (`snapshot == nil`), que en ese caso consultan directamente `Threat.GetThreatDetails`/`IsInCombatWith`/`IsPlayerTank`, `Absorb.HasAbsorb`/`MarkSeen`, y `Cast.GetState`.

### Problema arquitectónico

El contrato final deseado es que `Decision` no necesite conocer la existencia de `Threat`/`Absorb`/`Cast` como módulos independientes — solo el Snapshot. Los fallbacks actuales son funcionalmente correctos (producen el mismo resultado que si hubiera snapshot) y no representan un bug, pero mantienen acoplamiento residual y una segunda ruta de cálculo a mantener sincronizada con la primera.

### Trabajo futuro

1. Inventariar cada caller de `Decision.*` que hoy puede llegar sin snapshot (a día de hoy: los mismos hooks de repintado nativo de `HealthBarColor`/`CastingBar` que motivan el punto 1).
2. Determinar si esos callers pueden enrutarse a través de `Dispatcher.ApplyToUnit` (que sí construye snapshot) en vez de llamar a `Decision` directamente.
3. Migrar los callers de uno en uno, verificando equivalencia de resultado en cada paso.
4. Eliminar los fallbacks únicamente cuando no quede ningún consumidor legítimo sin snapshot.

**Prioridad:** baja. **Riesgo:** medio.

---

## 4. Absorb: fallbacks de `MarkSeen` fuera del Snapshot

### Estado actual

`Absorb.MarkSeen` es la única función que escribe `nameplate.MinimizerHasHadAbsorb`, y `Snapshot.Build` la invoca exactamente una vez por pase normal, exponiendo el resultado como `snapshot.hasHadAbsorb`. La ruta normal no duplica esta llamada.

Persisten, sin embargo, invocaciones a `Absorb.MarkSeen` en los caminos de fallback sin snapshot de `Decision` y `HealthBarColor` (mismo origen que los puntos 1 y 3: hooks de repintado nativo).

### Problema arquitectónico

Mismo patrón que el punto 3, aplicado específicamente a la persistencia de absorb: mientras existan caminos sin snapshot, `MarkSeen` puede invocarse más de una vez por unidad en el mismo frame desde sitios distintos — no produce un resultado incorrecto (la función es idempotente respecto al resultado final), pero sí trabajo/llamadas redundantes.

### Trabajo futuro

Eliminar las llamadas de fallback a `MarkSeen` únicamente cuando **todos** los caminos de rendering/decision puedan garantizar que reciben snapshot (ver puntos 1 y 3, de los que este depende). Mantener `Absorb.GetTotalAbsorbs` como API de dominio para el overshield — no convertir ese valor numérico en estado persistente del Snapshot salvo que un diseño futuro lo requiera explícitamente.

**Prioridad:** baja-media. **Riesgo:** medio, por la semántica de persistencia y reciclaje de generación que ya está cubierta por tests (`GAP1`, tests de secrets A/B en `smoke_test.lua`; sección de Absorb en `equivalence_test.lua`) — cualquier cambio aquí debe volver a pasar esas mismas comprobaciones.

---

## 5. Campos de generación ad-hoc: unificación todavía incompleta

### Estado actual

La comprobación de "¿este token fue reciclado?" ya está centralizada en `Lifecycle.GetGeneration`/`Lifecycle.IsGenerationStale`. Sin embargo, cada consumidor de esa comprobación sigue guardando **su propio campo** de generación en la nameplate en vez de compartir un único mecanismo de almacenamiento:

- `nameplate.MinimizerDesimplifiedPersistentGen` (Dispatcher, fast-path de simplificación).
- `nameplate.MinimizerAbsorbPersistentGen` (Absorb, persistencia de `hasHadAbsorb`).
- `nameplate.MinimizerHealthBarColorGen` (HealthBarColor, persistencia de color de cast).

### Problema arquitectónico

El *algoritmo* de validación de generación ya es único (`IsGenerationStale`); lo que sigue disperso es la *representación* del estado por consumidor. No es una inconsistencia funcional — cada campo se invalida correctamente contra su propio consumidor — pero es tres reinvenciones del mismo patrón de almacenamiento.

### Trabajo futuro

Evaluar si estos tres campos pueden sustituirse por una representación común (p. ej. un único mapa `nameplate.MinimizerGenerations[kind] = gen`) sin perder ninguna de las siguientes garantías, cada una con su propia cobertura de test que debe seguir pasando exactamente igual:

- seguridad frente a reciclaje de token (`tests/equivalence_test.lua`, "Cross-Generation Recycle Leak-Prevention");
- persistencia correcta de "no simp" (`tests/smoke_test.lua`, "GAP2");
- persistencia correcta de absorb (`tests/smoke_test.lua`, "GAP1"; tests de secrets A/B);
- persistencia correcta de color de healthbar tras terminar un cast.

**No eliminar campos por estética.** La seguridad de reciclaje tiene prioridad absoluta sobre la limpieza estructural.

**Prioridad:** baja. **Riesgo:** alto si se modifica sin pruebas cross-generation específicas para cada uno de los tres flags.

---

## 6. Lifecycle: `ClearNeverSimplify` sigue coordinando teardown de otros dominios

### Estado actual

`Lifecycle` es el dueño de `ActiveNameplates` y de las generaciones, pero `Lifecycle.ClearNeverSimplify` sigue siendo quien coordina la limpieza de estado en otros módulos al retirar una nameplate: invalida `Cache`, llama al no-op de `Cast.InvalidateState`, cancela reintentos de `HitTest`, olvida el estado de `Threat`, y ejecuta `OnNamePlateRemoved` de cada módulo de Plater registrado.

Nota adicional respecto a revisiones anteriores: **el teardown de `Threat`/`Dispatcher` ya no depende exclusivamente de `Lifecycle.ClearNeverSimplify`.** El handler del evento `NAME_PLATE_UNIT_REMOVED` en `Events.lua` llama directamente a `Threat.ForgetUnit` y `Dispatcher.ForgetUnit` (y notifica a `Overlays.OnUnitChanged`) **antes** de que el hook de `NamePlateDriverFrame:OnNamePlateRemoved` dispare `Lifecycle.ClearNeverSimplify`. Es decir, hoy hay dos disparadores de teardown en momentos distintos (el evento, y el hook), cada uno responsable de una parte distinta de la limpieza — esto es intencional (el evento es más inmediato para lo que Threat/Dispatcher necesitan; el hook es el único punto fiable para el teardown genérico de nameplate), pero añade otra superficie a tener en cuenta si se toca el orden de teardown.

### Problema arquitectónico

La arquitectura objetivo original preveía un Lifecycle con dependencias mínimas. El teardown actual es funcional y está cubierto por tests, pero `Lifecycle` sigue conociendo la existencia de varios dominios (`Cache`, `Cast`, `HitTest`, `Threat`, y la lista de módulos registrados) para poder limpiarlos.

### Trabajo futuro

Evaluar un mecanismo de teardown más desacoplado (p. ej. que `Lifecycle` publique un evento de "nameplate retirada" y cada dominio se suscriba para limpiar su propio estado), sin devolver la propiedad de generaciones/`ActiveNameplates` a ningún otro módulo. No convertir esto en una reescritura de Lifecycle sin necesidad concreta.

**Prioridad:** baja. **Riesgo:** medio-alto — el orden actual entre el evento `NAME_PLATE_UNIT_REMOVED` y el hook `OnNamePlateRemoved` no está garantizado por Blizzard de forma explícita; cualquier cambio aquí debe volver a ejecutar la suite de recycling/teardown completa (`smoke_test.lua`, `equivalence_test.lua`) antes y después.

---

## 7. `ADDON_LOADED`: consolidación opcional

### Estado actual

La inicialización principal (`Config.Initialize`, `Options.Initialize`) está centralizada en un único listener de `ADDON_LOADED` en `Bootstrap.lua`. No se ha identificado, en la revisión actual del código, ningún segundo listener independiente de `ADDON_LOADED` fuera de este.

### Trabajo futuro

Esta tarea queda como **opcional** y de prioridad baja: si en el futuro se añade un nuevo módulo con necesidad de inicialización propia tras `ADDON_LOADED`, evaluar si debe registrar su propio listener o si debe recibir una llamada explícita desde `Bootstrap.lua`, para no reintroducir múltiples puntos de entrada de lifecycle del propio addon.

**Prioridad:** baja/opcional.

---

## 8. `HookIndicator` (Absorb) — mantener hasta evidencia concreta de redundancia

### Estado actual

Se mantienen dos mecanismos capaces de disparar un reproceso de la nameplate cuando cambia el estado visual de absorb:

```
UNIT_ABSORB_AMOUNT_CHANGED  ──>  Dispatcher.ApplyToUnit
HookIndicator (Show/Hide del overlay de absorb)  ──>  Dispatcher.ApplyToUnit
```

El segundo es un hook de repintado/overlay protegido contra reentrancia (usa el mismo patrón de guarda que el resto de hooks de repintado nativo).

### Decisión

**No eliminar `HookIndicator` sin una prueba concreta de que es redundante frente al evento.** La existencia de ambos caminos no implica dos dueños de la decisión — ambos son, en última instancia, invalidadores que terminan pidiéndole al mismo Dispatcher que reprocese la unidad; no hay dos algoritmos de decisión compitiendo, solo dos disparadores hacia el mismo punto de entrada.

### Trabajo futuro

Investigar únicamente si una versión futura de la API de Blizzard (o un cambio de comportamiento del indicador nativo) hace innecesario mantener el hook. No es una tarea activa.

**Prioridad:** informativa. **Estado:** mantener.

---

## 9. Invariantes que NO deben cambiar en el próximo split

Cualquier futuro cambio arquitectónico debe preservar explícitamente, y verificar contra la suite de tests indicada entre paréntesis:

**Dispatcher / reentrancia** (`equivalence_test.lua`, sección 4)
- Coalescing de reentrancia con dominancia de `forceUpdate`.
- Límite de seguridad `MAX_REENTRANT_PASSES = 10`.
- `Dispatcher.ApplyToUnit` como única entrada al pipeline normal por unidad; `Dispatcher.ApplyToAll` como entrada de pase completo.
- Ausencia de cualquier ticker periódico incondicional ("safety net") — no reintroducirlo (`friendly_filter_safety_net_test.lua`).

**Threat** (`equivalence_test.lua` secciones 1, 5, 6; `threat_monitor/stable_state_test.lua`)
- Cadencia `0.25 / monitorCount`.
- `monitorStep` como puntero round-robin.
- `Threat.StatesEqual` y la reutilización de tablas de estado cuando nada cambió.
- Memoización/refresh del estado de tank (`playerTankCache`) y su invalidación explícita en roster/spec change.
- Activación/desactivación dinámica del monitor según `IsThreatEnabled()` (grupo/raid/tank), e idempotencia de `UpdateMonitorState`.
- Heurística de `nilSince`/`nilSpecial` (confirmación tras ≥1.0s de threat `nil` en combate contra una unidad que no puede atacar al jugador).
- Limpieza completa de estado (`nilState`, `unitThreatStateCache`) al retirar una nameplate.

**Cast** (`equivalence_test.lua` secciones 4 y 9; `smoke_test.lua`)
- Sin cache — cada `Cast.GetState` llama a la API nativa.
- Exactamente una lectura por `ApplyToUnit` cuando se consume vía Snapshot; los fallbacks sin snapshot pueden releer.

**Lifecycle** (`equivalence_test.lua` sección 11; `smoke_test.lua` grupos de recycle)
- `ActiveNameplates` como registro único.
- Generación por token, incrementada solo en `NAME_PLATE_UNIT_ADDED`.
- `IsGenerationStale` como comparación centralizada (aunque el almacenamiento siga fragmentado, ver punto 5).
- Ningún estado de la unidad anterior debe sobrevivir a un reciclaje de token.

**Snapshot** (`equivalence_test.lua` sección 4; `smoke_test.lua` grupo "PRIORITY")
- Pool por profundidad de recursión, no una única tabla scratch.
- `displayKind` y su prioridad exacta (focus > prioridad de threat > aggro > absorb > eliteType).
- `hasAbsorb` (live) y `hasHadAbsorb` (persistente) como conceptos distintos.
- Estado de cast/channel expuesto tal cual lo devuelve `Cast.GetState`, sin reinterpretación.
- `isFriendly`/`isPvP` calculados una vez y reutilizados por todos los consumidores del pase.

**Rendering / Overlays** (`smoke_test.lua`; `friendly_filter_safety_net_test.lua`)
- `HealthBarColor`/`CastingBar` deben consumir Snapshot cuando esté disponible, y solo recalcular por su cuenta en el fallback sin snapshot.
- `HookIndicator` debe seguir terminando en `Dispatcher.ApplyToUnit` (ver punto 8).
- Target/Focus mantienen su throttle visual a 30 FPS y su independencia de `ActiveNameplates`.
- Pips/Widgets mantienen su desacoplamiento del pipeline de decisión.
- El filtro friendly/PvP (`Dispatcher.IsPipelineRelevant`) sigue excluyendo del pipeline principal sin afectar a Overlays.

---

## 10. Criterio para el siguiente split arquitectónico

El siguiente split **no debe comenzar por una limpieza general del código**. Orden recomendado, cada paso pequeño, reversible, y acompañado de tests de equivalencia antes de tocar el paso siguiente:

1. Auditar y, si es viable, consolidar `Snapshot.ComputeDisplayKind` (punto 1).
2. Auditar la frontera Dispatcher ↔ Threat en el monitor (punto 2).
3. Eliminar fallbacks sin Snapshot en `Decision` cuando exista cobertura equivalente (punto 3), lo que a su vez habilita simplificar los fallbacks de `Absorb.MarkSeen` (punto 4).
4. Revisar la unificación de los campos de generación ad-hoc (punto 5) — solo después de que los puntos 1, 3 y 4 reduzcan el número de sitios que dependen de cada campo.
5. Solo entonces considerar el desacoplamiento del teardown de `Lifecycle` (punto 6).
6. `ADDON_LOADED` (punto 7) y `HookIndicator` (punto 8) quedan como tareas opcionales/informativas, sin orden estricto respecto a las anteriores.

---

## Estado de cierre de esta revisión

La migración arquitectónica principal, más la ronda de estabilización de Threat Monitor/Snapshot/Dispatcher y la ampliación de la suite de tests y benchmark, quedan **aprobadas funcionalmente**. Este documento no describe bugs conocidos ni tareas bloqueantes: describe la diferencia entre la implementación estable actual (verificada por `tests/test_all.lua` en verde) y la forma más estrictamente desacoplada que un futuro split podría alcanzar.

La prioridad de cualquier trabajo futuro sobre esta base debe seguir siendo **reducir la deuda arquitectónica residual listada arriba sin alterar comportamiento observable**, verificando cada paso contra la suite de tests y contra el benchmark antes de considerarlo terminado.
