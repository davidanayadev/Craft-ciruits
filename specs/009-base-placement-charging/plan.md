# Plan 009 — Escena de base, viaje entre zonas, colocación libre y estación de carga

| Campo | Valor |
|---|---|
| **Spec** | [spec.md](spec.md) (debe estar *Aprobado*) |
| **Estado** | Planificado (2026-11-17) |

> Escrito contra el código de la spec 008 tal como está en el árbol de trabajo de `feat/008-death-recovery`
> (`DeathController`, `DroppedItemSpawner`, `GameManager` con contador de visitas, `TransferScreen`). La 008 debe
> estar fusionada en `main` antes de implementar; si cambia antes, se revisan §1 "Viaje" y "Muerte con base" y §3.

## 1. Enfoque

**Capas (architecture §3).**

| Capa | Piezas |
|---|---|
| Datos | `ZoneData` (+ `kind`, `scene_path`), `BuildGridData` (celda, área, celdas reservadas), `StructureData`, `RecipeData` + `RecipeIngredientData`, `DataCatalog` (+ `zones`, `structures`, `recipes`) |
| Sistemas | `BuildGrid` (ocupación, límites, conversión celda ↔ posición, ida y vuelta en JSON), `CraftingSystem` (coste y "puede pagar"), `InventoryRules.remove_many` |
| Componentes | `InventoryComponent.remove_many` (cobro todo o nada), `PlayerInput` con motivos de bloqueo, `BatteryComponent.recharge_full` (ya existe) |
| Entidades | `Zone` (clase base de las zonas), `FarmZone extends Zone`, `BaseZone extends Zone`, `ExitPoint`, `RepairBench`, `ChargingStation` |
| Estado del mundo (nodos bajo `World`) | `BaseStructures` (estructuras colocadas, persiste entre zonas), `DroppedItemSpawner` (+ guardar y restaurar los objetos de una zona descargada) |
| Flujo | `ZoneLoader` (nodo de `Main`: carga, puebla, descarga, viaje), `BuildFlow` (nodo de `Main`: banco → pantalla de construcción → colocación, botón "Editar base") |
| Presentación | `LoadingScreen` (como `TransferScreen`, fuera de `UIManager`), `BuildScreen` y `PlacementScreen` (pantallas de `UIManager`), botón "Editar base" en `Hud`, cuadrícula visible en la base, botón de depuración "Llenar base" en `DebugHud` |
| Autoloads | `GameManager` (+ zona actual), `EventBus` (+ `zone_changed`, `structure_built`, `player_recharged`), `DataRegistry` (+ `get_zone`, `get_base_zone`, `get_structure`, `get_recipe`). Ninguno nuevo |

**Zonas como datos (R-009-01).**
- `ZoneData` gana `enum Kind { BASE, FARM }`, `kind` y `scene_path` (`@export_file("*.tscn")`). Una ruta y no un
  `PackedScene`: la escena de la zona ya referencia su `ZoneData` (`Zone.data`), y un `PackedScene` dentro del
  `ZoneData` haría un ciclo de recursos; además cargaría todas las zonas en memoria con el catálogo al arrancar,
  y architecture §6 pide carga en segundo plano. Formato de la ruta en el `.tres` y en Android: **(verificar)** 3.
- `ZoneData.counts_visits() -> bool` (`kind == FARM`): la regla "el contador solo vale para zonas `FARM`"
  (pregunta 12) vive en un sitio y la usan `ZoneLoader` (salida) y `DeathController` (muerte).
- `DataCatalog.zones` se indexa por `zone_id` (`Vector2i`), no por un `id` de texto: el `zone_id` ya es el id
  estable de una zona (architecture §10.3). `build_index()` informa de un `zone_id` repetido y de un número de
  zonas `BASE` distinto de uno. `get_base_zone()` devuelve la única: nadie escribe `(0, -1)` en un script.
- `base.tres`: `zone_id (0, -1)` (architecture §14), `BASE`, 20 x 20 m (BALANCE §5.6), sin cajas ni enemigos.
  `green_zone.tres` gana `FARM` y su ruta.

**Clase base `Zone`.** `FarmZone` y `BaseZone` comparten lo que `ZoneLoader` necesita: `data`, `get_spawn_position()`
y la señal `exit_requested(destination, traveller)`, que reenvía la de su `%ExitPoint`. `ZoneLoader` trabaja
con `Zone` y pregunta `data.kind` para lo propio de cada tipo. Es un contrato con dos implementaciones (como
`ITimeService`), no una abstracción de código repetido (constitución P2 pide esperar a la tercera repetición para
eso). `FarmZone` pasa de `extends Node3D` a `extends Zone` y mueve `data` y `get_spawn_position()` a la base; su
comportamiento no cambia.

**Viaje (R-009-02 a 09, 11 a 18).** `ZoneLoader.travel_to(zone_id) -> ActionResult`:
1. Comprueba en el momento: `zone_id` en el catálogo y ningún viaje en curso. Si no, `push_error` con el motivo,
   `ERR_INVALID_REQUEST` y nada cambia (R-009-06).
2. Marca el viaje, emite `travel_started(zone_id)` y pide la escena con `ResourceLoader.load_threaded_request`
   **(verificar)** 1. `Main` responde a `travel_started`: bloquea la entrada con el motivo `TRAVEL` en el acto,
   muestra `LoadingScreen` y congela `World` en diferido (el mismo `_set_world_frozen` de la 008, aplazado por la
   misma razón: la petición de viaje llega desde el paso de física del robot). Con el mundo congelado no baja la
   batería, no hay golpes ni IA (R-009-07). `CombatFeedback.release_all()` devuelve las chispas activas al pool.
   Queda una ventana de, como mucho, el resto de ese paso de física en la que un zombie podría golpear (§7).
3. Sondea el estado en `_process` (`ZoneLoader` cuelga de `Main`, no de `World`, así que sigue procesando). Si la
   carga falla: `push_error`, emite `travel_failed(zone_id)`, la zona actual sigue intacta (el contador de
   visitas tampoco ha cambiado, ver "Salir por un punto de salida") y `Main` descongela y quita `TRAVEL`.
4. Con la escena cargada, descarga la actual (R-009-04): `FarmZone.despawn_enemies()`,
   `DroppedItemSpawner.unbind_zone()` (guarda los suyos y los devuelve al pool), `BaseStructures.unbind_base()` si
   era la base; `remove_child` + `queue_free` de la zona, para que `ZoneSlot` nunca tenga dos (R-009-02).
5. Instancia la nueva en `ZoneSlot` **(verificar)** 2, fija `GameManager.set_current_zone(zone_id)` (único que la
   escribe, R-009-09) y la puebla: una `FarmZone` con `generate(seed, visita)` + `spawn_enemies` de la visita
   actual (R-009-16, mismas funciones que la reposición de la 008), después de precalentar `ZombiePool`,
   `ImpactPool` y `DroppedItemPool` con los máximos de la zona (lo que hoy hace `Main._ready`; idempotente, detrás
   de la pantalla de carga, constitución P12); la base con `BaseStructures.bind_base(base)`. Si la clase de la
   escena no casa con `data.kind` (`FarmZone` ↔ `FARM`, `BaseZone` ↔ `BASE`) o su `data` no es ese mismo
   `ZoneData`: `push_error`, `travel_failed` y la zona anterior intacta (además lo comprueba un test de datos).
   Después `DroppedItemSpawner.bind_zone(zone_id, zona)`, que restaura los objetos guardados de esa zona y descarta
   los caducados antes de nada más (R-009-17, R-008-23).
6. Pone cada robot de `Players` en el `SpawnPoint` de la zona, quieto (R-009-03), emite `zone_loaded(zone)` (señal
   local: `Main` y `BuildFlow` conectan las señales propias de esa zona), quita la marca, emite
   `EventBus.zone_changed(zone_id)` una vez y `travel_finished(zone_id)`. `Main` oculta la pantalla, descongela y
   quita el motivo `TRAVEL`.

- El viaje dura lo que tarde la carga, sin mínimo (pregunta 9). Siempre hay al menos un fotograma de pantalla de
  carga, porque la carga se sondea en `_process`.
- `travel_to` a la zona ya cargada la recarga (descarga y vuelve a cargar). Solo pasa al morir dentro de la base
  (R-009-52); así la muerte sigue un solo camino.
- **Salir por un punto de salida.** `ExitPoint` (escena con `InteractableComponent`, prompt `PROMPT_TRAVEL`, y
  el destino puesto en la instancia de cada zona, R-009-12) emite
  `travel_requested(destination, traveller)`; la zona lo reenvía como `exit_requested`. El destino es un
  `@export var destination: ZoneData` (el `.tres` de la zona destino), no un `Vector2i` copiado: el `zone_id` de
  cada zona vive solo en su `ZoneData` (P2). `ZoneLoader` llama a `travel_to(destination.zone_id)` y marca el
  viaje como "salida". **Sube el contador en el paso 4, al descargar de verdad la zona de origen**, solo si el viaje
  es una salida y esa zona `counts_visits()` (R-009-14). Si la carga falla, no sube nada. Entrar nunca lo toca
  (R-009-15). Sin coste de batería ni límite (R-009-11).
- **Reposición al subir la visita.** La escucha de `GameManager.zone_visit_changed` pasa de `Main` a `ZoneLoader`
  (lo previó la 008), sin excepciones: si la zona cuyo contador sube es la cargada, se repuebla (R-008-09). Al
  salir, cuando sube ya no es la cargada, así que no hay nada que repoblar; la siguiente carga trae la visita nueva
  (R-009-16). Al morir (sin viaje aún) repuebla como en la 008.
- **Arranque (R-009-08).** `ZoneSlot` empieza vacío en `main.tscn` (sale la instancia `GreenZone`). `Main._ready`
  llama a `travel_to(get_base_zone().zone_id)`. Arrancar también emite `zone_changed`; la 010 guardará al entrar
  en la base, también en ese primer viaje.
- **Nada de viajes desde el HUD (R-009-13).** Solo llaman a `travel_to` `ZoneLoader` (salidas), `Main` (arranque y
  muerte) y los tests. Lo comprueba un test que busca la llamada en los scripts.

**Objetos caídos fuera de su zona (R-009-04, R-009-17).**
- `DroppedItemSpawner.unbind_zone()`: guarda `to_data()` de cada objeto de la zona enlazada en
  `_stored: Dictionary[Vector2i, Array]` y lo devuelve al pool. `bind_zone(zone_id, root)` restaura los guardados
  de esa zona con su `uid`, posición local, hora de caída y pilas (con `DataRegistry` para resolver los ids), y
  llama a `discard_expired_now()`. Los datos guardados son tipos JSON (R-008-17): es el mismo camino que usará la
  010 para cargar, solo que desde memoria.
- Un id de objeto que el catálogo no conoce en la restauración: `push_error` y esa pila se pierde, nunca el resto.

**Muerte con base (R-009-51 a 53).**
- `DeathController` sube el contador solo si la zona de la muerte `counts_visits()` (pregunta 12): morir en la base
  no repuebla nada.
- `Main._on_transfer_finished` ya no reaparece en el sitio: marca `_respawn_pending` y viaja a la base. Al llegar
  (`travel_finished` con la marca), `DeathController.respawn(robot, base.get_spawn_position())` con la batería del
  ruleset (BALANCE §1.1, `normal.tres` ya tiene 1.0), y después quita los motivos `DEATH` y `TRAVEL`. El punto de
  reaparición sigue decidiéndose en un solo sitio (R-008-31).
- Si ese viaje falla (`travel_failed` con la marca puesta): `push_error` y reaparición en el `SpawnPoint` de la zona
  que sigue cargada, como en la 008. El juego no se queda parado con un robot muerto; el fallo ya está informado.
- Morir mientras se coloca o se mueve: `Main._on_player_died` ya llama a `UIManager.close_all()`; cerrar
  `PlacementScreen` es cancelar (no se cobró nada y la estructura no dejó sus celdas, R-009-53).

**Cuadrícula (R-009-23, 25 a 31).**
- `BuildGridData` (`resources/config/base_grid.tres`, configuración como los demás `.tres` de `config/`): `cell_size_m` 1.0 y `area_size_cells (12, 8)` de BALANCE §5.6;
  `area_origin_local` (esquina de la celda `(0, 0)` en coordenadas de la base) y `reserved_cells` son trazado de la
  escena de la base (BALANCE §5.6 los define como dato de la escena) y viven en el mismo `.tres`, al que apuntan la
  escena (`BaseZone.grid`) y `BaseStructures` (que lo necesita antes de que se cargue la base, para su estado). Un
  test comprueba que es el mismo recurso y que el nodo `BuildArea` está en `area_origin_local`.
- `BuildGrid` (`scripts/systems/`, `RefCounted`, sin nodos): guarda `uid → (structure_id, cell, footprint)` y la
  ocupación `cell → uid`. Valida una colocación si toda celda de la huella está dentro, no reservada, no ocupada
  por otra estructura (las de `moving_uid` no cuentan, R-009-45) y no está en `blocked` (las celdas de los robots,
  R-009-58). `move` libera y ocupa en un paso; inválido no cambia nada (R-009-26). `find_free_cell(footprint,
  near, blocked)` busca la celda válida más cercana a `near` y sirve también para "cabe en algún sitio"
  (R-009-27). Conversión: `cell_to_local(cell, footprint)` da el centro de la huella; `local_to_cell(local)` la
  celda que contiene ese punto (R-009-28).
- Estado en JSON (R-009-29, 31): `to_data()` = lista de `{"uid", "structure_id", "zone_id": [x, y], "cell": [x,
  y]}`; `load_data(data, catalog) -> ActionResult` valida todo antes de ocupar nada (ids conocidos, celdas
  válidas, sin solapes) y, si algo falla, deja la cuadrícula vacía como estaba. La huella sale del `StructureData`
  al cargar: no se guarda.
- "La base está llena" (R-009-38) se pregunta sin celdas bloqueadas: si el único sitio libre está bajo el robot,
  el jugador puede apartarse; el modo colocación ya marca esa celda en rojo.

**Estructuras colocadas (R-009-30, 32, 35, 36, 41, 42, 44, 50, 60).** `BaseStructures` (`scenes/base/`, nodo
bajo `World`, como `DroppedItemSpawner`) es el dueño de `BuildGrid` y del estado: sobrevive a la descarga de la
base. Con la base cargada (`bind_base`), instancia cada estructura en el nodo `%Structures` de la base, en su
celda; las instancias se van con la base al descargarla (no son de un pool: son estáticas y se recrean desde el
estado).
- `place(player, recipe, cell) -> ActionResult`: base enlazada (R-009-41), receta con estructura, celda válida con
  los robots bloqueados (si no, `ERR_INVALID_PLACEMENT`), `CraftingSystem.can_pay` (si no,
  `ERR_NOT_ENOUGH_MATERIALS`, la misma clave que muestra `BuildScreen`), después `player.inventory.remove_many(coste)`, `uid` nuevo
  (`Uid.generate`), ocupar, instanciar y `EventBus.structure_built(uid)` una vez (R-009-35). Cualquier fallo antes
  del cobro: nada cambia (R-009-36, 39). Sin tope de cantidad (R-009-42).
- `move(player, uid, cell) -> ActionResult`: mismo orden sin cobro; recoloca la instancia.
- `player` es la petición de un jugador (architecture §3 regla 4, §12): `place` cobra de su inventario; los dos
  rechazan un jugador nulo. En cooperativo, el anfitrión decidirá aquí quién puede (ONLINE.md).
- `set_interactions_enabled(false)` desactiva los `InteractableComponent` de las estructuras mientras se coloca o
  se mueve (R-009-50). El banco y el punto de salida no son estructuras colocadas: `structure_at(cell)` nunca los
  devuelve (R-009-20, R-009-60).
- Vista previa: es presentación de la base, no estado. `BaseZone.show_preview(structure, local_position, valid)` /
  `hide_preview()` instancian la escena de la estructura con un material translúcido verde o rojo
  (`resources/materials/preview_valid.tres`, `preview_invalid.tres`), sin colisión ni `InteractableComponent`
  activo, en su `%PreviewRoot` (R-009-33, 34). `PlacementScreen` la pide con la posición que le da
  `BaseStructures.cell_to_world`.
- Celdas de los robots: las que toca el círculo de cada robot de `Robot.PLAYER_GROUP` (radio de su
  `CapsuleShape3D`, leído por `Robot.get_footprint_radius()`); `BuildGrid.cells_in_radius` hace la cuenta.

**Construir desde el banco (R-009-61 a 65, 38, 39).**
- `RecipeData`: `id`, `ingredients: Array[RecipeIngredientData]` (`item: ItemData`, `quantity: int`), `station`
  (`enum Station { SELF, NANOBOTS, WORKBENCH }`, ACTION_PLAN 2.4), `tier`, `requires: Array[StringName]`,
  `result_structure: StructureData`. La 011 añade `result_item` para las piezas; hasta entonces un campo de
  resultado que nadie lee sería código muerto (P14).
- `CraftingSystem` (puro, sobre `Array[ItemStack]` como `InventoryRules`): `cost_of(recipe)` suma ingredientes
  repetidos; `can_pay(slots, recipe)` delega en `InventoryRules.can_remove_many(slots, cost_of(recipe))`, así la
  regla "hay de todo" existe una vez. El cobro lo hace el dueño del inventario: `InventoryComponent.remove_many(
  amounts)` comprueba todas las cantidades antes de quitar nada y emite un solo `inventory_changed`; la regla vive
  en `InventoryRules.remove_many`. Es el texto de R-009-62 tras la revisión del plan (2026-11-17): la versión
  anterior ponía la retirada en `CraftingSystem` tomando el inventario, y architecture §3 prohíbe que un sistema
  conozca nodos (`InventoryComponent` es un `Node`) y que nadie salvo el dueño escriba su estado. La 011 necesitará
  cobrar y añadir la pieza en una sola operación del dueño; se diseña allí.
- `RepairBench` (en la escena de la base, fijo): `InteractableComponent` con `PROMPT_USE`; emite `used(user)`, que
  `BaseZone` reenvía como `bench_used(user)`.
- `BuildFlow` (nodo de `Main`): con `bench_used` del robot local abre `BuildScreen`. La pantalla lista las recetas
  `WORKBENCH` con resultado de estructura del catálogo, con nombre y coste traducidos; el botón "Construir" de cada
  una se desactiva con su aviso si `not CraftingSystem.can_pay` (`ERR_NOT_ENOUGH_MATERIALS`) o si no cabe
  (`MSG_BASE_FULL`, R-009-38). Elegir una llama a `Robot.request_build(recipe)` (petición con firma, como
  `request_throw`), que emite `build_requested(player, recipe)`; la pantalla se cierra y `BuildFlow` abre
  `PlacementScreen` en modo colocar. No se cobra nada hasta confirmar (R-009-65).

**Colocación y edición (R-009-33 a 37, 40, 43 a 45, 55 a 60).** Una sola pantalla de `UIManager`,
`PlacementScreen`, con tres modos: `PLACE` (estructura nueva), `EDIT_PICK` (modo edición, sin vista previa) y
`MOVE` (estructura cogida).
- Ser una pantalla de `UIManager` da gratis lo que piden las preguntas 5 y 6: la entrada del robot se bloquea sin
  pausar el juego (la batería sigue bajando, R-009-57) y la muerte la cierra (R-009-53).
- Escape (`pause`) y el botón atrás de Android hacen lo mismo que "Cancelar" en cada modo (R-009-56). Hoy
  `UIManager` cierra la pantalla de arriba entera; se le añade una consulta: `UIScreen.handle_back() -> bool`
  (por defecto `false`). `UIManager` la llama a la pantalla de arriba antes de cerrarla y, si devuelve `true`, no
  cierra. `PlacementScreen` la usa para cancelar: en `MOVE` vuelve a `EDIT_PICK` y devuelve `true`; en los otros
  modos devuelve `false` y `UIManager` la cierra.
- Limpieza al cerrar por cualquier camino (botón, Escape, almacén, muerte con `close_all()`): `UIManager` llama a
  `UIScreen.on_closed()` (nuevo, vacío por defecto) en el acto, al sacar la pantalla de la pila y antes del
  `queue_free`. `PlacementScreen` ahí oculta la vista previa y la cuadrícula y vuelve a activar las estaciones. Su raíz es un `Control` a pantalla completa que
  recibe los toques en `_gui_input` antes que el joystick (que lee `_unhandled_input`); el `Hud` va encima y sus
  botones siguen respondiendo.
- Toque o clic → rayo de la cámara (`Camera3D.project_ray_origin/normal`, **(verificar)** 4) contra el plano del
  suelo de la base → `BuildGrid.local_to_cell`. Fuera del área, la vista previa no se mueve. En `EDIT_PICK`, tocar
  una celda con estructura la coge (`MOVE`); en `PLACE` y `MOVE`, la vista previa va a esa celda (R-009-55) y se
  pinta verde o roja con `BaseStructures.can_place` (R-009-34).
- Al entrar en `PLACE` o `MOVE`, la vista previa empieza en la celda válida más cercana al robot
  (`find_free_cell`), o en la de la propia estructura al moverla.
- Botones "Confirmar" y "Cancelar" (`PLACEMENT_CONFIRM`, `PLACEMENT_CANCEL`); en PC, la acción nueva `confirm`
  (Enter) confirma y `pause` cancela (R-009-56). Confirmar en celda inválida no hace nada y sigue en el modo
  (R-009-36). Confirmar bien en `PLACE` cierra la pantalla; en `MOVE` vuelve a `EDIT_PICK`. Cancelar en `MOVE`
  vuelve a `EDIT_PICK` con la estructura intacta (R-009-44); en `PLACE` o `EDIT_PICK` cierra.
- Mientras la pantalla está abierta: `set_interactions_enabled(false)` (R-009-50) y la cuadrícula de la base
  visible (`BuildArea.set_overlay_visible`).
- Botón "Editar base" (`HUD_EDIT_BASE`) en el `Hud`: visible solo con la base cargada (`BuildFlow` lo enciende con
  `zone_loaded`, R-009-59). Pulsado abre `PlacementScreen` en `EDIT_PICK`; pulsado otra vez la cierra
  (`UIManager.is_open(id)`, nuevo). Con otra pantalla abierta (inventario, construcción), el botón no hace nada:
  no se apila la colocación encima de otra pantalla. **Decisión del plan, aceptada (2026-11-17) y anotada en R-009-57**: el robot tampoco se mueve en `EDIT_PICK` (es la misma
  pantalla); el spec solo lo pide al colocar o mover, y separar los dos casos obligaría a una segunda vía de
  entrada para la misma pantalla.

**Bloqueo de entrada con motivos.** Hoy `PlayerInput.set_input_blocked(bool)` tiene dos dueños (pantallas y
transferencia); la 008 dejó escrito que con un tercero se pasaría a motivos (plan 008 §7). La 009 añade el viaje:
`set_input_blocked(blocked: bool, reason: StringName)` con `REASON_SCREEN`, `REASON_DEATH`, `REASON_TRAVEL`;
`is_input_blocked()` es "algún motivo activo" y `blocked_changed(blocked)` se emite solo cuando ese "algún motivo
activo" cambia (añadir un segundo motivo o quitar uno de dos no emite). `UIManager` se conecta
con `.bind(REASON_SCREEN)`. Los tests que hoy llaman con un argumento cambian la llamada, no lo que comprueban.

**Estación de carga (R-009-46 a 49).** `ChargingStation` (`scenes/base/charging_station.tscn`): `StaticBody3D` con
colisión 1 x 1 m (pregunta 7), malla de marcador de posición e `InteractableComponent` con `PROMPT_RECHARGE`. Al
interactuar un `Robot`: `robot.battery.recharge_full()` (emite `battery_changed`, R-009-48) y
`EventBus.player_recharged(robot.player_uid)` una vez (R-009-49; evento nuevo, se añade a architecture §7). No
guarda nada: la 010 escucha ese evento y `zone_changed`.

**Escena de la base (R-009-18 a 22).** `scenes/base/base.tscn` (`BaseZone extends Zone`):

| Nodo | Contenido |
|---|---|
| `Ground` | `GridMap` con la `MeshLibrary` de la zona verde (`green_zone_tiles.tres`) y un tile de suelo metálico CC0 si cabe en la librería; si no, el mismo suelo. Malla única descartada: el `GridMap` ya existe y se mide igual |
| `Boundaries` | Cuatro `StaticBody3D` con colisión; mallas bajas solo en norte y oeste (los lados que no tapan al robot con la cámara a 45°), sin techo (pregunta 11) |
| `SpawnPoint`, `ExitPoint` | Uno al lado del otro en el sur; `ExitPoint.destination = green_zone.tres` |
| `RepairBench` | Posición fija al norte del área edificable |
| `BuildArea` | Origen de la cuadrícula (`base_grid.tres`) y su dibujo (líneas, oculto fuera del modo colocación, **(verificar)** 5) |
| `Structures`, `PreviewRoot` | Padres de las estructuras instanciadas y de la vista previa |
| Luces | `DirectionalLight3D` con sombras + `WorldEnvironment` (los de la zona verde), dos `OmniLight3D` sin sombras como máximo; el resto de lámparas, material emisivo |
| Decoración | Cajas y barriles de primitivas o Kenney CC0, fuera del área edificable |

Sin `NavigationRegion3D` ni `ZombieSpawner` (R-009-18). Las celdas reservadas: delante del `SpawnPoint`, del
`ExitPoint` y del banco, en `base_grid.tres`.

## 2. Archivos

| Archivo (`game/…`) | Nuevo / Cambia | Responsabilidad |
|---|---|---|
| `scripts/data/zone_data.gd` | Cambia | `Kind`, `kind`, `scene_path`, `counts_visits()` |
| `scripts/data/build_grid_data.gd` | Nuevo | Celda, área, origen, celdas reservadas |
| `scripts/data/structure_data.gd` | Nuevo | Id, nombre, escena, huella |
| `scripts/data/recipe_data.gd`, `recipe_ingredient_data.gd` | Nuevo | Receta (ACTION_PLAN 2.4) e ingrediente |
| `scripts/data/data_catalog.gd` | Cambia | `zones` (índice por `zone_id`), `structures`, `recipes`, `get_base_zone()` |
| `scripts/autoload/data_registry.gd` | Cambia | `get_zone`, `get_base_zone`, `get_structure`, `get_recipe` |
| `scripts/autoload/game_manager.gd` | Cambia | Zona actual (`set_current_zone`, `get_current_zone_id`, `has_current_zone`) |
| `scripts/autoload/event_bus.gd` | Cambia | `zone_changed`, `structure_built`, `player_recharged` |
| `scripts/systems/build_grid.gd` | Nuevo | Reglas de la cuadrícula y estado en JSON |
| `scripts/systems/crafting_system.gd` | Nuevo | Coste de una receta y "puede pagar" |
| `scripts/systems/inventory_rules.gd` | Cambia | `remove_many` (comprobar todo, luego quitar) |
| `scripts/components/inventory_component.gd` | Cambia | `remove_many` (cobro todo o nada, una señal) |
| `scripts/components/player_input.gd` | Cambia | Motivos de bloqueo, `blocked_changed` |
| `scenes/zones/zone.gd` | Nuevo | Clase base `Zone` (script base de las escenas de zona, junto a ellas, como `scenes/ui/ui_screen.gd` para las pantallas) |
| `scenes/zones/exit_point.tscn` + `.gd` | Nuevo | Punto de salida con destino como dato |
| `scenes/zones/zone_loader.gd` | Nuevo | Viaje, carga, población y descarga |
| `scenes/farm_zone/farm_zone.gd` | Cambia | `extends Zone` |
| `scenes/farm_zone/farm_zone_green.tscn` | Cambia | `ExitPoint` junto al `SpawnPoint`, destino `(0, -1)` |
| `scenes/base/base.tscn` + `base_zone.gd` | Nuevo | Escena de la base (`BaseZone`) |
| `scenes/base/build_area.gd` | Nuevo | Dibujo de la cuadrícula |
| `scenes/base/repair_bench.tscn` + `.gd` | Nuevo | Banco fijo interactuable |
| `scenes/base/charging_station.tscn` + `.gd` | Nuevo | Estación de carga |
| `scenes/base/base_structures.gd` | Nuevo | Estructuras colocadas: estado, colocar, mover, vista previa |
| `scenes/base/build_flow.gd` | Nuevo | Banco → construcción → colocación; botón "Editar base" |
| `scenes/entities/dropped_item_spawner.gd` | Cambia | `unbind_zone`, restaurar en `bind_zone` |
| `scenes/entities/robot.gd` | Cambia | `build_requested`, `request_build`, `get_footprint_radius` |
| `scenes/death/death_controller.gd` | Cambia | Contador solo en zonas `FARM` |
| `scenes/feedback/combat_feedback.gd` | Cambia | `release_all()` |
| `scenes/main.gd`, `scenes/main.tscn` | Cambia | `ZoneSlot` vacío, `ZoneLoader`, `BaseStructures`, `BuildFlow`, `LoadingScreen`; arranque, viaje y reaparición en la base; sale la reposición (a `ZoneLoader`) |
| `scenes/ui/loading_screen.tscn` + `.gd` | Nuevo | Pantalla de carga (marcador de posición, ACTION_PLAN 4.4) |
| `scenes/ui/build_screen.tscn` + `.gd` | Nuevo | Lista de recetas de estructuras con coste |
| `scenes/ui/placement_screen.tscn` + `.gd` | Nuevo | Modos `PLACE`, `EDIT_PICK`, `MOVE` |
| `scenes/ui/ui_manager.gd`, `ui_screen.gd` | Cambia | `is_open(screen_id)`; `UIScreen.handle_back()` y `on_closed()` |
| `scenes/ui/hud.gd`, `hud.tscn` | Cambia | Botón "Editar base"; escucha `blocked_changed` del jugador en lugar de `set_modal_open` |
| `scenes/ui/touch_controls.gd` | — | Sin cambios: la pantalla de colocación se queda con los toques antes que el joystick |
| `scenes/ui/debug_hud.gd`, `.tscn` | Cambia | Botón "Llenar base" (solo depuración, para medir R-009-22): da al robot la chatarra justa y llama a `BaseStructures.place` en cada celda libre; ninguna ruta de depuración dentro de `BaseStructures` |
| `resources/zones/base.tres`, `green_zone.tres` | Nuevo / Cambia | Ver §4 |
| `resources/config/base_grid.tres` | Nuevo | Ver §4 |
| `resources/structures/charging_station.tres` | Nuevo | Ver §4 |
| `resources/recipes/charging_station.tres` | Nuevo | Ver §4 |
| `resources/materials/preview_valid.tres`, `preview_invalid.tres` | Nuevo | Vista previa verde / roja |
| `resources/data_catalog.tres`, `resources/ui/screens.tres` | Cambia | Zonas, estructuras, recetas; pantallas `build` y `placement` |
| `project.godot` | Cambia | Acción `confirm` (Enter, Enter del teclado numérico) |
| `i18n/strings.csv` (+ `.translation`) | Cambia | Claves de §4 |
| `specs/architecture.md` | Cambia | §7: fila de `player_recharged`; §8: `structures` en el catálogo |
| `tests/unit/…`, `tests/integration/…` | Nuevo / Cambia | §5 |

`scenes/zones/` es una carpeta nueva para lo común a todas las zonas (architecture §4: escenas con su script al
lado, por área).

## 3. Contratos

```gdscript
# --- Datos ---
class_name ZoneData
extends Resource
enum Kind { BASE, FARM }
@export var kind: Kind = Kind.FARM
@export_file("*.tscn") var scene_path: String     # (verificar) 3
# …campos de la 004 sin cambios…
func counts_visits() -> bool                       # kind == FARM

class_name BuildGridData
extends Resource
@export var cell_size_m: float = 0.0
@export var area_size_cells: Vector2i = Vector2i.ZERO
@export var area_origin_local: Vector3 = Vector3.ZERO   # corner of cell (0, 0), local to the base
@export var reserved_cells: Array[Vector2i] = []

class_name StructureData
extends Resource
@export var id: StringName
@export var name_key: StringName
@export var scene: PackedScene
@export var footprint: Vector2i = Vector2i.ONE

class_name RecipeIngredientData
extends Resource
@export var item: ItemData
@export var quantity: int = 0

class_name RecipeData
extends Resource
enum Station { SELF, NANOBOTS, WORKBENCH }
@export var id: StringName
@export var ingredients: Array[RecipeIngredientData] = []
@export var station: Station = Station.WORKBENCH
@export var tier: int = 1
@export var requires: Array[StringName] = []
@export var result_structure: StructureData

class_name DataCatalog                              # additions
@export var zones: Array[ZoneData] = []
@export var structures: Array[StructureData] = []
@export var recipes: Array[RecipeData] = []
func has_zone(zone_id: Vector2i) -> bool
func get_zone(zone_id: Vector2i) -> ZoneData        # unknown → push_error, null
func get_base_zone() -> ZoneData                    # the only BASE zone; none → push_error, null
func has_structure(id: StringName) -> bool
func get_structure(id: StringName) -> StructureData
func has_recipe(id: StringName) -> bool
func get_recipe(id: StringName) -> RecipeData
func get_recipes() -> Array[RecipeData]

# --- Sistemas ---
class_name BuildGrid
extends RefCounted
const NO_CELL := Vector2i(-1, -1)
func _init(p_config: BuildGridData, p_zone_id: Vector2i) -> void
func contains(cell: Vector2i) -> bool
func is_valid(footprint: Vector2i, cell: Vector2i, blocked: Array[Vector2i], moving_uid: String = "") -> bool
func occupy(uid: String, structure: StructureData, cell: Vector2i) -> ActionResult   # invalid → ERR_INVALID_PLACEMENT, no change
func move(uid: String, cell: Vector2i, blocked: Array[Vector2i]) -> ActionResult    # invalid → ERR_INVALID_PLACEMENT, no change
func get_cell(uid: String) -> Vector2i                                           # unknown → NO_CELL
func uid_at(cell: Vector2i) -> String                                            # "" when free
func get_uids() -> Array[String]
func get_structure_id(uid: String) -> StringName
func find_free_cell(footprint: Vector2i, near: Vector2i, blocked: Array[Vector2i]) -> Vector2i  # none → NO_CELL
func cell_to_local(cell: Vector2i, footprint: Vector2i) -> Vector3               # centre of the footprint
func local_to_cell(local: Vector3) -> Vector2i                                   # may be outside the area
func cells_in_radius(local: Vector3, radius: float) -> Array[Vector2i]
func to_data() -> Array[Dictionary]               # [{uid, structure_id, zone_id: [x, y], cell: [x, y]}]
func load_data(data: Array, catalog: DataCatalog) -> ActionResult   # all or nothing

class_name CraftingSystem
extends RefCounted
const ERR_NOT_ENOUGH_MATERIALS := &"ERR_NOT_ENOUGH_MATERIALS"
static func cost_of(recipe: RecipeData) -> Dictionary[StringName, int]
static func can_pay(slots: Array[ItemStack], recipe: RecipeData) -> bool

# InventoryRules (addition)
static func can_remove_many(slots: Array[ItemStack], amounts: Dictionary[StringName, int]) -> bool
static func remove_many(slots: Array[ItemStack], amounts: Dictionary[StringName, int]) -> void

# --- Componentes ---
# InventoryComponent (addition)
## Every amount or nothing: missing → ERR_NOT_ENOUGH_ITEMS, invalid → ERR_INVALID_REQUEST. One inventory_changed.
func remove_many(amounts: Dictionary[StringName, int]) -> ActionResult

# PlayerInput (changes)
signal blocked_changed(blocked: bool)
const REASON_SCREEN := &"screen"
const REASON_DEATH := &"death"
const REASON_TRAVEL := &"travel"
func set_input_blocked(blocked: bool, reason: StringName) -> void
func is_input_blocked() -> bool                     # any reason active

# --- Autoloads ---
# GameManager (additions)
func has_current_zone() -> bool
func get_current_zone_id() -> Vector2i
func set_current_zone(zone_id: Vector2i) -> void    # only ZoneLoader calls it (test)

# EventBus (additions)
signal zone_changed(zone_id: Vector2i)
signal structure_built(structure_uid: String)
signal player_recharged(player_uid: String)

# --- Zonas ---
class_name Zone
extends Node3D
signal exit_requested(destination: ZoneData, traveller: Node3D)
@export var data: ZoneData
func get_spawn_position() -> Vector3

class_name ExitPoint
extends Node3D
signal travel_requested(destination: ZoneData, traveller: Node3D)
@export var destination: ZoneData

class_name BaseZone
extends Zone
signal bench_used(user: Node3D)
@export var grid: BuildGridData
func get_structures_root() -> Node3D
func get_preview_root() -> Node3D
func get_floor_height() -> float                    # y of the build plane, global
func set_grid_visible(visible: bool) -> void
func show_preview(structure: StructureData, local_position: Vector3, valid: bool) -> void
func hide_preview() -> void

class_name ZoneLoader
extends Node
signal travel_started(zone_id: Vector2i)
signal zone_loaded(zone: Zone)
signal travel_finished(zone_id: Vector2i)
signal travel_failed(zone_id: Vector2i)
@export var zone_slot: Node3D
@export var players_root: Node3D
@export var zombie_pool: ObjectPool
@export var dropped_items: DroppedItemSpawner
@export var base_structures: BaseStructures
func travel_to(zone_id: Vector2i) -> ActionResult
func is_travelling() -> bool
func get_current_zone() -> Zone                     # null before the first travel ends

# --- Base ---
class_name RepairBench
extends Node3D
signal used(user: Node3D)

class_name ChargingStation
extends StaticBody3D
func set_interaction_enabled(enabled: bool) -> void

class_name BaseStructures
extends Node
@export var grid_config: BuildGridData
func bind_base(base: BaseZone) -> void
func unbind_base() -> void
func is_bound() -> bool
func fits_anywhere(structure: StructureData) -> bool
func can_place(structure: StructureData, cell: Vector2i, moving_uid: String = "") -> bool
func place(player: Robot, recipe: RecipeData, cell: Vector2i) -> ActionResult
func move(player: Robot, structure_uid: String, cell: Vector2i) -> ActionResult
func structure_at(cell: Vector2i) -> String
func get_structure(structure_uid: String) -> StructureData
func get_cell(structure_uid: String) -> Vector2i
func nearest_free_cell(structure: StructureData, world_position: Vector3) -> Vector2i
func cell_at(world_position: Vector3) -> Vector2i
func cell_to_world(structure: StructureData, cell: Vector2i) -> Vector3
func set_interactions_enabled(enabled: bool) -> void
func to_data() -> Array[Dictionary]
func load_data(data: Array) -> ActionResult
const ERR_INVALID_PLACEMENT := &"ERR_INVALID_PLACEMENT"

class_name BuildFlow
extends Node
@export var ui_manager: UIManager
@export var base_structures: BaseStructures
func bind(player: Robot, hud: Hud, zone_loader: ZoneLoader) -> void

# --- Entidades ---
# Robot (additions)
signal build_requested(player: Robot, recipe: RecipeData)
func request_build(recipe: RecipeData) -> void      # depleted battery → nothing
func get_footprint_radius() -> float

# DroppedItemSpawner (additions)
func unbind_zone() -> void                           # stores this zone's items, returns them to the pool
# bind_zone(zone_id, root) also restores the stored items of zone_id and discards the expired ones

# CombatFeedback (addition)
func release_all() -> void

# --- Presentación ---
class_name LoadingScreen
extends Control
func show_loading() -> void
func hide_loading() -> void
func is_showing() -> bool

class_name BuildScreen
extends UIScreen
const SCREEN_ID := &"build"
const CONTEXT_PLAYER := &"player"
const CONTEXT_BASE := &"base"

class_name PlacementScreen
extends UIScreen
const SCREEN_ID := &"placement"
const CONTEXT_PLAYER := &"player"
const CONTEXT_BASE := &"base"
const CONTEXT_RECIPE := &"recipe"                    # present → PLACE; absent → EDIT_PICK
enum Mode { PLACE, EDIT_PICK, MOVE }
func get_mode() -> Mode
func get_cell() -> Vector2i
func is_cell_valid() -> bool
func select_cell(cell: Vector2i) -> void             # pointer input ends here
func confirm() -> ActionResult
func cancel() -> void

# UIManager (addition)
func is_open(screen_id: StringName) -> bool

# Hud (changes)
signal edit_base_pressed
func set_edit_base_available(available: bool) -> void
# bind(player) also connects player.player_input.blocked_changed; set_modal_open() goes away
```

## 4. Datos

| Recurso / `.tres` | Campos | Valores desde |
|---|---|---|
| `zones/base.tres` (`ZoneData`) | `zone_id (0, -1)`, `kind BASE`, `size_m (20, 20)`, cajas y enemigos 0, `scene_path` de `base.tscn` | architecture §14; BALANCE §5.6; PMV §2.1 (zona segura) |
| `zones/green_zone.tres` | `kind FARM`, `scene_path` de `farm_zone_green.tscn`; el resto sin cambios | — |
| `config/base_grid.tres` (`BuildGridData`) | `cell_size_m 1.0`, `area_size_cells (12, 8)`; `area_origin_local` y `reserved_cells` del trazado de la base | BALANCE §5.6 |
| `structures/charging_station.tres` (`StructureData`) | `id charging_station`, `name_key STRUCTURE_CHARGING_STATION`, `footprint (1, 1)`, escena | BALANCE §5.6 |
| `recipes/charging_station.tres` (`RecipeData`) | `id charging_station`, 4 × `scrap`, `WORKBENCH`, tier 1, `requires []`, resultado la estación | BALANCE §5.1, §5.3; ACTION_PLAN 2.4 |
| `rulesets/normal.tres` | `respawn_battery_ratio 1.0` (ya existe) | BALANCE §1.1 |

Ningún número nuevo en BALANCE: la recarga es "al 100 %" (`recharge_full`), el viaje no cuesta (BALANCE §1.2) y la
pantalla de carga no tiene mínimo (pregunta 9).

Claves de traducción nuevas (ES + EN): `PROMPT_TRAVEL`, `PROMPT_RECHARGE`, `PROMPT_USE`, `LOADING_TITLE`,
`BUILD_TITLE`, `BUILD_BUTTON`, `BUILD_COST_ENTRY` (formato "%s x%d"), `STRUCTURE_CHARGING_STATION`,
`ERR_NOT_ENOUGH_MATERIALS`, `ERR_INVALID_PLACEMENT`, `MSG_BASE_FULL`, `PLACEMENT_CONFIRM`, `PLACEMENT_CANCEL`,
`PLACEMENT_HINT_PLACE`, `PLACEMENT_HINT_EDIT`, `HUD_EDIT_BASE`.

## 5. Verificación

Tests nuevos en `unit/`: `test_build_grid.gd`, `test_crafting_system.gd`, `test_structure_resources.gd`,
`test_recipe_resources.gd`, `test_build_grid_data.gd`, `test_exit_point.gd`, `test_charging_station.gd`, `test_repair_bench.gd`,
`test_build_screen.gd`, `test_placement_screen.gd`, `test_loading_screen.gd`. En `integration/`:
`test_zone_loader.gd`, `test_base_zone.gd`, `test_base_structures.gd`, `test_build_flow.gd`, `test_base_loop.gd`.

| Requisito | Test (`game/tests/…`) o paso manual |
|---|---|
| R-009-01 | `unit/test_zone_resources.gd::test_r_009_01_zone_kinds_and_scenes`, `::test_r_009_01_scene_root_matches_kind_and_data` (`ResourceLoader.exists`, raíz `FarmZone`/`BaseZone` según `kind`, `data` es el mismo recurso), `::test_r_009_01_base_zone_id_from_architecture`; `unit/test_data_catalog.gd::test_r_009_01_zones_indexed_by_zone_id`, `::test_r_009_01_exactly_one_base_zone`, `::test_r_009_01_every_zone_tres_listed` (filtra `resources/zones/` por tipo: ahí viven también el navmesh y la `MeshLibrary`) |
| R-009-02 | `integration/test_zone_loader.gd::test_r_009_02_one_zone_in_slot_after_each_travel` |
| R-009-03 | `test_zone_loader.gd::test_r_009_03_robot_on_arrival_point`, `::test_r_009_03_zone_changed_once` |
| R-009-04 | `test_zone_loader.gd::test_r_009_04_enemies_back_in_pool`, `::test_r_009_04_dropped_items_back_in_pool`; `integration/test_combat_feedback.gd::test_r_009_04_release_all_returns_sparks` |
| R-009-05 | `test_zone_loader.gd::test_r_009_05_round_trip_keeps_battery_inventory_xp` (architecture §6) |
| R-009-06 | `test_zone_loader.gd::test_r_009_06_unknown_zone_id`, `::test_r_009_06_travel_in_progress`, `::test_r_009_06_load_failure_keeps_zone_and_visit` (`ZoneData` de test con `scene_path` inexistente); `test_main_scene.gd::test_r_009_06_respawn_travel_failure_respawns_in_place` |
| R-009-07 | `integration/test_main_scene.gd::test_r_009_07_loading_screen_while_travelling`, `::test_r_009_07_world_frozen_and_input_blocked`; `unit/test_loading_screen.gd::test_r_009_07_texts_are_keys`; `unit/test_player_input.gd::test_r_009_07_reasons_block_independently` |
| R-009-08 | `test_main_scene.gd::test_r_009_08_starts_in_base_spawn`, `::test_r_009_08_zone_slot_empty_in_scene` |
| R-009-09 | `unit/test_game_manager.gd::test_r_009_09_current_zone`, `::test_r_009_09_only_zone_loader_sets_it` (búsqueda en scripts) |
| R-009-10 | `unit/test_exit_point.gd::test_r_009_10_prompt_travel`; `test_base_zone.gd` y `test_green_zone.gd::test_r_009_10_has_one_exit_point` |
| R-009-11 | `test_main_scene.gd::test_r_009_11_exit_travels_without_battery_cost`, `::test_r_009_11_two_round_trips_in_a_row` |
| R-009-12 | `test_exit_point.gd::test_r_009_12_destination_is_exported`; `test_base_zone.gd` / `test_green_zone.gd::test_r_009_12_exit_destinations` |
| R-009-13 | `test_zone_loader.gd::test_r_009_13_travel_to_callers` (búsqueda: solo `zone_loader.gd` y `main.gd`) |
| R-009-14 | `test_zone_loader.gd::test_r_009_14_leaving_farm_counts_one_visit` |
| R-009-15 | `test_zone_loader.gd::test_r_009_15_entering_counts_nothing`, `::test_r_009_15_leaving_base_counts_nothing` |
| R-009-16 | `test_zone_loader.gd::test_r_009_16_farm_populated_with_current_visit`, `::test_r_009_16_no_repopulation_while_travelling` |
| R-009-17 | `integration/test_dropped_item_spawner.gd::test_r_009_17_unbind_stores_and_rebind_restores`, `::test_r_009_17_expired_discarded_on_rebind`; `test_zone_loader.gd::test_r_009_17_items_back_after_round_trip` |
| R-009-18 | `test_base_zone.gd::test_r_009_18_no_navigation_region_nor_spawner`; `test_zone_loader.gd::test_r_009_18_no_enemies_in_base` |
| R-009-19 | `test_base_zone.gd::test_r_009_19_has_floor_bounds_spawn_exit_bench_area`, `::test_r_009_19_build_area_starts_empty`, `::test_r_009_19_robot_moves_in_base` (ACTION_PLAN 2.1), `::test_r_009_19_bounds_stop_robot` |
| R-009-20 | `test_base_structures.gd::test_r_009_20_bench_not_pickable` |
| R-009-21 | `test_base_zone.gd::test_r_009_21_battery_drains_in_base`; `test_zone_loader.gd::test_r_009_21_entering_base_does_not_recharge` (batería por debajo del máximo antes del viaje) |
| R-009-22 | Manual (T-009-17): APK debug en el Android de gama media, base con el área llena (botón "Llenar base" del `DebugHud`), FPS ≥ 30 durante 60 s en el contador del `DebugHud`; triángulos y llamadas de dibujo con el monitor del editor en PC (remoto) |
| R-009-23 | `unit/test_build_grid_data.gd::test_r_009_23_values_from_balance`, `::test_r_009_23_reserved_cells_inside_area`; `test_base_zone.gd::test_r_009_23_same_grid_resource_and_origin` |
| R-009-24 | `test_structure_resources.gd::test_r_009_24_charging_station_footprint`, `::test_r_009_24_no_rotation_field`; `test_data_catalog.gd::test_r_009_24_structures_listed` |
| R-009-25 | `test_build_grid.gd::test_r_009_25_outside_limits`, `::test_r_009_25_reserved_cell`, `::test_r_009_25_occupied_cell`, `::test_r_009_25_blocked_cell`, `::test_r_009_25_footprint_partly_outside` |
| R-009-26 | `test_build_grid.gd::test_r_009_26_move_frees_old_cells`, `::test_r_009_26_invalid_move_keeps_place` |
| R-009-27 | `test_build_grid.gd::test_r_009_27_fits_somewhere`, `::test_r_009_27_full_grid_fits_nowhere` |
| R-009-28 | `test_build_grid.gd::test_r_009_28_cell_local_round_trip_every_cell` |
| R-009-29 | `test_base_structures.gd::test_r_009_29_uid_and_zone_cell` |
| R-009-30 | `test_base_structures.gd::test_r_009_30_survive_unbind_and_rebind`; `test_base_loop.gd` |
| R-009-31 | `test_build_grid.gd::test_r_009_31_data_is_json_types`, `::test_r_009_31_round_trip_same_cells`, `::test_r_009_31_bad_data_changes_nothing` |
| R-009-32 | `test_base_structures.gd::test_r_009_32_place_returns_result_and_takes_player`, `::test_r_009_32_null_player_rejected` |
| R-009-33 | `test_placement_screen.gd::test_r_009_33_preview_snapped_to_cell`, `::test_r_009_33_starts_near_robot` |
| R-009-34 | `test_placement_screen.gd::test_r_009_34_valid_green_invalid_red` |
| R-009-35 | `test_base_structures.gd::test_r_009_35_place_charges_and_emits_once`; `test_placement_screen.gd::test_r_009_35_confirm_places_and_closes` |
| R-009-36 | `test_base_structures.gd::test_r_009_36_invalid_cell_charges_nothing`; `test_placement_screen.gd::test_r_009_36_invalid_confirm_stays` |
| R-009-37 | `test_placement_screen.gd::test_r_009_37_cancel_charges_nothing` |
| R-009-38 | `test_build_screen.gd::test_r_009_38_full_base_disables_with_notice`; `test_base_structures.gd::test_r_009_38_fits_anywhere` |
| R-009-39 | `test_build_screen.gd::test_r_009_39_missing_materials_disables`; `test_base_structures.gd::test_r_009_39_cannot_pay_changes_nothing` |
| R-009-40 | `unit/test_input_map.gd::test_r_009_40_confirm_action`; `test_placement_screen.gd::test_r_009_40_texts_are_keys`, `::test_r_009_40_confirm_action_confirms`; manual (T-009-17): toque y ratón en PC y en Android |
| R-009-41 | `test_base_structures.gd::test_r_009_41_place_refused_without_base`; `test_hud.gd::test_r_009_59_edit_button_only_in_base` |
| R-009-42 | `test_base_structures.gd::test_r_009_42_place_until_full` |
| R-009-43 | `test_placement_screen.gd::test_r_009_43_move_at_no_cost` |
| R-009-44 | `test_placement_screen.gd::test_r_009_44_cancel_move_keeps_cells_and_uid` |
| R-009-45 | `test_build_grid.gd::test_r_009_45_move_onto_own_cells` |
| R-009-46 | `test_charging_station.gd::test_r_009_46_prompt_recharge` |
| R-009-47 | `test_charging_station.gd::test_r_009_47_recharges_to_maximum` |
| R-009-48 | `test_charging_station.gd::test_r_009_48_through_battery_method` (`battery_changed` emitido); `unit/test_battery_component.gd::test_r_009_48_recharge_full_emits_change` |
| R-009-49 | `test_charging_station.gd::test_r_009_49_player_recharged_once` |
| R-009-50 | `test_base_structures.gd::test_r_009_50_stations_disabled_while_placing`; `test_placement_screen.gd::test_r_009_50_reenabled_on_close` |
| R-009-51 | `test_main_scene.gd::test_r_009_51_death_in_zone_respawns_in_base` |
| R-009-52 | `test_main_scene.gd::test_r_009_52_death_in_base` (objeto caído sigue en la base tras recargarla); `integration/test_death_controller.gd::test_r_009_52_base_death_counts_no_visit` |
| R-009-53 | `test_main_scene.gd::test_r_009_53_death_while_placing_cancels`, `::test_r_009_53_death_while_moving_keeps_cells` |
| R-009-54 | `integration/test_base_loop.gd::test_r_009_54_full_loop`; manual (T-009-17) en PC y Android |
| R-009-55 | `test_placement_screen.gd::test_r_009_55_tap_moves_preview` (`select_cell` y, por separado, la conversión pantalla → celda con la cámara de la base) |
| R-009-56 | `test_placement_screen.gd::test_r_009_56_confirm_and_cancel_buttons`, `::test_r_009_56_pause_cancels`, `::test_r_009_56_pause_in_move_back_to_edit`; `unit/test_ui_manager.gd::test_r_009_56_handle_back_keeps_screen`, `::test_r_009_56_on_closed_called_on_close_all`; atrás de Android: manual (T-009-17) |
| R-009-57 | `test_main_scene.gd::test_r_009_57_robot_still_and_draining_while_placing` |
| R-009-58 | `test_base_structures.gd::test_r_009_58_robot_cell_invalid` |
| R-009-59 | `test_hud.gd::test_r_009_59_edit_button_only_in_base`, `::test_r_009_59_text_is_key`; `test_main_scene.gd::test_r_009_59_edit_button_toggles` |
| R-009-60 | `test_placement_screen.gd::test_r_009_60_tap_structure_picks_it`, `::test_r_009_60_tap_empty_cell_picks_nothing`; `test_base_structures.gd::test_r_009_60_exit_point_not_pickable` |
| R-009-61 | `test_recipe_resources.gd::test_r_009_61_charging_station_recipe`; `test_data_catalog.gd::test_r_009_61_recipes_listed_and_refs_exist` |
| R-009-62 | `test_crafting_system.gd::test_r_009_62_exact`, `::test_r_009_62_surplus`, `::test_r_009_62_insufficient`, `::test_r_009_62_repeated_ingredient`; `unit/test_inventory_component.gd::test_r_009_62_remove_many_all_or_nothing` |
| R-009-63 | `test_repair_bench.gd::test_r_009_63_interactable_with_key` |
| R-009-64 | `test_build_screen.gd::test_r_009_64_lists_recipes_with_name_and_cost`, `::test_r_009_64_texts_are_keys`; `test_main_scene.gd::test_r_009_64_bench_opens_build_screen` |
| R-009-65 | `test_build_screen.gd::test_r_009_65_pick_requests_placement_without_cost`; `integration/test_build_flow.gd::test_r_009_65_build_requested_opens_placement` |

Puntos **(verificar)** (T-009-01, en la referencia de clases de Godot 4.7.2 con `--doctool` y con scripts de prueba
en headless fuera del repo):

1. `ResourceLoader.load_threaded_request`, `load_threaded_get_status`, `load_threaded_get` en 4.7.2, también en
   headless (tests) y con un `.tscn` ya cargado en caché.
2. Un nodo añadido bajo un padre `PROCESS_MODE_DISABLED` recibe `_ready` en ese momento; una `NavigationRegion3D`
   con navmesh horneado añadida así registra su mapa y los zombies navegan al descongelar.
3. Qué guarda `@export_file` en el `.tres` (`uid://` o `res://`) y que `ResourceLoader` lo resuelve en un APK
   exportado (los recursos cambian a `.remap`).
4. `Camera3D.project_ray_origin` / `project_ray_normal` con proyección ortográfica, y el tipo de retorno de
   `Plane.intersects_ray` con los avisos del proyecto como error.
5. Dibujar líneas con `ImmediateMesh` en el renderer Compatibility; si no sirve, `MultiMeshInstance3D` con cajas
   finas.
6. Un `Control` a pantalla completa recibe `InputEventScreenTouch` en `_gui_input` en Android y los botones de un
   `Control` hermano posterior (el `Hud`) los reciben antes.
7. `remove_child` + `queue_free` de una zona con `World` desactivado mientras el `InteractorComponent` del robot
   apunta a un `InteractableComponent` de esa zona: sin errores (008 §5.1 punto 5 es parecido).

### 5.1 Resultado de los puntos (verificar) (T-009-01, 2026-11-17)

Godot 4.7.2 (`--doctool` y scripts de prueba con `-s` contra `game/`, fuera del repo).

| # | Resultado | Efecto en el plan |
|---|---|---|
| 1 | ✅ `load_threaded_request` → `OK`; `load_threaded_get_status` pasa por `IN_PROGRESS` (30 fotogramas la primera vez para `farm_zone_green.tscn` en headless) a `LOADED`; con la escena en caché, `LOADED` en el acto. Una ruta inexistente: la petición también devuelve `OK`, pasa por `IN_PROGRESS` y acaba en `FAILED` (unos 5 fotogramas), con dos `ERROR` del motor (`Cannot open file`, `Failed loading resource`) | Sin cambios. El fallo de carga se detecta en el sondeo, no en la petición; el test del fallo espera esos errores del motor |
| 2 | ✅ Un nodo añadido bajo un padre `PROCESS_MODE_DISABLED` recibe `_ready` en el acto; la `NavigationRegion3D` registra su mapa (1 región) y, al descongelar, `map_get_path` devuelve camino (20 puntos) | Sin cambios |
| 3 | ⚠️ Parcial. Las escenas del proyecto no tienen `uid` en su cabecera, así que la ruta se escribe como `res://…tscn` en el `.tres`; `ResourceLoader` la resuelve en headless. La resolución en el APK (`.remap`) no se puede probar en headless: la cubre T-009-17, y el primer arranque ya la ejercita (el juego empieza cargando `base.tscn` por esa ruta) | Sin cambios; anotado para T-009-17 |
| 4 | ✅ Con proyección ortográfica, `project_ray_origin` / `project_ray_normal` dan un rayo paralelo a la vista; `Plane.intersects_ray` devuelve `Variant` (`Vector3`, o `null` sin corte) | Sin cambios (asignar a `Vector3` tras comprobar `null`) |
| 5 | ✅ `ImmediateMesh` con `PRIMITIVE_LINES` y material sin sombreado se dibuja con el renderer Compatibility (`opengl3`, ventana de 640x360) | Sin cambios |
| 6 | ⚠️ Con `emulate_mouse_from_touch` activo (por defecto), un `Control` recibe el toque en `_gui_input` como `InputEventMouseButton` emulado, no como `InputEventScreenTouch`; el `InputEventScreenTouch` sigue llegando a `_unhandled_input`. Un `Button` hermano posterior se queda el clic antes que el `Control` de fondo | `PlacementScreen` lee el botón izquierdo del ratón (también el emulado) en `_gui_input`. El joystick flotante puede seguir viendo el toque, pero la entrada del robot está bloqueada mientras la pantalla está abierta, así que no se mueve. Android: manual en T-009-17 |
| 7 | ✅ Descargar la zona con `World` desactivado mientras el interactor apunta a una caja: sin errores; el objetivo pasa a `null` y `request_interact` no hace nada | Sin cambios |

### 5.2 Pruebas manuales (T-009-17, 2026-11-17)

Hechas por la persona que revisa en PC (Windows) y en el Android de gama media (APK debug). Resultado según su
informe: todo pasa.

| Prueba | PC | Android |
|---|---|---|
| El juego arranca en la base (incluida la ruta de `base.tscn` en el APK, §5.1 punto 3) | ✅ | ✅ |
| Criterio de hecho del spec §5 | ✅ | ✅ |
| Colocación con ratón y con toque | ✅ | ✅ |
| Botón atrás de Android cancela (§5.1 punto 6) | — | ✅ |
| FPS ≥ 30 durante 60 s con la base llena | ✅ | ✅ |

No se anotaron cifras de FPS, solo que se cumple el mínimo.

### 5.3 Desviaciones de implementación (2026-11-17)

Cambios menores respecto a §1-§4, ninguno toca un requisito:

- **Trazado de la base** (`base_grid.tres`): origen del área en `(-6, 0, -5)` local; celdas reservadas `(5, 0)` y
  `(6, 0)` (frente del banco, en `(0, 0, -6.5)`), `(3, 7)` (frente del `SpawnPoint`, en `(-2.5, 0, 5)`) y `(8, 7)`
  (frente del `ExitPoint`, en `(2.5, 0, 5)`). Aparición y salida quedan fuera del área y a más de 2 m entre sí, para
  que llegar no ofrezca ya "Viajar". Suelo: el tile `dirt` de `green_zone_tiles.tres` (no se añadió un tile
  metálico a la librería compartida).
- **`ChargingStation.set_interaction_enabled`** no existe: `BaseStructures.set_interactions_enabled` apaga y
  enciende el `InteractableComponent` de cada estructura colocada, sea del tipo que sea (sirve igual para el
  generador y los cofres de la 012).
- **`BaseStructures`** gana `get_base()` e `is_in_area(cell)`; la `PlacementScreen` recibe `BaseStructures` como
  `CONTEXT_BASE` y obtiene de ahí la `BaseZone` para la vista previa y el rayo.
- **`BaseZone`** gana `is_grid_visible()` y `get_preview()`; **`BuildArea`**, `is_overlay_visible()` (para tests).
- **`ZoneLoader`** exporta también `impact_pool` y `dropped_item_pool` (los precalienta, §1 paso 5).
- **`RepairBench`** es un `StaticBody3D` (tiene colisión), no un `Node3D` sin cuerpo.
- **`DebugHud.bind_base_structures()`** le da al botón "Llenar base" su `BaseStructures`.
- **`DeathController`** consulta el catálogo para saber si la zona de la muerte `counts_visits()`; una zona que el
  catálogo no conoce se informa con `push_error` y no cuenta visita. Por eso el `ZONE_ID` de
  `test_death_controller.gd` pasa a ser la zona verde.
- **`test_placement_screen.gd`** vive en `integration/` (necesita la escena de la base y un `UIManager` real).
- **Chispas al viajar**: `Main` llama a `CombatFeedback.release_all()` en `travel_started` (no `ZoneLoader`): las
  chispas cuelgan de `World`, no de la zona, y `ZoneLoader` no conoce `CombatFeedback`.
- **Joystick al abrir la colocación**: `BuildFlow` no llama a `FloatingJoystick.cancel()`. La entrada del robot está
  bloqueada mientras la pantalla está abierta, así que no se mueve; si el aro del joystick se queda visible con el
  dedo puesto, se verá en T-009-17.
- **Revisión de `architecture-guardian` (2026-11-17)**, aplicado: el congelado de `World` lleva motivos en `Main`
  (`DEATH`, `TRAVEL`, como `PlayerInput`), y una muerte en el mismo paso en que se usa una salida espera al final de
  ese viaje y reaparece en la base (tests `test_r_009_51_death_in_exit_step_waits_for_base` y
  `test_r_009_51_transfer_ends_during_exit_travel`); `ZoneLoader` empieza a sondear la carga en diferido, detrás del
  congelado; `Robot.place_at()` es la vía del robot para colocarse al llegar; `BaseStructures.place` ocupa las celdas
  antes de cobrar y las suelta si el cobro falla (`BuildGrid.remove`); el inventario no se abre durante un viaje;
  Enter en `EDIT_PICK` no hace nada. Aceptado sin cambio: en ese caso extremo (salir y morir en el mismo paso) la zona
  de origen suma dos visitas, una por la muerte (R-008-07) y otra por la salida (R-009-14).
- **Bloqueo en `EDIT_PICK`**: se implementó como propone §1 (el robot tampoco se mueve con el modo edición abierto
  sin nada cogido); aceptado por la persona que revisa (2026-11-17) y anotado en R-009-57.

## 6. Check de constitución

| Principio | Cumple | Nota |
|---|---|---|
| P1 Spec primero | ✅ | Spec *Aprobado*; la 008 fusionada antes de empezar |
| P2 Una fuente de verdad | ✅ | Coste, huella, celda y área en `.tres` desde BALANCE §5.1, §5.3, §5.6; cada `zone_id` solo en su `ZoneData` (los puntos de salida apuntan al `.tres` destino); "cuenta visitas" en `ZoneData.counts_visits`; el punto de reaparición sigue en un sitio |
| P3 Lógica separada | ✅ | `BuildGrid`, `CraftingSystem` e `InventoryRules.remove_many` sin nodos; las pantallas solo piden a `BaseStructures` y a `Robot` |
| P4 Estado por jugador | ✅ | Batería, inventario y XP siguen en el robot; estructuras, objetos caídos y zona actual son estado del mundo (`World` y `GameManager`) |
| P5 Datos como recursos | ✅ | `StructureData`, `RecipeData`, `RecipeIngredientData`, `BuildGridData` en `resources/`, catalogados |
| P6 Señales | ✅ | Eventos nuevos en `EventBus` y en architecture §7; señales locales para zona, banco, salida, viaje; referencias con `%` y `@export` |
| P7 Tipado | ✅ | Todo tipado; `Plane.intersects_ray` devuelve `Variant`: se asigna a variable tipada tras comprobar `null` (verificar 4) |
| P8 Plataforma | ✅ | Toques y clics solo en `PlacementScreen` (capa de UI); gameplay lee acciones (`confirm`, `pause`) y `PlayerInput` |
| P9 Determinismo | ✅ | Posiciones `(zone_id, celda)` y `(zone_id, posición local)`; la carga de zona usa la misma generación con semilla + visita |
| P10 Servicios | ✅ | Sin servicios nuevos; el reloj de los objetos caídos sigue en `ITimeService` |
| P11 i18n | ✅ | Claves de §4 en ES y EN; `DebugHud` exento (solo depuración, como en la 007) |
| P12 Presupuesto móvil | ✅ | Base sin navmesh, 1 direccional con sombras + ≤ 2 omni sin sombras; medida en Android (R-009-22); zombies y objetos caídos devueltos al pool al descargar |
| P13 Test primero | ✅ | Tareas de lógica con test antes; cada requisito en §5 |
| P14 Alcance | ⚠️ | Tres cambios fuera de lo que el spec nombra, todos necesarios para cumplirlo: **(a)** clase base `Zone` (el cargador necesita un tipo común); **(b)** motivos de bloqueo en `PlayerInput` (tercer dueño del bloqueo, previsto en el plan 008 §7); **(c)** botón "Llenar base" en `DebugHud`, solo depuración, para poder medir R-009-22 sin juntar 360 de chatarra. Y una decisión pequeña: el robot tampoco se mueve en `EDIT_PICK` (§1). R-009-62 se reescribió en la revisión del plan para casar con architecture §3 (§1 "Construir desde el banco") |

## 7. Riesgos y alternativas descartadas

**Riesgos.**
- **Tests de `main.tscn` que dan por cargada la zona verde** → con R-009-08 el juego empieza en la base. Unos 30
  tests de `test_main_scene.gd` y `test_hud_attack_input.gd` necesitan la zona verde: un ayudante
  `_travel_to_green_zone()` en su `before_each` viaja y espera `travel_finished`. Cambia la preparación, no lo que
  comprueban. R-009-08 sustituye a R-004-05 (anotado en el spec): `test_r_004_05_green_zone_loaded` se renombra a `test_r_009_08_green_zone_loaded_after_travel` y comprueba la zona verde tras el viaje.
- **Carga asíncrona en los tests** → los tests esperan la señal (`wait_for_signal` con tiempo máximo), no un
  número fijo de fotogramas.
- **Repoblar justo antes de descargar** → al morir en la zona se repuebla (R-008-09) y, tras la transferencia, se
  descarga. Es trabajo tirado detrás de una pantalla; se acepta para no cambiar la 008. Al salir por la salida no
  pasa: el contador sube al descargar la zona, cuando ya no es la cargada.
- **Joystick y toques de colocación** → la pantalla se queda con los toques en `_gui_input` (verificar 6). Si el
  dedo ya estaba en el joystick al abrirla, la entrada del robot sigue bloqueada; al final `BuildFlow` no llama a
  `FloatingJoystick.cancel()` (§5.3) y lo comprueba T-009-17.
- **Pulsar "Inventario" con la colocación abierta** → `Main._on_storage_pressed` cierra la pantalla de arriba, que
  es cancelar. Se acepta: no gasta nada.
- **Recarga de la base al morir dentro** → descarga y vuelve a cargar la base (una escena pequeña) detrás de la
  transferencia. Más sencillo que una segunda vía de reaparición.
- **`main.gd` crece** → la colocación va a `BuildFlow` y la vida de la zona a `ZoneLoader`; `main.gd` pierde la
  reposición y el cableado de la zona verde fija. Objetivo: no pasar de su tamaño actual.
- **Sondeo de la carga en `_process`** → solo mientras hay viaje (`set_process` solo entonces), no en cada
  fotograma de juego (architecture §11).
- **Golpe en el paso de física de la salida** → el congelado va en diferido (como en la 008); un zombie que ataque
  en ese mismo paso puede quitar batería una vez. No se puede mitigar sin congelar en mitad del paso físico, que es
  lo que la 008 evitó. Se acepta: es como morir el golpe justo antes de llegar.
- **Objetos caídos guardados de una zona sin cargar** → no caducan mientras no se carga; se descartan al volver,
  antes de que nadie interactúe (R-008-23). Igual que hará la 010 al cargar la partida.

**Alternativas descartadas.**
- **`PackedScene` en `ZoneData`.** Ciclo de recursos con `Zone.data` y todas las zonas en memoria desde el
  arranque.
- **Subir la visita en `ZoneLoader` al descargar cualquier zona `FARM`** (también al morir). Un solo sitio, pero
  movería la subida de la 008 al final de la transferencia y cambiaría sus tests.
- **`CraftingSystem.pay(inventory: InventoryComponent, recipe)`.** Es lo que dice R-009-62 al pie de la letra, pero
  un sistema no conoce nodos ni escribe el estado de otro (architecture §3 reglas 1 y 3).
- **Modo colocación como capa propia fuera de `UIManager`.** Habría que reprogramar Escape, atrás de Android, el
  bloqueo del robot, el cierre al morir y el reparto de toques con el joystick.
- **Estructuras en `GameManager`.** También es estado del mundo, pero un nodo bajo `World` sigue el camino de los
  objetos caídos de la 008 y la 010 los guardará igual (grupo `persistent`, architecture §10.2).
- **Estructuras como hijas de un nodo fuera de la zona.** Se verían en la zona verde; como hijas de la base se van
  con ella y se recrean desde el estado.
- **Rotación y huellas no cuadradas.** Fuera del PMV (pregunta 4).
- **Viaje síncrono en un fotograma.** La pantalla de carga no llegaría a verse (R-009-07).

### 7.1 Revisión de `architecture-guardian` (2026-11-17)

Aplicado en este plan:
- **Bloqueante — R-009-62.** El texto aprobado pedía la retirada de ingredientes dentro de `CraftingSystem`
  tomando el inventario; el plan la hace el dueño (`InventoryComponent.remove_many`) con una regla pura de
  `InventoryRules`. Se reescribió R-009-62 en el spec para que diga eso (§1 "Construir desde el banco").
- El contador de visitas al salir sube al **descargar** la zona de origen, no al empezar el viaje: un fallo de carga
  ya no deja el contador en N+1 con la zona de la visita N, y desaparece la excepción a R-008-09.
- Escape y atrás de Android hacen lo mismo que "Cancelar" en cada modo (`UIScreen.handle_back`); limpieza al cerrar
  por cualquier camino (`UIScreen.on_closed`).
- Fallo de carga con test, y reaparición en el sitio si falla el viaje de reaparición.
- `ZoneLoader` precalienta los pools al cargar una zona `FARM` (antes lo hacía `Main._ready`).
- Tests nuevos: `test_build_flow.gd` (R-009-65), morir moviendo (R-009-53), Escape en `MOVE` (R-009-56), dos
  viajes seguidos (R-009-11), entrar en la base con batería por debajo del máximo (R-009-21), punto de salida no
  seleccionable (R-009-60), objeto caído en la base tras morir dentro (R-009-52), escena y `data` de cada
  `ZoneData`, misma cuadrícula en base y `BaseStructures`.
- `ExitPoint.destination` es un `ZoneData`, no un `Vector2i` copiado; `BuildGrid.occupy` / `move` devuelven
  `ActionResult`; `kind` y clase de la escena se comprueban; vista previa en `BaseZone`; `base_grid.tres` en
  `resources/config/`; una sola clave (`ERR_NOT_ENOUGH_MATERIALS`) para la falta de materiales; `blocked_changed`
  solo al cambiar "algún motivo"; "Llenar base" usa `place`; R-009-08 anota que sustituye a R-004-05.

En desacuerdo:
- **`zone.gd` en `scripts/`.** Es el script base de las escenas de zona, no lógica reutilizable sin escena: va junto
  a ellas, como `scenes/ui/ui_screen.gd` para las pantallas (architecture §4: presentación con su escena).

Decidido por la persona que revisa (2026-11-17):
- Bloquear el robot también en `EDIT_PICK` (§1 "Colocación y edición"): aceptado ("si editas no te mueves") y
  anotado en R-009-57.
