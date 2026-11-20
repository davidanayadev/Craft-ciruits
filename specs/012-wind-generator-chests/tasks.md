# Tareas 012 — Generador eólico y cofres

> Orden de ejecución. Cada tarea deja el proyecto compilando y los tests en verde. Marcar `[x]` al terminar.
> Requisito previo: la spec 011 *Hecho* y fusionada; rama `feat/012-wind-generator-chests` desde `main`.

- [x] **T-012-01** Comprobar en la referencia de clases de Godot 4.7.2 (`--doctool`) las API del plan. Hecho al
  planificar (2026-11-19): plan §5.1. Queda un punto **(verificar)** en Android (toque emulado una sola vez en
  `_gui_input`), que cubre M3 en T-012-15. Cubre: — (prerrequisito de R-012-21, R-012-22, R-012-46).
  Verifica: plan §5.1 escrito.
- [x] **T-012-02** Test primero: casos 012 de `test_structure_resources.gd`, `test_recipe_resources.gd`,
  `test_consumable_resources.gd` (nuevo) y `test_data_catalog.gd`. Después, `StructureData.max_count`,
  `WindGeneratorData`, `StorageChestData`, `ContainerConfigData`, `ConsumableData`, el icono SVG (con
  `CREDITS.md`), los `.tres` de §4 (escenas de cofre y generador como marcador vacío hasta T-012-09), el catálogo y
  las claves `STRUCTURE_*` e `ITEM_PORTABLE_BATTERY`. Cubre: R-012-01 a R-012-06 (datos). Verifica: tests en verde
  y los de las specs 009 y 011 sin cambios.
- [x] **T-012-03** Test primero: casos 012 de `test_inventory_rules.gd`. Después, `InventoryRules.can_merge`,
  `move_to_slot`, `transfer` y sus claves (D12), sobre `can_split` / `split` / `add_stack`. Cubre: R-012-29,
  R-012-30, R-012-32 (regla), R-012-33, R-012-34. Verifica: tests en verde y los de las specs 005, 008 y 011 sin
  cambios.
- [x] **T-012-04** Test primero: casos 012 de `test_inventory_component.gd`. Después,
  `InventoryComponent.move_to_slot` y `transfer_to` con una `inventory_changed` por inventario cambiado, origen
  primero. Cubre: R-012-32 (componente), R-012-34. Verifica: tests en verde.
- [x] **T-012-05** Test primero: `test_wind_generator_rules.gd` y `test_wind_generator_component.gd` (nuevos) y
  el caso 012 de `test_time_service.gd`. Después, `WindGeneratorRules` (D7) y `WindGeneratorComponent` (`start`,
  lecturas, `collect` con D8, guardado). Cubre: R-012-15 a R-012-20 (regla y componente). Verifica: tests en verde.
- [x] **T-012-06** Test primero: casos 012 de `test_battery_component.gd`, sustituyendo
  `test_r_010_11_load_above_maximum_is_rejected` por los de R-012-14 (D11, plan §5.4). Después,
  `BatteryComponent.set_maximum_bonus` y la carga guardada pendiente (con `push_error` al borrarse sin aplicarse). Cubre: R-012-11 a R-012-14 (componente),
  R-012-40 (batería). Verifica: tests en verde; el resto de `test_r_010_*` de la batería sin cambios.
- [x] **T-012-07** Test primero (`gut-test-writer`, varios requisitos): `test_consumable_rules.gd` (nuevo),
  `integration/test_robot_consumable.gd` (nuevo) y casos 012 de `test_hud.gd` y `test_inventory_screen.gd`.
  Después, `ConsumableRules`, `PlayerInput.is_use_consumable_just_pressed`, `Robot.use_consumable` /
  `request_use_consumable` / `use_refused` (por ranura, D4), `Hud.show_notice` con argumentos y `use_refused` (D18, D19), y el botón
  "Usar" de la pantalla de inventario con `INVENTORY_USE`, `ERR_BATTERY_FULL`, `ERR_NO_PORTABLE_BATTERY`. Cubre:
  R-012-23, R-012-24, R-012-25. Verifica: tests en verde; `test_r_008_42_screen_never_changes_inventory` sigue en
  verde.
- [x] **T-012-08** Test primero: `test_structure_states.gd` (nuevo), casos 012 de `test_base_structures.gd` y
  `test_event_bus.gd`. Después, `StructureStates` (D5, D6; estados por `uid` en un diccionario; una entrada de cofre sin lista de ranuras es
  inválida), y en `BaseStructures`: `time_service` por defecto (D21), el orden de D5 en `place` y `from_save_data`, límite (D1) en `place`, creación de estado, bonificación (D9),
  `collect_batteries`, `get_chest_contents`, `seconds_to_next_battery`, claves `chests` y `generators` en su parte,
  `structure_used`; `EventBus.batteries_collected` y `chest_closed`; razones de `SaveManager`. Actualizar
  architecture §7 (dos filas) y §8 (subclases en `structures`). Cubre: R-012-09, R-012-10, R-012-11 (base),
  R-012-16 (base sin cargar), R-012-18, R-012-20 (petición), R-012-26, R-012-39 a R-012-42, R-012-44 (eventos).
  Verifica: tests en verde y los de la spec 009 y 010 sin cambios.
- [x] **T-012-09** Test primero: `test_wind_generator.gd` y `test_storage_chest.gd` (nuevos) y casos 012 de
  `test_bench_screen.gd`. Después, `storage_chest.tscn/.gd`, `wind_generator.tscn/.gd` (primitivas, aspas con
  `AnimationPlayer` en bucle, `Label3D`, `Timer` de 1 s, D17), su conexión en `BaseStructures._instantiate`
  (`bind_state` y `used` → `structure_used`), y `MSG_STRUCTURE_LIMIT` en `BenchBuildSection`; claves
  `PROMPT_COLLECT`, `GENERATOR_*`, `MSG_STRUCTURE_LIMIT`. Cubre: R-012-07 (pantalla), R-012-08, R-012-21,
  R-012-22. Verifica: tests en verde; la vista previa del generador no da errores.
- [x] **T-012-10** Test primero: casos 012 de `test_ui_manager.gd`, `test_placement_screen.gd` y
  `test_notice_screen.gd`. Después, en `UIScreen` `closed`, `back_requested`, `closes_on_outside_tap` y su
  `_gui_input` (D16); en `UIManager` `open()` que devuelve la pantalla, `closed` al sacarla y `back_requested` de la
  de arriba por el camino de Escape; `closes_on_outside_tap` y `mouse_filter = 0` explícito en el `Panel` de `bench_screen.tscn` e
  `inventory_screen.tscn` (D16).
  Actualizar architecture §9.5. Cubre: R-012-46, R-012-47 (pantalla), R-012-48. Verifica: tests en verde y los de
  las specs 005 y 009 de `UIManager` sin cambios.
- [x] **T-012-11** Test primero: `test_container_screen.gd` (nuevo) y casos 012 de `test_loot_box.gd`,
  `test_robot_interaction.gd`, `test_main_scene.gd` y `test_ui_manager.gd`, aplicando la tabla de plan §5.4 test a
  test (mover, renombrar o sustituir; ninguno sin sustituto). Después, `InventoryGrid.set_empty_cells_pressable` y su celda (D14), `container_screen.tscn/.gd`
  (un solo panel con `mouse_filter = 0`, rejilla de 2 columnas, selector, "Transferir", "Coger todo", `%Notice`
  (D22), `closes_on_outside_tap`), `LootBox` como
  contenedor (`container_config`, sin desactivarse, `opened` en cada interacción), `Main._on_box_opened` con
  `ContainerScreen`, `screens.tres`; borrar `loot_screen.gd/.tscn` y `test_loot_screen.gd`; claves
  `CHEST_TITLE`, `CONTAINER_*`, `ERR_PARTIAL_SWAP`, `ERR_SLOT_FULL`, `ERR_NO_ROOM`, sin `LOOT_TAKE_ALL`. Cubre:
  R-012-06 (caja), R-012-27 a R-012-35 (pantalla), R-012-37. Verifica: tests en verde; `grep LootScreen` vacío
  fuera de `specs/` y `docs/`.
- [x] **T-012-12** Test primero: `integration/test_structure_use_flow.gd` (nuevo), casos 012 de
  `test_main_scene.gd` (R-012-47, también `test_r_012_47_outside_touch_does_not_reach_joystick`, punto
  **(verificar)** de plan §5.1) y de `test_build_flow.gd`. Después, `StructureUseFlow` (cofre →
  pantalla y `chest_closed` con cambios, D15; generador → `collect_batteries` y aviso con tiempo) y en `Main` /
  `main.tscn`: `StructureStates` bajo `BaseStructures`, `StructureUseFlow`, `time_service` de `BaseStructures` y la
  bonificación conectada a la batería antes de cargar (D9). Actualizar architecture §9.1 (los usos de cofre y
  generador llegan como `structure_used`). Cubre: R-012-07, R-012-12 (juego), R-012-20 (aviso),
  R-012-27 (flujo), R-012-47. Verifica: tests en verde.
- [x] **T-012-13** Test primero: casos 012 de `test_save_load.gd`, `test_save_triggers.gd`,
  `test_save_fixtures.gd`, `test_base_loop.gd`, `test_death_controller.gd`, `test_zone_memory.gd` y
  `test_green_zone.gd`. Después, lo que falte para que pasen (se espera poco: T-012-05 a T-012-12 ya lo dejan
  hecho). Cubre: R-012-12, R-012-13 (reaparecer), R-012-14 (recarga), R-012-16 (app cerrada), R-012-36, R-012-38,
  R-012-39, R-012-43, R-012-44. Verifica: `godot-runner` con la suite completa en verde.
- [x] **T-012-14** Revisar textos: todas las claves nuevas de plan §4.1 en `strings.csv` (ES + EN), ninguna
  sobrante. Cubre: R-012-45. Verifica: tests de claves en verde; `i18n-auditor` en el cierre.
- [x] **T-012-15** Pasos manuales M1 y M2 (PC) y M3 (Android, APK debug) de plan §5.3; anotar el resultado en plan
  §5.5 (nueva). Cubre: R-012-22 y el resto en el juego, el punto **(verificar)** de plan §5.1. Verifica: plan §5.5
  escrito.

## Cierre

- [x] Definición de hecho (constitución §4): `godot-runner`, `i18n-auditor` y `balance-auditor` en paralelo, y
  después `architecture-guardian`.
- [x] ACTION_PLAN 2.6: el cofre usa un `InventoryComponent` (plan §7); marcar las Tareas 2.5 y 2.6.
- [x] `system-documenter spec 012` (base y estructuras, inventario, batería, UI, botín, guardado).
- [x] CLAUDE.md "Repository state": spec 012 hecha, `ContainerScreen` en lugar de `LootScreen`, siguiente spec 013.
- [x] Estado del spec actualizado en `spec.md` y en `specs/README.md §6`.
