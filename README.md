# Minimizer

> Simplifica nameplates enemigas usando las APIs nativas de Blizzard (`C_NamePlateManager`), con lógica adicional de color, marcadores de target/focus y widgets de cooldown, todo diseñado para sobrevivir a los "secretos" (Secrets/Midnight) sin taintear la UI.

Este documento es la **referencia técnica canónica** del addon: arquitectura, APIs de WoW verificadas contra cliente real, patrones seguros de manejo de taint/secrets, y el estado actual de cada feature. Todo lo que hay aquí está verificado línea por línea contra el código fuente que compila y corre en cliente — no es una guía teórica ni copia de ningún otro addon.

**Objetivo:** que cualquiera que toque este código pueda buscar "¿cómo resolvemos X?" y encontrar la respuesta ya verificada, en vez de tener que releer todos los `.lua` o arriesgarse a re-descubrir a base de crashes por qué comparar un secreto revienta el cliente.

**Fuera de alcance:** panel de opciones/localización propios — el producto final que consume este addon ya tiene su propio menú, implementar uno aquí duplicaría trabajo. `Menu.lua` existe solo como fallback de desarrollo/debug vía `/simp menu`.

**Estado del proyecto:** todas las features funcionales están implementadas y estables (ver [§8](#8-known-issues)). Lo único pendiente es benchmarking continuo y optimización de procesos que se disparan más veces de las necesarias / generación de basura (ver [§9](#9-optimización-pendiente)).

---

## Índice

1. [SpellData: formato y uso](#1-spelldata-formato-y-uso)
2. [Mapa de módulos](#2-mapa-de-módulos)
3. [APIs de WoW verificadas y cómo las usamos](#3-apis-de-wow-verificadas-y-cómo-las-usamos)
4. [Checklist canónico de taint / secrets](#4-checklist-canónico-de-taint--secrets)
5. [Leyenda de color M+ (prioridades)](#5-leyenda-de-color-m-prioridades)
6. [Historial de fixes (contexto de por qué el código es como es)](#6-historial-de-fixes)
7. [Candidatos futuros — evaluados, no adoptados todavía](#7-candidatos-futuros--evaluados-no-adoptados-todavía)
8. [Known Issues](#8-known-issues)
9. [Optimización pendiente](#9-optimización-pendiente)
10. [Baseline de performance](#10-baseline-de-performance)

---

## 1. SpellData: formato y uso

Minimizer centraliza las listas de spells usadas por widgets en `data/SpellData.lua`. El archivo admite dos formatos de entrada en cada lista:

- Entrada legacy (número): `12345` — sigue funcionando tal cual.
- Entrada enriquecida (recomendada): `{ id = 12345, name = "Avatar" }`.

Reglas:

- El campo `name` (cuando está presente) es el que se muestra en los dropdowns del menú (`Menu.lua`).
- El orden de las entradas en cada tabla es significativo: `Minimizer.Utils.FindKnownSpell` elige el **primer** `spellID` conocido por el jugador en ese orden.
- En cliente real, preferir `name = GetSpellInfo(id)` (o validar que esté localizado) para compatibilidad multi-idioma.
- `Minimizer.Utils.FindKnownSpell` y `Minimizer.Widgets.GetCDSpellID` aceptan ambos formatos y siempre devuelven el `spellID` numérico.

Para añadir/corregir spells por clase, editar `data/SpellData.lua` respetando el orden. Ver `Docs/debt.md` para el procedimiento recomendado al completar spells faltantes.

---

## 2. Mapa de módulos

Orden de carga tal como aparece en `Minimizer.toc`:

```
Bootstrap.lua       Minimizer (inicialización global, ADDON_LOADED)
Utils.lua           Minimizer.Utils (helpers puros, guardas de secretos, debounce/throttle, tokens)
Widgets.lua         Minimizer.Widgets (búsqueda de castbars, halos, pips, cooldowns)
HitTest.lua         Minimizer.HitTest (sincroniza hit-test con la healthBar real y reintenta si Blizzard aún no permite mutar el click region)
Config.lua          Minimizer.Config (SavedVariables MinimizerDB, defaults, migraciones)
Constants.lua       Minimizer.Constants (paletas de color de salud/cast/pips)
data/SpellData.lua  Minimizer.Data (spellIDs por clase: interrupts, CDs of./def., CC masivo)
Cache.lua           Minimizer.Cache (cache genérico unit -> {kind -> valor}, invalidado por generación)
Threat.lua          Minimizer.Threat (aggro/tanque, sincronización de tokens de grupo/raid)
Absorb.lua          Minimizer.Absorb (detección de absorción vía indicator:IsShown())
Cast.lua            Minimizer.Cast (lectura SIN cache de casts/canalizaciones, ver §3.5)
Classification.lua  Minimizer.Classification (boss/miniboss/caster/melee/trivial)
Decision.lua        Minimizer.Decision (motor ShouldSimplifyUnit)
Interrupt.lua        Minimizer.Interrupt (spellID de interrupción + cache de "listo" a nivel de pase)
Core.lua            Minimizer.Core (orquestación, snapshot, ciclo de vida, RegisterModule)
Markers.lua         Minimizer.Markers (flechas de target/focus)
HealthBarColor.lua  módulo registrado: coloreo de healthbars nativas
CastingBar.lua      módulo registrado: coloreo de castbars nativas, visuales de "me está casteando"
Focus.lua           Minimizer.Focus (retrato de focus, CD de interrupt, pip de CC masivo)
Target.lua          Minimizer.Target (halo de CD ofensivo + pip de CD defensivo sobre el target)
Menu.lua            Minimizer.Menu (frame propio, dropdowns/checkboxes; uso interno/dev)
Events.lua          Minimizer (EventFrame centralizado, tabla de dispatch)
SlashCommands.lua   Minimizer (/simp)
```

`Core.lua` construye un `snapshot` por unidad **una vez por pase** (`BuildSnapshot`, dentro de `ApplyToUnit`) y lo pasa tanto a `Decision.ShouldSimplifyUnit` como a `Core.UpdateModules` → cada módulo visual registrado. Esto evita que `Decision` y `HealthBarColor` recalculen `Classification.GetEliteType` / `Absorb.HasAbsorb` cada uno por su cuenta.

`Target.lua` y `Focus.lua` usan dos familias visuales intencionalmente distintas: el halo/donut del target y los pips circulares pequeños de cooldown, más el retrato del focus con color de estado listo/CD. No se mezcla "anillo" con "círculo" porque el hueco central del halo es parte del framing visual del retrato del focus en pulls grandes.

`Minimizer.Core.RegisterModule(name, module)` es el único punto de entrada para que un módulo visual se enganche al ciclo de vida de las nameplates. Un módulo registrado puede exponer:

- `module:UpdateNamePlate(unit, nameplate, snapshot)` — llamado desde `Core.UpdateModules` en cada pase de `ApplyToUnit`. `snapshot` puede ser `nil` si el llamador es un hook de repintado nativo fuera del pase normal (ver §3.3); los módulos deben tener fallback.
- `module:OnNamePlateRemoved(unit, nameplate)` — llamado desde `Core.ClearNeverSimplify`.

Esto separa la lógica de **decisión** (Core, Threat, Cast, Absorb, Classification, Decision) de la lógica de **presentación** (HealthBarColor, CastingBar, Focus, Target, Markers).

---

## 3. APIs de WoW verificadas y cómo las usamos

Todas verificadas en cliente real (Interface 120100 / Midnight). Se puede confiar en estos patrones tal cual durante cualquier trabajo futuro.

### 3.1 Simplificación de nameplate

```lua
C_NamePlateManager.SetNamePlateSimplified(unitToken, bool)
```

- Verificado en `Core.lua`, `Minimizer.Core.ApplyToUnit`.
- Se llama **solo cuando cambia el estado deseado** (`nameplate.MinimizerState ~= shouldSimplify`), o cuando se pide `forceUpdate` explícito.
- Disponibilidad comprobada primero con `Minimizer.Utils.IsSimplifiedAvailable()` (`C_NamePlateManager and type(...) == "function"`). **Nunca** se llama sin este guard.

### 3.2 Sincronización del hit-test con la healthbar

```lua
nameplate:SetAllHitTestPoints(healthBar)
nameplate:CanChangeHitTestPoints()
```

- Verificado en `HitTest.lua`, `Minimizer.HitTest.Sync`.
- Se llama justo después de `C_NamePlateManager.SetNamePlateSimplified` para que la región de clic siga a la healthbar visual real del nameplate.
- Blizzard no siempre permite mutar el hit-test inmediatamente tras `NAME_PLATE_UNIT_ADDED`; por eso `Sync` comprueba `CanChangeHitTestPoints()` y reintenta con `C_Timer.After` hasta 6 veces a 0.05s.
- Si la API aún no está disponible, no se fuerza nada: se deja el reintento en cola, no se queda el click region desincronizado con la barra visible.

### 3.3 Resolución de nameplate por unit token

```lua
Minimizer.Utils.GetNamePlateForUnit(unit)
```

- Camino rápido: si `unit` hace match con `^nameplate%d+$`, llama directo a `C_NamePlate.GetNamePlateForUnit(unit)`.
- Camino lento (para `target`, `focus`, `bossN`, etc.): itera `C_NamePlate.GetNamePlates()` (⚠️ aloca una tabla nueva cada vez, ver §9) y compara con `UnitIsUnit(token, unit)`.
- Para `target`/`focus` específicamente, `Target.lua`/`Focus.lua` llaman directo a `C_NamePlate.GetNamePlateForUnit("target"/"focus")` en vez de pasar por este camino lento.

### 3.3b Ciclo de vida de nameplates: eventos + un único hook seguro

```lua
-- Events.lua
EventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
-- ...
hooksecurefunc(NamePlateDriverFrame, "OnNamePlateRemoved", function(_, unit)
    if not unit or not unit:match("^nameplate%d+$") then return end
    Minimizer.Core.ClearNeverSimplify(unit)
end)
```

- **`OnNamePlateAdded` NO se hookea.** Toda la lógica de llegada (incremento de generación + `Core.ApplyToUnit`) vive en el handler del evento `NAME_PLATE_UNIT_ADDED`, para evitar doble incremento del mismo spawn en el mismo frame si además se hookeara `OnNamePlateAdded`.
- `OnNamePlateRemoved` sí necesita hook propio (`hooksecurefunc`) porque no existe un evento equivalente y fiable de "acaba de desaparecer" para esa limpieza específica.
- Mismo patrón de "escuchar sin interceptar" aplicado al re-coloreo nativo:
  ```lua
  hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(unitFrame) ... end)
  hooksecurefunc(castBar, "SetStatusBarColor", function() ... end)   -- CastingBar.lua
  hooksecurefunc(healthBar, "SetStatusBarColor", function() ... end) -- HealthBarColor.lua
  ```
  Blizzard repinta las barras después de sus propios eventos; en vez de pelear por el orden de ejecución, dejamos que Blizzard pinte primero y **reaplicamos color encima vía hook**.
- Regla general: **nunca llamar directamente** a `NamePlateDriverFrame:OnNamePlateAdded/Removed`. Solo se escucha con `hooksecurefunc` o eventos.

### 3.4 Guardas de reentrancia en hooks de auto-repintado

```lua
Minimizer.Utils.GuardedCall(obj, flagName, fn)
```

```lua
Minimizer.Utils.GuardedCall(castBar, "MinimizerApplyingColor", function()
    castBar:SetStatusBarColor(r, g, b, a or 1)
end)
```

- `GuardedCall` pone un flag en el objeto antes de ejecutar `fn` (con `pcall`) y lo limpia después. El propio hook de `SetStatusBarColor` comprueba ese flag y no hace nada si ya estamos "dentro" de nuestra propia llamada — evita bucle infinito de auto-disparo.
- Errores dentro de `fn` se loguean vía `print` con throttle de 10s por `flagName` (`Minimizer.Utils.LogGuardedError`) para no inundar el chat si algo falla en cada frame.
- Usado por `CastingBar.lua` y `HealthBarColor.lua`.

### 3.5 Lectura de estado de cast/channel — SIN CACHE, siempre fresco

```lua
local castName, _, _, _, _, _, _, castUninterruptible = UnitCastingInfo(unit)
local channelName, _, _, _, _, _, channelUninterruptible = UnitChannelInfo(unit)
```

- Verificado en `Cast.lua` → `ReadCastState`. Índice `[8]` para cast, `[7]` para channel.
- Se usa `if/elseif` explícito en vez de `and/or` para evitar coerción de secretos.
- Devuelve `isCasting, uninterruptible, rawUninterruptible, isChanneling`.

**Importante — decisión de diseño deliberada:** `Minimizer.Cast` **no cachea nada**. `Minimizer.Cast.InvalidateState(unit)` es un **no-op** que se mantiene únicamente porque `Core.lua`/`Events.lua` la siguen llamando en varios sitios (mantener la API estable evita tocar N call-sites).

Hubo una versión anterior con un slot único (escalar, no tabla por unidad) que dependía de que `InvalidateState()` se disparase *siempre* antes de que un token de nameplate reciclado (ej. `"nameplate3"` pasando de un mob muerto a uno nuevo) fuera vuelto a leer. Esa invalidación vivía en un hook distinto (`NamePlateDriverFrame.OnNamePlateRemoved`) del que lee el estado nuevo (`NAME_PLATE_UNIT_ADDED` / hooks de `SetStatusBarColor`), sin garantía dura de orden entre ambos. Si esa carrera se perdía una sola vez, una unidad podía heredar el `rawUninterruptible` de la unidad **anterior** que ocupó el mismo token — dos mobs con estados reales opuestos mostrando el mismo color.

`UnitCastingInfo`/`UnitChannelInfo` son baratas: no vale la pena el riesgo por un cache que en la práctica casi nunca se reutilizaba (`BuildSnapshot` solo llama una vez por unidad por pase; las llamadas fuera de pase vienen de hooks de Blizzard repintando barras, casi siempre para unidades distintas de todos modos). Leer siempre fresco elimina la clase de bug entera, no solo el síntoma. **No reintroducir un cache aquí sin resolver primero la garantía de orden entre invalidación y lectura.**

### 3.6 Resolver un valor potencialmente secreto sin compararlo en Lua

```lua
Minimizer.Utils.EvaluateColorRGB(state, colorTrue, colorFalse)
Minimizer.Utils.EvaluateBoolean(state, ifTrue, ifFalse)
```

Ambas encapsulan:

```lua
C_CurveUtil.EvaluateColorValueFromBoolean(state, valueIfTrue:number, valueIfFalse:number) -> number
```

- `EvaluateColorRGB` la llama 3 veces (canal por canal) para resolver un color completo:
  ```lua
  return C_CurveUtil.EvaluateColorValueFromBoolean(state, colorTrue[1], colorFalse[1]),
         C_CurveUtil.EvaluateColorValueFromBoolean(state, colorTrue[2], colorFalse[2]),
         C_CurveUtil.EvaluateColorValueFromBoolean(state, colorTrue[3], colorFalse[3])
  ```
- Ambas funciones tienen fallback si `C_CurveUtil` no existe (clientes viejos): usan `Minimizer.Utils.IsSecretValue` para decidir con seguridad sin comparar el secreto directamente.
- Patrón de uso — decidir color de cast/channel sin taint:
  ```lua
  local r, g, b = Minimizer.Utils.EvaluateColorRGB(rawUninterruptible, COLORS.superiorUninterruptible, COLORS.castInterruptible)
  ```
- **Nunca usar** `if rawUninterruptible then ... end` ni `if rawUninterruptible == true then ... end` — ambos pueden taintear la UI.

### 3.7 `SetAlphaFromBoolean` — aceptar un secreto directamente en un sink C-side

```lua
if visuals.targetContainer.SetAlphaFromBoolean then
    visuals.targetContainer:SetAlphaFromBoolean(targeted)
end
```

- Verificado y en uso en `CastingBar.lua` para el borde pulsante de "este cast me apunta a mí" (`IsSpellTargetingPlayer`, que puede devolver un booleano secreto vía `UnitIsSpellTarget`). Se pasa el valor tal cual al sink; nunca se compara antes.

### 3.8 `ApplyReadyShade` — shade de portrait vía sink escalar (patrón actual)

```lua
Minimizer.Utils.ApplyReadyShade(texture, ready)
```

- Usado por `Focus.lua` para oscurecer el retrato del focus cuando el interrupt está en cooldown.
- Implementación actual: **un único `EvaluateColorValueFromBoolean`** que resuelve un `shade` escalar (1.0 si listo, 0.38 si no) y lo aplica a los 3 canales de `SetVertexColor` a la vez. No usa 3 llamadas por canal porque los 3 canales comparten el mismo valor (blanco/gris, no un color con tonalidad).
- Ver [§7](#7-candidatos-futuros--evaluados-no-adoptados-todavía) para una API alternativa (`SetVertexColorFromBoolean`) evaluada pero **no adoptada** todavía.

### 3.9 Amenaza (threat) sin coerción de secretos

```lua
local situation = UnitThreatSituation(source, unit)
if Minimizer.Utils.IsSecretValue(situation) then return nil end
if type(situation) ~= "number" then return nil end
```

- Verificado en `Threat.lua` → `GetSituation`. Solo después de este doble guard se compara `situation == 3` (aggro sólido) o `situation < 3`.
- `Threat.PlayerHasAggro` tiene rama especial para tanks (usa `ShouldUnsimplify`/`GetTankSituation`, que iteran los tokens de tank de grupo/raid vía `Threat.tankTokens`, refrescados en `RefreshTankTokens`). **No es la misma función** que `ShouldUnsimplify` — no sustituir una por otra sin revisar `Threat.lua`.

### 3.10 Absorb: depender EXCLUSIVAMENTE del indicador visual

```lua
local indicator = healthBar and (healthBar.totalAbsorbOverlay or healthBar.totalAbsorb)
return indicator and indicator.IsShown and indicator:IsShown() == true or false
```

- Verificado en `Absorb.lua`. No se calcula el valor numérico del absorb (`UnitGetTotalAbsorbs`) porque el indicador visual nativo ya resume correctamente si hay absorb visible o no, sin arriesgarse a leer un número que podría venir secreto.

### 3.11 Cache genérico invalidado por generación de plate

```lua
Minimizer.Cache.GetUnitKeyWithGeneration(unit, key)
Minimizer.Cache.SetUnitKeyWithGeneration(unit, key, value)
```

- Usado por `Classification.GetEliteType` (`"eliteType"`) y `Threat.GetSituation` (`"threat:" .. source`).
- Cada entrada se guarda junto a `Minimizer.Core.GetPlateGeneration(unit)` (contador monotónico por token, incrementado en `Core.IncrementPlateGeneration` cuando una unidad **llega** a un token vía `NAME_PLATE_UNIT_ADDED`). Al leer, si `entry.gen ~= generación actual`, se trata como cache-miss.
- Esto es la defensa contra el mismo problema de fondo que motivó quitar el cache de `Cast.lua` (§3.5): **reciclaje de tokens de nameplate**. La diferencia es que aquí sí compensa cachear (clasificación y threat son más caras de recalcular y no dependen de un orden de invalidación externo tan frágil), así que se mantiene el cache pero atado a un contador de generación explícito en vez de a un hook de invalidación separado.
- `SetUnitKeyWithGeneration` reutiliza la entry existente (`entry.value = ...; entry.gen = ...`) en vez de crear una tabla nueva en cada escritura, porque esta función se llama por unidad/clave/pase.

### 3.12 Cache de interrupción "listo" — refrescado una vez por pase, no por nameplate

```lua
Minimizer.Interrupt.RefreshReadyCache()  -- llamado en Core.ApplyToAll y en SPELL_UPDATE_COOLDOWN
Minimizer.Interrupt.IsReady()            -- solo LEE el cache, nunca llama a C_Spell
```

- Elimina ~100 llamadas/frame a `C_Spell.GetSpellCooldownDuration` que antes ocurrían una vez por nameplate.
- `Interrupt.GetSpellID()` tiene su propio cache (`cachedSpellIDResolved`), invalidado explícitamente en `PLAYER_TALENT_UPDATE` / `PLAYER_SPECIALIZATION_CHANGED` (ver `Events.lua` → `HandleRosterOrSpecChange`).

### 3.13 Otros cachés con la misma filosofía ("recalcular es más caro que cachear con invalidación explícita")

- `Widgets.cdSpellCache` — cache fuerte por clave `dbTable:override` para `GetCDSpellID`. Invalidado manualmente vía `Minimizer.Widgets.InvalidateCDSpellCache()` en cambio de talento/spec.
- `CastingBar:GetCastBar` — cachea el widget de castbar encontrado por duck-typing (`nameplate.MinimizerCastBar`), validado en cada lectura con `type(cached.SetStatusBarColor) == "function" and type(cached.GetValue) == "function"` antes de confiar en él. Ver §7 para el estado de esto.

---

## 4. Checklist canónico de taint / secrets

1. **Nunca evaluar un valor potencialmente secreto con `and/or`, `not`, `==`, `>`, etc.** directamente en Lua. Comprobar primero con `issecretvalue(value)` (envuelto en `Minimizer.Utils.IsSecretValue`).
2. **Si el valor es secreto, no lo conviertas a booleano.** Propágalo crudo hacia una API C-side (`SetAlphaFromBoolean`, `EvaluateColorValueFromBoolean`, etc.).
3. **Cuando no exista una API C-side para el dato secreto**, comprobar si Blizzard ya expone la misma información en un widget nativo (`indicator:IsShown()`).
4. `EvaluateColorValueFromBoolean` es **escalar**: respeta el orden `(state, valueIfTrue, valueIfFalse)`.
5. **Nunca llamar directamente** a `NamePlateDriverFrame:OnNamePlateAdded/Removed`. Solo escuchar con `hooksecurefunc` o eventos.
6. **Proteger hooks de auto-repintado con guardas de reentrancia** (`Minimizer.Utils.GuardedCall`).
7. **Solo simplificar/tocar nameplates a través de** `C_NamePlateManager.SetNamePlateSimplified`, con guard de disponibilidad.
8. **Aplicar `SetNamePlateSimplified` solo cuando el estado deseado cambia** (o hay `forceUpdate` explícito).
9. **Toda lectura de threat situation debe verificar `issecretvalue` y `type(x) == "number"`** antes de comparar contra `3`.
10. **Todo dato cacheado debe invalidarse explícitamente** — por evento (`Cast` ya no cachea nada, ver §3.5) o por contador de generación de plate (`Cache.lua`, ver §3.11). No confiar en "probablemente se invalida a tiempo".
11. **No resolver un secreto con `EvaluateBoolean(x,1,0)==1` para luego compararlo.** El resultado de un sink C-side sigue tainted; compararlo revienta el cliente con `attempt to compare (secret number value) tainted`. Los sinks son de un solo sentido, hacia la API C-side final (`SetStatusBarColor`, `SetVertexColor`, `SetAlpha`), no hacia más lógica en Lua.

---

## 5. Leyenda de color M+ (prioridades)

Prioridad descendente — la primera regla que aplica gana:

| Prioridad | Condición | Color | Simplificación |
|-----------|-----------|-------|-----------------|
| 1 | **Focus** | Amarillo | Sin cambio (focus no altera simplificación) |
| 2 | **Aggro** (situación 3) | Rojo gestionado por Blizzard | TEMPORAL (mientras dura) |
| 3 | **Shield/Absorb** visto alguna vez | Rosa (`absorb`), **PERSISTENTE** | **PERSISTENTE** (desimp y color) |
| 4 | **Superior** (boss/miniboss) | Morado, SIEMPRE, cast o no | "no simp" **PERSISTENTE** (los superiores nunca fueron simplificables) |
| 5 | **Inferior** + cast/channel **interrumpible** | Verde, **PERSISTENTE** (color) | **PERSISTENTE** ("no simp") |
| 6 | **Inferior** + cast/channel **ininterrumpible** | Gris, **PERSISTENTE** (color) | **TEMPORAL** (vuelve a poder simplificarse al terminar el cast) |
| 6 | **Azul** + **PERSISTENTE** (color) | **PERSISTENTE** (los azules nunca fueron simplificables) |

Definiciones:

- **Superior**: `boss` o `miniboss` (morado). Determinado por nivel skull / worldboss / elite + 2 niveles (`Classification.lua` → `GetSuperiorKind`).
- **Inferior**: cualquier unidad que no sea superior — melee (blanco), caster/hasmana (azul), trivial (negro), esbirros, menores.
- **Los azules (caster/hasmana) NO siguen las reglas de cast** — solo cambian de color por aggro, focus o shield. Esto es intencional (ver rationale abajo).
- **Persistente**: el flag/color permanece incluso después de que termine el cast o el escudo.
- **Temporal**: el flag/color desaparece en cuanto desaparece la condición.

**Rationale M+:** en Mythic+, cualquier inferior que castee algo interrumpible ES wipe potencial si no se para. El verde persistente le dice al grupo que esa unidad ya demostró capacidad de castear y hay que priorizarla incluso después del cast actual. El gris (ininterrumpible) es peligroso pero no interrumpible — no hace falta mantenerlo desimplificado una vez termina. Cuando una unidad ya mostró absorb, se considera parte del historial visual de esa plate: tanto el color rosa como la desimplificación quedan persistentes para evitar que el significado del shield se pierda al reciclar la plate o al pasar por un repintado nativo. Los superiores son siempre peligrosos (morado); su color no depende de si su cast es o no interrumpible porque el grupo ya sabe que hay que interrumpirlos si pueden.

Implementado en `HealthBarColor.lua` (barra de vida) y `CastingBar.lua` (misma leyenda para la castbar: verde si interrumpible + corte listo, rosa si interrumpible + corte en CD, sin tocar si ininterrumpible porque Blizzard ya pinta gris por defecto ahí).

---

## 6. Historial de fixes

Esta sección explica **por qué** el código actual toma las decisiones que toma. No es documentación de trabajo pendiente — todo lo descrito como "fix real / vigente" está aplicado y verificado; las secciones marcadas DEPRECATED son intencionalmente históricas para que nadie reintroduzca el mismo bug sin saber que ya se intentó y falló.

### 6.1 Persistencia de color de cast (v2, vigente)

**Root cause real:** no hay forma soportada de comparar en Lua un valor de interrumpibilidad que llega como secreto, ni directamente ni "resuelto" vía `EvaluateBoolean`/`EvaluateColorRGB` (ambos son sinks de un solo sentido hacia APIs C-side; el resultado sigue tainted). Cualquier intento de decidir un flag booleano (`"kind"`) a partir de ese valor está condenado a fallar de una forma u otra.

**Fix aplicado (`HealthBarColor.lua`):** se dejó de decidir un "kind". En su lugar se persiste directamente el `r,g,b` ya resuelto por `EvaluateColorRGB` (el mismo sink válido que usa `CastingBar.lua` para la castbar nativa) en `nameplate.MinimizerPersistentCastColor`. No hay ninguna comparación sobre `rawUninterruptible` ni sobre nada derivado de él.

**Consecuencia aceptada:** el color gris (cast ininterrumpible) ahora TAMBIÉN persiste visualmente tras terminar el cast — antes debía volver al color base. La **simplificación** no cambia: `Decision.lua` sigue devolviendo `"temporal"` para el caso ininterrumpible, así que el bicho vuelve a ser simplificable en cuanto termina el cast aunque la barra se quede en gris hasta el próximo repintado (nuevo cast, cambio de generación de plate, o `nameplate.MinimizerPersistentCastColor = nil` en `OnNamePlateRemoved`).

**Cambio adicional del mismo parche:** los superiores (`boss`/`miniboss`) dejan de cambiar de color al castear — se mantienen siempre morados; su desimplificación persistente no depende del color.

### 6.2 DEPRECATED — persistencia por "kind" (v1, NO reintroducir)

```lua
-- NO FUNCIONA -- no reintroducir bajo ningun concepto:
if Minimizer.Utils.IsSecretValue(rawUninterruptible) or safeUninterruptible == false then
    nameplate.MinimizerPersistentCastColorKind = "castInterruptible"
end
```

Dos fallos independientes, ambos confirmados en cliente real:

1. Como el valor de interrumpibilidad llega secreto casi siempre en cliente real, `IsSecretValue(raw) or ...` entra casi incondicionalmente — sin mirar si el cast era realmente interrumpible. Un bicho que solo casteaba gris terminaba marcado `"castInterruptible"` y pintado de verde persistente al terminar. Este fue el bug original reportado.
2. Intentar "arreglarlo" resolviendo el secreto explícitamente (`EvaluateBoolean(raw,1,0)==1`) tampoco sirve: el resultado sigue tainted y la comparación revienta el cliente con `attempt to compare (secret number value) tainted`.

### 6.3 DEPRECATED — regla de color para superiores casteando (v1, NO reintroducir)

Antes de v2, un superior casteando algo ininterrumpible se pintaba gris TEMPORAL (volvía a morado al terminar el cast). Se retiró porque forzaba a decidir en Lua si el cast del superior era o no interrumpible — la misma clase de comparación-sobre-secreto que causaba el bug de los inferiores. Dado que un superior siempre desimplifica de forma persistente igualmente (nunca dependió del color para eso), y que ya resulta obvio en pantalla cuando un superior está casteando, se sacrificó el cambio de color a cambio de eliminar esa comparación.

### 6.4 Cast.lua: de "cache con invalidación por hook" a "sin cache" (vigente, ver §3.5)

Cubierto en detalle en §3.5. Resumen: el cache de una sola entrada dependía de un orden de invalidación entre dos hooks distintos que no estaba garantizado; se eliminó por completo en vez de parchear el orden, porque `UnitCastingInfo`/`UnitChannelInfo` son lo bastante baratas.

---

## 7. Candidatos futuros — evaluados, no adoptados todavía

### 7.1 `Region:SetVertexColorFromBoolean(value, colorIfTrue, colorIfFalse)`

API de la Widget API de Midnight, aplicable a `Texture`/`Region` (no a `StatusBar`). A diferencia de `C_CurveUtil.EvaluateColorValueFromBoolean` (escalar, obliga a 3 llamadas por canal), acepta tablas de color completas de una sola vez.

**Estado: NO adoptada.** `Focus.lua`/`Utils.ApplyReadyShade` (§3.8) sigue usando el patrón escalar de 3 llamadas — o, más exactamente, una sola llamada escalar porque el shade del retrato es un gris puro (mismo valor en los 3 canales), así que el ahorro real de adoptar esta API ahí es mínimo. Sería candidata directa si en el futuro el shade del portrait dejara de ser un gris puro y necesitara un color con tonalidad. **No portar a `HealthBarColor.lua`/`CastingBar.lua`**: ahí el consumidor final es `SetStatusBarColor` (no un `Texture`), así que no aplica.

Antes de adoptarla en cualquier `Texture`/`Region` nuevo: validar con `/dump <objeto>:HasSecretValues()` en cliente real que el objeto en cuestión soporta el método, porque no está en la lista de APIs verificadas de §3.

### 7.2 `FrameScriptObject:HasSecretValues()` / `HasAnySecretAspect()` / `HasSecretAspect(aspect)`

Permiten preguntarle a un objeto/frame "¿tienes algo secreto ahora mismo?" sin tocar el valor en sí.

**Estado: NO usada todavía.** Podría servir como guard adicional antes de intentar cualquier lectura de un widget, pero **no sustituye** a `issecretvalue()` para valores sueltos (sirve para objetos/frames completos, no para el `duration`/`uninterruptible` escalares que ya manejamos vía `Minimizer.Utils.IsSecretValue`). Candidata a evaluar si en el futuro se añaden más widgets con estado potencialmente secreto embebido.

### 7.3 `CastingBar:GetCastBar` duck-typing

`CastingBar:GetCastBar` sigue validando el cache con duck-typing (`type(cached.SetStatusBarColor) == "function"`) en vez de una interfaz más formal. No es taint-unsafe ni un bug — es deuda técnica de estilo. Baja prioridad; no tocar sin motivo concreto.

---

## 8. Known Issues

**Minimizar fuera de combate (EN DESARROLLO).** A día de hoy, TODAS las demás features del addon funcionan correctamente. El resto del código (Decision, Classification, Threat, Absorb, Cast, HealthBarColor, CastingBar, Markers, Target, Focus) se considera correcto y estable. No usar esta sección como excusa para "arreglar" código fuera-de-combate sin contexto adicional — hablar primero con el desarrollador principal.

Causa raíz conocida y ya parcheada parcialmente: las unidades fuera de combate se evaluaban a `true` (simplificar) al aparecer, pero Blizzard las repintaba maximizadas al final de ese mismo frame de inicialización. `Minimizer.Core.ApplyToUnit` acepta un parámetro `forceUpdate`, enviado a `true` mediante `RequestApplyToAll` (debounce) disparado justo después de `NAME_PLATE_UNIT_ADDED` — mitiga el problema pero no lo cierra del todo.

**Sincronización con Target/Focus nativos:** el Target y el Focus están forzados a maximizarse por Blizzard. `Minimizer.Decision.ShouldSimplifyUnit` devuelve `false, "target"` / `false, "focus"` explícitamente para alinear la respuesta del addon con lo que Blizzard impone. Esto es intencional, no un bug.

**Nameplates que no aparecen en pulls masivos:** (limitación del motor, NO bug
de Minimizer).** Confirmado en pulls de ~80 unidades: algunas nameplates no
reciben plate del cliente hasta que muere otra unidad y libera un slot del
pool interno de Blizzard. `C_NamePlate.GetNamePlateForUnit` devuelve `nil`
para esas unidades mientras tanto — no hay widget que Minimizer pueda
pintar, sea cual sea su color/estado. En cuanto Blizzard asigna el plate
(`NAME_PLATE_UNIT_ADDED`), `Core.ApplyToUnit` corre de inmediato y pinta
correctamente sin delay perceptible. No existe API de addon para forzar
más plates simultáneas ni para priorizar qué unidad recibe una. No
"arreglar" esto buscando el bug en Absorb/HealthBarColor — no está ahí.

---

## 9. Optimización pendiente

**Nota (2026-08-17):** Desde 2026-08-17, `HealthBarColor` y `CastingBar` también saltan unidades amistosas (no solo PvP). Esto alinea el comportamiento con la política del parche 12.1 de Blizzard, que gestiona nativamente las nameplates amistosas y evita tocar sus barras.

Esta es la única área de trabajo activo en el proyecto aparte de benchmarking continuo. No hay bugs funcionales conocidos fuera de §8.

- **`C_NamePlate.GetNamePlates()` aloca una tabla nueva en cada llamada** (comentario explícito en `Utils.lua`). Se llama en el camino lento de `GetNamePlateForUnit`, en `Core.ApplyToAll`, y en `Events.lua` (`HandleFullRefreshEvent` para limpiar flags persistentes en `PLAYER_REGEN_ENABLED`). Candidato a revisar cuántas de estas llamadas son realmente necesarias por pase vs. cuántas podrían compartir un único snapshot de la lista de plates activas.
- **Llamadas redundantes a módulos cuando Blizzard repinta fuera de nuestro pase normal.** Los hooks de `SetStatusBarColor` en `HealthBarColor.lua`/`CastingBar.lua` llaman `UpdateNamePlate` con `snapshot = nil`, lo que fuerza un fallback que recalcula `ComputeDisplayKind`/`Cast.GetState` fuera del snapshot cacheado del pase. Si Blizzard repinta varias veces por frame, esto puede multiplicar trabajo que el snapshot ya evitaba para el pase normal.
- **Presión de GC en closures de `Throttle`/`Debounce`.** Cada llamada a una función throttled que cae en la rama "pending" crea una closure nueva pasada a `C_Timer.After`. Con ráfagas de `SPELL_UPDATE_COOLDOWN` (ver benchmark §10) esto puede ser una fuente de basura medible; evaluar si vale la pena una versión con menos allocaciones.
- **Benchmark en sí mismo tiene ruido alto** (ver §10 — el `P50/P90` reportado por `os.clock()` en llamadas individuales de microsegundos tiene resolución insuficiente en el entorno de test Lua puro; los números agregados por módulo/función son más fiables que los percentiles por-llamada). Si se decide invertir en tooling de benchmark, mejorar la resolución del reloj o medir en bloques de N llamadas en vez de por llamada individual.
- Antes de optimizar nada de lo anterior: correr `tests/benchmark/benchmark.lua`, guardar el resultado como nuevo baseline, cambiar UNA cosa, volver a correrlo y comparar contra el `REGRESSION_THRESHOLD_MS` (actualmente 2.5ms de p90). No optimizar a ciegas.

---

## 10. Baseline de performance

Correr desde la raíz del proyecto:

```bash
lua tests/benchmark/benchmark.lua
lua tests/smoke_test.lua
```

`benchmark.lua` simula 50 nameplates con churn aleatorio de casts/threat/absorbs a lo largo de 1000 frames, en 6 runs con distinta semilla, y agrega los resultados por mediana. Falla el proceso (`os.exit(1)`) si la mediana de p90 supera `REGRESSION_THRESHOLD_MS = 2.5` ms.

### Última corrida agregada (`tests/results/benchmark_aggregated_20260816_052057.txt`)

- **Resultado:** `median p90 = 0.0000 ms`, `median avgApplyToUnit = 0.062139 ms` — dentro del umbral (2.5 ms) con amplio margen.
- Reparto de coste por módulo (runs con más carga, `run 6` con 23k llamadas acumuladas):
  - `HealthBarColor` ~10.7 µs/call — el módulo más caro, consistente entre runs.
  - `CastingBar` ~10.3 µs/call.
  - `Markers` ~3.1 µs/call — notablemente el más barato de los tres módulos registrados.
- Funciones no-módulo instrumentadas (parte de `Decision.ShouldSimplifyUnit`, invisibles en el desglose de módulos si no se instrumentan aparte): `HasAbsorb`, `PlayerHasAggro`, `GetEliteType`, `ShouldSimplifyUnit` — su coste combinado es comparable al de `HealthBarColor` en los runs más cargados, y crece con el número de llamadas igual que el resto (esperado: no hay caching roto, escala linealmente).
- **Throttle Target/Focus:** ante 100 eventos `SPELL_UPDATE_COOLDOWN` simulados en ~1s, las llamadas reales a `Target:UpdateTargetCDs()`/`Focus:UpdateFace()` se mantienen en **25** en todas las corridas — el throttle a 30 FPS (`Minimizer.Utils.Throttle(fn, 0.033)`) está funcionando como se espera y elimina ~75% de los repintados redundantes.

### Referencia histórica (comparación pre/post-refactor del snapshot)

| | Pre-refactor (2026-08-14) | Post-refactor (2026-08-15) |
|---|---|---|
| Avg/Frame (`ApplyToAll`) | 1.748 ms | 1.935 ms* |
| `HealthBarColor` | 40.66% del tiempo | 16.43% del tiempo (**-55%** aprox.) |
| `CastingBar` | 15.93% | 14.06% |
| `Markers` | 11.02% | 9.72% |

\* El aumento del "post-refactor" se debe a profiling extra activo (`GetEliteType`, `HasAbsorb`, `ShouldSimplifyUnit`, `PlayerHasAggro` instrumentados individualmente), no a una regresión real — la mejora de `HealthBarColor` gracias al snapshot compartido es la cifra que importa de esta comparación.

Ver §9 para las áreas identificadas como candidatas a la próxima ronda de optimización.