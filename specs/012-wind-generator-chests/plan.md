# Plan 012 — Generador eólico y cofres

| Campo | Valor |
|---|---|
| **Spec** | [spec.md](spec.md) (debe estar *Aprobado*) |
| **Estado** | Planificado (2026-11-19) |

## 1. Enfoque

Cinco piezas, cada una en su capa (architecture §3):

1. **Datos.** `StructureData` gana `max_count` (0 = sin límite). Dos subclases: `WindGeneratorData` (bonificación,
   periodo, máximo almacenado y el item que fabrica: todos los números del generador en un recurso, R-012-04) y
   `StorageChestData` (apunta a un `ContainerConfigData` con la capacidad, que también lee la caja de loot,
   R-012-06). La batería portátil es un `ConsumableData extends ItemData` con sus puntos. Dos recetas nuevas.
2. **Reglas puras.** `InventoryRules` aprende a mover una cantidad a una ranura concreta (colocar, sumar o
   intercambiar) y a transferirla al otro lado, sobre la regla de dividir de la spec 008. `WindGeneratorRules`
   calcula las baterías a partir de `(guardadas, referencia, ahora)`. `ConsumableRules` decide si se puede usar un
   consumible.
3. **Dueños del estado.** Cada cofre tiene su `InventoryComponent` y cada generador su `WindGeneratorComponent`.
   No viven en la instancia de la estructura (se libera al descargar la base) sino en `StructureStates`, hijo de
   `BaseStructures` bajo `World`, con un nodo por `uid`. `BaseStructures` guarda su parte del Mundo con dos claves
   nuevas (`chests`, `generators`), aplica el límite de cada estructura y publica la bonificación de batería
   máxima como señal de estado. `BatteryComponent` suma la bonificación a su máxima. `Robot` usa consumibles.
4. **Escenas.** `StorageChest` y `WindGenerator` (modelo, aspas, rótulo) solo avisan de que se han usado;
   `BaseStructures` reemite `structure_used(uid, user)` y un flujo nuevo, `StructureUseFlow`, abre la pantalla del
   cofre o pide recoger las baterías, como `BuildFlow` hace con el banco.
5. **UI.** `ContainerScreen` sustituye a `LootScreen` para cofres y cajas. `UIScreen` puede cerrarse tocando fuera
   de su panel (opción por pantalla), y `UIManager` lo trata como "atrás".

**Alternativa principal descartada**: guardar el contenido del cofre y el reloj del generador en la instancia de su
escena. La instancia se libera al salir de la base (spec 009, `BaseStructures.unbind_base`), así que el estado se
perdería o habría que reconstruirlo desde el guardado en cada viaje, lo que architecture §6 descarta para el robot.

### 1.1 Decisiones del plan

| # | Decisión | Por qué |
|---|---|---|
| D1 | `StructureData.max_count: int` (0 = sin límite). Cofre 5, generador 1, estación 0. `BaseStructures.is_at_limit(structure)` cuenta las colocadas por id. | R-012-03 sin literales. 0 como "sin límite" evita un segundo campo booleano. |
| D2 | `WindGeneratorData extends StructureData` con `max_battery_bonus`, `seconds_per_battery`, `max_stored` y `battery_item`. `StorageChestData extends StructureData` con `container: ContainerConfigData`. Los dos van en `DataCatalog.structures` como `PieceData` va en `items`. | R-012-04 pide los números del generador en un recurso; el tipo de la estructura dice qué estado tiene sin comparar ids en el código. |
| D3 | `ContainerConfigData` (`slot_count`) en `resources/config/container.tres`. Lo referencian `storage_chest.tres` y `loot_box.tscn`. | R-012-06: la caja lee el mismo valor que el cofre. |
| D4 | La batería portátil es `ConsumableData extends ItemData` con `battery_points`. El uso va por ranura: `Q` usa la primera ranura con un consumible en orden de ranuras; el botón "Usar" pasa el índice de la ranura elegida. Se quita una unidad de esa ranura (`remove_from_slots`). | Sin el id `portable_battery` escrito en un script. El botón de consumibles del HUD (ACTION_PLAN 4.1) reutiliza lo mismo. Por ranura y no por id: `InventoryRules.remove` quita de la última ranura, no de la elegida (revisión). |
| D5 | El estado de cofres y generadores vive en `StructureStates` (hijo de `BaseStructures`, bajo `World`): un `InventoryComponent` por cofre y un `WindGeneratorComponent` por generador. `StructureStates` los guarda en un `Dictionary[String, Node]` por `uid` (nunca los busca por nombre) y, al soltarlos, hace `remove_child` antes de `queue_free`. Se crean al colocar (con la hora de ese momento, R-012-18) y al cargar. Ninguno está en el grupo `persistent`: `BaseStructures` los guarda dentro de su parte. **Orden**: el estado existe antes que su instancia. `place()`: celdas → cobro → estado → instancia → bonificación → `structure_built`. `from_save_data()`: cuadrícula (sin rehacer instancias) → estados → instancias (si la base está cargada) → bonificación. | Sobrevive a viajes y muertes como el resto de `World` (R-012-36). Un solo `from_save_data` carga lo colocado y después su estado, así que una entrada de un `uid` no colocado se detecta sin depender del orden (R-012-42). El orden evita que un `WindGenerator` quede enlazado a un estado ya liberado al recargar con la base cargada, como hacen los tests de `test_save_load.gd` (revisión). |
| D6 | La parte `structures` del Mundo gana `chests: {uid: contenido}` y `generators: {uid: {stored, since_unix}}`, opcionales. Sin ellas, cada cofre colocado empieza vacío y cada generador empieza a contar al cargar. No sube `schema_version` (architecture §10.2, campo opcional). | R-012-39, R-012-43. Un Mundo de la spec 010/011 no puede tener cofres ni generadores. |
| D7 | Reloj del generador: el estado es `(stored, since_unix)`, donde `since_unix` es el inicio del periodo en curso. Asentar a una hora `now`: lleno → sin cambio; si no, `gained = elapsed / period`, `stored = min(stored + gained, max)` y `since += gained × period`. `elapsed = max(now − since, 0)`. Al coger de un generador que estaba lleno, `since = now`; si no estaba lleno, el periodo en curso sigue. Leer no cambia el estado; solo `collect` lo asienta. `seconds_per_battery < 1` o `max_stored < 1` → `push_error` y sin baterías (un test de datos lo vigila). | R-012-16, R-012-17, R-012-19. Guardar `(stored, since)` sin asentar es exacto: asentar es determinista. Sin división por cero con datos malos (revisión). |
| D8 | Recoger: `WindGeneratorComponent.collect(inventory, now)` asienta y llama a `inventory.add(battery_item.id, stored)`; lo que no cabe se queda. Nada cabe → `MSG_INVENTORY_FULL` sin cambios (el `overflowed` del inventario ya enseña el aviso del HUD, R-005-20). Cero baterías → `MSG_GENERATOR_EMPTY`. La petición del jugador entra por `BaseStructures.collect_batteries(player, uid)`, que emite `EventBus.batteries_collected` si algo se movió. | Mismo patrón que `place(player, …)`: el anfitrión decidirá ahí en cooperativo. Un solo camino para el aviso de inventario lleno. |
| D9 | Bonificación: `BaseStructures.get_max_battery_bonus()` es la mayor `max_battery_bonus` de los generadores colocados, y la señal de estado `max_battery_bonus_changed(bonus)` sale cuando cambia (colocar, cargar). `Main` la conecta a `robot.battery.set_maximum_bonus` y aplica el valor actual antes de cargar. | R-012-11. "La mayor" y no "la suma": con el límite de 1 es igual, y no da por decidido que varios generadores se acumulen (PMV §10, v1.1). En cooperativo, cada robot se conecta al unirse (v2.0). |
| D10 | `BatteryComponent.set_maximum_bonus(bonus)`: máxima = `config.maximum + bonus`; la carga se queda (o baja a la máxima si quedara por encima); una sola `battery_changed` si algo cambió; nunca `battery_low` ni `battery_depleted` (es un cambio de estado, no un consumo): el aviso se rearma como al cargar. | R-012-12, R-012-13, D15 de la spec 010. |
| D11 | Carga guardada por encima de la máxima actual (R-012-14): `from_save_data` pone la carga en la máxima y recuerda la guardada como **pendiente**, sin error todavía. `set_maximum_bonus` la aplica si la nueva máxima la admite y la borra; si aun así queda por encima, la borra con `push_error`. Cualquier otro cambio de carga (`_set_current`, que usan `tick`, `consume`, `add` y `recharge_full`) o un nuevo `from_save_data` también la borra, con `push_error` si no se aplicó. Así un valor absurdo (1e9) se sigue informando, solo más tarde. El test `test_r_010_11_load_above_maximum_is_rejected` (protege la regla de errores de la constitución §2; R-010-11 trata de ids) se sustituye por `test_r_012_14_*`: la carga final sin generador es la misma (la máxima) y el `push_error` llega al borrar la pendiente. | Independiente del orden de los dueños persistentes, sin cambiar `SaveManager`. No es debilitar un test: R-012-14 cambia ese caso, y el error se sigue comprobando (revisión). |
| D12 | Movimientos entre inventarios: `InventoryRules.move_to_slot(from, from_index, to, to_index, quantity)` y `transfer(from, from_index, to, quantity)` sobre arrays (el mismo array vale en `move_to_slot`). "Mismo item" (`can_merge`) es mismo id y ningún `uid`: dos piezas nunca se suman y se tratan como items distintos (se intercambian). Destino del mismo item sin sitio → `ERR_SLOT_FULL`. `InventoryComponent.move_to_slot(from_index, target, to_index, quantity)` y `transfer_to(target, from_index, quantity)` calculan con la regla sobre copias de sus ranuras y de las de `target`, escriben las dos (misma clase: escribe `target._slots`) y emiten una `inventory_changed` por inventario cambiado, primero el de origen. Es una desviación de architecture §3 regla 3, declarada en §6 (P3). | R-012-29 a R-012-34. Un intercambio entre dos inventarios es atómico: escribir las dos partes en un paso evita estados intermedios que una pantalla vería a medias. Los dos dueños son la misma clase y validan igual (catálogo, `is_valid_stack`). Descartado un método público para reemplazar ranuras enteras: abriría una puerta a cualquiera (revisión, opción b). |
| D13 | `ContainerScreen` (id `&"container"`) sustituye a `LootScreen` (id `&"loot"`): se borran `loot_screen.gd/.tscn` y `test_loot_screen.gd`. La clave `LOOT_TAKE_ALL` pasa a `CONTAINER_TAKE_ALL`; `LOOT_TITLE` sigue como título de la caja. Tests afectados, uno por uno (§5.4). | Lo pide R-012-37, que sustituye a R-005-16, R-005-18 y R-005-21. Borrar archivos y tests de la spec 005 se aprueba con este plan; ningún test se quita sin su sustituto. |
| D14 | Las celdas vacías de una rejilla se pueden tocar solo si la pantalla lo pide (`InventoryGrid.empty_cells_pressable`, falso por defecto): la pantalla de contenedor lo activa mientras hay selección. | R-012-29 necesita tocar una ranura vacía; la pantalla de inventario (Tab) no cambia (spec, fuera de alcance). |
| D15 | Guardar al cerrar un cofre (R-012-44): `UIScreen` gana la señal `closed`, que `UIManager` emite al sacarla de la pila por cualquier camino (tras `on_closed()`; también `close_all()` en un viaje o una muerte, y entonces el guardado espera a que `SaveManager` suelte la retención), y `UIManager.open()` devuelve la pantalla abierta o `null`. `StructureUseFlow` vigila `inventory_changed` del cofre mientras su pantalla está abierta y, al cerrarse con cambios, emite `EventBus.chest_closed(uid, player_uid)`; con `null` no conecta nada. Las llamadas actuales que ignoran el retorno no cambian (`return_value_discarded` se ignora por defecto, §5.1). | La pantalla no sabe de cofres ni del bus; el flujo que la abre sí. Las cajas no guardan al cerrar (spec, pregunta 9). Descartada `UIManager.screen_closed(screen_id)`: el flujo tendría que distinguir qué cofre se cerró sin tener la pantalla. |
| D16 | Cerrar tocando fuera: `UIScreen` exporta `closes_on_outside_tap` (falso por defecto; verdadero en banco, inventario y contenedor). Su `_gui_input` solo recibe lo que no para ningún hijo: el `Panel` (`PanelContainer`, `STOP` por defecto, §5.1) se fija `mouse_filter = 0` de forma explícita en las tres escenas, y el fondo y el centrado son `IGNORE`, así que una pulsación ahí es "fuera". Cada una de las tres pantallas tiene **un solo** panel (el contenedor pone las dos rejillas en el mismo), para que no haya huecos "fuera" entre paneles. Atiende solo `InputEventMouseButton` izquierdo pulsado (en Android llega por `emulate_mouse_from_touch`, por defecto activo: §5.1), llama a `accept_event()` y emite `back_requested`; `UIManager` lo atiende como "atrás" solo si esa pantalla es la de arriba. | R-012-46 a R-012-48. Una sola clase de evento: un toque no cierra dos veces (toque y ratón emulado). El evento aceptado no llega a `_unhandled_input`, donde escuchan el ataque y el joystick (R-012-47). |
| D17 | El generador no tiene pantalla: su rótulo `Label3D` muestra `GENERATOR_STORED` ("n/máximo") y `GENERATOR_NEXT` (tiempo hasta la siguiente) o `GENERATOR_FULL`. Se repinta con `generator_changed` y con un `Timer` de presentación de 1 s; sin `_process`. Las aspas giran con un `AnimationPlayer` en bucle (`autoplay`). Con 0 baterías, interactuar enseña `MSG_GENERATOR_EMPTY` con el tiempo que falta (pregunta 7). | R-012-21, R-012-22. Una cuenta atrás cambia sin que cambie el estado: refrescar cada segundo es presentación, no sondeo de estado. El segundo es una constante de presentación, no de juego. |
| D18 | `Hud.show_notice(message_key, args := [])`: con argumentos muestra `tr(key) % args`. | El aviso del generador lleva el tiempo; el resto de avisos no cambia. |
| D19 | El HUD muestra las negativas de usar un consumible por la señal `Robot.use_refused(error_key)`, para la tecla Q y para el botón "Usar" (el HUD se dibuja encima de las pantallas, spec 005). | R-012-24 con un solo camino. |
| D20 | Icono de la batería portátil: SVG propio de marcador, CC0, anotado en `assets/CREDITS.md`. Modelos del cofre y del generador: primitivas (cajas y cilindros), como el zombie y la estación. | Presupuesto 0 € (R-005-31). Modelos definitivos en ACTION_PLAN 4.4. |
| D21 | `BaseStructures.time_service` toma `GameManager.get_time_service()` en `_ready()` si nadie lo asignó (como `InventoryComponent.catalog`). Los tests asignan un `FakeTimeService` antes de colocar o enlazar la base; `WindGenerator.bind_state` guarda el servicio, así que un test que lo cambie vuelve a enlazar la base. | R-012-19 y tiempo determinista en los tests (constitución P13). Sin caso "sin servicio". |
| D22 | Las negativas de la pantalla de contenedor (`ERR_SLOT_FULL`, `ERR_PARTIAL_SWAP`, `ERR_NO_ROOM`) se ven en su propia etiqueta `%Notice`, dentro del panel; la selección se mantiene. El inventario lleno de "Coger todo" sigue en el HUD (R-005-20). | La negativa se ve donde se toca; el HUD queda para los avisos del juego. |

## 2. Archivos

| Archivo (`game/…`) | Nuevo / Cambia | Responsabilidad |
|---|---|---|
| `scripts/data/structure_data.gd` | Cambia | `max_count` (D1) |
| `scripts/data/wind_generator_data.gd` | Nuevo | Números del generador (D2) |
| `scripts/data/storage_chest_data.gd` | Nuevo | `container` (D2) |
| `scripts/data/container_config_data.gd` | Nuevo | `slot_count` (D3) |
| `scripts/data/consumable_data.gd` | Nuevo | `battery_points` (D4) |
| `scripts/systems/inventory_rules.gd` | Cambia | `can_merge`, `move_to_slot`, `transfer` y sus claves (D12) |
| `scripts/systems/wind_generator_rules.gd` | Nuevo | Reloj del generador, puro (D7) |
| `scripts/systems/consumable_rules.gd` | Nuevo | `check_use`, `first_consumable` (D4) |
| `scripts/components/inventory_component.gd` | Cambia | `move_to_slot`, `transfer_to` (D12) |
| `scripts/components/wind_generator_component.gd` | Nuevo | Estado de un generador, `collect`, guardado (D7, D8) |
| `scripts/components/battery_component.gd` | Cambia | `set_maximum_bonus`, carga guardada pendiente (D10, D11) |
| `scripts/components/player_input.gd` | Cambia | `is_use_consumable_just_pressed()` |
| `scenes/entities/robot.gd` | Cambia | `use_consumable`, `request_use_consumable`, `use_refused` (D4, D19) |
| `scenes/entities/loot_box.gd` / `.tscn` | Cambia | Capacidad de contenedor, nunca se desactiva, `opened` en cada interacción (R-012-37) |
| `scenes/base/structure_states.gd` | Nuevo | Estado por `uid` de cofres y generadores (D5, D6) |
| `scenes/base/base_structures.gd` | Cambia | Límite, `StructureStates`, bonificación, `collect_batteries`, `structure_used`, claves de guardado, `time_service` |
| `scenes/base/storage_chest.gd` / `.tscn` | Nuevo | Cofre colocado: modelo, interactuable, `used` |
| `scenes/base/wind_generator.gd` / `.tscn` | Nuevo | Generador colocado: modelo, aspas, rótulo, `used` (D17) |
| `scenes/base/structure_use_flow.gd` | Nuevo | Abre la pantalla del cofre, pide recoger baterías, avisos, `chest_closed` (D15) |
| `scenes/main.gd` / `main.tscn` | Cambia | `StructureStates` bajo `BaseStructures`, `StructureUseFlow`, bonificación y `time_service`; la caja abre `ContainerScreen` |
| `scenes/ui/ui_screen.gd` | Cambia | `closed`, `back_requested`, `closes_on_outside_tap` (D15, D16) |
| `scenes/ui/ui_manager.gd` | Cambia | `open()` devuelve la pantalla; atiende `back_requested`; emite `closed` |
| `scenes/ui/container_screen.gd` / `.tscn` | Nuevo | Pantalla de contenedor (R-012-27 a R-012-35) |
| `scenes/ui/loot_screen.gd` / `.tscn` | Se borra | Sustituida (D13) |
| `scenes/ui/inventory_grid.gd`, `inventory_slot.gd` | Cambia | Celdas vacías pulsables a petición (D14) |
| `scenes/ui/inventory_screen.gd` / `.tscn` | Cambia | Botón "Usar"; `closes_on_outside_tap` |
| `scenes/ui/bench_screen.tscn` | Cambia | `closes_on_outside_tap` |
| `scenes/ui/bench_build_section.gd` | Cambia | Motivo `MSG_STRUCTURE_LIMIT` (R-012-08) |
| `scenes/ui/hud.gd` | Cambia | `show_notice` con argumentos; `use_refused` (D18, D19) |
| `scripts/autoload/event_bus.gd` | Cambia | `batteries_collected`, `chest_closed` |
| `scripts/autoload/save_manager.gd` | Cambia | Dos razones nuevas y sus conexiones |
| `resources/structures/wind_generator.tres`, `storage_chest.tres` | Nuevo | Estructuras (R-012-01, R-012-03, R-012-04) |
| `resources/structures/charging_station.tres` | Cambia | `max_count = 0` explícito |
| `resources/recipes/wind_generator.tres`, `storage_chest.tres` | Nuevo | Recetas (R-012-02) |
| `resources/items/portable_battery.tres` | Nuevo | `ConsumableData` (R-012-05) |
| `resources/config/container.tres` | Nuevo | Capacidad (R-012-06) |
| `resources/data_catalog.tres` | Cambia | Estructuras, recetas e item nuevos |
| `resources/ui/screens.tres` | Cambia | `&"loot"` → `&"container"` |
| `assets/textures/icons/items/portable_battery.svg`, `assets/CREDITS.md` | Nuevo / Cambia | Icono (D20) |
| `i18n/strings.csv` | Cambia | Claves de §4.1 |
| `tests/…` | Nuevos y cambian | §5 |
| `specs/architecture.md` | Cambia | §7: filas `batteries_collected`, `chest_closed`; §8: subclases en `structures`; §9.5: `open()` devuelve la pantalla, `closed`, regla de tocar fuera (D16); §9.1: los usos de cofre y generador llegan como `structure_used` |

## 3. Contratos

```gdscript
# StructureData (added)
## How many can stand in the base at once (BALANCE §5.2, §5.4); 0 = no limit (R-012-03).
@export var max_count: int = 0

class_name WindGeneratorData
extends StructureData
## The wind generator (spec 012, BALANCE §5.2): every number of it (R-012-04).
## Points added to the maximum battery of every player robot while one is placed.
@export var max_battery_bonus: float = 0.0
## Seconds to make one portable battery.
@export var seconds_per_battery: int = 0
## Batteries it holds at most.
@export var max_stored: int = 0
## What it makes (the portable battery).
@export var battery_item: ItemData

class_name StorageChestData
extends StructureData
## Its slots (R-012-06); the loot box reads the same resource.
@export var container: ContainerConfigData

class_name ContainerConfigData
extends Resource
## Slots of a chest and of an opened loot box (BALANCE §1.3, §5.4).
@export var slot_count: int = 0

class_name ConsumableData
extends ItemData
## Battery points it gives when used, capped at the maximum (BALANCE §1.1).
@export var battery_points: float = 0.0
```

```gdscript
# InventoryRules (added)
const ERR_PARTIAL_SWAP := &"ERR_PARTIAL_SWAP"
const ERR_SLOT_FULL := &"ERR_SLOT_FULL"
const ERR_NO_ROOM := &"ERR_NO_ROOM"

## Same id and neither has a uid: two pieces never merge (R-012-34). null on either side → false.
static func can_merge(a: ItemStack, b: ItemStack) -> bool
## quantity of from[from_index] to to[to_index] (from and to may be the same array) (R-012-29):
## empty target → placed; can_merge → added up to stack_max, the rest stays in the origin (no room →
## ERR_SLOT_FULL); otherwise the whole stack swaps, a part → ERR_PARTIAL_SWAP (R-012-33). Keeps
## durability and uid (R-012-34). Index out of range, empty origin, quantity outside 1..its stack
## (can_split) or the same slot → push_error, ERR_INVALID_REQUEST. Any refusal changes nothing.
static func move_to_slot(from: Array[ItemStack], from_index: int, to: Array[ItemStack], to_index: int, quantity: int) -> ActionResult
## quantity of from[from_index] into to, as add_stack does (same item first, then empty slots), as
## much as fits; the rest stays in the origin (R-012-30). Nothing fits → ERR_NO_ROOM. Same invalid
## requests as move_to_slot, plus from and to being the same array.
static func transfer(from: Array[ItemStack], from_index: int, to: Array[ItemStack], quantity: int) -> ActionResult
```

```gdscript
# InventoryComponent (added)
## InventoryRules.move_to_slot between these slots and target's (target == self allowed). One
## inventory_changed per inventory that changed, this one first. No target, or an item target's catalog
## does not know → push_error, ERR_INVALID_REQUEST, no change.
func move_to_slot(from_index: int, target: InventoryComponent, to_index: int, quantity: int) -> ActionResult
## InventoryRules.transfer into target (never self). Same signals and invalid requests.
func transfer_to(target: InventoryComponent, from_index: int, quantity: int) -> ActionResult
```

```gdscript
class_name WindGeneratorRules
extends RefCounted
## The generator's clock (spec 012, plan D7). Pure: the time comes by parameter.

class Settled:
	var stored: int
	var since_unix: int

## max(now - since, 0) (R-012-19).
static func elapsed_s(since_unix: int, now_unix: int) -> int
## One battery per full period while below max_stored, never above it; full → unchanged (R-012-16, R-012-17).
static func settle(stored: int, since_unix: int, now_unix: int, config: WindGeneratorData) -> Settled
## Seconds until the next battery; -1 when full.
static func seconds_to_next(stored: int, since_unix: int, now_unix: int, config: WindGeneratorData) -> int
## After taking taken from settled: a generator that was full starts its next period at now (R-012-17).
static func after_taking(settled: Settled, taken: int, now_unix: int, config: WindGeneratorData) -> Settled
```

```gdscript
class_name WindGeneratorComponent
extends Node
## State of one placed generator (spec 012): batteries held and the start of the period in
## progress. Owned by StructureStates under World, so it outlives the base scene.

## State signal: what it holds or its reference time changed.
signal generator_changed

const MSG_GENERATOR_EMPTY := &"MSG_GENERATOR_EMPTY"

var config: WindGeneratorData

## Built at now_unix: 0 stored, its first period starts now (R-012-18).
func start(p_config: WindGeneratorData, now_unix: int) -> void
func get_stored(now_unix: int) -> int
## -1 when full.
func get_seconds_to_next(now_unix: int) -> int
## Settles and moves what fits into inventory as config.battery_item (D8). ok when any moved;
## MSG_GENERATOR_EMPTY or MSG_INVENTORY_FULL with no change; generator_changed once on a change.
func collect(inventory: InventoryComponent, now_unix: int) -> ActionResult
## {stored, since_unix}, JSON types only.
func to_save_data() -> Dictionary
## false (no change) for a bad entry: stored outside 0..max_stored or since_unix not a whole number.
## Emits generator_changed, never a fact.
func load_save_data(data: Dictionary) -> bool
```

`WindGeneratorComponent` no está en el grupo `persistent` (D5): por eso su carga se llama `load_save_data` y
devuelve si la entrada era válida, para que `StructureStates` la descarte con `push_error` (R-012-42).

```gdscript
class_name ConsumableRules
extends RefCounted
const ERR_BATTERY_FULL := &"ERR_BATTERY_FULL"
const ERR_NO_PORTABLE_BATTERY := &"ERR_NO_PORTABLE_BATTERY"
const NO_SLOT := -1
## ERR_NO_PORTABLE_BATTERY when slot_index holds no ConsumableData (NO_SLOT included), else
## ERR_BATTERY_FULL when current >= maximum, else success (R-012-24). Index out of range → push_error,
## ERR_INVALID_REQUEST.
static func check_use(slots: Array[ItemStack], slot_index: int, current: float, maximum: float) -> ActionResult
## The first slot holding a ConsumableData, in slot order; NO_SLOT when none (D4).
static func first_consumable_slot(slots: Array[ItemStack]) -> int
```

```gdscript
# BatteryComponent (added / changed)
## Maximum = config.maximum + bonus (D10). The charge stays (lowered only if it would be above the new
## maximum); one battery_changed when anything changed; never battery_low nor battery_depleted. A charge
## loaded above the old maximum is applied now if nothing changed the charge since (D11).
## bonus < 0 → push_error, no change.
func set_maximum_bonus(bonus: float) -> void
# from_save_data: a charge above the maximum is no longer rejected (D11); <= 0 still is.
```

```gdscript
# PlayerInput (added)
## True only on the physics frame use_consumable goes down; false while blocked.
func is_use_consumable_just_pressed() -> bool

# Robot (added)
## A request to use a consumable was refused; the HUD shows tr(error_key) (D19).
signal use_refused(error_key: StringName)
## One unit of the consumable in slot_index leaves that slot (InventoryComponent.remove_from_slots) and
## its battery_points go to the battery through BatteryComponent.add, in one call (R-012-23). A
## ConsumableRules.check_use refusal → its key, use_refused, no change (R-012-24). A depleted robot →
## ERR_INVALID_REQUEST, nothing else.
func use_consumable(slot_index: int) -> ActionResult
## The use_consumable action and the "Use" button (R-012-25): slot_index, or the first consumable slot
## when NO_SLOT (D4); ERR_NO_PORTABLE_BATTERY through use_refused when there is none.
func request_use_consumable(slot_index: int = ConsumableRules.NO_SLOT) -> void
```

```gdscript
class_name StructureStates
extends Node
## The state of the placed structures that have one (spec 012, plan D5): one InventoryComponent per
## chest and one WindGeneratorComponent per generator, named by uid. Child of BaseStructures, which
## saves it in its own part.

const CHESTS_KEY := "chests"
const GENERATORS_KEY := "generators"

## Nothing for a structure with no state (the charging station).
func create_for(uid: String, structure: StructureData, now_unix: int) -> void
## null when uid is not a chest.
func get_chest_contents(uid: String) -> InventoryComponent
## null when uid is not a generator.
func get_generator(uid: String) -> WindGeneratorComponent
## {chests: {uid: InventoryComponent.to_save_data()}, generators: {uid: {...}}} (R-012-39).
func to_data() -> Dictionary
## Drops every state (remove_child, then queue_free; D5) and makes one per placed uid that needs it, filled from data. An entry that is
## not valid, whose uid is not placed or is placed as another kind → push_error and skipped; its
## structure starts new (R-012-42). Missing keys → every state new (R-012-43). No fact signals (R-012-41).
func load_data(data: Dictionary, placed: Dictionary[String, StructureData], now_unix: int) -> void
```

```gdscript
# BaseStructures (added / changed)
## A player interacted with a placed chest or generator (relayed from its instance).
signal structure_used(structure_uid: String, user: Node3D)
## State signal: the maximum battery bonus of the placed generators changed (D9).
signal max_battery_bonus_changed(bonus: float)

const MSG_STRUCTURE_LIMIT := &"MSG_STRUCTURE_LIMIT"

## GameManager.get_time_service() at _ready() unless assigned before (R-012-19, D21).
var time_service: ITimeService

func count_of(structure_id: StringName) -> int
## max_count > 0 and count_of(id) >= max_count (R-012-08).
func is_at_limit(structure: StructureData) -> bool
## The largest max_battery_bonus among placed generators; 0.0 when none (D9).
func get_max_battery_bonus() -> float
func get_chest_contents(structure_uid: String) -> InventoryComponent
## -1 when full; the generator's state read with time_service.
func seconds_to_next_battery(structure_uid: String) -> int
## The player's request (D8, R-012-20): EventBus.batteries_collected when any battery moved.
## No player, unknown uid or not a generator → push_error, ERR_INVALID_REQUEST.
func collect_batteries(player: Robot, structure_uid: String) -> ActionResult
# place(): at the limit → MSG_STRUCTURE_LIMIT before anything else, no charge, no change (R-012-09);
#   on success: cells → payment → state (now) → instance → bonus → structure_built (D5).
# to_save_data(): {placed, chests, generators};
# from_save_data(): grid (no instances yet) → states → instances if the base is loaded → bonus (D5).
```

```gdscript
class_name StorageChest
extends StaticBody3D
signal used(user: Node3D)

class_name WindGenerator
extends StaticBody3D
signal used(user: Node3D)
## Shows state (D17); without a state (the placement preview) the label stays empty and nothing fails.
func bind_state(state: WindGeneratorComponent, time_service: ITimeService) -> void
## "h:mm:ss", digits only (no text to translate).
static func format_time_left(seconds: int) -> String
```

```gdscript
class_name StructureUseFlow
extends Node
## Chests and generators in the base (spec 012): a chest opens the container screen for the local
## player; a generator asks BaseStructures to collect. It only opens screens and shows notices.
@export var ui_manager: UIManager
@export var base_structures: BaseStructures
func bind(player: Robot, hud: Hud) -> void
```

```gdscript
# EventBus (added)
## A player took batteries from a generator. Emitted by BaseStructures, once per collection that moved any (spec 012).
signal batteries_collected(structure_uid: String, player_uid: String)
## A player closed a chest's screen after its contents changed. Emitted by StructureUseFlow (spec 012).
signal chest_closed(structure_uid: String, player_uid: String)

# SaveManager (added)
const REASON_BATTERIES_COLLECTED := &"batteries_collected"
const REASON_CHEST_CLOSED := &"chest_closed"
```

```gdscript
# UIScreen (added)
## Emitted by UIManager when the screen leaves the stack, after on_closed().
signal closed
## A tap or click outside the panel of a screen with closes_on_outside_tap (D16).
signal back_requested
## Bench, inventory and container: true in their scenes. Placement and notice: false (R-012-48).
@export var closes_on_outside_tap: bool = false

# UIManager (changed)
## Now returns the screen it opened; null when it could not (unknown id, already open).
func open(screen_id: StringName, context: Dictionary = {}) -> UIScreen
# back_requested of the top screen → the same path as Escape: handle_back() or close (R-012-46).
```

```gdscript
class_name ContainerScreen
extends UIScreen
## A chest or an opened loot box next to the player's inventory (spec 012).
const SCREEN_ID := &"container"
const CONTEXT_CONTAINER := &"container"   # InventoryComponent of the chest or the box
const CONTEXT_INVENTORY := &"inventory"   # InventoryComponent of the player
const CONTEXT_TITLE := &"title"           # StringName: CHEST_TITLE or LOOT_TITLE
const NO_SELECTION := -1
enum Side { CONTAINER, PLAYER }
## Missing or wrong context → push_error.
func setup(context: Dictionary) -> void
func get_selected_side() -> Side
func get_selected_index() -> int
func on_closed() -> void

# InventoryGrid (added)
## Empty cells can be pressed too (D14). False by default.
func set_empty_cells_pressable(pressable: bool) -> void

# ContainerScreen: refusals of a move or a transfer show tr(key) in its own %Notice label (D22).

# InventoryScreen (changed): %UseButton next to the throw button, enabled for a selected
# ConsumableData stack; it calls the robot's request_use_consumable(selected slot) (R-012-25).

# Hud (changed)
func show_notice(message_key: StringName, args: Array = []) -> void
```

`BenchBuildSection.blocking_reason`: `MSG_STRUCTURE_LIMIT` (si `is_at_limit`) antes que materiales y sitio.

## 4. Datos

| Recurso / `.tres` | Campos | Valores desde |
|---|---|---|
| `resources/structures/wind_generator.tres` (`WindGeneratorData`) | `id = wind_generator`, `name_key = STRUCTURE_WIND_GENERATOR`, `scene`, `footprint = (2, 2)`, `max_count = 1`, `max_battery_bonus = 20.0`, `seconds_per_battery = 14400`, `max_stored = 3`, `battery_item` = batería portátil | BALANCE §5.2 (efecto, 1 cada 4 h, máximo 3, máximo en base 1), §5.6 (huella) |
| `resources/structures/storage_chest.tres` (`StorageChestData`) | `id = storage_chest`, `name_key = STRUCTURE_STORAGE_CHEST`, `scene`, `footprint = (1, 1)`, `max_count = 5`, `container` = `container.tres` | BALANCE §5.4 (máximo 5), §5.6 (huella) |
| `resources/structures/charging_station.tres` | `max_count = 0` | BALANCE §5.3 (sin límite) |
| `resources/config/container.tres` (`ContainerConfigData`) | `slot_count = 4` | BALANCE §1.3, §5.4 |
| `resources/items/portable_battery.tres` (`ConsumableData`) | `id = portable_battery`, `name_key = ITEM_PORTABLE_BATTERY`, `stack_max = 5`, `icon`, `battery_points = 20.0` | BALANCE §2 (pila 5), §1.1 (+20) |
| `resources/recipes/wind_generator.tres` | `WORKBENCH`, tier 1, sin `requires`, `result_structure` = generador; 5 chatarra + 3 cables + 2 hierro | BALANCE §5.2, §5.5 |
| `resources/recipes/storage_chest.tres` | Igual; 3 chatarra + 1 hierro | BALANCE §5.4, §5.5 |
| `resources/data_catalog.tres` | `structures` + 2, `recipes` + 2, `items` + batería portátil | architecture §8 |
| `scenes/entities/loot_box.tscn` | `container_config` = `container.tres` | R-012-06 |

### 4.1 Claves de traducción (ES + EN)

| Clave | EN | ES |
|---|---|---|
| `STRUCTURE_WIND_GENERATOR` | Wind generator | Generador eólico |
| `STRUCTURE_STORAGE_CHEST` | Storage chest | Cofre |
| `ITEM_PORTABLE_BATTERY` | Portable battery | Batería portátil |
| `PROMPT_COLLECT` | Collect | Recoger |
| `GENERATOR_STORED` | Batteries %d/%d | Baterías %d/%d |
| `GENERATOR_NEXT` | Next in %s | Siguiente en %s |
| `GENERATOR_FULL` | Full | Lleno |
| `MSG_GENERATOR_EMPTY` | No batteries yet, next in %s | Aún no hay baterías, siguiente en %s |
| `MSG_STRUCTURE_LIMIT` | Limit reached | Límite alcanzado |
| `CHEST_TITLE` | Chest | Cofre |
| `CONTAINER_TRANSFER` | Transfer | Transferir |
| `CONTAINER_TAKE_ALL` | Take all | Coger todo |
| `ERR_PARTIAL_SWAP` | Choose the whole stack to swap | Elige la pila entera para intercambiar |
| `ERR_SLOT_FULL` | That slot is full | Esa ranura está llena |
| `ERR_NO_ROOM` | No room on the other side | No hay sitio en el otro lado |
| `INVENTORY_USE` | Use | Usar |
| `ERR_BATTERY_FULL` | Battery already full | La batería ya está llena |
| `ERR_NO_PORTABLE_BATTERY` | No portable batteries | No tienes baterías portátiles |

Se quita `LOOT_TAKE_ALL` (D13). Se reutilizan `PROMPT_OPEN` (cofre), `LOOT_TITLE`, `MSG_INVENTORY_FULL`,
`BUILD_BUTTON`, `BUILD_COST_ENTRY` y `ERR_INVALID_REQUEST`.

## 5. Verificación

### 5.1 Puntos comprobados al planificar (2026-11-19)

Referencia de clases generada con `--doctool` de Godot 4.7.2:

| Punto | Resultado |
|---|---|
| `Control._gui_input(event)`, `Control.accept_event()`, `mouse_filter` (por defecto `MOUSE_FILTER_STOP`) | Existen |
| `ProjectSettings` `input_devices/pointing/emulate_mouse_from_touch` | Existe, por defecto `true`; `project.godot` no lo cambia |
| `Label3D.text`, `billboard`, `pixel_size` | Existen |
| `AnimationPlayer.autoplay` | Existe |
| `GridContainer.columns` | Existe |
| `Input.is_action_just_pressed` | Existe (ya usado por `interact`) |
| `PanelContainer.mouse_filter` | Sobrescribe el de `Control`: por defecto `0` (`STOP`). `Container` usa `1` (`PASS`); el `CenterContainer` de las pantallas ya es `IGNORE` en sus escenas |
| `Animation.loop_mode` | Existe (aspas en bucle) |
| `Viewport.push_input(event, in_local_coords)` | Existe (tests de R-012-47) |
| `debug/gdscript/warnings/return_value_discarded` | Por defecto `0` (ignorar) y `project.godot` no lo cambia: las llamadas que ignoran el retorno de `open()` no dan aviso (D15) |

Quedan dos puntos **(verificar)** que la referencia no contesta:

- Que un toque en Android llegue a `_gui_input` del fondo como `InputEventMouseButton` emulado **una sola vez**
  (D16). Lo cubre M3 (T-012-15).
- Que una `InputEventScreenTouch` que cae en un `Control` con `STOP` no llegue a
  `FloatingJoystick._unhandled_input`. Lo comprueba primero el test `test_r_012_47_outside_touch_does_not_reach_joystick`
  (T-012-12) y después M3. Si fallara, la pantalla también acepta esa `InputEventScreenTouch` (sin emitir
  `back_requested`, para no cerrar dos veces).

### 5.2 Requisitos

| Requisito | Test (`game/tests/…`) o paso manual |
|---|---|
| R-012-01 | `unit/test_structure_resources.gd::test_r_012_01_generator_and_chest_listed` (escena, huella de BALANCE §5.6), `::test_r_012_01_names_translated_es_en` |
| R-012-02 | `unit/test_recipe_resources.gd::test_r_012_02_structure_recipes_match_balance`; `unit/test_data_catalog.gd::test_r_011_05_*` (WORKBENCH, tier 1, sin `requires`) sigue cubriéndolas |
| R-012-03 | `unit/test_structure_resources.gd::test_r_012_03_limits_match_balance` (5, 1, 0); sin literales: `balance-auditor` en el cierre |
| R-012-04 | `unit/test_structure_resources.gd::test_r_012_04_generator_data_matches_balance` (también periodo y máximo ≥ 1, D7); `unit/test_wind_generator_rules.gd::test_r_012_04_bad_data_reports_error` |
| R-012-05 | `unit/test_consumable_resources.gd::test_r_012_05_portable_battery_listed` (pila 5, icono, 20 puntos), `::test_r_012_05_name_translated_es_en` |
| R-012-06 | `unit/test_structure_resources.gd::test_r_012_06_chest_capacity_matches_balance`; `unit/test_loot_box.gd::test_r_012_06_box_reads_the_chest_container` (mismo recurso) |
| R-012-07 | `unit/test_bench_screen.gd::test_r_012_07_build_lists_generator_and_chest`; `integration/test_build_flow.gd::test_r_012_07_build_generator_and_chest` (colocación, cobro, `structure_built`, guardado) |
| R-012-08 | `unit/test_bench_screen.gd::test_r_012_08_limit_disables_build_with_notice` (5 cofres; 1 generador) |
| R-012-09 | `integration/test_base_structures.gd::test_r_012_09_place_over_limit_refused` (sin cobro, sin celdas, sin evento) |
| R-012-10 | `integration/test_base_structures.gd::test_r_012_10_move_keeps_chest_and_generator_state`, `::test_r_012_10_reload_with_base_loaded_rebinds_state` (D5: el rótulo muestra el estado cargado, no uno liberado) |
| R-012-11 | `unit/test_battery_component.gd::test_r_012_11_maximum_with_bonus`; `integration/test_base_structures.gd::test_r_012_11_bonus_while_generator_placed` |
| R-012-12 | `unit/test_battery_component.gd::test_r_012_12_bonus_keeps_charge_emits_once`, `::test_r_012_12_bonus_emits_no_fact`; `integration/test_base_loop.gd::test_r_012_12_building_generator_raises_robot_maximum` |
| R-012-13 | `unit/test_battery_component.gd::test_r_012_13_low_threshold_uses_new_maximum`, `::test_r_012_13_recharge_full_to_new_maximum`; `integration/test_death_controller.gd::test_r_012_13_respawn_uses_new_maximum` |
| R-012-14 | `unit/test_battery_component.gd::test_r_012_14_charge_loaded_before_bonus`, `::test_r_012_14_bonus_before_charge`, `::test_r_012_14_above_without_bonus_reported_and_at_maximum` (sustituye a `test_r_010_11_load_above_maximum_is_rejected`, D11), `::test_r_012_14_pending_dropped_by_other_change`, `::test_r_012_14_bonus_too_small_reports`; `integration/test_save_load.gd::test_r_012_14_charge_above_base_maximum_survives_reload`. En `main.tscn`, `BaseStructures` carga antes que el robot: la integración prueba "base primero"; el orden contrario queda en los unitarios |
| R-012-15 | `unit/test_wind_generator_rules.gd` entero (sin escena ni nodos) |
| R-012-16 | `unit/test_wind_generator_rules.gd::test_r_012_16_one_battery_per_full_period`, `::test_r_012_16_partial_period_adds_nothing`, `::test_r_012_16_surplus_capped_at_max`; `integration/test_base_structures.gd::test_r_012_16_counts_while_base_unloaded`; `integration/test_save_load.gd::test_r_012_16_counts_while_app_closed` |
| R-012-17 | `unit/test_wind_generator_rules.gd::test_r_012_17_full_does_not_accumulate`, `::test_r_012_17_taking_from_full_restarts_period`, `::test_r_012_17_taking_below_full_keeps_period` |
| R-012-18 | `unit/test_wind_generator_component.gd::test_r_012_18_starts_empty_counting_now`; `integration/test_base_structures.gd::test_r_012_18_built_generator_starts_empty` |
| R-012-19 | `unit/test_wind_generator_rules.gd::test_r_012_19_negative_elapsed_counts_zero`; `unit/test_time_service.gd::test_r_012_19_only_local_time_service_reads_the_clock` (busca `Time.get_unix_time` fuera de `LocalTimeService`, como `test_no_global_rng.gd`) |
| R-012-20 | `unit/test_wind_generator_component.gd::test_r_012_20_collect_moves_what_fits`, `::test_r_012_20_nothing_fits_no_change`, `::test_r_012_20_empty_refused`; `integration/test_base_structures.gd::test_r_012_20_collect_request_emits_event`; `integration/test_structure_use_flow.gd::test_r_012_20_empty_generator_shows_time_left` |
| R-012-21 | `unit/test_wind_generator.gd::test_r_012_21_label_shows_stored_and_time_left`, `::test_r_012_21_full_shows_full`, `::test_r_012_21_refreshes_on_change`, `::test_r_012_21_does_not_process`, `::test_r_012_21_preview_without_state` |
| R-012-22 | `unit/test_wind_generator.gd::test_r_012_22_blades_animation_autoplays`; paso manual M1 (se ven girar) |
| R-012-23 | `unit/test_consumable_rules.gd`; `integration/test_robot_consumable.gd::test_r_012_23_use_removes_one_and_adds_points`, `::test_r_012_23_capped_at_maximum` |
| R-012-24 | `unit/test_consumable_rules.gd::test_r_012_24_*`; `integration/test_robot_consumable.gd::test_r_012_24_full_battery_refused`, `::test_r_012_24_no_battery_refused` (`use_refused`, nada cambia); `unit/test_hud.gd::test_r_012_24_shows_use_refused` |
| R-012-25 | `unit/test_inventory_screen.gd::test_r_012_25_use_button_for_consumable`, `::test_r_012_25_use_button_disabled_for_material`; `integration/test_robot_consumable.gd::test_r_012_25_use_consumable_action`; `unit/test_input_map.gd` (Q, ya existe) |
| R-012-26 | `unit/test_structure_states.gd::test_r_012_26_chest_has_own_inventory_with_capacity` |
| R-012-27 | `unit/test_container_screen.gd::test_r_012_27_grids_selector_and_buttons` (2 columnas); `integration/test_structure_use_flow.gd::test_r_012_27_chest_opens_container_screen` |
| R-012-28 | `unit/test_container_screen.gd::test_r_012_28_tap_selects_whole_stack`, `::test_r_012_28_tap_again_clears` |
| R-012-29 | `unit/test_inventory_rules.gd::test_r_012_29_to_empty_slot`, `::test_r_012_29_same_item_adds_up_to_max`, `::test_r_012_29_same_item_no_room_refused`, `::test_r_012_29_other_item_whole_stack_swaps`, `::test_r_012_29_within_the_same_slots`; `unit/test_container_screen.gd::test_r_012_29_tap_target_moves`, `::test_r_012_29_empty_cells_pressable_only_with_selection` |
| R-012-30 | `unit/test_inventory_rules.gd::test_r_012_30_transfer_same_item_then_empty`, `::test_r_012_30_rest_stays`, `::test_r_012_30_no_room_refused`; `unit/test_container_screen.gd::test_r_012_30_transfer_button` |
| R-012-31 | `unit/test_container_screen.gd::test_r_005_19_take_all_in_slot_order`, `::test_r_005_19_take_all_moves_everything_that_fits` (movidos, D13), `::test_r_012_31_rest_stays_and_full_notice` |
| R-012-32 | `unit/test_inventory_rules.gd::test_r_012_32_invalid_requests_report_error_no_change`; `unit/test_inventory_component.gd::test_r_012_32_move_between_two_one_signal_each`, `::test_r_012_32_refusal_changes_nothing` |
| R-012-33 | `unit/test_inventory_rules.gd::test_r_012_33_partial_swap_refused` |
| R-012-34 | `unit/test_inventory_rules.gd::test_r_012_34_pieces_keep_uid_and_never_merge`; `unit/test_inventory_component.gd::test_r_012_34_transfer_keeps_piece` |
| R-012-35 | `unit/test_container_screen.gd::test_r_005_26_both_sides_update` (movido), `::test_r_012_35_selection_cleared_when_gone`, `::test_r_012_35_stays_open_when_empty` |
| R-012-36 | `integration/test_base_loop.gd::test_r_012_36_chest_survives_travel_and_death`; `integration/test_save_load.gd::test_r_012_36_chest_survives_close_and_reopen` |
| R-012-37 | `unit/test_loot_box.gd::test_r_012_37_capacity_of_a_chest`, `::test_r_012_37_every_interaction_opens_also_empty`, `::test_r_012_37_never_disabled`, `::test_r_012_37_restored_box_has_capacity`, `::test_r_012_37_restored_empty_box_stays_enabled`; `integration/test_robot_interaction.gd::test_r_012_37_emptied_box_still_offered`; `integration/test_main_scene.gd::test_r_012_37_box_opens_container_screen`, `::test_r_005_24_storage_closes_container_screen`. Tests sustituidos: §5.4 |
| R-012-38 | `integration/test_zone_memory.gd::test_r_012_38_deposited_item_stays_after_reload`; `integration/test_green_zone.gd::test_r_012_38_deposited_item_lost_next_visit` |
| R-012-39 | `unit/test_structure_states.gd::test_r_012_39_round_trip`; `integration/test_save_load.gd::test_r_012_39_world_holds_chests_and_generators` |
| R-012-40 | `unit/test_structure_states.gd::test_r_012_40_no_capacity_saved`; `unit/test_battery_component.gd::test_r_010_24_save_data_is_only_the_current_charge` (existente) |
| R-012-41 | `integration/test_base_structures.gd::test_r_012_41_load_emits_no_facts` (sin `structure_built` ni `batteries_collected`; sí `max_battery_bonus_changed`) |
| R-012-42 | `unit/test_structure_states.gd::test_r_012_42_invalid_entry_skipped`, `::test_r_012_42_entry_for_unplaced_uid_skipped`, `::test_r_012_42_entry_of_other_kind_skipped` |
| R-012-43 | `integration/test_save_fixtures.gd::test_r_012_43_world_v1_loads_unchanged` (sin cofres ni generadores, máxima 100) |
| R-012-44 | `integration/test_save_triggers.gd::test_r_012_44_collect_saves`, `::test_r_012_44_chest_closed_after_change_saves`, `::test_r_012_44_chest_closed_unchanged_does_not_save`, `::test_r_012_44_loot_box_does_not_save_on_close`; `unit/test_event_bus.gd::test_r_012_44_event_signatures` |
| R-012-45 | Casos de claves en `test_structure_resources.gd`, `test_consumable_resources.gd`, `test_container_screen.gd`, `test_wind_generator.gd`, `test_inventory_screen.gd`, `test_bench_screen.gd`; `i18n-auditor` en el cierre |
| R-012-46 | `unit/test_ui_manager.gd::test_r_012_46_outside_tap_closes_top`, `::test_r_012_46_outside_tap_goes_through_handle_back`, `::test_r_012_46_only_the_top_screen`, `::test_r_012_46_off_by_default`; en `unit/test_bench_screen.gd`, `test_inventory_screen.gd` y `test_container_screen.gd`: `::test_r_012_46_closes_on_outside_tap`, `::test_r_012_46_tap_inside_panel_does_not_close`, `::test_r_012_46_panel_stops_the_mouse` (D16) |
| R-012-47 | `unit/test_ui_manager.gd::test_r_012_47_outside_tap_is_accepted`; `integration/test_main_scene.gd::test_r_012_47_outside_tap_does_not_attack` (pulsación empujada al viewport con el inventario abierto: se cierra y `poll_attack()` da falso), `::test_r_012_47_outside_touch_does_not_reach_joystick` (`InputEventScreenTouch` en la mitad izquierda: el joystick no coge el dedo); "pantalla de abajo": `test_r_012_46_only_the_top_screen`; M3 |
| R-012-48 | `unit/test_placement_screen.gd::test_r_012_48_not_closed_by_outside_tap`; `unit/test_notice_screen.gd::test_r_012_48_not_closed_by_outside_tap` |

Todos los tests del generador y de `BaseStructures` usan `FakeTimeService` (D21); ninguno espera tiempo real.

### 5.3 Pasos manuales

- **M1 (PC)**: partida nueva; reunir materiales y, en el banco, construir un generador y un cofre. Los dos se
  colocan con vista previa (el generador ocupa 2x2) y se mueven en "Editar base" sin perder estado. Al colocar el
  generador la barra de batería pasa de máxima 100 a 120 sin cambiar la carga; una estación recarga a 120. Las
  aspas giran y el rótulo dice "Baterías 0/3" y una cuenta atrás de unas 4 h. El botón de construir del generador
  queda desactivado con "Límite alcanzado". En el cofre: elegir una pila, bajar la cantidad, tocar una ranura vacía
  del cofre, "Transferir", "Coger todo"; cerrar con Escape, con clic fuera del panel y con Tab. Viajar, morir y
  reiniciar: lo del cofre sigue. Una caja de loot abre la misma pantalla, se deja algo dentro y no se desactiva al
  vaciarse; la visita siguiente ya no lo tiene.
- **M2 (PC, reloj)**: con el juego cerrado, adelantar el reloj del sistema 8 h y abrir: el generador tiene 2;
  interactuar las pasa al inventario. Usar una con el botón "Usar" y otra con Q: suma 20 sin pasar de la máxima;
  con la batería llena sale "La batería ya está llena". Devolver el reloj a su hora.
- **M3 (Android, APK debug)**: tocar fuera del panel del banco, del inventario y del cofre los cierra una sola vez
  y no ataca ni mueve al robot; en la colocación un toque fuera sigue eligiendo celda. La pantalla de contenedor se
  maneja con el dedo en horizontal 1920x1080 y los textos caben en ES y EN.

### 5.4 Tests existentes que cambian (D11, D13)

Ninguno se quita sin sustituto. Los que se mueven conservan sus asserts.

| Test actual | Qué pasa | Por qué |
|---|---|---|
| `unit/test_battery_component.gd::test_r_010_11_load_above_maximum_is_rejected` | Sustituido por `test_r_012_14_above_without_bonus_reported_and_at_maximum` (misma carga final y `push_error`, ahora al borrar la pendiente) | R-012-14, D11 |
| `unit/test_loot_screen.gd::test_r_005_25_both_grids`, `test_r_005_19_take_all_in_slot_order`, `test_r_005_19_take_all_moves_everything_that_fits`, `test_r_005_26_both_sides_update`, `test_r_005_26_does_not_poll`, `test_r_005_24_controls_never_take_focus`, `test_r_005_30_keys_translated`, `test_screen_consumes_touches`, `test_setup_without_inventories_reports_error` | Movidos a `unit/test_container_screen.gd` con sus nombres (`CONTAINER_TAKE_ALL` en lugar de `LOOT_TAKE_ALL`) | D13 |
| `unit/test_loot_screen.gd::test_r_005_18_tap_box_cell_takes_stack`, `test_r_005_18_tap_takes_as_much_as_fits`, `test_r_005_18_occupied_box_cells_can_be_pressed` | Sustituidos por `test_r_012_28_tap_selects_whole_stack` y `test_r_012_29_tap_target_moves` (tocar ya no coge: selecciona) | R-012-37 sustituye a R-005-18 |
| `unit/test_loot_screen.gd::test_r_005_21_requests_close_when_box_empty`, `test_r_005_21_last_tap_requests_close` | Sustituidos por `test_r_012_35_stays_open_when_empty` | R-012-37 sustituye a R-005-21 |
| `unit/test_loot_box.gd::test_r_005_21_emptied_box_disabled_forever`, `test_r_005_21_empty_roll_disables` | Sustituidos por `test_r_012_37_never_disabled` y `test_r_012_37_every_interaction_opens_also_empty` | R-012-37 |
| `unit/test_loot_box.gd::test_r_005_16_interaction_emits_opened_with_opener` | Se queda (sigue siendo cierto) | — |
| `unit/test_loot_box.gd::test_r_010_27_restored_box_disables_when_emptied`, `test_r_010_27_restore_empty_contents_disables` | Sustituidos por `test_r_012_37_restored_empty_box_stays_enabled` (abre el contenedor) | R-012-37 |
| `integration/test_robot_interaction.gd::test_r_005_21_emptied_box_is_no_longer_offered` | Sustituido por `test_r_012_37_emptied_box_still_offered` | R-012-37 |
| `integration/test_main_scene.gd` (línea ~406, `is LootScreen`) | Pasa a `test_r_012_37_box_opens_container_screen` con `is ContainerScreen` | D13 |
| `integration/test_main_scene.gd::test_r_005_24_storage_closes_loot_screen` | Renombrado `test_r_005_24_storage_closes_container_screen`, mismos asserts | D13 |
| `unit/test_ui_manager.gd::test_real_catalog_lists_both_screens` | `LootScreen.SCREEN_ID` → `ContainerScreen.SCREEN_ID` | D13 |
| `unit/test_bench_screen.gd::test_r_009_64_lists_recipes_with_name_and_cost` | Cuenta una entrada por receta de estructura del catálogo en lugar de 1; los asserts de la estación siguen (añadido al implementar) | R-012-07 |
| `unit/test_data_catalog.gd` (`EXPECTED_ITEMS`) | Gana `portable_battery` (pila 5): `test_r_004_20_every_item_file_in_catalog` cuenta un archivo por material de BALANCE §2, que ya lista la batería (añadido al implementar) | R-012-05 |
| `unit/test_loot_box.gd::test_r_005_17_rolls_once_into_contents` | El número de ranuras pasa de "una por pila" a la capacidad de un cofre; el resto de asserts sigue (añadido al implementar) | R-012-37 |
| `integration/test_main_scene.gd::test_r_005_19_open_box_take_all_fills_inventory` | Sus dos asserts de R-005-21 (la pantalla se cierra sola, la caja se desactiva) pasan a lo contrario (la pantalla sigue abierta, la caja sigue activa); los de R-005-19 siguen (añadido al implementar) | R-012-35, R-012-37 |

### 5.5 Resultado de los pasos manuales (T-012-15, 2026-11-20)

Hechos por la persona que revisa en PC (Windows) y en Android (APK debug). Resultado según su informe: todo pasa.

| Paso | Resultado |
|---|---|
| M1 (PC) | ✅ Generador (2x2) y cofre se construyen, se colocan y se mueven sin perder estado; la batería máxima pasa de 100 a 120 y la estación recarga a 120; las aspas giran y el rótulo muestra baterías y cuenta atrás; límite del generador con "Límite alcanzado"; el cofre selecciona, mueve, transfiere y coge todo, y se cierra con Escape, clic fuera y Tab; su contenido sobrevive a viajar, morir y reiniciar; la caja de loot abre la misma pantalla y no se desactiva al vaciarse |
| M2 (PC, reloj) | ✅ Con el reloj adelantado 8 h el generador tiene 2; se recogen, una se usa con "Usar" y otra con Q (+20 sin pasar de la máxima); con la batería llena sale "La batería ya está llena" |
| M3 (Android) | ✅ Tocar fuera del panel del banco, del inventario y del cofre los cierra una vez sin atacar ni mover al robot; la colocación sigue eligiendo celda; la pantalla de contenedor se maneja con el dedo y los textos caben en ES y EN. Confirma el punto **(verificar)** del joystick de §5.1 |

### 5.6 Notas de implementación (2026-11-19)

Cambios menores frente a §2 y §3, sin cambiar ningún requisito:

- `ContainerScreen` usa `enum GridSide` en lugar de `enum Side`: Godot 4.7 ya tiene un enum global `Side`
  (`SIDE_LEFT`…) y el nombre chocaba al tipar.
- `StructureStates` no es un nodo de `main.tscn`: `BaseStructures` lo crea como hijo en `_ready()`, así cualquier
  `BaseStructures` (también los de los tests) lo tiene sin cablearlo. Sigue bajo `World`, como pide D5.
- `BaseStructures.to_save_data()` solo escribe `chests` y `generators` cuando no están vacíos: una base sin cofres
  ni generadores se guarda igual que en la spec 010 (`test_r_010_31_saved_as_spec_009` sigue sin cambios).
- El test de R-012-48 de la colocación está en `integration/test_placement_screen.gd`, que es donde vive ese
  archivo (§5.2 decía `unit/`).
- `ContainerScreen` no sobrescribe `on_closed()` (§3 lo listaba): no tiene nada que soltar, porque sus conexiones a
  `inventory_changed` se van con la pantalla al liberarse.
- Revisión de `architecture-guardian` (2026-11-20): sin bloqueantes. Aplicado: la excepción D12 escrita en
  architecture §3 regla 3, `wait_time = 1.0` explícito en el `RefreshTimer` del generador y el aviso de la
  pantalla de contenedor que se oculta al cambiar de selección (con test).
- Punto **(verificar)** de §5.1 sobre el joystick: `test_r_012_47_outside_touch_does_not_reach_joystick` pasa, y
  se comprobó aparte que sin pantalla abierta el mismo `InputEventScreenTouch` sí llega al joystick (el test no es
  vacío). Falta confirmarlo en Android (M3).

## 6. Check de constitución

| Principio | Cumple | Nota |
|---|---|---|
| P1 Spec primero | ✅ | Spec aprobada el 2026-11-19 con sus 13 preguntas cerradas |
| P2 Una fuente de verdad | ✅ | Costes, límites, bonificación, periodo, máximo, capacidad y puntos en `.tres` desde BALANCE §1.1, §1.3, §2, §5.2-§5.6. La capacidad de caja y cofre es un solo recurso (D3). Sin ids escritos en scripts (D2, D4). El segundo del refresco del rótulo es presentación (D17) |
| P3 Lógica separada | ⚠️ | Reloj, movimientos y consumibles en `WindGeneratorRules`, `InventoryRules`, `ConsumableRules` sin nodos; los componentes escriben; la UI y los flujos solo piden. Desviación de architecture §3 regla 3: `InventoryComponent.move_to_slot` / `transfer_to` escriben también las ranuras de `target`, otro `InventoryComponent` (D12). Justificación: intercambio atómico entre dos dueños de la misma clase, con la misma validación y una señal por inventario; la alternativa (un método público que reemplace ranuras) abre más de lo que cierra |
| P4 Estado por jugador | ✅ | Batería e inventario siguen en el robot. Cofres y generadores son estado del mundo (base) bajo `World`, no de un jugador ni de un autoload; la bonificación sube a cada robot conectado (D9) |
| P5 Datos como recursos | ✅ | `WindGeneratorData`, `StorageChestData`, `ContainerConfigData`, `ConsumableData` con `class_name` y `.tres` |
| P6 Señales | ✅ | Dos eventos nuevos con fila en architecture §7 y `player_uid`; `max_battery_bonus_changed` y `generator_changed` son señales de estado (`*_changed`); `structure_used` es local. Referencias con `@export` y `%UniqueName` |
| P7 Tipado | ✅ | Todo tipado; la conexión de instancias con su estado es por clase (`as StorageChest`, `as WindGenerator`), sin `call()` |
| P8 Plataforma | ✅ | Q es la acción `use_consumable`; tocar fuera atiende un solo tipo de evento que llega igual con ratón y con toque (D16, M3) |
| P9 Determinismo | ✅ | El generador depende del tiempo de juego por `ITimeService`, no de RNG; el `uid` de las estructuras sigue siendo identidad |
| P10 Servicios | ✅ | La hora solo por `ITimeService` (R-012-19), con test que lo vigila |
| P11 i18n | ✅ | Claves de §4.1 en ES y EN; el rótulo 3D usa `tr()` |
| P12 Presupuesto móvil | ✅ | Modelos de primitivas (pocas decenas de triángulos), sin luces; el rótulo se repinta una vez por segundo, no por fotograma |
| P13 Test primero | ✅ | Cada tarea de lógica empieza por su test (tasks.md). Tests existentes que cambian, cada uno con su sustituto y su motivo: §5.4 (R-012-14 y R-012-37 cambian lo que comprobaban); ninguno se quita para pasar la CI. Tiempo con `FakeTimeService` (D21) |
| P14 Alcance | ⚠️ | Dentro de la spec. Cambios fuera de lo literal, justificados: `UIManager.open()` devuelve la pantalla y `UIScreen.closed` (D15, para R-012-44); sustituir un test de la spec 010 (D11, lo cambia R-012-14); borrar `LootScreen` y los tests de R-005-18/R-005-21 (D13, lo pide R-012-37) |

## 7. Riesgos y alternativas descartadas

- **Botones del HUD encima de las pantallas** (atacar, interactuar, almacén): un toque fuera del panel que cae en uno
  de ellos no cierra la pantalla. → Aceptado: el ataque y la interacción no hacen nada con la entrada bloqueada
  (spec 005, 007) y el almacén ya cierra la de arriba. M3 lo comprueba.
- **Toque doble en Android** (toque + ratón emulado) → solo se atiende `InputEventMouseButton` (D16); M3.
- **Recargar con la base cargada** (tests de `test_save_load.gd`) dejaría un `WindGenerator` con un estado
  liberado → orden de D5 (estados antes que instancias) y estados guardados por `uid` en un diccionario, no por
  nombre de nodo; test `test_r_012_10_reload_with_base_loaded_rebinds_state`.
- **Aviso del generador con argumentos** (D18): el texto ya traducido no cambia si se cambia el idioma con el aviso
  visible. Aceptado: dura unos segundos y no hay cambio de idioma en caliente en el PMV.
- **`BaseStructures` crece**: el estado vive en `StructureStates` y el uso en `StructureUseFlow`, para que
  `BaseStructures` siga siendo cuadrícula, colocación y su parte del guardado.
- **Vista previa del generador** sin estado ni `time_service` → `WindGenerator` funciona sin `bind_state`
  (test `test_r_012_21_preview_without_state`).
- **Una caja guardada antes de esta spec** tiene tantas ranuras como pilas tiradas (≤ 3): al restaurarla se le dan
  las 4 de la capacidad y se cargan sus pilas (R-012-37); una lista guardada más larga que la capacidad pierde lo de
  más con `push_error` (regla de `from_save_data`, spec 010).
- **Cambiar la hora del móvil adelanta el generador** → aceptado en el PMV (architecture §14, pregunta 2).
- **Carga por encima de la máxima base sin generador** (archivo editado o entrada del generador perdida): se queda
  en la máxima, sin error (D11). La entrada perdida ya se informa en `StructureStates` (R-012-42).
- **Cooperativo (v2.0)**: un robot que entra después debe conectarse a `max_battery_bonus_changed` y leer el valor
  actual; hoy `Main` lo hace con el robot local (D9).
- **ACTION_PLAN 2.6** describe el cofre con `chest_id`, `items = []` y `add_item()`; el plan usa un
  `InventoryComponent` por cofre (R-012-26), que ya da esas operaciones. Se anota en ACTION_PLAN al cerrar.
- **Descartado**: estado en la instancia de la escena (§1); un `uid` de estado persistente propio en el grupo
  `persistent` (rompería R-012-42 por el orden de carga); sumar la bonificación de varios generadores (D9); cargar
  las partes del mundo antes que las de los jugadores en `SaveManager` en vez de D11 (R-012-14 pide no depender del
  orden); una pantalla para el generador (pregunta 7); una regla genérica de "estado por estructura" con un
  `PackedScene` en `StructureData` (dos casos no justifican la abstracción, constitución P2).

### 7.1 Revisión de `architecture-guardian` (2026-11-19)

Un bloqueante, corregido: la lista de tests que cambian estaba incompleta (faltaban los dos `test_r_010_27_*` de
cajas restauradas que se desactivan, el de `test_robot_interaction.gd` y dos que nombran `LootScreen`); ahora
está entera en §5.4, cada uno con su sustituto.

Aplicado también:
- D11: la carga pendiente informa con `push_error` cuando se borra sin aplicarse, y se dice qué la borra.
- D5: los estados se crean antes que las instancias, al colocar y al cargar, y se guardan por `uid` en un
  diccionario. Hay test de recarga con la base cargada.
- D16: `mouse_filter = STOP` explícito en el panel. Un solo panel por pantalla. Prueba de "dentro del panel" en las
  tres pantallas.
- §5.1: comprobados `PanelContainer.mouse_filter`, `Animation.loop_mode`, `Viewport.push_input` y
  `return_value_discarded`. Queda marcado **(verificar)** que un toque no llegue al joystick, con su test.
- D15: `close_all()` también emite `closed`, y `open()` puede devolver `null`.
- D21: `FakeTimeService` en todos los tests, y `time_service` por defecto en `_ready()`.
- D7: guarda contra datos con periodo o máximo menor que 1.
- D4: el uso va por ranura y no por id.
- D22: dónde se ven las negativas del contenedor.
- tasks.md: architecture §9.1 se actualiza en T-012-12.

Sin cambiar, con su porqué:
- D12 se queda en la opción (b): escribe las ranuras del otro inventario, declarado como desviación en §6 (P3).
  La opción (a), un método público que reemplace ranuras, permitiría a cualquiera reescribir un inventario.
- D15 mantiene `open()` con retorno frente a una señal `UIManager.screen_closed(screen_id)`. Con esa señal, el
  flujo no sabría qué cofre se ha cerrado sin guardarse aparte la pantalla.
