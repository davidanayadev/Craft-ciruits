# Mundo y zonas

> La escena `Main` mantiene el esqueleto persistente y carga una zona de granja generada a partir de la semilla del mundo.
> Specs: [004](../../specs/004-green-zone/spec.md), [006](../../specs/006-zombies/spec.md), [008](../../specs/008-death-recovery/spec.md) · Última actualización: spec 008 (visitas y repoblación)

## Piezas

| Pieza | Tipo | Archivo | Responsabilidad |
|---|---|---|---|
| `Main` | Escena | `game/scenes/main.tscn`, `main.gd` | Esqueleto (`World`, `ZoneSlot`, `ZombiePool`, `Players`, `UI`); genera la zona, coloca al robot, cablea señales |
| `FarmZone` | Escena | `game/scenes/farm_zone/farm_zone.gd`, `farm_zone_green.tscn` | Suelo (`GridMap`), decoración, límites, marcadores, `generate()`, `spawn_enemies()` |
| `ZoneData` | Resource | `game/scripts/data/zone_data.gd` | `zone_id`, tamaño, rango de cajas y de enemigos, entradas de spawn |
| `green_zone.tres` | Recurso | `game/resources/zones/green_zone.tres` | Datos de la zona verde |
| `ZonePopulation` | Sistema puro | `game/scripts/systems/zone_population.gd` | Elige marcadores de cajas y los enemigos de una visita |
| `SeededRng` | Util | `game/scripts/util/seeded_rng.gd` | Deriva semillas por (mundo, zona, flujo, índice) |
| `WorldGridConfigData` | Resource | `game/scripts/data/world_grid_config_data.gd` | Tamaño de la celda del mapa global (`world_grid.tres`) |
| `DevWorldConfigData` | Resource | `game/scripts/data/dev_world_config_data.gd` | Semilla fija de desarrollo (`dev_world.tres`) |
| `GameManager` | Autoload | `game/scripts/autoload/game_manager.gd` | `get_world_seed()` (de `dev_world.tres`), contador de visitas por `zone_id` y `zone_visit_changed` |
| `DroppedItemSpawner` | Nodo | `game/scenes/entities/dropped_item_spawner.gd` | Bajo `World/DroppedItems`, fuera de la zona (ver [death.md](death.md)) |
| `green_zone_navmesh.tres` | Recurso | `game/resources/zones/green_zone_navmesh.tres` | `NavigationMesh` horneado de la zona |
| `ZombieSpawner` | Nodo | `game/scenes/farm_zone/zombie_spawner.gd` | Coloca zombis (ver [enemies.md](enemies.md)) |

## Cómo funciona

1. `Main._ready()` llama `_zone.generate(GameManager.get_world_seed(), visita)` con
   `GameManager.get_visit_count(zone_id)`; la zona nunca lee la semilla por sí sola.
2. `generate()` (una sola vez; la segunda llamada es `push_error`) crea un RNG con
   `SeededRng.create(seed, zone_id, STREAM_BOX_PLACEMENT)` y `ZonePopulation.pick_box_markers()` elige cuántas cajas
   y en qué marcadores de `%BoxMarkers`.
3. Por cada marcador elegido instancia `box_scene`, la coloca en el transform del marcador y le pasa su semilla de
   botín (flujo `box_loot`, visita e índice = marcador, con `derive_seed_for_visit`). Ver [loot.md](loot.md).
   Cuántas cajas y dónde no dependen de la visita; su contenido sí.
4. `Main._spawn_enemies()` precalienta el pool con `enemy_count_max` y llama `zone.spawn_enemies(seed, visita, pool)`;
   los enemigos dependen de la visita. El pool vive bajo `World`, no en la zona.
5. `Main` coloca al robot en `get_spawn_position()` y conecta `box_opened` para abrir la pantalla de botín.
6. Navegación: `farm_zone_green.tscn` contiene un `NavigationRegion3D` (`Navigation`) con el navmesh horneado en el
   editor a partir de los nodos del grupo `navigation_mesh_source_group` (`Ground`, `Decoration`, `Boundaries`).
   Los zombis lo usan con `NavigationAgent3D`.
7. Todas las posiciones son locales a la zona, cuyo origen es el centro de su celda de la cuadrícula global.

### Visitas y repoblación (spec 008)

1. `GameManager` guarda un contador por `zone_id` (0 si la zona no está, `ZonePopulation.FIRST_VISIT`). Generar o
   entrar no lo sube; hoy solo sube al morir (`increment_visit_count`, llamado por `DeathController`, ver
   [death.md](death.md)). Subirlo al salir por un punto de salida es de la spec 009.
2. `increment_visit_count` emite `zone_visit_changed(zone_id, visit)`. `Main` la escucha y, si es la zona cargada,
   llama en diferido a `FarmZone.repopulate(seed, visit, pool)` y después a `discard_expired_now()`.
3. `repopulate` devuelve los zombis al pool, coloca los de la visita nueva y **sustituye** cada caja por una nueva,
   cerrada, en el mismo marcador (`queue_free` de la vieja; lo que quedaba dentro se descarta).
4. Los objetos caídos cuelgan de `World/DroppedItems`, no de la zona: sobreviven a la repoblación.

`SeededRng.derive_seed` = SHA-256 de (semilla s64, zona x/y s32, índice s32, nombre del flujo UTF-8); los 8 primeros
bytes son la semilla. `derive_seed_for_visit(seed, zone, flujo, visita, índice)` encadena dos `derive_seed` (primero la
visita, luego el elemento), así que las semillas anteriores no cambian. Flujos: `box_placement`, `box_loot`,
`enemy_spawn`, `enemy_brain`, `enemy_drop`.

## Datos

| Recurso | Clase | Valores en BALANCE |
|---|---|---|
| `resources/zones/green_zone.tres` | `ZoneData` | [§7.1](../../BALANCE.md) (cajas, enemigos, tamaño), reposición [§7.2](../../BALANCE.md) |
| `resources/config/world_grid.tres` | `WorldGridConfigData` | [§7](../../BALANCE.md) (celda del mapa global) |
| `resources/config/dev_world.tres` | `DevWorldConfigData` | No es balance: solo hace reproducible la zona |

## Decisiones

| Decisión | Por qué | Fuente |
|---|---|---|
| Mundos por semilla; zona generada con `seed + zone_id` y RNG propio, nunca el aleatorio global | Mundo idéntico en cada carga | R-004-09..11, [constitución P9](../../specs/constitution.md), [CLAUDE.md](../../CLAUDE.md) |
| Flujos separados de RNG | Añadir un uso de azar no mueve lo ya colocado | comentario de `seeded_rng.gd` |
| Derivación SHA-256 con layout fijo de bytes | Un servidor no Godot puede reproducirla; cambiarla exige migrar guardados | comentario de `seeded_rng.gd` |
| Las posiciones se guardan como (`zone_id`, posición local) | Mundo de celdas acotadas | [SPECS §26](../../SPECS.md), [CLAUDE.md](../../CLAUDE.md) |
| Navmesh horneado en el editor, guardado como `.tres` externo | La zona es estática; no depende del spike 0.5 | [spec 006](../../specs/006-zombies/spec.md) (pregunta 3), [plan 006](../../specs/006-zombies/plan.md) |
| `ZombiePool` bajo `World`, no en la zona | Sobrevive a la zona y se reutiliza entre visitas | comentario de `main.gd` |
| `ZoneSlot` con la zona verde fija | Hasta que exista `ZoneLoader` (spec 009) | comentario de `main.gd` |
| Contador de visitas en `GameManager` (estado del mundo, no del jugador) | El mundo lo guarda; la 010 lo persistirá | R-008-06, R-008-34 |
| Semilla encadenada (visita, luego elemento) en vez de un campo nuevo en `derive_seed` | No cambia ninguna semilla ya fijada por tests | [plan 008 §1](../../specs/008-death-recovery/plan.md) |
| Repoblar sustituye las cajas en vez de reiniciarlas | Reiniciar obliga a deshacer la tirada y las conexiones de `LootBox` | [plan 008 §1](../../specs/008-death-recovery/plan.md) |

## Relación con otros sistemas

- [enemies.md](enemies.md): spawner, pool y zombis. [loot.md](loot.md): cajas. [interaction.md](interaction.md) y [ui.md](ui.md): `Main` cablea el HUD y las pantallas.
- Usa [foundation.md](foundation.md) (`GameManager`, ajustes) y [data_catalog.md](data_catalog.md).

## Trampas y límites

- Cada zona debe tener al menos tantos marcadores como `box_count_max` y `enemy_count_max`; si no, `push_error`.
- El orden de llamadas al RNG en `ZonePopulation` es un contrato con los mundos guardados.
- `Array.shuffle()` y `randf()` usan el RNG global y están prohibidos en código del juego (lo vigila `test_no_global_rng.gd`).
- `WorldGridConfigData` solo lo leen los tests hoy; la cuadrícula global y el cambio de zona llegan con el spec 009.
- `DevWorldConfigData` se sustituye por la semilla del mundo guardado en el spec 010. No hay guardado ni base todavía.
- Los contadores de visita viven en memoria y se pierden al cerrar el juego (spec 010). `clear_visit_counts()` solo lo
  usan los tests: las suites que instancian `main.tscn` lo llaman antes de instanciar, porque `Main._ready` lee el contador.
- El contenido de las cajas de la visita 0 cambió respecto a la spec 004 por la derivación nueva.
- `generate()` y `repopulate()` reciben la visita; `repopulate` antes de `generate` es `push_error`.
- Si cambias la geometría de la zona hay que volver a hornear `green_zone_navmesh.tres` en el editor.
- El navmesh de zonas generadas en runtime depende del spike de la Tarea 0.5 (ver [CLAUDE.md](../../CLAUDE.md), huecos abiertos).
- `despawn_enemies()` debe llamarse antes de descargar la zona; aún no lo hace nadie.

## Cómo extenderlo

Zona nueva: escena con los mismos nodos únicos (`%SpawnPoint`, `%BoxMarkers`, `%Boxes`, `%EnemyMarkers`, `%ZombieSpawner`),
un `ZoneData` con su `zone_id` y un navmesh propio. Otro tipo de población: nuevo flujo en `SeededRng` y función en `ZonePopulation`.

## Tests

| Archivo | Verifica |
|---|---|
| `tests/unit/test_seeded_rng.gd` | Misma entrada, misma secuencia; respuestas conocidas (contrato) |
| `tests/unit/test_no_global_rng.gd` | Sin RNG global en `scripts/` y `scenes/` |
| `tests/unit/test_zone_population.gd` | Cajas y enemigos: rangos, marcadores distintos, errores |
| `tests/unit/test_zone_resources.gd` | `zone_id`, celda y datos de zona contra BALANCE |
| `tests/unit/test_game_manager.gd` | Semilla desde `dev_world.tres`; contador de visitas (empieza en 0, por zona, emite señal) |
| `tests/integration/test_green_zone.gd` | Suelo, colisiones, límites, misma semilla = mismas cajas; contenido por visita, posiciones estables, `repopulate` |
| `tests/integration/test_main_scene.gd` | Zona cargada, robot en el punto de aparición; generar no cuenta visita; cambio de visita repuebla |
| `tests/integration/test_zombie_spawner.gd` | Navmesh cubre la zona (R-006-20) y spawn |
