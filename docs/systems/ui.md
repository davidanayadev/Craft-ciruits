# Interfaz (UI)

> Capa de pantallas emergentes (`UIManager`), HUD (batería, interactuar, almacén, atacar, borde rojo), controles
> táctiles y pantalla de transferencia tras la muerte. Presentación pura: lee señales y pide cambios, nunca es
> dueña del estado.
> Specs: [002](../../specs/002-iso-scene-player-movement/spec.md), [003](../../specs/003-battery/spec.md),
> [005](../../specs/005-inventory/spec.md), [007](../../specs/007-melee-combat/spec.md),
> [008](../../specs/008-death-recovery/spec.md) · Última actualización: spec 008

## Piezas

| Pieza | Tipo | Archivo | Responsabilidad |
|---|---|---|---|
| `UIManager` | Escena/`Control` (nodo bajo `UI`, **no** autoload) | `game/scenes/ui/ui_manager.gd` | Pila de pantallas por id; cierra la de arriba con `pause` y con atrás de Android |
| `UIScreen` | Clase base | `game/scenes/ui/ui_screen.gd` | `setup(context)` y señal `close_requested` |
| `UIScreenCatalog` | Recurso | `game/scripts/data/ui_screen_catalog.gd` | Diccionario id → `PackedScene` |
| `screens.tres` | `.tres` | `game/resources/ui/screens.tres` | Registra `inventory` y `loot` |
| `Hud` | Escena | `game/scenes/ui/hud.gd` | Batería, botones Interact, almacenamiento y atacar, aviso de inventario lleno y borde rojo |
| `AttackButton` | `Button` | `game/scenes/ui/attack_button.gd` | Botón grande de mantener, abajo a la derecha, visible en PC y móvil; emite `held_changed` |
| `DamageFlash` | `TextureRect` | `game/scenes/ui/damage_flash.gd` | Borde rojo radial que se desvanece; `flash(duration_s)` |
| `DebugHud` | Escena (`CanvasLayer`) | `game/scenes/ui/debug_hud.gd` | FPS y XP, solo en builds de depuración |
| `TransferScreen` | `Control` | `game/scenes/ui/transfer_screen.gd` | "Transferencia de Consciencia" entre la muerte y la reaparición (spec 008) |
| `QuantitySelector` | `HBoxContainer` | `game/scenes/ui/quantity_selector.gd` | − / + y deslizador de 1 a la cantidad de una pila; emite `value_changed` |
| `TouchControls` + `FloatingJoystick` | Escena | `game/scenes/ui/touch_controls.gd`, `floating_joystick.gd` | Joystick flotante, solo con pantalla táctil |
| Pantallas de inventario | Pantallas | [inventory.md](inventory.md) | `InventoryScreen`, `LootScreen` y sus rejillas |

## Cómo funciona

Orden de hijos de `UI` en `main.tscn`: `UIManager`, `Hud`, `TouchControls`, `DebugHud`, `TransferScreen`. Lo que
va después se dibuja encima.

1. **Abrir.** `main.gd` llama a `ui_manager.open(id, context)`. El manager busca la escena en el catálogo, la
   instancia, la añade como hijo, la apila, conecta su `close_requested` y llama a `setup(context)`. Id
   desconocido o ya abierto: `push_error` y nada cambia.
2. **Contexto.** Es un `Dictionary` con claves constantes de cada pantalla (`CONTEXT_SOURCE`,
   `CONTEXT_INVENTORY`). La pantalla convierte con `as` y avisa si falta algo; nunca busca datos en el árbol.
3. **Cerrar.** `close_top()` (acción `pause`, atrás de Android o el botón de almacenamiento) y `close_all()`
   (game over). `_remove_at` saca la pantalla de la pila al instante, para que `is_modal_open()` sea correcto, y la
   libera con `queue_free()` porque el cierre puede llegar en mitad de una señal de la propia pantalla.
4. **Bloqueo de entrada.** `modal_state_changed(is_open)` se emite solo al pasar de ninguna pantalla a alguna y
   al revés. `main.gd` lo conecta a `PlayerInput.set_input_blocked` (sin dirección, carrera ni interactuar) y a
   `Hud.set_modal_open` (oculta el botón Interact). `Robot.request_interact()` también se ignora. El árbol **no se
   pausa**: la batería sigue gastando y los zombies actúan ([enemies.md](enemies.md)).
5. **HUD.** `Hud.bind(robot)` conecta `battery_changed`, `target_changed` del interactor y `overflowed` del
   inventario, y pinta el estado inicial con los mismos manejadores. Emite `interact_pressed` y `storage_pressed`
   (botón o acción `open_storage`); `main.gd` las enruta. No lee estado en `_process`.
6. **Almacenamiento.** `main.gd`: batería agotada, nada; pantalla abierta, `close_top()`; si no, abre
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
11. **Táctil.** `TouchControls` es el único sitio que pregunta por la pantalla táctil (o `force_touch_debug`);
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
| Dos dueños del bloqueo de entrada (`UIManager` y la transferencia) | No chocan: durante la transferencia no se abre ninguna pantalla | plan 008 §7 |
| Texto solo por claves de traducción | i18n obligatoria | R-005-30, Constitución P11 |

## Relación con otros sistemas

- Usa: [battery.md](battery.md) (`battery_changed`, `battery_depleted`), [interaction.md](interaction.md)
  (`target_changed`, botón Interact), [inventory.md](inventory.md) (`overflowed`, pantallas),
  [movement.md](movement.md) (`PlayerInput`, joystick).
- Lo usa: [combat.md](combat.md) (`CombatFeedback` llama a `flash_damage`), [death.md](death.md) (transferencia),
  [loot.md](loot.md) (la caja abre `loot`). Estructura general en [foundation.md](foundation.md).

## Trampas y límites

- `open()` de un id ya abierto es un error, no una segunda pantalla.
- `UIManager` solo reacciona a `pause` si hay pantalla abierta; sin ella, esa acción queda libre.
- `TransferScreen` hereda de `Control`, no de `UIScreen`: no pasa por `UIManager`.
- `DebugHud` no se traduce a propósito (solo depuración). Es el único sitio donde se ve la XP.
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
| `tests/unit/test_ui_manager.gd` | Pila, ids desconocidos/repetidos, `modal_state_changed`, `close_top`/`close_all`, `pause` y atrás |
| `tests/unit/test_hud.gd` | Barra y número de batería, botón Interact con/sin modal, mensaje de inventario lleno, botón de atacar (posición, texto traducido, `attack_held_changed`), borde rojo |
| `tests/unit/test_transfer_screen.gd` | Título traducido, oculta hasta `play()`, traga toques, duración desde la config, `finished` una vez |
| `tests/unit/test_quantity_selector.gd` | Rango 1..máximo, empieza en el máximo, − / + y deslizador |
| `tests/unit/test_debug_hud.gd` | Muestra la XP |
| `tests/integration/test_hud_attack_input.gd` | Un clic en un botón del HUD no es un golpe |
| `tests/unit/test_floating_joystick.gd` | Joystick táctil y modo ratón de depuración |
| `tests/unit/test_player_input.gd` | Entrada bloqueada mientras hay pantalla |
| `tests/integration/test_main_scene.gd` | Cableado de `main.tscn` |
