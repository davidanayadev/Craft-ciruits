# Tareas 006 — Zombies: `HealthComponent`, IA y spawner con pool

> Orden de ejecución. Cada tarea deja el proyecto compilando y los tests en verde. Marcar `[x]` al terminar.
> **(usuario)** = la hace el usuario en su máquina.

- [ ] **T-006-00** Preparar la rama:
  - [x] `feat/006-zombies`, apilada sobre `feat/005-inventory` (todavía sin fusionar), con la spec, el plan, las
    tareas, `BALANCE.md` y `specs/README.md` en un commit `docs(zombies): …`.
  - [ ] **(usuario)** Fusionar `feat/005-inventory` en `main` antes del PR de la 006, con commit de fusión (no
    squash), para que el PR de la 006 solo enseñe sus commits.

  Verifica: `git log --oneline feat/005-inventory..feat/006-zombies` muestra solo los commits de la 006.
- [ ] **T-006-01** Comprobar en la documentación oficial de 4.7.2 y en el binario headless los 8 puntos
  **(verificar)** del plan §5. Anotar el resultado en el plan. Si alguno falla, parar y ajustar el plan antes de
  escribir tests. Verifica: nota en el plan.
- [ ] **T-006-02** Test primero: `test_health_component.gd`. Crear `health_component.gd`. Cubre: R-006-05 a 09.
  Verifica: `godot-runner`.
- [ ] **T-006-03** Test primero: `test_enemy_resources.gd`.
  - Crear `enemy_data.gd`, `enemy_ai_data.gd`, `zombie_slow.tres`, `zombie_fast.tres` y `zombie_ai.tres` con BALANCE
    §3.1.
  - Añadir `ENEMY_ZOMBIE_SLOW` y `ENEMY_ZOMBIE_FAST` (ES + EN) a `strings.csv` y reimportar.

  Cubre: R-006-01, R-006-02 y R-006-03 (datos). Verifica: `godot-runner`.
- [ ] **T-006-04** Test primero: los tests R-006-04 en `test_data_catalog.gd`. Añadir `enemies`, `has_enemy` y
  `get_enemy` a `DataCatalog`, `get_enemy` a `DataRegistry`, y los dos enemigos a `data_catalog.tres`. Cubre:
  R-006-04. Verifica: `godot-runner`.
- [ ] **T-006-05** Test primero: `test_enemy_brain.gd` (con `gut-test-writer`), con RNG de semilla fija y la tabla
  de transiciones del plan §1. Crear `enemy_brain.gd`. Cubre: R-006-11, 12, 14 y 15, y R-006-13 y 18 (lógica).
  Verifica: `godot-runner`.
- [ ] **T-006-06** Test primero: `test_object_pool.gd`. Crear `object_pool.gd`. Cubre: R-006-22 (pool). Verifica:
  `godot-runner`, sin avisos de nodos huérfanos.
- [ ] **T-006-07** Antes de tocar `ZonePopulation`, añadir los tests de respuesta conocida de las cajas
  (`test_zone_population.gd::test_r_004_21_known_answer` y `test_green_zone.gd::test_r_004_21_dev_seed_known_boxes`)
  con lo que da el código actual, y verlos en verde. Después, test primero: los tests R-006-23 y 25 en
  `test_zone_population.gd` y `test_r_006_24` en `test_no_global_rng.gd`.
  - Crear `enemy_spawn_entry_data.gd`.
  - Añadir los campos de enemigos a `ZoneData` y `green_zone.tres` (BALANCE §7.1), y los dos streams a
    `SeededRng`.
  - Extraer el helper privado de marcadores e implementar `pick_enemy_spawns`.

  Cubre: R-006-23 y 25 (lógica) y R-006-24. Verifica: `godot-runner`, con los tests de cajas de la 004 sin cambios
  y en verde.
- [ ] **T-006-08** Test primero: `tests/integration/test_robot_hit.gd`. Añadir `PLAYER_GROUP`, `receive_hit` y `hit_received` a
  `Robot`, y el grupo a `robot.tscn`. Cubre: R-006-16, 17 y 18 (robot). Verifica: `godot-runner`.
- [ ] **T-006-09** Montar `zombie.tscn` con un placeholder de primitivas y un `AnimationPlayer` con `idle`, `walk` y
  `attack`. Escribir `zombie.gd` con `activate`, el cerebro, el agente de navegación, el golpe y `defeated`.
  Escribir antes los tests de `test_zombie.gd` que no necesitan navmesh: 10, 15, 16, 18, 21 y 22. Cubre: R-006-10,
  15, 16, 18, 21 y 22. Verifica: `godot-runner`.
- [ ] **T-006-10** En `farm_zone_green.tscn`:
  - Añadir el `NavigationRegion3D` y hornear el navmesh en el editor con lo verificado en T-006-01.
  - Añadir `%EnemyMarkers` (10 marcadores a más de 13 m del `SpawnPoint`, visión + patrulla de BALANCE §3.1) y
    `%Enemies`.

  Escribir el test R-006-13 de `test_zombie.gd` y los tests R-006-12 (punto inalcanzable), R-006-20 y R-006-23
  (marcadores fuera de vista) de `test_zombie_spawner.gd`. Cubre: R-006-12, 13, 20 y 23 (marcadores). Verifica: `godot-runner`.
- [ ] **T-006-11** Test primero: el resto de `test_zombie_spawner.gd` (23, 25, 26 y 27) y los tests R-006-19 y 26 de
  `test_main_scene.gd`.
  - Crear `zombie_spawner.gd` y añadir `spawn_enemies`, `despawn_enemies` y `get_enemies` a `FarmZone`.
  - Añadir `World/ZombiePool` a `main.tscn`, y en `main.gd` el `prewarm` con `enemy_count_max` y la llamada a
    `spawn_enemies`.

  Cubre: R-006-19, 23, 25, 26 y 27. Verifica: `godot-runner`.
- [ ] **T-006-12** Buscar un modelo de zombie CC0 (Quaternius o Kenney) con idle, walk y attack, licencia clara y
  ≤ 2 000 triángulos. Si
  lo hay, importarlo, sustituir el placeholder sin tocar la lógica y anotar la licencia como en la 004. Si no, se
  queda el placeholder y se anota aquí. Cubre: R-006-10. Verifica: `godot-runner` y vista en el editor.
- [ ] **T-006-13** Prueba manual en PC del criterio de hecho de la spec §5:
  - patrulla;
  - persecución rodeando árboles;
  - huir corriendo del rápido y no andando;
  - un golpe cada 1.5 s con −5 y −4 de batería;
  - con la batería a 0 dejan de atacar;
  - siguen actuando con el inventario abierto;
  - no salen de la valla;
  - misma semilla, mismos zombies.

  Cubre: R-006-13, 15, 16, 19, 20 y 25 (manual). Verifica: nota con el resultado aquí.
- [ ] **T-006-14** **(usuario)** APK debug en el Android de gama media, con una semilla que dé 8 zombies puesta en
  `dev_world.tres` solo en local (sin commit): 60 s con todos persiguiendo al robot, FPS del `DebugHud` ≥ 30.
  Anotar la semilla, el dispositivo, el FPS mínimo y los triángulos en pantalla. Cubre: R-006-28.
  Verifica: nota aquí.

## Cierre

- [ ] Definición de hecho (constitución §4): `godot-runner`, `i18n-auditor` y `balance-auditor` en paralelo, y
  después `architecture-guardian`.
- [ ] Estado del spec actualizado en `spec.md` y en `specs/README.md §6`.
