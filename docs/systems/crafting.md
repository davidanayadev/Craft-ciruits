# Crafteo y reparación en el banco

> En el banco de reparaciones el jugador crea las tres piezas básicas con materiales y repara piezas dañadas. Las piezas
> son objetos únicos del inventario (con `uid` y durabilidad), sin efecto hasta la spec 015. La construcción de
> estructuras del mismo banco está en [base.md](base.md).
> Specs: [009](../../specs/009-base-placement-charging/spec.md), [011](../../specs/011-crafting-repair/spec.md) · Última actualización: spec 011

## Piezas

| Pieza | Tipo | Archivo | Responsabilidad |
|---|---|---|---|
| `CraftingSystem` | Sistema puro (`RefCounted`, estático) | `game/scripts/systems/crafting_system.gd` | Decide, nunca escribe: `cost_of`, `can_pay`, `check_craft`, `create_result`, `is_damaged`, `repair_cost`, `check_repair` |
| `InventoryComponent` | Componente | `game/scripts/components/inventory_component.gd` | `craft(recipe)` y `repair(piece_uid, costs)`: cobran y escriben en un paso ([inventory.md](inventory.md)) |
| `RepairBench` | `StaticBody3D` | `game/scenes/base/repair_bench.gd` | Petición del jugador: `craft(player, recipe)` y `repair(player, piece_uid)`; emite los eventos. Sin estado |
| `BenchScreen` | `UIScreen` (`SCREEN_ID = &"bench"`) | `game/scenes/ui/bench_screen.gd`, `.tscn` | `TabContainer` con Construir, Crear y Reparar; escucha `inventory_changed` del jugador |
| `BenchEntry` | `HBoxContainer` | `game/scenes/ui/bench_entry.gd` | Fila común: icono, nombre, detalle, coste, aviso y botón (`setup`, `set_blocked(razón)`, señal `pressed`) |
| `BenchBuildSection` | `VBoxContainer` | `game/scenes/ui/bench_build_section.gd` | Pestaña Construir (lógica de la antigua `BuildScreen`, [base.md](base.md)) |
| `BenchCraftSection` | `VBoxContainer` | `game/scenes/ui/bench_craft_section.gd` | Una fila fija por receta `WORKBENCH` con `result_item` (nombre de nodo = id de receta) |
| `BenchRepairSection` | `VBoxContainer` | `game/scenes/ui/bench_repair_section.gd` | Una fila por pieza dañada (nombre de nodo = `uid`); `%NothingToRepair` si no hay |
| `PieceData` | Resource (`extends ItemData`) | `game/scripts/data/piece_data.gd` | `durability_max`; `stack_max` siempre 1 |
| `RepairCostData`, `RepairTierData` | Resources | `game/scripts/data/repair_cost_data.gd`, `repair_tier_data.gd` | Tramos de coste por porcentaje de durabilidad restante |
| `RecipeData.result_item` | Campo | `game/scripts/data/recipe_data.gd` | Receta de ítem; una receta del catálogo tiene `result_structure` o `result_item`, no ambos |

## Cómo funciona

**Crear.**
1. El robot usa el banco; `BaseZone` emite `bench_used`; `BuildFlow` abre `bench` con jugador, `BaseStructures` y
   `BaseZone.get_bench()`. Abre en Construir.
2. `BenchCraftSection.refresh()` pone a cada fila `set_blocked(CraftingSystem.check_craft(...).error_key)`:
   `ERR_NOT_ENOUGH_MATERIALS`, o `ERR_NO_ROOM_FOR_RESULT` si, tras pagar, el resultado no cabe en ninguna ranura (se
   cuenta la que libera el pago; `check_craft` paga sobre una copia profunda).
3. Pulsar "Crear" (si sigue sin bloqueo) llama a `RepairBench.craft`, que llama a `player.inventory.craft(recipe)`:
   `check_craft`, `remove_many` del coste y `add_stack` de `CraftingSystem.create_result` (cantidad 1, durabilidad
   máxima, `Uid.generate()`), con un solo `inventory_changed`.
4. Si sale bien, `RepairBench` emite `EventBus.item_crafted(recipe_id, player_uid)`. `SaveManager` lo convierte en un
   guardado diferido con razón `item_crafted` ([save.md](save.md)). La pantalla sigue abierta.

**Reparar.**
1. `BenchRepairSection.refresh()` rehace sus filas con cada `inventory_changed`: una por pieza con
   `CraftingSystem.is_damaged`, con durabilidad, coste (`repair_cost`) y bloqueo de `check_repair`.
2. `check_repair` rechaza en este orden: `uid` desconocido (`ERR_PIECE_NOT_FOUND`), intacta (`ERR_PIECE_INTACT`), rota
   (`ERR_PIECE_BROKEN`), sin materiales (`ERR_NOT_ENOUGH_MATERIALS`).
3. `repair_cost` elige el primer tramo (orden ascendente) con `durabilidad × PERCENT <= up_to_percent × máxima`,
   en enteros para que el borde no dependa de coma flotante.
4. `RepairBench.repair` llama a `player.inventory.repair(uid, catalog.repair_costs)`, que cobra y pone la durabilidad
   al máximo conservando `uid` y ranura. Si sale bien emite `EventBus.piece_repaired(piece_uid, player_uid)`
   (razón de guardado `piece_repaired`).

**Pantalla.** Las tres secciones se refrescan con `inventory_changed` del jugador (nunca en `_process`); `on_closed`
desconecta la señal. Construir cierra la pantalla y llama a `Robot.request_build` (R-009-65); Crear y Reparar no la
cierran. Los títulos de pestaña se traducen con `tr()` en `setup()`. Un contexto incompleto es `push_error` y la
pantalla queda sin filas.

## Datos

| Recurso | Clase | Valores en BALANCE |
|---|---|---|
| `resources/pieces/basic_arms.tres`, `basic_legs.tres`, `basic_core.tres` | `PieceData` | [§4.1](../../BALANCE.md) (durabilidad máxima) |
| `resources/recipes/basic_arms.tres`, `basic_legs.tres`, `basic_core.tres` | `RecipeData` | [§4.3.1](../../BALANCE.md), §5.1 |
| `resources/config/repair_costs.tres` | `RepairCostData` | [§4.3.2](../../BALANCE.md) (tramos), §4.1 |

El catálogo lista las piezas en `items`, las recetas en `recipes` y `repair_costs` ([data_catalog.md](data_catalog.md)).
Iconos SVG de marcador en `assets/textures/icons/items/`, anotados en `assets/CREDITS.md`.

## Decisiones

| Decisión | Por qué | Fuente |
|---|---|---|
| El sistema decide y el componente escribe; no hay `craft_piece()` en `CraftingSystem` | Un único dueño del estado | [plan 011 §1](../../specs/011-crafting-repair/plan.md), R-009-62 |
| La pieza es siempre válida en un inventario: cantidad 1, durabilidad 1..máx y `uid` no vacío | Sin ello `add` crearía piezas sin identidad | [plan 011 D1](../../specs/011-crafting-repair/plan.md), R-011-07, R-011-08 |
| Crear comprueba la ranura tras cobrar, con una clave propia | Cuenta la ranura que libera el pago | plan 011 D6, [spec 011 pregunta 3](../../specs/011-crafting-repair/spec.md) |
| Coste de reparación por tramos, porcentajes enteros, umbrales en `.tres` | Sin literales de juego en scripts ni coma flotante | plan 011 D4, R-011-06, spec 011 pregunta 2 |
| Emite los eventos el banco, no el inventario | El componente no conoce el bus ni el `player_uid` | plan 011 D7, [architecture §7](../../specs/architecture.md) |
| Una pantalla con tres pestañas sustituye a `BuildScreen` | Una sola pantalla del banco | R-011-21, plan 011 D9 |
| Títulos de pestaña con `tr()` explícito | No depender de que `TabBar` traduzca | plan 011 D10 |
| Reparar rehace sus filas, Construir y Crear solo actualizan botón y aviso | Las piezas dañadas cambian; las recetas no | plan 011 D11 |
| Guardar tras crear y reparar, en silencio | Igual que construir | R-011-28 |
| Crear es instantáneo, sin cola ni confirmación | Ningún documento pide tiempo | R-011-15 |

## Relación con otros sistemas

Usa [inventory.md](inventory.md) (el componente escribe), [data_catalog.md](data_catalog.md), [ui.md](ui.md)
(`UIManager`, `UIScreen`) y [base.md](base.md) (la base da el banco; Construir sigue siendo de la base). Lo escucha
[save.md](save.md). La spec 015 añadirá equipo, desgaste y reparar piezas equipadas.

## Trampas y límites

- Una pieza creada no hace nada: no hay equipo, stats ni desgaste hasta la spec 015; por eso reparar solo se prueba con
  tests que inyectan una pieza dañada ([spec 011 pregunta 7](../../specs/011-crafting-repair/spec.md)).
- `InventoryComponent` nunca contiene una pieza a 0 (`is_valid_stack`); `ERR_PIECE_BROKEN` solo se alcanza desde el
  sistema puro. La spec 015 debe quitar las piezas rotas, o se rechazarán al cargar ([plan 011 §7](../../specs/011-crafting-repair/plan.md)).
- Una pila de pieza sin `uid` o con durabilidad inválida se rechaza: quien las cree (por ejemplo el botín de la spec 016)
  debe usar `CraftingSystem.create_result`.
- `RepairBench.craft` solo acepta recetas `WORKBENCH`; la comprobación de "tiene `result_item`" está en el inventario.
- El `uid` de una fila de reparación es el nombre de su nodo; sirve a los tests, no se muestra.
- Discrepancia menor con el plan: `ERR_INVALID_REQUEST` vive ahora en `ActionResult` (`action_result.gd:8`) y
  `InventoryComponent.ERR_INVALID_REQUEST` es un alias; `action_result.gd` no estaba en la lista de archivos del plan.

## Cómo extenderlo

- Receta de ítem nueva: `.tres` en `resources/recipes/` con `result_item` (y su ítem en `items`), añadirla a
  `data_catalog.tres`, claves `ITEM_*` en `strings.csv` y números antes en `BALANCE.md`; `BenchCraftSection` la lista sola.
- Cambiar costes o tramos de reparación: solo `repair_costs.tres` (tramos ascendentes, el último a 100).
- Pieza nueva: `PieceData` con `stack_max = 1` y su receta; la 015 añade `slot_type` y modificadores.

## Tests

| Archivo | Verifica |
|---|---|
| `tests/unit/test_crafting_system.gd` | `check_craft` (justo, de sobra, falta, lleno, el pago libera ranura, no cambia las ranuras), `create_result`, coste por tramos y bordes, motivos de `check_repair` |
| `tests/unit/test_inventory_component.gd` | `craft` y `repair`: todo o nada, `uid` nuevo al crear y conservado al reparar, `uid` desconocido, dos Brazos en dos ranuras |
| `tests/unit/test_repair_bench.gd` | Eventos solo si sale bien, peticiones inválidas, `BaseZone.get_bench()` |
| `tests/unit/test_bench_screen.gd` | Tres pestañas, filas, avisos, refresco, sigue abierta, textos ES/EN y los casos de construir movidos de la spec 009 |
| `tests/unit/test_piece_resources.gd`, `test_recipe_resources.gd`, `test_data_catalog.gd` | Piezas, recetas y costes contra BALANCE; un único resultado por receta |
| `tests/integration/test_save_triggers.gd` | Guardado tras crear y reparar |
