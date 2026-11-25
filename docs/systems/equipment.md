# Equipo, desgaste y rotura

> El robot lleva tres ranuras (Brazos, Piernas, Core). Las piezas equipadas dan los stats ([stats.md](stats.md)), se
> desgastan con cada golpe recibido hasta romperse, se reparan en el banco y se equipan desde la pantalla de inventario.
> Specs: [015](../../specs/015-pieces-slots-degradation/spec.md) · Última actualización: spec 015

## Piezas

| Pieza | Tipo | Archivo | Responsabilidad |
|---|---|---|---|
| `EquipmentComponent` | Componente (`Node`, hijo del robot, grupo `persistent`) | `game/scripts/components/equipment_component.gd` | Dueño de las tres ranuras (`ItemStack` con `uid` y durabilidad); equipar, quitar, desgaste, rotura, `take_slots`, `repair`, guardado |
| `DegradationSystem` | Sistema puro (`RefCounted`, estático) | `game/scripts/systems/degradation_system.gd` | `target_slot(pieces)` (orden `WEAR_ORDER`: brazos, piernas, core) y `durability_after_hit(durability, wear)` |
| `PieceData` | Resource | `game/scripts/data/piece_data.gd` | Gana `SlotType` (`ARMS`, `LEGS`, `CORE`), `slot_type` y `modifiers` |
| `InventoryComponent.exchange_slot` | Método | `game/scripts/components/inventory_component.gd` | El inventario escribe su propia ranura al equipar |
| `Robot.equip` / `unequip` | Métodos | `game/scenes/entities/robot.gd` | Rechazan con la batería agotada y delegan en el equipo con su inventario; es lo único que llama la pantalla |
| `DurabilityDisplayData` | Resource | `game/scripts/data/durability_display_data.gd` | `band_of(durability, maximum)` devuelve `GREEN`, `YELLOW` o `RED` |
| `EquipmentPanel` | `PanelContainer` | `game/scenes/ui/equipment_panel.gd`, `.tscn` | Dos columnas: las tres celdas (icono, nombre o "sin pieza", barra) y la lista de stats; emite `slot_pressed` |
| `InventoryScreen` | `UIScreen` | `game/scenes/ui/inventory_screen.gd` | Dueña de la selección y de "Equipar" / "Quitar" ([inventory.md](inventory.md)) |
| `Hud` | Escena | `game/scenes/ui/hud.gd` | Aviso "Pieza rota" con `piece_broken` |

## Cómo funciona

**Equipar y quitar.**
1. La pantalla llama `Robot.equip(slot_index)` o `Robot.unequip(slot)`. Con la batería agotada: `ERR_INVALID_REQUEST`.
2. `equip_from` copia la pila de esa ranura y la valida contra el catálogo (`PieceData` y `is_valid_stack`; si no,
   `ERR_NOT_A_PIECE`). **Escribe primero su ranura sin emitir**, después pide `inventory.exchange_slot(índice, lo
   que estaba equipado o null)`; si el inventario rechaza, restaura su ranura y devuelve ese rechazo. Si no, emite
   `equipment_changed`. Orden de señales: `inventory_changed` y después `equipment_changed`, y quien escucha la primera
   ya ve el equipo final.
3. `unequip_to` rechaza con `ERR_SLOT_EMPTY` o `ERR_NO_FREE_SLOT` sin cambiar nada; si no, vacía la ranura, añade la pieza
   con `add_stacks` (primera ranura libre) y emite `equipment_changed`.
4. `Robot` recalcula los stats con cada `equipment_changed` ([stats.md](stats.md)).

**Desgaste y rotura.**
1. `Robot.receive_hit` (con batería) llama `equipment.apply_hit_wear(stat de desgaste)` **antes** de `battery.consume`: un
   golpe que vacía la batería desgasta (o rompe) la primera pieza del orden, nunca el Core en su lugar.
2. `apply_hit_wear` pide `DegradationSystem.target_slot` (sin piezas, nada) y `durability_after_hit` (entero, redondeado,
   nunca negativo). Si queda durabilidad: `durability_changed(slot, durability)`.
3. Si llega a 0 o menos, la ranura se vacía y se pierde (ni inventario ni suelo), `equipment_changed` y después
   `piece_broken(uid, slot, piece)`. El sobrante no pasa a la pieza siguiente. El `PieceData` viaja en la señal porque la
   pieza ya no existe.
4. `Hud._on_piece_broken` muestra `MSG_PIECE_BROKEN` con el nombre de la pieza, por el mensaje corto del HUD.

**Muerte.** `DeathController` toma brazos y piernas (y el Core si el ruleset no lo conserva) y los entrega al objeto caído;
solo si se creó llama a `take_slots` ([death.md](death.md)).

**Reparar lo equipado.**
1. `BenchRepairSection.refresh()` lista primero las piezas equipadas dañadas con la marca `BENCH_EQUIPPED`, y después las
   del inventario. Para las equipadas, el bloqueo y la pulsación usan `CraftingSystem.check_repair_stack(pieza, ranuras del
   inventario, costes)`.
2. `RepairBench.repair` mira el `uid`: si lo tiene el equipo, `equipment.repair(uid, inventory, costes)`; si no,
   `inventory.repair` como antes. Emite `EventBus.piece_repaired` en ambos casos ([crafting.md](crafting.md)).
3. `EquipmentComponent.repair` comprueba, **pone primero la durabilidad máxima sin emitir**, pide `payer.remove_many`,
   restaura si falla y emite `durability_changed`. La pieza sigue equipada con su `uid`.
4. `BenchScreen` también refresca con `equipment_changed` y `durability_changed` y los desconecta en `on_closed`.

**Pantalla de equipo.** `InventoryScreen.setup` enlaza el `EquipmentPanel` con `robot.equipment` y `robot.stats`. El panel
sigue `equipment_changed`, `durability_changed` y `stats_changed` sin `_process`; pinta cada barra con
`DurabilityDisplayData.band_of` (el rojo es el primer tramo de `repair_costs`) y los colores (`band_colors`) son de la
escena. La pantalla elige entre una ranura del inventario o una del equipo, nunca las dos.

**Guardado y mundo nuevo.** `Equipment` es el primer nodo `persistent` de `robot.tscn`, antes de `BatteryComponent`: al
cargar, la batería ya tiene la máxima del Core guardado ([save.md](save.md)). `_ready()` pone `starting_pieces` (Core y
Piernas básicos, `CraftingSystem.create_result`): es el estado de partida nueva y de un Mundo sin parte `equipment`.
`to_save_data` guarda `{"slots": {"arms"|"legs"|"core": {item_id, durability, uid} o null}}`. `from_save_data` reemplaza las
tres ranuras, una entrada mala carga vacía con `push_error`, y emite solo `equipment_changed` (nunca `piece_broken`).

## Datos

| Recurso | Clase | Valores en BALANCE |
|---|---|---|
| `resources/pieces/basic_arms.tres`, `basic_legs.tres`, `basic_core.tres` | `PieceData` (`slot_type`, `modifiers`) | [§4.2](../../BALANCE.md), durabilidad en §4.1 |
| `resources/robot/robot_base_stats.tres` | `RobotBaseStatsData` | `durability_per_hit`: [§4.1](../../BALANCE.md) |
| `resources/config/durability_display.tres` | `DurabilityDisplayData` | [§4.1](../../BALANCE.md) "Color de la durabilidad", §4.3.2 |
| `EquipmentComponent.starting_pieces` en `robot.tscn` | Lista de `PieceData` | [§4.2](../../BALANCE.md) "Equipo inicial" |

## Decisiones

| Decisión | Por qué | Fuente |
|---|---|---|
| Equipar escribe cada dueño lo suyo (`exchange_slot`) | No ampliar la excepción de `move_to_slot`; el rechazo es un `ActionResult` | [plan 015 D7](../../specs/015-pieces-slots-degradation/plan.md) |
| Equipar y quitar pasan por `Robot` | El equipo no conoce la batería y la pantalla solo pide | [plan 015 D8](../../specs/015-pieces-slots-degradation/plan.md), R-015-12 |
| El desgaste se aplica antes de restar la batería | El golpe mortal desgasta los brazos, no el Core | R-015-54, [spec 015 pregunta 16](../../specs/015-pieces-slots-degradation/spec.md) |
| `piece_broken` es una señal del componente, no del `EventBus` | "En el robot" es un componente de la entidad | [plan 015 D10](../../specs/015-pieces-slots-degradation/plan.md) |
| Pieza rota: se pierde | Una pieza a 0 no se queda en el inventario | R-015-23 |
| Reparar lo equipado reutiliza `check_repair_stack` | Una sola regla de reparación | [plan 015 D16](../../specs/015-pieces-slots-degradation/plan.md) |
| Panel dentro de la pantalla de inventario, dentro de su panel único | Un toque entre rejilla y panel no cuenta como "fuera" | [plan 015 D17](../../specs/015-pieces-slots-degradation/plan.md) |
| Umbral rojo derivado del primer tramo de reparación | El 25 vive en un solo `.tres` | [plan 015 D18](../../specs/015-pieces-slots-degradation/plan.md) |
| Sin momento de guardado nuevo al equipar o romper | Pregunta cerrada | [spec 015 pregunta 8](../../specs/015-pieces-slots-degradation/spec.md) |
| Sin `schema_version` nueva: un Mundo viejo carga con el equipo inicial | Campo opcional | R-015-42, [plan 015 D20](../../specs/015-pieces-slots-degradation/plan.md) |

## Relación con otros sistemas

Usa [inventory.md](inventory.md) (`exchange_slot`, `add_stacks`, `remove_many`), [crafting.md](crafting.md)
(`check_repair_stack`, `create_result`) y [stats.md](stats.md). Lo usan [death.md](death.md), [crafting.md](crafting.md)
(banco), [ui.md](ui.md), [save.md](save.md) y [battery.md](battery.md) (la máxima la da el Core).

## Trampas y límites

- Reordenar `robot.tscn` y poner la batería antes del equipo hace que una carga guardada sobre la máxima sin Core se
  quede pendiente y se pierda; lo cubre `test_save_load.gd`.
- `get_piece` y `get_pieces` devuelven copias: cambiarlas no cambia el equipo.
- `take_slots` quita sin comprobar adónde van las piezas: quien lo llama (la muerte) debe haber creado antes su destino.
- `InventoryScreen` muestra el rechazo con `String(result.error_key)` en un `Label` que traduce solo; depende de
  `auto_translate_mode` por defecto.
- Sin Core el robot sigue vivo y gasta el consumo "Sin Core"; sin brazos pega con un brazo, sin piernas no corre.
- Sin estado de piezas en el HUD de juego, SFX ni modelo visible (ACTION_PLAN 4.x); "Pieza rota" y la muerte en el mismo
  golpe: la transferencia tapa el aviso (aceptado, [plan 015 §7](../../specs/015-pieces-slots-degradation/plan.md)).

## Cómo extenderlo

- Pieza nueva: `PieceData` con `slot_type`, `modifiers` y su receta; stats en [stats.md](stats.md).
- Otro orden o regla de desgaste: `DegradationSystem` (BALANCE §4.1 primero).
- Otra ranura: `PieceData.SlotType` (al final), `_SLOT_KEYS`, `WEAR_ORDER`, y su celda en `equipment_panel.tscn`.

## Tests

| Archivo | Verifica |
|---|---|
| `tests/unit/test_equipment_component.gd` | Tres ranuras, equipar, cambiar, quitar, rechazos, orden de señales, desgaste, rotura, `take_slots`, reparar, guardado y carga con entradas malas |
| `tests/unit/test_degradation_system.gd` | Orden brazos-piernas-core, redondeo, sin piezas |
| `tests/unit/test_inventory_component.gd` | `exchange_slot` (válida, `null`, índice malo, pila inválida) |
| `tests/unit/test_durability_display_data.gd` | Bandas y rojo derivado del primer tramo |
| `tests/unit/test_inventory_screen.gd` | Tres celdas, "Equipar" / "Quitar", rechazos, barra viva, ficha de durabilidad, cabe en 1920x1080 |
| `tests/unit/test_bench_screen.gd`, `test_repair_bench.gd`, `test_crafting_system.gd` | Reparar lo equipado, eventos, `check_repair_stack` |
| `tests/unit/test_hud.gd` | Aviso "Pieza rota", barra naranja |
| `tests/integration/test_robot_equipment.gd` | Stats por piezas, desgaste antes de la batería, robot sin batería no se desgasta, rotura |
| `tests/integration/test_save_load.gd` | Equipo antes de batería, Mundo viejo con equipo inicial, ranuras vacías |
