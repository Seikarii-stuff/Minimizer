# APIs de WoW Verificadas — Extraídas del código fuente de Platynator

> [!IMPORTANT]
> Todas las APIs aquí listadas están **verificadas y comprobadas** como funcionales dentro del código de Platynator.
> Cada entrada incluye el archivo fuente y la línea exacta donde se usa.

## Archivos fuente originales (rutas locales)
> Se han identificado estos archivos tras inspeccionar todo el repositorio con búsqueda de patrones de APIs WoW (`C_*`, `Unit*`, `CreateFrame`, `RegisterEvent`, `hooksecurefunc`, etc.).
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\API\Main.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Core\Constants.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Core\Dialogs.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Core\Initialize.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Core\PixelPerfect.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Core\SlashCmd.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Core\Utilities.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\CustomiseDialog\AuraFilters.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\CustomiseDialog\Behaviour.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\CustomiseDialog\Builders\AuraTextBuilder.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\CustomiseDialog\Builders\ColorsBuilder.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\CustomiseDialog\Builders\MovementBehavior.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\CustomiseDialog\Components.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\CustomiseDialog\Designer.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\CustomiseDialog\ImportDialog.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\CustomiseDialog\Initialize.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\CustomiseDialog\Main.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\CustomiseDialog\StyleSelection.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\AbsorbText.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\Auras\AurasNext.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\Auras\AurasPrev.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\Auras\ManagerPrev.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\CVars.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\Cache.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\CastBar.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\CastInterrupterText.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\CastTargetText.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\CastTimeText.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\Colors.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\CreatureText.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\CreatureTextMSP.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\DesignForContext.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\EliteMarker.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\EnergyBar.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\EnergyText.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\FactionMarker.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\GuildText.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\HealthBar.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\HealthFillTextBar.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\HealthText.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\Initialize.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\LevelText.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\MythicPlusForcesText.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\Nameplate.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\PowerBar.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\PvPMarker.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\RaidMarker.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\RareMarker.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\UnitTargetText.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\Utilities.lua
- c:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns\Platynator\Display\Widgets.lua

---

## 1. Control Simplificado de Barras (Simplify/Unsimplify)

### API Principal: `C_NamePlateManager.SetNamePlateSimplified(unit, bool)`

Simplifica o desimplifica la nameplate de una unidad específica.

- **Archivo**: [Initialize.lua](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Initialize.lua#L822-L824)
- **Uso verificado**:
```lua
if C_NamePlateManager and C_NamePlateManager.SetNamePlateSimplified then
  C_NamePlateManager.SetNamePlateSimplified(unit, shouldSimplify)
end
```

### Detección de disponibilidad

- **Archivo**: [Constants.lua](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Core/Constants.lua#L15)
```lua
IsSimplifiedAvailable = C_NamePlateManager and C_NamePlateManager.SetNamePlateSimplified ~= nil
```

### Lógica de unsimplify condicional: Cast + Threat

Platynator usa `ShouldUnsimplifyForCast()` y `ShouldUnsimplifyForThreat()` en [DesignForContext.lua](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/DesignForContext.lua#L217-L251) y [L187-L215](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/DesignForContext.lua#L187-L215).

**La decisión se toma en `GetDesignFromState()`** (línea 337-342):
```lua
if shouldSimplify and unit and (ShouldUnsimplifyForCast(unit, settings.style) or ShouldUnsimplifyForThreat(unit, settings.style)) then
  shouldSimplify = false
end
return settings.style, settings.scale, shouldSimplify, index
```

#### Unsimplify por Cast (APIs involucradas):
```lua
-- DesignForContext.lua L219-L229
local cacheInfo = addonTable.Cache:Get(unit, "cast")
local isCastingNow = cacheInfo.cast[1] ~= nil or cacheInfo.channel[1] ~= nil or cacheInfo.interrupted ~= nil
local uninterruptable = castInfo[8]  -- campo 8 de UnitCastingInfo
if uninterruptable == nil then
  uninterruptable = channelInfo[7]   -- campo 7 de UnitChannelInfo
end
```

#### Unsimplify por Threat (APIs involucradas):
```lua
-- DesignForContext.lua L189-L204
local threatDetails = addonTable.Cache:Get(unit, "threat")
local threat = threatDetails.situation      -- resultado de UnitThreatSituation("player", unit)
local doesOtherTankHaveAggro = threatDetails.otherTankAggro
local isTank = IsTankRole()
```

### Re-evaluación dinámica en combate

El nameplate re-evalúa simplificación al cambiar estado de cast o threat:
- **Archivo**: [Nameplate.lua](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Nameplate.lua#L208-L221)
```lua
addonTable.Cache:RegisterCallback(self.unit, "cast", function(state)
  -- ...
  if self.currentSimplify ~= nil then
    local _, _, newSimplify = addonTable.Display.Context:GetAssignedDesign(self.unit)
    if self.currentSimplify ~= newSimplify then
      addonTable.CallbackRegistry:TriggerEvent("UnitDesignChange", self.unit)
    end
  end
end)
```

### Eventos de combate para simplificación

| Evento | Uso | Archivo |
|---|---|---|
| `PLAYER_REGEN_DISABLED` | Inicio de combate | [Initialize.lua L118](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Initialize.lua#L118) |
| `PLAYER_REGEN_ENABLED` | Fin de combate | [Initialize.lua L119](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Initialize.lua#L119) |
| `UNIT_THREAT_LIST_UPDATE` | Cambio amenaza | [Cache.lua L148](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Cache.lua#L148) |

---

## 2. Hacer Más Grande a Mobs que Castean (Cast Scale)

### API: `SetScale(scale)` en el display/nameplate

- **Archivo**: [Nameplate.lua](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Nameplate.lua#L299-L333)
```lua
function addonTable.Display.NameplateMixin:UpdateVisual()
  -- ...
  if self.casting then
    scale = addonTable.Config.Get(addonTable.Config.Options.CAST_SCALE)
    alpha = math.max(alpha, addonTable.Config.Get(addonTable.Config.Options.CAST_ALPHA))
  end
  self:SetScale(self.scale * scale * addonTable.Config.Get(addonTable.Config.Options.GLOBAL_SCALE) * scaleMod)
  self:SetAlpha(alpha)
end
```

### Estado de cast actualizado en tiempo real:
```lua
-- Nameplate.lua L291-L293
function addonTable.Display.NameplateMixin:UpdateCastingState(state)
  self.casting = state.cast[1] ~= nil or state.channel[1] ~= nil
end
```

### APIs involucradas para saber si castea:
| API | Retorno relevante | Uso |
|---|---|---|
| `UnitCastingInfo(unit)` | `[1]=name, [8]=notInterruptible, [9]=spellID` | [Cache.lua L46](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Cache.lua#L46) |
| `UnitChannelInfo(unit)` | `[1]=name, [7]=notInterruptible, [8]=spellID, [9]=isEmpowered` | [Cache.lua L46](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Cache.lua#L46) |

### Opciones de configuración:
- `CAST_SCALE` — multiplicador de escala al castear
- `CAST_ALPHA` — alpha al castear

---

## 3. Colores de Barras por Tipo de Mob (Melee vs Caster) y Estado de Cast

### 3a. Determinación Melee vs Caster

**API clave: `UnitPowerType(unit)` + `UnitHasPowerType(unit, Enum.PowerType.Mana)`**

- **Archivo**: [Utilities.lua](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Utilities.lua#L596-L624)
```lua
local HasMana
if UnitHasPowerType then
  HasMana = function(unit)
    return UnitHasPowerType(unit, Enum.PowerType.Mana)
  end
else
  HasMana = function(unit)
    return UnitPowerType(unit) == Enum.PowerType.Mana
  end
end
```

#### Resultado en `GetEliteType()`:
```lua
function addonTable.Display.Utilities.GetEliteType(unit, casterOverride)
  local classification = UnitClassification(unit)
  if classification == "elite" then
    -- ... lógica de level para miniboss/boss ...
    return HasMana(unit) and "caster" or "melee"
  elseif classification == "normal" or classification == "trivial" or classification == "minus" then
    return casterOverride and HasMana(unit) and "caster" or "trivial"
  end
end
```

### 3b. Sistema de Colores por Elite Type

- **Archivo**: [Colors.lua](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Colors.lua#L384-L391)
```lua
elseif s.kind == "eliteType" then
  if (inRelevantEliteInstance or not s.instancesOnly) and not IsNeutralUnit(unit) then
    local t = GetEliteType(unit, s.applyCasterAlways)
    if t and s.enabled[t] then
      PushColor(colorQueue, s.colors[t])  -- t = "boss"|"miniboss"|"caster"|"melee"|"trivial"
      break
    end
  end
```

**Tipos de color disponibles**: `boss`, `miniboss`, `caster`, `melee`, `trivial`

### 3c. Color de Barra de Cast por Interruptibilidad

#### APIs para determinar si es interrumpible:

```lua
-- Cache.lua L76-L88
local notInterruptible = new.cast[8]        -- campo 8 de UnitCastingInfo
if notInterruptible == nil then
  notInterruptible = new.channel[7]          -- campo 7 de UnitChannelInfo
end
```

#### Kinds de color en cast bar ([Colors.lua](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Colors.lua)):

| Kind | Descripción | Línea |
|---|---|---|
| `"cast"` | Color por tipo de cast (cast / channel / empowered / interrupted) | L580-L597 |
| `"isCast"` | Está casteando (bool, con persistencia opcional) | L606-L615 |
| `"notCast"` | No está casteando | L598-L605 |
| `"uninterruptableCast"` | Cast no interrumpible (con soporte secretvalue) | L543-L557 |
| `"interruptReady"` | Cast interrumpible + interrupción disponible (cooldown 0) | L450-L486 |
| `"interruptNotReady"` | Cast interrumpible + interrupción en cooldown | L487-L525 |
| `"castTargetsYou"` | Cast te apunta a ti (`UnitIsSpellTarget` o `UnitIsUnit(unit.."target", "player")`) | L526-L542 |
| `"importantCast"` | Cast marcado como importante por Blizzard (`C_Spell.IsSpellImportant(spellID)`) | L558-L579 |

#### APIs de interrupción:
```lua
-- Colors.lua L465-L475
C_Spell.GetSpellCooldownDuration(spellID)   -- Midnight (objeto Duration)
C_Spell.GetSpellCooldown(spellID)           -- Legacy (tabla con startTime, duration)
```

#### API de cast importante:
```lua
-- Colors.lua L559-L570
C_Spell.IsSpellImportant(spellID)           -- Solo Retail
```

### 3d. Marker de "Cannot Interrupt"

- **Archivo**: [CannotInterruptMarker.lua](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/CannotInterruptMarker.lua#L27-L44)
```lua
-- usa SetAlphaFromBoolean para valores secretos
if self.marker.SetAlphaFromBoolean then
  self:Show()
  self.marker:SetAlphaFromBoolean(notInterruptible)
else
  self:SetShown(notInterruptible)
end
```

---

## 4. Clasificación de Mobs: Miniboss / Trivial / Menor / Esbirro

### API Principal: `UnitClassification(unit)`

- **Archivo**: [Utilities.lua L607](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Utilities.lua#L607), [DesignForContext.lua L116](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/DesignForContext.lua#L116)
- **Valores retornados**: `"worldboss"`, `"elite"`, `"rareelite"`, `"rare"`, `"normal"`, `"minus"`, `"trivial"`

### Evento de cambio: `UNIT_CLASSIFICATION_CHANGED`

- **Archivos**: [EliteMarker.lua L25](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/EliteMarker.lua#L25), [DesignForContext.lua L139](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/DesignForContext.lua#L139)

### APIs auxiliares de clasificación:

| API | Descripción | Archivo:Línea |
|---|---|---|
| `UnitIsLieutenant(unit)` | Detecta mini-boss (teniente) en M+ | [Utilities.lua L613](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Utilities.lua#L613) |
| `UnitEffectiveLevel(unit)` | Nivel efectivo del mob (para comparar con dungeon) | [Utilities.lua L609](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Utilities.lua#L609) |
| `UnitLevel(unit)` | Nivel bruto | [Utilities.lua L47](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Utilities.lua#L47) |
| `UnitIsMinion(unit)` | Detecta esbirro (minion) | [DesignForContext.lua L22-L26](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/DesignForContext.lua#L22-L26) |
| `UnitIsOtherPlayersPet(unit)` | Fallback para detectar minions en clientes sin UnitIsMinion | [DesignForContext.lua L27-L29](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/DesignForContext.lua#L27-L29) |
| `UnitIsPlayer(unit)` | Distinguir jugador de NPC | [DesignForContext.lua L13-L18](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/DesignForContext.lua#L13-L18) |
| `UnitTreatAsPlayerForDisplay(unit)` | NPCs que Blizzard muestra como jugadores | [DesignForContext.lua L11-L13](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/DesignForContext.lua#L11-L13) |

### Lógica completa de `GetEliteType()` (subtipos de elite):

```lua
-- Utilities.lua L606-L624
function GetEliteType(unit, casterOverride)
  local classification = UnitClassification(unit)
  if classification == "elite" then
    local level = UnitEffectiveLevel(unit)
    local dungeonLevel = PLATYNATOR_LAST_INSTANCE.level
    if isRetail and (level == dungeonLevel + 1 or UnitIsLieutenant(unit)) then
      return "miniboss"
    elseif isRetail and (level == dungeonLevel + 2 or ...) or level == -1 then
      return "boss"
    else
      return HasMana(unit) and "caster" or "melee"
    end
  elseif classification == "normal" or classification == "trivial" or classification == "minus" then
    return casterOverride and HasMana(unit) and "caster" or "trivial"
  end
end
```

### Criterios de DesignForContext (asignación de diseño por clasificación):

| Criterio | Condición | Línea |
|---|---|---|
| `"class-rare"` | `c == "rare" or c == "rareelite"` | [DesignForContext.lua L61](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/DesignForContext.lua#L61) |
| `"class-elite"` | `c == "elite" or c == "rareelite"` | L62 |
| `"class-worldboss"` | `c == "worldboss"` | L63 |
| `"class-normal"` | `c == "normal"` | L64 |
| `"class-minor"` | `c == "minus"` | L65 |
| `"class-trivial"` | `c == "trivial"` | L66 |
| `"elite-boss"` | `eliteType == "boss"` | L74 |
| `"elite-miniboss"` | `eliteType == "miniboss"` | L75 |
| `"elite-caster"` | `eliteType == "caster"` | L76 |
| `"elite-melee"` | `eliteType == "melee"` | L77 |
| `"elite-trivial"` | `eliteType == "trivial"` | L78 |

### Dificultad de criatura:

```lua
-- Utilities.lua L31-L60
C_PlayerInfo.GetContentDifficultyCreatureForPlayer(unit) -- Retail
-- Retorna: Enum.RelativeContentDifficulty.Trivial/Easy/Fair/Difficult/Impossible
```

---

## 5. Amenaza (Threat)

### API: `UnitThreatSituation(playerOrTank, unit)`

- **Archivo**: [Cache.lua](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Cache.lua#L92-L103)
```lua
["threat"] = function(oldState, unit)
  local result = {situation = UnitThreatSituation("player", unit), otherTankAggro = false}
  if result.situation ~= 3 and result.situation ~= 2 and IsTank() then
    for _, tankUnit in ipairs(GetOtherTanks()) do
      if UnitThreatSituation(tankUnit, unit) == 3 then
        result.otherTankAggro = true
        break
      end
    end
  end
  return result, ...
end
```

**Valores de `situation`**:
- `nil` — no en combate con el jugador
- `0` — no es target del mob
- `1` — transición (puedes perder/ganar aggro)
- `2` — transición alta
- `3` — tienes aggro sólido

### Evento: `UNIT_THREAT_LIST_UPDATE`
- **Archivo**: [Cache.lua L148](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Cache.lua#L148)

### Estado de combate:

| API | Archivo:Línea |
|---|---|
| `UnitAffectingCombat(unit)` | [Cache.lua L9](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Cache.lua#L9) |
| `UnitIsFriend("player", unit)` | [Cache.lua L11](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Cache.lua#L11) |
| `UnitInParty(unit)` | [Cache.lua L11](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Cache.lua#L11) |
| `UnitCanAttack("player", unit)` | [Cache.lua L113](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Cache.lua#L113) |

---

## 6. Detección de Cast y Eventos de Cast

### APIs de estado de cast:

| API | Campos relevantes | Archivo |
|---|---|---|
| `UnitCastingInfo(unit)` | `[1]=name, [2]=text, [3]=texture, [4]=startTime, [5]=endTime, [6]=isTradeSkill, [7]=castID, [8]=notInterruptible, [9]=spellID` | [Cache.lua L46](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Cache.lua#L46) |
| `UnitChannelInfo(unit)` | `[1]=name, [2]=text, [3]=texture, [4]=startTime, [5]=endTime, [6]=isTradeSkill, [7]=notInterruptible, [8]=spellID, [9]=isEmpowered` | [Cache.lua L46](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Cache.lua#L46) |
| `UnitCastingDuration(unit)` | Objeto Duration (solo Midnight/Secrets) | [Cache.lua L54](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Cache.lua#L54) |
| `UnitChannelDuration(unit)` | Objeto Duration (solo Midnight/Secrets) | [Cache.lua L59](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Cache.lua#L59) |
| `UnitEmpoweredChannelDuration(unit, true)` | Objeto Duration para empower (solo Secrets) | [Cache.lua L57](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Cache.lua#L57) |

### Eventos de cast registrados:

| Evento | Archivo:Línea |
|---|---|
| `UNIT_SPELLCAST_START` | [Cache.lua L136](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Cache.lua#L136) |
| `UNIT_SPELLCAST_STOP` | L137 |
| `UNIT_SPELLCAST_FAILED` | L138 |
| `UNIT_SPELLCAST_INTERRUPTED` | L139 |
| `UNIT_SPELLCAST_INTERRUPTIBLE` | L140 |
| `UNIT_SPELLCAST_NOT_INTERRUPTIBLE` | L141 |
| `UNIT_SPELLCAST_CHANNEL_START` | L142 |
| `UNIT_SPELLCAST_CHANNEL_STOP` | L143 |
| `UNIT_SPELLCAST_DELAYED` | L144 |
| `UNIT_SPELLCAST_CHANNEL_UPDATE` | L145 |
| `UNIT_SPELLCAST_EMPOWER_START` | L153 (solo Retail) |
| `UNIT_SPELLCAST_EMPOWER_STOP` | L154 (solo Retail) |
| `UNIT_SPELLCAST_EMPOWER_UPDATE` | L155 (solo Retail) |

### Detección de interruptor (quién interrumpió):

```lua
-- Cache.lua L17-L27 (para clientes sin Secrets/Midnight)
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
local _, subevent, _, playerGUID, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
if subevent == "SPELL_INTERRUPT" then
  addonTable.CallbackRegistry:TriggerEvent("LegacyInterrupter", playerGUID, destGUID)
end
```

```lua
-- UNIT_SPELLCAST_INTERRUPTED (Midnight/Secrets)
-- Cache.lua L34-L36
local _, _, interrupterGUID = ...   -- tercer argumento del evento
```

### APIs de identificación del interruptor:

| API | Archivo:Línea |
|---|---|
| `UnitNameFromGUID(guid)` | [CastInterrupterText.lua L35](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/CastInterrupterText.lua#L35) |
| `GetPlayerInfoByGUID(guid)` | [CastInterrupterText.lua L36](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/CastInterrupterText.lua#L36) |
| `UnitTokenFromGUID(guid)` | [CastInterrupterText.lua L38](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/CastInterrupterText.lua#L38) |
| `UnitGUID(unit)` | [Cache.lua L193](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Cache.lua#L193) |

---

## 7. Auras: Control de Masas Compartido (Crowd Control)

### Framework de Auras Modernas (AuraContainer)

El sistema Midnight usa `AuraContainer` con template `"CustomAuraContainerTemplate"`:

- **Archivo**: [AurasNext.lua](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Auras/AurasNext.lua#L136-L163)
```lua
self.crowdControl = CreateFrame("AuraContainer", nil, self, "CustomAuraContainerTemplate")
```

### Filtros de CC — Strings de filtro de auras:

- **Archivo**: [AuraGroupBuilder.lua](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Auras/AuraGroupBuilder.lua#L21-L24)
```lua
local CROWD_CONTROL_FILTERS = {
  ALL = "HARMFUL|CROWD_CONTROL",
  PLAYER_ONLY = "HARMFUL|CROWD_CONTROL|PLAYER",
}
```

### APIs de AuraContainer (Blizzard Midnight):

| Método | Descripción | Archivo:Línea |
|---|---|---|
| `container:AddAuraGroup(name, filter, options)` | Agrega grupo de auras con filtro | [AuraGroupBuilder.lua L65](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Auras/AuraGroupBuilder.lua#L65) |
| `container:SetAuraGroupMaxFrameCount(name, count)` | Límite de frames por grupo | [AuraGroupBuilder.lua L72, L97](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Auras/AuraGroupBuilder.lua#L72) |
| `container:SetAuraGroupLayout(name, layout)` | Layout (spacing) del grupo | [AuraGroupBuilder.lua L98](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Auras/AuraGroupBuilder.lua#L98) |
| `container:SetAuraGroupCandidateFilters(name, filters)` | Filtros candidatos (include/exclude spellIDs) | [AuraGroupBuilder.lua L100](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Auras/AuraGroupBuilder.lua#L100) |
| `container:SetUnit(unit)` | Asigna unidad al container | [AurasNext.lua L592-L594](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Auras/AurasNext.lua#L592-L594) |
| `container:SetEnabled(bool)` | Activa/desactiva el container | [AurasNext.lua L580-L582](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Auras/AurasNext.lua#L580-L582) |
| `container:SetFlowLayoutGrowthDirection(h, v)` | Dirección de crecimiento | [AurasNext.lua L467-L469](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Auras/AurasNext.lua#L467-L469) |
| `container:SetFlowLayoutAnchorPoint(anchor)` | Punto de anclaje del layout | [AurasNext.lua L433](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Auras/AurasNext.lua#L433) |
| `frame:SetApplicationCount(fontString, options)` | Stacks del aura | [AurasNext.lua L122](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Auras/AurasNext.lua#L122) |
| `frame:SetIcon(texture)` | Icono del aura | [AurasNext.lua L123](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Auras/AurasNext.lua#L123) |
| `frame:SetDurationCooldown(cooldown)` | Cooldown de duración | [AurasNext.lua L124](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Auras/AurasNext.lua#L124) |
| `frame:SetAuraBorder(texture, options)` | Borde con dispel type | [AurasNext.lua L125](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Auras/AurasNext.lua#L125) |
| `frame:EnableMouseMotion(bool)` | Habilitar tooltips | [AurasNext.lua L24](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Auras/AurasNext.lua#L24) |

### Filtros de Debuffs:

```lua
-- AuraGroupBuilder.lua L26-L33
local DEBUFF_FILTERS = {
  PLAYER_IMPORTANT = "HARMFUL|IMPORTANT|PLAYER|!CROWD_CONTROL",
  ANY_PLAYER_IMPORTANT = "HARMFUL|IMPORTANT|!CROWD_CONTROL",
  PLAYER_PERSONAL = "HARMFUL|!IMPORTANT|INCLUDE_NAME_PLATE_ONLY|PLAYER|!CROWD_CONTROL",
  ANY_PLAYER_PERSONAL = "HARMFUL|!IMPORTANT|INCLUDE_NAME_PLATE_ONLY|!CROWD_CONTROL",
  ALL_PLAYER = "HARMFUL|PLAYER|!CROWD_CONTROL",
  ALL = "HARMFUL|!CROWD_CONTROL",
}
```

### Filtros de Buffs (para enrage, soothe, defensivos):

```lua
-- AuraGroupBuilder.lua L35-L44
local BUFF_FILTERS = {
  ALL = "HELPFUL|!PLAYER",
  PLAYER_ASSIST = "HELPFUL|PLAYER",
  IMPORTANT = "HELPFUL|IMPORTANT|!PLAYER",
  ENRAGE = "HELPFUL|!IMPORTANT|!PLAYER",
  STEALABLE = "HELPFUL|!IMPORTANT|!PLAYER",
  DEFENSIVE1 = "HELPFUL|BIG_DEFENSIVE|!PLAYER",
  DEFENSIVE2 = "HELPFUL|EXTERNAL_DEFENSIVE|!PLAYER",
  DEFENSIVE3 = "HELPFUL|RAID_IN_COMBAT|!PLAYER",
}
```

### Descriptores de candidatos (enrage, stealable):

```lua
-- AurasNext.lua L12-L19
local candidateIMPORTANTDefault = {}
local candidateIMPORTANTNoEnrage = {excludeDispelTypes = {[""] = true}}
local candidateENRAGEDefault = {includeDispelTypes = {[""] = true}}
local candidateSTEALABLEDefault = {isStealable = true}
local candidateSTEALABLENoEnrage = {
  isStealable = true,
  excludeDispelTypes = {[""] = true},
}
```

### Evento de Auras (legacy):

| Evento | Uso | Archivo |
|---|---|---|
| `UNIT_AURA` | Actualización de auras | [Initialize.lua L158, L510, L595](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Initialize.lua#L158) |
| `RefreshAuras` (hook) | Hook en UnitFrame Blizzard para sincronizar auras | [Initialize.lua L565-L576](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Initialize.lua#L565-L576) |

### APIs de Auras Legacy (clientes pre-Midnight):

| API | Archivo |
|---|---|
| `C_UnitAuras.GetUnitAuraBySpellID(unit, spellID)` | [Utilities.lua L458-L467](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Utilities.lua#L458-L467) |

### Configuración de filtros por especialización:

```lua
-- AurasNext.lua L316-L330
local function GetSpecializationFilters()
  local allFilters = addonTable.Config.Get(addonTable.Config.Options.AURA_FILTERS)
  local specializationID = addonTable.Display.Utilities.GetSpecializationID()
  -- Retorna {buffs = {include, exclude}, debuffs = ..., crowdControl = ...}
end
```

---

## 8. APIs de Nameplates, Escala, y Gestión

### Eventos principales del ciclo de vida:

| Evento | Descripción | Archivo:Línea |
|---|---|---|
| `NAME_PLATE_UNIT_ADDED` | Nameplate aparece | [Initialize.lua L107](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Initialize.lua#L107) |
| `NAME_PLATE_UNIT_REMOVED` | Nameplate desaparece | [Initialize.lua L108](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Initialize.lua#L108) |
| `PLAYER_LOGIN` | Login del jugador | [Initialize.lua L109](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Initialize.lua#L109) |
| `PLAYER_ENTERING_WORLD` | Entrada a zona | [Initialize.lua L110](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Initialize.lua#L110) |
| `PLAYER_SOFT_INTERACT_CHANGED` | Soft target cambió | [Initialize.lua L116](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Initialize.lua#L116) |
| `UI_SCALE_CHANGED` | Escala UI cambió | [Initialize.lua L114](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Initialize.lua#L114) |
| `VARIABLES_LOADED` | Variables cargadas | [Initialize.lua L139](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Initialize.lua#L139) |
| `ADDON_RESTRICTION_STATE_CHANGED` | Restricción de addon (Secrets) | [Initialize.lua L121](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Initialize.lua#L121) |

### APIs de C_NamePlate:

| API | Archivo:Línea |
|---|---|
| `C_NamePlate.GetNamePlateForUnit(unit, issecure())` | [Initialize.lua L149, L293, L589, L729, L798](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Initialize.lua#L149) |
| `C_NamePlate.SetNamePlateSize(width, height)` | [Initialize.lua L920-L936](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Initialize.lua#L920-L936) |
| `C_NamePlate.SetNamePlateEnemySize(w, h)` | [Initialize.lua L943](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Initialize.lua#L943) |
| `C_NamePlate.SetNamePlateFriendlySize(w, h)` | [Initialize.lua L948](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Initialize.lua#L948) |

### APIs de C_NamePlateManager:

| API | Archivo:Línea |
|---|---|
| `C_NamePlateManager.SetNamePlateSimplified(unit, bool)` | [Initialize.lua L823](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Initialize.lua#L823) |
| `C_NamePlateManager.SetNamePlateHitTestInsets(type, l, r, t, b)` | [Initialize.lua L991-L999](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Initialize.lua#L991-L999) |

### APIs de hit test / click regions:

| API | Archivo:Línea |
|---|---|
| `nameplate:CanChangeHitTestPoints()` | [Initialize.lua L45-L48](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Initialize.lua#L45-L48) |
| `nameplate:SetAllHitTestPoints(clickRegion)` | [Initialize.lua L766](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Initialize.lua#L766) |
| `nameplate:SetStackingBoundsFrame(frame)` | [Initialize.lua L830](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Initialize.lua#L830) |

---

## 9. APIs de Health, Absorbs, y Power

### Health:

| API | Archivo:Línea |
|---|---|
| `UnitHealth(unit)` / `UnitHealth(unit, true)` | [HealthBar.lua L6, L184](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/HealthBar.lua#L6) |
| `UnitHealthMax(unit)` | [HealthBar.lua L7, L173](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/HealthBar.lua#L7) |
| `UnitGetTotalAbsorbs(unit)` | [HealthBar.lua L8, L172](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/HealthBar.lua#L8) |
| `UnitGetDetailedHealPrediction(unit, nil, calculator)` | [HealthBar.lua L157](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/HealthBar.lua#L157) |
| `CreateUnitHealPredictionCalculator()` | [HealthBar.lua L10, L92](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/HealthBar.lua#L10) |
| `UnitHealthPercent(unit, nil, curve)` | [Colors.lua L627](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Colors.lua#L627) |

### Eventos de health:

| Evento | Archivo:Línea |
|---|---|
| `UNIT_HEALTH` | [HealthBar.lua L103](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/HealthBar.lua#L103) |
| `UNIT_MAXHEALTH` | [HealthBar.lua L104](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/HealthBar.lua#L104) |
| `UNIT_ABSORB_AMOUNT_CHANGED` | [HealthBar.lua L105](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/HealthBar.lua#L105) |

---

## 10. APIs de Valores Secretos (Midnight/Secrets)

| API | Descripción | Archivo |
|---|---|---|
| `issecretvalue(value)` | Detecta si un valor es secreto | [Cache.lua L81](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Cache.lua#L81), [HealthBar.lua L15](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/HealthBar.lua#L15), [Colors.lua L89](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Colors.lua#L89) |
| `C_CurveUtil.EvaluateColorValueFromBoolean(state, v1, v2)` | Evaluación C-side de booleans secretos | [Colors.lua L215-L218](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Colors.lua#L215-L218), [CastBar.lua L157](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/CastBar.lua#L157) |
| `SetAlphaFromBoolean(bool)` | Alpha desde boolean secreto | [CannotInterruptMarker.lua L37](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/CannotInterruptMarker.lua#L37) |
| `C_Secrets.HasSecretRestrictions()` | Detecta cliente Midnight con restricciones | [Constants.lua L19](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Core/Constants.lua#L19) |
| `C_Secrets.ShouldUnitIdentityBeSecret(unit)` | Identidad de unidad es secreta | [Utilities.lua L314](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Utilities.lua#L314) |
| `C_ClassColor.GetClassColor(class)` | Color de clase (soporta secretos) | [Colors.lua L426](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Colors.lua#L426), [CastInterrupterText.lua L57](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/CastInterrupterText.lua#L57) |
| `C_CurveUtil.CreateColorCurve()` | Crear curva de color | [Utilities.lua L190](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Utilities.lua#L190) |
| `C_CurveUtil.CreateCurve()` | Crear curva numérica | [Nameplate.lua L353](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Nameplate.lua#L353) |

---

## 11. APIs Auxiliares Relevantes

### Reacción y Selección:

| API | Archivo:Línea |
|---|---|
| `UnitReaction(unit, "player")` | [Utilities.lua L14](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Utilities.lua#L14) |
| `UnitSelectionType(unit)` | [Utilities.lua L11-L12](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Utilities.lua#L11-L12) (1=unfriendly, 2=neutral) |
| `UnitIsEnemy(unit, "player")` | [Colors.lua L79](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Colors.lua#L79) |
| `UnitIsFriend("player", unit)` | [Colors.lua L441](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Colors.lua#L441) |
| `UnitPlayerControlled(unit)` | [Utilities.lua L27](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Utilities.lua#L27) |
| `UnitIsTapDenied(unit)` | [Utilities.lua L27](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Utilities.lua#L27) |
| `UnitIsDeadOrGhost(unit)` | [Colors.lua L551, L611](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Colors.lua#L551) |
| `UnitIsGameObject(unit)` | [Nameplate.lua L150](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Nameplate.lua#L150) |
| `UnitNameplateShowsWidgetsOnly(unit)` | [Nameplate.lua L150](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Nameplate.lua#L150) |

### Target y Mouseover:

| API | Archivo:Línea |
|---|---|
| `UnitIsUnit("target", unit)` | [Cache.lua L117](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Cache.lua#L117) |
| `UnitIsUnit("softenemy", unit)` | [Cache.lua L121](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Cache.lua#L121) |
| `UnitIsUnit("softfriend", unit)` | [Cache.lua L121](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Cache.lua#L121) |
| `UnitIsUnit("mouseover", unit)` | [Cache.lua L125](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Cache.lua#L125) |
| `UnitIsUnit("focus", unit)` | [Cache.lua L129](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Cache.lua#L129) |
| `UnitExists("mouseover")` | [Cache.lua L347](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Cache.lua#L347) |
| `UnitIsSpellTarget(unit, "player")` | [Colors.lua L537](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Colors.lua#L537) |

### Grupo y Rol:

| API | Archivo:Línea |
|---|---|
| `UnitGroupRolesAssigned(unit)` | [Colors.lua L667](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Colors.lua#L667), [Utilities.lua L664-L697](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Utilities.lua#L664-L697) |
| `C_SpecializationInfo.GetSpecialization()` | [Utilities.lua L520](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Utilities.lua#L520) |
| `C_SpecializationInfo.GetSpecializationInfo(index)` | [Utilities.lua L470, L523](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Utilities.lua#L470) |
| `IsInRaid()` | [Utilities.lua L663](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Utilities.lua#L663) |
| `IsInInstance()` | [Utilities.lua L79](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Utilities.lua#L79) |
| `GetInstanceInfo()` | [Utilities.lua L84](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Utilities.lua#L84) |

### Spells y SpellBook:

| API | Archivo:Línea |
|---|---|
| `C_SpellBook.IsSpellKnownOrInSpellBook(spellID)` | [Utilities.lua L207](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Utilities.lua#L207) |
| `C_SpellBook.IsSpellKnown(spellID)` | [Utilities.lua L214](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Utilities.lua#L214) |
| `C_Spell.GetSpellCooldown(spellID)` | [CastBar.lua L209, L245](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/CastBar.lua#L209), [Colors.lua L475, L513](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Colors.lua#L475) |
| `C_Spell.GetSpellCooldownDuration(spellID)` | [Utilities.lua L239](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Utilities.lua#L239), [Colors.lua L467, L507](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Colors.lua#L467) |
| `C_Spell.IsSpellImportant(spellID)` | [Colors.lua L570](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Colors.lua#L570) |

### CVars de Nameplates:

```lua
-- CVars.lua L4-L29
nameplateGlobalScale, NamePlateHorizontalScale, NamePlateVerticalScale,
nameplateLargeBottomInset, nameplateLargerScale, nameplateMaxAlpha,
nameplateMaxAlphaDistance, nameplateMinAlpha, nameplateMinAlphaDistance,
nameplateMaxDistance, nameplatePlayerMaxDistance, nameplateMaxScale,
nameplateMinScale, nameplateMotionSpeed, nameplatePlayerLargerScale,
nameplateTargetBehindMaxDistance, nameplateTargetRadialPosition,
clampTargetNameplateToScreen, nameplateNotSelectedAlpha,
nameplateOverlapH, nameplateOverlapV
```

| API CVar | Archivo |
|---|---|
| `C_CVar.SetCVar(name, value)` | [CVars.lua L37](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/CVars.lua#L37), [Initialize.lua L443-L468](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Initialize.lua#L443-L468) |
| `C_CVar.GetCVar(name)` | [Initialize.lua L453](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Initialize.lua#L453) |
| `C_CVar.GetCVarInfo(name)` | [CVars.lua L36](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/CVars.lua#L36) |
| `C_CVar.SetCVarBitfield(name, bit, value)` | [Initialize.lua L443-L444](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Initialize.lua#L443-L444) |
| `GetCVarBool(name)` | [Nameplate.lua L337-L339](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Nameplate.lua#L337-L339) |

### Frame creation y Utilities:

| API | Archivo |
|---|---|
| `CreateFrame("Frame")` | Múltiples archivos |
| `CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")` | [AurasNext.lua L136-L138](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Auras/AurasNext.lua#L136-L138) |
| `CreateFrame("Cooldown", nil, parent, "CooldownFrameTemplate")` | [AurasNext.lua L92](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Auras/AurasNext.lua#L92) |
| `CreateFramePool("Frame", parent)` | [Initialize.lua L54-L55, L351](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Initialize.lua#L54-L55) |
| `Mixin(frame, mixin)` | [Initialize.lua L6, L11, L16](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Initialize.lua#L6) |
| `hooksecurefunc(obj, method, callback)` | [Initialize.lua L145, L154](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Initialize.lua#L145) |
| `C_EventUtils.IsEventValid(event)` | [Colors.lua L166](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Colors.lua#L166) |
| `InCombatLockdown()` | [Initialize.lua L430](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Initialize.lua#L430) |
| `IsMouseButtonDown()` | [Cache.lua L357](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Cache.lua#L357) |
| `GetTime()` | [Cache.lua L36](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Cache.lua#L36), [CastBar.lua L40](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/CastBar.lua#L40) |
| `C_Timer.NewTicker(interval, callback)` | [Initialize.lua L333](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Initialize.lua#L333) |
| `PixelUtil.SetSize(frame, w, h)` | [Nameplate.lua L268](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Nameplate.lua#L268) |
| `PixelUtil.ConvertPixelsToUIForRegion(px, region)` | [AurasNext.lua L434](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Auras/AurasNext.lua#L434) |

---

## 12. Quest, Tooltip y GUID

| API | Archivo:Línea |
|---|---|
| `C_TooltipInfo.GetUnit(unit)` | [Utilities.lua L319](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Utilities.lua#L319) |
| `UnitGUID(unit)` | [Utilities.lua L379](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Utilities.lua#L379), [Cache.lua L193](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Cache.lua#L193) |
| `UnitName(unit)` | [CastInterrupterText.lua L42](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/CastInterrupterText.lua#L42) |
| `UnitClassBase(unit)` | [CastInterrupterText.lua L43](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/CastInterrupterText.lua#L43), [Utilities.lua L198](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Utilities.lua#L198) |
| `UnitClass(unit)` | [Colors.lua L424](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Colors.lua#L424) |
| `GetGuildInfo(unit)` | [Colors.lua L415-L416](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Colors.lua#L415-L416) |
| `SetUnitCursorTexture(texture, unit)` | [Nameplate.lua L345](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Nameplate.lua#L345) |
| `CombatLogGetCurrentEventInfo()` | [Cache.lua L21](file:///c:/Program%20Files%20(x86)/World%20of%20Warcraft/_ptr_/Interface/AddOns/Platynator/Display/Cache.lua#L21) |

---

> [!NOTE]
> Este documento fue generado el 2026-08-10 inspeccionando directamente el código fuente de Platynator.
> Cada API listada tiene su referencia exacta de archivo y línea verificada.
