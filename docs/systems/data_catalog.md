# Catálogo de datos y autoloads

> Cómo se registran y se consultan los recursos de datos por `id`, y qué hacen los tres autoloads actuales
> (`EventBus`, `DataRegistry`, `GameManager`). Incluye `ActionResult`, el tipo de resultado de acciones que pueden
> fallar.
> Specs: [004](../../specs/004-green-zone/spec.md), [005](../../specs/005-inventory/spec.md),
> [006](../../specs/006-zombies/spec.md), [007](../../specs/007-melee-combat/spec.md),
> [008](../../specs/008-death-recovery/spec.md) · Última actualización: spec 008

## Piezas

| Pieza | Tipo | Archivo | Responsabilidad |
|---|---|---|---|
| `EventBus` | autoload | `game/scripts/autoload/event_bus.gd` | Señales de hechos globales; lista cerrada, sin estado |
| `DataRegistry` | autoload | `game/scripts/autoload/data_registry.gd` | Carga el catálogo al arrancar y devuelve datos por id |
| `GameManager` | autoload | `game/scripts/autoload/game_manager.gd` | Estado del mundo: semilla, ruleset, contadores de visitas por zona y el reloj (`ITimeService`) |
| `DataCatalog` | Resource | `game/scripts/data/data_catalog.gd` | Lista explícita de `items`, `enemies` y `rulesets`; construye los índices por id |
| Catálogo | `.tres` | `game/resources/data_catalog.tres` | La lista real: 3 ítems, 2 enemigos y 1 ruleset (`normal`) |
| `DevWorldConfigData` | Resource | `game/scripts/data/dev_world_config_data.gd` | Semilla y `ruleset_id` fijos de desarrollo (`resources/config/dev_world.tres`) |
| `ActionResult` | RefCounted | `game/scripts/data/action_result.gd` | `ok` + `error_key` (clave de traducción) |

## Cómo funciona

1. Al arrancar, `DataRegistry._ready()` carga `data_catalog.tres` como `DataCatalog`. Si falta o no es de ese
   tipo, `push_error` y el registro queda sin catálogo.
2. Llama a `build_index()`: indexa `items`, `enemies` y `rulesets` en tres diccionarios por separado (un id solo
   ha de ser único dentro de su tipo) con una función común que lee el `id` por nombre. Devuelve un mensaje por
   hueco vacío, id vacío o id repetido; el registro los muestra con `push_error`. El primer recurso con un id se
   queda con él.
3. Consulta: `DataRegistry.get_item(id)` / `get_enemy(id)` / `get_ruleset(id)` delegan en el catálogo; un id
   desconocido da `push_error` y `null`. `has_item` / `has_enemy` / `has_ruleset` están solo en `DataCatalog`.
   `get_catalog()` entrega el catálogo entero (lo usan `InventoryComponent` para validar ids cuando no se le inyecta
   otro, y `Robot` para el XP de una kill, [combat.md](combat.md)).
4. `DataCatalog` construye su índice de forma perezosa si nadie llamó a `build_index()`, así se puede probar con
   catálogos hechos a mano sin el autoload.
5. `GameManager._ready()` lee `dev_world.tres`, guarda la semilla y resuelve el ruleset con
   `DataRegistry.get_ruleset(ruleset_id)` (por eso `DataRegistry` va antes en la lista). `Main` pide la semilla con
   `get_world_seed()` para generar la zona y colocar enemigos ([world_zones.md](world_zones.md),
   [enemies.md](enemies.md)). Además guarda un contador de visitas por `zone_id` (`get_visit_count`,
   `increment_visit_count`, que emite `zone_visit_changed`; `clear_visit_counts()` lo usan los tests) y expone el
   reloj con `get_time_service()` ([death.md](death.md)).
6. **`EventBus`** (autoload, el primero de la lista, sin `class_name`) solo declara señales tipadas; emiten sus
   dueños. Hoy: `enemy_killed(enemy_id, killer_uid)` (007, lo emite el `Zombie`, [combat.md](combat.md)),
   `player_died(player_uid)` y `player_respawned(player_uid)` (008, las emite `DeathController`,
   [death.md](death.md)). No guarda variables (un test lo vigila).
7. `ActionResult.success()` / `ActionResult.failure(key)` son los únicos constructores. La UI muestra
   `tr(error_key)`. Hoy lo usa `InventoryComponent` ([inventory.md](inventory.md)).

## Datos

El catálogo no tiene números. Los recursos que enumera (`resources/items/*.tres`, `resources/enemies/*.tres`)
tienen sus valores en `BALANCE.md` §2 (materiales) y §3.1 (zombis); `resources/rulesets/normal.tres` sale de
PMV §2.4 y BALANCE §1.1 ("Batería al reaparecer"). La semilla y el `ruleset_id` de desarrollo no son de balance.

## Decisiones

| Decisión | Por qué | Fuente |
|---|---|---|
| Catálogo enumerado a mano, no escaneo de carpetas | En Android exportado el listado de `res://` no es fiable | [architecture §8](../../specs/architecture.md) |
| Ids `StringName` en `snake_case`, estables | Guardados y red solo usan ids, nunca rutas | [architecture §8](../../specs/architecture.md) |
| Lógica de búsqueda en `DataCatalog`, no en el autoload | Se puede probar con catálogos hechos a mano | Comentario de `data_registry.gd` |
| Un índice por tipo | Un id de ítem y uno de enemigo pueden coincidir | [R-006-04](../../specs/006-zombies/spec.md) |
| Una función de indexado común para los tres tipos, sin clase base | Al llegar el tercer tipo (rulesets) se unifica el indexado; los recursos siguen sin base común y se lee `id` por nombre | [plan 008 §2](../../specs/008-death-recovery/plan.md) (`data_catalog.gd`), constitución P2 |
| Lista de autoloads cerrada | Añadir uno exige cambiar la arquitectura | [architecture §5](../../specs/architecture.md) |
| `EventBus` solo con señales tipadas, sin estado, lista cerrada | Evita dependencias cruzadas; un evento nuevo va a la tabla de architecture §7 | [architecture §7](../../specs/architecture.md), R-007-17 |
| `EventBus` el primero de los autoloads | Los demás se pueden conectar en su `_ready` | [plan 007 §3](../../specs/007-melee-combat/plan.md) |
| `GameManager` sin estado por jugador | LAN co-op depende de ello | PMV §4.5 gancho 7, R-008-34 |
| El ruleset se resuelve por id desde el catálogo | El archivo de Mundo (spec 010) guardará el id, nunca el recurso | [plan 008 §1](../../specs/008-death-recovery/plan.md) "Ruleset" |
| El reloj lo crea y expone `GameManager` | Los servicios se alcanzan desde autoloads (con el contrato `ITimeService`) | [architecture §3](../../specs/architecture.md), plan 008 §1 |
| `ActionResult` único para todo el juego | Reglas testeables sin escena | [architecture §9.2](../../specs/architecture.md) |
| Los autoloads no llevan `class_name` | Chocaría con el nombre del autoload | Comentarios de ambos scripts |

## Relación con otros sistemas

Usa: [foundation.md](foundation.md) (registro de autoloads). Lo usan: [inventory.md](inventory.md) (validación de
ids, `ActionResult`), [loot.md](loot.md) (ítems de las tablas), [enemies.md](enemies.md) (`get_enemy`),
[world_zones.md](world_zones.md) (semilla, contador de visitas), [combat.md](combat.md) (`enemy_killed`, XP por
enemigo), [death.md](death.md) (ruleset, `player_died`, `player_respawned`, reloj).

## Trampas y límites

- Discrepancia con la arquitectura: [architecture §8](../../specs/architecture.md) prevé `recipes`, `zones` y
  `rulesets` en el catálogo; el código ya tiene `rulesets` (spec 008) pero sigue sin `recipes` ni `zones`.
  `ZoneData` existe pero no está catalogado. Llegarán con sus specs.
- `GameManager` no tiene todavía la zona actual ni el mundo guardado (la spec 010 sustituye `dev_world.tres` y
  guarda semilla, ruleset y contadores). Hoy los contadores de visitas viven solo en memoria.
- `SaveManager`, `AudioManager` y `TutorialManager` aún no existen.
- Una señal nueva de `EventBus` necesita su fila en architecture §7. Las que se emiten fuera del bus llevan
  `@warning_ignore("unused_signal")`.
- Un test que instancia `main.tscn` o un `DeathController` debe llamar a `GameManager.clear_visit_counts()` antes
  de instanciar: es un autoload y una muerte deja la visita en 1 para el siguiente test.
- Un `.tres` que no esté en `data_catalog.tres` no se encuentra; los tests lo detectan.
- `get_item`/`get_enemy` devuelven `null` ante un id inválido: el llamador debe comprobarlo.

## Cómo extenderlo

- **Ítem, enemigo o ruleset nuevo**: crear el `.tres` en `resources/items/`, `resources/enemies/` o
  `resources/rulesets/`, añadirlo al array en `data_catalog.tres`, añadir su nombre a `strings.csv` y sus números
  antes a `BALANCE.md`.
- **Evento nuevo en el bus**: fila en architecture §7 (en el plan de la spec), señal tipada en `event_bus.gd` con
  `@warning_ignore("unused_signal")` y test de firma en `test_event_bus.gd`.
- **Tipo de dato nuevo**: añadir `@export var` y un índice en `DataCatalog`, más `get_x` en `DataRegistry`; la
  arquitectura (§8) debe reflejarlo.

## Tests

| Archivo | Verifica |
|---|---|
| `game/tests/unit/test_data_catalog.gd` | Ids únicos, catálogo completo, consulta por id, errores, ítems y enemigos según BALANCE |
| `game/tests/unit/test_game_manager.gd` | Semilla y ruleset de `dev_world.tres`, contadores de visitas, solo estado del mundo, reloj |
| `game/tests/unit/test_event_bus.gd` | Firmas de `enemy_killed`, `player_died`, `player_respawned`; el bus no guarda estado |
| `game/tests/unit/test_action_result.gd` | `success` y `failure`, y su uso desde el inventario |
| `game/tests/unit/test_project_settings.gd` | Autoloads registrados |
