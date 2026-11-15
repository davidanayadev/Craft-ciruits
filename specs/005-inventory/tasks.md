# Tareas 005 — Inventario: `InventoryComponent`, UI y loot al jugador

> Orden de ejecución. Cada tarea deja el proyecto compilando y los tests en verde. Marcar `[x]` al terminar.
> **(usuario)** = la hace el usuario en su máquina.

- [ ] **T-005-00** Preparar las ramas, apiladas porque cada una necesita la anterior (los subagentes de
  `.claude/agents/` solo existen en `chore/claude-subagents`, y las decisiones de la 005 en PMV §10 y BALANCE
  §7.2 van junto a las de la Tarea 1.5):
  - [x] `docs/dropped-items-rules`, desde `chore/claude-subagents`: caducidad de lo soltado al morir; tirar items y
    cajas vaciadas como contenedor; casillas de ACTION_PLAN de las tareas hechas. Un commit por tema.
  - [x] `feat/005-inventory`, desde `docs/dropped-items-rules`: solo lo de la 005 (spec, plan, tareas,
    `specs/README.md`, la nota de R-004-24 en la spec 004 y las líneas de la 005 en BALANCE.md, PMV.md y
    ACTION_PLAN.md) en un commit `docs(inventory): …`.
  - [ ] **(usuario)** Subir las tres ramas y fusionar los PR en orden: `chore/claude-subagents` →
    `docs/dropped-items-rules` → `feat/005-inventory`, cada uno con la CI en verde y con commit de fusión (no
    squash), para que el PR siguiente solo enseñe sus commits.

  Verifica: `git log --oneline main..feat/005-inventory` muestra los commits de las tres ramas en ese orden.
- [x] **T-005-01** Comprobar en el binario 4.7.2 headless y en la documentación oficial los 7 puntos
  **(verificar)** del plan §5. Anotar el resultado en el plan, como en el plan 004 §5. Si alguno falla, parar y
  ajustar el plan. Verifica: nota en el plan.
- [x] **T-005-02** Test primero: `test_action_result.gd`. Crear `action_result.gd` e `inventory_add_result.gd`.
  Añadir `ERR_INVALID_REQUEST`, `ERR_NOT_ENOUGH_ITEMS` y `MSG_INVENTORY_FULL` (ES + EN) a `strings.csv` y
  reimportar. Cubre: R-005-14. Verifica: `godot-runner`.
- [x] **T-005-03** Test primero: `test_chassis_level_data.gd`. Crear `chassis_level_data.gd` y
  `resources/progression/chassis_levels.tres` con BALANCE §6.1. Cubre: R-005-02 (datos). Verifica: `godot-runner`.
- [x] **T-005-04** Test primero: `test_inventory_rules.gd` (con `gut-test-writer`). Añadir `ItemStack.copy()` y crear
  `inventory_rules.gd`. Cubre: R-005-01, R-005-03..07. Verifica: `godot-runner`.
- [x] **T-005-05** Test primero: `test_inventory_component.gd` (con `gut-test-writer`), con catálogos hechos a mano.
  Crear `inventory_component.gd` con `add`, `add_stacks`, `remove`, `has`, `count`, `get_slots`, `is_empty`,
  `set_slot_count` y `find_in`. Cubre: R-005-05, R-005-06, R-005-08..14. Verifica: `godot-runner`.
- [x] **T-005-06** Test primero: tests de R-005-15 en `test_inventory_component.gd`. Añadir `remove_from_slots()` y
  `take_from()`. Cubre: R-005-15. Verifica: `godot-runner`.
- [x] **T-005-07** Test primero: `test_robot_inventory.gd`. Añadir `%InventoryComponent` a `robot.tscn`, y
  `chassis_levels` (con `chassis_levels.tres`) e `inventory` a `robot.gd`, que fija las ranuras del nivel 1 en
  `_ready()`. Cubre: R-005-02, R-005-10. Verifica: `godot-runner`.
- [x] **T-005-08** Test primero: R-005-16, R-005-17, R-005-20 y R-005-21 en `test_loot_box.gd`, y
  `test_r_005_17_loot_fits_one_slot_per_entry` en `test_data_catalog.gd`.
  - Añadir `%Contents` a `loot_box.tscn`.
  - En `loot_box.gd`: tirar solo la primera vez dentro de `%Contents`, emitir `opened` mientras quede algo,
    desactivarse al vaciarse y actualizar la cabecera.
  - Conectar `%Contents.inventory_changed` después de llenar la caja en la tirada.
  - Reescribir como R-005-21 las aserciones de "desactivada al abrirse" de `test_loot_box.gd` y
    `test_robot_interaction.gd`. En `test_main_scene.gd::test_r_004_14_hud_button_opens_box`, vaciar la caja con
    `robot.inventory.take_from()` antes de comprobar que el botón se oculta: la suite no puede quedar en rojo hasta
    T-005-15. R-004-23 y R-004-25 siguen en verde.

  Cubre: R-005-16 (caja), R-005-17, R-005-20 (caja), R-005-21 (caja). Verifica: `godot-runner`.
- [x] **T-005-09** Test primero: `box_opened` en `test_green_zone.gd`. En `farm_zone.gd`, reemitir `opened` de cada
  caja como `box_opened(box, opener)`. Cubre: R-005-16 (zona). Verifica: `godot-runner`.
- [x] **T-005-10** Crear los tres SVG de marcador en `assets/textures/icons/items/`, `assets/CREDITS.md` y el campo
  `icon` de `ItemData`, y asignarlos en los tres `.tres`. Test primero: `test_r_005_31_every_item_has_icon` en
  `test_data_catalog.gd`. Cubre: R-005-31, R-005-32. Verifica: `godot-runner`.
- [x] **T-005-11** Test primero: `test_player_input.gd` y `test_ui_manager.gd` (con escenas de prueba hechas con
  `PackedScene.pack()`).
  - Crear `set_input_blocked()` en `player_input.gd`, y hacer que `request_interact()` del robot lo respete.
  - Crear `ui_screen.gd`, `ui_screen_catalog.gd` y `ui_manager.tscn` + `ui_manager.gd`.
  - Poner `quit_on_go_back=false` en `project.godot`, con su test en `test_project_settings.gd`.

  Cubre: R-005-27 (entrada y señal), R-005-28, R-005-33. Verifica: `godot-runner`.
- [x] **T-005-12** Añadir `INVENTORY_TITLE` (ES + EN) a `strings.csv` y reimportar. Test primero:
  `test_inventory_screen.gd`. Crear `inventory_slot.tscn` + `.gd`, `inventory_grid.tscn` + `.gd` e
  `inventory_screen.tscn` + `.gd`: un fondo que consume los toques y un panel centrado que no tapa la batería ni el
  botón de almacenamiento. Cubre: R-005-25, R-005-26, R-005-30 (inventario). Verifica: `godot-runner`.
- [x] **T-005-13** Añadir `LOOT_TITLE` y `LOOT_TAKE_ALL` (ES + EN) a `strings.csv` y reimportar. Test primero:
  `test_loot_screen.gd`. Crear `loot_screen.tscn` + `.gd`, con la rejilla de la caja que se puede pulsar, la del
  jugador y "Coger todo" (`focus_mode` sin foco, como las celdas). Crear `resources/ui/screens.tres` con las dos
  pantallas. Cubre: R-005-18, R-005-19, R-005-21 (pantalla), R-005-24 (foco), R-005-25, R-005-26, R-005-30 (caja).
  Verifica: `godot-runner`.
- [x] **T-005-14** Añadir `HUD_STORAGE` (ES + EN) a `strings.csv` y reimportar. Test primero: los tests de
  R-005-20, R-005-23, R-005-24, R-005-27 y R-005-30 en `test_hud.gd`. Añadir a `hud.tscn` + `hud.gd`:
  - `%StorageButton` abajo en el centro, sin foco, con `HUD_STORAGE`;
  - la señal `storage_pressed`, emitida por el botón y por `open_storage` en `_unhandled_input`;
  - `set_modal_open()`: el botón de interactuar se ve solo con objetivo y sin pantalla abierta;
  - `%MessageLabel` y `%MessageTimer` (3 s, ACTION_PLAN 4.1), enlazados a `overflowed` en `bind()`.

  Cubre: R-005-20 (HUD), R-005-23, R-005-24, R-005-27 (HUD), R-005-30. Verifica: `godot-runner`.
- [x] **T-005-15** Test primero: los tests de R-005-16, R-005-19, R-005-20, R-005-22, R-005-24, R-005-27 y R-005-29
  en `test_main_scene.gd`.
  - En `main.tscn`, añadir `%UIManager` bajo `UI` antes de `Hud`, con `screens.tres`.
  - En `main.gd`: `box_opened` abre la pantalla de caja si quien abre es el robot local (o da error si no tiene
    inventario).
  - `storage_pressed` cierra la pantalla de arriba o abre el inventario, y no hace nada con la batería agotada.
  - `modal_state_changed` va a `set_input_blocked()` y a `set_modal_open()`.
  - `close_all()` en el game over.

  Cubre: R-005-16, R-005-19, R-005-20, R-005-22, R-005-24, R-005-27, R-005-29. Verifica: `godot-runner` y el
  juego en PC.
- [ ] **T-005-16 (usuario + Claude)** Probar en PC y exportar un APK debug al Android real:
  - interactuar con una caja abre su pantalla; tocar una pila la coge y "Coger todo" coge lo que cabe;
  - al vaciar la caja, la pantalla se cierra y la caja se desactiva;
  - con el inventario lleno sale "Inventario lleno", la caja se queda con el resto y se puede volver a abrir; tras
    hacer sitio, enseña lo mismo que quedaba;
  - el botón de almacenamiento y Tab abren el inventario: 5 ranuras con icono y cantidad, que se actualizan solas, y
    ninguna pasa del máximo;
  - con una pantalla abierta, el robot no se mueve ni interactúa, la batería baja y el joystick no aparece;
  - las pantallas se cierran con el botón, Tab, Escape y atrás en Android, y atrás sin pantalla no cierra el juego;
  - tocar el botón de almacenamiento no crea el joystick, y textos e iconos se leen bien en ES y EN;
  - con un dedo en el joystick, abrir el inventario con otro dedo: al soltar y cerrar, el robot no sigue andando
    solo (el `released` del joystick tiene que llegar con la pantalla encima);
  - ≥ 30 FPS con el `DebugHud` y una pantalla abierta.

  Cubre: criterio de hecho, R-005-23, R-005-28, R-005-33. Verifica: checklist manual.
- [ ] **T-005-17** Definición de hecho:
  - `godot-runner`, `i18n-auditor` y `balance-auditor` en paralelo, luego `architecture-guardian` una vez;
  - revisar el diff: sin literales de gameplay, iconos en `CREDITS.md`, un cambio lógico por commit;
  - actualizar "Repository state" en `CLAUDE.md`.

  Cubre: R-005-30, R-005-32. Verifica: informes de los agentes y revisión del diff.

## Cierre

- [ ] Definición de hecho (constitución §4) revisada. La CI corre al subir la rama (PR).
- [ ] Estado del spec actualizado en `spec.md` y en `specs/README.md §6`.
