# Plan 013 — Cajas de loot en sitios variables y nueva pantalla de contenedor

| Campo | Valor |
|---|---|
| **Spec** | [spec.md](spec.md) (debe estar *Aprobado*) |
| **Estado** | Planificado (2026-11-21) |

## 1. Enfoque

Dos partes independientes, cada una en su capa (architecture §3):

1. **Cajas por sitios y por visita.** La escena de la zona verde agrupa sus marcadores en 6 sitios (nodos `Node3D`
   bajo `%BoxMarkers`, cada uno con 3-4 `Marker3D`). `ZonePopulation.pick_box_markers` pasa a recibir cuántos
   marcadores tiene cada sitio y el máximo por sitio, y sigue siendo pura. `FarmZone` crea su RNG con el número de
   visita como índice del stream `box_placement` (igual que los zombies con `enemy_spawn`) y `repopulate()` vuelve
   a elegir marcadores en lugar de reponer en los mismos. `ZoneData` gana `box_max_per_site`. El formato guardado no
   cambia: una caja abierta se sigue identificando por su índice de marcador.
2. **Pantalla de contenedor con ficha fija.** `ContainerScreen` se reorganiza: cabecera con nombre y ocupación sobre
   cada rejilla y una ficha de acción de tamaño fijo debajo. La pantalla tiene tres estados (sin selección,
   selección, colocando) y un solo método pinta la ficha a partir del estado. Tocar solo selecciona; mover es
   siempre un botón ("Pasar…", "Colocar…" + ranura, "Coger todo"). Las reglas de movimiento no cambian
   (`InventoryComponent.move_to_slot` / `transfer_to` / `take_from`, spec 012). Las piezas de UI compartidas
   ganan lo mínimo: la celda sabe resaltarse un momento y marcarse como destino, y el selector de cantidad sabe
   desactivarse.

Alternativa descartada para la parte 1: elegir primero los sitios y luego un marcador dentro de cada uno. Reparte
igual de bien, pero gasta un número de tiradas que depende de los datos y complica fijar el orden de las llamadas
al RNG, que es un contrato con los mundos guardados (D2). Para la parte 2, la pantalla de inventario (Tab) no se
toca (spec §4, pregunta 8).

### 1.1 Decisiones del plan

| # | Decisión | Por qué |
|---|---|---|
| D1 | Un sitio es un hijo `Node3D` de `%BoxMarkers` y sus marcadores son sus hijos `Marker3D`. El índice de marcador es **plano**: sitios en orden de escena y, dentro de cada uno, marcadores en orden de escena. Ese índice es el que guarda la visita (R-013-08) y el que usa el contenido de cada caja (R-004-23, R-008-08). Una sola pasada (`_collect_box_sites()`, en `_ready`) llena a la vez la lista plana `_box_marker_nodes: Array[Marker3D]` y `_site_marker_counts: Array[int]`, así que los dos no pueden desalinearse. Un hijo directo de `%BoxMarkers` que sea `Marker3D` (la disposición antigua) o que no sea `Node3D`, o un hijo de un sitio que no sea `Marker3D` → `push_error` y se salta, sin contar en ninguna de las dos listas. | Mantiene el formato guardado y la semilla del contenido. Reordenar sitios o marcadores en la escena cambia qué caja es cuál: queda escrito como contrato en el docstring de `FarmZone`, como ya lo está el orden de las llamadas al RNG. Cuando haya partidas reales, reordenarlos obliga a subir `schema_version` y migrar (architecture §10.2); hoy no (D6). |
| D2 | `pick_box_markers` hace, en este orden: número de cajas con `randi_range(min, max)`, una permutación completa de todos los marcadores con `_pick_distinct(total, total, rng)` y un recorrido que toma cada marcador si su sitio no ha llegado al máximo, hasta tener el número. Devuelve los índices planos ordenados. | Siempre llena el número si caben y reutiliza `_pick_distinct`. El número de tiradas no depende del recorrido, solo de los datos. El orden de las llamadas es un contrato con los mundos guardados; lo fija un test de respuesta conocida. |
| D3 | Capacidad = Σ min(marcadores del sitio, máximo por sitio). Capacidad < `max_count` → `push_error` y como mucho la capacidad. Rango inválido (`min < 0`, `min > max`), máximo por sitio < 1 o un sitio con número de marcadores negativo → `push_error` y ninguna caja. | R-013-05, mismo estilo que el `pick_box_markers` actual y que `pick_enemy_spawns`. |
| D4 | RNG de colocación: `SeededRng.create(world_seed, zone_id, STREAM_BOX_PLACEMENT, visit)`. Sin stream nuevo. | R-013-01. Es la misma forma que usa `ZombieSpawner` con `STREAM_ENEMY_SPAWN`. La visita 0 da la misma semilla que hoy, pero la distribución cambia igual porque cambian el algoritmo y la escena (pregunta 4: sin migración). |
| D5 | `generate()` y `repopulate()` comparten `_place_boxes(world_seed, visit)`. `repopulate()` libera todas las cajas y llama a `_place_boxes` con la visita nueva. `populate()` no cambia: `generate()` + `_restore_boxes()`. | R-013-07: un solo camino de colocación, así que la misma visita da lo mismo por cualquier camino (R-013-02). |
| D6 | Las cajas guardadas cuyo marcador no tiene caja en esa visita ya se descartan con `push_error` (`FarmZone._restore_boxes`, spec 010). Solo falta el test. El campo guardado `marker` cambia de significado (índice plano por sitios) sin subir `schema_version`: es una excepción a architecture §10.2, justificada en §6. | R-013-08, pregunta 4. |
| D7 | Disposición de la escena: 6 sitios en anillo alrededor del punto de aparición (noroeste, norte, noreste, sureste, suroeste, oeste), cada uno entre 12 y 21 m del centro, con 3-4 marcadores separados entre 3 y 5 m. La separación mínima supera el alcance de interacción (`interaction_range_m`, 2.0 m, BALANCE §11) con margen, para que el botón "Interactuar" nunca dude entre dos cajas de un sitio; el test de R-013-03 la compara con `controls.tres`. Se reutilizan los 10 marcadores actuales que caen dentro de un sitio y se mueven los demás. 21 marcadores en total (tres sitios con 4 y tres con 3). Las coordenadas exactas se ajustan al implementar hasta que pasen los tests de R-013-03, R-013-09 y R-013-10. | BALANCE §7.1 (6 sitios, 3-4 marcadores, máximo 2 por sitio). Capacidad 12 ≥ 7. Con 21 marcadores y unas 6 cajas por visita, la probabilidad de que un marcador quede sin caja en 50 visitas es del orden de 10⁻⁸ (**estimación**); el test lo comprueba con una semilla fija. El navmesh no cambia: los `Marker3D` no están en el grupo de geometría fuente. |
| D8 | El contexto de la pantalla cambia `CONTEXT_TITLE` por `CONTEXT_KIND` con `enum Kind { LOOT_BOX, CHEST }`. La pantalla elige con una tabla constante las claves de título, cabecera y botón de guardar. Llamadores: `Main._on_box_opened` y `StructureUseFlow._open_chest`. Un `CONTEXT_KIND` que falte, no sea `int` o no sea un valor de `Kind` → `push_error` y no se muestra nada, como ya pasa sin inventarios (constitución §2). | R-013-12 y R-013-15 necesitan tres textos por tipo de contenedor. Un tipo en lugar de tres claves sueltas evita combinaciones incoherentes. |
| D9 | Estado interno `enum Mode { BROWSING, PLACING }` más la selección (`_selected_side`, `_selected_index`). `_refresh_card()` pinta toda la ficha (texto, icono, selector, botones, aviso) a partir del estado; ningún otro método toca la ficha. | Una sola fuente del aspecto de la ficha. Es lo que pedía la spec: nada aparece ni desaparece por caminos distintos. |
| D10 | Toques. En `BROWSING` las celdas vacías no se pueden pulsar (`set_empty_cells_pressable(false)`); en una celda con pila: sin selección → selecciona; la seleccionada → la deselecciona; otra → selecciona esa. En `PLACING` todas las celdas de las dos rejillas se pueden pulsar: la de origen equivale a "Cancelar"; otra → `move_to_slot`. Si sale bien, se deselecciona y se vuelve a `BROWSING`. Si se rechaza, se mantienen la selección y el modo y se muestra el motivo. Si la pila elegida desaparece por otro camino (R-012-35), se borra la selección y, en `PLACING`, se vuelve a `BROWSING` y se quitan las marcas de destino. | R-013-14, R-013-16, R-013-19. Tocar el origen no puede ser un movimiento (sería `ERR_INVALID_REQUEST` con `push_error`). Tras un rechazo, quedarse en el modo deja tocar otra ranura sin volver a pulsar "Colocar…". |
| D11 | En `PLACING` se desactivan el selector, el botón de pasar y "Coger todo"; "Colocar…" pasa a "Cancelar". | Un modo explícito no debe mezclarse con otras acciones (R-013-16). |
| D12 | `ContainerScreen.handle_back()` devuelve `true` y sale de `PLACING` (conservando la selección) mientras el modo está activo; si no, `false`. El toque fuera del panel ya llega a `handle_back()` por `UIManager._on_back_requested` → `_back()`. | R-013-17 con el contrato de architecture §9.5; `UIManager` no cambia. |
| D13 | Resaltado de destino: `InventorySlotView.flash_highlight(duration_s)` muestra un marco `%Highlight` que se apaga solo, con el mismo patrón que `DamageFlash` (`_process` solo mientras se ve y `advance(delta)` público para tests deterministas). La pantalla copia las ranuras del destino antes de mover y, si sale bien, resalta las que cambiaron (comparando item, cantidad y `uid`), sin la ranura de origen cuando origen y destino están en la misma rejilla (un intercambio cambia las dos, pero el destino es una). Vale para "Pasar", "Colocar" y "Coger todo". | R-013-19. Los tests no dependen del reloj real (P13). La comparación es presentación, no regla de juego: queda privada en la pantalla. |
| D14 | Ocupación: `InventoryRules.count_used_slots(slots) -> int` (pura). Las cabeceras se repintan en el `inventory_changed` de cada inventario, que la pantalla ya escucha. | R-013-12. Un solo sitio para contar, testeable sin escena. |
| D15 | La duración del resaltado va en `ControlConfigData.move_highlight_s` (`controls.tres`). La pantalla la recibe con `@export var controls: ControlConfigData`, asignado en su `.tscn`. Sin `controls` → `push_error` en `_ready` y no resalta. | BALANCE §11 es dueño del número y `ControlConfigData` ya es el recurso de §11 (P2, P5). |
| D16 | La ficha es un `PanelContainer` `%ActionCard` con `custom_minimum_size` fijo. Las etiquetas recortan con `text_overrun_behavior` (elipsis) y los botones tienen un ancho mínimo que cabe el texto más largo en ES y EN, así que la ficha no cambia de tamaño. El aviso de rechazo (`%Notice`) vive dentro de la ficha, en una línea reservada. | R-013-13. Un test compara el tamaño de la ficha en los tres estados. |
| D17 | `QuantitySelector.set_editable(editable: bool)`: desactiva −, + y el deslizador (`Slider.editable`) y no se oculta nunca. La pantalla de inventario no lo llama, así que no cambia. | R-013-13 ("desactivados, nunca ocultos"). |
| D18 | Las celdas se marcan como destino en `PLACING` con `InventorySlotView.set_target_marked(marked)` (un `ReferenceRect` `%TargetOutline`), a través de `InventoryGrid.set_targets_marked(marked)`. | R-013-16 ("outlines the slots of both grids"). |
| D19 | Claves de texto: se añaden las de §4.2. `CONTAINER_TRANSFER` se borra (ya no se usa). `CONTAINER_TAKE_ALL` cambia su texto para llevar la flecha. `LOOT_TITLE`, `CHEST_TITLE` e `INVENTORY_TITLE` no cambian. | R-013-21; el i18n-auditor marca las claves sin uso. |
| D20 | Los requisitos que esta spec sustituye se marcan en sus specs con "**Sustituido por R-013-xx** (spec 013, fecha)": R-004-11, R-012-27 (disposición y botón "Transfer"), R-012-28 y R-012-29 (movimiento por toque). R-004-21 y R-008-09 se marcan como "ampliado por" R-013-01 y R-013-07. | Convención de los specs 004, 005 y 008. |
| D21 | Los tests de comportamiento sustituido se reescriben con el ID nuevo, no se borran sin más (§5.3). Los que siguen siendo ciertos conservan su nombre, salvo los de un requisito que D20 marca como sustituido, que pasan al ID nuevo. | P13: nunca se debilita un test. Solo cambian los que prueban lo que la spec aprobada sustituye. |
| D22 | Los controles nuevos de la ficha (botón de pasar, "Colocar…"/"Cancelar") tienen `focus_mode = FOCUS_NONE`, como los de la spec 005. | R-005-24 sigue valiendo; su test se amplía. |

## 2. Archivos

| Archivo (`game/…`) | Nuevo / Cambia | Responsabilidad |
|---|---|---|
| `scripts/systems/zone_population.gd` | Cambia | `pick_box_markers` por sitios con máximo por sitio (D2, D3) |
| `scripts/data/zone_data.gd` | Cambia | `box_max_per_site` |
| `resources/zones/green_zone.tres` | Cambia | `box_max_per_site = 2` |
| `scenes/farm_zone/farm_zone.gd` | Cambia | Lee sitios y marcadores (D1), RNG por visita (D4), `_place_boxes` compartido (D5), docstring |
| `scenes/farm_zone/farm_zone_green.tscn` | Cambia | 6 sitios con 3-4 marcadores (D7) |
| `scripts/systems/inventory_rules.gd` | Cambia | `count_used_slots` (D14) |
| `scripts/data/control_config_data.gd` | Cambia | `move_highlight_s` (D15) |
| `resources/config/controls.tres` | Cambia | `move_highlight_s = 0.4` |
| `scenes/ui/inventory_slot.gd`, `.tscn` | Cambia | `%Highlight` + `flash_highlight` / `advance_highlight` / `is_highlighted` (D13); `%TargetOutline` + `set_target_marked` (D18) |
| `scenes/ui/inventory_grid.gd` | Cambia | `flash_slots`, `set_targets_marked` (pasan a las celdas) |
| `scenes/ui/quantity_selector.gd` | Cambia | `set_editable` (D17) |
| `scenes/ui/container_screen.gd`, `.tscn` | Cambia | Cabeceras, ficha fija, modos, botones con destino, resaltado, `handle_back` (D8-D13, D16) |
| `scenes/main.gd` | Cambia | Abre la caja con `CONTEXT_KIND: Kind.LOOT_BOX` (D8) |
| `scenes/base/structure_use_flow.gd` | Cambia | Abre el cofre con `CONTEXT_KIND: Kind.CHEST` (D8) |
| `i18n/strings.csv` | Cambia | Claves de §4.2 (D19) |
| `tests/unit/test_zone_population.gd` | Cambia | Casos 013 de `pick_box_markers` (sustituyen a los de R-004-21) |
| `tests/unit/test_zone_resources.gd` | Cambia | `box_max_per_site` de BALANCE §7.1 |
| `tests/integration/test_green_zone.gd` | Cambia | Sitios, navmesh, colisiones, visita, máximo por sitio, marcadores vivos, guardado sin marcador |
| `tests/unit/test_inventory_rules.gd` | Cambia | `count_used_slots` |
| `tests/unit/test_movement_resources.gd` | Cambia | `move_highlight_s` de BALANCE §11 |
| `tests/unit/test_inventory_slot.gd`, `test_inventory_grid.gd` | Nuevo | Resaltado y marca de destino |
| `tests/unit/test_quantity_selector.gd` | Cambia | `set_editable` |
| `tests/unit/test_container_screen.gd` | Cambia | Casos 013 (sustituyen a los de R-012-27 a R-012-30, §5.3) |
| `tests/integration/test_structure_use_flow.gd` | Cambia | El cofre abre la pantalla con su tipo |
| `../specs/004-green-zone/spec.md`, `008-death-recovery/spec.md`, `012-wind-generator-chests/spec.md` | Cambia | Marcas de sustitución (D20) |

## 3. Contratos

```gdscript
# ZonePopulation (changed; replaces the flat pick_box_markers of spec 004)
## Number of boxes in [min_count, max_count], then that many distinct markers with at most
## max_per_site in each site. site_marker_counts[i] = markers of site i; markers are numbered
## flat, site by site (FarmZone, plan D1). Returns flat indices sorted ascending.
## Sites hold fewer than max_count under max_per_site → push_error, at most what fits.
## Invalid range, max_per_site < 1 or a negative site count → push_error, no boxes.
## The order of the RNG calls is a contract with saved worlds: count, then a full
## permutation of the markers (plan D2).
static func pick_box_markers(
	site_marker_counts: Array[int],
	min_count: int,
	max_count: int,
	max_per_site: int,
	rng: RandomNumberGenerator
) -> Array[int]

# ZoneData (added)
## Boxes a visit places at most in one site (BALANCE §7.1, R-013-06).
@export var box_max_per_site: int = 0

# FarmZone (changed behaviour, same public API)
func generate(world_seed: int, visit: int) -> void       # number and markers depend on the visit
func repopulate(world_seed: int, visit: int, pool: ObjectPool) -> void   # boxes on the new visit's markers
# private, plan D1 and D5:
#   _collect_box_sites() -> void   # one pass in _ready: fills _box_marker_nodes and _site_marker_counts
#   var _box_marker_nodes: Array[Marker3D]   # flat, site by site; the index is the saved "marker"
#   var _site_marker_counts: Array[int]      # markers of each site, in scene order
#   _place_boxes(world_seed: int, visit: int) -> void

# InventoryRules (added)
## Slots holding a stack (R-013-12).
static func count_used_slots(slots: Array[ItemStack]) -> int

# ControlConfigData (added)
## Seconds the slots that received a move stay highlighted (BALANCE §11, R-013-19).
@export var move_highlight_s: float = 0.0

# InventorySlotView (added)
## Shows the highlight frame for duration_s seconds; <= 0 → nothing.
func flash_highlight(duration_s: float) -> void
func is_highlighted() -> bool
## Advances the highlight by delta seconds; _process calls it while highlighted.
func advance_highlight(delta: float) -> void
## Outline of a possible destination (placing mode).
func set_target_marked(marked: bool) -> void
func is_target_marked() -> bool

# InventoryGrid (added)
## An index outside the grid → push_error, skipped (added while implementing).
func flash_slots(indices: Array[int], duration_s: float) -> void
func set_targets_marked(marked: bool) -> void

# QuantitySelector (added)
## Disables −, + and the slider without hiding them (R-013-13).
func set_editable(editable: bool) -> void
func is_editable() -> bool

# ContainerScreen (changed)
enum Kind { LOOT_BOX, CHEST }
enum Mode { BROWSING, PLACING }
const CONTEXT_KIND := &"kind"          # replaces CONTEXT_TITLE; value: Kind
@export var controls: ControlConfigData
func get_mode() -> Mode
func get_selected_side() -> GridSide    # unchanged
func get_selected_index() -> int        # unchanged
## In PLACING: leaves the mode, keeps the selection, returns true. Otherwise false (UIManager closes).
func handle_back() -> bool
```

`EventBus`, `UIManager`, `InventoryComponent` y el formato guardado no cambian.

## 4. Datos

### 4.1 Recursos

| Recurso / `.tres` | Campos | Valores desde |
|---|---|---|
| `ZoneData` `green_zone.tres` | `box_max_per_site = 2` (`box_count_min/max` = 5/7 no cambian) | BALANCE §7.1 "Máximo de cajas por sitio", "Cajas" |
| `ControlConfigData` `controls.tres` | `move_highlight_s = 0.4` | BALANCE §11 "Resaltado de la ranura destino" |
| `farm_zone_green.tscn` | 6 sitios, 3-4 marcadores cada uno (diseño de nivel, no dato de `ZoneData`; lo comprueba un test) | BALANCE §7.1 "Sitios de cajas" |
| Test de R-013-10 | 50 visitas, semilla fija | BALANCE §7.1 "Comprobación de marcadores" |

### 4.2 Claves de texto (ES / EN)

| Clave | EN | ES |
|---|---|---|
| `CONTAINER_HEADER_BOX` | `Box %d/%d` | `Caja %d/%d` |
| `CONTAINER_HEADER_CHEST` | `Chest %d/%d` | `Cofre %d/%d` |
| `CONTAINER_HEADER_INVENTORY` | `Inventory %d/%d` | `Inventario %d/%d` |
| `CONTAINER_HINT_SELECT` | `Tap a stack to choose it` | `Toca una pila para elegirla` |
| `CONTAINER_HINT_PLACE` | `Tap the slot where it goes` | `Toca la ranura de destino` |
| `CONTAINER_SELECTED` | `%s ×%d` | `%s ×%d` |
| `CONTAINER_MOVE` | `Move` | `Pasar` |
| `CONTAINER_MOVE_TO_INVENTORY` | `Move to inventory →` | `Pasar al inventario →` |
| `CONTAINER_MOVE_TO_BOX` | `← Move to box` | `← Pasar a la caja` |
| `CONTAINER_STORE_IN_CHEST` | `← Store in chest` | `← Guardar en el cofre` |
| `CONTAINER_PLACE` | `Place…` | `Colocar…` |
| `CONTAINER_CANCEL` | `Cancel` | `Cancelar` |
| `CONTAINER_TAKE_ALL` (cambia) | `Take all →` | `Coger todo →` |
| `CONTAINER_TRANSFER` | se borra | se borra |

`CONTAINER_MOVE` es el texto del botón desactivado sin selección. Los rechazos siguen usando las claves de la
spec 012 (`ERR_SLOT_FULL`, `ERR_PARTIAL_SWAP`, `ERR_NO_ROOM`).

## 5. Verificación

### 5.1 Puntos comprobados al planificar (2026-11-21)

Referencia de clases generada con `--doctool` de Godot 4.7.2:

| Punto | Resultado |
|---|---|
| `NavigationServer3D.map_get_closest_point(map, to_point)`, `map_get_path`, `map_get_iteration_id` | Existen (los dos últimos ya se usan en `test_zombie.gd`) |
| `Node3D.get_world_3d()`, `World3D.navigation_map`, `World3D.direct_space_state` | Existen |
| `PhysicsDirectSpaceState3D.intersect_shape`, `PhysicsShapeQueryParameters3D.shape` / `transform` | Existen |
| `Slider.editable` | Existe (en `Slider`, no en `Range`) |
| `Label.text_overrun_behavior`, `Label.clip_text`, `Control.custom_minimum_size` | Existen |
| `ReferenceRect.border_color`, `BaseButton.disabled`, `CanvasItem.modulate` | Existen |

No queda ningún punto **(verificar)** nuevo. El del botón atrás de Android (architecture §9.5) ya lo cubrió la
spec 012; M3 lo repite para el modo colocar.

### 5.2 Requisitos

| Requisito | Test (`game/tests/…`) o paso manual |
|---|---|
| R-013-01 | `integration/test_green_zone.gd::test_r_013_01_layout_changes_with_visit` (misma semilla, visitas 0..N: al menos dos distribuciones distintas) y `::test_r_013_01_same_on_every_path` (`generate(v)`, `repopulate(v)` desde otra visita y `populate(v, {})` dan los mismos marcadores) |
| R-013-02 | `integration/test_green_zone.gd::test_r_013_02_same_seed_and_visit_same_boxes`, `::test_r_013_02_dev_seed_known_boxes` (fija la distribución del mundo de desarrollo en la visita 0 y en otra) e `integration/test_save_load.gd::test_r_010_35_same_boxes_same_visit` (ya recarga en una visita ≥ 1; sin cambios) |
| R-013-03 | `integration/test_green_zone.gd::test_r_013_03_sites_and_markers` (≥ 6 sitios `Node3D`, cada uno con 3-4 `Marker3D` y nada más), `::test_r_013_03_sites_cover_the_zone` (hay sitios en los cuatro cuadrantes y todos los marcadores están dentro de `size_m`), `::test_r_013_03_markers_apart` (dos marcadores cualesquiera, más lejos que `interaction_range_m` de `controls.tres`, D7) y `::test_r_013_03_stray_marker_reports_error` (un `Marker3D` colgado de `%BoxMarkers` → `push_error`, D1). Paso manual M1 |
| R-013-04 | `unit/test_zone_population.gd::test_r_013_04_count_in_range`, `::test_r_013_04_at_most_max_per_site`, `::test_r_013_04_distinct_sorted_markers` e `integration/test_green_zone.gd::test_r_013_04_per_site_limit_over_visits` |
| R-013-05 | `unit/test_zone_population.gd::test_r_013_05_same_rng_same_markers`, `::test_r_013_05_known_answer`, `::test_r_013_05_sites_too_small_reports_error`, `::test_r_013_05_invalid_range_reports_error`, `::test_r_013_05_invalid_max_per_site_reports_error`, `::test_r_013_05_negative_site_count_reports_error` |
| R-013-06 | `unit/test_zone_resources.gd::test_r_013_06_box_max_per_site_matches_balance` y revisión del balance-auditor (sin literal en `farm_zone.gd`) |
| R-013-07 | `integration/test_green_zone.gd::test_r_013_07_repopulate_places_new_visit_markers` (tras `repopulate(v)`, mismos marcadores que una zona nueva con `generate(v)`, todas cerradas). Siguen valiendo `test_r_008_09_repopulate_closes_boxes_with_new_contents` (sin sus aserciones de posición, §5.3), `test_r_008_09_repopulate_discards_leftovers`, `test_r_012_38_deposited_item_lost_next_visit` y `test_main_scene.gd::test_r_008_09_visit_change_repopulates_loaded_zone` |
| R-013-08 | `integration/test_green_zone.gd::test_r_013_08_saved_box_without_marker_dropped` (estado guardado con un marcador sin caja en esa visita → `push_error`, las demás vuelven abiertas). Siguen valiendo `test_zone_memory.gd::test_r_010_27_*` |
| R-013-09 | `integration/test_green_zone.gd::test_r_013_09_markers_on_navmesh_and_reachable` (punto más cercano del mapa a menos de una tolerancia en XZ y camino desde el punto de aparición que acaba junto al marcador; espera la sincronización del mapa como `test_zombie.gd`) y `::test_r_013_09_markers_clear_of_obstacles` (`intersect_shape` con la forma del cuerpo de `LootBox` en cada marcador: ningún `StaticBody3D` de `Decoration` ni de `Boundaries`). Paso manual M4 |
| R-013-10 | `integration/test_green_zone.gd::test_r_013_10_no_dead_marker` (semilla fija, 50 visitas: todos los marcadores reciben alguna caja) |
| R-013-11 | `unit/test_no_global_rng.gd::test_r_004_10_no_global_rng_in_game_code` (ya recorre todo el código del juego; sin cambios) |
| R-013-12 | `unit/test_container_screen.gd::test_r_013_12_headers_by_kind` (caja y cofre: nombre y `usadas/total` de cada lado), `::test_r_013_12_headers_follow_changes` y `::test_r_013_12_invalid_kind_reports_error` (D8); `unit/test_inventory_rules.gd::test_r_013_12_count_used_slots`; `integration/test_structure_use_flow.gd::test_r_012_27_chest_opens_container_screen` (pasa a comprobar la cabecera de cofre) |
| R-013-13 | `unit/test_container_screen.gd::test_r_013_13_card_without_selection` (pista visible, selector y botón de pasar desactivados y visibles) y `::test_r_013_13_card_keeps_its_size` (mismo tamaño sin selección, con selección y colocando); `unit/test_quantity_selector.gd::test_r_013_13_set_editable` |
| R-013-14 | `unit/test_container_screen.gd::test_r_013_14_tap_selects_whole_stack` (marco, icono, nombre traducido, cantidad, selector a la pila entera), `::test_r_013_14_tap_again_clears`, `::test_r_013_14_tap_other_switches`, `::test_r_013_14_tap_never_moves` y `::test_r_013_14_empty_cells_not_pressable` |
| R-013-15 | `unit/test_container_screen.gd::test_r_013_15_button_names_destination` (caja→inventario, inventario→caja, inventario→cofre) y `::test_r_013_15_move_to_other_side` (cantidad elegida, regla de R-012-30) |
| R-013-16 | `unit/test_container_screen.gd::test_r_013_16_place_mode` (marca las celdas, pista, "Cancelar", celdas vacías pulsables), `::test_r_013_16_tap_slot_places_and_leaves`, `::test_r_013_16_cancel_keeps_selection`, `::test_r_013_16_tap_origin_cancels`, `::test_r_013_16_other_actions_disabled` y `::test_r_013_16_stack_gone_leaves_mode` (D10); `unit/test_inventory_slot.gd::test_r_013_16_target_marked`, `unit/test_inventory_grid.gd::test_r_013_16_targets_marked` |
| R-013-17 | `unit/test_container_screen.gd::test_r_013_17_back_leaves_place_mode` (`handle_back()` → `true`, modo fuera, selección intacta; sin modo → `false`) e `::test_r_013_17_outside_tap_leaves_place_mode` (con `UIManager`: el toque fuera no cierra la pantalla en modo colocar y sí fuera de él). Paso manual M3 |
| R-013-18 | `unit/test_container_screen.gd::test_r_013_18_take_all_disabled_when_empty`; siguen valiendo `test_r_005_19_*` y `test_r_012_31_*` |
| R-013-19 | `unit/test_container_screen.gd::test_r_013_19_refusal_shows_reason_keeps_selection` (también en modo colocar), `::test_r_013_19_done_clears_and_highlights` (pasar, colocar y coger todo resaltan solo las ranuras que cambiaron, durante `move_highlight_s`), `::test_r_013_19_swap_highlights_destination_only` (D13), `::test_r_013_19_take_all_refusal_shows_reason` ("Coger todo" sin nada que quepa muestra `MSG_INVENTORY_FULL` en la ficha, añadido al implementar) y `::test_r_013_19_new_selection_hides_reason`; `unit/test_inventory_slot.gd::test_r_013_19_highlight_fades` (con `advance_highlight`, sin reloj real); `unit/test_movement_resources.gd::test_r_013_19_highlight_matches_balance` |
| R-013-20 | Siguen valiendo `test_inventory_rules.gd` y `test_inventory_component.gd` de la spec 012 sin cambios, y `test_container_screen.gd::test_r_012_35_*` |
| R-013-21 | `unit/test_container_screen.gd::test_r_005_30_keys_translated` (lista de claves ampliada con las de §4.2) e i18n-auditor |
| R-013-22 | `unit/test_container_screen.gd::test_r_013_22_no_platform_checks` (el código de la pantalla, la rejilla, la celda y el selector no contiene `OS.has_feature`, `OS.get_name`, `InputEventScreenTouch` ni `InputEventKey`) y pasos manuales M2 y M3 |

### 5.3 Tests que cambian por comportamiento sustituido (D21)

| Test actual | Qué pasa | Por qué |
|---|---|---|
| `test_zone_population.gd::test_r_004_21_*` (6) | Se sustituyen por los `test_r_013_04_*` / `test_r_013_05_*` | La firma de `pick_box_markers` cambia (R-013-05). Se mantienen los mismos casos (rango, distintos y ordenados, mismo RNG, pocos marcadores, rango inválido, respuesta conocida) |
| `test_green_zone.gd::test_r_008_08_positions_same_on_every_visit` | Se sustituye por `test_r_013_01_layout_changes_with_visit` | R-013-07 amplía R-008-09: la posición ya no es la misma en cada visita |
| `test_green_zone.gd::test_r_004_21_dev_seed_known_boxes` | Se sustituye por `test_r_013_02_dev_seed_known_boxes` con las posiciones nuevas | Su comentario prohibía mover las cajas; la spec 013 lo cambia a propósito (pregunta 4) |
| `test_green_zone.gd::test_r_008_09_repopulate_closes_boxes_with_new_contents` | Pierde las aserciones "same number of boxes" y "on the same markers"; conserva "cerradas", "las viejas ya no están" y "contenido de la visita 1". La posición la cubre `test_r_013_07_repopulate_places_new_visit_markers` | R-013-07 amplía R-008-09 |
| `test_green_zone.gd::test_r_004_11_same_seed_same_boxes`, `test_r_004_11_other_seed_other_layout`, `test_r_004_11_generate_twice_reports_error` | Pasan a `test_r_013_02_*` con el mismo contenido | R-004-11 queda sustituido por R-013-02 (D20, D21) |
| `test_green_zone.gd` helpers `_marker_positions` | Recorren sitios y marcadores | D1 |
| `test_container_screen.gd::test_r_012_27_*`, `test_r_012_28_*`, `test_r_012_29_*`, `test_r_012_30_*` | Se sustituyen por los `test_r_013_12` a `test_r_013_19` de §5.2 | R-013-12 a R-013-15 sustituyen a R-012-27 a R-012-30 en la pantalla. Las reglas (R-012-29, R-012-30 en `InventoryRules`) siguen probadas sin cambios |
| `test_container_screen.gd` helper `_open` | Pasa `CONTEXT_KIND: Kind.LOOT_BOX` en lugar de `CONTEXT_TITLE`; afecta a todos los tests del archivo | D8 |
| `test_container_screen.gd` constantes `TRANSFER_KEY` y `KEYS`, y `test_r_005_30_keys_translated` | Sin `CONTAINER_TRANSFER`; con las claves de §4.2; comprueba los textos de los botones nuevos | D19 |
| `test_container_screen.gd::test_r_005_26_both_sides_update`, `test_r_005_24_controls_never_take_focus`, `test_r_012_35_stays_open_when_empty` | Usan `%MoveButton` en lugar de `%TransferButton`; `test_r_005_24_*` incluye también `%PlaceButton` (D22) | D8, D9 |
| `test_container_screen.gd::test_r_012_35_selection_cleared_when_gone` | La última aserción pasa de "el selector se oculta" a "el selector sigue visible y desactivado" | R-013-13 ("disabled, never hidden") |
| `test_container_screen.gd::test_r_012_46_panel_stops_the_mouse` | "Un panel" pasa a "un panel exterior": cuenta los `PanelContainer` que no están dentro de `Center/Panel` (añadido al implementar) | `%ActionCard` es un `PanelContainer` dentro del panel (D16); no puede abrir un hueco que cuente como "fuera" |
| `test_structure_use_flow.gd::test_r_012_27_chest_opens_container_screen` | Comprueba la cabecera de cofre en lugar del título y mueve con `%MoveButton` en lugar de `%TransferButton` | D8 |

Los demás tests de las specs 004, 005, 008, 010 y 012 se quedan como están y deben seguir en verde. Entre ellos,
`test_main_scene.gd` (`_go_to_first_box` coloca el robot a 1.6 m de la caja 0; con la separación de D7 no hay otra
caja dentro del alcance de interacción).

### 5.4 Pasos manuales

| # | Plataforma | Paso | Esperado |
|---|---|---|---|
| M1 | PC | Mundo nuevo: ir a la zona verde, mirar dónde están las cajas, volver a la base y repetir 4 veces; morir una vez en la zona | Cada visita pone las cajas en sitios distintos, entre 5 y 7, nunca dos en un marcador ni más de 2 en un sitio. Hay sitios vacíos |
| M2 | PC y Android | Abrir una caja y un cofre. Tocar pilas de los dos lados, pasar, colocar y coger todo | Cabeceras "Caja"/"Cofre" e "Inventario" con su ocupación. Tocar nunca mueve. El botón dice adónde va. La ficha no cambia de tamaño. Las ranuras de destino se iluminan un momento. Con el ratón igual que con el dedo |
| M3 | Android | En modo colocar: tocar fuera del panel; volver a entrar y pulsar el botón atrás del sistema | Las dos veces sale del modo sin cerrar la pantalla y la selección sigue. Fuera del modo, las dos cierran la pantalla |
| M4 | PC | Recorrer los 6 sitios con el robot | Cada caja se puede alcanzar y abrir; ninguna está dentro ni pegada a un árbol, roca, chatarra o valla |
| M5 | PC | Cerrar y abrir el juego en mitad de una visita con una caja abierta a medias | Mismas cajas en los mismos sitios; la abierta vuelve abierta con lo que quedaba |

## 6. Check de constitución

| Principio | Cumple | Nota |
|---|---|---|
| P1 Spec primero | ✅ | Spec 013 *Aprobado* (2026-11-21) |
| P2 Una fuente de verdad | ✅ | `box_max_per_site` y `move_highlight_s` en `.tres` desde BALANCE §7.1 y §11. Sitios y marcadores por sitio son diseño de nivel en la escena y un test los compara con BALANCE (como el número de marcadores de la spec 004). El índice plano de marcador sale de un solo sitio (`FarmZone._collect_box_sites`) |
| P3 Lógica separada | ✅ | El reparto por sitios es puro en `ZonePopulation` y el recuento en `InventoryRules`. La pantalla solo pinta y pide los movimientos al `InventoryComponent` |
| P4 Estado por jugador | ✅ | Sin estado nuevo por jugador. La pantalla recibe el inventario del jugador local por contexto, como en la spec 012 |
| P5 Datos como recursos | ✅ | Campos nuevos en `ZoneData` y `ControlConfigData`; sin recursos nuevos |
| P6 Señales | ✅ | Cabeceras y ficha por `inventory_changed`; sin sondeo en `_process` (el resaltado procesa solo mientras se ve, como `DamageFlash`). Rutas con `%UniqueName` |
| P7 Tipado | ✅ | Firmas tipadas en §3; `Array[int]` en los recuentos por sitio |
| P8 Plataforma | ✅ | La pantalla solo escucha `pressed` de botones y `handle_back()`; un test busca comprobaciones de plataforma (R-013-22) |
| P9 Determinismo | ✅ | RNG de `SeededRng` con semilla, `zone_id`, stream y visita; orden de llamadas fijado por un test de respuesta conocida (D2) |
| P10 Servicios | ✅ | No toca guardado, tiempo ni tienda: el formato y `ISaveStore` no cambian |
| architecture §10.2 (`schema_version`) | ⚠️ | El campo guardado `marker` cambia de significado sin subir `schema_version` ni migrar (D6). Justificación: pregunta 4 de la spec lo acepta porque solo hay partidas de desarrollo; lo peor que pasa es perder las cajas abiertas de la visita en curso, con `push_error`. Cuando haya partidas reales, reordenar sitios o marcadores sí subirá la versión (D1) |
| P11 i18n | ✅ | Todas las claves de §4.2 en ES y EN; los textos con números usan `tr(key) % args`, como `GENERATOR_STORED` |
| P12 Presupuesto móvil | ✅ | Más marcadores (`Marker3D`, sin malla) y el mismo número de cajas; el navmesh no cambia |
| P13 Test primero | ✅ | Cada tarea de lógica empieza por su test (tasks.md). Los tests de comportamiento sustituido se reescriben, no se borran (§5.3) |
| P14 Alcance | ✅ | La pantalla de inventario, los cofres de la base y la colocación de zombies no cambian (spec §4) |

## 7. Riesgos y alternativas descartadas

- **Mundos guardados antes de esta spec** → las cajas abiertas de la visita en curso se pierden con `push_error`
  (pregunta 4, D6). Solo hay partidas de desarrollo.
- **Reordenar sitios o marcadores en la escena** cambia la identidad guardada de las cajas y su contenido (D1) →
  queda escrito en el docstring de `FarmZone`. Los tests de respuesta conocida lo detectan.
- **Un marcador que cae en el borde del navmesh** (el navmesh deja un margen alrededor de los obstáculos) → el test
  de R-013-09 lo detecta y se mueve el marcador al implementar (D7).
- **El texto largo de un botón no cabe en ES** → ancho mínimo fijado con el texto más largo (D16) y M2 en Android.
- **Las flechas y signos nuevos (`←`, `→`, `×`, `…`) son los primeros del proyecto** y el juego usa la fuente
  por defecto de Godot (**inferencia**: no está comprobado que los tenga). M2 lo comprueba en PC y Android; si
  falta alguno, se cambia por ASCII (`<-`, `->`, `x`, `...`) en `strings.csv`, sin tocar código.
- **La medida del tamaño de la ficha en GUT headless** no está comprobada. Si `size` no es fiable sin ventana, el
  test compara `get_combined_minimum_size()` en los tres estados y M2 lo confirma a ojo.
- **La ficha cambia de tamaño con una fuente o un idioma distintos** → test de R-013-13 con los dos idiomas de los
  tests y M2.
- Descartado: elegir primero sitios y luego marcadores (§1). Descartado: identificar cajas por nombre de nodo en
  lugar de índice: cambiaría el formato guardado sin necesidad (pregunta 4 acepta perder cajas, no pide migrar).
- Descartado: un `ContainerCardView` separado como escena propia. Hoy solo lo usa esta pantalla; se separaría si
  la pantalla de inventario adopta la ficha (pregunta 8, spec propia).
