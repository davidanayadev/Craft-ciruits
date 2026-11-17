# Spec 008 — Muerte, `RulesetData`, objetos caídos y recuperación

| Campo | Valor |
|---|---|
| **Estado** | Hecho (2026-11-16) |
| **Tarea(s) ACTION_PLAN** | 1.5 |
| **Fuentes** | ACTION_PLAN.md Tarea 1.5 (y 2.1, 2.3, 3.1, 4.1, 4.3, 4.4 para los límites) · PMV.md §2.1, §2.3, §2.4, §3.2, §4.5 ganchos 2, 4 y 7, §10 (cajas y viaje, combate) · BALANCE.md §1.1, §2.1, §3.1, §7.2, §8.1, §11 · SPECS.md §27 (Hardcore, v1.1) · architecture.md §3, §5, §6, §7, §8, §9.1, §9.3, §10.1, §10.2, §10.3, §11 · Constitución P2, P3, P4, P6, P9, P10, P11, P12, P13, P14 |
| **Depende de** | 003 (`BatteryComponent`, game over provisional), 004 (`FarmZone`, cajas, `SeededRng`, `InteractableComponent`), 005 (`InventoryComponent`, `UIManager`, pantalla de inventario), 006 (zombies, `ZombieSpawner`, número de visita, `ObjectPool`), 007 (`EventBus`, `player_uid`, `ExperienceComponent`; debe estar *Hecho* antes de implementar esta) |
| **Rama** | `feat/008-death-recovery` |

## 1. Objetivo

Dar consecuencias reales a quedarse sin batería. Hoy el juego se reinicia con una pantalla provisional; con esta
spec el robot muere, suelta lo que lleva donde cayó, reaparece con la batería llena y puede volver a por sus
cosas antes de que caduquen, con la zona ya repuesta. La reacción a la muerte sale del ruleset del mundo, para
que el Hardcore de v1.1 sea otro dato y no otro código. El mismo objeto caído sirve para el material de los
zombies y para tirar items del inventario.

## 2. Historias

- Como jugador, quiero que morir duela pero no sea el final, para arriesgarme sin miedo a perder la partida.
- Como jugador, quiero encontrar mis cosas donde morí, para decidir si vuelvo a por ellas.
- Como jugador, quiero que esa ventana tenga un límite y que la zona esté repuesta al volver, para que la
  recuperación sea una decisión con riesgo.
- Como jugador, quiero que los zombies suelten material, para que pelear dé algo más que XP.
- Como jugador, quiero tirar lo que no me sirve, para hacer sitio en el inventario.
- Como desarrollador del Hardcore (v1.1), quiero la reacción a la muerte como dato del mundo, para añadir otro
  modo sin tocar la mecánica.
- Como desarrollador del guardado (spec 010), quiero el contador de visitas y los objetos caídos como estado
  del mundo en tipos simples, para guardarlos sin cambiarlos.

## 3. Requisitos (EARS)

### 3.1 Ruleset y datos

| ID | Requisito | Fuente |
|---|---|---|
| R-008-01 | THE game SHALL define a `RulesetData` resource with a stable id and the fields that describe the death reaction of PMV §2.4, and one `.tres`, `NORMAL`, listed in the `DataCatalog`. | ACTION_PLAN 1.5, PMV §4.5 gancho 4, architecture §8 |
| R-008-02 | ~~THE `GameManager` SHALL hold the ruleset of the current world, taken from the dev world config until spec 010 reads it from the World file.~~ **Sustituido por R-010-20** (spec 010, 2026-11-17): el ruleset viene del Mundo cargado o creado. | architecture §5, PMV §4.5 gancho 4 |
| R-008-03 | THE reaction to a player's death SHALL be read from the world's `RulesetData`; no script SHALL branch on a ruleset id or name. | ACTION_PLAN 1.5, PMV §2.4 |
| R-008-04 | THE battery after reappearing (BALANCE §1.1), the lifetime of dropped objects (BALANCE §7.2) and the duration of the transfer screen (BALANCE §11) SHALL come from data resources, not script literals. | Constitución P2 — pregunta 5 |
| R-008-05 | THE `EnemyData` resource SHALL gain a drop table, and the slow and fast zombie `.tres` SHALL carry the material of BALANCE §3.1, rolled with the range rule of BALANCE §2.1. | ACTION_PLAN 1.5, BALANCE §2.1, §3.1 — pregunta 6 |

### 3.2 Contador de visitas y reposición

| ID | Requisito | Fuente |
|---|---|---|
| R-008-06 | THE game SHALL keep one visit counter per `zone_id` as world state, outside any player entity, starting at 0 and never going up on entering or loading. | BALANCE §7.2, architecture §5 — pregunta 2 |
| R-008-07 | WHEN a player dies in a zone, THE visit counter of that zone SHALL go up by exactly one. | ACTION_PLAN 1.5, BALANCE §7.2, PMV §10 |
| R-008-08 | THE contents of each box SHALL come from world seed + `zone_id` + box index + visit number, while the number and position of the boxes keep coming from world seed + `zone_id` only. | BALANCE §2.1, §7.2 — pregunta 2 |
| R-008-09 | WHEN the visit counter of the loaded zone goes up, THE zone SHALL be repopulated for the new visit: its enemies replaced by those of the new visit and every box closed again with the contents of the new visit, discarding what was left inside. | ACTION_PLAN 1.5, BALANCE §7.2 — pregunta 2 |

### 3.3 Objeto caído

| ID | Requisito | Fuente |
|---|---|---|
| R-008-10 | THE game SHALL have a dropped object (`DroppedItem`) that holds one or more `ItemStack`s, a `uid`, its `(zone_id, local position)` and the time it was dropped. | ACTION_PLAN 1.5, PMV §4.5 gancho 2, architecture §10.3 — pregunta 3 |
| R-008-11 | THE dropped object SHALL keep the item, quantity, durability and `uid` of every stack unchanged: dropping and picking up never create or lose items. (`ItemStack` gains durability and `uid` in spec 014; until then only item and quantity can be checked, and spec 014 must carry them through `InventoryRules`.) | architecture §9.3 |
| R-008-12 | THE dropped object SHALL be interactable through `InteractableComponent`, with a pick-up prompt whose text comes only from translation keys in ES and EN. | architecture §9.1, Constitución P11 |
| R-008-13 | WHEN a player interacts with a dropped object, THE player's `InventoryComponent` SHALL take every stack that fits, in slot order. | ACTION_PLAN 1.5 — pregunta 3 |
| R-008-14 | WHEN a dropped object is left with no stacks, THE dropped object SHALL disappear and go back to its pool. | architecture §11 |
| R-008-15 | IF some stacks do not fit, THEN THE dropped object SHALL stay with the rest and its original drop time, and THE game SHALL show the inventory-full notice of spec 005. | Spec 005 R-005-20, BALANCE §7.2 |
| R-008-16 | THE dropped objects of a zone SHALL be world state of that zone: they stay through a repopulation and a new visit until they are picked up or expire. | BALANCE §7.2, PMV §10 |
| R-008-17 | THE state of a dropped object SHALL be expressible with JSON types only (ids, numbers, texts), so spec 010 can save it without changing it. | architecture §10.2 |
| R-008-18 | THE dropped objects SHALL come from an `ObjectPool`, and a reused one SHALL carry nothing from its previous use. | architecture §11, Constitución P12 |

### 3.4 Caducidad

| ID | Requisito | Fuente |
|---|---|---|
| R-008-19 | THE game SHALL define the `ITimeService` contract (`now_unix() -> int`) with a `LocalTimeService` that reads the device clock; the drop time SHALL be read only through it, and tests SHALL use a fake clock. | architecture §10.1, Constitución P10, P13 — pregunta 8 |
| R-008-20 | WHEN a dropped object is created, THE game SHALL record `now_unix()` as its drop time. | BALANCE §7.2 |
| R-008-21 | THE expiry rule SHALL be pure code: an object is expired when the time since its drop reaches the lifetime of BALANCE §7.2, and a negative elapsed time counts as 0. | BALANCE §7.2, PMV §10, Constitución P3 |
| R-008-22 | WHILE its zone is loaded, THE dropped object whose lifetime ends SHALL disappear without giving its items to anyone. | BALANCE §7.2 — pregunta 9 |
| R-008-23 | WHEN a zone is populated or repopulated, THE game SHALL discard its expired dropped objects before any player can interact with them. | ACTION_PLAN 1.5, PMV §10 |
| R-008-24 | THE expiry SHALL depend only on the drop time and the clock: never on the visit counter, an open screen or the frame rate. | BALANCE §7.2 |

### 3.5 Muerte y reaparición (ruleset `NORMAL`)

| ID | Requisito | Fuente |
|---|---|---|
| R-008-25 | WHEN a robot's battery is depleted, THE game SHALL emit `EventBus.player_died(player_uid)` exactly once per death, whatever emptied the battery (drain, a swing or a hit). | ACTION_PLAN 1.5, architecture §7 |
| R-008-26 | WHEN a player dies, THE game SHALL move every stack of its inventory into one dropped object at the death position, recorded as `(zone_id, local position)`. | ACTION_PLAN 1.5, PMV §2.4, §4.5 gancho 2 — pregunta 3 |
| R-008-27 | IF the player dies with an empty inventory, THEN THE game SHALL create no dropped object. | PMV §2.4 |
| R-008-28 | WHEN a player dies, THE robot SHALL keep its XP total and the slot count of its inventory unchanged. | PMV §2.4, BALANCE §2 (XP) |
| R-008-29 | WHEN the local player dies, THE game SHALL close every `UIManager` screen, block the robot's input and show the "Transferencia de Consciencia" screen, with texts only from translation keys in ES and EN. | ACTION_PLAN 1.5, PMV §2.4, Constitución P11 — pregunta 5 |
| R-008-30 | WHILE the transfer screen is shown, THE robot SHALL not move, attack, interact or take hits. | Spec 006 R-006-18 — pregunta 5 |
| R-008-31 | WHEN the transfer ends, THE robot SHALL reappear at the respawn point with the battery of BALANCE §1.1 and its input unblocked, and THE game SHALL emit `EventBus.player_respawned(player_uid)` once. | ACTION_PLAN 1.5, BALANCE §1.1, architecture §7 — pregunta 1 |
| R-008-32 | WHEN a robot that already reappeared dies again, THE game SHALL create a new dropped object with its own drop time, leaving the earlier ones untouched. | PMV §2.4 |
| R-008-33 | THE game SHALL no longer show the provisional game over screen nor reload the scene when the battery is depleted (replaces R-003-12). | Spec 003 §4 |
| R-008-34 | THE battery, inventory, XP and death position of a player SHALL live in its entity or in the dropped object; `GameManager` SHALL hold only world state (seed, ruleset, visit counters) and the time service. | PMV §4.5 gancho 7, Constitución P4 |

### 3.6 Material de los zombies

| ID | Requisito | Fuente |
|---|---|---|
| R-008-35 | WHEN an enemy with a drop table dies from a player's hit, THE game SHALL roll its table once and, if the roll gives any item, create a dropped object where the enemy died. | ACTION_PLAN 1.5, BALANCE §3.1, PMV §10 (combate) |
| R-008-36 | THE roll SHALL come from `SeededRng` with world seed + `zone_id` + visit number + the spawn index of that enemy, so it depends neither on the order of the kills nor on reloading. | ACTION_PLAN 1.5, Constitución P9 |
| R-008-37 | THE dropped object of an enemy SHALL follow the same pick-up and expiry rules as any other. | BALANCE §7.2 — pregunta 6 |

### 3.7 Tirar items del inventario

| ID | Requisito | Fuente |
|---|---|---|
| R-008-38 | WHEN the player taps a stack in the inventory screen, THE screen SHALL select it and show a quantity selector (− / + and a slider) that goes from 1 to the size of the stack and starts at the whole stack (replaces the "display only" cells of plan 005). | PMV §10 — preguntas 7 y 11 |
| R-008-39 | WHEN the player presses the throw button with a stack selected, THE robot's inventory SHALL lose the chosen quantity from that slot, the rest SHALL stay in it, and a dropped object holding the thrown quantity SHALL appear at the robot's position. | ACTION_PLAN 1.5, PMV §10 — preguntas 7 y 11 |
| R-008-40 | THE rule that splits a stack (what leaves, what stays, invalid quantities rejected with no change) SHALL be pure code, so the transfer screen of the chests spec can reuse it. | Constitución P2, P3 — pregunta 11 |
| R-008-41 | IF no stack is selected, THEN THE throw button SHALL be disabled and nothing SHALL change. | Constitución §2 (errores) — pregunta 7 |
| R-008-42 | THE inventory screen SHALL only request the throw: the change SHALL be made by the components that own the state, and the texts of the button and the selector SHALL come from translation keys in ES and EN. | architecture §3 regla 2, Constitución P11 |
| R-008-43 | THE thrown object SHALL follow the same pick-up and expiry rules as any other. | BALANCE §7.2 |

### 3.8 Bucle completo

| ID | Requisito | Fuente |
|---|---|---|
| R-008-44 | WHEN a robot carrying items dies in the green zone, THE player SHALL be able to reappear with a full battery and an empty inventory, walk back among the enemies of the new visit and get the same stacks back by interacting with the dropped object. | ACTION_PLAN 1.5 (test) |
| R-008-45 | WHILE the zone holds its maximum of zombies and the dropped objects of a normal session, THE game SHALL keep ≥ 30 FPS on the mid-range Android device, with the dropped object inside the budget of PMV §3.2. | PMV §3.2, Constitución P12 |

Los valores numéricos (batería al reaparecer, duración de la ventana, material de los zombies, duración de la
transferencia) se citan por su fuente; el spec no los fija.

## 4. Fuera de alcance

- Escena de la base, `ZoneLoader`, puntos de salida y viaje entre zonas: spec 009 (ACTION_PLAN 2.1). Subir el
  contador de visitas **al salir** por el punto de salida también es de la 009; aquí solo sube al morir. Morir
  dentro de la base (PMV §2.4, §10) usa estas mismas reglas cuando exista la base (pregunta 1).
- Guardar el contador de visitas, los objetos caídos con su hora y descartar los caducados **al cargar la
  partida**: spec 010 (ACTION_PLAN 2.3), que reutiliza la regla de R-008-21. Guardar las cajas abiertas dentro
  de una visita: spec 010. En la 008 todo vive en memoria y se pierde al cerrar el juego.
- Perder las piezas equipadas y conservar el Core: spec 014 (ACTION_PLAN 3.1), que crea `EquipmentComponent`
  (pregunta 4).
- Red de seguridad con "piezas medio rotas" garantizadas (PMV §2.4 punto 5): sin valores en BALANCE (pregunta
  10).
- Modo Hardcore, Respaldo de consciencia y salón de la fama: v1.1 (PMV §2.3, SPECS §27). Aquí solo existe
  `NORMAL`.
- Dejar items en una caja vaciada: spec de cofres (ACTION_PLAN 2.6).
- Mover una pila, o una parte, a la ranura que elijas y repartirla entre el inventario y un contenedor: spec de
  cofres (ACTION_PLAN 2.6), con "tocar la pila y tocar el destino" y la regla de dividir de R-008-40 (pregunta
  11). La 008 solo divide al tirar.
- Marcador del lugar de la muerte en el minimapa y cuenta atrás de la caducidad en el HUD: ACTION_PLAN 4.1
  (pregunta 9).
- Animación de muerte del robot, animación pulida de la transferencia y efectos al recoger: ACTION_PLAN 4.4.
  SFX de muerte y de recogida: ACTION_PLAN 4.3.
- Drops del robot hostil (BALANCE §3.2): spec 015, que reutiliza el objeto caído y la tabla de `EnemyData`.
- Dueño de un objeto caído y quién puede recogerlo en cooperativo: ONLINE.md (v2.0).
- Analítica de zonas de muerte: TOOLING.md (v1.5).

## 5. Criterio de hecho

En la zona verde, con chatarra en el inventario, dejar que la batería llegue a 0 (por consumo, por un golpe
propio o por un zombie) ya no enseña "Batería agotada" ni reinicia la escena: se cierra cualquier pantalla,
aparece "Transferencia de Consciencia" y, al terminar, el robot está en el punto de reaparición con la batería
al 100 % (BALANCE §1.1), el inventario vacío, las mismas ranuras y la misma XP. Los zombies son los de la visita
siguiente y las cajas vuelven a estar cerradas con otro contenido. Donde murió hay un objeto caído con el
prompt de recoger; al interactuar, las pilas vuelven al inventario tal como estaban, y si no caben todas aparece
"Inventario lleno" y el resto se queda. Pasados 5 minutos (BALANCE §7.2) el objeto desaparece. Un zombie muerto
deja a veces 1 de chatarra en el suelo (BALANCE §3.1), siempre la misma con la misma semilla y visita. En la
pantalla de inventario se puede seleccionar una pila, elegir con − / + cuántas unidades (por defecto todas) y
tirarlas: caen a los pies del robot, el resto sigue en su ranura y lo tirado se puede volver a recoger.

Tests en verde: regla de caducidad (límite exacto, tiempo negativo, reloj falso), `RulesetData` `NORMAL` en el
catálogo y reacción leída del ruleset, contador de visitas (empieza en 0, sube una vez por muerte, no sube al
generar), contenido de las cajas por visita y posiciones estables, repoblación de la zona, soltar y recoger sin
crear ni perder items (también parcial), objeto reutilizado limpio, `player_died` y `player_respawned` una vez
por muerte, XP y ranuras intactas, muerte con el inventario vacío, dos muertes seguidas, tirada del zombie
determinista, regla de dividir (entera, parcial, cantidades inválidas), tirar una pila entera y una parte, e
integración "al morir, el robot reaparece con la batería al 100 %, sin items, y los items quedan en la zona"
(ACTION_PLAN 1.5). Probado en PC y en el Android de gama media (toca UI, input y rendimiento).

## 6. Preguntas abiertas

| # | Pregunta | Propuesta | ¿Bloquea? |
|---|---|---|---|
| 1 | ~~Reaparecer sin base~~ | **Cerrada (nov 2026)**: en la 008 el robot reaparece en el `SpawnPoint` de la zona, que hace de base provisional; el punto de reaparición se decide en un solo sitio y la 009 lo cambia por `ZoneLoader.travel_to(base)`. Descartado: hacer antes la 009. | — |
| 2 | ~~Dueño del contador de visitas y de la reposición de cajas~~ | **Cerrada (nov 2026)**: la 008 crea el contador en memoria (estado del mundo en `GameManager`), lo sube al morir, mete la visita en la semilla de las cajas y repuebla la zona. La 009 lo sube al salir por el punto de salida. La 010 solo lo guarda, junto con las cajas abiertas de la visita. BALANCE §7.2 corregido. `SeededRng.derive_seed` tiene un solo índice y hacen falta dos (caja + visita, zombie + visita): el plan elige cómo, ahora que no hay partidas guardadas que migrar. | — |
| 3 | ~~Forma del objeto caído y cómo se recoge~~ | **Cerrada (nov 2026)**: un solo objeto por muerte con todas las pilas; el zombie y el item tirado crean un objeto con una pila. Interactuar coge directamente todo lo que quepa, sin pantalla; el resto se queda. Descartado: un objeto por pila y abrir la pantalla de caja. | — |
| 4 | ~~Piezas equipadas~~ | **Cerrada (nov 2026)**: la 008 suelta solo el inventario. `RulesetData` declara qué se conserva (Core y XP) y la spec 014 lo aplica a las piezas: brazos y piernas van al mismo objeto caído con su durabilidad y su `uid` (recuperables, no destruidos); el Core se queda. | — |
| 5 | ~~Pantalla de transferencia: duración y cómo termina~~ | **Cerrada (nov 2026)**: termina sola, sin botón, a los 2,0 s (BALANCE §11, "Muerte"). Texto traducido sobre un fundido como marcador; la animación definitiva es de ACTION_PLAN 4.4. Mientras dura, el mundo queda congelado. | — |
| 6 | ~~Material de los zombies: caducidad y probabilidad~~ | **Cerrada (nov 2026)**: misma regla que todo objeto caído (BALANCE §7.2). "0-1 chatarra" con la regla de rangos de §2.1: la mitad de las veces no cae nada (BALANCE §3.1). | — |
| 7 | ~~Cómo se tira un item~~ | **Cerrada (nov 2026)**: tocar una pila la selecciona y un botón "Tirar" suelta la cantidad elegida (pregunta 11), sin confirmación y sin cerrar la pantalla. El objeto cae en la posición del robot. | — |
| 8 | ~~`ITimeService` no existe todavía~~ | **Cerrada (nov 2026)**: la 008 crea `ITimeService` y `LocalTimeService` (architecture §10.1). El plan decide qué autoload lo expone; la regla de caducidad recibe la hora por parámetro. | — |
| 9 | ~~Aviso de caducidad~~ | **Cerrada (nov 2026)**: el objeto desaparece al cumplirse su tiempo, también a la vista. Sin cuenta atrás ni marcador en la 008; se decide con el HUD (ACTION_PLAN 4.1) y el playtesting (5.1). | — |
| 10 | ~~Red de seguridad de PMV §2.4 punto 5~~ | **Cerrada para la 008 (nov 2026)**: fuera de alcance. Trasladada a PMV §10 como pregunta abierta, a decidir con la spec 014. | — |
| 11 | ~~Dividir pilas~~ (pedido en la revisión; la spec 005 lo dejaba fuera del PMV) | **Cerrada (nov 2026)**: sí se pueden dividir. Al seleccionar una pila aparece un selector de cantidad (− / + y deslizador, por defecto la pila entera) y la acción usa esa cantidad. La 008 lo aplica a tirar y deja la regla de dividir como código puro. Mover la pila o una parte a la ranura que elijas, y repartirla entre inventario y contenedores, llega con la spec de cofres, con "tocar la pila y tocar el destino" (se mueve, se suma si es el mismo item o se intercambia si es otro). Descartado: botón de dividir a la mitad y arrastrar y soltar. | — |

