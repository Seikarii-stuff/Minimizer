# Arquitectura actual — Minimizer

> Documento generado por auditoría arquitectónica. **No se ha modificado ningún archivo de código fuente del addon.** Este documento es analítico y de planificación únicamente.
>
> Convención usada en todo el documento:
> - **[OBSERVADO]** — comportamiento verificado leyendo el código fuente provisto.
> - **[INFERENCIA]** — deducción razonable a partir de lo observado, no verificada línea por línea contra cliente real.
> - **[PROPUESTA]** — arquitectura futura, todavía no implementada.
> - **`REQUIERE VALIDACIÓN`** — algo que no puede confirmarse solo con el código disponible.
> - **`BUG EXISTENTE — NO CORREGIR DURANTE MIGRACIÓN`** — comportamiento incorrecto o inconsistente que debe preservarse tal cual hasta después de la migración.

Archivos analizados (34 documentos recibidos, todo el árbol relevante del addon salvo la rama `split-architectonico` que no se adjuntó como contenido, solo como referencia de estructura de carpetas):

```
Bootstrap.lua
Core/Utils.lua
Core/Cache.lua
Core/Constants.lua
Config.lua
Menu.lua
Options.lua
SlashCommands.lua
Data/SpellData.lua
Overlays/Widgets.lua
Overlays/Focus.lua
Overlays/Target.lua
Plater/Core.lua
Plater/Events.lua
Plater/Threat.lua
Plater/Absorb.lua
Plater/Cast.lua
Plater/Classification.lua
Plater/Decision.lua
Plater/Interrupt.lua
Plater/HealthBarColor.lua
Plater/CastingBar.lua
Plater/Markers.lua
Plater/HitTest.lua
Minimizer.toc
README.md
Docs/debt.md
.gitignore
tests/smoke_test.lua
tests/wow_mock.lua
tests/run_cast_debug.lua
tests/run_absorb_debug.lua
tests/benchmark/benchmark.lua
```

Total: **27 archivos de código/config** + 3 archivos de test + README/debt.md/.gitignore = **34 documentos**.

---

## 1. Mapa general

El addon simplifica nameplates enemigas usando `C_NamePlateManager.SetNamePlateSimplified` y añade encima: color de healthbar/castbar según una "leyenda M+", marcadores de target/focus, halos/pips de cooldown sobre target y focus, y sincronización del hit-test.

El ciclo de vida hoy tiene **tres motores de actualización coexistiendo** en vez de uno:

1. **Eventos → `Core.ApplyToUnit` / `Core.RequestApplyToAll`** (`Plater/Events.lua` es quien decide, evento por evento, si aplica inmediato a una unidad o si debe debouncar un pase completo).
2. **`Threat.StartMonitor`** — un `OnUpdate` propio en `Plater/Threat.lua` que recorre `Minimizer.ActiveNameplates` por su cuenta y llama `Core.ApplyToUnit` directamente, en round-robin, independientemente del pipeline de eventos.
3. **`Core.StartSafetyNet`** — un `C_Timer.NewTicker(2.0, ...)` en `Plater/Core.lua` que llama `Core.ApplyToAll(false)` cada 2 segundos como red de seguridad.

Además, `Overlays/Focus.lua` y `Overlays/Target.lua` **no están registrados como módulos de `Core`** (no llaman `Core.RegisterModule`). Se actualizan por su cuenta desde `Plater/Events.lua` (llamadas directas a `Focus:UpdateFace()` / `Target:UpdateTargetCDs()`) y desde un throttle propio de 30 FPS (`Minimizer.Utils.Throttle`) enganchado al evento `SPELL_UPDATE_COOLDOWN`. Es decir: existe el pipeline de "módulos registrados" (`HealthBarColor`, `CastingBar`, `Markers`) que sí pasan por `Core.UpdateModules` con `snapshot` compartido, y existe un segundo pipeline paralelo, no unificado, para Target/Focus.

---

## 2. Estructura de carpetas actual

```
Minimizer/
├── Plater/
│   ├── Events.lua        (dispatcher de eventos + 2 hooksecurefunc globales)
│   ├── Core.lua           (registro de módulos, snapshot, lifecycle, ApplyToUnit/All)
│   ├── Threat.lua         (aggro/tank + su propio monitor OnUpdate)
│   ├── Absorb.lua         (detección visual de absorb, sin cache propio)
│   ├── Cast.lua           (lectura de cast/channel, sin cache deliberadamente)
│   ├── Classification.lua (boss/miniboss/caster/melee/trivial, con cache)
│   ├── Decision.lua       (ShouldSimplifyUnit)
│   ├── Interrupt.lua      (spellID de interrupt + cache "ready" de pase)
│   ├── HealthBarColor.lua (módulo visual registrado)
│   ├── CastingBar.lua     (módulo visual registrado)
│   ├── Markers.lua        (módulo visual registrado)
│   └── HitTest.lua        (sincroniza hit-test con la healthbar)
│
├── Overlays/
│   ├── Target.lua   (NO registrado en Core; throttle propio)
│   ├── Focus.lua    (NO registrado en Core; throttle propio)
│   └── Widgets.lua  (búsqueda de castbar, halos, pips, cooldowns, cache de CD spell)
│
├── Core/
│   ├── Cache.lua     (cache genérico unit->kind->valor, gen-gated)
│   ├── Constants.lua (paletas de color, estático)
│   └── Utils.lua     (helpers puros + Debounce/Throttle + resolución de secrets)
│
├── Data/
│   └── SpellData.lua (spellIDs estáticos por clase)
│
├── Bootstrap.lua      (ADDON_LOADED → Config.Initialize + Core.StartSafetyNet)
├── Menu.lua           (frame propio de opciones, dev/fallback)
├── Options.lua        (panel de Blizzard Settings que abre Menu; su propio listener ADDON_LOADED)
├── Config.lua         (SavedVariables, defaults, migración legacy)
├── SlashCommands.lua  (/mini)
└── Minimizer.toc
```

**Nota:** esta es solo una reorganización física (rama `split-architectonico`). Como pide el encargo, no se asume que esta clasificación por carpeta sea la correcta conceptualmente — de hecho varios archivos de `Plater/` hacen cosas que no son "Plater" (p.ej. `Threat.lua` tiene su propio dispatcher; `Core.lua` mezcla snapshot+lifecycle+decisión+rendering-trigger).

---

## 3. Componentes y responsabilidades

Para cada módulo: responsabilidad, estado, datos leídos, APIs de WoW, dependencias salientes/entrantes, eventos, timers/frames, caches, funciones públicas/internas clave, efectos secundarios, y qué hace que conceptualmente no le pertenece.

### 3.1 `Bootstrap.lua`

- **Responsabilidad real:** inicialización del namespace global y arranque de `Config`/`Core` tras `ADDON_LOADED`.
- **Estado:** ninguno propio (crea `bootstrapFrame`).
- **APIs WoW:** `CreateFrame`, `RegisterEvent("ADDON_LOADED")`.
- **Llama a:** `Minimizer.Config.Initialize()`, `Minimizer.Core.StartSafetyNet()`.
- **Quién lo consulta:** nadie (es el punto de entrada, primer archivo del `.toc`).
- **Eventos:** `ADDON_LOADED` (uno propio, distinto del de `Options.lua`, ver 3.15 — dos frames distintos escuchan `ADDON_LOADED` de forma independiente).
- **Clasificación:** Lifecycle / Infraestructura de arranque.
- **Fuera de lugar:** dispara `Core.StartSafetyNet()` — acopla el arranque genérico del addon a un detalle interno de scheduling de `Core`. Conceptualmente el "quién inicia el motor de dispatch" debería decidirlo el propio dispatcher, no el bootstrap.

### 3.2 `Core/Utils.lua` (`Minimizer.Utils`)

- **Responsabilidad real:** caja de herramientas puras + dos primitivas de scheduling genéricas (`Debounce`, `Throttle`) + resolución segura de valores "secretos" (Secrets/Midnight).
- **Estado:** `_guarded_log_throttle` (tabla de throttle de logs por `flagName`, 10s).
- **Datos leídos:** ninguno propio; helpers reciben `unit`/valores como parámetro.
- **APIs WoW:** `UnitExists`, `UnitIsUnit`, `C_NamePlate.GetNamePlates`/`GetNamePlateForUnit`, `C_NamePlateManager`, `C_Timer`, `C_CurveUtil.EvaluateColorValueFromBoolean`, `issecretvalue`, `GetTime`, `C_SpellBook.*`, `IsPlayerSpell`, `IsSpellKnown`.
- **Funciones públicas clave:** `IsSecretValue`, `IsSimplifiedAvailable`, `GetNamePlateForUnit` (camino rápido por regex `^nameplate%d+$` vs camino lento iterando `C_NamePlate.GetNamePlates()`, que aloca tabla nueva — documentado en README §9 como candidato de optimización, **no tocar ahora**), `GetValidNamePlateToken`, `GetUnitFromNameplate`, `GetNameplateFromHealthBar` (sube la cadena de padres), `GetHealthBar`, `EvaluateColorRGB`/`EvaluateBoolean` (sinks seguros de un solo sentido para secrets), `GuardedCall` (guarda de reentrancia genérica), `LogGuardedError`, `ApplyReadyShade`, `IsPvPUnit`, `Debounce`, `Throttle`, `IsSpellKnownByPlayer`, `FindKnownSpell`.
- **Quién lo consulta:** prácticamente todos los módulos.
- **Clasificación:** mezcla de **Raw/Game Data helpers** + **Infraestructura de scheduling genérica** (Debounce/Throttle son usados por `Core.RequestApplyToAll` y por `Target.DebouncedUpdate`/`Focus.DebouncedUpdate` — es decir, las primitivas de scheduling viven aquí pero **no hay un único componente que las orqueste**; cada consumidor crea su propia instancia de Debounce/Throttle).
- **Fuera de lugar:** `Debounce`/`Throttle` son mecanismos de scheduling, no "utilidades puras" — en la arquitectura destino deberían quedar bajo el dominio de Dispatch, aunque la implementación en sí puede seguir viviendo como primitiva de bajo nivel.

### 3.3 `Overlays/Widgets.lua` (`Minimizer.Widgets`)

- **Responsabilidad real:** (a) localizar la castbar anónima de una nameplate por duck-typing, (b) resolver qué spellID mostrar en un widget de cooldown (con cache), (c) crear/configurar frames de cooldown circular, halos y "pips".
- **Estado:** `cdSpellCache` (nested: `cdSpellCache[dbTable][override or false] = spellID or false`), invalidado por `InvalidateCDSpellCache()`.
- **Datos leídos:** `Minimizer.Data.*` (SpellData), `UnitClass("player")`.
- **APIs WoW:** `C_Spell.GetSpellCooldownDuration`/`GetSpellCooldown`, `GetSpellCooldown` (legacy fallback), `CreateFrame`, `hooksecurefunc` no, `CreateMaskTexture`/`AddMaskTexture`.
- **Funciones públicas clave:** `FindCastBar`, `GetCDSpellID`, `InvalidateCDSpellCache`, `ConfigureCooldownFrame`, `MakeCooldownCircular`, `ApplyCooldownDuration`, `CreateHalo`, `UpdateHalo`, `CreatePip`, `UpdatePip`.
- **Quién lo consulta:** `Overlays/Focus.lua`, `Overlays/Target.lua`, `Plater/CastingBar.lua` (`FindCastBar`), `Menu.lua` (indirectamente vía `Data`, no vía `Widgets.GetCDSpellID` directamente — Menu usa `BuildSpellOptions` propio).
- **Invalidado por:** `Plater/Events.lua` → `HandleRosterOrSpecChange` (spec/talent change), `Menu.lua` → callbacks de dropdown.
- **Clasificación:** mezcla de **Decision** (`GetCDSpellID` decide qué spell mostrar — es lógica de negocio, no solo widget) + **Rendering/Lifecycle** (creación de frames) + **Raw Data** (`ApplyCooldownDuration` lee cooldown directo de la API).
- **Fuera de lugar:** `GetCDSpellID` es lógica de decisión de "qué CD mostrarle al jugador" (con override manual del usuario + fallback automático), pero vive en un archivo de "Widgets" nombrado como si solo creara frames.

### 3.4 `Plater/HitTest.lua` (`Minimizer.HitTest`)

- **Responsabilidad real:** mantener el hit-test (región de clic) de la nameplate sincronizado con la healthBar real, con reintentos si Blizzard aún no permite mutarlo.
- **Estado:** `pendingRetries[unit] = remainingTicks`, `_hit_test_log_throttle`.
- **APIs WoW:** `nameplate:CanChangeHitTestPoints()`, `nameplate:SetAllHitTestPoints(healthBar)`, `C_Timer.After`.
- **Funciones públicas:** `Sync(unit, nameplate)`, `CancelRetry(unit)`.
- **Quién lo llama:** `Core.ApplyToUnit` (tras `SetNamePlateSimplified`), `Core.ClearNeverSimplify` (cancela reintentos pendientes).
- **Timers:** cadena de hasta 6 `C_Timer.After(0.05, tick)` por unidad — es un **mini-scheduler propio por unidad**, independiente del resto.
- **Clasificación:** Lifecycle / sincronización de presentación con el motor nativo de Blizzard.
- **Nota:** es un ejemplo adicional (más pequeño que Threat) de "componente con su propio scheduling per-unit", a tener en cuenta al diseñar el Dispatcher.

### 3.5 `Config.lua` (`Minimizer.Config`)

- **Responsabilidad real:** definir defaults de `MinimizerDB`/`MinimizerCharDB`, inicializarlos, migrar claves legacy, y centralizar `IsSimplifyEnabled()`.
- **Estado:** ninguno propio en memoria (todo vive en `MinimizerDB`/`MinimizerCharDB`, SavedVariables).
- **Funciones públicas:** `Initialize()`, `IsSimplifyEnabled()`.
- **Quién lo consulta:** `Bootstrap.lua` (Initialize), `Decision.lua` (IsSimplifyEnabled, con fallback duplicado inline si `Minimizer.Config` no existiera — ver 4.7), `Menu.lua`.
- **Migración interna:** detecta `MinimizerDB.focusIndicator ~= nil` (clave vieja) y la convierte a `enableFocusFace`/`enableFocusArrows` — gateada por presencia de clave, no por número de versión.
- **Clasificación:** Configuration/UI (persistencia) — correcto, sin mezcla relevante.

### 3.6 `Core/Constants.lua`

- **Responsabilidad real:** paletas de color estáticas (`HealthColors`, `CastColors`, `PipColors`).
- **Clasificación:** Static Data. Sin problemas.

### 3.7 `Data/SpellData.lua` (`Minimizer.Data`)

- **Responsabilidad real:** listas de spellIDs por clase (`INTERRUPT_SPELLS`, `OFFENSIVE_CDS`, `DEFENSIVE_CDS`, `MASS_CC_SPELLS`), formato `{id=, name=}` o numérico legacy.
- **Clasificación:** Static Data. Sin problemas. Ver `Docs/debt.md` para el proceso de añadir spells (fuera del alcance de esta auditoría).

### 3.8 `Core/Cache.lua` (`Minimizer.Cache`)

- **Responsabilidad real:** cache genérico `unit -> key -> {value, gen}`, gen-gated contra `Minimizer.Core.GetPlateGeneration(unit)`.
- **Estado:** `Cache.units`.
- **Dependencia saliente:** `Minimizer.Core.GetPlateGeneration` — **Cache depende de Core** para saber si una entrada sigue siendo válida.
- **Funciones públicas:** `GetUnitState`, `GetUnitKeyWithGeneration`, `SetUnitKeyWithGeneration`, `InvalidateUnit(unit, kind)` (prefix-match usando `_KNOWN_PREFIXES`, con fallback `kind..":"` inline), `InvalidateAll(kind)` (recorre TODAS las unidades cacheadas — full scan).
- **Quién lo usa:** `Classification.GetEliteType` (key `"eliteType"`), `Threat.GetThreatDetails` (key `"threat:details"`), `Threat.GetSituation` (key `"threat:"..source`).
- **Quién lo invalida:** `Plater/Events.lua` (`InvalidateAllThreat` en varios eventos), `Threat.Invalidate(unit)`, `Core.ClearNeverSimplify` (invalida TODO el estado de la unidad, no solo threat).
- **Clasificación:** Cache/Persistence. Correcta como componente aislado, pero con **acoplamiento circular conceptual**: `Cache` → `Core.GetPlateGeneration`, y `Core.BuildSnapshot` → `Classification`/`Threat` que a su vez usan `Cache`. No es un ciclo de carga (el `.toc` carga `Cache.lua` antes que `Core.lua`, y el acceso a `Minimizer.Core.GetPlateGeneration` se hace en tiempo de ejecución, no de carga, así que funciona), pero sí es un ciclo de **dependencia conceptual** a resolver en la arquitectura destino (la generación de plate debería ser propiedad de un componente de Lifecycle del que Cache dependa explícitamente, no de "Core" como caja negra).

### 3.9 `Plater/Threat.lua` (`Minimizer.Threat`) — el módulo más sobrecargado

Desglose exhaustivo (tal y como pide el encargo):

- **Estado que mantiene:**
  - `tankTokens` (array de tokens de grupo/raid con rol TANK).
  - `playerTankCache` / `playerTankCacheValid` (bool cacheado de "el jugador es tank").
  - `nilState[unit] = {generation, nilSince, nilSpecial}` (heurística temporal: cuánto tiempo lleva `UnitThreatSituation` devolviendo `nil` en combate contra una unidad que no puede atacarnos).
  - `monitorFrame`, `monitorElapsed`, `monitorStep`, `monitorUnits[]`, `monitorCount`, `monitorState[unit]`, `monitorDirty` — **estado completo de un scheduler propio**.
- **Datos que lee:** `UnitGroupRolesAssigned`, `UnitThreatSituation`, `UnitAffectingCombat`, `UnitCanAttack`, `UnitInParty`, `UnitExists`, `IsInRaid`, `IsInGroup`, `GetSpecialization`/`GetSpecializationRole`, `C_SpecializationInfo.*`, `GetTime`.
- **APIs WoW consultadas directamente:** todas las anteriores + `CreateFrame` (para `monitorFrame`).
- **Otros módulos que consulta:** `Minimizer.Cache` (Get/SetUnitKeyWithGeneration, InvalidateUnit), `Minimizer.Core.GetPlateGeneration`, `Minimizer.Core.ApplyToUnit` (¡desde dentro de `ProcessMonitoredUnit`!), `Minimizer.ActiveNameplates` (lectura directa, no vía API).
- **Módulos que lo consultan:** `Plater/Decision.lua` (`Threat.ShouldUnsimplify`), `Plater/Core.lua` → `BuildSnapshot` (`Threat.GetThreatDetails`, `Threat.PlayerHasAggro`), `Plater/Core.lua` → `ComputeDisplayKind` (`Threat.IsNilSpecial`, `Threat.PlayerHasAggro`), `Plater/HealthBarColor.lua` (`Threat.IsPlayerTank`, `Threat.IsNilSpecial`, `Threat.ShouldLetBlizzardPaint`), `Overlays/Focus.lua`/`Target.lua` NO lo consultan directamente, `Plater/Events.lua` (`RefreshTankTokens`, `RefreshPlayerTankCache`, `InvalidatePlayerTankCache`, `Invalidate`, `ForgetUnit`, `TrackUnit`, `StartMonitor`).
- **Eventos que recibe:** ninguno directamente (no registra eventos propios); es notificado vía llamadas explícitas desde `Events.lua`.
- **Timers/OnUpdate:** `monitorFrame:SetScript("OnUpdate", ...)` — round-robin que procesa ~1 unidad cada `0.25/monitorCount` segundos.
- **Frames que crea:** `monitorFrame` (sin nombre, `CreateFrame("Frame")`).
- **Unidades/nameplates que recorre:** `Minimizer.ActiveNameplates` (vía `RebuildMonitorUnits`, filtrando con `IsNameplateToken`) — **acceso directo a una tabla que "pertenece" a `Core.lua`**.
- **Caches que usa:** `Minimizer.Cache` (vía `GetThreatDetails`/`GetSituation`), más su propio `playerTankCache` y `nilState` (caches ad-hoc fuera de `Minimizer.Cache`).
- **Invalidaciones que realiza:** `Invalidate(unit)` → `Cache.InvalidateUnit(unit, "threat")`.
- **Funciones públicas clave:** `RefreshTankTokens`, `RefreshPlayerTankCache`, `InvalidatePlayerTankCache`, `IsPlayerTank`, `GetThreatDetails`, `Invalidate`, `IsInCombatWith`, `GetSituation`, `PlayerHasAggro`, `GetTankSituation`, `IsNilSpecial`, `ShouldLetBlizzardPaint`, `ShouldUnsimplify`, `TrackUnit`, `ForgetUnit`, `StartMonitor`.
- **Funciones internas clave:** `IsThreatEnabled`, `UpdateNilState`, `RebuildMonitorUnits`, `ProcessMonitoredUnit`.
- **Efectos secundarios:** llama `Minimizer.Core.ApplyToUnit(unit)` cuando `ProcessMonitoredUnit` detecta un cambio de estado — **dispara el pipeline de dispatch completo desde dentro de un módulo de "estado"**.
- **Cosas visuales que modifica:** ninguna directamente (correcto — Threat no pinta nada).
- **Cosas de gameplay que decide:** `ShouldUnsimplify` (si debe desimplificarse por aggro/nil-special), `ShouldLetBlizzardPaint` (si HealthBarColor debe abstenerse de pintar porque el jugador es tank en cierto estado) — **dos decisiones de negocio viviendo en el módulo de datos de threat**, cuando conceptualmente pertenecen a `Decision`/`HealthBarColor` respectivamente (o a un componente de Decision unificado).
- **Cosas de infraestructura que hace:** scheduling (`monitorFrame` OnUpdate), lectura directa de `ActiveNameplates`, invocación directa de `Core.ApplyToUnit`.
- **Qué debería pertenecer a otro componente:**
  1. El **monitor OnUpdate completo** (`StartMonitor`/`RebuildMonitorUnits`/`ProcessMonitoredUnit`/`monitorFrame`) es, en esencia, un **segundo Dispatcher**. Debe migrar a ser una fuente de invalidación que el Dispatcher central consuma (Threat notifica "esta unidad cambió de threat", el Dispatcher decide cuándo reprocesar), no un bucle que llama `Core.ApplyToUnit` por su cuenta.
  2. `ShouldUnsimplify` debería vivir en `Decision.lua` (o el futuro componente Decision), consumiendo datos de Threat vía snapshot, no al revés.
  3. `ShouldLetBlizzardPaint` debería ser una decisión consumida por `HealthBarColor` desde snapshot, no una llamada directa cross-module a `Threat`.
  4. El acceso a `Minimizer.ActiveNameplates` debe pasar por una API del Dispatcher/Lifecycle, nunca lectura directa de la tabla.

### 3.10 `Plater/Absorb.lua` (`Minimizer.Absorb`)

- **Responsabilidad real:** determinar si hay absorb activo **mirando el indicador visual nativo** (`totalAbsorbOverlay`/`totalAbsorb`) vía `:IsShown()`, deliberadamente sin leer el número (`UnitGetTotalAbsorbs`) para evitar comparar un valor potencialmente secreto (documentado en README §3.10).
- **Estado:** ninguno (sin cache propio).
- **Función pública:** `HasAbsorb(unit, nameplate)`.
- **Quién lo consulta:** `Plater/Core.lua` → `BuildSnapshot` y `ComputeDisplayKind`, `Plater/Decision.lua` (fallback si no hay snapshot), `Plater/HealthBarColor.lua` (fallback si no hay snapshot).
- **Clasificación:** Derived State (booleano derivado de un widget nativo).
- **Ver §6.3** para el problema de múltiples fuentes de verdad relacionadas con "absorb" — el propio `Absorb.lua` está bien acotado, el problema está en cómo lo consumen y persisten otros módulos.

### 3.11 `Plater/Cast.lua` (`Minimizer.Cast`)

- **Responsabilidad real:** leer estado de cast/channel **siempre fresco**, sin cache (decisión de diseño explícita y documentada en README §3.5/§6.4, motivada por un bug histórico de cache con orden de invalidación no garantizado).
- **Estado:** ninguno.
- **Funciones públicas:** `InvalidateState(unit)` (no-op, mantenido solo por compatibilidad de API — múltiples call-sites en `Core.lua`/`Events.lua` lo siguen llamando), `GetState(unit)`, `IsUnitCasting(unit)`, `IsUnitCastUninterruptible(unit)`.
- **Quién lo consulta:** `Plater/Core.lua` → `BuildSnapshot` (una vez por pase), `Plater/CastingBar.lua` (fallback si no hay snapshot), `Plater/Decision.lua` (fallback si no hay snapshot).
- **Clasificación:** Raw/Derived Data reader, sin cache por diseño. Correcto y bien documentado — **preservar el comportamiento "sin cache" tal cual durante la migración**, no reintroducir cache aquí sin resolver antes la garantía de orden que motivó quitarlo.

### 3.12 `Plater/Classification.lua` (`Minimizer.Classification`)

- **Responsabilidad real:** clasificar una unidad en `trivial | boss | miniboss | caster | melee`.
- **Estado:** ninguno propio (usa `Minimizer.Cache` con key `"eliteType"`).
- **Datos leídos:** `UnitClassification`, `UnitEffectiveLevel` (unidad y jugador, leído una sola vez y pasado como parámetro a las funciones internas), `UnitIsLieutenant`, `UnitHasPowerType`/`UnitPowerType`.
- **Función pública:** `GetEliteType(unit)`.
- **Funciones internas:** `IsTrivial`, `GetSuperiorKind`, `HasMana`.
- **Quién lo consulta:** `Plater/Core.lua` (`BuildSnapshot`, `ComputeDisplayKind`), `Plater/Decision.lua` (fallback), `Plater/HealthBarColor.lua` (fallback y lectura directa de `eliteType` para `isSuperior`/`isCasterClass`).
- **Clasificación:** Derived State + uso correcto del Cache centralizado. Sin problemas estructurales relevantes más allá de depender indirectamente de `Core.GetPlateGeneration` vía `Cache`.

### 3.13 `Plater/Decision.lua` (`Minimizer.Decision`)

- **Responsabilidad real:** el único punto que decide `ShouldSimplifyUnit(unit, nameplate, snapshot) -> bool, reason`.
- **Orden de reglas implementado (tal cual, no evaluar si es correcto):** unidad inválida → target → focus → friendly → `Config.IsSimplifyEnabled()` → `eliteType` boss/miniboss/caster → `Threat.ShouldUnsimplify` → `hasHadAbsorb` (vía snapshot o fallback `Absorb.HasAbsorb` + `Core.MarkAbsorbSeen`) → cast/channel (interrumpible → "no simp" persistente; ininterrumpible → "temporal") → si nada aplica, `simplify`.
- **Dependencias salientes:** `Config.IsSimplifyEnabled` (con fallback inline duplicado si `Minimizer.Config` no existiera — ver §4.7), `Classification.GetEliteType`, `Threat.ShouldUnsimplify`, `Absorb.HasAbsorb`, `Core.MarkAbsorbSeen`, `Cast.GetState`.
- **Quién lo consulta:** `Plater/Core.lua` → `ApplyToUnit` (única llamada real en el pase normal), `tests/smoke_test.lua` (extensivamente).
- **Clasificación:** Decision — correcta como concepto, pero **no es la única fuente de "prioridad"** del addon (ver §6.6 sobre prioridades duplicadas entre Decision, `BuildSnapshot.displayKind` y `HealthBarColor`).

### 3.14 `Plater/Interrupt.lua` (`Minimizer.Interrupt`)

- **Responsabilidad real:** resolver el spellID de interrupción de la clase/spec actual (con cache invalidado explícitamente en cambio de spec/talento) y mantener un cache de "¿está listo?" refrescado **una vez por pase**, nunca leído desde dentro de un loop de nameplates.
- **Estado:** `cachedSpellID`/`cachedSpellIDResolved`, `cachedReady`.
- **APIs WoW:** `UnitClass("player")`, `C_Spell.GetSpellCooldownDuration`.
- **Funciones públicas:** `InvalidateSpellIDCache`, `GetSpellID`, `RefreshReadyCache`, `IsReady`.
- **Quién lo llama:** `Plater/Core.lua` → `ApplyToAll` (`RefreshReadyCache`), `Plater/Events.lua` → `SPELL_UPDATE_COOLDOWN` handler (`RefreshReadyCache` + comparación con `lastInterruptReady` para decidir si vale la pena `UpdateNameplates()`), `Plater/CastingBar.lua` (`IsReady`), `Overlays/Focus.lua` (`GetSpellID`, `IsReady` vía `Utils.ApplyReadyShade`), `Overlays/Target.lua` (`GetSpellID` para el countdown).
- **Clasificación:** Cache/Derived state con contrato implícito "alguien externo debe llamar `RefreshReadyCache` antes de que `IsReady` sea confiable" — frágil pero documentado (README §3.12). **Preservar tal cual.**

### 3.15 `Plater/Core.lua` (`Minimizer.Core`) — el componente más sobrecargado junto a Threat

Desglose función por función:

| Función | Qué hace realmente | Dominio real |
|---|---|---|
| `GetPlateGeneration(token)` | lee `plateGeneration[token]` | Lifecycle |
| `MarkAbsorbSeen(unit, nameplate, hasAbsorbNow)` | persiste `nameplate.MinimizerHasHadAbsorb`, gen-gated vía `MinimizerAbsorbPersistentGen` | Derived State / Persistence (no debería estar en "Core") |
| `StartSafetyNet()` | crea `C_Timer.NewTicker(2.0, ApplyToAll(false))` | Dispatch/Scheduling |
| `IncrementPlateGeneration(token)` | incrementa contador | Lifecycle |
| `RegisterModule(name, module)` | registro de módulos visuales | Dispatch (registro) |
| `UpdateModules(unit, nameplate, snapshot)` | fan-out a `ModuleList`, con `pcall` y throttle de error-log | Dispatch |
| `BuildSnapshot(unit, nameplate)` (local, no expuesta como API pública) | arma `scratchSnapshot` (tabla **reutilizada**, no una por unidad) combinando Classification+Absorb+Threat+PvP/Friendly+Cast+`displayKind` (con su propia prioridad interna) | Snapshot (dominio correcto, pero implementación mezclada con Core) |
| `ComputeDisplayKind(unit, nameplate)` | **reimplementación paralela** de la lógica de prioridad de `displayKind` dentro de `BuildSnapshot`, usada como fallback fuera del pase normal | Snapshot — **duplicado real, ver §6.6** |
| `ApplyToUnit(unit, forceUpdate)` | resuelve nameplate/token, registra en `ActiveNameplates`, construye snapshot, aplica fast-path de "no simp persistente", si no hay fast-path llama `Decision.ShouldSimplifyUnit`, llama `C_NamePlateManager.SetNamePlateSimplified` si cambió/forzado, llama `HitTest.Sync`, llama `UpdateModules` | **Dispatcher + Lifecycle + Decision-orchestration + mutación de API de Blizzard + trigger de Rendering, todo en una función** |
| `ApplyToAll(forceUpdate)` | refresca `Interrupt.RefreshReadyCache`, itera `ActiveNameplates`, llama `ApplyToUnit` por cada token | Dispatch — el pase "canónico", pero no el único (ver Threat y SafetyNet) |
| `RequestApplyToAll` | `Utils.Debounce(ApplyToAll(true))` | Dispatch (scheduling) |
| `ClearNeverSimplify(unit)` | limpieza de teardown: Cache, Cast (no-op), HitTest, Threat, `OnNamePlateRemoved` de cada módulo registrado, limpia varios campos de `nameplate`, borra de `ActiveNameplates` | Lifecycle |

- **Estado que mantiene `Core.lua`:** `Modules`, `ModuleList`, `ActiveNameplates` (**el registro central de nameplates activas — leído también directamente por `Threat.lua`**), `plateGeneration`, `scratchSnapshot` (tabla única reutilizada — seguro solo porque el procesamiento es síncrono por unidad; **si en el futuro se paraleliza o se difiere el consumo del snapshot, esto rompe**), `_module_error_throttle`, `_safetyNetStarted`.
- **Quién lo consulta:** prácticamente todo el addon (`Events.lua`, `Threat.lua`, `Decision.lua`, `HealthBarColor.lua`, `Menu.lua`, `SlashCommands.lua`, `Focus.lua`, `Options.lua` indirectamente vía Menu).
- **Fuera de lugar (resumen):** `Core.lua` hoy es simultáneamente Dispatcher, constructor de Snapshot, autoridad de Lifecycle (generación de plates, registro de `ActiveNameplates`), motor de Decision-orchestration (fast-path de "no simp persistente" es una decisión de negocio cacheada dentro de Core, no dentro de Decision), y quien dispara la mutación de la API nativa de Blizzard + Rendering (`UpdateModules`). Es exactamente la caja negra descrita en el encargo.

### 3.16 `Plater/Markers.lua` (`Minimizer.Markers`)

- **Responsabilidad real:** flechas de target/focus sobre la nameplate.
- **Estado:** widgets guardados en `nameplate.MinimizerMarkers` (idempotente vía `Ensure`).
- **Datos leídos:** `MinimizerDB.enableTargetMarkers`/`enableFocusMarkers`/`enableFocusArrows`, `UnitIsUnit`.
- **Registrado en Core:** sí (`Core.RegisterModule("Markers", Markers)`).
- **Clasificación:** Rendering/Presentation puro. Sin problemas estructurales relevantes — es el módulo visual **más limpio** del repo (según el propio benchmark, también el más barato).

### 3.17 `Plater/HealthBarColor.lua` (`Minimizer.HealthBarColor`)

- **Responsabilidad real:** colorear la healthbar nativa según la "leyenda M+" (README §5), gestionar la barra de overshield/absorb, e interceptar repintados nativos de Blizzard vía `hooksecurefunc`.
- **Estado por nameplate:** `MinimizerHealthBarColorGen`, `MinimizerHealthBarColorUnit`, `MinimizerPersistentCastColor`, `MinimizerHasAbsorb`, `MinimizerLastAppliedColor`, `MinimizerHealthBarColorKind`. Estado por healthBar: `MinimizerHealthColorHooked`, `MinimizerOvershieldBar` (+ `MinimizerLastAbsorb`/`MinimizerLastMaxHealth` en la overshield bar).
- **Datos leídos directamente (bypaseando snapshot cuando no hay uno):** `UnitCanAttack`, `Utils.IsPvPUnit`, `Threat.IsPlayerTank`/`IsNilSpecial`/`ShouldLetBlizzardPaint`, `Absorb.HasAbsorb`, `Core.MarkAbsorbSeen`, `Classification.GetEliteType`, `UnitGetTotalAbsorbs`/`UnitHealthMax` (**lectura numérica directa de absorb, ver §6.3**).
- **Hooks:** `HookHealthBar` (hooksecurefunc sobre `healthBar.SetStatusBarColor`, idempotente vía flag), `HookIndicator` (hooksecurefunc sobre `Show`/`Hide` del indicador de absorb — **dispara `Core.ApplyToUnit(unit)` desde dentro de un hook de presentación**, o `HealthBarColor:UpdateNamePlate` directamente si `Core.ApplyToUnit` no existiera).
- **Registrado en Core:** sí.
- **Clasificación:** Rendering/Presentation, pero con fugas hacia Decision (reimplementa gates que ya decide Threat/Absorb) y hacia Dispatch (dispara `Core.ApplyToUnit`).
- **Fuera de lugar:** (1) lee `UnitGetTotalAbsorbs` numérico directamente, contradiciendo la filosofía documentada en README §3.10 de "confiar solo en el indicador visual" — es una necesidad real (la overshield bar necesita un número para dibujar el ancho), pero debería canalizarse a través de una función explícita de "Absorb" en vez de vivir suelta aquí. (2) `ShouldLetBlizzardPaint`/gates de tank son decisiones que debería resolver el snapshot/Decision, no que HealthBarColor vuelva a preguntarle a Threat.

### 3.18 `Plater/CastingBar.lua` (`Minimizer.CastingBar`)

- **Responsabilidad real:** colorear la castbar nativa (misma leyenda que HealthBarColor) y mostrar un borde pulsante cuando el cast apunta al jugador.
- **Estado por nameplate/castbar:** `nameplate.MinimizerCastBar`, `castBar.MinimizerCastVisuals` (`targetContainer`/`targetBorder`/`targetPulse`), `castBar.MinimizerColorHooked`, `castBar.MinimizerLastCastColor`, `castBar.MinimizerCastUnit`.
- **Estado a nivel de módulo:** `_scratchDangerColor` (tabla scratch reutilizada, mismo patrón que `scratchSnapshot` de Core — seguro solo por ser síncrono).
- **Hooks:** `hooksecurefunc(castBar, "SetStatusBarColor", ...)` — **hook independiente y paralelo al de `HealthBarColor`, mismo patrón duplicado en dos archivos** en vez de un helper compartido "hook de repintado + reaplicar último color".
- **Registrado en Core:** sí.
- **Fallback sin snapshot:** llama `Cast.GetState(unit)` directamente (releyendo `UnitCastingInfo`/`UnitChannelInfo` fuera del snapshot del pase — documentado como candidato de optimización en README §9, no corregir ahora).
- **Clasificación:** Rendering/Presentation. Duplicación de patrón de hook con HealthBarColor — candidato a extraer un helper común en la arquitectura destino (`GuardedRepaintHook` o similar), sin cambiar comportamiento.

### 3.19 `Overlays/Focus.lua` (`Minimizer.Focus`)

- **Responsabilidad real:** retrato de focus con cooldown de interrupt y pip de CC masivo, anclado a la nameplate del focus.
- **Estado:** `frame` (module-level, único, no por-nameplate — solo existe una "unidad focus" a la vez), `portrait`, `cooldown`, `ccPip`.
- **NO registrado en `Core.RegisterModule`.** Se actualiza vía:
  - `Focus.DebouncedUpdate` = `Utils.Throttle(UpdateFace, 0.033)`, invocado desde `Events.lua` en `SPELL_UPDATE_COOLDOWN`.
  - Llamada directa a `Focus.UpdateFace()` (sin throttle) desde `Events.lua` en `PLAYER_FOCUS_CHANGED`, `NAME_PLATE_UNIT_ADDED`, `NAME_PLATE_UNIT_REMOVED`.
- **Efectos secundarios:** `SetFaceEnabled`/`SetArrowsEnabled` mutan `MinimizerDB` y llaman `Core.ApplyToAll()` — **un Overlay dispara un pase completo del Dispatcher central**.
- **Clasificación:** Overlay/Presentation con su propio mini-pipeline de actualización, fuera del pipeline de `Core.UpdateModules`.

### 3.20 `Overlays/Target.lua` (`Minimizer.Target`)

- Análogo a Focus pero para "target": halo ofensivo + pip defensivo + countdown de interrupt.
- **NO registrado en Core.** `Target.DebouncedUpdate` (throttle 30fps) enganchado a `SPELL_UPDATE_COOLDOWN`; `UpdateTargetCDs()` también llamado directo desde `PLAYER_TARGET_CHANGED`, `NAME_PLATE_UNIT_ADDED`, `NAME_PLATE_UNIT_REMOVED`.
- **Clasificación:** igual que Focus — Overlay con pipeline propio.

### 3.21 `Menu.lua` (`Minimizer.Menu`)

- **Responsabilidad real:** frame de opciones de desarrollo/fallback (`/mini menu`) con toggles, dropdowns de override de spell y una leyenda de colores puramente informativa.
- **Estado:** `Menu.frame`, controles guardados en `frame.MinimizerMenuControls`.
- **Efectos secundarios de sus callbacks:** mutan `MinimizerDB`/`MinimizerCharDB`, llaman `Core.ApplyToAll()`, `Widgets.InvalidateCDSpellCache()`, `Focus:SetFaceEnabled/SetArrowsEnabled`.
- **Clasificación:** Configuration/UI. Correcto como dominio, con dependencias esperables hacia Core/Widgets/Focus como efecto de acciones del usuario (a preservar, no a "corregir").

### 3.22 `Options.lua`

- **Responsabilidad real:** registrar un panel en Blizzard Settings que abre `Menu.Open()`.
- **Nota:** tiene su **propio** frame + listener de `ADDON_LOADED` (`MinimizerOptionsBootstrapFrame`), independiente del de `Bootstrap.lua`. Funcionalmente inofensivo (ambos comprueban `name == ADDON_NAME` y se auto-desregistran), pero es un segundo punto de entrada de lifecycle a tener en cuenta.
- **Clasificación:** Configuration/UI.

### 3.23 `SlashCommands.lua`

- **Responsabilidad real:** `/mini` — abre menú, toggles rápidos de focus, on/off de simplify, valor 0-100 legacy.
- **Efectos secundarios:** mutan `MinimizerDB`, llaman `Core.ApplyToAll()`.
- **Clasificación:** Configuration/UI.

### 3.24 `Plater/Events.lua` — el segundo componente "dispatcher-like"

- **Responsabilidad real:** único `EventFrame` que registra ~25 eventos de WoW + tabla `handlers` de dispatch + 2 `hooksecurefunc` globales de Blizzard.
- **Estado:** `lastInterruptReady` (dedupe de repintado en `SPELL_UPDATE_COOLDOWN`).
- **Eventos registrados:** `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`, `PLAYER_DIFFICULTY_CHANGED`, `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED`, `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`, `PLAYER_ROLES_ASSIGNED`, `GROUP_ROSTER_UPDATE`, `PLAYER_TALENT_UPDATE`, `PLAYER_SPECIALIZATION_CHANGED`, `SPELL_UPDATE_COOLDOWN`, `NAME_PLATE_UNIT_ADDED`, `NAME_PLATE_UNIT_REMOVED`, `UNIT_DISPLAYPOWER`, `UNIT_CLASSIFICATION_CHANGED`, `UNIT_LEVEL`, `UNIT_THREAT_SITUATION_UPDATE`, `UNIT_THREAT_LIST_UPDATE`, `UNIT_SPELLCAST_START/STOP/FAILED/INTERRUPTED/INTERRUPTIBLE/NOT_INTERRUPTIBLE`, `UNIT_SPELLCAST_CHANNEL_START/STOP/UPDATE`, `UNIT_SPELLCAST_EMPOWER_START/STOP/UPDATE`, `UNIT_ABSORB_AMOUNT_CHANGED` (este último se registra el handler pero **no se ve `EventFrame:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")` en la lista final de `RegisterEvent` — `REQUIERE VALIDACIÓN`: el handler existe en la tabla `handlers` pero no encontramos la línea de registro explícita en el bloque final de `RegisterEvent`s del archivo provisto**).
- **Hooks globales:** `hooksecurefunc(NamePlateDriverFrame, "OnNamePlateRemoved", ...)` → `Core.ClearNeverSimplify`; `hooksecurefunc("CompactUnitFrame_UpdateHealthColor", ...)` → `Core.ApplyToUnit(unit)` si `unitFrame.MinimizerLetBlizzardHealthColor` no está seteado (**este flag no se encuentra seteado en ningún otro archivo del repo provisto — `REQUIERE VALIDACIÓN`: código muerto o depende de algo fuera del árbol analizado**).
- **Arranca:** `Minimizer.Threat.StartMonitor()` — **es `Events.lua`, no `Threat.lua` ni `Core.lua`, quien enciende el segundo dispatcher**.
- **Patrón de doble definición:** `handlers["NAME_PLATE_UNIT_ADDED"]` se define una vez (incrementa generación, gestiona Threat, llama `Core.ApplyToUnit(unit)` + `UpdateNameplates()` debounced) y luego se **redefine** envolviendo la original (`originalNamePlateAdded`) para añadir actualización de Target/Focus. Funciona pero es un patrón de "monkey-patch de la propia tabla de handlers" a limpiar en la migración (sin cambiar comportamiento).
- **Granularidad de dispatch decidida aquí, evento por evento:**
  - Inmediato + debounced-full a la vez: `NAME_PLATE_UNIT_ADDED`.
  - Solo inmediato (`Core.ApplyToUnit(unit)`), sin debounce: `UNIT_DISPLAYPOWER`, `UNIT_CLASSIFICATION_CHANGED`, `UNIT_LEVEL`, `UNIT_ABSORB_AMOUNT_CHANGED`, eventos de cast (`HandleCastEvent`), threat con unit específico (`HandleThreatEvent`).
  - Solo debounced-full (`RequestApplyToAll`): `HandleFullRefreshEvent` (varios eventos), threat sin unit específico, `HandleRosterOrSpecChange`.
  - `HandleFullRefreshEvent` en `PLAYER_REGEN_ENABLED` **itera `C_NamePlate.GetNamePlates()` directamente** (tercer patrón de recorrido de nameplates, además de `Core.ApplyToAll` sobre `ActiveNameplates` y `Threat`'s monitor sobre `ActiveNameplates`) para limpiar `MinimizerDesimplifiedPersistent*` en TODAS las plates visibles.
- **Clasificación:** es, de facto, la capa de **entrada de eventos + reglas de granularidad de dispatch**. En la arquitectura destino esta lógica de "qué tan grande es el blast radius de este evento" es responsabilidad legítima de un Dispatcher, pero hoy vive fuera de `Core` (que se llama a sí mismo el núcleo) — otra prueba de que no hay una autoridad única de dispatch.

---

## 4. Flujo actual de eventos

1. WoW dispara un evento → `EventFrame:OnEvent` → busca en `handlers[event]`.
2. El handler decide, según el tipo de evento, si:
   - llama `Core.ApplyToUnit(unit)` inmediatamente para una unidad concreta, y/o
   - llama `UpdateNameplates()` (= `Core.RequestApplyToAll()`, debounced a 0s vía `C_Timer.After(0, ...)`), y/o
   - invalida cache de Threat/Cast/Widgets/Interrupt, y/o
   - dispara actualizaciones ad-hoc de Target/Focus.
3. **En paralelo**, sin relación con el punto 1-2:
   - `Threat.monitorFrame` (si `StartMonitor` corrió) procesa ~1 unidad de `ActiveNameplates` cada `0.25/N` segundos y puede llamar `Core.ApplyToUnit(unit)` si detecta cambio de threat/combat/generación.
   - `Core`'s `SafetyNet` ticker llama `Core.ApplyToAll(false)` cada 2s.
   - Hooks de repintado nativo de Blizzard (`CompactUnitFrame_UpdateHealthColor`, `SetStatusBarColor` de healthBar/castBar, `Show`/`Hide` del indicador de absorb) pueden disparar `Core.ApplyToUnit(unit)` o una llamada directa a `Module:UpdateNamePlate(unit, nameplate, nil)` **sin snapshot**, forzando fallbacks de recomputación en cada módulo.

---

## 5. Flujo actual de una nameplate

**Aparición (`NAME_PLATE_UNIT_ADDED`):**
1. `Events.lua` incrementa la generación del token (`Core.IncrementPlateGeneration`).
2. `Threat.ForgetUnit` + `Threat.TrackUnit` (marca `monitorDirty=true`).
3. `Threat.Invalidate(unit)`.
4. `Core.ApplyToUnit(unit)` — pase completo inmediato para esa unidad (ver más abajo).
5. `UpdateNameplates()` — además programa un pase completo debounced.
6. (segunda definición del handler) Si `unit` es el target actual → `Target:UpdateTargetCDs()`. Siempre → `Focus.UpdateFace()`.

**`Core.ApplyToUnit(unit)`:**
1. Resuelve `nameplate` y `npToken` (vía `Utils.GetNamePlateForUnit`/`GetValidNamePlateToken`).
2. Registra `ActiveNameplates[npToken] = nameplate`.
3. `BuildSnapshot(npToken, nameplate)` — un único snapshot compartido (tabla reutilizada `scratchSnapshot`).
4. Si `nameplate.MinimizerDesimplifiedPersistent` está activo y la generación no cambió → fast-path, `shouldSimplify=false`.
   Si no → `Decision.ShouldSimplifyUnit(npToken, nameplate, snapshot)`. Si la razón es `"no simp"`, marca el fast-path persistente para el resto de esta generación.
5. Si `C_NamePlateManager.SetNamePlateSimplified` está disponible y (`forceUpdate` o cambió el estado deseado) → llama a la API nativa, actualiza `nameplate.MinimizerState`, sincroniza `HitTest.Sync`.
6. `Core.UpdateModules(npToken, nameplate, snapshot)` → fan-out a `HealthBarColor`, `CastingBar`, `Markers` (los tres únicos módulos registrados hoy).

**Desaparición (`NAME_PLATE_UNIT_REMOVED` vía hook de `NamePlateDriverFrame:OnNamePlateRemoved`):**
1. `Core.ClearNeverSimplify(unit)`: invalida Cache, Cast (no-op), cancela reintentos de HitTest, `Threat.ForgetUnit`, llama `OnNamePlateRemoved` de cada módulo registrado (cada uno limpia sus propios campos en `nameplate`), limpia campos genéricos (`MinimizerDesimplifiedPersistent*`, `MinimizerState`, `MinimizerCastBar`, `MinimizerHasHadAbsorb`, `MinimizerAbsorbPersistentGen`), borra de `ActiveNameplates`.

---

## 6. Fuentes de verdad y estado

Esta sección es la más importante para la migración: documenta, para cada concepto, **dónde se calcula, dónde se cachea, dónde se invalida, quién lo consume**, y si hay más de una implementación/representación.

### 6.1 `tank` (¿el jugador es tank?)

- **Se calcula en:** `Threat.RefreshPlayerTankCache()` — cadena de fallback: `UnitGroupRolesAssigned("player")=="TANK"` → si no, `C_SpecializationInfo.GetSpecialization`+`GetSpecializationInfo` → si no, `GetSpecialization`+`GetSpecializationRole` (legacy).
- **Se cachea en:** `playerTankCache`/`playerTankCacheValid` (module-level de `Threat.lua`, **fuera** de `Minimizer.Cache`).
- **Se invalida en:** `Threat.InvalidatePlayerTankCache()`, llamado desde `Events.lua` → `HandleRosterOrSpecChange` (roster/talent/spec change) y desde `tests` directamente.
- **Consumido por:** `Threat.IsThreatEnabled` (local), `Threat.GetThreatDetails`, `Threat.PlayerHasAggro`, `Threat.ShouldLetBlizzardPaint`, `HealthBarColor.ShouldLetBlizzardPaint` (indirecto vía `Threat.IsPlayerTank`).
- **Única implementación.** Fuente de verdad clara: `Threat.lua`. Sin duplicación, pero cacheado fuera del sistema de cache genérico (inconsistencia de estilo, no de corrección).

### 6.2 `threat` / `aggro`

- **DOS caminos de lectura paralelos, no unificados:**
  1. `Threat.GetThreatDetails(unit)` — cachea bajo key `"threat:details"` en `Minimizer.Cache`; incluye `situation`, `otherTankAggro`, `nilSince`, `nilSpecial`. Usado por `Core.BuildSnapshot`, `HealthBarColor` (indirecto), `Threat.ShouldUnsimplify`, `Threat.ShouldLetBlizzardPaint`, `Threat.PlayerHasAggro` (rama tank).
  2. `Threat.GetSituation(unit, source)` — cachea bajo key `"threat:"..source` en `Minimizer.Cache` (independiente de la entrada `"threat:details"`); lee `UnitThreatSituation(source, unit)` **directamente otra vez**, sin pasar por `GetThreatDetails`. Usado por `Threat.PlayerHasAggro` (rama no-tank) y `Threat.GetTankSituation`... **no**, `GetTankSituation` usa `GetThreatDetails`. `GetSituation` es usado por `PlayerHasAggro` (no-tank) y expuesto para tests (`tests/smoke_test.lua` prueba explícitamente `Cache.GetUnitKeyWithGeneration(unit, "threat:player")`).
- **`Threat.PlayerHasAggro(unit)` tiene DOS algoritmos distintos** según si el jugador es tank o no:
  - Tank: usa `GetThreatDetails` + `IsInCombatWith` + `otherTankAggro` + `situation` en `{nil,0,1,2}` = aggro.
  - No-tank: usa `GetSituation(unit,"player") == 3`.
- **Invalidación:** `Threat.Invalidate(unit)` → `Cache.InvalidateUnit(unit, "threat")` (borra **ambas** entradas por prefijo `"threat:"`, así que al menos la invalidación sí es unificada). `Events.lua` también invalida todo con `Cache.InvalidateAll("threat")` en varios eventos globales.
- **Conclusión:** hay dos representaciones (`threat:details` como tabla rica, `threat:<source>` como escalar) para datos solapados, y dos algoritmos distintos de "aggro" según rol. **No corregir ahora.** Fuente de verdad futura recomendada: unificar en un único `GetThreatSnapshot(unit)` que devuelva toda la información necesaria (situation por cada source relevante + detalles), consumido por una única función `PlayerHasAggro` con las dos ramas ya existentes preservadas como lógica interna.

### 6.3 `absorb` / `hasAbsorb` / `hasHadAbsorb`

Este es el ejemplo que el propio encargo señala como síntoma. Hay **al menos cuatro representaciones relacionadas pero distintas**:

1. **`Absorb.HasAbsorb(unit, nameplate)`** — booleano "¿el indicador está visible AHORA MISMO?". Sin cache. Fuente: `healthBar.totalAbsorbOverlay`/`totalAbsorb`.
2. **`nameplate.MinimizerHasHadAbsorb`** (+ `nameplate.MinimizerAbsorbPersistentGen`) — booleano persistente "¿tuvo absorb alguna vez en esta generación de plate?", calculado/escrito por `Core.MarkAbsorbSeen(unit, nameplate, hasAbsorbNow)`. **Tres call-sites independientes** pueden invocar `MarkAbsorbSeen` con su propio `hasAbsorbNow` recién calculado: `Core.BuildSnapshot` (pase normal), `Decision.ShouldSimplifyUnit` (fallback sin snapshot), `HealthBarColor.UpdateNamePlate` (fallback sin snapshot) y `Core.ComputeDisplayKind` (fallback). Cada uno puede, en teoría, escribir el flag en momentos distintos con datos frescos distintos.
3. **`snapshot.displayKind == "absorb"`** — computado en `Core.BuildSnapshot`/`Core.ComputeDisplayKind` a partir de `hasHadAbsorb` (prioridad: focus > nilSpecial > aggro > absorb > eliteType).
4. **`nameplate.MinimizerHasAbsorb`** — flag booleano **distinto**, seteado únicamente dentro de `HealthBarColor:UpdateNamePlate` como `baseKind == "absorb"` — es decir, es una copia local/derivada de (3), pero vive en un campo de nameplate separado que nadie más lee (`REQUIERE VALIDACIÓN`: no se encontró ningún lector de `nameplate.MinimizerHasAbsorb` en el resto del repo provisto — posible campo muerto o usado solo para debug).
5. Adicionalmente, **`HealthBarColor.UpdateOvershieldBar`** lee `UnitGetTotalAbsorbs(unit)` **numérico directamente** (bypaseando la filosofía "solo booleano vía indicador" documentada en README §3.10) para dimensionar la barra de overshield.

`BUG EXISTENTE — NO CORREGIR DURANTE MIGRACIÓN`: el propio encargo describe la inconsistencia observable resultante (overlay de absorb visible pero healthbar no pintada con el color correspondiente, o viceversa) como consecuencia directa de tener 3-4 cálculos/persistencias independientes de "tuvo absorb" que pueden desincronizarse entre el momento en que corre `BuildSnapshot` (una vez por pase) y el momento en que corre un hook de repintado nativo fuera de pase (que recalcula con datos potencialmente más frescos o más viejos).

- **Fuente de verdad futura recomendada:** una única función `Absorb.HasAbsorb` (booleano en vivo, sin cambios) + una única función de persistencia `MarkAbsorbSeen`/`GetHasHadAbsorb` que viva dentro del futuro componente de Snapshot/Lifecycle (no en "Core" como caja negra ni duplicada en Decision/HealthBarColor), consumida siempre vía snapshot y nunca recalculada ad-hoc por un módulo visual.

### 6.4 `PvP` / `friendly`

- **`Utils.IsPvPUnit(unit)`** — `UnitIsPlayer(unit) and UnitCanAttack("player", unit)`. Única implementación.
- **`friendly`** — `UnitCanAttack("player", unit) == false`, calculado de forma **idéntica pero por separado** en: `Core.BuildSnapshot` (`s.isFriendly`), `Decision.ShouldSimplifyUnit` (inline, como parte de la cadena de reglas), `HealthBarColor.UpdateNamePlate` (fallback si `snapshot.isFriendly == nil`), `CastingBar.UpdateNamePlate` (mismo fallback, mismo patrón). No hay una función `Utils.IsFriendlyUnit` — cada consumidor repite `UnitCanAttack and not UnitCanAttack("player", unit)`.
- **Conclusión:** no es una inconsistencia de datos (todos calculan lo mismo con la misma fórmula), pero **sí es lógica duplicada en 4 sitios** en vez de una sola función reutilizable. Documentar para migración de estilo, no es un bug de comportamiento.

### 6.5 `cast` / `interruptible`

- **Única fuente real:** `Cast.GetState(unit)` (sin cache, siempre fresco — ver §3.11).
- **Consumido** vía snapshot (`Core.BuildSnapshot`) por `Decision`, `HealthBarColor`, `CastingBar`. Cuando no hay snapshot (hooks de repintado nativo), cada uno de los tres llama `Cast.GetState` **por separado**, lo cual, al ser sin cache, implica releer `UnitCastingInfo`/`UnitChannelInfo` varias veces si varios hooks se disparan en el mismo frame para la misma unidad (documentado como candidato de optimización en README §9). No es una fuente de verdad *inconsistente* (todos leen lo mismo, fresco), pero sí es trabajo redundante fuera del pase normal.
- **Persistencia de color** (`MinimizerPersistentCastColor`) es un concepto **distinto** de "¿está casteando ahora?" — vive únicamente en `HealthBarColor.lua`, gen-gated por `MinimizerHealthBarColorGen` (que es una CUARTA variable de generación distinta de `Core.plateGeneration`, `MinimizerDesimplifiedPersistentGen` y `MinimizerAbsorbPersistentGen` — ver §6.7).

### 6.6 `displayKind` / prioridad visual vs prioridad de simplificación

**Tres implementaciones independientes de "qué es más importante para esta unidad", que deben mantenerse sincronizadas a mano:**

1. **`Decision.ShouldSimplifyUnit`** — orden: target/focus → friendly → disabled → eliteType(boss/miniboss/caster) → `Threat.ShouldUnsimplify` → hasHadAbsorb → cast/channel → simplify. Objetivo: decidir simplificar o no.
2. **`Core.BuildSnapshot`** (rama `displayKind`) — orden: focus → `isNilSpecial` (`"priority"`) → `hasAggro` (`"aggro"`) → `hasHadAbsorb` (`"absorb"`) → `eliteType`. Objetivo: decidir qué **color base** usar.
3. **`Core.ComputeDisplayKind`** — **reimplementación separada** de (2), con pequeñas diferencias de implementación (usa `Threat.IsNilSpecial`/`Threat.PlayerHasAggro` directamente en vez de partir de `GetThreatDetails`), usada como fallback cuando no hay snapshot.
4. Dentro de **`HealthBarColor.UpdateNamePlate`** hay además una tercera capa de prioridad (`isSpecial = baseKind=="focus" or "aggro" or "priority" or isCasterClass`, `isSuperior = boss/miniboss`) que decide si el color de cast puede o no sobreescribir el `baseKind` — **una cuarta variante de "qué gana"**, coherente con las anteriores en la práctica (verificado por los tests de smoke: "PRIORITY" tests), pero implementada como una cuarta pieza de lógica en vez de derivarse mecánicamente de (2)/(3).

`BUG EXISTENTE / RIESGO DE DESINCRONIZACIÓN — NO CORREGIR DURANTE MIGRACIÓN`: cualquier cambio futuro a la tabla de prioridades (README §5) requiere tocar 3-4 sitios a mano. Los tests de `smoke_test.lua` (grupo "TEST GROUP 5B: Prioridad sobre superiores") cubren el comportamiento actual y deben seguir pasando igual tras la migración.

### 6.7 "generación de plate" — CUATRO campos de generación distintos

- `Minimizer.Core.plateGeneration[token]` — la fuente canónica, incrementada solo en `NAME_PLATE_UNIT_ADDED` (`Events.lua`).
- `nameplate.MinimizerDesimplifiedPersistentGen` — gen en que se marcó el fast-path de "no simp persistente" (`Core.ApplyToUnit`).
- `nameplate.MinimizerAbsorbPersistentGen` — gen en que se marcó `MinimizerHasHadAbsorb` (`Core.MarkAbsorbSeen`).
- `nameplate.MinimizerHealthBarColorGen` — gen en que se fijó `MinimizerPersistentCastColor` (`HealthBarColor.UpdateNamePlate`).

Los cuatro se comparan independientemente contra `Core.GetPlateGeneration(unit)` para decidir "¿este token fue reciclado desde la última vez que escribí este flag?". Es el mismo patrón de invalidación repetido cuatro veces con cuatro nombres de campo distintos, en vez de una única función `Core`/Lifecycle `HasGenerationChanged(nameplate, fieldName)` o de apoyarse siempre en `Minimizer.Cache` (que ya centraliza exactamente este patrón para otros datos). **No corregir ahora — documentar como candidato claro para el Snapshot/Lifecycle unificado.**

### 6.8 `simplified` / `desimplified`

- **Fuente de verdad de "¿debería estar simplificada?":** `Decision.ShouldSimplifyUnit` (o el fast-path de `Core.ApplyToUnit` cuando `MinimizerDesimplifiedPersistent` está activo).
- **Estado físico real de la nameplate:** `nameplate.MinimizerState` (lo último que se envió a `C_NamePlateManager.SetNamePlateSimplified`), comparado contra el resultado de Decision para decidir si vale la pena llamar a la API de nuevo.
- **Fast-path persistente:** `nameplate.MinimizerDesimplifiedPersistent` — una vez que `Decision` devuelve `"no simp"`, `Core.ApplyToUnit` deja de volver a preguntar a `Decision` mientras la generación no cambie (optimización, documentada, con tests explícitos "GAP2").
- Sin duplicación real aquí — es un único pipeline (`Decision` → fast-path cache en `Core`), correcto conceptualmente aunque la cache viva "a mano" en vez de en `Minimizer.Cache`.

### 6.9 `focus` / `target`

- `UnitIsUnit(unit, "target"/"focus")` se consulta en `Decision.ShouldSimplifyUnit` (para devolver razón `"target"`/`"focus"`) y en `Core.BuildSnapshot` (para `displayKind == "focus"`, nota: **no** hay caso `"target"` explícito en `displayKind`, target no tiene color especial propio más allá de lo que ya le darían las demás reglas — `REQUIERE VALIDACIÓN` si esto es intencional). Consistente entre los dos sitios que lo usan.

---

## 7. Caches e invalidación

| Cache | Dónde vive | Key | Invalidado por | Consumido por |
|---|---|---|---|---|
| `Minimizer.Cache.units` | `Core/Cache.lua` | `unit -> "eliteType" \| "threat:details" \| "threat:<source>"` | `Cache.InvalidateUnit(unit,kind)`, `Cache.InvalidateAll(kind)`, gen-gate automático vía `Core.GetPlateGeneration` | `Classification`, `Threat` |
| `Threat.playerTankCache` | `Plater/Threat.lua` | escalar único | `InvalidatePlayerTankCache()` (roster/spec change) | `Threat.*` |
| `Threat.nilState` | `Plater/Threat.lua` | `unit -> {generation,nilSince,nilSpecial}` | reset implícito cuando `generation` cambia dentro de `UpdateNilState`; `ForgetUnit` lo borra | `Threat.GetThreatDetails` |
| `Widgets.cdSpellCache` | `Overlays/Widgets.lua` | `dbTable -> (override or false) -> spellID or false` | `InvalidateCDSpellCache()` (spec/talent change, cambios de dropdown en Menu) | `Focus`, `Target` |
| `Interrupt.cachedSpellID` | `Plater/Interrupt.lua` | escalar único | `InvalidateSpellIDCache()` (spec/talent change) | `Focus`, `Target`, `CastingBar` (indirecto vía `GetSpellID`) |
| `Interrupt.cachedReady` | `Plater/Interrupt.lua` | escalar único | se **sobrescribe** en cada `RefreshReadyCache()` (no hay "invalidación", hay refresco explícito) | `CastingBar`, `Focus` |
| `nameplate.MinimizerDesimplifiedPersistent*` | `Plater/Core.lua` (escrito), leído también por `Decision` indirectamente vía fast-path | por nameplate | gen-gate manual + `Core.ClearNeverSimplify` en remove + `Events.lua`→`PLAYER_REGEN_ENABLED` limpia TODAS las plates visibles | `Core.ApplyToUnit` |
| `nameplate.MinimizerHasHadAbsorb` / `MinimizerAbsorbPersistentGen` | `Plater/Core.lua` (`MarkAbsorbSeen`) | por nameplate | gen-gate manual + `Core.ClearNeverSimplify` en remove | `Decision`, `HealthBarColor`, `Core.BuildSnapshot/ComputeDisplayKind` |
| `nameplate.MinimizerPersistentCastColor` / `MinimizerHealthBarColorGen` | `Plater/HealthBarColor.lua` | por nameplate | gen-gate manual + `HealthBarColor:OnNamePlateRemoved` | `HealthBarColor` (exclusivo) |
| `castBar.MinimizerLastCastColor` | `Plater/CastingBar.lua` | por castBar | `CastingBar:OnNamePlateRemoved` | hook de repintado nativo propio |
| `nameplate.MinimizerCastBar` | `Plater/CastingBar.lua` | por nameplate | `Core.ClearNeverSimplify` (`nameplate.MinimizerCastBar = nil`, en `Core.lua` no en `CastingBar.lua`) | `CastingBar:GetCastBar` |
| `MinimizerMarkers` | `Plater/Markers.lua` | por nameplate | nunca se destruye, solo se ocultan (`OnNamePlateRemoved` hace `:Hide()`) — reutilización de frames | `Markers` |

**Patrón general observado:** hay un sistema de cache centralizado (`Minimizer.Cache`, gen-gated) usado correctamente por `Classification` y (parcialmente) por `Threat`, y **en paralelo** un patrón manual de "campo en `nameplate` + campo de generación ad-hoc + comparación a mano" repetido independientemente en `Core.lua` (dos veces), `HealthBarColor.lua` (una vez) y `CastingBar.lua`/`Markers.lua` (sin gen-gate, solo limpieza en remove). Ninguno de estos casos es incorrecto individualmente, pero constituyen 3-4 reinvenciones del mismo mecanismo.

---

## 8. Timers, OnUpdate y polling

| Origen | Tipo | Intervalo | Qué hace | Riesgo |
|---|---|---|---|---|
| `Core.StartSafetyNet` (`Plater/Core.lua`, arrancado desde `Bootstrap.lua`) | `C_Timer.NewTicker` | 2.0s | `Core.ApplyToAll(false)` — pase completo de red de seguridad | Coincide en el tiempo con el resto de mecanismos; puede reprocesar unidades ya al día. |
| `Threat.StartMonitor` (`Plater/Threat.lua`, arrancado desde `Plater/Events.lua` al cargar el archivo) | `CreateFrame + SetScript("OnUpdate", ...)` | round-robin, `0.25/monitorCount` s por unidad | recorre `ActiveNameplates`, detecta cambios de threat/combat/nilSpecial/generación, llama `Core.ApplyToUnit(unit)` | **Segundo dispatcher independiente**, lee `ActiveNameplates` directamente. |
| `Utils.Debounce` (usado por `Core.RequestApplyToAll`) | `C_Timer.After(0, ...)` | próximo frame | ejecuta `ApplyToAll(true)` una sola vez aunque se pida varias veces en el mismo frame | Ninguno relevante; patrón correcto de coalescing. |
| `Utils.Throttle` (usado por `Focus.DebouncedUpdate`, `Target.DebouncedUpdate`) | `C_Timer.After(remaining, ...)` | máx. 1 cada 0.033s (30 FPS) | limita repintado de Focus/Target ante ráfagas de `SPELL_UPDATE_COOLDOWN` | Ninguno relevante; verificado por benchmark (§10 README: se mantiene en 25 llamadas ante 100 eventos simulados). |
| `HitTest.ScheduleRetry` | `C_Timer.After(0.05, tick)` encadenado | hasta 6 reintentos por unidad | reintenta `HitTest.Sync` hasta que Blizzard permita mutar el hit-test | Scheduler per-unit propio, pequeño pero independiente. |

**Conclusión de esta sección:** existen **al menos 3 mecanismos de "cuándo reprocesar"** actuando de forma no coordinada sobre el mismo universo de nameplates (`Events.lua`+debounce, `Threat`'s monitor, `Core`'s safety net), más 2 mini-schedulers per-unit (`HitTest`, y los throttles de Target/Focus). Ninguno de ellos sabe de la existencia de los otros.

---

## 9. Dependencias entre módulos

Notación: `A → B` significa "A llama funciones de B" (dependencia de tiempo de ejecución, no necesariamente de carga — el `.toc` ya garantiza que todo está cargado antes de `ADDON_LOADED`).

```
Bootstrap        → Config, Core
Options          → Menu
Menu             → Config, Core, Widgets, Data, Constants, Focus
SlashCommands    → Menu, Focus, Core
Events           → Core, Threat, Cast, Cache, Widgets, Interrupt, Target, Focus, Menu, Utils
Core             → Utils, Classification, Absorb, Threat, Cast, Decision, Interrupt, HitTest,
                    Cache (indirecto: Classification/Threat lo usan y Core expone GetPlateGeneration
                    del que Cache depende)
Decision         → Config, Classification, Threat, Absorb, Core (MarkAbsorbSeen), Cast
Threat           → Cache, Core (GetPlateGeneration, ApplyToUnit, ActiveNameplates), Utils
Classification   → Cache, Core (GetPlateGeneration, indirecto vía Cache), Utils
Absorb           → Utils
Cast             → (ninguna dependencia de otros módulos de dominio, solo WoW API)
Interrupt        → Utils, Data
HealthBarColor   → Utils, Constants, Threat, Absorb, Core (MarkAbsorbSeen, GetPlateGeneration,
                    ComputeDisplayKind, ApplyToUnit vía hook), Classification
CastingBar       → Utils, Constants, Cast, Interrupt, Widgets (FindCastBar)
Markers          → Utils (implícito), Core (RegisterModule)
HitTest          → Utils
Widgets          → Utils, Data
Focus            → Widgets, Interrupt, Utils, Data, Core (ApplyToAll vía SetFaceEnabled/SetArrowsEnabled)
Target           → Widgets, Interrupt, Data
Cache            → Core (GetPlateGeneration)
Config           → (ninguna)
Constants        → (ninguna)
Data             → (ninguna)
```

**Ciclos conceptuales detectados (no ciclos de carga, sí de dependencia de responsabilidad):**

- `Cache → Core.GetPlateGeneration` **y** `Core.BuildSnapshot → Classification/Threat/Absorb → Cache`. Core depende de los módulos de dominio para construir el snapshot, y esos módulos dependen de Core para saber la generación de la plate. Funciona porque `GetPlateGeneration` es una lectura trivial sin más dependencias, pero es un acoplamiento circular conceptual.
- `Threat → Core.ApplyToUnit` **y** `Core.BuildSnapshot → Threat.GetThreatDetails/PlayerHasAggro`. Threat es tanto insumo de Core como disparador de Core.
- `HealthBarColor → Core.ApplyToUnit` (desde `HookIndicator`) **y** `Core.UpdateModules → HealthBarColor.UpdateNamePlate`. Un módulo de presentación puede volver a disparar el dispatcher que lo invoca a él mismo.

---

## 10. Ciclos y responsabilidades cruzadas (resumen)

- **Core ↔ Threat:** ver arriba. Threat actúa como productor de datos para el snapshot de Core y, simultáneamente, como un dispatcher independiente que llama de vuelta a Core.
- **Core ↔ HealthBarColor:** HealthBarColor es consumido por Core (`UpdateModules`) y también puede volver a invocar a Core (`ApplyToUnit`) desde sus propios hooks de repintado nativo.
- **Decision ↔ Threat:** Decision delega una regla completa (`ShouldUnsimplify`) a Threat en vez de que Threat solo exponga datos y Decision decida.
- **HealthBarColor ↔ Threat:** HealthBarColor consulta directamente `Threat.IsPlayerTank`/`IsNilSpecial`/`ShouldLetBlizzardPaint` en vez de recibirlo resuelto en el snapshot.
- **Overlays (Target/Focus) fuera del ciclo de módulos registrados:** no participan de `Core.UpdateModules`, tienen su propio disparo desde `Events.lua` y su propio throttle — funcionan, pero constituyen un pipeline paralelo no unificado.

---

# Problemas arquitectónicos encontrados

## P1 — Dispatcher duplicado (el hallazgo central)

Existen tres mecanismos independientes capaces de decidir "hay que reprocesar nameplates ahora":
1. `Events.lua` (dispatch dirigido por eventos, con reglas de granularidad ad-hoc por tipo de evento).
2. `Threat.lua` → `monitorFrame` (polling round-robin sobre `ActiveNameplates`, con su propia lógica de "¿cambió algo?").
3. `Core.lua` → `StartSafetyNet` (ticker de 2s, pase completo incondicional).

Ninguno sabe de la existencia de los otros dos. Los tres pueden, en el mismo frame o en frames consecutivos, provocar múltiples `Core.ApplyToUnit`/`ApplyToAll` sobre las mismas unidades.

## P2 — Fuentes de verdad duplicadas

Ver §6 completo. Los casos más graves, de mayor a menor impacto:
1. **Absorb** (§6.3): 4-5 representaciones relacionadas, causa confirmada de inconsistencias visuales reportadas.
2. **displayKind / prioridad visual vs. prioridad de simplificación** (§6.6): 3-4 implementaciones paralelas de la misma tabla de prioridades.
3. **Generación de plate** (§6.7): 4 campos de generación independientes para el mismo concepto de "¿se recicló el token?".
4. **Threat/aggro** (§6.2): dos caminos de cache y dos algoritmos de `PlayerHasAggro` (justificados por rol tank/no-tank, pero no documentados como "dos algoritmos" en ningún sitio hasta ahora).
5. **friendly/PvP** (§6.4): misma fórmula repetida en 4 sitios sin una función compartida.

## P3 — Core sobrecargado

`Plater/Core.lua` mezcla: registro de módulos (Dispatch), construcción de snapshot (Snapshot), lifecycle de generación y `ActiveNameplates` (Lifecycle), fast-path de decisión persistente (Decision), mutación directa de la API nativa de Blizzard (Rendering-trigger), y orquestación del hit-test (Rendering-adyacente). Es la pieza más grande a descomponer.

## P4 — Threat sobrecargado

`Plater/Threat.lua` mezcla: lectura de datos crudos, cache propio ad-hoc (fuera de `Minimizer.Cache`), dos decisiones de negocio (`ShouldUnsimplify`, `ShouldLetBlizzardPaint`), y un dispatcher completo (`monitorFrame`). Es la segunda pieza más grande a descomponer, y la que más directamente ejemplifica el problema del encargo.

## P5 — Módulos que hacen trabajo de otros módulos

- `HealthBarColor` relee `UnitGetTotalAbsorbs` numérico en vez de pedírselo a un componente de Absorb.
- `HealthBarColor` y `CastingBar` duplican, cada uno por su cuenta, el hook de "reaplicar último color tras repintado nativo de Blizzard" (mismo patrón, dos implementaciones).
- `HealthBarColor` y `CastingBar` duplican, cada uno por su cuenta, el cálculo de `isFriendly`/`isPvP` como fallback.
- `Decision` y `HealthBarColor` duplican, cada uno por su cuenta, el fallback de `hasHadAbsorb` (llamando a `Absorb.HasAbsorb` + `Core.MarkAbsorbSeen` de forma independiente cuando no hay snapshot).
- `Widgets.lua` contiene lógica de decisión (`GetCDSpellID`) mezclada con creación de frames.

## P6 — Overlays (Target/Focus) fuera del pipeline central de módulos

No están registrados en `Core.RegisterModule`; se actualizan por un camino de eventos + throttle completamente distinto al de `HealthBarColor`/`CastingBar`/`Markers`. Esto no es necesariamente incorrecto (Target/Focus no iteran `ActiveNameplates`, solo atienden a una unidad concreta cada uno), pero sí significa que hoy **hay dos formas distintas de "ser un módulo visual" en el addon**, sin una interfaz común.

## P7 — Scheduling primitivo disperso

`Debounce`/`Throttle` viven en `Utils.lua` como primitivas de propósito general, pero cada consumidor (`Core.RequestApplyToAll`, `Focus.DebouncedUpdate`, `Target.DebouncedUpdate`) crea su propia instancia sin que exista un componente que sepa cuántos "debounces"/"throttles" activos hay ni pueda coordinarlos.

## P8 — Doble listener de `ADDON_LOADED`

`Bootstrap.lua` y `Options.lua` registran cada uno su propio frame para `ADDON_LOADED`. Inofensivo hoy, pero es una duplicación de patrón de lifecycle a unificar.

## P9 — Elementos que requieren validación adicional antes de migrar

- `REQUIERE VALIDACIÓN`: `UNIT_ABSORB_AMOUNT_CHANGED` tiene handler en `Events.lua` pero no se encontró su línea de `RegisterEvent` en el bloque final del archivo provisto — confirmar en el archivo real si está registrado o es código muerto.
- `REQUIERE VALIDACIÓN`: `unitFrame.MinimizerLetBlizzardHealthColor` (consultado en el hook de `CompactUnitFrame_UpdateHealthColor`) no se encontró seteado en ningún archivo del repo provisto — confirmar si es un flag vivo (seteado por Blizzard, por otro addon, o por código no incluido en esta auditoría) o dead code.
- `REQUIERE VALIDACIÓN`: `nameplate.MinimizerHasAbsorb` (distinto de `MinimizerHasHadAbsorb`) no se encontró leído por ningún módulo — confirmar si tiene consumidores fuera del árbol analizado antes de tocarlo en migración.
- `REQUIERE VALIDACIÓN`: la rama `split-architectonico` no se incluyó como contenido de archivos, solo como estructura de carpetas descrita en el encargo — si sus archivos difieren en contenido de los aquí analizados, esta auditoría debe re-ejecutarse contra esa rama antes de fase 1.

---

# Arquitectura objetivo

**[PROPUESTA]** — nada de esto existe todavía. Se define a nivel de responsabilidad, no de archivo, evitando "una carpeta por archivo".

## Lifecycle

**Responsabilidad:** única autoridad sobre la existencia y generación de nameplates activas.
- Posee: `ActiveNameplates` (registro token→nameplate), `plateGeneration` (contador por token).
- Expone: `RegisterNameplate(token, nameplate)`, `UnregisterNameplate(token)`, `GetGeneration(token)`, `IncrementGeneration(token)`, `IsGenerationStale(nameplate, storedGen)` (reemplaza los 4 campos de generación ad-hoc de §6.7 por una única función de utilidad reutilizada por quien la necesite, sin forzar a nadie a inventar su propio campo `MinimizerXGen`).
- Sustituye la responsabilidad de lifecycle hoy repartida entre `Core.lua` (ActiveNameplates, plateGeneration, IncrementPlateGeneration) y las partes de `Events.lua` que hoy deciden directamente cuándo incrementar generación.

## Dispatcher

**Responsabilidad:** única autoridad sobre "cuándo" se reprocesa una unidad o todas.
- Recibe: eventos de WoW (via un listener fino, ver Events abajo), señales de invalidación de los módulos de dominio (Threat, Absorb, Cast, Classification), y timers de red de seguridad.
- Decide: granularidad (unidad concreta vs. pase completo), coalescing/debounce, orden.
- Expone: `RequestUpdate(unit)`, `RequestFullUpdate()`, y una única implementación de debounce/throttle interna (sustituye el uso disperso de `Utils.Debounce`/`Throttle` para *este* propósito específico — `Utils.Throttle` puede seguir existiendo como primitiva genérica para otros usos como el throttle visual de Focus/Target).
- **Sustituye:** `Core.ApplyToAll`/`ApplyToUnit`/`RequestApplyToAll` (la parte de "cuándo"), `Threat.monitorFrame` completo, `Core.StartSafetyNet`.
- **Regla:** ningún otro componente crea su propio `OnUpdate`/`C_Timer.NewTicker` para recorrer nameplates. Los módulos de dominio (Threat, etc.) **notifican** al Dispatcher, no lo reemplazan.

## Snapshot / Context

**Responsabilidad:** construir, una vez por unidad por pase, la fotografía completa de datos que necesitan los módulos consumidores.
- Sustituye: `Core.BuildSnapshot` + `Core.ComputeDisplayKind` (unificados en una sola implementación — eliminar la duplicación de §6.6 estructuralmente, aunque el *comportamiento* resultante debe seguir siendo el mismo que hoy).
- Es el único lugar donde se decide `displayKind`/prioridad visual, con una tabla de prioridad **única**, reutilizada tanto por Decision (simplificación) como por los módulos de rendering, en vez de reimplementada en cada uno.
- Incluye el `hasHadAbsorb` persistente (sustituye `Core.MarkAbsorbSeen` como única fuente, eliminando los fallbacks ad-hoc de Decision/HealthBarColor descritos en §6.3).

## Domain (Threat, Absorb, Cast, Classification, Interrupt)

**Responsabilidad:** cada uno expone datos derivados de WoW sobre una unidad. **No deciden nada de negocio, no disparan el Dispatcher, no recorren `ActiveNameplates`.**
- `Threat` pierde: `monitorFrame` y todo su estado asociado (migra al Dispatcher, que puede seguir usando la misma cadencia round-robin como estrategia interna de invalidación, pero como *una* estrategia del Dispatcher, no como *un segundo dispatcher*), `ShouldUnsimplify` (migra a Decision), `ShouldLetBlizzardPaint` (migra a Decision o queda como dato consumido por HealthBarColor vía snapshot, no como pregunta directa).
- `Threat` conserva: `tankTokens`, `playerTankCache`, `nilState`, `GetThreatDetails`, `GetSituation`, `IsPlayerTank`, `PlayerHasAggro` (con sus dos ramas actuales preservadas tal cual).
- `Absorb` conserva su única responsabilidad (booleano vía indicador visual) y gana la responsabilidad de exponer también el dato numérico necesario para la overshield bar (sustituyendo la lectura directa de `UnitGetTotalAbsorbs` dentro de `HealthBarColor`), sin cambiar cómo se calcula.
- `Cast`, `Classification`, `Interrupt` quedan prácticamente iguales — ya están razonablemente bien acotados.

## Decision

**Responsabilidad:** única autoridad de reglas de negocio: simplificación (`ShouldSimplifyUnit`, ya existente) **más** las reglas hoy dispersas en Threat/HealthBarColor (`ShouldUnsimplify`, `ShouldLetBlizzardPaint`).
- Consume exclusivamente el Snapshot — nunca vuelve a llamar a `Threat`/`Absorb`/`Cast` directamente si el dato ya está en el snapshot (regla explícita pedida en el encargo).

## Plater (rendering de nameplates)

**Responsabilidad:** `HealthBarColor`, `CastingBar`, `Markers`, `HitTest` — módulos de presentación registrados que consumen snapshot y no vuelven a leer gameplay. Se preserva el mecanismo actual de `RegisterModule`/`UpdateModules`/`OnNamePlateRemoved` (funciona bien, es el pipeline más sano del repo hoy).
- Se extrae un helper común para el patrón "hook de repintado nativo + reaplicar último color guardado" (hoy duplicado entre `HealthBarColor` y `CastingBar`).

## Overlays (Target, Focus, y futuras)

**Responsabilidad:** presentación anclada a una unidad especial (target, focus, y lo que venga en el futuro), no a la iteración de todas las nameplates.
- Se les da una interfaz explícita y unificada (p.ej. `Overlays.Register(name, {onUnitChanged=..., onCooldownTick=...})`) en vez de que cada uno tenga su propio `DebouncedUpdate` cableado a mano en `Events.lua`. El **comportamiento observable** (throttle a 30fps, reaccionar a target/focus changed y a nameplate added/removed) se preserva.
- `Overlays` puede consumir infraestructura común (Widgets, Interrupt, Utils) pero no se convierte en otro dispatcher: no debe llamar `Core.ApplyToAll()` como efecto secundario de un toggle de configuración (hoy `Focus.SetFaceEnabled` lo hace) — en la arquitectura destino, un cambio de configuración debe pasar por el Dispatcher (`RequestFullUpdate()`), no por una llamada directa a Core.

## UI (Config, Menu, Options, SlashCommands)

Sin cambios de responsabilidad — ya están razonablemente bien acotados. Sus efectos secundarios (disparar refresco tras un cambio de configuración) deben pasar a usar la API pública del Dispatcher en vez de `Core.ApplyToAll()` directamente.

## Data (SpellData, Constants)

Sin cambios — ya son Static Data puro.

---

# Contratos entre componentes

**[PROPUESTA]**

### Dispatcher
- **Inputs:** eventos de WoW (a través de un Events/listener fino), invalidaciones explícitas emitidas por los componentes de Domain, tick de red de seguridad.
- **Outputs:** llamadas a Lifecycle (para resolver token/generación), a Snapshot (para construir contexto), a Decision (para simplificar/no), a la API nativa de Blizzard (`SetNamePlateSimplified`), a Plater/UpdateModules (fan-out).
- **Ownership:** único dueño de "cuándo se procesa qué".
- **Dependencias permitidas:** Lifecycle, Snapshot, Decision, Plater (fan-out), API nativa de Blizzard.
- **Dependencias prohibidas:** ningún componente de Domain (Threat/Absorb/Cast/Classification) debe ser llamado directamente por Dispatcher salvo a través de Snapshot.

### Lifecycle
- **Inputs:** eventos `NAME_PLATE_UNIT_ADDED`/`REMOVED`.
- **Outputs:** registro/generación consultables.
- **Ownership:** único dueño de `ActiveNameplates` y `plateGeneration`.
- **Dependencias permitidas:** ninguna (o solo Utils puro).
- **Dependencias prohibidas:** no debe llamar a Dispatcher, Decision, ni a módulos de Plater/Overlays.

### Snapshot
- **Inputs:** `unit`, `nameplate` (de Lifecycle).
- **Outputs:** tabla de contexto inmutable por el resto del pase (puede seguir siendo una tabla reutilizada por rendimiento, documentando explícitamente esa restricción de "solo válida durante este pase síncrono", tal como hoy).
- **Ownership:** único dueño de la tabla de prioridad (`displayKind`) y del flag persistente de absorb.
- **Dependencias permitidas:** Domain (Threat/Absorb/Cast/Classification/Interrupt), Lifecycle.
- **Dependencias prohibidas:** no debe llamar a Decision ni a Plater/Overlays.

### Domain (Threat/Absorb/Cast/Classification/Interrupt)
- **Inputs:** `unit` (y a veces `nameplate` para leer widgets nativos, como Absorb).
- **Outputs:** datos derivados, booleanos/tablas.
- **Ownership:** cada uno dueño de su propio dato crudo/derivado y de su propio cache (usando el cache genérico centralizado siempre que sea posible).
- **Dependencias permitidas:** Cache, Lifecycle (solo para generación), Utils.
- **Dependencias prohibidas:** no deben llamar a Dispatcher (`RequestUpdate`/`ApplyToUnit`), no deben recorrer `ActiveNameplates`, no deben decidir simplificación/pintado (eso es Decision/Plater).

### Decision
- **Inputs:** Snapshot.
- **Outputs:** `shouldSimplify, reason`; `shouldLetBlizzardPaint`; etc.
- **Dependencias permitidas:** Snapshot, Config.
- **Dependencias prohibidas:** no debe leer APIs de WoW directamente si el dato ya está en Snapshot.

### Plater (módulos registrados) / Overlays
- **Inputs:** Snapshot (Plater) o unit especial + eventos dedicados (Overlays).
- **Outputs:** mutaciones visuales (`SetStatusBarColor`, `Show`/`Hide`, etc.).
- **Dependencias permitidas:** Snapshot, Decision (solo lectura de su resultado), Widgets, Constants.
- **Dependencias prohibidas:** no deben llamar `Dispatcher.RequestUpdate`/`RequestFullUpdate` como efecto de un repintado nativo (deben limitarse a reaplicar el último valor conocido, patrón ya usado hoy con `GuardedCall`); no deben recorrer `ActiveNameplates`; no deben volver a consultar Domain si el dato está en Snapshot.

---

# Plan de migración

**[PROPUESTA]** Orden determinado por dependencias reales observadas en §9, no por la lista sugerida en el encargo. Cada fase es incremental, verificable con `tests/smoke_test.lua` y `tests/benchmark/benchmark.lua`, y no cambia comportamiento observable.

## Fase 0 — Documentación (esta fase)
- Producir/actualizar `arquitectura.md`. **Completada con este documento.**
- No tocar código.

## Fase 1 — Extraer Lifecycle de `Core.lua` sin tocar semántica
- **Archivos a tocar:** `Plater/Core.lua` (extraer, no reescribir lógica), posiblemente nuevo archivo `Plater/Lifecycle.lua` (o donde decida el equipo, sin forzar una carpeta nueva si no aporta).
- **Mover:** `Minimizer.ActiveNameplates`, `Minimizer.Core.plateGeneration`, `GetPlateGeneration`, `IncrementPlateGeneration`.
- **Preservar:** que `Cache.lua` siga pudiendo leer la generación (a través de la nueva ubicación, actualizando solo la referencia, no el comportamiento), que `Threat.lua` siga pudiendo leer `ActiveNameplates` (temporalmente, hasta Fase 3, para no romper el monitor antes de tener su reemplazo).
- **NO tocar:** `Decision.lua`, ningún módulo de Plater/Overlays todavía.
- **Comprobación:** `tests/smoke_test.lua` pasa igual; `tests/benchmark/benchmark.lua` no regresiona (p90 < 2.5ms).

## Fase 2 — Unificar `BuildSnapshot`/`ComputeDisplayKind`
- **Archivos a tocar:** `Plater/Core.lua`.
- **Acción:** las dos implementaciones de prioridad de `displayKind` (§6.6) se convierten en una sola función interna reutilizada por ambos call-sites (el pase normal y el fallback sin-snapshot de los hooks nativos). **Sin cambiar el resultado en ningún caso de test existente** — esto es refactor puro dentro de un mismo archivo, de bajo riesgo, y sienta la base para que Fase 4 pueda mover Snapshot a su propio componente.
- **Comprobación:** los tests de "PRIORITY" (grupo 5B de `smoke_test.lua`) deben seguir pasando exactamente igual.

## Fase 3 — Migrar el monitor de `Threat.lua` a ser fuente de invalidación, no un dispatcher
- **Archivos a tocar:** `Plater/Threat.lua`, `Plater/Core.lua` (o el nuevo Dispatcher si ya existe), `Plater/Events.lua` (quién llama `StartMonitor`).
- **Acción:** `monitorFrame`/`RebuildMonitorUnits`/`ProcessMonitoredUnit` dejan de llamar `Core.ApplyToUnit` directamente; en su lugar, marcan la unidad como "necesita reproceso" en una cola/flag que el Dispatcher (todavía `Core.ApplyToAll`/`ApplyToUnit` en esta fase temprana) consume en su siguiente pase. El **timing observable** (round-robin cada `0.25/N`s) debe preservarse — es funcionalidad, no arquitectura.
- **Preservar exactamente:** `ShouldUnsimplify`, `ShouldLetBlizzardPaint`, `PlayerHasAggro` (ambas ramas), `nilState`/`nilSpecial` heurística de 1.0s.
- **NO tocar todavía:** dónde viven `ShouldUnsimplify`/`ShouldLetBlizzardPaint` (eso es Fase 5).
- **Comprobación:** tests de Threat en `smoke_test.lua` (grupo "Threat: PlayerHasAggro (no-tank)" y el de tank cache) deben seguir pasando; correr `benchmark.lua` y verificar que el throttle check (Target/Focus) sigue en ~25 llamadas ante 100 eventos simulados.

## Fase 4 — Extraer Snapshot como componente propio (sin Dispatcher todavía)
- **Archivos a tocar:** `Plater/Core.lua` → nuevo componente Snapshot (nombre a decidir por el equipo).
- **Acción:** mover la función unificada de Fase 2 a su propio archivo/namespace, expuesta como `Minimizer.Snapshot.Build(unit, nameplate)`. `Core.ApplyToUnit` pasa a llamar a `Minimizer.Snapshot.Build` en vez de tener la lógica inline.
- **Preservar:** el uso de una tabla reutilizada (`scratchSnapshot`) si así se decide mantener por rendimiento — documentar explícitamente la restricción de "válida solo durante el pase síncrono actual" para que nadie la guarde entre pases en el futuro.
- **Comprobación:** todos los tests que dependen de `snapshot.*` (mayoría de `smoke_test.lua`) deben seguir pasando sin cambios.

## Fase 5 — Mover `ShouldUnsimplify`/`ShouldLetBlizzardPaint` a Decision
- **Archivos a tocar:** `Plater/Threat.lua` (retirar las funciones, dejar solo datos), `Plater/Decision.lua` (añadir las funciones, consumiendo Snapshot en vez de llamar a Threat directamente donde sea posible), `Plater/HealthBarColor.lua` (dejar de llamar `Threat.ShouldLetBlizzardPaint`/`IsPlayerTank`/`IsNilSpecial` directamente, consumir el resultado ya resuelto desde Snapshot/Decision).
- **Preservar exactamente:** el algoritmo actual de ambas funciones, tal cual, solo cambia su ubicación y su forma de recibir datos (de llamada directa a lectura de snapshot).
- **Comprobación:** tests de "Decision" y los de HealthBarColor relacionados con tank (no hay test explícito de tank+HealthBarColor en el smoke test provisto — `REQUIERE VALIDACIÓN`: verificar manualmente en cliente real tras esta fase, ya que `ShouldLetBlizzardPaint` no tiene cobertura de test visible).

## Fase 6 — Unificar Absorb (resolver §6.3 estructuralmente, sin cambiar comportamiento observable)
- **Archivos a tocar:** `Plater/Absorb.lua` (añadir lectura numérica opcional), `Plater/Core.lua`/Snapshot (única llamada a `MarkAbsorbSeen`, eliminar los fallbacks de `Decision.lua` y `HealthBarColor.lua`), `Plater/Decision.lua`, `Plater/HealthBarColor.lua`.
- **Acción:** todo consumidor de "hasHadAbsorb" pasa a leerlo exclusivamente del Snapshot (que ya lo calcula una vez por pase); se elimina el fallback ad-hoc que cada módulo tenía "por si no hay snapshot" **solo si se puede garantizar que todo consumidor siempre recibe snapshot** — si algún hook nativo puede disparar estos módulos sin snapshot (como ocurre hoy, ver `HookIndicator`), esos hooks deben empezar a pasar por el Dispatcher (que sí construye snapshot) en vez de llamar al módulo directamente. Esto depende de que Fase 7 (Dispatcher) ya exista, o de mantener temporalmente el fallback tal cual hasta entonces.
- **Comprobación:** tests "GAP1", "TEST A"/"TEST B" (secrets/persistencia verde), y el "BUG_FIX: repintado nativo... no debe eliminar el color absorb" deben seguir pasando exactamente igual.

## Fase 7 — Extraer Dispatcher real
- **Archivos a tocar:** `Plater/Core.lua` (retirar `ApplyToAll`/`ApplyToUnit`/`RequestApplyToAll`/`StartSafetyNet` hacia el nuevo componente), `Plater/Events.lua` (los handlers pasan a llamar a la API del Dispatcher en vez de a `Core.*` directamente — renombrar las llamadas, no la lógica de granularidad por evento, que se preserva tal cual).
- **Acción:** `Core.lua` queda reducido a: registro de módulos (`RegisterModule`/`UpdateModules`) y quizá nada más — su nombre podría incluso re-evaluarse, pero **no es objetivo de esta fase renombrar archivos**, solo mover responsabilidades.
- **Preservar exactamente:** todos los flujos de eventos documentados en §4 (inmediato vs debounced-full por tipo de evento), el ticker de safety-net a 2s, el debounce a 0 frames de `RequestApplyToAll`.
- **Comprobación:** `smoke_test.lua` completo + `benchmark.lua` completo (incluyendo el "Throttle check" y la medición aislada de `ApplyToAll`).

## Fase 8 — Unificar overlays bajo una interfaz común
- **Archivos a tocar:** `Overlays/Focus.lua`, `Overlays/Target.lua`, posible nuevo `Overlays/Overlays.lua` (registro).
- **Acción:** dar a Target/Focus una interfaz de registro similar a `Core.RegisterModule` pero para "unidad especial" en vez de "todas las nameplates", sin cambiar el throttle a 30fps ni los triggers de evento actuales.
- **Preservar exactamente:** `Focus.SetFaceEnabled`/`SetArrowsEnabled` (comportamiento visible en Menu/SlashCommands debe ser idéntico), el halo/pip/countdown de Target, el retrato/pip de Focus.
- **Comprobación:** manual en cliente (no hay tests automatizados de Overlays en el repo provisto — `REQUIERE VALIDACIÓN`: considerar añadir cobertura de test antes o durante esta fase).

## Fase 9 — Limpieza de duplicaciones menores (estilo, no arquitectura)
- Extraer `Utils.IsFriendlyUnit(unit)` para sustituir las 4 repeticiones de §6.4.
- Extraer un helper común de "hook de repintado + reaplicar último color" para sustituir la duplicación entre `HealthBarColor`/`CastingBar` (§P5).
- Sustituir los 4 campos de generación ad-hoc (§6.7) por la función `Lifecycle.IsGenerationStale` de Fase 1.
- **Comprobación:** suite completa de tests, sin cambios de comportamiento esperados en ninguno.

---

# Tabla completa de migración

| Código actual | Responsabilidad actual | Problema | Destino | Acción | Dependencias | Orden |
|---|---|---|---|---|---|---|
| `Core.ActiveNameplates` | registro de nameplates activas | leído directamente por `Threat.lua` | Lifecycle | mover, exponer API de solo-lectura | Threat (Fase 3), Cache (indirecto) | Fase 1 |
| `Core.plateGeneration` / `GetPlateGeneration` / `IncrementPlateGeneration` | contador de generación por token | consumido por `Cache.lua` con dependencia circular conceptual | Lifecycle | mover | Cache, Classification, Threat | Fase 1 |
| `Core.BuildSnapshot` | construir snapshot por unidad, incluye `displayKind` | duplicado con `ComputeDisplayKind` | Snapshot | unificar primero (Fase 2), luego extraer (Fase 4) | Classification, Absorb, Threat, Cast, Utils | Fase 2 y 4 |
| `Core.ComputeDisplayKind` | fallback de `displayKind` sin snapshot | reimplementación paralela de `BuildSnapshot` | Snapshot | eliminar como función separada, unificar | mismos que BuildSnapshot | Fase 2 |
| `Core.MarkAbsorbSeen` | persistir `hasHadAbsorb` | 3 call-sites independientes (`Core`, `Decision`, `HealthBarColor`) pueden invocarlo con datos distintos | Snapshot (única invocación) | centralizar llamada única dentro de Snapshot | Absorb, Decision, HealthBarColor | Fase 6 |
| `Core.ApplyToUnit` | dispatch + snapshot + decisión fast-path + mutación API nativa + hit-test + fan-out | hace demasiado | Dispatcher (dispatch/mutación/fan-out) + Decision (fast-path) + HitTest (ya separado) | descomponer | Lifecycle, Snapshot, Decision, HitTest, Plater | Fase 7 |
| `Core.ApplyToAll` | pase completo | uno de tres mecanismos de pase completo | Dispatcher | mover | Threat monitor, SafetyNet | Fase 7 |
| `Core.RequestApplyToAll` | debounce de pase completo | ok conceptualmente, mal ubicado | Dispatcher | mover | Utils.Debounce | Fase 7 |
| `Core.StartSafetyNet` | ticker de 2s de red de seguridad | mecanismo de dispatch nº3 | Dispatcher | mover, mantener intervalo 2.0s | Bootstrap (quién lo arranca) | Fase 7 |
| `Core.ClearNeverSimplify` | teardown de nameplate | reparte limpieza entre campos genéricos y `OnNamePlateRemoved` de módulos (correcto), pero vive en Core | Lifecycle (teardown genérico) + Plater (teardown por módulo, ya correcto) | mover la parte genérica | Cache, Cast, HitTest, Threat, todos los módulos registrados | Fase 1 (parcial) |
| `Core.RegisterModule` / `Core.UpdateModules` | registro y fan-out de módulos visuales | correcto, sin problema | Plater (se queda) | no mover | ninguna nueva | — |
| `Threat.monitorFrame` + funciones asociadas | scheduler round-robin sobre `ActiveNameplates` | dispatcher nº2 | Dispatcher (como estrategia interna de invalidación) | migrar a notificación, no a llamada directa | Lifecycle, Dispatcher | Fase 3 |
| `Threat.ShouldUnsimplify` | decisión de "no simplificar por threat" | vive en módulo de datos, no de decisión | Decision | mover | Snapshot | Fase 5 |
| `Threat.ShouldLetBlizzardPaint` | decisión de "dejar pintar a Blizzard" | vive en módulo de datos, consumida directamente por HealthBarColor | Decision (o Snapshot como dato ya resuelto) | mover | Snapshot, HealthBarColor | Fase 5 |
| `Threat.GetThreatDetails` / `GetSituation` (dos caminos de cache) | lectura de threat | dos representaciones parcialmente solapadas | Threat (se queda, documentar explícitamente las dos ramas en comentario, sin unificar el algoritmo — fuera de alcance de la migración arquitectónica) | ninguna en esta migración | Cache | no aplica (documentar, no migrar comportamiento) |
| `HealthBarColor.UpdateOvershieldBar` (lectura de `UnitGetTotalAbsorbs`) | dibujar ancho de overshield | bypasea la filosofía de Absorb.lua | Absorb (exponer lectura numérica) | mover la llamada a la API, mantener el cálculo | Absorb | Fase 6 |
| `HealthBarColor` fallback `isFriendly`/`isPvP` | recomputar si no hay snapshot | duplicado con CastingBar | Utils (`IsFriendlyUnit` nuevo) | extraer helper | CastingBar | Fase 9 |
| `HealthBarColor` hook `SetStatusBarColor` | reaplicar último color tras repintado nativo | patrón duplicado con CastingBar | helper compartido (ubicación a decidir, p.ej. Utils o un nuevo `RepaintGuard`) | extraer | CastingBar | Fase 9 |
| `CastingBar` hook `SetStatusBarColor` | ídem para castbar | ídem | mismo helper compartido | extraer | HealthBarColor | Fase 9 |
| `Widgets.GetCDSpellID` | decidir qué spell mostrar (con override de usuario) | lógica de decisión en archivo de "Widgets" | se mantiene en Overlays-support, pero documentado como Decision-adyacente; no migrar físicamente si no aporta (evitar microcarpetas) | ninguna (documentar) | Data, Utils | no aplica |
| `Focus.SetFaceEnabled`/`SetArrowsEnabled` → `Core.ApplyToAll()` | efecto secundario de config | Overlay llamando directo al dispatcher | usar `Dispatcher.RequestFullUpdate()` | actualizar la llamada | Dispatcher | Fase 7/8 |
| `nameplate.MinimizerDesimplifiedPersistentGen` / `MinimizerAbsorbPersistentGen` / `MinimizerHealthBarColorGen` (3 campos de generación ad-hoc, más el canónico de Core) | invalidación por reciclaje de token | 4 representaciones del mismo concepto | Lifecycle (`IsGenerationStale` helper) | sustituir por helper único, preservando el resultado | Core/Lifecycle, HealthBarColor | Fase 9 |
| `Overlays/Focus.lua`, `Overlays/Target.lua` | overlays de unidad especial con pipeline propio | no unificado con Plater | Overlays (interfaz de registro propia, no fusionar con Plater) | dar interfaz común | Widgets, Interrupt, Dispatcher | Fase 8 |
| `Options.lua` listener `ADDON_LOADED` propio | duplica el de Bootstrap | menor, cosmético | Bootstrap (único listener, notifica a quien se suscriba) | opcional, bajo impacto | Bootstrap | Fase 9 (opcional) |

---

# Funcionalidad que debe preservarse

Listado explícito de comportamiento actual (correcto o no) que la migración **no debe alterar**:

1. **Determinación de tank:** `UnitGroupRolesAssigned("player")=="TANK"` primero; si no, `C_SpecializationInfo`; si no, `GetSpecialization`/`GetSpecializationRole` legacy. Cacheado hasta invalidación explícita en roster/talent/spec change.
2. **Aggro (no-tank):** `UnitThreatSituation("player", unit) == 3`.
3. **Aggro (tank):** el jugador tiene aggro si está en combate con la unidad, ningún otro tank tiene aggro (`otherTankAggro`), y `situation` es `nil`, `0`, `1` o `2`.
4. **nilSpecial:** una unidad que no puede atacar al jugador (`UnitCanAttack(unit,"player")==false`) y lleva ≥1.0s en combate con `UnitThreatSituation` devolviendo `nil` se marca `nilSpecial=true`; se resetea si deja de cumplirse la condición.
5. **Absorb:** se determina exclusivamente mirando si el indicador visual nativo (`totalAbsorbOverlay`/`totalAbsorb`) está `:IsShown()`. Una vez visto absorb, `hasHadAbsorb` queda persistente hasta que cambie la generación del token (nameplate reciclada) o se remueva la nameplate.
6. **Target/Focus:** siempre desimplificadas (`Decision` devuelve `false, "target"`/`false, "focus"`), independientemente de cualquier otra regla.
7. **Cooldowns (Target/Focus):** halo ofensivo + pip defensivo en Target; retrato + cooldown de interrupt + pip de CC masivo en Focus; ambos con override manual del usuario vía `MinimizerCharDB` con fallback automático al primer spell conocido por orden en `SpellData.lua`.
8. **Simplificación/desimplificación:** ver tabla de prioridad README §5 completa (focus > aggro > absorb > superior > inferior+cast interrumpible > inferior+cast ininterrumpible > resto). El fast-path de "no simp persistente" evita repreguntar a Decision mientras no cambie la generación del token.
9. **HitTest:** se sincroniza tras cada cambio de estado de simplificación (o forzado), con hasta 6 reintentos a 0.05s si Blizzard aún no permite mutar el hit-test.
10. **Castbars:** verde si interrumpible + corte de interrupt listo, rosa si interrumpible + corte en cooldown, sin tocar (gris nativo de Blizzard) si ininterrumpible. Igual leyenda para channel que para cast.
11. **Interrupts:** el spellID a usar es el primero conocido por el jugador según el orden de `SpellData.lua` por clase; el estado "listo" se refresca una vez por pase (`ApplyToAll`) y en `SPELL_UPDATE_COOLDOWN`, nunca dentro de un loop de nameplates.
12. **Markers:** flechas de target (blancas) y focus (amarillas, opcionales vía `enableFocusArrows`) ancladas a la healthBar.
13. **Eventos que provocan actualización:** ver §4 y la tabla de handlers de `Events.lua` completa — cada evento debe seguir disparando exactamente el mismo conjunto de acciones (inmediato/debounced/invalidación) que hoy.
14. **Fallbacks fuera de pase (hooks nativos):** cuando un módulo se invoca sin `snapshot` (repintado nativo de Blizzard), debe seguir pudiendo recalcular su dato por sí mismo (aunque la migración pueda cambiar *cómo* obtiene ese dato, el resultado visible debe ser idéntico).
15. **Estados históricos/persistentes:** color de cast persistente (incluyendo el caso gris que persiste tras terminar un cast ininterrumpible, ver README §6.1), flag de absorb persistente, flag de "no simp" persistente — todos gen-gated y limpiados en `OnNamePlateRemoved`/regen-enabled según corresponda.
16. **Migración de config legacy:** `focusIndicator` (string) → `enableFocusFace`/`enableFocusArrows` (booleans), gateada por presencia de la clave vieja.
17. **Simplify enabled:** soporta tanto `MinimizerDB.simplifyEnabled` (booleano, fuente moderna) como `MinimizerDB.simplifyPercent` (string/número legacy, `>0` = habilitado) como fallback si el booleano no existe.

---

# Bugs conocidos que NO deben corregirse durante la migración

1. **`BUG EXISTENTE`** — Inconsistencia absorb: overlay visible pero healthbar no pintada del color correspondiente (o viceversa), causada por las 4-5 representaciones independientes de "hasHadAbsorb"/"hasAbsorb" descritas en §6.3. Preservar el comportamiento actual (incluyendo sus inconsistencias) hasta después de la migración arquitectónica.
2. **`BUG EXISTENTE`** (documentado en README §6.1 como "consecuencia aceptada") — El color gris de cast ininterrumpible persiste visualmente tras terminar el cast, aunque la simplificación vuelve a estar disponible ("temporal"). Es un desacople intencional entre color persistente y estado de simplificación real. No es un bug de arquitectura, es comportamiento de producto documentado — **preservar tal cual**.
3. **`BUG EXISTENTE` (Known Issues README §8)** — Unidades fuera de combate pueden evaluarse a "simplificar" al aparecer y luego Blizzard las repinta maximizadas en el mismo frame; mitigado parcialmente con `forceUpdate` mediante `RequestApplyToAll` tras `NAME_PLATE_UNIT_ADDED`, pero "no cerrado del todo" según el propio README. No tocar.
4. **`REQUIERE VALIDACIÓN` tratado como posible bug/dead-code** — `unitFrame.MinimizerLetBlizzardHealthColor` nunca visto seteado en el árbol analizado; y el registro de `UNIT_ABSORB_AMOUNT_CHANGED` no se encontró explícitamente en la lista final de `RegisterEvent` de `Events.lua` pese a tener handler. Documentar, no tocar sin validar contra el repo real.
5. **`BUG EXISTENTE` (implícito, riesgo de desincronización)** — Las 3-4 implementaciones paralelas de prioridad `displayKind`/simplificación (§6.6) pueden, ante un cambio futuro no coordinado, divergir. Hoy están sincronizadas (verificado por los tests de prioridad), pero es una fragilidad estructural a resolver **como parte de la migración arquitectónica en sí** (Fase 2/4), no como "corrección de bug" — es exactamente el tipo de trabajo que el encargo autoriza (reorganizar sin perder funcionalidad), siempre que el resultado observable sea idéntico.

---

# Riesgos

| Riesgo | Dónde aplica | Mitigación propuesta |
|---|---|---|
| Orden de carga (`Minimizer.toc`) | cualquier fase que mueva código entre archivos | mantener el mismo orden relativo de dependencias (p.ej. Lifecycle debe cargar antes que Cache si Cache sigue dependiendo de él) o eliminar la dependencia de carga sustituyéndola por inicialización perezosa, como ya hace `Cache.lua` hoy (`Minimizer.Core and Minimizer.Core.GetPlateGeneration and ...`) |
| Inicialización (`ADDON_LOADED`) | Fase 9 si se unifica el listener de Options | verificar que `Config.Initialize()` sigue corriendo antes de que cualquier módulo lea `MinimizerDB` |
| Globals (`_G.Minimizer`) | todas las fases | no romper el patrón `local _, Minimizer = ...` en cada archivo; cualquier archivo nuevo debe seguir el mismo patrón |
| Referencias a `Minimizer.Core` desde fuera | Fase 1, 3, 4, 7 (mientras se mueven funciones) | mantener alias temporales (`Minimizer.Core.ApplyToUnit = Minimizer.Dispatcher.ApplyToUnit`) durante la transición si hay múltiples call-sites que no se puedan actualizar todos en el mismo commit |
| Referencias a módulos (`Minimizer.Threat.X`, etc.) | Fase 3, 5 | mismo patrón de alias temporal; los tests (`tests/smoke_test.lua`) acceden a `addonTable.Threat.*`, `addonTable.Decision.*`, etc. directamente — cualquier función movida debe seguir siendo accesible por el mismo nombre cualificado hasta que se actualicen los tests explícitamente |
| Callbacks/closures | `Utils.Debounce`/`Throttle` (closures con estado propio: `pending`, `lastTime`) | no reinstanciar estas closures en cada llamada; si se centraliza en Dispatcher, verificar que sigue habiendo una única instancia por consumidor lógico (hoy: una para `RequestApplyToAll`, una para `Focus.DebouncedUpdate`, una para `Target.DebouncedUpdate`) |
| Hooks (`hooksecurefunc`) | HealthBarColor, CastingBar, Events (NamePlateDriverFrame, CompactUnitFrame_UpdateHealthColor) | los hooks son globales y acumulativos — si una fase reorganiza el código que los registra, verificar que no se registran dos veces (usar los mismos flags idempotentes ya existentes: `MinimizerHealthColorHooked`, `MinimizerColorHooked`, `MinimizerAbsorbHooked`) |
| Frames (`CreateFrame`) | Focus, Target, Menu, Options, Widgets, HealthBarColor (overshield bar), CastingBar (visuals) | los frames con nombre global (`CreateFrame("Frame", "MinimizerXxx", ...)`) quedan en `_G` — si se renombra un archivo/módulo no cambiar el nombre del frame sin verificar que nada más lo referencia por nombre string |
| Eventos (`RegisterEvent`) | Events.lua | un único `EventFrame` centralizado hoy — preservar esto en el Dispatcher, no fragmentar el registro de eventos entre varios frames |
| Caches | Cache.lua, Threat (propio), Widgets (propio), Interrupt (propio) | cada cache tiene su propia invalidación — al mover código, verificar que la invalidación se sigue disparando desde los mismos eventos que hoy (`HandleRosterOrSpecChange`, `PLAYER_REGEN_ENABLED`, etc.) |
| Generación de nameplates | Core.plateGeneration + 3 campos ad-hoc | al centralizar en Lifecycle (Fase 1) y luego unificar los campos ad-hoc (Fase 9), verificar con los tests "GAP1"/"GAP2"/Token-recycle (grupo 6 del smoke test) que el comportamiento de reciclaje de token sigue siendo idéntico |
| Estado persistente en `nameplate.*` | todos los módulos que escriben campos `Minimizer*` en `nameplate` | los nombres de campo son parte del contrato implícito con Blizzard (nameplates se reciclan, no se destruyen) — no renombrar campos sin actualizar TODOS los lectores/escritores y los tests que los inspeccionan directamente (`np.MinimizerHitTestRegion`, `np.MinimizerPersistentCastColor`, etc.) |
| Funciones que esperan existir antes que otras | `Bootstrap.lua` espera `Config`/`Core` ya cargados; `Options.lua`/`Menu.lua` esperan `Minimizer.Menu`/`Minimizer.Focus` disponibles en tiempo de click, no de carga | preservar los checks defensivos ya existentes (`if Minimizer.Focus then ... end`) durante toda la migración, especialmente mientras haya fases intermedias con componentes a medio mover |

---

# Checklist de migración

Antes de dar cualquier fase por completada:

- [ ] `lua tests/smoke_test.lua` pasa con 0 `FAIL`.
- [ ] `lua tests/benchmark/benchmark.lua` no regresiona contra el último baseline guardado en `tests/results/` (p90 < 2.5ms, y comparar manualmente el reparto por módulo/función contra la corrida anterior).
- [ ] Ningún archivo fuera de la fase actual fue modificado.
- [ ] Todos los campos `nameplate.Minimizer*` que existían antes de la fase siguen existiendo con el mismo nombre y semántica (salvo que la fase sea explícitamente "Fase 9 — unificar campos de generación", documentada aparte).
- [ ] Todos los eventos registrados en `Events.lua` antes de la fase siguen registrados después.
- [ ] Todos los `hooksecurefunc` siguen registrándose exactamente una vez (verificar flags idempotentes).
- [ ] El orden de `Minimizer.toc` sigue siendo coherente con las dependencias de carga reales.
- [ ] Ningún módulo nuevo introduce un `OnUpdate`/`CreateFrame`+`C_Timer.NewTicker` adicional que recorra `ActiveNameplates` (violaría la Regla R1 de la sección siguiente).

---

# Reglas arquitectónicas

Derivadas de los hallazgos de este documento, para aplicar durante toda la migración (fases 1-9) y en desarrollo futuro:

**R1.** Ningún módulo puede recorrer `ActiveNameplates` (o su futura ubicación en Lifecycle) salvo el Dispatcher. Todo componente que hoy lo hace (`Threat.monitorFrame`, `Events.lua`→`HandleFullRefreshEvent` vía `C_NamePlate.GetNamePlates()`) debe migrar a notificar al Dispatcher en vez de iterar por su cuenta.

**R2.** Ningún módulo puede crear su propio `OnUpdate`/`C_Timer.NewTicker` que actúe como scheduler de reprocesamiento de nameplates. Los mini-schedulers per-unit legítimos y acotados (como `HitTest.ScheduleRetry`, que reintenta una operación puntual de Blizzard, no que decide "qué reprocesar") no están prohibidos por esta regla, pero deben documentarse explícitamente como excepción justificada.

**R3.** Ningún módulo de rendering (Plater u Overlays) puede consultar directamente una fuente de gameplay (Threat, Absorb, Cast, Classification) si el dato ya está disponible en el Snapshot del pase actual. Los fallbacks para el caso "sin snapshot" (hooks de repintado nativo) son la única excepción tolerada, y deben minimizarse en la medida en que el Dispatcher pueda garantizar snapshot siempre.

**R4.** Un estado derivado (aggro, tank, hasHadAbsorb, displayKind, generación de plate) tiene una única función que lo calcula y, si aplica, un único mecanismo de persistencia/cache. Prohibido que dos módulos calculen o persistan independientemente el mismo concepto con nombres de campo distintos (ver §6.7 como ejemplo del anti-patrón a no repetir).

**R5.** Los módulos de Domain (Threat, Absorb, Cast, Classification, Interrupt) no llaman `Dispatcher.RequestUpdate`/`RequestFullUpdate` ni al equivalente de `Core.ApplyToUnit`/`ApplyToAll`. Solo notifican/invalidan; el Dispatcher decide cuándo actuar sobre esa notificación.

**R6.** Los eventos de WoW entran únicamente por el listener central del Dispatcher (hoy `Events.lua`). Ningún otro archivo registra `RegisterEvent`/`RegisterUnitEvent` propio para eventos relacionados con el ciclo de vida de nameplates o gameplay de unidades (excepción ya existente y aceptable: `Bootstrap.lua`/`Options.lua` con `ADDON_LOADED`, que es lifecycle del propio addon, no de nameplates).

**R7.** Plater no depende de Overlays. Overlays puede depender de infraestructura común (Widgets, Interrupt, Utils, Dispatcher) pero nunca se convierte en un segundo Dispatcher (no debe recorrer todas las nameplates ni mantener su propio registro paralelo de "unidades activas").

**R8.** Ningún módulo visual (Plater/Overlays) dispara un pase completo del Dispatcher como efecto secundario de una acción de UI (toggle de Menu/SlashCommands). Esa responsabilidad es de la capa de Configuration/UI, que debe llamar a una API pública del Dispatcher (`RequestFullUpdate()`), nunca a una función interna.

**R9.** Todo cache de estado derivado debe usar el mecanismo centralizado de invalidación (gen-gated, vía el componente Cache) salvo justificación explícita documentada en el propio código (como el caso de `Cast.lua`, que deliberadamente no cachea nada — decisión ya documentada y a preservar).

**R10.** Ningún componente de Domain decide simplificación, coloreado, ni ninguna otra regla de presentación/gameplay que no sea "cuál es el valor actual de X". Las decisiones (`ShouldSimplifyUnit`, `ShouldUnsimplify`, `ShouldLetBlizzardPaint`, prioridad de `displayKind`) viven exclusivamente en Decision/Snapshot.

**R11.** Un hook de repintado nativo de Blizzard (`hooksecurefunc` sobre `SetStatusBarColor`, `Show`/`Hide`, etc.) solo puede reaplicar el último valor conocido guardado por el propio módulo (patrón `GuardedCall` ya existente). Si necesita recalcular ese valor desde cero, debe hacerlo pidiendo al Dispatcher que reprocese la unidad (con snapshot fresco), no recalculando manualmente con llamadas directas a Domain.

**R12.** Añadir un nuevo feature (o un nuevo overlay, o un nuevo módulo de Plater) no debe requerir tocar el Dispatcher ni el Snapshot salvo para añadir el dato nuevo que ese feature necesite exponer — nunca para cambiar la lógica de "cuándo" se procesa.

---

# Resumen ejecutivo (validación final del análisis)

1. **Archivos analizados:** 34 documentos — 27 archivos de código/configuración del addon (`.lua`/`.toc`), 3 archivos de test/benchmark, y 4 archivos de documentación/config (`README.md`, `Docs/debt.md`, `.gitignore`, y este propio `arquitectura.md` que se genera). Todos los archivos del `.toc` fueron leídos y clasificados.
2. **Todos los timers/OnUpdate identificados:** `Core.StartSafetyNet` (ticker 2s), `Threat.StartMonitor` (OnUpdate round-robin), `Utils.Debounce`/`Throttle` (usados por `Core.RequestApplyToAll`, `Focus.DebouncedUpdate`, `Target.DebouncedUpdate`), `HitTest.ScheduleRetry` (cadena de hasta 6 `C_Timer.After`).
3. **Todos los recorridos de nameplates identificados:** `Core.ApplyToAll` sobre `ActiveNameplates`; `Threat.RebuildMonitorUnits`/monitor sobre `ActiveNameplates`; `Events.lua`→`HandleFullRefreshEvent` sobre `C_NamePlate.GetNamePlates()` directo (camino lento, aloca tabla).
4. **Fuentes de verdad duplicadas confirmadas:** absorb (la más grave, con síntoma visual reportado), displayKind/prioridad (3-4 implementaciones), generación de plate (4 campos), threat/aggro (2 caminos de cache + 2 algoritmos por rol), friendly/PvP (lógica repetida en 4 sitios sin bug real, solo duplicación).
5. **Core desglosado por responsabilidad:** ver §3.15 (tabla función por función) — no tratado como caja negra.
6. **Threat desglosado por responsabilidad:** ver §3.9 — el módulo más sobrecargado tras Core, con un dispatcher completo embebido.
7. **HealthBarColor desglosado:** ver §3.17.
8. **Events desglosado:** ver §3.24 — confirmado como segundo componente con lógica de dispatch (granularidad por tipo de evento).
9. **Target/Focus/Widgets tratados como Overlays**, con la salvedad documentada de que Target/Focus no están unificados con el pipeline de módulos de Plater (§P6).
10. **HitTest clasificado según lo que realmente hace:** sincronización de hit-test con mini-scheduler de reintentos per-unit, no un módulo de decisión ni de rendering puro.
11. **El plan conserva toda la funcionalidad existente** (ver sección dedicada), incluyendo los bugs conocidos, explícitamente marcados para NO corregir en esta migración.
12. **Ningún archivo de código fue modificado** durante esta auditoría — únicamente se ha creado `arquitectura.md`.

**Principales candidatos a migración (por impacto):** `Plater/Core.lua` (fases 1, 2, 4, 7), `Plater/Threat.lua` (fases 3, 5), la unificación de Absorb (fase 6), y la extracción del Dispatcher real (fase 7) como culminación de las fases previas.

**Mayores riesgos:** (a) romper el contrato implícito de nombres de campo `nameplate.Minimizer*` que varios tests inspeccionan directamente; (b) desincronizar las 3-4 implementaciones de prioridad `displayKind` al unificarlas si no se valida exhaustivamente contra los tests de "PRIORITY" existentes; (c) que el monitor de Threat dejado de lado en Fase 3 cambie sutilmente el timing round-robin observable si no se preserva la fórmula `0.25/monitorCount`; (d) los dos puntos marcados `REQUIERE VALIDACIÓN` (`UNIT_ABSORB_AMOUNT_CHANGED` y `MinimizerLetBlizzardHealthColor`) deben confirmarse contra el repositorio real (posiblemente la rama `split-architectonico`) antes de tocar `Events.lua` en Fase 7.
