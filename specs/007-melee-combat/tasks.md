# Tareas 007 — Combate cuerpo a cuerpo y XP por muerte

> Orden de ejecución. Cada tarea deja el proyecto compilando y los tests en verde. Marcar `[x]` al terminar.

- [x] **T-007-01** Comprobar los 10 puntos **(verificar)** de plan §5 en la referencia de clases de Godot 4.7.2
  (`--doctool`) y con scripts de prueba en headless (fuera del repo). Anotar el resultado en un §5.1 nuevo del plan
  y, si un punto falla, aplicar su plan B antes de seguir. Cubre: — (prerrequisito de R-007-12, 15, 16, 18, 24, 27).
  Verifica: §5.1 escrito.
- [x] **T-007-02** Test primero: `test_combat_resources.gd` y el caso nuevo de `test_enemy_resources.gd`. Después,
  `AttackStatsData`, `CombatConfigData`, `CombatFeedbackData`, `EnemyData.xp_reward` y sus `.tres` (plan §4).
  Cubre: R-007-01, R-007-03, R-007-04 (datos), R-007-05 (archivos), R-007-28 (golpes para matar). Verifica: los tests
  de datos en verde.
- [x] **T-007-03** Test primero: `test_combat_system.gd`. Después, `CombatSystem`. Cubre: R-007-05, R-007-07,
  R-007-08, R-007-09 (lógica). Verifica: tests sin árbol de escena en verde, con `delta` exactos en binario y el
  caso de 60 pasos de `1/60`.
- [x] **T-007-04** Test primero: `test_uid.gd`, `test_event_bus.gd` y los casos nuevos de `test_project_settings.gd`.
  Después, `Uid`, el autoload `EventBus` (el primero) y la capa 3 `hurtbox` en `project.godot`. Cubre: R-007-17
  (contrato), R-007-18 (formato), R-007-19 (bus sin estado). Verifica: tests en verde y el proyecto abre sin avisos
  nuevos.
- [x] **T-007-05** Test primero: `test_hurtbox_component.gd`. Después, `HurtboxComponent`. Cubre: R-007-11,
  R-007-12 (capa), R-007-17 (último atacante), R-007-23 (reset). Verifica: tests en verde.
- [x] **T-007-06** Test primero: `test_experience_component.gd` con catálogos hechos a mano. Después,
  `ExperienceComponent`. Cubre: R-007-19, R-007-20 (lógica), R-007-21. Verifica: tests en verde, incluidos los
  `assert_push_error`.
- [x] **T-007-07** Test primero: `test_melee_attack_component.gd` (ritmo con `tick` a mano, `apply_impact` con
  hurtboxes sin física, caja creada en código desde los datos, parámetros de la consulta `intersect_shape`).
  Después, `MeleeAttackComponent`. Cubre: R-007-04 (caja), R-007-06, R-007-07, R-007-10 (señal), R-007-11,
  R-007-12 (máscara, solo áreas). Verifica: tests en verde.
- [x] **T-007-08** Test primero: casos nuevos de `test_player_input.gd`. Después, ataque en `PlayerInput`
  (`_unhandled_input`, `set_attack_button_held`, `poll_attack`; sin filtro de ratón emulado, que plan §5.1 punto 1
  demostró innecesario). Cubre: R-007-07 (sin
  cola), R-007-09 (bloqueado), R-007-15 (input). Verifica: tests en verde; los de movimiento e interacción de
  `test_player_input.gd` siguen igual.
- [x] **T-007-09** Robot: `%MeleeAttack` (con `one_arm.tres`, `combat.tres` y su caja), `%Experience`,
  `%AnimationPlayer` con `attack`, `player_uid`, coste en `swing_started`, `poll_attack` en `_physics_process` (el
  movimiento sale a un método propio para no pasar de 20 líneas) y `EventBus.enemy_killed` → `reward_kill`.
  Escribir `integration/test_robot_combat.gd` antes de cablear. Cubre: R-007-02, R-007-06, R-007-09 a R-007-14,
  R-007-18, R-007-20. Verifica: `test_robot_combat.gd` y los tests de robot de las specs 002-006 en verde.
- [x] **T-007-10** Test primero: `test_hit_flash_component.gd`. Después, `HitFlashComponent` y
  `resources/materials/hit_flash.tres`. Zombie: `%Hurtbox` (comparte la `CapsuleShape3D` del cuerpo), `%HitFlash`
  con sus cuatro mallas, `hurt` → destello, `died` → `EventBus.enemy_killed`, y `activate` reinicia hurtbox y
  destello. Casos nuevos en `test_zombie.gd`. Cubre: R-007-17, R-007-23, R-007-24 (destello). Verifica: tests en
  verde, incluidos los de la 006.
- [x] **T-007-11** Test primero: `test_camera_rig.gd`. Después, `CameraRig.shake` con `h_offset`/`v_offset`.
  Cubre: R-007-24, R-007-25 (sacudida). Verifica: tests en verde y `test_no_global_rng.gd` sigue en verde.
- [x] **T-007-12** Test primero: casos nuevos de `test_hud.gd`. Después, `AttackButton` (con el toque propio si
  T-007-01 punto 2 lo pide), `DamageFlash`, `%AttackButton` y `%DamageFlash` en `hud.tscn`, "Interactuar" encima del
  de atacar, `attack_held_changed`, `flash_damage` y `HUD_ATTACK` en `strings.csv` (ES + EN). Cubre: R-007-16,
  R-007-25 (borde). Verifica: tests de HUD en verde, incluidos los de las specs 003-005 (sin `_process` en `Hud`).
- [x] **T-007-13** `ImpactSparks` (emisor según T-007-01 punto 5) y `CombatFeedback`. Escribir
  `integration/test_combat_feedback.gd` antes. Cubre: R-007-24 a R-007-27. Verifica: tests en verde.
- [x] **T-007-14** Test primero: `test_debug_hud.gd`. Después, `DebugHud.bind` y `%XpLabel`. Cubre: R-007-22.
  Verifica: tests en verde.
- [x] **T-007-15** Main: `World/ImpactPool` precalentado con `enemy_count_max`, `%CombatFeedback`, `%DebugHud`,
  `attack_held_changed` → `PlayerInput`, y el enlace de feedback y depuración (agrupado para que `_ready` no pase de
  20 líneas). `integration/test_hud_attack_input.gd` y el caso nuevo de `test_main_scene.gd`. Pasos manuales en PC
  de R-007-15, R-007-22 y R-007-28. Cubre: R-007-15, R-007-22, R-007-28. Verifica: `godot-runner` con toda la suite
  en verde y los pasos manuales anotados aquí.

  Resultado (2026-11-16): `godot-runner` con la suite en verde (578 tests). Probado en PC por el usuario, todo
  correcto. Observación del usuario, fuera de esta spec: el zombie deja de perseguir al alejarse (R-006-14,
  abandono a 12 m de BALANCE §3.1) y quiere que persiga siempre; se tratará como enmienda a la spec 006.
- [x] **T-007-16** APK debug en el Android de gama media: golpear con el pulgar derecho mientras el izquierdo mueve
  (R-007-16); tocar el escenario y el joystick no golpea (R-007-15); 60 s peleando con el máximo de zombies con FPS
  ≥ 30 (R-007-29); chispas con `GPUParticles3D` y regla de plan §1 "Partículas" (se quedan si funcionan en
  Compatibility, sin tirón en el primer impacto y con FPS ≥ 30; si no, `CPUParticles3D`) (R-007-27).
  Cubre: R-007-15, R-007-16, R-007-27, R-007-29. Verifica: dispositivo, FPS mínimo, triángulos y elección de
  partículas anotados aquí.

  Resultado (2026-11-16): probado en el móvil por el usuario, todo correcto. Las chispas se quedan con
  `GPUParticles3D`. No se anotaron el dispositivo, el FPS mínimo ni los triángulos en pantalla.

## Cierre

- [x] Definición de hecho (constitución §4) revisada: `godot-runner`, `i18n-auditor` y `balance-auditor` en
  paralelo, después `architecture-guardian` una vez.
- [x] `CLAUDE.md` "Repository state" actualizado (spec 007 hecha, el robot ya ataca).
- [x] Estado del spec actualizado en `spec.md` y en `specs/README.md §6`.
