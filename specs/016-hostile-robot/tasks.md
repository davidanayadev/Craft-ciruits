# Tareas 016 — Robot hostil y sus drops

> Orden de ejecución. Cada tarea deja el proyecto compilando y los tests en verde. Marcar `[x]` al terminar.
> T-016-01 a T-016-02 no cambian el comportamiento: el commit de T-016-02 es solo el renombrado (plan D1).

- [x] **T-016-01** Test de referencia, **sobre el código actual y antes de cualquier cambio**: en
  `test_zombie_spawner.gd`, `test_r_016_22_zombies_pinned` fija "id @ posición" de los zombies de 3 semillas × 4
  visitas y el drop de cada uno al matarlo (id × cantidad), con los valores que da hoy `spawn_enemies`. Cubre: R-016-22. Verifica: el test pasa en verde sin tocar
  código de producción.
- [x] **T-016-02** Comprobar el renombrado de scripts con `class_name` fuera del editor (plan §5.1) y anotarlo; después,
  renombrado de D1 con `git mv` (scripts con su `.uid`, tests), rutas en `.tscn`, `--import` y referencias en tests. Sin
  ningún otro cambio. Cubre: — (habilita R-016-06, R-016-10, R-016-20 a R-016-25). Verifica: suite completa en verde
  (`godot-runner`), `test_r_016_22_zombies_pinned` incluido, y el editor abre sin errores. Commit
  `refactor(enemies): ...` aparte.
- [x] **T-016-03** Test primero: `SeededRng` con los tres flujos `hostile_robot_*` (nombres fijados), `PieceDropData`,
  `EnemyData.piece_drop` (null por defecto) y los campos `hostile_robot_*` de `ZoneData` (0, 0, vacío por defecto).
  Cubre: R-016-17 (nombres), R-016-04, R-016-20 (campos). Verifica: `test_seeded_rng.gd`, `test_enemy_resources.gd`,
  `test_zone_resources.gd` (casos de valores por defecto).
- [x] **T-016-04** Test primero: `LootSystem.validate_piece_drop`, `roll_piece` y `roll_enemy_drop` (plan D11), y
  `Enemy._drop_loot` llamando a `roll_enemy_drop`. Cubre: R-016-14 a R-016-17 (lógica), R-016-22 (secuencia del
  zombie). Verifica: `test_loot_system.gd`; `test_enemy.gd` de R-008-35/36 sigue en verde.
- [x] **T-016-05** Test primero: datos del robot (plan §4): `hostile_robot_basic.tres`, `hostile_robot_ai.tres`,
  `hostile_robot_drop.tres`, `resources/piece_drops/hostile_robot_piece_drop.tres`, entrada en `data_catalog.tres`,
  `ENEMY_HOSTILE_ROBOT_BASIC` en `strings.csv`, y `green_zone.tres` con 0-1 robot. Actualizar el esperado de
  `test_r_006_02_only_the_two_zombies` y `EXPECTED_ENEMY_IDS` de `test_data_catalog.gd` (plan §5.3). Cubre: R-016-01 a R-016-05, R-016-20 (datos). Verifica:
  `test_enemy_resources.gd`, `test_data_catalog.gd`, `test_zone_resources.gd`.
- [x] **T-016-06** Escena `hostile_robot.tscn` (plan D2, D3) con `enemy.gd`: modelo de primitivas, colisionador,
  componentes, animaciones y mallas en `HitFlash`. Tests de la escena activada a mano con su `EnemyData` en `farm_zone_green.tscn` (sin spawner, con la navmesh
  sincronizada como en `test_enemy.gd`):
  estructura, triángulos, colisionador, animación por estado, IA propia, persecución en el suelo, velocidad, golpe tras
  el intervalo con desgaste, reinicio al salir del rango, jugador agotado, golpe recibido y destello, `enemy_killed`
  una vez, muerte sin atacante, una tirada por muerte y un solo `loot_dropped` con todo; XP al matarlo en
  `test_robot_combat.gd`. Cubre: R-016-06 a R-016-14, R-016-18 (señal). Verifica: `test_hostile_robot.gd`,
  `test_robot_combat.gd`, `test_combat_feedback.gd`.
- [x] **T-016-07** Test primero: `EnemySpawner.population` y `rules_for` (plan D4); en `farm_zone_green.tscn`,
  `%HostileRobotMarkers` con 4 marcadores colocados a mano y `%HostileRobotSpawner` (plan D7). Cubre: R-016-20,
  R-016-21, R-016-17 (semilla de drop por índice), R-016-22 (zombies intactos con robots, mapa de `rules_for`, población de cada nodo). Verifica:
  `test_enemy_spawner.gd` (casos de R-016-17, R-016-20, R-016-21, R-016-22).
- [x] **T-016-08** Test primero: `FarmZone` con dos poblaciones (plan D8): `spawn_hostile_robots`, `populate` y
  `repopulate` con los dos pools, `despawn_enemies` de los dos, `get_hostile_robots`, relevo del loot y
  `dead_hostile_robots` en el estado de visita (ausente → `[]`). Actualizar las llamadas de tests a
  `populate`/`repopulate` (plan §5.3). Cubre: R-016-23 (zona), R-016-24, R-016-25, R-016-26 (estado). Verifica:
  `test_enemy_spawner.gd`, `test_green_zone.gd`, `test_zone_memory.gd`.
- [x] **T-016-09** `ZoneLoader.hostile_robot_pool` con su precalentado (robots, chispas y objetos caídos) y
  `World/HostileRobotPool` en `main.tscn` (plan D9), pool sin asignar → `push_error` y sin robots; fixture de
  `test_zone_loader.gd` con el pool nuevo. Comprobar si la semilla de `SaveTestSupport` (visita 0) y la de
  `world_v1.json` dan robot y dónde, y que ningún test de `Main` cambia por ello (plan §7). Cubre: R-016-23, R-016-24
  (viaje y muerte). Verifica: `test_zone_loader.gd`, `test_main_scene.gd`, suite completa.
- [x] **T-016-10** Tests de punta a punta en `Main`: matar al robot deja un objeto caído con materiales y pieza que se
  abre en la pantalla de contenedor y caduca; la pieza se coge, se equipa y se repara en el tramo "pieza dañada";
  sobrevive a guardar y cargar; `world_v1.json` carga con sus zombies. Cubre: R-016-18, R-016-19, R-016-25 (guardado),
  R-016-26. Verifica: `test_main_scene.gd`, `test_save_load.gd`, `test_save_fixtures.gd`.
- [x] **T-016-11** Buscar con un script de desarrollo (fuera del repo) una semilla y visita de la zona verde con robot,
  y otra en la que su drop trae pieza; anotarlas en `plan.md` §5.2 para M1 y M3. Hacer M1 a M4 en PC y M1 a M5 en
  el APK debug de Android. Cubre: R-016-07, R-016-08, R-016-10, R-016-12, R-016-18, R-016-19, R-016-25 (manual), P12.
  Verifica: resultado de cada paso anotado en `plan.md` §5.2.

## Cierre

- [x] Definición de hecho (constitución §4) revisada: `godot-runner`, `i18n-auditor` y `balance-auditor` en paralelo,
  después `architecture-guardian` una vez.
- [x] `system-documenter spec 016` (`docs/systems/`: enemigos, loot, mundo y zonas) y CLAUDE.md (`EnemySpawner`, robot
  hostil, siguiente spec) actualizados (plan D13).
- [x] Estado del spec actualizado en `spec.md` y en `specs/README.md §6`.
