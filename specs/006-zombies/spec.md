# Spec 006 — Zombies: `HealthComponent`, IA y spawner con pool

| Campo | Valor |
|---|---|
| **Estado** | Hecho (2026-11-16) |
| **Tarea(s) ACTION_PLAN** | 1.3 |
| **Fuentes** | ACTION_PLAN.md Tarea 1.3 · PMV.md §2.1 (zombies), §2.3, §3.2, §4.3 (pool, máquina de estados), §4.5 ganchos 3 y 6 · BALANCE.md §1.1, §3.1, §4.1, §4.2, §7.1, §7.2 · SPECS.md §28 (facciones), §17 · architecture.md §3, §4, §6, §7, §8, §11, §12, §13 · Constitución P2, P3, P5, P6, P9, P12, P13 |
| **Depende de** | 002 (robot), 003 (`BatteryComponent`), 004 (zona verde, `SeededRng`, `DataCatalog`), 005 (`UIManager`: el juego no se pausa con una pantalla abierta). La 005 debe estar cerrada y fusionada antes de crear la rama |
| **Rama** | `feat/006-zombies` |

## 1. Objetivo

Poner la primera amenaza en la zona verde: zombies lentos y rápidos que patrullan, ven al robot, lo persiguen y
le quitan batería al golpearlo. Así la batería, que es la vida del robot, por fin tiene un motivo para bajar
además del paso del tiempo. A la vez fija lo que reutilizarán el combate (spec 007), la muerte (spec 008) y el
robot hostil (spec 016): `HealthComponent`, `EnemyData` con facción, la máquina de estados y el pool de enemigos.

## 2. Historias

- Como jugador, quiero ver zombies que patrullan la zona y me persiguen al acercarme, para que explorar tenga
  riesgo.
- Como jugador, quiero poder huir del zombie rápido corriendo, para que escapar sea una decisión con coste de
  batería (BALANCE §4.2).
- Como jugador, quiero que los zombies me quiten batería al golpearme, para sentir que el combate y la huida
  importan.
- Como desarrollador del combate (spec 007), quiero un `HealthComponent` con `take_damage` y `died`, para
  aplicar el daño de los brazos sin tocar la IA.

## 3. Requisitos (EARS)

### 3.1 Datos

| ID | Requisito | Fuente |
|---|---|---|
| R-006-01 | THE game SHALL define an `EnemyData` resource with a stable `snake_case` id, a translated name key, max HP, damage per hit, move speed, attack interval and a `faction` field from the enum `INFECTED`, `MACHINE`, `HUMAN`. | ACTION_PLAN 1.3, PMV §4.5 gancho 6, architecture §8 |
| R-006-02 | THE game SHALL have two `EnemyData` `.tres` files, the slow and the fast zombie, both with faction `INFECTED` and the HP, damage, speed and attack interval of BALANCE §3.1. | ACTION_PLAN 1.3, BALANCE §3.1, SPECS §28 |
| R-006-03 | THE AI tuning values (vision radius, attack range, patrol behaviour, chase give-up distance) SHALL come from data resources with the values of BALANCE, not script literals. | Constitución P2 — ver pregunta 2 |
| R-006-04 | THE `DataCatalog` SHALL list every `EnemyData` under `resources/enemies/`, THE `DataRegistry` SHALL return each one by id, and a test SHALL reject repeated or empty ids. | architecture §8 |

### 3.2 Salud

| ID | Requisito | Fuente |
|---|---|---|
| R-006-05 | THE `HealthComponent` SHALL hold `hp_current` and `hp_max`, start at `hp_max`, and emit `health_changed(current, maximum)` whenever `hp_current` changes. | ACTION_PLAN 1.3 |
| R-006-06 | WHEN `take_damage(amount)` is called with a positive amount, THE `HealthComponent` SHALL lower `hp_current` by that amount without going below 0. | ACTION_PLAN 1.3 |
| R-006-07 | WHEN `hp_current` reaches 0, THE `HealthComponent` SHALL emit `died` exactly once, and further `take_damage` or `heal` calls SHALL change nothing until it is reset. | ACTION_PLAN 1.3, architecture §13 (señal una vez) |
| R-006-08 | WHEN `heal(amount)` is called with a positive amount on a living entity, THE `HealthComponent` SHALL raise `hp_current` by that amount without going above `hp_max`. | ACTION_PLAN 1.3 |
| R-006-09 | IF `take_damage` or `heal` receives a negative amount, THEN THE `HealthComponent` SHALL report an error with context and change nothing. | Constitución §2 (errores) |

### 3.3 Escena e IA

| ID | Requisito | Fuente |
|---|---|---|
| R-006-10 | THE `Zombie` scene SHALL be a `CharacterBody3D` with collision, a low-poly model with idle, walk and attack animations, a `HealthComponent` and a `NavigationAgent3D`, configured only through an `EnemyData`. | ACTION_PLAN 1.3 — ver pregunta 6 |
| R-006-11 | THE zombie AI SHALL be a state machine with the states `IDLE`, `PATROL`, `CHASE` and `ATTACK`, whose transition rules live in pure code testable without a scene tree. | ACTION_PLAN 1.3, PMV §4.3, Constitución P3 |
| R-006-12 | WHILE no player is within its vision radius, THE zombie SHALL alternate between `IDLE` and `PATROL` around its spawn position. | ACTION_PLAN 1.3 — ver pregunta 2 |
| R-006-13 | WHEN a living player enters the zombie's vision radius, THE zombie SHALL switch to `CHASE` and move toward that player along the zone's navigation mesh at the speed of its `EnemyData`. | ACTION_PLAN 1.3, BALANCE §3.1 — ver pregunta 3 |
| R-006-14 | WHEN the chased player gets farther than the chase give-up distance, THE zombie SHALL stop chasing and return to `PATROL`. | Inferido — ver pregunta 2 |
| R-006-15 | WHILE the chased player is within attack range, THE zombie SHALL be in `ATTACK`, stop moving, face the player and hit once per attack interval of its `EnemyData`. | ACTION_PLAN 1.3, BALANCE §3.1 — ver pregunta 4 |
| R-006-16 | WHEN a zombie hit lands, THE player's `BatteryComponent` SHALL lose the zombie's damage in battery points. | BALANCE §1.1, §3.1, CLAUDE.md (batería = vida) — ver pregunta 1 |
| R-006-17 | WHEN a zombie hit lands, THE hit SHALL be announced by a typed signal that carries the damage and the attacker, so the degradation of pieces (spec 015) can connect to it without touching the AI. | BALANCE §4.1, Constitución P6 |
| R-006-18 | WHILE the player's battery is depleted, THE zombies SHALL not target or hit that player. | Inferido de spec 003 R-003-12 y spec 004 R-004-16 |
| R-006-19 | WHILE a screen of the `UIManager` is open, THE zombies SHALL keep acting, since the game is not paused. | Spec 005 (`UIManager` sin pausa) |
| R-006-20 | THE zombies SHALL walk around obstacles and stay inside the zone's playable area. | ACTION_PLAN 1.3, SPECS §31 (los enemigos no saltan) — ver pregunta 3 |
| R-006-21 | WHEN a zombie's `HealthComponent` emits `died`, THE zombie SHALL stop acting, leave the scene's active set and return to the enemy pool. | ACTION_PLAN 1.3, Constitución P12 |

### 3.4 Spawner y pool

| ID | Requisito | Fuente |
|---|---|---|
| R-006-22 | THE zombies SHALL come from a generic `ObjectPool` that reuses instances instead of creating and freeing them, and a reused zombie SHALL start with full HP, in `IDLE`, with no target. | architecture §11, PMV §3.2, Constitución P12 |
| R-006-23 | WHEN the green zone is generated, THE `ZombieSpawner` SHALL place a number of zombies within the range of BALANCE §7.1, choosing count, type and position with a `SeededRng` stream of its own. | ACTION_PLAN 1.3, BALANCE §7.1, Constitución P9 — ver preguntas 5 y 7 |
| R-006-24 | THE spawn generation SHALL use only RNGs from `SeededRng`, never the global `randf()`, `randi()`, `randi_range()` or `randomize()`. | Constitución P9 |
| R-006-25 | WHEN the green zone is generated twice with the same world seed and the same visit number, THE zombies SHALL appear in the same number, types and positions. | ACTION_PLAN 1.3, BALANCE §7.2 |
| R-006-26 | THE `ZombieSpawner` SHALL take the zone's visit number as a parameter, so a new visit spawns all zombies again; until spec 010 adds the visit counter, the caller SHALL pass 0. | BALANCE §7.2, PMV §10 (reposición) — ver pregunta 7 |
| R-006-27 | WHEN the zone is unloaded, THE spawner SHALL return every zombie to the pool. | architecture §6, §11 |
| R-006-28 | WHILE the green zone holds its maximum of zombies around the robot, THE game SHALL stay within the mobile budget of PMV §3.2 and keep ≥ 30 FPS on the mid-range Android device. | PMV §3.2, Constitución P12 |

Los valores numéricos (HP, daño, velocidad, intervalo de ataque, número de zombies, radios) se citan por su
fuente; el spec no los fija.

## 4. Fuera de alcance

- Atacar a los zombies, hitbox de los brazos, consumo de batería por golpe, XP al matar y
  `EventBus.enemy_killed`: spec 007 (ACTION_PLAN 1.4). En la 006 solo los tests llaman a `take_damage`.
- Material que sueltan los zombies al morir (BALANCE §3.1, "0-1 chatarra"): spec 007, con la muerte por combate.
- Degradación de piezas por golpe recibido (BALANCE §4.1): spec 015. La 006 solo emite la señal del golpe
  (R-006-17).
- Muerte del robot, `RulesetData`, contador de visitas que sube al morir: spec 008. La pantalla provisional de
  game over de la 003 sigue sirviendo.
- Contador de visitas por zona y guardado del estado de los zombies: spec 010. En la 006 los zombies reaparecen
  enteros cada vez que se genera la zona.
- Robot hostil (facción `MACHINE`) y sus drops: spec 016. Zombies eléctrico y ácido: v1.1 (SPECS §17).
- Tabla de relaciones entre facciones e IA de grupo de los infectados (aggro compartido, flanqueo): v1.2
  (SPECS §28). En la 006 la facción es solo un campo de datos.
- Retroceso, parpadeo, sacudida de cámara, partículas y sonido al golpear o recibir golpes: ACTION_PLAN 1.4,
  4.3, 4.4.
- Barra de vida sobre los zombies: no la pide el PMV.
- Generación procedural de zonas y navmesh en tiempo de ejecución: v1.1, pendiente del spike de la Tarea 0.5.
- Sigilo y agachado (detección reducida): v1.1 (SPECS §30).

## 5. Criterio de hecho

En la zona verde aparecen entre 5 y 8 zombies (BALANCE §7.1), lentos y rápidos, que patrullan. Al acercarse el
robot, lo persiguen rodeando obstáculos; andando no se escapa del rápido y corriendo sí (BALANCE §4.2). En rango
golpean cada 1.5 s (BALANCE §3.1) y la batería baja lo que indica BALANCE §3.1 por golpe. Con la batería a 0 dejan
de atacar. Con la misma semilla y visita salen los mismos zombies en el mismo sitio. Tests en verde:
`HealthComponent` (daño, curación, límites, `died` una vez), transiciones de la máquina de estados, intervalo de
ataque, spawner reproducible y dentro de rango, pool que reinicia al reutilizar, catálogo de enemigos válido y
ningún RNG global en la generación. ≥ 30 FPS en el Android de gama media con todos los zombies persiguiendo al
robot.

## 6. Preguntas abiertas

| # | Pregunta | Propuesta | ¿Bloquea? |
|---|---|---|---|
| 1 | ~~¿El daño de BALANCE §3.1 son puntos de batería?~~ | **Cerrada (nov 2026)**: 1:1, sin defensa en el PMV (BALANCE §3.1). | — |
| 2 | ~~Números de IA~~ | **Cerrada (nov 2026)**: visión 8 m, ataque 1.5 m, patrulla en 5 m con pausas de 2-4 s, abandono a 12 m; iguales para los dos tipos y ajustables en el móvil (BALANCE §3.1, "IA de zombies"). | — |
| 3 | ~~Navmesh de la zona verde~~ | **Cerrada (nov 2026)**: horneado en el editor, porque la zona es estática; no depende del spike de la Tarea 0.5. | — |
| 4 | ~~¿Primer golpe inmediato?~~ | **Cerrada (nov 2026)**: tras un intervalo completo en rango; salir y volver a entrar reinicia la espera (BALANCE §3.1). | — |
| 5 | ~~Proporción de lentos y rápidos~~ | **Cerrada (nov 2026)**: primero uno de cada tipo y el resto al 50 % (BALANCE §7.1). Los pesos van en el `.tres` de la zona. | — |
| 6 | ~~Modelo y animaciones~~ | **Cerrada (nov 2026)**: modelo CC0 (Quaternius o Kenney) con idle, walk y attack si hay uno con licencia clara; si no, placeholder de primitivas con `AnimationPlayer`. Licencia anotada como en la 004. | — |
| 7 | ~~Posiciones y semilla~~ | **Cerrada (nov 2026)**: marcadores colocados a mano (más que el máximo de zombies); número, tipo y marcador salen de `semilla + zone_id + número de visita` en un stream propio de `SeededRng`, así que cambian en cada visita (BALANCE §7.1). | — |
| 8 | ~~Colisión entre zombies~~ | **Cerrada (nov 2026)**: colisión física con el robot y el escenario; `avoidance` del `NavigationAgent3D` desactivada al principio y activada solo si se amontonan en el móvil. | — |
| 9 | ~~¿Aviso al recibir un golpe?~~ | **Cerrada (nov 2026)**: ninguno extra en la 006; la barra de batería del HUD ya baja por señal (spec 003). | — |
