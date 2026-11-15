# Plan 006 — Zombies: `HealthComponent`, IA y spawner con pool

| Campo | Valor |
|---|---|
| **Spec** | [spec.md](spec.md) (debe estar *Aprobado*) |
| **Estado** | Planificado (2026-11-15) |

## 1. Enfoque

**Capas (architecture §3).**

| Capa | Piezas |
|---|---|
| Datos | `EnemyData`, `EnemyAiData`, `EnemySpawnEntryData` y los campos de enemigos de `ZoneData` |
| Sistemas | `EnemyBrain`: la máquina de estados, pura, en `RefCounted`. Recibe la distancia al objetivo y `delta` por parámetro, sin nodos ni árbol de escena |
| Sistemas | `ZonePopulation.pick_enemy_spawns()`: número, tipo y marcador de cada zombie |
| Componentes | `HealthComponent`: dueño único de la vida |
| Componentes | `ObjectPool`: genérico, guarda instancias fuera del árbol |
| Entidades | `Zombie`: lee el cerebro, mueve con `NavigationAgent3D`, anima y golpea |
| Entidades | `ZombieSpawner`: dentro de la zona, coloca y devuelve zombies |
| Entidades | `Robot`: recibe golpes |

**Máquina de estados (R-006-11 a 15).**
- `EnemyBrain.tick(delta, target_distance, patrol_arrived) -> bool` avanza un paso y devuelve `true` si en ese paso
  cae un golpe.
- `target_distance` es la distancia horizontal (XZ) al jugador vivo más cercano, o `INF` si no hay ninguno. Así un
  jugador con la batería a 0 es lo mismo que ningún jugador (R-006-18), sin otra regla.
- Las transiciones son las siguientes. Los radios vienen de `EnemyAiData` y el intervalo de `EnemyData`.

  | Desde | Condición | Pasa a |
  |---|---|---|
  | `IDLE` | Termina la pausa (2-4 s del RNG) | `PATROL`, con un punto nuevo en el radio de patrulla alrededor de casa |
  | `PATROL` | Llega al punto (`patrol_arrived`) | `IDLE`, con una pausa nueva |
  | `IDLE` o `PATROL` | `distancia ≤ visión` | `CHASE` |
  | `CHASE` | `distancia ≤ ataque` | `ATTACK`, con el temporizador de ataque a 0 |
  | `CHASE` o `ATTACK` | `distancia > abandono` (incluye `INF`) | `PATROL`, con un punto nuevo. Se evalúa **antes** que la fila siguiente, así que gana |
  | `ATTACK` | `distancia > ataque` | `CHASE`, con el temporizador a 0: salir del rango reinicia la espera (pregunta 4) |

- En `ATTACK` el temporizador suma `delta`. Al llegar al intervalo cae un golpe y se resta el intervalo, para que
  el ritmo no dependa de los FPS. El primer golpe llega tras un intervalo completo.
- El cerebro recibe su `RandomNumberGenerator` al crearse, y de él salen las pausas y los puntos de patrulla. Los
  tests le pasan uno con semilla fija (P13).
- `home` y los puntos de patrulla están en **coordenadas globales**, porque `NavigationAgent3D` trabaja en
  global. El spawner pasa la posición global del marcador. Nada de esto se guarda: lo que se guardará (spec 010) es
  la visita, y los zombies se regeneran desde la semilla, así que P9 (posiciones guardadas como local a la zona) no
  se ve afectado.
- `EnemyBrain` sirve también para el robot hostil (spec 015), porque no sabe nada de zombies.

**Golpe al robot (R-006-16 a 18).**
- El robot está en el grupo `Robot.PLAYER_GROUP`. El zombie busca allí al jugador vivo más cercano en cada paso de
  física. Con un solo jugador es una lista de uno, y en el cooperativo sirve tal cual.
- Cuando el cerebro dice que hay golpe, el zombie llama a `target.receive_hit(data.hit_damage, self)`.
- `Robot.receive_hit` no hace nada si la batería está a 0. Si no, llama a `battery.consume(damage)` y emite
  `hit_received(damage, attacker)`.
- La degradación (spec 014) conectará `DegradationComponent` a `hit_received` sin tocar la IA (R-006-17).
- El zombie llama directamente al robot porque es una relación atacante-objetivo, como `interact()` en §9.1. No va
  por el `EventBus`.

**Movimiento (R-006-13, 20).**
- Navmesh horneado en el editor (pregunta 3): un `NavigationRegion3D` en `farm_zone_green.tscn`. Su
  `NavigationMesh` toma la geometría de un grupo (`Ground`, `Decoration`, `Boundaries` y sus hijos), así que no hay
  que mover nodos ni romper `%` existentes **(verificar)**.
- El suelo es un `GridMap` cuyas teselas **no tienen colisión** (`green_zone_tiles.tres`, `shapes = []`), y los
  muros de los límites solo tienen colisión, sin malla. Por eso el tipo de geometría es `PARSED_GEOMETRY_BOTH`:
  las mallas del `GridMap` dan el suelo transitable y los colisionadores dan los obstáculos y los muros.
- Si el horneado no lee las mallas del `GridMap` (verificar 1), se añade a la zona un `StaticBody3D` plano de
  `size_m` solo para el horneado, en el grupo y con `collision_layer = 0` para que no toque la física del robot.
  Es un cambio de escena de la 004, así que `test_green_zone.gd` tiene que seguir en verde.
- En `CHASE` el destino del agente es el robot.
- En `PATROL` el `Zombie` proyecta `get_patrol_point()` sobre el navmesh con
  `NavigationServer3D.map_get_closest_point()` antes de usarlo. Un punto dentro de un árbol, una caja o más allá de
  la valla pasa a ser el punto alcanzable más cercano. `patrol_arrived` es `is_navigation_finished()`, que también
  se cumple cuando el agente llega al final de un camino parcial. Así el zombie nunca se queda en `PATROL` para
  siempre (R-006-12).
- La velocidad sale de `next_path_position` y `EnemyData.move_speed`. El movimiento es solo horizontal, con
  `move_and_slide`, como el robot. `avoidance` queda desactivada (pregunta 8).
- La zona tiene paredes de colisión y el navmesh no sale de ellas, así que un zombie no puede abandonar el área
  jugable.

**Pool y ciclo de vida (R-006-21, 22, 27).**
- `ObjectPool` es un `Node` con `@export var scene`.
  - `acquire()` devuelve una instancia libre o crea otra. La instancia sale fuera del árbol, y quien la pide la
    añade donde quiera.
  - `release(instance)` la saca de su padre y la guarda.
  - Al liberarse el pool, libera las instancias que guarda.
- El pool de zombies, `%ZombiePool`, vive en `main.tscn` bajo `World`, no en la zona. Así sobrevive a la descarga
  de la zona y se reutiliza entre visitas cuando exista `ZoneLoader` (spec 009).
- Al reutilizar una instancia, `Zombie.activate(data, home, brain_seed)` lo reinicia todo:
  - los datos: guarda el `EnemyData` nuevo, porque una instancia que fue zombie lento puede volver como rápido;
  - la vida, con `HealthComponent.reset(data.hp_max)`;
  - el cerebro: crea un `EnemyBrain` **nuevo** con `data.ai`, `data.attack_interval` y un
    `RandomNumberGenerator` con `seed = brain_seed`, y llama a `reset(home)`, que lo deja en `IDLE` y sin objetivo;
  - la posición y la velocidad.
- `main.gd` llama a `ZombiePool.prewarm()` con el `enemy_count_max` de la zona, al arrancar y fuera de la
  partida, para que no se instancien zombies a mitad de juego.
- Al morir (`died`), el zombie desactiva su `_physics_process` y emite `defeated(self)`. El `ZombieSpawner` lo
  devuelve al pool con `call_deferred`, porque `died` llega en mitad de un paso de física.
- `FarmZone.despawn_enemies()` devuelve todos los zombies al pool. `ZoneLoader` (spec 009) la llamará antes de
  liberar la zona. En la 006 solo la llaman los tests: hasta la 009 la zona no se descarga.

**Spawner (R-006-23 a 26).**
- La zona sigue generando las cajas en `generate(world_seed)`. Los enemigos van aparte, en
  `FarmZone.spawn_enemies(world_seed, visit, pool)`, porque dependen de la visita y las cajas no (BALANCE §7.2).
  `generate` y sus tests no cambian.
- `ZombieSpawner` usa dos RNG de `SeededRng`, los dos con `index = visit`:
  - `STREAM_ENEMY_SPAWN`: número, tipo y marcador de cada zombie.
  - `STREAM_ENEMY_BRAIN`: una semilla por zombie, en orden de colocación.

  Con streams separados, cambiar la IA no mueve dónde aparecen los zombies.
- `ZonePopulation.pick_enemy_spawns(marker_count, min, max, entries, rng)` hace el reparto:
  1. Saca el número con `randi_range(min, max)`.
  2. Elige marcadores distintos con el mismo Fisher-Yates parcial que las cajas. La lógica se extrae a un helper
     privado que usan las dos funciones; `pick_box_markers` mantiene su firma y su resultado.
  3. Pone primero el `min_count` de cada entrada, que da "al menos uno de cada".
  4. Reparte el resto por peso.
  5. Baraja los tipos sobre los marcadores con el mismo RNG.
- **Antes** de extraer el helper, un test de respuesta conocida fija qué marcadores da `pick_box_markers` con una
  semilla concreta, y otro fija las cajas de `FarmZone.generate` con la semilla de `dev_world.tres` (20261115).
  Así, si el helper consume el RNG en otro orden, falla un test en lugar de cambiar en silencio las cajas de los
  mundos (BALANCE §7.2: número y posición de las cajas solo dependen de semilla + `zone_id`).
- Los marcadores de enemigos están a más de `vision_radius + patrol_radius` (13 m, BALANCE §3.1) del
  `SpawnPoint`. Así ningún zombie ve al robot al arrancar, ni en el juego ni en `test_main_scene.gd`. Un test lo
  comprueba leyendo `zombie_ai.tres`.
- `main.gd` llama a `spawn_enemies(world_seed, ZombieSpawner.FIRST_VISIT, %ZombiePool)` justo después de
  `generate`. `FIRST_VISIT = 0` es el valor que la spec 010 sustituirá por el contador (R-006-26).

**UI abierta (R-006-19).** No hace falta nada. `UIManager` no pausa el árbol y los zombies no escuchan
`modal_state_changed`. Un test de integración lo fija.

**Catálogo (R-006-04).** `DataCatalog` añade `enemies: Array[EnemyData]` con su índice, `has_enemy` y
`get_enemy`. `DataRegistry` añade `get_enemy`. El índice de enemigos repite la forma del de items, pero `ItemData`
y `EnemyData` no comparten clase base. La abstracción se hará cuando llegue el tercer tipo (`recipes`, Tarea 2.4),
según P2.

**Alternativas descartadas.**
- **Estados como nodos hijos (un nodo por estado).** Haría falta árbol de escena para testear las transiciones,
  contra P3 y R-006-11.
- **Pool dentro de la zona.** Se liberaría con ella y no reutilizaría nada entre visitas.
- **Golpe por `EventBus`.** Es un hecho entre dos entidades, no global (architecture §7). Además, el bus todavía no
  existe y crearlo no entra en esta spec.
- **Cambiar la firma de `generate(world_seed)` para añadir la visita.** Rompería los tests de la 004 y mezclaría
  cajas, que no dependen de la visita, con enemigos, que sí.

## 2. Archivos

| Archivo (`game/…`) | Nuevo / Cambia | Responsabilidad |
|---|---|---|
| `scripts/data/enemy_data.gd` | Nuevo | `EnemyData` con el enum `Faction` |
| `scripts/data/enemy_ai_data.gd` | Nuevo | Radios y pausas de IA (BALANCE §3.1 "IA de zombies") |
| `scripts/data/enemy_spawn_entry_data.gd` | Nuevo | Tipo, peso y mínimo de cada entrada de aparición de una zona |
| `scripts/data/zone_data.gd` | Cambia | `enemy_count_min`, `enemy_count_max` y `enemy_spawns` |
| `scripts/data/data_catalog.gd` | Cambia | `enemies`, índice, `has_enemy` y `get_enemy` |
| `scripts/autoload/data_registry.gd` | Cambia | `get_enemy` |
| `scripts/components/health_component.gd` | Nuevo | Vida de una entidad (R-006-05 a 09) |
| `scripts/components/object_pool.gd` | Nuevo | Pool genérico de instancias de una escena |
| `scripts/systems/enemy_brain.gd` | Nuevo | Máquina de estados pura |
| `scripts/systems/zone_population.gd` | Cambia | `pick_enemy_spawns` y un helper privado compartido para elegir marcadores |
| `scripts/util/seeded_rng.gd` | Cambia | `STREAM_ENEMY_SPAWN` y `STREAM_ENEMY_BRAIN`. La derivación no cambia |
| `scenes/entities/zombie.tscn` + `zombie.gd` | Nuevo | `CharacterBody3D`, modelo, `AnimationPlayer`, `%Health`, `%NavAgent` |
| `scenes/farm_zone/zombie_spawner.gd` | Nuevo | Coloca zombies del pool en los marcadores y los devuelve |
| `scenes/farm_zone/farm_zone.gd` | Cambia | `spawn_enemies`, `despawn_enemies` y `get_enemies` |
| `scenes/farm_zone/farm_zone_green.tscn` | Cambia | `NavigationRegion3D` horneado, `%EnemyMarkers` (10 marcadores), `%ZombieSpawner` y `%Enemies` |
| `scenes/entities/robot.gd` + `robot.tscn` | Cambia | `PLAYER_GROUP`, `receive_hit` y `hit_received` |
| `scenes/main.gd` + `main.tscn` | Cambia | `World/ZombiePool` y la llamada a `spawn_enemies` |
| `resources/enemies/zombie_slow.tres`, `zombie_fast.tres` | Nuevo | BALANCE §3.1 |
| `resources/ai/zombie_ai.tres` | Nuevo | BALANCE §3.1 "IA de zombies", compartido por los dos tipos |
| `resources/zones/green_zone.tres` | Cambia | 5-8 zombies, lento y rápido al 50 % con mínimo 1 (BALANCE §7.1) |
| `resources/data_catalog.tres` | Cambia | Los dos enemigos |
| `i18n/strings.csv` | Cambia | `ENEMY_ZOMBIE_SLOW` y `ENEMY_ZOMBIE_FAST` (ES + EN) |
| `assets/models/zombie/…` | Nuevo | Modelo CC0 y su licencia, o nada si se queda el placeholder (pregunta 6) |
| `tests/unit/test_health_component.gd` | Nuevo | R-006-05 a 09 |
| `tests/unit/test_enemy_resources.gd` | Nuevo | R-006-01 a 03 |
| `tests/unit/test_data_catalog.gd` | Cambia | R-006-04 |
| `tests/unit/test_enemy_brain.gd` | Nuevo | R-006-11, 12, 14, 15 y 18 (lógica) |
| `tests/unit/test_object_pool.gd` | Nuevo | R-006-22 (pool) |
| `tests/unit/test_zone_population.gd` | Cambia | R-006-23 y 25 (lógica). Los tests de cajas no cambian |
| `tests/integration/test_robot_hit.gd` | Nuevo | R-006-16 a 18 (robot) |
| `tests/integration/test_zombie.gd` | Nuevo | R-006-10, 13, 15, 16, 18, 21 y 22 con escena |
| `tests/integration/test_zombie_spawner.gd` | Nuevo | R-006-20, 23, 25, 26 y 27 con la zona verde |
| `tests/integration/test_main_scene.gd` | Cambia | R-006-19 y zombies presentes al arrancar |

## 3. Contratos

```gdscript
class_name EnemyData
extends Resource
enum Faction { INFECTED, MACHINE, HUMAN }
@export var id: StringName                  # snake_case, stable forever
@export var name_key: StringName            # ENEMY_ZOMBIE_SLOW…
@export var faction: Faction
@export var hp_max: int
@export var hit_damage: float               # battery points per hit, 1:1 (BALANCE §3.1)
@export var move_speed: float               # m/s
@export var attack_interval: float          # s
@export var ai: EnemyAiData

class_name EnemyAiData
extends Resource
@export var vision_radius: float
@export var attack_range: float
@export var patrol_radius: float
@export var patrol_pause_min: float
@export var patrol_pause_max: float
@export var give_up_distance: float

class_name EnemySpawnEntryData
extends Resource
@export var enemy: EnemyData
@export var weight: int                     # relative share among the rest
@export var min_count: int                  # guaranteed before weights

# ZoneData (added)
@export var enemy_count_min: int = 0
@export var enemy_count_max: int = 0
@export var enemy_spawns: Array[EnemySpawnEntryData] = []

class_name HealthComponent
extends Node
# Before the first reset(): maximum 0, inactive. is_dead() is false, and
# take_damage/heal push_error and change nothing: the owner must reset() first.
signal health_changed(current: int, maximum: int)
signal died                                 # once per life
func reset(maximum: int) -> void            # maximum <= 0 → push_error; full HP, alive again; emits health_changed
func take_damage(amount: int) -> void       # < 0 → push_error, no change; dead → no change
func heal(amount: int) -> void              # < 0 → push_error; dead → no change; capped at max
func get_current() -> int
func get_maximum() -> int
func is_dead() -> bool

class_name ObjectPool
extends Node
@export var scene: PackedScene
func acquire() -> Node                      # outside the tree; caller adds it
func release(instance: Node) -> void        # not from this pool or already free → push_error
func prewarm(count: int) -> void
func get_free_count() -> int

class_name EnemyBrain
extends RefCounted
enum State { IDLE, PATROL, CHASE, ATTACK }
func _init(ai: EnemyAiData, attack_interval: float, rng: RandomNumberGenerator) -> void
func reset(home: Vector3) -> void           # IDLE, new pause, timers at 0
func tick(delta: float, target_distance: float, patrol_arrived: bool) -> bool  # true = a hit lands
func get_state() -> State
func get_patrol_point() -> Vector3

# ZonePopulation (added)
class EnemySpawn: var marker_index: int; var enemy: EnemyData
static func pick_enemy_spawns(
	marker_count: int, min_count: int, max_count: int,
	entries: Array[EnemySpawnEntryData], rng: RandomNumberGenerator
) -> Array[EnemySpawn]                      # sorted by marker_index; invalid data → push_error, []

class_name Zombie
extends CharacterBody3D
signal defeated(zombie: Zombie)
func activate(data: EnemyData, home: Vector3, brain_seed: int) -> void
func get_data() -> EnemyData
func get_state() -> EnemyBrain.State
func get_health() -> HealthComponent

class_name ZombieSpawner
extends Node3D
const FIRST_VISIT := 0                      # until spec 010 adds the visit counter
func spawn(zone: ZoneData, markers: Array[Node], world_seed: int, visit: int, pool: ObjectPool) -> void
func despawn_all() -> void
func get_active() -> Array[Zombie]

# FarmZone (added)
func spawn_enemies(world_seed: int, visit: int, pool: ObjectPool) -> void
func despawn_enemies() -> void
func get_enemies() -> Array[Zombie]

# Robot (added)
const PLAYER_GROUP := &"players"
signal hit_received(damage: float, attacker: Node3D)
func receive_hit(damage: float, attacker: Node3D) -> void   # depleted → nothing
```

Streams nuevos de `SeededRng`: `STREAM_ENEMY_SPAWN := &"enemy_spawn"` y `STREAM_ENEMY_BRAIN := &"enemy_brain"`.
La derivación no cambia. Los tests de valores conocidos de `test_seeded_rng.gd` siguen igual.

No se añade ningún evento al `EventBus`. `enemy_killed` llega con el combate (spec 007).

## 4. Datos

| Recurso / `.tres` | Campos | Valores desde |
|---|---|---|
| `enemies/zombie_slow.tres` | `id = zombie_slow`, `name_key = ENEMY_ZOMBIE_SLOW`, `INFECTED`, `hp_max = 20`, `hit_damage = 5`, `move_speed = 1.5`, `attack_interval = 1.5`, `ai = zombie_ai` | BALANCE §3.1 |
| `enemies/zombie_fast.tres` | `id = zombie_fast`, `name_key = ENEMY_ZOMBIE_FAST`, `INFECTED`, `hp_max = 15`, `hit_damage = 4`, `move_speed = 3.5`, `attack_interval = 1.5`, `ai = zombie_ai` | BALANCE §3.1 |
| `ai/zombie_ai.tres` | `vision_radius = 8`, `attack_range = 1.5`, `patrol_radius = 5`, `patrol_pause_min = 2`, `patrol_pause_max = 4`, `give_up_distance = 12` | BALANCE §3.1 "IA de zombies" |
| `zones/green_zone.tres` | `enemy_count_min = 5`, `enemy_count_max = 8`, entradas `zombie_slow` y `zombie_fast` con `weight = 1` y `min_count = 1`: primero uno de cada tipo y el resto al 50 % | BALANCE §7.1 |
| `farm_zone_green.tscn` | 10 marcadores en `%EnemyMarkers`, más que el máximo de 8 | Spec, pregunta 7 |

La XP (BALANCE §3.1) y los drops no se añaden hasta la spec 007, que es quien los usa. El radio del agente de
navegación y los parámetros del horneado son técnicos, no de gameplay. Viven en la escena y en el
`NavigationMesh`, ajustados a la cápsula del zombie.

## 5. Verificación

| Requisito | Test (`game/tests/…`) o paso manual |
|---|---|
| R-006-01 | `unit/test_enemy_resources.gd::test_r_006_01_enemy_data_fields` (id `snake_case`, clave traducida ES + EN, facción del enum) |
| R-006-02 | `unit/test_enemy_resources.gd::test_r_006_02_zombies_match_balance` |
| R-006-03 | `unit/test_enemy_resources.gd::test_r_006_03_ai_matches_balance` y `test_r_006_03_no_ai_literals_in_scripts` (busca los nombres de los campos de IA asignados a números en `zombie.gd` y `enemy_brain.gd`) |
| R-006-04 | `unit/test_data_catalog.gd::test_r_006_04_get_enemy_by_id`, `test_r_006_04_registry_returns_enemies`, `test_r_006_04_repeated_or_empty_enemy_ids_reported`, `test_r_006_04_every_enemy_file_in_catalog` |
| R-006-05 | `unit/test_health_component.gd::test_r_006_05_starts_full`, `test_r_006_05_emits_health_changed` |
| R-006-06 | `unit/test_health_component.gd::test_r_006_06_take_damage_lowers`, `test_r_006_06_clamps_at_zero` |
| R-006-07 | `unit/test_health_component.gd::test_r_006_07_died_once`, `test_r_006_07_dead_ignores_damage_and_heal`, `test_r_006_07_reset_revives` |
| R-006-08 | `unit/test_health_component.gd::test_r_006_08_heal_capped_at_max` |
| R-006-09 | `unit/test_health_component.gd::test_r_006_09_negative_amount_reports_error` |
| R-006-10 | `integration/test_zombie.gd::test_r_006_10_scene_structure` (cuerpo, colisión, `%Health`, `%NavAgent`, `AnimationPlayer` con `idle`, `walk` y `attack`) y `test_r_006_10_activate_reads_enemy_data` |
| R-006-11 | `unit/test_enemy_brain.gd::test_r_006_11_*` (tabla de transiciones de §1, sin árbol de escena, incluido `test_r_006_11_give_up_wins_over_chase` desde `ATTACK`) |
| R-006-12 | `unit/test_enemy_brain.gd::test_r_006_12_idle_patrol_cycle`, `test_r_006_12_patrol_point_within_radius` e `integration/test_zombie_spawner.gd::test_r_006_12_unreachable_patrol_point_still_cycles` (punto dentro de un obstáculo: vuelve a `IDLE`) |
| R-006-13 | `unit/test_enemy_brain.gd::test_r_006_13_chase_on_vision` e `integration/test_zombie.gd::test_r_006_13_moves_toward_player_at_data_speed` (con navmesh; **(verificar)** la sincronización del mapa en headless). Paso manual en PC: el zombie rodea un árbol para llegar al robot |
| R-006-14 | `unit/test_enemy_brain.gd::test_r_006_14_gives_up_beyond_distance` |
| R-006-15 | `unit/test_enemy_brain.gd::test_r_006_15_hits_once_per_interval`, `test_r_006_15_first_hit_after_full_interval`, `test_r_006_15_leaving_range_restarts_wait`, `test_r_006_15_rate_independent_of_step` e `integration/test_zombie.gd::test_r_006_15_stops_and_faces_player` |
| R-006-16 | `integration/test_robot_hit.gd::test_r_006_16_hit_consumes_battery` e `integration/test_zombie.gd::test_r_006_16_hit_drains_robot_battery` |
| R-006-17 | `integration/test_robot_hit.gd::test_r_006_17_hit_received_signal` (daño y atacante) |
| R-006-18 | `unit/test_enemy_brain.gd::test_r_006_18_no_target_means_no_hit`, `integration/test_robot_hit.gd::test_r_006_18_depleted_ignores_hit` e `integration/test_zombie.gd::test_r_006_18_ignores_depleted_robot` |
| R-006-19 | `integration/test_main_scene.gd::test_r_006_19_zombies_act_with_screen_open` (inventario abierto, el zombie se mueve) |
| R-006-20 | `integration/test_zombie_spawner.gd::test_r_006_20_navmesh_covers_zone` (puntos de patrulla proyectados dentro de `size_m`) y paso manual en PC: perseguir al robot contra la valla, el zombie no sale ni atraviesa obstáculos |
| R-006-21 | `integration/test_zombie.gd::test_r_006_21_death_returns_to_pool` |
| R-006-22 | `unit/test_object_pool.gd::test_r_006_22_*` (reutiliza, crea si está vacío, error al liberar algo ajeno o dos veces, libera al salir) e `integration/test_zombie.gd::test_r_006_22_reused_zombie_is_reset` (reutiliza la instancia con el otro `EnemyData` y comprueba vida, velocidad e intervalo nuevos, `IDLE` y sin objetivo) |
| R-006-23 | `unit/test_zone_population.gd::test_r_006_23_count_in_range`, `test_r_006_23_at_least_one_of_each`, `test_r_006_23_distinct_markers`, `test_r_006_23_invalid_data_reports_error` e `integration/test_zombie_spawner.gd::test_r_006_23_green_zone_spawns_in_range` y `test_r_006_23_markers_out_of_sight_of_spawn` (distancia > visión + patrulla de `zombie_ai.tres`). Antes del refactor: `unit/test_zone_population.gd::test_r_004_21_known_answer` e `integration/test_green_zone.gd::test_r_004_21_dev_seed_known_boxes` |
| R-006-24 | `unit/test_no_global_rng.gd::test_r_004_10_no_global_rng_in_game_code` ya cubre todo `scripts/` y `scenes/`. Se añade `test_r_006_24_spawn_scripts_scanned`, que comprueba que `zombie_spawner.gd`, `zone_population.gd` y `enemy_brain.gd` están entre los revisados |
| R-006-25 | `unit/test_zone_population.gd::test_r_006_25_same_seed_same_spawns` e `integration/test_zombie_spawner.gd::test_r_006_25_same_seed_and_visit_same_zombies` (dos zonas, mismos tipos y posiciones) |
| R-006-26 | `integration/test_zombie_spawner.gd::test_r_006_26_visit_changes_spawns` (visita 0 contra 1 sobre varias semillas: al menos una difiere) y `integration/test_main_scene.gd::test_r_006_26_main_passes_first_visit` |
| R-006-27 | `integration/test_zombie_spawner.gd::test_r_006_27_despawn_returns_all_to_pool` |
| R-006-28 | Manual en el Android de gama media (APK debug): 8 zombies persiguiendo al robot durante 60 s, FPS del `DebugHud` ≥ 30 en todo momento. Anotar en `tasks.md` el dispositivo, el FPS mínimo y los triángulos en pantalla (monitor del editor remoto o `Performance`, **(verificar)**). La semilla que dé 8 se busca con un test o script local, se pone en `dev_world.tres` **solo en local, sin commit** (cambiaría las cajas de todos), y se anota en `tasks.md`. Presupuesto del modelo: ≤ 2 000 triángulos por zombie, para que 8 quepan con holgura en los 50K-100K de PMV §3.2 |

**(verificar)** antes de usar, en la documentación oficial de Godot 4.7.2 y en el binario headless:

1. `NavigationMesh`: `geometry_source_geometry_mode` con grupos (`SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN`),
   `geometry_source_group_name` y `geometry_parsed_geometry_type = PARSED_GEOMETRY_BOTH`. Comprobar si el horneado
   lee las mallas de un `GridMap` cuyas teselas no tienen colisión (si no, el suelo plano de §1).
2. Horneado en el editor de un `NavigationRegion3D`, y si el `NavigationMesh` horneado se guarda dentro de la
   escena o como `.tres`.
3. `NavigationAgent3D`: `target_position`, `get_next_path_position()`, `is_navigation_finished()`,
   `avoidance_enabled` y `path_desired_distance`/`target_desired_distance`. Comprobar el coste de cambiar
   `target_position` en cada paso de física.
4. Sincronización del mapa de navegación en headless: cuántos fotogramas de física hacen falta tras añadir la zona
   para que `get_next_path_position()` devuelva un camino (`NavigationServer3D.map_changed` o
   `map_get_iteration_id`).
5. `NavigationServer3D.map_get_closest_point()` para proyectar los puntos de patrulla y para el test de R-006-20.
6. Orden de `remove_child` durante una señal de física: si sacar un `CharacterBody3D` del árbol con `call_deferred`
   es seguro y si `NOTIFICATION_PREDELETE` en el pool basta para liberar instancias huérfanas sin fugas (los tests
   GUT avisan de huérfanos).
7. `AnimationPlayer` con animaciones hechas a mano sobre primitivas (placeholder), y la importación de un `.glb`
   CC0 con sus animaciones, si se usa.
8. Cómo leer los triángulos en pantalla en un APK debug: monitor `Performance` de render o depurador remoto del
   editor.

## 6. Check de constitución

| Principio | Cumple | Nota |
|---|---|---|
| P1 Spec primero | ✅ | Spec 006 *Aprobado*; el plan pasa a *Planificado* solo con el usuario |
| P2 Una fuente de verdad | ✅ | Todo número de gameplay está en `.tres` con su fuente en BALANCE. La lógica de elegir marcadores se comparte con las cajas en lugar de copiarse. El índice del catálogo se repite dos veces (items y enemigos) y se abstrae a la tercera |
| P3 Lógica separada | ✅ | `EnemyBrain` y `ZonePopulation` son puros. `HealthComponent` y `ObjectPool` se testean sin escena. `Zombie` solo cablea |
| P4 Estado por jugador | ✅ | La batería sigue en `BatteryComponent` y el golpe pasa por `Robot.receive_hit`. Ningún autoload guarda estado. El objetivo se busca por grupo, sin asumir un solo jugador |
| P5 Datos como recursos | ✅ | `EnemyData` (con facción), `EnemyAiData` y `EnemySpawnEntryData` en `resources/` |
| P6 Señales | ✅ | `health_changed`, `died`, `defeated` y `hit_received` tipadas y en pasado. Referencias por `%` y `@export`. La llamada zombie → robot es atacante-objetivo, no entre sistemas sin relación |
| P7 Tipado | ✅ | Todo tipado. El objetivo del grupo se convierte con `as Robot` y se comprueba si es `null` |
| P8 Plataforma | ✅ | La IA no lee input ni plataforma |
| P9 Determinismo | ✅ | Spawn y cerebros con `SeededRng` en streams propios e `index = visit`. Nada del RNG global (test existente) |
| P11 i18n | ✅ | `ENEMY_ZOMBIE_SLOW` y `ENEMY_ZOMBIE_FAST` en ES + EN. No hay texto visible nuevo en pantalla |
| P12 Presupuesto móvil | ✅ | Pool desde la primera versión, modelo low-poly, sin luces nuevas, `avoidance` desactivada. FPS medido en Android (R-006-28) |
| P13 Test primero | ✅ | Cerebro, salud, pool y reparto con su test antes del código. Cerebro y reparto con RNG de semilla fija |
| P10 Servicios | ✅ | No toca guardado, tiempo, tienda ni online. Ninguna dependencia nueva |
| P14 Alcance | ✅ | Sin combate, XP, drops, degradación ni contador de visitas. El helper de marcadores es la única refactorización, necesaria para no duplicar lógica, y no cambia el contrato de `pick_box_markers` |

## 7. Riesgos y alternativas descartadas

- **Navegación en tests headless** → si el mapa no se sincroniza de forma fiable (verificar 4), los tests de
  movimiento con navmesh pasan a comprobar solo el estado y la dirección hacia el siguiente punto del camino, y el
  rodeo de obstáculos queda como paso manual. No se debilita ningún test ya escrito: se decide antes de escribirlo.
- **Coste de rehacer el camino en cada paso con 8 zombies** → medirlo en el Android (R-006-28). Si hace falta,
  `target_position` solo se actualiza cuando el robot se ha movido más que `target_desired_distance` del agente,
  que es un valor técnico de la escena.
- **Zombies amontonados sobre el robot** → la colisión física los separa. Si en el móvil se ve mal, se activa la
  `avoidance` (pregunta 8), en un cambio aparte.
- **Game over provisional** → con la batería a 0, `main.gd` congela `World` y los zombies se paran con él. R-006-18
  se prueba sin `Main`, con un robot agotado delante de un zombie activo.
- **Modelo CC0 sin animaciones adecuadas** → se queda el placeholder de primitivas con `AnimationPlayer`
  (pregunta 6). El cambio de modelo no toca la lógica.
- **Sin `ActionResult` (architecture §3 regla 4)** → `take_damage`, `heal`, `reset` y `receive_hit` devuelven
  `void`, como `BatteryComponent.consume`. No son acciones que el jugador pida y que puedan fallar con un mensaje
  (§9.2); una entrada inválida es un error de programación y va por `push_error`.
- **Cajas que no están en el navmesh** → aparecen en tiempo de ejecución, así que un zombie puede engancharse con
  una al perseguir. Si se ve en T-006-13, se añade un `NavigationObstacle3D` a la caja en un cambio aparte.
- **`get_nodes_in_group` en cada paso** → crea un array por zombie y fotograma. Es poco coste, pero si aparece en el
  perfil de Android, el spawner pasa la lista de jugadores.
- **Descartado: un `Timer` por zombie para el ataque.** Sacaría el intervalo de la lógica pura y no se podría
  testear sin árbol.
