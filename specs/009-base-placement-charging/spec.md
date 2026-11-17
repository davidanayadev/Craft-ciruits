# Spec 009 — Escena de base, viaje entre zonas, colocación libre y estación de carga

| Campo | Valor |
|---|---|
| **Estado** | Aprobado (2026-11-17) |
| **Tarea(s) ACTION_PLAN** | 2.1, 2.8, 2.2 |
| **Fuentes** | ACTION_PLAN.md Tareas 2.1, 2.8, 2.2 (y 1.5, 2.3, 2.4, 2.5, 2.6, 4.1, 4.3, 4.4 para los límites) · PMV.md §2.1, §2.3, §2.4, §3.2, §4.5 ganchos 2 y 7, §10 (estación de carga crafteable; cajas y viaje; muerte) · BALANCE.md §1.1, §1.2, §5.1, §5.3, §5.6, §7, §7.2, §11 · SPECS.md §32 (base libre, v1.1) · architecture.md §3, §5, §6, §7, §8, §9.1, §9.2, §9.5, §10.2, §10.3, §12, §14 · Constitución P2, P3, P4, P6, P8, P9, P11, P12, P13, P14 |
| **Depende de** | 003 (`BatteryComponent`), 004 (`FarmZone`, `ZoneData`, `InteractableComponent`), 005 (`UIManager`, `InventoryComponent`), 006 (`ZombieSpawner`, `ObjectPool`), 008 (contador de visitas, repoblación, objeto caído, reaparición, `RulesetData`; debe estar *Hecho* antes de implementar esta) |
| **Rama** | `feat/009-base-placement-charging` |

## 1. Objetivo

Dar al jugador un sitio al que volver. Hoy el juego empieza y termina en la zona verde; con esta spec existe la
base (zona segura, `zone_id` de architecture §14), se viaja entre base y zona por puntos de salida físicos, la
batería se recarga solo en estaciones de carga que el jugador construye y coloca donde quiere dentro de la
cuadrícula de la base, y morir te devuelve a la base. Cierra el bucle de la Fase 1 ("base → zona verde → …
→ volver a base") y deja la colocación lista para el generador y los cofres (spec 012).

## 2. Historias

- Como jugador, quiero una base segura a la que volver, para decidir cuándo arriesgarme otra vez.
- Como jugador, quiero salir y entrar por un punto físico, para que irse de la zona sea una decisión con
  recorrido y no un botón.
- Como jugador, quiero construir mi primera estación de carga y recargar en ella, para que la batería deje de
  ser una cuenta atrás sin salida.
- Como jugador, quiero elegir dónde va cada estructura y moverla después, para ordenar la base a mi gusto.
- Como jugador, quiero ver antes de confirmar si la estructura cabe, para no gastar materiales en vano.
- Como desarrollador del generador y los cofres (spec 012), quiero la cuadrícula y el modo colocación como
  piezas reutilizables, para añadir una estructura como dato y no como código nuevo.
- Como desarrollador del guardado (spec 010), quiero las estructuras como estado del mundo en tipos simples,
  para guardarlas sin cambiarlas.

## 3. Requisitos (EARS)

### 3.1 Zonas como datos y `ZoneLoader`

| ID | Requisito | Fuente |
|---|---|---|
| R-009-01 | THE `ZoneData` resource SHALL gain the scene of the zone and its kind (`BASE` or `FARM`), and THE `DataCatalog` SHALL list the green zone and the base, the base with the `zone_id` of architecture §14. | architecture §6, §8, §14 |
| R-009-02 | THE game SHALL have a `ZoneLoader` node under `Main` with `travel_to(zone_id)`, which keeps exactly one zone loaded in `ZoneSlot` at a time. | architecture §6 |
| R-009-03 | WHEN `travel_to` ends, THE travelling robot SHALL stand on the arrival point of the new zone and THE game SHALL emit `EventBus.zone_changed(zone_id)` exactly once. | architecture §6, §7 |
| R-009-04 | WHEN a zone is unloaded, THE `ZoneLoader` SHALL first return its pooled entities (enemies, dropped objects, effects) to their pools, so none is freed with the zone. | Spec 006 (`despawn_enemies`), architecture §11 |
| R-009-05 | THE battery, inventory and XP of the robot SHALL not change because of a travel. | architecture §6 (verificación), BALANCE §1.2 |
| R-009-06 | IF `travel_to` receives a `zone_id` that is not in the catalog, or is called while another travel is in progress, THEN THE `ZoneLoader` SHALL report the error and leave the current zone untouched. | Constitución §2 (errores) |
| R-009-07 | WHILE a travel is in progress, THE game SHALL show a loading screen with texts only from translation keys in ES and EN, and THE robot SHALL not move, attack, interact, drain battery or take hits. | architecture §6, Constitución P11 — pregunta 9 |
| R-009-08 | WHEN a new game starts, THE robot SHALL appear at the spawn point of the base; `Main` SHALL no longer place the green zone in `ZoneSlot` itself (replaces R-004-05). | ACTION_PLAN Fase 1 (criterio), 2.1 — pregunta 10 |
| R-009-09 | THE current zone SHALL be held by `GameManager` as global state and set only by `ZoneLoader`. | architecture §5 |

### 3.2 Puntos de salida y viaje

| ID | Requisito | Fuente |
|---|---|---|
| R-009-10 | THE base and the green zone SHALL each have one exit point: an `InteractableComponent` whose prompt comes from the translation key `PROMPT_TRAVEL` in ES and EN. | ACTION_PLAN 2.1, PMV §10 (viaje), BALANCE §1.2 |
| R-009-11 | WHEN a player interacts with an exit point, THE game SHALL travel to the destination zone of that exit point, with no battery cost and no limit of uses. | BALANCE §1.2, PMV §10 — pregunta 9 |
| R-009-12 | THE destination of an exit point SHALL be data of the exit point (a `zone_id`), not a script literal. | Constitución P2, SPECS §26 |
| R-009-13 | THE travel SHALL be started only through an exit point or by the death reaction (§3.9); no HUD button SHALL start it from anywhere. | PMV §10 (viaje) |

### 3.3 Visitas y estado del mundo al viajar

| ID | Requisito | Fuente |
|---|---|---|
| R-009-14 | WHEN a player leaves a `FARM` zone through its exit point, THE visit counter of that zone SHALL go up by exactly one. | BALANCE §7.2, Spec 008 §4 |
| R-009-15 | THE visit counter SHALL not go up on entering a zone. | BALANCE §7.2 |
| R-009-16 | WHEN a `FARM` zone is loaded, THE zone SHALL be populated with the boxes and enemies of its current visit number, through the same rules as the repopulation of spec 008. | BALANCE §7.2, Spec 008 R-008-08, R-008-09 |
| R-009-17 | THE dropped objects of a zone SHALL survive its unloading as world state and SHALL be back in place when the zone is loaded again, after discarding the expired ones (R-008-23). | Spec 008 R-008-16, BALANCE §7.2 |
| R-009-18 | WHILE the base is loaded, THE game SHALL spawn no enemies, and the base SHALL need no navigation mesh for them. | PMV §2.1 (safe zone), ACTION_PLAN 2.8 |

### 3.4 Escena de la base

| ID | Requisito | Fuente |
|---|---|---|
| R-009-19 | THE base scene SHALL have floor, boundaries the robot cannot cross, a spawn point, an exit point, the repair bench at a fixed position and a buildable area that starts empty. | ACTION_PLAN 2.1, PMV §2.1, §10 |
| R-009-20 | THE repair bench SHALL be part of the base scene, not a placed structure: it SHALL not be movable in edit mode. | PMV §10 (banco fijo) |
| R-009-21 | WHILE the robot is in the base, THE battery SHALL drain by the same rules as in a farm zone, and entering the base SHALL not recharge it. | BALANCE §1.1, §5.3, PMV §2.1 |
| R-009-22 | THE base scene SHALL stay inside the budget of PMV §3.2 (triangles, dynamic lights, one shadowed directional light) and keep ≥ 30 FPS on the mid-range Android device with the buildable area full. | PMV §3.2, Constitución P12 — pregunta 11 |

### 3.5 Cuadrícula de la base (lógica pura)

| ID | Requisito | Fuente |
|---|---|---|
| R-009-23 | THE cell size, the limits of the buildable area and the reserved cells of the base SHALL come from a data resource with the values of BALANCE §5.6, not from script literals. | ACTION_PLAN 2.8, BALANCE §5.6, Constitución P2 — preguntas 3 y 7 |
| R-009-24 | THE game SHALL define a `StructureData` resource (stable id, scene, footprint in cells) listed in the `DataCatalog`, with the charging station as its first instance and the footprint of BALANCE §5.6; structures SHALL not rotate. | Constitución P5, architecture §8, BALANCE §5.6 — pregunta 4 |
| R-009-25 | THE occupancy rules SHALL be pure code: a placement is valid only when every cell of the footprint is inside the limits, not reserved, not occupied by another structure and not among the blocked cells passed by the caller (the cells where a robot stands). | ACTION_PLAN 2.8, Constitución P3 — pregunta 7 |
| R-009-26 | WHEN a structure is moved, THE grid SHALL free its previous cells and occupy the new ones; an invalid move SHALL leave the structure where it was. | ACTION_PLAN 2.8 |
| R-009-27 | THE grid SHALL answer whether a given `StructureData` still fits anywhere in the buildable area. | ACTION_PLAN 2.8, PMV §10 (base llena) |
| R-009-28 | THE conversion between a cell and its local position in the base SHALL be pure code and exact in both directions for every cell of the area. | PMV §4.5 gancho 2 |
| R-009-29 | Every placed structure SHALL have a `uid` (architecture §10.3) and its position recorded as `(zone_id, cell)`. | ACTION_PLAN 2.8, PMV §4.5 gancho 2 |
| R-009-30 | THE placed structures SHALL be world state outside any player entity: they SHALL survive the unloading of the base and be back on their cells when it is loaded again. | architecture §5, §6, PMV §4.5 gancho 7 |
| R-009-31 | THE state of the placed structures SHALL be expressible with JSON types only (ids, `uid`, cell), and an in-memory round trip SHALL restore the same structures on the same cells, so spec 010 can save it without changing it. | architecture §10.2, ACTION_PLAN 2.8 (test) — pregunta 2 |
| R-009-32 | THE operations that place and move a structure SHALL receive the requesting player and the cell by parameter and return an `ActionResult`; presentation SHALL only request them. | architecture §3 reglas 2-4, §9.2, §12 |

### 3.6 Modo colocación

| ID | Requisito | Fuente |
|---|---|---|
| R-009-33 | WHEN the player picks a structure in the build screen of the bench (§3.11), THE game SHALL enter placement mode with a preview of the structure snapped to a cell of the grid. | ACTION_PLAN 2.8, 2.2 — preguntas 1 y 5 |
| R-009-34 | WHILE in placement mode, THE preview SHALL be green where the placement is valid and red where it is not. | ACTION_PLAN 2.8 |
| R-009-35 | WHEN the player confirms on a valid cell, THE game SHALL place the structure there, charge its cost and emit `EventBus.structure_built(structure_uid)` once. | ACTION_PLAN 2.8, architecture §7 — pregunta 1 |
| R-009-36 | IF the player confirms on an invalid cell, THEN THE game SHALL place nothing, charge nothing and stay in placement mode. | ACTION_PLAN 2.8 |
| R-009-37 | WHEN the player cancels placement mode, THE game SHALL place nothing and charge nothing. | ACTION_PLAN 2.8, PMV §10 (base llena) — pregunta 1 |
| R-009-38 | IF the structure no longer fits anywhere in the buildable area, THEN THE build option SHALL be disabled with a translated notice, before any material is spent. | ACTION_PLAN 2.8, PMV §10 (base llena) |
| R-009-39 | IF the player lacks the materials of BALANCE §5.3, THEN THE build option for the charging station SHALL be disabled and nothing SHALL change. | ACTION_PLAN 2.2 (test), BALANCE §5.1, §5.3 — pregunta 1 |
| R-009-40 | THE placement mode SHALL work with touch and with mouse and keyboard through InputMap actions or the input abstraction, and every text of its controls SHALL come from translation keys in ES and EN. | ACTION_PLAN 2.8, Constitución P8, P11 — pregunta 5 |
| R-009-41 | THE placement mode SHALL be available only while the base is the loaded zone. | BALANCE §5.3 (ubicación), ACTION_PLAN 2.2 |
| R-009-42 | THE number of charging stations SHALL have no limit other than the space of the buildable area. | BALANCE §5.3 |
| R-009-55 | WHEN the player taps or clicks a cell of the buildable area in placement mode, THE preview SHALL move to that cell. | PMV §10 (spec 009) — pregunta 5 |
| R-009-56 | THE placement mode SHALL show "Confirm" and "Cancel" buttons; on PC the accept and cancel actions SHALL do the same, and the Android back button SHALL cancel. | PMV §10 (spec 009), architecture §9.5 — pregunta 5 |
| R-009-57 | WHILE a structure is being placed or moved, THE robot SHALL not move, attack or interact, and its battery SHALL keep draining by the usual rules. | PMV §10 (spec 009), BALANCE §1.1 — pregunta 5 |
| R-009-58 | WHILE a structure is being placed or moved, THE cells where a robot stands SHALL count as invalid. | PMV §10 (spec 009) — pregunta 7 |

### 3.7 Modo edición

| ID | Requisito | Fuente |
|---|---|---|
| R-009-43 | WHILE in the base, THE player SHALL be able to enter an edit mode, pick an already placed structure and move it with the same preview, validity colours, confirm and cancel as placement mode, at no cost (BALANCE §5.6). | ACTION_PLAN 2.8, PMV §2.1, BALANCE §5.6 — pregunta 6 |
| R-009-59 | THE HUD SHALL show an "Edit base" button only while the base is the loaded zone, with its text from translation keys in ES and EN; pressing it SHALL enter edit mode and pressing it again SHALL leave it. | PMV §10 (spec 009), Constitución P11 — pregunta 6 |
| R-009-60 | WHEN the player taps or clicks a placed structure in edit mode, THE game SHALL pick it up for moving; the repair bench and the exit point SHALL not be pickable. | PMV §10 (spec 009) — pregunta 6 |
| R-009-44 | WHEN the player cancels a move, THE structure SHALL stay on its original cells with its state and `uid` unchanged. | ACTION_PLAN 2.8 |
| R-009-45 | WHILE a structure is being moved, THE validity check SHALL ignore the cells that the structure itself occupies. | ACTION_PLAN 2.8 |

### 3.8 Estación de carga

| ID | Requisito | Fuente |
|---|---|---|
| R-009-46 | THE charging station SHALL be a placeable structure with an `InteractableComponent` whose prompt comes from the translation key `PROMPT_RECHARGE` in ES and EN. | ACTION_PLAN 2.2, architecture §9.1 |
| R-009-47 | WHEN a player interacts with a charging station, THE battery of that player SHALL go to 100 % of its maximum at once, with no cost per use (BALANCE §5.3). | ACTION_PLAN 2.2, BALANCE §1.1, §5.3 |
| R-009-48 | THE recharge SHALL be a method of `BatteryComponent` that emits its usual change signals; the station SHALL not write the battery's fields. | architecture §3 regla 3 |
| R-009-49 | WHEN a player recharges at a station, THE game SHALL signal the fact so that spec 010 can save the game and show "Partida guardada"; in this spec nothing is written to disk. | ACTION_PLAN 2.2, 2.3 — pregunta 2 |
| R-009-50 | WHILE a structure is being placed or moved, THE charging stations SHALL not be interactable. | Constitución §2 (errores) |

### 3.9 Muerte con base

| ID | Requisito | Fuente |
|---|---|---|
| R-009-51 | WHEN the transfer screen of spec 008 ends, THE robot SHALL reappear at the spawn point of the base through `ZoneLoader.travel_to`, with the battery of BALANCE §1.1 (replaces the provisional respawn point of R-008-31). | ACTION_PLAN 1.5, PMV §2.4, Spec 008 pregunta 1 |
| R-009-52 | WHEN a player dies inside the base, THE game SHALL apply the same rules as in a zone: the dropped object stays in the base and the robot reappears at the base spawn point. | PMV §2.4, §10 (morir dentro de la base) — pregunta 12 |
| R-009-53 | IF the player dies while placing or moving a structure, THEN THE game SHALL cancel the mode as in R-009-37 or R-009-44 before the death reaction. | Spec 008 R-008-29 |

### 3.10 Bucle completo

| ID | Requisito | Fuente |
|---|---|---|
| R-009-54 | THE player SHALL be able to start in the base, travel to the green zone, collect scrap, come back, build and place a charging station, recharge at it, move it, travel again and find the station on its cell on returning. | ACTION_PLAN Fase 1 y Fase 2 (criterios) |

### 3.11 Construcción desde el banco (mínimo adelantado de la Tarea 2.4)

| ID | Requisito | Fuente |
|---|---|---|
| R-009-61 | THE game SHALL define a `RecipeData` resource with a stable id, ingredients, result, `station`, `tier` and `requires`, listed in the `DataCatalog`, with one `.tres`: the charging station, at the cost of BALANCE §5.3, `WORKBENCH`, tier 1, no requirements. | ACTION_PLAN 2.4, 2.2, PMV §4.5 gancho 5, BALANCE §5.3 — pregunta 1 |
| R-009-62 | THE check that an inventory holds the ingredients of a recipe SHALL be pure code in `CraftingSystem` over the slots of that inventory and the recipe, and THE removal of those ingredients SHALL be done by the owner of the inventory (`InventoryComponent`) through an all-or-nothing pure rule of `InventoryRules`, returning an `ActionResult`; a failed payment SHALL change nothing. | ACTION_PLAN 2.4, architecture §3 regla 4, §9.2 — pregunta 1 |
| R-009-63 | THE repair bench SHALL be interactable through `InteractableComponent`, with its prompt from a translation key in ES and EN. | ACTION_PLAN 2.4, architecture §9.1 |
| R-009-64 | WHEN the local player interacts with the repair bench, THE game SHALL open through `UIManager` a build screen that lists the structure recipes with their name and cost, with texts only from translation keys in ES and EN. | ACTION_PLAN 2.2, architecture §9.5 — pregunta 1 |
| R-009-65 | WHEN the player picks an enabled recipe in the build screen, THE screen SHALL close and placement mode SHALL start for its structure, without spending anything yet (the cost is charged in R-009-35). | PMV §10 (spec 009) — pregunta 1 |

Los valores numéricos (coste de la estación, recarga, batería al reaparecer, celda, límites y huella de la
cuadrícula) se citan por su fuente; el spec no los fija.

## 4. Fuera de alcance

- Escribir en disco: `SaveManager`, Perfil y Mundo, autoguardado al entrar en la base y al recargar, mensaje
  "Partida guardada", guardar estructuras y contador de visitas: spec 010 (ACTION_PLAN 2.3). Aquí todo vive en
  memoria y se pierde al cerrar el juego (pregunta 2).
- Crafteo de piezas, reparación, UI completa del banco y el resto de recetas: spec 011 (ACTION_PLAN 2.4). Aquí
  solo entra lo de §3.11: `RecipeData` con la receta de la estación, el cobro y una pantalla de una entrada.
- Generador eólico y cofres (con su límite de 5): spec 012 (ACTION_PLAN 2.5, 2.6). Reutilizan `StructureData`,
  la cuadrícula y el modo colocación de esta spec.
- Desmontar o recuperar materiales de una estructura: no está en ningún documento (pregunta 8).
- Base en cualquier sitio del mundo, banco crafteable a mano, muros y enemigos dentro de la base: v1.1
  (PMV §2.3, SPECS §32).
- Coste de batería del viaje, mapa global, más zonas y viaje a pie: v1.1 (BALANCE §1.2, SPECS §26).
- Pantalla de carga pulida, animación de viaje y animación de carga de la estación: ACTION_PLAN 4.4. SFX de
  viaje, construcción y recarga: ACTION_PLAN 4.3. Música por zona: 4.3 (escucha `zone_changed`).
- Minimapa y marcadores de la base: ACTION_PLAN 4.1.
- Pasos de la guía "vuelve a la base" y "craftea tu primera estación": ACTION_PLAN 5.4.
- Quién puede construir o mover en la base de otro jugador en cooperativo: ONLINE.md (v2.0). Aquí las
  operaciones ya reciben el jugador por parámetro (R-009-32).

## 5. Criterio de hecho

Al arrancar, el robot aparece en la base: suelo, límites, el banco de reparaciones fijo, un punto de salida y un
área edificable vacía; no hay enemigos y la batería baja igual que fuera. En el punto de salida aparece el
prompt de viajar; al interactuar se ve la pantalla de carga y el robot aparece en la zona verde con la misma
batería, inventario y XP. Tras abrir cajas y volver por el punto de salida de la zona, entrar en la base no
recarga. Interactuar con el banco abre la pantalla de construcción con la estación de carga y su coste; con 4 de
chatarra (BALANCE §5.3) se puede elegir: la pantalla se cierra y aparece la vista previa sobre la cuadrícula,
que va a la celda que se toca, verde donde cabe y roja fuera de los límites, sobre celdas reservadas, sobre otra
estructura o sobre el robot; cancelar no gasta nada y confirmar la coloca y resta la chatarra. Mientras tanto el
robot no se mueve y la batería sigue bajando. Sin chatarra suficiente, o con la
cuadrícula llena, la opción está desactivada con su aviso. Interactuar con la estación deja la batería al 100 %.
Con el botón "Editar base", que solo se ve en la base, se puede coger la estación y moverla a otra celda libre; cancelar la deja donde estaba. Al
volver a la zona verde, las cajas y los zombies son los de la visita siguiente; al regresar a la base, la
estación sigue en su celda. Morir en la zona o en la base lleva, tras la transferencia, al punto de aparición de
la base con la batería al 100 % (BALANCE §1.1); lo soltado queda donde se murió.

Tests en verde: cuadrícula (ocupación, límites, celdas reservadas, mover libera las celdas anteriores, mover
sobre sí misma, "cabe en algún sitio", conversión celda ↔ posición), ida y vuelta en memoria del estado de las
estructuras, `ZoneData`, `StructureData` y `RecipeData` en el catálogo, `CraftingSystem` (materiales justos, de
sobra, insuficientes; un pago fallido no cambia nada), `ZoneLoader` (una sola zona cargada, `zone_changed`
una vez, id desconocido, viaje en curso, entidades devueltas a sus pools), integración base → zona → base sin
cambios en batería, inventario ni XP (architecture §6), contador de visitas (sube al salir por el punto de
salida, no al entrar), objetos caídos que sobreviven a la descarga de su zona, recarga al 100 % por el método de
`BatteryComponent`, construir sin materiales o sin sitio no cambia nada, cancelar no gasta, `structure_built`
una vez, reaparición en la base tras morir en la zona y en la base, e integración "el jugador puede moverse por
la base" (ACTION_PLAN 2.1). Probado en PC y en el Android de gama media (toca UI, input y rendimiento).

## 6. Preguntas abiertas

| # | Pregunta | Propuesta | ¿Bloquea? |
|---|---|---|---|
| 1 | **Cómo se construye la estación sin la spec 011.** ACTION_PLAN 2.2 dice "depende de la Tarea 2.4 para la receta" y que se construye desde el banco, pero el índice pone la 009 antes que la 011 (banco, `RecipeData`, `CraftingSystem`). Sin una forma de construir, la colocación no se puede probar jugando. | **A (recomendada)**: la 009 adelanta lo mínimo: `RecipeData` con los campos de ACTION_PLAN 2.4 y una sola receta (estación, BALANCE §5.3), la comprobación y el cobro de materiales como lógica pura en `CraftingSystem`, y el banco con una pantalla de construcción de una sola entrada. La 011 añade piezas, reparación y la UI completa sobre eso. **B**: la 009 solo trae base, viaje, cuadrícula y la estación colocable desde el HUD de depuración, sin coste; construir pagando llega con la 011. **C**: reordenar: hacer la 011 antes y dejar la Tarea 2.2 para después. Los materiales se cobran al confirmar la colocación, no al pulsar "Construir" (R-009-35, R-009-37). **Cerrada (nov 2026): opción A** (§3.11; PMV §10, ACTION_PLAN 2.2 y 2.4 actualizados). | — |
| 2 | **Guardado sin la spec 010.** ACTION_PLAN 2.2 pide guardar al interactuar con la estación y al entrar en la base, y mostrar "Partida guardada"; `SaveManager` no existe hasta la 010. | La 009 no escribe nada en disco. Deja los hechos que la 010 necesita (`zone_changed` al entrar en la base y un aviso al recargar; el plan decide si es un evento nuevo del `EventBus`) y el estado de las estructuras en tipos JSON con test de ida y vuelta en memoria. La 010 conecta el guardado y el mensaje. **Cerrada (nov 2026): aceptada.** | — |
| 3 | **Números de la cuadrícula.** ACTION_PLAN 2.8 pide tamaño de celda y límites "como dato", pero BALANCE.md no los tiene. Tampoco el tamaño de la base. | Añadir a BALANCE.md (sección nueva en §5 o §7) antes de aprobar: celda de 1,0 m, base de 20x20 m, área edificable de 12x8 celdas (96 celdas; la base completa del PMV son 1 generador + 5 cofres + estaciones). Valores iniciales, a ajustar en el móvil. **Cerrada (nov 2026): aceptada**; valores en BALANCE §5.6. Si el área se queda corta, se amplía. | — |
| 4 | **Huella y rotación de las estructuras.** Ningún documento dice cuántas celdas ocupa cada una ni si se pueden girar. | La huella es dato de `StructureData`; la estación ocupa 1x1 (valor a BALANCE.md con la pregunta 3). Sin rotación en el PMV: con huellas cuadradas no aporta, y añadirla después no cambia el formato `(zone_id, celda)` salvo un campo más. **Cerrada (nov 2026): aceptada** (BALANCE §5.6). | — |
| 5 | **Controles del modo colocación** (táctil y PC). ACTION_PLAN 2.8 solo dice "confirmar o cancelar". | Tocar (o hacer clic en) una celda lleva la vista previa a esa celda; botones "Confirmar" y "Cancelar" en pantalla (Enter / Escape en PC, y el botón atrás de Android cancela). El robot no se mueve ni ataca mientras dura el modo, pero la batería sigue bajando (no es una pausa). Descartado: que la vista previa siga al robot (impreciso con joystick) y arrastrar (choca con el joystick flotante). **Cerrada (nov 2026): aceptada** (R-009-55 a R-009-57). | — |
| 6 | **Cómo se entra en el modo edición.** Interactuar con la estación ya significa "recargar", así que mover necesita otro disparador. | Botón "Editar base" en el HUD, visible solo en la base. En modo edición, tocar una estructura la coge y pasa a los controles de la pregunta 5; cancelar la devuelve a su sitio; el botón sale del modo. Mover no cuesta nada. El banco y el punto de salida no se pueden coger. **Cerrada (nov 2026): aceptada** (R-009-59, R-009-60). | — |
| 7 | **Celdas que no se pueden ocupar y el robot.** ¿Se puede colocar encima del robot, del punto de aparición, del acceso al banco o al punto de salida? | Celdas reservadas como dato de la base (punto de aparición, frente del banco y del punto de salida): nunca edificables. Una celda donde hay un robot cuenta como inválida (roja). Las estructuras tienen colisión. No se comprueba que el jugador se encierre: el modo edición siempre permite deshacerlo. **Cerrada (nov 2026): aceptada** (R-009-25, R-009-58). | — |
| 8 | **Desmontar una estructura.** No aparece en PMV, BALANCE ni ACTION_PLAN. | Fuera del PMV: las estructuras se mueven, no se quitan. Si el playtesting lo pide, se decide con devolución de materiales en BALANCE.md. **Cerrada (nov 2026): aceptada** (BALANCE §5.6). | — |
| 9 | **Detalles del viaje.** ¿Pide confirmación? ¿Se puede salir con zombies persiguiéndote? ¿Cuánto dura la pantalla de carga? | Sin confirmación y también en plena persecución: llegar al punto de salida es la huida. La pantalla de carga dura lo que tarde la carga, sin mínimo (sin número nuevo en BALANCE §11); el mundo queda congelado mientras, como en la transferencia de la 008. Al llegar a la zona verde el robot aparece en su `SpawnPoint`, con el punto de salida al lado. **Cerrada (nov 2026): aceptada.** | — |
| 10 | **Dónde empieza la partida.** Hasta la 010 no hay guardado. | Cada arranque es un mundo nuevo: robot en el punto de aparición de la base, base vacía salvo el banco, contador de visitas a 0. **Cerrada (nov 2026): aceptada.** | — |
| 11 | **Techo y luces de la base.** ACTION_PLAN 2.1 pide "paredes y techo" y "luces puntuales (lámparas)"; con cámara isométrica un techo tapa al robot, y PMV §3.2 limita a 2-3 luces dinámicas. | Sin techo (almacén abierto por arriba) y paredes bajas o solo las del fondo. Como máximo 2 luces puntuales sin sombras más la direccional; el resto, lámparas con material emisivo. Suelo con `GridMap` o malla única: lo decide el plan midiendo. **Cerrada (nov 2026): aceptada** (ACTION_PLAN 2.1 actualizado). | — |
| 12 | **Contador de visitas de la base.** La 008 sube el contador de la zona donde mueres; la base no tiene cajas ni enemigos. | El contador solo se aplica a zonas `FARM`; morir o salir de la base no sube nada. **Cerrada (nov 2026): aceptada.** | — |
