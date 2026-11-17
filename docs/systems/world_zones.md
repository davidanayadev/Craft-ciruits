# Mundo y zonas

> La escena `Main` mantiene el esqueleto persistente; `ZoneLoader` carga una zona cada vez ([travel.md](travel.md)).
> La zona de granja se genera a partir de la semilla del mundo y de la visita.
> Specs: [004](../../specs/004-green-zone/spec.md), [006](../../specs/006-zombies/spec.md), [008](../../specs/008-death-recovery/spec.md), [009](../../specs/009-base-placement-charging/spec.md), [010](../../specs/010-save-profile-world/spec.md) · Última actualización: spec 010 (Mundo guardado, `ZoneMemory`)

## Piezas

| Pieza | Tipo | Archivo | Responsabilidad |
|---|---|---|---|
| `Main` | Escena | `game/scenes/main.tscn`, `main.gd` | Esqueleto (`World`, `ZoneSlot` vacío al arrancar, `ZombiePool`, `Players`, `UI`); carga el guardado con `SaveFlow`, viaja a la posición guardada o a la base y cablea señales |
| `Zone` | Clase base | `game/scenes/zones/zone.gd` | Contrato común de `FarmZone` y `BaseZone` ([travel.md](travel.md)) |
| `FarmZone` | Escena (`extends Zone`) | `game/scenes/farm_zone/farm_zone.gd`, `farm_zone_green.tscn` | Suelo (`GridMap`), decoración, límites, marcadores, `ExitPoint`, `generate()`, `populate()`, `get_visit_state()`, `spawn_enemies()` |
| `ZoneData` | Resource | `game/scripts/data/zone_data.gd` | `zone_id`, `kind`, `scene_path`, tamaño, rango de cajas y de enemigos, entradas de spawn |
| `green_zone.tres` | Recurso | `game/resources/zones/green_zone.tres` | Datos de la zona verde (`FARM`); la base es [base.md](base.md) |
| `ZonePopulation` | Sistema puro | `game/scripts/systems/zone_population.gd` | Elige marcadores de cajas y los enemigos de una visita |
| `SeededRng` | Util | `game/scripts/util/seeded_rng.gd` | Deriva semillas por (mundo, zona, flujo, índice) |
| `WorldGridConfigData` | Resource | `game/scripts/data/world_grid_config_data.gd` | Tamaño de la celda del mapa global (`world_grid.tres`) |
| `ZoneMemory` | Nodo (bajo `World`) | `game/scenes/zones/zone_memory.gd` | Estado de la visita en curso de cada granja (cajas abiertas, enemigos muertos); dueño de guardado `farm_visits` |
| `GameManager` | Autoload | `game/scripts/autoload/game_manager.gd` | Mundo en juego (`begin_world`, `get_world_seed()`), contador de visitas por `zone_id` (dueño de guardado `zone_visits`) y `zone_visit_counted` |
| `DroppedItemSpawner` | Nodo | `game/scenes/entities/dropped_item_spawner.gd` | Bajo `World/DroppedItems`, fuera de la zona (ver [death.md](death.md)) |
| `green_zone_navmesh.tres` | Recurso | `game/resources/zones/green_zone_navmesh.tres` | `NavigationMesh` horneado de la zona |
| `ZombieSpawner` | Nodo | `game/scenes/farm_zone/zombie_spawner.gd` | Coloca zombis y recuerda los índices muertos (`get_dead_indices`, ver [enemies.md](enemies.md)) |

## Cómo funciona

1. `ZoneLoader._populate` llama `farm.populate(seed, visita, pool, estado)` con `GameManager.get_visit_count(zone_id)` y
   el estado que `ZoneMemory.take_state` guarda de esa visita (`{}` si no hay); `populate` es `generate` más restaurar
   cajas abiertas y colocar los enemigos menos los muertos. La zona nunca lee la semilla por sí sola.
2. `generate()` (una sola vez; la segunda llamada es `push_error`) crea un RNG con
   `SeededRng.create(seed, zone_id, STREAM_BOX_PLACEMENT)` y `ZonePopulation.pick_box_markers()` elige cuántas cajas
   y en qué marcadores de `%BoxMarkers`.
3. Por cada marcador elegido instancia `box_scene`, la coloca en el transform del marcador y le pasa su semilla de
   botín (flujo `box_loot`, visita e índice = marcador, con `derive_seed_for_visit`). Ver [loot.md](loot.md).
   Cuántas cajas y dónde no dependen de la visita; su contenido sí.
4. `ZoneLoader` precalienta el pool con `enemy_count_max`; `populate` llama a `spawn_enemies` (con los índices muertos
   de la visita, que no se colocan pero sí consumen su semilla); los enemigos dependen de la visita. El pool vive bajo `World`, no en la zona.
5. `ZoneLoader` coloca al robot en `get_spawn_position()`; `Main._on_zone_loaded` conecta `box_opened` y
   `enemy_loot_dropped` de la zona recién cargada.
6. Navegación: `farm_zone_green.tscn` contiene un `NavigationRegion3D` (`Navigation`) con el navmesh horneado en el
   editor a partir de los nodos del grupo `navigation_mesh_source_group` (`Ground`, `Decoration`, `Boundaries`).
   Los zombis lo usan con `NavigationAgent3D`.
7. Todas las posiciones son locales a la zona, cuyo origen es el centro de su celda de la cuadrícula global.

### Visitas y repoblación (spec 008)

1. `GameManager` guarda un contador por `zone_id` (0 si la zona no está, `ZonePopulation.FIRST_VISIT`). Generar o
   entrar no lo sube. Sube al morir en una zona `FARM` (`DeathController`, ver [death.md](death.md)) y al salir de
   una `FARM` por su punto de salida, cuando ya está descargada (`ZoneLoader`, [travel.md](travel.md)). Una zona
   `BASE` nunca lo sube (`ZoneData.counts_visits()`).
2. `increment_visit_count` emite `zone_visit_counted(zone_id, visit)`. `ZoneLoader` (antes `Main`) la escucha y, si es
   la `FarmZone` cargada y no hay viaje, llama en diferido a `FarmZone.repopulate(seed, visit, pool)` y después a
   `discard_expired_now()`.
3. `repopulate` devuelve los zombis al pool, coloca los de la visita nueva y **sustituye** cada caja por una nueva,
   cerrada, en el mismo marcador (`queue_free` de la vieja; lo que quedaba dentro se descarta).
4. Los objetos caídos cuelgan de `World/DroppedItems`, no de la zona: sobreviven a la repoblación.

### Mundo y guardado (spec 010)

1. El Mundo (id, nombre, semilla, ruleset) lo da `SaveManager` a `GameManager.begin_world`, que limpia contadores y
   zona actual. `GameManager` ya no lee ningún recurso de desarrollo ([data_catalog.md](data_catalog.md), [save.md](save.md)).
2. `GameManager.from_save_data` repone contadores sin emitir `zone_visit_counted`: cargar no cuenta visita.
3. `ZoneMemory` guarda, por zona, la visita y `FarmZone.get_visit_state()` (`boxes` abiertas por marcador con su
   contenido, y `dead_enemies`). `ZoneLoader` llama `unbind_farm()` al descargar y `take_state` al cargar; el estado solo
   vale si coincide la visita, y al subir el contador se olvida. Una caja restaurada (`LootBox.restore_opened`) no emite
   `loot_generated` ni `opened`.

`SeededRng.derive_seed` = SHA-256 de (semilla s64, zona x/y s32, índice s32, nombre del flujo UTF-8); los 8 primeros
bytes son la semilla. `derive_seed_for_visit(seed, zone, flujo, visita, índice)` encadena dos `derive_seed` (primero la
visita, luego el elemento), así que las semillas anteriores no cambian. Flujos: `box_placement`, `box_loot`,
`enemy_spawn`, `enemy_brain`, `enemy_drop`.

## Datos

| Recurso | Clase | Valores en BALANCE |
|---|---|---|
| `resources/zones/green_zone.tres` | `ZoneData` | [§7.1](../../BALANCE.md) (cajas, enemigos, tamaño), reposición [§7.2](../../BALANCE.md) |
| `resources/config/world_grid.tres` | `WorldGridConfigData` | [§7](../../BALANCE.md) (celda del mapa global) |

## Decisiones

| Decisión | Por qué | Fuente |
|---|---|---|
| Mundos por semilla; zona generada con `seed + zone_id` y RNG propio, nunca el aleatorio global | Mundo idéntico en cada carga | R-004-09..11, [constitución P9](../../specs/constitution.md), [CLAUDE.md](../../CLAUDE.md) |
| Flujos separados de RNG | Añadir un uso de azar no mueve lo ya colocado | comentario de `seeded_rng.gd` |
| Derivación SHA-256 con layout fijo de bytes | Un servidor no Godot puede reproducirla; cambiarla exige migrar guardados | comentario de `seeded_rng.gd` |
| Las posiciones se guardan como (`zone_id`, posición local) | Mundo de celdas acotadas | [SPECS §26](../../SPECS.md), [CLAUDE.md](../../CLAUDE.md) |
| Navmesh horneado en el editor, guardado como `.tres` externo | La zona es estática; no depende del spike 0.5 | [spec 006](../../specs/006-zombies/spec.md) (pregunta 3), [plan 006](../../specs/006-zombies/plan.md) |
| `ZombiePool` bajo `World`, no en la zona | Sobrevive a la zona y se reutiliza entre visitas | comentario de `main.gd` |
| `ZoneSlot` vacío en `main.tscn`; `ZoneLoader` carga una zona cada vez | Una sola zona cargada, el mundo no es continuo | R-009-02, R-009-08, [architecture §6](../../specs/architecture.md) |
| Contador de visitas en `GameManager` (estado del mundo, no del jugador) | Es estado del mundo y ahora lo guarda `SaveManager` | R-008-06, R-008-34, [plan 010](../../specs/010-save-profile-world/plan.md) |
| El estado de la visita vive en `ZoneMemory` bajo `World`, no en la zona | Sobrevive a descargar la zona, como los objetos caídos | [plan 010](../../specs/010-save-profile-world/plan.md) (§2, archivos) |
| Se renombró `zone_visit_changed` a `zone_visit_counted` | Es un hecho, no un estado; cargar no la emite | [plan 010 §1.1 D15, D19](../../specs/010-save-profile-world/plan.md) |
| Semilla encadenada (visita, luego elemento) en vez de un campo nuevo en `derive_seed` | No cambia ninguna semilla ya fijada por tests | [plan 008 §1](../../specs/008-death-recovery/plan.md) |
| Repoblar sustituye las cajas en vez de reiniciarlas | Reiniciar obliga a deshacer la tirada y las conexiones de `LootBox` | [plan 008 §1](../../specs/008-death-recovery/plan.md) |

## Relación con otros sistemas

- [enemies.md](enemies.md): spawner, pool y zombis. [loot.md](loot.md): cajas. [interaction.md](interaction.md) y [ui.md](ui.md): `Main` cablea el HUD y las pantallas.
- Usa [foundation.md](foundation.md) (`GameManager`, ajustes) y [data_catalog.md](data_catalog.md).

## Trampas y límites

- Cada zona debe tener al menos tantos marcadores como `box_count_max` y `enemy_count_max`; si no, `push_error`.
- El orden de llamadas al RNG en `ZonePopulation` es un contrato con los mundos guardados.
- `Array.shuffle()` y `randf()` usan el RNG global y están prohibidos en código del juego (lo vigila `test_no_global_rng.gd`).
- `WorldGridConfigData` solo lo leen los tests hoy; no hay mapa global ni más zonas que la base `(0, -1)` y la verde.
- La semilla viene del Mundo cargado o creado; los tests que instancian `main.tscn` arrancan un Mundo con
  `SaveTestSupport.start_world()` ([save.md](save.md)). `clear_visit_counts()` solo lo usan los tests.
- Una caja restaurada abierta y un enemigo muerto solo se recuerdan durante la visita en curso; al subir el contador
  se descartan.
- El contenido de las cajas de la visita 0 cambió respecto a la spec 004 por la derivación nueva.
- `generate()` y `repopulate()` reciben la visita; `repopulate` antes de `generate` es `push_error`.
- Si cambias la geometría de la zona hay que volver a hornear `green_zone_navmesh.tres` en el editor.
- El navmesh de zonas generadas en runtime depende del spike de la Tarea 0.5 (ver [CLAUDE.md](../../CLAUDE.md), huecos abiertos).
- `despawn_enemies()` debe llamarse antes de descargar la zona; lo hace `ZoneLoader._unload_current`.
- Las suites que instancian `main.tscn` ya arrancan en la base: viajan a la zona verde y esperan `travel_finished`.
- Toda escena de zona necesita `%SpawnPoint` y `%ExitPoint` (los exige `Zone`).

## Cómo extenderlo

Zona de granja nueva: escena `FarmZone` con los mismos nodos únicos (`%SpawnPoint`, `%ExitPoint`, `%BoxMarkers`,
`%Boxes`, `%EnemyMarkers`, `%ZombieSpawner`), un `ZoneData` (`kind FARM`, `scene_path`) listado en el catálogo y un
navmesh propio. Otro tipo de población: nuevo flujo en `SeededRng` y función en `ZonePopulation`.

## Tests

| Archivo | Verifica |
|---|---|
| `tests/unit/test_seeded_rng.gd` | Misma entrada, misma secuencia; respuestas conocidas (contrato) |
| `tests/unit/test_no_global_rng.gd` | Sin RNG global en `scripts/` y `scenes/` |
| `tests/unit/test_zone_population.gd` | Cajas y enemigos: rangos, marcadores distintos, errores |
| `tests/unit/test_zone_resources.gd` | `zone_id`, celda y datos de zona contra BALANCE |
| `tests/unit/test_game_manager.gd` | `begin_world`, contador de visitas (empieza en 0, por zona, emite señal), guardado sin señales |
| `tests/integration/test_zone_memory.gd` | Estado por visita, `populate`, enemigos muertos y cajas abiertas al descargar y guardar |
| `tests/integration/test_green_zone.gd` | Suelo, colisiones, límites, misma semilla = mismas cajas; contenido por visita, posiciones estables, `repopulate` |
| `tests/integration/test_main_scene.gd` | Arranque en la base, zona verde tras viajar; generar no cuenta visita; cambio de visita repuebla |
| `tests/integration/test_zone_loader.gd` | Ver [travel.md](travel.md) |
| `tests/integration/test_zombie_spawner.gd` | Navmesh cubre la zona (R-006-20) y spawn |
