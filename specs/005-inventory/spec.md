# Spec 005 — Inventario: `InventoryComponent`, UI y loot al jugador

| Campo | Valor |
|---|---|
| **Estado** | Aprobado (2026-11-15, revisión con loot manual y pantalla de caja) |
| **Tarea(s) ACTION_PLAN** | 1.2 (sin crear `ItemData` ni los `.tres` de chatarra, cables y hierro, hechos en la spec 004) |
| **Fuentes** | ACTION_PLAN.md Tareas 1.2, 1.1 ("añadir a inventario"), 2.6 y 2.7 (contexto), 4.1 (botón almacenamiento) · PMV.md §2.1 (5 slots, botón almacenamiento), §4.5 gancho 7, §6, §10 · BALANCE.md §1.3, §2, §6.1, §7.2 · ONLINE.md "Preparación del código desde el PMV" punto 6 · architecture.md §3, §5, §6, §7, §8, §9.2, §9.3, §9.5, §12, §13 · Constitución P2, P3, P4, P5, P6, P8, P11, P13 |
| **Depende de** | 001 (InputMap `open_storage`), 002 (controles táctiles), 003 (HUD, game over), 004 (`ItemData`, `ItemStack`, `DataRegistry`, `LootBox`) |
| **Rama** | `feat/005-inventory` |

## 1. Objetivo

Que lo que hay en las cajas llegue al robot que las abre cuando el jugador lo decida, y que el jugador vea lo que
lleva. Es la primera pieza de estado por jugador después de la batería, y de ella dependen cofres (2.6), crafteo
(2.4), muerte (1.5), nivel de chasis (2.7) y guardado (2.3). Por eso fija ahora tres cosas: las reglas de apilado,
el contrato del componente con el movimiento de items entre inventarios, y las primeras pantallas emergentes.

## 2. Historias

- Como jugador, quiero abrir una caja y ver lo que tiene, para elegir qué cojo o cogerlo todo de una vez.
- Como jugador, quiero abrir mi inventario con el botón de almacenamiento (Tab en PC) y ver cada ranura con su
  icono y su cantidad, para saber qué llevo.
- Como jugador, quiero saber cuándo no me cabe algo, y que lo que no cabe se quede en la caja, para no perderlo sin
  enterarme.
- Como desarrollador de crafteo, cofres y muerte, quiero un inventario con `add` / `remove` / `has` y el movimiento
  entre inventarios probados, y las reglas de apilado aisladas, para no reimplementarlos.

## 3. Requisitos (EARS)

### 3.1 Reglas de apilado (`InventoryRules`, lógica pura)

| ID | Requisito | Fuente |
|---|---|---|
| R-005-01 | THE stacking rules SHALL live in a pure system (`InventoryRules`) with no `Node` or autoload dependency, testable on its own. | architecture §3, §9.3, Constitución P3 |
| R-005-02 | THE inventory SHALL take its slot count from the level-1 entry of a `ChassisLevelData` resource holding the table of BALANCE §6.1, the only place that number lives. | ACTION_PLAN 1.2, 2.7, BALANCE §1.3, §6.1, Constitución P2 |
| R-005-03 | THE inventory SHALL never hold more than `stack_max` (BALANCE §2) of one item in one slot, and each slot SHALL hold at most one kind of item. | ACTION_PLAN 1.2, BALANCE §2 |
| R-005-04 | WHEN items are added, THE inventory SHALL first fill the slots that already hold that item and are below `stack_max`, in slot order, and then use empty slots in slot order. | Decisión nov 2026 (pregunta 3) |
| R-005-05 | IF an add does not fit entirely, THEN THE inventory SHALL add what fits and report the quantity left over. | Decisión nov 2026 (preguntas 1 y 3) |
| R-005-06 | WHEN asked whether it has a quantity of an item, THE inventory SHALL answer with the sum of that item across all slots. | ACTION_PLAN 1.2 (`has_item`) |
| R-005-07 | WHEN items are removed and the inventory holds enough, THE inventory SHALL remove exactly that quantity, from the last slot towards the first, emptying the slots that reach 0. | ACTION_PLAN 1.2 (`remove_item`), decisión nov 2026 (pregunta 3) |
| R-005-08 | IF a remove asks for more than the inventory holds, THEN THE inventory SHALL remove nothing and return a failed `ActionResult`. | architecture §9.2, decisión nov 2026 (pregunta 3) |
| R-005-09 | IF an add or remove receives a quantity ≤ 0 or an item unknown to the catalog, THEN THE inventory SHALL reject it, report an error naming the item, and leave every slot unchanged. | Constitución §2 (errores), architecture §8 |

### 3.2 `InventoryComponent`

| ID | Requisito | Fuente |
|---|---|---|
| R-005-10 | THE robot SHALL own one `InventoryComponent`, and no autoload SHALL hold inventory contents. | PMV §4.5 gancho 7, ONLINE.md punto 6, architecture §6, Constitución P4 |
| R-005-11 | THE `InventoryComponent` SHALL be the only writer of its slots, exposing `add`, `remove`, `has` and `get_slots`, with every state-changing method taking its inputs as parameters and returning an `ActionResult`. | architecture §3 reglas 3-4, §9.2, §9.3, §12 |
| R-005-12 | WHEN its contents change, THE `InventoryComponent` SHALL emit `inventory_changed` exactly once per operation; WHEN an operation changes nothing, it SHALL not emit it. | architecture §7, §9.3 |
| R-005-13 | THE `InventoryComponent` SHALL expose a way to set its slot count, so ACTION_PLAN 2.7 can grow it without changing the component. | ACTION_PLAN 2.7, decisión nov 2026 (pregunta 2) |
| R-005-14 | THE game SHALL provide the `ActionResult` type of architecture §9.2, and every failure SHALL carry a translation key present in ES and EN. | architecture §9.2, Constitución P11 |
| R-005-15 | WHEN items are moved from one inventory to another, THE source SHALL lose exactly what the destination accepted, so no item is created or lost, and each inventory SHALL emit `inventory_changed` at most once for the move. | Decisión nov 2026 (pregunta 7), architecture §3 regla 3 |

### 3.3 Cajas de loot

| ID | Requisito | Fuente |
|---|---|---|
| R-005-16 | WHEN the player interacts with a loot box that still holds items, THE game SHALL open the loot screen through the `UIManager`, showing the box's slots and the slots of the interactor's inventory. | Decisión nov 2026 (pregunta 7), architecture §9.1, §9.5 |
| R-005-17 | THE box SHALL roll its loot table only on its first interaction and keep the result in its own `InventoryComponent`; later interactions SHALL show what is left without rolling again. | ACTION_PLAN 1.1, R-004-23, BALANCE §2.1, §7.2, decisión nov 2026 (preguntas 1 y 7) |
| R-005-18 | WHEN the player taps a stack of the box on the loot screen, THE game SHALL move that stack to the player's inventory, as much of it as fits. | Decisión nov 2026 (pregunta 7) |
| R-005-19 | WHEN the player presses the take-all button of the loot screen, THE game SHALL move every stack of the box to the player's inventory, in slot order, as much as fits. | Decisión nov 2026 (pregunta 7) |
| R-005-20 | IF a move leaves items in the box because they do not fit, THEN THE box SHALL keep them for the visit and stay interactable with the opened look, and THE HUD SHALL show the translated message `MSG_INVENTORY_FULL`. | Decisión nov 2026 (preguntas 1 y 7), BALANCE §7.2 |
| R-005-21 | WHEN a box becomes empty, THE loot screen SHALL close, and THE box SHALL disable its `InteractableComponent` and never offer loot again during the visit. Sustituye a R-004-24: la caja ya no se desactiva al abrirse, sino al vaciarse; la caja vaciada como contenedor llega con ACTION_PLAN 2.6. | ACTION_PLAN 1.1, 2.6, R-004-24, decisión nov 2026 (preguntas 1 y 7) |
| R-005-22 | IF the interactor of a box has no `InventoryComponent`, THEN THE game SHALL report an error naming the box and the interactor, open no screen and leave the box's contents unchanged. | Constitución §2 (errores), revisión de arquitectura nov 2026 (la tirada de R-005-17 ya ha ocurrido; no se pierde nada) |

### 3.4 Pantallas

| ID | Requisito | Fuente |
|---|---|---|
| R-005-23 | THE HUD SHALL show a storage button at the bottom centre, outside the joystick area of R-002-10. | PMV §2.1 (botón almacenamiento), ACTION_PLAN 4.1 |
| R-005-24 | WHEN the player presses the storage button or the `open_storage` InputMap action (Tab on PC), THE game SHALL open the inventory screen through the `UIManager` if no screen is open, and close the top screen if one is open. | PMV §2.1, spec 001 (InputMap), architecture §9.5, Constitución P8 |
| R-005-25 | THE inventory screen SHALL show one cell per slot, each with the item's icon and quantity, and an empty look for empty slots; THE loot screen SHALL use the same cells for both inventories. | ACTION_PLAN 1.2 |
| R-005-26 | WHILE a screen is open, THE screen SHALL update only through `inventory_changed` of the inventories it shows, never by polling. | architecture §9.5, §11 |
| R-005-27 | WHILE any `UIManager` screen is open, THE robot SHALL ignore movement and interaction input, and THE game SHALL not pause (the battery keeps draining). | architecture §9.5, decisión nov 2026 (preguntas 4 y 7) |
| R-005-28 | WHEN Escape (PC) or the Android back action is received with a `UIManager` screen open, THE `UIManager` SHALL close the top screen. | architecture §9.5 |
| R-005-33 | WHEN the Android back action is received with no `UIManager` screen open, THE game SHALL not close. | Decisión nov 2026 (pregunta 8), consecuencia de R-005-28 |
| R-005-29 | WHILE the battery is depleted (game over), THE `UIManager` SHALL have no screen open and SHALL open none. | Inferido de spec 003 R-003-12, como R-004-16 |
| R-005-30 | THE inventory screen, the loot screen, the storage and take-all buttons and `MSG_INVENTORY_FULL` SHALL use only translation keys for their text, in ES and EN. | Constitución P11 |

### 3.5 Datos de items

| ID | Requisito | Fuente |
|---|---|---|
| R-005-31 | EVERY `ItemData` SHALL have an icon, and the catalog test SHALL reject an item without one. | ACTION_PLAN 1.2 (`icon`), architecture §8 |
| R-005-32 | THE item icons SHALL be free CC0/CC assets or primitive placeholders, with their licence recorded. | CLAUDE.md (presupuesto €0) |

Los valores numéricos (ranuras, máximos de apilado) se citan por su fuente; el spec no los fija.

## 4. Fuera de alcance

- Crear `ItemData` y los `.tres` de chatarra, cables y hierro: hechos en la spec 004 (R-004-18).
- Subir de nivel el chasis y ampliar las ranuras al ganar XP: ACTION_PLAN 2.7 (spec 013). Aquí solo el punto de
  enganche (R-005-13). Reducir ranuras no existe en el PMV.
- Cofres y transferir del inventario a un contenedor: ACTION_PLAN 2.6 (spec 012). La pantalla de caja de la 005
  solo permite **coger**; dejar items en una caja vaciada llega con los cofres (pregunta 6), que reutilizarán el
  movimiento entre inventarios (R-005-15).
- Consumir materiales al craftear: ACTION_PLAN 2.4 (spec 011), que usa `remove` / `has`.
- Perder el inventario al morir y soltarlo en el suelo: ACTION_PLAN 1.5 (spec 008).
- Guardar y cargar el inventario (`to_save_data` / `from_save_data`, grupo `persistent`): ACTION_PLAN 2.3
  (spec 010). Aquí el estado solo tiene que ser serializable como ids y cantidades (architecture §10.2).
- Guardar lo que queda en cada caja durante la visita y perderlo al empezar la siguiente: spec 010 (BALANCE
  §7.2). En la 005 no hay salida de zona ni guardado: lo que queda dura hasta reiniciar la partida.
- Piezas en el inventario (`PieceData`, durabilidad, `uid` de `ItemStack`): ACTION_PLAN 3.1 (spec 014).
- Baterías portátiles y botón de consumibles: no salen en la caja básica (BALANCE §2.1); llegan con el generador
  (spec 012) y el HUD completo (ACTION_PLAN 4.1).
- Notificaciones genéricas de 3 s ("Nivel up", "Pieza rota"): ACTION_PLAN 4.1. R-005-20 solo exige un aviso
  mínimo de inventario lleno.
- Tirar items del inventario: spec 008 (ACTION_PLAN 1.5). Ver pregunta 6.
- Arrastrar, ordenar o dividir pilas, y coger una parte de una pila: no se pide en el PMV. Tocar una pila la coge
  entera (lo que quepa).
- Qué hace atrás en Android sin ninguna pantalla abierta (por ejemplo, abrir la pausa): menú de pausa,
  ACTION_PLAN 4.x. La 005 solo garantiza que no cierra el juego (R-005-33).
- Descripción de items en pantalla (ver pregunta 5) y animación o sonido de recogida (ACTION_PLAN 4.3, 4.4).
- Viaje entre zonas conservando el inventario: lo verifica la spec 009 (architecture §6).

## 5. Criterio de hecho

Al interactuar con una caja en la zona verde se abre una pantalla con lo que tiene y con el inventario del robot.
Tocar una pila la pasa al inventario, y "Coger todo" pasa todo lo que cabe; al vaciarse, la pantalla se cierra y la
caja se desactiva. Si algo no cabe, aparece "Inventario lleno" y la caja se queda con el resto: volver a
interactuar enseña lo mismo que quedaba, sin nueva tirada.

El botón de almacenamiento (o Tab) abre el inventario, con 5 ranuras (BALANCE §6.1, nivel 1) que muestran icono y
cantidad y se actualizan solas. Cualquier pantalla se cierra con el mismo botón, Tab, Escape o atrás en Android, y atrás sin pantalla abierta no
cierra el juego.
Mientras hay una abierta, el robot no se mueve ni interactúa, pero la batería sigue bajando. Ninguna ranura pasa
del máximo de BALANCE §2.

Tests en verde:
- apilado: llenar, desbordar, varias pilas, quitar, quitar de más, cantidades inválidas;
- señal una vez por operación y ningún autoload con inventario;
- mover entre inventarios sin crear ni perder items;
- caja: una sola tirada, se queda el resto y se desactiva al vaciarse;
- catálogo con iconos;
- integración "abrir una caja y coger todo añade los items al inventario" (ACTION_PLAN 1.2).

Probado en PC y en el Android de gama media (toca UI e input).

## 6. Preguntas abiertas

| # | Pregunta | Propuesta | ¿Bloquea? |
|---|---|---|---|
| 1 | ~~¿Qué pasa con el loot que no cabe?~~ | **Cerrada (nov 2026)**: se queda en la caja mientras dure la visita, y la caja sigue interactuable hasta vaciarse (R-005-20, R-005-21). Al salir de la zona, la visita nueva regenera las cajas y lo que quedaba se pierde (BALANCE §7.2). Guardar lo que queda dentro de la visita es de la spec 010. | — |
| 2 | ~~Ranuras: contradicción y fuente del dato~~ | **Cerrada (nov 2026)**: BALANCE §1.3 corregido (5 a nivel 1, crecen con §6.1). La 005 crea el recurso `ChassisLevelData` solo con los datos de §6.1 y el inventario toma las ranuras del nivel 1 (R-005-02); el cálculo de nivel, `level_up` y la ampliación siguen en ACTION_PLAN 2.7. | — |
| 3 | ~~Detalles de apilado~~ | **Cerrada (nov 2026)**: varias pilas del mismo item sí (R-005-04); `add` parcial, devuelve lo que sobra (R-005-05); `remove` todo o nada (R-005-08); se quita desde la última ranura hacia la primera (R-005-07). Nombres de architecture §9.3 (`add`, `remove`, `has`, `get_slots`), con el item por id (`StringName`, architecture §8). | — |
| 4 | ~~Pantalla emergente o tira fija en el HUD~~ | **Cerrada (nov 2026)**: pantalla emergente sobre un `UIManager` mínimo creado aquí (`open`, `close_top`, `is_modal_open`, `modal_state_changed`, cierre con Escape/atrás). El juego no se pausa: la batería sigue bajando (R-005-24, R-005-27, R-005-28). | — |
| 5 | ~~Campos de `ItemData`~~ | **Cerrada (nov 2026)**: se añade `icon: Texture2D`; `description_key` queda para la spec que muestre descripciones. Iconos de Kenney (CC0) o marcadores simples con licencia anotada (R-005-31, R-005-32). | — |
| 6 | ~~¿Se puede tirar un item o dejarlo en una caja?~~ | **Cerrada (nov 2026)**: sí a las dos (PMV §10, BALANCE §7.2). Tirar: el item cae al suelo y caduca con la regla de lo soltado al morir; lo implementa la spec 008 (ACTION_PLAN 1.5), que crea el objeto caído y la caducidad. Dejar en una caja vaciada (capacidad de un cofre, se pierde con la visita siguiente): lo implementa la spec de cofres (ACTION_PLAN 2.6), que amplía la pantalla de caja para depositar. La 005 no implementa ninguna de las dos. | — |
| 7 | ~~¿El loot pasa solo al inventario al abrir la caja?~~ | **Cerrada (nov 2026)**: no. Interactuar abre una pantalla con el contenido de la caja y el inventario del robot. Tocar una pila la coge (lo que quepa), "Coger todo" coge todo lo que quepa en orden de ranura, y la pantalla se cierra sola al vaciarse la caja (R-005-16 a R-005-21). Desde esa pantalla no se deposita (pregunta 6). Mientras está abierta, el robot no se mueve ni interactúa (R-005-27). | — |
| 8 | ~~¿Qué hace atrás en Android sin ninguna pantalla abierta?~~ | **Cerrada (nov 2026)**: para que atrás cierre la pantalla de arriba (R-005-28) hay que desactivar que atrás cierre la app. Sin pantalla abierta, atrás **no cierra el juego** (R-005-33): salir así perdería lo no guardado. Darle otro uso (abrir la pausa) es del menú de pausa, ACTION_PLAN 4.x. | — |
