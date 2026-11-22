# Plan 004 — Zona verde, `zone_id`, RNG con semilla y cajas de loot

| Campo | Valor |
|---|---|
| **Spec** | [spec.md](spec.md) (debe estar *Aprobado*) |
| **Estado** | Planificado |

## 1. Enfoque

**La zona es una escena con datos.** `farm_zone_green.tscn` (clase `FarmZone`) contiene el suelo, la decoración,
los límites, el punto de aparición y los marcadores de cajas, y lleva un `ZoneData` con su `zone_id` y sus números
(BALANCE §7, §7.1). La zona no se genera sola en `_ready`: `main.gd` le llama a `generate(world_seed)` con la
semilla de `GameManager`. Así la regla de generación recibe todo por parámetro (architecture §3 regla 4), los tests
generan la misma zona con varias semillas sin autoloads, y el `ZoneLoader` del spec 009 hará la misma llamada.

**`ZoneData` nace ahora** con `zone_id`, tamaño y número de cajas. El spec 009 le añade la escena y el tipo
(`BASE` / `FARM`) que pide architecture §6, y el 006 sus spawns. Así no hay dos tipos de datos de zona.

**Aleatoriedad con semilla** (R-004-09..11, P9). `SeededRng` deriva una semilla de 64 bits con SHA-256 sobre
`semilla del mundo + zone_id + flujo + índice` y la pone en un `RandomNumberGenerator`.
- **Flujos con nombre** (`box_placement`, `box_loot`): cada uso tiene su propia secuencia. Si el spec 006 añade
  spawns de zombies a la zona, las cajas no se mueven. El flujo es una etiqueta fija del código, no estado
  externo: la semilla sigue saliendo "solo" de la semilla del mundo y el `zone_id` (R-004-09).
- **SHA-256 y no `hash()`**: es un algoritmo estándar, con bytes de entrada documentados (§3). Un servidor que no
  sea Godot (v3.0) puede reproducir la semilla. Y no depende de cómo implemente Godot `hash()` en cada versión.
  Un test de valor conocido fija el resultado: si alguien cambia la derivación, se rompen las partidas y el test
  lo dice.
- La colocación (cuántas cajas y en qué marcadores) usa el flujo `box_placement`. El contenido de cada caja usa
  `box_loot` con el **índice del marcador**, así que no depende del orden de apertura ni del número de cajas
  (spec, pregunta 5).
- Un test recorre todo el código del juego y prohíbe `randf()`, `randi()`, `randi_range()`, `randf_range()`,
  `randfn()`, `randomize()`, `Array.shuffle()` y `Array.pick_random()`, que usan el RNG global (R-004-10).

**Interacción** (architecture §9.1).
- `InteractableComponent` es un `Area3D` en la capa de física `interaction`, que solo se deja detectar.
  `InteractorComponent` es un `Area3D` en el robot que solo detecta esa capa. El radio de su esfera sale de
  `ControlConfigData.interaction_range_m` (BALANCE §11).
- En cada fotograma de física, el interactor elige el interactuable activado más cercano y emite `target_changed`
  **solo si cambia**. La elección es una función estática pura, `pick_nearest()`, que se testea sin física.
- El robot une las dos vías de entrada: la acción `interact` de InputMap (ya existe, E, spec 001), leída por
  `PlayerInput`, y el botón del HUD, que emite `interact_pressed` y `main.gd` conecta a `Robot.request_interact()`.
- `request_interact()` no hace nada con la batería agotada (R-004-16). Además, en el game over `World` está
  desactivado y el robot no lee input.
- El HUD muestra un solo botón `InteractButton` abajo a la derecha (spec, pregunta 7), con el texto
  `tr(prompt_key)` del objetivo, y lo oculta sin objetivo.

**Cajas.** `LootBox` (`StaticBody3D`: también es obstáculo) recibe su semilla con `setup(loot_seed)` al generarse
la zona. Al recibir `interacted`:
1. Tira su `LootTableData` con `LootSystem.roll()`, que es lógica pura.
2. Pasa a abierta: cambia de malla y desactiva su interactuable.
3. Emite `loot_generated(stacks, opener)`.

Nadie escucha la señal en este spec: el 005 la conecta al `InventoryComponent` del robot que abre (opción A).

**Items y catálogo.**
- `ItemData` (id, clave de nombre, stack máximo) y los tres materiales de BALANCE §2.
- `DataCatalog` indexa por id y avisa de ids repetidos o desconocidos.
- `DataRegistry` es un autoload fino que carga el catálogo al arrancar y delega en él. Así la lógica se testea
  con catálogos hechos a mano, sin tocar el autoload.
- Las tablas de loot apuntan al recurso `ItemData`, no a un id de texto: el editor lo valida y un test comprueba
  que cada item está en el catálogo. Los ids solo se usarán en guardado y red (spec 010).

**`ItemStack` mínimo**: solo `item` y `quantity`. El spec 005 lo completa con lo que pida el inventario, y el 015
con `durability` y `uid` (architecture §9.3), para no adelantar campos sin uso (P14).

**`GameManager`** se crea ahora con un solo dato: la semilla del mundo, leída de `dev_world.tres` (spec, pregunta
1). El spec 010 la sustituye por la del mundo guardado.

**Arte.** Todo son **primitivas provisionales** (cajas, cilindros, esferas con material de color), que R-004-07
permite. No entra ningún asset de terceros, así que no hay licencias que anotar. Los packs CC0 (Kenney u otros)
se cambian en ACTION_PLAN 4.4 / 5.3, o antes si el usuario los descarga, con su licencia en `game/assets/CREDITS.md`.

## 2. Archivos

| Archivo (`game/…`) | Nuevo / Cambia | Responsabilidad |
|---|---|---|
| `scripts/util/seeded_rng.gd` | Nuevo | Derivación de semilla (SHA-256) y RNG por zona y flujo |
| `scripts/systems/zone_population.gd` | Nuevo | Elegir cuántas cajas y en qué marcadores |
| `scripts/systems/loot_system.gd` | Nuevo | Validar y tirar una tabla de loot |
| `scripts/data/item_data.gd` | Nuevo | Resource: id, clave de nombre, stack máximo |
| `scripts/data/item_stack.gd` | Nuevo | `RefCounted`: item + cantidad (architecture §9.3, mínimo) |
| `scripts/data/loot_entry_data.gd`, `loot_table_data.gd` | Nuevo | Resource: item con rango de cantidad; lista de entradas |
| `scripts/data/zone_data.gd` | Nuevo | Resource: `zone_id`, tamaño, número de cajas |
| `scripts/data/world_grid_config_data.gd` | Nuevo | Resource: tamaño de celda del mapa global |
| `scripts/data/dev_world_config_data.gd` | Nuevo | Resource: semilla fija de desarrollo |
| `scripts/data/data_catalog.gd` | Nuevo | Resource: lista de items, índice por id |
| `scripts/data/control_config_data.gd` | Cambia | Añade `interaction_range_m` |
| `scripts/autoload/game_manager.gd` | Nuevo | Autoload `GameManager`: semilla del mundo |
| `scripts/autoload/data_registry.gd` | Nuevo | Autoload `DataRegistry`: carga y expone el catálogo |
| `scripts/components/interactable_component.gd` | Nuevo | Objeto interactuable (architecture §9.1) |
| `scripts/components/interactor_component.gd` | Nuevo | Objetivo más cercano del robot (architecture §9.1) |
| `scripts/components/player_input.gd` | Cambia | `is_interact_just_pressed()` |
| `resources/items/scrap.tres`, `cables.tres`, `iron.tres` | Nuevo | BALANCE §2 |
| `resources/data_catalog.tres` | Nuevo | Catálogo con los tres items |
| `resources/loot/basic_box.tres` | Nuevo | BALANCE §2.1 "Caja básica (zona verde)" |
| `resources/zones/green_zone.tres` | Nuevo | BALANCE §7.1 + `zone_id (0, 0)` |
| `resources/zones/green_zone_tiles.tres` | Nuevo | `MeshLibrary` provisional: hierba y tierra |
| `resources/config/world_grid.tres` | Nuevo | BALANCE §7 "Celda del mapa global" |
| `resources/config/dev_world.tres` | Nuevo | Semilla de desarrollo |
| `resources/config/controls.tres` | Cambia | `interaction_range_m` (BALANCE §11) |
| `scenes/farm_zone/farm_zone.gd` | Nuevo | `FarmZone`: `generate()`, punto de aparición, cajas |
| `scenes/farm_zone/farm_zone_green.tscn` | Nuevo | Suelo GridMap, decoración, límites, sol, entorno, marcadores |
| `scenes/entities/loot_box.tscn` + `loot_box.gd` | Nuevo | Caja: colisión, mallas cerrada/abierta, interactuable |
| `scenes/entities/robot.tscn` + `robot.gd` | Cambia | `%Interactor`; `request_interact()`; lee `interact` |
| `scenes/ui/hud.tscn` + `hud.gd` | Cambia | `%InteractButton`, señal `interact_pressed` |
| `scenes/main.tscn` + `main.gd` | Cambia | Zona verde en `ZoneSlot` (`%GreenZone`); genera, coloca al robot, conecta interactuar |
| `scenes/dev/dev_zone.tscn` | **Se borra** | La sustituye la zona verde (R-004-05); su sol y entorno pasan a la zona |
| `project.godot` | Cambia | `[autoload]` GameManager y DataRegistry; nombre de la capa 3D 2 = `interaction` |
| `i18n/strings.csv` (+ `.translation` al importar) | Cambia | `PROMPT_OPEN`, `ITEM_SCRAP`, `ITEM_CABLES`, `ITEM_IRON` |
| `tests/unit/test_seeded_rng.gd` | Nuevo | R-004-09 |
| `tests/unit/test_no_global_rng.gd` | Nuevo | R-004-10 |
| `tests/unit/test_zone_population.gd` | Nuevo | R-004-21 (regla pura) |
| `tests/unit/test_loot_system.gd` | Nuevo | R-004-23 (tirada), R-004-26 |
| `tests/unit/test_data_catalog.gd` | Nuevo | R-004-18..20, R-004-22, R-004-26 (datos reales) |
| `tests/unit/test_zone_resources.gd` | Nuevo | R-004-02, R-004-03, datos de R-004-21 |
| `tests/unit/test_game_manager.gd` | Nuevo | R-004-08 |
| `tests/unit/test_interactable_component.gd` | Nuevo | R-004-15 |
| `tests/unit/test_interactor_component.gd` | Nuevo | R-004-12, R-004-15, R-004-17 |
| `tests/unit/test_loot_box.gd` | Nuevo | R-004-23..25 |
| `tests/unit/test_hud.gd` | Cambia | R-004-13 |
| `tests/unit/test_movement_resources.gd` | Cambia | `interaction_range_m` (R-004-17) |
| `tests/unit/test_project_settings.gd` | Cambia | Autoloads y capa `interaction` |
| `tests/integration/test_green_zone.gd` | Nuevo | R-004-01, R-004-04, R-004-11, R-004-21 |
| `tests/integration/test_robot_interaction.gd` | Nuevo | R-004-14, R-004-16 |
| `tests/integration/test_main_scene.gd` | Cambia | R-004-05; R-002-03 sigue (sol y entorno ahora en la zona) |

No se crean `EventBus`, `UIManager` ni `ZoneLoader` (spec §4).

## 3. Contratos

```gdscript
class_name SeededRng
extends RefCounted

const STREAM_BOX_PLACEMENT := &"box_placement"
const STREAM_BOX_LOOT := &"box_loot"

## SHA-256 over: world_seed (s64 LE) ‖ zone_id.x (s32 LE) ‖ zone_id.y (s32 LE) ‖ index (s32 LE)
## ‖ stream (UTF-8). The seed is the first 8 bytes of the digest as s64 LE.
static func derive_seed(world_seed: int, zone_id: Vector2i, stream: StringName, index: int = 0) -> int
static func create(world_seed: int, zone_id: Vector2i, stream: StringName, index: int = 0) -> RandomNumberGenerator
```

```gdscript
class_name ZonePopulation
extends RefCounted

## Number of boxes in [min_count, max_count], then that many distinct marker
## indices (Fisher-Yates with rng), sorted ascending. If marker_count < max_count
## → push_error and at most marker_count boxes.
static func pick_box_markers(marker_count: int, min_count: int, max_count: int, rng: RandomNumberGenerator) -> Array[int]
```

```gdscript
class_name LootSystem
extends RefCounted

## Empty when valid; one message per problem (no item, negative quantity, min > max).
static func validate(table: LootTableData) -> PackedStringArray
## One rng.randi_range(min, max) per entry, in table order; quantities of 0 are left out.
## Invalid table → push_error naming table.resource_path and returns [].
static func roll(table: LootTableData, rng: RandomNumberGenerator) -> Array[ItemStack]
```

```gdscript
class_name ItemData
extends Resource
@export var id: StringName          # snake_case, stable forever (architecture §8)
@export var name_key: StringName    # translation key: ITEM_SCRAP…
@export var stack_max: int = 0

class_name ItemStack
extends RefCounted
var item: ItemData
var quantity: int
func _init(p_item: ItemData, p_quantity: int) -> void

class_name LootEntryData
extends Resource
@export var item: ItemData
@export var min_quantity: int = 0
@export var max_quantity: int = 0

class_name LootTableData
extends Resource
@export var entries: Array[LootEntryData] = []

class_name ZoneData
extends Resource
@export var zone_id: Vector2i
@export var size_m: Vector2 = Vector2.ZERO
@export var box_count_min: int = 0
@export var box_count_max: int = 0

class_name WorldGridConfigData
extends Resource
@export var cell_size_m: float = 0.0

class_name DevWorldConfigData
extends Resource
@export var world_seed: int = 0

class_name DataCatalog
extends Resource
@export var items: Array[ItemData] = []
## Builds the id index; returns one message per repeated or empty id.
func build_index() -> PackedStringArray
func has_item(id: StringName) -> bool
func get_item(id: StringName) -> ItemData   # unknown id → push_error + null
```

```gdscript
# scripts/autoload/game_manager.gd — autoload "GameManager" (no class_name: it would clash with the autoload name)
extends Node
const DEV_WORLD_PATH := "res://resources/config/dev_world.tres"
func get_world_seed() -> int

# scripts/autoload/data_registry.gd — autoload "DataRegistry"
extends Node
const CATALOG_PATH := "res://resources/data_catalog.tres"
func get_catalog() -> DataCatalog
func get_item(id: StringName) -> ItemData   # delegates; push_error on unknown id
```

```gdscript
class_name InteractableComponent
extends Area3D

const PHYSICS_LAYER := 2            # named "interaction" in project.godot

signal interacted(interactor: Node3D)

@export var prompt_key: StringName
@export var enabled: bool = true

func interact(interactor: Node3D) -> void   # emits only while enabled
```

```gdscript
class_name InteractorComponent
extends Area3D

signal target_changed(target: InteractableComponent)   # null = no target

@export var config: ControlConfigData       # interaction_range_m → radius of its SphereShape3D

func get_target() -> InteractableComponent
## Calls interact(interactor) on the current target; false when there is none.
func interact_with_target(interactor: Node3D) -> bool
static func pick_nearest(origin: Vector3, candidates: Array[InteractableComponent]) -> InteractableComponent
```

```gdscript
class_name LootBox
extends StaticBody3D

signal loot_generated(stacks: Array[ItemStack], opener: Node3D)

@export var loot_table: LootTableData

func setup(loot_seed: int) -> void          # before it can be opened
func is_opened() -> bool
```

```gdscript
class_name FarmZone
extends Node3D

@export var data: ZoneData
@export var box_scene: PackedScene

## Places the boxes once (second call → push_error, no change).
func generate(world_seed: int) -> void
func get_spawn_position() -> Vector3
func get_boxes() -> Array[LootBox]
```

```gdscript
# Robot (cambia)
@onready var interactor: InteractorComponent = %Interactor
func request_interact() -> void             # no-op while battery.is_depleted()

# PlayerInput (cambia)
func is_interact_just_pressed() -> bool     # Input.is_action_just_pressed(&"interact")

# Hud (cambia)
signal interact_pressed
# bind(player) también conecta player.interactor.target_changed y pinta el objetivo actual
```

**Capas de física.** `InteractableComponent`: `collision_layer` = capa 2, `collision_mask` = 0, `monitoring` falso,
`monitorable` verdadero. `InteractorComponent`: `collision_layer` = 0, `collision_mask` = capa 2, `monitoring`
verdadero, `monitorable` falso. Los dos lo fijan en `_ready()` desde `InteractableComponent.PHYSICS_LAYER`: un solo
sitio para el número.

**Eventos**: ninguno nuevo en `EventBus` (architecture §7). `interacted`, `target_changed`, `loot_generated` e
`interact_pressed` son señales locales.

## 4. Datos

| Recurso / `.tres` | Campos | Valores desde |
|---|---|---|
| `resources/items/scrap.tres` | `id = &"scrap"`, `name_key = &"ITEM_SCRAP"`, `stack_max = 99` | BALANCE §2 |
| `resources/items/cables.tres` | `id = &"cables"`, `name_key = &"ITEM_CABLES"`, `stack_max = 50` | BALANCE §2 |
| `resources/items/iron.tres` | `id = &"iron"`, `name_key = &"ITEM_IRON"`, `stack_max = 50` | BALANCE §2 |
| `resources/loot/basic_box.tres` | scrap 2-5, cables 0-2, iron 0-1 (sin entrada de batería: 0 %) | BALANCE §2.1 "Caja básica (zona verde)" |
| `resources/zones/green_zone.tres` | `zone_id = (0, 0)`, `size_m = (50, 50)`, `box_count_min = 5`, `box_count_max = 7` | ACTION_PLAN 1.1; BALANCE §7.1 |
| `resources/config/world_grid.tres` | `cell_size_m = 80.0` | BALANCE §7 "Celda del mapa global" |
| `resources/config/controls.tres` | `interaction_range_m = 2.0` | BALANCE §11 "Radio de interacción" |
| `resources/config/dev_world.tres` | `world_seed` = un entero fijo | Spec, pregunta 1. No es un valor de balance: solo hace la zona reproducible hasta el spec 010 |

**Escena de la zona.**
- El suelo es un GridMap de 2 m por celda que cubre los 50x50 m, con hierba y caminos de tierra.
- Hay 10 marcadores de caja (más que `box_count_max`), repartidos a mano lejos de obstáculos y del punto de
  aparición.
- Las vallas visibles van en el borde y las paredes invisibles justo fuera. Todo cabe en la celda de 80 m (R-004-03).
- El GridMap se rellena una sola vez con un script temporal en headless (fuera del repo) y se guarda el `.tscn`.
  Los retoques posteriores se hacen en el editor.

## 5. Verificación

| Requisito | Test (`game/tests/…`) o paso manual |
|---|---|
| R-004-01 | `integration/test_green_zone.gd::test_r_004_01_ground_tiles_cover_zone` (GridMap con hierba y tierra dentro de `size_m`), `::test_r_004_01_every_obstacle_has_collider` |
| R-004-02 | `unit/test_zone_resources.gd::test_r_004_02_green_zone_id` |
| R-004-03 | `unit/test_zone_resources.gd::test_r_004_03_cell_size_matches_balance`, `integration/test_green_zone.gd::test_r_004_03_zone_fits_in_one_cell` (suelo, límites y marcadores dentro de `cell_size_m / 2` del origen) |
| R-004-04 | `integration/test_green_zone.gd::test_r_004_04_robot_cannot_leave` (robot a 1 m de cada borde, empujado hacia fuera 2 s con física real: sigue dentro) |
| R-004-05 | `integration/test_main_scene.gd::test_r_004_05_green_zone_loaded`, `::test_r_004_05_robot_at_spawn_point`; R-002-03 sigue en verde |
| R-004-06 | Manual (T-004-12): ≥ 30 FPS en el Android de gama media con el `DebugHud`; triángulos en pantalla con el monitor del editor en PC (< 50K) |
| R-004-07 | Revisión del diff (T-004-13): solo primitivas, ningún asset de terceros |
| R-004-08 | `unit/test_game_manager.gd::test_r_004_08_world_seed_from_dev_world` |
| R-004-09 | `unit/test_seeded_rng.gd::test_r_004_09_same_inputs_same_sequence`, `::test_r_004_09_other_zone_other_sequence`, `::test_r_004_09_other_stream_or_index_other_seed`, `::test_r_004_09_known_answer` (valor fijado al implementar) |
| R-004-10 | `unit/test_no_global_rng.gd::test_r_004_10_no_global_rng_in_game_code` (recorre `res://scripts` y `res://scenes`; excluye `addons` y `tests`) |
| R-004-11 | `integration/test_green_zone.gd::test_r_004_11_same_seed_same_boxes`, `::test_r_004_11_other_seed_other_layout` (semillas fijas que se sabe que difieren) |
| R-004-12 | `unit/test_interactor_component.gd::test_r_004_12_pick_nearest`, `::test_r_004_12_target_changed_on_enter_and_exit` (física real, dos objetivos), `::test_r_004_12_no_signal_without_change` |
| R-004-13 | `unit/test_hud.gd::test_r_004_13_button_shows_target_prompt`, `::test_r_004_13_button_hidden_without_target`, `::test_r_004_13_button_emits_interact_pressed`; manual (T-004-12): botón legible y sin chocar con el joystick |
| R-004-14 | `integration/test_robot_interaction.gd::test_r_004_14_interact_action_opens_box`, `::test_r_004_14_hud_button_opens_box` (con `main.tscn`) |
| R-004-15 | `unit/test_interactable_component.gd::test_r_004_15_disabled_does_not_emit`, `unit/test_interactor_component.gd::test_r_004_15_disabled_is_not_a_target` |
| R-004-16 | `integration/test_robot_interaction.gd::test_r_004_16_depleted_robot_does_not_interact` |
| R-004-17 | `unit/test_movement_resources.gd::test_r_004_17_interaction_range_matches_balance`, `unit/test_interactor_component.gd::test_r_004_17_radius_from_config` |
| R-004-18 | `unit/test_data_catalog.gd::test_r_004_18_items_match_balance`, `::test_r_004_18_item_names_translated_es_en` |
| R-004-19 | `unit/test_data_catalog.gd::test_r_004_19_get_item_by_id`, `::test_r_004_19_unknown_id_reports_error` (`assert_push_error`), `::test_r_004_19_registry_loads_catalog` |
| R-004-20 | `unit/test_data_catalog.gd::test_r_004_20_no_repeated_ids`, `::test_r_004_20_every_item_file_in_catalog` |
| R-004-21 | `unit/test_zone_population.gd::test_r_004_21_count_in_range` (100 semillas), `::test_r_004_21_distinct_sorted_markers`, `::test_r_004_21_too_few_markers_reports_error`; `unit/test_zone_resources.gd::test_r_004_21_box_counts_match_balance`; `integration/test_green_zone.gd::test_r_004_21_boxes_on_markers` |
| R-004-22 | `unit/test_data_catalog.gd::test_r_004_22_basic_box_matches_balance`, `::test_r_004_22_loot_items_in_catalog` |
| R-004-23 | `unit/test_loot_system.gd::test_r_004_23_quantities_in_range` (1000 tiradas con semilla fija), `::test_r_004_23_zero_left_out`; `unit/test_loot_box.gd::test_r_004_23_open_emits_once_with_opener`, `::test_r_004_23_contents_independent_of_open_order` |
| R-004-24 | `unit/test_loot_box.gd::test_r_004_24_opened_state_and_disabled`, `::test_r_004_24_second_interact_no_loot` |
| R-004-25 | `unit/test_loot_box.gd::test_r_004_25_prompt_open_translated_es_en` |
| R-004-26 | `unit/test_loot_system.gd::test_r_004_26_validate_rejects_bad_entries`, `::test_r_004_26_roll_invalid_reports_error`; `unit/test_data_catalog.gd::test_r_004_26_all_loot_tables_valid` |
| Criterio de hecho | T-004-12: PC y APK en Android real |

**APIs verificadas (2026-11-15)** contra el binario 4.7.2 en headless (`ClassDB`, propiedades de instancia y
ejecución). No queda nada **(verificar)**:

1. `HashingContext` con `HASH_SHA256` (`start` / `update` / `finish`) devuelve 32 bytes, y
   `PackedByteArray.encode_s64` / `decode_s64` existen.
2. `RandomNumberGenerator.seed` y `randi_range` (extremos incluidos) existen. Dos RNG con la misma semilla dan la
   misma secuencia.
3. `GridMap` (`mesh_library`, `cell_size`, `set_cell_item`, `get_used_cells`) y `MeshLibrary` (`create_item`,
   `set_item_mesh`, `set_item_shapes`) existen. `Marker3D` existe.
4. `Area3D.get_overlapping_areas()`, `monitoring` y `monitorable` existen.
5. `RegEx` (PCRE2) acepta lookbehind. El patrón de §1 detecta `randf()` y `arr.shuffle()`, y no detecta
   `rng.randi_range()`.
6. `DirAccess.get_files_at()` existe.
7. Una señal con parámetro `Array[ItemStack]` compila y se emite con un array tipado.
8. `Input.action_press(&"interact")` se ve con `Input.is_action_just_pressed` en el siguiente fotograma de física,
   y solo en uno.
9. `Control.FOCUS_NONE` existe: el botón no se queda con el foco, así que Espacio (`attack`) no lo pulsa.
10. La suma de enteros desborda en complemento a dos (la derivación no la usa: por eso SHA-256).

## 6. Check de constitución

| Principio | Cumple | Nota |
|---|---|---|
| P2 Una fuente de verdad | ✅ | Números en `.tres` desde BALANCE §2, §2.1, §7, §7.1 y §11. El número de capa vive solo en `InteractableComponent.PHYSICS_LAYER`. `ZoneData` es el único tipo de datos de zona: los specs 006 y 009 lo amplían |
| P3 Lógica separada | ✅ | Semilla, colocación y tirada son funciones estáticas puras con el RNG por parámetro. `pick_nearest()` es pura. Escenas y componentes solo cablean |
| P4 Estado por jugador | ✅ | El interactor vive en el robot. `GameManager` solo guarda la semilla, que es estado de la partida. `loot_generated` lleva quién abre |
| P5 Datos como recursos | ✅ | `ItemData`, `LootTableData`, `LootEntryData`, `ZoneData`, `WorldGridConfigData`, `DevWorldConfigData`, `DataCatalog` |
| P6 Señales | ✅ | Señales en pasado o como evento y tipadas. Referencias con `%` o `@export` |
| P7 Tipado | ✅ | Todo tipado. Los autoloads no llevan `class_name` (chocaría con su nombre) y se llaman por su identificador global, que está tipado |
| P8 Plataforma | ✅ | Interactuar lee la acción `interact` o el botón del HUD. El botón se ve en las dos plataformas |
| P9 Determinismo | ✅ | Todo sale de `SeededRng`. Hay un test que prohíbe el RNG global en todo el código del juego (más estricto que "en generación"). Las posiciones son locales a la zona, con origen en el centro de su celda |
| P11 i18n | ✅ | `PROMPT_OPEN` y los nombres de items en ES y EN |
| P12 Presupuesto móvil | ✅ | Primitivas y un GridMap de 625 celdas (unos 7.5K triángulos). Hay una luz con sombras: la de la zona, que sustituye a la de `DevZone`. Se mide en el móvil (T-004-12) |
| P13 Test primero | ✅ | Cada sistema, dato y componente lleva su test rojo primero. Lectura y FPS en el móvil, paso manual |
| P14 Alcance | ✅ | Sin inventario, `ZoneLoader`, guardado, spawns ni animación (spec §4). `ItemStack` e `ItemData` solo con los campos que se usan |
| architecture.md §3 regla 4 (`ActionResult`) | ✅ | Ninguna acción de este spec falla ante el jugador. Abrir una caja ya abierta no es posible: el botón desaparece. `ActionResult` sigue reservado para el spec 011 |
| architecture.md §9.5 (HUD por señales) | ✅ | El botón sigue a `target_changed`. La foto inicial pasa por el mismo manejador |

## 7. Riesgos y alternativas descartadas

- ~~**El spec 003 no está fusionado en `main`.**~~ Resuelto en T-004-00: el PR #4 está fusionado y
  `feat/004-green-zone` nace de `main` (`787e1d4`) con el 003 dentro.
- **Cambiar la derivación de semilla o el orden de las tiradas rompe mundos guardados** (spec 010 en adelante).
  Mitigación: el test de valor conocido de `SeededRng` y el orden de tirada documentado en `LootSystem.roll()`. Un
  cambio voluntario necesita migración.
- **`RandomNumberGenerator` es PCG32 de Godot.** Un servidor no-Godot (v3.0) tendría que reimplementar también
  PCG32, no solo la derivación. Es un algoritmo público. Se anota y no se resuelve ahora.
- **El interactor evalúa los candidatos en cada fotograma de física.** El coste es mínimo (pocas áreas
  solapadas) y la señal solo sale al cambiar. Se mide en el móvil.
- **El clic izquierdo también es `attack`** (spec 001). Pulsar el botón del HUD con el ratón lo consume la GUI
  antes del input sin manejar, así que no ataca. Lo revisa el spec 007 cuando exista el ataque.
- **Descartado: `hash()` de Godot para la semilla.** Su implementación no es un contrato estable entre versiones ni
  es fácil de reproducir fuera de Godot.
- **Descartado: un solo RNG por zona para todo.** Añadir spawns en el spec 006 movería las cajas de mundos ya
  guardados. Por eso hay flujos con nombre.
- **Descartado: tirar el loot al generar la zona.** Funciona igual con semilla, pero guarda resultados que nadie
  ha visto y complica el guardado de cambios por zona. Tirar al abrir con la semilla del marcador da el mismo
  resultado y no guarda nada.
- **Descartado: posiciones libres con RNG** (spec, pregunta 4). Podrían caer dentro de obstáculos.
- **Descartado: generar la zona en `FarmZone._ready()` leyendo `GameManager`.** Acopla la zona al autoload y
  obliga a los tests a tocar estado global.
- **Descartado: `ZoneLoader` ahora.** Con una sola zona y sin base no hay viaje. Llega con el spec 009.
- **Descartado: assets de terceros ya.** Descargar y elegir un pack es una decisión del usuario. Con primitivas, el
  spec se cumple y el rendimiento se mide igual.
