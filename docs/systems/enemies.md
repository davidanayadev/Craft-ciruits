# Enemigos (zombies y robot hostil)

> Zombies lentos y rápidos y un robot hostil que patrullan, persiguen y golpean al robot quitándole batería. Un solo
> script y una sola IA (máquina de estados pura) sirven a las dos escenas; cada población se coloca desde la semilla
> del mundo con su propio spawner y sale de su propio pool.
> Specs: [006](../../specs/006-zombies/spec.md), [007](../../specs/007-melee-combat/spec.md),
> [008](../../specs/008-death-recovery/spec.md) · [010](../../specs/010-save-profile-world/spec.md) · [016](../../specs/016-hostile-robot/spec.md) · Última actualización: spec 016 (robot hostil, `Enemy`, `EnemySpawner`)

## Piezas

| Pieza | Tipo | Archivo | Responsabilidad |
|---|---|---|---|
| `Enemy` | Script (`CharacterBody3D`) | `game/scenes/entities/enemy.gd` | Lee al cerebro, mueve con `NavigationAgent3D`, anima, golpea y suelta el drop. Lo usan dos escenas; todo lo propio de un tipo sale de su `EnemyData` |
| `zombie.tscn` | Escena | `game/scenes/entities/zombie.tscn` | Modelo provisional de primitivas redondeadas; `script = enemy.gd` |
| `hostile_robot.tscn` | Escena | `game/scenes/entities/hostile_robot.tscn` | Mismo árbol de nodos (`%Health`, `%NavAgent`, `%AnimationPlayer`, `%Hurtbox`, `%HitFlash`), modelo de cajas con visor rojo y animaciones `idle`, `walk`, `attack`; `script = enemy.gd` |
| `HealthComponent` | Componente | `game/scripts/components/health_component.gd` | Vida de una entidad (el robot no tiene: su batería es su vida) |
| `EnemyBrain` | Sistema puro (`RefCounted`) | `game/scripts/systems/enemy_brain.gd` | Estados `IDLE`, `PATROL`, `CHASE`, `ATTACK` |
| `EnemyData` | Recurso | `game/scripts/data/enemy_data.gd` | Un tipo de enemigo: id, nombre, facción, HP, daño, velocidad, intervalo, `xp_reward`, `drop_table` y `piece_drop` (016) |
| `PieceDropData` | Recurso | `game/scripts/data/piece_drop_data.gd` | Pieza que un enemigo puede soltar: probabilidad, piezas posibles y durabilidad con que sale (ver [loot.md](loot.md)) |
| `HurtboxComponent`, `HitFlashComponent` | Componentes | `game/scripts/components/` | Hijos del enemigo: lo que golpea el robot y su destello ([combat.md](combat.md)) |
| `EnemyAiData` | Recurso | `game/scripts/data/enemy_ai_data.gd` | Radios y pausas de la IA; los dos zombies comparten uno y el robot tiene el suyo |
| `EnemySpawnEntryData` | Recurso | `game/scripts/data/enemy_spawn_entry_data.gd` | Una línea de `enemy_spawns` o `hostile_robot_spawns` de `ZoneData`: enemigo, `min_count`, `weight` |
| `EnemySpawner` | Nodo 3D de la zona | `game/scenes/farm_zone/enemy_spawner.gd` | Coloca una población de una visita y la devuelve al pool. `enum Population { ZOMBIES, HOSTILE_ROBOTS }` y `rules_for()` |
| `ObjectPool` | Componente genérico | `game/scripts/components/object_pool.gd` | Reutiliza instancias de una escena: `World/ZombiePool` y `World/HostileRobotPool` |
| `ZonePopulation` | Sistema puro | `game/scripts/systems/zone_population.gd` | `pick_enemy_spawns()`: número, tipo y marcador; sirve a las dos poblaciones |
| `.tres` | Datos | `resources/enemies/` (`zombie_slow`, `zombie_fast`, `hostile_robot_basic`), `resources/ai/` (`zombie_ai`, `hostile_robot_ai`), `resources/loot/` (`zombie_drop`, `hostile_robot_drop`), `resources/piece_drops/`, `resources/zones/green_zone.tres` | Valores reales |

## Cómo funciona

1. `ZoneLoader._populate` precalienta `zombie_pool` y `hostile_robot_pool` y llama a
   `farm.populate(seed, visita, zombie_pool, hostile_robot_pool, estado)` ([travel.md](travel.md)). La visita sale de
   `GameManager.get_visit_count(zone_id)` (`ZonePopulation.FIRST_VISIT` es 0). Los pools son hijos de `World`.
2. `FarmZone` tiene **dos** `EnemySpawner` (`%ZombieSpawner`, `%HostileRobotSpawner`), cada uno con sus marcadores
   (`%EnemyMarkers`, `%HostileRobotMarkers`). `spawn_zombies` y `spawn_hostile_robots` llaman a `spawner.spawn(...)`.
3. `EnemySpawner.rules_for(population, zone)` (estático y puro) traduce la población a los campos de `ZoneData`
   (`enemy_*` o `hostile_robot_*`) y a tres flujos de `SeededRng`: `enemy_spawn/brain/drop` para los zombies y
   `hostile_robot_spawn/brain/drop` para el robot. Así ninguna tirada de una población consume números de la otra.
4. `spawn()` crea dos RNG con `index = visit`: el de spawn (cantidad, tipos y marcadores vía `ZonePopulation`) y el de
   cerebro (una semilla por enemigo, en orden de colocación). La semilla del drop sale de
   `SeededRng.derive_seed_for_visit(seed, zone_id, drop_stream, visit, i)` con `i` el orden de colocación.
5. Por cada enemigo: `pool.acquire()`, se coloca en su marcador **antes** de entrar al árbol, se añade a
   `enemies_root`, `activate(data, home, brain_seed, drop_seed)` y se conectan `defeated` y `loot_dropped`.
6. `activate()` lo reinicia todo: guarda el `EnemyData`, crea un `EnemyBrain` nuevo con su RNG, `HealthComponent.reset()`,
   `hurtbox.reset()`, `hit_flash.clear()` y empieza a procesar física. Una instancia puede volver como otro tipo de
   su escena.
7. Cada `_physics_process`: `_find_target()` busca en el grupo `Robot.PLAYER_GROUP` el robot vivo más cercano
   (batería no agotada); distancia en el plano XZ (`INF` si no hay) y `brain.tick(delta, distance, patrol_arrived)`.
8. Estados (radios en `EnemyAiData`, intervalo en `EnemyData`):
   - `IDLE`: pausa aleatoria, luego `PATROL`. `PATROL`: va a un punto alrededor de casa; al llegar, `IDLE`.
   - `IDLE`/`PATROL` con objetivo dentro de visión: `CHASE`. `CHASE` dentro del rango: `ATTACK`.
   - `CHASE`/`ATTACK` con objetivo más allá de la distancia de abandono (incluye `INF`): `PATROL`. Se evalúa antes.
   - `ATTACK` fuera de rango: `CHASE` y el temporizador vuelve a 0.
9. Movimiento: `CHASE` pone el robot como `target_position`; `PATROL` proyecta el punto con
   `NavigationServer3D.map_get_closest_point()`. La dirección sale de `get_next_path_position()`, a `move_speed`.
10. Golpe: `tick()` devuelve `true` al cumplirse el intervalo; llama a `target.receive_hit(data.hit_damage, self)`
    ([battery.md](battery.md), [equipment.md](equipment.md)).
11. Recibir golpes (007): el `HurtboxComponent` es lo único que ve el impacto del robot ([combat.md](combat.md)).
12. Muerte: `HealthComponent.died` desactiva al enemigo. Con atacante recordado emite
    `EventBus.enemy_killed(data.id, killer_uid)` y tira su drop **una vez**; sin atacante no emite ni suelta nada.
    Después emite `defeated` y el spawner lo devuelve a su pool con `call_deferred`.
13. Drop: `LootSystem.roll_enemy_drop(drop_table, piece_drop, rng)` con un RNG sembrado con `drop_seed` (primero la
    tabla, luego la pieza, mismo RNG). Si sale algo, `Enemy` emite `loot_dropped(stacks, posición)` con **todo junto**;
    sube por `EnemySpawner` y `FarmZone` (`enemy_loot_dropped`, los dos spawners por la misma señal) hasta `Main`, que
    lo entrega al `DroppedItemSpawner` ([death.md](death.md)).
14. Repoblación (008): al subir la visita, `FarmZone.repopulate(seed, visita, zombie_pool, hostile_robot_pool)` llama a
    `despawn_enemies()` (devuelve las **dos** poblaciones) y coloca las de la visita nueva ([world_zones.md](world_zones.md)).

## Datos

| Recurso | Clase | Valores desde |
|---|---|---|
| `zombie_slow.tres`, `zombie_fast.tres` | `EnemyData` | [BALANCE.md §3.1](../../BALANCE.md), XP en §6.2 |
| `hostile_robot_basic.tres` | `EnemyData` | BALANCE.md §3.2 (intervalo, drop), §6.2 (XP) |
| `zombie_ai.tres` | `EnemyAiData` | BALANCE.md §3.1 ("IA de zombies") |
| `hostile_robot_ai.tres` | `EnemyAiData` | BALANCE.md §3.2 ("IA del robot hostil") |
| `green_zone.tres` (`enemy_*`, `hostile_robot_*`) | `ZoneData` | [BALANCE.md §7.1](../../BALANCE.md) |
| `zombie_drop.tres`, `hostile_robot_drop.tres` | `LootTableData` | BALANCE.md §3.1 (notas), §2.1 (regla de rangos y fila del robot) |
| `hostile_robot_piece_drop.tres` | `PieceDropData` | BALANCE.md §3.2 |
| `green_zone_navmesh.tres` | `NavigationMesh` | Técnico: horneado en el editor, no es balance |

Las entradas de spawn ponen primero el `min_count` de cada tipo y reparten el resto por `weight`. Hay más marcadores
que el máximo de cada población. `drop_table = null` o `piece_drop = null` significan que no sueltan esa parte
(los zombies no tienen `piece_drop`).

## Decisiones

| Decisión | Por qué | Fuente |
|---|---|---|
| Máquina de estados pura en `RefCounted` | Testeable sin árbol de escena y reutilizable por otros enemigos | R-006-11, [plan 006 §1](../../specs/006-zombies/plan.md) |
| Distancia `INF` si no hay objetivo vivo | Batería a 0 equivale a ningún jugador sin otra regla | R-006-18, plan 006 §1 |
| El enemigo llama directo a `receive_hit`, sin `EventBus` | Relación atacante-objetivo entre dos entidades, no global | plan 006 §1 y §6, [architecture §7](../../specs/architecture.md) |
| Objetivo por grupo `players` en cada paso | Sin referencias; sirve en co-op | plan 006 §1 |
| `hit_received(damage, attacker)` | La degradación se conecta sin tocar la IA; el desgaste lo aplica `Robot.receive_hit` ([equipment.md](equipment.md)) | R-006-17, R-015-54 |
| Pool bajo `World`, con `prewarm` | Sobrevive a la zona, evita instanciar a mitad de juego | R-006-22, plan 006 §1, architecture §11 |
| Dos streams de RNG separados (spawn y cerebro) | Cambiar la IA no mueve dónde aparecen | R-006-23..25, plan 006 §1 |
| Navmesh horneado en el editor; sin `avoidance` | Decidido en las preguntas 3 y 8 de la spec | [spec 006](../../specs/006-zombies/spec.md), plan 006 §1, §7 |
| Último atacante en el hurtbox; `enemy_killed` solo si hubo atacante | `HealthComponent` no sabe de jugadores; una muerte sin jugador no es una kill | [plan 007 §1](../../specs/007-melee-combat/plan.md), R-007-17 |
| Drop con semilla de mundo + zona + visita + índice de aparición | No depende del orden de las muertes ni de recargar | R-008-36, [plan 008 §1](../../specs/008-death-recovery/plan.md) |
| El drop sube por tres señales locales, no por el bus | La lista del `EventBus` es cerrada | plan 008 §7, [plan 016 D13](../../specs/016-hostile-robot/plan.md) |
| `Zombie` pasó a `Enemy` y `ZombieSpawner` a `EnemySpawner`; una escena por tipo y un script | Un script que sirve a dos escenas no puede llamarse como una; sin subclases vacías | [plan 016 D1, D2](../../specs/016-hostile-robot/plan.md) |
| Un spawner por población, con `rules_for` | Dos poblaciones no justifican un recurso de población (se abstrae a la tercera); los zombies conservan campos y flujos | [plan 016 D4](../../specs/016-hostile-robot/plan.md), R-016-22 |
| El robot no es una entrada de `enemy_spawns` | Cambiaría número, marcadores y semillas de los zombies de toda visita guardada | [plan 016 §7](../../specs/016-hostile-robot/plan.md), R-016-22 |
| Flujos `hostile_robot_*` y marcadores propios | Contrato con los mundos guardados; el robot no mueve a los zombies | [plan 016 D6, D7](../../specs/016-hostile-robot/plan.md) |
| Pool propio del robot | Un `ObjectPool` crea instancias de una sola escena | [plan 016 D2, D9](../../specs/016-hostile-robot/plan.md) |
| Las cajas se sustituyen al repoblar, no se reinician | Reiniciar obliga a deshacer señales y ranuras | plan 008 §1 |

## Relación con otros sistemas

- Usa: [battery.md](battery.md), [world_zones.md](world_zones.md) (`FarmZone`, `ZoneData`, marcadores, `SeededRng`,
  navmesh), [travel.md](travel.md) (`ZoneLoader` precalienta y pasa los pools), [data_catalog.md](data_catalog.md)
  (`EnemyData` por id), [combat.md](combat.md) (hurtbox, XP), [loot.md](loot.md) (`roll_enemy_drop`).
- Lo usa: [ui.md](ui.md) (siguen actuando con una pantalla abierta), [death.md](death.md) (la transferencia congela
  `World`; los drops se vuelven objetos caídos).

## Trampas y límites

- `HealthComponent` está inactivo hasta el primer `reset()`: `take_damage`/`heal` dan error.
- `activate()` exige estar dentro del árbol; coloca al enemigo **antes** de `add_child`, o arrastra al robot si se solapan.
  Recibe `drop_seed` como cuarto argumento. `home` y los puntos de patrulla son globales.
- `EnemySpawner.Population` se guarda como entero en `farm_zone_green.tscn`: solo se añade al final.
- El orden de las entradas de una tabla y de `PieceDropData.pieces` es un contrato con los mundos guardados.
- `EnemySpawner` recuerda los índices de la visita que murieron u omitieron (`get_dead_indices`); `spawn` los salta sin
  tirar su botín pero consume su semilla de cerebro. `FarmZone.get_visit_state()` guarda `dead_enemies` y
  `dead_hostile_robots`; esta última es opcional al cargar (sin la clave, ninguno), sin `schema_version` nueva
  ([save.md](save.md)). Un mundo anterior a la 016 puede ver aparecer un robot en su visita en curso (aceptado en la spec, pregunta 9).
- Sin `hostile_robot_pool` asignado en `ZoneLoader`, hay `push_error` (el del cargador y el del spawner) y la zona se
  puebla sin robots.
- `FarmZone.spawn_enemies` y `get_enemies` ya no existen: son `spawn_zombies`, `spawn_hostile_robots`, `get_zombies`,
  `get_hostile_robots`. El nodo `%ZombieSpawner`, `ZombiePool`, `zombie_pool` y `zombie.tscn` conservan su nombre.
- La posición del hurtbox va un paso de física por detrás del cuerpo ([plan 007 §5.1](../../specs/007-melee-combat/plan.md)).
- No hay retroceso ni animación de muerte: el enemigo desaparece al morir. Sin estado `Flee` ni facciones (plan 016 §6, P14).
- Las cajas aparecen en ejecución y no están en el navmesh: un enemigo puede engancharse con una.
- Modelos y animaciones provisionales de primitivas (el pase de arte es ACTION_PLAN 4.4).
- `get_nodes_in_group` en cada paso crea un array por enemigo y fotograma; medir en Android (R-006-28).

## Cómo extenderlo

- Enemigo nuevo: `.tres` de `EnemyData` en `resources/enemies/` (valores a BALANCE primero), registrarlo en el catálogo,
  con su `ai`, `drop_table` y `piece_drop` si procede. Si comparte población, una entrada en `enemy_spawns`; si no,
  su escena con `enemy.gd`, su pool y una `Population` nueva **al final** del enum con su `rules_for` y sus flujos.
- Otro comportamiento: nuevo `EnemyAiData`. Una subclase de `Enemy` solo con la primera diferencia de comportamiento real.

## Tests

| Archivo | Verifica |
|---|---|
| `tests/unit/test_enemy_brain.gd` | Transiciones, ritmo de golpes, determinismo con semilla |
| `tests/unit/test_health_component.gd`, `test_object_pool.gd` | Daño y curación; `acquire`, `release`, `prewarm` |
| `tests/unit/test_enemy_resources.gd` | `.tres` de enemigos e IA (zombies y robot) frente a BALANCE, IA propia del robot, nombre ES/EN |
| `tests/unit/test_zone_population.gd` | Reparto de tipos y marcadores |
| `tests/integration/test_enemy.gd` | Enemigo con navmesh, golpe, batería agotada, reutilización limpia, `enemy_killed` una vez, destello, drop |
| `tests/integration/test_hostile_robot.gd` | Escena, IA propia, detección en el suelo, golpe cada intervalo y desgaste, combate, XP y un drop con todo |
| `tests/integration/test_enemy_spawner.gd` | Colocación determinista, despawn al pool, `rules_for`, zombies fijados (R-016-22), marcadores del robot, muertos |
| `tests/integration/test_robot_hit.gd` | `Robot.receive_hit` y `hit_received` |
