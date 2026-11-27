# Catálogo de datos y autoloads

> Cómo se registran y se consultan los recursos de datos por `id`, y qué hacen los autoloads actuales
> (`EventBus`, `DataRegistry`, `GameManager`; `SaveManager` está en [save.md](save.md)). Incluye `ActionResult`, el tipo de resultado de acciones que pueden
> fallar.
> Specs: [004](../../specs/004-green-zone/spec.md), [005](../../specs/005-inventory/spec.md),
> [006](../../specs/006-zombies/spec.md), [007](../../specs/007-melee-combat/spec.md),
> [008](../../specs/008-death-recovery/spec.md), [009](../../specs/009-base-placement-charging/spec.md), [010](../../specs/010-save-profile-world/spec.md),
> [011](../../specs/011-crafting-repair/spec.md), [012](../../specs/012-wind-generator-chests/spec.md) ·
> Última actualización: spec 012

## Piezas

| Pieza | Tipo | Archivo | Responsabilidad |
|---|---|---|---|
| `EventBus` | autoload | `game/scripts/autoload/event_bus.gd` | Señales de hechos globales; lista cerrada, sin estado |
| `DataRegistry` | autoload | `game/scripts/autoload/data_registry.gd` | Carga el catálogo al arrancar y devuelve datos por id |
| `GameManager` | autoload | `game/scripts/autoload/game_manager.gd` | Estado del mundo: id, nombre, semilla y ruleset del Mundo en juego, contadores de visitas por zona, zona actual, el reloj (`ITimeService`) y la tienda (`IStore`) |
| `DataCatalog` | Resource | `game/scripts/data/data_catalog.gd` | Lista explícita de `items`, `enemies`, `rulesets`, `zones`, `structures` y `recipes`, más `new_world_ruleset` y `repair_costs` (`RepairCostData`, spec 011); construye los índices |
| Catálogo | `.tres` | `game/resources/data_catalog.tres` | La lista real: ítems (incluida la batería portátil, `ConsumableData`), enemigos, el ruleset `normal`, las zonas (base y verde), las estructuras (estación de carga, generador eólico `WindGeneratorData`, cofre `StorageChestData`), las tres piezas básicas (`PieceData`) y las recetas de todo ello |
| Clases de dato de la spec 012 | Resources | `game/scripts/data/` | `WindGeneratorData` y `StorageChestData` (heredan de `StructureData`, que gana `max_count`), `ContainerConfigData` (capacidad de cofre y caja) y `ConsumableData` (hereda de `ItemData`, `battery_points`); ver [wind_generator_chests.md](wind_generator_chests.md) |
| `ActionResult` | RefCounted | `game/scripts/data/action_result.gd` | `ok` + `error_key` (clave de traducción); define `ERR_INVALID_REQUEST` |

## Cómo funciona

1. Al arrancar, `DataRegistry._ready()` carga `data_catalog.tres` como `DataCatalog`. Si falta o no es de ese
   tipo, `push_error` y el registro queda sin catálogo.
2. Llama a `build_index()`: indexa `items`, `enemies`, `rulesets`, `structures` y `recipes` en diccionarios por
   separado (un id solo ha de ser único dentro de su tipo) con una función común que lee el `id` por nombre. Las
   `zones` se indexan aparte, por `zone_id` (`Vector2i`, el id estable de una zona), y el catálogo exige exactamente
   una zona `BASE` si lista zonas. Devuelve un mensaje por hueco vacío, id vacío o repetido; el registro los muestra
   con `push_error`. El primer recurso con un id se queda con él.
3. Consulta: `DataRegistry.get_item(id)` / `get_enemy(id)` / `get_ruleset(id)` / `get_structure(id)` /
   `get_recipe(id)` / `get_zone(zone_id)` / `get_base_zone()` delegan en el catálogo; un id desconocido da
   `push_error` y `null`. `get_base_zone()` evita que ningún script escriba el `zone_id` de la base. `has_*` y
   `get_recipes()` están solo en `DataCatalog`.
   `get_catalog()` entrega el catálogo entero (lo usan `InventoryComponent` para validar ids cuando no se le inyecta
   otro, y `Robot` para el XP de una kill, [combat.md](combat.md)).
4. `DataCatalog` construye su índice de forma perezosa si nadie llamó a `build_index()`, así se puede probar con
   catálogos hechos a mano sin el autoload.
5. `GameManager` no lee ningún archivo de desarrollo: `SaveManager` le da el Mundo con `begin_world(id, nombre,
   semilla, ruleset)`, cargado (el ruleset se resuelve con `DataRegistry.get_ruleset(ruleset_id)`) o creado (con
   `DataCatalog.new_world_ruleset`, el `normal`). `begin_world` limpia contadores y zona actual. `ZoneLoader` pide la
   semilla con `get_world_seed()` para generar la zona y colocar enemigos ([world_zones.md](world_zones.md),
   [enemies.md](enemies.md)). Además guarda un contador de visitas por `zone_id` (`get_visit_count`,
   `increment_visit_count`, que emite `zone_visit_counted`; `clear_visit_counts()` lo usan los tests) y expone el
   reloj con `get_time_service()` ([death.md](death.md)). Desde la spec 009 guarda también la zona cargada
   (`has_current_zone`, `get_current_zone_id`, `set_current_zone`); solo `ZoneLoader` la escribe
   ([travel.md](travel.md)). `get_store()` devuelve el `IStore` (siempre `LocalStore`, [save.md](save.md)).
   `GameManager` es también dueño de guardado (`zone_visits`).
6. **`EventBus`** (autoload, el primero de la lista, sin `class_name`) solo declara señales tipadas; emiten sus
   dueños. Hoy: `enemy_killed(enemy_id, killer_uid)` (007, lo emite el `Enemy`, [combat.md](combat.md)),
   `player_died(player_uid)` y `player_respawned(player_uid)` (008, las emite `DeathController`,
   [death.md](death.md)); y, de la 009, `zone_changed(zone_id)` (`ZoneLoader`, [travel.md](travel.md)),
   `structure_built(structure_uid)` (`BaseStructures`) y `player_recharged(player_uid)` (`ChargingStation`,
   [base.md](base.md)); de la 010, `structure_moved(structure_uid)` (`BaseStructures`) y `game_saved(reason)`
   (`SaveManager`, [save.md](save.md)); de la 011, `item_crafted(recipe_id, player_uid)` y
   `piece_repaired(piece_uid, player_uid)` (`RepairBench`, [crafting.md](crafting.md)); de la 012, `batteries_collected(structure_uid, player_uid)` (`BaseStructures`) y `chest_closed(structure_uid, player_uid)` (`StructureUseFlow`, [wind_generator_chests.md](wind_generator_chests.md)). No guarda variables (un test lo vigila).
7. `ActionResult.success()` / `ActionResult.failure(key)` son los únicos constructores. La UI muestra
   `tr(error_key)`. Lo usan `InventoryComponent` ([inventory.md](inventory.md)) y `CraftingSystem` ([crafting.md](crafting.md)).

## Datos

El catálogo no tiene números. Los recursos que enumera (`resources/items/*.tres`, `resources/enemies/*.tres`)
tienen sus valores en `BALANCE.md` §2 (materiales) y §3.1 (zombis); `resources/rulesets/normal.tres` sale de
PMV §2.4 y BALANCE §1.1 ("Batería al reaparecer"). `new_world_ruleset` apunta a `rulesets/normal.tres` y no es balance.

## Decisiones

| Decisión | Por qué | Fuente |
|---|---|---|
| Catálogo enumerado a mano, no escaneo de carpetas | En Android exportado el listado de `res://` no es fiable | [architecture §8](../../specs/architecture.md) |
| Las zonas se indexan por `zone_id`, con exactamente una `BASE` | El `zone_id` ya es el id estable de una zona | [plan 009 §1](../../specs/009-base-placement-charging/plan.md), [architecture §10.3](../../specs/architecture.md) |
| Ids `StringName` en `snake_case`, estables | Guardados y red solo usan ids, nunca rutas | [architecture §8](../../specs/architecture.md) |
| Lógica de búsqueda en `DataCatalog`, no en el autoload | Se puede probar con catálogos hechos a mano | Comentario de `data_registry.gd` |
| Un índice por tipo | Un id de ítem y uno de enemigo pueden coincidir | [R-006-04](../../specs/006-zombies/spec.md) |
| Una función de indexado común para los tres tipos, sin clase base | Al llegar el tercer tipo (rulesets) se unifica el indexado; los recursos siguen sin base común y se lee `id` por nombre | [plan 008 §2](../../specs/008-death-recovery/plan.md) (`data_catalog.gd`), constitución P2 |
| Lista de autoloads cerrada | Añadir uno exige cambiar la arquitectura | [architecture §5](../../specs/architecture.md) |
| `EventBus` solo con señales tipadas, sin estado, lista cerrada | Evita dependencias cruzadas; un evento nuevo va a la tabla de architecture §7 | [architecture §7](../../specs/architecture.md), R-007-17 |
| `EventBus` el primero de los autoloads | Los demás se pueden conectar en su `_ready` | [plan 007 §3](../../specs/007-melee-combat/plan.md) |
| `GameManager` sin estado por jugador | LAN co-op depende de ello | PMV §4.5 gancho 7, R-008-34 |
| El ruleset se resuelve por id desde el catálogo | El archivo de Mundo guarda el id, nunca el recurso | [plan 008 §1](../../specs/008-death-recovery/plan.md) "Ruleset" |
| `GameManager` recibe el Mundo de `SaveManager`; la configuración de desarrollo con semilla fija desaparece | Nadie la lee ya | [plan 010 §1.1 D9](../../specs/010-save-profile-world/plan.md) |
| El ruleset de un Mundo nuevo sale del catálogo (`new_world_ruleset`) | Un solo origen, sin id escrito en código | R-010-19, [plan 010 §1.1 D8](../../specs/010-save-profile-world/plan.md) |
| `IStore` se alcanza por `GameManager.get_store()` | Mismo patrón que el reloj | [plan 010 §1.1 D1](../../specs/010-save-profile-world/plan.md) |
| El reloj lo crea y expone `GameManager` | Los servicios se alcanzan desde autoloads (con el contrato `ITimeService`) | [architecture §3](../../specs/architecture.md), plan 008 §1 |
| Subclases de `StructureData` e `ItemData` en las mismas listas del catálogo, sin lista nueva | El tipo dice qué estado tiene (`as WindGeneratorData`) sin comparar ids; igual que `PieceData` en `items` | [plan 012 D2](../../specs/012-wind-generator-chests/plan.md) |
| `ActionResult` único para todo el juego | Reglas testeables sin escena | [architecture §9.2](../../specs/architecture.md) |
| Los autoloads no llevan `class_name` | Chocaría con el nombre del autoload | Comentarios de ambos scripts |

## Relación con otros sistemas

Usa: [foundation.md](foundation.md) (registro de autoloads). Lo usan: [inventory.md](inventory.md) (validación de
ids, `ActionResult`), [loot.md](loot.md) (ítems de las tablas), [enemies.md](enemies.md) (`get_enemy`),
[world_zones.md](world_zones.md) (semilla, contador de visitas), [combat.md](combat.md) (`enemy_killed`, XP por
enemigo), [death.md](death.md) (ruleset, `player_died`, `player_respawned`, reloj).

## Trampas y límites

- El catálogo ya lista `zones`, `recipes`, `structures` y `rulesets`. Las zonas se indexan por `zone_id`, no por un
  `id` de texto, a diferencia del resto de tipos.
- `GameManager` está vacío (`get_world_id()` es `""`) hasta que `SaveManager` empieza un Mundo; solo `SaveManager` llama a
  `begin_world` (lo vigila un test).
- `AudioManager` y `TutorialManager` aún no existen.
- Una señal nueva de `EventBus` necesita su fila en architecture §7. Las que se emiten fuera del bus llevan
  `@warning_ignore("unused_signal")`.
- Un test que instancia `main.tscn` o un `DeathController` debe llamar a `GameManager.clear_visit_counts()` antes
  de instanciar (una muerte deja la visita en 1 para el siguiente test) y, si necesita un Mundo, a
  `SaveTestSupport.start_world()`.
- Un `.tres` que no esté en `data_catalog.tres` no se encuentra; los tests lo detectan.
- `get_item`/`get_enemy` devuelven `null` ante un id inválido: el llamador debe comprobarlo.

## Cómo extenderlo

- **Ítem, enemigo, ruleset, zona, estructura o receta nuevos**: crear el `.tres` en `resources/items/`,
  `resources/enemies/`, `resources/rulesets/`, `resources/zones/`, `resources/structures/`, `resources/recipes/` o `resources/pieces/` (una pieza es un ítem), añadirlo al array en `data_catalog.tres`, añadir su nombre a `strings.csv` y sus números
  antes a `BALANCE.md`.
- **Evento nuevo en el bus**: fila en architecture §7 (en el plan de la spec), señal tipada en `event_bus.gd` con
  `@warning_ignore("unused_signal")` y test de firma en `test_event_bus.gd`.
- **Tipo de dato nuevo**: añadir `@export var` y un índice en `DataCatalog`, más `get_x` en `DataRegistry`; la
  arquitectura (§8) debe reflejarlo.

## Tests

| Archivo | Verifica |
|---|---|
| `game/tests/unit/test_data_catalog.gd` | Ids únicos, catálogo completo (con la batería portátil), consulta por id, errores, ítems y enemigos según BALANCE; recetas con un único resultado, `WORKBENCH`/tier 1; tramos de reparación |
| `game/tests/unit/test_game_manager.gd` | `begin_world`, contadores de visitas, guardado, solo estado del mundo, reloj, tienda |
| `game/tests/unit/test_event_bus.gd` | Firmas de `enemy_killed`, `player_died`, `player_respawned`, `zone_changed`, `structure_built`, `structure_moved`, `game_saved`, `player_recharged`, `item_crafted`, `piece_repaired`, `batteries_collected`, `chest_closed`; el bus no guarda estado |
| `game/tests/unit/test_action_result.gd` | `success` y `failure`, y su uso desde el inventario |
| `game/tests/unit/test_project_settings.gd` | Autoloads registrados (`SaveManager` tras `GameManager`) |
