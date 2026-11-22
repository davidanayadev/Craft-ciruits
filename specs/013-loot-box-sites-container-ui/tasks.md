# Tareas 013 — Cajas de loot en sitios variables y nueva pantalla de contenedor

> Orden de ejecución. Cada tarea deja el proyecto compilando y los tests en verde. Marcar `[x]` al terminar.
> Requisito previo: la spec 012 *Hecho* y fusionada; rama `feat/013-loot-box-sites-container-ui` desde `main`.

## Cajas en sitios variables

- [x] **T-013-01** Comprobar en la referencia de clases de Godot 4.7.2 (`--doctool`) las API del plan. Hecho al
  planificar (2026-11-21): plan §5.1, sin puntos pendientes. Cubre: — (prerrequisito de R-013-09, R-013-13).
  Verifica: plan §5.1 escrito.
- [x] **T-013-02** Test primero: `test_r_013_06_box_max_per_site_matches_balance`. Después,
  `ZoneData.box_max_per_site` y `green_zone.tres` (todavía sin uso). Cubre: R-013-06. Verifica: tests en verde.
- [x] **T-013-03** Cajas por sitios y por visita, en un solo paso porque la firma nueva de
  `ZonePopulation.pick_box_markers`, la escena con sitios y `FarmZone` no compilan o no pasan por separado:
  1. Test primero: casos 013 de `test_zone_population.gd`, que sustituyen a los `test_r_004_21_*` (plan §5.3).
  2. Test primero: en `test_green_zone.gd`, los `test_r_013_01_*`, `_02_*`, `_03_*`, `_04_per_site_limit_over_visits`,
     `_07_*`, `_08_*`, `_09_*` y `_10_*`; los helpers de marcadores que recorren sitios; y los cambios de plan
     §5.3 (`test_r_004_11_*` → `test_r_013_02_*`, `test_r_008_08_positions_same_on_every_visit`,
     `test_r_004_21_dev_seed_known_boxes`, aserciones de posición de
     `test_r_008_09_repopulate_closes_boxes_with_new_contents`).
  3. `ZonePopulation.pick_box_markers` por sitios (D2, D3), con el docstring del orden de las llamadas al RNG.
  4. Los 6 sitios y 21 marcadores en `farm_zone_green.tscn` (D7).
  5. `FarmZone`: `_collect_box_sites` de una pasada (D1), RNG por visita (D4), `_place_boxes` compartido por
     `generate()` y `repopulate()` (D5) y el docstring de la clase (visita y contrato del índice plano).
  6. Ajustar los marcadores hasta que pasen los tests de R-013-03, R-013-09 y R-013-10, y fijar las posiciones de
     `test_r_013_02_dev_seed_known_boxes` y la respuesta conocida de `test_r_013_05_known_answer`.

  Cubre: R-013-01 a R-013-05, R-013-07 a R-013-11. Verifica: tests en verde, también `test_save_load.gd`,
  `test_zone_memory.gd`, `test_main_scene.gd`, `test_base_loop.gd`, `test_zone_loader.gd` y
  `test_no_global_rng.gd` sin cambios.

## Pantalla de contenedor

- [x] **T-013-04** Test primero: `test_r_013_12_count_used_slots` en `test_inventory_rules.gd` y
  `test_r_013_19_highlight_matches_balance` en `test_movement_resources.gd`. Después,
  `InventoryRules.count_used_slots` (D14), `ControlConfigData.move_highlight_s` y `controls.tres` (D15). Cubre:
  R-013-12 (recuento), R-013-19 (dato). Verifica: tests en verde.
- [x] **T-013-05** Test primero: `test_inventory_slot.gd` y `test_inventory_grid.gd` (nuevos) y el caso 013 de
  `test_quantity_selector.gd`. Después, `InventorySlotView` (`%Highlight`, `%TargetOutline`, D13, D18),
  `InventoryGrid.flash_slots` / `set_targets_marked` y `QuantitySelector.set_editable` (D17). Cubre: R-013-13
  (selector), R-013-16 (marca), R-013-19 (resaltado). Verifica: tests en verde y `test_inventory_screen.gd` sin
  cambios.
- [x] **T-013-06** Test primero: casos `test_r_013_12` a `test_r_013_22` de `test_container_screen.gd`, que
  sustituyen a los `test_r_012_27` a `test_r_012_30`, y el resto de cambios de plan §5.3 en ese archivo (helper
  `_open` con `CONTEXT_KIND`, claves, `%MoveButton`, foco de `%PlaceButton`, selector visible y desactivado en
  `test_r_012_35_selection_cleared_when_gone`) y en `test_structure_use_flow.gd`. Después,
  `container_screen.tscn` (cabeceras, `%ActionCard` de tamaño fijo con `%Notice` dentro, D16, foco de D22) y
  `container_screen.gd` (`Kind` con su validación, `Mode`, `_refresh_card`, toques y pérdida de la pila de D10,
  D11, `handle_back` de D12, resaltado de D13), las claves de §4.2 en `strings.csv` (D19) y los llamadores `Main`
  y `StructureUseFlow` (D8). Cubre: R-013-12 a R-013-22. Verifica: tests en verde, también
  `test_save_triggers.gd`, `test_ui_manager.gd` y los `test_r_005_*` / `test_r_012_31` a `test_r_012_46` de la
  pantalla.

## Cierre

- [x] **T-013-07** Marcar en las specs 004, 008 y 012 los requisitos sustituidos o ampliados (D20). Cubre: — .
  Verifica: diff de documentación.
- [ ] **T-013-08** Pasos manuales M1, M2, M4 y M5 en PC; M2 y M3 en Android (APK debug), incluidas las flechas y
  signos de §4.2 en la fuente por defecto. Anotar el resultado aquí. Cubre: R-013-03, R-013-09, R-013-17,
  R-013-22 (manual). Verifica: los cinco pasos con el resultado esperado de plan §5.4.
- [x] Definición de hecho (constitución §4): `godot-runner`, `i18n-auditor` y `balance-auditor` en paralelo, después
  `architecture-guardian`.
- [x] `system-documenter spec 013` (`docs/systems/`: zona verde y cajas, inventario y contenedor).
- [ ] "Repository state" de `CLAUDE.md`: spec 013 hecha, cajas por sitios y por visita, nueva interacción de la
  pantalla de contenedor, siguiente spec 014.
- [ ] Estado del spec actualizado en `spec.md` y en `specs/README.md §6`.
