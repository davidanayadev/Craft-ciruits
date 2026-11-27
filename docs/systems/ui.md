# Interfaz (UI)

> Capa de pantallas emergentes (`UIManager`), HUD (batería, interactuar, almacén, atacar, borde rojo), controles
> táctiles y pantalla de transferencia tras la muerte. Presentación pura: lee señales y pide cambios, nunca es
> dueña del estado.
> Specs: [002](../../specs/002-iso-scene-player-movement/spec.md), [003](../../specs/003-battery/spec.md),
> [005](../../specs/005-inventory/spec.md), [007](../../specs/007-melee-combat/spec.md),
> [008](../../specs/008-death-recovery/spec.md), [009](../../specs/009-base-placement-charging/spec.md), [010](../../specs/010-save-profile-world/spec.md), [011](../../specs/011-crafting-repair/spec.md), [012](../../specs/012-wind-generator-chests/spec.md), [013](../../specs/013-loot-box-sites-container-ui/spec.md), [015](../../specs/015-pieces-slots-degradation/spec.md) ·
> Última actualización: spec 015 (`UIManager.close`, `Kind.DROPPED`, panel de equipo, aviso "Pieza rota", barra naranja)

## Piezas

| Pieza | Tipo | Archivo | Responsabilidad |
|---|---|---|---|
| `UIManager` | Escena/`Control` (nodo bajo `UI`, **no** autoload) | `game/scenes/ui/ui_manager.gd` | Pila de pantallas por id; `pause`, atrás de Android y un toque fuera del panel van a la de arriba (`handle_back`) o la cierran; `is_open(id)`; `open()` devuelve la pantalla (spec 012); `close(pantalla)` cierra una pantalla esté donde esté de la pila (spec 015) |
| `UIScreen` | Clase base | `game/scenes/ui/ui_screen.gd` | `setup(context)`, `close_requested`, `handle_back() -> bool`, `on_closed()` y, de la spec 012, `closed`, `back_requested` y `closes_on_outside_tap` |
| `UIScreenCatalog` | Recurso | `game/scripts/data/ui_screen_catalog.gd` | Diccionario id → `PackedScene` |
| `screens.tres` | `.tres` | `game/resources/ui/screens.tres` | Registra `inventory`, `container` (antes `loot`), `bench`, `placement` y `notice` |
| `Hud` | Escena | `game/scenes/ui/hud.gd` | Batería (naranja si `is_low()`), botones Interact, almacenamiento, atacar y "Editar base" (solo con la base cargada), aviso corto (`show_notice(clave, args := [])`: inventario lleno, negativas de usar consumibles, aviso del generador, "Partida guardada", "Pieza rota" con `piece_broken`) y borde rojo |
| `LoadingScreen` | `Control` | `game/scenes/ui/loading_screen.gd` | Cubre el juego durante un viaje; fuera de `UIManager` ([travel.md](travel.md)) |
| `BenchScreen`, `PlacementScreen` | Pantallas | [crafting.md](crafting.md), [base.md](base.md) | Banco con pestañas Construir, Crear y Reparar (sustituye a `BuildScreen`) y modo colocar/editar |
| `AttackButton` | `Button` | `game/scenes/ui/attack_button.gd` | Botón grande de mantener, abajo a la derecha, visible en PC y móvil; emite `held_changed` |
| `DamageFlash` | `TextureRect` | `game/scenes/ui/damage_flash.gd` | Borde rojo radial que se desvanece; `flash(duration_s)` |
| `DebugHud` | Escena (`CanvasLayer`) | `game/scenes/ui/debug_hud.gd` | FPS, XP, nivel de chasis ("Level: n", `level_changed`), botón "Level up" (spec 014, suma la XP que falta al siguiente umbral con `add_xp`), semilla del Mundo y botón "New world" (`new_world_requested`), todo en una lista tras el botón "•••" de la esquina superior derecha, cerrada al empezar; solo en builds de depuración |
| `NoticeScreen` | `UIScreen` | `game/scenes/ui/notice_screen.gd`, `.tscn` | Aviso a pantalla completa que ni Escape ni atrás cierran; lo abre `SaveFlow` con `MSG_SAVE_NEWER_VERSION` ([save.md](save.md)) |
| `TransferScreen` | `Control` | `game/scenes/ui/transfer_screen.gd` | "Transferencia de Consciencia" entre la muerte y la reaparición (spec 008) |
| `QuantitySelector` | `HBoxContainer` | `game/scenes/ui/quantity_selector.gd` | − / + y deslizador de 1 a la cantidad de una pila; emite `value_changed`; `set_editable(bool)` lo desactiva sin ocultarlo (spec 013) |
| `TouchControls` + `FloatingJoystick` | Escena | `game/scenes/ui/touch_controls.gd`, `floating_joystick.gd` | Joystick flotante, solo con pantalla táctil |
| Pantallas de inventario | Pantallas | [inventory.md](inventory.md) | `InventoryScreen`, `ContainerScreen` y sus rejillas |
| `EquipmentPanel` | `PanelContainer` | `game/scenes/ui/equipment_panel.gd`, `.tscn` | Panel de equipo y stats dentro de `InventoryScreen` ([equipment.md](equipment.md)) |
| `ContainerScreen` | `UIScreen` | `game/scenes/ui/container_screen.gd`, `.tscn` | Cofre o caja abierta junto al inventario, cada rejilla con cabecera y ocupación, y una ficha fija `%ActionCard` (selección, selector de cantidad, `%MoveButton`, `%PlaceButton`, `%TakeAllButton`, `%Notice`); modos `BROWSING` / `PLACING` (spec 013) |

## Cómo funciona

Orden de hijos de `UI` en `main.tscn`: `UIManager`, `Hud`, `TouchControls`, `DebugHud`, `TransferScreen` y
`LoadingScreen` (ver el archivo para el orden exacto). Lo que va después se dibuja encima.
Como el HUD va encima de las pantallas, el panel de una pantalla debe dejar libre el botón de almacenamiento (abajo en
el centro), que sirve para cerrarla; `test_main_scene.gd` lo mide con el inventario en 1920×1080.

1. **Abrir.** `main.gd` llama a `ui_manager.open(id, context)`. El manager busca la escena en el catálogo, la
   instancia, la añade como hijo, la apila, conecta su `close_requested` y llama a `setup(context)`. Id
   desconocido o ya abierto: `push_error` y nada cambia.
2. **Contexto.** Es un `Dictionary` con claves constantes de cada pantalla (`CONTEXT_CONTAINER`,
   `CONTEXT_INVENTORY`, `CONTEXT_KIND`). La pantalla convierte con `as` y avisa si falta algo; nunca busca datos en el árbol.
3. **Cerrar.** `close_top()` (el botón de almacenamiento), `close_all()` (muerte y viaje) y, con `pause` o atrás de
   Android, `_back()` (spec 009): primero pregunta a la pantalla de arriba `handle_back()`; si devuelve `true` se
   queda abierta (la gestionó ella), si no se cierra. `_remove_at` saca la pantalla de la pila al instante, para que
   `is_modal_open()` sea correcto, llama a `on_closed()` (limpieza por **cualquier** camino de cierre, antes del
   `queue_free`) y la libera con `queue_free()` porque el cierre puede llegar en mitad de una señal de la propia pantalla.
4. **Bloqueo de entrada.** `modal_state_changed(is_open)` se emite solo al pasar de ninguna pantalla a alguna y
   al revés. `main.gd` lo conecta a `PlayerInput.set_input_blocked(bloqueado, REASON_SCREEN)` (sin dirección, carrera
   ni interactuar; ver [movement.md](movement.md)). `Robot.request_interact()` también se ignora. El árbol **no se
   pausa**: la batería sigue gastando y los enemigos actúan ([enemies.md](enemies.md)).
5. **HUD.** `Hud.bind(robot)` conecta `battery_changed`, `target_changed` del interactor, `overflowed` del
   inventario y `blocked_changed` de `PlayerInput` (el botón Interact se oculta con cualquier motivo de bloqueo:
   pantalla, muerte o viaje; `set_modal_open` ya no existe), y pinta el estado inicial con los mismos manejadores.
   `show_notice(clave)` pone una clave de traducción en la etiqueta del aviso corto, con su temporizador, y sustituye al
   que se vea; lo usan el inventario lleno, `SaveManager.save_notice` (conectado por `SaveFlow`) y `MSG_GAME_SAVED`,
   que sale solo cuando `game_saved` trae la razón de la estación de carga ([save.md](save.md)).
   Emite `interact_pressed`, `storage_pressed` (botón o acción `open_storage`) y `edit_base_pressed`; `main.gd` y
   `BuildFlow` las enrutan. `set_edit_base_available` muestra el botón solo con la base cargada. No lee estado en
   `_process`.
6. **Almacenamiento.** `main.gd`: batería agotada o viaje en curso, nada; pantalla abierta, `close_top()` (con la
   colocación abierta, esto la cancela sin gastar nada); si no, abre
   `inventory` con el inventario y el robot como `CONTEXT_THROWER`.
7. **Atacar** (007). `AttackButton` solo usa `button_down`/`button_up` (responde a cualquier dedo, así se golpea
   con un pulgar mientras el otro mueve el joystick) y emite `held_changed`; si se oculta pulsado, emite
   `held_changed(false)`. El `Hud` lo reemite como `attack_held_changed` y `main.gd` lo conecta a
   `PlayerInput.set_attack_button_held` ([movement.md](movement.md)). El botón se queda visible con una pantalla
   abierta: el bloqueo lo hace `PlayerInput`. "Interactuar" queda por encima. Un clic en otro botón del HUD no es un
   golpe porque el ataque no se lee del estado de la acción ([combat.md](combat.md)).
8. **Borde rojo** (007). `CombatFeedback` llama a `Hud.flash_damage(duración)` cuando el robot emite
   `hit_received`; `DamageFlash` solo procesa mientras se ve, así `Hud` sigue sin `_process`.
9. **Transferencia** (008). Al morir el robot local, `main.gd` hace `close_all()`, bloquea la entrada, suelta el
   joystick (`FloatingJoystick.cancel()`) y el botón de atacar, y llama a `TransferScreen.play()`; congela `World`.
   `TransferScreen` es un `Control` a pantalla completa con `mouse_filter` de parar (traga los toques), **fuera** de
   `UIManager`, así que Escape y atrás no la cierran, y no tiene botón: avanza con `advance(delta)` desde su
   `_process` y emite `finished` al cumplir `DeathConfigData.transfer_duration_s`, y `main.gd` reaparece al robot.
   Qué pasa en el mundo está en [death.md](death.md). No hay game over ni recarga de escena: `GameOverScreen` se
   borró en la spec 008.
10. **Tirar items** (008). `InventoryScreen` (ver [inventory.md](inventory.md)) selecciona una pila al tocarla,
    muestra `QuantitySelector` y el botón "Tirar", y solo llama a `Robot.request_throw(ranura, cantidad)`; la
    pantalla nunca cambia el inventario. `QuantitySelector.set_maximum(n)` fija el rango 1..n y empieza en n sin
    emitir; el valor se lee del deslizador. Sin `CONTEXT_THROWER` los controles de tirar no se muestran.
11. **Carga y colocación** (009). `LoadingScreen` es como `TransferScreen`: fuera de `UIManager`, traga los toques y
    no tiene mínimo de duración. `PlacementScreen` recibe los clics del suelo en `_gui_input` (un toque llega como
    clic de ratón emulado) y usa `handle_back`/`on_closed` ([base.md](base.md)).
12. **Contenedor** (012, 013, 015). `ContainerScreen` solo pide. Lo abren `Main` (`Kind.LOOT_BOX`), `StructureUseFlow`
    (`Kind.CHEST`, [wind_generator_chests.md](wind_generator_chests.md)) y `DroppedItemFlow` (`Kind.DROPPED`, título
    `DROPPED_TITLE`, cabecera `CONTAINER_HEADER_DROPPED`, botón "Dejar aquí"; [death.md](death.md)). `DROPPED` va al final
    del enum porque los textos se indexan por valor. `CONTEXT_KIND` elige por tabla el título, la
    cabecera y el texto de "guardar". Un `Kind` que falta o no es válido es `push_error` y no se muestra nada.
    - Cabeceras: cada rejilla lleva su nombre y `usadas/total` (`InventoryRules.count_used_slots`), repintadas con
      `inventory_changed` de ambos inventarios.
    - Ficha fija `%ActionCard` bajo las dos rejillas, siempre visible; `_refresh_card()` es el único método que la
      pinta, a partir del modo y la selección. Sin selección: pista "toca una pila", selector y botones desactivados
      (nunca ocultos, `QuantitySelector.set_editable`).
    - `BROWSING`: tocar solo selecciona (sin mover): una pila, la seleccionada la quita, otra cambia la selección;
      las celdas vacías no se pulsan. `%MoveButton` nombra el destino y llama a `origen.transfer_to`; "Coger todo"
      usa `take_from` y está desactivado con el contenedor vacío.
    - `PLACING` (botón "Colocar…", que pasa a "Cancelar"): marca las celdas de ambas rejillas
      (`InventoryGrid.set_targets_marked`, `InventorySlotView.set_target_marked`), tocar una celda llama a
      `origen.move_to_slot` y la de origen cancela; el selector, "Pasar" y "Coger todo" quedan desactivados.
    - `handle_back()` sale de `PLACING` conservando la selección y devuelve `true`; fuera del modo devuelve `false` y
      `UIManager` cierra (el toque fuera del panel llega por el mismo camino).
    - Una negativa (`ERR_SLOT_FULL`, `ERR_PARTIAL_SWAP`, `ERR_NO_ROOM`) sale en `%Notice`, dentro de la ficha, y
      mantiene selección y modo. "Coger todo" sin que quepa nada muestra `MSG_INVENTORY_FULL` ahí. Un movimiento
      hecho quita la selección y resalta las ranuras del destino que cambiaron
      (`InventorySlotView.flash_highlight(ControlConfigData.move_highlight_s)`, [BALANCE §11](../../BALANCE.md)); si la
      pila elegida desaparece por otro camino, se limpia selección y modo. No se cierra aunque quede vacío.
13. **Cerrar tocando fuera** (012). Con `closes_on_outside_tap` (banco, inventario y contenedor; no colocación ni aviso),
    el `_gui_input` de `UIScreen` solo recibe lo que ningún hijo para: el `Panel` (único por pantalla, `mouse_filter` de
    parar) lo traga y el fondo y el centrado lo dejan pasar. Atiende solo `InputEventMouseButton` izquierdo pulsado (en
    Android el toque llega como ratón emulado, así no cierra dos veces), hace `accept_event()` y emite `back_requested`;
    `UIManager` lo trata como atrás solo si esa pantalla es la de arriba. El evento aceptado no llega a `_unhandled_input`:
    ni ataque, ni joystick, ni interacción.
14. **Cerrado y guardado de cofres** (012). `_remove_at` emite `UIScreen.closed` tras `on_closed()`, por cualquier camino
    (`close_all` incluido); `StructureUseFlow` lo usa para saber cuándo se cerró la pantalla de un cofre, y
    `DroppedItemFlow` la de un objeto caído. `UIManager.close(pantalla)` (spec 015) es el `_close` interno hecho público:
    el flujo cierra la pantalla de un objeto caído que caduca; una pantalla que no está abierta no hace nada.
16. **Equipo** (015). `InventoryScreen` enseña el `EquipmentPanel` junto a la rejilla, dentro de su panel único (un toque
    entre ambos no cuenta como "fuera"). Solo pide `Robot.equip` / `unequip`; ver [equipment.md](equipment.md).
15. **Táctil.** `TouchControls` es el único sitio que pregunta por la pantalla táctil (o `force_touch_debug`);
   oculta la capa y desactiva el joystick si no hay. Las pantallas son un fondo oscuro a pantalla completa que
   consume los toques, así que el joystick no aparece mientras hay una abierta.

## Datos

`screens.tres` no es balance. Tamaños de celda, márgenes, radio del joystick y el `MessageTimer` del HUD son
maquetación o tiempo de UI, no de [BALANCE.md](../../BALANCE.md). Los valores del joystick están en
`ControlConfigData` (ver [movement.md](movement.md)).

## Decisiones

| Decisión | Por qué | Fuente |
|---|---|---|
| `UIManager` es un nodo bajo `UI`, no un autoload | La lista de autoloads está cerrada | [plan 005 §1](../../specs/005-inventory/plan.md), [architecture §9.5](../../specs/architecture.md) |
| Pantallas instanciadas al abrir y liberadas al cerrar | Sigue `open(screen_id, context)` de architecture §9.5 y no mantiene pantallas invisibles | plan 005 §7, Constitución P12 |
| Sin pausa del árbol | La batería sigue gastando con una pantalla abierta | R-005-27 |
| El robot no conoce a `UIManager`: `main.gd` conecta la señal | Señales entre sistemas no relacionados | plan 005 §6 (P6) |
| `UIScreen.close_requested` | La pantalla de caja se cierra sola sin conocer al manager | plan 005 §1 |
| `UIManager` va antes que `Hud` en `UI` | El HUD queda por encima de las pantallas; desvía architecture §6 | plan 005 §6 |
| `close_all()` y `UIScreen` añadidos a architecture §9.5 | Los usan el game over y las pantallas | plan 005 §6 (P14) |
| Atrás de Android sin pantalla abierta no cierra el juego | Consecuencia de R-005-28 | R-005-33 |
| Solo el robot local abre pantallas | En co-op otro robot no abre pantallas en este cliente | plan 005 §1, architecture §9.5 |
| `TransferScreen` fuera de `UIManager` | Escape y atrás la cerrarían | [plan 008 §1](../../specs/008-death-recovery/plan.md) "Alternativas descartadas" |
| `GameOverScreen` eliminada y la escena ya no se recarga al morir | Lo pide R-008-33 (sustituye a R-003-12) | R-008-33 |
| Botón de atacar visible siempre, también con una pantalla abierta | R-007-16 no pide ocultarlo; puede tapar algún botón abajo a la derecha de una pantalla | R-007-16, [plan 007 §7](../../specs/007-melee-combat/plan.md) |
| `AttackButton` sin seguir su propio toque | En 4.7.2 `BaseButton` ya responde a cualquier dedo | plan 007 §5.1 punto 2 |
| La pantalla de inventario solo pide tirar | El cambio lo hacen los componentes dueños del estado | R-008-42 |
| Bloqueo de entrada por motivos (`screen`, `death`, `travel`) | Con tres dueños ya podían pisarse; el plan 008 lo dejó previsto | [plan 009 §1](../../specs/009-base-placement-charging/plan.md) "Bloqueo de entrada con motivos", plan 008 §7 |
| `UIScreen.handle_back()` y `on_closed()` | Escape y atrás deben cancelar por pasos (mover → editar) y la limpieza debe correr cierre quien cierre | R-009-56, [plan 009 §1](../../specs/009-base-placement-charging/plan.md) |
| `LoadingScreen` fuera de `UIManager` | Escape y atrás no deben cerrarla | plan 009 §3 |
| La colocación es una pantalla de `UIManager` | Reutiliza bloqueo sin pausa, cierre al morir y Escape/atrás | plan 009 §1 |
| Texto solo por claves de traducción | i18n obligatoria | R-005-30, Constitución P11 |
| `UIManager.open()` devuelve la pantalla y `UIScreen` gana `closed` | El flujo que abre un cofre sabe cuándo se cierra sin que la pantalla conozca el bus | [plan 012 D15](../../specs/012-wind-generator-chests/plan.md) |
| Tocar fuera es "atrás", opción por pantalla, un solo tipo de evento | Mismo camino que Escape, también en PC, y el toque no llega al juego | R-012-46, R-012-47, plan 012 D16 |
| Colocación y aviso no se cierran tocando fuera | La colocación usa esos toques para elegir celda; el aviso es bloqueante | R-012-48 |
| `ContainerScreen` sustituye a `LootScreen` | Una caja abierta es un contenedor | R-012-37, plan 012 D13 |
| `Hud.show_notice` con argumentos (`tr(clave) % args`) | El aviso del generador lleva el tiempo que falta | plan 012 D18 |
| Tocar solo selecciona; mover es siempre un botón con destino; "Colocar…" es un modo explícito | El mismo toque hacía tres cosas y movía sin querer | R-013-14..16, [spec 013 pregunta 5](../../specs/013-loot-box-sites-container-ui/spec.md) |
| Ficha de acción fija pintada por un solo método | Nada aparece ni desaparece por caminos distintos | R-013-13, [plan 013 D9, D16](../../specs/013-loot-box-sites-container-ui/plan.md) |
| `CONTEXT_KIND` (enum) en vez de `CONTEXT_TITLE` | Tres textos por tipo de contenedor sin combinaciones incoherentes | [plan 013 D8](../../specs/013-loot-box-sites-container-ui/plan.md) |
| Duración del resaltado en `ControlConfigData.move_highlight_s` | El número es de BALANCE §11 | R-013-19, [plan 013 D15](../../specs/013-loot-box-sites-container-ui/plan.md) |
| La pantalla de inventario (Tab) no adopta la ficha fija | Queda para la UI de la Fase 4 | [spec 013 pregunta 8](../../specs/013-loot-box-sites-container-ui/spec.md) |
| `UIManager.close(pantalla)` público | Nadie emite señales de otro nodo: el flujo pide el cierre | [plan 015 D13](../../specs/015-pieces-slots-degradation/plan.md) |
| Panel de equipo dentro de la pantalla de inventario, sin pantalla propia | Se equipa en cualquier sitio, con los stats junto a la rejilla | R-015-35, [plan 015 D17](../../specs/015-pieces-slots-degradation/plan.md) |
| "Pieza rota" por `show_notice` | Hasta el sistema de avisos de ACTION_PLAN 4.1 | R-015-24 |

## Relación con otros sistemas

- Usa: [equipment.md](equipment.md) (`piece_broken`, panel de equipo), [battery.md](battery.md) (`battery_changed`, `is_low`, `battery_depleted`), [interaction.md](interaction.md)
  (`target_changed`, botón Interact), [inventory.md](inventory.md) (`overflowed`, pantallas),
  [movement.md](movement.md) (`PlayerInput`, joystick).
- Lo usa: [combat.md](combat.md) (`CombatFeedback` llama a `flash_damage`), [death.md](death.md) (transferencia),
  [loot.md](loot.md) (la caja abre `container`), [wind_generator_chests.md](wind_generator_chests.md) (cofre, `use_refused`). Estructura general en [foundation.md](foundation.md).

## Trampas y límites

- `NoticeScreen` no se puede cerrar (`handle_back` devuelve `true`); bloquea el juego hasta que el jugador actualice
  ([plan 010 §1.1 D11](../../specs/010-save-profile-world/plan.md)).
- `open()` de un id ya abierto es un error (devuelve `null`), no una segunda pantalla. Las llamadas que ignoran el retorno siguen valiendo.
- Los botones del HUD (atacar, interactuar, almacén) se dibujan sobre las pantallas: un toque fuera que cae en ellos no cierra la pantalla (aceptado en el plan 012 §7).
- El texto de `show_notice` con argumentos se traduce al mostrarse: no cambia si cambia el idioma con el aviso visible.
- Que un toque en Android llegue una sola vez al fondo y no al joystick está probado con `push_input`; falta confirmarlo en el móvil (M3 del plan 012).
- `UIManager` solo reacciona a `pause` si hay pantalla abierta; sin ella, esa acción queda libre.
- `%ActionCard` fija ancho y alto con `custom_minimum_size` (plan 013 D16), y sus filas reservan la altura de
  los botones y de la línea de aviso: si se añade una fila, hay que subir también ese mínimo. El test compara el
  tamaño de la ficha entre estados e idiomas.
- `ContainerScreen` sin `controls` asignado no resalta (`push_error` en `_ready`); la escena lo asigna.
- `TransferScreen` y `LoadingScreen` heredan de `Control`, no de `UIScreen`: no pasan por `UIManager`.
- `close_top()` (botón de almacenamiento, botón "Editar base" pulsado otra vez) no pasa por `handle_back`: cierra la
  pantalla entera aunque la colocación esté en `MOVE`.
- Un `UIScreen` que necesite limpiar algo (vista previa, estado de otros nodos) lo hace en `on_closed()`, no en
  `close_requested`.
- `DebugHud` no se traduce a propósito (solo depuración). Es el único sitio donde se ven la XP y el nivel (hasta ACTION_PLAN 4.1).
- Un dedo que estaba pulsado al morir no llega a soltar (la transferencia traga la suelta): por eso `main.gd`
  cancela el joystick y el botón de atacar. Se comprueba a mano en el móvil.
- Atrás en Android y Tab dependen del motor y se verifican a mano en el móvil.
- Sin pausa, ajustes ni notificaciones generales todavía (ACTION_PLAN 4.x).

## Cómo extenderlo

1. Escena nueva con script que extienda `UIScreen`, con constante `SCREEN_ID` y sus claves de contexto.
2. Añadirla a `screens.tres`.
3. Abrirla con `ui_manager.open(Pantalla.SCREEN_ID, contexto)` desde quien conecte el disparador.
4. Texto con claves en `game/i18n/strings.csv` (ES y EN).

## Tests

| Archivo | Verifica |
|---|---|
| `tests/unit/test_ui_manager.gd` | Pila, ids desconocidos/repetidos, `modal_state_changed`, `close_top`/`close_all`/`close(pantalla)`, `pause` y atrás, `handle_back` que mantiene la pantalla, `on_closed` en cada cierre, `is_open`; tocar fuera (solo la de arriba, vía `handle_back`, evento aceptado) |
| `tests/unit/test_container_screen.gd` | Cabeceras por tipo, ficha fija (tamaño y sin selección), tocar solo selecciona, botón con destino, modo colocar, atrás y toque fuera salen del modo, coger todo, rechazos, resaltado, sin comprobaciones de plataforma, no se cierra vacía |
| `tests/unit/test_hud.gd` | Barra y número de batería, barra naranja por debajo del umbral, aviso "Pieza rota", botón Interact con/sin bloqueo, mensaje de inventario lleno, `use_refused`, avisos con argumentos, botón de atacar, borde rojo, botón "Editar base" solo en la base |
| `tests/unit/test_loading_screen.gd` | Oculta hasta `show_loading()`, textos como claves, traga toques |
| `tests/unit/test_transfer_screen.gd` | Título traducido, oculta hasta `play()`, traga toques, duración desde la config, `finished` una vez |
| `tests/unit/test_quantity_selector.gd` | Rango 1..máximo, empieza en el máximo, − / + y deslizador, `set_editable` |
| `tests/unit/test_debug_hud.gd` | Muestra la XP, la semilla y `new_world_requested`; lista cerrada tras el botón "•••" |
| `tests/unit/test_notice_screen.gd` | Texto como clave y que no se cierra |
| `tests/integration/test_hud_attack_input.gd` | Un clic en un botón del HUD no es un golpe |
| `tests/unit/test_floating_joystick.gd` | Joystick táctil y modo ratón de depuración |
| `tests/unit/test_player_input.gd` | Entrada bloqueada mientras hay pantalla |
| `tests/integration/test_main_scene.gd` | Cableado de `main.tscn`; la caja abre `ContainerScreen`; un toque fuera no ataca ni llega al joystick |
