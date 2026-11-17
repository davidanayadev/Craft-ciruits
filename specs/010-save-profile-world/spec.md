# Spec 010 — Guardado en dos niveles (Perfil y Mundo) e `IStore`

| Campo | Valor |
|---|---|
| **Estado** | Aprobado (2026-11-17) |
| **Tarea(s) ACTION_PLAN** | 2.3 (y la parte de guardado de 2.2 y 2.8) |
| **Fuentes** | ACTION_PLAN.md Tarea 2.3 (y 1.5, 2.2, 2.5, 2.6, 2.7, 2.8, 3.1, 4.1, 4.2 para los límites) · PMV.md §2.1 (persistencia), §2.3, §3 (guardado local, savegame corrupto), §4.5 ganchos 1, 2, 7 y 8, §10 (cajas y viaje; guardado de la spec 009) · BALANCE.md §5.3, §7, §7.2 · SPECS.md §23, §26, §27 (v1.1) · ONLINE.md "Preparación del código desde el PMV" puntos 1, 4, 7 y 9 · TOOLING.md §3, "Resumen de decisiones por fase" (`IStore` + `LocalStore` en el PMV) · architecture.md §3, §5, §7, §8, §10, §12, §13 · Constitución P2, P3, P4, P9, P10, P11, P13, P14 |
| **Depende de** | 003 (`BatteryComponent`), 004 (cajas, `ZoneData`, `SeededRng`), 005 (`InventoryComponent`, `ItemStack`, aviso del HUD), 007 (`ExperienceComponent`, `player_uid`, `EventBus`), 008 (contador de visitas, objeto caído, `ITimeService`, regla de caducidad, `RulesetData`), 009 (`ZoneLoader`, base, estructuras colocadas, aviso de recarga); 007, 008 y 009 deben estar *Hecho* antes de implementar esta |
| **Rama** | `feat/010-save-profile-world` |

## 1. Objetivo

Que cerrar el juego no borre la partida. Hoy cada arranque es un mundo nuevo (PMV §10, spec 009); con esta spec
el progreso se escribe en disco en dos archivos: el **Perfil**, que sobrevive a los mundos, y el **Mundo**, uno
por partida. El formato nace versionado, con copia de seguridad y con cada componente dueño de su propia
serialización, para que el Hardcore, las compras y el cooperativo de v1.1+ no obliguen a rehacerlo. La tienda
queda detrás de `IStore` con una implementación local que siempre dice "demo".

## 2. Historias

- Como jugador, quiero cerrar el juego y seguir donde lo dejé, para jugar en sesiones cortas.
- Como jugador, quiero que una partida dañada no me deje sin nada, para no perder horas por un corte de batería.
- Como jugador, quiero saber cuándo se ha guardado, para decidir si puedo cerrar.
- Como desarrollador de v1.1, quiero que los guardados del PMV sigan cargando tras un cambio de formato, para no
  romper las partidas de quien probó la demo.
- Como desarrollador de los specs siguientes (cofres, generador, nivel de chasis, piezas), quiero añadir un
  componente persistente sin tocar `SaveManager`, para que el guardado no crezca con cada feature.
- Como desarrollador del desbloqueo de pago (v1.1), quiero que el juego pregunte los derechos a `IStore`, para
  cambiar la implementación sin tocar el juego.

## 3. Requisitos (EARS)

### 3.1 Servicios y orquestación

| ID | Requisito | Fuente |
|---|---|---|
| R-010-01 | THE game SHALL define the `ISaveStore` contract (read and write the bytes of a Profile and of a World, delete a World, with a backup copy of each) as a base class whose methods report an error when not overridden, and a `LocalSaveStore` that keeps the files under `user://`. | architecture §10.1, Constitución P10 |
| R-010-02 | THE game SHALL have a `SaveManager` autoload with `save_game()`, `load_game()`, `delete_save()`, `save_profile()` and `load_profile()`, which receives its `ISaveStore` at startup; no other code SHALL create or call a save store. | ACTION_PLAN 2.3, architecture §5, §10.1 |
| R-010-03 | THE `SaveManager` SHALL only orchestrate: it SHALL not know the fields of any component or world-state owner, and it SHALL hold no player state between a save and the next one. | architecture §5, §10.2, Constitución P4 |
| R-010-04 | THE operations of `SaveManager` that can fail SHALL return an `ActionResult` and report the cause with `push_error()`; none SHALL fail silently. | architecture §9.2, Constitución §2 (errores) |
| R-010-05 | THE assembly of a save document from the parts of its owners, its validation and its migration SHALL be pure code, testable without files or scene tree. | Constitución P3, P13 |

### 3.2 Contrato de serialización

| ID | Requisito | Fuente |
|---|---|---|
| R-010-06 | Every owner of persisted state (player components and world-state owners) SHALL expose `get_save_key() -> StringName`, `to_save_data() -> Dictionary` and `from_save_data(data: Dictionary) -> void`; the player components SHALL be in the `persistent` group. | architecture §10.2 |
| R-010-07 | THE game SHALL have a test that fails when a node of the `persistent` group lacks one of the three methods or when two owners share a save key. | architecture §10.2 |
| R-010-08 | `to_save_data()` SHALL return only JSON types: definitions as stable ids, unique instances by `uid`, positions as `(zone_id, local position)` or `(zone_id, cell)`; never a Godot `Resource`, a node path or a file path. | architecture §8, §10.2, §12 regla 5, PMV §4.5 gancho 2 |
| R-010-09 | FOR every owner, `from_save_data(to_save_data())` SHALL leave it in the same state and emit its usual change signals, so the HUD and the screens refresh without special code. | architecture §13 (ida y vuelta) |
| R-010-10 | IF the saved data lacks the key of an owner, THEN that owner SHALL keep its new-game state and the load SHALL go on. | ACTION_PLAN 2.3 (migración) — pregunta 10 |
| R-010-11 | IF the saved data names an id that the `DataCatalog` no longer has, THEN the owner SHALL skip that entry, report it with `push_error()` and load the rest. | architecture §8, Constitución §2 (errores) |

### 3.3 Perfil

| ID | Requisito | Fuente |
|---|---|---|
| R-010-12 | THE Profile SHALL hold `schema_version`, a `player_uuid`, the purchase `entitlements`, the hall of fame, the unlocked cosmetics and the unlocked blueprints; the last four SHALL be empty in the MVP. | ACTION_PLAN 2.3, PMV §4.5 gancho 1 |
| R-010-13 | WHEN the game starts and no Profile exists, THE game SHALL create one with a locally generated `player_uuid` (architecture §10.3) and write it at once. | ACTION_PLAN 2.3, ONLINE.md punto 4 |
| R-010-14 | THE `player_uuid` SHALL not change once created, and THE local robot SHALL take it as its `player_uid` (replaces the startup uid of R-007-18). | Spec 007 R-007-18, architecture §10.3 |
| R-010-15 | THE Profile SHALL be a file separate from every World: deleting a World SHALL leave the Profile and its backup unchanged. | ACTION_PLAN 2.3 (test), ONLINE.md punto 7 |
| R-010-16 | THE Profile SHALL hold no state of a world or of a robot (battery, inventory, XP, position). | PMV §4.5 gancho 1 |

### 3.4 Mundo: cabecera y creación

| ID | Requisito | Fuente |
|---|---|---|
| R-010-17 | THE World SHALL have a header with `world_id` (a `uid`), a name, `seed`, the ruleset id, `schema_version` and the time of the last save read from `ITimeService`. | ACTION_PLAN 2.3, PMV §4.5 gancho 1 |
| R-010-18 | THE World file SHALL be found by its `world_id`, so that several worlds can coexist in v1.1; in the MVP the game SHALL use the only one. | SPECS §26, ACTION_PLAN 2.3 |
| R-010-19 | WHEN the game starts and no World exists, THE game SHALL create one with a new `world_id`, a random seed and the `NORMAL` ruleset, place the robot at the spawn point of the base (R-009-08) and write it at once. | ACTION_PLAN 2.3, SPECS §26 — preguntas 8 y 9 |
| R-010-20 | THE `GameManager` SHALL take the world seed and the ruleset from the loaded or created World (replaces the dev world config of R-008-02 and of spec 004). | Spec 008 R-008-02, architecture §5 — pregunta 9 |
| R-010-21 | THE seed of a World SHALL never change after its creation. | PMV §4.5 gancho 3, Constitución P9 |

### 3.5 Estado del jugador

| ID | Requisito | Fuente |
|---|---|---|
| R-010-22 | THE World SHALL keep the state of each player under its `player_uid`, so that more than one robot fits in the same format. | architecture §12 (v2.0), ONLINE.md punto 6 |
| R-010-23 | THE saved state of a player SHALL be: current battery, every `ItemStack` of its inventory in its slot (item id, quantity, durability, `uid`), total XP, and its `(zone_id, local position)`. | ACTION_PLAN 2.3, architecture §9.3, PMV §4.5 gancho 2 |
| R-010-24 | THE values that are derived from data (maximum battery, number of inventory slots) SHALL not be saved: they SHALL be recomputed on load. | Constitución P2, ACTION_PLAN 2.7 |
| R-010-25 | THE format SHALL admit the owners that later specs add (equipped pieces, chassis level, chests, generator) as new keys, with no change in `SaveManager`. | ACTION_PLAN 2.3, 2.5, 2.6, 2.7, 3.1 — pregunta 10 |

### 3.6 Estado del mundo

| ID | Requisito | Fuente |
|---|---|---|
| R-010-26 | THE World SHALL keep the visit counter of every zone, indexed by `zone_id`; loading a World SHALL never raise a counter. | ACTION_PLAN 2.3, BALANCE §7.2 |
| R-010-27 | THE World SHALL keep, for the visit in progress of each `FARM` zone, which boxes are open and the stacks left inside each one. | ACTION_PLAN 2.3, BALANCE §7.2 |
| R-010-28 | WHEN the visit counter of a zone goes up, THE saved box state of that zone SHALL be discarded. | BALANCE §7.2 |
| R-010-29 | THE World SHALL keep every dropped object (stacks, `uid`, `(zone_id, local position)` and drop time), using the JSON state of R-008-17 unchanged. | ACTION_PLAN 2.3, Spec 008 R-008-17 |
| R-010-30 | WHEN a World is loaded, THE game SHALL discard the dropped objects that are expired by the rule of R-008-21, with the current time of `ITimeService`, before any player can interact with them. | ACTION_PLAN 1.5, PMV §10 (caducidad), Spec 008 §4 |
| R-010-31 | THE World SHALL keep every placed structure (structure id, `uid`, `(zone_id, cell)`), using the JSON state of R-009-31 unchanged. | ACTION_PLAN 2.2, 2.8, Spec 009 R-009-31 |
| R-010-32 | THE World SHALL keep which enemies of the visit in progress are dead, by spawn index, and a loaded zone SHALL not bring them back nor roll their drop again. | BALANCE §7.2 (misma visita), Spec 008 R-008-36 — pregunta 3 |
| R-010-33 | THE game SHALL apply no elapsed real time on load other than the expiry of dropped objects (R-010-30): battery, boxes and enemies SHALL be as they were saved. | BALANCE §7.2, PMV §10 (reposición) |

### 3.7 Carga

| ID | Requisito | Fuente |
|---|---|---|
| R-010-34 | WHEN the game starts and a World exists, THE game SHALL load it before any zone is populated, load the saved zone of the local player through `ZoneLoader` and place the robot on its saved local position. | ACTION_PLAN 2.3 (test), BALANCE §7.2 — pregunta 3 |
| R-010-35 | WHEN a World is loaded, THE zone SHALL be populated for its saved visit number with the saved box state, and neither the number nor the position of the boxes SHALL change. | BALANCE §7.2, PMV §10 (reposición) |
| R-010-36 | IF the saved zone or position of the player cannot be used (unknown `zone_id`, position outside the zone), THEN THE robot SHALL appear at the spawn point of the base and the rest of the World SHALL load. | Constitución §2 (errores) |
| R-010-37 | WHEN a save is followed by a load with nothing in between, THE player state and world state of §3.5 and §3.6 SHALL be the same as before the save. | ACTION_PLAN 2.3 (test), architecture §13 |

### 3.8 Cuándo se guarda

| ID | Requisito | Fuente |
|---|---|---|
| R-010-38 | WHEN `EventBus.zone_changed` reports that the base was entered, THE `SaveManager` SHALL save the World, without recharging the battery. | ACTION_PLAN 2.2, 2.3, BALANCE §5.3 |
| R-010-39 | WHEN a player recharges at a charging station (the fact signalled by R-009-49), THE `SaveManager` SHALL save the World after the recharge is applied. | ACTION_PLAN 2.2, BALANCE §5.3 |
| R-010-40 | WHEN the window receives a close request, THE game SHALL save the World before quitting. | ACTION_PLAN 2.3 |
| R-010-41 | WHEN the application goes to the background on a mobile device, THE game SHALL save the World. | ACTION_PLAN 6.2 (cerrar y reabrir app) — pregunta 2 |
| R-010-42 | WHEN the death reaction of spec 008 has been applied, and WHEN a structure is built or moved, THE `SaveManager` SHALL save the World. | architecture §7 (oyentes de `player_died` y `structure_built`) — pregunta 4 |
| R-010-43 | THE saved state SHALL always be a consistent one: IF a save is requested during a travel, the transfer screen, or a placement or edit mode, THEN THE game SHALL save the state as it is once the transition is resolved (travel finished, robot reappeared, mode cancelled with nothing charged). | Spec 008 R-008-30, Spec 009 R-009-07, R-009-37 — pregunta 5 |
| R-010-44 | WHEN a World is saved, THE `SaveManager` SHALL emit `EventBus.game_saved(reason)` once, with a reason that tells the triggers of this section apart. | architecture §7 |
| R-010-45 | IF a save fails, THEN THE previous World file and its backup SHALL stay as they were, `game_saved` SHALL not be emitted and THE game SHALL show a translated error notice in ES and EN. | PMV §3 (savegame corrupto), Constitución P11 |

### 3.9 Copia de seguridad y corrupción

| ID | Requisito | Fuente |
|---|---|---|
| R-010-46 | WHEN a Profile or a World is about to be overwritten, THE `LocalSaveStore` SHALL first keep the previous valid file as its backup. | ACTION_PLAN 2.3, PMV §3 |
| R-010-47 | THE write of a file SHALL be such that an interruption at any point leaves either the previous file or the new one readable, never a half-written main file with no valid backup. | PMV §3 (savegame corrupto) |
| R-010-48 | IF the main file cannot be read, decrypted, parsed or validated, THEN THE game SHALL load the backup instead and report it with `push_error()`. | ACTION_PLAN 2.3 |
| R-010-49 | IF neither the main file nor the backup is valid, THEN THE game SHALL set the damaged files aside without deleting them, start a new World (or Profile) and show a translated notice in ES and EN. | PMV §3 — pregunta 6 |
| R-010-50 | THE backup SHALL be used only by R-010-48: no screen or method SHALL let the player choose to go back to it. | ACTION_PLAN 2.3, SPECS §27 |
| R-010-51 | WHEN a World is deleted, THE game SHALL delete its backup too. | SPECS §27 (el respaldo no deshace una muerte) |

### 3.10 Versión de esquema y migración

| ID | Requisito | Fuente |
|---|---|---|
| R-010-52 | THE Profile and the World SHALL each carry their own `schema_version`, starting at 1. | ACTION_PLAN 2.3, architecture §10.2 |
| R-010-53 | WHEN a file with an older `schema_version` is loaded, THE game SHALL apply the chain of pure functions `migrate_vN_to_vN1` up to the current version before any owner reads it. | ACTION_PLAN 2.3, architecture §10.2 |
| R-010-54 | THE game SHALL keep an example file of each published `schema_version` under `tests/`, and a test SHALL load each one into the current version. | architecture §13 |
| R-010-55 | IF a file has a `schema_version` newer than the one the game knows, THEN THE game SHALL not load it, SHALL not overwrite it and SHALL show a translated notice in ES and EN without starting a game. | Constitución §2 (errores) — pregunta 7 |

### 3.11 Cifrado

| ID | Requisito | Fuente |
|---|---|---|
| R-010-56 | THE Profile and World files SHALL be written as encrypted JSON (AES-256), and THE backups SHALL be encrypted the same way. | ACTION_PLAN 2.3, PMV §2.1, §3 — pregunta 1 |
| R-010-57 | THE encryption SHALL live inside `LocalSaveStore`: `SaveManager` and the owners SHALL only see plain data. | architecture §10.1 |
| R-010-64 | WHERE the build is a debug build and a project setting asks for it, THE `LocalSaveStore` SHALL write plain JSON; a release build SHALL always encrypt. | Pregunta 1 |

### 3.12 Tienda (`IStore`)

| ID | Requisito | Fuente |
|---|---|---|
| R-010-58 | THE game SHALL define the `IStore` contract with `has_entitlement(id) -> bool` (synchronous, read from the Profile), `purchase(sku)` and `restore()`, whose results arrive through a signal of the contract carrying an `ActionResult`, as a base class whose methods report an error when not overridden. | ACTION_PLAN 2.3, PMV §4.5 gancho 8, Constitución P10 |
| R-010-59 | THE game SHALL have a `LocalStore` that is always in demo mode: `has_entitlement` answers no for every id, `purchase` fails with a translated error key and changes nothing, and `restore` changes nothing. | ACTION_PLAN 2.3, TOOLING §3 — pregunta 11 |
| R-010-60 | THE entitlements SHALL be read from and written to the Profile only; no World SHALL hold them. | ACTION_PLAN 2.3, SPECS §23 |
| R-010-61 | THE game SHALL add no billing plugin, SDK or network call. | TOOLING §3 y resumen por fase, PMV §2.3 |

### 3.13 Aviso de guardado

| ID | Requisito | Fuente |
|---|---|---|
| R-010-62 | WHEN `game_saved` arrives with the reason of the charging station, THE HUD SHALL show "Partida guardada" through the notice of spec 005, with its text from a translation key in ES and EN. | ACTION_PLAN 2.2, architecture §7 — pregunta 12 |

### 3.14 Bucle completo

| ID | Requisito | Fuente |
|---|---|---|
| R-010-65 | WHERE the build is a debug build, THE debug HUD SHALL show the world seed and a "New world" button that deletes the World through `delete_save()` and starts a new one; release builds SHALL have neither. | ACTION_PLAN 2.3 (`delete_save`) — preguntas 8 y 9 |
| R-010-63 | THE player SHALL be able to collect scrap, build and place a charging station, recharge, close the game, open it again and find the same battery, inventory, XP, station on its cell and visit number. | ACTION_PLAN 2.3 (test), Fase 2 (criterio) |

Los valores numéricos (caducidad de los objetos caídos, recarga) se citan por su fuente; el spec no los fija.

## 4. Fuera de alcance

- Varios mundos, pantalla de selección, nombre elegido por el jugador y semilla introducida a mano: v1.1
  (SPECS §26). Aquí solo existe un Mundo, creado automáticamente.
- Menú principal ("Jugar", "Continuar"), botón "Guardar" del menú de pausa y borrar la partida desde la UI:
  ACTION_PLAN 4.2. Aquí `delete_save()` existe y se prueba, pero no tiene pantalla (pregunta 8).
- Ajustes del jugador (`user://settings.cfg`): ACTION_PLAN 4.2 (architecture §10.2). No son Perfil ni Mundo.
- Piezas equipadas: spec 014. Nivel de chasis: spec 013. Cofres y sus items, generador y sus baterías, items
  dejados en cajas vaciadas: spec 012. Cada una añade su clave con el contrato de §3.2 (R-010-25).
- Estado de los enemigos vivos (posición, vida, estado de la IA): no se guarda; al cargar vuelven a su punto de
  aparición (pregunta 3).
- Modo Hardcore, salón de la fama, Respaldo de consciencia y borrar el Mundo al morir: v1.1 (PMV §2.3,
  SPECS §27). Aquí solo se respeta la regla del respaldo (R-010-50, R-010-51).
- Compras reales, facturación nativa, restauración real y pantalla de tienda: v1.1 (TOOLING §3).
- Guardado en la nube y sincronización entre dispositivos: v1.3 / v2.0 (TOOLING §5, PMV §2.3).
- Cola de acciones sin conexión y `OnlineManager`: v1.5 (ONLINE.md).
- Protección seria contra trampas (hora del servidor, validación remota): ONLINE.md. El cifrado solo evita la
  edición casual (PMV §3).
- Sistema general de notificaciones temporales: ACTION_PLAN 4.1. SFX de guardado: ACTION_PLAN 4.3.

## 5. Criterio de hecho

Primer arranque: se crean un Perfil con su `player_uuid` y un Mundo con semilla aleatoria; el robot aparece en
la base. Tras recoger chatarra en la zona verde, volver, construir una estación, colocarla y recargar, aparece
"Partida guardada". Al cerrar y reabrir, el robot está donde estaba, con la misma batería, inventario y XP, la
estación en su celda y el mismo número de visita; la zona verde tiene las mismas cajas en las mismas posiciones.
Cerrar el juego dentro de la zona verde con dos cajas abiertas y un zombie muerto, y reabrir, devuelve la misma
visita: esas cajas siguen abiertas con lo que quedaba dentro y ese zombie no vuelve. Un objeto caído sigue en su
sitio al reabrir antes de los 5 minutos (BALANCE §7.2) y ha desaparecido si se reabre después. Dañar a mano el
archivo del Mundo hace que cargue la copia de seguridad; dañar los dos arranca un Mundo nuevo con un aviso y sin
borrar los archivos dañados. Borrar el Mundo deja el Perfil intacto: el `player_uuid` es el mismo en el Mundo
siguiente. Los archivos de `user://` no se leen como texto. En el Android de gama media, mandar la app a segundo
plano y matarla desde recientes conserva el progreso, y guardar en la estación no produce un tirón visible.

Tests en verde: contrato de serialización (todo nodo `persistent` tiene los tres métodos, claves únicas), ida y
vuelta de cada dueño (batería, inventario con durabilidad y `uid`, XP, posición, contadores, cajas abiertas,
objetos caídos, estructuras, enemigos muertos), ida y vuelta del documento completo, clave ausente e id
desconocido, Perfil creado una vez y `player_uuid` estable, Mundo nuevo con cabecera completa, semilla que no
cambia, borrar el Mundo no borra el Perfil y sí su copia, copia de seguridad antes de sobrescribir, carga desde
la copia con el principal dañado, los dos dañados, guardado fallido que no toca los archivos, migración con un
archivo v1 de ejemplo, versión más nueva rechazada sin sobrescribir, archivo cifrado ilegible como JSON,
caducidad al cargar con reloj falso (límite exacto y tiempo negativo), cada disparador guarda una vez y emite
`game_saved` con su motivo, entrar en la base guarda y no recarga, `LocalStore` siempre demo, e integración
"cerrar y reabrir conserva el progreso" (ACTION_PLAN 2.3). Los tests usan un `ISaveStore` en memoria o una
carpeta temporal, nunca los guardados reales. Probado en PC y en el Android de gama media.

## 6. Preguntas abiertas

| # | Pregunta | Propuesta | ¿Bloquea? |
|---|---|---|---|
| 1 | ~~API y clave de cifrado~~ | **Cerrada (nov 2026)**: cifrado de archivos de `FileAccess` (AES-256), con la API exacta verificada en la documentación de Godot 4.7 al planificar; `EncryptionContext` no es una clase de Godot 4 y se corrige en PMV §3, ACTION_PLAN 2.3 y CLAUDE.md. Clave fija dentro del cliente, aceptada como ofuscación y no como secreto (PMV §3: "evitar trampas simples"). En builds de depuración, un ajuste de proyecto permite guardar sin cifrar para inspeccionar (R-010-64). Descartado: clave del identificador del dispositivo y del `player_uuid`. | — |
| 2 | ~~Cierre en Android~~ | **Cerrada (nov 2026)**: se guarda también al pasar a segundo plano (R-010-41); el plan verifica la notificación exacta en la documentación. En PC se mantiene la petición de cierre. | — |
| 3 | ~~Cerrar el juego dentro de la zona de farmeo~~ | **Cerrada (nov 2026): opción A**. El robot vuelve a su zona y posición; se guardan los índices de aparición de los enemigos muertos de la visita en curso (R-010-32); los vivos vuelven a su punto de aparición con la vida completa. BALANCE §7.2 y ACTION_PLAN 2.3 actualizados. Descartado: guardar posición y vida de los vivos (B) y cargar siempre en la base contando el cierre como salida (C). | — |
| 4 | ~~Disparadores además de los de ACTION_PLAN~~ | **Cerrada (nov 2026)**: se guarda también tras aplicar la reacción a la muerte y al construir o mover una estructura (R-010-42). No se guarda al entrar en la zona de farmeo ni por temporizador. | — |
| 5 | ~~Guardar en mitad de una transición~~ | **Cerrada (nov 2026)**: se guarda el estado ya resuelto, nunca uno intermedio (R-010-43). | — |
| 6 | ~~Principal y copia dañados a la vez~~ | **Cerrada (nov 2026)**: se apartan los archivos dañados sin borrarlos, se empieza un Mundo nuevo (o un Perfil con `player_uuid` nuevo) y se avisa con un texto traducido (R-010-49). | — |
| 7 | ~~Guardado de una versión más nueva del juego~~ | **Cerrada (nov 2026)**: ni se carga ni se sobrescribe; hasta la Tarea 4.2 el juego muestra un aviso traducido y no arranca partida (R-010-55). Con el menú, la 4.2 añade empezar un Mundo nuevo si el jugador lo confirma. | — |
| 8 | ~~Borrar la partida sin menús~~ | **Cerrada (nov 2026)**: `delete_save()` existe y se prueba; botón "Mundo nuevo" en el HUD de depuración, solo en builds de depuración (R-010-65). | — |
| 9 | ~~Semilla, nombre del Mundo y `DevWorldConfigData`~~ | **Cerrada (nov 2026)**: semilla aleatoria al crear el Mundo (es creación, no generación: no choca con P9); nombre vacío hasta v1.1; `DevWorldConfigData` deja de usarse en el juego y los tests fijan la semilla por parámetro; el HUD de depuración muestra la semilla (R-010-65). | — |
| 10 | ~~¿Añadir un dueño nuevo sube `schema_version`?~~ | **Cerrada (nov 2026)**: no. Una clave ausente deja al dueño en su estado de partida nueva (R-010-10); la versión sube solo cuando cambia la forma de una clave existente. | — |
| 11 | ~~Firma de `IStore.purchase`~~ | **Cerrada (nov 2026)**: `purchase(sku)` y `restore()` entregan su resultado por una señal del contrato con un `ActionResult`; `has_entitlement(id) -> bool` es síncrono (R-010-58). El plan decide qué autoload de la lista cerrada lo expone (architecture §5). | — |
| 12 | ~~Cuándo se ve "Partida guardada"~~ | **Cerrada (nov 2026)**: solo al recargar en la estación, con el aviso de la spec 005 y su misma duración; los demás guardados son silenciosos (R-010-62). La Tarea 4.1 lo mueve a su sistema de notificaciones. | — |
