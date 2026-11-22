# Spec 013 — Cajas de loot en sitios variables y nueva pantalla de contenedor

| Campo | Valor |
|---|---|
| **Estado** | Hecho (2026-11-22) |
| **Tarea(s) ACTION_PLAN** | Revisión de 1.1 (colocación de cajas) y 2.6 (UI de cofre y caja). Petición del usuario, 2026-11-20; no hay tarea propia (pregunta 11) |
| **Fuentes** | BALANCE.md §7.1, §7.2, §5.4, §11 · PMV.md §4.5 gancho 3, §10 ("Reposición de cajas abiertas", "Dividir y colocar pilas", "Pantalla de contenedor") · architecture.md §9.3, §9.5, §11 · Constitución P2, P3, P8, P9, P11, P13 · specs 004 (R-004-10, R-004-11, R-004-21), 008 (R-008-09), 010 (R-010-35), 012 (R-012-27 a R-012-35, R-012-46 a R-012-48) |
| **Depende de** | 004, 005, 008, 010, 012 |
| **Rama** | `feat/013-loot-box-sites-container-ui` |

## 1. Objetivo

Dos cambios pedidos tras jugar la spec 012:

1. **Cajas menos previsibles.** Hoy el número y el sitio de las cajas solo dependen de la semilla del mundo y del
   `zone_id` (BALANCE §7.2): en todas las visitas están en los mismos marcadores y el jugador aprende el recorrido.
   Con esta spec el número y los marcadores salen también del número de visita, como ya pasa con los zombies
   (BALANCE §7.1), y los marcadores se reparten en **sitios** por toda la zona.
2. **Pantalla de contenedor clara.** La pantalla de cofres y cajas (R-012-27 a R-012-30) usa el mismo toque para
   cosas distintas: seleccionar una pila, deseleccionarla o moverla a la ranura tocada, según haya o no una
   selección. El selector de cantidad aparece y desaparece y mueve la disposición, "Transferir" no dice hacia
   dónde y las rejillas no dicen cuál es la caja y cuál el inventario. La spec propone una ficha de acción fija con
   verbos que nombran el destino.

## 2. Historias

- Como jugador, quiero que las cajas no estén siempre en el mismo sitio, para tener que explorar la zona en cada
  visita y no repetir el mismo recorrido de memoria.
- Como jugador, quiero ver de un vistazo qué rejilla es la caja (o el cofre) y cuál es mi inventario, y cuánto
  espacio queda en cada una.
- Como jugador, quiero que tocar una pila haga siempre lo mismo y que el botón diga adónde va, para no mover
  cosas sin querer.

## 3. Requisitos (EARS)

### 3.1 Cajas en sitios variables por visita

| ID | Requisito | Fuente |
|---|---|---|
| R-013-01 | WHEN a farm zone places the boxes of a visit (`generate`, `repopulate` or `populate`), THE zone SHALL choose their number and their markers with an RNG from `SeededRng` derived from the world seed, the `zone_id`, the box placement stream and the visit number, so different visits can place them differently. Sustituye la fila "Número y posición de las cajas" de BALANCE §7.2 y amplía R-004-21. | Petición 2026-11-20, BALANCE §7.1 (zombies por visita), Constitución P9 — preguntas 1 y 3 |
| R-013-02 | WHEN the same world seed, zone and visit are placed twice, including after saving and reloading the World, THE boxes SHALL be the same in number and markers. Sustituye a R-004-11 (que no tenía visita); mantiene R-010-35. | R-004-11, R-010-35, Constitución P9 |
| R-013-03 | THE green zone scene SHALL group its box markers in sites spread over the whole playable area, with at least the number of sites and markers per site of BALANCE §7.1. | Petición 2026-11-20 — pregunta 2 |
| R-013-04 | WHEN the boxes of a visit are placed, THEIR number SHALL be in the range of BALANCE §7.1, at most one box SHALL be on each marker, and no site SHALL hold more boxes than the per-site maximum of BALANCE §7.1. | BALANCE §7.1 — pregunta 2 |
| R-013-05 | THE choice of R-013-04 SHALL be pure code in `ZonePopulation` that receives the markers of each site and the RNG; IF the sites cannot hold the maximum box count under the per-site maximum, or a range or the per-site maximum is invalid, THEN it SHALL report it with `push_error` and place no more boxes than fit. | Constitución P3, P13, §2 (errores) |
| R-013-06 | THE `ZoneData` of a farm zone SHALL hold the per-site maximum as data, next to `box_count_min` and `box_count_max`, never as a script literal. | Constitución P2, P5 |
| R-013-07 | WHEN a new visit starts (leaving by the exit or dying, R-008-09), THE zone SHALL remove the boxes of the previous visit with what they held and place closed boxes on the markers chosen for the new visit. Amplía R-008-09, que reponía en el mismo marcador. | R-008-09, BALANCE §7.2 |
| R-013-08 | THE saved state of the visit SHALL keep identifying each opened box by its marker, and loading SHALL bring it back opened, with what was left, on that marker; IF a saved box's marker has no box in that visit, THEN THE zone SHALL report it with `push_error` and drop only that box. | R-010-27, R-010-35, R-012-38 — pregunta 4 |
| R-013-09 | EVERY box marker of the green zone SHALL lie on the zone's navigation mesh, reachable from the spawn point, and outside every obstacle collider. | R-004-01, R-004-04 (colisiones), petición 2026-11-20 |
| R-013-10 | WHEN the placement is run for a fixed seed over the number of visits of BALANCE §7.1, EVERY box marker of the green zone SHALL receive a box at least once, so no marker is dead. | Petición 2026-11-20 (factor aleatorio) — pregunta 2 |
| R-013-11 | THE zone generation SHALL keep using only RNGs from `SeededRng`, never the global `randf()`, `randi()`, `randi_range()` or `randomize()`. Mantiene R-004-10. | R-004-10, Constitución P9 |

### 3.2 Pantalla de contenedor

Boceto (horizontal, 1920x1080). La ficha de acción ocupa siempre el mismo sitio, con o sin selección:

```
┌──────────────────────────── CAJA DE LOOT ────────────────────────────┐
│  CAJA  2/4                     │  INVENTARIO  4/5                     │
│  ┌────┐┌────┐                  │  ┌────┐┌────┐┌────┐┌────┐┌────┐      │
│  │▣ 12││    │                  │  │▣ 3 ││▣ 1 ││▣ 7 ││▣ 1 ││    │      │
│  └────┘└────┘                  │  └────┘└────┘└────┘└────┘└────┘      │
│  ┌────┐┌────┐                  │                                      │
│  │▣ 2 ││    │                  │                                      │
│  └────┘└────┘                  │                                      │
├──────────────────────────────────────────────────────────────────────┤
│ ▣ Chatarra ×12   [−] ━━━━━━●━ [+]  12   [ Pasar al inventario → ]    │
│                                          [ Colocar… ]  [ Coger todo → ]│
└──────────────────────────────────────────────────────────────────────┘
Sin selección: "Toca una pila para elegirla", selector y "Pasar…"/"Colocar…" desactivados.
Pila del inventario elegida: el botón es "← Pasar a la caja" (o "← Guardar en el cofre").
```

| ID | Requisito | Fuente |
|---|---|---|
| R-013-12 | WHEN the container screen opens, THE screen SHALL show the container's grid on the left under a header with its translated name (box or chest) and its occupancy as used/total slots, and the player's inventory on the right under the header "Inventory" with its occupancy; both headers SHALL update when the slots change. Sustituye la disposición de R-012-27. | Petición 2026-11-20, architecture §9.5 — pregunta 5 |
| R-013-13 | THE screen SHALL have an action card below both grids that is always visible with the same size; WHILE no stack is selected, THE card SHALL show a translated hint to tap a stack and its quantity selector and move buttons SHALL be disabled, never hidden. | Petición 2026-11-20 ("desplegable ambiguo") — pregunta 5 |
| R-013-14 | WHEN the player taps a stack in either grid, THE screen SHALL select it, highlight its slot and show in the card the item's icon, translated name and quantity, with the quantity selector of spec 008 set to the whole stack; tapping the selected slot again SHALL clear the selection and tapping another stack SHALL select that one instead. A tap never moves items. Sustituye a R-012-28 y al movimiento por toque de R-012-29. | Petición 2026-11-20, PMV §10 ("Dividir y colocar pilas") — pregunta 5 |
| R-013-15 | WHILE a stack is selected, THE card's move button SHALL name its destination with an arrow pointing to it ("Move to inventory →" for a container stack; "← Move to box" or "← Store in chest" for an inventory stack), and pressing it SHALL move the chosen quantity to the other grid with the rule of R-012-30. Sustituye el botón "Transfer" de R-012-27. | R-012-30, petición 2026-11-20 — preguntas 5 y 9 |
| R-013-16 | WHEN a stack is selected and the player presses "Place…", THE screen SHALL enter a placing mode that outlines the slots of both grids, shows a translated hint to tap the destination slot and turns the button into "Cancel"; tapping a slot SHALL move the chosen quantity there with the rule of R-012-29 and R-012-33 and leave the mode; pressing "Cancel" SHALL leave the mode keeping the selection. | R-012-29, R-012-33 — pregunta 6 |
| R-013-17 | WHILE the placing mode is active, the back action (Escape, Android back or a tap outside the panel, R-012-46 to R-012-48) SHALL leave the placing mode instead of closing the screen. | architecture §9.5 (`handle_back`), R-012-46 a R-012-48 |
| R-013-18 | THE card SHALL show the "Take all →" button of R-012-31, disabled WHILE the container is empty. | R-012-31, R-005-19 |
| R-013-19 | IF a move is refused, THEN THE card SHALL show the translated reason and keep the selection; WHEN a move is done, THE screen SHALL clear the selection and briefly highlight the destination slot(s) for the duration of BALANCE §11. | Plan 012 D22, petición 2026-11-20 — pregunta 7 |
| R-013-20 | THE moves of the screen SHALL keep the rules of R-012-31 to R-012-35 unchanged: pure code in `InventoryRules`, all or nothing with an `ActionResult`, pieces keep durability and `uid`, the screen updates on any change and never closes by itself. | R-012-31 a R-012-35, Constitución P3 |
| R-013-21 | EVERY text of the screen (headers, hint, buttons, refusals) SHALL go through translation keys in Spanish and English. | Constitución P11 |
| R-013-22 | THE screen SHALL behave the same with touch and with the mouse, with no platform checks. | Constitución P8 |

Los valores numéricos (número de cajas, sitios, marcadores por sitio, máximo por sitio, duración del resaltado) se
citan por su fuente (`BALANCE.md`); el spec no los fija.

## 4. Fuera de alcance

- Posiciones libres sobre el navmesh, en lugar de marcadores: solo si la pregunta 1 lo elige; dependería del spike
  de navmesh en tiempo de ejecución (PMV §10).
- Tipos de caja nuevos o tablas de loot por sitio: BALANCE §2.1 solo tiene la caja básica.
- La colocación de los zombies: ya cambia por visita (spec 006) y no se toca.
- Iconos de cajas en el minimapa (ACTION_PLAN 4.1); modelos 3D y animación de apertura (ACTION_PLAN 4.4).
- Arrastrar y soltar pilas: descartado en PMV §10 ("Dividir y colocar pilas").
- "Guardar todo" (pasar todo el inventario al contenedor): no se ha pedido.
- La pantalla de inventario (Tab) mantiene su interacción actual (pregunta 8).
- Los cofres de la base: los coloca el jugador (spec 009/012) y no se reparten al azar.

## 5. Criterio de hecho

- Con la misma partida, salir y volver a la zona verde varias veces muestra las cajas en sitios distintos, siempre
  entre los mínimos y máximos de BALANCE §7.1 y sin dos cajas en un marcador. Cerrar y abrir el juego dentro de una
  visita devuelve las mismas cajas, con las abiertas en su sitio y lo que quedaba dentro.
- Los tests prueban: misma semilla y visita = mismas cajas; el máximo por sitio; que ningún marcador queda muerto;
  que todos los marcadores están en el navmesh; y la pantalla de contenedor (cabeceras, ficha fija, tocar solo
  selecciona, botón con destino, modo colocar, atrás sale del modo).
- En PC y en Android, abrir una caja y un cofre: se ve cuál es cada rejilla y su ocupación, tocar una pila nunca
  la mueve, el botón dice adónde va y la disposición no salta al seleccionar.

## 6. Preguntas abiertas

| # | Pregunta | Propuesta | ¿Bloquea? |
|---|---|---|---|
| 1 | ~~¿Cajas de loot o cofres? ¿Posiciones libres o sitios?~~ | **Cerrada (2026-11-21)**: son las cajas de loot de la zona, no los cofres de la base. Sitios con marcadores colocados a mano (R-013-03); cada visita elige cuántas cajas y en cuáles. Descartado: posiciones libres sobre el navmesh (cajas en sitios absurdos y dependencia del navmesh en tiempo de ejecución, abierto en PMV §10). | — |
| 2 | ~~Valores de los sitios~~ | **Cerrada (2026-11-21)**: 6 sitios, 3-4 marcadores por sitio, como mucho 2 cajas por sitio y comprobación de R-013-10 sobre 50 visitas; las 5-7 cajas se mantienen. En BALANCE §7.1. | — |
| 3 | ~~¿Cambian por visita el número y la posición de las cajas?~~ | **Cerrada (2026-11-21)**: los dos, como los zombies: semilla del mundo + `zone_id` + número de visita (R-013-01). Recargar dentro de la visita no cambia nada (R-013-02). BALANCE §7.2 y PMV §10 actualizados. | — |
| 4 | ~~Mundos guardados antes de esta spec~~ | **Cerrada (2026-11-21)**: se acepta perder las cajas abiertas de la visita en curso (con `push_error`, R-013-08), sin migración ni subir `schema_version`: solo hay partidas de desarrollo. | — |
| 5 | ~~Forma de la pantalla de contenedor~~ | **Cerrada (2026-11-21)**: ficha de acción fija (R-013-12 a R-013-19): tocar solo selecciona y el botón nombra el destino. Descartados: tocar mueve la pila entera y mantener pulsado elige la cantidad (no se descubre en el móvil, mueve cosas sin querer), y dejar la interacción actual con cabeceras (el toque seguiría haciendo tres cosas). PMV §10 actualizado. | — |
| 6 | ~~¿Se mantiene colocar en una ranura concreta?~~ | **Cerrada (2026-11-21)**: sí, como modo explícito "Colocar…" con "Cancelar" (R-013-16), no como segundo toque oculto. | — |
| 7 | ~~Duración del resaltado de la ranura destino~~ | **Cerrada (2026-11-21)**: 0.4 s, en BALANCE §11. | — |
| 8 | ~~¿La pantalla de inventario adopta la ficha fija?~~ | **Cerrada (2026-11-21)**: sí, pero en su propia spec (UI de la Fase 4, ACTION_PLAN 4.1); aquí queda fuera de alcance. | — |
| 9 | ~~Textos del botón según el contenedor~~ | **Cerrada (2026-11-21)**: "Pasar al inventario →", "← Pasar a la caja" en cajas de loot y "← Guardar en el cofre" en cofres; claves nuevas en ES y EN. | — |
| 10 | ~~Numeración de las specs siguientes~~ | **Cerrada (2026-11-21)**: esta spec es la 013; nivel de chasis pasa a 014, piezas a 015 y robot hostil a 016. Las referencias de specs, `docs/systems/`, CLAUDE.md, PMV.md, ACTION_PLAN.md y comentarios de código se cambiaron en una pasada. | — |
| 11 | ~~No hay tarea en ACTION_PLAN~~ | **Cerrada (2026-11-21)**: la decisión se anota en las Tareas 1.1 y 2.6 de ACTION_PLAN. | — |
