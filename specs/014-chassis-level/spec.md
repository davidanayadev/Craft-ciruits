# Spec 014 — Nivel de chasis

| Campo | Valor |
|---|---|
| **Estado** | Borrador |
| **Tarea(s) ACTION_PLAN** | 2.7 |
| **Fuentes** | ACTION_PLAN.md Tarea 2.7 (y 1.2, 2.3, 3.4, 4.1, 4.3 para los límites) · PMV.md §2.3, §2.4, §6.1, §6.2, §10 ("Progresión y recuerdos") · BALANCE.md §1.3, §2, §6.1, §6.2, §8.2 · SPECS.md §6, §23 · ONLINE.md (leaderboards) · architecture.md §3, §7, §9.5, §10.2 · ADR 0001 · Constitución P2, P3, P4, P5, P6, P13, P14 · `docs/ideas/progresion-habilidades.md` (razonamiento) |
| **Depende de** | 005 (`InventoryComponent`, `ChassisLevelData`, rejilla de inventario), 007 (`ExperienceComponent`, XP por muerte), 008 (`RulesetData.keeps_xp`, muerte), 010 (contrato `persistent`, señales de estado y de hecho, R-010-24), 012 y 013 (pantalla de contenedor) |
| **Rama** | `feat/014-chassis-level` |

## 1. Objetivo

Que la XP sirva para algo: hoy se acumula sin efecto (R-007-22). Al pasar cada umbral de BALANCE §6.1 el chasis
sube de nivel, hasta el 10, y el inventario del robot gana ranuras en los niveles 5, 6 y 7 (de 5 a 8). Para que esas
ranuras pesen, baja el máximo de pila de los materiales (BALANCE §2): con 99 de chatarra el loot de una visita cabía
siempre en 3 ranuras. Cierra el criterio de la Fase 2 ("La XP sube de nivel el chasis"). Deja la señal `level_up`
como enganche para la notificación (Tarea 4.1), el sonido (Tarea 4.3) y los recuerdos (Tarea 3.4, spec 017), y
resuelve la condición de entrada de la spec 010: al cargar, el nivel se aplica antes de que el inventario lea sus
ranuras.

## 2. Historias

- Como jugador, quiero que matar enemigos me suba de nivel y me dé alguna ranura más, para llevar algo más de botín,
  sin que quepa todo: tengo que elegir qué vuelve a la base y cuántas piezas de repuesto llevo.
- Como jugador, quiero conservar mi nivel al morir y al cerrar el juego, porque la XP no se pierde (PMV §2.4).
- Como desarrollador de las Tareas 4.1 y 4.3, quiero una señal `level_up(new_level)` en el robot, para colgar de
  ella la notificación "Nivel up" y su sonido sin tocar la progresión.
- Como desarrollador de la spec 017 (recuerdos y huecos del Core, Tarea 3.4), quiero que el número de niveles y lo que
  da cada uno salgan de la tabla de datos, para añadir los recuerdos sin cambiar el cálculo del nivel.

## 3. Requisitos (EARS)

### 3.1 Datos y cálculo

| ID | Requisito | Fuente |
|---|---|---|
| R-014-01 | THE XP thresholds and the inventory slots per level SHALL live only in the `ChassisLevelData` resource (`chassis_levels.tres`, BALANCE §6.1: 10 levels); no script SHALL hold a threshold, a slot count or the number of levels as a literal. | ACTION_PLAN 2.7, BALANCE §6.1, Constitución P2, P5 |
| R-014-02 | THE validation of `ChassisLevelData` SHALL also reject a table whose first threshold is not 0, so that every non-negative XP has a level. | BALANCE §6.1 (nivel 1 = 0 XP) |
| R-014-03 | THE chassis level of a total XP SHALL be computed by pure logic in `scripts/systems/`, with no scene dependency, as the highest level whose threshold is less than or equal to that XP (accumulated XP, not XP per level). | ACTION_PLAN 2.7, BALANCE §6.1, Constitución P3 |
| R-014-04 | IF the total XP is above the last threshold, THEN the computed level SHALL be the last level of the table (level 10 with BALANCE §6.1). | ACTION_PLAN 2.7 ("no pasa del nivel 10"), PMV §6.1 |
| R-014-05 | IF the total XP is negative or the table is not valid, THEN the calculation SHALL report it with `push_error()` and return level 1. | Constitución §2 (errores) |

### 3.2 Subida de nivel

| ID | Requisito | Fuente |
|---|---|---|
| R-014-06 | THE chassis level SHALL be per-player state, held by a component of the robot entity and derived from its own XP, never in an autoload. | Constitución P4, PMV §4.5 gancho 7 |
| R-014-07 | WHEN the robot's XP changes and the level computed for the new total is higher than its current level, THE robot SHALL take the new level and emit the fact signal `level_up(new_level: int)` once, with the final level, also when several levels are crossed at once. | ACTION_PLAN 2.7, architecture §7 — pregunta 2 |
| R-014-08 | WHEN the robot's level goes up, THE robot's `InventoryComponent` SHALL take the slot count of the new level, keeping every stack in its slot (item, quantity, durability and `uid`); a level whose slot count equals the previous one SHALL leave the inventory unchanged. | ACTION_PLAN 2.7, BALANCE §6.1, R-011-09 |
| R-014-09 | WHEN the robot's XP changes without reaching the next threshold, THE robot SHALL keep its level and its slot count and SHALL not emit `level_up`. | ACTION_PLAN 2.7 |
| R-014-10 | WHEN the robot's level changes, for any reason (also on load), THE robot SHALL emit the state signal `level_changed(level: int)`. | architecture §7, §10.2 — pregunta 7 |
| R-014-11 | IF the robot's XP goes down, THEN THE robot SHALL keep its level and its slot count and report it with `push_error()`. | PMV §2.4 — pregunta 6 |
| R-014-12 | WHEN the robot dies in a world whose ruleset keeps the XP (`normal.tres`), THE robot SHALL respawn with the same level and the same slot count, with the inventory empty because it dropped. | PMV §2.4, spec 008 |
| R-014-13 | WHILE the inventory screen or the container screen is open, WHEN the robot's slot count grows, THE screen SHALL show the new slots and the new occupancy total ("n/total") without being reopened. | Spec 005 (R-005-25), spec 013 |
| R-014-14 | THE inventory screen and the container screen SHALL show every slot of the last level of the table (8, BALANCE §6.1) inside the 1920×1080 landscape screen, every slot reachable by touch and by mouse. | BALANCE §6.1, ADR 0001 (pantalla apaisada 1920×1080) — pregunta 8 |

### 3.3 Máximo de pila de los materiales

| ID | Requisito | Fuente |
|---|---|---|
| R-014-21 | THE `stack_max` of scrap, cables and iron SHALL be the values of BALANCE §2 (20, 10 and 10), set only in their item resources; the portable battery keeps its value (5). | BALANCE §2, PMV §10 ("Máximo de pila de los materiales"), ACTION_PLAN 2.7, Constitución P2 |
| R-014-22 | THE recipes and repair costs of BALANCE §4.3 and §5 SHALL each fit within one stack of every material they use, checked by a test over the catalog. | BALANCE §2 (nota: toda receta cabe en un stack) |

### 3.4 Guardado

| ID | Requisito | Fuente |
|---|---|---|
| R-014-15 | THE World SHALL keep saving only the robot's total XP: the level and the slot count SHALL not be saved and SHALL be recomputed from the XP on load, with no change to `schema_version`. | R-010-24, architecture §10.2 — pregunta 1 |
| R-014-16 | WHEN a World loads, THE robot SHALL size its inventory to the slot count of the loaded XP's level before the inventory loads its saved slots, so that no saved stack beyond the level-1 slots is lost. | Spec 010 (plan §7, condición de entrada), README §6 |
| R-014-17 | WHEN a World loads, THE robot SHALL emit `xp_changed` and `level_changed` and SHALL never emit `level_up`. | R-010-09, plan 010 D15, architecture §10.2 |
| R-014-18 | WHEN a new World starts, THE robot SHALL be at level 1 with the level-1 slot count. | BALANCE §6.1, R-005-02 |

### 3.5 Depuración

| ID | Requisito | Fuente |
|---|---|---|
| R-014-19 | THE debug HUD (debug builds only) SHALL show the robot's chassis level next to its XP and follow `level_changed`, until the game HUD shows them (Tarea 4.1). | R-007-22, ACTION_PLAN 4.1 |
| R-014-20 | WHERE the build is a debug build, THE debug HUD SHALL offer a button that adds to the robot the XP missing to reach the next level's threshold, read from the table, and does nothing at the last level. | Constitución P13 (verificación manual) — pregunta 9 |

Los valores numéricos se citan por su fuente (`BALANCE.md §2`, `§6.1`); el spec no los fija.

## 4. Fuera de alcance

- Notificación "Nivel up" y barra o número de XP y nivel en el HUD de juego: ACTION_PLAN 4.1. SFX de subida de
  nivel: ACTION_PLAN 4.3. Esta spec solo deja la señal `level_up` (R-014-07) para engancharlos.
- Recuerdos, huecos del Core y lo que da cada nivel además de ranuras: spec 017 (ACTION_PLAN 3.4). Esta spec solo
  calcula el nivel y aplica las ranuras.
- Fuentes nuevas de XP (craftear, reparar, vaciar un sitio de cajas) y revisión de la curva de los niveles 6-10:
  ACTION_PLAN 3.4. Los umbrales 6-10 de BALANCE §6.1 son provisionales; esta spec los lee de la tabla, así que
  cambiarlos no toca código.
- Habilidades activas (vienen de las piezas): v1.1 (SPECS §6).
- Límite de nivel de chasis de la demo (SPECS §23): v1.1. En el PMV la demo es todo el contenido.
- Leaderboards con el nivel de chasis (ONLINE.md): PMV §2.3.
- Perder XP o nivel (Hardcore, Respaldo de consciencia): v1.1 (SPECS §27, PMV §2.3). Ningún ruleset del PMV
  reinicia la XP (R-014-11).
- Efecto del nivel en estadísticas o piezas: los recuerdos (spec 017) y las piezas (spec 015).

## 5. Criterio de hecho

- Tests de la lógica pura con la tabla de BALANCE §6.1 (ACTION_PLAN 2.7): con 499 XP nivel 4 y 5 ranuras; con 500
  XP nivel 5 y 6 ranuras; con 1000 XP nivel 7 y 8 ranuras; con 2000 XP nivel 10 y 8 ranuras; con XP de sobra no
  pasa del nivel 10.
- Tests del catálogo: chatarra, cables y hierro apilan 20, 10 y 10 (BALANCE §2), y cada receta y reparación cabe en
  una pila (R-014-22).
- En el juego (PC y Android): al matar zombies hasta pasar 50 XP, el debug HUD muestra el nivel 2 y el inventario
  sigue con 5 ranuras. Con el botón de depuración se llega al nivel 5 y el inventario tiene 6 ranuras con lo que ya
  llevaba en su sitio; al nivel 10, 8 ranuras, que se ven y se tocan en la pantalla de inventario y en la de
  contenedor. Una visita a la zona verde llena varias pilas de chatarra de 20.
- Al morir se conserva el nivel y el número de ranuras; al cerrar y volver a abrir el juego, también, y las pilas
  guardadas en las ranuras de más siguen ahí. Cargar no emite `level_up`.

## 6. Preguntas abiertas

| # | Pregunta | Propuesta | ¿Bloquea? |
|---|---|---|---|
| 1 | ACTION_PLAN 2.7 dice "el nivel y la XP se guardan", pero R-010-24 prohíbe guardar valores derivados de datos. | Guardar solo la XP; el nivel y las ranuras se recalculan al cargar (R-014-15). Así un cambio de umbrales en BALANCE se aplica a los mundos existentes y no sube `schema_version`. Corregir el texto de ACTION_PLAN 2.7 al aprobar. | No |
| 2 | Si una ganancia de XP cruza varios umbrales, ¿una señal `level_up` con el nivel final o una por nivel? | Una con el nivel final (R-014-07): una notificación y un sonido. Matando no ocurre (la mayor recompensa es 10 XP, BALANCE §6.2, y los umbrales distan 50 o más); puede ocurrir con el botón de depuración o si las fuentes nuevas de la Tarea 3.4 dan mucha XP de golpe. | No |
| 3 | ¿`level_up` va también al `EventBus` (guía, audio, notificaciones son sistemas ajenos)? | No en esta spec: señal local del robot. La spec de la Tarea 4.1, 4.3 o la 017 añade el evento del bus si lo necesita (architecture §7: el evento lo añade el plan de la spec que lo crea), con `player_uid`. | No |
| 4 | ¿Subir de nivel guarda la partida? | No: la XP se guarda en el siguiente guardado, como hoy (entrar en la base, morir, cerrar, ir a segundo plano…). El nivel sale de la XP, así que no hay nada nuevo que guardar. | No |
| 5 | ¿El jugador ve algún aviso al subir en esta spec? | No: solo crecen las ranuras del inventario en los niveles 5-7 (y el debug HUD). La notificación es de la Tarea 4.1, como dice la propia Tarea 2.7. | No |
| 6 | ¿Qué pasa con el nivel si la XP baja? Solo puede bajar con `ExperienceComponent.reset()`, que usa un ruleset que no conserva la XP, y no hay ninguno en el PMV (Hardcore termina el mundo). `InventoryComponent` no admite encoger. | El nivel nunca baja en esta spec: si la XP baja, nivel y ranuras se quedan y se informa con `push_error()` (R-014-11). La spec que cree ese ruleset decide la regla. | No |
| 7 | architecture §10.2 pone de ejemplo que al cargar el nivel se emiten `xp_changed` y `stats_changed`, pero el nivel no cambia estadísticas en el PMV. | Señal de estado propia `level_changed(level)` (R-014-10) y el plan corrige el ejemplo de architecture §10.2. `stats_changed` sigue siendo de `StatsComponent` (spec 015). | No |
| 8 | ¿Caben las ranuras en las pantallas? La rejilla tiene 5 columnas de celdas de 104 px y la pantalla de contenedor pone al lado la rejilla del contenedor y una ficha de acción fija. | Con 8 ranuras (nivel máximo) son 2 filas de 5, sin desplazamiento (R-014-14), verificado a mano en PC y Android. Antes la duda era con 20 (4 filas); con 8 sobra sitio. | No |
| 9 | Verificar a mano los niveles 5-10 exige cientos de muertes (2000 XP a 2-3 XP por zombie). | Botón de depuración "Subir nivel" en el debug HUD (R-014-20), como "Fill base" en la spec 009: añade la XP que falta hasta el siguiente umbral leído de la tabla, sin literales. No se ve en builds de release. | No |
| 10 | Al bajar el máximo de pila (R-014-21), un guardado con una pila por encima del máximo nuevo (por ejemplo 60 de chatarra) deja de ser válido: en el inventario esa ranura se descarta al cargar (`InventoryComponent`, test `test_r_010_11_quantity_above_stack_max_leaves_slot_empty`). Los cofres usan `InventoryComponent`; los objetos caídos, a comprobar en el plan. | Sin migración: el PMV no está publicado y solo hay guardados de desarrollo. Se acepta perder esas pilas, sin subir `schema_version`. | No |
| 11 | Las ranuras de los niveles 1-4 bajan de 5/7/10/15 a 5/5/5/5. ¿Algún guardado o test depende de más de 5 ranuras? | No hay guardados con nivel (la XP no sube de nivel hasta esta spec), así que todo mundo guardado tiene 5. Los tests que llenan el inventario leen `get_slot_count()` y `stack_max` del catálogo, no literales; el plan lo comprueba. | No |
