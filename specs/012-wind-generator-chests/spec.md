# Spec 012 — Generador eólico y cofres

| Campo | Valor |
|---|---|
| **Estado** | Hecho (2026-11-20) |
| **Tarea(s) ACTION_PLAN** | 2.5, 2.6 |
| **Fuentes** | ACTION_PLAN.md Tareas 2.5, 2.6 (y 2.2, 2.3, 2.8, 4.1, 4.3, 4.4 para los límites) · PMV.md §2.1, §2.3, §2.4, §10 (cajas de loot, muerte y objetos caídos, base, guardado) · BALANCE.md §1.1, §1.3, §2, §2.1, §5.2, §5.4, §5.5, §5.6, §7.2 · SPECS.md §3 · architecture.md §3, §7, §8, §9.1, §9.2, §9.3, §9.5, §10.1, §10.2, §14 (pregunta 2) · Constitución P2, P3, P4, P5, P9, P10, P11, P13, P14 |
| **Depende de** | 005 (`InventoryComponent`, `InventoryRules`, `UIManager`, pantalla de loot), 008 (selector de cantidad, `InventoryRules.split`, `ITimeService`), 009 (`StructureData`, `BuildGrid`, `BaseStructures`, modo colocación y edición), 010 (contrato `persistent`, `SaveManager`), 011 (pantalla del banco, piezas con `uid` y durabilidad) |
| **Rama** | `feat/012-wind-generator-chests` |

## 1. Objetivo

Completar la base del PMV con las dos estructuras que faltan: el generador eólico, que sube la batería máxima y
fabrica baterías portátiles con el tiempo, y los cofres, el único almacén que sobrevive a la muerte (PMV §2.4).
Con ellos el bucle de la base deja de ser solo "recargar y craftear": el jugador guarda materiales entre
expediciones y gana autonomía en la zona. Las dos se construyen desde el banco y se colocan con el modo de la
spec 009, así que casi todo es dato. La misma pantalla de transferencia sustituye a la pantalla de loot: una caja
abierta es un contenedor donde se coge y se deja lo que se quiera durante la visita (PMV §10).

## 2. Historias

- Como jugador, quiero construir un generador eólico para tener más batería y salir más tiempo a la zona.
- Como jugador, quiero recoger las baterías portátiles que el generador ha fabricado mientras no jugaba, y
  usarlas para recargar fuera de la estación.
- Como jugador, quiero cofres en la base para guardar materiales y piezas que no pierdo al morir.
- Como jugador, quiero repartir una pila entre mi inventario y un cofre eligiendo cuántas unidades y a qué
  ranura van, para organizarme sin pasos de más.
- Como jugador, quiero coger de una caja de loot solo lo que me interesa y dejar en ella lo que no, para hacer
  sitio sin tirarlo al suelo, sabiendo que lo pierdo en la visita siguiente.
- Como desarrollador de la spec 014 (piezas), quiero que la bonificación del generador sea un dato aplicado a
  la batería máxima, para sumarla a la del Core sin rehacerla.
- Como desarrollador de v1.1 (bancos avanzados, SPECS §3), quiero las baterías portátiles ya como item, para que
  los bancos nuevos las consuman como ingrediente.

## 3. Requisitos (EARS)

### 3.1 Datos

| ID | Requisito | Fuente |
|---|---|---|
| R-012-01 | THE `DataCatalog` SHALL list one `StructureData` for the wind generator (`wind_generator`) and one for the storage chest (`storage_chest`), each with its scene, its footprint and a name from a translation key in ES and EN. | ACTION_PLAN 2.5, 2.6, BALANCE §5.6, architecture §8 — pregunta 1 |
| R-012-02 | THE `DataCatalog` SHALL list one recipe per structure of R-012-01, `WORKBENCH`, tier 1, with no requirements, whose result is that structure and whose ingredients are those of BALANCE §5.2 (generator) and §5.4 (chest). | ACTION_PLAN 2.5, 2.6, BALANCE §5.1, §5.2, §5.4, §5.5, R-011-05 |
| R-012-03 | THE maximum number of each structure in the base SHALL be data of that structure: the chest's from BALANCE §5.4, the generator's from BALANCE §5.2 (pregunta 2), and none for the charging station (BALANCE §5.3); no script SHALL hold that limit as a literal. | BALANCE §5.3, §5.4, Constitución P2 — pregunta 2 |
| R-012-04 | THE generator's numbers (maximum battery bonus, time per portable battery and maximum stored) SHALL live in one data resource with the values of BALANCE §5.2. | BALANCE §5.2, Constitución P2, P5 |
| R-012-05 | THE `DataCatalog` SHALL list an `ItemData` for the portable battery (`portable_battery`) with the stack maximum of BALANCE §2, an icon and a name from a translation key in ES and EN; the points it restores (BALANCE §1.1) SHALL be data, not a literal. | BALANCE §1.1, §2, R-005-31, Constitución P2, P11 — pregunta 3 |
| R-012-06 | THE chest capacity SHALL be data with the value of BALANCE §5.4, and the capacity of an opened loot box (R-012-37) SHALL read that same value. | BALANCE §1.3, §5.4, §7.2, Constitución P2 |

### 3.2 Construir y mover

| ID | Requisito | Fuente |
|---|---|---|
| R-012-07 | THE build section of the bench screen SHALL list the generator and the chest, and building them SHALL follow the same flow as the charging station: placement mode, payment on confirming the placement, `structure_built` and save (R-009-35, R-009-38, R-009-39, R-009-64, R-009-65, R-010-42). | ACTION_PLAN 2.5, 2.6, 2.8, BALANCE §5.5 (nota) — pregunta 10 |
| R-012-08 | IF the base already holds the maximum number of a structure (R-012-03), THEN its "Build" button SHALL be disabled with a notice that the limit is reached, before any material is spent. | ACTION_PLAN 2.6, BALANCE §5.4, PMV §10 (base llena) |
| R-012-09 | IF a placement is requested for a structure whose limit is reached, THEN `BaseStructures` SHALL refuse it with the same reason as R-012-08, charge nothing and change nothing. | architecture §9.2, §12 regla 2 |
| R-012-10 | WHEN a generator or a chest is moved in edit mode, THE game SHALL keep its state: the chest's contents, and the generator's stored batteries and generation progress. | ACTION_PLAN 2.8, BALANCE §5.6 |

### 3.3 Generador: batería máxima

| ID | Requisito | Fuente |
|---|---|---|
| R-012-11 | WHILE a wind generator is placed in the world's base, THE maximum battery of every player robot SHALL be its maximum without the generator plus the bonus of BALANCE §5.2. | BALANCE §5.2 ("permanente mientras exista"), PMV §2.1, Constitución P4 — preguntas 2 y 11 |
| R-012-12 | WHEN a generator is built, THE robot's maximum battery SHALL rise by the bonus, its current charge SHALL stay as it was, and `battery_changed` SHALL be emitted once. | BALANCE §5.2 — pregunta 6 |
| R-012-13 | THE low-battery threshold, the recharge at a station and the charge on respawn SHALL use the maximum of R-012-11. | BALANCE §1.1 (20 % de la máxima, 100 % de la máxima), §5.3 |
| R-012-14 | WHEN a World is loaded, THE saved charge of a robot SHALL be accepted up to the maximum of R-012-11, whatever order the persistent owners are loaded in. | R-010-24 (la máxima no se guarda), spec 010 §10.2 |

### 3.4 Generador: baterías portátiles

| ID | Requisito | Fuente |
|---|---|---|
| R-012-15 | THE number of batteries a generator holds at a time SHALL be computed by pure code from its stored count, its generation reference time, the current time and the data of R-012-04, with no scene. | ACTION_PLAN 2.5, Constitución P3, P13 |
| R-012-16 | WHILE a generator holds fewer batteries than the maximum of BALANCE §5.2, THE generator SHALL gain one battery for each full period of BALANCE §5.2 elapsed, counting the time while the app is closed and while the base is not loaded, and SHALL never hold more than that maximum. | BALANCE §5.2, PMV §2.1, architecture §14 (pregunta 2) — pregunta 4 |
| R-012-17 | WHILE a generator holds the maximum, THE elapsed time SHALL not accumulate: the next period SHALL start counting when a battery is taken from it. | BALANCE §5.2 ("máximo 3 almacenadas") — pregunta 4 |
| R-012-18 | WHEN a generator is built, THE generator SHALL hold 0 batteries and its first period SHALL start counting at that moment. | ACTION_PLAN 2.5 — pregunta 4 |
| R-012-19 | THE current time SHALL be read only through `ITimeService` (`GameManager.get_time_service()`), and IF the elapsed time is negative, THEN it SHALL count as 0. | architecture §10.1, §14 (pregunta 2), BALANCE §7.2 (misma regla), Constitución P10 |
| R-012-20 | WHEN the player interacts with a generator that holds batteries, THE generator SHALL move as many as fit into the player's inventory as `portable_battery` items and keep the rest; IF none fit, THEN the inventory full notice of R-005-20 SHALL show and nothing SHALL change. | ACTION_PLAN 2.5 ("Recoger"), architecture §9.1 — pregunta 7 |
| R-012-21 | THE generator SHALL show how many batteries it holds out of its maximum and, while it is not full, the time left until the next one, updated without reading state every frame. | ACTION_PLAN 2.5 ("mostrar baterías disponibles"), architecture §9.5 — pregunta 7 |
| R-012-22 | THE generator's model SHALL rotate its blades. | ACTION_PLAN 2.5 (verificación manual) |

### 3.5 Usar una batería portátil

| ID | Requisito | Fuente |
|---|---|---|
| R-012-23 | WHEN the player uses a portable battery, THE game SHALL remove one `portable_battery` from the player's inventory and add the points of BALANCE §1.1 to its battery through `BatteryComponent.add`, capped at the maximum, in one step. | BALANCE §1.1, PMV §2.1, R-003-09 — pregunta 3 |
| R-012-24 | IF the player's battery is full or the inventory holds no portable battery, THEN the use SHALL be refused with its own notice and nothing SHALL change. | architecture §9.2 — pregunta 3 |
| R-012-25 | THE player SHALL be able to use a portable battery from the inventory screen (a "Use" button for a selected portable battery) and with the `use_consumable` action. | ACTION_PLAN 4.1 (botón consumibles), plan 001 (`use_consumable` en el InputMap, `test_input_map.gd`), Constitución P8 — pregunta 3 |

### 3.6 Cofres y pantalla de transferencia

| ID | Requisito | Fuente |
|---|---|---|
| R-012-26 | THE chest SHALL keep its items in its own `InventoryComponent` with the capacity of R-012-06. | ACTION_PLAN 2.6, architecture §9.3 |
| R-012-27 | WHEN the local player interacts with a chest, THE game SHALL open, through `UIManager`, a container screen with the chest's slots as a 2x2 grid, the player's inventory, a quantity selector, a "Transfer" button and a "Take all" button. | ACTION_PLAN 2.6, architecture §9.5 — preguntas 8 y 12 |
| R-012-28 | WHEN the player taps a stack in either grid, THE screen SHALL select it, with the quantity selector of spec 008 set by default to the whole stack; tapping the selected slot again SHALL clear the selection. | PMV §10 (dividir y colocar pilas), ACTION_PLAN 2.6 |
| R-012-29 | WHEN a stack is selected and the player taps a slot of either grid, THE chosen quantity SHALL move to that slot: placed if the slot is empty, added up to its stack maximum if it holds the same item (the rest stays in the origin), and swapped with the slot's stack if it holds another item and the whole stack was chosen. | PMV §10, ACTION_PLAN 2.6 — pregunta 8 |
| R-012-30 | WHEN a stack is selected and the player presses "Transfer", THE chosen quantity SHALL move to the other grid, first into stacks of the same item and then into empty slots, as much as fits; the rest SHALL stay in the origin. | ACTION_PLAN 2.6 ("Transferir") — pregunta 8 |
| R-012-31 | WHEN the player presses "Take all", THE game SHALL move every stack of the container to the player's inventory, in slot order, as much as fits, as the take-all of R-005-19; what does not fit SHALL stay in the container and THE HUD SHALL show the inventory full notice of R-005-20. | R-005-19, R-005-20 — pregunta 12 |
| R-012-32 | THE move rules of R-012-29 to R-012-31 SHALL be pure code in `InventoryRules`, reusing its split rule (spec 008), and a move SHALL be all or nothing for what it moves, returning an `ActionResult`; an invalid request (slot out of range, quantity outside 1 to the stack) SHALL be reported with `push_error` and change nothing. | PMV §10 (reutiliza la regla de dividir), architecture §3, §9.2, Constitución P3 |
| R-012-33 | IF a move of R-012-29 would swap with only part of the origin stack, THEN it SHALL be refused and nothing SHALL change. | pregunta 8 |
| R-012-34 | EVERY move of a piece SHALL keep its durability and its `uid`, and two pieces SHALL never merge. | R-011-08, R-011-09, architecture §9.3 |
| R-012-35 | WHEN either inventory changes while the container screen is open, THE screen SHALL update both grids and clear a selection whose stack no longer exists; it SHALL not close by itself when the container becomes empty. | architecture §9.5, R-011-25 — pregunta 5 |
| R-012-36 | THE chests' contents SHALL survive leaving and entering the base, the robot's death (also in the base) and closing and reopening the game. | PMV §2.4 ("conservas cofres almacenados"), ACTION_PLAN 2.3 |

### 3.7 Cajas de loot como contenedor

| ID | Requisito | Fuente |
|---|---|---|
| R-012-37 | WHEN a loot box is opened (rolled on its first interaction, R-005-17, or restored opened from a save), THE box SHALL be a container with the capacity of R-012-06 that holds its rolled loot, and every interaction with it during the visit, also when it is empty, SHALL open the container screen of R-012-27 with the box in place of the chest; the box SHALL never be disabled for being empty. Sustituye a R-005-16, R-005-18 y R-005-21 (pantalla de loot); R-005-17, R-005-19 (con R-012-31) y R-005-20 se mantienen. | PMV §10 (coger el loot de una caja; tirar items y dejarlos en cajas), BALANCE §7.2 (caja como contenedor), ACTION_PLAN 2.6 — pregunta 5 |
| R-012-38 | THE items in an opened box, rolled or left by the player, SHALL stay in it for the rest of the visit, also after saving and reloading, and SHALL be lost when the zone's next visit starts. | BALANCE §7.2, R-010-27 |

### 3.8 Guardado

| ID | Requisito | Fuente |
|---|---|---|
| R-012-39 | THE World SHALL save each chest's contents and each generator's stored batteries and generation reference time, tied to the structure's `uid`, as new keys of the contract of spec 010 (R-010-25). | ACTION_PLAN 2.3 (cofres e items en cofres), 2.5 ("guardar estado"), architecture §10.2 |
| R-012-40 | THE maximum battery and the capacities SHALL not be saved; they SHALL be derived from data on load. | R-010-24, Constitución P2 |
| R-012-41 | WHEN a World is loaded, THE chests and generators SHALL emit only state signals, never fact signals. | architecture §7 (D15), §10.2 |
| R-012-42 | IF a saved chest or generator entry is invalid or names a structure that is not placed, THEN THE game SHALL report it with `push_error` and skip that entry, keeping the rest. | R-010-11, Constitución §2 (errores) |
| R-012-43 | A World saved before this spec SHALL load with no change in behaviour. | architecture §10.2 (campo opcional sin subir `schema_version`) |
| R-012-44 | WHEN batteries are taken from a generator, and WHEN a chest's container screen closes after its contents changed, THE game SHALL save the World. | PMV §10 (cuándo se guarda), R-010-42 — pregunta 9 |

### 3.9 Textos

| ID | Requisito | Fuente |
|---|---|---|
| R-012-45 | THE generator, the chests, the container screen, the use of a portable battery and their notices SHALL show player-visible text only from translation keys in ES and EN. | Constitución P11 |

### 3.10 Cerrar pantallas emergentes tocando fuera

| ID | Requisito | Fuente |
|---|---|---|
| R-012-46 | WHEN the player taps or clicks outside the panel of the pop-up screen on top of `UIManager` (bench, inventory, container), THE `UIManager` SHALL handle it as "back": the screen's `handle_back()` decides, and IF it does not handle it, THEN the screen SHALL close. | Decisión nov 2026 (pregunta 13), architecture §9.5, Constitución P8 |
| R-012-47 | THE tap or click of R-012-46 SHALL not reach the game: no attack, no joystick, no interaction and no tap on a screen below. | architecture §9.5 (el control del robot ignora la entrada con una pantalla abierta) — pregunta 13 |
| R-012-48 | THE placement screen SHALL keep using taps outside its buttons to pick cells and structures (R-009-55, R-009-60), and THE notice screen SHALL stay open (R-010-55). | R-009-55, R-009-60, R-010-55 — pregunta 13 |

Los valores numéricos (costes, bonificación de batería, periodo y máximo de baterías, puntos de una batería
portátil, capacidad y límite de cofres, huellas) se citan por su fuente; el spec no los fija.

## 4. Fuera de alcance

- Mantenimiento del generador (1 cable cada 24 h): v1.1 (BALANCE §5.2, nota).
- Bancos avanzados que consumen baterías portátiles (horno, ensamblador, reciclador): v1.1+ (SPECS §3).
- Cofres expandidos (20): v1.1 (BALANCE §5.4, PMV §9).
- Desmontar una estructura o recuperar sus materiales: fuera del PMV (BALANCE §5.6).
- Botón de consumibles en el HUD: ACTION_PLAN 4.1. Esta spec solo da la acción `use_consumable` y el botón
  "Usar" de la pantalla de inventario (pregunta 3).
- Baterías portátiles en las cajas de loot: la caja básica da 0 % (BALANCE §2.1).
- Dividir y colocar pilas dentro de la pantalla de inventario propia (Tab), sin contenedor: sigue como la deja
  la spec 008 (tirar). La colocación por ranura solo existe en la pantalla de contenedor.
- Batería máxima del Core equipado, `StatsComponent` y `StatModifier`: spec 014. La bonificación del generador se
  suma a la máxima que haya; la 014 decide cómo se integra en el cálculo de stats.
- Más ranuras por nivel de chasis: spec 013.
- Hora del servidor contra el cambio de hora del móvil: post-PMV; en el PMV se acepta (architecture §14,
  pregunta 2).
- SFX (ACTION_PLAN 4.3), animaciones de abrir el cofre y modelos definitivos (4.4). El generador gira sus aspas
  desde esta spec (R-012-22).
- Notificaciones genéricas de 3 s: ACTION_PLAN 4.1. Aquí se usa el mensaje corto del HUD que ya existe.
- Paso de la guía sobre el generador o los cofres: ACTION_PLAN 5.4 (la guía de PMV §2.1 no los pide).

## 5. Criterio de hecho

En la base, la pestaña "Construir" del banco lista el generador eólico y el cofre con su coste (BALANCE §5.2,
§5.4), y los dos se colocan y se mueven como la estación de carga. Al construir el generador, la batería máxima
sube con la bonificación de BALANCE §5.2 sin cambiar la carga actual, y una estación recarga hasta la nueva
máxima. El generador muestra cuántas baterías tiene y cuánto falta para la siguiente; con el tiempo (también
con la app cerrada) fabrica baterías hasta el máximo, e interactuar las pasa al inventario. Una batería
portátil se usa desde el inventario o con Q y suma sus puntos sin pasar de la máxima. Tras el quinto cofre (o el
máximo del generador) su botón se desactiva con aviso. Un cofre abre una pantalla 2x2 junto al inventario donde
una pila se divide y se coloca en la ranura elegida o se transfiere al otro lado; lo guardado sigue ahí tras
viajar, morir y reiniciar; "Coger todo" pasa al inventario todo lo que quepa. Una caja de loot abre la misma
pantalla desde la primera vez: se coge lo que se quiera, se deja lo que no y la caja no se desactiva al vaciarse;
lo que queda dentro se pierde en la visita siguiente. El banco, el inventario y el contenedor se cierran también
tocando (o haciendo clic) fuera de su panel, sin que ese toque ataque ni mueva al robot.

Tests en verde: recursos (estructuras, recetas, límites, datos del generador, batería portátil, capacidad);
generación de baterías por tiempo en código puro (periodos justos, de sobra, con el máximo lleno, tiempo
negativo, recogida que reinicia el periodo); batería máxima con y sin generador, carga guardada por encima de la
máxima base al cargar en cualquier orden; usar una batería (suma con tope, batería llena, sin baterías); reglas de
mover pilas (a vacía, mismo item con y sin tope, intercambio entero, intercambio parcial rechazado, piezas que
conservan `uid` y durabilidad, peticiones inválidas); límite de estructuras en el banco y en `BaseStructures`;
pantalla de contenedor (seleccionar, colocar, transferir, coger todo, se actualiza y no se cierra al vaciarse);
cofres que sobreviven a viaje, muerte y guardado; caja de loot como contenedor desde la primera apertura, también
restaurada de un guardado, y su pérdida en la visita siguiente; guardado y carga con
`MemorySaveStore`, entradas inválidas y mundo anterior a esta spec; cerrar tocando fuera (cierra la pantalla de
arriba, el toque no llega al juego, la colocación y el aviso de la spec 010 no se cierran). Las aspas que giran se comprueban a mano.

## 6. Preguntas abiertas

Todas cerradas (nov 2026). Las decisiones están en BALANCE.md §2, §5.2, §5.6 y §7.2, PMV.md §2.1 y §10
("Generador y cofres (spec 012)") y ACTION_PLAN.md Tareas 2.3, 2.5 y 2.6.

| # | Pregunta | Propuesta | ¿Bloquea? |
|---|---|---|---|
| 1 | ~~Huellas del generador y del cofre~~ | **Cerrada (nov 2026)**: cofre 1x1 y generador 2x2 (BALANCE §5.6). | — |
| 2 | ~~¿Cuántos generadores?~~ | **Cerrada (nov 2026)**: uno por base por ahora (BALANCE §5.2, R-012-03). El número con los mundos abiertos de v1.1 queda en PMV §10, "Decidir antes de empezar v1.1". | — |
| 3 | ~~Usar baterías portátiles~~ | **Cerrada (nov 2026)**: entra en esta spec (R-012-23 a R-012-25): botón "Usar" en la pantalla de inventario y `use_consumable` (Q); el botón del HUD sigue en ACTION_PLAN 4.1. En cualquier sitio, también en la base; con la batería llena no se gasta (BALANCE §1.1). Además, la pila máxima de la batería portátil baja de 10 a 5 (BALANCE §2). | — |
| 4 | ~~Reloj del generador~~ | **Cerrada (nov 2026)**: empieza vacío, cuenta con la app cerrada y con la base sin cargar, no acumula tiempo con el máximo lleno (el periodo siguiente empieza al recoger) y el tiempo negativo vale 0 (BALANCE §5.2, R-012-16 a R-012-19). | — |
| 5 | ~~Cuándo una caja de loot pasa a contenedor~~ | **Cerrada (nov 2026), distinta de la propuesta**: siempre, desde que se abre, no solo al vaciarse. Se coge lo que se quiera y se deja lo que no; la pantalla de contenedor sustituye a la de loot de la spec 005 y la caja no se desactiva al vaciarse (R-012-37, R-012-38). BALANCE §7.2 y PMV §10 actualizados. | — |
| 6 | ~~Carga al construir el generador~~ | **Cerrada (nov 2026)**: sube la máxima y la carga se queda (BALANCE §5.2, R-012-12). | — |
| 7 | ~~Cómo se ve y se recoge el generador~~ | **Cerrada (nov 2026)**: rótulo 3D con "n/máximo" y el tiempo hasta la siguiente; interactuar (prompt `PROMPT_COLLECT`) recoge lo que quepa, sin pantalla; con 0 baterías, aviso con el tiempo que falta (R-012-20, R-012-21). | — |
| 8 | ~~Detalles de la pantalla de contenedor~~ | **Cerrada (nov 2026)**: tocar destino (también dentro de la misma rejilla) y "Transferir" (R-012-29, R-012-30); solo se intercambian pilas enteras (R-012-33). | — |
| 9 | ~~Cuándo se guarda~~ | **Cerrada (nov 2026)**: al recoger baterías y al cerrar la pantalla de un cofre cuyo contenido cambió (R-012-44). Usar una batería no guarda. Lo que se coge o se deja en una caja de loot se guarda con el siguiente guardado normal, como hasta ahora. PMV §10 y ACTION_PLAN 2.3 actualizados. | — |
| 10 | ~~ACTION_PLAN 2.5, "Construir (primera vez)" en el propio generador~~ | **Cerrada (nov 2026)**: se construye en el banco y se coloca como el resto (R-012-07); ACTION_PLAN 2.5 corregido. | — |
| 11 | ~~Batería máxima en el cooperativo (v2.0)~~ | **Cerrada (nov 2026)**: sube a todos los robots del mundo; el generador es estado de la base (R-012-11). La spec 014 lo integra con la máxima del Core. | — |
| 12 | ~~"Coger todo" en la pantalla de contenedor~~ | **Cerrada (nov 2026)**: se mantiene el de la spec 005 (R-005-19), en cajas y en cofres (R-012-27, R-012-31). | — |
| 13 | ~~Cerrar emergentes tocando fuera~~ | **Cerrada (nov 2026)**: añadido a esta spec a petición del usuario. Hoy solo se cierran con Escape, atrás o el botón de almacén. Tocar o hacer clic fuera del panel de la pantalla de arriba cuenta como "atrás" (R-012-46), también en PC (Constitución P8), y ese toque no llega al juego (R-012-47). La colocación y el aviso de versión no cambian (R-012-48). El plan añade la regla a architecture §9.5. | — |
