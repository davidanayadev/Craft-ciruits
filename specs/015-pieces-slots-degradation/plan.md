# Plan 015 — Piezas, ranuras y degradación

| Campo | Valor |
|---|---|
| **Spec** | [spec.md](spec.md) (debe estar *Aprobado*) |
| **Estado** | Planificado (2026-11-24) |

## 1. Enfoque

Los stats del robot pasan a ser **datos más un cálculo puro** (architecture §9.4). Un recurso `RobotBaseStatsData`
(`robot_base_stats.tres`) tiene los valores del robot sin piezas, cada `PieceData` lleva su `slot_type` y su lista de
`StatModifier`, y `StatsCalculator` (puro) aplica `SET` → `ADD` → `MULTIPLY`. Dos componentes nuevos en el robot:
`EquipmentComponent` (dueño de las tres ranuras y de la durabilidad de lo equipado) y `StatsComponent` (dueño de los
stats calculados). `Robot`, como ya hace con el nivel (plan 014 D3), une los componentes: en cada `equipment_changed`
pide a `StatsComponent` que recalcule con los modificadores del equipo y, en cada `stats_changed`, entrega a
movimiento, ataque y batería los valores que leen. Ningún componente mira las piezas (R-015-14).

El desgaste vive en `EquipmentComponent` con la regla en un sistema puro, `DegradationSystem`; `Robot.receive_hit`
lo aplica **antes** de restar la batería (R-015-54). La muerte saca brazos y piernas del equipo y los mete en el mismo
objeto caído que el inventario. El objeto caído deja de recogerse de golpe: emite `opened` y un flujo nuevo,
`DroppedItemFlow` (como `StructureUseFlow`), lo abre en la pantalla de contenedor de la spec 013.

El panel de equipo es una escena nueva dentro de la pantalla de inventario; la pestaña Reparar del banco lista
también lo equipado. Los recursos sueltos de movimiento, ataque y batería que hacían de "pieza fija" desde las specs
002, 003 y 007 desaparecen: cada número de BALANCE §4.2 queda en un solo `.tres` (R-015-02).

**Alternativa principal descartada**: que batería, movimiento y ataque tengan una referencia a `StatsComponent` y lean
el stat en cada `tick` (modelo "pull"). Evita el cableado en `Robot`, pero hace que componentes hermanos se conozcan,
contra la regla que ya siguen batería, experiencia e inventario (P6, plan 014 D3), y obliga a cada componente a saber
qué ids de stat le tocan. Con "push" los componentes reciben valores tipados y siguen testeándose solos.

### 1.1 Decisiones del plan

| # | Decisión | Por qué |
|---|---|---|
| D1 | **Stats como datos.** `RobotBaseStatsData` con un campo `@export` por stat (`walk_speed`, `run_speed`, `walk_drain`, `run_drain`, `passive_drain`, `max_battery`, `attack_damage`, `attacks_per_second`, `battery_per_swing`, `durability_per_hit`) y `to_stats() -> Dictionary[StringName, float]` con las claves de `StatIds` (constantes, un archivo). `StatModifier` como en architecture §9.4. `PieceData` gana `slot_type: SlotType` (`ARMS`, `LEGS`, `CORE`) y `modifiers: Array[StatModifier]`. Los ids son los nombres de campo ya usados (`walk_speed`, no el `move_speed` de ejemplo de architecture §9.4, que se corrige). | R-015-01, R-015-02, R-015-06. Campos explícitos: tipados, visibles en el inspector y validables; un stat nuevo es un campo más. Un diccionario exportado aceptaría claves mal escritas sin aviso. |
| D2 | **Sin piernas no se corre** se expresa como `run_speed = 0` en la base: `can_run` deja de ser un dato y pasa a ser `run_speed > 0`, derivado al construir `MovementStatsData`. Las Piernas básicas hacen `SET run_speed 4.8`. | R-015-15, R-002-18. Un `MULTIPLY` futuro (spec 017) sobre 0 sigue en 0: sin piernas, sin correr. Evita un stat booleano 0/1. El 0 codifica "No puede correr" de BALANCE §4.2, no es un número de balance. |
| D3 | **Valores de cada pieza con `SET`** de toda su fila de BALANCE §4.2: Brazos básicos `attack_damage 10`, `attacks_per_second 1.0`, `battery_per_swing 1`; Piernas básicas `walk_speed 3.0`, `run_speed 4.8`, `walk_drain 0.05`; Core básico `max_battery 100`, `passive_drain 0.1`. La base tiene la fila "sin pieza" de cada ranura más `run_drain 0.15` (§1.1) y `durability_per_hit 5` (§4.1). | R-015-01, R-015-02: cada celda de la tabla vive en un solo `.tres` (la fila de la pieza en la pieza, la fila "sin" en la base). `SET` copia la tabla tal cual; un `ADD` (+5 de daño) escondería el 10 de BALANCE. Que dos filas tengan el mismo valor (1.0 golpe/s) no es un dato repetido: son dos celdas. |
| D4 | **Desaparecen** `resources/movement/basic_legs.tres`, `resources/combat/one_arm.tres`, `resources/combat/basic_arms.tres` y los campos `maximum`, `passive_drain` y `run_drain` de `BatteryConfigData` (que conserva `low_threshold_ratio`, que no es un stat). `MovementStatsData` y `AttackStatsData` siguen como **objetos de valor** que construye `StatsComponent` (sin `.tres`), así `LocomotionSystem` y `CombatSystem` no cambian de firma. `BatteryComponent` pierde `@export legs`. | R-015-02 (una sola copia), P14 (los sistemas puros no se tocan). |
| D5 | **Cableado "push" en `Robot`.** `_ready()`: conecta `equipment.equipment_changed` → `_on_equipment_changed` (llama a `stats.recompute(equipment.get_modifiers())`) y `stats.stats_changed` → `_apply_stats`, y los llama una vez (el equipo inicial ya está puesto, como `_on_level_changed` en la spec 014). `_apply_stats()`: `_movement = stats.get_movement()`, `melee.set_attack(stats.get_attack())`, `battery.set_drain_rates(passive, walk, run)` y `battery.set_base_maximum(max_battery)`. Después, `battery.recharge_full()` una vez en `_ready()` (un robot nuevo empieza lleno). | R-015-13, R-015-14. `BatteryComponent._ready()` ya no llena la carga: no conoce su máxima hasta que `Robot` se la da. El orden de `_ready` (hijos antes que el padre) lo garantiza. |
| D6 | **Máxima de la batería = stat + bonificación** dentro de `BatteryComponent`: `_maximum = _base_maximum + _maximum_bonus`. `set_base_maximum()` y `set_maximum_bonus()` comparten la regla de spec 012 en un solo método privado (`_apply_maximum`): la carga se queda salvo que supere la nueva máxima, un `battery_changed`, nunca `battery_low` ni `battery_depleted`, carga pendiente de la carga guardada (plan 012 D11). | R-015-18, R-015-19, pregunta 7. Una sola regla para los dos orígenes de la máxima (P2). |
| D7 | **`EquipmentComponent`** con tres ranuras indexadas por `PieceData.SlotType`. Equipar: `equip_from(inventory, slot_index)` lee la pila de esa ranura (`inventory.get_slots()`, una copia) y la valida (`PieceData`, `InventoryRules.is_valid_stack`). **Escribe primero su ranura sin emitir**, después pide al inventario `exchange_slot(slot_index, lo_que_estaba_equipado_o_null)`, un método nuevo en el que **el inventario escribe su propia ranura** y devuelve un `ActionResult`; si lo rechaza, el equipo **restaura** su ranura y devuelve ese rechazo sin emitir nada; si no, emite `equipment_changed`. Quitar: `unequip_to(inventory, slot)` comprueba que hay una ranura vacía (si no, `ERR_NO_FREE_SLOT`, sin cambios), vacía su ranura sin emitir, pide `inventory.add_stacks([pieza])` (una pieza ocupa la primera ranura vacía, `InventoryRules.add_stack`), restaura si falla y emite `equipment_changed` si no. Así, un oyente de `inventory_changed` ya ve el equipo final (nunca la misma pieza en los dos sitios) y el orden de señales es `inventory_changed` → `equipment_changed`. | R-015-07 a R-015-11. Cada dueño escribe solo su estado (architecture §3 regla 3) sin ampliar la excepción de `move_to_slot`. El rechazo de `exchange_slot` es un `ActionResult` (architecture §9.2), no un `null` que se confundiría con "la ranura estaba vacía" (revisión de `architecture-guardian`). Mismo criterio de "estado final antes de la señal" que `take_from` (`inventory_component.gd`). |
| D8 | **Equipar y quitar pasan por `Robot`**: `Robot.equip(slot_index)` y `Robot.unequip(slot)` rechazan con `ERR_INVALID_REQUEST` si la batería está vacía y si no delegan en el equipo con su inventario. La pantalla solo llama a esos dos métodos. | R-015-12 (robot muerto), architecture §3 regla 2. El equipo no conoce la batería. |
| D9 | **Desgaste.** `DegradationSystem` (estático): `target_slot(pieces) -> int` (primera ranura ocupada en el orden `WEAR_ORDER` = brazos, piernas, core; `NO_SLOT` si ninguna) y `durability_after_hit(durability, wear) -> int` (`durability - maxi(0, roundi(wear))`). `EquipmentComponent.apply_hit_wear(wear)` lo usa: si queda > 0, `durability_changed(slot, durability)`; si llega a ≤ 0, la ranura se vacía, `equipment_changed` y después `piece_broken`. `Robot.receive_hit` llama `equipment.apply_hit_wear(stats.get_stat(StatIds.DURABILITY_PER_HIT))` **antes** de `battery.consume(damage)`, y después del corte de batería vacía, así que un robot sin batería no se desgasta. | R-015-20 a R-015-23, R-015-53, R-015-54, pregunta 18. No se crea un `DegradationComponent` (architecture §6 lo nombra): no tendría estado propio, la durabilidad vive en las pilas del equipo; sería solo un cable. Se corrige el árbol de architecture §6 (D19). |
| D10 | **`piece_broken(piece_uid: String, slot: PieceData.SlotType, piece: PieceData)`** en `EquipmentComponent`, no en `EventBus`. Lleva además el `PieceData` roto porque el HUD tiene que nombrar una pieza que ya no existe (R-015-24). | Pregunta 9; "en el robot" es en un componente de la entidad, como `level_up` (plan 014 D1). El tercer argumento amplía la firma de la spec sin quitar nada. |
| D11 | **Golpe en curso.** `MeleeAttackComponent.set_attack(attack)` sustituye su `@export attack`. Al empezar un golpe guarda `_swing_attack = attack`; `set_attack` sin un golpe pendiente actualiza también `_swing_attack`, y con uno pendiente solo cambia `attack` (el ritmo y el siguiente golpe). `apply_impact` usa `_swing_attack`, así sigue funcionando llamado directamente sin golpe (tests de la spec 007). `_ready()` construye la forma con `config` solo, sin exigir un `attack` válido; `tick()` no hace nada sin uno. | R-015-16, R-015-17. |
| D12 | **Muerte.** `DeathController`, si el ruleset tiene `drops_inventory`, toma las ranuras que caen (brazos y piernas, y el Core si el ruleset no lo conserva, `keeps_core`), lee sus piezas con `equipment.get_piece()` (copias) y llama a `dropped_items.drop_inventory(robot.inventory, posición, piezas)`. **Solo si el objeto se creó** pide `equipment.take_slots(slots)`; si `drop_inventory` devuelve `null` (sin zona, pool o reloj), las piezas se quedan equipadas como hoy el inventario se queda en el robot (spec 008: nunca se crean ni se pierden objetos). El objeto se crea con **una ranura por pila recibida** (ranuras ocupadas del inventario + piezas) y no se crea si no hay nada (R-015-51). Sin `drops_inventory` no cae nada, tampoco del equipo. | R-015-25 a R-015-28, R-015-47, R-015-51. Se lee de los campos del ruleset, nunca del id (PMV §4.5 gancho 4). Ningún ruleset del PMV tiene `drops_inventory = false`. |
| D13 | **Objeto caído como contenedor.** `DroppedItem._on_interacted` ya no coge nada: emite `opened(item, opener)`; sigue interactuable mientras exista. `DroppedItemSpawner` reemite `item_opened(item, opener)` de sus objetos y emite `item_removed(item)` en `_release` (caducidad, descarga de zona, vaciado) después de sacarlo de su lista y **antes** de `reset()`. Gana `release_if_empty(item)` (diferido, con la comprobación de lista y `uid` de hoy) y pierde la señal `emptied` y `_on_item_emptied`. Un nodo nuevo, `DroppedItemFlow` (en `main.tscn`, como `StructureUseFlow`), abre la `ContainerScreen` con `Kind.DROPPED` para el jugador local y guarda el `UIScreen` que devuelve `open()`; llama a `release_if_empty` cuando esa pantalla emite `closed`, y si recibe `item_removed` del objeto abierto la cierra con un método público nuevo, `UIManager.close(screen)` (el `_close` que ya existe; nadie emite señales de otro nodo). | R-015-45 a R-015-50. Mismo patrón que cofres y cajas; el objeto no conoce la UI ni el pool. `Main` no crece. |
| D14 | `ContainerScreen.Kind` gana `DROPPED` (al final, los textos se indexan por valor, plan 013 D8): título `DROPPED_TITLE`, cabecera `CONTAINER_HEADER_DROPPED` ("Objeto caído %d/%d") y botón `CONTAINER_LEAVE_IN_DROPPED` ("← Dejar aquí"). El resto de la pantalla no cambia: "Coger todo", mover, colocar y dejar ya existen (R-013-20). El objeto caído pasa a ofrecer "Abrir" (`PROMPT_OPEN`, el de las cajas) en vez de "Recoger" en `dropped_item.tscn`; `PROMPT_PICK_UP` deja de usarse y se borra de `strings.csv` (los dos tests de `test_hud.gd` que lo usaban como clave cualquiera pasan a otra que existe). | R-015-45, R-015-46. "Abrir" y no "Recoger": interactuar abre una pantalla, como con una caja (decisión del usuario, 2026-11-24). |
| D15 | **Guardado del objeto caído.** `DroppedItem.to_data()` añade `"slot_count"`; `_restore` lo acepta si es un entero entre el número de pilas guardadas y `DroppedItemSpawner.MAX_RESTORED_SLOTS` (64: cota de cordura contra un archivo corrupto, muy por encima de lo que el juego crea, no un número de juego); si no, `push_error` y una ranura por pila (R-010-11). Sin el campo, una ranura por pila. Campo opcional: sin `schema_version` nueva. Un objeto vacío (pantalla abierta al guardar) no se restaura, como hoy: habría desaparecido al cerrar. | R-015-55, architecture §10.2. |
| D16 | **Reparar lo equipado.** `CraftingSystem.check_repair_stack(stack, payer_slots, costs)` sale de `check_repair` (que la llama tras buscar el `uid`), para que inventario y equipo usen la misma regla. `EquipmentComponent.repair(piece_uid, payer, costs)` comprueba con ella, **pone primero la durabilidad máxima sin emitir**, pide `payer.remove_many(coste)` (el inventario cobra), restaura si falla y emite `durability_changed` si no (mismo orden que D7). `RepairBench.repair` decide por el `uid`: si lo tiene el equipo, `equipment.repair`; si no, `inventory.repair` como hoy. `BenchRepairSection` lista primero lo equipado dañado, con la marca `BENCH_EQUIPPED`; en esas filas `set_blocked` y la comprobación al pulsar usan `check_repair_stack(pieza, slots del inventario, costes)`, no `check_repair` (que no encontraría el `uid`). `BenchScreen` refresca también con `equipment_changed` y `durability_changed` y los desconecta en `on_closed`. | R-015-29, R-015-30. DRY (P2): una regla de reparación. |
| D17 | **Panel de equipo** (`scenes/ui/equipment_panel.tscn`, `EquipmentPanel`) dentro de `inventory_screen.tscn`, a la derecha de la rejilla y **dentro del panel único de la pantalla** (el que tiene `mouse_filter = STOP`), así un toque entre la rejilla y el panel no cuenta como "fuera" (R-012-46): tres celdas (icono, nombre o estado "sin pieza", barra de durabilidad) y la lista de stats. `bind(equipment, stats)` (el `DurabilityDisplayData` es un `@export` de la escena) y escucha `equipment_changed`, `durability_changed` y `stats_changed`; emite `slot_pressed(slot)`. `InventoryScreen` es dueña de la selección (una ranura del inventario **o** una del equipo, nunca las dos), del botón `%EquipButton` ("Equipar" con una pieza seleccionada, "Quitar" con una ranura del equipo ocupada), de `%SelectedDetail` (durabilidad "72/100" con `BENCH_DURABILITY`) y de `%Notice` (rechazos). El contexto de la pantalla sigue siendo `CONTEXT_THROWER` (el `Robot`), sin renombrarlo (P14). | R-015-31 a R-015-35, R-015-52. Descartado: pantalla propia (pregunta 3). |
| D18 | **Colores.** Umbrales de durabilidad en un recurso nuevo `DurabilityDisplayData` (`resources/config/durability_display.tres`: `yellow_up_to_percent 50` y `repair_costs` → `repair_costs.tres`) con `band_of(durability, maximum) -> Band` (`GREEN`, `YELLOW`, `RED`), puro y testeable. El umbral rojo **se deriva**: es el `up_to_percent` del primer tramo de `repair_costs` (BALANCE §4.1: "el rojo coincide con el tramo muy dañada"), así el 25 vive en un solo `.tres` (P2). Batería baja: `BatteryComponent.is_low()` (misma regla que `battery_low`: carga < máxima × `low_threshold_ratio`) y `Hud._on_battery_changed` cambia el estilo `fill` de la barra. Los colores son presentación y viven en las escenas (`@export` de `Hud` y `EquipmentPanel`). | R-015-32, R-015-43. La barra sigue a `battery_changed`, señal de estado, así sale bien tras cargar, recargar o cambiar la máxima. |
| D19 | **Carga y mundo nuevo.** En `robot.tscn`, `Equipment` es el primer nodo del grupo `persistent` (antes de `BatteryComponent`), y `Stats` va junto a él (no es persistente). `EquipmentComponent._ready()` pone el equipo inicial (`@export starting_pieces: Array[PieceData]` en `robot.tscn` = Core básico y Piernas básicas, creados con `CraftingSystem.create_result`): es su estado de "partida nueva", que `SaveManager` deja si el Mundo no tiene la parte `equipment` (R-015-42, R-010-10). `from_save_data` reemplaza las tres ranuras, valida cada una con su `catalog` (como `InventoryComponent.catalog`: el de `DataRegistry` si se deja `null` en `_ready`, inyectable en tests) y emite solo `equipment_changed`. Clave `equipment`, formato `{"slots": {"arms": entrada o null, "legs": …, "core": …}}`, entrada `{"item_id", "durability", "uid"}`. | R-015-37 a R-015-42. Mismo patrón que el nivel (plan 014 D5). |
| D20 | Sin `schema_version` nueva, sin evento nuevo en `EventBus`, sin momento de guardado nuevo (preguntas 8, 9, 10). Se actualiza architecture: §6 (árbol del robot sin `DegradationComponent`), §7 (`equipment_changed`, `durability_changed` y `stats_changed` de estado; `piece_broken` de hecho; viven en `robot.equipment` y `robot.stats`), §9.1 (el objeto caído abre la pantalla de contenedor), §9.3 y §9.4 (ids reales, `slot_type`, cableado "push": batería, movimiento y combate **reciben** los valores de `StatsComponent`), §9.5 (`UIManager.close(screen)`) y §10.2 (segundo ejemplo de orden: `Equipment` antes que `BatteryComponent`). **Aprobado por el usuario el 2026-11-24** (documentos de producto y del repo): PMV.md §4.2 (árbol) y §4.3 (tabla de componentes) y CLAUDE.md dejan de nombrar `DegradationComponent` y nombran `EquipmentComponent` y `StatsComponent`; ACTION_PLAN.md Tarea 3.1 cambia los ids `attack_speed` / `move_speed` por los de D1. | P1, P6, constitución §5 (PMV es dueño de la arquitectura del código y manda sobre el plan). |

## 2. Archivos

| Archivo (`game/…`) | Nuevo / Cambia | Responsabilidad |
|---|---|---|
| `scripts/data/stat_ids.gd` | Nuevo | Constantes de ids de stat (D1) |
| `scripts/data/stat_modifier.gd` | Nuevo | `StatModifier` (architecture §9.4) |
| `scripts/data/robot_base_stats_data.gd` | Nuevo | Stats del robot sin piezas; `to_stats()` (D1) |
| `resources/robot/robot_base_stats.tres` | Nuevo | Valores de BALANCE §1.1, §4.1, §4.2 (§4) |
| `scripts/data/piece_data.gd` | Cambia | `SlotType`, `slot_type`, `modifiers` |
| `resources/pieces/basic_arms.tres`, `basic_legs.tres`, `basic_core.tres` | Cambia | `slot_type` y modificadores (D3) |
| `scripts/data/durability_display_data.gd`, `resources/config/durability_display.tres` | Nuevo | Umbrales de color y `band_of()` (D18) |
| `scripts/data/movement_stats_data.gd`, `attack_stats_data.gd` | Cambia (docstring) | Objetos de valor sin `.tres` (D4) |
| `scripts/data/battery_config_data.gd`, `resources/battery/robot_battery.tres` | Cambia | Solo `low_threshold_ratio` (D4) |
| `resources/movement/basic_legs.tres`, `resources/combat/one_arm.tres`, `resources/combat/basic_arms.tres` | Se borran | Sustituidos por la base y las piezas (D4) |
| `scripts/systems/stats_calculator.gd` | Nuevo | `SET` → `ADD` → `MULTIPLY` (R-015-03, R-015-04) |
| `scripts/systems/degradation_system.gd` | Nuevo | Pieza que se desgasta y durabilidad tras el golpe (D9) |
| `scripts/systems/crafting_system.gd` | Cambia | `check_repair_stack()` (D16) |
| `scripts/components/stats_component.gd` | Nuevo | Stats calculados, `stats_changed`, vistas tipadas |
| `scripts/components/equipment_component.gd` | Nuevo | Ranuras, equipar, quitar, desgaste, rotura, reparación, guardado (D7, D9, D16, D19) |
| `scripts/components/inventory_component.gd` | Cambia | `exchange_slot()` (D7) |
| `scripts/components/battery_component.gd` | Cambia | `set_base_maximum`, `set_drain_rates`, `is_low`; sin `legs` ni llenado en `_ready` (D5, D6, D18) |
| `scripts/components/melee_attack_component.gd` | Cambia | `set_attack`, golpe con sus valores de inicio (D11) |
| `scenes/entities/robot.gd`, `robot.tscn` | Cambia | Nodos `Equipment` y `Stats`, cableado, `equip`/`unequip`, desgaste antes de la batería (D5, D8, D9, D19) |
| `scenes/death/death_controller.gd` | Cambia | Piezas equipadas al objeto caído (D12) |
| `scenes/entities/dropped_item.gd`, `dropped_item.tscn` | Cambia | `opened`, `slot_count` en `to_data()`; sin coger directo ni `emptied`; prompt "Abrir" (D13, D14, D15) |
| `scenes/entities/dropped_item_spawner.gd` | Cambia | `drop_inventory` con piezas y ranuras por pila, `item_opened`, `item_removed`, `release_if_empty`, restauración con `slot_count` (D12, D13, D15) |
| `scenes/entities/dropped_item_flow.gd` | Nuevo | Abre, cierra y libera el objeto caído del jugador local (D13) |
| `scenes/main.tscn`, `scenes/main.gd` | Cambia | Nodo `DroppedItemFlow` y su `bind` |
| `scenes/ui/container_screen.gd` | Cambia | `Kind.DROPPED` y sus textos (D14) |
| `scenes/ui/ui_manager.gd` | Cambia | `close(screen)` público (D13) |
| `scenes/base/repair_bench.gd` | Cambia | Repara en el equipo o en el inventario por `uid` (D16) |
| `scenes/ui/bench_repair_section.gd`, `bench_screen.gd` | Cambia | Lista lo equipado y refresca con el equipo (D16) |
| `scenes/ui/equipment_panel.gd`, `equipment_panel.tscn` | Nuevo | Panel de equipo (D17) |
| `scenes/ui/inventory_screen.gd`, `inventory_screen.tscn` | Cambia | Panel, selección de ranura de equipo, Equipar / Quitar, durabilidad, aviso (D17) |
| `scenes/ui/hud.gd`, `hud.tscn` | Cambia | Aviso "Pieza rota" y barra naranja (D18, R-015-24) |
| `resources/data_catalog.tres` | Sin cambio | Las piezas ya están; ningún `.tres` nuevo es un item |
| `i18n/strings.csv` | Cambia | Claves de §4.1 |
| `specs/architecture.md` | Cambia | D20 |
| `PMV.md` §4.2-§4.3, `CLAUDE.md`, `ACTION_PLAN.md` Tarea 3.1 | Cambia (aprobado por el usuario, 2026-11-24) | D20 |
| Tests | Nuevo / Cambia | §5 |

## 3. Contratos

```gdscript
# StatIds (new) — scripts/data/stat_ids.gd
class_name StatIds
extends RefCounted
const WALK_SPEED := &"walk_speed"
const RUN_SPEED := &"run_speed"            # 0 → cannot run (D2)
const WALK_DRAIN := &"walk_drain"
const RUN_DRAIN := &"run_drain"
const PASSIVE_DRAIN := &"passive_drain"
const MAX_BATTERY := &"max_battery"
const ATTACK_DAMAGE := &"attack_damage"
const ATTACKS_PER_SECOND := &"attacks_per_second"
const BATTERY_PER_SWING := &"battery_per_swing"
const DURABILITY_PER_HIT := &"durability_per_hit"


# StatModifier (new) — architecture §9.4
class_name StatModifier
extends Resource
enum Op { SET, ADD, MULTIPLY }
@export var stat: StringName
@export var op: Op = Op.SET
@export var value: float = 0.0


# RobotBaseStatsData (new)
class_name RobotBaseStatsData
extends Resource
@export var walk_speed: float      # …one field per StatIds constant (D1)
## Stat id → value, one entry per field.
func to_stats() -> Dictionary[StringName, float]


# PieceData (changed)
enum SlotType { ARMS, LEGS, CORE }
@export var slot_type: SlotType = SlotType.ARMS
@export var modifiers: Array[StatModifier] = []


# DurabilityDisplayData (new)
class_name DurabilityDisplayData
extends Resource
enum Band { GREEN, YELLOW, RED }
@export var yellow_up_to_percent: int = 0
## The red threshold is the up_to_percent of its first tier (D18, BALANCE §4.1).
@export var repair_costs: RepairCostData
## RED at or below the red threshold of maximum, YELLOW at or below yellow_up_to_percent, else GREEN.
## maximum <= 0 or no repair tier → push_error, RED.
func band_of(durability: int, maximum: int) -> Band


# StatsCalculator (new, pure)
class_name StatsCalculator
extends RefCounted
## A new dictionary: every SET, then every ADD, then every MULTIPLY, each in list order.
## Inputs never change. A null modifier or a stat the base lacks → push_error, skipped (R-015-04).
static func compute(
	base: Dictionary[StringName, float], modifiers: Array[StatModifier]
) -> Dictionary[StringName, float]


# DegradationSystem (new, pure)
class_name DegradationSystem
extends RefCounted
const NO_SLOT := -1
## Arms → legs → core (BALANCE §4.1), as PieceData.SlotType values.
const WEAR_ORDER: Array[int] = [PieceData.SlotType.ARMS, PieceData.SlotType.LEGS, PieceData.SlotType.CORE]
## First occupied slot of pieces (indexed by SlotType) in WEAR_ORDER; NO_SLOT when none (R-015-22).
static func target_slot(pieces: Array[ItemStack]) -> int
## durability - maxi(0, roundi(wear)); may be <= 0, which means broken (R-015-21, R-015-23).
static func durability_after_hit(durability: int, wear: float) -> int


# CraftingSystem (changed)
## Rules of check_repair for a stack already found, paid from payer_slots (D16):
## intact, broken, bad data, not enough materials, in that order.
static func check_repair_stack(
	stack: ItemStack, payer_slots: Array[ItemStack], costs: RepairCostData
) -> ActionResult
# check_repair(slots, piece_uid, costs): finds the uid, then check_repair_stack(stack, slots, costs).


# StatsComponent (new) — scripts/components/stats_component.gd
class_name StatsComponent
extends Node
## State: the stats were computed again (R-015-13). Once per recompute().
signal stats_changed
@export var base_stats: RobotBaseStatsData
## The base stats until the first recompute().
func recompute(modifiers: Array[StatModifier]) -> void
## Unknown id → push_error, 0.0.
func get_stat(stat: StringName) -> float
## New value objects each call; never shared with the component.
func get_movement() -> MovementStatsData   # can_run = run_speed > 0 (D2)
func get_attack() -> AttackStatsData       # damage = roundi(attack_damage)


# EquipmentComponent (new) — scripts/components/equipment_component.gd
class_name EquipmentComponent
extends Node
## State: the slots changed (equip, unequip, swap, break, death, load). Once per operation.
signal equipment_changed
## State: a piece lost durability without breaking, or was repaired (R-015-53).
signal durability_changed(slot: PieceData.SlotType, durability: int)
## Fact: a piece broke and is gone (R-015-23). After equipment_changed; never on load.
signal piece_broken(piece_uid: String, slot: PieceData.SlotType, piece: PieceData)
const ERR_NOT_A_PIECE := &"ERR_NOT_A_PIECE"
const ERR_NO_FREE_SLOT := &"ERR_NO_FREE_SLOT"
const ERR_SLOT_EMPTY := &"ERR_SLOT_EMPTY"
const SAVE_KEY := &"equipment"
## New-game state, put on in _ready(): BALANCE §4.2 (D19).
@export var starting_pieces: Array[PieceData] = []
## Validates ids on load; DataRegistry's catalog when left null at _ready() (as InventoryComponent).
var catalog: DataCatalog = null
## Copy of the piece in slot, or null.
func get_piece(slot: PieceData.SlotType) -> ItemStack
## Copies indexed by SlotType, null for empty.
func get_pieces() -> Array[ItemStack]
func has_piece(piece_uid: String) -> bool
## Modifiers of the equipped pieces only (R-015-05).
func get_modifiers() -> Array[StatModifier]
## D7. Not a valid piece → ERR_NOT_A_PIECE; no change on any refusal.
func equip_from(inventory: InventoryComponent, slot_index: int) -> ActionResult
## D7. Empty slot → ERR_SLOT_EMPTY; no empty inventory slot → ERR_NO_FREE_SLOT (R-015-11).
func unequip_to(inventory: InventoryComponent, slot: PieceData.SlotType) -> ActionResult
## D9: wears DegradationSystem.target_slot by wear; nothing equipped → no change.
func apply_hit_wear(wear: float) -> void
## Removes these slots and returns their pieces (death, D12); one equipment_changed if any.
func take_slots(slots: Array[PieceData.SlotType]) -> Array[ItemStack]
## D16. Unknown uid → push_error, CraftingSystem.ERR_PIECE_NOT_FOUND.
func repair(piece_uid: String, payer: InventoryComponent, costs: RepairCostData) -> ActionResult
func get_save_key() -> StringName
func to_save_data() -> Dictionary
## Replaces the three slots; a bad entry loads empty with push_error (R-015-40).
## equipment_changed once; never piece_broken (R-015-39).
func from_save_data(data: Dictionary) -> void


# InventoryComponent (changed)
## Puts incoming (null or a valid stack this catalog knows) in slot_index, replacing
## what was there (the caller read it before, D7). Bad index or invalid incoming →
## push_error, ERR_INVALID_REQUEST, no change. One inventory_changed when something changed.
func exchange_slot(slot_index: int, incoming: ItemStack) -> ActionResult


# UIManager (changed)
## Closes that screen wherever it is in the stack (the existing _close), as Escape
## would on top. Not open → nothing (D13).
func close(screen: UIScreen) -> void


# BatteryComponent (changed)
## Stat part of the maximum (R-015-18); same rule as set_maximum_bonus (D6). < 0 → push_error.
func set_base_maximum(maximum: float) -> void
## Rates used by drain_per_second from now on (R-015-15, R-015-44). Negative → push_error.
func set_drain_rates(passive: float, walk: float, run: float) -> void
## Charge below maximum × config.low_threshold_ratio (R-015-43).
func is_low() -> bool
# _ready(): no longer fills the charge (D5). @export legs removed.


# MeleeAttackComponent (changed)
## From the next swing on; a pending impact keeps the values it started with (R-015-17).
func set_attack(attack: AttackStatsData) -> void
# @export attack removed; var attack stays readable.


# Robot (changed)
@onready var equipment: EquipmentComponent = %Equipment
@onready var stats: StatsComponent = %Stats
## Depleted battery → ERR_INVALID_REQUEST; else equipment.equip_from(inventory, slot_index).
func equip(slot_index: int) -> ActionResult
## Depleted battery → ERR_INVALID_REQUEST; else equipment.unequip_to(inventory, slot).
func unequip(slot: PieceData.SlotType) -> ActionResult
# receive_hit(): after the depleted check, equipment.apply_hit_wear(...) then battery.consume (D9).
# @export movement_stats removed; _move() uses the MovementStatsData of the last stats_changed.


# DroppedItem (changed)
## Every interaction (R-015-45). Replaces taking the stacks and the emptied signal.
signal opened(item: DroppedItem, opener: Node3D)
# to_data(): adds "slot_count" (D15).


# DroppedItemSpawner (changed)
const MAX_RESTORED_SLOTS := 64   # sanity cap for disk data, not a gameplay value (D15)
signal item_opened(item: DroppedItem, opener: Node3D)
## Before the item is reset and pooled: expiry, unload or release_if_empty (D13).
signal item_removed(item: DroppedItem)
## One slot per received stack: used slots of source plus pieces (R-015-47). Nothing → null.
func drop_inventory(source: InventoryComponent, world_position: Vector3, pieces: Array[ItemStack] = []) -> DroppedItem
## Deferred; releases item if it is still the same use and holds no stacks (R-015-50).
func release_if_empty(item: DroppedItem) -> void


# DroppedItemFlow (new) — scenes/entities/dropped_item_flow.gd
class_name DroppedItemFlow
extends Node
@export var ui_manager: UIManager
@export var dropped_items: DroppedItemSpawner
func bind(player: Robot) -> void


# ContainerScreen (changed)
enum Kind { LOOT_BOX, CHEST, DROPPED }


# EquipmentPanel (new) — scenes/ui/equipment_panel.gd
class_name EquipmentPanel
extends PanelContainer
signal slot_pressed(slot: PieceData.SlotType)
@export var display: DurabilityDisplayData
@export var band_colors: Array[Color] = []   # indexed by DurabilityDisplayData.Band
func bind(equipment: EquipmentComponent, stats: StatsComponent) -> void
func set_selected_slot(slot: int) -> void    # NO_SELECTION clears


# Hud (changed)
const MSG_PIECE_BROKEN := &"MSG_PIECE_BROKEN"
@export var low_battery_fill: StyleBox
# bind(): also player.equipment.piece_broken → show_notice(MSG_PIECE_BROKEN, [tr(piece.name_key)]).
# _on_battery_changed(): fill override = low_battery_fill while battery.is_low(), else removed.
```

Señales nuevas (architecture §7): `equipment_changed`, `durability_changed` y `stats_changed` son **de estado**
(se emiten al cargar); `piece_broken` es **de hecho** (nunca al cargar). `DroppedItem.opened` e `item_opened` son de
hecho; `item_removed` también. Ninguna va al `EventBus`.

## 4. Datos

| Recurso / `.tres` | Campos | Valores desde |
|---|---|---|
| `RobotBaseStatsData` (`resources/robot/robot_base_stats.tres`) | `walk_speed` 0.5, `run_speed` 0, `walk_drain` 0.1, `run_drain` 0.15, `passive_drain` 0.2, `max_battery` 100, `attack_damage` 5, `attacks_per_second` 1.0, `battery_per_swing` 1, `durability_per_hit` 5 | BALANCE §4.2 filas "Un brazo", "Sin piernas" ("no puede correr" = 0, D2), "Sin Core"; §1.1 consumo al correr; §4.1 degradación por golpe |
| `PieceData` `basic_arms.tres` | `slot_type` ARMS; `SET attack_damage 10`, `SET attacks_per_second 1.0`, `SET battery_per_swing 1` | BALANCE §4.2 "Brazos básicos" |
| `PieceData` `basic_legs.tres` | `slot_type` LEGS; `SET walk_speed 3.0`, `SET run_speed 4.8`, `SET walk_drain 0.05` | BALANCE §4.2 "Piernas básicas" |
| `PieceData` `basic_core.tres` | `slot_type` CORE; `SET max_battery 100`, `SET passive_drain 0.1` | BALANCE §4.2 "Core básico", §1.1 |
| `BatteryConfigData` `robot_battery.tres` | `low_threshold_ratio` 0.2 (pierde `maximum`, `passive_drain`, `run_drain`) | BALANCE §1.1 |
| `DurabilityDisplayData` `resources/config/durability_display.tres` | `yellow_up_to_percent` 50; `repair_costs` → `repair_costs.tres` (rojo = 25, su primer tramo) | BALANCE §4.1 "Color de la durabilidad", §4.3.2 |
| `robot.tscn`, `EquipmentComponent.starting_pieces` | `[basic_core, basic_legs]` | BALANCE §4.2 "Equipo inicial" |

**Claves de texto nuevas** (ES + EN, R-015-36): `EQUIPMENT_TITLE`, `EQUIPMENT_SLOT_ARMS`, `EQUIPMENT_SLOT_LEGS`,
`EQUIPMENT_SLOT_CORE`, `EQUIPMENT_NO_ARMS` ("Un brazo"), `EQUIPMENT_NO_LEGS` ("Sin piernas"), `EQUIPMENT_NO_CORE`
("Sin Core"), `EQUIPMENT_EQUIP` ("Equipar"), `EQUIPMENT_UNEQUIP` ("Quitar"), `STAT_ATTACK_DAMAGE`,
`STAT_ATTACKS_PER_SECOND`, `STAT_BATTERY_PER_SWING`, `STAT_WALK_SPEED`, `STAT_RUN_SPEED`, `STAT_CANNOT_RUN`
("No puede correr"), `STAT_WALK_DRAIN`, `STAT_PASSIVE_DRAIN`, `STAT_MAX_BATTERY`, `MSG_PIECE_BROKEN`
("Pieza rota: %s"), `ERR_NOT_A_PIECE`, `ERR_NO_FREE_SLOT`, `ERR_SLOT_EMPTY`, `BENCH_EQUIPPED` ("Equipada"),
`DROPPED_TITLE`, `CONTAINER_HEADER_DROPPED`, `CONTAINER_LEAVE_IN_DROPPED`. Se reutiliza `BENCH_DURABILITY`
("Durabilidad %d/%d") para la ficha (R-015-52) y `PROMPT_OPEN` para el objeto caído; se borra `PROMPT_PICK_UP` (D14).

## 5. Verificación

### 5.1 Comprobaciones de motor (T-015-01, antes de usarlas)

| # | Qué | Por qué |
|---|---|---|
| 1 | `roundi()` en Godot 4.7.2 redondea los medios lejos de 0 (`roundi(2.5) == 3`) **(verificar)** | D9, pregunta 18: el desgaste con decimales |
| 2 | `ProgressBar` usa el estilo de tema `fill` y `add_theme_stylebox_override(&"fill", …)` / `remove_theme_stylebox_override(&"fill")` lo cambian en ejecución **(verificar)** | D18, R-015-43 |
| 3 | Un `@export var x: SomeEnum` declarado en otra clase (`PieceData.SlotType`) se guarda y carga en `.tres`, y `Array[StatModifier]` exportado con subrecursos en un `.tres` (ya se hace con `Array[RepairTierData]`) **(verificar el primero)** | D1, D3 |

### 5.2 Requisitos

| Requisito | Test (`game/tests/…`) o paso manual |
|---|---|
| R-015-01 | `unit/test_piece_resources.gd::test_r_015_01_basic_pieces_slot_and_modifiers` (ranura y modificadores de BALANCE §4.2) · `::test_r_015_01_every_piece_modifier_names_a_base_stat` · `balance-auditor` |
| R-015-02 | `unit/test_robot_base_stats.gd::test_r_015_02_base_matches_balance`, `::test_r_015_02_old_stat_resources_are_gone` (los tres `.tres` de D4 no existen, `BatteryConfigData` sin `maximum`/`passive_drain`/`run_drain`) · `balance-auditor` |
| R-015-03 | `unit/test_stats_calculator.gd::test_r_015_03_set_then_add_then_multiply`, `::test_r_015_03_inputs_unchanged`, `::test_r_015_03_no_modifiers_returns_base_copy` |
| R-015-04 | `unit/test_stats_calculator.gd::test_r_015_04_unknown_stat_ignored_and_reported`, `::test_r_015_04_null_modifier_reported` |
| R-015-05 | `unit/test_stats_component.gd::test_r_015_05_only_given_modifiers_count` · `integration/test_robot_equipment.gd::test_r_015_05_piece_in_inventory_changes_nothing` |
| R-015-06 | `unit/test_robot_base_stats.gd::test_r_015_06_wear_is_a_stat` · `integration/test_robot_equipment.gd::test_r_015_06_modifier_changes_wear` (un modificador de prueba `SET durability_per_hit`) |
| R-015-07 | `unit/test_equipment_component.gd::test_r_015_07_three_slots_keep_uid_and_durability`, `::test_r_015_07_each_component_has_its_own_slots` · revisión: ningún autoload guarda equipo (`architecture-guardian`) |
| R-015-08 | `unit/test_equipment_component.gd::test_r_015_08_equip_into_empty_slot` (sale del inventario, mismo `uid` y durabilidad, `inventory_changed` antes de `equipment_changed`, una de cada), `::test_r_015_08_equipment_final_inside_inventory_changed` (D7), `::test_r_015_08_refused_exchange_restores_slot` |
| R-015-09 | `unit/test_equipment_component.gd::test_r_015_09_equip_swaps_with_equipped` · `unit/test_inventory_component.gd::test_r_015_09_exchange_slot` (válida, `null`, índice malo, pila no válida) |
| R-015-10 | `unit/test_equipment_component.gd::test_r_015_10_unequip_to_first_empty_slot`, `::test_r_015_10_unequip_core` |
| R-015-11 | `unit/test_equipment_component.gd::test_r_015_11_unequip_full_inventory_refused` (`ERR_NO_FREE_SLOT`, sin señales) |
| R-015-12 | `unit/test_equipment_component.gd::test_r_015_12_equip_material_refused`, `::test_r_015_12_equip_invalid_piece_refused`, `::test_r_015_12_empty_slot_refused` · `integration/test_robot_equipment.gd::test_r_015_12_depleted_robot_cannot_equip_or_unequip` |
| R-015-13 | `unit/test_stats_component.gd::test_r_015_13_recompute_emits_once` · `integration/test_robot_equipment.gd::test_r_015_13_each_change_recomputes_once` (equipar, quitar, intercambiar, romper, morir, cargar: un `stats_changed` cada uno) |
| R-015-14 | `integration/test_robot_equipment.gd::test_r_015_14_consumers_follow_stats` (velocidad, daño y consumo cambian al cambiar `StatsComponent`) · revisión del diff: `BatteryComponent`, `MeleeAttackComponent`, `LocomotionSystem` no nombran `PieceData` ni `EquipmentComponent` (`architecture-guardian`) |
| R-015-15 | `integration/test_robot_equipment.gd::test_r_015_15_legs_walk_run_and_drain`, `::test_r_015_15_no_legs_slow_never_runs` · `unit/test_battery_component.gd::test_r_015_15_drain_rates_by_gait` · `unit/test_locomotion_system.gd::test_r_002_18_no_legs_no_run` (con `run_speed` 0) · manual M1 |
| R-015-16 | `integration/test_robot_equipment.gd::test_r_015_16_arms_damage_and_cost`, `::test_r_015_16_no_arms_one_arm_values` · manual M1 |
| R-015-17 | `unit/test_melee_attack_component.gd::test_r_015_17_pending_swing_keeps_its_values`, `::test_r_015_17_next_swing_uses_new_values` |
| R-015-18 | `unit/test_battery_component.gd::test_r_015_18_maximum_is_stat_plus_bonus` · `integration/test_robot_equipment.gd::test_r_015_18_core_and_generator_bonus` |
| R-015-19 | `unit/test_battery_component.gd::test_r_015_19_base_maximum_keeps_or_lowers_charge`, `::test_r_015_19_no_low_nor_depleted_signal` · `integration/test_robot_equipment.gd::test_r_015_19_removing_basic_core_keeps_charge` · manual M3 |
| R-015-20 | `unit/test_equipment_component.gd::test_r_015_20_equal_pieces_wear_separately` |
| R-015-21 | `unit/test_degradation_system.gd::test_r_015_21_order_arms_legs_core`, `::test_r_015_21_wear_rounded_never_negative` (5 → -5, 2.5 → -3, -1 → 0) · `unit/test_equipment_component.gd::test_r_015_21_hit_wears_only_first_piece` |
| R-015-22 | `unit/test_degradation_system.gd::test_r_015_22_nothing_equipped_no_slot` · `integration/test_robot_equipment.gd::test_r_015_22_depleted_robot_does_not_wear` |
| R-015-23 | `unit/test_equipment_component.gd::test_r_015_23_piece_breaks_at_zero` (ranura vacía, no va al inventario, `equipment_changed` y después `piece_broken` con `uid`, ranura y pieza), `::test_r_015_23_leftover_does_not_pass_on` · `integration/test_robot_equipment.gd::test_r_015_23_broken_arms_back_to_one_arm` · manual M2 |
| R-015-24 | `unit/test_hud.gd::test_r_015_24_piece_broken_notice_names_piece` · manual M2 |
| R-015-25 | `integration/test_death_controller.gd::test_r_015_25_arms_and_legs_fall_core_stays` (con `uid` y durabilidad), `::test_r_015_25_no_drop_created_pieces_stay_equipped` (sin zona enlazada: nada se pierde, D12) |
| R-015-26 | `integration/test_death_controller.gd::test_r_015_26_spare_core_in_inventory_falls` |
| R-015-27 | `integration/test_death_controller.gd::test_r_015_27_ruleset_without_keeps_core_drops_core` (ruleset de prueba) |
| R-015-28 | `integration/test_death_controller.gd::test_r_015_28_respawn_with_remaining_stats` · manual M4 |
| R-015-29 | `unit/test_bench_screen.gd::test_r_015_29_repair_lists_equipped_marked`, `::test_r_015_29_refreshes_on_wear` |
| R-015-30 | `unit/test_equipment_component.gd::test_r_015_30_repair_equipped_keeps_it_equipped` · `unit/test_repair_bench.gd::test_r_015_30_bench_repairs_equipped_and_emits` · `unit/test_crafting_system.gd::test_r_015_30_check_repair_stack_rules` · manual M5 |
| R-015-31 | `unit/test_inventory_screen.gd::test_r_015_31_three_slots_icon_and_name`, `::test_r_015_31_no_piece_states` |
| R-015-32 | `unit/test_durability_display_data.gd::test_r_015_32_bands` (51 → verde, 50 → amarillo, 26 → amarillo, 25 → rojo, con máximas distintas de 100), `::test_r_015_32_red_comes_from_first_repair_tier` (tramos hechos a mano) · `unit/test_inventory_screen.gd::test_r_015_32_bar_color_follows_band` · manual M2 |
| R-015-33 | `unit/test_inventory_screen.gd::test_r_015_33_shows_stats_and_follows`, `::test_r_015_33_no_legs_cannot_run_text` |
| R-015-34 | `unit/test_inventory_screen.gd::test_r_015_34_piece_offers_equip`, `::test_r_015_34_slot_offers_unequip`, `::test_r_015_34_refusal_shows_reason` |
| R-015-35 | `unit/test_inventory_screen.gd::test_r_015_35_panel_fits_screen` (con las ranuras del último nivel, dentro de 1920×1080 como R-014-14, celdas con `mouse_filter = STOP`) · los tests existentes de `UIManager` y de cerrar tocando fuera siguen cubriendo bloqueo y cierre · manual M6 (táctil y ratón) |
| R-015-36 | `unit/test_inventory_screen.gd` y `unit/test_hud.gd` comprueban claves, no textos · `i18n-auditor` |
| R-015-37 | `unit/test_equipment_component.gd::test_r_015_37_save_data_per_slot`, `::test_r_015_37_round_trip` · revisión: sin stats en el guardado |
| R-015-38 | `integration/test_save_load.gd::test_r_015_38_equipment_loads_before_battery` (orden en `get_nodes_in_group(&"persistent")` con `Main` arrancado) · `::test_r_015_38_saved_charge_up_to_core_maximum_kept` |
| R-015-39 | `unit/test_equipment_component.gd::test_r_015_39_load_emits_state_never_broken` · `integration/test_save_load.gd::test_r_015_39_load_emits_equipment_and_stats` |
| R-015-40 | `unit/test_equipment_component.gd::test_r_015_40_bad_entries_load_empty` (id desconocido, material, otra ranura, durabilidad 0 o > máxima, `uid` vacío) · `integration/test_save_load.gd::test_r_015_40_rest_of_world_loads` |
| R-015-41 | `unit/test_equipment_component.gd::test_r_015_41_new_component_starting_pieces` · `integration/test_save_load.gd::test_r_015_41_new_world_starting_equipment` · `unit/test_piece_resources.gd::test_r_015_41_starting_pieces_match_balance` (lee `robot.tscn`) |
| R-015-42 | `integration/test_save_load.gd::test_r_015_42_world_without_equipment_part`, `::test_r_015_42_empty_slots_load_empty` (sin cambiar `SaveMigrations.WORLD_VERSION`) |
| R-015-43 | `unit/test_hud.gd::test_r_015_43_bar_orange_below_threshold`, `::test_r_015_43_follows_load_and_bonus` · `unit/test_battery_component.gd::test_r_015_43_is_low` · manual M7 |
| R-015-44 | `unit/test_battery_component.gd::test_r_015_44_passive_rate_from_stats` · `integration/test_robot_equipment.gd::test_r_015_44_no_core_double_drain` · manual M3 |
| R-015-45 | `unit/test_dropped_item.gd::test_r_015_45_interact_opens_never_takes`, `::test_r_015_45_prompt_is_open` (`PROMPT_OPEN`, D14) · `integration/test_dropped_item_flow.gd::test_r_015_45_opens_container_screen_with_header` · `unit/test_container_screen.gd::test_r_015_45_dropped_kind_texts` |
| R-015-46 | `integration/test_dropped_item_flow.gd::test_r_015_46_take_all_choose_and_leave` (incluye una pieza con `uid` y durabilidad) |
| R-015-47 | `integration/test_dropped_item_spawner.gd::test_r_015_47_one_slot_per_received_stack`, `::test_r_015_47_emptied_slot_accepts_player_stack` |
| R-015-48 | `integration/test_dropped_item_spawner.gd::test_r_015_48_taking_or_leaving_keeps_drop_time`, `::test_r_015_48_expiry_removes_left_stacks` |
| R-015-49 | `integration/test_dropped_item_flow.gd::test_r_015_49_expiry_closes_screen_keeps_taken` |
| R-015-50 | `integration/test_dropped_item_flow.gd::test_r_015_50_empty_released_on_close`, `::test_r_015_50_stays_open_while_empty`, `::test_r_015_50_not_empty_stays_after_close` |
| R-015-51 | `integration/test_death_controller.gd::test_r_015_51_only_pieces_create_drop`, `::test_r_008_27_empty_inventory_creates_nothing` (ahora sin piezas equipadas que caigan) |
| R-015-52 | `unit/test_inventory_screen.gd::test_r_015_52_card_shows_durability`, `::test_r_015_52_grid_has_no_bars` |
| R-015-53 | `unit/test_equipment_component.gd::test_r_015_53_wear_emits_durability_changed` · `unit/test_inventory_screen.gd::test_r_015_53_bar_updates_while_open`, `::test_r_015_53_broken_shows_no_piece_state` |
| R-015-54 | `integration/test_robot_equipment.gd::test_r_015_54_wear_before_battery` · `integration/test_death_controller.gd::test_r_015_54_lethal_hit_wears_arms_not_core` |
| R-015-55 | `integration/test_dropped_item_spawner.gd::test_r_015_55_slot_count_saved_and_restored`, `::test_r_015_55_old_save_one_slot_per_stack`, `::test_r_015_55_bad_slot_count_one_per_stack` (negativo, decimal, menor que las pilas, mayor que la cota) |

**Pasos manuales** (spec §5), en PC y en Android (APK debug):

- **M1** Fabricar Brazos y Piernas básicos (las piernas ya vienen equipadas en un mundo nuevo: quitarlas primero y
  ver 0.5 m/s y que Shift o el joystick al fondo no corren). Equiparlos desde la pantalla de inventario: el zombie
  lento muere en 2 golpes en vez de 4 y el robot corre.
- **M2** Dejarse golpear: la barra de los brazos pasa de verde a amarillo y rojo, sale "Pieza rota: Brazos básicos" y
  el robot vuelve a pegar con un brazo; después se desgastan las piernas. Con la pantalla de inventario abierta, la
  barra baja sin reabrirla.
- **M3** Quitarse el Core: la máxima no cambia, el consumo pasivo del panel pasa al de "Sin Core" y la batería baja el
  doble de rápido quieto; ponerlo lo devuelve. Con brazos y piernas rotos, los golpes desgastan el Core y, si llega a
  0, el robot sigue vivo con el consumo de "Sin Core".
- **M4** Morir de un golpe con brazos y piernas: el golpe desgasta los brazos, no el Core; brazos y piernas caen con
  su durabilidad; el robot reaparece con su Core y sin brazos ni piernas. Con el inventario lleno al morir, volver a
  0.5 m/s, abrir el objeto caído, coger las piernas y lo que se elija, dejar algo para hacer sitio y equiparse.
- **M5** Reparar en el banco una pieza equipada dañada: sigue equipada y con la barra llena.
- **M6** Un objeto caído que caduca con su pantalla abierta la cierra y desaparece con lo que quedaba, también lo
  dejado; vaciado, desaparece al cerrar. Cerrar el juego con uno a medio vaciar y volver: conserva sus ranuras vacías.
  Cerrar y volver a abrir conserva equipo, durabilidades y carga. Panel y botones se tocan con dedo y ratón.
- **M7** Al bajar del 20 % de la máxima la barra se pone naranja; vuelve a su color al recargar o usar una batería
  portátil, y con el generador colocado el cambio llega en 24.

### 5.3 Tests existentes que cambian

| Test | Cambio | Por qué |
|---|---|---|
| `unit/test_movement_resources.gd`, `unit/test_combat_resources.gd`, `unit/test_battery_resources.gd` | Dejan de cargar `basic_legs.tres`, `one_arm.tres`, `basic_arms.tres` y los campos de máxima y consumo de `robot_battery.tres`; comprueban lo mismo contra `robot_base_stats.tres` y los modificadores de las piezas. El test de "impacto antes que el intervalo de golpe" recorre la base y cada pieza de brazos | R-015-02 (D4): los datos cambian de sitio; las mismas aserciones de BALANCE |
| `unit/test_battery_component.gd` | El helper da máxima y consumos con `set_base_maximum` / `set_drain_rates` y llena con `recharge_full`; sin `legs` | D5, D6 |
| `unit/test_locomotion_system.gd` | Las piernas salen de `StatsComponent` con `basic_legs` (o de un `MovementStatsData` hecho a mano); `test_r_002_18_no_legs_no_run` usa `run_speed` 0 | D2, D4 |
| `unit/test_melee_attack_component.gd` | `melee.attack = x` pasa a `set_attack(x)`; los tests que llaman a `apply_impact` sin golpe siguen igual (D11: `set_attack` sin golpe pendiente actualiza `_swing_attack`) | D11 |
| `integration/test_robot_combat.gd` | `test_r_007_02_robot_attacks_with_one_arm` compara con los stats de la base en vez de `assert_same(one_arm.tres)`; `walk_speed` sale de `stats.get_movement()` | D4 (R-007-02 se cumple con datos nuevos) |
| `integration/test_save_load.gd`, `test_base_loop.gd`, `test_save_fixtures.gd`, `test_death_controller.gd` | La máxima esperada sale de `robot.stats.get_stat(StatIds.MAX_BATTERY)` en vez de `config.maximum` | D4 |
| `integration/test_death_controller.gd` | Las aserciones sobre el objeto caído cuentan también las Piernas del equipo inicial y el número de ranuras por pila (R-015-47); `test_r_008_27_*` quita antes las piezas equipadas | R-015-25, R-015-47, R-015-51 |
| `unit/test_dropped_item.gd` | `test_r_008_13_*`, `test_r_008_14_emptied_once` y `test_r_008_15_*` se sustituyen por los tests de R-015-45, R-015-48 y R-015-50; `PROMPT_KEY` pasa a `PROMPT_OPEN` | La spec sustituye R-008-13 y R-008-15 y ajusta R-008-14 (§3.10): cambia el requisito, no se debilita el test. El texto lo cambia D14 |
| `unit/test_hud.gd` | Los dos casos que usan `PROMPT_PICK_UP` como clave de un objetivo cualquiera usan otra clave existente; mismas aserciones | D14: la clave se borra |
| `integration/test_dropped_item_spawner.gd` | `test_r_008_14_emptied_goes_back_to_pool` pasa a `release_if_empty`; el helper `_pick_up` (que recogía interactuando) pasa a mover con `take_from` y llamar a `release_if_empty`, como hace la pantalla al cerrarse; lo usan `test_r_008_18_reused_item_is_clean`, `test_r_011_09_throw_and_pick_up_keep_piece` y los otros dos casos que lo llaman, con las mismas aserciones | R-015-45 (interactuar ya no coge), R-015-50, D13 |
| `integration/test_death_controller.gd::test_r_011_09_death_drops_and_recovers_piece` | Recupera la pieza con `take_from` sobre el contenido del objeto caído en vez de interactuar; mismas aserciones de `uid` y durabilidad | R-015-45 sustituye a R-008-13 |
| `integration/test_main_scene.gd::test_r_008_15_full_inventory_shows_notice` | Se sustituye por el aviso de "Coger todo" con inventario lleno a través del flujo del objeto caído (R-012-31 lo sigue mostrando el HUD) | R-008-15 sustituido por R-015-48 |
| `integration/test_robot_hit.gd` | Sin cambio de aserciones; se añade que la batería baja igual con piezas | R-015-54 no cambia `hit_received` |
| Tests que cuentan las pilas del inventario de un robot nuevo | Siguen igual: el equipo inicial va en el equipo, no en el inventario | R-015-41 |

## 6. Check de constitución

| Principio | Cumple | Nota |
|---|---|---|
| P1 Spec primero | ✅ | Spec *Aprobado* (2026-11-24); las preguntas 17 y 18 no bloquean |
| P2 Una fuente de verdad | ✅ | Cada número de BALANCE §4.2 en un solo `.tres` (D3, D4); una regla de máxima (D6) y de reparación (D16); el umbral rojo se deriva del primer tramo de reparación (D18) |
| P3 Lógica separada | ✅ | `StatsCalculator`, `DegradationSystem`, `CraftingSystem.check_repair_stack` y `DurabilityDisplayData.band_of` puros; los componentes reciben sus entradas por parámetro; `Robot`, `DroppedItemFlow` y la UI solo cablean y piden |
| P4 Estado por jugador | ✅ | Equipo y stats en componentes del robot; ningún autoload (R-015-07) |
| P5 Datos como recursos | ✅ | `StatModifier`, `RobotBaseStatsData`, `DurabilityDisplayData` con `class_name` y `.tres` |
| P6 Señales | ✅ | Estado (`*_changed`) y hecho (`piece_broken`, `opened`, `item_removed`) según architecture §7; componentes hermanos unidos por `Robot`; sin evento de bus nuevo |
| P7 Tipado | ✅ | Todo tipado; `Dictionary[StringName, float]`; los `Variant` de los tests se asignan a variables tipadas |
| P8 Plataforma | ✅ | Nada de plataforma en gameplay; el panel funciona con ratón y toque como las otras pantallas |
| P9 Determinismo | N/A | Sin generación: los `uid` de las piezas iniciales salen de `Uid.generate()`, como al fabricar (spec 011) |
| P10 Servicios | N/A | Ningún servicio nuevo; la caducidad sigue con `ITimeService` |
| P11 i18n | ✅ | Claves de §4 en ES + EN; `i18n-auditor` |
| P12 Presupuesto móvil | ✅ | Sin nodos 3D nuevos; el objeto caído sigue en su pool; todo por señales, sin sondeo |
| P13 Test primero | ✅ | Cada requisito con test o paso manual (§5.2); sistemas y componentes con su test antes; los tests sustituidos lo son por requisitos sustituidos (§5.3) |
| P14 Alcance | ✅ | Sin HUD de piezas, SFX, animación, recuerdos, defensa ni piezas avanzadas (spec §4); sin renombrar `CONTEXT_THROWER` ni `drop_inventory` |
| Arquitectura §3 regla 3 | ✅ | Equipar no amplía la excepción de `move_to_slot`: cada dueño escribe lo suyo (D7) |
| Arquitectura §6, PMV §4.2-§4.3 | ⚠️ | No se crea `DegradationComponent`: no tendría estado (D9). PMV.md (dueño de la arquitectura del código, constitución §5) y CLAUDE.md lo nombran; el usuario aprobó cambiarlos (2026-11-24) junto con architecture §6, en T-015-15 (D20) |

## 7. Riesgos y alternativas descartadas

- **Alguien reordena `robot.tscn`** y la batería carga antes que el equipo: una carga guardada por encima de la máxima
  sin Core quedaría pendiente y se perdería. → Test de orden de R-015-38 (como R-014-16) y docstring de `Robot`.
- **Muchos tests tocan los recursos que desaparecen** (§5.3). → T-015-08 corre la suite entera y los adapta leyendo la
  base y las piezas, sin bajar ninguna aserción.
- **El cambio de `drop_inventory` a una ranura por pila** deja menos ranuras que antes en el objeto de una muerte. →
  Lo pide R-015-47; dos pilas de chatarra que se fusionan al caer dejan una ranura vacía donde dejar algo.
- **Re-entrada al caducar con la pantalla abierta**: `item_removed` cierra la pantalla, cuyo `closed` llama a
  `release_if_empty` de un objeto que ya se está liberando. → `_release` lo saca de la lista antes de emitir, y
  `release_if_empty` comprueba lista y `uid` (D13). Test de R-015-49.
- **Rotura y muerte en el mismo golpe**: el golpe rompe los brazos (aviso "Pieza rota") y vacía la batería; el aviso
  queda tapado por la pantalla de transferencia. → Aceptado: la Tarea 4.1 decide la cola de avisos.
- **Tres toques para la chatarra de un zombie** (pregunta 17). → Se mide en M4/M6 y en la Tarea 5.1.
- **El panel no cabe** junto a 8 ranuras en 1920×1080. → Test de R-015-35 y M6; si falla, se ajusta la escena.
- **`damage = roundi(attack_damage)`**: con "Puño reforzado" (spec 017, BALANCE §6.3) un brazo daría 7.5 y se
  aplicaría 8. → Sin efecto en esta spec; la 017 decide si el daño pasa a `float`.
- Descartado: modelo "pull" (§1), `DegradationComponent` (D9), stats en un diccionario exportado (D1), `ADD` en las
  piezas (D3), `can_run` como stat (D2), pantalla de equipo propia (pregunta 3), equipar automáticamente al recoger
  (pregunta 15).
