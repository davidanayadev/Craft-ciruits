# Tareas 009 — Escena de base, viaje entre zonas, colocación libre y estación de carga

> Orden de ejecución. Cada tarea deja el proyecto compilando y los tests en verde. Marcar `[x]` al terminar.
> Requisito previo: la spec 008 en estado *Hecho* y fusionada; rama `feat/009-base-placement-charging` desde `main`.

- [ ] **T-009-01** Comprobar los 7 puntos **(verificar)** de plan §5 en la referencia de clases de Godot 4.7.2
  (`--doctool`) y con scripts de prueba en headless (fuera del repo). Anotar el resultado en un §5.1 nuevo del plan
  y, si un punto falla, ajustar el plan antes de seguir. Cubre: — (prerrequisito de R-009-01, 02, 07, 28, 55, 56).
  Verifica: §5.1 escrito.
- [ ] **T-009-02** Test primero: `test_zone_resources.gd` (casos 009), `test_build_grid_data.gd`,
  `test_structure_resources.gd`, `test_recipe_resources.gd` y los casos 009 de `test_data_catalog.gd`. Después,
  `ZoneData` (`kind`, `scene_path`, `counts_visits`), `BuildGridData`, `StructureData`, `RecipeData`,
  `RecipeIngredientData`, `DataCatalog` (`zones` por `zone_id`, una sola `BASE`, `structures`, `recipes`),
  `DataRegistry` y los `.tres` de plan §4 (la escena de la base aún no existe: `base.tres` apunta a la ruta y el
  test de escena llega en T-009-08). Cubre: R-009-01 (datos), R-009-23, R-009-24, R-009-61. Verifica: tests de
  datos en verde, incluidos los de catálogo de las specs 004 a 008.
- [ ] **T-009-03** Test primero: `test_build_grid.gd`. Después, `BuildGrid`. Cubre: R-009-25, R-009-26,
  R-009-27, R-009-28, R-009-31, R-009-45, R-009-58 (regla). Verifica: tests sin árbol de escena en verde.
- [ ] **T-009-04** Test primero: `test_crafting_system.gd` y los casos `remove_many` de `test_inventory_rules.gd` y
  `test_inventory_component.gd`. Después, `CraftingSystem`, `InventoryRules.can_remove_many` / `remove_many` e
  `InventoryComponent.remove_many`. Cubre: R-009-62, R-009-39 (regla). Verifica: tests en verde.
- [ ] **T-009-05** Test primero: casos 009 de `test_player_input.gd`, `test_game_manager.gd`, `test_event_bus.gd`,
  `test_battery_component.gd` y `test_death_controller.gd`. Después, motivos de bloqueo en `PlayerInput` (y sus
  llamadas en `main.gd`, `hud.gd` y los tests que hoy pasan un solo argumento), zona actual en `GameManager`,
  eventos `zone_changed`, `structure_built`, `player_recharged`, y `DeathController` contando visitas solo si la
  zona `counts_visits()`. Añadir `player_recharged` a architecture §7 y `structures` a §8. Cubre: R-009-07
  (bloqueo), R-009-09, R-009-48 (señal), R-009-52 (contador), R-009-57 (bloqueo). Verifica: suite completa en
  verde (es el cambio que toca más tests existentes).
- [ ] **T-009-06** Test primero: `test_exit_point.gd` y casos 009 de `test_green_zone.gd`. Después, `Zone`,
  `ExitPoint` (destino como `ZoneData`), `FarmZone extends Zone` y el `ExitPoint` de la zona verde (destino
  `base.tres`, junto al `SpawnPoint`). Cubre: R-009-10, R-009-12. Verifica: tests de la zona verde de las specs 004 a 008 sin cambios en
  verde.
- [ ] **T-009-07** Test primero: casos 009 de `test_dropped_item_spawner.gd`. Después, `unbind_zone` y la
  restauración en `bind_zone` (con caducados descartados). Cubre: R-009-04 (objetos caídos), R-009-17. Verifica:
  tests de la 008 sobre objetos caídos sin cambios en verde.
- [ ] **T-009-08** Test primero: `test_base_zone.gd` y `test_repair_bench.gd`. Después, `base.tscn` con
  `BaseZone` (con la vista previa), `BuildArea` (dibujo de la cuadrícula), `RepairBench`, `ExitPoint` (destino
  `green_zone.tres`), límites,
  luces y decoración (plan §1 "Escena de la base"); `reserved_cells` y `area_origin_local` de `base_grid.tres`
  según el trazado. Cubre: R-009-18 (escena), R-009-19, R-009-21, R-009-63. Verifica: tests en verde; abrir la
  escena en el editor sin avisos.
- [ ] **T-009-09** Test primero: `test_charging_station.gd`. Después, `charging_station.tscn` y `ChargingStation`.
  Cubre: R-009-46, R-009-47, R-009-48, R-009-49. Verifica: tests en verde.
- [ ] **T-009-10** Test primero: `test_base_structures.gd`. Después, `BaseStructures` (estado, `place`, `move`,
  `bind_base` / `unbind_base`, materiales `preview_valid.tres` / `preview_invalid.tres`, interacciones de las estaciones), `Robot.get_footprint_radius`. Cubre: R-009-20, R-009-29, R-009-30, R-009-32, R-009-35 (operación),
  R-009-36 (operación), R-009-38 (regla), R-009-39 (operación), R-009-41, R-009-42, R-009-50, R-009-58. Verifica:
  tests en verde.
- [ ] **T-009-11** Test primero: `test_zone_loader.gd` y `test_loading_screen.gd`. Después, `ZoneLoader`,
  `LoadingScreen` y `CombatFeedback.release_all`; `ZoneLoader` precalienta los pools al cargar una
  zona `FARM` y sube la visita al descargar la de origen de una salida; en `main.tscn`, `ZoneSlot` vacío y los nodos `ZoneLoader`,
  `BaseStructures` y `LoadingScreen`; en `main.gd`, arranque en la base, `travel_started` / `travel_finished` /
  `travel_failed` (pantalla, congelado, motivo `TRAVEL`), cableado por zona con `zone_loaded`, y la reposición
  pasa a `ZoneLoader`. Adaptar la preparación de `test_main_scene.gd` y `test_hud_attack_input.gd` con
  `_travel_to_green_zone()` (plan §7). Cubre: R-009-02 a R-009-09, R-009-11, R-009-13 a R-009-18. Verifica: suite
  completa en verde.
- [ ] **T-009-12** Test primero: casos R-009-51 a 53 de `test_main_scene.gd`. Después, reaparición en la base por
  `travel_to` en `Main._on_transfer_finished` y `travel_finished`, y en el sitio si ese viaje falla. Cubre: R-009-51, R-009-52, R-009-53 (con la
  pantalla de T-009-14, el caso de colocación se completa allí). Verifica: tests de muerte de la 008 en verde con
  el punto de reaparición nuevo.
- [ ] **T-009-13** Test primero: `test_build_screen.gd` y `test_build_flow.gd`. Después, `BuildScreen`, `Robot.request_build` /
  `build_requested`, `BuildFlow` (banco → pantalla) y la pantalla `build` en `screens.tres`. Cubre: R-009-38,
  R-009-39, R-009-64, R-009-65. Verifica: tests en verde.
- [ ] **T-009-14** Test primero: `test_placement_screen.gd`, casos 009 de `test_hud.gd`, `test_input_map.gd` y
  `test_ui_manager.gd`. Después, `PlacementScreen` (modos, toque → celda, botones, acción `confirm`), pantalla
  `placement` en `screens.tres`, `UIManager.is_open`, `UIScreen.handle_back` / `on_closed`, botón "Editar base" del `Hud`, y en `BuildFlow` la apertura en
  `PLACE` tras `build_requested` y el conmutador de edición. Cubre: R-009-33 a R-009-37, R-009-40, R-009-43,
  R-009-44, R-009-50 (al cerrar), R-009-53 (colocación), R-009-55 a R-009-57, R-009-59, R-009-60. Verifica: suite
  completa en verde.
- [ ] **T-009-15** Claves de traducción de plan §4 en `strings.csv` (ES + EN) y `.translation` reimportados.
  Cubre: R-009-07, R-009-10, R-009-40, R-009-46, R-009-59, R-009-63, R-009-64 (textos). Verifica: `i18n-auditor`
  sin claves que falten ni sin usar.
- [ ] **T-009-16** Test primero: `test_base_loop.gd`. Después, lo que falte para el bucle completo, y el botón
  "Llenar base" del `DebugHud`. Cubre: R-009-54, R-009-22 (herramienta). Verifica: test en verde.
- [ ] **T-009-17** Pruebas manuales en PC y en el Android de gama media (APK debug): criterio de hecho del spec
  §5 completo, toque y ratón en la colocación, botón atrás de Android cancela, y FPS ≥ 30 durante 60 s con la base
  llena. Anotar resultados en un §5.2 nuevo del plan. Cubre: R-009-22, R-009-40, R-009-54, R-009-56 (atrás).
  Verifica: §5.2 escrito.

## Cierre

- [ ] Definición de hecho (constitución §4) revisada: `godot-runner`, `i18n-auditor` y `balance-auditor` en
  paralelo, después `architecture-guardian`.
- [ ] `CLAUDE.md` ("Repository state") actualizado.
- [ ] Estado del spec actualizado en `spec.md` y en `specs/README.md §6`.
