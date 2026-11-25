# Spec 015 — Piezas, ranuras y degradación

| Campo | Valor |
|---|---|
| **Estado** | Hecho (2026-11-25) |
| **Tarea(s) ACTION_PLAN** | 3.1, 3.2 (y el punto pendiente de 1.5: "Limpiar piezas equipadas (conservar solo core)") |
| **Fuentes** | ACTION_PLAN.md Tareas 3.1, 3.2 (y 1.4, 1.5, 2.4, 2.5, 3.3, 3.4, 4.1, 4.3, 4.4, 5.1 para los límites) · PMV.md §2.1, §2.2, §2.3, §2.4, §4.5 gancho 7, §10 ("Muerte y objetos caídos", "Crafteo y reparación", "Progresión y recuerdos") · BALANCE.md §1.1, §4.1, §4.2, §4.3.2, §5.2, §6.3, §9.3, §11 · SPECS.md §6, §15 · architecture.md §6, §7, §9.2, §9.3, §9.4, §9.5, §10.2 · README §6 (pendientes para la 015) · specs 002 (R-002-18), 003, 006 (R-006-17, R-006-18), 007 (R-007-02), 008 (pregunta 4, R-008-11), 010, 011 (R-011-09, preguntas 6 y 8), 012 (pregunta 11), 014 (R-014-16) · Constitución P2, P3, P4, P5, P6, P11, P13, P14 |
| **Depende de** | 002 (movimiento, `LocomotionSystem`), 003 (`BatteryComponent`), 006 (`hit_received`), 007 (`MeleeAttackComponent`, `AttackStatsData`), 008 (`RulesetData.keeps_core`, objeto caído), 010 (contrato `persistent`, señales de estado y de hecho), 011 (`PieceData`, piezas únicas con `uid` y durabilidad, pestaña Reparar), 012 (bonificación de batería máxima del generador), 013 (pantalla de contenedor), 014 (orden de carga de las partes del robot) |
| **Rama** | `feat/015-pieces-slots-degradation` |

## 1. Objetivo

Que las piezas sirvan para algo. Desde la spec 011 se crean y se reparan Brazos, Piernas y Core básicos, pero no
se pueden equipar: el robot anda con los valores fijos de las Piernas básicas, pelea con un brazo y tiene la batería
máxima del Core básico, leídos de recursos sueltos (R-002, R-003, R-007-02). Esta spec trae las tres ranuras de
equipo, los stats como modificadores (`StatModifier`, `StatsCalculator`, `StatsComponent`, architecture §9.4), el
desgaste por golpe recibido hasta la rotura (BALANCE §4.1) y la pantalla para equipar y ver la durabilidad. Cierra
también lo que otras specs dejaron para cuando existieran las ranuras: soltar brazos y piernas al morir y conservar
el Core (spec 008, pregunta 4), reparar piezas equipadas (spec 011, pregunta 6) y el Core de repuesto al morir
(spec 011, pregunta 8). Como al morir caen más pilas de las que caben al reaparecer, el objeto caído pasa a ser un
contenedor que se abre en la pantalla de la spec 013 (pregunta 15). Deja `StatsComponent` y el Core equipado listos
para los recuerdos (spec 017).

## 2. Historias

- Como jugador, quiero equiparme las piezas que fabrico, para pegar más fuerte con Brazos básicos y moverme y correr
  con Piernas básicas.
- Como jugador, quiero ver cuánto le queda a cada pieza equipada y los stats que me dan, para decidir cuándo volver
  a la base a repararlas.
- Como jugador, quiero que cada golpe que recibo desgaste mis piezas hasta romperlas, para que los combates tengan
  un coste más allá de la batería.
- Como jugador que muere, quiero que mis brazos y piernas caigan con el inventario y poder recuperarlos, y conservar
  el Core (PMV §2.4).
- Como desarrollador de la spec 017 (recuerdos) y de las piezas de v1.1, quiero que todo stat del robot salga de
  `StatsComponent` con modificadores como datos, para añadir recuerdos y piezas nuevas sin tocar movimiento, batería
  ni combate.

## 3. Requisitos (EARS)

Los valores numéricos se citan por su fuente (`BALANCE.md §x`); el spec no los fija.

### 3.1 Datos y cálculo de stats

| ID | Requisito | Fuente |
|---|---|---|
| R-015-01 | THE `PieceData` resource SHALL declare the equipment slot it fits (`slot_type`: arms, legs or core) and its stats as a list of `StatModifier` (stat id, operation `SET`, `ADD` or `MULTIPLY`, value); the three basic pieces SHALL carry the values of BALANCE §4.2 in their `.tres`, with no gameplay literal in any script. | ACTION_PLAN 3.1, architecture §9.3, §9.4, Constitución P2, P5 |
| R-015-02 | THE stats of the robot with no piece equipped (one arm, no legs, no Core) SHALL live in one base-stats resource (`RobotBaseStats.tres`) with the values of BALANCE §1.1, §4.1 and §4.2, and every number of BALANCE §4.2 SHALL be defined in exactly one resource (no second copy in the movement, attack or battery resources used until now). | ACTION_PLAN 3.1, architecture §9.4, Constitución P2 — pregunta 2 |
| R-015-03 | THE stats of an entity SHALL be computed by a pure `StatsCalculator` (no scene dependency) from a base and a list of modifiers, applying every `SET`, then every `ADD`, then every `MULTIPLY`, without changing its inputs. | architecture §9.4, Constitución P3, P13 |
| R-015-04 | IF a modifier names a stat the base does not have, THEN `StatsCalculator` SHALL ignore that modifier and report it with `push_error()`. | Constitución §2 (errores) |
| R-015-05 | THE robot's stats SHALL be the base stats with the modifiers of its equipped pieces only: a piece in the inventory, a chest or a dropped object SHALL change nothing. | PMV §2.1, ACTION_PLAN 3.1 |
| R-015-06 | THE durability lost per hit received SHALL be a stat of the base-stats resource (BALANCE §4.1), so that a modifier can change it (spec 017, "Chasis reforzado", BALANCE §6.3). | BALANCE §4.1, §6.3 |

### 3.2 Equipo

| ID | Requisito | Fuente |
|---|---|---|
| R-015-07 | THE robot SHALL own an `EquipmentComponent` with three slots (arms, legs, core), each empty or holding one piece `ItemStack` with its `uid` and durability; it SHALL be per-player state, never in an autoload. | ACTION_PLAN 3.1, architecture §9.3, PMV §4.5 gancho 7, Constitución P4 |
| R-015-08 | WHEN the player equips a piece from an inventory slot and the equipment slot of its `slot_type` is empty, THE piece SHALL leave the inventory slot and occupy that equipment slot with the same `uid` and durability, and THE `EquipmentComponent` SHALL emit `equipment_changed`. | ACTION_PLAN 3.1, R-011-09 |
| R-015-09 | WHEN the player equips a piece and the equipment slot of its `slot_type` is occupied, THE two pieces SHALL swap: the equipped one goes to the inventory slot the new one left, both keeping their `uid` and durability. | ACTION_PLAN 3.1 ("Cambiar") — pregunta 3 |
| R-015-10 | WHEN the player unequips a piece of any slot, the Core included, THE piece SHALL go to the first empty slot of the robot's inventory with its `uid` and durability, and THE `EquipmentComponent` SHALL emit `equipment_changed`. | ACTION_PLAN 3.1 |
| R-015-11 | IF the robot's inventory has no empty slot, THEN unequipping SHALL be refused with an `ActionResult` whose error key the UI shows, and nothing SHALL change. | architecture §9.2 |
| R-015-12 | IF the stack to equip is not a valid piece (not a `PieceData`, or failing `InventoryRules.is_valid_stack`), or the robot's battery is depleted, THEN equipping or unequipping SHALL be refused with an `ActionResult` and nothing SHALL change. | architecture §9.2, R-011-07, spec 008 (robot muerto) |
| R-015-13 | WHEN the equipment changes, for any reason (equip, unequip, swap, break, death, load), THE `StatsComponent` SHALL recompute the robot's stats and emit the state signal `stats_changed` once. | architecture §7, §9.4 |
| R-015-14 | THE robot's movement, battery and melee attack SHALL read their values from its `StatsComponent`; none SHALL read the equipped pieces directly. | architecture §9.4 |

### 3.3 Efecto de las piezas

| ID | Requisito | Fuente |
|---|---|---|
| R-015-15 | WHILE legs are equipped, THE robot SHALL walk and run at their speeds, drain their walking rate while walking and the running rate of BALANCE §1.1 (a stat, so spec 017 can modify it) while running; WHILE no legs are equipped, it SHALL walk at the no-legs speed, drain the no-legs walking rate and never run, whatever the run input (R-002-18 with real equipment). | BALANCE §1.1, §4.2, PMV §2.1 |
| R-015-16 | WHILE arms are equipped, THE robot SHALL attack with their damage, attacks per second and battery per swing; WHILE no arms are equipped, it SHALL attack with the one-arm values (it is never without an attack). | BALANCE §4.2, PMV §10 ("Nunca sin ataque"), R-007-02 |
| R-015-17 | WHEN the arms change while a swing is under way, THE swing SHALL land with the values it started with; the new values SHALL apply from the next swing. | Spec 007 (el golpe empezado se paga y termina) |
| R-015-18 | THE robot's maximum battery SHALL be the maximum-battery stat (the equipped Core's, or the no-Core value, which BALANCE §4.2 does not reduce) plus the wind generator's bonus (BALANCE §5.2). | BALANCE §4.2, §5.2, spec 012 (pregunta 11) — preguntas 2 y 7 |
| R-015-19 | WHEN the maximum battery changes because of the equipment, THE `BatteryComponent` SHALL follow the rule of the generator's bonus (spec 012): the charge stays, lowered only if it is above the new maximum; one `battery_changed`; never `battery_low` nor `battery_depleted`. With the values of BALANCE §4.2, removing or breaking the basic Core does not change the maximum, so it never cuts the charge. | R-012-11 a R-012-14 — pregunta 2 |
| R-015-44 | THE passive drain SHALL be a stat of `StatsComponent`: WHILE a Core is equipped, THE robot SHALL drain the Core's passive rate; WHILE no Core is equipped, it SHALL drain the no-Core rate (BALANCE §4.2, the double), wherever it is, also in the base. | BALANCE §1.1, §4.2, PMV §2.1 — pregunta 2 |

### 3.4 Degradación y rotura

| ID | Requisito | Fuente |
|---|---|---|
| R-015-20 | THE current durability of a piece SHALL live in its own `ItemStack`, so that two equal pieces wear separately; `PieceData` only holds the maximum. | ACTION_PLAN 3.2, architecture §9.3 |
| R-015-21 | WHEN a hit lands on the robot (`Robot.receive_hit`, the same hit that `hit_received` announces, R-006-17), THE first equipped piece in the order arms → legs → core SHALL lose the durability-per-hit stat (R-015-06) as a whole number, rounded to the nearest integer and never below 0; the other pieces SHALL not change. The choice of piece and the new durability SHALL be computed by pure logic (`DegradationSystem`). | BALANCE §4.1, §9.3, ACTION_PLAN 3.2, Constitución P3 |
| R-015-22 | IF no piece is equipped, THEN a hit received SHALL change no durability. A hit that the robot does not take (depleted battery, R-006-18) SHALL change no durability either. | BALANCE §9.3, R-006-18 |
| R-015-23 | WHEN a hit takes a piece's durability to 0 or below, THE piece SHALL break: it leaves its equipment slot and is lost (it goes neither to the inventory nor to the ground), THE robot SHALL emit the fact signal `piece_broken` with the piece's `uid` and slot, and the stats SHALL return to the no-piece values of that slot (R-015-13). The damage left over SHALL not pass to the next piece. | BALANCE §4.1, §9.3, ACTION_PLAN 3.2, README §6 (una pieza a 0 no se queda en el inventario) |
| R-015-53 | WHEN an equipped piece loses durability without breaking, THE `EquipmentComponent` SHALL emit a state signal with the slot and the new durability, and WHILE the equipment view is open, its bar SHALL update without reopening it (the game is not paused); a piece that breaks with the view open SHALL be replaced by its no-piece state on `equipment_changed`. | architecture §7, R-015-32, R-015-35 |
| R-015-54 | WHEN a hit lands on the robot, THE wear of R-015-21 SHALL be applied before the hit's battery damage, so that a hit that empties the battery wears (or breaks) the first piece of the order before the pieces fall (R-015-25), never the Core in their place. | R-006-17, R-008-25 — pregunta 16 |
| R-015-24 | WHEN a piece breaks, THE HUD SHALL show the "Pieza rota" message with the piece's name (ES + EN), through the HUD's temporary message until the notification system of ACTION_PLAN 4.1 exists. | ACTION_PLAN 3.2, 4.1 — pregunta 11 |

### 3.5 Muerte

| ID | Requisito | Fuente |
|---|---|---|
| R-015-25 | WHEN the robot dies in a world whose ruleset drops the inventory (`drops_inventory`), THE equipped arms and legs SHALL fall in the same dropped object as the inventory, with their `uid` and durability; WHILE the ruleset keeps the Core (`keeps_core`, `normal.tres`), THE Core SHALL stay equipped. | PMV §2.4, §10 ("Piezas equipadas al morir"), ACTION_PLAN 1.5, spec 008 (pregunta 4) |
| R-015-26 | WHEN the robot dies, THE pieces in its inventory, a spare Core included, SHALL drop like any other stack. | Spec 011 (pregunta 8), PMV §10 ("Core de repuesto al morir") — pregunta 5 |
| R-015-27 | IF the world's ruleset does not keep the Core, THEN THE equipped Core SHALL fall in the dropped object too. The reaction SHALL be read from the ruleset's fields, never from its id. | PMV §4.5 gancho 4, spec 008 |
| R-015-28 | WHEN the robot respawns after a death, THE robot SHALL have the stats of its remaining equipment (with `normal.tres`: one arm, no legs, its Core). | PMV §2.4, BALANCE §4.2 — pregunta 4 |

### 3.6 Reparación de piezas equipadas

| ID | Requisito | Fuente |
|---|---|---|
| R-015-29 | THE Repair tab of the bench SHALL also list the damaged equipped pieces, marked as equipped, with the cost tier of BALANCE §4.3.2. | Spec 011 (pregunta 6), README §6 |
| R-015-30 | WHEN an equipped piece is repaired, THE piece SHALL stay equipped with the same `uid` and its maximum durability, the materials SHALL be taken from the inventory as for an inventory piece, and THE bench SHALL emit `EventBus.piece_repaired` (which saves the World, spec 011). | Spec 011, BALANCE §4.1, §4.3.2 |

### 3.7 Pantalla de equipo

| ID | Requisito | Fuente |
|---|---|---|
| R-015-31 | THE equipment view SHALL show the three slots (Brazos, Piernas, Core), each with the equipped piece's icon and name, or the no-piece state ("Un brazo", "Sin piernas", "Sin Core") when empty. | ACTION_PLAN 3.1 — pregunta 3 |
| R-015-32 | THE equipment view SHALL show a durability bar under each equipped piece: green above 50 % of its maximum, yellow from 50 % down to just above 25 %, red at 25 % or less (BALANCE §4.1), with the thresholds read from data. | BALANCE §4.1, ACTION_PLAN 3.2 — pregunta 6 |
| R-015-33 | THE equipment view SHALL show the robot's resulting stats (damage, attacks per second, battery per swing, walking and running speed or "no puede correr", walking drain, passive drain, maximum battery) and update them on `stats_changed` while it is open. | ACTION_PLAN 3.1 — pregunta 12 |
| R-015-34 | WHEN the player selects a piece in the inventory, THE screen SHALL offer "Equipar"; WHEN the player selects an equipped slot, it SHALL offer "Quitar"; a refusal SHALL show `tr(error_key)`. | ACTION_PLAN 3.1, architecture §9.2 — pregunta 3 |
| R-015-35 | THE equipment view SHALL go through `UIManager` like the other screens: it blocks the robot's input without pausing the game, closes with back and with a tap outside its panel, and works with touch and mouse inside the 1920×1080 landscape screen. | architecture §9.5, spec 012 (cerrar tocando fuera), ADR 0001 |
| R-015-52 | WHEN the player selects a piece in the inventory screen, THE action card SHALL show its durability as current/maximum (for example "72/100"); the grids SHALL show no durability bars. | Pregunta 13 |
| R-015-36 | THE texts of the equipment view, the no-piece states, the stats and the "Pieza rota" message SHALL go through translation keys, ES + EN. | Constitución P11 |

### 3.8 Guardado y mundo nuevo

| ID | Requisito | Fuente |
|---|---|---|
| R-015-37 | THE `EquipmentComponent` SHALL be a persistent owner (architecture §10.2): it SHALL save, per slot, the piece's item id, durability and `uid`, and nothing derived (stats are never saved). | architecture §10.2, R-010-24 |
| R-015-38 | WHEN a World loads, THE equipment SHALL be applied before the `BatteryComponent` loads its charge, so that a saved charge up to the maximum given by the saved Core is not lowered. | R-014-16 (mismo patrón), architecture §10.2 |
| R-015-39 | WHEN a World loads, THE robot SHALL emit `equipment_changed` and `stats_changed` and SHALL never emit `piece_broken`. | architecture §7, §10.2 |
| R-015-40 | IF a saved equipment slot holds an unknown item id, a non-piece, a piece of another `slot_type` or an invalid durability or `uid`, THEN that slot SHALL load empty with a `push_error()`, and the rest of the World SHALL load. | architecture §10.2, R-011-07 |
| R-015-41 | WHEN a new World starts, THE robot SHALL have the starting equipment of BALANCE §4.2 (basic Core and basic legs equipped, one arm), new pieces at full durability with fresh `uid`s. | BALANCE §4.2 — pregunta 1 |
| R-015-42 | WHEN a World saved before this spec (no equipment part) loads, THE robot SHALL have the starting equipment of R-015-41, without raising `schema_version`; a World whose equipment part has empty slots SHALL load them empty. | architecture §10.2 (campo opcional) — pregunta 10 |

### 3.9 Barra de batería baja

| ID | Requisito | Fuente |
|---|---|---|
| R-015-43 | WHILE the battery charge is below the low threshold (BALANCE §1.1, a fraction of the current maximum), THE HUD battery bar SHALL be orange; WHILE it is at or above the threshold, it SHALL have its normal color. The color SHALL follow `battery_changed` (a state signal), so it is right after a load, a recharge, a portable battery or a change of the maximum, and never depends on `battery_low` alone. | BALANCE §1.1, R-003-11, architecture §7 — pregunta 14 |

### 3.10 Objeto caído como contenedor

Cambia la recogida de la spec 008: sustituye a R-008-13 y R-008-15 y ajusta R-008-14 y R-008-27 (pregunta 15).
Ajusta también R-008-12: el texto del objeto caído pasa de "Recoger" a "Abrir", porque interactuar abre la
pantalla en vez de coger (R-015-45); sigue saliendo solo de claves de traducción en ES y EN.

| ID | Requisito | Fuente |
|---|---|---|
| R-015-45 | WHEN a player interacts with a dropped object (a death, a zombie's material or a thrown item), THE game SHALL open the container screen of spec 013 with the object's contents and the player's inventory, instead of taking the stacks directly; the object's header SHALL show its translated name and its occupancy. Sustituye a R-008-13. | Pregunta 15, spec 013 (R-013-12 a R-013-22) |
| R-015-46 | WHILE the screen of a dropped object is open, THE player SHALL be able to take everything that fits with "Take all", take the stacks they choose, and leave stacks of their own in the object, with the moves and rules of R-013-20 (all or nothing, pieces keep durability and `uid`). | Pregunta 15, R-013-20, R-011-09 |
| R-015-47 | THE dropped object SHALL keep the slot count it was created with: one slot per stack it received (a death: the inventory stacks plus the equipped pieces that fall; a zombie's material or a thrown item: one). A slot emptied by taking a stack SHALL accept a stack from the player. | Pregunta 15 |
| R-015-48 | THE dropped object SHALL have one expiry clock, its drop time (R-008-20): taking or leaving stacks SHALL never change it, and WHEN it expires, everything inside SHALL disappear, the stacks the player left included. Sustituye a R-008-15. | Pregunta 15, BALANCE §7.2, R-008-21, R-008-22 |
| R-015-49 | IF a dropped object expires while its screen is open, THEN THE screen SHALL close and the object SHALL disappear; the stacks already moved to the inventory SHALL stay there. | R-008-24 (la caducidad no depende de una pantalla abierta) — pregunta 15 |
| R-015-50 | WHEN the screen of a dropped object closes and the object holds no stacks, THE object SHALL disappear and go back to its pool; while the screen is open it SHALL stay, also empty. Ajusta R-008-14. | R-008-14, architecture §11 — pregunta 15 |
| R-015-51 | WHEN a player dies with an empty inventory and with equipped pieces that fall (R-015-25), THE game SHALL create the dropped object with those pieces; with nothing to drop, it SHALL create none. Ajusta R-008-27. | R-008-27, R-015-25 |
| R-015-55 | THE saved state of a dropped object SHALL keep its slot count (R-015-47), so that after a load it still has the empty slots where the player can leave stacks; a dropped object saved without it SHALL load with one slot per saved stack, without raising `schema_version`. | R-015-47, R-010-29, architecture §10.2 (campo opcional) |

## 4. Fuera de alcance

- Robot hostil, sus drops y las piezas dañadas al 50 % que suelta: spec 016 (ACTION_PLAN 3.3). Esta spec solo
  garantiza que una pieza recogida se puede equipar.
- Recuerdos, huecos del Core (máximo de huecos como dato de `PieceData`) y fuentes nuevas de XP: spec 017 (ACTION_PLAN
  3.4). Esta spec deja `StatsComponent`, la durabilidad por golpe como stat (R-015-06) y el Core equipado.
- Estado de las piezas en el HUD de juego (arriba a la izquierda, PMV §2.1) y sistema de notificaciones de 3 s: ACTION_PLAN
  4.1. Aquí "Pieza rota" usa el mensaje temporal que ya tiene el HUD (R-015-24).
- SFX de rotura y de equipar: ACTION_PLAN 4.3. Animación de rotura y piezas visibles en el modelo del robot: ACTION_PLAN
  4.4 y arte; el robot sigue siendo un placeholder igual con cualquier equipo.
- Piezas avanzadas, Core Estándar y habilidades activas (Overclock y su desgaste de -2/s): v1.1 (PMV §2.3, SPECS §6,
  §15).
- Defensa del jugador: vale 0 en el PMV (BALANCE §3.1, §9.2); ningún stat de defensa. Un Core con armadura (por
  ejemplo, un Core blindado que absorbe parte del golpe a cambio de menos batería máxima) sería una pieza avanzada
  de v1.1 (BALANCE §4.2, pregunta 2).
- Ideas de v1.1 sobre el desgaste ("Blindaje adaptativo", "Desguace", `docs/ideas/progresion-habilidades.md` §5.2).
- Armas: v1.1 (PMV §2.3, SPECS §18).
- Desgaste por usar la pieza (golpes dados, distancia andada): no existe en BALANCE §4.1; solo los golpes recibidos.
- Resto del HUD de batería (aviso "Batería baja", icono, parpadeo): ACTION_PLAN 4.1. Aquí solo cambia el color de la
  barra (R-015-43).

## 5. Criterio de hecho

- Tests de la lógica pura (ACTION_PLAN 3.1, 3.2): `StatsCalculator` aplica `SET` → `ADD` → `MULTIPLY`; equipar y
  quitar cada pieza básica cambia los stats a los de BALANCE §4.2 y vuelve a los de sin pieza; un golpe desgasta solo
  la primera pieza del orden brazos → piernas → core; la pieza que llega a 0 se rompe, sale de su ranura y emite
  `piece_broken`; el golpe siguiente desgasta la pieza siguiente.
- En el juego (PC y Android): fabricar Brazos y Piernas básicos, equiparlos desde la pantalla y ver que el robot pega
  10 en vez de 5 (el zombie lento muere en 2 golpes en vez de 4) y corre con Shift o con el joystick al fondo.
  Dejarse golpear por zombies y ver bajar la barra de los brazos de verde a amarillo y rojo hasta "Pieza rota" y el
  robot vuelve a pegar con un brazo; después se desgastan las piernas.
- Reparar en el banco una pieza equipada dañada: sigue equipada y con la barra llena.
- Quitarse el Core: la batería máxima no cambia, el consumo pasivo de la pantalla pasa al de "Sin Core" y la batería
  baja el doble de rápido quieto; volver a ponerlo lo devuelve. Con brazos y piernas rotos, los golpes desgastan el
  Core y, si llega a 0, el robot sigue vivo con el consumo de "Sin Core".
- Morir de un golpe con brazos y piernas equipados: el golpe mortal desgasta los brazos, no el Core; brazos y piernas
  caen en el objeto caído con su durabilidad; el robot reaparece en la base con su Core y sin brazos ni piernas. Con
  el inventario lleno al morir, vuelve a la zona a 0.5 m/s, abre el objeto caído, coge las piernas y lo que elija, deja
  algo para hacer sitio y se equipa desde la pantalla de inventario. La recuperación es dura pero posible (pregunta 4).
- Un objeto caído que caduca con su pantalla abierta la cierra y desaparece con lo que quedaba dentro, también lo que
  dejó el jugador; vaciado, desaparece al cerrar la pantalla. Cerrar el juego con un objeto a medio vaciar y volver a
  abrirlo conserva sus ranuras vacías (R-015-55).
- Cerrar y volver a abrir el juego conserva el equipo, la durabilidad de cada pieza y la carga de la batería.
- Al bajar la batería del 20 % de la máxima la barra se pone naranja, y vuelve a su color al recargar o usar una
  batería portátil.
- Ningún literal de BALANCE §4 en scripts (`balance-auditor`); textos en ES + EN (`i18n-auditor`).

## 6. Preguntas abiertas

| # | Pregunta | Propuesta | ¿Bloquea? |
|---|---|---|---|
| 1 | ~~Equipo inicial de un mundo nuevo~~ | **Cerrada (2026-11-24)**, como se proponía: un mundo nuevo empieza con **Core básico y Piernas básicas** equipados (nuevos, al 100 %) y con un brazo; fabricar Brazos básicos es el primer objetivo de crafteo (R-015-41). Anotado en BALANCE §4.2. | — |
| 2 | ~~Robot sin Core~~ | **Cerrada (2026-11-24): opción A2**. El Core es "el corazón del robot": brazos = pelear, piernas = moverse, Core = aguantar y progresar. (1) Fuente de energía: marca la batería máxima; sin Core el robot **drena batería** con el consumo pasivo doble (0.2/s, estimación a ajustar en la prueba del juego), sin reducir la máxima, así que no hay recorte de carga y se reaparece al 100 % (R-015-18, R-015-19, R-015-44). (2) Soporte de los recuerdos (spec 017): se conserva al morir; roto, los recuerdos se apagan sin perderse. (3) Última capa de desgaste: brazos y piernas lo protegen, y como se conserva con su desgaste, repararlo es mantenimiento entre muertes. Se quita y se cambia a mano como cualquier pieza (R-015-10). Descartadas: máxima reducida, Core más resistente, Core indestructible y Core con armadura (pieza avanzada de v1.1). Anotado en BALANCE §1.1 y §4.2 y PMV §2.1 y §10. | — |
| 3 | ~~Dónde y cuándo se equipa~~ | **Cerrada (2026-11-24)**, como se proponía: **panel de equipo dentro de la pantalla de inventario** (botón de almacenamiento / Tab), con las tres ranuras y los stats junto a la rejilla; "Equipar" al seleccionar una pieza (intercambio si la ranura está ocupada) y "Quitar" al seleccionar una ranura (R-015-31 a R-015-35). Se equipa **en cualquier sitio**, también en la zona, sin pausar el juego. Anotado en ACTION_PLAN 3.1. | — |
| 4 | ~~Red de seguridad tras morir sin piernas~~ | **Cerrada (2026-11-24)**: la dificultad es **intencionada**. Perder las piernas al morir obliga a tener repuestos en la base o a arriesgarse a perder el equipo; recuperar a 0.5 m/s es el castigo. Se quita "piezas medio rotas" de PMV §2.4: la red es el brazo y la pierna base, el Core que se conserva y la chatarra garantizada de las cajas. BALANCE §4.2 no cambia; la prueba del criterio de hecho comprueba que la recuperación es dura pero posible. | — |
| 5 | ~~Core de repuesto al morir~~ | **Cerrada (2026-11-24)**, como se proponía: solo se conserva el **Core equipado**; uno de repuesto en el inventario cae como cualquier objeto (R-015-26). Cerrada también en PMV §10. | — |
| 6 | ~~Umbrales de color de la durabilidad~~ | **Cerrada (2026-11-24)**, como se proponía: verde > 50 %, amarillo de 50 % a más de 25 %, rojo **≤ 25 %**, igual que el tramo de reparación "muy dañada" (R-015-32). Anotado en BALANCE §4.1; ACTION_PLAN 3.2 corregido. | — |
| 7 | ~~Bonificación del generador y stats~~ | **Cerrada (2026-11-24)**, como se proponía: la máxima es el stat de batería máxima más la bonificación del generador, que sigue siendo estado de la base (R-015-18). "Batería ampliada" (spec 017) será un modificador `ADD`. El plan decide dónde se suma la bonificación. | — |
| 8 | ~~Guardar al equipar o quitar~~ | **Cerrada (2026-11-24)**, como se proponía: sin momento de guardado nuevo; tampoco al romper una pieza. | — |
| 9 | ~~`piece_broken` en el `EventBus`~~ | **Cerrada (2026-11-24)**, como se proponía: señal local del robot con `uid` y ranura; las Tareas 4.1 o 4.3 la suben al bus si la necesitan. | — |
| 10 | ~~Mundos guardados antes de esta spec~~ | **Cerrada (2026-11-24)**, como se proponía: cargan con el equipo inicial, sin migración ni `schema_version` nueva (R-015-42). | — |
| 11 | ~~Aviso "Pieza rota" antes de la Tarea 4.1~~ | **Cerrada (2026-11-24)**, como se proponía: mensaje temporal del HUD (`show_notice`) con el nombre de la pieza (R-015-24). | — |
| 12 | ~~Qué stats enseña la pantalla~~ | **Cerrada (2026-11-24)**, como se proponía: daño, golpes por segundo, batería por golpe, velocidad andando y corriendo (o "no puede correr"), consumo al andar y batería máxima (R-015-33). **Ampliada con la pregunta 2**: también el consumo pasivo, porque ahora cambia al quitar o romper el Core. | — |
| 13 | ~~Durabilidad de las piezas fuera de la pantalla de equipo~~ | **Cerrada (2026-11-24)**, como se proponía: al seleccionar una pieza en la pantalla de inventario, la ficha muestra su durabilidad ("72/100"); sin barras en las rejillas hasta la Fase 4. | — |
| 14 | ~~Color de la barra de batería baja~~ | **Cerrada (2026-11-24)**, petición del usuario: por debajo del umbral de batería baja (20 % de la máxima, BALANCE §1.1) la barra pasa a **naranja** (R-015-43). Naranja y no amarillo porque el amarillo ya es el tramo medio de la durabilidad (pregunta 6) y la batería baja es más urgente; el rojo queda libre para un posible "crítico" de la Tarea 4.1. Se usa el umbral relativo a la máxima, no 20 puntos fijos: con el generador (máxima 120) el aviso salta en 24, igual que `battery_low`. | — |
| 15 | ~~Recoger un objeto caído~~ | **Cerrada (2026-11-24)**, decisión del usuario tras la revisión: el objeto caído es un **contenedor**, como las cajas y los cofres. Interactuar abre la pantalla de contenedor (spec 013): "Coger todo" se lleva lo que quepa con un toque, o el jugador elige qué pilas coge y cuáles deja, y puede dejar cosas suyas para hacer sitio. El contenedor tiene el temporizador del objeto caído: lo que haya dentro al cumplirse (5 minutos, BALANCE §7.2) desaparece, también lo que dejó el jugador. Vale para todo objeto caído (muerte, material de zombie, objeto tirado). Lo recogido va al inventario y se equipa desde la pantalla de inventario. Motivo: al morir con brazos y piernas el objeto puede tener más pilas que ranuras libres al reaparecer (hasta 7 frente a 5 en los niveles 1-4), y coger en orden dejaba las piezas en el suelo. Descartado: equipar automáticamente al recoger y dar prioridad a las piezas en el orden de recogida. Detalles propuestos en la revisión (R-015-47, R-015-49, R-015-50): el objeto conserva sus ranuras de creación; si caduca con la pantalla abierta, la pantalla se cierra; vacío, desaparece al cerrar la pantalla; sin momento de guardado nuevo (como recoger hasta ahora). | — |
| 16 | ~~Golpe mortal y desgaste~~ | **Cerrada (2026-11-24)**, como se proponía. `Robot.receive_hit` resta la batería y después emite `hit_received`; si el golpe vaciaba la batería, `DeathController` soltaba brazos y piernas antes del desgaste, que solo encontraba el Core. Ahora el golpe desgasta su pieza **antes** de restar la batería (R-015-54, R-015-21): el golpe mortal desgasta los brazos como cualquier otro, y si los rompe, se pierden y no caen. | — |
| 17 | **Recoger el material de un zombie con pantalla** (riesgo, hallado en la revisión final). Con el objeto caído como contenedor (pregunta 15), la chatarra de un zombie, que cae la mitad de las veces (BALANCE §3.1), pasa de un toque a tres: abrir, "Coger todo" y cerrar. En una visita con muchos zombies se repite a menudo. | Mantener lo decidido (vale para todo objeto caído) y medirlo en la prueba del juego del criterio de hecho y en la Tarea 5.1. Si molesta, decidir entonces un atajo, sin cambiarlo en esta spec. | No |
| 18 | **Desgaste por golpe con decimales** (hallado en la revisión final). La durabilidad de un `ItemStack` es un entero, pero el stat de desgaste por golpe es un número con decimales que un modificador `MULTIPLY` (spec 017 o v1.1) puede dejar en, por ejemplo, 3.5. | El desgaste se redondea al entero más cercano y nunca baja de 0 (R-015-21). Con los valores del PMV (5, o 4 con "Chasis reforzado") no hay decimales, así que no cambia nada hoy. | No |
