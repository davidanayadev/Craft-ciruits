# Enemigos (zombies)

> Zombies lentos y rápidos que patrullan, persiguen y golpean al robot quitándole batería. La IA es una máquina
> de estados pura; los zombies se colocan desde la semilla del mundo y salen de un pool de instancias.
> Specs: [006](../../specs/006-zombies/spec.md), [007](../../specs/007-melee-combat/spec.md),
> [008](../../specs/008-death-recovery/spec.md) · Última actualización: spec 008

## Piezas

| Pieza | Tipo | Archivo | Responsabilidad |
|---|---|---|---|
| `Zombie` | Escena (`CharacterBody3D`) | `game/scenes/entities/zombie.gd`, `zombie.tscn` | Lee al cerebro, mueve con `NavigationAgent3D`, anima y golpea. Modelo provisional de primitivas |
| `HealthComponent` | Componente | `game/scripts/components/health_component.gd` | Vida de una entidad (el robot no tiene: su batería es su vida) |
| `EnemyBrain` | Sistema puro (`RefCounted`) | `game/scripts/systems/enemy_brain.gd` | Estados `IDLE`, `PATROL`, `CHASE`, `ATTACK` |
| `EnemyData` | Recurso | `game/scripts/data/enemy_data.gd` | Un tipo de enemigo: id, nombre, facción, HP, daño, velocidad, intervalo, `xp_reward` (007) y `drop_table` (008) |
| `HurtboxComponent`, `HitFlashComponent` | Componentes | `game/scripts/components/` | Hijos del zombie (`%Hurtbox`, `%HitFlash`): lo que golpea el robot y su destello ([combat.md](combat.md)) |
| `EnemyAiData` | Recurso | `game/scripts/data/enemy_ai_data.gd` | Radios y pausas de la IA, compartidos por enemigos que se comportan igual |
| `EnemySpawnEntryData` | Recurso | `game/scripts/data/enemy_spawn_entry_data.gd` | Una línea de `ZoneData.enemy_spawns`: enemigo, `min_count`, `weight` |
| `ZombieSpawner` | Nodo 3D de la zona | `game/scenes/farm_zone/zombie_spawner.gd` | Coloca los zombies de una visita y los devuelve al pool |
| `ObjectPool` | Componente genérico | `game/scripts/components/object_pool.gd` | Reutiliza instancias de una escena, fuera del árbol mientras están guardadas |
| `ZonePopulation` | Sistema puro | `game/scripts/systems/zone_population.gd` | `pick_enemy_spawns()`: número, tipo y marcador |
| `.tres` | Datos | `resources/enemies/zombie_slow.tres`, `zombie_fast.tres`, `resources/ai/zombie_ai.tres`, `resources/zones/green_zone.tres`, `resources/loot/zombie_drop.tres` | Valores reales |

## Cómo funciona

1. `main.gd` hace `%ZombiePool.prewarm(zone.data.enemy_count_max)` y llama a
   `zone.spawn_enemies(world_seed, visit, pool)`, con la visita de `GameManager.get_visit_count(zone_id)`
   (`ZonePopulation.FIRST_VISIT` es 0). El pool es hijo de `World`, no de la zona.
2. `ZombieSpawner.spawn()` crea dos RNG de `SeededRng` con `index = visit`: `STREAM_ENEMY_SPAWN` (cantidad, tipos y
   marcadores vía `ZonePopulation`) y `STREAM_ENEMY_BRAIN` (una semilla por zombie, en orden de colocación). La
   semilla del drop de cada zombie sale de `SeededRng.derive_seed_for_visit(seed, zone_id, STREAM_ENEMY_DROP, visit, i)`
   con `i` el orden de colocación (008).
3. Por cada zombie: `pool.acquire()`, se coloca en su marcador **antes** de entrar al árbol, se añade a
   `enemies_root`, `activate(data, home, brain_seed, drop_seed)` y se conectan `defeated` y `loot_dropped`.
4. `activate()` lo reinicia todo: guarda el `EnemyData`, crea un `EnemyBrain` nuevo con su RNG, `HealthComponent.reset()`,
   `hurtbox.reset()` (olvida al último atacante), `hit_flash.clear()` y empieza a procesar física. Una instancia
   puede volver como otro tipo.
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
9. Recibir golpes (007): el `HurtboxComponent` (capa de física 3 `hurtbox`) es lo único que ve el impacto del robot
   ([combat.md](combat.md)). `receive_attack` llama a `HealthComponent.take_damage`; `hurt` dispara el destello.
10. Muerte: `HealthComponent.died` desactiva el zombie. Si el hurtbox recuerda un atacante (muerte provocada por un
    jugador) emite `EventBus.enemy_killed(data.id, killer_uid)` y tira su `drop_table` **una vez**; una muerte sin
    atacante no emite ni suelta nada. Después emite `defeated` y el spawner lo devuelve al pool con
    `call_deferred` (`died` llega en mitad de un paso de física). `FarmZone.despawn_enemies()` devuelve todos.
11. Drop (008): `LootSystem.roll(drop_table, rng)` con un RNG sembrado con `drop_seed`; si sale algo, `Zombie`
    emite `loot_dropped(stacks, posición)`, que `ZombieSpawner` y `FarmZone` reemiten como `enemy_loot_dropped`
    y `Main` entrega al `DroppedItemSpawner` ([death.md](death.md)). La tirada no depende del orden de las muertes.
12. Repoblación (008): cuando sube el contador de visitas de la zona cargada, `FarmZone.repopulate()` devuelve todos
    los zombies al pool y coloca los de la visita nueva (otro reparto, otras semillas); además sustituye las cajas
    ([world_zones.md](world_zones.md), [death.md](death.md)).

## Datos

| Recurso | Clase | Valores desde |
|---|---|---|
| `zombie_slow.tres`, `zombie_fast.tres` | `EnemyData` | [BALANCE.md §3.1](../../BALANCE.md) |
| `zombie_ai.tres` | `EnemyAiData` | BALANCE.md §3.1 ("IA de zombies") |
| `green_zone.tres` (`enemy_count_min/max`, `enemy_spawns`) | `ZoneData` | [BALANCE.md §7.1](../../BALANCE.md) |
| `green_zone_navmesh.tres` | `NavigationMesh` | Técnico: horneado en el editor, no es balance |
| `zombie_slow/fast.tres` (`xp_reward`) | `EnemyData` | BALANCE.md §3.1 y §6.2 |
| `zombie_drop.tres` (`drop_table`, compartida por los dos zombies) | `LootTableData` | BALANCE.md §3.1 (notas), regla de rangos §2.1 |

Las entradas de `enemy_spawns` ponen primero el `min_count` de cada tipo y reparten el resto por `weight`. Hay 10
marcadores en `%EnemyMarkers` (más que el máximo de enemigos). `drop_table = null` significa que no suelta nada.

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
| Último atacante en el hurtbox, no en `HealthComponent` | `HealthComponent` no sabe de jugadores | [plan 007 §1](../../specs/007-melee-combat/plan.md) |
| `enemy_killed` solo si hubo atacante | Una muerte sin jugador no es una kill | R-007-17 |
| Drop con semilla de mundo + zona + visita + índice de aparición | No depende del orden de las muertes ni de recargar | R-008-36, [plan 008 §1](../../specs/008-death-recovery/plan.md) |
| El drop sube por tres señales (`Zombie` → spawner → zona → `Main`), no por el bus | La lista del `EventBus` es cerrada y solo le interesa a quien carga la zona | plan 008 §7 |
| Las cajas se sustituyen al repoblar, no se reinician | Reiniciar obliga a deshacer señales y ranuras | plan 008 §1 |

## Relación con otros sistemas

- Usa: [battery.md](battery.md) (consumo por golpe), [world_zones.md](world_zones.md) (`FarmZone`, `ZoneData`,
  marcadores, `SeededRng`, navmesh), [data_catalog.md](data_catalog.md) (`EnemyData` por id en `DataCatalog`,
  `EventBus`), [combat.md](combat.md) (hurtbox, XP), [loot.md](loot.md) (`LootSystem.roll` para el drop).
- Lo usa: [ui.md](ui.md) (los zombies siguen actuando con una pantalla abierta), [death.md](death.md) (la
  transferencia congela `World`; los drops se vuelven objetos caídos).

## Trampas y límites

- `HealthComponent` está inactivo hasta el primer `reset()`: `take_damage`/`heal` dan error. El robot no tiene
  `HealthComponent`.
- `activate()` exige estar dentro del árbol; coloca el zombie en su sitio **antes** de `add_child`, o arrastra al
  robot si se solapan.
- `home` y los puntos de patrulla están en coordenadas globales.
- La visita sale de `GameManager`, que no se guarda todavía (spec 010). `FarmZone.repopulate()` llama a
  `despawn_enemies()` en cada muerte del robot; el `ZoneLoader` llega con la spec 009.
- `activate()` ahora recibe `drop_seed` como cuarto argumento: quien lo llame a mano (tests) debe pasarlo.
- La posición del hurtbox va un paso de física por detrás del cuerpo del zombie (matiz de `intersect_shape`,
  [plan 007 §5.1](../../specs/007-melee-combat/plan.md)).
- No hay retroceso, animación de muerte ni XP de otros enemigos: el zombie desaparece al morir.
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
| `tests/integration/test_zombie.gd` | Zombie con navmesh, golpe, batería agotada, reutilización limpia, `enemy_killed` una vez, destello, tirada del drop |
| `tests/integration/test_zombie_spawner.gd` | Colocación determinista, despawn al pool, drop independiente del orden de muertes y de la visita |
| `tests/integration/test_robot_hit.gd` | `Robot.receive_hit` y `hit_received` |
