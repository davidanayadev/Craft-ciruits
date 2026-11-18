# Tareas 011 — Crafteo de piezas y reparación en el banco

> Orden de ejecución. Cada tarea deja el proyecto compilando y los tests en verde. Marcar `[x]` al terminar.
> Requisito previo: la spec 010 *Hecho* y fusionada; rama `feat/011-crafting-repair` desde `main`.

- [x] **T-011-01** Comprobar en la referencia de clases de Godot 4.7.2 (`--doctool`) las API de UI del plan.
  Hecho al planificar (2026-11-17): plan §5.1, sin puntos **(verificar)** pendientes. Cubre: — (prerrequisito de
  R-011-21). Verifica: plan §5.1 escrito.
- [ ] **T-011-02** Test primero: `test_piece_resources.gd` (nuevo) y casos 011 de `test_recipe_resources.gd` y
  `test_data_catalog.gd`. Después, `PieceData`, `RecipeData.result_item`, `RepairTierData`, `RepairCostData`,
  `DataCatalog.repair_costs`, los tres iconos SVG (con `CREDITS.md`), los `.tres` de piezas, recetas y
  `repair_costs.tres`, el catálogo y las claves `ITEM_BASIC_*` en `strings.csv`. Cubre: R-011-01, R-011-02,
  R-011-03 (datos), R-011-04, R-011-05, R-011-06. Verifica: tests en verde; `test_r_009_61_*` sigue en verde.
- [ ] **T-011-03** Test primero: casos 011 de `test_inventory_rules.gd`. Después, `InventoryRules.add_stack`,
  `add` sobre `add_stack`, `split` que conserva, `is_valid_stack` e `index_of_uid` (D1-D3). Cubre: R-011-08,
  R-011-09 (reglas), R-011-11 (regla). Verifica: tests en verde y los de la spec 005 sin cambios.
- [ ] **T-011-04** Test primero: casos 011 de `test_crafting_system.gd`. Después, `check_craft`, `create_result`,
  `is_damaged`, `repair_cost`, `check_repair` y las claves `ERR_NO_ROOM_FOR_RESULT`, `ERR_PIECE_*` (D4-D6), con la
  suma de ingredientes compartida con `cost_of`. Cubre: R-011-07, R-011-12, R-011-16, R-011-17, R-011-18,
  R-011-20 (comprobación). Verifica: tests en verde.
- [ ] **T-011-05** Test primero (`gut-test-writer`, varios requisitos): casos 011 de
  `test_inventory_component.gd`. Después, en `InventoryComponent`: todos los caminos con `add_stack` y sobrantes
  que conservan; rechazo de piezas inválidas en `add`/`add_stacks` (D1); `from_save_data` con `is_valid_stack`;
  `craft` y `repair` con una sola `inventory_changed`. Cubre: R-011-03 (componente), R-011-07, R-011-08, R-011-09,
  R-011-11, R-011-13, R-011-14, R-011-15, R-011-19, R-011-20. Verifica: tests en verde, y los de cajas, loot,
  objeto caído y guardado sin cambios.
- [ ] **T-011-06** Test primero: casos 011 de `test_dropped_item.gd`, `test_dropped_item_spawner.gd` y
  `test_death_controller.gd`. Después, `DroppedItem.to_data()` con `durability` y `uid` y
  `DroppedItemSpawner._restore_stacks` que los lee y valida (D12). Cubre: R-011-09 (tirar, morir, recoger),
  R-011-10, R-011-11 (objeto caído). Verifica: tests en verde; `test_save_fixtures.gd` sin cambios (D12).
- [ ] **T-011-07** Test primero: casos 011 de `test_event_bus.gd` y `test_repair_bench.gd`. Después,
  `EventBus.item_crafted` y `piece_repaired`, `RepairBench.craft` / `repair`, `BaseZone.get_bench()`, las razones
  de `SaveManager` y sus conexiones (D7, D8). Actualizar architecture §7 (fila `piece_repaired`, emisor y oyentes de
  `item_crafted`), §8 (`repair_costs`) y §9.3 (`PieceData` desde la 011) y §10.2 (campos opcionales, D12). Cubre: R-011-13 (banco), R-011-14
  (banco), R-011-19 (banco), R-011-28 (evento). Verifica: tests en verde.
- [ ] **T-011-08** Test primero: `test_bench_screen.gd` (nuevo; mueve los cuatro tests de `test_build_screen.gd`
  con sus nombres, D9) y el caso de `test_build_flow.gd`. Después, `BenchEntry`, `BenchBuildSection` (lógica de
  `BuildScreen`), `BenchCraftSection`, `BenchRepairSection`, `bench_screen.tscn/.gd` (pestañas con `tr()`, D10;
  refresco, D11), `screens.tres`, `BuildFlow`; borrar `build_screen.gd/.tscn` y `test_build_screen.gd`; actualizar
  `test_base_loop.gd`, `test_main_scene.gd` y `test_ui_manager.gd` a `BenchScreen` y el comentario de `test_base_structures.gd`; claves de plan §4.1. Cubre:
  R-009-38, R-009-39, R-009-64, R-009-65, R-011-15 (UI), R-011-21 a R-011-27. Verifica: tests en verde;
  `grep BuildScreen` vacío fuera de `specs/` y `docs/`.
- [ ] **T-011-09** Test primero: `test_save_triggers.gd::test_r_011_28_craft_and_repair_save` y
  `test_save_load.gd::test_r_011_10_piece_survives_close_and_reopen`. Después, lo que falte para que pasen (se
  espera nada: T-011-05 a T-011-07 ya lo dejan hecho). Cubre: R-011-10 (inventario y objeto caído por
  `SaveManager`), R-011-28. Verifica: `godot-runner` con la suite completa en verde.
- [ ] **T-011-10** Pasos manuales M1 y M2 (PC) y M3 (Android, APK debug) de plan §5.3; anotar el resultado en
  plan §5.4. Cubre: R-011-21 a R-011-27 en el juego, R-011-09 jugando. Verifica: plan §5.4 escrito.

## Cierre

- [ ] Definición de hecho (constitución §4): `godot-runner`, `i18n-auditor` y `balance-auditor` en paralelo, y
  después `architecture-guardian`.
- [ ] README §6: anotar para la 014 que una pieza a 0 se quita del inventario (no se queda a 0, plan §7) y para la
  015 que las piezas del loot se crean con `uid` y durabilidad (plan §7).
- [ ] `system-documenter spec 011` (inventario, crafteo y banco, objeto caído, guardado).
- [ ] CLAUDE.md "Repository state": spec 011 hecha, `BenchScreen` en lugar de `BuildScreen`, siguiente spec 012.
- [ ] Estado del spec actualizado en `spec.md` y en `specs/README.md §6`.
