# Arquitectura — CyberScrap

| Campo | Valor |
|---|---|
| **Estado** | Aprobado (2026-11-14) |
| **Versión** | 1.0 · 2026-11-14 |
| **Decisión** | [ADR 0005](decisions/0005-architecture-baseline.md) |
| **Fuentes** | PMV.md §4 (principios, carpetas, patrones, ganchos §4.5) · ONLINE.md "Preparación del código desde el PMV" · [constitution.md](constitution.md) · ADR 0001-0004 |

> Este documento define **cómo se organiza el código** para que todos los specs lo sigan. No repite el diseño
> del juego ni los principios de la constitución: los aplica. Cada sección termina con su preparación para
> servidor y cómo se verifica. Lo marcado **(verificar)** se comprueba en la documentación de Godot 4.7 antes de
> implementarlo.

---

## 1. Objetivos de calidad

| Prioridad | Objetivo | Cómo se consigue |
|---|---|---|
| 1 | **Correcto y testeable** | Reglas de juego en código puro, testeado con GUT sin escenas (§3, §13) |
| 2 | **Mantenible por una persona** | Un sitio para cada cosa, dependencias en un solo sentido, sin magia (§3) |
| 3 | **Rendimiento móvil** | Escenas ligeras, pools, nada de sondeo por fotograma en la UI (§11) |
| 4 | **Preparado para multijugador y servidor** | Estado con dueño único, cambios solo por métodos con parámetros explícitos, ids estables, datos y guardado en JSON versionado (§12) |

## 2. Contexto

```
                ┌───────────────────────────────────┐
  Jugador ────▶ │  Cliente Godot (Android / PC dev) │ ──▶ archivos locales (Perfil, Mundo, ajustes)
                └───────────────────────────────────┘
                     │ v1.1 tienda nativa (IStore)
                     │ v1.5 backend asíncrono (solo vía OnlineManager)
                     │ v2.0 otros clientes en red local (host autoritativo)
```

En el PMV no hay red ni servidor. Todo lo que hable con algo externo vive detrás de un contrato (§10) con una
implementación local.

## 3. Capas y regla de dependencias

```
  Presentación      escenas, nodos visuales, HUD, pantallas, controles táctiles
        │  (escucha señales, envía peticiones)
        ▼
  Entidades y       nodos de juego (Robot, Zombie, LootBox…) y sus componentes
  componentes       (BatteryComponent, InventoryComponent…): dueños del estado
        │  (llaman a lógica pura con parámetros explícitos)
        ▼
  Sistemas          lógica pura sin Node ni autoloads: CraftingSystem, CombatSystem,
                    DegradationSystem, StatsCalculator, ChassisLevelSystem…
        │
        ▼
  Datos             Resources (.tres): ItemData, PieceData, RecipeData, EnemyData…

  Servicios         contratos + implementación local: ISaveStore, ITimeService, IStore
  (al lado)         accesibles solo desde autoloads; nunca desde Sistemas
```

Reglas (se revisan en cada plan, constitución P3):

1. Una capa solo depende de las de **debajo**. Los Sistemas no conocen nodos, escenas, autoloads ni la UI.
2. **La UI nunca cambia estado**: pide el cambio al componente dueño y muestra el resultado.
3. **Todo cambio de estado tiene un único dueño**: el componente que lo guarda. Nadie más escribe sus campos.
   Única excepción (spec 012, plan D12): `InventoryComponent.move_to_slot` / `transfer_to` escriben también las
   ranuras del otro `InventoryComponent` en un solo paso, para que un intercambio entre dos inventarios sea
   atómico; solo entre instancias de esa misma clase, que validan igual. Ninguna otra clase lo hace.
4. Los métodos que cambian estado reciben todo lo que necesitan por parámetro (inventario, receta, `delta`…) y
   devuelven un `ActionResult` (§9.2). Así se testean sin escena y, más adelante, se ejecutan en el anfitrión o
   el servidor (§12).

## 4. Estructura de carpetas

Base: PMV.md §4.2 + ADR 0004. Se concreta así:

| Carpeta (`game/`) | Contenido |
|---|---|
| `scenes/<área>/` | Escenas `.tscn` **con su script al lado** (`robot.tscn` + `robot.gd`). Solo presentación y cableado |
| `scripts/autoload/` | Autoloads (§5) |
| `scripts/components/` | Componentes reutilizables |
| `scripts/systems/` | Lógica pura |
| `scripts/data/` | Clases `Resource` (`item_data.gd`, `stat_modifier.gd`…) |
| `scripts/services/` | Contratos (`i_save_store.gd`) e implementaciones locales (`local_save_store.gd`). **Carpeta nueva** respecto a PMV §4.2 |
| `scripts/util/` | Utilidades sin estado (`seeded_rng.gd`, `uid.gd`) |
| `resources/<tipo>/` | Instancias `.tres` (`resources/items/scrap.tres`) y el catálogo (§8) |
| `tests/unit/`, `tests/integration/` | GUT (ADR 0002) |

## 5. Autoloads

Lista cerrada. Añadir uno requiere cambiar este documento.

| Autoload | Responsabilidad | No hace |
|---|---|---|
| `EventBus` | Señales de hechos globales (§7) | Guardar estado |
| `DataRegistry` | Catálogo de datos por id (§8) | Cargar partidas |
| `GameManager` | Estado global de la partida: mundo (id, nombre, semilla), ruleset, zona actual, contadores de visitas por zona; acceso a `ITimeService` y a `IStore` (spec 010) | Guardar estado de un jugador (PMV §4.5 gancho 7) |
| `SaveManager` | Orquestar guardado y carga (§6); guarda en memoria el Perfil cargado (uuid, derechos), que es estado de la cuenta y no de un robot ni de un mundo (spec 010) | Saber cómo se serializa cada componente; guardar estado de un jugador entre guardados |
| `AudioManager` | SFX y música con pool de reproductores | Decidir cuándo suena algo (escucha eventos) |
| `TutorialManager` | Guía básica (ACTION_PLAN 5.4) | Bloquear el juego fuera de sus pasos |

Más adelante: `OnlineManager` (v1.5, único que habla con un backend) y `MultiplayerManager` (v2.0).

## 6. Flujo de escenas

**Decisión**: escena raíz persistente con un hueco para la zona.

```
Main (Node)                          main.gd: arranque y cableado
├── World (Node3D)
│   ├── ZoneSlot (Node3D)            una zona cargada a la vez: base o zona verde
│   └── Players (Node3D)
│       └── Robot (CharacterBody3D)  persiste entre zonas
│           ├── BatteryComponent
│           ├── InventoryComponent
│           ├── EquipmentComponent   ranuras Brazos / Piernas / Core y su desgaste (§9.3)
│           ├── StatsComponent       stats finales (§9.4)
│           └── InteractorComponent  objeto interactuable más cercano (§9.1)
├── CameraRig                        sigue al jugador local
├── ZoneLoader (Node)                carga y descarga zonas
└── UI (CanvasLayer)
    ├── HUD
    ├── TouchControls                joystick flotante y botones (spec 002)
    └── UIManager                    pila de pantallas emergentes (§9.5)
```

- **Sin `DegradationComponent`** (spec 015, plan D9): no tendría estado propio, porque la durabilidad vive en las
  pilas del equipo. El desgaste es de `EquipmentComponent` con la regla en el sistema puro `DegradationSystem`.
- **Viajar**: `ZoneLoader.travel_to(zone_id)` carga la escena de la zona en segundo plano
  (`ResourceLoader.load_threaded_request`, **(verificar)**) mientras se ve la pantalla de carga, libera la zona
  anterior, instancia la nueva en `ZoneSlot`, coloca al robot en su `SpawnPoint` y emite
  `EventBus.zone_changed`.
- **Cada zona** es una escena con su `zone_id` y sus puntos de aparición. Las zonas se registran como datos
  (`ZoneData`: id, escena, tipo `BASE` o `FARM`) en el catálogo (§8).
- **Por qué**: el robot conserva su estado sin pasar por el guardado en cada viaje; el viaje es rápido; varios
  robots caben bajo `Players` (cooperativo v2.0).
- **Descartado**: `change_scene_to_file()` en cada viaje. Destruye al robot y obliga a reconstruirlo desde el
  guardado cada vez.
- **Servidor**: el anfitrión decide la zona de cada jugador; `ZoneLoader` ya recibe el `zone_id` desde fuera.
- **Verificación**: test de integración que viaja base → zona → base y comprueba que la batería y el inventario
  del robot no cambian por el viaje.

## 7. Señales y bus de eventos

**Decisión**: sistema mixto.

- **Señales locales** (lo normal): un componente emite y su entidad, la UI enlazada o un hermano escucha.
  Ejemplos: `battery_changed`, `inventory_changed`, `stats_changed`, `interacted`.
- **`EventBus`** (lo excepcional): solo hechos que interesan a sistemas sin relación entre sí (guía, audio,
  notificaciones, guardado). Catálogo inicial, se amplía en cada spec:

| Evento | Argumentos | Lo emite | Lo escuchan (ejemplos) |
|---|---|---|---|
| `player_died` | `player_uid: String` | Ruleset (spec 008) | Audio, guía, guardado |
| `player_respawned` | `player_uid: String` | Ruleset | HUD, audio |
| `zone_changed` | `zone_id: Vector2i` | `ZoneLoader` | Audio (música), guardado, guía |
| `game_saved` | `reason: StringName` | `SaveManager` | Notificaciones |
| `enemy_killed` | `enemy_id: StringName`, `killer_uid: String` | Enemigo | Progresión, guía, audio |
| `item_crafted` | `recipe_id: StringName`, `player_uid: String` | `RepairBench` (spec 011) | Guardado (spec 011), guía, audio |
| `structure_built` | `structure_uid: String` | Colocación (Tarea 2.8) | Guardado, guía |
| `player_recharged` | `player_uid: String` | Estación de carga (spec 009) | Guardado (spec 010), guía |
| `structure_moved` | `structure_uid: String` | `BaseStructures` (spec 010) | Guardado |
| `piece_repaired` | `piece_uid: String`, `player_uid: String` | `RepairBench` (spec 011) | Guardado, guía, audio |
| `batteries_collected` | `structure_uid: String`, `player_uid: String` | `BaseStructures` (spec 012) | Guardado (spec 012), guía, audio |
| `chest_closed` | `structure_uid: String`, `player_uid: String` | `StructureUseFlow` (spec 012), al cerrar la pantalla de un cofre cuyo contenido cambió | Guardado (spec 012) |

**Señales de estado y de hecho** (spec 010, D15). Las **de estado** dicen cuál es un valor ahora y repetirlas no
tiene efectos (`battery_changed`, `inventory_changed`, `xp_changed`, `level_changed`, `health_changed`); por
convención se llaman `*_changed`. Las **de hecho** dicen que algo pasó y sus oyentes reaccionan (todo `EventBus`, `zone_visit_counted`,
`battery_low`, `battery_depleted`, `overflowed`, `level_up`…). Cargar una partida emite solo señales de estado
(§10.2). Una señal nueva elige su clase y su nombre con esta regla.

El equipo (spec 015) emite desde `robot.equipment` `equipment_changed` (estado: las ranuras cambiaron, también al
cargar), `durability_changed(slot, durability)` (estado: una pieza se desgastó sin romperse o se reparó) y
`piece_broken(piece_uid, slot, piece)` (hecho: una pieza se rompió y se perdió, nunca al cargar); `robot.stats`
emite `stats_changed` (estado). Ninguna va al `EventBus`: "Pieza rota" se engancha ahí hasta la Tarea 4.1. El objeto
caído emite `opened` y `DroppedItemSpawner` lo reemite como `item_opened`, más `item_removed` al irse un objeto
(caducidad, descarga, vaciado): los tres son de hecho.

El nivel de chasis (spec 014) emite `level_changed(level)` (estado) y `level_up(new_level)` (hecho, nunca al
cargar) desde `robot.experience`, el mismo componente que `xp_changed`: ahí se enganchan la notificación (Tarea
4.1), el sonido (Tarea 4.3) y los recuerdos (spec 017). No van al `EventBus`; la spec que necesite el evento lo
añade a la tabla con `player_uid`.

Reglas: el bus **no guarda estado**; toda señal está tipada; todo evento que afecte a un jugador lleva su
`player_uid` (cooperativo); un evento nuevo se añade a esta tabla en el plan del spec que lo crea.

- **Por qué**: las conexiones directas entre sistemas sin relación crean dependencias cruzadas; un bus para todo
  hace imposible saber quién escucha qué. La mezcla limita el bus a una lista corta y documentada.
- **Servidor**: el bus es local. Lo que viaja por red pasa por `MultiplayerManager` / `OnlineManager`, que
  pueden reemitir en el bus lo que llega de fuera sin que el resto del juego cambie.

## 8. Catálogo de datos

**Decisión**: `DataRegistry` carga al arrancar un recurso `DataCatalog.tres` que enumera todos los `.tres` de
datos, y los indexa por `id`.

```gdscript
class_name DataCatalog
extends Resource

@export var items: Array[ItemData] = []      # incluye PieceData y ConsumableData (heredan de ItemData)
@export var recipes: Array[RecipeData] = []
@export var enemies: Array[EnemyData] = []
@export var zones: Array[ZoneData] = []
@export var rulesets: Array[RulesetData] = []
@export var structures: Array[StructureData] = []   # estructuras colocables (spec 009); incluye WindGeneratorData y StorageChestData (spec 012)
@export var repair_costs: RepairCostData             # tramos de reparación de BALANCE §4.3.2 (spec 011)
```

`DataRegistry` expone `get_item(id: StringName) -> ItemData`, `get_recipe(id)`, etc., y `push_error()` si un
id no existe.

- **Ids**: `StringName` en `snake_case`, estables para siempre (`scrap`, `basic_arms`). Nunca se renombra un id
  publicado; si cambia el concepto, se crea otro id. Los guardados y la red solo usan ids, nunca rutas de
  archivo.
- **Por qué un catálogo explícito y no escanear carpetas**: en Android exportado los recursos pueden cambiar de
  nombre (conversión a binario y archivos `.remap`) y el listado de `res://` no es fiable **(verificar)**.
- **Servidor**: los datos se pueden exportar a JSON (id → campos) con una herramienta del editor cuando un
  servidor no-Godot los necesite (v3.0). El id es el contrato común.
- **Verificación**: tests que comprueban que no hay ids repetidos, que todo `.tres` de `resources/` está en el
  catálogo y que toda referencia por id (recetas, drops) existe.

## 9. Patrones de juego

### 9.1 Interacción

**Decisión**: un componente para lo interactuable y otro para quien interactúa.

```gdscript
class_name InteractableComponent
extends Area3D

signal interacted(interactor: Node3D)

@export var prompt_key: StringName           # clave de traducción: "PROMPT_OPEN", "PROMPT_RECHARGE", "PROMPT_TRAVEL"…
@export var enabled: bool = true

func interact(interactor: Node3D) -> void    # emite interacted si enabled
```

- `InteractorComponent` (en el robot) detecta el interactuable **más cercano** dentro de su área y emite
  `target_changed(target: InteractableComponent)`. El HUD muestra un solo botón "Interactuar" con el texto
  `tr(prompt_key)`; en PC, la tecla E.
- Caja, banco, estación, cofre, generador y objeto caído **solo** conectan `interacted` a su lógica. La
  proximidad, el botón y el texto se programan una vez.
- **Objeto caído** (spec 015): es un contenedor como cajas y cofres. Interactuar solo emite `opened`;
  `DroppedItemSpawner` lo reemite como `item_opened` y `DroppedItemFlow` abre la pantalla de contenedor
  (`Kind.DROPPED`). Al cerrarse la pantalla pide `release_if_empty`; si el objeto caduca con la pantalla abierta,
  `item_removed` la cierra con `UIManager.close(screen)`.
- **Cofre y generador** (spec 012): su estado no vive en la instancia (se libera con la base), así que la
  instancia solo emite `used(user)`; `BaseStructures` lo reemite como `structure_used(structure_uid, user)` y
  `StructureUseFlow` abre la pantalla del cofre o pide `BaseStructures.collect_batteries(player, uid)`, igual que
  `BuildFlow` hace con el banco.
- **Servidor**: `interact` es la petición; el anfitrión comprueba la distancia antes de aceptarla.

### 9.2 Cambios de estado y resultados

Toda acción que puede fallar devuelve un resultado, en lugar de un `bool` o un `print`:

```gdscript
class_name ActionResult
extends RefCounted

var ok: bool
var error_key: StringName                    # clave de traducción: "ERR_NOT_ENOUGH_MATERIALS"…

static func success() -> ActionResult
static func failure(key: StringName) -> ActionResult
```

La UI muestra `tr(error_key)`. Un solo tipo de resultado para todo el juego (DRY).

### 9.3 Inventario y piezas

**Decisión**: cada ranura guarda un `ItemStack`; las piezas son objetos con `stack_max = 1` y durabilidad.

```gdscript
class_name ItemStack
extends RefCounted

var item: ItemData
var quantity: int
var durability: int = -1                     # -1 = no aplica (materiales); 0-100 en piezas
var uid: String = ""                         # solo objetos únicos (piezas): identidad estable
```

- `PieceData extends ItemData` nace en la spec 011 con `durability_max` y `stack_max = 1`; la spec 015 añade
  `slot_type` y `modifiers: Array[StatModifier]`. Una pieza en un inventario siempre tiene cantidad 1,
  durabilidad entre 1 y su máxima y `uid` (`InventoryRules.is_valid_stack`), y todo camino que mueve una pila
  conserva su durabilidad y su `uid` (`InventoryRules.add_stack`).
- `InventoryComponent` gestiona ranuras (`add`, `remove`, `has`, `get_slots`) y emite `inventory_changed`; las
  reglas de apilado viven en un sistema puro (`InventoryRules`) que se testea solo.
- `EquipmentComponent` (spec 015) guarda las tres ranuras indexadas por `PieceData.SlotType` (`ARMS`, `LEGS`,
  `CORE`), cada una vacía o con una pila de pieza con su `uid` y durabilidad, y emite `equipment_changed`. Equipar
  y quitar no amplían la excepción de `move_to_slot`: el equipo escribe su ranura y pide al inventario que escriba
  la suya (`InventoryComponent.exchange_slot`, `add_stacks`), con el estado final antes de cualquier señal. El
  desgaste por golpe (`apply_hit_wear`) elige la pieza con `DegradationSystem` (brazos → piernas → core); a 0 la
  pieza se rompe y se pierde.

### 9.4 Stats de piezas

**Decisión**: modificadores como datos y un cálculo puro.

```gdscript
class_name StatModifier
extends Resource

enum Op { SET, ADD, MULTIPLY }

@export var stat: StringName                 # un id de StatIds: "walk_speed", "run_speed", "attack_damage"…
@export var op: Op
@export var value: float
```

- Ids reales (spec 015, `StatIds`): `walk_speed`, `run_speed` (0 = no puede correr), `walk_drain`, `run_drain`,
  `passive_drain`, `max_battery`, `attack_damage`, `attacks_per_second`, `battery_per_swing`, `durability_per_hit`.
- Valores base del robot **sin piezas** en `RobotBaseStatsData` (`resources/robot/robot_base_stats.tres`,
  BALANCE §1.1, §4.1, §4.2: sin piernas 0.5 m/s, con un brazo 5 de daño, sin Core 0.2/s…), un campo por id. Cada
  `PieceData` lleva su `slot_type` y sus `modifiers` (su fila de BALANCE §4.2 con `SET`).
- `StatsCalculator.compute(base, modifiers) -> Dictionary` aplica en orden `SET` → `ADD` → `MULTIPLY`.
- `StatsComponent` recalcula al cambiar el equipo o romperse una pieza y emite `stats_changed`. Cableado "push"
  (plan 015 D5): `Robot` le pasa los modificadores del equipo y, en cada `stats_changed`, **entrega** a movimiento
  (`MovementStatsData`), combate (`MeleeAttackComponent.set_attack`) y batería (`set_drain_rates`,
  `set_base_maximum`) los valores que usan; ninguno mira las piezas ni conoce a `StatsComponent`. La máxima de la
  batería es el stat más la bonificación del generador (`set_maximum_bonus`).
- **Por qué**: una pieza nueva de v1.1 o el overclock (modificador temporal) son datos, no código. Cumple el
  "Strategy" de PMV §4.3 sin una clase por pieza.

### 9.5 Pantallas y HUD

**Decisión**: `UIManager` con una pila de pantallas emergentes.

```gdscript
func open(screen_id: StringName, context: Dictionary = {}) -> UIScreen   # la abierta o null (spec 012)
func close_top() -> void
func close(screen: UIScreen) -> void                 # spec 015: cierra esa, esté donde esté en la pila
func is_modal_open() -> bool
func is_open(screen_id: StringName) -> bool         # spec 009
signal modal_state_changed(is_open: bool)

# UIScreen (base de las pantallas)
func setup(context: Dictionary) -> void
func handle_back() -> bool   # true: la pantalla atendió "atrás" y sigue abierta (spec 009)
func on_closed() -> void     # al salir de la pila por cualquier camino, antes de liberarse (spec 009)
signal closed                # la emite UIManager tras on_closed(), por cualquier camino (spec 012)
signal back_requested        # toque fuera del panel (spec 012)
@export var closes_on_outside_tap: bool = false   # spec 012
```

- **Cerrar tocando fuera** (spec 012, R-012-46 a R-012-48): una pantalla con `closes_on_outside_tap` emite
  `back_requested` cuando un toque o clic izquierdo llega a su propio `_gui_input`, es decir, cuando ningún hijo lo
  paró: su panel único tiene `mouse_filter = STOP` y su fondo y su centrado `IGNORE`. Solo atiende
  `InputEventMouseButton` (en Android llega emulado desde el toque) y lo acepta, así que no llega a
  `_unhandled_input` (ataque, joystick). `UIManager` lo trata como Escape, y solo para la de arriba. Banco,
  inventario y contenedor lo activan; la colocación y el aviso no.

- Las pantallas (banco, cofre, inventario, equipo, pausa) se registran por id en un recurso de catálogo de UI.
- Escape (PC) y el botón atrás de Android (`NOTIFICATION_WM_GO_BACK_REQUEST`, **(verificar)**) van a la de
  arriba: si su `handle_back()` devuelve `true` la atiende ella (la colocación cancela un movimiento y sigue en
  edición, spec 009); si no, se cierra.
- Con una pantalla abierta, el control del robot ignora el movimiento (escucha `modal_state_changed`).
- El HUD se engancha al jugador local con `bind(player: Robot)` y escucha sus señales. **Nada de leer estado en
  `_process`.**
- **Servidor/cooperativo**: cada cliente enlaza su HUD a su robot local; la UI nunca asume que hay un solo
  jugador.

## 10. Servicios y guardado

### 10.1 Contratos

| Contrato | Implementación PMV | Futuro |
|---|---|---|
| `ISaveStore` (leer/escribir bytes de Perfil y Mundo, con copia de seguridad) | `LocalSaveStore` (archivos en `user://`, cifrados) | Guardado en la nube (v2.0+) |
| `ITimeService` (`now_unix() -> int`) | `LocalTimeService` (reloj del dispositivo) | Hora del servidor (anti-trampas) |
| `IStore` (derechos de compra) | `LocalStore` (siempre demo) | Facturación nativa (v1.1) |

ONLINE.md los nombra `ISaveManager` e `ITimeManager`; aquí se separa quién **orquesta** (`SaveManager`, autoload)
de dónde se **almacena** (`ISaveStore`), para cambiar el almacenamiento sin tocar la orquestación.

GDScript no tiene interfaces: el contrato es una clase base cuyos métodos llaman a `push_error()` si no se
sobrescriben (ONLINE.md). `SaveManager` recibe la implementación al arrancar; nadie más la crea.

### 10.2 Serialización

**Decisión**: cada componente persistente sabe convertirse a datos simples; `SaveManager` solo orquesta.

- Los componentes persistentes están en el grupo `persistent` e implementan:
  `get_save_key() -> StringName`, `to_save_data() -> Dictionary`, `from_save_data(data: Dictionary) -> void`.
  Un componente ya hereda de `Node`, así que el contrato se comprueba con un test (todo nodo del grupo tiene los
  tres métodos), no con herencia.
- Los dueños de estado del mundo (contadores de visitas, objetos caídos, estructuras, estado de las visitas)
  también están en `persistent`: `SaveManager` guarda una parte bajo el `player_uid` de la entidad de la que
  cuelga el nodo (grupo `players`) o, si no cuelga de ninguna, bajo el mundo (spec 010).
- `to_save_data()` solo devuelve tipos JSON: números, textos, listas, diccionarios. Objetos como ids
  (`"basic_arms"`), posiciones como `(zone_id, local)`. La semilla del mundo va como texto decimal (un número JSON
  es un `float` y perdería precisión) y los `float` se escriben con precisión completa (spec 010).
- `from_save_data()` emite las señales **de estado** de su dueño y **nunca** las de hecho (§7): cargar no es que
  algo haya pasado. Por ejemplo, al cargar el nivel de chasis (spec 014) se emiten `xp_changed` y `level_changed`,
  pero no `level_up`; al cargar el equipo (spec 015), `equipment_changed` y `stats_changed`, nunca `piece_broken`.
- `SaveManager` aplica las partes en el orden del árbol del grupo `persistent`; un dueño cuyo estado se deriva de
  otro va después de él en la escena (spec 014: en `robot.tscn`, `Experience` va antes que `InventoryComponent`,
  para que el inventario tenga las ranuras del nivel cargado al leer las suyas; spec 015: `Equipment` es el primer
  nodo persistente del robot, antes que `BatteryComponent`, para que la batería tenga la máxima del Core cargado al
  leer su carga).
- El archivo lleva `schema_version`. Cada cambio de formato añade una función `migrate_vN_to_vN1(data)`; cargar
  aplica la cadena hasta la versión actual (Tarea 2.3).
- Añadir un campo **opcional** cuyo valor por defecto reproduce lo que se cargaba antes **no** sube
  `schema_version` (por ejemplo `durability` y `uid` en las pilas del objeto caído, spec 011). Quitar, renombrar o
  cambiar el significado de un campo sí la sube.
- **Nunca** se guardan ni cargan `Resource` de Godot en `user://`: un recurso cargado desde un archivo editable
  puede ejecutar código **(verificar en la documentación de seguridad de Godot)**.
- Ajustes del jugador (sensibilidad, volumen, calidad) van aparte, en `user://settings.cfg` con `ConfigFile`; no
  son parte del Perfil ni del Mundo.

### 10.3 Identidad

| Qué | Id |
|---|---|
| Definición de datos | `StringName` estable (§8) |
| Jugador | `player_uuid` generado localmente (Perfil, PMV §4.5) |
| Instancia única (pieza, estructura, objeto caído) | `uid` aleatorio de 128 bits en hexadecimal (`Crypto.generate_random_bytes`, **(verificar)**) |
| Zona | `zone_id: Vector2i` (PMV §4.5) |

## 11. Rendimiento

- Enemigos, proyectiles, partículas y objetos caídos salen de un `ObjectPool` genérico desde su primera versión
  (constitución P12).
- La UI se actualiza por señales, nunca sondeando en `_process`.
- La lógica de juego corre en `_physics_process` con `delta`; la presentación (animaciones, efectos) en
  `_process`.
- Generación con `SeededRng` (`scripts/util/`), que crea un `RandomNumberGenerator` con `semilla + zone_id`
  (constitución P9).

## 12. Preparación para multijugador y servidor

Qué se reutiliza de verdad en cada etapa de ONLINE.md:

| Etapa | Qué aporta esta arquitectura | Qué habrá que añadir |
|---|---|---|
| **v1.5 asíncrono** (Firebase) | Perfil separado del Mundo, ids estables, `player_uuid`, guardado en JSON versionado | `OnlineManager`, cola de acciones sin conexión, contratos `IMarket`, `IClan`… |
| **v2.0 cooperativo en red local** (anfitrión Godot) | **Se reutiliza casi toda la lógica**: el anfitrión ejecuta los mismos componentes y sistemas. Estado con dueño único, cambios por métodos con parámetros (§3 regla 4), eventos con `player_uid`, varios robots bajo `Players`, zonas regenerables desde la semilla | `MultiplayerManager`, autoridad por nodo, réplica de estado (`MultiplayerSynchronizer` / `MultiplayerSpawner`, **(verificar)**), peticiones del cliente al anfitrión |
| **v3.0 servidor dedicado** (Rust/Go) | Contratos de datos: ids, catálogo exportable a JSON, formato de guardado versionado, `ActionResult`, peticiones bien definidas | **La lógica GDScript no corre en Rust/Go: hay que reescribirla en el servidor.** La arquitectura reduce el coste (reglas aisladas y testeadas que sirven de especificación), no lo elimina |

Reglas que se cumplen desde el PMV para no cerrar esas puertas:

1. Ningún autoload guarda estado de un jugador.
2. Cada cambio de estado pasa por el método de su dueño, con parámetros explícitos y `ActionResult`.
3. La UI solo pide; nunca escribe estado.
4. Toda aleatoriedad de juego usa RNG con semilla; nada depende del orden de fotogramas.
5. Todo lo que se guarda o viajaría por red es JSON con ids, nunca objetos de Godot.
6. Todo evento relativo a un jugador lleva su `player_uid`.

## 13. Estrategia de tests por capa

| Capa | Tipo | Ejemplo |
|---|---|---|
| Sistemas | Unitario puro | `StatsCalculator` con base y modificadores; reglas de apilado |
| Componentes | Unitario sin árbol de escena | `BatteryComponent` con `tick(delta)` simulado; señales emitidas una vez |
| Datos | Validación del catálogo | Ids únicos, referencias existentes, todo `.tres` catalogado |
| Guardado | Ida y vuelta + migraciones | `to_save_data` → `from_save_data` igual; un archivo v1 de ejemplo carga en v2 |
| Escenas | Integración | Viaje entre zonas conserva estado; interactuar abre la pantalla correcta |

## 14. Preguntas abiertas

| # | Pregunta | Propuesta | ¿Bloquea? |
|---|---|---|---|
| 1 | ~~`zone_id` de la base en el PMV~~ | **Cerrada (nov 2026)**: `(0, -1)`, tipo `BASE` (la zona verde es `(0, 0)`, ACTION_PLAN 1.1). En v1.1 la base pasa a la celda que elija el jugador (SPECS §32). | — |
| 2 | ~~Cambiar el reloj del móvil adelanta las baterías del generador~~ | **Cerrada (nov 2026)**: se acepta en el PMV (un jugador, sin competición); `ITimeService` permite usar la hora del servidor más adelante. | — |
| 3 | ~~¿Scripts junto a su escena o todos en `scripts/`?~~ | **Cerrada (nov 2026)**: junto a su escena para la presentación; `scripts/` para lo reutilizable (§4). | — |
