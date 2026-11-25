# Muerte, objetos caídos y recuperación

> Al llegar la batería a 0 el robot suelta su inventario y sus brazos y piernas donde cae, la zona `FARM` se repone con
> la visita siguiente y, tras una pantalla de transferencia, reaparece en la base con la batería llena y su Core. Lo caído
> es un contenedor: "Interactuar" lo abre en la pantalla de contenedor; caduca y sobrevive a descargar la zona.
> Specs: [008](../../specs/008-death-recovery/spec.md), [009](../../specs/009-base-placement-charging/spec.md), [010](../../specs/010-save-profile-world/spec.md), [011](../../specs/011-crafting-repair/spec.md), [015](../../specs/015-pieces-slots-degradation/spec.md) · Última actualización: spec 015

## Piezas

| Pieza | Tipo | Archivo | Responsabilidad |
|---|---|---|---|
| `DeathController` | Nodo de `main.tscn` | `game/scenes/death/death_controller.gd` | Aplica el ruleset a cada robot enlazado y lo hace reaparecer; no guarda estado |
| `RulesetData` | Resource | `game/scripts/data/ruleset_data.gd` | Reacción a la muerte como dato (`drops_inventory`, `keeps_xp`, `keeps_core`, `respawn_battery_ratio`) |
| `normal.tres` | Recurso | `game/resources/rulesets/normal.tres` | Único ruleset (`NORMAL`) |
| `DeathConfigData` / `death.tres` | Resource | `game/scripts/data/death_config_data.gd`, `resources/config/death.tres` | Duración de la transferencia |
| `DroppedItem` | Escena (`Node3D`) | `game/scenes/entities/dropped_item.gd`, `.tscn` | Contenedor en el suelo, con su `InventoryComponent` y su `InteractableComponent`; interactuar solo emite `opened` |
| `DroppedItemSpawner` | Nodo (bajo `World`) | `game/scenes/entities/dropped_item_spawner.gd` | Crea, caduca y devuelve al pool los objetos caídos; reemite `item_opened` y emite `item_removed`; `release_if_empty` |
| `DroppedItemFlow` | Nodo de `main.tscn` | `game/scenes/entities/dropped_item_flow.gd` | Abre la `ContainerScreen` (`Kind.DROPPED`) del objeto que abre el jugador local, lo libera al cerrarla si quedó vacío y la cierra si el objeto se va |
| `DroppedItemRules` | Sistema puro | `game/scripts/systems/dropped_item_rules.gd` | Regla de caducidad (`is_expired`) |
| `DroppedItemConfigData` / `dropped_items.tres` | Resource | `game/scripts/data/dropped_item_config_data.gd`, `resources/config/dropped_items.tres` | Vida de un objeto caído |
| `ITimeService`, `LocalTimeService` | Servicio | `game/scripts/services/` | Contrato del reloj e implementación con el reloj del dispositivo |
| `GameManager` | Autoload | `game/scripts/autoload/game_manager.gd` | Ruleset, contador de visitas por zona y `get_time_service()` |
| `TransferScreen` | `Control` | `game/scenes/ui/transfer_screen.gd`, `.tscn` | "Transferencia de Consciencia"; fuera de `UIManager` |
| `Main` | Escena | `game/scenes/main.gd` | Cablea todo: pantalla, congelado de `World`, viaje a la base y reaparición (`_respawn_pending`) |

## Cómo funciona

1. `BatteryComponent` emite `battery_depleted` una vez por llegada a 0, sea cual sea la causa (consumo, un golpe propio
   o uno de zombi). `DeathController.bind(robot)` la escucha ([battery.md](battery.md)).
2. `_on_battery_depleted`, en este orden: `robot.melee.cancel_swing()` (un robot muerto no golpea; si no, un impacto
   pendiente mataría a un zombi cuya devolución al pool quedaría detrás de la repoblación); si
   `ruleset.drops_inventory`, `_drop_carried`: toma brazos y piernas (y el Core si el ruleset no tiene `keeps_core`) con
   `equipment.get_piece()` y llama `DroppedItemSpawner.drop_inventory(inventario, posición, piezas)` (un solo objeto con
   **una ranura por pila recibida**; sin pilas ni piezas no crea nada). **Solo si el objeto se creó** pide
   `equipment.take_slots(ranuras)`: sin zona, pool o reloj las piezas se quedan equipadas y nada se pierde. Sin
   `drops_inventory` no cae nada, tampoco del equipo. Si no `ruleset.keeps_xp`, `experience.reset()`; `GameManager.increment_visit_count(zona)`;
   y al final `EventBus.player_died(player_uid)`, para que quien escuche ya vea el inventario en el suelo. El
   contador solo sube si la zona de la muerte `counts_visits()` (`FARM`): morir en la base no repuebla nada. Una zona
   que el catálogo no conoce es `push_error` y no cuenta visita.
3. `GameManager` emite `zone_visit_counted`; `SaveManager` guarda tras `player_died`, con retención hasta
   `player_respawned` ([save.md](save.md)). `ZoneLoader` repuebla en diferido la zona cargada
   ([world_zones.md](world_zones.md), [travel.md](travel.md)) y vuelve a llamar `discard_expired_now()`.
4. `Main._on_player_died` (solo si el uid es el del robot local): `UIManager.close_all()`, bloquea el input, suelta el
   joystick y el botón de ataque, `TransferScreen.play()` y congela `World` en diferido (`process_mode = DISABLED`,
   con el motivo `DEATH`, [travel.md](travel.md)). Cerrar las pantallas cancela una colocación o un movimiento en
   curso sin cobrar nada ([base.md](base.md)).
5. `TransferScreen` avanza con `advance(delta)` desde su `_process` y emite `finished` al cumplir la duración.
6. `Main._on_transfer_finished` marca `_respawn_pending` y viaja a la base con `ZoneLoader.travel_to` (también si
   murió dentro de la base: la recarga). Al terminar el viaje, `Main._respawn_at` llama
   `DeathController.respawn(robot, base.get_spawn_position())`. El robot vuelve con los stats del equipo que le queda
   (con `normal.tres`: un brazo, sin piernas, su Core). Calcula la batería (máximo × `respawn_battery_ratio`),
   llama `Robot.respawn_at` y emite `EventBus.player_respawned`; después quita los motivos `DEATH` y `TRAVEL`. Si
   `respawn` devuelve `false` (robot vivo o sin ruleset: `push_error`), `Main` no reanuda `World`. Si el viaje
   falla o se rechaza, reaparece en el `SpawnPoint` de la zona que sigue cargada. Si la muerte coincide con un viaje
   en curso por una salida, espera a que termine y viaja a la base.
7. Abrir y recoger (spec 015): `DroppedItem._on_interacted` ya no coge nada, emite `opened(item, opener)` y el spawner lo
   reemite como `item_opened`. `DroppedItemFlow` (solo para el jugador local) abre la `ContainerScreen` con
   `Kind.DROPPED`, el contenido del objeto y el inventario del jugador ([ui.md](ui.md)): "Coger todo", elegir pilas o
   dejar pilas propias, con las reglas de la pantalla ([inventory.md](inventory.md)); una pieza conserva `uid` y
   durabilidad. El objeto sigue interactuable mientras exista y **conserva la hora original**: coger o dejar pilas no la
   cambia.
   - Al cerrarse la pantalla (cualquier camino) el flujo llama `release_if_empty(item)`: diferido, libera el objeto solo
     si sigue siendo el mismo uso (`uid`) y está vacío. Abierta, no se libera aunque esté vacío.
   - Si el objeto sale con la pantalla abierta (caducidad, descarga de zona), `_release` lo saca de la lista, emite
     `item_removed` y el flujo cierra la pantalla con `UIManager.close(pantalla)`; lo ya movido al inventario se queda.
8. Los objetos caídos nacen de tres sitios, todos por `DroppedItemSpawner`: la muerte (`drop_inventory`), tirar
   desde la pantalla de inventario (`drop_from_slot`) y el material de un zombi (`drop_stacks`, ver
   [enemies.md](enemies.md) y [loot.md](loot.md)).

### Caducidad

- Al crear un objeto, el spawner anota `time_service.now_unix()` como `dropped_at_unix`.
- `DroppedItemRules.is_expired(dropped_at, now, lifetime)` es pura: el tiempo negativo cuenta 0. No mira visitas,
  pantallas abiertas ni FPS.
- Un `Timer` creado por el spawner (cada `EXPIRY_CHECK_INTERVAL_S`, solo mientras hay objetos) llama
  `discard_expired_now()`; también lo llama `Main` al poblar y repoblar. Un objeto caducado vuelve al pool sin dar nada.
- El reloj lo expone `GameManager.get_time_service()` y `Main` se lo asigna al spawner; el spawner no crea relojes.
- Al cargar un guardado, `from_save_data` descarta los caducados con la hora del reloj antes de que nadie interactúe
  (R-010-30); los de una zona sin cargar se comprueban al ligarla.

### Objetos caídos y descarga de zona (spec 009)

- `DroppedItemSpawner.unbind_zone()` (lo llama `ZoneLoader` al descargar): guarda `to_data()` de cada objeto por
  `zone_id` en memoria y los devuelve al pool; ninguno se libera con la zona.
- `bind_zone(zone_id, zona)` (al cargar): restaura los guardados de esa zona con su `uid`, posición local, hora de caída
  y pilas, y llama `discard_expired_now()` antes de que nadie interactúe. Un id de ítem desconocido pierde esa pila con
  `push_error`, no el resto. Los guardados no caducan mientras la zona no está cargada.

### Guardado (spec 010)

`DroppedItem.to_data()` añade `slot_count` (R-015-55). Al restaurar, `_restored_slot_count` lo acepta si es un entero entre
el número de pilas guardadas y `MAX_RESTORED_SLOTS` (cota de cordura contra un archivo corrupto, no un valor de juego); si
falta (guardado anterior) o no vale, una ranura por pila (con `push_error` si no vale). Campo opcional: sin `schema_version`
nueva. Un objeto vacío no se guarda ni se restaura.

`DroppedItemSpawner` está en el grupo `persistent` con clave `dropped_items`: `to_save_data` junta los guardados de
cada zona descargada y los vivos (`to_data()`); `from_save_data` reemplaza todo y descarta los caducados y los de zona
desconocida o forma mala (`push_error`); los de la zona ligada se restauran y el resto espera a `bind_zone`. Las
lecturas pasan por `SaveFields`; una pila con ítem desconocido, cantidad no positiva o pieza inválida
(`InventoryRules.is_valid_stack`) se pierde sola. Cada pila guarda `item_id`, `quantity`, `durability` y `uid`; los dos
últimos son opcionales al leer (`-1` y `""`), así que un archivo de la spec 010 carga igual y no sube `schema_version`.
Cargar no emite señales.

## Datos

| Recurso | Clase | Valores en BALANCE |
|---|---|---|
| `rulesets/normal.tres` | `RulesetData` | [§1.1](../../BALANCE.md) (batería al reaparecer), PMV §2.4 |
| `config/death.tres` | `DeathConfigData` | [§11](../../BALANCE.md) "Muerte" |
| `config/dropped_items.tres` | `DroppedItemConfigData` | [§7.2](../../BALANCE.md) |

`DataRegistry.get_ruleset(id)` resuelve el id al recurso; el ruleset del Mundo viene de su archivo de guardado, o de
`DataCatalog.new_world_ruleset` para un Mundo nuevo ([data_catalog.md](data_catalog.md), [save.md](save.md)).

## Decisiones

| Decisión | Por qué | Fuente |
|---|---|---|
| La reacción a la muerte se lee de `RulesetData`; ningún script compara su id | El Hardcore de v1.1 será otro `.tres` | R-008-03, [plan 008 §1](../../specs/008-death-recovery/plan.md) |
| `player_died` lo emite `DeathController`, no la batería | Es la reacción del ruleset, no un hecho de la batería | [plan 008 §1](../../specs/008-death-recovery/plan.md) (alternativas descartadas), architecture §7 |
| Un solo objeto por muerte con todas las pilas | Pregunta 3 cerrada | [spec 008 §6](../../specs/008-death-recovery/spec.md) |
| El objeto caído es un contenedor que se abre en la pantalla de la spec 013, no se recoge de golpe | Al morir con piezas caen más pilas que ranuras libres al reaparecer | R-015-45, [spec 015 pregunta 15](../../specs/015-pieces-slots-degradation/spec.md) |
| El objeto conserva sus ranuras de creación (una por pila recibida) y una sola hora de caída | Un hueco vaciado admite pilas del jugador; la caducidad no se alarga | R-015-47, R-015-48 |
| Las piezas dejan el equipo solo si el objeto se creó | Nunca se crean ni se pierden objetos | [plan 015 D12](../../specs/015-pieces-slots-degradation/plan.md) |
| Brazos y piernas caen, el Core se conserva por `keeps_core`; se lee del ruleset, nunca del id | El Hardcore de v1.1 será otro `.tres` | R-015-25, R-015-27 |
| Un abrir-cerrar vacío libera el objeto; el flujo vive en `DroppedItemFlow`, no en `Main` | Mismo patrón que cofres y cajas; el objeto no conoce la UI ni el pool | [plan 015 D13](../../specs/015-pieces-slots-degradation/plan.md) |
| `DroppedItem` guarda sus pilas en un `InventoryComponent` | Reutiliza apilado y "lo que cabe"; no crea ni pierde unidades | R-008-11, [plan 008 §1](../../specs/008-death-recovery/plan.md) |
| Objetos caídos bajo `World`, fuera de la zona, con posición `(zone_id, local)` | Repoblar o descargar la zona no los toca | R-008-10, R-008-16, [plan 008 §1](../../specs/008-death-recovery/plan.md) |
| `TransferScreen` fuera de `UIManager` | Escape y "atrás" no deben cerrarla | [plan 008 §1](../../specs/008-death-recovery/plan.md) |
| Reaparece en el `SpawnPoint` de la base, por un viaje, también si murió dentro de ella | El punto de reaparición se decide en un solo sitio y la muerte sigue un solo camino | R-009-51, R-009-52, [plan 009 §1](../../specs/009-base-placement-charging/plan.md) "Muerte con base" |
| Morir en la base no sube el contador de visitas | Solo las zonas `FARM` cuentan | [plan 009 §1](../../specs/009-base-placement-charging/plan.md) (pregunta 12) |
| Los objetos caídos guardan su estado en JSON al descargar la zona | Es el mismo camino que usará la 010 al cargar | R-009-17, plan 009 §1, [plan 010](../../specs/010-save-profile-world/plan.md) |
| Los caducados se descartan al cargar, con la hora actual | Un guardado viejo no resucita objetos | R-010-30 |
| El spawner recibe el reloj inyectado | Los tests usan un reloj falso sin tocar el autoload | [plan 008 §6](../../specs/008-death-recovery/plan.md) (aviso P10) |
| `World` se congela con `process_mode`, sin pausar el árbol | La pantalla de transferencia sigue corriendo | [plan 008 §1](../../specs/008-death-recovery/plan.md) |

## Relación con otros sistemas

- Usa [equipment.md](equipment.md) (`get_piece`, `take_slots`) y [ui.md](ui.md) (`ContainerScreen`, `UIManager.close`).
- Usa [battery.md](battery.md) (`battery_depleted`, `add`), [inventory.md](inventory.md) (`take_from`, `take_amount_from`),
  [interaction.md](interaction.md) (el objeto es interactuable), [world_zones.md](world_zones.md) (visitas, repoblación,
  `SeededRng`) y [combat.md](combat.md) (`cancel_swing`, XP).
- Lo usan [enemies.md](enemies.md) y [loot.md](loot.md) (material del zombi), [ui.md](ui.md) (`TransferScreen`, que
  sustituye a `GameOverScreen`) y [save.md](save.md) (guardado).

## Trampas y límites

- **Durabilidad y `uid` de pila (R-008-11):** desde la spec 011 se conservan al caer, recoger, tirar y guardar
  ([inventory.md](inventory.md), R-011-09, R-011-10). Una pieza que se rompe sale del equipo y se pierde, no pasa
  por el inventario ([equipment.md](equipment.md)).
- Cae el inventario, brazos y piernas; el Core equipado se queda (`keeps_core`). Un Core de repuesto en el inventario
  cae como cualquier pila. La muerte con las piernas perdidas obliga a volver a 0.5 m/s: es intencionado
  ([spec 015 pregunta 4](../../specs/015-pieces-slots-degradation/spec.md)).
- El golpe mortal desgasta su pieza **antes** de restar la batería, así que desgasta (o rompe) los brazos y no el Core.
  Si los rompe, se pierden y no caen.
- Un objeto caído tiene tantas ranuras como pilas recibió: dos pilas de chatarra que se fusionan al caer dejan una
  ranura vacía.
- Con la chatarra de un zombi, recoger pasa de un toque a tres (abrir, "Coger todo", cerrar): riesgo anotado en
  [spec 015 pregunta 17](../../specs/015-pieces-slots-degradation/spec.md).
- Las pilas parciales del mismo item se fusionan al caer: "tal como estaban" se cumple por item y cantidad, no por ranura. Una pieza no se fusiona nunca.
- Contador de visitas y objetos caídos se guardan en disco ([save.md](save.md)). `DroppedItem.to_data()` usa solo tipos
  JSON (`SaveFields`) y guarda `durability` y `uid` de cada pila.
- `GameManager` es un autoload: una muerte en un test deja la visita en 1. Las suites que instancian `main.tscn` o un
  `DeathController` llaman a `clear_visit_counts()` **antes** de instanciar.
- El bloqueo de input y el congelado de `World` van por motivos (`DEATH`, `TRAVEL`, `SCREEN`): terminar el viaje no
  levanta el bloqueo de la muerte ([movement.md](movement.md)).
- Salir por una salida y morir en el mismo paso de física suma dos visitas a la zona de origen (muerte y salida):
  aceptado en [plan 009 §5.3](../../specs/009-base-placement-charging/plan.md).
- Un objeto puede verse hasta 1 s tras caducar (resolución del `Timer`). Sin cuenta atrás ni marcador (ACTION_PLAN 4.1).
- Morir justo en el punto de reaparición deja el objeto bajo el robot; se abre igual con "Interactuar".
- R-008-45 (FPS en Android): la spec lo da por verificado a mano, pero [tasks.md](../../specs/008-death-recovery/tasks.md)
  (T-008-15) anota que no se registró dispositivo ni FPS mínimo.

## Cómo extenderlo

- Otro modo de juego: nuevo `RulesetData` `.tres` en `resources/rulesets/`, registrado en el catálogo; si necesita un
  campo nuevo, léelo en `DeathController` (nunca compares el id).
- Otro origen de objetos caídos: llamar a `drop_stacks` o `drop_from_slot` del spawner desde quien cablee el evento;
  se abre solo con `DroppedItemFlow`.
- Cambiar dónde se reaparece: `Main._respawn_at` y el destino de `_travel_to_base_for_respawn`; no hay otro sitio.

## Tests

| Archivo | Verifica |
|---|---|
| `tests/unit/test_ruleset_resources.gd` | `normal.tres`, configs contra BALANCE, sin comparaciones con el id |
| `tests/unit/test_dropped_item_rules.gd` | Caducidad: límite exacto, tiempo negativo |
| `tests/unit/test_time_service.gd` | Contrato, reloj local, solo `local_time_service.gd` lee `Time` |
| `tests/unit/test_dropped_item.gd` | Pilas, uid, interactuar abre y no coge, `reset`, JSON con `durability`, `uid` y `slot_count`, prompt "Abrir" ES/EN |
| `tests/integration/test_dropped_item_flow.gd` | Abre la pantalla con cabecera, coger todo / elegir / dejar, caducidad con la pantalla abierta, vacío se libera al cerrar |
| `tests/unit/test_transfer_screen.gd` | Oculta hasta `play()`, `finished` una vez, absorbe toques, textos |
| `tests/integration/test_dropped_item_spawner.gd` | Pool, hora, caducidad, objeto reutilizado limpio; guardar al descargar y restaurar (caducados descartados); una pieza sobrevive a tirar, recoger y guardar; pila de pieza inválida perdida; una ranura por pila y `slot_count` guardado y restaurado |
| `tests/integration/test_save_load.gd`, `test_save_triggers.gd` | Objetos caídos tras cerrar y abrir, caducidad al cargar; guardar tras morir sin pisar la reaparición |
| `tests/integration/test_death_controller.gd` | Una muerte, un `player_died`; XP y ranuras; reaparición; ruleset a mano; morir en la base no cuenta visita; una pieza cae y se recupera con su `uid`; brazos y piernas caen y el Core se queda, Core de repuesto, ruleset sin `keeps_core`, golpe mortal sobre los brazos, solo piezas crean objeto |
| `tests/integration/test_main_scene.gd` | Pantallas cerradas, robot congelado, bucle morir-reaparecer en la base-recuperar, fallo del viaje de reaparición, muerte colocando o moviendo |
