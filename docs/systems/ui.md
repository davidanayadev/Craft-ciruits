# Interfaz (UI)

> Capa de pantallas emergentes (`UIManager`), HUD, controles táctiles y pantalla de game over. Presentación
> pura: lee señales y pide cambios, nunca es dueña del estado.
> Specs: [002](../../specs/002-iso-scene-player-movement/spec.md), [003](../../specs/003-battery/spec.md),
> [005](../../specs/005-inventory/spec.md) · Última actualización: spec 005

## Piezas

| Pieza | Tipo | Archivo | Responsabilidad |
|---|---|---|---|
| `UIManager` | Escena/`Control` (nodo bajo `UI`, **no** autoload) | `game/scenes/ui/ui_manager.gd` | Pila de pantallas por id; cierra la de arriba con `pause` y con atrás de Android |
| `UIScreen` | Clase base | `game/scenes/ui/ui_screen.gd` | `setup(context)` y señal `close_requested` |
| `UIScreenCatalog` | Recurso | `game/scripts/data/ui_screen_catalog.gd` | Diccionario id → `PackedScene` |
| `screens.tres` | `.tres` | `game/resources/ui/screens.tres` | Registra `inventory` y `loot` |
| `Hud` | Escena | `game/scenes/ui/hud.gd` | Batería, botón Interact, botón de almacenamiento y aviso de inventario lleno |
| `DebugHud` | Escena (`CanvasLayer`) | `game/scenes/ui/debug_hud.gd` | FPS, solo en builds de depuración |
| `GameOverScreen` | Escena | `game/scenes/ui/game_over_screen.gd` | Game over provisional con botón de reinicio |
| `TouchControls` + `FloatingJoystick` | Escena | `game/scenes/ui/touch_controls.gd`, `floating_joystick.gd` | Joystick flotante, solo con pantalla táctil |
| Pantallas de inventario | Pantallas | [inventory.md](inventory.md) | `InventoryScreen`, `LootScreen` y sus rejillas |

## Cómo funciona

Orden de hijos de `UI` en `main.tscn`: `UIManager`, `Hud`, `TouchControls`, `DebugHud`, `GameOverScreen`. Lo que
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
   `inventory`.
7. **Game over.** Al agotarse la batería, `main.gd` hace `close_all()`, congela `World` y llama a
   `GameOverScreen.open()`; su botón emite `restart_requested` y `main.gd` recarga la escena.
8. **Táctil.** `TouchControls` es el único sitio que pregunta por la pantalla táctil (o `force_touch_debug`);
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
| Game over provisional | Lo sustituye la spec 008 | R-003-12 |
| Texto solo por claves de traducción | i18n obligatoria | R-005-30, Constitución P11 |

## Relación con otros sistemas

- Usa: [battery.md](battery.md) (`battery_changed`, `battery_depleted`), [interaction.md](interaction.md)
  (`target_changed`, botón Interact), [inventory.md](inventory.md) (`overflowed`, pantallas),
  [movement.md](movement.md) (`PlayerInput`, joystick).
- Lo usa: [loot.md](loot.md) (la caja abre `loot`). Estructura general en [foundation.md](foundation.md).

## Trampas y límites

- `open()` de un id ya abierto es un error, no una segunda pantalla.
- `UIManager` solo reacciona a `pause` si hay pantalla abierta; sin ella, esa acción queda libre.
- `GameOverScreen` hereda de `Control`, no de `UIScreen`: no pasa por `UIManager`.
- `DebugHud` no se traduce a propósito (solo depuración).
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
| `tests/unit/test_hud.gd` | Barra y número de batería, botón Interact con/sin modal, mensaje de inventario lleno |
| `tests/unit/test_game_over_screen.gd` | `open()` y `restart_requested` |
| `tests/unit/test_floating_joystick.gd` | Joystick táctil y modo ratón de depuración |
| `tests/unit/test_player_input.gd` | Entrada bloqueada mientras hay pantalla |
| `tests/integration/test_main_scene.gd` | Cableado de `main.tscn` |
