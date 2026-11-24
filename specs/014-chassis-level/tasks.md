# Tareas 014 — Nivel de chasis

> Orden de ejecución. Cada tarea deja el proyecto compilando y los tests en verde. Marcar `[x]` al terminar.
> Requisito previo: la spec 013 *Hecho* y fusionada; rama `feat/014-chassis-level` desde `main`.

## Datos y cálculo

- [x] **T-014-01** Comprobar en GUT headless el tamaño de la ventana raíz (plan §5.1, punto 2) y anotar el
  resultado en el plan. El orden de `get_nodes_in_group()` ya se comprobó al planificar (§5.1, punto 1).
  Cubre: — (prerrequisito de R-014-14). Verifica: plan §5.1 sin **(verificar)**.
- [x] **T-014-02** Test primero: en `test_chassis_level_data.gd`, `EXPECTED_XP` / `EXPECTED_SLOTS` de BALANCE §6.1,
  `test_r_014_02_*` y el cambio de `test_r_005_02_validate_rejects_bad_tables` (plan §5.3). Después,
  `ChassisLevelData.validate()` y `get_xp_required()` (D8) y los 10 niveles en `chassis_levels.tres`.
  Cubre: R-014-01, R-014-02. Verifica: `godot-runner` en verde (el robot sigue con 5 ranuras: nivel 1).
- [x] **T-014-03** Test primero: `EXPECTED_ITEMS` con 20 / 10 / 10 y `test_r_014_22_every_cost_fits_one_stack` en
  `test_data_catalog.gd`. Después, `stack_max` en `scrap.tres`, `cables.tres` e `iron.tres`. Correr la suite entera
  y corregir los tests que supusieran 99 / 50 para que lean el catálogo (plan §5.3, pregunta 11).
  Cubre: R-014-21, R-014-22. Verifica: `godot-runner` en verde.
- [x] **T-014-04** Test primero (`gut-test-writer`): `test_chassis_level_system.gd` con los casos de plan §5.2.
  Después, `ChassisLevelSystem.level_for_xp` y `xp_to_next_level` (D2).
  Cubre: R-014-01, R-014-03, R-014-04, R-014-05, R-014-20 (cálculo). Verifica: tests en verde.

## Subida de nivel

- [x] **T-014-05** Test primero (`gut-test-writer`): en `test_experience_component.gd`, los `test_r_014_06/07/09/10/11/15/17_*`
  y los cambios de plan §5.3 (`before_each` y `other` con la tabla, `push_error` de `reset()`, carga con el mismo
  total). Después, en `ExperienceComponent`: `set_level_table`, `get_level`, `level_changed`, `level_up`, el orden de
  D4, la XP que baja (D6), la carga (D7), sin tabla (D9) y el docstring de la clase. En la misma tarea,
  `Robot._ready()` llama a `experience.set_level_table(chassis_levels)`: sin ella, todo test que gana o carga XP en
  un robot recibiría el `push_error` de D9 y la suite no quedaría en verde. Afirmar el `push_error` de D6 en el caso
  sin `keeps_xp` de `test_death_controller.gd` (plan §5.3).
  Cubre: R-014-06, R-014-07, R-014-09, R-014-10, R-014-11, R-014-15, R-014-17. Verifica: `godot-runner` en verde.
- [x] **T-014-06** Test primero: en `test_robot_inventory.gd`, `test_r_014_08_*`, `test_r_014_09_*` y
  `test_r_014_11_*`. Después, en `Robot`: `_on_level_changed` y el tamaño inicial desde `experience.get_level()`
  (D3); mover `Experience` antes de `InventoryComponent` en `robot.tscn` (D5); docstrings de `Robot` (quitar "Only
  level 1 until ACTION_PLAN 2.7"; explicar el orden) y de `SaveManager._apply_world` (orden del árbol, D13).
  Cubre: R-014-08, R-014-09, R-014-11. Verifica: tests en verde.
- [x] **T-014-07** Test primero: `test_r_014_12_death_keeps_level_and_slots` en `test_death_controller.gd`. Sin cambio de producción esperado: si falla, se para y se
  revisa el diseño. Cubre: R-014-12. Verifica: tests en verde.

## Guardado

- [x] **T-014-08** Test primero: en `test_save_load.gd`, `test_r_014_15_level_recomputed_on_load`,
  `test_r_014_16_saved_stacks_beyond_level_one_load`, `test_r_014_16_experience_loads_before_inventory`,
  `test_r_014_17_load_never_emits_level_up` y
  `test_r_014_18_new_world_level_one`, con `SaveTestSupport`. Sin cambio de producción esperado (lo cubren T-014-05
  y T-014-06). Cubre: R-014-15, R-014-16, R-014-17, R-014-18. Verifica: tests en verde; diff sin cambios en
  `SaveMigrations` ni `SaveDocuments`.

## Pantallas

- [x] **T-014-09** Test primero: `test_r_014_13_*` y `test_r_014_14_*` en `test_inventory_screen.gd` y
  `test_container_screen.gd`, con las ranuras del último nivel leídas de `chassis_levels.tres` y el resultado de
  T-014-01. Sin cambio de código esperado (D11); si R-014-14 falla, ajustar la escena.
  Cubre: R-014-13, R-014-14. Verifica: tests en verde.

## Depuración

- [x] **T-014-10** Test primero: `test_r_014_19_*` y `test_r_014_20_*` en `test_debug_hud.gd`. Después,
  `%LevelLabel`, `%LevelUpButton` y `level_up_player()` en el debug HUD, y su docstring (D10).
  Cubre: R-014-19, R-014-20. Verifica: tests en verde.

## Documentación y verificación manual

- [x] **T-014-11** architecture.md §7 (`level_changed` entre las señales de estado; las señales viven en
  `robot.experience`) y §10.2 (`stats_changed` → `level_changed` en el ejemplo de la carga del nivel; orden del árbol
  al aplicar las partes) (D13). Cubre: — (spec pregunta 7). Verifica: diff.
- [x] **T-014-12** Pasos manuales M1-M4 (plan §5.2) en PC y en Android (APK debug, export con `godot-runner`).
  Cubre: R-014-14, R-014-20 y el criterio de hecho de la spec. Verifica: resultado anotado en el plan. Hecho
  (2026-11-24): el usuario hizo M1-M4 en PC y Android y todos dieron el resultado esperado.

## Cierre

- [x] Definición de hecho (constitución §4): `godot-runner`, `i18n-auditor` y `balance-auditor` en paralelo, después
  `architecture-guardian`.
- [x] `system-documenter spec 014` (`docs/systems/`).
- [x] CLAUDE.md "Repository state" (spec 014 hecha, la siguiente es la 015).
- [x] Estado del spec actualizado en `spec.md` y en `specs/README.md §6`.
