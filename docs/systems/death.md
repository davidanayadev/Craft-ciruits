# Muerte, objetos caídos y recuperación

> Al llegar la batería a 0 el robot suelta su inventario donde cae, la zona se repone con la visita siguiente y, tras una
> pantalla de transferencia, reaparece con la batería llena. Lo caído se recoge con "Interactuar" y caduca.
> Specs: [008](../../specs/008-death-recovery/spec.md) · Última actualización: spec 008

## Piezas

| Pieza | Tipo | Archivo | Responsabilidad |
|---|---|---|---|
| `DeathController` | Nodo de `main.tscn` | `game/scenes/death/death_controller.gd` | Aplica el ruleset a cada robot enlazado y lo hace reaparecer; no guarda estado |
| `RulesetData` | Resource | `game/scripts/data/ruleset_data.gd` | Reacción a la muerte como dato (`drops_inventory`, `keeps_xp`, `keeps_core`, `respawn_battery_ratio`) |
| `normal.tres` | Recurso | `game/resources/rulesets/normal.tres` | Único ruleset (`NORMAL`) |
| `DeathConfigData` / `death.tres` | Resource | `game/scripts/data/death_config_data.gd`, `resources/config/death.tres` | Duración de la transferencia |
| `DroppedItem` | Escena (`Node3D`) | `game/scenes/entities/dropped_item.gd`, `.tscn` | Pilas en el suelo, con su `InventoryComponent` y su `InteractableComponent` |
| `DroppedItemSpawner` | Nodo (bajo `World`) | `game/scenes/entities/dropped_item_spawner.gd` | Crea, caduca y devuelve al pool los objetos caídos |
| `DroppedItemRules` | Sistema puro | `game/scripts/systems/dropped_item_rules.gd` | Regla de caducidad (`is_expired`) |
| `DroppedItemConfigData` / `dropped_items.tres` | Resource | `game/scripts/data/dropped_item_config_data.gd`, `resources/config/dropped_items.tres` | Vida de un objeto caído |
| `ITimeService`, `LocalTimeService` | Servicio | `game/scripts/services/` | Contrato del reloj e implementación con el reloj del dispositivo |
| `GameManager` | Autoload | `game/scripts/autoload/game_manager.gd` | Ruleset, contador de visitas por zona y `get_time_service()` |
| `TransferScreen` | `Control` | `game/scenes/ui/transfer_screen.gd`, `.tscn` | "Transferencia de Consciencia"; fuera de `UIManager` |
| `Main` | Escena | `game/scenes/main.gd` | Cablea todo: pantalla, congelado de `World`, repoblación y punto de reaparición |

## Cómo funciona

1. `BatteryComponent` emite `battery_depleted` una vez por llegada a 0, sea cual sea la causa (consumo, un golpe propio
   o uno de zombi). `DeathController.bind(robot)` la escucha ([battery.md](battery.md)).
2. `_on_battery_depleted`, en este orden: `robot.melee.cancel_swing()` (un robot muerto no golpea; si no, un impacto
   pendiente mataría a un zombi cuya devolución al pool quedaría detrás de la repoblación); si
   `ruleset.drops_inventory`, `DroppedItemSpawner.drop_inventory()` (un solo objeto con todas las pilas; con el inventario
   vacío no crea nada); si no `ruleset.keeps_xp`, `experience.reset()`; `GameManager.increment_visit_count(zona)`;
   y al final `EventBus.player_died(player_uid)`, para que quien escuche ya vea el inventario en el suelo.
3. `GameManager` emite `zone_visit_changed`. `Main` repuebla en diferido la zona cargada
   ([world_zones.md](world_zones.md)) y vuelve a llamar `discard_expired_now()`.
4. `Main._on_player_died` (solo si el uid es el del robot local): `UIManager.close_all()`, bloquea el input, suelta el
   joystick y el botón de ataque, `TransferScreen.play()` y congela `World` en diferido (`process_mode = DISABLED`).
5. `TransferScreen` avanza con `advance(delta)` desde su `_process` y emite `finished` al cumplir la duración.
6. `Main._on_transfer_finished` llama `DeathController.respawn(robot, zone.get_spawn_position())`. Calcula la batería
   (máximo × `respawn_battery_ratio`), llama `Robot.respawn_at` y emite `EventBus.player_respawned`. Si `respawn`
   devuelve `false` (robot vivo o sin ruleset: `push_error`), `Main` no reanuda `World`.
7. Recoger: `DroppedItem` conecta `interacted` y pasa todas las ranuras al inventario de quien interactúa con
   `take_from`; entra lo que cabe en orden de ranura. Si algo no cabe, el inventario emite `overflowed` y el HUD muestra
   el aviso de [inventory.md](inventory.md); el objeto se queda con el resto y su hora original. Si queda vacío emite
   `emptied` y el spawner lo devuelve al pool en diferido.
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

## Datos

| Recurso | Clase | Valores en BALANCE |
|---|---|---|
| `rulesets/normal.tres` | `RulesetData` | [§1.1](../../BALANCE.md) (batería al reaparecer), PMV §2.4 |
| `config/death.tres` | `DeathConfigData` | [§11](../../BALANCE.md) "Muerte" |
| `config/dropped_items.tres` | `DroppedItemConfigData` | [§7.2](../../BALANCE.md) |
| `config/dev_world.tres` (`ruleset_id`) | `DevWorldConfigData` | No es balance |

`DataRegistry.get_ruleset(id)` resuelve el id al recurso ([data_catalog.md](data_catalog.md)).

## Decisiones

| Decisión | Por qué | Fuente |
|---|---|---|
| La reacción a la muerte se lee de `RulesetData`; ningún script compara su id | El Hardcore de v1.1 será otro `.tres` | R-008-03, [plan 008 §1](../../specs/008-death-recovery/plan.md) |
| `player_died` lo emite `DeathController`, no la batería | Es la reacción del ruleset, no un hecho de la batería | [plan 008 §1](../../specs/008-death-recovery/plan.md) (alternativas descartadas), architecture §7 |
| Un solo objeto por muerte con todas las pilas; recoger sin pantalla | Pregunta 3 cerrada | [spec 008 §6](../../specs/008-death-recovery/spec.md) |
| `DroppedItem` guarda sus pilas en un `InventoryComponent` | Reutiliza apilado y "lo que cabe"; no crea ni pierde unidades | R-008-11, [plan 008 §1](../../specs/008-death-recovery/plan.md) |
| Objetos caídos bajo `World`, fuera de la zona, con posición `(zone_id, local)` | Repoblar o descargar la zona no los toca | R-008-10, R-008-16, [plan 008 §1](../../specs/008-death-recovery/plan.md) |
| `TransferScreen` fuera de `UIManager` | Escape y "atrás" no deben cerrarla | [plan 008 §1](../../specs/008-death-recovery/plan.md) |
| Reaparece en el `SpawnPoint` de la zona | Hace de base hasta la spec 009 | [spec 008 §6](../../specs/008-death-recovery/spec.md) (pregunta 1) |
| El spawner recibe el reloj inyectado | Los tests usan un reloj falso sin tocar el autoload | [plan 008 §6](../../specs/008-death-recovery/plan.md) (aviso P10) |
| `World` se congela con `process_mode`, sin pausar el árbol | La pantalla de transferencia sigue corriendo | [plan 008 §1](../../specs/008-death-recovery/plan.md) |

## Relación con otros sistemas

- Usa [battery.md](battery.md) (`battery_depleted`, `add`), [inventory.md](inventory.md) (`take_from`, `take_amount_from`),
  [interaction.md](interaction.md) (el objeto es interactuable), [world_zones.md](world_zones.md) (visitas, repoblación,
  `SeededRng`) y [combat.md](combat.md) (`cancel_swing`, XP).
- Lo usan [enemies.md](enemies.md) y [loot.md](loot.md) (material del zombi), [ui.md](ui.md) (`TransferScreen`, que
  sustituye a `GameOverScreen`) y, en el futuro, el guardado (spec 010).

## Trampas y límites

- **R-008-11, durabilidad y `uid` de pila:** `ItemStack` solo tiene `item` y `quantity`, así que solo se garantiza que
  esos dos datos pasan intactos. La spec 014 debe llevar la durabilidad y el `uid` por `InventoryRules` para que sigan
  valiendo ([plan 008 §7](../../specs/008-death-recovery/plan.md)).
- Se pierde y se conserva solo el inventario: `keeps_core` se declara pero no lo aplica nadie hasta la spec 014 (piezas).
- Las pilas parciales del mismo item se fusionan al caer: "tal como estaban" se cumple por item y cantidad, no por ranura.
- Nada se guarda: contador de visitas y objetos caídos viven en memoria (spec 010). `to_data()` ya devuelve solo tipos
  JSON; `from_data` no existe.
- `GameManager` es un autoload: una muerte en un test deja la visita en 1. Las suites que instancian `main.tscn` o un
  `DeathController` llaman a `clear_visit_counts()` **antes** de instanciar.
- Dos escritores del bloqueo de input (`UIManager` y la transferencia); no chocan mientras no se abra una pantalla
  muerto. Un tercero obligaría a un contador de motivos.
- Un objeto puede verse hasta 1 s tras caducar (resolución del `Timer`). Sin cuenta atrás ni marcador (ACTION_PLAN 4.1).
- Morir justo en el punto de reaparición deja el objeto bajo el robot; se recoge igual con "Interactuar".
- R-008-45 (FPS en Android): la spec lo da por verificado a mano, pero [tasks.md](../../specs/008-death-recovery/tasks.md)
  (T-008-15) anota que no se registró dispositivo ni FPS mínimo.

## Cómo extenderlo

- Otro modo de juego: nuevo `RulesetData` `.tres` en `resources/rulesets/`, registrado en el catálogo; si necesita un
  campo nuevo, léelo en `DeathController` (nunca compares el id).
- Otro origen de objetos caídos: llamar a `drop_stacks` o `drop_from_slot` del spawner desde quien cablee el evento.
- Reaparecer en la base (spec 009): cambiar el argumento de `respawn` en `Main._on_transfer_finished`.

## Tests

| Archivo | Verifica |
|---|---|
| `tests/unit/test_ruleset_resources.gd` | `normal.tres`, configs contra BALANCE, sin comparaciones con el id |
| `tests/unit/test_dropped_item_rules.gd` | Caducidad: límite exacto, tiempo negativo |
| `tests/unit/test_time_service.gd` | Contrato, reloj local, solo `local_time_service.gd` lee `Time` |
| `tests/unit/test_dropped_item.gd` | Pilas, uid, recoger (total y parcial), `reset`, JSON, prompt ES/EN |
| `tests/unit/test_transfer_screen.gd` | Oculta hasta `play()`, `finished` una vez, absorbe toques, textos |
| `tests/integration/test_dropped_item_spawner.gd` | Pool, hora, caducidad, objeto reutilizado limpio |
| `tests/integration/test_death_controller.gd` | Una muerte, un `player_died`; XP y ranuras; reaparición; ruleset a mano |
| `tests/integration/test_main_scene.gd` | Pantallas cerradas, robot congelado, bucle morir-reaparecer-recuperar |
