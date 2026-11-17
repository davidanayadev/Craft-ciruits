# Enemigos (zombies)

> Zombies lentos y rápidos que patrullan, persiguen y golpean al robot quitándole batería. La IA es una máquina
> de estados pura; los zombies se colocan desde la semilla del mundo y salen de un pool de instancias.
> Specs: [006](../../specs/006-zombies/spec.md) · Última actualización: spec 006

## Piezas

| Pieza | Tipo | Archivo | Responsabilidad |
|---|---|---|---|
| `Zombie` | Escena (`CharacterBody3D`) | `game/scenes/entities/zombie.gd`, `zombie.tscn` | Lee al cerebro, mueve con `NavigationAgent3D`, anima y golpea. Modelo provisional de primitivas |
| `HealthComponent` | Componente | `game/scripts/components/health_component.gd` | Vida de una entidad (el robot no tiene: su batería es su vida) |
| `EnemyBrain` | Sistema puro (`RefCounted`) | `game/scripts/systems/enemy_brain.gd` | Estados `IDLE`, `PATROL`, `CHASE`, `ATTACK` |
| `EnemyData` | Recurso | `game/scripts/data/enemy_data.gd` | Un tipo de enemigo: id, nombre, facción, HP, daño, velocidad, intervalo |
| `EnemyAiData` | Recurso | `game/scripts/data/enemy_ai_data.gd` | Radios y pausas de la IA, compartidos por enemigos que se comportan igual |
| `EnemySpawnEntryData` | Recurso | `game/scripts/data/enemy_spawn_entry_data.gd` | Una línea de `ZoneData.enemy_spawns`: enemigo, `min_count`, `weight` |
| `ZombieSpawner` | Nodo 3D de la zona | `game/scenes/farm_zone/zombie_spawner.gd` | Coloca los zombies de una visita y los devuelve al pool |
| `ObjectPool` | Componente genérico | `game/scripts/components/object_pool.gd` | Reutiliza instancias de una escena, fuera del árbol mientras están guardadas |
| `ZonePopulation` | Sistema puro | `game/scripts/systems/zone_population.gd` | `pick_enemy_spawns()`: número, tipo y marcador |
| `.tres` | Datos | `resources/enemies/zombie_slow.tres`, `zombie_fast.tres`, `resources/ai/zombie_ai.tres`, `resources/zones/green_zone.tres` | Valores reales |

## Cómo funciona

1. `main.gd` hace `%ZombiePool.prewarm(zone.data.enemy_count_max)` y llama a
   `zone.spawn_enemies(world_seed, ZombieSpawner.FIRST_VISIT, pool)`. El pool es hijo de `World`, no de la zona.
2. `ZombieSpawner.spawn()` crea dos RNG de `SeededRng` con `index = visit`: `STREAM_ENEMY_SPAWN` (cantidad, tipos y
   marcadores vía `ZonePopulation`) y `STREAM_ENEMY_BRAIN` (una semilla por zombie, en orden de colocación).
3. Por cada zombie: `pool.acquire()`, se coloca en su marcador **antes** de entrar al árbol, se añade a
   `enemies_root`, `activate(data, home, brain_seed)` y se conecta `defeated`.
4. `activate()` lo reinicia todo: guarda el `EnemyData`, crea un `EnemyBrain` nuevo con su RNG, `HealthComponent.reset()`
   y empieza a procesar física. Una instancia puede volver como otro tipo.
5. Cada `_physics_process`: `_find_target()` busca en el grupo `Robot.PLAYER_GROUP` el robot vivo más cercano
   (batería no agotada); calcula la distancia en el plano XZ (`INF` si no hay objetivo) y llama a
   `brain.tick(delta, distance, patrol_arrived)`.
6. Estados (radios en `EnemyAiData`, intervalo en `EnemyData`):
   - `IDLE`: pausa aleatoria, luego `PATROL`. `PATROL`: va a un punto alrededor de casa; al llegar, `IDLE`.
   - `IDLE`/`PATROL` con objetivo dentro de visión: `CHASE`. `CHASE` dentro del rango: `ATTACK`.
   - `CHASE`/`ATTACK` con objetivo más allá de la distancia de abandono (incluye `INF`): `PATROL`. Se evalúa antes.
   - `ATTACK` fuera de rango: `CHASE` y el temporizador vuelve a 0.
7. Movimiento: `CHASE` pone el robot como `target_position`; `PATROL` proyecta el punto con
   `NavigationServer3D.map_get_closest_point()` para que siempre sea alcanzable. La dirección sale de
   `get_next_path_position()`, a `move_speed`, horizontal, con `move_and_slide()`.
8. Golpe: `tick()` devuelve `true` al cumplirse el intervalo; el zombie llama a
   `target.receive_hit(data.hit_damage, self)`. `Robot.receive_hit` no hace nada con la batería agotada; si no,
   `battery.consume(damage)` y emite `hit_received(damage, attacker)` ([battery.md](battery.md)).
9. Muerte: `HealthComponent.died` desactiva el zombie y emite `defeated`; el spawner lo devuelve al pool con
   `call_deferred` (`died` llega en mitad de un paso de física). `FarmZone.despawn_enemies()` devuelve todos.

## Datos

| Recurso | Clase | Valores desde |
|---|---|---|
| `zombie_slow.tres`, `zombie_fast.tres` | `EnemyData` | [BALANCE.md §3.1](../../BALANCE.md) |
| `zombie_ai.tres` | `EnemyAiData` | BALANCE.md §3.1 ("IA de zombies") |
| `green_zone.tres` (`enemy_count_min/max`, `enemy_spawns`) | `ZoneData` | [BALANCE.md §7.1](../../BALANCE.md) |
| `green_zone_navmesh.tres` | `NavigationMesh` | Técnico: horneado en el editor, no es balance |

Las entradas de `enemy_spawns` ponen primero el `min_count` de cada tipo y reparten el resto por `weight`. XP y
drops no existen aún (spec 007). Hay 10 marcadores en `%EnemyMarkers` (más que el máximo de enemigos).

## Decisiones

| Decisión | Por qué | Fuente |
|---|---|---|
| Máquina de estados pura en `RefCounted` | Testeable sin árbol de escena y reutilizable por otros enemigos | R-006-11, [plan 006 §1](../../specs/006-zombies/plan.md) |
| Distancia `INF` si no hay objetivo vivo | Batería a 0 equivale a ningún jugador sin otra regla | R-006-18, plan 006 §1 |
| El zombie llama directo a `receive_hit`, sin `EventBus` | Relación atacante-objetivo entre dos entidades, no global | plan 006 §1 y §6, [architecture §7](../../specs/architecture.md) |
| Objetivo por grupo `players` en cada paso | Sin referencias; sirve en co-op | plan 006 §1 |
| `hit_received(damage, attacker)` | La degradación (spec 014) se conecta sin tocar la IA | R-006-17 |
| Pool bajo `World`, con `prewarm` | Sobrevive a la zona, evita instanciar a mitad de juego | R-006-22, plan 006 §1, architecture §11 |
| Dos streams de RNG separados | Cambiar la IA no mueve dónde aparecen | R-006-23..25, plan 006 §1 |
| Navmesh horneado en el editor | Decidido en la pregunta 3 de la spec | [spec 006](../../specs/006-zombies/spec.md), R-006-20 |
| Sin `avoidance` | Pregunta 8 de la spec; la colisión física los separa | plan 006 §1, §7 |
| Sin `ActionResult` en `HealthComponent` | Una entrada inválida es error de programación | plan 006 §7 |

## Relación con otros sistemas

- Usa: [battery.md](battery.md) (consumo por golpe), [world_zones.md](world_zones.md) (`FarmZone`, `ZoneData`,
  marcadores, `SeededRng`, navmesh), [data_catalog.md](data_catalog.md) (`EnemyData` por id en `DataCatalog`).
- Lo usa: [ui.md](ui.md) (los zombies siguen actuando con una pantalla abierta). El game over congela `World`.

## Trampas y límites

- `HealthComponent` está inactivo hasta el primer `reset()`: `take_damage`/`heal` dan error. El robot no tiene
  `HealthComponent`.
- `activate()` exige estar dentro del árbol; coloca el zombie en su sitio **antes** de `add_child`, o arrastra al
  robot si se solapan.
- `home` y los puntos de patrulla están en coordenadas globales.
- `FIRST_VISIT = 0` es provisional hasta el contador de visitas (spec 010). `despawn_enemies()` solo la llaman los
  tests hasta el `ZoneLoader` (spec 009).
- El robot todavía no ataca: nadie llama a `take_damage` de un zombie en el juego (spec 007).
- Las cajas aparecen en ejecución y no están en el navmesh, así que un zombie puede engancharse con una.
- Modelo y animaciones provisionales de primitivas.
- `get_nodes_in_group` en cada paso crea un array por zombie y fotograma; medir en Android (R-006-28).

## Cómo extenderlo

- Zombie nuevo: `.tres` de `EnemyData` en `resources/enemies/` con su `ai`, añadirlo a `enemy_spawns` de la zona
  y valores a BALANCE.md §3.1 primero.
- Otro comportamiento: nuevo `EnemyAiData`. Otro enemigo (robot hostil, spec 015) reutiliza `EnemyBrain`.
- Otra cosa agrupable en pool: un `ObjectPool` con su escena, que ofrezca su propio `activate()`.

## Tests

| Archivo | Verifica |
|---|---|
| `tests/unit/test_enemy_brain.gd` | Transiciones, ritmo de golpes, determinismo con semilla |
| `tests/unit/test_health_component.gd` | Daño, curación, `died` una vez, entradas inválidas |
| `tests/unit/test_object_pool.gd` | `acquire`, `release`, `prewarm`, errores |
| `tests/unit/test_enemy_resources.gd` | `.tres` de enemigos e IA frente a BALANCE |
| `tests/unit/test_zone_population.gd` | Reparto de tipos y marcadores |
| `tests/integration/test_zombie.gd` | Zombie con navmesh, golpe, batería agotada, reutilización |
| `tests/integration/test_zombie_spawner.gd` | Colocación determinista, despawn al pool |
| `tests/integration/test_robot_hit.gd` | `Robot.receive_hit` y `hit_received` |
