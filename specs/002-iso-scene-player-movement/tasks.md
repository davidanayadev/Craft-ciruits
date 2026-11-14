# Tareas 002 — Escena isométrica y movimiento del robot

> Orden de ejecución. Cada tarea deja el proyecto compilando y los tests en verde. Marcar `[x]` al terminar.
> **(usuario)** = la hace el usuario en su máquina.

- [x] **T-002-00 (usuario)** Fusionar el PR del spec 001 en `main` (CI en verde) y crear la rama
  `feat/002-iso-scene-player-movement` desde `main`. Verifica: `git log main` contiene el bootstrap.
- [x] **T-002-01** Verificar en la documentación de Godot 4.7 / GUT los seis puntos **(verificar)** del plan §5
  y anotar las diferencias en el plan. Cubre: base de R-002-09/10/12. Verifica: plan actualizado.
- [x] **T-002-02** Escribir en BALANCE.md §11 los valores aprobados (giro `10.0 rad/s`, tamaño ortográfico
  `14.0 m`, distancia `20.0 m`; "distancia" pasa a ser tamaño + distancia física). Crear las clases de datos
  (`movement_stats_data.gd`, `control_config_data.gd`, `camera_config_data.gd`), los `.tres` y el test de
  valores (rojo → verde). Cubre: R-002-14. Verifica: `tools/run_tests.sh`.
- [x] **T-002-03** Test primero: `test_joystick_logic.gd` (zona muerta, histéresis 80/70, recorte al radio,
  dirección normalizada); implementar `joystick_logic.gd` hasta verde. Cubre: R-002-15, R-002-16, parte de
  R-002-10/11. Verifica: `tools/run_tests.sh`.
- [x] **T-002-04** Test primero: `test_locomotion_system.gd` (dirección relativa a cámara, velocidades 3.0/4.8,
  velocidad fija por tramo, sin piernas no corre, parada inmediata, giro suave); implementar
  `locomotion_system.gd` hasta verde. Cubre: R-002-05..08, R-002-17, R-002-18. Verifica: `tools/run_tests.sh`.
- [x] **T-002-05** Crear `player_input.gd` (teclado vía InputMap + muestra del joystick), `robot.tscn` +
  `robot.gd` (CharacterBody3D, cápsula, malla placeholder con "frente" visible) y
  `test_robot_movement.gd` (parada, colisión con física simulada). Cubre: R-002-04, R-002-09, R-002-13.
  Verifica: `tools/run_tests.sh`.
- [x] **T-002-06** Crear `dev_zone.tscn` (suelo 50x50, luz con sombras, cielo, obstáculo), `camera_rig.tscn` +
  `camera_rig.gd`, rellenar `main.tscn` con el esqueleto de architecture.md §6 + `main.gd`, y
  `test_main_scene.gd`. Cubre: R-002-01..03. Verifica: `tools/run_tests.sh` y el juego arranca en PC con WASD.
- [x] **T-002-07** Crear `touch_controls.tscn`/`.gd` y `floating_joystick.gd` (renombrado: 4.7 tiene un
  `VirtualJoystick` nativo, plan §7) (flotante en mitad izquierda,
  sigue solo su dedo, visibilidad táctil/flag debug), cablear en `main.gd` hacia `PlayerInput`, y test del
  manejador con eventos sintetizados. Cubre: R-002-10, R-002-11, R-002-12. Verifica: `tools/run_tests.sh` +
  joystick con ratón (flag debug + `emulate_touch_from_mouse`).
- [x] **T-002-08 (usuario + Claude)** Exportar APK debug, probar en el Android real: joystick flotante, umbral
  de correr, velocidades, giro, colisión, cámara y ≥ 30 FPS. Ajustar `ortho_size` / `turn_speed_rad` si hace
  falta y volcar los valores finales a BALANCE §11 y a los `.tres`. Cubre: criterio de hecho, R-002-10..12.
  Verifica: checklist manual del plan §5.
- [x] **T-002-10** (añadida el 2026-11-14) Cambiar a orientación apaisada — decisión de producto tras la
  primera prueba en el móvil: spec/plan 001 enmendados, `project.godot` (1920x1080, `SENSOR_LANDSCAPE`),
  test guardián renombrado, `ortho_size` a 10.0 en BALANCE §11 — y añadir `DebugHud` (FPS en builds debug)
  para poder medir el criterio de ≥ 30 FPS. Verifica: `tools/run_tests.sh` y re-prueba en el móvil.
- [x] **T-002-09** Revisión final del PR: R-002-13 (ningún acceso táctil fuera de `virtual_joystick.gd`), sin
  literales de gameplay, diff limpio. Cubre: R-002-13, R-002-14. Verifica: revisión del diff.

## Cierre

- [x] Definición de hecho (constitución §4) revisada.
- [x] Estado del spec actualizado en `spec.md` y en `specs/README.md §6`.
