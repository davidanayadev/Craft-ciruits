# Plan 005 — Inventario: `InventoryComponent`, UI y loot al jugador

| Campo | Valor |
|---|---|
| **Spec** | [spec.md](spec.md) (debe estar *Aprobado*) |
| **Estado** | Planificado (2026-11-15) |

## 1. Enfoque

**Tres capas, como pide architecture §3.**
- `InventoryRules` (sistema puro): apila, cuenta y quita sobre un `Array[ItemStack]` que recibe por parámetro
  (`null` = ranura vacía).
- `InventoryComponent`: es el dueño de ese array y su único escritor. Valida la petición, llama a las reglas,
  devuelve un `ActionResult` y emite `inventory_changed` una vez si algo cambió.
- La UI (pantallas y HUD) solo lee `get_slots()`, que devuelve copias, escucha señales y **pide** los cambios al
  componente dueño.

**Ranuras.**
- `ChassisLevelData` nace aquí con la tabla de BALANCE §6.1 (XP y ranuras por nivel), la única fuente del número.
- El componente no sabe nada del chasis: tiene `set_slot_count()`, que solo deja crecer.
- `Robot._ready()` le pone las ranuras del nivel 1. La Tarea 2.7 hará la misma llamada al subir de nivel
  (R-005-13).
- Como no depende del chasis, el mismo componente guarda el contenido de las cajas, y servirá para los cofres
  (2.6).

**Items por id.**
- `add`, `remove`, `has` y `count` reciben `item_id: StringName` (spec, pregunta 3).
- El componente valida el id contra un `DataCatalog`: por defecto el de `DataRegistry`, y en los tests uno hecho a
  mano.
- Guarda el `ItemData` del catálogo, así que un `ItemStack` que llegue con otra instancia del mismo id se normaliza.
- `add_stacks()` mete varias pilas de golpe: valida todo antes de tocar nada y emite una sola señal.

**Resultados.**
- `ActionResult` es tal cual architecture §9.2.
- Añadir puede dejar sobrante (R-005-05), así que `add`, `add_stacks` y `take_from` devuelven
  `InventoryAddResult`, una subclase de `ActionResult` con `leftovers: Array[ItemStack]` (lo que no entró). La UI
  sigue leyendo `ok` y `error_key`.
- `ok` significa que entró todo. Un fallo por falta de sitio puede haber añadido una parte.
- Cuando algo no cabe, el componente que recibe emite `overflowed(leftovers)`. El HUD lo escucha para mostrar
  `MSG_INVENTORY_FULL`, y la misma señal servirá cuando el crafteo (2.4) entregue una pieza con el inventario lleno.

**Mover entre inventarios (R-005-15).** `take_from(source, slot_indices)` vive en el componente que **recibe**:
1. Copia las pilas de esas ranuras de `source` y mete en sus propias ranuras lo que quepa, en el orden de los
   índices.
2. Pide a `source` que quite exactamente lo que entró, ranura a ranura, con `remove_from_slots(amounts)`.

Cada componente escribe solo sus ranuras y emite una sola señal. Si nada cabe, ninguno cambia. Es la base de "coger"
en la pantalla de caja y la reutilizarán los cofres (2.6) para depositar.

**Cajas (R-005-16..22).**
- `LootBox` tiene un `InventoryComponent` hijo (`%Contents`) con su contenido.
- En la **primera** interacción tira su tabla con su semilla, como en la 004. Pone en `%Contents` tantas ranuras
  como pilas salieron y las mete. Pasa al aspecto de abierta y emite `loot_generated` (se mantiene para R-004-23).
- En **cada** interacción con contenido emite `opened(opener)`. La caja no conoce ni el inventario del jugador ni la
  UI.
- La caja escucha el `inventory_changed` de su `%Contents`. Al quedarse vacía, desactiva su interactuable para el
  resto de la visita (R-005-21). Una tirada vacía la desactiva en el acto. Conecta esa señal **después** de llenar
  `%Contents` en la tirada: si no, el `set_slot_count()` de la propia tirada llegaría con la caja aún vacía y la
  desactivaría para siempre.
- `FarmZone`, que crea las cajas, conecta el `opened` de cada una y lo reemite como `box_opened(box, opener)`.
- `main.gd` escucha `box_opened`, busca el inventario de quien abre con `InventoryComponent.find_in(opener)` y abre
  la pantalla de caja con los dos inventarios en el contexto. Si no hay inventario, da error con los nombres de la
  caja y de quien abre, y no abre nada (R-005-22). Solo abre la pantalla si quien abre es el robot local enlazado al
  HUD. Con un jugador siempre lo es, pero así el cooperativo nunca abre en un cliente la pantalla de otro robot
  (architecture §9.5).
- Lo que no se coge se queda en `%Contents` (R-005-20). Volver a interactuar enseña lo mismo, porque solo se tira
  una vez (R-005-17).

**Cambia el comportamiento de la 004.** R-005-21 sustituye a R-004-24: la caja ya no se desactiva al abrirse, sino
al vaciarse. Los tests de R-004-24 que comprueban "desactivada al abrir" se reescriben como tests de R-005-21. Los
de R-004-23 (una sola tirada con la semilla de la caja) siguen igual.

**Pantallas (architecture §9.5).**
- `UIManager` es un nodo bajo `UI` en `main.tscn`, no un autoload: la lista de autoloads está cerrada.
- Los ids de pantalla se registran en un `UIScreenCatalog` (`.tres`, id → escena).
- `open(id, context)` instancia la escena, la añade encima y le llama `setup(context)`. `close_top()` la saca de la
  pila en el acto, así que `is_modal_open()` cambia enseguida, y la libera con `queue_free()`: el cierre puede
  llegar en medio de una señal de la propia pantalla (pulsar → `take_from` → `inventory_changed` →
  `close_requested`).
- Emite `modal_state_changed` solo al pasar de ninguna pantalla a alguna y al revés.
- Cierra la de arriba con la acción `pause` (Escape, ya existe desde la spec 001) y con
  `NOTIFICATION_WM_GO_BACK_REQUEST` (atrás en Android).
- Cada pantalla hereda de `UIScreen`, que tiene `setup(context)` y la señal `close_requested`. `UIManager` cierra
  la pantalla que la emite. Así la pantalla de caja se cierra sola al vaciarse sin conocer al `UIManager`.
- Añade `close_all()` a los miembros de architecture §9.5, para el game over.

**Pantallas de esta spec.** Las dos usan la misma rejilla, `InventoryGrid` (una celda `InventorySlotView` por
ranura de un `InventoryComponent`), que se repinta solo con `inventory_changed` (R-005-25, R-005-26).
- `InventoryScreen`: título y la rejilla del inventario del jugador. Las celdas no se pueden pulsar.
- `LootScreen`: título, rejilla de la caja (celdas que se pueden pulsar), rejilla del jugador y botón
  `LOOT_TAKE_ALL`.
  - Tocar una celda de la caja pide `player_inventory.take_from(box_contents, [i])`.
  - "Coger todo" pide `take_from()` con todas las ranuras ocupadas, en orden.
  - Cuando la caja se queda vacía, emite `close_requested`.
  - "Coger todo" y las celdas tienen `focus_mode = NONE`, como `%StorageButton`. Ningún control de las pantallas
    toma el foco, así que Tab sigue llegando a `open_storage` y Enter no pulsa nada por accidente.
- Las dos son un fondo oscuro a pantalla completa que consume los toques, con un panel centrado encima. Así el
  joystick flotante no aparece mientras están abiertas: R-002-10 solo lo crea fuera de los controles del HUD.
- `UIManager` va **antes** que `Hud` en el árbol de `UI`, así que se dibuja debajo. La batería, el aviso de
  inventario lleno y el botón de almacenamiento quedan visibles por encima, y ese botón cierra la pantalla
  (R-005-24).

**Entrada.**
- Botón de almacenamiento: el HUD lo muestra abajo en el centro y emite `storage_pressed`. La acción `open_storage`
  (Tab) la lee el HUD en `_unhandled_input` y emite la misma señal.
- `main.gd`: con la batería agotada no hace nada. Si hay una pantalla abierta, cierra la de arriba. Si no, abre el
  inventario (R-005-24, R-005-29).
- `main.gd` conecta `modal_state_changed` a `PlayerInput.set_input_blocked()` y a `Hud.set_modal_open()`:
  - con la entrada bloqueada, `PlayerInput` no da dirección, ni carrera, ni interactuar;
  - `Robot.request_interact()` (la vía del botón del HUD) tampoco hace nada;
  - el HUD muestra el botón de interactuar solo si hay objetivo **y** no hay pantalla abierta; un cambio de
    objetivo con una pantalla abierta no lo vuelve a mostrar.

  El robot sigue con su `_physics_process`, así que la batería gasta lo pasivo y el árbol no se pausa (R-005-27).
- Al agotarse la batería, `main.gd` cierra todas las pantallas (R-005-29).

**Iconos.** `ItemData` gana `icon: Texture2D`. Los tres son SVG de marcador hechos a mano: formas geométricas de
color, sin texto, para no tener que traducirlos. Son obra propia (CC0) y quedan anotados en `game/assets/CREDITS.md`
(R-005-32). Elegir un pack de Kenney es decisión del usuario (ACTION_PLAN 4.4 / 5.3), como en la 004.

## 2. Archivos

| Archivo (`game/…`) | Nuevo / Cambia | Responsabilidad |
|---|---|---|
| `scripts/data/action_result.gd` | Nuevo | `ActionResult` (architecture §9.2) |
| `scripts/data/inventory_add_result.gd` | Nuevo | `ActionResult` + `leftovers` |
| `scripts/data/item_stack.gd` | Cambia | `copy()` |
| `scripts/data/item_data.gd` | Cambia | `icon: Texture2D` |
| `scripts/data/chassis_level_data.gd` | Nuevo | Resource: XP y ranuras por nivel (BALANCE §6.1) |
| `scripts/data/ui_screen_catalog.gd` | Nuevo | Resource: id de pantalla → escena |
| `scripts/systems/inventory_rules.gd` | Nuevo | Reglas puras de apilado |
| `scripts/components/inventory_component.gd` | Nuevo | Dueño de las ranuras: `add`, `add_stacks`, `remove`, `remove_from_slots`, `take_from`, `has`, `count`, `get_slots`, `set_slot_count` |
| `scripts/components/player_input.gd` | Cambia | `set_input_blocked()` |
| `resources/progression/chassis_levels.tres` | Nuevo | BALANCE §6.1 |
| `resources/ui/screens.tres` | Nuevo | `inventory` → `inventory_screen.tscn`, `loot` → `loot_screen.tscn` |
| `resources/items/scrap.tres`, `cables.tres`, `iron.tres` | Cambia | `icon` |
| `assets/textures/icons/items/scrap.svg`, `cables.svg`, `iron.svg` | Nuevo | Iconos de marcador (obra propia, CC0) |
| `assets/CREDITS.md` | Nuevo | Origen y licencia de cada asset (R-005-32) |
| `scenes/ui/ui_screen.gd` | Nuevo | Clase base `UIScreen`: `setup(context)`, `close_requested` |
| `scenes/ui/ui_manager.tscn` + `ui_manager.gd` | Nuevo | Pila de pantallas, Escape y atrás |
| `scenes/ui/inventory_slot.tscn` + `inventory_slot.gd` | Nuevo | Una celda: icono y cantidad, o vacía; se puede pulsar o no |
| `scenes/ui/inventory_grid.tscn` + `inventory_grid.gd` | Nuevo | Rejilla enlazada a un `InventoryComponent`; emite `slot_pressed(index)` |
| `scenes/ui/inventory_screen.tscn` + `inventory_screen.gd` | Nuevo | Fondo, panel, título y rejilla del jugador |
| `scenes/ui/loot_screen.tscn` + `loot_screen.gd` | Nuevo | Fondo, panel, rejilla de la caja, rejilla del jugador, "Coger todo" |
| `scenes/ui/hud.tscn` + `hud.gd` | Cambia | `%StorageButton`, `storage_pressed`, Tab, `set_modal_open()`, `%MessageLabel` + `%MessageTimer` |
| `scenes/entities/loot_box.tscn` + `loot_box.gd` | Cambia | `%Contents`, tirada única, `opened`, desactivarse al vaciarse |
| `scenes/entities/robot.tscn` + `robot.gd` | Cambia | `%InventoryComponent`, `chassis_levels`, ranuras del nivel 1 en `_ready()`; `request_interact()` respeta el bloqueo |
| `scenes/farm_zone/farm_zone.gd` | Cambia | Reemite `opened` de cada caja como `box_opened(box, opener)` |
| `scenes/main.tscn` + `main.gd` | Cambia | `%UIManager` antes que `Hud`; abrir inventario y caja; bloquear entrada; cerrar en game over |
| `project.godot` | Cambia | `application/config/quit_on_go_back=false` **(verificar)** |
| `i18n/strings.csv` (+ `.translation` al importar) | Cambia | `HUD_STORAGE`, `INVENTORY_TITLE`, `LOOT_TITLE`, `LOOT_TAKE_ALL`, `MSG_INVENTORY_FULL`, `ERR_NOT_ENOUGH_ITEMS`, `ERR_INVALID_REQUEST` |
| `tests/unit/test_action_result.gd` | Nuevo | R-005-14 |
| `tests/unit/test_inventory_rules.gd` | Nuevo | R-005-01, R-005-03..07 |
| `tests/unit/test_inventory_component.gd` | Nuevo | R-005-05..15 |
| `tests/unit/test_chassis_level_data.gd` | Nuevo | R-005-02 |
| `tests/unit/test_player_input.gd` | Nuevo | R-005-27 |
| `tests/unit/test_ui_manager.gd` | Nuevo | R-005-27 (señal), R-005-28, `close_requested` |
| `tests/unit/test_inventory_screen.gd` | Nuevo | R-005-25, R-005-26, R-005-30 |
| `tests/unit/test_loot_screen.gd` | Nuevo | R-005-18..21 (pantalla), R-005-25, R-005-26, R-005-30 |
| `tests/unit/test_loot_box.gd` | Cambia | R-005-17, R-005-20, R-005-21; los de R-004-24 pasan a R-005-21; R-004-23 y R-004-25 siguen |
| `tests/unit/test_hud.gd` | Cambia | R-005-20 (mensaje), R-005-23, R-005-24, R-005-27 (botón oculto), R-005-30 |
| `tests/unit/test_data_catalog.gd` | Cambia | R-005-31; ninguna entrada de loot pasa del `stack_max` de su item |
| `tests/unit/test_project_settings.gd` | Cambia | R-005-33 (`quit_on_go_back`) |
| `tests/integration/test_robot_inventory.gd` | Nuevo | R-005-02, R-005-10 |
| `tests/integration/test_robot_interaction.gd` | Cambia | `test_r_004_24_opened_box_is_no_longer_offered` pasa a R-005-21 (caja vaciada) |
| `tests/integration/test_green_zone.gd` | Cambia | `box_opened` de cada caja |
| `tests/integration/test_main_scene.gd` | Cambia | R-005-16, R-005-19..22, R-005-24, R-005-27, R-005-29; `test_r_004_14_hud_button_opens_box` vacía la caja con `take_from` antes de comprobar que el botón se oculta (T-005-08, para que la suite no quede en rojo hasta T-005-15) |

No se crean `EventBus`, `ZoneLoader`, guardado ni `ChassisLevelSystem` (spec §4).

## 3. Contratos

```gdscript
class_name ActionResult
extends RefCounted

var ok: bool = false
var error_key: StringName = &""             # translation key; empty when ok

static func success() -> ActionResult
static func failure(key: StringName) -> ActionResult
```

```gdscript
class_name InventoryAddResult
extends ActionResult
## What was not added, one stack per offered stack, in the order offered. Empty when ok.
## On a rejected request (ERR_INVALID_REQUEST) it is everything offered.
var leftovers: Array[ItemStack] = []

static func added_all() -> InventoryAddResult
static func not_added(key: StringName, p_leftovers: Array[ItemStack]) -> InventoryAddResult
```

```gdscript
class_name ItemStack            # cambia
func copy() -> ItemStack        # same item, same quantity; never shares state with the original

class_name ItemData             # cambia
@export var icon: Texture2D     # required: the catalog test rejects an item without one (R-005-31)
```

```gdscript
class_name ChassisLevelData
extends Resource

const FIRST_LEVEL := 1

## Total XP to reach each level, level 1 first (BALANCE §6.1). ACTION_PLAN 2.7 uses it.
@export var xp_required: Array[int] = []
## Inventory slots at each level, level 1 first (BALANCE §6.1).
@export var inventory_slots: Array[int] = []

func get_level_count() -> int
## Level outside 1..get_level_count() → push_error and 0.
func get_inventory_slots(level: int) -> int
## Empty when valid: same size in both arrays, at least one level, values increasing.
func validate() -> PackedStringArray
```

```gdscript
class_name InventoryRules
extends RefCounted
## Pure stacking rules. Slots are an Array[ItemStack] where null is an empty
## slot; the caller owns it and these functions change it in place.

## Room for item: free room in its stacks below stack_max plus empty slots × stack_max.
static func space_for(slots: Array[ItemStack], item: ItemData) -> int
## Fills that item's stacks below stack_max in slot order, then empty slots in
## slot order. Returns the quantity that did not fit. quantity <= 0 or
## stack_max < 1 → push_error, no change, returns quantity.
static func add(slots: Array[ItemStack], item: ItemData, quantity: int) -> int
## Sum of item_id over every slot.
static func count(slots: Array[ItemStack], item_id: StringName) -> int
## Removes exactly quantity from the last slot towards the first; slots that
## reach 0 become null. Caller checks count() first; quantity above it →
## push_error and no change.
static func remove(slots: Array[ItemStack], item_id: StringName, quantity: int) -> void
```

```gdscript
class_name InventoryComponent
extends Node

const ERR_INVALID_REQUEST := &"ERR_INVALID_REQUEST"
const ERR_NOT_ENOUGH_ITEMS := &"ERR_NOT_ENOUGH_ITEMS"
const MSG_INVENTORY_FULL := &"MSG_INVENTORY_FULL"

## Once per operation that changed slots or slot count; never without a change.
signal inventory_changed
## Something offered to this inventory did not fit (part or all). Not emitted for rejected requests.
signal overflowed(leftovers: Array[ItemStack])

## Validates ids; DataRegistry's catalog when left null at _ready().
var catalog: DataCatalog

# add, add_stacks and take_from store copies: a stack the caller passes in is never
# kept, so nobody (a listener of loot_generated, for example) can change the slots
# through it.

func get_slot_count() -> int
## Grows to count slots, keeping contents. count < current → failure ERR_INVALID_REQUEST.
func set_slot_count(count: int) -> ActionResult
## Copies, slot order, null for empty: the caller can never change the inventory through them.
func get_slots() -> Array[ItemStack]
func is_empty() -> bool
func count(item_id: StringName) -> int                      # unknown id → push_error, 0
func has(item_id: StringName, quantity: int) -> bool        # count(item_id) >= quantity
## quantity <= 0 or unknown id → push_error naming the item, ERR_INVALID_REQUEST, no change.
## Not everything fits → adds what fits, MSG_INVENTORY_FULL with the leftover.
func add(item_id: StringName, quantity: int) -> InventoryAddResult
## Same rules for several stacks as one operation: validates all first, one inventory_changed.
func add_stacks(stacks: Array[ItemStack]) -> InventoryAddResult
## All or nothing: more than held → ERR_NOT_ENOUGH_ITEMS and no change.
func remove(item_id: StringName, quantity: int) -> ActionResult
## amounts[i] leaves slot i; size must equal the slot count and each amount must be
## within 0..that slot's quantity, otherwise ERR_INVALID_REQUEST and no change. One signal.
func remove_from_slots(amounts: Array[int]) -> ActionResult
## Moves the stacks in source's slot_indices into this inventory, in that order, as
## much as fits; source loses exactly what entered (R-005-15). Source == self, or an
## index out of range or repeated → ERR_INVALID_REQUEST and no change. Nothing fits →
## MSG_INVENTORY_FULL, no change, overflowed on this inventory.
func take_from(source: InventoryComponent, slot_indices: Array[int]) -> InventoryAddResult

## First direct child of node that is an InventoryComponent; null when none.
static func find_in(node: Node) -> InventoryComponent
```

```gdscript
class_name LootBox               # cambia
signal loot_generated(stacks: Array[ItemStack], opener: Node3D)   # once, on the roll (R-004-23)
## Every interaction while the box still holds items, after the roll on the first one.
signal opened(opener: Node3D)

@onready var _contents: InventoryComponent = %Contents

func get_contents() -> InventoryComponent
func is_opened() -> bool                     # rolled at least once
# On %Contents.inventory_changed (connected after the roll fills it): empty →
# interactable disabled for the rest of the visit.
```

```gdscript
class_name FarmZone              # cambia
signal box_opened(box: LootBox, opener: Node3D)
```

```gdscript
class_name UIScreenCatalog
extends Resource
@export var screens: Dictionary[StringName, PackedScene] = {}   # (verificar) typed export

class_name UIScreen
extends Control
## The screen asks to be closed (for example, the loot screen when the box is empty).
signal close_requested
## Called by UIManager once, after the screen enters the tree.
func setup(context: Dictionary) -> void

class_name UIManager
extends Control                  # full rect, mouse_filter IGNORE; screens are its children

signal modal_state_changed(is_open: bool)   # only on none ↔ some

@export var catalog: UIScreenCatalog

## Unknown id or id already open → push_error, no change.
func open(screen_id: StringName, context: Dictionary = {}) -> void
func close_top() -> void                    # pops at once, then queue_free(); nothing open → no-op
func close_all() -> void
func is_modal_open() -> bool
# _unhandled_input: "pause" pressed with a screen open → close_top() + set_input_as_handled()
# _notification: NOTIFICATION_WM_GO_BACK_REQUEST with a screen open → close_top()
# close_requested of an open screen → that screen is closed
```

```gdscript
class_name InventorySlotView
extends Button                   # focus_mode NONE; disabled when not interactive
func show_stack(stack: ItemStack) -> void   # null → empty look

class_name InventoryGrid
extends GridContainer
signal slot_pressed(index: int)
@export var interactive: bool = false
func bind(inventory: InventoryComponent) -> void   # paints now and on every inventory_changed

class_name InventoryScreen
extends UIScreen
const SCREEN_ID := &"inventory"
const CONTEXT_INVENTORY := &"inventory"     # InventoryComponent of the player
func setup(context: Dictionary) -> void      # missing or wrong type → push_error

class_name LootScreen
extends UIScreen
# %TakeAllButton: focus_mode NONE, text LOOT_TAKE_ALL
const SCREEN_ID := &"loot"
const CONTEXT_SOURCE := &"source"           # InventoryComponent of the box
const CONTEXT_INVENTORY := &"inventory"     # InventoryComponent of the player
func setup(context: Dictionary) -> void      # missing or wrong type → push_error
```

```gdscript
# Hud (cambia)
signal storage_pressed
func set_modal_open(is_open: bool) -> void   # interact button visible = has target and no screen open
# bind(player) también conecta player.inventory.overflowed → %MessageLabel con MSG_INVENTORY_FULL
# durante %MessageTimer; _unhandled_input: "open_storage" → storage_pressed

# PlayerInput (cambia)
func set_input_blocked(blocked: bool) -> void   # get_direction() → ZERO; run and interact → false
func is_input_blocked() -> bool

# Robot (cambia)
@export var chassis_levels: ChassisLevelData
@onready var inventory: InventoryComponent = %InventoryComponent
# _ready(): inventory.set_slot_count(chassis_levels.get_inventory_slots(ChassisLevelData.FIRST_LEVEL))
# request_interact(): no-op while the battery is depleted or input is blocked
```

**Eventos**: ninguno nuevo en `EventBus` (architecture §7). `inventory_changed`, `overflowed`, `opened`,
`box_opened`, `storage_pressed`, `close_requested` y `modal_state_changed` son señales locales.

## 4. Datos

| Recurso / `.tres` | Campos | Valores desde |
|---|---|---|
| `resources/progression/chassis_levels.tres` | `xp_required = [0, 50, 150, 300, 500]`, `inventory_slots = [5, 7, 10, 15, 20]` | BALANCE §6.1 |
| `resources/items/scrap.tres`, `cables.tres`, `iron.tres` | `icon` = su SVG | R-005-32 (marcadores) |
| `resources/ui/screens.tres` | `inventory` → `inventory_screen.tscn`, `loot` → `loot_screen.tscn` | architecture §9.5; no es balance |
| `stack_max`, tabla de la caja básica | Sin cambios | BALANCE §2, §2.1 (ya en la 004) |
| Ranuras de `%Contents` de una caja | Una por pila tirada | Se deriva de la tirada, no es un número de balance. Un test comprueba que ninguna entrada de loot pasa del `stack_max` de su item, así que cada pila cabe en una ranura |
| `hud.tscn` `%MessageTimer.wait_time` | `3.0` | ACTION_PLAN 4.1 ("notificaciones temporales (3 segundos)"). Es tiempo de UI, no de juego; la 4.1 lo moverá a su sistema de notificaciones |

Tamaños de celda, márgenes y fuentes son maquetación en los `.tscn`, no balance.

## 5. Verificación

| Requisito | Test (`game/tests/…`) o paso manual |
|---|---|
| R-005-01 | `unit/test_inventory_rules.gd::test_r_005_01_rules_are_pure` (la clase hereda de `RefCounted`; su código no nombra autoloads, `get_node` ni `get_tree`); todo el archivo corre sin árbol de escena |
| R-005-02 | `unit/test_chassis_level_data.gd::test_r_005_02_levels_match_balance`, `::test_r_005_02_validate_rejects_bad_tables`, `::test_r_005_02_level_out_of_range_reports_error`; `integration/test_robot_inventory.gd::test_r_005_02_robot_starts_with_level_one_slots` |
| R-005-03 | `unit/test_inventory_rules.gd::test_r_005_03_never_above_stack_max`, `::test_r_005_03_one_item_kind_per_slot` |
| R-005-04 | `unit/test_inventory_rules.gd::test_r_005_04_fills_partial_stacks_first`, `::test_r_005_04_then_empty_slots_in_order`, `::test_r_005_04_several_stacks_of_one_item` |
| R-005-05 | `unit/test_inventory_rules.gd::test_r_005_05_add_returns_leftover`, `::test_r_005_05_space_for`; `unit/test_inventory_component.gd::test_r_005_05_partial_add_reports_leftovers` |
| R-005-06 | `unit/test_inventory_rules.gd::test_r_005_06_count_sums_all_slots`; `unit/test_inventory_component.gd::test_r_005_06_has` |
| R-005-07 | `unit/test_inventory_rules.gd::test_r_005_07_remove_from_last_slot`, `::test_r_005_07_emptied_slots_become_null` |
| R-005-08 | `unit/test_inventory_component.gd::test_r_005_08_remove_more_than_held_changes_nothing` |
| R-005-09 | `unit/test_inventory_component.gd::test_r_005_09_non_positive_quantity_rejected`, `::test_r_005_09_unknown_item_rejected` (`assert_push_error` con el id), `::test_r_005_09_one_bad_stack_rejects_all` |
| R-005-10 | `integration/test_robot_inventory.gd::test_r_005_10_robot_owns_one_inventory`; `unit/test_inventory_component.gd::test_r_005_10_no_autoload_holds_inventory` (ninguna propiedad de los autoloads de `project.godot` es `InventoryComponent`, `ItemStack` ni `Array[ItemStack]`) |
| R-005-11 | `unit/test_inventory_component.gd::test_r_005_11_get_slots_returns_copies`, `::test_r_005_11_add_stores_copies` (cambiar la pila pasada a `add_stacks` no cambia el inventario), `::test_r_005_11_results_are_action_results` |
| R-005-12 | `unit/test_inventory_component.gd::test_r_005_12_changed_once_per_operation` (`add_stacks` de tres pilas → 1), `::test_r_005_12_no_signal_without_change` (remove fallido, petición inválida, add sin sitio) |
| R-005-13 | `unit/test_inventory_component.gd::test_r_005_13_growing_keeps_contents`, `::test_r_005_13_shrinking_rejected` |
| R-005-14 | `unit/test_action_result.gd::test_r_005_14_success_and_failure`; `unit/test_inventory_component.gd::test_r_005_14_error_keys_translated_es_en` |
| R-005-15 | `unit/test_inventory_component.gd::test_r_005_15_take_moves_exactly_what_fits` (los totales de los dos lados no cambian), `::test_r_005_15_take_nothing_fits_changes_nothing`, `::test_r_005_15_take_one_signal_per_side`, `::test_r_005_15_take_invalid_request` (mismo inventario, índice fuera de rango o repetido), `::test_r_005_15_remove_from_slots` |
| R-005-16 | `unit/test_loot_box.gd::test_r_005_16_interaction_emits_opened_with_opener`; `integration/test_green_zone.gd::test_r_005_16_zone_relays_box_opened`; `integration/test_main_scene.gd::test_r_005_16_interacting_opens_loot_screen` |
| R-005-17 | `unit/test_loot_box.gd::test_r_005_17_rolls_once_into_contents` (contenido = tirada de su semilla; reinteractuar no vuelve a tirar); `unit/test_data_catalog.gd::test_r_005_17_loot_fits_one_slot_per_entry` |
| R-005-18 | `unit/test_loot_screen.gd::test_r_005_18_tap_box_cell_takes_stack` |
| R-005-19 | `unit/test_loot_screen.gd::test_r_005_19_take_all_in_slot_order`; `integration/test_main_scene.gd::test_r_005_19_open_box_take_all_fills_inventory` (la prueba de ACTION_PLAN 1.2) |
| R-005-20 | `unit/test_loot_box.gd::test_r_005_20_partly_taken_box_stays_enabled`; `unit/test_hud.gd::test_r_005_20_inventory_full_message` (sale con `overflowed`; se oculta cuando el test emite `timeout` del timer, sin esperar tiempo real); `integration/test_main_scene.gd::test_r_005_20_full_inventory_keeps_rest_in_box` |
| R-005-21 | `unit/test_loot_box.gd::test_r_005_21_emptied_box_disabled_forever`, `::test_r_005_21_empty_roll_disables`; `unit/test_loot_screen.gd::test_r_005_21_requests_close_when_box_empty`; `integration/test_robot_interaction.gd::test_r_005_21_emptied_box_is_no_longer_offered` |
| R-005-22 | `integration/test_main_scene.gd::test_r_005_22_opener_without_inventory_reports_error` (nombre de caja y de quien abre; ninguna pantalla; contenido intacto) |
| R-005-23 | `unit/test_hud.gd::test_r_005_23_storage_button_bottom_centre_without_focus`; manual (T-005-16): en Android, tocar el botón no crea el joystick |
| R-005-24 | `unit/test_hud.gd::test_r_005_24_open_storage_action_emits`, `::test_r_005_24_button_emits`; `integration/test_main_scene.gd::test_r_005_24_storage_toggles_inventory` (botón y Tab), `::test_r_005_24_storage_closes_loot_screen`; `unit/test_loot_screen.gd::test_r_005_24_controls_never_take_focus` |
| R-005-25 | `unit/test_inventory_screen.gd::test_r_005_25_one_cell_per_slot_with_icon_and_quantity`, `::test_r_005_25_empty_cells`, `::test_r_005_25_cells_follow_slot_count`; `unit/test_loot_screen.gd::test_r_005_25_both_grids` |
| R-005-26 | `unit/test_inventory_screen.gd::test_r_005_26_updates_on_inventory_changed`, `::test_r_005_26_does_not_poll`; `unit/test_loot_screen.gd::test_r_005_26_both_sides_update` |
| R-005-27 | `unit/test_player_input.gd::test_r_005_27_blocked_ignores_movement_and_interact`; `unit/test_ui_manager.gd::test_r_005_27_modal_state_changed_on_transitions`; `unit/test_hud.gd::test_r_005_27_interact_button_hidden_while_modal` (también si cambia el objetivo con la pantalla abierta); `integration/test_main_scene.gd::test_r_005_27_robot_still_battery_drains` (con una pantalla abierta: sin desplazamiento, el botón del HUD no interactúa, la batería baja y `get_tree().paused` es falso) |
| R-005-28 | `unit/test_ui_manager.gd::test_r_005_28_pause_closes_top`, `::test_r_005_28_back_request_closes_top`, `::test_r_005_28_nothing_open_does_not_consume_pause`; manual (T-005-16): atrás en Android |
| R-005-33 | `unit/test_project_settings.gd::test_r_005_33_back_does_not_quit` (`quit_on_go_back` en falso); manual (T-005-16): atrás sin pantalla no cierra el juego en Android |
| R-005-29 | `integration/test_main_scene.gd::test_r_005_29_game_over_closes_and_blocks_screens` |
| R-005-30 | `unit/test_hud.gd::test_r_005_30_storage_button_key_translated`; `unit/test_inventory_screen.gd::test_r_005_30_title_key_translated`; `unit/test_loot_screen.gd::test_r_005_30_keys_translated` (claves en ES y EN, `auto_translate_mode` activo; cantidades sin traducir); `i18n-auditor` en la definición de hecho |
| R-005-31 | `unit/test_data_catalog.gd::test_r_005_31_every_item_has_icon` |
| R-005-32 | Revisión (T-005-17): cada icono está en `assets/CREDITS.md` con origen y licencia |
| `UIScreen.close_requested` | `unit/test_ui_manager.gd::test_close_requested_closes_that_screen` (contrato del plan, sin requisito propio) |
| Criterio de hecho | T-005-16: PC y APK en Android real |

**APIs por comprobar (verificar)** en el binario 4.7.2 headless y la documentación oficial antes de usarlas
(T-005-01):

1. `application/config/quit_on_go_back` existe y, en `false`, atrás en Android no cierra la app y entrega
   `NOTIFICATION_WM_GO_BACK_REQUEST`.
2. `NOTIFICATION_WM_GO_BACK_REQUEST` llega a todos los nodos del árbol, no solo a la ventana raíz.
3. `@export var screens: Dictionary[StringName, PackedScene]` se guarda y carga en un `.tres`.
4. Un `Array[ItemStack]` admite `null` como elemento.
5. Tab (`open_storage`) llega a `_unhandled_input` cuando ningún `Control` tiene el foco: `ui_focus_next` no lo
   consume.
6. `Input.parse_input_event()` con un `InputEventAction` de `pause` llega a `_unhandled_input` en los tests de GUT
   headless.
7. Un `Control` a pantalla completa con `mouse_filter = STOP` impide que un toque llegue al `_unhandled_input` del
   joystick (que vive en otro `CanvasLayer`).

Si alguna falla, se para y se ajusta el plan antes de seguir.

## 6. Check de constitución

| Principio | Cumple | Nota |
|---|---|---|
| P1 Spec primero | ✅ | La spec volvió a Borrador al pasar a loot manual; el usuario la aprobó otra vez el 2026-11-15, junto con este plan |
| P2 Una fuente de verdad | ✅ | Ranuras del jugador solo en `chassis_levels.tres` (BALANCE §6.1). Las de una caja salen de su tirada. `stack_max` solo en `ItemData`. Las claves de error son constantes de `InventoryComponent`. El tiempo del mensaje (3 s) es de UI y cita ACTION_PLAN 4.1 |
| P3 Lógica separada | ✅ | El apilado está en `InventoryRules` (estático, sin `Node`). El componente valida y delega. `take_from` coordina dos dueños sin escribir en las ranuras del otro. Las escenas solo cablean: `FarmZone` reemite y `main.gd` abre pantallas |
| P4 Estado por jugador | ✅ | El inventario está en el robot y un test comprueba que ningún autoload lo guarda. `UIManager` es un nodo de `UI`, y las pantallas reciben los inventarios por contexto |
| P5 Datos como recursos | ✅ | `ChassisLevelData`, `UIScreenCatalog` e `ItemData.icon` |
| P6 Señales | ✅ | La caja no conoce el inventario del jugador ni la UI: emite `opened`. El HUD escucha `overflowed`. El robot no conoce `UIManager`: `main.gd` conecta `modal_state_changed`. Una pantalla pide cerrarse con `close_requested`. Referencias con `%` o `@export` |
| P7 Tipado | ✅ | Todo tipado. El `context` es un `Dictionary` sin tipar (firma de architecture §9.5): el valor se convierte con `as` y se comprueba que no sea `null` |
| P8 Plataforma | ✅ | Se entra por la acción `open_storage`, el botón o la interacción, y se cierra por la acción `pause` o la notificación de atrás, sin `OS.has_feature()`. Las celdas son `Button`, así que funcionan con toque y ratón. `quit_on_go_back=false` es un override de `project.godot` que exige R-005-33 (decidido en la spec, pregunta 8); qué hace atrás sin pantalla lo decidirá la pausa (ACTION_PLAN 4.x) |
| P11 i18n | ✅ | Siete claves nuevas en ES y EN. Las celdas solo muestran icono y número |
| P12 Presupuesto móvil | ✅ | Como mucho 20 + 3 celdas. Sin `_process` en la UI. Iconos SVG pequeños. Las pantallas se instancian al abrir y se liberan al cerrar |
| P13 Test primero | ✅ | Reglas, componente, datos, caja, `UIManager` y pantallas con su test rojo primero. El joystick bajo el botón y atrás en Android son pasos manuales |
| P14 Alcance | ✅ | Sin depositar, coger parte de una pila, arrastrar, ordenar, tirar, cofres, guardado ni subida de nivel (spec §4). Más allá de architecture §9.5 solo se añaden `close_all()` y la base `UIScreen` con `close_requested`, porque los usa esta spec. `take_from` es el mínimo que pide R-005-15 y la 2.6 lo reutilizará |
| architecture §9.2 (un tipo de resultado) | ✅ | `InventoryAddResult` hereda de `ActionResult`: quien solo mira `ok` y `error_key` no nota la diferencia. Con un `Dictionary` genérico se perdería el tipado |
| architecture §9.5 (HUD por señales, catálogo de UI) | ✅ | Las pantallas se registran en `UIScreenCatalog`. Rejillas y HUD pintan el estado inicial con el mismo manejador de la señal |
| architecture §4 y §6 (carpetas y árbol) | ⚠️ | Hay dos desviaciones menores, justificadas. `ui_screen.gd` es una clase base sin escena y va en `scenes/ui/`, junto a las pantallas que la heredan: es presentación, y `scripts/` es para lo que no lo es. `ActionResult` va en `scripts/data/` como `ItemStack`, aunque sea un `RefCounted`. En `UI`, `UIManager` va antes que `Hud` (§6 dibuja lo contrario) para que el HUD quede por encima de las pantallas |

## 7. Riesgos y alternativas descartadas

- **Lo que queda en las cajas se pierde al reiniciar la partida.** Lo acepta la spec (§4): guardarlo es de la 010.
- **Se reescriben tests de la 004.** "Desactivada al abrirse" (R-004-24) pasa a "desactivada al vaciarse"
  (R-005-21), por decisión del usuario (spec, pregunta 7). Se cambian solo esas aserciones, con el id nuevo. Los
  tests de la tirada (R-004-23) no se tocan.
- **Atrás en Android y Tab dependen del motor** (§5, puntos 1, 2 y 5). Se verifican en T-005-01 y en el móvil
  (T-005-16) antes de cerrar.
- **El botón de almacenamiento ocupa los dos lados del centro**, así que su mitad izquierda cae en la zona del
  joystick. R-002-10 solo crea el joystick fuera de los controles del HUD, y el botón consume el toque antes del
  `_unhandled_input` del joystick. Se comprueba a mano en el Android real. Si molesta, se mueve justo a la derecha
  del centro.
- **`InventoryAddResult` puede ser "fallo" con cambios** (añadido parcial). Se documenta en el contrato. La
  alternativa (`ok` verdadero con sobrante) escondería al jugador que algo no cupo.
- **Tirar en la primera interacción aunque luego falte el inventario.** R-005-22 ya lo recoge: solo exige que el
  contenido no cambie. La tirada es determinista y no se pierde nada.
- **Descartado: el loot pasa solo al inventario al abrir** (versión anterior de esta spec). El usuario prefiere
  elegir qué coger (spec, pregunta 7).
- **Descartado: un sistema estático que mueva items entre dos componentes.** Los sistemas no conocen nodos
  (architecture §3). `take_from` en el componente que recibe mantiene un escritor por inventario.
- **Descartado: la caja guarda su contenido en un `Array[ItemStack]` propio.** Habría que repetir las reglas para
  quitar y mostrar. Con un `InventoryComponent`, la pantalla de caja usa la misma rejilla y los cofres heredan el
  patrón.
- **Descartado: `main.gd` conecta cada caja.** Con el `ZoneLoader` (spec 009) tendría que reconectarlas en cada
  viaje. `FarmZone` crea sus cajas y reemite una sola señal.
- **Descartado: pantallas instanciadas de antemano y enlazadas una vez.** Es más simple de enlazar, pero se aparta de
  `open(screen_id, context)` de architecture §9.5 y mantiene vivas pantallas que no se ven.
- **Descartado: pausar el árbol** con una pantalla abierta: lo descartó la pregunta 4 del spec (la batería sigue).
- **Descartado: que `InventoryComponent` lea `ChassisLevelData`.** Lo ataría al chasis e impediría usarlo en cajas y
  cofres.
- **Descartado: mostrar "inventario lleno" por `EventBus`.** El bus aún no existe, y el hecho es de un jugador: una
  señal local del componente basta.
