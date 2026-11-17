# Catálogo de datos y autoloads

> Cómo se registran y se consultan los recursos de datos por `id`, y qué hacen los dos autoloads actuales
> (`GameManager`, `DataRegistry`). Incluye `ActionResult`, el tipo de resultado de acciones que pueden fallar.
> Specs: [004](../../specs/004-green-zone/spec.md), [005](../../specs/005-inventory/spec.md),
> [006](../../specs/006-zombies/spec.md) · Última actualización: spec 006 (backfill)

## Piezas

| Pieza | Tipo | Archivo | Responsabilidad |
|---|---|---|---|
| `DataRegistry` | autoload | `game/scripts/autoload/data_registry.gd` | Carga el catálogo al arrancar y devuelve datos por id |
| `GameManager` | autoload | `game/scripts/autoload/game_manager.gd` | Estado global de la partida; hoy solo la semilla del mundo |
| `DataCatalog` | Resource | `game/scripts/data/data_catalog.gd` | Lista explícita de `items` y `enemies`; construye los índices por id |
| Catálogo | `.tres` | `game/resources/data_catalog.tres` | La lista real: 3 ítems y 2 enemigos |
| `DevWorldConfigData` | Resource | `game/scripts/data/dev_world_config_data.gd` | Semilla fija de desarrollo (`resources/config/dev_world.tres`) |
| `ActionResult` | RefCounted | `game/scripts/data/action_result.gd` | `ok` + `error_key` (clave de traducción) |

## Cómo funciona

1. Al arrancar, `DataRegistry._ready()` carga `data_catalog.tres` como `DataCatalog`. Si falta o no es de ese
   tipo, `push_error` y el registro queda sin catálogo.
2. Llama a `build_index()`: indexa `items` y `enemies` en dos diccionarios por separado (un id solo ha de ser único
   dentro de su tipo). Devuelve un mensaje por hueco vacío, id vacío o id repetido; el registro los muestra con
   `push_error`. El primer recurso con un id se queda con él.
3. Consulta: `DataRegistry.get_item(id)` / `get_enemy(id)` delegan en el catálogo; un id desconocido da
   `push_error` y `null`. `has_item` / `has_enemy` están solo en `DataCatalog`. `get_catalog()` entrega el
   catálogo entero (lo usa `InventoryComponent` para validar ids cuando no se le inyecta otro).
4. `DataCatalog` construye su índice de forma perezosa si nadie llamó a `build_index()`, así se puede probar con
   catálogos hechos a mano sin el autoload.
5. `GameManager._ready()` lee `dev_world.tres` y guarda la semilla; `Main` la pide con `get_world_seed()` para
   generar la zona y colocar enemigos ([world_zones.md](world_zones.md), [enemies.md](enemies.md)).
6. `ActionResult.success()` / `ActionResult.failure(key)` son los únicos constructores. La UI muestra
   `tr(error_key)`. Hoy lo usa `InventoryComponent` ([inventory.md](inventory.md)).

## Datos

El catálogo no tiene números. Los recursos que enumera (`resources/items/*.tres`, `resources/enemies/*.tres`)
tienen sus valores en `BALANCE.md` §2 (materiales) y §3.1 (zombis). La semilla de desarrollo no es de balance.

## Decisiones

| Decisión | Por qué | Fuente |
|---|---|---|
| Catálogo enumerado a mano, no escaneo de carpetas | En Android exportado el listado de `res://` no es fiable | [architecture §8](../../specs/architecture.md) |
| Ids `StringName` en `snake_case`, estables | Guardados y red solo usan ids, nunca rutas | [architecture §8](../../specs/architecture.md) |
| Lógica de búsqueda en `DataCatalog`, no en el autoload | Se puede probar con catálogos hechos a mano | Comentario de `data_registry.gd` |
| Un índice por tipo | Un id de ítem y uno de enemigo pueden coincidir | [R-006-04](../../specs/006-zombies/spec.md) |
| Sin clase base común para ítem y enemigo | La abstracción espera al tercer tipo | Comentario de `data_catalog.gd` (constitución P2) |
| Lista de autoloads cerrada | Añadir uno exige cambiar la arquitectura | [architecture §5](../../specs/architecture.md) |
| `GameManager` sin estado por jugador | LAN co-op depende de ello | PMV §4.5 gancho 7 |
| `ActionResult` único para todo el juego | Reglas testeables sin escena | [architecture §9.2](../../specs/architecture.md) |
| Los autoloads no llevan `class_name` | Chocaría con el nombre del autoload | Comentarios de ambos scripts |

## Relación con otros sistemas

Usa: [foundation.md](foundation.md) (registro de autoloads). Lo usan: [inventory.md](inventory.md) (validación de
ids, `ActionResult`), [loot.md](loot.md) (ítems de las tablas), [enemies.md](enemies.md) (`get_enemy`),
[world_zones.md](world_zones.md) (semilla).

## Trampas y límites

- Discrepancia con la arquitectura: [architecture §8](../../specs/architecture.md) prevé `recipes`, `zones` y
  `rulesets` en el catálogo; el código solo tiene `items` y `enemies`. `ZoneData` existe pero no está catalogado.
  Llegarán con sus specs.
- `GameManager` solo tiene la semilla; ruleset, zona actual y mundo guardado llegan con specs posteriores (la 010
  sustituye `dev_world.tres`).
- `EventBus`, `SaveManager`, `AudioManager` y `TutorialManager` aún no existen.
- Un `.tres` que no esté en `data_catalog.tres` no se encuentra; los tests lo detectan.
- `get_item`/`get_enemy` devuelven `null` ante un id inválido: el llamador debe comprobarlo.

## Cómo extenderlo

- **Ítem o enemigo nuevo**: crear el `.tres` en `resources/items/` o `resources/enemies/`, añadirlo al array en
  `data_catalog.tres`, añadir su nombre a `strings.csv` y sus números antes a `BALANCE.md`.
- **Tipo de dato nuevo**: añadir `@export var` y un índice en `DataCatalog`, más `get_x` en `DataRegistry`; la
  arquitectura (§8) debe reflejarlo.

## Tests

| Archivo | Verifica |
|---|---|
| `game/tests/unit/test_data_catalog.gd` | Ids únicos, catálogo completo, consulta por id, errores, ítems y enemigos según BALANCE |
| `game/tests/unit/test_game_manager.gd` | La semilla viene de `dev_world.tres` |
| `game/tests/unit/test_action_result.gd` | `success` y `failure`, y su uso desde el inventario |
| `game/tests/unit/test_project_settings.gd` | Autoloads registrados |
