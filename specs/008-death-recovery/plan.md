# Plan 008 — Muerte, `RulesetData`, objetos caídos y recuperación

| Campo | Valor |
|---|---|
| **Spec** | [spec.md](spec.md) (debe estar *Aprobado*) |
| **Estado** | Planificado (2026-11-16) |

> Escrito contra el código de la spec 007 tal como está en el árbol de trabajo (`EventBus`, `Robot.player_uid`,
> `ExperienceComponent`, `HurtboxComponent`). La 007 debe estar *Hecho* antes de implementar; si cambia antes de
> cerrarse, se revisan §1 "Muerte" y §3.

## 1. Enfoque

**Capas (architecture §3).**

| Capa | Piezas |
|---|---|
| Datos | `RulesetData` (`normal.tres`), `DeathConfigData` (duración de la transferencia), `DroppedItemConfigData` (caducidad), `EnemyData.drop_table`, `loot/zombie_drop.tres`, `DevWorldConfigData.ruleset_id` |
| Sistemas | `DroppedItemRules` (caducidad), `InventoryRules.split` (dividir una pila), `SeededRng.derive_seed_for_visit` (semilla con visita e índice), `ZonePopulation.FIRST_VISIT` |
| Servicios | `ITimeService` + `LocalTimeService` (carpeta nueva `scripts/services/`, architecture §4) |
| Componentes | `InventoryComponent.take_amount_from` (mover parte de una pila), `ExperienceComponent.reset`, `MeleeAttackComponent.cancel_swing` |
| Entidades | `DroppedItem` (objeto caído, con su `InventoryComponent` y su `InteractableComponent`), `DroppedItemSpawner` (crea, caduca y devuelve al pool), `Robot.request_throw`, `Zombie` (tirada de su tabla), `FarmZone.repopulate` |
| Reglas de muerte | `DeathController` (nodo de `main.tscn`): aplica la reacción del ruleset a cada robot enlazado |
| Presentación | `TransferScreen` (sustituye a `GameOverScreen`), selector de cantidad y botón "Tirar" en `InventoryScreen`, `QuantitySelector` |
| Autoloads | `GameManager` (ruleset, contador de visitas, reloj), `EventBus` (`player_died`, `player_respawned`), `DataRegistry` (`get_ruleset`). Ninguno nuevo |

**Ruleset (R-008-01 a 04).**
- `RulesetData`: `id`, `drops_inventory`, `keeps_xp`, `keeps_core`, `respawn_battery_ratio`. `normal.tres` en
  `resources/rulesets/`, listado en `DataCatalog.rulesets` (architecture §8 ya lo prevé).
- `DevWorldConfigData` gana `ruleset_id`. `GameManager._ready` lo resuelve con `DataRegistry.get_ruleset(id)`
  (`DataRegistry` va antes en la lista de autoloads). Es el mismo camino que usará la spec 010: el archivo de Mundo
  guarda el id, nunca el recurso.
- Lo que aplica la 008: `drops_inventory` (suelta o no el inventario), `keeps_xp` (si es `false`, la XP vuelve a 0)
  y `respawn_battery_ratio` (batería al reaparecer = máxima × ratio). `keeps_core` solo se declara: lo aplica la
  spec 015, que crea las ranuras (pregunta 4).
- Ningún script compara el id ni el nombre del ruleset: `DeathController` solo lee sus campos (R-008-03, con un
  test que busca esas comparaciones y otro con un ruleset hecho a mano).
- No hay campo "reaparece sí/no": el Hardcore de v1.1 lo añadirá con su comportamiento. Añadirlo ahora obligaría a
  programar una rama que el PMV no tiene (P14).

**Contador de visitas y reposición (R-008-06 a 09).**
- `GameManager` guarda `Dictionary[Vector2i, int]`. `get_visit_count(zone_id)` devuelve
  `ZonePopulation.FIRST_VISIT` (0) si la zona no está. `increment_visit_count(zone_id)` suma uno y emite la señal
  local `zone_visit_changed(zone_id, visit)`. Generar o entrar no lo toca.
- `FIRST_VISIT` se mueve de `ZombieSpawner` a `ZonePopulation` (capa de sistemas), para que `GameManager` no
  dependa de un script de escena y el 0 viva en un solo sitio. Cambia la referencia en `main.gd` y en dos archivos
  de test (renombre mecánico, sin cambiar lo que comprueban).
- `Main` escucha `zone_visit_changed`; si es la zona cargada, repuebla en diferido (la señal llega dentro de un paso
  de física). En la 009 lo hará `ZoneLoader`.
- **Semilla con dos índices (pregunta 2).** `SeededRng.derive_seed_for_visit(world_seed, zone_id, stream, visit,
  index)` = `derive_seed(derive_seed(world_seed, zone_id, stream, visit), zone_id, stream, index)`. Primero la
  semilla de la visita, después la del elemento. `derive_seed` no cambia, así que sus respuestas fijadas en
  `test_seeded_rng.gd` y las posiciones de cajas y zombies de las specs 004 y 006 siguen igual. Se fija con un test
  de respuesta conocida propio.
- Cajas: contenido con `derive_seed_for_visit(seed, zone_id, STREAM_BOX_LOOT, visit, marker_index)`. Número y
  posición siguen saliendo de `STREAM_BOX_PLACEMENT` sin visita (R-008-08). El contenido de la visita 0 cambia
  respecto al de hoy; ningún test lo fija y no hay partidas guardadas.
- `FarmZone.generate(world_seed, visit)` recibe la visita. `FarmZone.repopulate(world_seed, visit, pool)` devuelve
  los zombies al pool, coloca los de la visita nueva y **sustituye** cada caja por una nueva y cerrada en su mismo
  marcador (`queue_free` de la vieja). Lo que quedaba dentro se descarta con la caja (R-008-09).
- Por qué sustituir y no reiniciar la caja: `LootBox` conecta `inventory_changed` al tirar y da a su contenido una
  ranura por pila; reiniciarla pide deshacer las dos cosas. Son 5-7 nodos creados en el fotograma de la muerte, con
  la pantalla de transferencia ya puesta y justo antes de congelar el mundo, no en mitad de la partida (P12).

**Objeto caído (R-008-10 a 18).**
- `DroppedItem` (`Node3D`): malla placeholder, `%Interactable` (`PROMPT_PICK_UP`) y `%Contents`
  (`InventoryComponent`), igual que `LootBox`. Sin cuerpo de colisión: el robot pasa por encima. Guarda `uid`
  (`Uid.generate()`), `zone_id`, `local_position` (respecto a la zona, fijada al caer) y `dropped_at_unix`.
- **Ranuras del contenido.** `InventoryComponent` nace con 0 ranuras y solo crece, así que gana
  `clear(slot_count)`: lo vacía y lo deja con ese número de ranuras, para contenedores reutilizados.
  `DroppedItem.setup(..., slot_count)` lo llama con las ranuras del inventario de origen (muerte), con 1 (tirar) o
  con el número de pilas (zombie); `reset()` lo llama con 0.
- **Reutilización.** Soltar y recoger usan los métodos que ya existen en `InventoryComponent`, así que nunca se
  crean ni pierden unidades (R-008-11):
  - Soltar todo: `contents.take_from(inventario, todas las ranuras)`.
  - Soltar una parte: `contents.take_amount_from(inventario, ranura, cantidad)` (nuevo, abajo).
  - Material de un zombie: `contents.add_stacks(pilas)`.
  - Recoger: `inventario_del_jugador.take_from(contents, todas las ranuras)`. Entra lo que cabe en orden de ranura
    (R-008-13); si sobra, el inventario emite `overflowed` y el HUD ya enseña "Inventario lleno" (R-008-15, spec
    005). La hora de caída no se toca.
- `DroppedItem` solo conecta `interacted` a su recogida y emite `emptied(self)` al quedarse sin pilas. No sabe de
  pools ni del reloj.
- `DroppedItemSpawner` (`Node3D` bajo `World`, fuera de la zona): padre de los objetos activos. Los saca de
  `%DroppedItemPool`, les pone `uid`, zona y hora (`time_service.now_unix()`, R-008-20) y los devuelve al pool, en
  diferido, cuando se vacían o caducan (R-008-14). Al estar fuera de la zona, repoblarla no los toca (R-008-16).
- `bind_zone(zone_id, zone_root)` le dice qué zona está cargada: al soltar, el spawner calcula
  `zone_root.to_local(posición global)` y se lo da al objeto, que lo guarda (R-008-10, P9). Así el dato no depende
  de que la zona siga cargada (009). En la 009 lo llamará `ZoneLoader`.
- **Limpio al reutilizar (R-008-18).** `DroppedItem.reset()` deja `%Contents` sin pilas ni ranuras
  (`clear(0)`), borra `uid`, zona, posición y hora y desactiva el interactuable; `setup()` lo reactiva. El `InteractorComponent` puede seguir
  apuntando un paso de física a un objeto ya devuelto al pool: como está desactivado, `interact_with_target` no hace
  nada.
- **JSON (R-008-17).** `DroppedItem.to_data()`, sin parámetros, devuelve `{uid, zone_id: [x, y], position:
  [x, y, z], dropped_at, stacks: [{item_id, quantity}]}`. `DroppedItemSpawner.to_data()` devuelve la lista. Leerlo de vuelta
  (`from_data`) es de la spec 010.
- **Pilas fusionadas.** `take_from` apila con las reglas de `InventoryRules`: dos pilas parciales del mismo item
  caen como una. El total por item no cambia. Con piezas (`stack_max = 1`, spec 015) no hay fusión. Tirar una
  parte y volver a cogerla puede dejar dos pilas parciales del mismo item, que al morir se juntan: el "tal como
  estaban" del spec §5 se cumple por item y cantidad, no por ranura (§7).

**Caducidad (R-008-19 a 24).**
- `ITimeService.now_unix() -> int` y `LocalTimeService` en `scripts/services/`. `GameManager` crea el
  `LocalTimeService` y lo expone con `get_time_service()` (pregunta 8; architecture §3: los servicios se alcanzan
  solo desde autoloads). `Main` se lo pasa al `DroppedItemSpawner` por propiedad; los tests le pasan un
  `FakeTimeService`. El spawner nunca crea un reloj ni llama a `Time` (⚠️ en §6).
- `DroppedItemRules.is_expired(dropped_at_unix, now_unix, lifetime_s)`: `max(now − dropped_at, 0) >= lifetime_s`.
  Puro, con la hora por parámetro (R-008-21).
- `DroppedItemSpawner.discard_expired(now_unix)` devuelve al pool los caducados sin dar nada a nadie (R-008-22).
  Lo llaman:
  - Un `Timer` hijo del spawner, cada segundo (el reloj no da más resolución; valor técnico en la escena, no de
    BALANCE). Solo corre mientras hay objetos activos.
  - `Main` al poblar y al repoblar la zona, antes de devolver el control (R-008-23).
- La regla solo mira la hora de caída y el reloj: ni el contador de visitas, ni una pantalla abierta, ni los FPS
  (R-008-24). Con el mundo congelado por la transferencia el `Timer` se para; al reanudar, el primer tic descarta lo
  caducado.

**Muerte y reaparición (R-008-25 a 34).**
- `DeathController` (nodo de `main.tscn`) enlaza cada robot con `bind(robot)` y escucha su
  `battery.battery_depleted`, que sale una vez por llegada a 0 sea cual sea la causa (spec 003). En ese momento, en
  este orden:
  0. `robot.melee.cancel_swing()`: un robot muerto no golpea. La batería puede agotarse en `_move`, antes del
     `melee.tick` de ese mismo paso; sin esto, un impacto pendiente mataría a un zombie cuya devolución al pool
     quedaría en cola detrás de la repoblación, y devolvería un zombie vivo de la visita nueva.
  1. Si `ruleset.drops_inventory`: `dropped_items.drop_inventory(robot.inventory, robot.global_position)`. Con el
     inventario vacío no crea nada (R-008-27).
  2. Si no `ruleset.keeps_xp`: `robot.experience.reset()`. Las ranuras del inventario no se tocan (R-008-28).
  3. `GameManager.increment_visit_count(zone_id)` (R-008-07).
  4. `EventBus.player_died.emit(robot.player_uid)`, al final, para que quien escuche vea ya el inventario vacío
     (R-008-25).
- `Main` escucha `EventBus.player_died` y, solo si el uid es el del robot local: cierra todas las pantallas, bloquea
  el input, enseña `TransferScreen` y congela `World` en diferido (como hace hoy el game over). La repoblación
  diferida del paso 3 corre antes que la congelación.
- Durante la transferencia el robot no se mueve ni ataca (mundo congelado e input bloqueado), no interactúa
  (`request_interact` ya rechaza con la batería a 0) y no recibe golpes (`receive_hit` ya los ignora) (R-008-30).
- `TransferScreen.play()` dura `DeathConfigData.transfer_duration_s` y emite `finished`. Avanza con
  `advance(delta)`, llamado por su `_process` solo mientras se ve, así que los tests no esperan tiempo real. Es un
  `Control` a pantalla completa encima del HUD, fuera de `UIManager`: Escape o "atrás" no la cierran.
- Al terminar, `Main` llama a `death_controller.respawn(robot, zone.get_spawn_position())`, reanuda `World` y
  desbloquea el input. `respawn` calcula la batería (`máxima × respawn_battery_ratio`), llama a
  `robot.respawn_at(posición, batería)` y emite `EventBus.player_respawned(uid)` (R-008-31). Si el robot no está
  muerto, `push_error` y nada cambia.
- `Robot.respawn_at` es del robot, único dueño de su posición y su velocidad (architecture §3 regla 3): se coloca,
  pone la velocidad a 0 y carga con `battery.add`.
- **Punto de reaparición en un solo sitio** (pregunta 1): el argumento de esa llamada en `Main`. La 009 lo cambia
  por `ZoneLoader.travel_to(base)`.
- **Estado (R-008-34).** `DeathController` no guarda estado: "muerto" es "batería a 0 hasta `respawn`". Batería,
  inventario y XP siguen en los componentes del robot; la posición de la muerte, en el objeto caído. `GameManager`
  solo gana ruleset y contadores.
- **Dos muertes seguidas (R-008-32).** Cada muerte crea su objeto con su hora; el spawner no toca los anteriores.
- **Game over provisional (R-008-33).** Se borran `game_over_screen.gd/.tscn`, su test y las claves
  `GAME_OVER_TITLE` y `GAME_OVER_RESTART`. `Main` deja de recargar la escena.

**Material de los zombies (R-008-05, 35 a 37).**
- `EnemyData.drop_table: LootTableData` (`null` = no suelta nada). Los dos zombies comparten
  `loot/zombie_drop.tres`: chatarra 0-1 (BALANCE §3.1). Se tira con `LootSystem.roll`, la regla de §2.1.
- `ZombieSpawner` calcula para el zombie número `i` de la visita (orden de `pick_enemy_spawns`, por marcador)
  `derive_seed_for_visit(seed, zone_id, STREAM_ENEMY_DROP, visit, i)` y se lo pasa en `activate(..., drop_seed)`.
  No depende del orden de las muertes ni de recargar (R-008-36).
- `Zombie._on_died`: si hubo atacante y hay tabla, tira una vez y, si sale algo, emite `loot_dropped(stacks,
  global_position)`. `ZombieSpawner` y `FarmZone` lo reemiten (`enemy_loot_dropped`), como `box_opened`, y `Main`
  lo conecta a `dropped_items.drop_stacks`.

**Tirar items (R-008-38 a 43).**
- `InventoryRules.split(slots, slot_index, quantity) -> ItemStack`: la pila que sale; la ranura se queda con el
  resto (`null` si no queda nada). Ranura vacía, índice fuera de rango o cantidad fuera de `1..pila` → `null` y sin
  cambios (R-008-40). `InventoryRules.can_split` es la misma comprobación sin cambiar nada.
- `InventoryComponent.take_amount_from(source, slot_index, quantity) -> InventoryAddResult`: hermano de
  `take_from` para una parte de una ranura. Saca la pila que sale con `InventoryRules.split` sobre la copia de
  `source.get_slots()` (`null` → `ERR_INVALID_REQUEST`), mete lo que cabe y `source` pierde exactamente lo que
  entró con su `remove_from_slots`. La regla de dividir se escribe una sola vez. La spec de cofres lo reutiliza.
- `InventoryScreen`: la rejilla pasa a `interactive`. Tocar una pila la selecciona (celda resaltada) y enseña
  `%QuantitySelector` de 1 a la cantidad de la pila, empezando en la pila entera. `%ThrowButton` está desactivado
  sin selección (R-008-41). Al pulsarlo, la pantalla llama a `thrower.request_throw(ranura, cantidad)` y nada más
  (R-008-42). No se cierra ni pide confirmación (pregunta 7).
- Tras cada `inventory_changed`: si la ranura seleccionada quedó vacía, se quita la selección; si no, el selector
  se ajusta a lo que queda.
- `Robot.request_throw(slot_index, quantity)` emite `throw_requested(robot, slot_index, quantity)` salvo con la
  batería a 0. `Main` lo conecta a `dropped_items.drop_from_slot(robot.inventory, slot_index, quantity,
  robot.global_position)`. El robot no conoce el spawner. El `ActionResult` no vuelve a la pantalla: el selector no
  deja pedir una cantidad inválida, y si llega una, `Main` hace `push_error` con su `error_key`.
- El contexto de la pantalla gana `CONTEXT_THROWER` (el `Robot`). Sin él, el botón no se enseña: así los tests de
  la 005 que solo pasan el inventario siguen valiendo.
- `test_r_005_25_cells_cannot_be_pressed` deja de ser cierto: R-008-38 pide que se puedan tocar. Se sustituye por
  `test_r_008_38_*`, que conserva la comprobación de `focus_mode` (ver §7).

**Alternativas descartadas.**
- **Añadir un campo `visit` a la cabecera de `derive_seed`.** Un solo hash, pero cambia todas las semillas: obliga
  a reescribir las respuestas fijadas de `test_seeded_rng.gd` y `test_r_004_21_dev_seed_known_boxes`. El encadenado
  es igual de reproducible fuera de Godot (dos SHA-256) y no toca nada de lo que ya existe.
- **`TransferScreen` dentro de `UIManager`.** Escape y "atrás" la cerrarían.
- **Reiniciar las cajas en lugar de sustituirlas.** Ver "Contador de visitas".
- **Objetos caídos como hijos de la zona.** Al descargar la zona (009) se liberarían instancias del pool; fuera de
  la zona, el mismo spawner sirve para la base.
- **`DroppedItem` con una lista propia de `ItemStack`.** Duplicaría las reglas de apilado y de "lo que cabe" de
  `InventoryComponent`.
- **Contexto de la pantalla con un `Callable` para tirar.** Sin tipo; `Robot.request_throw` es una petición del
  jugador con firma, como `request_interact`.
- **Contador de visitas o "muerto" en un componente del robot.** El contador es del mundo (R-008-06); "muerto" ya
  lo dice la batería.
- **`player_died` desde `BatteryComponent` o `Robot`.** El evento es la reacción del ruleset, no un hecho de la
  batería (architecture §7: "Lo emite: Ruleset").

## 2. Archivos

| Archivo (`game/…`) | Nuevo / Cambia | Responsabilidad |
|---|---|---|
| `scripts/data/ruleset_data.gd` | Nuevo | Reacción a la muerte como dato |
| `scripts/data/death_config_data.gd` | Nuevo | Duración de la transferencia (BALANCE §11) |
| `scripts/data/dropped_item_config_data.gd` | Nuevo | Caducidad (BALANCE §7.2) |
| `scripts/data/enemy_data.gd` | Cambia | `drop_table` |
| `scripts/data/dev_world_config_data.gd` | Cambia | `ruleset_id` |
| `scripts/data/data_catalog.gd` | Cambia | `rulesets`, `has_ruleset`, `get_ruleset`; el indexado pasa a una función común (tercer tipo, P2) |
| `scripts/services/i_time_service.gd`, `local_time_service.gd` | Nuevo | Contrato de reloj e implementación local |
| `scripts/systems/dropped_item_rules.gd` | Nuevo | Regla de caducidad |
| `scripts/systems/inventory_rules.gd` | Cambia | `split`, `can_split` |
| `scripts/systems/zone_population.gd` | Cambia | `FIRST_VISIT` |
| `scripts/util/seeded_rng.gd` | Cambia | `derive_seed_for_visit`, `STREAM_ENEMY_DROP` |
| `scripts/components/inventory_component.gd` | Cambia | `take_amount_from`, `clear` |
| `scripts/components/experience_component.gd` | Cambia | `reset` |
| `scripts/components/melee_attack_component.gd` | Cambia | `cancel_swing` |
| `scripts/autoload/game_manager.gd` | Cambia | Ruleset, contador de visitas, reloj |
| `scripts/autoload/data_registry.gd` | Cambia | `get_ruleset` |
| `scripts/autoload/event_bus.gd` | Cambia | `player_died`, `player_respawned` |
| `scenes/entities/dropped_item.gd` + `.tscn` | Nuevo | Objeto caído |
| `scenes/entities/dropped_item_spawner.gd` | Nuevo | Crea, caduca y devuelve al pool |
| `scenes/death/death_controller.gd` | Nuevo | Reacción del ruleset a la muerte y reaparición |
| `scenes/ui/transfer_screen.gd` + `.tscn` | Nuevo | "Transferencia de Consciencia" |
| `scenes/ui/quantity_selector.gd` + `.tscn` | Nuevo | − / + y deslizador |
| `scenes/ui/inventory_screen.gd` + `.tscn` | Cambia | Selección, selector y botón "Tirar" |
| `scenes/ui/inventory_grid.gd`, `inventory_slot.gd` + `.tscn` | Cambia | Celda seleccionada |
| `scenes/ui/game_over_screen.gd` + `.tscn` | **Se borra** | R-008-33 |
| `scenes/entities/robot.gd` | Cambia | `request_throw`, `throw_requested`, `respawn_at` |
| `scenes/entities/zombie.gd` | Cambia | `drop_seed` en `activate`, tirada y `loot_dropped` |
| `scenes/farm_zone/zombie_spawner.gd` | Cambia | Semilla de drop por índice, reemite `enemy_loot_dropped`, sin `FIRST_VISIT` |
| `scenes/farm_zone/farm_zone.gd` | Cambia | `generate(seed, visit)`, `repopulate`, reemite `enemy_loot_dropped` |
| `scenes/main.gd` + `main.tscn` | Cambia | `%DroppedItemPool`, `%DroppedItems`, `%DeathController`, `%TransferScreen`; sin game over |
| `resources/rulesets/normal.tres` | Nuevo | Ruleset `NORMAL` |
| `resources/config/death.tres`, `dropped_items.tres` | Nuevo | BALANCE §11 "Muerte", §7.2 |
| `resources/loot/zombie_drop.tres` | Nuevo | BALANCE §3.1 |
| `resources/enemies/zombie_slow.tres`, `zombie_fast.tres` | Cambia | `drop_table` |
| `resources/config/dev_world.tres` | Cambia | `ruleset_id = &"normal"` |
| `resources/data_catalog.tres` | Cambia | `rulesets` |
| `i18n/strings.csv` | Cambia | + `PROMPT_PICK_UP`, `TRANSFER_TITLE`, `INVENTORY_THROW`; − `GAME_OVER_TITLE`, `GAME_OVER_RESTART` |
| `tests/support/fake_time_service.gd` | Nuevo | Reloj falso para los tests (carpeta nueva, GUT no la recorre) |
| `tests/unit/test_ruleset_resources.gd` | Nuevo | R-008-01, 03, 04 |
| `tests/unit/test_dropped_item_rules.gd` | Nuevo | R-008-21, 24 |
| `tests/unit/test_time_service.gd` | Nuevo | R-008-19 |
| `tests/unit/test_inventory_rules.gd`, `test_inventory_component.gd` | Cambia | R-008-40, 11 |
| `tests/unit/test_seeded_rng.gd` | Cambia | R-008-08, 36 (derivación nueva) |
| `tests/unit/test_game_manager.gd` | Cambia | R-008-02, 06, 34 |
| `tests/unit/test_data_catalog.gd`, `test_enemy_resources.gd` | Cambia | R-008-01, 05 |
| `tests/unit/test_event_bus.gd` | Cambia | R-008-25, 31 (firmas) |
| `tests/unit/test_experience_component.gd`, `test_melee_attack_component.gd` | Cambia | `reset`, `cancel_swing` |
| `tests/unit/test_dropped_item.gd` | Nuevo | R-008-10 a 15, 17, 18 |
| `tests/unit/test_transfer_screen.gd` | Nuevo | R-008-29, 04 |
| `tests/unit/test_quantity_selector.gd` | Nuevo | R-008-38 |
| `tests/unit/test_inventory_screen.gd` | Cambia | R-008-38, 39, 41, 42 |
| `tests/unit/test_game_over_screen.gd` | **Se borra** | Con la pantalla |
| `tests/unit/test_hud.gd` | Cambia | Usa otra clave de prompt en lugar de `GAME_OVER_RESTART` |
| `tests/unit/test_no_global_rng.gd` | Cambia | `zombie.gd` entre los scripts vigilados |
| `tests/integration/test_dropped_item_spawner.gd` | Nuevo | R-008-14, 16, 18, 20, 22, 23, 32 |
| `tests/integration/test_death_controller.gd` | Nuevo | R-008-03, 07, 25 a 28, 31, 32 |
| `tests/integration/test_green_zone.gd`, `test_zombie_spawner.gd`, `test_zombie.gd` | Cambia | R-008-08, 09, 35, 36 |
| `tests/integration/test_robot_inventory.gd` | Cambia | R-008-39 (`request_throw`) |
| `tests/integration/test_robot_combat.gd` | Cambia | Su llamada a `zombie.activate` gana `drop_seed`; nada más |
| `tests/integration/test_hud_attack_input.gd` | Cambia | `GameManager.clear_visit_counts()` en `before_each` (instancia `main.tscn`) |
| `tests/integration/test_main_scene.gd` | Cambia | R-008-29, 30, 33, 44; R-004-16 y R-005-29 pasan a la transferencia |

## 3. Contratos

```gdscript
class_name RulesetData
extends Resource
@export var id: StringName                    # "normal"; stable forever (architecture §8)
@export var drops_inventory: bool             # every inventory stack falls where the player died
@export var keeps_xp: bool
@export var keeps_core: bool                  # applied by spec 015 (EquipmentComponent)
@export var respawn_battery_ratio: float      # fraction of the maximum, 0 < ratio <= 1
func validate() -> PackedStringArray          # empty id, ratio out of range

class_name DeathConfigData
extends Resource
@export var transfer_duration_s: float

class_name DroppedItemConfigData
extends Resource
@export var lifetime_s: int

# EnemyData (added)
@export var drop_table: LootTableData         # null = drops nothing

# DevWorldConfigData (added)
@export var ruleset_id: StringName

# DataCatalog (added)
@export var rulesets: Array[RulesetData] = []
func has_ruleset(id: StringName) -> bool
func get_ruleset(id: StringName) -> RulesetData        # unknown → push_error, null

class_name ITimeService
extends RefCounted
func now_unix() -> int                        # base: push_error and 0

class_name LocalTimeService
extends ITimeService                          # device clock, whole seconds

class_name DroppedItemRules
extends RefCounted
static func elapsed_s(dropped_at_unix: int, now_unix: int) -> int      # negative counts as 0
static func is_expired(dropped_at_unix: int, now_unix: int, lifetime_s: int) -> bool

# InventoryRules (added)
static func can_split(slots: Array[ItemStack], slot_index: int, quantity: int) -> bool
static func split(slots: Array[ItemStack], slot_index: int, quantity: int) -> ItemStack   # invalid → null, no change

# ZonePopulation (added; moved from ZombieSpawner)
const FIRST_VISIT := 0

# SeededRng (added)
const STREAM_ENEMY_DROP := &"enemy_drop"
static func derive_seed_for_visit(
	world_seed: int, zone_id: Vector2i, stream: StringName, visit: int, index: int
) -> int

# InventoryComponent (added)
func take_amount_from(source: InventoryComponent, slot_index: int, quantity: int) -> InventoryAddResult
func clear(slot_count: int) -> ActionResult   # empties it and leaves slot_count slots; < 0 → ERR_INVALID_REQUEST

# ExperienceComponent (added)
func reset() -> void                          # total back to 0; xp_changed only if it changed

# MeleeAttackComponent (added)
func cancel_swing() -> void                   # drops a pending impact; the swing's cost stays paid

# GameManager (added)
signal zone_visit_changed(zone_id: Vector2i, visit: int)
func get_ruleset() -> RulesetData
func get_time_service() -> ITimeService
func get_visit_count(zone_id: Vector2i) -> int
func increment_visit_count(zone_id: Vector2i) -> int       # returns the new count
func clear_visit_counts() -> void             # a new world starts with none (spec 010); tests isolate with it

# DataRegistry (added)
func get_ruleset(id: StringName) -> RulesetData

# EventBus (added)
signal player_died(player_uid: String)
signal player_respawned(player_uid: String)

class_name DroppedItem
extends Node3D
signal emptied(dropped: DroppedItem)
var uid: String
var zone_id: Vector2i
var local_position: Vector3                   # relative to its zone, fixed when it falls
var dropped_at_unix: int
func setup(
	p_uid: String, p_zone_id: Vector2i, p_local_position: Vector3, p_dropped_at_unix: int, slot_count: int
) -> void                                     # starts a new use with slot_count empty slots
func reset() -> void                          # no stacks, no slots, no uid, zone, position or time
func get_contents() -> InventoryComponent
func to_data() -> Dictionary                  # JSON types only

class_name DroppedItemSpawner
extends Node3D
@export var pool: ObjectPool
@export var config: DroppedItemConfigData
var time_service: ITimeService
func bind_zone(zone_id: Vector2i, zone_root: Node3D) -> void
func drop_inventory(source: InventoryComponent, world_position: Vector3) -> DroppedItem   # empty source → null
func drop_from_slot(
	source: InventoryComponent, slot_index: int, quantity: int, world_position: Vector3
) -> ActionResult                             # invalid → ERR_INVALID_REQUEST, nothing created
func drop_stacks(stacks: Array[ItemStack], world_position: Vector3) -> DroppedItem        # empty → null
func discard_expired(now_unix: int) -> void
func get_items() -> Array[DroppedItem]
func to_data() -> Array[Dictionary]

class_name DeathController
extends Node
@export var dropped_items: DroppedItemSpawner
var ruleset: RulesetData                      # set by Main from GameManager
var zone_id: Vector2i                         # zone the bound robots are in; ZoneLoader sets it in spec 009
func bind(robot: Robot) -> void
func respawn(robot: Robot, world_position: Vector3) -> void   # robot not dead → push_error, no change

class_name TransferScreen
extends Control
signal finished
@export var config: DeathConfigData
func play() -> void
func is_playing() -> bool
func advance(delta: float) -> void            # called by _process while playing

class_name QuantitySelector
extends HBoxContainer
signal value_changed(value: int)
func set_maximum(maximum: int) -> void        # range 1..maximum, value = maximum
func get_value() -> int

# InventoryScreen (added)
const CONTEXT_THROWER := &"thrower"           # Robot; without it the throw controls stay hidden

# InventoryGrid / InventorySlotView (added)
func set_selected_index(index: int) -> void   # -1 = none
func set_selected(selected: bool) -> void

# Robot (added)
signal throw_requested(player: Robot, slot_index: int, quantity: int)
func request_throw(slot_index: int, quantity: int) -> void   # depleted battery → nothing
func respawn_at(world_position: Vector3, battery_amount: float) -> void   # places itself, stops, charges

# Zombie (changed / added)
signal loot_dropped(stacks: Array[ItemStack], world_position: Vector3)
func activate(data: EnemyData, home: Vector3, brain_seed: int, drop_seed: int) -> void

# ZombieSpawner / FarmZone (added)
signal enemy_loot_dropped(stacks: Array[ItemStack], world_position: Vector3)

# FarmZone (changed / added)
func generate(world_seed: int, visit: int) -> void
func repopulate(world_seed: int, visit: int, pool: ObjectPool) -> void
```

**`EventBus`.** `player_died` y `player_respawned` ya están en la tabla de architecture §7 con estos argumentos;
no hace falta cambiarla. Las emite `DeathController`, que es quien aplica el ruleset.

**Entradas inválidas.** `drop_from_slot` devuelve `ActionResult` porque la pide la UI (architecture §3 regla 4).
`drop_inventory` y `drop_stacks` devuelven el objeto creado o `null`: no fallan con mensaje para el jugador.

## 4. Datos

| Recurso / `.tres` | Campos | Valores desde |
|---|---|---|
| `rulesets/normal.tres` | `id = &"normal"`, `drops_inventory = true`, `keeps_xp = true`, `keeps_core = true`, `respawn_battery_ratio = 1.0` | PMV §2.4 puntos 1-3, BALANCE §1.1 "Batería al reaparecer" |
| `config/death.tres` | `transfer_duration_s = 2.0` | BALANCE §11 "Muerte" |
| `config/dropped_items.tres` | `lifetime_s = 300` | BALANCE §7.2 "Caducidad de los items soltados" (5 minutos) |
| `loot/zombie_drop.tres` | `scrap`, `min_quantity = 0`, `max_quantity = 1` | BALANCE §3.1 (notas), §2.1 (regla de rangos) |
| `enemies/zombie_slow.tres`, `zombie_fast.tres` | `drop_table = zombie_drop.tres` | BALANCE §3.1 |
| `config/dev_world.tres` | `ruleset_id = &"normal"` | PMV §4.5 gancho 4 (no es balance) |

Valores técnicos o de presentación que viven en la escena, no en BALANCE: intervalo del `Timer` de caducidad (1 s,
la resolución del reloj), cuántos objetos caídos se precalientan (`enemy_count_max` de la zona + ranuras del
inventario del robot + 1: un drop por zombie, una tirada por ranura y una muerte; si faltan, el pool crea más), malla y color del objeto caído, fundido de la transferencia y tamaño
de los controles del selector.

## 5. Verificación

| Requisito | Test (`game/tests/…`) o paso manual |
|---|---|
| R-008-01 | `unit/test_ruleset_resources.gd::test_r_008_01_normal_matches_pmv`, `test_r_008_01_every_ruleset_file_valid`; `unit/test_data_catalog.gd::test_r_008_01_get_ruleset_by_id`, `test_r_008_01_unknown_ruleset_reports_error`, `test_r_008_01_every_ruleset_file_in_catalog`, `test_r_008_01_repeated_or_empty_ruleset_ids_reported` |
| R-008-02 | `unit/test_game_manager.gd::test_r_008_02_ruleset_from_dev_world` |
| R-008-03 | `unit/test_ruleset_resources.gd::test_r_008_03_no_script_branches_on_ruleset_id` (busca comparaciones con el id en `scripts/` y `scenes/`); `integration/test_death_controller.gd::test_r_008_03_reaction_follows_ruleset` (ruleset hecho a mano: sin soltar inventario, XP a 0, batería a la mitad) |
| R-008-04 | `unit/test_ruleset_resources.gd::test_r_008_04_death_config_matches_balance`, `test_r_008_04_dropped_item_lifetime_matches_balance`, `test_r_008_04_no_death_literals_in_scripts`; `unit/test_transfer_screen.gd::test_r_008_04_duration_from_config` |
| R-008-05 | `unit/test_enemy_resources.gd::test_r_008_05_zombies_drop_table_matches_balance`; `unit/test_data_catalog.gd::test_r_004_26_all_loot_tables_valid` ya recorre `resources/loot/` |
| R-008-06 | `unit/test_game_manager.gd::test_r_008_06_visit_count_starts_at_zero`, `test_r_008_06_counts_are_per_zone`; `integration/test_main_scene.gd::test_r_008_06_generating_does_not_count_a_visit` |
| R-008-07 | `unit/test_game_manager.gd::test_r_008_07_increment_adds_one_and_emits`; `integration/test_death_controller.gd::test_r_008_07_death_counts_one_visit` |
| R-008-08 | `unit/test_seeded_rng.gd::test_r_008_08_visit_and_index_change_the_seed`, `test_r_008_08_known_answer`; `integration/test_green_zone.gd::test_r_008_08_contents_change_with_visit`, `test_r_008_08_positions_same_on_every_visit` |
| R-008-09 | `integration/test_green_zone.gd::test_r_008_09_repopulate_closes_boxes_with_new_contents`, `test_r_008_09_repopulate_discards_leftovers`, `test_r_008_09_repopulate_places_enemies_of_the_visit`; `integration/test_main_scene.gd::test_r_008_09_visit_change_repopulates_loaded_zone` |
| R-008-10 | `unit/test_dropped_item.gd::test_r_008_10_holds_stacks_uid_zone_and_time`; `integration/test_dropped_item_spawner.gd::test_r_008_10_position_is_local_to_the_zone` |
| R-008-11 | `unit/test_inventory_component.gd::test_r_008_11_take_amount_moves_exactly`; `unit/test_dropped_item.gd::test_r_008_11_drop_and_pick_up_keep_totals`. Durabilidad y `uid` de pila: `ItemStack` aún no los tiene (los añade la spec 015 con su `copy()`); ver §7 |
| R-008-12 | `unit/test_dropped_item.gd::test_r_008_12_interactable_with_pick_up_prompt`, `test_r_008_12_prompt_translated_es_en` |
| R-008-13 | `unit/test_dropped_item.gd::test_r_008_13_interact_takes_all_in_slot_order`, `test_r_008_13_interactor_without_inventory_reports_error` |
| R-008-14 | `unit/test_dropped_item.gd::test_r_008_14_emptied_once`; `integration/test_dropped_item_spawner.gd::test_r_008_14_emptied_goes_back_to_pool` |
| R-008-15 | `unit/test_dropped_item.gd::test_r_008_15_partial_pick_up_keeps_rest_and_time`; `integration/test_main_scene.gd::test_r_008_15_full_inventory_shows_notice` |
| R-008-16 | `integration/test_main_scene.gd::test_r_008_16_dropped_items_survive_repopulation` |
| R-008-17 | `unit/test_dropped_item.gd::test_r_008_17_data_is_json_only` (recorre el diccionario: solo `String`, `int`, `float`, `bool`, `Array`, `Dictionary`; ids y no recursos) |
| R-008-18 | `unit/test_dropped_item.gd::test_r_008_18_reset_leaves_nothing`; `integration/test_dropped_item_spawner.gd::test_r_008_18_reused_item_is_clean` (primero una muerte con 5 ranuras, después el drop de un zombie: 1 ranura, 1 pila, otro `uid` y otra hora), `test_r_008_18_items_come_from_the_pool`; `unit/test_inventory_component.gd::test_r_008_18_clear_empties_and_resizes` |
| R-008-19 | `unit/test_time_service.gd::test_r_008_19_base_reports_error`, `test_r_008_19_local_reads_device_clock` (entre dos lecturas de `Time`), `test_r_008_19_no_other_script_reads_the_clock` (en `scripts/` y `scenes/`, solo `local_time_service.gd` nombra `Time.get_unix_time`; los addons quedan fuera); `unit/test_game_manager.gd::test_r_008_19_exposes_time_service` |
| R-008-20 | `integration/test_dropped_item_spawner.gd::test_r_008_20_drop_records_now` (reloj falso) |
| R-008-21 | `unit/test_dropped_item_rules.gd::test_r_008_21_expired_at_exact_lifetime`, `test_r_008_21_not_expired_one_second_before`, `test_r_008_21_negative_elapsed_counts_as_zero` |
| R-008-22 | `integration/test_dropped_item_spawner.gd::test_r_008_22_expired_disappears_and_gives_nothing`, `test_r_008_22_timer_runs_only_with_items` |
| R-008-23 | `integration/test_main_scene.gd::test_r_008_23_repopulation_discards_expired` |
| R-008-24 | `unit/test_dropped_item_rules.gd::test_r_008_24_depends_only_on_times`; `integration/test_main_scene.gd::test_r_008_24_expires_with_screen_open_and_after_new_visit` |
| R-008-25 | `unit/test_event_bus.gd::test_r_008_25_player_died_signature`; `integration/test_death_controller.gd::test_r_008_25_died_once_by_drain`, `test_r_008_25_died_once_by_swing`, `test_r_008_25_died_once_by_hit` |
| R-008-26 | `integration/test_death_controller.gd::test_r_008_26_inventory_falls_where_it_died` |
| R-008-27 | `integration/test_death_controller.gd::test_r_008_27_empty_inventory_creates_nothing` |
| R-008-28 | `integration/test_death_controller.gd::test_r_008_28_xp_and_slots_unchanged` |
| R-008-29 | `integration/test_main_scene.gd::test_r_008_29_death_closes_screens_and_shows_transfer`; `unit/test_transfer_screen.gd::test_r_008_29_title_translated_es_en`, `test_r_008_29_hidden_until_played`, `test_r_008_29_consumes_touches` |
| R-008-30 | `integration/test_main_scene.gd::test_r_008_30_robot_frozen_during_transfer` (no se mueve, no golpea, no interactúa, un golpe no cambia nada); se conservan `test_r_004_16_*` y `test_r_005_29_*`, ahora con la transferencia en lugar del game over. `test_r_004_16_*` guardaba una caja que la repoblación libera: pasa a comprobar que ninguna caja de `zone.get_boxes()` está abierta y que no hay pantalla abierta tras pulsar el botón y la acción, igual de estricto. El mundo congelado y "el robot no se mueve" de `test_r_003_12_*` pasan a `test_r_008_30_*` |
| R-008-31 | `unit/test_event_bus.gd::test_r_008_31_player_respawned_signature`; `integration/test_death_controller.gd::test_r_008_31_respawn_restores_battery_and_emits_once`, `test_r_008_31_respawn_of_living_robot_reports_error`; `unit/test_transfer_screen.gd::test_r_008_31_finished_once_after_duration`; `integration/test_main_scene.gd::test_r_008_31_robot_back_at_spawn_with_input` |
| R-008-32 | `integration/test_death_controller.gd::test_r_008_32_second_death_makes_its_own_item` |
| R-008-33 | `integration/test_main_scene.gd::test_r_008_33_no_game_over_and_no_reload` (no hay `GameOverScreen` y la instancia de `Main` es la misma tras morir); sustituye a `test_r_003_12_*` |
| R-008-34 | `unit/test_game_manager.gd::test_r_008_34_holds_only_world_state` (las variables del script son exactamente semilla, ruleset, contadores y reloj: nada de un jugador); `integration/test_death_controller.gd::test_r_008_34_controller_holds_no_player_state` |
| R-008-35 | `integration/test_zombie.gd::test_r_008_35_killed_zombie_rolls_once`, `test_r_008_35_no_killer_no_loot`, `test_r_008_35_no_table_no_loot`; `integration/test_main_scene.gd::test_r_008_35_loot_becomes_dropped_item_where_it_died` |
| R-008-36 | `integration/test_zombie_spawner.gd::test_r_008_36_drop_independent_of_kill_order`, `test_r_008_36_drop_changes_with_visit`; `unit/test_no_global_rng.gd` (con `zombie.gd` vigilado) |
| R-008-37 | `integration/test_main_scene.gd::test_r_008_35_loot_becomes_dropped_item_where_it_died` (es un `DroppedItem` del mismo spawner: mismas reglas por construcción) |
| R-008-38 | `unit/test_quantity_selector.gd::test_r_008_38_*` (rango 1..máximo, empieza en el máximo, − / + de uno en uno y sin salirse, deslizador); `unit/test_inventory_screen.gd::test_r_008_38_tap_selects_and_shows_selector`, `test_r_008_38_cells_pressable_without_focus` |
| R-008-39 | `unit/test_inventory_screen.gd::test_r_008_39_throw_requests_slot_and_quantity`; `integration/test_robot_inventory.gd::test_r_008_39_request_throw_emits`; `integration/test_main_scene.gd::test_r_008_39_throw_whole_stack`, `test_r_008_39_throw_part_keeps_rest` |
| R-008-40 | `unit/test_inventory_rules.gd::test_r_008_40_split_whole`, `test_r_008_40_split_part`, `test_r_008_40_invalid_quantities_change_nothing` (0, negativa, mayor que la pila, ranura vacía, índice fuera de rango), sin árbol de escena |
| R-008-41 | `unit/test_inventory_screen.gd::test_r_008_41_throw_disabled_without_selection`, `test_r_008_41_selection_cleared_when_slot_empties` |
| R-008-42 | `unit/test_inventory_screen.gd::test_r_008_42_screen_never_changes_inventory` (thrower falso: el inventario no cambia), `test_r_008_42_texts_translated_es_en` |
| R-008-43 | `integration/test_main_scene.gd::test_r_008_39_throw_whole_stack` (lo tirado se recoge) y `test_r_008_24_*` (caduca) |
| R-008-44 | `integration/test_main_scene.gd::test_r_008_44_die_respawn_and_recover` (ACTION_PLAN 1.5: batería al 100 %, inventario vacío, items en la zona, zombies de la visita 1, recoger devuelve las mismas pilas). Paso manual en PC: el criterio de hecho del spec §5 completo |
| R-008-45 | Manual en el Android de gama media (APK debug): zona con el máximo de zombies (semilla de 8 de T-006-14), matar varios, tirar 5 items y morir una vez; FPS del `DebugHud` ≥ 30. Anotar en `tasks.md` dispositivo, FPS mínimo y triángulos del objeto caído |

**(verificar)** antes de usar, en la referencia de clases de Godot 4.7.2 (`--doctool`) y con scripts de prueba en
headless:

1. `Time.get_unix_time_from_system()`: que devuelva segundos UTC como `float` y cómo pasarlo a `int`.
2. `HSlider` con `min_value = 1`, `step = 1`, `rounded`: `value_changed`, `set_value_no_signal` y qué hace con
   `min_value == max_value` (pila de 1). Si no admite ese rango, el selector oculta el deslizador con pilas de 1.
3. Añadir y quitar del árbol un `Area3D` desde un paso de física (soltar al morir por un golpe; devolver al pool
   en diferido), y que el `InteractorComponent` deje de verlo en el paso siguiente y lo vea al reaparecer en otro
   sitio.
4. `Node.process_mode`: pasar `World` de `DISABLED` a `INHERIT`. Que los `CharacterBody3D` y los
   `NavigationAgent3D` sigan funcionando, que un `Timer` hijo se pare y siga, y que mover al robot mientras está
   desactivado surta efecto al reanudar.
5. `queue_free` de una caja y alta de otra en el mismo marcador en el mismo fotograma, con el mundo congelado: sin
   errores de física ni del `InteractorComponent`.
6. Que un `Control` a pantalla completa con `mouse_filter = STOP`, colocado después del HUD, se trague los toques
   de los botones del HUD (ya lo hacía `GameOverScreen`; se confirma con la escena nueva).
7. Una función común de indexado en `DataCatalog` para tres tipos sin clase base: leer el id con `get(&"id")` y
   asignarlo a una variable tipada, con `unsafe_property_access` como error. Si no compila limpio, se escribe la
   tercera función específica y la unificación se queda fuera.

### 5.1 Resultado de los puntos (verificar) (T-008-01, 2026-11-16)

Script de prueba en headless con Godot 4.7.2, fuera del repo.

| # | Resultado |
|---|---|
| 1 | `Time.get_unix_time_from_system()` devuelve `float` con decimales; `int()` lo trunca a segundos. ✅ |
| 2 | `HSlider` con `min_value = 1`, `step = 1`, `rounded`: admite `min_value == max_value` (valor 1, sin señal). `value` se recorta al rango y emite `value_changed` también al asignar el mismo valor; `set_value_no_signal` no emite. Bajar `max_value` por debajo del valor lo recorta **sin** emitir: el selector lee el valor del deslizador, no de la última señal. ✅ |
| 3 | Un `Area3D` añadido al árbol se ve en el paso de física siguiente; quitado en diferido deja de verse en el paso siguiente; añadido otra vez en otro sitio solo se ve allí. ✅ |
| 4 | `World` de `DISABLED` a `INHERIT`: un `Timer` hijo no da ni un tic mientras está desactivado y sigue después; mover un `CharacterBody3D` mientras está desactivado surte efecto al reanudar; las áreas siguen detectando. ✅ |
| 5 | `queue_free` de un `StaticBody3D` y alta de otro en el mismo sitio en el mismo fotograma, con el mundo congelado: sin errores. ✅ |
| 6 | No se pudo simular el clic con `push_input` en el script suelto. Se comprueba con `test_r_008_29_consumes_touches`, con el mismo método que usaba el test de `GameOverScreen`. ⏳ (T-008-11) |
| 7 | `resource.get(&"id")` asignado a una variable `StringName` compila con los avisos del proyecto como error; una propiedad que no existe da `null`. ✅ El indexado común del catálogo es viable. |

Ningún punto obliga a cambiar el plan.

## 6. Check de constitución

| Principio | Cumple | Nota |
|---|---|---|
| P1 Spec primero | ✅ | Spec 008 *Aprobado*. Un punto pide tocar el spec antes de implementar: R-008-38 sustituye la parte "las celdas no se pulsan" de la 005 (§7) |
| P2 Una fuente de verdad | ✅ | Batería al reaparecer, caducidad, duración de la transferencia y drop del zombie en `.tres` con su fuente. `FIRST_VISIT` en un solo sitio. Una tabla de drop para los dos zombies. Soltar y recoger reutilizan `InventoryComponent`. El indexado del catálogo se unifica al llegar el tercer tipo |
| P3 Lógica separada | ✅ | `DroppedItemRules`, `InventoryRules.split` y `derive_seed_for_visit` son puros. `discard_expired(now)` y `TransferScreen.advance(delta)` reciben el tiempo por parámetro |
| P4 Estado por jugador | ✅ | `GameManager` solo gana ruleset, contadores y reloj (test). `DeathController` no guarda estado. Inventario y XP siguen en el robot |
| P5 Datos como recursos | ✅ | `RulesetData`, `DeathConfigData`, `DroppedItemConfigData` con `class_name` y `.tres` |
| P6 Señales | ✅ | `player_died` y `player_respawned` por el bus con `player_uid`. `zone_visit_changed`, `emptied`, `loot_dropped`, `throw_requested`, `finished` locales y tipadas. Referencias por `%` y `@export` |
| P7 Tipado | ✅ | Todo tipado. `to_data()` devuelve `Dictionary` sin tipo de valor: es JSON |
| P8 Plataforma | ✅ | Sin teclas ni `OS.has_feature()`. El selector y el botón son `Control` normales |
| P9 Determinismo | ✅ | Cajas y drops con `SeededRng` (semilla + zona + visita + índice). El `uid` del objeto caído es aleatorio a propósito (identidad, architecture §10.3), no generación. Posición como `(zone_id, local)` |
| P10 Servicios | ✅ | `ITimeService` como clase base con implementación local; solo `GameManager` la crea |
| P11 i18n | ✅ | `PROMPT_PICK_UP`, `TRANSFER_TITLE`, `INVENTORY_THROW` en ES + EN. "−", "+" y los números no se traducen |
| P12 Presupuesto móvil | ✅ | Objetos caídos con pool desde el principio, malla de pocos triángulos, sin luces. El `Timer` de caducidad solo corre con objetos activos. FPS medido en Android (R-008-45) |
| P13 Test primero | ✅ | Reglas, datos y componentes con test antes del código. Reloj falso; ningún test espera tiempo real |
| P10 / architecture §3 | ⚠️ | "Los servicios se alcanzan solo desde autoloads": `GameManager` es el único que crea y expone el reloj, pero `DroppedItemSpawner` lo recibe inyectado y lo llama. Se acepta porque así el test usa un reloj falso sin tocar el autoload |
| P14 Alcance | ⚠️ | Añadidos que el spec no nombra, justificados en §7 y pendientes de tu visto bueno: `ExperienceComponent.reset` y la rama `drops_inventory = false` (para que el ruleset no tenga campos que nadie lee), `MeleeAttackComponent.cancel_swing`, `InventoryComponent.clear`, `Robot.respawn_at`, y mover `FIRST_VISIT` a `ZonePopulation` (renombre en `main.gd` y dos tests) |
| architecture §3 regla 4 | ⚠️ | `drop_inventory`, `drop_stacks`, `respawn`, `increment_visit_count` no devuelven `ActionResult`: no son acciones con mensaje para el jugador, igual que `consume` y `take_damage` (plan 007 §7) |
| architecture §5 | ✅ | Ningún autoload nuevo. `GameManager` gana lo que su fila ya dice (mundo, ruleset). El reloj y `zone_visit_changed` no están en esa fila: se propone añadirlos al texto de architecture §5 (§7) |

## 7. Riesgos y alternativas descartadas

- **R-008-38 contradice un test de la 005** → `test_r_005_25_cells_cannot_be_pressed` comprueba que las celdas del
  inventario no se pulsan. El texto de R-005-25 no lo exige (venía del plan 005), pero conviene que el spec 008 lo
  diga, como hace con R-003-12. Propuesta: añadir a R-008-38 "(sustituye a 'solo muestra' del plan 005)". El test
  se sustituye, no se debilita: `focus_mode` se sigue comprobando.
- **R-008-11, durabilidad y `uid` de pila** → `ItemStack` hoy solo tiene `item` y `quantity`. El objeto caído mueve
  pilas con `InventoryComponent`, así que conservará lo que la spec 015 añada a `ItemStack` si la 015 lo lleva
  también por `InventoryRules`. En la 008 solo se puede comprobar item y cantidad. Se anota como condición de
  entrada para la 015. Propuesta: anotarlo en R-008-11 del spec antes de pasar la puerta.
- **R-008-34 dice "solo el ruleset y los contadores"** → `GameManager` ya guarda la semilla y ahora también el
  reloj. Ninguno es estado de un jugador, que es lo que protege el requisito. Propuesta: que el spec diga "solo
  estado del mundo (semilla, ruleset, contadores de visitas) y el servicio de tiempo".
- **Fila de `GameManager` en architecture §5** → añadir "contadores de visitas por zona, acceso a `ITimeService`".
  Es un cambio de un documento de gobierno: lo decides tú. **Aprobado y aplicado (2026-11-16).**
- **Contenido de las cajas de la visita 0** → cambia respecto a hoy por la derivación nueva. Sin partidas guardadas
  ni tests que lo fijen; se nota solo si alguien recordaba qué daba cada caja con la semilla de desarrollo.
- **Estado del `GameManager` entre tests** → es un autoload: una muerte en un test deja la visita en 1 para el
  siguiente. Toda suite que instancia `main.tscn` o un `DeathController` (`test_main_scene`,
  `test_hud_attack_input`, `test_death_controller`) llama a `clear_visit_counts()` en `before_each` y en
  `after_each`. Ese método lo usará la
  010 al crear o cargar un mundo; hasta entonces solo lo llaman los tests.
- **Dos dueños del bloqueo de input** → `UIManager.modal_state_changed` y la transferencia escriben
  `PlayerInput.set_input_blocked`. No chocan: durante la transferencia no se puede abrir ninguna pantalla (batería a
  0). Si la 009 o los menús añaden un tercero, se cambia a un contador de motivos.
- **Impacto pendiente al morir** → sin `cancel_swing` en la muerte, el impacto podría caer en el mismo paso de
  física y devolver al pool un zombie de la visita nueva (§1 "Muerte", paso 0), o caer 0,2 s después de reaparecer.
- **`keeps_xp = false` sin ruleset que lo use** → se programa y se testea con un ruleset hecho a mano. La
  alternativa (declarar el campo y no leerlo) dejaría un dato que no hace nada y rompería R-008-03.
- **Morir justo en el punto de aparición** → el objeto caído queda bajo el robot al reaparecer. Se recoge con
  "Interactuar"; no se mitiga.
- **Objeto caído dentro de un obstáculo** → el robot muere donde puede estar de pie y los zombies también, así que
  el objeto queda al alcance (radio de interacción 2 m, BALANCE §11).
- **`Timer` de caducidad de 1 s** → un objeto puede verse hasta 1 s después de caducar. No se puede recoger
  ventaja: `discard_expired` corre también al repoblar, y la 010 lo hará al cargar. Si el playtesting pide cuenta
  atrás, llega con el HUD (pregunta 9).
- **Tests con el reloj real** → solo `test_r_008_19_local_reads_device_clock` lee `Time`, y compara con un margen
  entre dos lecturas, no con un valor fijo.
- **Ajustes durante la implementación (revisión de `architecture-guardian`, 2026-11-16)** → cambian §3 en esto:
  - `DeathController` no tiene `zone_id`: lee la zona del spawner (`DroppedItemSpawner.get_zone_id()`), para que
    la zona cargada se fije en un solo sitio (`bind_zone`) y la 009 no tenga que actualizar dos (P2).
  - `FloatingJoystick.cancel()` (nuevo): al morir, `Main` suelta el joystick y el botón de ataque. La pantalla de
    transferencia se queda con la suelta del dedo y, sin esto, el robot andaría o golpearía solo al reaparecer.
    Antes lo tapaba la recarga de la escena. Se comprueba en el móvil (T-008-15).
  - `ZombieSpawner` desconecta `loot_dropped` junto a `defeated` al devolver un zombie al pool.
  - `DroppedItemSpawner.is_checking_expiry()` (nuevo, solo lectura) para comprobar R-008-22 sin tocar el `Timer`.
    El `Timer` lo crea el script, con su intervalo en la constante `EXPIRY_CHECK_INTERVAL_S` (valor técnico, no
    de BALANCE), en lugar de vivir en una escena: el spawner no tiene `.tscn` propio.
  - `DeathController.respawn` devuelve `bool`: si se rechaza (`push_error`), `Main` no reanuda el mundo con un
    robot muerto.
  - `DroppedItemSpawner.discard_expired_now()` (nuevo): descarta con el reloj del propio spawner, el mismo con el
    que se apuntó la hora de caída. `Main` lo llama al poblar y al repoblar, así hay un solo camino al reloj y los
    tests de `Main` usan una hora fija con `FakeTimeService`.
  - `drop_from_slot` devuelve al pool el objeto si no llegó a entrar nada, y la devolución diferida de un objeto
    vaciado comprueba su `uid` (el mismo nodo puede estar ya en uso como otra caída).
  - `test_game_manager.gd` también limpia los contadores (`clear_visit_counts()`), y las suites que instancian
    `main.tscn` lo hacen **antes** de instanciar, porque `Main._ready` lee el contador.
- **Tres saltos de señal para el drop del zombie** (`Zombie` → `ZombieSpawner` → `FarmZone` → `Main`) → es el mismo
  patrón que `box_opened`. La alternativa, un evento en `EventBus`, abriría la lista cerrada para algo que solo
  interesa a quien carga la zona.
