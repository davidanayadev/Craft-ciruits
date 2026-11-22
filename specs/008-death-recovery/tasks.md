# Tareas 008 — Muerte, `RulesetData`, objetos caídos y recuperación

> Orden de ejecución. Cada tarea deja el proyecto compilando y los tests en verde. Marcar `[x]` al terminar.
> Requisito previo: la spec 007 en estado *Hecho* y fusionada; rama `feat/008-death-recovery` desde `main`.

- [x] **T-008-01** Comprobar los 7 puntos **(verificar)** de plan §5 en la referencia de clases de Godot 4.7.2
  (`--doctool`) y con scripts de prueba en headless (fuera del repo). Anotar el resultado en un §5.1 nuevo del plan
  y, si un punto falla, ajustar el plan antes de seguir. Cubre: — (prerrequisito de R-008-19, 22, 29, 30, 38).
  Verifica: §5.1 escrito.
- [x] **T-008-02** Test primero: `test_dropped_item_rules.gd` y `test_time_service.gd`. Después,
  `DroppedItemRules`, `ITimeService`, `LocalTimeService` (`scripts/services/`) y `tests/support/fake_time_service.gd`.
  Cubre: R-008-19, R-008-21, R-008-24 (regla). Verifica: tests sin árbol de escena en verde.
- [x] **T-008-03** Test primero: casos nuevos de `test_seeded_rng.gd` (con respuesta conocida calculada fuera de
  Godot). Después, `SeededRng.derive_seed_for_visit` y `STREAM_ENEMY_DROP`. Mover `FIRST_VISIT` a `ZonePopulation`
  y actualizar sus referencias (`main.gd`, `test_main_scene.gd`, `test_zombie_spawner.gd`). Cubre: R-008-08 y
  R-008-36 (derivación). Verifica: `test_seeded_rng.gd` entero en verde, con las respuestas fijadas de la 004 sin
  tocar.
- [x] **T-008-04** Test primero: `test_ruleset_resources.gd` y los casos nuevos de `test_data_catalog.gd` y
  `test_enemy_resources.gd`. Después, `RulesetData`, `DeathConfigData`, `DroppedItemConfigData`,
  `EnemyData.drop_table`, `DataCatalog.rulesets` (con el indexado común a los tres tipos),
  `DataRegistry.get_ruleset` y los `.tres` de plan §4. Cubre: R-008-01, R-008-03 (búsqueda en scripts), R-008-04
  (datos), R-008-05. Verifica: tests
  de datos en verde, incluidos los de catálogo de las specs 004 y 006.
- [x] **T-008-05** Test primero: casos nuevos de `test_game_manager.gd` y `test_event_bus.gd`. Después,
  `DevWorldConfigData.ruleset_id`, y en `GameManager` el ruleset, el reloj y el contador de visitas con
  `zone_visit_changed`; en `EventBus`, `player_died` y `player_respawned`. Cubre: R-008-02, R-008-06, R-008-07
  (contador), R-008-19 (exposición), R-008-25 y R-008-31 (firmas), R-008-34 (autoload). Verifica: tests en verde y
  el proyecto abre sin avisos nuevos.
- [x] **T-008-06** Test primero: casos nuevos de `test_inventory_rules.gd` y `test_inventory_component.gd`.
  Después, `InventoryRules.can_split` y `split`, e `InventoryComponent.take_amount_from` (que usa `split`) y
  `clear`. Cubre: R-008-40, R-008-11 (mover una parte), R-008-18 (contenedor reutilizado). Verifica: tests en verde, incluidos los de la 005.
- [x] **T-008-07** Test primero: `test_dropped_item.gd`. Después, `dropped_item.tscn` + `DroppedItem` y la clave
  `PROMPT_PICK_UP` (ES + EN). Cubre: R-008-10 a R-008-15, R-008-17, R-008-18 (reset). Verifica: tests en verde.
- [x] **T-008-08** Test primero: `integration/test_dropped_item_spawner.gd` con `FakeTimeService`. Después,
  `DroppedItemSpawner` (pool, `bind_zone`, las tres formas de soltar, `discard_expired`, `Timer`, `to_data`).
  Cubre: R-008-10 (posición local), R-008-14, R-008-18, R-008-20, R-008-22, R-008-32 (objetos independientes).
  Verifica: tests en verde.
- [x] **T-008-09** Test primero: casos nuevos de `test_green_zone.gd`, `test_zombie.gd` y `test_zombie_spawner.gd`,
  y `zombie.gd` en la lista de `test_no_global_rng.gd`. Después, `FarmZone.generate(seed, visit)` y `repopulate`,
  la semilla de las cajas con visita, `Zombie.activate(..., drop_seed)` con su tirada y `loot_dropped`, y el
  reenvío `enemy_loot_dropped`. Actualizar las llamadas a `generate` y `activate` de los tests existentes (también la de
  `test_robot_combat.gd`), sin cambiar lo que comprueban. Cubre:
  R-008-08, R-008-09 (zona), R-008-35, R-008-36. Verifica: tests en verde, incluidos los de las specs 004 y 006.
- [x] **T-008-10** Test primero: casos nuevos de `test_experience_component.gd` y
  `test_melee_attack_component.gd`, e `integration/test_death_controller.gd`. Después,
  `ExperienceComponent.reset`, `MeleeAttackComponent.cancel_swing`, `Robot.respawn_at` y `DeathController` (con
  `clear_visit_counts()` en `before_each` y `after_each` del test). Cubre: R-008-03, R-008-07,
  R-008-25 a R-008-28, R-008-31 (reaparición), R-008-32, R-008-34. Verifica: tests en verde.
- [x] **T-008-11** Test primero: `test_transfer_screen.gd`. Después, `transfer_screen.tscn` + `TransferScreen` y la
  clave `TRANSFER_TITLE` (ES + EN). Cubre: R-008-04 (duración), R-008-29 (pantalla), R-008-31 (`finished`).
  Verifica: tests en verde.
- [x] **T-008-12** Test
  primero: `test_quantity_selector.gd`, los casos nuevos de `test_inventory_screen.gd` (sustituyendo
  `test_r_005_25_cells_cannot_be_pressed`) y el de `test_robot_inventory.gd`. Después, `QuantitySelector`, celda
  seleccionada en `InventoryGrid`/`InventorySlotView`, selección y botón "Tirar" en `InventoryScreen`,
  `Robot.request_throw` y la clave `INVENTORY_THROW` (ES + EN). Cubre: R-008-38 a R-008-42. Verifica: tests de UI en
  verde, incluidos los demás de la 005.
- [x] **T-008-13** Main: `World/DroppedItemPool` precalentado, `World/DroppedItems`, `%DeathController`,
  `%TransferScreen`; zona generada con `GameManager.get_visit_count`; repoblación al cambiar la visita;
  `player_died` → cerrar pantallas, bloquear, transferencia y congelar; `finished` → reaparecer, reanudar y
  desbloquear; `throw_requested` y `enemy_loot_dropped` → spawner. Borrar `GameOverScreen`, su test y sus dos
  claves; `test_hud.gd` usa otra clave de prompt. Escribir antes los casos nuevos de `test_main_scene.gd` y pasar
  `test_r_004_16_*` y `test_r_005_29_*` a la transferencia como dice plan §5 (R-008-30), con
  `clear_visit_counts()` en `before_each` y `after_each` de `test_main_scene.gd` y `test_hud_attack_input.gd`. Cubre: R-008-06, R-008-09, R-008-15, R-008-16,
  R-008-23, R-008-24, R-008-29, R-008-30, R-008-31, R-008-33, R-008-35, R-008-37, R-008-39, R-008-43, R-008-44.
  Verifica: `godot-runner` con toda la suite en verde.
- [x] **T-008-14** Pasos manuales en PC: criterio de hecho del spec §5 completo (morir por consumo, por un golpe
  propio y por un zombie; recoger con el inventario lleno; esperar la caducidad de 5 minutos; drop de zombie igual
  con la misma semilla y visita; tirar una pila entera y una parte). Cubre: R-008-44 y repaso de R-008-22, 29, 38,
  39. Verifica: resultado anotado aquí.
  **Resultado (2026-11-16):** el usuario confirma que todo va bien ("todo ok"). No dio el detalle paso a paso.
- [x] **T-008-15** APK debug en el Android de gama media: selector y botón "Tirar" con el dedo (deslizador
  incluido), recoger con "Interactuar", transferencia y reaparición, y la medición de R-008-45 (máximo de zombies,
  5 items tirados, una muerte; FPS ≥ 30). Cubre: R-008-38, R-008-39, R-008-45. Verifica: dispositivo, FPS mínimo y
  triángulos del objeto caído anotados aquí.
  **Resultado (2026-11-16):** el usuario confirma que todo va bien ("todo ok"). **Sin anotar:** dispositivo y FPS
  mínimo (no se facilitaron; R-008-45 queda sin cifra registrada). El objeto caído es un `BoxMesh`: 12 triángulos.

## Cierre

- [x] Definición de hecho (constitución §4) revisada: `godot-runner`, `i18n-auditor` y `balance-auditor` en
  paralelo, después `architecture-guardian` una vez. Resultado (2026-11-16): 725/725 tests, 139 scripts cargan,
  i18n y balance sin hallazgos, arquitectura "OK con observaciones" (aplicadas, plan §7). Las pruebas
  manuales (T-008-14 y T-008-15) las confirmó el usuario el mismo día.
- [x] `CLAUDE.md` "Repository state" actualizado (spec 008 hecha: muerte real, objetos caídos, tirar items).
- [x] Condición de entrada anotada en la spec 015: `ItemStack` con durabilidad y `uid` debe pasar por
  `InventoryRules` para que el objeto caído los conserve (R-008-11). La spec 015 aún no existe: queda anotada en
  su fila de `specs/README.md §6`.
- [x] Estado del spec actualizado en `spec.md` y en `specs/README.md §6`.
