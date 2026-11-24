# Nivel de chasis

> La XP total del robot determina su nivel de chasis (hasta el último de la tabla) y cada nivel fija cuántas ranuras
> tiene su inventario. El nivel se calcula, no se guarda.
> Specs: [014](../../specs/014-chassis-level/spec.md) (sobre [007](../../specs/007-melee-combat/spec.md) y
> [005](../../specs/005-inventory/spec.md)) · Última actualización: spec 014

## Piezas

| Pieza | Tipo | Archivo | Responsabilidad |
|---|---|---|---|
| `ChassisLevelSystem` | Sistema puro (`RefCounted`, estático) | `game/scripts/systems/chassis_level_system.gd` | `level_for_xp(total, tabla)` y `xp_to_next_level(total, tabla)`; la tabla entra por parámetro |
| `ChassisLevelData` | Recurso | `game/scripts/data/chassis_level_data.gd` | `xp_required` e `inventory_slots` por nivel; `get_xp_required`, `get_inventory_slots`, `get_level_count`, `validate()` |
| `chassis_levels.tres` | `.tres` | `game/resources/progression/chassis_levels.tres` | La tabla real |
| `ExperienceComponent` | Componente | `game/scripts/components/experience_component.gd` | Dueño de la XP **y** del nivel: `set_level_table`, `get_level`, señales `level_changed` y `level_up` |
| `Robot` | Escena (cableado) | `game/scenes/entities/robot.gd`, `robot.tscn` | Pasa la tabla al componente y amplía el inventario en cada `level_changed` |
| `DebugHud` | Escena | `game/scenes/ui/debug_hud.gd`, `.tscn` | `%LevelLabel` ("Level: n") y `%LevelUpButton` ("Level up"), solo en builds de depuración |

## Cómo funciona

1. `Robot._ready()` llama a `experience.set_level_table(chassis_levels)`, conecta `experience.level_changed` a
   `_on_level_changed` y lo llama una vez con el nivel actual. `_on_level_changed` hace
   `inventory.set_slot_count(chassis_levels.get_inventory_slots(level))`; con el mismo número de ranuras no cambia nada.
2. **Ganar XP.** `add_xp(n)` suma y emite `xp_changed`; si `ChassisLevelSystem.level_for_xp` da un nivel mayor, emite
   `level_changed(nivel)` y después `level_up(nivel)`, una vez de cada, con el nivel final aunque se crucen varios
   umbrales. Quien escuche `level_up` ya ve las ranuras nuevas.
3. **El nivel no baja.** `reset()` o `from_save_data()` con un total menor cambian la XP pero dejan nivel y ranuras, con
   `push_error`. `set_level_table` solo puede subir el nivel.
4. **Cargar.** `from_save_data` guarda el total y emite `xp_changed` y `level_changed` (también si no cambiaron),
   nunca `level_up`. Solo se guarda `{"total": n}`; el nivel y las ranuras se recalculan.
5. **Orden de carga (invariante).** `SaveManager._apply_world` aplica las partes en el orden del árbol del grupo
   `persistent`. En `robot.tscn` el nodo `Experience` va **antes** que `InventoryComponent`: así, cuando el inventario
   lee sus ranuras guardadas ya tiene las del nivel cargado y no pierde las pilas de las ranuras de más
   ([save.md](save.md)). Reordenar los hijos del robot rompe esto.
6. **Depuración.** `DebugHud.bind` sigue `level_changed`; "Level up" llama a `level_up_player()`, que hace
   `add_xp(ChassisLevelSystem.xp_to_next_level(total, tabla))` (0 en el último nivel, `add_xp(0)` no hace nada).

```
add_xp -> xp_changed -> level_changed -> Robot._on_level_changed -> inventory.set_slot_count -> level_up
carga  -> xp_changed -> level_changed                                (sin level_up)
```

## Datos

| Recurso | Clase | Valores desde |
|---|---|---|
| `chassis_levels.tres` | `ChassisLevelData` | [BALANCE.md §6.1](../../BALANCE.md) (umbrales 6-10 provisionales; cambiarlos solo toca el `.tres`) |
| `scrap.tres`, `cables.tres`, `iron.tres` (`stack_max`) | `ItemData` | [BALANCE.md §2](../../BALANCE.md); solo datos, sin código nuevo |

`validate()` exige: al menos un nivel, mismo tamaño en ambos arrays, primer umbral 0, umbrales estrictamente crecientes
y ranuras **no decrecientes** (pueden repetirse).

## Decisiones

| Decisión | Por qué | Fuente |
|---|---|---|
| El nivel vive en `ExperienceComponent`, no en un componente nuevo | Solo el dueño de la XP distingue una ganancia (`level_up`) de una carga (sin `level_up`) | [plan 014 D1](../../specs/014-chassis-level/plan.md), R-014-06, R-014-17 |
| `ChassisLevelSystem` puro con la tabla por parámetro | Testeable con tablas a mano y sin número de niveles en el código | plan 014 D2, R-014-01, R-014-03 |
| `Robot` une XP e inventario; `ExperienceComponent` no conoce el inventario | Los componentes hermanos no se llaman entre sí | plan 014 D3 |
| Orden de señales `xp_changed`, `level_changed`, `level_up` | El inventario ya ha crecido cuando alguien reacciona a `level_up` | plan 014 D4, R-014-07 |
| Se guarda solo la XP | Un cambio de umbrales se aplica a los mundos existentes y no sube `schema_version` | R-014-15, [spec 014 pregunta 1](../../specs/014-chassis-level/spec.md) |
| `Experience` antes que `InventoryComponent` en la escena, sin prioridad de carga explícita | Cambio mínimo; la prioridad en el contrato `persistent` se añadiría con una segunda dependencia | plan 014 D5, [architecture §10.2](../../specs/architecture.md) |
| El nivel nunca baja | Ningún ruleset del PMV baja la XP; el que lo haga decidirá la regla | R-014-11, plan 014 D6 |
| Ranuras no decrecientes en la validación | BALANCE §6.1 repite ranuras entre niveles | plan 014 D8 |
| `level_up` es señal local del componente, no del `EventBus` | El evento lo añade la spec que lo necesite, con `player_uid` | spec 014 pregunta 3, [architecture §7](../../specs/architecture.md) |
| Debug HUD sin traducir | Solo depuración, no es texto del jugador | plan 014 D10 |

## Relación con otros sistemas

- Usa: [inventory.md](inventory.md) (`set_slot_count`), [save.md](save.md) (contrato `persistent`).
- Lo usan: [combat.md](combat.md) (la XP por muerte), [death.md](death.md) (`keeps_xp` conserva nivel y ranuras),
  [ui.md](ui.md) (debug HUD y pantallas, que se repintan con `inventory_changed`).

## Trampas y límites

- No hay notificación, sonido ni número de nivel en el HUD de juego (ACTION_PLAN 4.1, 4.3), ni recuerdos ni efecto del
  nivel salvo las ranuras (spec 017).
- Sin tabla o con una no válida, la XP se acumula y el nivel se queda en 1 con `push_error`.
- Si una XP guardada baja de verdad, el nivel recalculado al cargar será menor y se perderían las pilas de las ranuras
  de más; ningún ruleset del PMV lo provoca ([plan 014 §7](../../specs/014-chassis-level/plan.md)).
- Bajar `stack_max` de los materiales no migra guardados: las pilas por encima del máximo nuevo se pierden (spec 014
  pregunta 10).
- Discrepancias código vs spec/plan: ninguna.

## Cómo extenderlo

- Más niveles o cambiar umbrales y ranuras: solo `chassis_levels.tres` (con BALANCE §6.1 primero).
- Reaccionar a una subida (notificación, sonido, recuerdos): conectar `robot.experience.level_up`; para estado
  derivado, `level_changed`.

## Tests

| Archivo | Verifica |
|---|---|
| `tests/unit/test_chassis_level_system.gd` | Nivel por XP acumulada, tope, entradas inválidas, `xp_to_next_level`, nivel desde la tabla |
| `tests/unit/test_chassis_level_data.gd` | Tabla frente a BALANCE, primer umbral 0, ranuras iguales válidas |
| `tests/unit/test_experience_component.gd` | `level_up` y `level_changed`, varios niveles, nivel que no baja, carga sin `level_up`, solo `total` guardado |
| `tests/integration/test_robot_inventory.gd` | Ranuras que crecen conservando pilas, mismo número no cambia nada |
| `tests/integration/test_save_load.gd` | Nivel recalculado, pilas de ranuras 6-8 se cargan, `Experience` antes que `InventoryComponent` |
| `tests/integration/test_death_controller.gd` | La muerte conserva nivel y ranuras |
| `tests/unit/test_debug_hud.gd` | Etiqueta de nivel y botón "Level up" |
| `tests/unit/test_inventory_screen.gd`, `test_container_screen.gd` | Ranuras nuevas con la pantalla abierta; 8 ranuras caben en 1920x1080 |
| `tests/unit/test_data_catalog.gd` | `stack_max` de materiales; toda receta y reparación cabe en una pila |
