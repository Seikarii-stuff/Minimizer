# Platynator Nameplate + Taint / Secret Integration Reference

Este documento reúne las APIs canónicas, ejemplos de uso y patrones de diseño que Platynator ya emplea para trabajar con las nameplates "default" de Blizzard, manejar simplificación, colores, cast bars, amenazas y valores secretos sin romper taint.

## 1. APIs principales para nameplates por defecto

### `C_NamePlateManager.SetNamePlateSimplified(unit, bool)`
- Uso verificado: `Display/Initialize.lua` L820-L824
- Descripción: simplifica o desimplifica la nameplate de una unidad concreta.
- Disponibilidad comprobada en `Core/Constants.lua` L15:
```lua
IsSimplifiedAvailable = C_NamePlateManager and C_NamePlateManager.SetNamePlateSimplified ~= nil
```

### `C_NamePlateManager.SetNamePlateHitTestInsets(type, left, right, top, bottom)`
- Uso verificado: `Display/Initialize.lua` L995-L1007
- Descripción: controla si las nameplates son clicables y cómo se expanden/ocultan los hit tests para enemy/friendly.
- Ejemplo:
```lua
if state.enemy then
  C_NamePlateManager.SetNamePlateHitTestInsets(Enum.NamePlateType.Enemy, 0, 0, 0, 0)
else
  C_NamePlateManager.SetNamePlateHitTestInsets(Enum.NamePlateType.Enemy, value, value, value, value)
end
```

### `C_NamePlate.GetNamePlateForUnit(unit, issecure())`
- Uso verificado: `Display/Initialize.lua` L807
- Descripción: obtiene el frame de nameplate actual para una unidad, respetando el modo seguro.

### Event hooks seguros de Blizzard
- `Display/Initialize.lua` L145-L153 hookea `NamePlateDriverFrame:OnNamePlateAdded` y `OnNamePlateRemoved` con `hooksecurefunc`.
- Importante: Platynator no invoca `NamePlateDriverFrame:OnNamePlateAdded()` directamente, lo que evita taint por transición addon-controlled.

## 2. Manejo de simplificación / desimplificación

### Lógica de decisión de diseño
- Archivo clave: `Display/DesignForContext.lua`.
- Método principal: `GetAssignedDesign(unit)`.
- Patrón: aplicar `ShouldUnsimplifyForCast(unit, style)` o `ShouldUnsimplifyForThreat(unit, style)` antes de decidir `shouldSimplify`.

### `ShouldUnsimplifyForCast(unit, styleName)`
- Usa cache de cast en `addonTable.Cache:Get(unit, "cast")`.
- Detecta cast activo mediante:
```lua
local isCastingNow = cacheInfo.cast[1] ~= nil or cacheInfo.channel[1] ~= nil or cacheInfo.interrupted ~= nil
```
- Determina interruptibilidad con:
```lua
local uninterruptable = castInfo[8]
if uninterruptable == nil then
  uninterruptable = channelInfo[7]
end
```
- Aplica `unsimplify` si el diseño tiene `bar.autoColors` que lo requiere.

### `ShouldUnsimplifyForThreat(unit, styleName)`
- Usa cache de amenaza en `addonTable.Cache:Get(unit, "threat")`.
- Usa `UnitThreatSituation("player", unit)` y, si eres tanque, también revisa otros tanques.
- Ejemplo:
```lua
local threat = threatDetails.situation
if isTank and (threat == 0 or threat == nil) then ... end
if not isTank and threat == 3 then ... end
```
- Aplica `unsimplify` cuando el diseño permite `kind == "threat"` o `threatIgnoreRole`.

### Actualización dinámica
- `Display/Nameplate.lua` registra callbacks sobre estado de `cast` y `threat`.
- Cuando `currentSimplify` cambia, dispara `UnitDesignChange` para forzar reevaluación.

## 3. Cache, eventos y detección de cast

### Sistema de cache de estados
- Archivo clave: `Display/Cache.lua`.
- Tipos de estado: `cast`, `threat`, `range`, `combat`, `canAttack`, `target`, `softTarget`, `mouseover`, `focus`.
- Evento → tipo inyectado en `eventToKind`.

### Detección de cast
- Usa APIs nativas:
  - `UnitCastingInfo(unit)`
  - `UnitChannelInfo(unit)`
  - `UnitCastingDuration(unit)`
  - `UnitChannelDuration(unit)`
  - `UnitEmpoweredChannelDuration(unit, true)` (Secrets)
- `Display/Cache.lua` L46-L59 crea el estado de cast con estos valores.

### Eventos de cast manejados
- `UNIT_SPELLCAST_START`
- `UNIT_SPELLCAST_STOP`
- `UNIT_SPELLCAST_FAILED`
- `UNIT_SPELLCAST_INTERRUPTED`
- `UNIT_SPELLCAST_INTERRUPTIBLE`
- `UNIT_SPELLCAST_NOT_INTERRUPTIBLE`
- `UNIT_SPELLCAST_CHANNEL_START`
- `UNIT_SPELLCAST_CHANNEL_STOP`
- `UNIT_SPELLCAST_DELAYED`
- `UNIT_SPELLCAST_CHANNEL_UPDATE`
- `UNIT_SPELLCAST_EMPOWER_START` / `STOP` / `UPDATE` (Retail)

### Persistencia de cast interrumpido
- `Cache.lua` mantiene estado `interrupted` por un timeout configurado.
- Si un cast se interrumpe, el estado se guarda brevemente para poder pintar la barra o estilo apropiado.

## 4. Color de barras y cast bars

### Sistema de evaluación de colores
- Archivo central: `Display/Colors.lua`.
- Usa una cola de colores (`colorQueue`) y condiciones para evaluar el estilo de cada barra.
- Los `kind` más relevantes para health/cast son:
  - `eliteType`
  - `threat`
  - `uninterruptableCast`
  - `interruptReady`
  - `interruptNotReady`
  - `castTargetsYou`
  - `importantCast`
  - `cast`
  - `isCast`
  - `notCast`

### Cast bar / health bar por interruptibilidad
- `uninterruptableCast`: verifica `castInfo[8]` o `channelInfo[7]`.
- `cast` / `channel` / `empowered`: pinta según si es channel o empowered.
- `interruptReady` / `interruptNotReady`: usa cooldown de interruptores.
- `castTargetsYou`: usa `UnitIsSpellTarget(unit, "player")` o `UnitIsUnit(unit.."target","player")`.
- `importantCast`: usa `C_Spell.IsSpellImportant(spellID)` si está disponible.

### Ejemplo de color condicional
```lua
if s.kind == "uninterruptableCast" then
  local cacheInfo = GetEvaluationCache(evaluationCache, unit, "cast")
  local uninterruptable = castInfo[8] or channelInfo[7]
  if s.persistent and cacheInfo.hasUninterruptableCasted and not UnitIsDeadOrGhost(unit) then
    PushStateColor(colorQueue, s.colors.uninterruptable)
  elseif uninterruptable then
    PushStateColor(colorQueue, s.colors.uninterruptable)
  end
end
```

### Resaltar cast importante
- `Display/Colors.lua` L559-L579 usa `C_Spell.IsSpellImportant(spellID)`.
- Si el spell es importante se pinta con los colores `cast` o `channel` definidos.

## 5. Taint seguro y valores secretos

### Principios generales en Platynator
- No llamar a métodos protegidos de Blizzard desde transiciones de addon-controlled si puede evitarse.
- Usar `hooksecurefunc` para funciones de Blizzard en lugar de llamadas directas.
- Usar `issecretvalue()` antes de lógica Lua con valores potencialmente secretos.
- Preferir `SetAlphaFromBoolean()` y `SetShown()` para aceptar valores secretos.
- Delegar lógica booleana a C-side cuando sea posible.

### Detección de secretos
- `Core/Constants.lua` define `IsSecretsActive` con `C_Secrets and C_Secrets.HasSecretRestrictions()`.
- `Core/Utilities.lua` expone:
```lua
function addonTable.Utilities.IsChangesRestricted()
  return InCombatLockdown() or C_Secrets.ShouldAurasBeSecret()
end
```

### Ejemplos de manejo seguro
- `Display/CannotInterruptMarker.lua`:
```lua
if self.marker.SetAlphaFromBoolean then
  self:Show()
  self.marker:SetAlphaFromBoolean(notInterruptible)
else
  self:SetShown(notInterruptible)
end
```
- `Display/HealthBar.lua`:
```lua
local function ValuesDiffer(value, previous)
  if issecretvalue and (issecretvalue(value) or issecretvalue(previous)) then
    return true
  end
  return value ~= previous
end
```
- `Display/AbsorbText.lua` y `Display/GuildText.lua` también validan `issecretvalue(raw)` antes de renderear.

### Manejo de cast secret y duración
- `Display/Cache.lua` guarda `castDuration`, `channelDuration` y `empoweredDuration` sólo si `Constants.IsSecretsActive`.
- Esto evita filtrar información protegida y sigue el modelo de Blizzard de ofrecer solo datos seguros.

## 6. Control de tipo de mob y colores de salud

### Detección de tipo de mob
- `Display/Utilities.lua` usa `UnitClassification(unit)` y `UnitEffectiveLevel(unit)`.
- Detecta miniboss/boss con `UnitIsLieutenant(unit)` y comparaciones de nivel relativas al dungeon.
- Determina caster vs melee con `HasMana(unit)` (`UnitHasPowerType(unit, Enum.PowerType.Mana)` o `UnitPowerType(unit)`).

### `GetEliteType(unit, casterOverride)`
- Devuelve uno de:
  - `boss`
  - `miniboss`
  - `caster`
  - `melee`
  - `trivial`

### Clasificación usada para colores
- `eliteType` en `Display/Colors.lua`
- Se aplica cuando `s.kind == "eliteType"` y la unidad no es neutral.
- Los colores pueden mapear:
  - `boss`
  - `miniboss`
  - `caster`
  - `melee`
  - `trivial`

## 7. Target / Focus y alpha / escala

### Escala y alpha de nameplate
- `Display/Nameplate.lua` L300-L330 actualiza la escala de la nameplate en función de:
  - `CAST_SCALE` cuando la unidad está casteando
  - `CAST_ALPHA` cuando la unidad está casteando
  - `MOUSEOVER_ALPHA` cuando está en mouseover
  - `NOT_TARGET_ALPHA` cuando no es target
  - `OUT_OF_RANGE_ALPHA` si está fuera de rango
  - `NOT_IN_PULL_ALPHA` si no está en combate y el jugador sí lo está
- Ejemplo:
```lua
if self.casting then
  scale = addonTable.Config.Get(addonTable.Config.Options.CAST_SCALE)
  alpha = math.max(alpha, addonTable.Config.Get(addonTable.Config.Options.CAST_ALPHA))
end
self:SetScale(self.scale * scale * addonTable.Config.Get(addonTable.Config.Options.GLOBAL_SCALE) * scaleMod)
self:SetAlpha(alpha)
```

### Target / soft target
- Usa `UnitIsUnit("target", self.unit)` y `UnitIsUnit("softenemy", self.unit)` / `softfriend`.
- Esto permite distinguir el target principal y soft target del foco.

### Foco y visibilidad de flechas
- El diseño existente en `Design.lua` muestra highlights de tipo `target` y `mouseover` con assets de flechas.
- La lógica de `Nameplate.lua` mantiene el estado de target/softtarget/mouseover sin cambio directo de taint.

## 8. Patrones de implementación recomendados

### Trabajar con el motor C+ de Blizzard
- Dejar que Blizzard controle la creación y gestión de nameplates.
- Apoyarse en:
  - `C_NamePlate.GetNamePlateForUnit`
  - `C_NamePlateManager.SetNamePlateSimplified`
  - `C_NamePlateManager.SetNamePlateHitTestInsets`
  - `NamePlateDriverFrame` vía `hooksecurefunc`

### Evitar taint
- No llamar a métodos protegidos directamente.
- Usar `hooksecurefunc` para acciones de Blizzard controladas.
- No mutar `NamePlateDriverFrame` ni `UnitFrame` protegidos durante combate salvo con APIs seguras.

### Manejar valores secretos
- Validar `issecretvalue` antes de comparar u operar.
- Usar `SetAlphaFromBoolean` / `SetShown` cuando el valor puede ser secreto.
- No inferir valores secretos por lógica Lua compleja.

## 9. Referencias canónicas

- `Display/Initialize.lua`
  - asignación de diseño
  - `SetNamePlateSimplified`
  - `SetNamePlateHitTestInsets`
  - `hooksecurefunc(NamePlateDriverFrame, "OnNamePlateAdded")`
- `Display/DesignForContext.lua`
  - `ShouldUnsimplifyForCast`
  - `ShouldUnsimplifyForThreat`
  - `GetAssignedDesign`
- `Display/Cache.lua`
  - cache de cast
  - cache de threat
  - callbacks de eventos de cast y amenaza
- `Display/Nameplate.lua`
  - `UpdateVisual`
  - `UpdateCastingState`
  - target / soft target / mouseover
- `Display/Colors.lua`
  - evaluación de `cast`, `uninterruptableCast`, `interruptReady`, `castTargetsYou`, `importantCast`
- `Display/CannotInterruptMarker.lua`
  - `SetAlphaFromBoolean` / `SetShown`
- `Core/Constants.lua` y `Core/Utilities.lua`
  - detección de secretos y restricciones

## 10. Conclusión

Platynator ya usa un enfoque seguro y canónico para:
- controlar simplificación de nameplates Blizzard sin reemplazarlas,
- ajustar escala/alpha de nameplates al castear,
- colorear health/cast bars según tipo de mob y estado de interruptibilidad,
- manejar valores secretos con `issecretvalue` y APIs seguras,
- evitar llamadas directas a métodos protegidos de Blizzard.

Para replicar el comportamiento descrito en el requerimiento, la estrategia correcta es:
1. mantener la lógica de evaluación local en `Display/DesignForContext.lua` y `Display/Colors.lua`,
2. aplicar `SetNamePlateSimplified` sólo cuando cambia el estado deseado,
3. usar `SetNamePlateHitTestInsets` para controlar clics,
4. renderizar los highlights de target/focus mediante assets y condiciones de diseño, y
5. respetar secretos y taint en cada rama de decisión.




Notas:

Firma real de EvaluateColorValueFromBoolean resuelta: la llamada con tablas de color falló (bad argument #2), pero con escalares sueltos funcionó y devolvió un solo valor. Es decir, la firma real es EvaluateColorValueFromBoolean(state, valueIfTrue:number, valueIfFalse:number) -> number — NO acepta un color RGB de una vez. Para pintar una barra hay que llamarla 3 veces (una por canal):
lua
local r = C_CurveUtil.EvaluateColorValueFromBoolean(notInterruptible, grisR, verdeR)
local g = C_CurveUtil.EvaluateColorValueFromBoolean(notInterruptible, grisG, verdeG)
local b = C_CurveUtil.EvaluateColorValueFromBoolean(notInterruptible, grisB, verdeB)
castBar:SetStatusBarColor(r, g, b)

## APIs para geometría de nameplates (pendiente)

- Tamaño base de las placas: `C_NamePlate.SetNamePlateSize(width, height)`.
- Área clicable global: `C_NamePlateManager.SetNamePlateHitTestInsets(Enum.NamePlateType.Enemy, left, right, top, bottom)`.
- Área clicable por placa: `nameplate:CanChangeHitTestPoints()` y `nameplate:SetAllHitTestPoints(clickRegion)`.
- Área usada para apilado: `nameplate:SetStackingBoundsFrame(frame)`.
- Estas APIs controlan regiones distintas: cambiar el tamaño visual no garantiza que el hit-test o el apilado coincidan automáticamente. Deben validarse por separado antes de usarlas.




FUTURO:
Añadir ccs al lado de la cara del focus (cara+cc) cap 3
Añadir ofensivos/defensivos en el target (ofensivo+defensivo) cap3
Hara falta algun tipo de db 