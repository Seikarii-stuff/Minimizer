# Minimizer — Referencia de Arquitectura, Taint y Secrets (v2)

> Este documento reemplaza al `project.md` original (guía teórica basada en Platynator).
> Aquí ya no se documenta "cómo lo hace Platynator" en abstracto: se documenta **cómo lo
> hace realmente Minimizer hoy**, verificado línea por línea contra el código fuente
> actual (que compila y funciona en cliente), señalando dónde coincide con el patrón
> canónico de Platynator, dónde se desvió (a propósito o por error), y qué partes son
> deuda técnica / código junior que hay que vigilar durante la reestructuración.
>
> Objetivo: que durante la reescritura de arquitectura se pueda abrir este archivo,
> buscar "¿cómo se resolvía X?" y encontrar la respuesta verificada, sin tener que
> releer todos los .lua ni arriesgarse a romper taint por reinventar una solución que
> ya se había resuelto correctamente.
>
> Nota: el punto de "falta de panel de opciones/localizacion" identificado en un review anterior queda fuera de alcance de este proyecto -- el producto final que consume este addon ya tiene su propio menu, implementar uno aqui duplicaria trabajo.

---

## LEYENDA M+ — CONVENCIÓN DE COLORES Y SIMPLIFICACIÓN (NO MODIFICAR SIN PERMISO)

> Esta es la leyenda de Mythic+ estándar que sigue TODO el mundo.
> **No cambiar nada de esta sección ni la lógica que la implementa sin permiso explícito.**

### Prioridad de color (descendente — la primera regla que aplica gana)

| Prioridad | Condición | Color | Simplificación |
|-----------|-----------|-------|----------------|
| 1 | **Focus** | Amarillo | Sin cambio (focus no altera simplificación) |
| 2 | **Aggro** (situación 3) | Rojo gestionado por Blizzard | TEMPORAL (mientras dura) |
| 3 | **Shield/Absorb** activo | Rosa (`absorb`) | TEMPORAL (mientras dura) |
| 4 | **Superior** (boss/miniboss) + cast **ininterrumpible** | Gris | TEMPORAL (solo mientras castea) |
| 5 | **Inferior** (cualquier no-superior) + cast **interrumpible** o canalización | Verde **PERSISTENTE** | **PERSISTENTE** (flag permanente) |
| 6 | **Inferior** + cast **ininterrumpible** | Gris | TEMPORAL (solo mientras castea) |

### Definiciones

- **Superior**: `boss` o `miniboss` (morado). Determinado por nivel skull / worldboss / elite+2 niveles.
- **Inferior**: CUALQUIER unidad que no sea superior — melee (blanco), caster/hasmana (azul), trivial (negro), esbirros, menores. Los azules no tienen regla especial de cast; siguen la misma leyenda que cualquier inferior.
- **Persistente**: el flag/color permanece incluso después de que termine el cast o el escudo.
- **Temporal**: el flag/color desaparece en cuanto desaparece la condición.

### Rationale M+

En Mythic+, cualquier inferior que castee algo interrumpible ES wipe potencial si no se para.
Verde persistente: el grupo sabe que esa unidad ya demostró capacidad de castear y hay que
priorizarla incluso después del cast actual. Gris (ininterrumpible): peligroso pero no interrumpible.
Los superiores son siempre peligrosos (morado); solo se avisa con gris temporal cuando su cast
es ininterrumpible, pues si es interrumpible el grupo ya sabe que tiene que interrupirlo.

---

## 0. Mapa de módulos (estado actual, orden de carga del .toc)


```
Bootstrap.lua       -> Minimizer (inicialización global, ADDON_LOADED)
Utils.lua           -> Minimizer.Utils (helpers puros, guards de secretos, debounce, tokens)
Widgets.lua         -> Minimizer.Widgets (búsqueda de castbars, creación y estilo de widgets de CD)
Config.lua          -> Minimizer.Config (SavedVariables MinimizerDB, defaults, migración)
Constants.lua       -> Minimizer.Constants (paletas de color de salud y cast)
data/SpellData.lua  -> Minimizer.Data (tablas de spellIDs por clase: interrupts, CDs ofensivos/defensivos, CC)
Cache.lua           -> Minimizer.Cache (cache genérico unit -> {kind -> valor})
Threat.lua          -> Minimizer.Threat (detección de aggro/tanque, sincronización de tokens)
Absorb.lua          -> Minimizer.Absorb (detección de absorción visual vía indicator:IsShown())
Cast.lua            -> Minimizer.Cast (lectura segura de casts/canalizaciones e invalidación)
Classification.lua  -> Minimizer.Classification (clasificación de unidades: boss, miniboss, caster, melee, trivial)
Decision.lua        -> Minimizer.Decision (motor de decisión de simplificación ShouldSimplifyUnit)
Interrupt.lua       -> Minimizer.Interrupt (spellID de interrupción + cache de cooldown a nivel de pase)
Core.lua            -> Minimizer.Core (orquestación, ciclo de vida, registro de módulos, snapshot)
Markers.lua         -> Minimizer.Markers (gestión de marcas de objetivo)
HealthBarColor.lua  -> Minimizer.HealthBarColor (módulo registrado: coloreo de healthbars nativas)
CastingBar.lua      -> Minimizer.CastingBar (módulo registrado: coloreo de castbars nativas, visuales de objetivo)
Focus.lua           -> Minimizer.Focus (retrato de focus, indicador de CD de interrupt y CC masivo)
Target.lua          -> Minimizer.Target (widgets de CDs defensivos y ofensivos sobre el objetivo)
Events.lua          -> Minimizer (EventFrame centralizado con tabla de dispatch)
SlashCommands.lua   -> Minimizer (comandos de consola /simp)
```

`Core.lua` construye un `snapshot` por unidad una vez por pase (`BuildSnapshot`, dentro de `ApplyToUnit`) y lo pasa tanto a `Decision.ShouldSimplifyUnit` como a `Core.UpdateModules` → cada módulo visual registrado. Esto sustituye al patrón anterior donde `Decision` y `HealthBarColor` recalculaban `Classification.GetEliteType`/`Absorb.HasAbsorb` cada uno por su cuenta.

`Minimizer.Core.RegisterModule(name, module)` es el único punto de entrada para que un
módulo visual (`HealthBarColor`, `CastingBar`) se enganche al ciclo de vida de las
nameplates. Un módulo registrado debe exponer opcionalmente:
- `module:UpdateNamePlate(unit, nameplate, snapshot)` — llamado desde `Core.UpdateModules` en cada
  pase de `ApplyToUnit`.
- `module:OnNamePlateRemoved(unit, nameplate)` — llamado desde `Core.ClearNeverSimplify`.

Esto separa la lógica de decisión (Core, Threat, Cast, Absorb, Classification, Decision) de la lógica de presentación (HealthBarColor, CastingBar, Focus, Target), manteniendo el flujo desacoplado y de alto rendimiento.

---

## 1. APIs verificadas en producción (confirmadas contra Platynator)

Estas son las llamadas que **ya están probadas en cliente real** y coinciden con lo
documentado originalmente sobre Platynator. Se puede confiar en ellas tal cual durante
el refactor.

### 1.1 Simplificación de nameplate
```lua
C_NamePlateManager.SetNamePlateSimplified(unitToken, bool)
```
- Verificado en `Core.lua`, `Minimizer.Core.ApplyToUnit`.
- Se llama **solo cuando cambia el estado** (`nameplate.MinimizerState ~= shouldSimplify`),
  o cuando se solicita un `forceUpdate` explícito.
- Disponibilidad comprobada primero con `Minimizer.Utils.IsSimplifiedAvailable()`
  (`C_NamePlateManager and type(...) == "function"`). Nunca se llama sin este guard.

### 1.2 Resolución de nameplate por unit token
```lua
Minimizer.Utils.GetNamePlateForUnit(unit)
```
- Camino rápido: si `unit` ya hace match con `^nameplate%d+$`, llama directo a
  `C_NamePlate.GetNamePlateForUnit(unit)`.
- Camino lento (para `target`, `focus`, `bossN`, etc.): itera
  `C_NamePlate.GetNamePlates()` y compara con `UnitIsUnit(token, unit)`.

### 1.3 Hooks seguros del ciclo de vida de nameplates
```lua
hooksecurefunc(NamePlateDriverFrame, "OnNamePlateAdded", function(_, unit) ... end)
hooksecurefunc(NamePlateDriverFrame, "OnNamePlateRemoved", function(_, unit) ... end)
```
- Verificado en `Events.lua`. Es el patrón canónico documentado: nunca se llama
  a `OnNamePlateAdded`/`Removed` directamente, solo se "escucha" con `hooksecurefunc`.
- Mismo patrón aplicado a re-coloreo nativo:
  ```lua
  hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(unitFrame) ... end)
  hooksecurefunc(castBar, "SetStatusBarColor", function() ... end)   -- CastingBar.lua
  hooksecurefunc(healthBar, "SetStatusBarColor", function() ... end) -- HealthBarColor.lua
  ```
  Blizzard repinta las barras después de sus propios eventos; en vez de pelear por el
  orden de ejecución, el addon deja que Blizzard pinte primero y **reaplica su color
  encima via hook**.

### 1.4 Guardas de reentrancia en hooks de auto-repintado
```lua
Minimizer.Utils.GuardedCall(castBar, "MinimizerApplyingColor", function()
    castBar:SetStatusBarColor(r, g, b, a or 1)
end)
```
```lua
Minimizer.Utils.GuardedCall(healthBar, "MinimizerHealthColorApplying", function()
    healthBar:SetStatusBarColor(r, g, b)
end)
```
- Ambos módulos usan el helper `GuardedCall` para que su propio hook de `SetStatusBarColor`
  no se dispare a sí mismo en bucle infinito.

### 1.5 Lectura de estado de cast sin coerción de secretos
```lua
local castName, _, _, _, _, _, _, castUninterruptible = UnitCastingInfo(unit)
local channelName, _, _, _, _, _, channelUninterruptible = UnitChannelInfo(unit)
```
- Verificado en `Cast.lua` → `ReadCastState`. Índice `[8]` para cast, `[7]` para channel.
- Se usa `if/elseif` explícito en vez de `and/or` para evitar coerción de secretos.
- Devuelve `isCasting, uninterruptible, rawUninterruptible, isChanneling`.

### 1.6 Cache de estado de cast (memoización de un solo unit)
```lua
local cachedCastUnit, cachedIsCasting, cachedUninterruptible, cachedRawUninterruptible, cachedIsChanneling
local cachedCastValid = false
function Minimizer.Cast.GetState(unit) ... end
function Minimizer.Cast.InvalidateState(unit) ... end
```
- Cache de una sola entrada invalidada por evento de cast.

### 1.7 `SetAlphaFromBoolean` para aceptar valores secretos directamente
```lua
if visuals.targetContainer.SetAlphaFromBoolean then
    visuals.targetContainer:SetAlphaFromBoolean(targeted)
end
```

### 1.8 Firma real de `EvaluateColorValueFromBoolean` (resuelta empíricamente)
```lua
C_CurveUtil.EvaluateColorValueFromBoolean(state, valueIfTrue:number, valueIfFalse:number) -> number
```
- Encapsulado en `Minimizer.Utils.EvaluateColorRGB(state, colorTrue, colorFalse)` canal por canal:
  ```lua
  return C_CurveUtil.EvaluateColorValueFromBoolean(state, colorTrue[1], colorFalse[1]),
         C_CurveUtil.EvaluateColorValueFromBoolean(state, colorTrue[2], colorFalse[2]),
         C_CurveUtil.EvaluateColorValueFromBoolean(state, colorTrue[3], colorFalse[3])
  ```

### 1.9 Amenaza (threat) sin coerción de secretos
```lua
local situation = UnitThreatSituation(source, unit)
if Minimizer.Utils.IsSecretValue(situation) then return nil end
if type(situation) ~= "number" then return nil end
```

### 1.10 Absorb: depender EXCLUSIVAMENTE del indicador visual (`IsShown()`)
```lua
local indicator = healthBar and (healthBar.totalAbsorbOverlay or healthBar.totalAbsorb)
return indicator and indicator.IsShown and indicator:IsShown() == true or false
```

---

## 2. Discrepancias entre la guía original (Platynator) y la implementación real

1. **`GetNamePlateForUnit` sin `issecure()`.** La guía decía
   `C_NamePlate.GetNamePlateForUnit(unit, issecure())`. El código real omite el segundo
   argumento siempre. Funciona en las pruebas actuales.
2. **No hay `C_NamePlateManager.SetNamePlateHitTestInsets`.** Es una feature no implementada actualmente.
3. **`Minimizer.Cast` es un motor propio, no una copia del cache de Platynator.**
   Minimizer no implementa persistencia de cast interrumpido con timeout porque el cliente de Blizzard gestiona sus propios visuales de corte nativos.
4. **`importantCast` se descartó.** Tras pruebas se determinó que el visual nativo de Blizzard es suficiente.

---

## 3. Estado post-refactor (snapshot + eventos unificados)

### 3.1 Patrón de snapshot (nuevo)
`Core.BuildSnapshot(unit, nameplate)` centraliza el cálculo de: `eliteType`,
`hasAbsorb`, `hasAggro`, `isCasting`, `isUninterruptible`, `rawUninterruptible`, `isChanneling`, y `displayKind`
(prioridad focus > aggro > absorb > eliteType). Se calcula UNA vez por
`ApplyToUnit`, SIEMPRE (incluso con el fast-path de
`MinimizerDesimplifiedPersistent` activo, porque los módulos visuales lo
necesitan igual). Vive en un table de scratch reutilizado a nivel de módulo
(`scratchSnapshot` en Core.lua) — no crear un table nuevo por nameplate por
frame, y nunca guardar una referencia a `snapshot` más allá de la llamada
síncrona a `ApplyToUnit`.

### 3.2 GetCastBar (duck-typing) — pendiente de encapsular
`CastingBar:GetCastBar` sigue usando duck-typing (`type(cached.SetStatusBarColor) == "function"`)
para validar el cache. No se ha tocado en este refactor. Queda pendiente
para un pase futuro si se decide dar a esto una interfaz más formal.

### 3.3 Cache de interrupción (nuevo)
`Interrupt.IsReady()` ya NO llama a ninguna API de Blizzard directamente —
lee un valor cacheado (`cachedReady`) que se refresca explícitamente con
`Interrupt.RefreshReadyCache()`, llamado UNA vez por pase desde
`Core.ApplyToAll` y también desde el handler de `SPELL_UPDATE_COOLDOWN` en
Events.lua. Esto eliminó ~100 llamadas/frame a `C_Spell.GetSpellCooldownDuration`
que antes ocurrían una vez por nameplate.

### 3.4 Events.lua: dispatch table
La cadena `if/elseif` de 15+ ramas se convirtió en una tabla `handlers[event] = fn`.
Target.lua y Focus.lua ya NO tienen su propio CreateFrame/RegisterEvent —
se registran en el EventFrame único de Events.lua. Reglas preservadas:
- `NAME_PLATE_UNIT_REMOVED` ahora SÍ está registrado globalmente (antes solo
  lo escuchaban los drivers propios de Target/Focus).
- `SPELL_UPDATE_COOLDOWN` dispara 3 cosas independientes: refresco del cache
  de interrupt, el filtro de "solo refrescar nameplates si ready cambió"
  (sin tocar), y el refresco de Target/Focus (que NO respeta ese filtro,
  siempre se refrescan vía su propio debounce).
- Target SÍ filtra por unidad en `NAME_PLATE_UNIT_ADDED`/`REMOVED`
  (`UnitIsUnit(unit, "target")`); Focus NO filtra (comportamiento heredado,
  intencional).

---

## 4. Checklist canónico de taint / secrets (consolidado y verificado)

1. **Nunca evaluar un valor potencialmente secreto con `and/or`, `not`, `==`, `>` etc.** directamente en Lua. Comprobar primero con `issecretvalue(value)` (envuelto en `Minimizer.Utils.IsSecretValue`).
2. **Si el valor es secreto, no lo conviertas a booleano.** Propágalo crudo hacia una API C-side (`SetAlphaFromBoolean`, `EvaluateColorValueFromBoolean`).
3. **Cuando no exista una API C-side para el dato secreto**, busca si Blizzard ya expone la misma información en un widget nativo (`indicator:IsShown()`).
4. **`EvaluateColorValueFromBoolean` es escalar**, respetando el orden `(state, valueIfTrue, valueIfFalse)`.
5. **Nunca llamar directamente a `NamePlateDriverFrame:OnNamePlateAdded/Removed`.** Solo escuchar con `hooksecurefunc`.
6. **Proteger hooks con guardas de reentrancia** (`Minimizer.Utils.GuardedCall`).
7. **Solo simplificar/tocar nameplates a través de `C_NamePlateManager.SetNamePlateSimplified`**.
8. **Aplicar `SetNamePlateSimplified` solo cuando el estado deseado cambia**.
9. **Todas las lecturas de threat situation deben verificar `issecretvalue` y `type(x) == "number"` antes de comparar contra `3`**.
10. **Todo dato derivado de eventos debe invalidarse explícitamente por evento**.

---

## 5. Qué llevarse (y qué no) a la nueva arquitectura

**Llevarse tal cual (probado, canónico):**
- El patrón `Core.RegisterModule` + `UpdateNamePlate`/`OnNamePlateRemoved`.
- `BuildSnapshot` + propagación a módulos.
- `ReadCastState` con retorno cuádruple (`isCasting, uninterruptible, rawUninterruptible, isChanneling`).
- `Interrupt.RefreshReadyCache` por pase en lugar de por nameplate.
- El patrón de reentrancia con `GuardedCall`.
- El fallback de absorb a indicador visual `indicator:IsShown()`.
- La comparación `situation == 3` para aggro sólido.

---

## 6. Known Issues & Sincronización

### 6.1 Minimizar fuera de combate (EN PROGRESO)
A día de hoy, TODAS las features del addon funcionan correctamente EXCEPTO
la simplificación de nameplates fuera de combate, que tiene fallos
conocidos y está en desarrollo activo. El resto del código (Decision,
Classification, Threat, Absorb, Cast, HealthBarColor, CastingBar, Markers,
Target, Focus) se considera correcto y estable. No usar esta sección como
excusa para "arreglar" código fuera-de-combate sin contexto adicional —
hablar primero con el desarrollador principal.

### 6.2 Sincronización de estado con la Interfaz Nativa (Target, Focus y Combate)
1. **El Target y el Focus están forzados a maximizarse por Blizzard**. `Minimizer.Decision.ShouldSimplifyUnit` devuelve `false, "target"` y `false, "focus"` explícitamente para alienar su respuesta con lo que Blizzard impone a la fuerza.
2. **Las unidades fuera de combate** se evaluaban a `true` al aparecer, Minimizer las simplificaba en `NAME_PLATE_UNIT_ADDED`, pero Blizzard las repintaba maximizadas al final de ese mismo frame de inicialización. `Minimizer.Core.ApplyToUnit` acepta un parámetro `forceUpdate` enviado a `true` mediante el `RequestApplyToAll` retardado (`UpdateNameplates`) que se dispara justo después de `NAME_PLATE_UNIT_ADDED`.

---

## 7. Baseline de Performance (referencia para detectar regresiones)

### Pre-refactor (2026-08-14)
- Avg/Frame: 1.748000 ms (ApplyToAll)
- HealthBarColor: 40.66% del tiempo total (0.7120 s)
- CastingBar: 15.93% (0.2790 s)
- Markers: 11.02% (0.1930 s)
- ~32% restante no instrumentado en esta versión del benchmark (Decision/Classification/Threat/Absorb no tenían profiling propio).

### Post-refactor (2026-08-15)
- Avg/Frame: 1.935000 ms (con profiling extra activo de GetEliteType, HasAbsorb, ShouldSimplifyUnit, PlayerHasAggro)
- HealthBarColor: 16.43% del tiempo total (0.3180 s) -> **Mejora de más del 55% en HealthBarColor gracias al snapshot**
- CastingBar: 14.06% (0.2720 s)
- Markers: 9.72% (0.1880 s)
- Desglose no-módulo instrumentado:
  - GetEliteType: 8.99% (0.1740 s)
  - HasAbsorb: 7.44% (0.1440 s)
  - ShouldSimplifyUnit: 4.34% (0.0840 s)
  - PlayerHasAggro: 2.89% (0.0560 s)

### Throttle check Target/Focus (implementado a 30 FPS / 0.033s)
- **Implementación**: `Minimizer.Utils.Throttle(fn, 0.033)` en `Target.lua` y `Focus.lua`.
- **Resultado del benchmark**: Ante 100 eventos `SPELL_UPDATE_COOLDOWN` simulados en ~1 segundo, las llamadas reales se reducen de 100 a **25 llamadas** (~25-30 FPS cap).
- Se eliminó el 75% de los repintados redundantes sin perder fluidez visual ni respuesta inmediata al primer evento.