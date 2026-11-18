# Spec 011 — Crafteo de piezas y reparación en el banco

| Campo | Valor |
|---|---|
| **Estado** | Aprobado (2026-11-17) |
| **Tarea(s) ACTION_PLAN** | 2.4 |
| **Fuentes** | ACTION_PLAN.md Tarea 2.4 (y 2.2, 2.3, 2.5, 2.6, 3.1, 3.2, 3.3, 4.3, 4.4, 5.4 para los límites) · PMV.md §2.1, §2.2, §2.3, §2.4, §4.5 gancho 5, §8.2, §10 (base y viaje; guardado; muerte) · BALANCE.md §2, §4.1, §4.3, §5.1, §8.1, §8.2 · SPECS.md §29 · architecture.md §3, §8, §9.2, §9.3, §9.5, §10.3 · README §6 (condición de entrada de la spec 014) · Constitución P1, P2, P3, P4, P5, P11, P13, P14 |
| **Depende de** | 005 (`InventoryComponent`, `InventoryRules`, `UIManager`), 008 (objeto caído, dividir y tirar), 009 (`RecipeData`, `CraftingSystem`, banco, `BuildScreen`), 010 (guardado del inventario y del objeto caído, `Uid`) |
| **Rama** | `feat/011-crafting-repair` |

## 1. Objetivo

Completar el banco de reparaciones: además de construir estructuras (spec 009), crear las tres piezas básicas
y reparar piezas dañadas, pagando con los materiales de BALANCE §4.3. Es la vía por la que el jugador consigue
sus primeros Brazos y Piernas (BALANCE §8.2, "Día 2-3") y deja `RecipeData` y `CraftingSystem` listos para que
el resto de recetas sean datos. Las piezas entran como objetos únicos del inventario (con `uid` y durabilidad);
equiparlas y degradarlas es de la spec 014 (pregunta 1).

## 2. Historias

- Como jugador, quiero crear Brazos, Piernas y Core básicos en el banco con los materiales que traigo de la
  zona, para dejar de pelear con un brazo y una pierna.
- Como jugador, quiero ver qué cuesta cada pieza y por qué no puedo crearla, para saber qué me falta.
- Como jugador, quiero reparar una pieza dañada antes de que se rompa, para no perderla.
- Como jugador, quiero que una pieza conserve su desgaste aunque la tire, muera o cierre el juego, para que
  reparar tenga sentido.
- Como desarrollador de la spec 014 (piezas y degradación), quiero piezas que ya existen como objetos únicos y
  una reparación probada, para solo añadir equipo, stats y desgaste.
- Como desarrollador de v1.2 (crafteo por niveles), quiero que una receta nueva sea un `.tres`, para rellenar el
  árbol sin tocar código.

## 3. Requisitos (EARS)

### 3.1 Datos: piezas, recetas y coste de reparación

| ID | Requisito | Fuente |
|---|---|---|
| R-011-01 | THE game SHALL define a `PieceData` resource that extends `ItemData`, with the maximum durability of BALANCE §4.1 as a field, and every `PieceData` SHALL have a `stack_max` of 1. | architecture §9.3, ACTION_PLAN 3.1, 3.2, Constitución P5 — pregunta 1 |
| R-011-02 | THE `DataCatalog` SHALL list one `PieceData` `.tres` per basic piece of PMV §2.2, with the ids `basic_arms`, `basic_legs` and `basic_core`, each with an icon and a name from a translation key in ES and EN. | PMV §2.2, architecture §8, R-005-31, Constitución P11 |
| R-011-03 | THE `RecipeData` resource SHALL be able to produce one item (`result_item`) instead of a structure, and every recipe in the `DataCatalog` SHALL have exactly one result: a structure or an item. | ACTION_PLAN 2.4, PMV §4.5 gancho 5 |
| R-011-04 | THE `DataCatalog` SHALL list one recipe per basic piece, whose result is that piece and whose ingredients are those of BALANCE §4.3.1. | ACTION_PLAN 2.4, BALANCE §4.3.1, §5.1 |
| R-011-05 | THE catalog tests SHALL check that every recipe of the MVP is `WORKBENCH`, tier 1, with no requirements, and that every item it names exists in the `DataCatalog`. | ACTION_PLAN 2.4, SPECS §29, architecture §8 |
| R-011-06 | THE repair costs SHALL live in one data resource listed in the `DataCatalog` or referenced from it, with the costs and durability ranges of BALANCE §4.3.2; no script SHALL hold a repair cost or a durability threshold as a literal. | BALANCE §4.1, §4.3.2, §5.1, Constitución P2 — pregunta 2 |

### 3.2 Piezas como objetos únicos

| ID | Requisito | Fuente |
|---|---|---|
| R-011-07 | WHEN a piece is created, THE game SHALL give its `ItemStack` a quantity of 1, the maximum durability of its `PieceData` and a new `uid` from `Uid.generate()`. | architecture §9.3, §10.3, BALANCE §4.1, §5.1 |
| R-011-08 | THE inventory rules SHALL keep every piece in a slot of its own, never merged with another piece, even of the same `PieceData`. | architecture §9.3 |
| R-011-09 | WHEN a piece moves between inventories, is split or thrown, falls in the dropped object of a death or is picked up from a dropped object, THE game SHALL keep its durability and its `uid`. | README §6 (condición de entrada de la spec 014), R-008-11 — pregunta 1 |
| R-011-10 | THE saved data of a dropped object SHALL include the durability and `uid` of each of its stacks, and loading it SHALL restore them. | spec 010 (R-010-29), README §6 — pregunta 1 |
| R-011-11 | IF a loaded piece stack has a durability outside 1 to its maximum or an empty `uid`, THEN THE game SHALL report it with `push_error` and drop that stack, as spec 010 does with any other invalid entry, keeping the rest. | Constitución §2 (errores), spec 010 |

### 3.3 Crafteo

| ID | Requisito | Fuente |
|---|---|---|
| R-011-12 | THE check of whether a player can craft an item recipe SHALL be pure code in `CraftingSystem` over the slots of its inventory and the recipe, and SHALL give the reason when it cannot: not enough materials, or no free slot for the result once the ingredients are paid. | ACTION_PLAN 2.4, architecture §3, §9.2, Constitución P3 — pregunta 3 |
| R-011-13 | WHEN a player crafts an item recipe that it can craft, THE player's `InventoryComponent` SHALL remove the ingredients and add the new piece of R-011-07 in one step, returning a successful `ActionResult`. | ACTION_PLAN 2.4, BALANCE §5.1, R-009-62 |
| R-011-14 | IF a craft is requested that cannot be done, THEN THE inventory SHALL stay unchanged and THE `ActionResult` SHALL carry the translation key of the reason of R-011-12. | architecture §9.2, R-009-62 |
| R-011-15 | THE crafting of an item SHALL charge its ingredients when it is crafted, with no confirmation step and no waiting time. | ACTION_PLAN 2.4, BALANCE §5.1 |

### 3.4 Reparación

| ID | Requisito | Fuente |
|---|---|---|
| R-011-16 | THE repair cost of a piece SHALL be computed by pure code from its durability, its maximum durability and the data of R-011-06. | ACTION_PLAN 2.4, BALANCE §4.3.2, Constitución P3 — pregunta 2 |
| R-011-17 | IF a piece is at its maximum durability, THEN THE repair check SHALL refuse it with its own reason. | BALANCE §4.3.2 (restauración completa) |
| R-011-18 | IF a piece's durability is 0, THEN THE repair check SHALL refuse it as not repairable. | BALANCE §4.1, §4.3.2 (pieza rota) |
| R-011-19 | WHEN a player repairs a damaged piece of its inventory, identified by its `uid`, and can pay the cost of R-011-16, THE player's `InventoryComponent` SHALL remove the cost and set that piece's durability to its maximum in one step, keeping its `uid` and its slot, and return a successful `ActionResult`. | ACTION_PLAN 2.4, BALANCE §4.1, §5.1 |
| R-011-20 | IF a repair is requested that cannot be done (not enough materials, refused by R-011-17 or R-011-18, or a `uid` that is not in the inventory), THEN THE inventory SHALL stay unchanged and THE `ActionResult` SHALL carry the translation key of the reason; an unknown `uid` SHALL also be reported with `push_error`. | architecture §9.2, Constitución §2 (errores) |

### 3.5 Pantalla del banco

| ID | Requisito | Fuente |
|---|---|---|
| R-011-21 | WHEN the local player uses the repair bench, THE game SHALL open one bench screen through `UIManager` with three sections: build (the structures of spec 009), craft and repair; the build section SHALL keep R-009-38, R-009-39, R-009-64 and R-009-65. | ACTION_PLAN 2.4, PMV §2.1, architecture §9.5 — pregunta 4 |
| R-011-22 | THE craft section SHALL list every `WORKBENCH` item recipe with the icon and name of its result, its cost and a "Create" button. | ACTION_PLAN 2.4 |
| R-011-23 | IF the player cannot craft a recipe, THEN its "Create" button SHALL be disabled and a notice SHALL show the reason of R-011-12. | ACTION_PLAN 2.4 (botón deshabilitado sin materiales) |
| R-011-24 | THE repair section SHALL list every damaged piece of the player's inventory with its icon, name, current durability, repair cost and a "Repair" button; IF the player cannot repair it, THEN the button SHALL be disabled with a notice of the reason; IF there is no damaged piece, THEN the section SHALL show a notice that there is nothing to repair. | ACTION_PLAN 2.4, BALANCE §4.3.2 |
| R-011-25 | WHEN the player's inventory changes while the bench screen is open, THE screen SHALL update its entries, buttons and notices. | ACTION_PLAN 2.4, architecture §9.5 (sin leer estado en `_process`) |
| R-011-26 | WHEN a craft or a repair succeeds, THE bench screen SHALL stay open. | pregunta 4 |
| R-011-27 | THE bench screen SHALL show player-visible text only from translation keys in ES and EN. | Constitución P11 |

### 3.6 Guardado

| ID | Requisito | Fuente |
|---|---|---|
| R-011-28 | WHEN a craft or a repair succeeds, THE game SHALL save the World as it does after building a structure (R-010-42). | PMV §10 (guardado), spec 010 — pregunta 5 |

Los valores numéricos (durabilidad máxima, ingredientes de cada pieza, coste y tramos de reparación) se citan
por su fuente; el spec no los fija.

## 4. Fuera de alcance

- Equipar y desequipar piezas, `EquipmentComponent`, `StatModifier`, `StatsComponent`, `RobotBaseStats.tres`,
  `slot_type` y la UI de equipo: spec 014 (ACTION_PLAN 3.1). Hasta entonces una pieza creada es un objeto del
  inventario sin efecto (pregunta 1).
- Degradación por golpe, rotura, `piece_broken`, notificación "Pieza rota" y barra de durabilidad con colores:
  spec 014 (ACTION_PLAN 3.2). Hasta entonces ninguna pieza se daña jugando (pregunta 7).
- Reparar piezas equipadas sin desequiparlas: spec 014 (pregunta 6).
- Qué pasa con un Core de repuesto al morir: lo decide la spec 014 con las ranuras (pregunta 8). Esta spec no
  cambia la muerte: el inventario cae entero (R-008-26).
- Recetas del generador eólico y del cofre, y su límite de cinco: spec 012 (ACTION_PLAN 2.5, 2.6). Entran como
  datos en la sección de construir.
- Piezas dañadas en el loot del robot hostil (50 % de durabilidad): spec 015 (ACTION_PLAN 3.3). Red de seguridad
  con "piezas medio rotas": pregunta abierta de PMV §10, con la spec 014.
- Crafteo "uno mismo" y por nanobots, árbol de crafteo, desbloqueo de requisitos (`requires`) y tiers
  superiores: v1.2+ (PMV §2.3, SPECS §29). Banco crafteable a mano: v1.1 (SPECS §29, §32).
- Armas y banco de armas: v1.1 (PMV §2.3).
- Cola o tiempo de crafteo: ningún documento lo pide; crear es instantáneo (R-011-15).
- SFX de crear y reparar: ACTION_PLAN 4.3. Animaciones: 4.4. Modelo 3D definitivo del banco: el de la spec 009
  se queda hasta 4.4.
- Paso de la guía sobre crear piezas: ACTION_PLAN 5.4 (la guía de PMV §2.1 solo pide la estación de carga).

## 5. Criterio de hecho

En la base, interactuar con el banco abre una pantalla con tres secciones. "Construir" funciona como en la
spec 009. "Crear" muestra Brazos, Piernas y Core básicos con icono, nombre y coste (BALANCE §4.3.1); sin
materiales suficientes, o sin ranura libre para la pieza, el botón está desactivado con su aviso. Con los
materiales, "Crear" resta los ingredientes y añade la pieza en una ranura propia, al 100 % de durabilidad
(BALANCE §4.1), sin cerrar la pantalla. Dos Brazos básicos ocupan dos ranuras. "Reparar" dice que no hay nada
que reparar mientras ninguna pieza esté dañada. Una pieza conserva su durabilidad y su `uid` al tirarla y
recogerla, al morir y recuperarla, y al cerrar y reabrir el juego.

Tests en verde: recursos (`PieceData` de las tres piezas, recetas con los ingredientes de BALANCE §4.3.1, datos
de reparación con los de §4.3.2, un único resultado por receta, `WORKBENCH`/tier 1/sin requisitos);
`CraftingSystem` (materiales justos, de sobra, insuficientes; inventario lleno; un pago que libera la ranura
justa; coste de reparación en cada tramo y en sus bordes; pieza intacta y pieza a 0 rechazadas); crear y reparar
en `InventoryComponent` (todo o nada, `uid` nuevo al crear y conservado al reparar, `uid` desconocido); piezas
que no se apilan; durabilidad y `uid` conservados al mover, dividir, tirar, morir, recoger y guardar y cargar
el objeto caído; entrada de pieza inválida al cargar; pantalla del banco (entradas, botones y avisos, se
actualiza al cambiar el inventario, sigue abierta tras crear o reparar); guardado tras crear y reparar con
`MemorySaveStore`. Reparar una pieza dañada se comprueba con tests que inyectan una pieza dañada (pregunta 7).

## 6. Preguntas abiertas

| # | Pregunta | Propuesta | ¿Bloquea? |
|---|---|---|---|
| 1 | ~~Piezas antes de la spec 014~~ | **Cerrada (nov 2026): opción A**. La 011 crea `PieceData` mínima (durabilidad máxima y `stack_max` 1) y las tres piezas como objetos del inventario, sin efecto hasta la 014, y adelanta la condición de entrada de la 014: durabilidad y `uid` se conservan en todos los caminos de una pila, también en el objeto caído guardado (R-011-07 a R-011-11). La 014 añade `slot_type`, modificadores, equipo y desgaste. README §6 actualizado. Descartado: hacer la 014 antes (B) y dejar reparar para la 014 (C). | — |
| 2 | ~~Coste de reparación~~ | **Cerrada (nov 2026): opción A**. Tramos según la durabilidad que queda: por encima del 25 % de la máxima, 2 hierro + 1 cable; del 25 % para abajo (sin llegar a 0), 3 hierro + 2 cables; a 0, no reparable. BALANCE §4.1 y §5.1 remiten a §4.3.2, que habla de tramos; ACTION_PLAN 2.4 actualizado. Descartado: coste fijo (B) y proporcional (C). | — |
| 3 | ~~Inventario lleno al crear~~ | **Cerrada (nov 2026): opción A**. Se comprueba antes de cobrar, contando la ranura que libera el pago; si no cabe, "Crear" desactivado con aviso. Descartado: dejar la pieza en el suelo (B). | — |
| 4 | ~~Forma de la pantalla del banco~~ | **Cerrada (nov 2026): opción A**. Una sola pantalla con tres pestañas (Construir, Crear, Reparar) que sustituye a la de la spec 009 y abre en Construir; crear y reparar la dejan abierta, construir la cierra para colocar (R-009-65). Coste como hoy ("Chatarra x4"). | — |
| 5 | ~~Guardar tras crear o reparar~~ | **Cerrada (nov 2026): opción A**. Se guarda tras crear y tras reparar (R-011-28), sin mensaje "Partida guardada"; PMV §10 y ACTION_PLAN 2.3 actualizados. | — |
| 6 | ~~Reparar piezas equipadas~~ | **Cerrada (nov 2026)**: fuera de esta spec; la 014 hace que "Reparar" liste también las piezas equipadas, sin desequiparlas (anotado en README §6). | — |
| 7 | ~~Probar reparar jugando~~ | **Cerrada (nov 2026): opción A**. Reparar se verifica con tests que inyectan una pieza dañada; la prueba jugando llega con la 014. Sin botón de depuración. | — |
| 8 | ~~Core de repuesto al morir~~ | **Cerrada (nov 2026)**: se conserva solo el Core equipado (lo aplica la 014); uno de repuesto en el inventario cae como cualquier objeto. Anotado en PMV §10 para confirmarlo con la 014. | — |
