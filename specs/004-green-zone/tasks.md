# Tareas 004 — Zona verde, `zone_id`, RNG con semilla y cajas de loot

> Orden de ejecución. Cada tarea deja el proyecto compilando y los tests en verde. Marcar `[x]` al terminar.
> **(usuario)** = la hace el usuario en su máquina.

- [x] **T-004-00 (usuario)** Fusionar el PR del spec 003 en `main` (CI en verde) y crear la rama
  `feat/004-green-zone` desde `main`. La rama lleva la spec, el plan, las tareas, `specs/README.md` y los cambios de
  BALANCE.md y PMV.md del spec 004, en un commit `docs(green-zone): …`. Verifica: `git log main` contiene el commit
  de cierre del spec 003.
- [x] **T-004-01** Test primero: `test_seeded_rng.gd` (rojo). Crear `scripts/util/seeded_rng.gd` hasta verde y fijar
  el valor conocido en `test_r_004_09_known_answer`. Cubre: R-004-09. Verifica: `tools/run_tests.sh`.
- [x] **T-004-02** Test primero: `test_no_global_rng.gd`, que recorre `res://scripts` y `res://scenes` con el patrón
  del plan §5.5. Hoy debe pasar en verde; comprobar que falla al añadir `randf()` en un script temporal y quitarlo.
  Cubre: R-004-10. Verifica: `tools/run_tests.sh`.
- [x] **T-004-03** Test primero: `test_data_catalog.gd` (items, catálogo, registro) y `test_project_settings.gd`
  (autoloads). Crear `item_data.gd`, `data_catalog.gd`, los tres `.tres` de items y `data_catalog.tres`; añadir
  `ITEM_SCRAP`, `ITEM_CABLES` e `ITEM_IRON` (ES + EN) a `strings.csv` y reimportar. Crear los autoloads
  `GameManager` (con `dev_world_config_data.gd` y `dev_world.tres`) y `DataRegistry`, y registrarlos en
  `project.godot`. Añadir `test_game_manager.gd`. Cubre: R-004-08, R-004-18..20. Verifica: `tools/run_tests.sh`.
- [x] **T-004-04** Test primero: `test_loot_system.gd` y la parte de tablas de `test_data_catalog.gd`. Crear
  `item_stack.gd`, `loot_entry_data.gd`, `loot_table_data.gd`, `loot_system.gd` y `resources/loot/basic_box.tres`.
  Cubre: R-004-22, R-004-23 (tirada), R-004-26. Verifica: `tools/run_tests.sh`.
- [ ] **T-004-05** Test primero: `test_zone_population.gd` y `test_zone_resources.gd`. Crear `zone_population.gd`,
  `zone_data.gd`, `world_grid_config_data.gd`, `green_zone.tres` y `world_grid.tres`. Cubre: R-004-02, R-004-03
  (datos), R-004-21 (regla y datos). Verifica: `tools/run_tests.sh`.
- [ ] **T-004-06** Test primero: `test_interactable_component.gd` y `test_interactor_component.gd`, y el test de
  `interaction_range_m` en `test_movement_resources.gd`. Añadir `interaction_range_m` a `control_config_data.gd` y
  `controls.tres`, nombrar la capa 3D 2 `interaction` en `project.godot` (con su test en
  `test_project_settings.gd`) y crear los dos componentes. Cubre: R-004-12, R-004-15, R-004-17. Verifica:
  `tools/run_tests.sh`.
- [ ] **T-004-07** Añadir `PROMPT_OPEN` (ES + EN) a `strings.csv` y reimportar. Test primero: `test_loot_box.gd`.
  Crear `loot_box.tscn` + `loot_box.gd`: colisión, mallas cerrada y abierta de primitivas, `%Interactable` con
  `PROMPT_OPEN`. Cubre: R-004-23..25. Verifica: `tools/run_tests.sh`.
- [ ] **T-004-08** Test primero: `test_green_zone.gd` (rojo). Crear `farm_zone.gd` y `farm_zone_green.tscn`:
  - sol y entorno movidos desde `DevZone`;
  - `MeshLibrary` provisional y GridMap rellenado con un script temporal en headless, fuera del repo;
  - decoración de primitivas con colisión;
  - vallas en el borde y paredes invisibles fuera;
  - `%SpawnPoint` y 10 marcadores en `%BoxMarkers`.

  Cubre: R-004-01, R-004-03, R-004-04, R-004-11, R-004-21. Verifica: `tools/run_tests.sh`.
- [ ] **T-004-09** Añadir `%Interactor` a `robot.tscn`, `is_interact_just_pressed()` a `player_input.gd` y
  `request_interact()` a `robot.gd` (sin efecto con la batería agotada). Cubre: R-004-14 (vía teclado), R-004-16.
  Verifica: `tools/run_tests.sh`.
- [ ] **T-004-10** Test primero: tests de R-004-13 en `test_hud.gd`. Añadir `%InteractButton` (abajo a la derecha,
  `focus_mode` sin foco, oculto) y `interact_pressed` a `hud.tscn` + `hud.gd`, con `bind()` conectado a
  `target_changed`. Cubre: R-004-13. Verifica: `tools/run_tests.sh`.
- [ ] **T-004-11** Test primero: R-004-05 en `test_main_scene.gd` y `test_robot_interaction.gd`. En `main.tscn`,
  sustituir `DevZone` por la zona verde (`%GreenZone`). En `main.gd`, generar con `GameManager.get_world_seed()`,
  colocar al robot en el punto de aparición y conectar `interact_pressed` a `request_interact()`. Borrar
  `scenes/dev/dev_zone.tscn`. R-002-03 sigue en verde. Cubre: R-004-05, R-004-14, R-004-16. Verifica:
  `tools/run_tests.sh` y el juego arranca en PC dentro de la zona verde.
- [ ] **T-004-12 (usuario + Claude)** Probar en PC y exportar un APK debug al Android real:
  - el robot aparece en la zona verde y no sale de ella;
  - hay entre 5 y 7 cajas, siempre en el mismo sitio al reiniciar;
  - el botón "Abrir" aparece cerca de una caja, se lee bien y no choca con el joystick;
  - la caja se abre con el botón y con E, y no vuelve a ofrecerse;
  - ≥ 30 FPS con el `DebugHud` y < 50K triángulos (monitor del editor en PC).

  Cubre: criterio de hecho, R-004-06, R-004-13. Verifica: checklist manual.
- [ ] **T-004-13** Revisión final del diff:
  - sin literales de gameplay en scripts;
  - sin RNG global;
  - solo primitivas, ningún asset de terceros;
  - `.tres` con los valores de BALANCE;
  - un cambio lógico por commit.

  Actualizar "Repository state" en `CLAUDE.md`. Cubre: R-004-07, R-004-10. Verifica: revisión del diff.

## Cierre

- [ ] Definición de hecho (constitución §4) revisada.
- [ ] Estado del spec actualizado en `spec.md` y en `specs/README.md §6`.
