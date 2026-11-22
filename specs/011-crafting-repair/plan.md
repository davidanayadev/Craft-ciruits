# Plan 011 — Crafteo de piezas y reparación en el banco

| Campo | Valor |
|---|---|
| **Spec** | [spec.md](spec.md) (debe estar *Aprobado*) |
| **Estado** | Planificado (2026-11-18) |

## 1. Enfoque

Cuatro capas, como pide architecture §3:

1. **Datos.** `PieceData extends ItemData` con solo `durability_max` (la spec 015 añade `slot_type` y
   modificadores); tres `.tres` de pieza en `resources/pieces/`. `RecipeData` gana `result_item` y tres recetas
   nuevas. El coste de reparación es un recurso propio, `RepairCostData`, con tramos (`RepairTierData`), que el
   `DataCatalog` referencia como ya hace con `new_world_ruleset` (R-011-06).
2. **Reglas puras.** `InventoryRules` aprende a mover una pila **con** su durabilidad y su `uid` (`add_stack`,
   `split`) y a validar una pila de pieza (`is_valid_stack`). `CraftingSystem` añade la comprobación de crear (con
   la ranura que libera el pago), la creación del resultado (`uid` nuevo, durabilidad máxima), el coste de
   reparación por tramos y la comprobación de reparar. Todo sobre `Array[ItemStack]`, sin nodos.
3. **Dueño del estado.** `InventoryComponent.craft(recipe)` y `repair(piece_uid, costs)` cambian las ranuras en
   un solo paso y una sola `inventory_changed`. Todos los caminos que ya mueven pilas (`add_stacks`, `take_from`,
   `take_amount_from`, sobrantes) pasan a `add_stack`, así que caja, objeto caído, muerte y tirar conservan la
   pieza sin tocar sus escenas. `DroppedItem.to_data()` y `DroppedItemSpawner` guardan y restauran durabilidad y
   `uid`.
4. **Escena y UI.** `RepairBench.craft(player, recipe)` / `repair(player, piece_uid)` son la petición del jugador
   (el anfitrión decidirá aquí en cooperativo, como `BaseStructures.place`): llaman al inventario del jugador y,
   si sale bien, emiten `EventBus.item_crafted` / `piece_repaired`, que `SaveManager` ya sabe convertir en un
   guardado diferido (R-011-28). `BenchScreen` sustituye a `BuildScreen`: un `TabContainer` con tres secciones
   (Construir, Crear, Reparar) que comparten una fila (`BenchEntry`) y se refrescan con `inventory_changed`.

**Alternativa principal descartada**: poner `craft_piece()` en `CraftingSystem` cambiando el inventario, como
dice ACTION_PLAN 2.4. Rompe architecture §3 regla 3 (un único dueño del estado) y la decisión de la spec 009
(R-009-62): el sistema decide, el componente escribe.

### 1.1 Decisiones del plan

| # | Decisión | Por qué |
|---|---|---|
| D1 | Una pieza en un inventario siempre es válida: cantidad 1, durabilidad entre 1 y su máxima y `uid` no vacío (`InventoryRules.is_valid_stack`). La regla solo mira pilas cuyo item **del catálogo** es `PieceData`: una pila de material sigue con las reglas de la spec 005 (por ejemplo, `add_stacks` reparte una pila por encima de `stack_max`, R-005-05) y `DroppedItemSpawner` sigue aceptando los materiales que acepta hoy. Se valida después de cambiar el item por el del catálogo (como ya hace `add_stacks`, R-005-11), para que un `ItemData` ajeno con id `basic_arms` no entre como material. `add(item_id, n)` de una pieza y `add_stacks` con una pila de pieza inválida se rechazan (`push_error`, `ERR_INVALID_REQUEST`). Las piezas solo entran creadas por `CraftingSystem.create_result` o como pila que ya trae su `uid`. | Sin esto, `add(&"basic_arms", 3)` crearía tres piezas sin identidad, o con el mismo `uid` si se copiara (R-011-07, R-011-08). Es la misma regla que aplica la carga (R-011-11), así que se escribe una vez. Una pieza a 0 no vive en un inventario: BALANCE §4.1 la da por perdida (la quita la spec 015). |
| D2 | Las pilas se siguen fusionando solo por id, como hoy. Una pieza nunca se fusiona porque su `stack_max` es 1 (R-011-01): no hace falta otra regla de apilado. | Menos código; el test de R-011-08 lo vigila (dos Brazos, dos ranuras). |
| D3 | `InventoryRules.add(slots, item, n)` pasa a ser `add_stack(slots, ItemStack.new(item, n))`; `add_stack` copia durabilidad y `uid` a cada ranura nueva. `split` devuelve una copia con durabilidad y `uid`. Los sobrantes (`leftovers`) también los conservan. | Un solo camino de llenado: lo que hoy pierde la pieza (`_fill_empty_slots`, `split`, `ItemStack.new` en los sobrantes) queda arreglado en un sitio (R-011-09). |
| D4 | Tramos de reparación en porcentaje entero: el primer tramo, en orden ascendente, con `durabilidad × 100 ≤ up_to_percent × durability_max` da el coste. Datos: `{25: 3 hierro + 2 cables}`, `{100: 2 hierro + 1 cable}`. | Enteros: sin errores de coma flotante en el borde (25/100 → tramo caro, 26/100 → barato). El umbral del 25 % vive en el `.tres` (R-011-06); el `100` del script es la escala del porcentaje (`CraftingSystem.PERCENT`), no un valor de juego. |
| D5 | Antes del coste, la comprobación de reparar rechaza en este orden: `uid` desconocido (`ERR_PIECE_NOT_FOUND`), intacta (`ERR_PIECE_INTACT`), rota (`ERR_PIECE_BROKEN`), sin materiales (`ERR_NOT_ENOUGH_MATERIALS`). | Un motivo por caso (R-011-17, R-011-18, R-011-20). El `push_error` del `uid` desconocido lo hace `InventoryComponent.repair` (la UI nunca lo pide: lista solo lo que hay). |
| D6 | Crear comprueba la ranura **después** de cobrar, sobre una copia **profunda** de las ranuras (`ItemStack.copy()` por ranura; `InventoryRules.remove` resta en la propia pila): `remove_many` en la copia y `space_for(result) ≥ 1`. Un test comprueba que `check_craft` no cambia las ranuras que recibe. Motivo `ERR_NO_ROOM_FOR_RESULT`, clave nueva. | Cuenta la ranura que libera un pago que vacía una pila (pregunta 3). Una clave propia dice más que "Inventario lleno". |
| D7 | Quien emite los eventos es el banco (`RepairBench`), no el inventario: el componente no conoce el `player_uid` ni el bus, y architecture §7 ya nombra al banco como emisor de `item_crafted`. La pantalla recibe el banco en su contexto; `BaseZone.get_bench()` se lo da a `BuildFlow`. | Mismo patrón que `BaseStructures.place(player, …)` y `ChargingStation`. |
| D8 | Evento nuevo `piece_repaired(piece_uid: String, player_uid: String)` (fila nueva en architecture §7); `item_crafted(recipe_id, player_uid)` ya estaba en la tabla y se declara ahora. `SaveManager` añade `REASON_ITEM_CRAFTED` y `REASON_PIECE_REPAIRED` y los conecta con `_on_save_fact`, como `structure_built`. | R-011-28. El guardado sigue diferido y agrupado (spec 010). |
| D9 | `BenchScreen` (id `&"bench"`) sustituye a `BuildScreen` (id `&"build"`): se borran `build_screen.gd/.tscn`, `screens.tres` cambia la entrada y la lógica de construir pasa tal cual a `BenchBuildSection`. Los tests de R-009-38/39/64/65 de `test_build_screen.gd` pasan a `test_bench_screen.gd` con los mismos nombres y asserts (solo cambia cómo se llega a la fila). Son cinco (dos de R-009-64); el título esperado pasa de `BUILD_TITLE` a `BENCH_TITLE` por R-011-21, y `BUILD_TITLE` se sigue comprobando como título de la pestaña Construir (anotado al implementar). | R-011-21 pide una sola pantalla. Borrar archivos de la spec 009 se aprueba con este plan. |
| D10 | Títulos de pestaña con `set_tab_title(i, tr(key))` en `setup()`. | No depende de si `TabBar` traduce solo sus títulos (la referencia de clases no lo dice, §5.1). No hay cambio de idioma en caliente en el PMV. |
| D11 | Refresco: Construir y Crear tienen filas fijas (una por receta) y solo actualizan botón y aviso; Reparar rehace su lista (las piezas dañadas cambian). Las filas viejas salen con `remove_child` + `queue_free`. | R-011-25 sin leer estado en `_process`; liberar diferido porque el refresco llega dentro del `pressed` del botón que lo provocó. |
| D12 | El formato del objeto caído gana `durability` y `uid` por pila, opcionales con los valores por defecto `-1` y `""`. No sube `schema_version`. La regla se deja escrita en architecture §10.2: añadir un campo opcional cuyo valor por defecto reproduce lo que se cargaba antes no sube la versión; quitar, renombrar o cambiar el significado de uno sí. | Un archivo de la spec 010 carga igual: no tenía piezas y sus pilas sin esos campos son materiales válidos. Es una lectura de la pregunta 10 de la spec 010 (la versión sube cuando cambia la forma de una clave existente), por eso se escribe la regla. |
| D13 | Iconos de las tres piezas: SVG propios de marcador, CC0, como los de la spec 005, anotados en `assets/CREDITS.md`. | Presupuesto 0 € y R-005-31 (todo item tiene icono). |

## 2. Archivos

| Archivo (`game/…`) | Nuevo / Cambia | Responsabilidad |
|---|---|---|
| `scripts/data/piece_data.gd` | Nuevo | `PieceData extends ItemData`: `durability_max` |
| `scripts/data/recipe_data.gd` | Cambia | `result_item: ItemData` |
| `scripts/data/repair_tier_data.gd` | Nuevo | Un tramo: `up_to_percent`, `ingredients` |
| `scripts/data/repair_cost_data.gd` | Nuevo | Los tramos, ascendentes |
| `scripts/data/data_catalog.gd` | Cambia | `repair_costs: RepairCostData` |
| `scripts/data/action_result.gd` | Cambia | `ERR_INVALID_REQUEST` vive aquí (capa Datos) y `InventoryComponent` la toma como alias, para que `CraftingSystem` no conozca un nodo (revisión de `architecture-guardian` al implementar) |
| `scripts/systems/inventory_rules.gd` | Cambia | `add_stack`, `is_valid_stack`, `index_of_uid`; `add` y `split` conservan durabilidad y `uid` |
| `scripts/systems/crafting_system.gd` | Cambia | `check_craft`, `create_result`, `repair_cost`, `check_repair`, `is_damaged`; claves nuevas |
| `scripts/components/inventory_component.gd` | Cambia | `craft`, `repair`; todos los caminos con `add_stack`; rechazo y validación de piezas (D1) |
| `scenes/entities/dropped_item.gd` | Cambia | `to_data()` con `durability` y `uid` |
| `scenes/entities/dropped_item_spawner.gd` | Cambia | `_restore_stacks` los lee y valida con `is_valid_stack` |
| `scenes/base/repair_bench.gd` | Cambia | `craft(player, recipe)`, `repair(player, piece_uid)`; emite los eventos |
| `scenes/base/base_zone.gd` | Cambia | `get_bench()` |
| `scenes/base/build_flow.gd` | Cambia | Abre `BenchScreen` con jugador, estructuras y banco |
| `scripts/autoload/event_bus.gd` | Cambia | `item_crafted`, `piece_repaired` |
| `scripts/autoload/save_manager.gd` | Cambia | Dos razones nuevas y sus conexiones |
| `scenes/ui/bench_screen.tscn` / `.gd` | Nuevo | Pantalla del banco: pestañas, contexto, refresco |
| `scenes/ui/bench_entry.gd` | Nuevo | Fila: icono, nombre, detalle, coste, aviso y botón |
| `scenes/ui/bench_build_section.gd` | Nuevo | Pestaña Construir (lógica de `BuildScreen`) |
| `scenes/ui/bench_craft_section.gd` | Nuevo | Pestaña Crear |
| `scenes/ui/bench_repair_section.gd` | Nuevo | Pestaña Reparar |
| `scenes/ui/build_screen.tscn` / `.gd` | Se borra | Sustituida por `BenchScreen` (D9) |
| `resources/ui/screens.tres` | Cambia | `&"build"` → `&"bench"` |
| `resources/pieces/basic_arms.tres`, `basic_legs.tres`, `basic_core.tres` | Nuevo | Las tres piezas |
| `resources/recipes/basic_arms.tres`, `basic_legs.tres`, `basic_core.tres` | Nuevo | Sus recetas |
| `resources/config/repair_costs.tres` | Nuevo | Tramos de BALANCE §4.3.2 |
| `resources/data_catalog.tres` | Cambia | Piezas en `items`, recetas nuevas, `repair_costs` |
| `assets/textures/icons/items/basic_arms.svg`, `basic_legs.svg`, `basic_core.svg` | Nuevo | Iconos de marcador (D13) |
| `assets/CREDITS.md` | Cambia | Los tres iconos |
| `i18n/strings.csv` | Cambia | Claves de §4.1 |
| `tests/…` | Nuevos y cambian | §5 |
| `specs/architecture.md` | Cambia | §7: fila `piece_repaired`, emisor y oyentes de `item_crafted`; §8: `repair_costs` en el catálogo; §9.3: `PieceData` nace en la 011 con `durability_max`; §10.2: regla de los campos opcionales (D12) |

## 3. Contratos

```gdscript
class_name PieceData
extends ItemData
## A robot piece (spec 011): a unique inventory item with its own uid and
## durability in its ItemStack. Spec 015 adds slot_type and modifiers.

## BALANCE §4.1. Its stack_max is always 1 (a catalog test guards it).
@export var durability_max: int = 0
```

```gdscript
# RecipeData (added)
## The item it makes, one unit (spec 011); null for a structure recipe.
## Every catalog recipe sets exactly one of result_structure and result_item (R-011-03).
@export var result_item: ItemData
```

```gdscript
class_name RepairTierData
extends Resource
## Highest durability left, in percent of the maximum, this tier covers (inclusive).
@export var up_to_percent: int = 0
@export var ingredients: Array[RecipeIngredientData] = []

class_name RepairCostData
extends Resource
## Ascending by up_to_percent; the last one is 100 (a catalog test guards both).
@export var tiers: Array[RepairTierData] = []

# DataCatalog (added)
## Repair cost tiers of BALANCE §4.3.2 (spec 011, R-011-06).
@export var repair_costs: RepairCostData
```

```gdscript
# InventoryRules (added / changed)
## Like add() for one stack: new slots copy its durability and uid (R-011-09). Returns what did not fit.
static func add_stack(slots: Array[ItemStack], stack: ItemStack) -> int
## add(slots, item, quantity) == add_stack(slots, ItemStack.new(item, quantity)).
static func add(slots: Array[ItemStack], item: ItemData, quantity: int) -> int
## Now keeps durability and uid in the returned stack.
static func split(slots: Array[ItemStack], slot_index: int, quantity: int) -> ItemStack
## True for a stack whose item is not a PieceData (materials keep the rules of spec 005). A PieceData
## needs quantity 1, durability in 1..durability_max and a non-empty uid (D1, R-011-11). The caller
## passes the stack with the catalog's item.
static func is_valid_stack(stack: ItemStack) -> bool
## Slot holding uid; -1 when none or uid is empty.
static func index_of_uid(slots: Array[ItemStack], uid: String) -> int
```

```gdscript
# CraftingSystem (added)
const ERR_NO_ROOM_FOR_RESULT := &"ERR_NO_ROOM_FOR_RESULT"
const ERR_PIECE_INTACT := &"ERR_PIECE_INTACT"
const ERR_PIECE_BROKEN := &"ERR_PIECE_BROKEN"
const ERR_PIECE_NOT_FOUND := &"ERR_PIECE_NOT_FOUND"
## Scale of RepairTierData.up_to_percent (D4); not a gameplay value.
const PERCENT := 100

## For an item recipe (the caller checks it has result_item): ERR_NOT_ENOUGH_MATERIALS, else
## ERR_NO_ROOM_FOR_RESULT when the result fits nowhere once paid (D6), else success (R-011-12).
## Never changes slots: it pays on a deep copy.
static func check_craft(slots: Array[ItemStack], recipe: RecipeData) -> ActionResult
## One unit of item; a PieceData gets durability_max and Uid.generate() (R-011-07).
static func create_result(item: ItemData) -> ItemStack
## A PieceData below its maximum (0 included).
static func is_damaged(stack: ItemStack) -> bool
## Item id → quantity of the first tier that covers the piece's durability (D4, R-011-16);
## empty, with push_error, when no tier does (bad data) or the stack is not a piece.
static func repair_cost(stack: ItemStack, costs: RepairCostData) -> Dictionary[StringName, int]
## In the order of D5 (R-011-17, R-011-18, R-011-20).
static func check_repair(slots: Array[ItemStack], piece_uid: String, costs: RepairCostData) -> ActionResult
```

`cost_of(recipe)` y `repair_cost` suman ingredientes con la misma función privada.

```gdscript
# InventoryComponent (added)
## Pays the recipe and adds its result in one step, one inventory_changed (R-011-13, R-011-15).
## No recipe, no result_item, a result_structure, or an item this catalog does not know → push_error,
## ERR_INVALID_REQUEST, no change. A check_craft refusal → its key, no change (R-011-14).
func craft(recipe: RecipeData) -> ActionResult
## Pays repair_cost and sets that piece's durability to its maximum, keeping its uid and slot, in one
## step (R-011-19). Unknown uid → push_error and ERR_PIECE_NOT_FOUND; any other check_repair refusal
## → its key; no change either way (R-011-20). costs null → push_error, ERR_INVALID_REQUEST.
func repair(piece_uid: String, costs: RepairCostData) -> ActionResult
```

Cambios de comportamiento de `InventoryComponent` (D1, D3): `add` de una pieza y `add_stacks` con una pila que no
pasa `is_valid_stack` → `push_error`, `ERR_INVALID_REQUEST`, sin cambios; `add_stacks`, `take_from`,
`take_amount_from` y los sobrantes conservan durabilidad y `uid`; `from_save_data` descarta con `push_error` la
ranura que no pase `is_valid_stack` (R-011-11).

```gdscript
# RepairBench (added)
## The player's craft request at this bench (D7): player.inventory.craft(recipe) and, when ok,
## EventBus.item_crafted(recipe.id, player.player_uid). Not a WORKBENCH recipe or no player →
## push_error, ERR_INVALID_REQUEST.
func craft(player: Robot, recipe: RecipeData) -> ActionResult
## player.inventory.repair(piece_uid, the catalog's repair_costs) and, when ok,
## EventBus.piece_repaired(piece_uid, player.player_uid).
func repair(player: Robot, piece_uid: String) -> ActionResult

# BaseZone (added)
func get_bench() -> RepairBench

# EventBus (added)
## A player crafted an item at the bench and paid it. Emitted by RepairBench, once per craft (spec 011).
signal item_crafted(recipe_id: StringName, player_uid: String)
## A player repaired a piece at the bench and paid it. Emitted by RepairBench, once per repair (spec 011).
signal piece_repaired(piece_uid: String, player_uid: String)

# SaveManager (added)
const REASON_ITEM_CRAFTED := &"item_crafted"
const REASON_PIECE_REPAIRED := &"piece_repaired"
```

```gdscript
class_name BenchScreen
extends UIScreen
## The repair bench (spec 011): tabs Build, Craft and Repair; opens on Build.

const SCREEN_ID := &"bench"
const CONTEXT_PLAYER := &"player"   # Robot
const CONTEXT_BASE := &"base"       # BaseStructures
const CONTEXT_BENCH := &"bench"     # RepairBench
enum Tab { BUILD, CRAFT, REPAIR }

## Missing or wrong context → push_error, no entries. Connects the player's inventory_changed.
func setup(context: Dictionary) -> void
func get_current_tab() -> Tab
func show_tab(tab: Tab) -> void
## Disconnects inventory_changed.
func on_closed() -> void

class_name BenchEntry
extends HBoxContainer
## One row: Icon, Name, Detail (optional), Cost, Notice and ActionButton.
signal pressed
## The cost shows as "Scrap x4, Cables x2" in the current language (BUILD_COST_ENTRY), built with tr()
## by the entry itself (an instance method: tr() is not available in a static function).
func setup(icon: Texture2D, name_key: StringName, detail: String, cost: Dictionary[StringName, int], button_key: StringName) -> void
## &"" enables the button and hides the notice; otherwise disables it and shows tr(reason).
func set_blocked(reason: StringName) -> void

class_name BenchBuildSection
extends VBoxContainer
const MSG_BASE_FULL := &"MSG_BASE_FULL"
## The screen closes and calls player.request_build(recipe) (R-009-65).
signal build_picked(recipe: RecipeData)
func setup(player: Robot, structures: BaseStructures) -> void
func refresh() -> void
## &"" when it can be built (R-009-38, R-009-39).
func blocking_reason(recipe: RecipeData) -> StringName

class_name BenchCraftSection
extends VBoxContainer
## One fixed row per WORKBENCH recipe with result_item, named by recipe id (R-011-22).
func setup(player: Robot, bench: RepairBench) -> void
func refresh() -> void

class_name BenchRepairSection
extends VBoxContainer
## One row per damaged piece, named by its uid; %NothingToRepair when there is none (R-011-24).
func setup(player: Robot, bench: RepairBench, costs: RepairCostData) -> void
func refresh() -> void
```

`BuildFlow._on_bench_used` abre `BenchScreen.SCREEN_ID` con los tres contextos; el resto de `BuildFlow` no
cambia.

## 4. Datos

| Recurso / `.tres` | Campos | Valores desde |
|---|---|---|
| `resources/pieces/basic_arms.tres` (`PieceData`) | `id = basic_arms`, `name_key = ITEM_BASIC_ARMS`, `stack_max = 1`, `durability_max = 100`, `icon` | BALANCE §4.1 (durabilidad máxima), R-011-01 |
| `resources/pieces/basic_legs.tres` | `basic_legs`, `ITEM_BASIC_LEGS`, 1, 100, `icon` | BALANCE §4.1 |
| `resources/pieces/basic_core.tres` | `basic_core`, `ITEM_BASIC_CORE`, 1, 100, `icon` | BALANCE §4.1 |
| `resources/recipes/basic_arms.tres` | `id = basic_arms`, `WORKBENCH`, tier 1, sin `requires`, `result_item` = brazos; 4 chatarra + 2 cables | BALANCE §4.3.1 |
| `resources/recipes/basic_legs.tres` | 4 chatarra + 2 hierro | BALANCE §4.3.1 |
| `resources/recipes/basic_core.tres` | 6 chatarra + 3 cables + 2 hierro | BALANCE §4.3.1 |
| `resources/config/repair_costs.tres` (`RepairCostData`) | tramo `up_to_percent = 25`: 3 hierro + 2 cables; tramo `up_to_percent = 100`: 2 hierro + 1 cable | BALANCE §4.3.2 (tramos, decisión nov 2026) |
| `resources/data_catalog.tres` | `items` + las tres piezas; `recipes` + las tres recetas; `repair_costs` | architecture §8 |

Ids estables (architecture §8): los de pieza y receta coinciden a propósito; son de tipos distintos, así que no
chocan (cada tipo tiene su índice).

### 4.1 Claves de traducción (ES + EN)

| Clave | EN | ES |
|---|---|---|
| `ITEM_BASIC_ARMS` | Basic arms | Brazos básicos |
| `ITEM_BASIC_LEGS` | Basic legs | Piernas básicas |
| `ITEM_BASIC_CORE` | Basic core | Core básico |
| `BENCH_TITLE` | Repair bench | Banco de reparaciones |
| `CRAFT_TITLE` | Create | Crear |
| `REPAIR_TITLE` | Repair | Reparar |
| `CRAFT_BUTTON` | Create | Crear |
| `REPAIR_BUTTON` | Repair | Reparar |
| `BENCH_DURABILITY` | Durability %d/%d | Durabilidad %d/%d |
| `ERR_NO_ROOM_FOR_RESULT` | No free slot for it | No hay ranura libre para la pieza |
| `ERR_PIECE_INTACT` | It is in perfect condition | Está como nueva |
| `ERR_PIECE_BROKEN` | Broken, it cannot be repaired | Está rota, no se puede reparar |
| `ERR_PIECE_NOT_FOUND` | That piece is not in the inventory | Esa pieza no está en el inventario |
| `MSG_NOTHING_TO_REPAIR` | Nothing to repair | No hay nada que reparar |

Se reutilizan `BUILD_TITLE` (ahora título de la pestaña Construir), `BUILD_BUTTON`, `BUILD_COST_ENTRY`,
`ERR_NOT_ENOUGH_MATERIALS`, `MSG_BASE_FULL` y `ERR_INVALID_REQUEST`.

## 5. Verificación

### 5.1 Puntos comprobados al planificar (2026-11-17)

Referencia de clases generada con `--doctool` de Godot 4.7.2:

| Punto | Resultado |
|---|---|
| `TabContainer.set_tab_title(idx, title)`, `current_tab`, `get_tab_count()`, señal `tab_changed`, `tab_focus_mode` | Existen. La referencia no dice si `TabBar` traduce sus títulos: se evita depender de ello (D10) |
| `TextureRect.expand_mode = EXPAND_IGNORE_SIZE`, `stretch_mode = STRETCH_KEEP_ASPECT_CENTERED` | Existen |
| Herencia de un recurso con `class_name` exportado (`PieceData extends ItemData`) en un `Array[ItemData]` exportado | GDScript estándar, ya usado por `InventoryAddResult extends ActionResult`; sin punto **(verificar)** |

No queda ningún punto **(verificar)**.

### 5.2 Requisitos

| Requisito | Test (`game/tests/…`) o paso manual |
|---|---|
| R-011-01 | `unit/test_piece_resources.gd::test_r_011_01_piece_data_extends_item_data`, `::test_r_011_01_every_piece_stacks_one_with_balance_durability` |
| R-011-02 | `unit/test_piece_resources.gd::test_r_011_02_basic_pieces_listed_with_icon`, `::test_r_011_02_piece_names_translated_es_en`, `::test_r_011_02_every_piece_file_in_catalog` |
| R-011-03 | `unit/test_data_catalog.gd::test_r_011_03_every_recipe_has_one_result`; `unit/test_inventory_component.gd::test_r_011_03_craft_rejects_structure_recipe` |
| R-011-04 | `unit/test_recipe_resources.gd::test_r_011_04_piece_recipes_match_balance` |
| R-011-05 | `unit/test_data_catalog.gd::test_r_011_05_recipes_workbench_tier_1_no_requires`, `::test_r_011_05_recipe_items_in_catalog` |
| R-011-06 | `unit/test_data_catalog.gd::test_r_011_06_repair_costs_match_balance`, `::test_r_011_06_repair_tiers_ascending_up_to_100`; sin literales: `balance-auditor` en el cierre |
| R-011-07 | `unit/test_crafting_system.gd::test_r_011_07_create_result_piece`, `::test_r_011_07_create_result_new_uid_each_time`; `unit/test_inventory_component.gd::test_r_011_07_add_piece_by_id_rejected`, `::test_r_011_07_invalid_piece_stack_rejected` |
| R-011-08 | `unit/test_inventory_rules.gd::test_r_011_08_pieces_never_merge`; `unit/test_inventory_component.gd::test_r_011_08_two_crafted_arms_two_slots` |
| R-011-09 | `unit/test_inventory_rules.gd::test_r_011_09_add_stack_keeps_durability_and_uid`, `::test_r_011_09_split_keeps_durability_and_uid`; `unit/test_inventory_component.gd::test_r_011_09_take_from_keeps_piece`, `::test_r_011_09_take_amount_from_keeps_piece`, `::test_r_011_09_add_stacks_keeps_piece`, `::test_r_011_09_leftover_keeps_piece`; `integration/test_dropped_item_spawner.gd::test_r_011_09_throw_and_pick_up_keep_piece`; `integration/test_death_controller.gd::test_r_011_09_death_drops_and_recovers_piece` |
| R-011-10 | `unit/test_dropped_item.gd::test_r_011_10_to_data_has_durability_and_uid`; `integration/test_dropped_item_spawner.gd::test_r_011_10_save_load_restores_piece`; `integration/test_save_load.gd::test_r_011_10_piece_survives_close_and_reopen` |
| R-011-11 | `unit/test_inventory_rules.gd::test_r_011_11_is_valid_stack` (una pila de material sigue siendo válida); `unit/test_inventory_component.gd::test_r_011_11_material_over_stack_max_still_split` (R-005-05 sin cambios); `unit/test_inventory_component.gd::test_r_011_11_bad_saved_piece_dropped` (durabilidad 0, por encima de la máxima, `uid` vacío; el resto carga); `integration/test_dropped_item_spawner.gd::test_r_011_11_bad_saved_piece_stack_lost` |
| R-011-12 | `unit/test_crafting_system.gd::test_r_011_12_exact`, `::test_r_011_12_surplus`, `::test_r_011_12_insufficient`, `::test_r_011_12_full_inventory`, `::test_r_011_12_payment_frees_the_slot`, `::test_r_011_12_check_does_not_change_slots` |
| R-011-13 | `unit/test_inventory_component.gd::test_r_011_13_craft_pays_and_adds_once`; `unit/test_repair_bench.gd::test_r_011_13_bench_craft_emits_item_crafted` |
| R-011-14 | `unit/test_inventory_component.gd::test_r_011_14_craft_refused_changes_nothing` (materiales y ranura, con su clave); `unit/test_repair_bench.gd::test_r_011_14_failed_craft_emits_nothing` |
| R-011-15 | `unit/test_inventory_component.gd::test_r_011_13_craft_pays_and_adds_once` (cobra y añade en la misma llamada); `unit/test_bench_screen.gd::test_r_011_15_create_acts_at_once` (sin otra pantalla ni espera) |
| R-011-16 | `unit/test_crafting_system.gd::test_r_011_16_repair_cost_tiers` (99, 26, 25, 1 sobre 100, y una pieza con otra máxima) |
| R-011-17 | `unit/test_crafting_system.gd::test_r_011_17_intact_refused`; `unit/test_inventory_component.gd::test_r_011_20_repair_refused_changes_nothing` |
| R-011-18 | `unit/test_crafting_system.gd::test_r_011_18_broken_refused`. Solo en el sistema: por D1 un `InventoryComponent` nunca tiene una pieza a 0 |
| R-011-19 | `unit/test_inventory_component.gd::test_r_011_19_repair_restores_keeps_uid_and_slot`; `unit/test_repair_bench.gd::test_r_011_19_bench_repair_emits_piece_repaired` |
| R-011-20 | `unit/test_crafting_system.gd::test_r_011_20_unknown_uid`; `unit/test_inventory_component.gd::test_r_011_20_repair_refused_changes_nothing`, `::test_r_011_20_unknown_uid_reports_error` |
| R-011-21 | `unit/test_bench_screen.gd::test_r_011_21_three_tabs_open_on_build`, y los cinco casos movidos de `test_build_screen.gd` (`test_r_009_64_*`, `test_r_009_39_*`, `test_r_009_38_*`, `test_r_009_65_*`); `integration/test_build_flow.gd::test_r_009_64_bench_opens_build_screen` (ahora `BenchScreen`) |
| R-011-22 | `unit/test_bench_screen.gd::test_r_011_22_craft_lists_item_recipes` |
| R-011-23 | `unit/test_bench_screen.gd::test_r_011_23_missing_materials_disables`, `::test_r_011_23_no_room_disables` |
| R-011-24 | `unit/test_bench_screen.gd::test_r_011_24_lists_damaged_pieces`, `::test_r_011_24_cannot_pay_disables`, `::test_r_011_24_nothing_to_repair` |
| R-011-25 | `unit/test_bench_screen.gd::test_r_011_25_updates_on_inventory_change` (las tres pestañas) |
| R-011-26 | `unit/test_bench_screen.gd::test_r_011_26_stays_open_after_craft_and_repair` |
| R-011-27 | `unit/test_bench_screen.gd::test_r_011_27_texts_are_keys_es_en`; `i18n-auditor` en el cierre |
| R-011-28 | `integration/test_save_triggers.gd::test_r_011_28_craft_and_repair_save` (`MemorySaveStore`, una partida guardada por acción con su razón); `unit/test_event_bus.gd::test_r_011_28_bench_event_signatures` |

### 5.3 Pasos manuales

- **M1 (PC)**: partida nueva; recoger en la zona verde materiales para unos Brazos (4 chatarra, 2 cables);
  volver a la base y usar el banco. Abre en Construir; Crear muestra las tres piezas con icono, nombre y coste;
  con lo justo, "Crear" de Brazos resta los materiales, la pieza aparece en una ranura propia y la pantalla
  sigue abierta. Sin materiales, el botón está desactivado con "Faltan materiales". Reparar dice "No hay nada que
  reparar". Escape cierra.
- **M2 (PC)**: con unos Brazos en el inventario, tirarlos y recogerlos; morir con ellos y recuperarlos; cerrar y
  abrir el juego. La pieza sigue siendo una (mismo icono, una ranura) en cada paso. El `uid` se comprueba en los
  tests (no se ve en el juego).
- **M3 (Android, APK debug)**: las tres pestañas y los botones se pueden tocar con el dedo en horizontal
  1920x1080, los textos caben en ES y EN, y el botón atrás cierra la pantalla.

### 5.4 Resultado de los pasos manuales (T-011-10, 2026-11-18)

Hechos por la persona que revisa en PC (Windows) y en Android (APK debug). Resultado según su informe: todo pasa.

| Paso | Resultado |
|---|---|
| M1 (PC) | ✅ El banco abre en Construir; Crear lista las tres piezas; crear unos Brazos resta los materiales, la pieza ocupa una ranura propia y la pantalla sigue abierta; sin materiales, botón desactivado con "Faltan materiales"; Reparar dice "No hay nada que reparar"; Escape cierra |
| M2 (PC) | ✅ Tirar y recoger, morir y recuperar, y cerrar y abrir el juego dejan la pieza como una sola (mismo icono, una ranura) |
| M3 (Android) | ✅ Pestañas y botones se tocan con el dedo en horizontal, los textos caben en ES y EN y el botón atrás cierra |

**Desviaciones de implementación.** Las firmas de §3 se cumplen. Cambios anotados al implementar: se mueven cinco
tests de `test_build_screen.gd`, no cuatro (D9); `ERR_INVALID_REQUEST` pasa a `ActionResult` (§2 y §7.2).

## 6. Check de constitución

| Principio | Cumple | Nota |
|---|---|---|
| P1 Spec primero | ✅ | Spec aprobada el 2026-11-17 con sus preguntas cerradas |
| P2 Una fuente de verdad | ✅ | Durabilidad, recetas y tramos en `.tres` desde BALANCE §4.1, §4.3.1, §4.3.2. `CraftingSystem.PERCENT` es la escala del porcentaje, no un valor de juego (D4). Coste de construir, crear y reparar se muestra con una sola función de `BenchEntry` y se suma con una sola función privada |
| P3 Lógica separada | ✅ | Comprobar, crear el resultado y costes en `CraftingSystem` / `InventoryRules` sin nodos; el componente escribe; la UI solo pide al banco y muestra |
| P4 Estado por jugador | ✅ | Las piezas viven en el `InventoryComponent` del robot; el banco no guarda estado |
| P5 Datos como recursos | ✅ | `PieceData`, `RepairCostData`, `RepairTierData` con `class_name` y `.tres` |
| P6 Señales | ✅ | Dos eventos del bus con fila en architecture §7 y `player_uid`; la pantalla escucha `inventory_changed`; sin rutas `get_node` largas (`%UniqueName` en la escena, nombres de fila para los tests) |
| P7 Tipado | ✅ | Todo tipado; `Dictionary[StringName, int]` para costes |
| P8 Plataforma | ✅ | La pantalla usa botones y `UIManager`; Escape/atrás ya los atiende `UIManager` |
| P9 Determinismo | ✅ | El `uid` de una pieza es identidad, no generación del mundo (como el de las estructuras, spec 009) |
| P11 i18n | ✅ | Claves de §4.1 en ES y EN; títulos de pestaña con `tr()` (D10) |
| P12 Presupuesto móvil | ✅ | Solo UI; sin luces ni mallas nuevas |
| P13 Test primero | ✅ | Cada tarea de lógica empieza por su test (tasks.md) |
| P14 Alcance | ✅ | Sin equipo, stats ni desgaste (spec 015). Dos cambios fuera de lo literal, justificados: el rechazo de piezas inválidas en `add`/`add_stacks` (D1, protege R-011-07 y R-011-08) y el borrado de `BuildScreen` (D9, lo pide R-011-21) |

## 7. Riesgos y alternativas descartadas

- **Borrar `BuildScreen`** cambia tests de las specs 009 y 010 que la nombran (`test_build_flow.gd`,
  `test_base_loop.gd`, `test_main_scene.gd`, `test_ui_manager.gd`, y el comentario de `test_base_structures.gd`) → se actualizan a `BenchScreen` sin quitar
  asserts; los cinco tests de `test_build_screen.gd` se mueven con sus nombres (D9).
- **La spec 015 rompe piezas a 0**: si en vez de quitarlas las deja en el inventario, `is_valid_stack` las
  rechazaría al cargar → se anota en el cierre para la 015 (BALANCE §4.1 dice que una pieza rota se pierde).
- **La spec 016 suelta piezas en el loot**: `LootSystem` crea pilas con `ItemStack.new(item, n)`, que `add_stacks`
  rechazaría para una pieza (D1) → la 016 debe crearlas con `CraftingSystem.create_result` (o un equivalente con
  durabilidad al 50 %). Se anota en README §6 al cerrar.
- **Refrescar dentro de la señal del botón** que se libera (Reparar) → `remove_child` + `queue_free` (D11); un
  test pulsa "Reparar" y comprueba que la fila nueva está y la vieja no.
- **Dos guardados seguidos** al crear varias piezas en un fotograma → `SaveManager` ya los agrupa (spec 010).
- **Una pila de material con `uid` dividida por encima de `stack_max`** (revisión al implementar, 2026-11-18):
  `InventoryRules._fill_empty_slots` copia la plantilla, así que el `uid` se repetiría en varias ranuras. Hoy no
  pasa (los materiales no tienen `uid` y las piezas tienen `stack_max` 1). → Aceptado; a tener en cuenta en la 015
  si algún item apilable gana `uid`.
- **Descartado**: `craft_piece()` en `CraftingSystem` cambiando el inventario (§1); tres pantallas separadas y una
  lista mezclada (pregunta 4); un `uid` por pila de material (no hace falta identidad); subir `schema_version`
  por los campos nuevos del objeto caído (D12); confiar en que `TabBar` traduzca sus títulos (D10).

### 7.1 Revisión de `architecture-guardian` (2026-11-17)

Sin bloqueantes. Aplicado: copia profunda en `check_craft` y su test (D6); la validación de piezas solo toca
pilas de `PieceData`, contra el item del catálogo, y los materiales siguen con las reglas de la spec 005 (D1,
`is_valid_stack`, test de R-005-05); la regla de los campos opcionales del guardado se escribe en architecture §10.2
(D12); `BenchEntry` construye el coste en un método de instancia (`tr()` no existe en una función estática);
`test_base_structures.gd` en la lista de D9; la fila de R-011-18 explica por qué solo se prueba en el sistema;
ACTION_PLAN 2.4 recoge que `CraftingSystem` comprueba y `InventoryComponent` cambia el inventario. Pendiente fuera
del plan: `main` aún no tiene la spec 010 (requisito previo de tasks.md) y la sección "Repository state" de
CLAUDE.md nombra `BuildScreen` (se actualiza en el cierre).

### 7.2 Revisión de `architecture-guardian` en el cierre (2026-11-18)

Un bloqueante, corregido: `CraftingSystem` (sistema puro) devolvía una constante de `InventoryComponent` (un nodo).
`ERR_INVALID_REQUEST` vive ahora en `ActionResult`, en la capa de datos, y el componente la expone como alias.
Corregido también: nombres de tests con su id de requisito, orden de miembros de `BenchScreen`, la creación ya
comprobada como `assert` en vez de rama de error, y `BuildFlow` guarda la base cargada en lugar de un `bind`.
