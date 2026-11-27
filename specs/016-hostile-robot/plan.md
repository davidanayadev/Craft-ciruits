# Plan 016 — Robot hostil y sus drops

| Campo | Valor |
|---|---|
| **Spec** | [spec.md](spec.md) (debe estar *Aprobado*) |
| **Estado** | Planificado (2026-11-26) |

## 1. Enfoque

El robot hostil es **otra escena y otros datos sobre el mismo código** que los zombies. `zombie.gd` ya no tiene nada de
zombie: lee todo de su `EnemyData`, usa `EnemyBrain`, el pool, el hurtbox, el destello y el drop sembrado. Por eso la
escena nueva `hostile_robot.tscn` usa **el mismo script**, que pasa a llamarse `Enemy` (`enemy.gd`), con su propio
modelo de primitivas y sus animaciones `idle`, `walk` y `attack`. Lo mismo con el spawner: `ZombieSpawner` pasa a
`EnemySpawner` y la zona verde tiene **dos** nodos de él, uno para los zombies y otro para los robots, cada uno con sus
marcadores, su rango de BALANCE §7.1, sus flujos de semilla y su lista de muertos de la visita. Los zombies no cambian:
mismos marcadores, mismos flujos (`enemy_spawn`, `enemy_brain`, `enemy_drop`), mismos índices y misma clave de
guardado (`dead_enemies`); el robot usa flujos nuevos (`hostile_robot_*`) y una clave nueva y opcional
(`dead_hostile_robots`), así que un Mundo guardado antes carga sin migración (R-016-22, R-016-26).

El drop es **datos más una tirada pura**: los materiales son un `LootTableData` como el de los zombies y la pieza un
recurso nuevo, `PieceDropData` (probabilidad, piezas posibles y durabilidad con que salen). `LootSystem.roll_enemy_drop`
tira primero la tabla y después la pieza con el **mismo RNG**, sembrado por robot y visita como el drop de un zombie
(spec 008). La pieza se crea con `CraftingSystem.create_result` (uid nuevo) y se le baja la durabilidad, así que nunca
es un `ItemStack.new(item, n)` (condición de entrada, plan 011 §7). Todo cae en **un solo** objeto caído por el camino
que ya usan los zombies (`loot_dropped` → `FarmZone.enemy_loot_dropped` → `DroppedItemSpawner.drop_stacks`), que se
abre en la pantalla de contenedor (spec 015). Matarlo emite `EventBus.enemy_killed` y da su XP sin código nuevo.

**Alternativa principal descartada**: una clase `HostileRobot` (y un `HostileRobotSpawner`) que copie o herede de
`Zombie`. Copiar duplica ~200 líneas de lógica (P2); heredar deja dos subclases vacías y un `Zombie` que sería la base
de un robot. El nombre `Zombie` en una escena de robot confundiría a quien mantenga el código; el renombrado (D1) es
mecánico y se hace en un commit propio sin cambio de comportamiento. Si la revisión no lo aprueba, el plan B es
`hostile_robot.tscn` con `zombie.gd` tal cual y una línea en su docstring (ver §7).

### 1.1 Decisiones del plan

| # | Decisión | Por qué |
|---|---|---|
| D1 | **Renombrado (aprobado por el usuario el 2026-11-26, P14, pregunta 12 de la spec).** Clase `Zombie` → `Enemy` (`scenes/entities/zombie.gd` → `enemy.gd`, con su `.uid`); `ZombieSpawner` → `EnemySpawner` (`scenes/farm_zone/zombie_spawner.gd` → `enemy_spawner.gd`, con su `.uid`); señal `defeated(zombie: Zombie)` → `defeated(enemy: Enemy)`; `FarmZone.spawn_enemies` → `spawn_zombies` y `FarmZone.get_enemies` → `get_zombies` (pasan a nombrar lo que hacen cuando hay dos poblaciones). Tests: `test_zombie.gd` → `test_enemy.gd`, `test_zombie_spawner.gd` → `test_enemy_spawner.gd`, y las referencias en los demás. **No** cambian: `zombie.tscn`, el nodo `%ZombieSpawner` de la zona, `ZombiePool`, `zone_loader.zombie_pool`, los ids, las claves de guardado ni ningún nombre de test `test_r_*`. Un commit `refactor(enemies)` con `git mv`, sin cambio de comportamiento, con la suite en verde antes de tocar nada más. Descartado en la revisión (2026-11-26): subclases vacías `Zombie` y `HostileRobot` de `Enemy` "por si acaso"; los ajustes de cada tipo ya viven en sus `.tres` y su escena, y la subclase se crea con la primera diferencia de comportamiento real (por ejemplo, los robots de v1.1). | Pregunta 12. Un script que sirve a dos escenas no puede llamarse como una de ellas. Hecho aparte, el diff de la feature no mezcla renombres con lógica. |
| D2 | **Una escena por tipo, un script.** `hostile_robot.tscn` repite el árbol de `zombie.tscn` (`CollisionShape3D`, `Model`, `%Health`, `%NavAgent`, `%AnimationPlayer`, `%Hurtbox`, `%HitFlash`) con otro modelo y otras animaciones, y `script = enemy.gd`. Su `EnemyData` llega en `activate()`, como hoy. Pool propio (`World/HostileRobotPool`): un `ObjectPool` crea instancias de una sola escena. | R-016-06, R-016-10, R-016-11, R-016-23. Reutiliza `activate`, el reinicio del pool (R-007-23), el objetivo por grupo y la regla de batería agotada (R-016-09) sin una línea nueva. |
| D3 | **Modelo placeholder** (pregunta 11): cuerpo `BoxMesh` ancho y bajo, cabeza `BoxMesh` con un visor emisivo rojo, dos brazos `BoxMesh` y dos "orugas" `BoxMesh` a los lados, gris metálico oscuro; ningún `CapsuleMesh`/`SphereMesh` como el zombie ni los colores del jugador. Colisionador `CapsuleShape3D` de radio 0.45 m y alto 1.7 m (cabe en la navmesh horneada para un agente de 0.5 m y 2 m). Animaciones: `idle` (balanceo del cuerpo), `walk` (bamboleo y brazos), `attack` (golpe de los dos brazos al frente), `loop_mode` 1 como las del zombie. Las mallas visibles van en `HitFlash.meshes`. Mismo presupuesto de triángulos que el zombie: el test lo lee de `preload("res://tests/integration/test_enemy.gd").MAX_TRIANGLES`, sin copiar el número. | R-016-10, P12. Silueta cuadrada frente a la redonda del zombie; el rojo del visor lo separa del jugador. El modelo final es del pase de arte (ACTION_PLAN 4.4). |
| D4 | **`EnemySpawner.Population`** (`ZOMBIES`, `HOSTILE_ROBOTS`), `@export var population` en cada nodo spawner. Un único método estático y puro, `rules_for(population, zone) -> Rules` (clase interna: `count_min`, `count_max`, `entries`, `spawn_stream`, `brain_stream`, `drop_stream`), traduce la población a los campos de `ZoneData` y a las constantes de `SeededRng`; es público para que un test fije ese mapa (revisión de `architecture-guardian`), y el resto del spawner no cambia. El enum se guarda como entero en `farm_zone_green.tscn`: **solo se añade al final** (comentario en el enum y test de que cada nodo de la zona tiene su población). `spawn(zone, markers, world_seed, visit, pool, dead_indices)` conserva su firma. Con `ZOMBIES` lee `enemy_count_min/max`, `enemy_spawns` y `STREAM_ENEMY_*`, exactamente lo de hoy. | R-016-20, R-016-21, R-016-22. Dos poblaciones: la abstracción (un recurso de población por zona) se hará a la tercera (P2). Mantener los campos y flujos de los zombies es lo que garantiza que sus visitas no cambian. |
| D5 | **`ZoneData` gana** `hostile_robot_count_min`, `hostile_robot_count_max` y `hostile_robot_spawns: Array[EnemySpawnEntryData]`, con los mismos nombres que los de zombies. `green_zone.tres`: 0, 1 y una entrada `hostile_robot_basic` con `min_count 0`, `weight 1`. `ZonePopulation.pick_enemy_spawns` sirve tal cual: `randi_range(0, 1)` es la regla de rangos de §2.1 (pregunta 6) y el peso único siempre elige el robot. La base deja los tres a su valor por defecto (0, 0, vacío). | R-016-20, P2, P5. Sin cambios en `ZonePopulation`. |
| D6 | **Flujos nuevos** en `SeededRng`: `STREAM_HOSTILE_ROBOT_SPAWN = &"hostile_robot_spawn"`, `STREAM_HOSTILE_ROBOT_BRAIN = &"hostile_robot_brain"`, `STREAM_HOSTILE_ROBOT_DROP = &"hostile_robot_drop"`. Nombres fijados por test (como `test_r_008_36_enemy_drop_stream_name`): son un contrato con los mundos guardados. | R-016-17, R-016-20, R-016-21, R-016-22, pregunta 9. Ninguna tirada del robot consume números de un flujo de zombies. |
| D7 | **Marcadores** en un nodo nuevo `%HostileRobotMarkers` de `farm_zone_green.tscn`, con **4** `Marker3D` colocados a mano (uno por cada lado de la zona), cada uno: dentro con margen del agente, sobre la navmesh, a más de `vision_radius + patrol_radius` del robot hostil (13 m) del `SpawnPoint`, a más de 2 × 0.5 m de cualquier marcador de zombie y de caja. 4 > `hostile_robot_count_max` para que el sitio cambie entre visitas; el número es diseño de nivel (como los 10 de los zombies), no un valor de BALANCE. El nodo spawner nuevo es `%HostileRobotSpawner` (`population = HOSTILE_ROBOTS`, `enemies_root` = `%Enemies`, el mismo padre). | R-016-21, pregunta 7. Las mismas comprobaciones que R-006-23 y R-013-09 para los zombies y las cajas. |
| D8 | **`FarmZone` con dos poblaciones.** `populate(world_seed, visit, zombie_pool, hostile_robot_pool, saved_state)` y `repopulate(world_seed, visit, zombie_pool, hostile_robot_pool)` ganan el pool del robot; `spawn_zombies` (D1) y el nuevo `spawn_hostile_robots(world_seed, visit, pool, dead_indices = [])`; `despawn_enemies()` devuelve **los dos**; `get_hostile_robots()`; las dos señales `enemy_loot_dropped` de los spawners salen por la de la zona. `get_visit_state()` añade `"dead_hostile_robots": [int]`; `populate` lo lee con la misma validación que `dead_enemies` (`_saved_dead(saved_state, key)`), y **sin la clave** es `[]`. | R-016-18, R-016-23, R-016-24, R-016-25, R-016-26. Campo opcional cuyo defecto reproduce lo de antes: sin `schema_version` nueva (architecture §10.2). `ZoneMemory` no cambia: guarda el diccionario de la zona tal cual. |
| D9 | **`ZoneLoader`** gana `@export var hostile_robot_pool: ObjectPool` y en `_populate` precalienta: `hostile_robot_pool.prewarm(hostile_robot_count_max)`, `impact_pool.prewarm(enemy_count_max + hostile_robot_count_max)` y en los objetos caídos suma `hostile_robot_count_max` a las caídas de enemigos (pregunta 8). Pasa los dos pools a `populate` y `repopulate`. `main.tscn` añade `World/HostileRobotPool` (`scene = hostile_robot.tscn`) y lo cablea. `Main` no cambia: ya conecta `farm.enemy_loot_dropped`. Sin `hostile_robot_pool` asignado, `_populate` hace `push_error` y la zona se puebla sin robots (zombies y cajas como siempre); nunca un fallo por null a mitad de viaje. | R-016-23, P12. Todo se crea detrás de la pantalla de carga. |
| D10 | **`PieceDropData`** (`scripts/data/piece_drop_data.gd`): `chance_percent: int`, `pieces: Array[PieceData]`, `durability_percent: int`. `EnemyData` gana `@export var piece_drop: PieceDropData` (null = no suelta pieza; los zombies lo dejan así). Porcentajes enteros con la escala `CraftingSystem.PERCENT`, como `DurabilityDisplayData`: el 15 % y el 50 % de BALANCE §3.2 son exactos, sin redondeos de `float`. | R-016-04, R-016-15, R-016-16, P5. |
| D11 | **Tirada.** En `LootSystem` (puro): `validate_piece_drop(drop)` (probabilidad en 0..100; si es > 0: durabilidad en 1..100, lista no vacía, sin huecos y cada pieza con `durability_max >= 1`), así un `PieceDropData.new()` con probabilidad 0 es válido; `roll_piece(drop, rng) -> ItemStack`: `rng.randi_range(1, PERCENT) <= chance_percent`; si sale, `rng.randi_range(0, pieces.size() - 1)` elige la pieza; la pila es `CraftingSystem.create_result(pieza)` con `durability = clampi(durability_max * durability_percent / PERCENT, 1, durability_max)` (división entera a propósito, con `@warning_ignore("integer_division")` en esa línea y un comentario del porqué, para no dejar un aviso nuevo; con 100 y 50 da 50). Si no sale, `null`, y no se hace la segunda llamada. `roll_enemy_drop(table, piece_drop, rng)`: `roll(table, rng)` si hay tabla, después `roll_piece` si hay `piece_drop`, añadida al final. **Ese orden de llamadas es un contrato** con los mundos guardados. `Enemy._drop_loot` llama a `roll_enemy_drop` con el RNG de su `drop_seed`: para un zombie (sin `piece_drop`) es la misma secuencia que hoy. Tabla o `piece_drop` inválidos → `push_error` y esa parte no da nada. | R-016-14 a R-016-17, R-016-22. El `uid` sale de `Uid.generate()` (aleatorio de 128 bits, architecture §10.3): es identidad, no juego; "la misma semilla da el mismo drop" compara id, cantidad y durabilidad. El mínimo de 1 evita una pieza a 0, que `InventoryRules.is_valid_stack` rechaza. |
| D12 | **Datos nuevos** (§4): `hostile_robot_basic.tres` (`EnemyData`, `MACHINE`), `hostile_robot_ai.tres` (`EnemyAiData` propio, no el de los zombies), `hostile_robot_drop.tres` (`LootTableData`) y `resources/piece_drops/hostile_robot_piece_drop.tres` (`PieceDropData`, carpeta propia: `resources/loot/` solo guarda `LootTableData`). El robot entra en `DataCatalog.enemies`. Clave `ENEMY_HOSTILE_ROBOT_BASIC` en `strings.csv` (EN "Hostile robot", ES "Robot hostil"). | R-016-01 a R-016-05. |
| D13 | Sin señal nueva, sin evento nuevo en `EventBus`, sin momento de guardado nuevo, sin `schema_version` nueva, sin cambio en `architecture.md`. Al cerrar la spec se actualizan CLAUDE.md (`ZombieSpawner` → `EnemySpawner`, el robot hostil) y `docs/systems/` (`system-documenter spec 016`). | P6, architecture §7, §10.2. |

## 2. Archivos

| Archivo (`game/…`) | Nuevo / Cambia | Responsabilidad |
|---|---|---|
| `scenes/entities/zombie.gd` → `scenes/entities/enemy.gd` (+ `.uid`) | Renombra (D1) y cambia | Clase `Enemy`; `_drop_loot` usa `LootSystem.roll_enemy_drop` (D11) |
| `scenes/entities/zombie.tscn` | Cambia | Solo la ruta del script (D1) |
| `scenes/entities/hostile_robot.tscn` | Nuevo | Modelo, colisionador, componentes y animaciones del robot hostil (D2, D3) |
| `scenes/farm_zone/zombie_spawner.gd` → `scenes/farm_zone/enemy_spawner.gd` (+ `.uid`) | Renombra (D1) y cambia | Clase `EnemySpawner`; `Population` y `_rules` (D4) |
| `scenes/farm_zone/farm_zone.gd` | Cambia | Dos poblaciones, dos pools, estado de visita con `dead_hostile_robots` (D1, D8) |
| `scenes/farm_zone/farm_zone_green.tscn` | Cambia | Ruta del script del spawner; `%HostileRobotMarkers` (4) y `%HostileRobotSpawner` (D7) |
| `scenes/zones/zone_loader.gd` | Cambia | `hostile_robot_pool`, precalentado y paso de pools (D9) |
| `scenes/main.tscn` | Cambia | `World/HostileRobotPool` y su cableado en `ZoneLoader` (D9) |
| `scripts/data/piece_drop_data.gd` | Nuevo | `PieceDropData` (D10) |
| `scripts/data/enemy_data.gd` | Cambia | `piece_drop` (D10) |
| `scripts/data/zone_data.gd` | Cambia | Campos `hostile_robot_*` (D5) |
| `scripts/systems/loot_system.gd` | Cambia | `validate_piece_drop`, `roll_piece`, `roll_enemy_drop` (D11) |
| `scripts/util/seeded_rng.gd` | Cambia | Tres flujos `hostile_robot_*` (D6) |
| `resources/enemies/hostile_robot_basic.tres` | Nuevo | `EnemyData` del robot (§4) |
| `resources/ai/hostile_robot_ai.tres` | Nuevo | `EnemyAiData` del robot (§4) |
| `resources/loot/hostile_robot_drop.tres` | Nuevo | Materiales (§4) |
| `resources/piece_drops/hostile_robot_piece_drop.tres` | Nuevo | Pieza (§4) |
| `resources/zones/green_zone.tres` | Cambia | 0-1 robot y su entrada (§4) |
| `resources/data_catalog.tres` | Cambia | `enemies` con el robot |
| `i18n/strings.csv` | Cambia | `ENEMY_HOSTILE_ROBOT_BASIC` (ES + EN) |
| `tests/integration/test_zombie.gd` → `test_enemy.gd` | Renombra (D1) | Más casos de `roll_enemy_drop` sin pieza (zombie) |
| `tests/integration/test_zombie_spawner.gd` → `test_enemy_spawner.gd` | Renombra (D1) y cambia | Población del robot, marcadores, zombies intactos, pools, visitas, muertos |
| `tests/integration/test_hostile_robot.gd` | Nuevo | Escena, comportamiento, combate, XP y drop del robot hostil |
| `tests/unit/test_loot_system.gd`, `test_enemy_resources.gd`, `test_data_catalog.gd`, `test_zone_resources.gd`, `test_seeded_rng.gd`, `test_no_global_rng.gd` | Cambian | §5 |
| `tests/integration/test_green_zone.gd`, `test_zone_loader.gd`, `test_zone_memory.gd`, `test_save_fixtures.gd`, `test_main_scene.gd`, `test_save_load.gd`, `test_robot_combat.gd`, `test_base_zone.gd` | Cambian | Nombres de D1 y el pool del robot en `populate`/`repopulate`; casos nuevos de §5 |
| `tests/support/hostile_drop_search.gd` | Nuevo | Ayuda de tests (sin `class_name`): busca una visita cuyo robot suelte pieza y calcula su drop con la semilla, sin copiar números. Para ir rápido coloca en la zona cargada de `Main` los robots de esa visita en lugar de los de la suya; solo lo usan los tests de `Main` y de guardado de T-016-10, cuyas aserciones no dependen de la visita |

## 3. Contratos

```gdscript
# scripts/data/piece_drop_data.gd
class_name PieceDropData
extends Resource
## The piece an enemy may drop when a player kills it (BALANCE §3.2, spec 016).
## Percentages on the scale of CraftingSystem.PERCENT.

## Chance of dropping one piece, 0..100.
@export var chance_percent: int = 0
## One of these, with equal chance; never empty while chance_percent > 0.
@export var pieces: Array[PieceData] = []
## Durability the piece keeps, as a percentage of its durability_max, 1..100.
@export var durability_percent: int = 0


# scripts/data/enemy_data.gd (añade)
## Rolled after drop_table, with the same RNG, when a player kills it (spec 016); null drops no piece.
@export var piece_drop: PieceDropData


# scripts/data/zone_data.gd (añade)
## Hostile robots placed on each visit, apart from enemy_count_* (BALANCE §7.1, spec 016).
@export var hostile_robot_count_min: int = 0
@export var hostile_robot_count_max: int = 0
@export var hostile_robot_spawns: Array[EnemySpawnEntryData] = []


# scripts/util/seeded_rng.gd (añade)
const STREAM_HOSTILE_ROBOT_SPAWN := &"hostile_robot_spawn"
const STREAM_HOSTILE_ROBOT_BRAIN := &"hostile_robot_brain"
const STREAM_HOSTILE_ROBOT_DROP := &"hostile_robot_drop"


# scripts/systems/loot_system.gd (añade)
## Empty when valid; one message per problem: chance outside 0..100 and, when
## chance > 0, durability outside 1..100, no pieces, an empty piece slot or a
## piece with durability_max < 1.
static func validate_piece_drop(drop: PieceDropData) -> PackedStringArray
## One rng.randi_range(1, CraftingSystem.PERCENT); at or below chance_percent,
## one rng.randi_range(0, pieces.size() - 1) picks the piece. A new unique stack
## (CraftingSystem.create_result) with durability_percent of its durability_max,
## at least 1; null when no piece drops. That order is a contract with saved
## worlds. Invalid drop → push_error naming it and null, no RNG call.
static func roll_piece(drop: PieceDropData, rng: RandomNumberGenerator) -> ItemStack
## roll(table) when table is not null, then roll_piece(piece_drop) when it is
## not null, with the same rng; the piece goes last. Both null → empty.
static func roll_enemy_drop(
	table: LootTableData, piece_drop: PieceDropData, rng: RandomNumberGenerator
) -> Array[ItemStack]


# scenes/entities/enemy.gd (renombrada desde zombie.gd; solo cambia lo marcado)
class_name Enemy
extends CharacterBody3D
signal defeated(enemy: Enemy)                       # antes defeated(zombie: Zombie)
signal loot_dropped(stacks: Array[ItemStack], world_position: Vector3)
func activate(data: EnemyData, home: Vector3, brain_seed: int, drop_seed: int) -> void
func get_data() -> EnemyData
func get_state() -> EnemyBrain.State
func get_health() -> HealthComponent
func get_hurtbox() -> HurtboxComponent


# scenes/farm_zone/enemy_spawner.gd (renombrada desde zombie_spawner.gd)
class_name EnemySpawner
extends Node3D
## Which part of a zone's population this spawner places: its ZoneData fields
## and its SeededRng streams (D4). Saved as an int in scenes: only append.
enum Population { ZOMBIES, HOSTILE_ROBOTS }
## ZoneData fields and SeededRng streams of one population (D4).
class Rules:
	extends RefCounted
	var count_min: int
	var count_max: int
	var entries: Array[EnemySpawnEntryData]
	var spawn_stream: StringName
	var brain_stream: StringName
	var drop_stream: StringName
signal enemy_loot_dropped(stacks: Array[ItemStack], world_position: Vector3)
@export var enemies_root: Node3D
@export var population: Population = Population.ZOMBIES
func spawn(
	zone: ZoneData, markers: Array[Node], world_seed: int, visit: int, pool: ObjectPool,
	dead_indices: Array[int] = []
) -> void
func despawn_all() -> void
func get_dead_indices() -> Array[int]
func get_active() -> Array[Enemy]
## Pure: what population reads from zone and which streams it uses. null zone → push_error, null.
static func rules_for(for_population: Population, zone: ZoneData) -> Rules  # no shadowing of the member `population`


# scenes/farm_zone/farm_zone.gd (cambia)
signal enemy_loot_dropped(stacks: Array[ItemStack], world_position: Vector3)  # de los dos spawners
func repopulate(
	world_seed: int, visit: int, zombie_pool: ObjectPool, hostile_robot_pool: ObjectPool
) -> void
func populate(
	world_seed: int, visit: int, zombie_pool: ObjectPool, hostile_robot_pool: ObjectPool,
	saved_state: Dictionary
) -> void
## {"boxes": [...], "dead_enemies": [int], "dead_hostile_robots": [int]}
func get_visit_state() -> Dictionary
func spawn_zombies(world_seed: int, visit: int, pool: ObjectPool, dead_indices: Array[int] = []) -> void
func spawn_hostile_robots(
	world_seed: int, visit: int, pool: ObjectPool, dead_indices: Array[int] = []
) -> void
## Both populations back to their pools.
func despawn_enemies() -> void
func get_zombies() -> Array[Enemy]
func get_hostile_robots() -> Array[Enemy]


# scenes/zones/zone_loader.gd (añade)
@export var hostile_robot_pool: ObjectPool
```

## 4. Datos

| Recurso / `.tres` | Campos | Valores desde |
|---|---|---|
| `resources/enemies/hostile_robot_basic.tres` (`EnemyData`) | `id = &"hostile_robot_basic"`, `name_key = &"ENEMY_HOSTILE_ROBOT_BASIC"`, `faction = MACHINE`, `hp_max 50`, `hit_damage 8.0`, `move_speed 2.0`, `attack_interval 2.0`, `xp_reward 10`, `ai` → `hostile_robot_ai.tres`, `drop_table` → `hostile_robot_drop.tres`, `piece_drop` → `hostile_robot_piece_drop.tres` | BALANCE §3.2 (tabla, intervalo), §6.2 (XP) |
| `resources/ai/hostile_robot_ai.tres` (`EnemyAiData`) | `vision_radius 8.0`, `attack_range 1.5`, `patrol_radius 5.0`, `patrol_pause_min 2.0`, `patrol_pause_max 4.0`, `give_up_distance 12.0` | BALANCE §3.2 "IA del robot hostil" |
| `resources/loot/hostile_robot_drop.tres` (`LootTableData`) | `scrap` 2-4, `cables` 1-2, `iron` 1-2, en ese orden | BALANCE §2.1 fila "Robot hostil básico" (la batería, 0 %, no entra) |
| `resources/piece_drops/hostile_robot_piece_drop.tres` (`PieceDropData`) | `chance_percent 15`, `pieces` = `basic_arms`, `basic_legs`, `basic_core` (en ese orden), `durability_percent 50` | BALANCE §3.2 |
| `resources/zones/green_zone.tres` (`ZoneData`) | `hostile_robot_count_min 0`, `hostile_robot_count_max 1`, `hostile_robot_spawns` = [{`hostile_robot_basic`, `min_count 0`, `weight 1`}] | BALANCE §7.1 |
| `i18n/strings.csv` | `ENEMY_HOSTILE_ROBOT_BASIC`: EN "Hostile robot", ES "Robot hostil" | Constitución P11 |

El orden de las entradas de la tabla y de la lista de piezas es un contrato con los mundos guardados (como en
`LootTableData`): cambiarlo cambia el drop de los robots vivos de una visita guardada.

## 5. Verificación

### 5.1 Comprobaciones de motor (T-016-02, antes de usarlas)

| Qué | Por qué | Resultado |
|---|---|---|
| Renombrar un script con `class_name` fuera del editor: mover `x.gd` y `x.gd.uid` juntos, cambiar el `path` de los `ext_resource` y reimportar (`--headless --import`) deja la escena cargando y el `class_name` nuevo registrado, sin errores. **(verificar)** en la documentación de Godot 4.7 sobre UIDs de scripts | D1 | **Confirmado (2026-11-26).** El artículo de Godot sobre UIDs (4.4, sigue vigente en 4.7) pide mover el `.uid` junto al script; no dice nada de la caché de `class_name`. Comprobado en la práctica: `git mv` de los `.gd` con su `.gd.uid`, `path` corregido en `zombie.tscn` y `farm_zone_green.tscn` (no llevan `uid=` en el `ext_resource`), `--headless --import` deja `Enemy` y `EnemySpawner` en `.godot/global_script_class_cache.cfg` con su ruta nueva y ningún `Zombie`; la suite completa pasa (1773/1773). Abrir el editor no se ha probado |

`RandomNumberGenerator.randi_range` (ambos extremos incluidos) ya lo usan `LootSystem` y `ZonePopulation`; `Array[PieceData]`
exportado en un `.tres` ya existe (`Array[StatModifier]` en las piezas). No hace falta comprobarlos otra vez.

### 5.2 Requisitos

Los tests nuevos van en los archivos de §2; `test_enemy.gd` y `test_enemy_spawner.gd` son los renombrados de D1.

| Requisito | Test (`game/tests/…`) o paso manual |
|---|---|
| R-016-01 | `unit/test_enemy_resources.gd::test_r_016_01_hostile_robot_matches_balance` (facción `MACHINE`, HP, daño, velocidad, XP) · `unit/test_data_catalog.gd::test_r_016_01_hostile_robot_in_catalog` · el escaneo de literales de IA (`test_r_006_03_no_ai_literals_in_scripts`) sobre `enemy.gd` · `balance-auditor` |
| R-016-02 | `unit/test_enemy_resources.gd::test_r_016_02_attack_interval_matches_balance` |
| R-016-03 | `unit/test_enemy_resources.gd::test_r_016_03_ai_matches_balance` · `::test_r_016_03_ai_not_shared_with_zombies` (`assert_ne` de `ai` con `zombie_ai.tres` como recurso) |
| R-016-04 | `unit/test_enemy_resources.gd::test_r_016_04_drop_table_matches_balance` · `::test_r_016_04_piece_drop_matches_balance` (15, las tres piezas básicas, 50) · `unit/test_data_catalog.gd::test_r_004_26_all_loot_tables_valid` (ya existe; recorre la tabla nueva) · `::test_r_016_04_piece_drops_valid` |
| R-016-05 | `unit/test_enemy_resources.gd::test_r_016_05_hostile_robot_name_translated_es_en` (el de la spec 006 solo recorre los zombies) · `i18n-auditor` |
| R-016-06 | `integration/test_hostile_robot.gd::test_r_016_06_activate_uses_its_own_ai` · `::test_r_016_06_detects_by_ground_distance` (con `vision_radius` leído de `hostile_robot_ai.tres`: un jugador algo dentro del radio en horizontal pero más alto, fuera del radio en 3D, **sí** se persigue; uno algo fuera del radio en el suelo, no) |
| R-016-07 | `integration/test_hostile_robot.gd::test_r_016_07_moves_toward_player_at_data_speed` · manual M1 (rodea obstáculos) |
| R-016-08 | `integration/test_hostile_robot.gd::test_r_016_08_hits_after_full_interval` (batería −8 en el primer golpe, nada antes de 2 s) · `::test_r_016_08_hit_wears_equipped_piece` · `::test_r_016_08_leaving_range_restarts_wait` · `unit/test_enemy_brain.gd` prueba la regla genérica, pero solo con el intervalo del zombie lento: los 2 s los cubre `test_r_016_08_hits_after_full_interval` |
| R-016-09 | `integration/test_hostile_robot.gd::test_r_016_09_ignores_depleted_robot` |
| R-016-10 | `integration/test_hostile_robot.gd::test_r_016_10_scene_structure` (árbol de D2, tres animaciones, evitación apagada) · `::test_r_016_10_model_within_triangle_budget` · `::test_r_016_10_collider_fits_navmesh_agent` · `::test_r_016_10_animation_follows_state` · manual M2 (se distingue a simple vista) |
| R-016-11 | `integration/test_hostile_robot.gd::test_r_016_11_hit_lowers_health_and_flashes` · `integration/test_combat_feedback.gd` (las chispas ya salen en cualquier `HurtboxComponent`; comprobar en T-016-06 que un caso usa el robot) |
| R-016-12 | `integration/test_hostile_robot.gd::test_r_016_12_enemy_killed_once_with_killer` · `integration/test_robot_combat.gd::test_r_016_12_killing_hostile_robot_gives_its_xp` |
| R-016-13 | `integration/test_hostile_robot.gd::test_r_016_13_death_without_attacker_no_xp_no_drop` |
| R-016-14 | `unit/test_loot_system.gd::test_r_016_14_materials_in_range_every_roll` (muchas semillas fijas: siempre las tres, en rango) · `integration/test_hostile_robot.gd::test_r_016_14_kill_rolls_once` |
| R-016-15 | `unit/test_loot_system.gd::test_r_016_15_piece_only_at_or_below_chance` (`chance 0` nunca, `100` siempre) · `::test_r_016_15_every_piece_can_drop` (semillas fijas: salen las tres) · `::test_r_016_15_share_close_to_chance` (10 000 semillas fijas: entre 13 % y 17 %, determinista) · `::test_r_016_15_invalid_piece_drop_reports_error` |
| R-016-16 | `unit/test_loot_system.gd::test_r_016_16_piece_is_unique_and_damaged` (cantidad 1, `uid` no vacío y distinto en cada tirada, durabilidad 50 de 100, `InventoryRules.is_valid_stack`) · `::test_r_016_16_durability_never_zero` (`durability_percent 1` con una pieza de máximo 10 → 1) |
| R-016-17 | `unit/test_loot_system.gd::test_r_016_17_same_seed_same_drop` (id, cantidad y durabilidad) · `::test_r_016_17_zombie_drop_sequence_unchanged` (`roll_enemy_drop(tabla, null, rng)` = `roll(tabla, rng)` y el RNG queda igual) · `integration/test_enemy_spawner.gd::test_r_016_17_drop_seed_from_stream_visit_and_index` · `::test_r_016_17_reload_gives_same_drop` · `unit/test_seeded_rng.gd::test_r_016_17_hostile_robot_stream_names` · `unit/test_no_global_rng.gd` (`enemy_spawner.gd`, `enemy.gd` en `SPAWN_SCRIPTS`) |
| R-016-18 | `integration/test_hostile_robot.gd::test_r_016_18_drop_is_one_signal_with_all_stacks` · `integration/test_main_scene.gd::test_r_016_18_kill_leaves_one_dropped_item` (materiales y pieza en el mismo objeto, abre la pantalla de contenedor, caduca con `DroppedItemRules`) |
| R-016-19 | `integration/test_main_scene.gd::test_r_016_19_dropped_piece_taken_equipped_and_repaired` (se coge en el contenedor, se equipa, el banco cobra el tramo "pieza dañada" de `repair_costs.tres`) · `integration/test_save_load.gd::test_r_016_19_dropped_piece_survives_save` (durabilidad y `uid` tras guardar y cargar el objeto caído) · manual M3 |
| R-016-20 | `unit/test_zone_resources.gd::test_r_016_20_hostile_robot_counts_match_balance` · `::test_r_016_20_hostile_robot_spawns_match_balance` · `integration/test_enemy_spawner.gd::test_r_016_20_zero_and_one_over_visits` (semilla fija, 50 visitas: solo 0 o 1 y salen los dos) · `::test_r_016_20_same_seed_and_visit_same_robots` |
| R-016-21 | `integration/test_enemy_spawner.gd::test_r_016_21_markers_out_of_sight_of_spawn` (dentro, sobre la navmesh, lejos del `SpawnPoint`) · `::test_r_016_21_markers_apart_from_zombies_and_boxes` · `::test_r_016_21_no_dead_marker` (50 visitas: todos los marcadores reciben algún robot) · `::test_r_016_21_robot_on_its_markers_under_enemies` |
| R-016-22 | `integration/test_enemy_spawner.gd::test_r_016_22_zombies_pinned` (**test de referencia**: "id @ posición" de los zombies de 3 semillas × 4 visitas, más el drop de cada zombie al matarlo (id × cantidad); valores capturados con el código de `main` antes de T-016-03; tiene que pasar antes y después de esta spec) · `::test_r_016_22_zombie_rules_unchanged` (`EnemySpawner.rules_for(ZOMBIES, green_zone)` lee `enemy_count_min/max`, `enemy_spawns` y `STREAM_ENEMY_SPAWN/BRAIN/DROP`; `HOSTILE_ROBOTS`, los campos y flujos `hostile_robot_*`: fija también la semilla de cerebro, que no se ve desde fuera) · `::test_r_016_22_spawner_populations_in_zone` (`%ZombieSpawner` es `ZOMBIES`, `%HostileRobotSpawner` es `HOSTILE_ROBOTS`) · `::test_r_016_22_zombies_same_with_and_without_robots` (`populate` con los dos pools frente a `spawn_zombies` solo: mismas posiciones y mismo drop al matar cada zombie) · los tests existentes de R-006-25, R-008-36 y R-010-32 sin cambiar ninguna aserción |
| R-016-23 | `integration/test_enemy_spawner.gd::test_r_016_23_death_returns_robot_to_its_pool` · `::test_r_016_23_despawn_returns_both_populations` · `::test_r_016_23_reused_robot_is_reset` (vida completa y limpio, como R-006-22 y R-007-23) · `integration/test_zone_loader.gd::test_r_016_23_robot_pool_prewarmed` · `::test_r_016_23_unload_returns_robots` |
| R-016-24 | `integration/test_green_zone.gd::test_r_016_24_repopulate_places_robots_of_the_visit` · `integration/test_zone_loader.gd::test_r_016_24_exit_and_death_replace_robots` |
| R-016-25 | `integration/test_enemy_spawner.gd::test_r_016_25_dead_robot_not_back_and_no_drop` · `::test_r_016_25_living_robot_back_on_marker_full_hp` · `::test_r_016_25_visit_state_lists_dead_robots` · `integration/test_zone_memory.gd::test_r_016_25_dead_robots_stay_dead` (ida y vuelta por `ZoneMemory`) · manual M4 |
| R-016-26 | `integration/test_save_fixtures.gd::test_r_016_26_world_v1_loads_with_its_zombies` (`world_v1.json`: carga sin error, el zombie 0 sigue muerto y los demás son los de `spawn_zombies(semilla del archivo, su visita, pool, [0])` en una zona nueva) · `integration/test_enemy_spawner.gd::test_r_016_26_state_without_robot_key` (`dead_hostile_robots` ausente → `[]`, sin `push_error`) |

**Pasos manuales** (Definición de hecho; PC y APK debug en el Android de gama media):

- **M1** (R-016-07, R-016-08): en una visita con robot (semilla de desarrollo y visita que lo den, anotadas en
  T-016-11), acercarse: patrulla, persigue rodeando árboles y rocas, se para a 1.5 m y golpea cada 2 s con 8 de
  batería; el panel de equipo muestra el desgaste. Andando con Piernas básicas se escapa; sin piernas, no.
- **M2** (R-016-10): se distingue del jugador y de los zombies a simple vista, de lejos y de cerca, en movimiento y
  atacando.
- **M3** (R-016-12, R-016-18, R-016-19): matarlo sube la XP del HUD de depuración en 10 y deja un objeto caído con
  materiales; con una semilla y visita que den pieza (anotadas en T-016-11), la pieza se ve a 50/100, se coge en la
  pantalla de contenedor, se equipa y se repara en el banco por 2 hierro y 1 cable.
- **M4** (R-016-25): con el robot muerto, cerrar y abrir el juego dentro de la visita: no vuelve ni deja otro drop.
- **M5** (P12, spec §5): ≥ 30 FPS en el Android de gama media con el robot y todos los zombies persiguiendo.

Semilla de desarrollo para M1 a M4 (comprobada en T-016-09 con el código de esta rama): **20261115**, la de
`SaveTestSupport.KNOWN_SEED`. Visitas de la zona verde con robot hostil: 2 (oeste), 4, 5 y 9 (este), 7 (norte) y 8
(oeste); las visitas 0, 1, 3, 6, 10 y 11 no tienen. El drop del robot trae pieza en las visitas **7** y **9**.

Estado de T-016-11 (2026-11-26): semilla y visitas buscadas y anotadas arriba. Arranque del juego en PC (600 frames,
headless) sin errores ni avisos y APK debug exportado sin errores (`builds/android/cyberscrap-debug.apk`).

Resultado (2026-11-27, usuario): **M1 a M5 correctos** en PC y en el APK de Android. Observación: el robot sale en
pocas visitas (0 o 1 por visita, BALANCE §7.1), así que al principio costó encontrarlo; no es un fallo de la spec, y
cambiar cuántos aparecen sería un cambio de balance (BALANCE.md primero). El juego no deja elegir la semilla de un mundo nuevo
(`SaveManager._new_world_seed()`), así que en PC y Android la prueba manual usa la semilla aleatoria del mundo: salir
y volver a entrar por la salida hasta que haya robot (uno de cada dos visitas, de media) y matar robots hasta que uno
suelte pieza (15 %). La semilla 20261115 sirve para los tests y para reproducir un caso con un mundo creado a mano.

### 5.3 Tests existentes que cambian

- **D1 (renombrado)**: referencias a `Zombie`, `ZombieSpawner`, `spawn_enemies`, `get_enemies` y a las rutas
  `zombie.gd` / `zombie_spawner.gd` en `test_enemy.gd`, `test_enemy_spawner.gd`, `test_green_zone.gd`,
  `test_main_scene.gd`, `test_robot_combat.gd`, `test_save_load.gd`, `test_zone_loader.gd`, `test_zone_memory.gd`,
  `test_base_zone.gd`, `test_enemy_resources.gd` (`AI_SCRIPTS`) y `test_no_global_rng.gd` (`SPAWN_SCRIPTS`). Ninguna
  aserción cambia.
- **D8**: las 12 llamadas de tests a `populate`/`repopulate` pasan también un pool del robot (`test_green_zone.gd`,
  `test_enemy_spawner.gd`, `test_zone_memory.gd`). Ninguna aserción cambia.
- `test_zone_loader.gd`: su fixture monta un `ZoneLoader.new()` y asigna `zombie_pool` a mano; también crea y asigna un
  `ObjectPool` de `hostile_robot.tscn` (D9). Ninguna aserción cambia.
- `test_data_catalog.gd::EXPECTED_ENEMY_IDS` gana `hostile_robot_basic` (lo exige
  `test_r_006_04_every_enemy_file_in_catalog`, que cuenta los archivos de `resources/enemies/`).
- `test_enemy_resources.gd::test_r_006_02_only_the_two_zombies`: cuenta un archivo por enemigo de BALANCE §3.1 **y
  §3.2** (2 + 1). En los dos casos es el dato esperado que cambia con BALANCE, no un test que se afloja; el resto de casos de zombies
  (valores, IA compartida entre los dos zombies) siguen igual.
- `test_combat_resources.gd::EXPECTED_ONE_ARM_HITS` (no previsto al planificar; lo exige `test_r_007_28_one_arm_kills_both_zombies`,
  que recorre todos los archivos de `resources/enemies/`) gana `hostile_robot_basic`: 10 golpes de un brazo (50 HP de
  BALANCE §3.2 / 5 de daño de §4.2). Es el dato esperado que crece con BALANCE.

## 6. Check de constitución

| Principio | Cumple | Nota |
|---|---|---|
| P1 Spec primero | ✅ | Spec 016 *Aprobado* (2026-11-26); el renombrado de D1 lo autoriza la pregunta 12 de la spec si la revisión del plan lo aprueba |
| P2 Una fuente de verdad | ✅ | Cada número de BALANCE §2.1, §3.2, §6.2 y §7.1 vive en un `.tres` (§4). Un solo script para los dos enemigos y un solo spawner (D1, D2, D4): la alternativa duplicaba la lógica. `PERCENT` se reutiliza de `CraftingSystem`. Los campos `hostile_robot_*` de `ZoneData` repiten la forma de los de zombies: dos poblaciones, se abstrae a la tercera |
| P3 Lógica separada | ✅ | La tirada es pura (`LootSystem`, D11) y la población sigue en `ZonePopulation`; las escenas solo cablean |
| P4 Estado por jugador | ✅ | Ningún estado nuevo de jugador; los muertos de la visita son estado del mundo en `FarmZone`/`ZoneMemory` |
| P5 Datos como recursos | ✅ | `PieceDropData` nuevo con `class_name` y `.tres` en `resources/piece_drops/` (no en `resources/loot/`, donde `test_r_004_26_all_loot_tables_valid` exige que todo sea `LootTableData`) |
| P6 Señales | ✅ | Sin señales nuevas: el loot y la muerte viajan por las de hoy (`loot_dropped`, `defeated`, `enemy_killed`); `%UniqueName` y `@export` para los nodos nuevos |
| P7 Tipado | ✅ | Todo tipado, incluidos `Array[PieceData]` y la clase interna `EnemySpawner.Rules` (pública: un test fija el mapa de `rules_for`, D4) |
| P8 Plataforma | ✅ | Sin input ni código por plataforma |
| P9 Determinismo | ✅ | Aparición, comportamiento y drop del robot con flujos propios de `SeededRng` por visita e índice (D6); ningún `randf()`/`randi()` global (`test_no_global_rng.gd`). El `uid` es identidad (`Uid.generate`), no juego (D11) |
| P10 Servicios | — | No toca servicios |
| P11 i18n | ✅ | `ENEMY_HOSTILE_ROBOT_BASIC` ES + EN |
| P12 Presupuesto móvil | ✅ | Pool propio precalentado tras la pantalla de carga (D9); modelo de primitivas bajo el presupuesto de triángulos del zombie (D3); un enemigo más como máximo; FPS medidos en Android (M5) |
| P13 Test primero | ✅ | La lógica nueva (`LootSystem`, datos, flujos) se escribe con su test antes (tasks); el test de referencia de los zombies (R-016-22) se escribe **antes** de cambiar nada |
| P14 Alcance | ⚠️ | El renombrado de D1 es un cambio "de paso" que la spec deja al plan (pregunta 12): se justifica porque el script pasa a servir a dos escenas, va en un commit propio sin cambio de comportamiento y **lo aprobó el usuario el 2026-11-26** al pasar el plan a *Planificado*. Nada más fuera de la spec: sin estado `Flee`, sin relaciones entre facciones, sin planos ni créditos |

## 7. Riesgos y alternativas descartadas

- **El renombrado rompe referencias que no se ven** (`.uid`, caché de `class_name`, rutas en `.tscn`) → T-016-02 lo
  comprueba primero; el commit de D1 se hace con la suite completa en verde (`godot-runner`) y sin otro cambio.
- **Un cambio "inofensivo" mueve los zombies de los mundos guardados** (orden de RNG, índices, marcadores) → el test de
  referencia de R-016-22 se escribe sobre `main` antes de tocar nada y fija posiciones; los nombres de flujo están
  fijados por test; `roll_enemy_drop` sin `piece_drop` hace exactamente las mismas llamadas que `roll`.
- **Un mundo guardado antes ve aparecer un robot en su visita en curso** → aceptado en la spec (pregunta 9).
- **Un robot aparece en tests de `Main` que ya existen** (semilla fija de `SaveTestSupport`, visita 0, o la de
  `world_v1.json`) y se mete en un test que mueve al jugador por la zona (por ejemplo
  `test_r_007_28_robot_kills_a_zone_zombie`) → T-016-09 comprueba si esas semillas y visitas dan robot y dónde; si
  estorba, el test afectado lo saca de en medio sin cambiar sus aserciones (y se anota aquí). **Comprobado
  (2026-11-26):** la visita 0 de la semilla 20261115 no tiene robot, así que los tests de `Main` no cambian; la visita
  2 de `world_v1.json` lo tiene en el marcador oeste (-23, 0, -3), a 26 m de la posición guardada del jugador.
- **El precalentado de chispas cambia** (D9): `test_main_scene.gd` comprobaba `impact_pool` = `enemy_count_max`; ahora
  es `enemy_count_max + hostile_robot_count_max`. Es el dato esperado que cambia con D9, no un test que se afloja.
- **Hallazgos de `architecture-guardian` no adoptados**: un `@export var markers_root` en el spawner (cohesión
  opcional; los marcadores los sigue pasando `FarmZone`, como hoy) y un escáner de literales del drop en scripts (lo
  cubre `balance-auditor` en la Definición de hecho).
- **Hallazgos de la revisión del diff (2026-11-26) no adoptados**: constantes de test a mitad de archivo (los tests ya
  agrupan así las de cada spec, junto a sus casos); dos `push_error` con `hostile_robot_pool` sin asignar (el del
  `ZoneLoader` y el del spawner, ambos dicen algo distinto y el test los espera); `validate_piece_drop(null)` sin
  comprobar (todos sus llamadores comprueban antes). Adoptados: el caso del robot en `test_combat_feedback.gd`, los
  rangos de `test_r_016_14` leídos de su tabla, `test_r_006_02` contra una lista de nombres, `PINNED_ZOMBIES` tipado
  y CLAUDE.md sin dar la spec por cerrada mientras falte T-016-11.
- **Marcadores del robot mal colocados** (dentro de un obstáculo, fuera de la navmesh, a la vista del spawn) → los
  mismos tests que para zombies y cajas (R-016-21).
- **Probabilidad del 15 % difícil de ver en el juego** → los tests usan semillas fijas; para la prueba manual, T-016-11
  anota una semilla de desarrollo y visita que dan robot y pieza.
- **Descartado: una escena `DroppedPiece.tscn`** (pregunta 5): un solo objeto caído por muerte, el de los zombies.
- **Descartado: `Area3D` de detección** (pregunta 3): la distancia en el suelo de `Enemy._find_target` sirve igual.
- **Descartado: el robot dentro de la población de los zombies** (una entrada más en `enemy_spawns`): cambiaría el
  número, los marcadores y las semillas de los zombies de toda visita guardada, contra R-016-22.
- **Descartado: un recurso `EnemyPopulationData` para las dos poblaciones**: obligaría a mover los campos de zombies
  de `ZoneData` y sus tests (P14) por dos usos; se hará a la tercera población.
- **Descartado: probabilidades en `float`** (`randf() < 0.15`): el entero en `PERCENT` es exacto, como los tramos de
  reparación, y no depende de si `randf` incluye el 1.
- **Plan B si no se aprueba D1**: `hostile_robot.tscn` usa `zombie.gd` (`Zombie`) y el spawner sigue siendo
  `ZombieSpawner` con `population`; se cambian los docstrings para decir que sirven a cualquier enemigo de un
  `EnemyData`. Funciona igual, pero deja nombres engañosos.
