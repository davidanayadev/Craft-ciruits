# Spec 016 — Robot hostil y sus drops

| Campo | Valor |
|---|---|
| **Estado** | Aprobado (2026-11-26) |
| **Tarea(s) ACTION_PLAN** | 3.3 |
| **Fuentes** | ACTION_PLAN.md Tarea 3.3 (y 1.3, 1.5, 4.1, 4.3, 4.4 para los límites) · PMV.md §2.1, §2.3, §4.3, §10 ("Muerte y objetos caídos": forma del objeto caído) · BALANCE.md §2, §2.1, §3.1, §3.2, §4.1, §4.3.2, §6.2, §7.1, §7.2 · SPECS.md §15.4, §17.2, §28 · ONLINE.md (créditos) · architecture.md §6, §7, §8, §10.2, §11 · README §6 (condición de entrada de la 016) · specs 004, 006 (R-006-14, R-006-18, R-006-27), 007 (R-007-17), 008 (R-008-35), 010 (R-010-32), 011 (plan §7), 015 (objeto caído como contenedor, R-015-21) · Constitución P2, P3, P5, P9, P11, P12, P13, P14 |
| **Depende de** | 006 (`EnemyData`, `EnemyBrain`, `HealthComponent`, pool, spawner por visita), 007 (`HurtboxComponent`, `enemy_killed`, XP al matar, `CombatFeedback`), 008 (drops de enemigos como objeto caído, semilla por visita), 010 (enemigos muertos de la visita en el guardado), 011 (`PieceData`, piezas únicas con `uid` y durabilidad, `CraftingSystem.create_result`), 013 (pantalla de contenedor), 015 (objeto caído como contenedor, equipo, desgaste por golpe) |
| **Rama** | `feat/016-hostile-robot` |

## 1. Objetivo

Añadir el segundo tipo de enemigo del PMV, el robot hostil básico (facción `MACHINE`, BALANCE §3.2), y con él la
única fuente de piezas que no es el banco: al morir suelta siempre materiales y, a veces, una pieza dañada al 50 %
que hay que reparar. Es más duro que un zombie y más raro (0-1 por visita, BALANCE §7.1), así que da una razón para
arriesgarse en la zona y una vía de recuperar piezas tras una muerte. Va ahora porque las piezas ya se equipan, se
desgastan y se reparan (spec 015), y cierra la Fase 3 junto con la spec 017.

## 2. Historias

- Como jugador, quiero encontrarme a veces un robot hostil en la zona verde, más duro que los zombies, para que cada
  visita tenga un riesgo distinto.
- Como jugador, quiero que al matarlo caigan materiales y, con suerte, una pieza dañada, para conseguir piezas sin
  fabricarlas y recuperarme antes tras una muerte.
- Como jugador, quiero que la pieza que suelta funcione como cualquier otra (equipar, reparar, guardar), para no
  tener que aprender reglas nuevas.
- Como desarrollador, quiero que el robot hostil reutilice la máquina de estados, el pool, el combate y el objeto
  caído de los zombies, para que un enemigo nuevo sea sobre todo datos y una escena.

## 3. Requisitos (EARS)

Los valores numéricos se citan por su fuente (`BALANCE.md §x`); el spec no los fija.

### 3.1 Datos

| ID | Requisito | Fuente |
|---|---|---|
| R-016-01 | THE basic hostile robot SHALL be described by an `EnemyData` `.tres` with faction `MACHINE` and the HP, hit damage, move speed and XP of BALANCE §3.2, listed in the `DataCatalog`, with no gameplay literal in any script. | ACTION_PLAN 3.3, BALANCE §3.2, SPECS §28, architecture §8, Constitución P2, P5 |
| R-016-02 | THE `EnemyData` of the hostile robot SHALL take its attack interval from BALANCE §3.2. | ACTION_PLAN 3.3 ("cada 2s") — pregunta 1 |
| R-016-03 | THE hostile robot SHALL take its AI tuning (vision radius, attack range, patrol radius, patrol pauses, chase give-up distance) from an `EnemyAiData` resource of its own, not shared with the zombies, with the values of BALANCE §3.2 ("IA del robot hostil"). | ACTION_PLAN 3.3, BALANCE §3.2 — pregunta 2 |
| R-016-04 | THE drop of the hostile robot SHALL be data: its materials as a loot table with the ranges of the "Robot hostil básico" row of BALANCE §2.1, and the chance of a piece, the pieces it can drop and the durability they keep from BALANCE §3.2. | BALANCE §2.1, §3.2, Constitución P2, P5 — pregunta 4 |
| R-016-05 | THE player-visible name of the hostile robot SHALL be a translation key with its ES and EN texts. | Constitución P11 |

### 3.2 Comportamiento y combate

| ID | Requisito | Fuente |
|---|---|---|
| R-016-06 | THE hostile robot SHALL be driven by the same state machine as the zombies (`EnemyBrain`: `IDLE`, `PATROL`, `CHASE`, `ATTACK`), fed with its own `EnemyAiData` and attack interval, and SHALL detect players by their distance on the ground, like the zombies. | ACTION_PLAN 3.3, plan 006 (`EnemyBrain` sirve al robot hostil) — pregunta 3 |
| R-016-07 | WHILE patrolling or chasing, THE hostile robot SHALL walk at its move speed (BALANCE §3.2) along the zone's navmesh with a `NavigationAgent3D`, going around obstacles. | ACTION_PLAN 3.3, BALANCE §3.2 |
| R-016-08 | WHILE a player is within its attack range, THE hostile robot SHALL stop and land one hit per attack interval through `Robot.receive_hit` with its hit damage, so that each hit takes battery 1:1 and wears the player's pieces like any received hit; the first hit SHALL come after a full interval in range, and leaving the range SHALL restart the wait. | ACTION_PLAN 3.3, BALANCE §3.1 (regla del intervalo), §3.2, §4.1 — pregunta 1 |
| R-016-09 | WHILE a player's battery is depleted, THE hostile robots SHALL not target or hit that player. | Spec 006 R-006-18 |
| R-016-10 | THE hostile robot SHALL play an idle, a walk and an attack animation from its `AnimationPlayer`, following its state, and its model SHALL be told apart at a glance from the player's robot and from the zombies. | ACTION_PLAN 3.3 — pregunta 11 |
| R-016-11 | WHEN a player's hit reaches the hostile robot's hurtbox, THE hostile robot SHALL lose that damage from its `HealthComponent` and show the same hit feedback as a zombie (white flash, impact sparks). | Spec 007, ACTION_PLAN 1.4 |
| R-016-12 | WHEN the hostile robot's `HealthComponent` reaches 0 after a player's hit, THE game SHALL emit `EventBus.enemy_killed` once with the robot's enemy id and the killer's uid, so that the killer gains the XP of BALANCE §3.2 (§6.2). | ACTION_PLAN 3.3, BALANCE §3.2, §6.2, Spec 007 R-007-17 |
| R-016-13 | IF the hostile robot dies with no player's hit as the cause, THEN THE game SHALL award no XP and roll no drop. | Spec 007 R-007-17, Spec 008 R-008-35 |

### 3.3 Drops

| ID | Requisito | Fuente |
|---|---|---|
| R-016-14 | WHEN a player kills a hostile robot, THE game SHALL roll its material table once, with the range rule of BALANCE §2.1 (uniform integer, both ends included, a 0 delivers nothing). | ACTION_PLAN 3.3, BALANCE §2.1 |
| R-016-15 | WHEN a player kills a hostile robot, THE game SHALL also give, with the chance of BALANCE §3.2, exactly one piece chosen with equal chance among the pieces the robot can drop. | ACTION_PLAN 3.3, BALANCE §3.2 — pregunta 4 |
| R-016-16 | THE dropped piece SHALL be a unique stack with a new `uid` and a durability of the fraction of BALANCE §3.2 of its `durability_max`, never a plain `ItemStack.new(item, n)`. | BALANCE §3.2, README §6 (condición de entrada), plan 011 §7 |
| R-016-17 | THE roll of a hostile robot's drop (materials and piece) SHALL be seeded from the world seed, the `zone_id`, the visit number and the robot's place in the spawn of that visit, so that neither the order of the kills nor a reload changes it, and the global RNG SHALL not be used. | BALANCE §2.1, §7.2, Constitución P9, Spec 008 |
| R-016-18 | WHEN the drop of a killed hostile robot holds anything, THE game SHALL create one dropped object where the robot died, holding the materials and the piece, which opens in the container screen and expires like the loot of any enemy. | PMV §10 (forma del objeto caído), BALANCE §7.2, Spec 008 R-008-35, Spec 015 — pregunta 5 |
| R-016-19 | THE piece dropped by a hostile robot SHALL behave as any piece of the same kind: it can be taken, equipped, repaired at the bench at the tier of BALANCE §4.3.2 that its durability gives, and it keeps its durability and `uid` on every path that moves or saves a stack. | BALANCE §3.2 ("requiere reparación"), §4.3.2, Specs 011, 015 |

### 3.4 Aparición, visitas y guardado

| ID | Requisito | Fuente |
|---|---|---|
| R-016-20 | WHEN a visit of the green zone is populated, THE zone SHALL place a number of hostile robots within the range of BALANCE §7.1, decided from the world seed, the `zone_id` and the visit number. | ACTION_PLAN 3.3, BALANCE §7.1, §7.2, Constitución P9 — pregunta 6 |
| R-016-21 | THE hostile robots of a visit SHALL appear on markers of the zone reserved for them, chosen from the world seed, the `zone_id` and the visit number. | BALANCE §7.2 (enemigos por visita) — pregunta 7 |
| R-016-22 | THE hostile robots SHALL not change the number, kinds, markers, behaviour seeds or drops of the zombies of any world seed and visit. | BALANCE §7.2, Spec 010 (mundos guardados) — preguntas 8 y 9 |
| R-016-23 | THE hostile robots SHALL be taken from an object pool prewarmed while the zone loads, and SHALL return to it when they die, when a new visit starts and when the zone is unloaded. | ACTION_PLAN 1.3, Constitución P12, architecture §11, Spec 006 R-006-27 |
| R-016-24 | WHEN a new visit of the zone starts (leaving by the exit or dying in it), THE hostile robots of the old visit SHALL be replaced by those of the new visit. | BALANCE §7.2 ("Enemigos"), Specs 008, 009 |
| R-016-25 | THE World SHALL keep which hostile robots of the visit in progress are dead, and a loaded zone SHALL not bring them back nor roll their drop again; a living hostile robot SHALL come back on its marker with full HP. | BALANCE §7.2 ("Enemigos muertos"), Spec 010 R-010-32 |
| R-016-26 | WHEN a World saved before this spec is loaded, THE game SHALL load it without a migration, and the zombies of its visit in progress SHALL stay as they were saved. | Spec 010 (compatibilidad) — pregunta 9 |

## 4. Fuera de alcance

- Más tipos de robot hostil (eléctrico, a distancia) y sus ataques: v1.1 (PMV §2.3, SPECS §17.2).
- Planos como drop del robot hostil y materiales extra si ya se tiene el plano: v1.1 (SPECS §15.4).
- Créditos del mercado al matar robots (ONLINE.md): llegan con el mercado asíncrono, fuera del PMV.
- Relaciones entre facciones (zombies y robots que se atacan entre sí) y ataques telepáticos de la IA rebelde: v1.2
  (PMV §2.3, SPECS §28). En el PMV la facción es solo un dato; robots y zombies se ignoran.
- Estado `Flee` (PMV §4.3): ni ACTION_PLAN 3.3 ni BALANCE §3.2 lo piden.
- Cambiar la regla de abandono de la persecución (enmienda pendiente de la spec 006, decidida el 2026-11-16): va en su
  propia rama. El robot hostil sigue la regla que tenga `EnemyBrain` (pregunta 10).
- Iconos de enemigos en el minimapa: ACTION_PLAN 4.1. Sonidos del robot hostil: ACTION_PLAN 4.3. Modelo y
  animaciones finales: ACTION_PLAN 4.4 y arte (pregunta 11).
- Piezas visibles en el modelo del robot hostil o desgaste de sus propias piezas: el robot hostil no tiene equipo
  real; "las piezas que puede soltar" es un dato de su drop (pregunta 4).
- Robots hostiles en la base: la base es zona segura (PMV §2.1).
- Fuentes nuevas de XP (craftear, reparar, vaciar un sitio): spec 017.

## 5. Criterio de hecho

- Tests (ACTION_PLAN 3.3, "robot hostil suelta piezas y materiales al morir"): el catálogo tiene el robot hostil con
  los valores de BALANCE §3.2 y su tabla de BALANCE §2.1; matarlo emite `enemy_killed` una vez y da su XP; su drop
  siempre trae materiales en rango y, con una semilla que lo dé, una pieza con `uid` nuevo y la durabilidad de BALANCE
  §3.2; la misma semilla y visita dan el mismo drop; en muchas visitas con una semilla fija salen 0 y 1 robots, y los
  zombies de cada visita son los mismos que sin esta spec; un robot muerto no vuelve al recargar la visita; el pool
  reinicia la vida al reutilizarlo.
- En el juego (PC y Android): en algunas visitas a la zona verde aparece un robot hostil, distinto a simple vista de
  los zombies, que patrulla, persigue rodeando obstáculos y golpea con el intervalo y el daño de BALANCE §3.2, y sus
  golpes desgastan las piezas. Andando con Piernas básicas se le escapa (BALANCE §3.2 frente a §4.2). Al matarlo, el
  nivel/XP del HUD de depuración sube lo de BALANCE §3.2 y cae un objeto con materiales; tras varias muertes (o con
  una semilla de prueba) cae una pieza que se ve a la mitad de su durabilidad, se coge en la pantalla de contenedor, se
  equipa y se repara en el banco con el coste del tramo que le toca.
- Cerrar y abrir el juego dentro de la visita no resucita a un robot muerto ni repite su drop.
- ≥ 30 FPS en el Android de gama media con el robot hostil y todos los zombies persiguiendo al jugador (PMV §3.2).
- Ningún literal de BALANCE §2.1, §3.2 o §7.1 en scripts (`balance-auditor`); nombre del enemigo en ES + EN
  (`i18n-auditor`).

## 6. Preguntas abiertas

| # | Pregunta | Propuesta | ¿Bloquea? |
|---|---|---|---|
| 1 | ~~Intervalo de ataque del robot hostil~~ | **Cerrada (2026-11-26)**, como se proponía: **2 s**, con la misma regla que los zombies (el primer golpe tras un intervalo completo en rango; salir y volver a entrar reinicia la espera). Con 8 de daño son 4 puntos de batería por segundo frente a los 3.3 del zombie lento. Anotado en BALANCE §3.2. | — |
| 2 | ~~IA del robot hostil~~ | **Cerrada (2026-11-26)**: empieza con los mismos valores que los zombies (visión 8 m, rango 1.5 m, patrulla 5 m, pausas 2-4 s, abandono 12 m), pero como **valores propios**: tabla "IA del robot hostil" en BALANCE §3.2 y un `EnemyAiData` `.tres` aparte del de los zombies (R-016-03), para ajustarlos por separado en las pruebas (decisión del usuario). Su intervalo de ataque y el resto de su `EnemyData` también son suyos. | — |
| 3 | ~~Detección con `Area3D`~~ | **Cerrada (2026-11-26)**, como se proponía: por distancia en el suelo, como los zombies (R-016-06). ACTION_PLAN 3.3 corregido. | — |
| 4 | ~~Qué piezas puede soltar~~ | **Cerrada (2026-11-26)**, como se proponía: con poca probabilidad (15 %, BALANCE §3.2) **cualquiera de las tres piezas básicas**, 1/3 cada una, medio rota (50 % de durabilidad); también da Cores de repuesto. Los materiales son los de su fila de BALANCE §2.1. No tiene equipo real: las piezas son un dato del drop. Anotado en BALANCE §3.2 y ACTION_PLAN 3.3. | — |
| 5 | ~~`DroppedPiece.tscn`~~ | **Cerrada (2026-11-26)**, como se proponía: sin escena nueva; un solo objeto caído por muerte con los materiales y la pieza (R-016-18), que caduca como el material de un zombie (BALANCE §7.2). ACTION_PLAN 3.3 corregido. | — |
| 6 | ~~Cómo se tira "0-1 robots"~~ | **Cerrada (2026-11-26)**, como se proponía: regla de rangos de BALANCE §2.1, un robot en la mitad de las visitas. Anotado en BALANCE §7.1. | — |
| 7 | ~~Dónde aparece~~ | **Cerrada (2026-11-26)**, como se proponía: marcadores propios del robot, colocados a mano lejos del punto de aparición del jugador y distintos de los de los zombies, elegidos por semilla y visita (R-016-21). Anotado en BALANCE §7.1. | — |
| 8 | ~~¿Cuenta en los 5-8 enemigos de la zona?~~ | **Cerrada (2026-11-26)**, como se proponía: no; 5-8 zombies más 0-1 robot. El pool de objetos caídos se calienta con uno más. Anotado en BALANCE §7.1. | — |
| 9 | ~~Mundos guardados y visita en curso~~ | **Cerrada (2026-11-26)**, como se proponía: flujos de semilla propios del robot (aparición, comportamiento y drop) y su lista de muertos aparte en el estado de la visita; sin migración (R-016-22, R-016-26). Aceptado: en una visita guardada antes de esta spec puede aparecer un robot que antes no estaba. | — |
| 10 | ~~Abandono de la persecución~~ | **Cerrada (2026-11-26)**, como se proponía: el robot usa `EnemyBrain` tal cual, con su propia distancia de abandono (BALANCE §3.2). La enmienda pendiente de la spec 006 decidirá si la persecución sin abandono vale también para el robot. | — |
| 11 | ~~Modelo y animaciones~~ | **Cerrada (2026-11-26)**, como se proponía: placeholder de primitivas distinto en silueta y color del jugador y de los zombies, con animaciones sencillas idle, walk y attack; colisionador que cabe en la navmesh actual. Modelo CC0 en el pase de arte (ACTION_PLAN 4.4). | — |
| 12 | ~~Reutilizar el código del zombie~~ | **Cerrada (2026-11-26)**, como se proponía: el plan decide cómo compartir `Zombie` y `ZombieSpawner` sin duplicar lógica; un renombrado, si hace falta, se propone en el plan y se aprueba en su revisión (Constitución P14). | — |
