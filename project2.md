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

---

## 0. Mapa de módulos (estado actual, orden de carga del .toc)

```
Config.lua      -> Minimizer.Config      (SavedVariables, defaults, migración)
Constants.lua   -> Minimizer.Constants   (tablas de color estáticas)
Cache.lua       -> Minimizer.Cache       (cache genérico unit -> {kind -> valor})
Core.lua        -> Minimizer.Utils, Minimizer.Cache (extendido), Minimizer.Threat,
                    Minimizer.Absorb, Minimizer.Cast, Minimizer.Markers,
                    Minimizer.Core, Minimizer.Bench, eventos, slash command
Interrupt.lua   -> Minimizer.Interrupt   (spellID de interrupción + cooldown)
HealthBarColor.lua -> Minimizer.HealthBarColor (módulo registrado)
CastingBar.lua  -> Minimizer.CastingBar  (módulo registrado)
Focus.lua       -> Minimizer.Focus       (retrato de focus + cooldown de interrupt)
```

**Detalle importante para el refactor:** `Minimizer.Cache` se define en `Cache.lua`
(`Cache.units`, `GetUnitState`, `InvalidateUnit`, `InvalidateAll`) y **se vuelve a abrir
y extender en `Core.lua`** (`Cache.IsUnitCasting`, `Cache.ShouldSimplifyUnit`). No es un
error: es el mismo table compartido (`Minimizer.Cache = Minimizer.Cache or {}` en ambos
archivos, y `Cache.lua` carga antes que `Core.lua` en el `.toc`). Si se reestructura en
módulos separados hay que decidir explícitamente si este patrón de "extender el mismo
namespace desde dos archivos" se mantiene o se separa en `Cache` (estado puro) vs un
motor de decisión aparte (hoy mezclados).

`Minimizer.Core.RegisterModule(name, module)` es el único punto de entrada para que un
módulo visual (`HealthBarColor`, `CastingBar`) se enganche al ciclo de vida de las
nameplates. Un módulo registrado debe exponer opcionalmente:
- `module:UpdateNamePlate(unit, nameplate)` — llamado desde `Core.UpdateModules` en cada
  pase de `ApplyToUnit`.
- `module:OnNamePlateRemoved(unit, nameplate)` — llamado desde `Core.ClearNeverSimplify`.

Esto **sí es un patrón canónico bien resuelto**: separa la lógica de decisión (Core,
Threat, Cast, Absorb) de la lógica de presentación (HealthBarColor, CastingBar, Focus),
igual que Platynator separa `DesignForContext.lua` (decisión) de `Colors.lua`
(presentación). Vale la pena conservarlo en la reestructuración.

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
  nunca en cada tick. Esto es intencional: llamar a esta API en cada frame es el tipo de
  cosa que puede generar overhead/parpadeo y además es innecesario porque la API no es
  idempotente-gratis.
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
- **Desviación respecto a la guía original de Platynator** (ver sección 2.1): la guía
  documentaba la firma `C_NamePlate.GetNamePlateForUnit(unit, issecure())`, pero el
  código real **nunca pasa el segundo argumento**. Funciona hoy, pero no está verificado
  qué pasa en contextos de combate/secure. Marcar como pendiente de verificar (ver
  sección 3).

### 1.3 Hooks seguros del ciclo de vida de nameplates
```lua
hooksecurefunc(NamePlateDriverFrame, "OnNamePlateAdded", function(_, unit) ... end)
hooksecurefunc(NamePlateDriverFrame, "OnNamePlateRemoved", function(_, unit) ... end)
```
- Verificado en `Core.lua`, sección 6. Es el patrón canónico documentado: nunca se llama
  a `OnNamePlateAdded`/`Removed` directamente, solo se "escucha" con `hooksecurefunc`.
  Esto es lo que evita taint por transición addon-controlled — no tocar esto en el
  refactor salvo para añadir más hooks del mismo tipo.
- Mismo patrón aplicado a re-coloreo nativo:
  ```lua
  hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(unitFrame) ... end)
  hooksecurefunc(castBar, "SetStatusBarColor", function() ... end)   -- CastingBar.lua
  hooksecurefunc(healthBar, "SetStatusBarColor", function() ... end) -- HealthBarColor.lua
  ```
  Blizzard repinta las barras después de sus propios eventos; en vez de pelear por el
  orden de ejecución, el addon deja que Blizzard pinte primero y **reaplica su color
  encima via hook**. Es la misma filosofía que "usar hooksecurefunc en vez de llamadas
  directas" de la guía original, pero llevada a un caso que la guía no cubría
  explícitamente (recoloreo competitivo con el cliente). **Documentar esto como patrón
  canónico propio del proyecto**, no viene de Platynator tal cual.

### 1.4 Guardas de reentrancia en hooks de auto-repintado
```lua
castBar.MinimizerApplyingColor = true
castBar:SetStatusBarColor(r, g, b, a)
castBar.MinimizerApplyingColor = nil
```
```lua
healthBar.MinimizerHealthColorApplying = true
healthBar:SetStatusBarColor(r, g, b)
healthBar.MinimizerHealthColorApplying = nil
```
- Ambos módulos usan una flag booleana para que su propio hook de `SetStatusBarColor`
  no se dispare a sí mismo en bucle infinito. **Patrón canónico nuevo, no documentado en
  la guía original — es imprescindible conservarlo** en cualquier módulo futuro que
  haga hook sobre un setter que el propio módulo también llama.

### 1.5 Lectura de estado de cast sin coerción de secretos
```lua
local castName, _, _, _, _, _, _, castUninterruptible = UnitCastingInfo(unit)
local channelName, _, _, _, _, _, channelUninterruptible = UnitChannelInfo(unit)
```
- Verificado en `Core.lua` → `ReadCastState`. Índice `[8]` para cast, `[7]` para channel,
  igual que documentaba la guía original (`castInfo[8]`, `channelInfo[7]`).
- Punto crítico ya resuelto correctamente: **no se usa `and/or` para elegir entre
  `castUninterruptible` y `channelUninterruptible`**, se usa un `if/elseif` explícito.
  El comentario en el código lo explica: un valor secreto sometido a una prueba lógica
  Lua (`and/or`, `not`, comparación) tainted/rompe. Esto es la aplicación correcta del
  principio de la guía original ("no inferir valores secretos por lógica Lua compleja").
- Cuando el valor es secreto (`Minimizer.Utils.IsSecretValue(uninterruptible)`), la
  función devuelve `true, nil, uninterruptible` — es decir, deja `uninterruptible`
  (el segundo valor, para lógica Lua) en `nil` (indeterminado) pero **conserva el valor
  secreto crudo como tercer retorno** para que el consumidor lo use solo con APIs
  C-side (`SetAlphaFromBoolean`, `EvaluateColorValueFromBoolean`). Este patrón de
  "double return: uno seguro para Lua, uno crudo para C-side" es la forma correcta de
  propagar un secreto sin evaluarlo — replicar este patrón en cualquier código nuevo
  que maneje valores potencialmente secretos.

### 1.6 Cache de estado de cast (memoización de un solo unit)
```lua
local cachedCastUnit, cachedIsCasting, cachedUninterruptible, cachedRawUninterruptible
local cachedCastValid = false
function Minimizer.Cast.GetState(unit) ... end
function Minimizer.Cast.InvalidateState(unit) ... end
```
- Cache de **una sola entrada** (no un diccionario por unit), invalidada por evento de
  cast. Esto es válido porque el consumo típico es "leer el estado de la unidad que
  acaba de disparar el evento", pero **no sirve como cache multi-unit** — si el
  refactor necesita leer el estado de cast de varias unidades en el mismo frame sin
  invalidar entre medias, esta cache de una sola entrada las pisará. Vigilar este
  límite al portar a la nueva arquitectura (candidato a fusionarse con
  `Minimizer.Cache.units`, que sí es multi-unit).

### 1.7 `SetAlphaFromBoolean` para aceptar valores secretos directamente
```lua
if cooldown.SetAlphaFromBoolean then
    cooldown:SetAlphaFromBoolean(duration:IsZero(), 0, 1)   -- Focus.lua
end
...
visuals.targetContainer:SetAlphaFromBoolean(targeted)        -- CastingBar.lua
```
- Coincide exactamente con el patrón documentado en la guía original
  (`Display/CannotInterruptMarker.lua` de Platynator). Siempre con guard
  `if widget.SetAlphaFromBoolean then ... else fallback end` — nunca se asume que la
  API existe en todos los clientes/widgets.

### 1.8 Firma real de `EvaluateColorValueFromBoolean` (resuelta empíricamente)
```lua
C_CurveUtil.EvaluateColorValueFromBoolean(state, valueIfTrue:number, valueIfFalse:number) -> number
```
- **Esto NO acepta una tabla de color RGB de una sola vez.** Se probó y falló con
  `bad argument #2` al pasar una tabla; funciona pasando escalares. Por eso en
  `CastingBar.lua` y `HealthBarColor.lua` cada color se arma con **3 llamadas
  independientes**, una por canal:
  ```lua
  local r = C_CurveUtil.EvaluateColorValueFromBoolean(uninterruptible, colorA[1], colorB[1])
  local g = C_CurveUtil.EvaluateColorValueFromBoolean(uninterruptible, colorA[2], colorB[2])
  local b = C_CurveUtil.EvaluateColorValueFromBoolean(uninterruptible, colorA[3], colorB[3])
  ```
- **Cuidado con el orden de los argumentos**: es
  `(state, valueIfTrue, valueIfFalse)` — el primer valor numérico es el que se usa
  cuando `state` es verdadero. Los tres call-sites actuales (`CastingBar:ApplyGreenColor`
  dos veces, `HealthBarColor:UpdateNamePlate` una vez, `Focus.lua` `UpdateCooldown` una
  vez) respetan este orden, pero **hay que releer cada uno con cuidado antes de tocarlo**
  porque invertir el orden no da error de sintaxis, solo pinta el color equivocado
  silenciosamente. Esto es exactamente el tipo de bug "no truena, pero está mal" que
  hay que vigilar en el refactor.
- Todo esto está anotado en las "Notas" al final del `project.md` original — se
  promueve aquí a sección principal porque es la API más usada y más fácil de romper
  del addon.

### 1.9 Amenaza (threat) sin coerción de secretos
```lua
local situation = UnitThreatSituation(source or "player", unit)
if issecretvalue and issecretvalue(situation) then return nil end
if type(situation) ~= "number" then return nil end
```
- Coincide con la guía original: solo el número `3` se trata como aggro sólido, nunca
  por coerción (`if situation then` sería incorrecto porque `0` es truthy en Lua).
  `Minimizer.Threat.PlayerHasAggro` compara explícitamente `== 3`.
- Cacheado por unit+source en `Minimizer.Cache.units[unit]["threat:" .. source]`,
  invalidado en `UNIT_THREAT_SITUATION_UPDATE` / `UNIT_THREAT_LIST_UPDATE`.

### 1.10 Absorb: fallback a indicador visual cuando el número es secreto
```lua
local absorbs = UnitGetTotalAbsorbs and UnitGetTotalAbsorbs(unit)
if Minimizer.Utils.IsSecretValue(absorbs) or absorbs == nil then
    -- no se puede leer el número: se cae a mirar si el overlay nativo está visible
    local indicator = healthBar and (healthBar.totalAbsorbOverlay or healthBar.totalAbsorb)
    return indicator and indicator.IsShown and indicator:IsShown() == true or false
end
if type(absorbs) == "number" and absorbs > 0 then return true end
```
- Este patrón **no está en la guía original de Platynator** tal cual, es una solución
  propia del proyecto: cuando el valor numérico es secreto, en vez de intentar inferir
  nada sobre él, se usa la señal visual que Blizzard ya calculó y expuso de forma seria
  (`IsShown()` de su propio overlay de absorb). Es un patrón sólido y reutilizable:
  **"si un número puede ser secreto, busca si Blizzard ya expone la misma información
  como un widget visible/oculto, y usa eso en vez de intentar comparar el número."**
  Vale la pena generalizar este patrón para otros datos que puedan volverse secretos en
  el futuro (daño, HP exacto, etc.).

---

## 2. Discrepancias entre la guía original (Platynator) y la implementación real

Estos son los puntos donde el código actual **se desvía** de lo que decía el
`project.md` original. No implica que estén mal — Minimizer no es Platynator, tiene su
propio motor —, pero hay que saber que son desviaciones deliberadas o pendientes de
revisar, para no "corregir" el código nuevo haciéndolo calzar con la guía vieja por
error.

1. **`GetNamePlateForUnit` sin `issecure()`.** La guía decía
   `C_NamePlate.GetNamePlateForUnit(unit, issecure())`. El código real omite el segundo
   argumento siempre. Funciona en las pruebas actuales, pero no hay evidencia de que se
   haya probado en un escenario donde `issecure()` cambia el resultado (p. ej. dentro de
   una transición secure). **Acción para el refactor: decidir explícitamente si se debe
   añadir el segundo argumento, y probarlo en combate.**

2. **No hay `C_NamePlateManager.SetNamePlateHitTestInsets`.** La guía lo documentaba
   como API disponible, pero Minimizer no la usa en ningún archivo actual. Es
   "pendiente" — el propio `project.md` original ya tenía una sección "APIs para
   geometría de nameplates (pendiente)" al final, así que esto es una feature no
   implementada, no una regresión.

3. **`Minimizer.Cast` es un motor propio, no una copia del cache de Platynator.**
   La guía describía `addonTable.Cache:Get(unit, "cast")` con un objeto rico
   (`cacheInfo.cast`, `cacheInfo.channel`, `cacheInfo.interrupted`, con persistencia de
   "cast interrumpido" con timeout). Minimizer **no implementa la persistencia de cast
   interrumpido** — no existe ningún timeout ni estado `interrupted` guardado. Si el
   refactor quiere ese comportamiento (mantener el color/estado un momento después de
   que se interrumpe un cast) hay que construirlo desde cero, no está aquí.
   Nota del dev: se deja pasar para que blizzard implemente su propio cast interrumpido.

4. **`importantCast` se detecta pero no se usa para pintar nada.** `CastingBar.lua`
   calcula `IsImportantSpell` / `important` y lo guarda en
   `nameplate.MinimizerImportantCast`, pero el propio comentario del código dice:
   *"El cliente ya resalta los casts importantes; sólo conservamos el dato para futuras
   animaciones sin duplicar su indicador nativo."* Es decir: es un dato calculado y
   **no consumido todavía**. No es un bug, es trabajo a medias marcado explícitamente
   — útil saberlo para no asumir que ya hay una animación de cast importante en algún
   lado.
   Nota del dev: No se va a usar, tras varias pruebas se llega a la conclusion que el visual de blizzard es suficiente ,feature a borrar.

---

## 3. Código a vigilar: clasificado por severidad

### 🔴 3.1 BUG ACTIVO — lógica de interrupción deshabilitada en `CastingBar`

En `CastingBar:UpdateNamePlate`:
```lua
-- Diagnóstico temporal: se ignoran interruptibilidad y cooldown para
-- comprobar de forma aislada que localizamos y pintamos el castbar.
-- Diagnóstico solicitado: cualquier casteo activo se pinta verde,
-- independientemente del cooldown o de la interruptibilidad.
self:ApplyGreenColor(castBar, unit, isCasting, isChanneling, ready, uninterruptible)
```
Los propios comentarios dicen que esto es **código de diagnóstico temporal**, y aunque
`ApplyGreenColor` internamente sí mira `uninterruptible` y `ready`, el comentario indica
que la intención original de diseño (pintar rosa cuando NO es interrumpible o el
interrupt no está listo) fue puesta en modo "todo verde" para depurar la localización
del castbar, y **nunca se revirtió**. Esto es exactamente el tipo de código junior que
se cuela: un flag de debug que queda en el camino feliz de producción. Hay que decidir
antes del refactor:
- Si el comportamiento correcto final es el que ya calcula `ApplyGreenColor` (que sí
  usa `ready`/`uninterruptible` correctamente) → **borrar los comentarios de
  diagnóstico**, ya no aplica, la llamada ya está bien.
- Si en verdad todavía hace falta un modo "todo verde" para depurar futuras nameplates
  → convertirlo en un flag explícito de `/simp` en vez de dejarlo mudo en el código.
  

**Revisar esto es prioridad #1 antes de tocar `CastingBar.lua` en la reescritura**,
porque si se copia tal cual a la nueva arquitectura se arrastra un comentario engañoso
sobre qué hace la función.

### 🟠 3.2 Fragilidad — localización del castbar por duck-typing

```lua
function CastingBar:GetCastBar(nameplate)
    ...
    -- Duck-typing: en este cliente los widgets de nameplate son anónimos
    -- (GetName() vacío) y no cuelgan de campos nombrados como .castBar/.CastBar.
    -- Se localiza recorriendo los nietos de UnitFrame y descartando la healthbar
    ...
```
Recorre `unitFrame:GetChildren()` → `child:GetChildren()` (nietos), descarta la
healthbar, y toma el primer widget que tenga `SetStatusBarColor` + `GetValue`. Esto es
un workaround razonado (documentado, no accidental) para un cliente donde el castbar no
está expuesto por campo nombrado, pero es inherentemente frágil ante:
- Cambios de Blizzard en la jerarquía de frames de nameplate (parche que añade un
  widget hermano con `SetStatusBarColor`/`GetValue`, por ejemplo una barra de poder).
- Nameplates de tipo distinto (jugador vs NPC vs boss) que puedan tener distinta
  jerarquía.

Está cacheado (`nameplate.MinimizerCastBar`) así que el costo de recorrer se paga una
sola vez por nameplate, lo cual mitiga el problema de performance pero no el de
fragilidad estructural. **Para el refactor: aislar esta función detrás de una interfaz
clara (`Minimizer.Widgets.FindCastBar(nameplate)`) para que si Blizzard cambia la
jerarquía, el arreglo se haga en un solo sitio.**

### 🟡 3.3 Config incompleto — claves usadas pero no declaradas en `DEFAULTS`

`Interrupt.lua` lee `MinimizerDB.interruptSpellID` y `MinimizerDB.interruptReady` como
overrides manuales, pero `Config.lua` → `Minimizer.Config.DEFAULTS` no las declara.
Esto significa:
- No hay ningún valor por defecto ni migración para ellas.
- No hay ninguna UI/slash-command actual que las setee (no aparecen en el bloque de
  `/simp` de `Core.lua`).
Son, en la práctica, **hooks de debugging manual** (se pueden setear a mano desde
`/run MinimizerDB.interruptReady = false` para forzar pruebas) que nunca se
formalizaron como feature. No es taint-unsafe, pero es deuda de diseño: si el refactor
expone un panel de opciones, falta decidir si esto se vuelve una opción real o se
elimina.

### 🟡 3.4 Cobertura incompleta de la tabla de interrupts por clase

```lua
local INTERRUPT_SPELLS = {
    WARRIOR = 6552, ROGUE = 1766, MAGE = 2139, SHAMAN = 57994,
    HUNTER = 147362, PRIEST = 15487, WARLOCK = 19647, MONK = 116705,
    DRUID = 106839, DEATHKNIGHT = 47528, PALADIN = 96231,
    DEMONHUNTER = 183752, EVOKER = 351338,
}
```
Un solo spellID por clase, no por spec. Casos conocidos donde esto no alcanza:
`DRUID = 106839` (Skull Bash) solo existe en forma Feral/Guardian; Balance/Resto no
tienen interrupt de esa lista. El código ya maneja el caso "el jugador no tiene el
spell" (`IsSpellKnownOrInSpellBook` / `IsPlayerSpell` como fallback en cascada), así que
el peor caso es "no se muestra ningún indicator de interrupt para esa spec", no un
crash ni taint — pero es una limitación funcional a tener en cuenta, no un bug de
seguridad.

### 🟢 3.5 Higiene de archivo — mojibake / encoding mixto en `Core.lua`

Hay comentarios con caracteres corruptos, p. ej.
`-- La clase de enemigo puede cambiar durante una transformaciÃ³n.` (debería ser
"transformación"). Es evidencia de que el archivo fue guardado/editado alguna vez con
una codificación distinta a UTF-8 consistente (o pasó por una herramienta que
rompió tildes). No afecta la ejecución (son comentarios), pero **antes de reescribir
Core.lua conviene re-guardar todo el árbol como UTF-8 sin BOM** para que el diff del
refactor no arrastre basura de encoding mezclada con cambios reales.

---

## 4. Checklist canónico de taint / secrets (consolidado y verificado)

Reglas confirmadas por el código real, no solo por la guía teórica. Aplicar estas
mismas reglas a todo módulo nuevo del refactor:

1. **Nunca evaluar un valor potencialmente secreto con `and/or`, `not`, `==`, `>` etc.**
   directamente en Lua. Comprobar primero con `issecretvalue(value)`
   (envuelto en `Minimizer.Utils.IsSecretValue`). Ejemplo real: `ReadCastState` en
   `Core.lua`.
2. **Si el valor es secreto, no lo "conviertas" a booleano por tu cuenta.** Propágalo
   crudo hacia una API C-side que sepa aceptarlo (`SetAlphaFromBoolean`,
   `EvaluateColorValueFromBoolean`, `SetShown` cuando aplique). Nunca intentes
   "adivinar" el valor con heurísticas Lua.
3. **Cuando no exista una API C-side para el dato secreto** (caso absorb), busca si
   Blizzard ya expone la misma información como estado visual de un widget nativo
   (`indicator:IsShown()`) y confía en eso en vez de en el número.
4. **`EvaluateColorValueFromBoolean` es escalar, no acepta tablas de color.** Tres
   llamadas por color, una por canal RGB, respetando el orden
   `(state, valueIfTrue, valueIfFalse)`.
5. **Nunca llamar directamente a `NamePlateDriverFrame:OnNamePlateAdded/Removed`.**
   Solo escuchar con `hooksecurefunc`.
6. **Si un módulo hace `hooksecurefunc` sobre un setter que el propio módulo también
   llama** (p. ej. `SetStatusBarColor`), protegerlo con una flag de reentrancia
   (`ModuleApplyingX = true/nil`) para no generar un bucle o un doble-repintado.
7. **Solo simplificar/tocar nameplates a través de
   `C_NamePlateManager.SetNamePlateSimplified`**, nunca manipulando `SetScale` u otras
   propiedades de un SecureFrame directamente.
8. **Aplicar `SetNamePlateSimplified` solo cuando el estado deseado cambia**
   (comparar contra el último estado aplicado guardado en el frame), no en cada tick.
9. **Todas las lecturas de threat situation deben verificar `issecretvalue` y
   `type(x) == "number"` antes de comparar contra `3`.** Nunca tratar `0`/`nil` como
   "sin amenaza" por truthiness.
10. **Todo dato derivado de eventos debe invalidarse explícitamente por evento**, nunca
    confiar en que expira solo. Ver el bloque `OnEvent` de `Core.lua` como referencia de
    qué evento invalida qué `kind` en la cache.

---

## 5. Qué llevarse (y qué no) a la nueva arquitectura

**Llevarse tal cual (probado, canónico):**
- El patrón `Core.RegisterModule` + `UpdateNamePlate`/`OnNamePlateRemoved`.
- `ReadCastState` con retorno doble (seguro para Lua / crudo para C-side).
- El patrón de reentrancia en hooks de auto-repintado.
- El fallback de absorb a indicador visual cuando el número es secreto.
- La firma real de `EvaluateColorValueFromBoolean` y su uso canal-por-canal.
- La comparación `situation == 3` para aggro sólido.

**Revisar/decidir antes de portar:**
- `CastingBar:UpdateNamePlate` — resolver el comentario de "diagnóstico temporal"
  (sección 3.1) antes de copiar la función a la nueva arquitectura.
- `CastingBar:GetCastBar` — encapsular el duck-typing detrás de una interfaz aislada
  (sección 3.2).
- `GetNamePlateForUnit` sin `issecure()` — decidir si hace falta el segundo argumento.
- Cache de un solo unit en `Minimizer.Cast` (sección 1.6) — decidir si se fusiona con
  `Minimizer.Cache.units` (multi-unit) para evitar dos sistemas de cache paralelos.
- Claves de config no declaradas (`interruptSpellID`, `interruptReady`) — formalizar
  como feature o eliminar.

**No portar / no reintroducir:**
- Cualquier código que compare un valor de `UnitCastingInfo`/`UnitChannelInfo` con
  `and/or` en lugar de `if/elseif` explícito.
- Cualquier llamada a `EvaluateColorValueFromBoolean` pasando una tabla de color en vez
  de tres escalares.