# Tareas 003 — Batería: consumo, señales y HUD

> Orden de ejecución. Cada tarea deja el proyecto compilando y los tests en verde. Marcar `[x]` al terminar.
> **(usuario)** = la hace el usuario en su máquina.

- [x] **T-003-00 (usuario)** Fusionar el PR del spec 002 en `main` (CI en verde) y crear la rama
  `feat/003-battery` desde `main`, llevando `specs/003-battery/plan.md` y `tasks.md`. Verifica: `git log main`
  contiene el commit del spec 002.
- [x] **T-003-01** Test primero: `test_battery_resources.gd` (rojo). Crear `battery_config_data.gd`,
  `resources/battery/robot_battery.tres` y añadir `walk_drain` a `movement_stats_data.gd` y `basic_legs.tres`
  (verde). Cubre: R-003-13. Verifica: `tools/run_tests.sh`.
- [x] **T-003-02** Test primero: tests de `gait()` en `test_locomotion_system.gd` (quieto, andar, correr, correr sin
  piernas que puedan). Añadir `enum Gait` y `gait()` a `locomotion_system.gd` y hacer que `horizontal_velocity` la
  use; los tests del spec 002 siguen en verde sin tocarlos. Cubre: R-003-03, R-003-04 (marcha). Verifica:
  `tools/run_tests.sh`.
- [x] **T-003-03** Test primero: `test_battery_component.gd` con arranque lleno, ritmos quieto/andar/correr,
  independencia del frame rate, `battery_changed` con valores y sin cambio, y dos instancias. Implementar
  `battery_component.gd` (`_ready`, getters, `drain_per_second`, `tick`, `_set_current`) hasta verde. Cubre:
  R-003-01..06, R-003-14. Verifica: `tools/run_tests.sh`.
- [x] **T-003-04** Test primero en el mismo archivo: umbral bajo (una vez, rearme), agotada (recorte, una emisión,
  sin consumo después, orden de señales), `consume` / `add` con tope / `recharge_full`, y negativos rechazados con
  `assert_push_error`. Completar el componente hasta verde. Cubre: R-003-07..10. Verifica: `tools/run_tests.sh`.
- [x] **T-003-05** Añadir `BatteryComponent` a `robot.tscn` (`%BatteryComponent`, `config` y `legs`) y en
  `robot.gd` calcular la marcha una vez por fotograma para moverse y para `battery.tick()`. Escribir
  `test_robot_battery.gd` (quieto, andando y corriendo con física real e InputMap). Cubre: R-003-02..04. Verifica:
  `tools/run_tests.sh`.
- [x] **T-003-06** Test primero: `test_hud.gd` (redondeo hacia arriba, sigue a `battery_changed`, sin sondeo). Crear
  `hud.tscn` + `hud.gd` (barra y número arriba a la izquierda), añadirlo a `main.tscn` y enlazarlo en `main.gd`;
  añadir `test_r_003_11_hud_bound_to_robot` a `test_main_scene.gd`. Cubre: R-003-11. Verifica:
  `tools/run_tests.sh` y el juego arranca en PC con la barra bajando.
- [x] **T-003-07** Añadir `GAME_OVER_TITLE` y `GAME_OVER_RESTART` (ES + EN) a `strings.csv` y reimportar. Test
  primero: `test_game_over_screen.gd`. Crear `game_over_screen.tscn` + `.gd`, añadirla a `main.tscn`, poner nombre
  único a `World` y en `main.gd` conectar `battery_depleted` (desactivar `World`, abrir la pantalla) y
  `restart_requested` (recargar la escena). Añadir `test_r_003_12_depletion_opens_game_over_and_freezes_world` a
  `test_main_scene.gd`. Cubre: R-003-12. Verifica: `tools/run_tests.sh`.
- [x] **T-003-08 (usuario + Claude)** Probar en PC y exportar un APK debug al Android real: HUD legible arriba a la
  izquierda, la barra baja más rápido al andar y más aún al correr, game over al llegar a 0 (con `maximum` bajado
  en local y luego deshecho, plan §5), reiniciar recarga la partida, ≥ 30 FPS con el `DebugHud`. Cubre: criterio de
  hecho, R-003-11, R-003-12. Verifica: checklist manual del plan §5.
- [x] **T-003-09** Revisión final del diff: sin literales de gameplay en `battery_component.gd` ni en `robot.gd`,
  el HUD sin `_process`, `robot_battery.tres` con los valores de BALANCE, un cambio lógico por commit. Actualizar
  "Repository state" en `CLAUDE.md`. Cubre: R-003-11, R-003-13. Verifica: revisión del diff.

## Cierre

- [x] Definición de hecho (constitución §4) revisada.
- [x] Estado del spec actualizado en `spec.md` y en `specs/README.md §6`.
