# Base, construcción y estación de carga

> La base es una zona segura con un banco de reparación, una cuadrícula de construcción y estructuras que el jugador
> coloca y mueve libremente. La única estructura de la spec 009 es la estación de carga, que recarga la batería al 100 %.
> Specs: [009](../../specs/009-base-placement-charging/spec.md), [010](../../specs/010-save-profile-world/spec.md), [011](../../specs/011-crafting-repair/spec.md) · Última actualización: spec 011

## Piezas

| Pieza | Tipo | Archivo | Responsabilidad |
|---|---|---|---|
| `BaseZone` | Escena (`Zone`) | `game/scenes/base/base.tscn`, `base_zone.gd` | Suelo, límites, `SpawnPoint`, `ExitPoint`, banco, `BuildArea`, `%Structures`, `%PreviewRoot`; muestra la vista previa |
| `BuildArea` | `Node3D` | `game/scenes/base/build_area.gd` | Origen de la cuadrícula y su dibujo (`ImmediateMesh`), oculto salvo al colocar |
| `RepairBench` | `StaticBody3D` | `game/scenes/base/repair_bench.gd`, `.tscn` | Banco fijo con `InteractableComponent`; emite `used`, que la base reenvía como `bench_used`; también atiende crear y reparar ([crafting.md](crafting.md)) |
| `ChargingStation` | `StaticBody3D` | `game/scenes/base/charging_station.gd`, `.tscn` | Al interactuar: `battery.recharge_full()` y `EventBus.player_recharged` |
| `BaseStructures` | Nodo bajo `World` | `game/scenes/base/base_structures.gd` | Dueño del estado de las estructuras (`BuildGrid`); coloca, mueve, instancia |
| `BuildGrid` | Sistema puro (`RefCounted`) | `game/scripts/systems/build_grid.gd` | Ocupación, validez, celda ↔ posición, estado en JSON |
| `CraftingSystem` | Sistema puro | `game/scripts/systems/crafting_system.gd` | `cost_of(recipe)` y `can_pay(slots, recipe)`; no retira nada. Crear y reparar: [crafting.md](crafting.md) |
| `BuildFlow` | Nodo de `Main` | `game/scenes/base/build_flow.gd` | Banco → `BenchScreen` (con `BaseZone.get_bench()`) → `PlacementScreen`; botón "Editar base" |
| `BenchScreen`, `BenchBuildSection` | `UIScreen` y sección | `game/scenes/ui/bench_screen.gd`, `bench_build_section.gd` | Pestaña Construir: recetas de estructura con coste; "Construir" con aviso si falta material o no cabe. Las pestañas Crear y Reparar: [crafting.md](crafting.md) |
| `PlacementScreen` | `UIScreen` | `game/scenes/ui/placement_screen.gd`, `.tscn` | Modos `PLACE`, `EDIT_PICK`, `MOVE`; vista previa verde o roja |
| `BuildGridData`, `StructureData`, `RecipeData`, `RecipeIngredientData` | Resources | `game/scripts/data/` | Cuadrícula, estructura (id, escena, huella), receta e ingrediente |
| `base_grid.tres`, `structures/charging_station.tres`, `recipes/charging_station.tres`, `zones/base.tres` | Recursos | `game/resources/` | Datos de la base (ver Datos) |

## Cómo funciona

**Construir.**
1. El robot interactúa con el banco; `BaseZone` emite `bench_used`; `BuildFlow` (si es el robot local) abre `bench` (en la pestaña Construir).
2. `BenchBuildSection` lista las recetas `WORKBENCH` con resultado de estructura. Elegir una cierra la pantalla y llama a
   `Robot.request_build(recipe)` (no hace nada con la batería agotada); el robot emite `build_requested`.
3. `BuildFlow` abre `placement` en modo `PLACE`. No se cobra nada todavía.
4. `PLACE`: la vista previa empieza en la celda válida más cercana al robot. Un clic o toque sobre el suelo (rayo de
   la cámara contra el plano de la base, `select_cell`) la mueve; verde si `BaseStructures.can_place`, roja si no.
5. "Confirmar" o Enter (acción `confirm`) llama a `BaseStructures.place`: valida celda y materiales, **ocupa las
   celdas, cobra con `InventoryComponent.remove_many`** (si el cobro falla, las suelta), instancia la estructura y
   emite `EventBus.structure_built` una vez. Celda inválida: no cambia nada y sigue en el modo.

**Editar.** El botón "Editar base" del `Hud` (visible solo con la base cargada) abre `placement` en `EDIT_PICK`;
tocar una estructura la coge (`MOVE`); confirmar llama a `BaseStructures.move` (sin coste) y vuelve a `EDIT_PICK`.
Cancelar, Escape o atrás en `MOVE` vuelven a `EDIT_PICK` (`handle_back`); en los otros modos cierran. El banco y el
punto de salida no son estructuras: nunca se cogen.

**Mientras se coloca.** `PlacementScreen` es una pantalla de `UIManager`: la entrada del robot se bloquea sin pausar
el juego (la batería sigue bajando) y una muerte la cierra con `close_all()`. `setup` apaga los
`InteractableComponent` de las estructuras y muestra la cuadrícula; `on_closed` revierte ambas cosas y oculta la
vista previa, sea cual sea la forma de cerrar. Las celdas bajo cada robot cuentan como bloqueadas.

**Persistencia entre zonas.** `BaseStructures` guarda el estado y, con la base cargada (`bind_base`), instancia cada
estructura en `%Structures`; al descargar (`unbind_base`) las instancias se van con la base y el estado queda. Ver
[travel.md](travel.md). `to_data()`/`load_data()` usan solo tipos JSON (`uid`, `structure_id`, `zone_id`, `cell`);
`load_data` es todo o nada.

**Guardado (spec 010).** `BaseStructures` está en el grupo `persistent` con clave `structures`: `to_save_data` es
`{placed: to_data()}`. `from_save_data` descarta con `push_error` las estructuras que el catálogo ya no tiene y carga el
resto con `load_data`; no emite `structure_built`, porque nada se construyó. `move` emite
`EventBus.structure_moved(structure_uid)` una vez; `SaveManager` guarda con ese hecho y con `structure_built`
([save.md](save.md)). `BuildGrid` lee `zone_id` y `cell` por `SaveFields`.

**Estación de carga.** Es una estructura colocada (huella de una celda). Recarga a través del método de la batería,
sin coste ni límite de usos, y avisa con `player_recharged`. Entrar en la base no recarga.

## Datos

| Recurso | Clase | Valores en BALANCE |
|---|---|---|
| `resources/config/base_grid.tres` | `BuildGridData` | [§5.6](../../BALANCE.md) (celda y área); origen y celdas reservadas son trazado de la escena |
| `resources/structures/charging_station.tres` | `StructureData` | §5.6 (huella), §5.3 (estación) |
| `resources/recipes/charging_station.tres` | `RecipeData` | [§5.1 y §5.3](../../BALANCE.md) (coste) |
| `resources/zones/base.tres` | `ZoneData` | §5.6 (tamaño), [architecture §14](../../specs/architecture.md) (`zone_id`) |
| `resources/materials/preview_valid.tres`, `preview_invalid.tres` | Materiales | No es balance |

`BaseZone.grid` y `BaseStructures.grid_config` apuntan al mismo recurso (lo vigila un test).

## Decisiones

| Decisión | Por qué | Fuente |
|---|---|---|
| El estado de las estructuras vive en un nodo bajo `World`, no en la base ni en `GameManager` | Sobrevive a la descarga y se guarda como los objetos caídos | [plan 009 §7](../../specs/009-base-placement-charging/plan.md) |
| `InventoryComponent.remove_many` cobra; `CraftingSystem` solo calcula | Un sistema puro no conoce nodos ni escribe estado ajeno | plan 009 §7.1, [architecture §3](../../specs/architecture.md) |
| `place` y `move` reciben el jugador que pide | En cooperativo decide el anfitrión | plan 009 §1, architecture §3 regla 4 y §12 |
| Colocación como pantalla de `UIManager` | Gratis: bloqueo sin pausa, cierre al morir, Escape y atrás | plan 009 §1 "Colocación y edición" |
| Sin rotación ni huellas no cuadradas | Fuera del PMV | plan 009 §7 |
| El robot tampoco se mueve en `EDIT_PICK` | Es la misma pantalla; pendiente de confirmar por la persona que revisa | plan 009 §5.3 y §7.1 |
| Las estaciones se apagan con `set_interactions_enabled` genérico, no con un método de la estación | Sirve para cualquier estructura futura | plan 009 §5.3 |
| `ChargingStation` sin estado ni guardado | `SaveManager` escucha `player_recharged` | plan 009 §1 "Estación de carga" |
| `structure_moved` como señal nueva del bus | Mover también es un hecho que se guarda | [plan 010](../../specs/010-save-profile-world/plan.md) (adición a `EventBus`) |

## Relación con otros sistemas

Usa [inventory.md](inventory.md) (`remove_many`), [battery.md](battery.md) (`recharge_full`),
[interaction.md](interaction.md), [ui.md](ui.md) (`UIManager`, `UIScreen`), [travel.md](travel.md) y
[data_catalog.md](data_catalog.md). Crear piezas y reparar en el banco: [crafting.md](crafting.md) (spec 011). La 012
añadirá el generador y los cofres como estructuras.

## Trampas y límites

- Recargar en la estación guarda y es el único guardado que se anuncia ("Partida guardada", [ui.md](ui.md)).
- Dos escritores del estado no deben existir: toda colocación pasa por `BaseStructures`; el `DebugHud` ("Llenar
  base") también lo usa, dándole antes al robot el coste.
- La base llena se pregunta sin celdas bloqueadas: si el único hueco está bajo el robot, basta con apartarse.
- Con el botón "Editar base" pulsado en `MOVE`, `BuildFlow` hace `close_top()` y cierra la pantalla entera sin pasar
  por `handle_back`. Es menor y coincide con "pulsado otra vez la cierra", pero no vuelve a `EDIT_PICK`.
- Las instancias de estructura no son de un pool: se recrean desde el estado cada vez que se carga la base.
- Si tocas el trazado de la base, `base_grid.tres` (origen y celdas reservadas) debe seguir casando con la escena.
- R-009-22 (fotogramas con el área llena) y los toques en Android son pruebas manuales (T-009-17).

## Cómo extenderlo

Estructura nueva: escena, `StructureData` y `RecipeData` en `resources/`, ambos en `data_catalog.tres`, claves
`STRUCTURE_*` en `strings.csv` y sus números antes en `BALANCE.md`. `BenchBuildSection` la lista sola.

## Tests

| Archivo | Verifica |
|---|---|
| `tests/unit/test_build_grid.gd`, `test_build_grid_data.gd` | Límites, reservadas, ocupadas, mover, conversión, JSON, `base_grid.tres` |
| `tests/unit/test_crafting_system.gd`, `test_recipe_resources.gd`, `test_structure_resources.gd` | Coste, "puede pagar", recetas y estructuras |
| `tests/integration/test_base_zone.gd`, `test_base_structures.gd` | Escena de la base; colocar, cobrar, mover, persistir al descargar |
| `tests/integration/test_charging_station.gd`, `tests/unit/test_repair_bench.gd` | Recarga, evento, banco |
| `tests/unit/test_bench_screen.gd` (casos de construir), `tests/integration/test_placement_screen.gd`, `test_build_flow.gd` | Pantallas y flujo banco → colocación |
| `tests/integration/test_save_load.gd` | Estructuras colocadas vuelven en su celda tras cerrar y abrir |
| `tests/integration/test_base_loop.gd` | Bucle completo: ir a la zona, recoger chatarra, volver, construir, recargar, mover y comprobar tras otro viaje |
