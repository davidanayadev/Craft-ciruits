# Plan 010 — Guardado en dos niveles (Perfil y Mundo) e `IStore`

| Campo | Valor |
|---|---|
| **Spec** | [spec.md](spec.md) (debe estar *Aprobado*) |
| **Estado** | Planificado (2026-11-17) |

## 1. Enfoque

Tres capas, como piden architecture §3 y §10:

1. **Almacén** (`ISaveStore` → `LocalSaveStore`): solo bytes. Escribe y lee el Perfil y cada Mundo bajo
   `user://saves/`, cifra y descifra (AES-256 con el cifrado de archivos de `FileAccess`), guarda la copia de
   seguridad y escribe de forma que un corte nunca deja el principal a medias. No sabe qué hay dentro.
2. **Documento** (lógica pura en `scripts/systems/`): `SaveCodec` pasa un `Dictionary` a bytes JSON y vuelta,
   `SaveMigrations` aplica la cadena `migrate_vN_to_vN1`, y `SaveDocuments` monta el Perfil y el Mundo a partir de
   las partes de sus dueños, los valida y los separa otra vez. Todo se prueba sin archivos ni árbol de escena
   (R-010-05).
3. **Orquestación** (`SaveManager`, autoload ya previsto en la lista cerrada de architecture §5): recoge las partes
   de los nodos del grupo `persistent`, llama a la capa pura, escribe con el almacén y, al cargar, reparte cada
   parte a su dueño por su clave. No conoce ningún campo (R-010-03). En la escena, `SaveFlow` (nodo de `Main`,
   como `BuildFlow`) hace el arranque desde el guardado, retiene los guardados durante el viaje y la transferencia
   y muestra los avisos.

**Dueños.** Cada estado persistente lo serializa quien ya lo posee (architecture §10.2):

| Clave | Dueño | Ámbito | Contenido |
|---|---|---|---|
| `battery` | `BatteryComponent` | jugador | carga actual (el máximo se recalcula, R-010-24) |
| `inventory` | `InventoryComponent` | jugador | cada ranura: `item_id`, cantidad, durabilidad, `uid` (el número de ranuras se recalcula) |
| `experience` | `ExperienceComponent` | jugador | XP total |
| `location` | `LocationComponent` (nuevo) | jugador | `(zone_id, posición local)` |
| `zone_visits` | `GameManager` | mundo | contador de visitas por `zone_id` |
| `farm_visits` | `ZoneMemory` (nuevo) | mundo | por zona de farmeo y visita: cajas abiertas con su contenido y enemigos muertos por índice de aparición |
| `dropped_items` | `DroppedItemSpawner` | mundo | la lista de `DroppedItem.to_data()` de la spec 008, sin cambios (R-010-29) |
| `structures` | `BaseStructures` | mundo | la lista de `BuildGrid.to_data()` de la spec 009, sin cambios (R-010-31) |

Un solo grupo, `persistent`, para los dos ámbitos: `SaveManager` mira si el nodo cuelga de una entidad del grupo
`players` (entonces es del jugador con ese `player_uid`, R-010-22) o no (entonces es del mundo). Los componentes
del robot entran en el grupo en `robot.tscn`; `ZoneMemory`, `DroppedItems` y `BaseStructures` en `main.tscn`;
`GameManager` con `add_to_group()` en su `_ready`. Añadir un dueño en las specs 012-014 es poner el nodo en el
grupo con sus tres métodos (R-010-25). architecture §10.2 se amplía con una frase sobre los dueños del mundo; no
hace falta un segundo grupo. La cabecera (`world_id`, nombre, semilla, ruleset, `schema_version`, hora) no es de
ningún dueño: es el esquema del propio documento, que `SaveManager` lee de `GameManager` y le devuelve con
`GameManager.begin_world()` al cargar (R-010-20).

**Cajas y enemigos de la visita.** El estado de una zona de farmeo solo vale durante su visita: salir o morir sube
el contador y lo descarta (R-010-28). `ZoneMemory` (bajo `World`, como `DroppedItemSpawner` y `BaseStructures`)
guarda ese estado por zona junto con su número de visita, que lee de la propia zona (`FarmZone.get_visit()`, fijado
por `generate()` y `repopulate()`), nunca de `GameManager`: entre la subida del contador y la repoblación diferida
los dos no coinciden. `ZoneLoader` le entrega la zona cargada y le pide el estado al poblarla. La zona se puebla
con la misma semilla y la misma visita, así que número y posición de las cajas no cambian (R-010-35), y
`FarmZone.populate()` abre las cajas guardadas con lo que quedaba dentro y no pone a los enemigos muertos
(R-010-27, R-010-32). Los vivos vuelven a su punto con la vida completa (pregunta 3).

**Cuándo se guarda.** `SaveManager` escucha `EventBus` (`zone_changed` hacia la base, `player_recharged`,
`player_died`, `structure_built` y el nuevo `structure_moved`). Esas peticiones **nunca se atienden durante la
emisión**: se apuntan y se resuelven una vez al final del fotograma (`call_deferred`), todas juntas en un solo
guardado. Así:

- Las retenciones que `SaveFlow` pone en la misma emisión ya cuentan. `SaveFlow` retiene con
  `PlayerInput.REASON_TRAVEL` de `travel_started` a `travel_finished` / `travel_failed`, y con
  `PlayerInput.REASON_DEATH` de `player_died` a `player_respawned` del jugador local. Una petición retenida queda
  pendiente y se hace al soltarse la última retención (R-010-43).
- Una muerte en la zona de farmeo pide `died` (retenida), y el viaje de vuelta pide `entered_base` en el mismo
  fotograma en que se reaparece: sale **un** guardado, con el motivo de la primera petición pendiente (`died`), y
  un solo `game_saved` (R-010-44).
- Sin Mundo cargado (tests que no arrancan `Main`, Perfil bloqueado) una petición se ignora sin error: no hay nada
  que guardar. `save_game()` llamado a mano sin Mundo sí es un error (R-010-04).

El cierre de la ventana y el paso a segundo plano no esperan al final del fotograma: guardan en el acto si no hay
retención (el SO puede suspender la app en cuanto vuelve la notificación) y, si la hay, quedan pendientes; el
cierre sale después del guardado (`quit_action`). El modo colocación no necesita retención: `BaseStructures` solo
cambia al confirmar, así que el estado durante el modo **es** el de "cancelado sin cobrar nada"; lo prueba un test.

**Escritura segura** (R-010-45, R-010-46, R-010-47), por archivo `X`:

1. Escribir `X.tmp` entero y comprobar que se vuelve a leer.
2. Si `X` es válido (se lee y `SaveCodec.decode` da un objeto), copiarlo a `X.bak.tmp`.
3. Renombrar `X.tmp` a `X` (reemplaza; comprobado en Windows, §5.1).
4. Renombrar `X.bak.tmp` a `X.bak`.

Si falla 1, 2 o 3 se borran los temporales y `X` y `X.bak` quedan como estaban (R-010-45). Un corte entre 3 y 4
deja `X` nuevo y `X.bak` una versión más antigua, los dos válidos. Un principal dañado nunca pasa a ser la copia
(R-010-46). Los temporales sobrantes se ignoran al leer y se pisan en la siguiente escritura.

**Por qué este enfoque y no la alternativa principal.** La alternativa era que `SaveManager` leyera los campos de
cada componente (un `save_game()` que conoce batería, inventario…). Es más corta hoy, pero cada spec siguiente
tocaría `SaveManager` y rompería R-010-03 y R-010-25. Otra alternativa descartada: guardar `Resource` de Godot
(`ResourceSaver`) en `user://`; architecture §10.2 lo prohíbe porque un recurso editable puede ejecutar código.

### 1.1 Decisiones del plan

| # | Decisión | Por qué |
|---|---|---|
| D1 | `IStore` lo expone `GameManager.get_store()`, igual que `get_time_service()` (pregunta 11). Se actualiza la fila de `GameManager` en architecture §5. | `GameManager` ya da acceso a los servicios globales; `SaveManager` solo orquesta el guardado. `LocalStore` no necesita el Perfil (siempre dice "no"); la tienda nativa de v1.1 leerá los derechos con `SaveManager.get_profile()`. |
| D2 | `SaveManager` guarda en memoria el `ProfileData` cargado (uuid, derechos y listas vacías). La fila de `SaveManager` en architecture §5 lo dice. | El Perfil es estado de la cuenta, no de un robot ni de un mundo (R-010-16); alguien tiene que tenerlo para `get_player_uuid()` y para que v1.1 escriba derechos. No es el estado del jugador de R-010-03 (batería, inventario, XP, posición), que nunca pasa por `SaveManager` entre guardados. |
| D3 | La semilla se guarda como **texto decimal** (`"-8213…"`), no como número JSON. | Comprobado (§5.1): `JSON.parse` devuelve todo número como `float`, y un entero de 64 bits pierde precisión. La semilla cambiaría el mundo (R-010-21). |
| D4 | `SaveCodec` escribe con `JSON.stringify(data, "", true, true)` (claves ordenadas, precisión completa). Los lectores pasan los números por `SaveFields`, que acepta un `float` sin decimales como entero. | Comprobado (§5.1): con `full_precision` la ida y vuelta de `float` es exacta; sin él, no (R-010-09, R-010-37). |
| D5 | Clave de cifrado: una constante en `LocalSaveStore`, usada con `FileAccess.open_encrypted_with_pass`. Antes de descifrar se miran los 4 primeros bytes (`GDEC`). | Pregunta 1: ofuscación, no secreto. Vive solo en el almacén (R-010-57). Mirar la cabecera evita que un archivo en claro llegue al descifrado (que escribe un error del motor, §5.1). |
| D6 | Ajuste de proyecto `cyberscrap/save/plain_json_in_debug` (por defecto `false`). `LocalSaveStore.should_encrypt(is_debug, plain_setting)` es puro: en release siempre cifra. Al leer, un archivo con cabecera `GDEC` se descifra; uno sin ella solo se acepta en modo sin cifrar. | R-010-64. Un archivo en claro en release sería editable a mano, que es justo lo que evita el cifrado. |
| D7 | El Mundo se busca por `world_id` en el nombre del archivo (`world_<id>.save`); `ISaveStore.list_world_ids()` lo encuentra. En el PMV hay uno; si aparecen más, `push_error` y se usa el primero en orden. | R-010-18, sin pantalla de selección (v1.1). |
| D8 | Mundo nuevo: `world_id = Uid.generate()`, semilla de 64 bits con `Crypto.generate_random_bytes(8).decode_s64(0)` (no el RNG global, `test_no_global_rng`), ruleset `normal` (campo `new_world_ruleset` de `DataCatalog`, apuntando a `normal.tres`; enmendado al implementar, 2026-11-17: una constante `&"normal"` en `SaveManager` rompía la guarda de la spec 008, `test_r_008_03`, que prohíbe ese literal en el código) y nombre vacío. Los tests fijan la semilla con `SaveManager.create_world(seed)`. | R-010-19, pregunta 9. |
| D9 | `DevWorldConfigData` y `dev_world.tres` se **borran**: nadie los lee ya. `test_game_manager.gd` (casos R-004-08 y R-008-02) se sustituye por los casos R-010-20, porque R-010-20 reemplaza esos requisitos, y esos dos requisitos se marcan como sustituidos en las specs 004 y 008. `test_green_zone.gd` fija su semilla de respuesta conocida (20261115) en una constante del test; `test_death_controller.gd` toma el ruleset de `DataRegistry`. | Pregunta 9. No se debilita ningún test: los requisitos que comprobaban dejan de existir y los nuevos tienen su test. Borrado aprobado por el usuario (2026-11-17). |
| D10 | Los tests nunca tocan los guardados reales ni dependen del orden. Un *hook* de GUT (`pre_run_script`, verificado en `addons/gut/gut_config.gd:44`) instala un `MemorySaveStore` y una `quit_action` que no sale. `use_store()` reinicia **todo** el estado de `SaveManager` (Mundo, Perfil, retenciones, pendientes, bloqueo). Los tests que instancian `main.tscn` llaman en `before_each` a `SaveTestSupport.start_world()`, que pone un almacén nuevo y crea un Mundo con una semilla fija (`KNOWN_SEED`), y en `after_each` a `SaveTestSupport.reset()`. Los de `LocalSaveStore` usan `user://test_saves/<uid>/`, borrada al acabar, y afirman con `assert_engine_error` el error que el motor escribe al descifrar un archivo dañado. | Spec §5 ("nunca los guardados reales"), pregunta 9 (semilla por parámetro), constitución P13 (deterministas). |
| D11 | Avisos: `Hud.show_notice(key)` reutiliza la etiqueta y el temporizador del aviso de la spec 005 (también para "inventario lleno"). El aviso que impide jugar (R-010-55) es una pantalla nueva, `NoticeScreen`, que no se cierra con "atrás"; mientras el juego está bloqueado, `Main` ignora el botón de almacén. | R-010-45, R-010-49, R-010-55, R-010-62 sin un sistema de notificaciones (Tarea 4.1). |
| D12 | "Mundo nuevo" del HUD de depuración: `SaveManager.delete_save()` y `get_tree().reload_current_scene()`; `Main._ready` vuelve a cargar, no encuentra Mundo y crea uno. El arranque vive en la escena (`SaveFlow`) y no en el `_ready` del autoload precisamente para esto. Durante un viaje el botón no hace nada. | R-010-65. Recargar la escena deja los autoloads; `begin_world()` reinicia el estado global, también la zona actual. |
| D13 | Si el Perfil se pierde entero (principal y copia dañados, R-010-49), el `player_uuid` nuevo no coincide con el del Mundo y el robot empieza con estado de partida nueva en ese Mundo (R-010-10). Aceptado por el usuario para el PMV (2026-11-17); anotado en §7. | La spec pide un Perfil con uuid nuevo (pregunta 6); adoptar al único jugador del Mundo sería una regla nueva fuera de la spec (P14). |
| D14 | `SaveFlow` (`scenes/save/save_flow.gd`) saca de `main.gd` el arranque desde el guardado, las retenciones, los avisos y "Mundo nuevo". Suelta sus retenciones en `_exit_tree`. | Una responsabilidad por escena (constitución §2); `main.gd` ya tiene 245 líneas. |
| D15 | **Dos clases de señales** (R-010-09 precisado, architecture §7 y §10.2): las **de estado** dicen cuál es un valor ahora y repetirlas no tiene efectos (`battery_changed`, `inventory_changed`, `xp_changed`, `health_changed`; por convención, `*_changed`); las **de hecho** dicen que algo pasó y sus oyentes reaccionan (todo `EventBus`, `zone_visit_counted`, `battery_low`, `battery_depleted`, `overflowed`, `loot_generated`, `defeated`…). `from_save_data()` emite las de estado y nunca las de hecho. Consecuencias: `GameManager` carga los contadores sin `zone_visit_counted`; `BatteryComponent` carga con `battery_changed` y rearma el aviso de batería baja según el umbral, sin emitir `battery_low` ni `battery_depleted` (hoy `_set_current()` los emitiría); `LootBox.restore_opened()` no emite `loot_generated` ni `opened`; los enemigos saltados no emiten `defeated` ni `enemy_killed`. Refuerzo independiente del orden: `ZoneMemory` solo entrega un estado si su visita coincide con la de la zona. | Al cargar no ha pasado nada en el juego: emitir un hecho haría repoblar o borrar las cajas (visitas), avisar de batería baja o, en la spec 013, repetir la animación de subir de nivel. Ninguna pantalla muestra los contadores, `LocationComponent`, `DroppedItemSpawner` ni `BaseStructures`: no tienen señal de estado y no emiten nada. Un test vigila que cargar no emita ningún hecho (§5.2, R-010-09). |
| D18 | `BuildGrid._to_pair()` y la lectura de `DroppedItemSpawner._restore()` pasan a usar `SaveFields`; `DroppedItem.to_data()` escribe sus vectores con `SaveFields`. Los formatos JSON no cambian (R-010-29, R-010-31). | DRY (P2), aprobado por el usuario (2026-11-17): es la tercera lectura de pares JSON. `_restore()` además deja de suponer que cada campo existe, que ahora importa porque los datos vienen del disco. Los tests de `BuildGrid` y `DroppedItemSpawner` siguen en verde sin cambios. |
| D19 | `GameManager.zone_visit_changed` se renombra a `zone_visit_counted`, con los mismos argumentos y el mismo emisor. Cambian `game_manager.gd`, `zone_loader.gd`, `test_game_manager.gd`, `test_zone_loader.gd`, `test_death_controller.gd` y las páginas `docs/systems/` que la nombran (`data_catalog.md`, `death.md`, `travel.md`, `world_zones.md`). Los planes cerrados de las specs 008 y 009 no se tocan: son historia. | Aprobado por el usuario (2026-11-17). Era la única `*_changed` que es de hecho: con el nombre nuevo, la convención de D15 (`*_changed` = estado) no tiene excepciones y la regla se lee en el propio nombre. |
| D16 | Un Perfil con `schema_version` más nueva bloquea igual que un Mundo: ni se carga ni se sobrescribe, y `load_profile()` falla con `MSG_SAVE_NEWER_VERSION`. | R-010-55 habla de "a file"; sobrescribirlo perdería los derechos de compra de v1.1. |
| D17 | "Fill base" del HUD de depuración retiene los guardados mientras coloca y suelta al acabar: un solo guardado. | Cada `structure_built` guardaría de forma síncrona y falsearía la medida de FPS de R-009-22. |

## 2. Archivos

| Archivo (`game/…`) | Nuevo / Cambia | Responsabilidad |
|---|---|---|
| `scripts/services/i_save_store.gd` | Nuevo | `ISaveStore`: contrato de bytes del Perfil y de cada Mundo, con copia y apartado de dañados |
| `scripts/services/save_read_result.gd` | Nuevo | `SaveReadResult`: resultado de una lectura (encontrado, ausente, ilegible) con sus bytes |
| `scripts/services/local_save_store.gd` | Nuevo | `LocalSaveStore`: archivos en `user://saves/`, cifrado, copia, escritura segura |
| `scripts/services/i_store.gd` | Nuevo | `IStore`: contrato de la tienda |
| `scripts/services/local_store.gd` | Nuevo | `LocalStore`: siempre demo |
| `scripts/systems/save_codec.gd` | Nuevo | `SaveCodec`: `Dictionary` ↔ bytes JSON UTF-8 |
| `scripts/systems/save_migrations.gd` | Nuevo | `SaveMigrations`: versión actual de cada documento y cadena de migraciones |
| `scripts/systems/save_documents.gd` | Nuevo | `SaveDocuments`: montar, validar y separar Perfil y Mundo; grupo y claves de la cabecera |
| `scripts/util/save_fields.gd` | Nuevo | `SaveFields`: leer valores JSON con tipo (enteros que llegan como `float`, pares, vectores) |
| `scripts/data/profile_data.gd` | Nuevo | `ProfileData`: el Perfil en memoria |
| `scripts/autoload/save_manager.gd` | Nuevo | Autoload `SaveManager`: orquestación, peticiones, retenciones, cierre y segundo plano |
| `scripts/components/location_component.gd` | Nuevo | `LocationComponent`: zona y posición local del jugador, y la restaurada al cargar |
| `scenes/zones/zone_memory.gd` | Nuevo | `ZoneMemory`: estado de la visita en curso de cada zona de farmeo |
| `scenes/save/save_flow.gd` | Nuevo | `SaveFlow`: arranque desde el guardado, retenciones, avisos, "Mundo nuevo" (D14) |
| `scenes/ui/notice_screen.gd` / `.tscn` | Nuevo | `NoticeScreen`: aviso a pantalla completa que no se cierra (R-010-55) |
| `scripts/autoload/game_manager.gd` | Cambia | `begin_world()`, `world_id`, nombre, `get_store()`, dueño de `zone_visits`; sin mundo de desarrollo; `zone_visit_changed` → `zone_visit_counted` (D19) |
| `scripts/autoload/event_bus.gd` | Cambia | Señal `structure_moved` |
| `scripts/data/item_stack.gd` | Cambia | `durability` y `uid` (architecture §9.3), copiados por `copy()` |
| `scripts/data/zone_data.gd` | Cambia | `contains_local_position()` |
| `scripts/components/battery_component.gd` | Cambia | Contrato de guardado |
| `scripts/components/inventory_component.gd` | Cambia | Contrato de guardado (también lo usa el contenido de las cajas) |
| `scripts/components/experience_component.gd` | Cambia | Contrato de guardado |
| `scenes/entities/robot.gd` / `robot.tscn` | Cambia | `set_player_uid()`, `enter_zone()`, nodo `Location`; componentes persistentes en el grupo `persistent` |
| `scenes/entities/loot_box.gd` | Cambia | `get_save_state()` y `restore_opened()` |
| `scenes/farm_zone/farm_zone.gd` | Cambia | `populate()`, `get_visit()`, `get_visit_state()` |
| `scenes/farm_zone/zombie_spawner.gd` | Cambia | Índices de aparición muertos: los recuerda y no los vuelve a poner |
| `scenes/zones/zone_loader.gd` | Cambia | `travel_to_position()`, `ZoneMemory`, `robot.enter_zone()` |
| `scenes/entities/dropped_item_spawner.gd` | Cambia | Contrato de guardado; descarta caducados al cargar; `_restore()` lee con `SaveFields` (D18) |
| `scenes/entities/dropped_item.gd` | Cambia | `to_data()` escribe sus vectores con `SaveFields`, mismo formato (D18) |
| `scripts/systems/build_grid.gd` | Cambia | `_to_pair()` se sustituye por `SaveFields.to_vector2i()`, mismo formato (D18) |
| `scenes/base/base_structures.gd` | Cambia | Contrato de guardado; emite `structure_moved` |
| `scenes/main.gd` / `main.tscn` | Cambia | Nodos `SaveFlow` y `ZoneMemory` (grupos en la escena); `_ready` arranca con `SaveFlow` y viaja a la ubicación guardada; almacén ignorado con el juego bloqueado |
| `scenes/ui/hud.gd` | Cambia | `show_notice()`; "Partida guardada" al recargar |
| `scenes/ui/debug_hud.gd` / `.tscn` | Cambia | Semilla del mundo, botón "New world", retención durante "Fill base" |
| `resources/ui/screens.tres` | Cambia | Pantalla `notice` |
| `i18n/strings.csv` | Cambia | Claves de §4 |
| `project.godot` | Cambia | Autoload `SaveManager` (después de `GameManager`); ajuste `cyberscrap/save/plain_json_in_debug` |
| `.gutconfig.json` | Cambia | `pre_run_script` |
| `scripts/data/dev_world_config_data.gd`, `resources/config/dev_world.tres` | Se borran | D9 |
| `tests/support/memory_save_store.gd` | Nuevo | `MemorySaveStore`: almacén en memoria con fallos inyectables |
| `tests/support/save_test_hook.gd` | Nuevo | Hook de GUT (D10) |
| `tests/support/save_test_support.gd` | Nuevo | `SaveTestSupport.start_world()` / `reset()` (D10) |
| `tests/support/fake_persistent_owner.gd` | Nuevo | Dueño de prueba para R-010-25 |
| `tests/fixtures/saves/world_v1.json`, `profile_v1.json` | Nuevo | Archivos de ejemplo de la versión 1 (R-010-54), en JSON plano |
| `tests/unit/…`, `tests/integration/…` | Nuevo / Cambia | §5 |
| `specs/architecture.md` | Cambia | §5 (`GameManager` expone `IStore`; `SaveManager` guarda el Perfil en memoria), §7 (señales de estado y de hecho, `structure_moved`, motivos de `game_saved`), §10.2 (`from_save_data()` emite estado y nunca hechos, con el ejemplo del nivel de chasis; dueños del mundo en `persistent`; semilla como texto; precisión completa) |
| `specs/004-green-zone/spec.md`, `specs/008-death-recovery/spec.md` | Cambia | R-004-08 y R-008-02 marcados como sustituidos por R-010-20 (D9) |

## 3. Contratos

```gdscript
# --- Servicios ---------------------------------------------------------------
class_name SaveReadResult
extends RefCounted
enum Status { FOUND, MISSING, UNREADABLE }
var status: Status
var bytes: PackedByteArray          # plain bytes; empty unless FOUND
static func found(p_bytes: PackedByteArray) -> SaveReadResult
static func missing() -> SaveReadResult
static func unreadable() -> SaveReadResult

class_name ISaveStore
extends RefCounted
## Every method push_errors and fails when not overridden (R-010-01).
enum Copy { MAIN, BACKUP }
func read_profile(copy: Copy) -> SaveReadResult
func write_profile(bytes: PackedByteArray) -> ActionResult      # safe write of plan §1; keeps a valid MAIN as BACKUP
func set_aside_profile() -> ActionResult                        # renames MAIN and BACKUP aside, never deletes
func list_world_ids() -> PackedStringArray
func read_world(world_id: String, copy: Copy) -> SaveReadResult
func write_world(world_id: String, bytes: PackedByteArray) -> ActionResult
func set_aside_world(world_id: String) -> ActionResult
func delete_world(world_id: String) -> ActionResult             # MAIN, BACKUP and any leftover temporary

class_name LocalSaveStore
extends ISaveStore
const DEFAULT_ROOT := "user://saves"
const PLAIN_IN_DEBUG_SETTING := "cyberscrap/save/plain_json_in_debug"
func _init(p_root: String, p_encrypt: bool) -> void
## Release builds always encrypt (R-010-64).
static func should_encrypt(is_debug_build: bool, plain_requested: bool) -> bool
# Files: profile.save, profile.save.bak, world_<id>.save, world_<id>.save.bak, *.tmp, *.bak.tmp,
# set aside as <file>.damaged.<n> (first free n).

class_name IStore
extends RefCounted
## Every method push_errors when not overridden (R-010-58). Results never arrive during the call.
signal purchase_finished(sku: StringName, result: ActionResult)
signal restore_finished(result: ActionResult)
func has_entitlement(entitlement_id: StringName) -> bool        # synchronous, from the Profile
func purchase(sku: StringName) -> void
func restore() -> void

class_name LocalStore
extends IStore
const ERR_STORE_DEMO := &"ERR_STORE_DEMO"
# has_entitlement → false; purchase → purchase_finished(sku, failure(ERR_STORE_DEMO)) deferred;
# restore → restore_finished(success()) deferred, nothing changes (R-010-59).

# --- Sistemas (puros) -------------------------------------------------------
class_name SaveCodec
extends RefCounted
static func encode(document: Dictionary) -> PackedByteArray     # JSON, sorted keys, full precision (D4)
## Null when the bytes are not UTF-8 JSON with an object at the top.
static func decode(bytes: PackedByteArray) -> Variant

class_name SaveMigrations
extends RefCounted
const PROFILE_VERSION := 1
const WORLD_VERSION := 1
enum Outcome { CURRENT, MIGRATED, TOO_NEW, INVALID }
class Result:
	var outcome: Outcome
	var document: Dictionary
## Applies steps[v - 1] for every v from the document's schema_version up to current (R-010-53).
static func apply(document: Dictionary, current: int, steps: Array[Callable]) -> Result
static func migrate_world(document: Dictionary) -> Result       # apply(doc, WORLD_VERSION, world steps: none yet)
static func migrate_profile(document: Dictionary) -> Result

class_name SaveDocuments
extends RefCounted
const PERSISTENT_GROUP := &"persistent"
# World keys: schema_version, world_id, name, seed (decimal text, D3), ruleset_id, saved_at, players, world.
# Profile keys: schema_version, player_uuid, entitlements, hall_of_fame, cosmetics, blueprints.
class WorldHeader:
	var world_id: String
	var world_name: String
	var world_seed: int
	var ruleset_id: StringName
	var saved_at_unix: int
static func build_world(header: WorldHeader, players: Dictionary[String, Dictionary],
		world: Dictionary[String, Dictionary]) -> Dictionary
static func build_profile(profile: ProfileData) -> Dictionary
## Empty when valid; one message per problem. The ruleset id must be in the catalog.
static func validate_world(document: Dictionary, catalog: DataCatalog) -> PackedStringArray
static func validate_profile(document: Dictionary) -> PackedStringArray
static func read_header(document: Dictionary) -> WorldHeader                 # of a validated document
static func read_players(document: Dictionary) -> Dictionary[String, Dictionary]   # player_uid → {key → part}
static func read_world_parts(document: Dictionary) -> Dictionary[String, Dictionary]  # key → part
static func read_profile(document: Dictionary) -> ProfileData
## A repeated key within one scope (a player or the world) → its message (R-010-07).
static func find_repeated_keys(keys: Array[StringName]) -> PackedStringArray

class_name SaveFields
extends RefCounted
static func is_whole_number(value: Variant) -> bool              # int, or a float with no fraction
static func to_int(value: Variant, fallback: int) -> int
static func to_vector2i(value: Variant) -> Variant              # [x, y] whole numbers → Vector2i, else null
static func to_vector3(value: Variant) -> Variant               # [x, y, z] numbers → Vector3, else null
static func vector2i_to_array(value: Vector2i) -> Array
static func vector3_to_array(value: Vector3) -> Array

class_name ProfileData
extends RefCounted
var player_uuid: String
var entitlements: PackedStringArray
var hall_of_fame: Array[Dictionary]                              # empty in the MVP (R-010-12)
var cosmetics: PackedStringArray
var blueprints: PackedStringArray
static func create_new() -> ProfileData                         # player_uuid = Uid.generate()
func copy() -> ProfileData

# --- Contrato de cada dueño (R-010-06): por nombre, comprobado por test (R-010-07) ---
const SAVE_KEY := &"…"
func get_save_key() -> StringName
func to_save_data() -> Dictionary                               # JSON types only (R-010-08)
## Missing or invalid fields → push_error, that entry keeps its new-game state (R-010-10, R-010-11).
## Emits its state signals and never a fact signal (R-010-09, D15).
func from_save_data(data: Dictionary) -> void

# --- Autoloads ---------------------------------------------------------------
# SaveManager (autoload, no class_name)
signal save_notice(message_key: StringName)                    # non-blocking notices: R-010-45, R-010-49
const REASON_NEW_WORLD := &"new_world"
const REASON_ENTERED_BASE := &"entered_base"
const REASON_RECHARGED := &"recharged"
const REASON_DIED := &"died"
const REASON_STRUCTURE_BUILT := &"structure_built"
const REASON_STRUCTURE_MOVED := &"structure_moved"
const REASON_CLOSE := &"close"
const REASON_BACKGROUND := &"background"
const ERR_SAVE_FAILED := &"ERR_SAVE_FAILED"
const MSG_WORLD_DAMAGED := &"MSG_WORLD_DAMAGED"
const MSG_PROFILE_DAMAGED := &"MSG_PROFILE_DAMAGED"
const MSG_SAVE_NEWER_VERSION := &"MSG_SAVE_NEWER_VERSION"
## What runs once a close request is saved; get_tree().quit by default. The test hook replaces it (D10).
var quit_action: Callable
## Startup default is a LocalSaveStore; only this file and tests call it (guard test, R-010-02).
## Resets every other state: world, profile, holds, pending requests, block, pending quit.
func use_store(store: ISaveStore) -> void
## Loads MAIN, else BACKUP, else creates and writes (R-010-13). Newer schema → failure
## MSG_SAVE_NEWER_VERSION, nothing written (D16).
func load_profile() -> ActionResult
func save_profile() -> ActionResult
func get_player_uuid() -> String
func get_profile() -> ProfileData               # a copy
## The only World, its BACKUP, or a new one. Newer schema → failure MSG_SAVE_NEWER_VERSION. Resets holds.
func load_game() -> ActionResult
func create_world(world_seed: int) -> ActionResult  # resets holds; writes at once
func has_world() -> bool
## Writes now. No world, or saves blocked by a newer file → push_error and failure (R-010-04).
func save_game(reason: StringName) -> ActionResult
## Never acts during the call: noted and resolved once at the end of the frame, all noted reasons in one save
## with the first one as its reason; with a hold, when the last hold goes. No world → ignored, no error.
## A failure is reported by push_error and save_notice(ERR_SAVE_FAILED), hence void.
func request_save(reason: StringName) -> void
func hold_saves(reason: StringName) -> void
func release_saves(reason: StringName) -> void
func delete_save() -> ActionResult              # World and its backup; the Profile stays (R-010-15, R-010-51)
# _ready: set_auto_accept_quit(false); EventBus triggers → request_save.
# _notification: NOTIFICATION_WM_CLOSE_REQUEST → save now (or when holds go) then quit_action;
#                NOTIFICATION_APPLICATION_PAUSED → save now (or when holds go). No world → close quits at once.

# GameManager (changes)
## Renamed from zone_visit_changed (D19): a fact, a visit was counted. Whoever has that zone loaded repopulates it.
signal zone_visit_counted(zone_id: Vector2i, visit: int)
const SAVE_KEY := &"zone_visits"
## Only SaveManager calls it (guard test). Clears the visit counters and the current zone.
func begin_world(world_id: String, world_name: String, world_seed: int, ruleset: RulesetData) -> void
func get_world_id() -> String
func get_world_name() -> String
func get_store() -> IStore                      # D1
# + the three owner methods; from_save_data emits nothing (D15). DEV_WORLD_PATH and its loading go away.

# EventBus (addition)
## A placed structure moved to another cell. Emitted by BaseStructures, once per move (spec 010).
signal structure_moved(structure_uid: String)

# --- Datos -------------------------------------------------------------------
# ItemStack (additions, architecture §9.3)
var durability: int = -1                         # -1: does not apply
var uid: String = ""                             # only unique items
# copy() keeps both.

# ZoneData (addition)
## Inside the playable area: |x| <= size_m.x / 2 and |z| <= size_m.y / 2 (y is free).
func contains_local_position(local_position: Vector3) -> bool

# --- Componentes ------------------------------------------------------------
# BatteryComponent: SAVE_KEY = &"battery"; {"current": float}. current <= 0 or > maximum → push_error, keeps full.
#   battery_changed once when the loaded value differs from the current one; the low warning is re-armed from
#   the threshold, and neither battery_low nor battery_depleted is emitted (D15).
# InventoryComponent: SAVE_KEY = &"inventory"; {"slots": [null | {item_id, quantity, durability, uid}]}.
#   from_save_data keeps the slot count; unknown id, quantity outside 1..stack_max or a slot beyond the count →
#   push_error and that slot stays empty; one inventory_changed.
# ExperienceComponent: SAVE_KEY = &"experience"; {"total": int}. Negative → push_error, no change.
#   xp_changed once when it changes.

class_name LocationComponent
extends Node
const SAVE_KEY := &"location"
## The player now stands in zone_id; positions are local to zone_root.
func enter(zone_id: Vector2i, zone_root: Node3D) -> void
func has_restored_location() -> bool
func get_restored_zone_id() -> Vector2i
func get_restored_local_position() -> Vector3
# to_save_data: {"zone_id": [x, y], "position": [x, y, z]} while in a zone; the restored one before entering any;
# {} if neither.

# --- Entidades y zonas ------------------------------------------------------
# Robot (changes)
@onready var location: LocationComponent = %Location
## The Profile's uuid (R-010-14); also the attacker uid of its melee.
func set_player_uid(uid: String) -> void
## place_at() plus location.enter().
func enter_zone(zone_id: Vector2i, zone_root: Node3D, world_position: Vector3) -> void

# LootBox (additions)
## Null when it was not opened in this visit; else {"contents": InventoryComponent save data}.
func get_save_state() -> Variant
## Opened with these contents, without rolling and without loot_generated (R-010-27): sizes its contents to the
## saved slot list, loads them, shows the opened mesh, connects inventory_changed and disables itself if empty,
## as after a roll. Already opened → push_error, no change.
func restore_opened(saved: Dictionary) -> void

# FarmZone (additions)
## generate() + boxes restored from saved_state + enemies of the visit without the dead ones.
func populate(world_seed: int, visit: int, pool: ObjectPool, saved_state: Dictionary) -> void
## The visit given to generate() or repopulate().
func get_visit() -> int
## {"boxes": [{"marker": int, "contents": {...}}], "dead_enemies": [int]} of the visit in progress.
func get_visit_state() -> Dictionary
# spawn_enemies(world_seed, visit, pool, dead_indices: Array[int] = []) passes them to the spawner.

# ZombieSpawner (changes)
## dead_indices are not placed and roll no drop; their brain seed is still drawn, so the others keep theirs.
func spawn(zone: ZoneData, markers: Array[Node], world_seed: int, visit: int, pool: ObjectPool,
		dead_indices: Array[int] = []) -> void
func get_dead_indices() -> Array[int]           # skipped plus killed in this visit, sorted; despawn_all clears

class_name ZoneMemory
extends Node
const SAVE_KEY := &"farm_visits"
func bind_farm(farm: FarmZone) -> void
## Keeps the bound farm's state under farm.get_visit(); ZoneLoader calls it before despawning.
func unbind_farm() -> void
## The kept state of zone_id when it is of that visit; else {}.
func take_state(zone_id: Vector2i, visit: int) -> Dictionary
# Listens to GameManager.zone_visit_counted: drops the kept state of that zone (R-010-28).
# to_save_data: {"zones": [{"zone_id": [x, y], "visit": n, "state": {...}}]}, the bound farm's live state included.

# ZoneLoader (changes)
@export var zone_memory: ZoneMemory
## travel_to(), arriving at local_position of the zone instead of its spawn point (R-010-34).
func travel_to_position(zone_id: Vector2i, local_position: Vector3) -> ActionResult

# DroppedItemSpawner: SAVE_KEY = &"dropped_items"; {"items": [DroppedItem.to_data()…]} of every zone.
#   from_save_data replaces what is stored, drops the expired ones with time_service now (R-010-30),
#   push_errors and skips malformed entries; bind_zone() restores them as in spec 009.
# BaseStructures: SAVE_KEY = &"structures"; {"placed": [BuildGrid.to_data()…]}.
#   from_save_data skips entries with an unknown structure id (push_error, R-010-11), then load_data();
#   move() emits EventBus.structure_moved on success.

# --- Presentación -----------------------------------------------------------
class_name SaveFlow
extends Node
@export var ui_manager: UIManager
## Connects save_notice to the HUD, loads the Profile (robot takes its uuid) and the World. False when the game
## is blocked by a newer file: NoticeScreen open; Main freezes World and starts no travel.
func start(robot: Robot, hud: Hud, debug_hud: DebugHud, zone_loader: ZoneLoader) -> bool
func is_game_blocked() -> bool
## The death hold, for the branch where a respawn was rejected (a bug already reported).
func release_death_hold() -> void
# Holds REASON_TRAVEL from travel_started to travel_finished/travel_failed, and REASON_DEATH from the local
# player's player_died to its player_respawned; releases both in _exit_tree. new_world_requested → delete_save()
# and reload_current_scene(), ignored during a travel.

# Hud (changes)
const MSG_GAME_SAVED := &"MSG_GAME_SAVED"
func show_notice(message_key: StringName) -> void   # the spec 005 label and timer
# _ready connects EventBus.game_saved: REASON_RECHARGED → show_notice(MSG_GAME_SAVED) (R-010-62).

# DebugHud (changes)
signal new_world_requested
func show_world_seed(world_seed: int) -> void
# fill_base() holds saves while placing (D17).

class_name NoticeScreen
extends UIScreen
const SCREEN_ID := &"notice"
const CONTEXT_MESSAGE := &"message"   # translation key
# handle_back() → true: it stays open.
```

## 4. Datos

No hay valores de juego nuevos. Los que intervienen ya existen y se citan por su fuente:

| Recurso / `.tres` | Campos | Valores desde |
|---|---|---|
| `DroppedItemConfigData` (`dropped_items.tres`) | `lifetime_s` (caducidad al cargar, R-010-30) | BALANCE §7.2 (5 min), sin cambios |
| `RulesetData` (`normal.tres`) | `id = normal` (ruleset del Mundo nuevo, por `DataCatalog.new_world_ruleset` en `data_catalog.tres`) | PMV §2.4, sin cambios |
| `BatteryConfigData` (`robot_battery.tres`) | `maximum` (se recalcula al cargar, R-010-24) | BALANCE §1.1, sin cambios |
| `ChassisLevelData` (`chassis_levels.tres`) | ranuras del nivel 1 (se recalculan, R-010-24) | BALANCE §6, sin cambios |
| `ZoneData` (`base.tres`, `green_zone.tres`) | `size_m` (posición válida, R-010-36) | BALANCE §7, sin cambios |
| `MessageTimer` de `hud.tscn` | 3 s, duración del aviso (pregunta 12: la misma de la spec 005) | spec 005, sin cambios |
| `project.godot` | `cyberscrap/save/plain_json_in_debug = false` | D6 (no es un número de juego) |
| `SaveMigrations` | `PROFILE_VERSION = 1`, `WORLD_VERSION = 1` | R-010-52 (versión de formato, no de juego) |

Claves de traducción nuevas (ES / EN) en `i18n/strings.csv`:

| Clave | es | en |
|---|---|---|
| `MSG_GAME_SAVED` | Partida guardada | Game saved |
| `ERR_SAVE_FAILED` | No se pudo guardar la partida | The game could not be saved |
| `MSG_WORLD_DAMAGED` | La partida guardada estaba dañada; empieza un mundo nuevo | The saved game was damaged; a new world starts |
| `MSG_PROFILE_DAMAGED` | El perfil estaba dañado; se ha creado uno nuevo | The profile was damaged; a new one was created |
| `MSG_SAVE_NEWER_VERSION` | Esta partida es de una versión más nueva del juego. Actualízalo para seguir jugando. | This save comes from a newer version of the game. Update it to keep playing. |
| `ERR_STORE_DEMO` | Las compras no están disponibles en la demo | Purchases are not available in the demo |

Archivos de ejemplo (R-010-54): `tests/fixtures/saves/world_v1.json` (un jugador con batería, una pila de `scrap`
con durabilidad y `uid`, XP, posición en la zona verde; visitas, una caja abierta, un enemigo muerto, un objeto
caído y una estación) y `profile_v1.json`. En JSON plano: son documentos, no archivos del almacén.

## 5. Verificación

`S` = `tests/unit/`, `I` = `tests/integration/`. Los tests de disparadores esperan un fotograma
(`await wait_process_frames(1)`) porque las peticiones se resuelven al final del fotograma.

### 5.1 Resultado de los puntos (verificar) (2026-11-17)

Comprobado con la referencia de clases de Godot 4.7.2 (`--doctool`) y un script en headless fuera del repo, en
Windows 11:

| # | Punto | Resultado |
|---|---|---|
| 1 | `FileAccess.open_encrypted_with_pass(path, mode_flags, pass)` | ✅ Existe (también `open_encrypted(path, mode_flags, key, iv)`). Escribe y lee; con otra clave devuelve `null`, `get_open_error() == ERR_FILE_CORRUPT` y el motor escribe un error ("MD5 sum… does not match"): los tests lo afirman con `assert_engine_error` (D10). La comprobación MD5 cubre los datos, no el relleno del último bloque: un byte cambiado en el relleno no se detecta, pero tampoco cambia el JSON; lo que no sea JSON válido lo para `SaveCodec`/la validación |
| 2 | Cabecera de un archivo cifrado | ✅ `GDEC` en los 4 primeros bytes. Un archivo sin ella devuelve `null`, `ERR_FILE_UNRECOGNIZED` y otro error del motor: por eso se mira la cabecera antes (D5, D6) |
| 3 | `DirAccess.rename_absolute()` sobre un destino existente | ✅ en Windows (`OK`, el destino queda reemplazado). ✅ Android: confirmado en M2 (§5.4); el plan B (borrar el destino antes de renombrar) no hizo falta |
| 4 | `JSON.stringify(data, indent, sort_keys, full_precision)` | ✅ Existe (`sort_keys` por defecto `true`). Con `full_precision = true`, `73.12345678901235` y `0.1 + 0.2` vuelven exactos; sin él, no (D4) |
| 5 | Números al parsear | ✅ `JSON.parse_string` y `JSON.parse` devuelven **siempre** `float`, también para `7`; `9007199254740993` vuelve como `9007199254740992.0` (D3, `SaveFields`) |
| 6 | Cierre de ventana | ✅ `Node.NOTIFICATION_WM_CLOSE_REQUEST` (1006) y `SceneTree.set_auto_accept_quit()` existen. ✅ Llega al autoload con la ventana real: M1 (§5.4) |
| 7 | Segundo plano en Android (pregunta 2) | ✅ `Node.NOTIFICATION_APPLICATION_PAUSED` (2015) y `NOTIFICATION_APPLICATION_RESUMED` (2014) existen; la referencia de clases los da como propios de Android e iOS. ✅ Llega en el dispositivo: M2 (§5.4) |
| 8 | `SceneTree.reload_current_scene()` conserva los autoloads | ✅ Los autoloads cuelgan de `root`, no de la escena actual; confirmado en M3 (§5.4): el `player_uuid` no cambia |
| 9 | `ProjectSettings.get_setting(name, default)` con un ajuste propio | ✅ Lee el valor de `project.godot`; con un nombre que no existe devuelve el valor por defecto |
| — | `Crypto.generate_random_bytes(8).decode_s64(0)` | ✅ Da un entero de 64 bits (D8) |
| — | GUT `pre_run_script`, `assert_engine_error`, `assert_push_error` | ✅ En `addons/gut/gut_config.gd:44` y `addons/gut/test.gd:2348, 2389`; `failure_error_types` incluye `engine` y `push_error` (`gut_config.gd:57`) |

### 5.2 Requisitos

| Requisito | Test (`game/tests/…`) o paso manual |
|---|---|
| R-010-01 | `S/test_i_save_store.gd::test_r_010_01_base_methods_report_errors`; `S/test_local_save_store.gd::test_r_010_01_files_under_root` |
| R-010-02 | `S/test_save_manager.gd::test_r_010_02_public_methods`; `::test_r_010_02_only_save_manager_uses_a_store` (busca `LocalSaveStore`, `ISaveStore` y `use_store(` en `scenes/` y `scripts/`, fuera de `save_manager.gd` y `scripts/services/`) |
| R-010-03 | `S/test_save_manager.gd::test_r_010_03_holds_no_player_state` (lista blanca de variables del script, como `test_event_bus` R-007-19); revisión de `architecture-guardian` |
| R-010-04 | `S/test_save_manager.gd::test_r_010_04_failures_return_action_result` (sin mundo, escritura fallida, versión nueva: `ok == false`, `error_key` y `assert_push_error`); `::test_r_010_04_request_without_world_is_silent` |
| R-010-05 | `S/test_save_documents.gd`, `S/test_save_migrations.gd`, `S/test_save_codec.gd` sin árbol de escena ni archivos |
| R-010-06 | `I/test_save_contract.gd::test_r_010_06_player_components_in_group` (batería, inventario, XP y ubicación del robot de `main.tscn`) |
| R-010-07 | `I/test_save_contract.gd::test_r_010_07_every_owner_has_the_methods`; `::test_r_010_07_keys_unique_per_scope`; `S/test_save_documents.gd::test_r_010_07_repeated_key_found` |
| R-010-08 | `I/test_save_contract.gd::test_r_010_08_only_json_types` (recorre cada `to_save_data()`: solo `null`, `bool`, `int`, `float`, `String`, `Array`, `Dictionary` con claves `String`; ningún texto empieza por `res://` ni `user://`) |
| R-010-09 | `test_r_010_09_round_trip_*` en `S/test_battery_component.gd` (desde una carga que no es la máxima: un `battery_changed`), `test_inventory_component.gd` (un `inventory_changed`), `test_experience_component.gd` (un `xp_changed`), `test_location_component.gd`, `test_game_manager.gd`, `I/test_zone_memory.gd`, `I/test_dropped_item_spawner.gd`, `I/test_base_structures.gd` (mismo estado; los cuatro últimos no tienen señal de estado, D15); `S/test_battery_component.gd::test_r_010_09_load_below_threshold_no_fact` (ni `battery_low` ni `battery_depleted`); `I/test_save_load.gd::test_r_010_09_load_emits_no_fact_signal` (Mundo con la batería bajo el umbral, una caja abierta, un enemigo muerto, un objeto caído y una estación: durante la carga no se emite ninguna señal de `EventBus`, ni `zone_visit_counted`, ni `battery_low`, `battery_depleted` u `overflowed`; sí `battery_changed`, `inventory_changed` y `xp_changed`. El viaje posterior emite su `zone_changed`, que es un hecho del viaje y no de la carga). Si un dueño futuro emite un hecho al cargar, este test falla |
| R-010-10 | `I/test_save_load.gd::test_r_010_10_missing_key_keeps_new_game` (documento sin `inventory` ni `structures`) |
| R-010-11 | `test_r_010_11_unknown_id_skipped` en `S/test_inventory_component.gd`, `I/test_dropped_item_spawner.gd`, `I/test_base_structures.gd`, `I/test_zone_memory.gd` (`assert_push_error`, el resto carga) |
| R-010-12 | `S/test_save_documents.gd::test_r_010_12_profile_fields` |
| R-010-13 | `S/test_save_manager.gd::test_r_010_13_profile_created_once` (sin Perfil: se crea y se escribe; segunda carga: el mismo) |
| R-010-14 | `S/test_save_manager.gd::test_r_010_14_uuid_stable`; `I/test_save_load.gd::test_r_010_14_robot_takes_profile_uuid` (y su `melee.attacker_uid`) |
| R-010-15 | `S/test_local_save_store.gd::test_r_010_15_delete_world_keeps_profile` (bytes del Perfil y de su copia iguales) |
| R-010-16 | `S/test_save_documents.gd::test_r_010_16_profile_has_no_world_state` (claves exactamente las de R-010-12) |
| R-010-17 | `S/test_save_documents.gd::test_r_010_17_world_header`; `S/test_save_manager.gd::test_r_010_17_saved_at_from_time_service` (reloj falso) |
| R-010-18 | `S/test_local_save_store.gd::test_r_010_18_world_found_by_id` (dos mundos conviven); `S/test_save_manager.gd::test_r_010_18_loads_the_only_world` |
| R-010-19 | `I/test_save_load.gd::test_r_010_19_new_world` (cabecera completa, ruleset `normal`, robot en el punto de aparición de la base, escrito en el almacén) |
| R-010-20 | `S/test_game_manager.gd::test_r_010_20_world_from_begin_world` (sustituye R-004-08 y R-008-02, D9); `::test_r_010_20_only_save_manager_begins_a_world` |
| R-010-21 | `I/test_save_load.gd::test_r_010_21_seed_never_changes` (tres ciclos guardar-cargar; semilla de 64 bits con los 8 bytes ocupados) |
| R-010-22 | `S/test_save_documents.gd::test_r_010_22_players_by_uid` (dos jugadores en el mismo documento) |
| R-010-23 | `I/test_save_load.gd::test_r_010_23_player_state_saved` |
| R-010-24 | `I/test_save_load.gd::test_r_010_24_derived_values_not_saved` (el documento no tiene máximo ni número de ranuras; al cargar salen de los `.tres`) |
| R-010-25 | `I/test_save_load.gd::test_r_010_25_new_owner_needs_no_change` (`FakePersistentOwner` en el grupo: se guarda y se carga) |
| R-010-26 | `I/test_save_load.gd::test_r_010_26_visit_counters` (cargar deja el valor guardado y no emite `zone_visit_counted`) |
| R-010-27 | `I/test_zone_memory.gd::test_r_010_27_open_boxes_kept`; `S/test_loot_box.gd::test_r_010_27_restore_opened` (abierta, con su contenido, sin `loot_generated`; vacía → desactivada) |
| R-010-28 | `I/test_zone_memory.gd::test_r_010_28_visit_up_discards_boxes` (también guardando entre la subida y la repoblación diferida) |
| R-010-29 | `I/test_dropped_item_spawner.gd::test_r_010_29_saved_as_spec_008` (igual a `to_data()`) |
| R-010-30 | `I/test_dropped_item_spawner.gd::test_r_010_30_expired_on_load` (reloj falso: límite exacto caduca, un segundo antes no, tiempo negativo no) |
| R-010-31 | `I/test_base_structures.gd::test_r_010_31_saved_as_spec_009` |
| R-010-32 | `I/test_zone_memory.gd::test_r_010_32_dead_enemies_stay_dead` (ni vuelven ni sueltan otra vez); `I/test_zombie_spawner.gd::test_r_010_32_skipped_keep_other_seeds` |
| R-010-33 | `I/test_save_load.gd::test_r_010_33_no_elapsed_time` (reloj falso adelantado una hora: batería, cajas y enemigos como al guardar) |
| R-010-34 | `I/test_save_load.gd::test_r_010_34_loads_saved_zone_and_position` (guardar en la zona verde, cargar: zona verde y misma posición local) |
| R-010-35 | `I/test_save_load.gd::test_r_010_35_same_boxes_same_visit` |
| R-010-36 | `I/test_save_load.gd::test_r_010_36_bad_location_goes_to_base` (zona desconocida y posición fuera de `size_m`); `S/test_zone_resources.gd::test_r_010_36_contains_local_position` |
| R-010-37 | `I/test_save_load.gd::test_r_010_37_save_load_same_state` (todo §3.5 y §3.6) |
| R-010-38 | `I/test_save_triggers.gd::test_r_010_38_entering_base_saves_without_recharge` |
| R-010-39 | `I/test_save_triggers.gd::test_r_010_39_recharge_saves_after_recharge` (la batería guardada es la máxima) |
| R-010-40 | `S/test_save_manager.gd::test_r_010_40_close_request_saves_then_quits` (notificación enviada a mano; `quit_action` de prueba: corre después del guardado y, con una retención, solo al soltarla); paso manual M1 |
| R-010-41 | `S/test_save_manager.gd::test_r_010_41_background_saves` (sin esperar al final del fotograma); paso manual M2 |
| R-010-42 | `I/test_save_triggers.gd::test_r_010_42_death_saves_once_after_respawn` (un guardado, motivo `died`, batería > 0, robot en la base); `::test_r_010_42_build_and_move_save` |
| R-010-43 | `I/test_save_triggers.gd::test_r_010_43_held_during_travel`; `::test_r_010_43_held_during_transfer`; `::test_r_010_43_placement_state_is_cancelled_state` (guardar en PLACE y en MOVE: sin estructura nueva, sin cobro, estructura en su celda); `S/test_save_manager.gd::test_r_010_43_holds_reset` (`use_store`, `load_game`, `create_world`) |
| R-010-44 | `I/test_save_triggers.gd::test_r_010_44_one_game_saved_per_save` (cada motivo distinto; varias peticiones en un fotograma o retenidas → un solo `game_saved` con el primer motivo) |
| R-010-45 | `S/test_save_manager.gd::test_r_010_45_failed_save_keeps_files` (`MemorySaveStore` con fallo: sin `game_saved`, `save_notice(ERR_SAVE_FAILED)`); `S/test_local_save_store.gd::test_r_010_45_failed_write_keeps_files` (fallo en el paso 1, con el `.tmp` ocupado por una carpeta, y en el paso 3, con `X` sustituido por una carpeta no vacía: `X` y `X.bak` iguales); `S/test_hud.gd::test_r_010_45_notice_shown` |
| R-010-46 | `S/test_local_save_store.gd::test_r_010_46_backup_before_overwrite`; `::test_r_010_46_damaged_main_not_kept_as_backup` (cifrado y en claro) |
| R-010-47 | `S/test_local_save_store.gd::test_r_010_47_leftover_temporaries_ignored` (`.tmp` y `.bak.tmp` a medias junto a un principal válido: se lee el principal; la siguiente escritura funciona) |
| R-010-48 | `S/test_save_manager.gd::test_r_010_48_damaged_main_loads_backup` (bytes ilegibles, JSON roto y documento inválido; `assert_push_error`) |
| R-010-49 | `S/test_save_manager.gd::test_r_010_49_both_damaged_new_world`; `::test_r_010_49_both_damaged_new_profile`; `S/test_local_save_store.gd::test_r_010_49_set_aside_keeps_files` |
| R-010-50 | `S/test_save_manager.gd::test_r_010_50_backup_only_on_damage` (con el principal válido nunca se lee la copia; `Copy.BACKUP` no aparece en `scenes/` ni en `scripts/` fuera de `save_manager.gd` y `scripts/services/`); revisión de que ninguna pantalla lo ofrece |
| R-010-51 | `S/test_local_save_store.gd::test_r_010_51_delete_removes_backup` |
| R-010-52 | `S/test_save_documents.gd::test_r_010_52_schema_versions` |
| R-010-53 | `S/test_save_migrations.gd::test_r_010_53_chain_applied` (cadena inyectada v1→v2→v3); `S/test_save_manager.gd::test_r_010_53_before_any_owner_reads` (con un paso de prueba) |
| R-010-54 | `I/test_save_fixtures.gd::test_r_010_54_world_v1_loads`; `::test_r_010_54_profile_v1_loads` |
| R-010-55 | `S/test_save_manager.gd::test_r_010_55_newer_world_refused`; `::test_r_010_55_newer_profile_refused` (ni carga ni escribe después: bytes iguales); `I/test_save_load.gd::test_r_010_55_notice_and_no_game` (`NoticeScreen` abierta, sin viaje, `World` congelado; ni "atrás" ni el almacén la cierran) |
| R-010-56 | `S/test_local_save_store.gd::test_r_010_56_files_not_readable_as_json` (Perfil, Mundo y copias) |
| R-010-57 | `S/test_save_manager.gd::test_r_010_57_store_gets_plain_json` (el `MemorySaveStore` recibe bytes que `SaveCodec.decode` lee); revisión: `open_encrypted` solo en `local_save_store.gd` |
| R-010-58 | `S/test_i_store.gd::test_r_010_58_base_methods_report_errors`; `::test_r_010_58_signals` |
| R-010-59 | `S/test_local_store.gd::test_r_010_59_always_demo` (await de las señales; `ERR_STORE_DEMO` traducida en ES y EN) |
| R-010-60 | `S/test_save_documents.gd::test_r_010_60_entitlements_only_in_profile` |
| R-010-61 | `S/test_no_network.gd::test_r_010_61_no_billing_or_network` (`addons/` solo tiene `gut`; ningún script usa `HTTPRequest`, `HTTPClient`, `StreamPeerTCP`, `WebSocketPeer`, `JavaClassWrapper` ni `Engine.get_singleton`) |
| R-010-62 | `S/test_hud.gd::test_r_010_62_saved_notice_only_on_recharge` |
| R-010-63 | `I/test_save_load.gd::test_r_010_63_close_and_reopen_keeps_progress` (dos `Main` seguidos con el mismo `MemorySaveStore`); pasos manuales M1 y M2 |
| R-010-64 | `S/test_local_save_store.gd::test_r_010_64_release_always_encrypts`; `::test_r_010_64_plain_in_debug`; `S/test_project_settings.gd::test_r_010_64_setting_off_by_default` |
| R-010-65 | `S/test_debug_hud.gd::test_r_010_65_shows_seed_and_new_world`; `S/test_save_manager.gd::test_r_010_65_delete_save`; paso manual M3 |

Tests existentes que cambian, sin debilitarse: `test_game_manager.gd` (D9 y la lista blanca de variables de
`GameManager` con `world_id`, nombre y tienda), `test_green_zone.gd` y `test_death_controller.gd` (D9),
`test_main_scene.gd`, `test_base_loop.gd`, `test_base_zone.gd` y `test_hud_attack_input.gd`
(`SaveTestSupport.start_world()` / `reset()`, D10), `test_event_bus.gd` (`structure_moved`),
`test_project_settings.gd` (autoload y ajuste), `test_debug_hud.gd` (retención de D17), `test_loot_box.gd`,
`test_zombie_spawner.gd`, `test_dropped_item_spawner.gd`, `test_base_structures.gd` (casos nuevos). Los tests que
disparan eventos sin arrancar `Main` (`test_zone_loader`, `test_charging_station`, `test_placement_screen`,
`test_build_flow`, `test_death_controller`) no cambian: sin Mundo, la petición se ignora sin error.

### 5.3 Pasos manuales

| # | Paso | Cubre |
|---|---|---|
| M1 | PC: primer arranque, recoger chatarra en la zona verde, volver, construir y colocar una estación, recargar ("Partida guardada"). Cerrar la ventana y reabrir: misma batería, inventario, XP, estación en su celda y visita. Cerrar dentro de la zona verde con dos cajas abiertas y un zombie muerto; reabrir: misma visita, cajas abiertas con lo que quedaba, zombie sin volver. Un objeto caído sigue al reabrir antes de 5 min y no después. | R-010-34, 35, 40, 62, 63, spec §5, §5.1 punto 6 |
| M2 | Android de gama media (APK debug): lo mismo de M1 mandando la app a segundo plano y matándola desde recientes; recargar en la estación no produce un tirón visible (perfilador o FPS del HUD de depuración); un segundo guardado reemplaza el archivo (renombrado sobre un destino existente). | R-010-41, R-010-47, R-010-63, P12, §5.1 puntos 3 y 7 |
| M3 | PC, build de depuración: el HUD de depuración muestra la semilla; "New world" crea otro Mundo (semilla distinta, robot en la base) y el `player_uuid` del Perfil no cambia. En un export release el HUD de depuración no aparece. | R-010-65, R-010-15, §5.1 punto 8 |
| M4 | PC: dañar a mano el archivo del Mundo en `user://saves/` → carga la copia; dañar los dos → Mundo nuevo, aviso y los dañados apartados sin borrar. Abrir los archivos con un editor de texto: no se leen como JSON. | R-010-48, 49, 56 |

### 5.4 Resultado de los pasos manuales (T-010-10, 2026-11-17)

Hechos por la persona que revisa en PC (Windows) y en el Android de gama media (APK debug). Resultado según su
informe: todo pasa.

| Paso | Resultado |
|---|---|
| M1 (PC) | ✅ Cerrar la ventana guarda y reabrir conserva el progreso (§5.1 punto 6) |
| M2 (Android) | ✅ Segundo plano y muerte desde recientes conservan el progreso; sin tirón visible al recargar; el segundo guardado reemplaza el archivo (§5.1 puntos 3 y 7) |
| M3 (PC) | ✅ Semilla visible, "New world" crea otro Mundo y el `player_uuid` no cambia (§5.1 punto 8) |
| M4 (PC) | ✅ Con el principal dañado se carga la copia; con los dos dañados, Mundo nuevo y los dañados apartados |

No se anotaron cifras de FPS ni de tiempo de guardado, solo que no hay tirón visible.

**Errores del motor en M4 (esperados).** Abrir un archivo cifrado dañado hace que Godot escriba su propio error
(`file_access_encrypted.cpp`, `ERR_FILE_CORRUPT`), como dice §5.1 punto 1; no se puede evitar sin descifrar a mano, y
`LocalSaveStore._read()` lo trata como copia ilegible. Con el principal dañado aparece dos veces, junto al aviso de
`SaveManager`: al leerlo al cargar y en el primer guardado, cuando el paso 2 de la escritura segura comprueba si el
principal vale para copia. Esa comprobación es la que impide que el principal dañado
sustituya a la copia buena (R-010-46); después el principal queda reemplazado por uno válido.

**Desviaciones de implementación.** Las firmas de §3 se cumplen. Añadido en la revisión al implementar, sin tocar
ningún requisito: una copia del Mundo cuya cabecera tiene un `world_id` distinto del de su archivo cuenta como
inválida (R-010-18, `test_r_010_18_header_of_another_world_is_not_valid`); y un archivo dañado que no se puede
apartar nunca se sobrescribe (§7).

## 6. Check de constitución

| Principio | Cumple | Nota |
|---|---|---|
| P1 Spec primero | ✅ | Spec 010 *Aprobado*, sin preguntas abiertas |
| P2 Una fuente de verdad | ✅ | Sin números de juego nuevos; máximo de batería y ranuras se recalculan desde sus `.tres` (R-010-24); los formatos de objetos caídos y estructuras se reutilizan sin copiarlos. El ruleset del Mundo nuevo es un dato del catálogo (`DataCatalog.new_world_ruleset`), no un literal. La lectura de pares JSON vive solo en `SaveFields` (D18) |
| P3 Lógica separada | ✅ | Documento, validación, migración y códec puros en `scripts/systems/`; el almacén es un servicio; las escenas solo cablean |
| P4 Estado por jugador | ⚠️ | El estado del robot vive en sus componentes y se guarda por `player_uid`. `SaveManager` guarda el `ProfileData` en memoria (D2): es estado de la cuenta, no de un robot ni de un mundo, y la arquitectura no tiene otro autoload para él. `GameManager` gana `world_id`, nombre y tienda: estado global |
| P5 Datos como recursos | ✅ | Sin recursos nuevos; se borra `DevWorldConfigData`, que deja de usarse (D9) |
| P6 Señales | ✅ | Disparadores por `EventBus` (`structure_moved` nueva, fila en architecture §7); señales de estado y de hecho separadas (D15); referencias por `%UniqueName` y `@export` |
| P7 Tipado | ✅ | Todo tipado, también los diccionarios del documento; los `Variant` de JSON pasan por `SaveFields` antes de usarse (`unsafe_call_argument` es error) |
| P8 Plataforma | ✅ | Ni `OS.has_feature()` ni `OS.get_name()`: el cierre y el segundo plano son notificaciones del motor en un autoload; `OS.is_debug_build()` solo decide el formato del almacén y el HUD de depuración, como ya hace este |
| P9 Determinismo | ✅ | La semilla del Mundo se crea una vez (creación, no generación, pregunta 9) y nunca cambia; poblar una zona cargada usa la misma semilla y visita; los enemigos muertos se saltan sin mover las semillas de los demás; los tests fijan la semilla (D10) |
| P10 Servicios | ✅ | `ISaveStore`/`LocalSaveStore`, `IStore`/`LocalStore`; solo `SaveManager` usa el almacén (test); ninguna dependencia nueva (R-010-61) |
| P11 i18n | ✅ | Seis claves nuevas ES + EN (§4); el HUD de depuración sigue exento |
| P12 Presupuesto móvil | ✅ | Guardado síncrono de un documento pequeño (decenas de KB), uno por fotograma como mucho (peticiones agrupadas); se mide en M2. Nada nuevo por fotograma |
| P13 Test primero | ✅ | Cada requisito tiene test o paso manual (§5.2); los tests nunca tocan guardados reales y no dependen del orden (D10) |
| P14 Alcance | ✅ | Sin menú, selección de mundos, Hardcore ni compras reales; `ItemStack` gana `durability` y `uid` solo porque R-010-23 los guarda (las reglas que los conservan al apilar siguen siendo de la spec 014) |

## 7. Riesgos y alternativas descartadas

- **Orden de carga entre dueños (spec 013).** Las ranuras del inventario se recalculan del nivel de chasis; si el
  nivel se carga después del inventario, las ranuras de más se perderían. Hoy solo hay nivel 1. → Condición de
  entrada de la 013 en README §6: el nivel se aplica antes de que `InventoryComponent` lea sus ranuras.
- **Perfil perdido entero** (D13). → Aceptado en el PMV; la copia de seguridad lo hace muy improbable.
- **Muerte de la app en segundo plano durante un viaje o la transferencia.** La petición queda retenida y el SO
  puede matar la app antes de soltarla: se pierde lo hecho desde el último guardado (como mucho, lo de esa zona).
  → Aceptado: los dos estados duran segundos y guardar uno intermedio rompería R-010-43.
- **Cierre de ventana con una retención atascada** (un reaparecer rechazado deja `REASON_DEATH` puesto). → `Main`
  llama a `SaveFlow.release_death_hold()` también en esa rama, ya informada como bug; el robot sin batería se
  guarda y, al cargar, `BatteryComponent` rechaza una carga ≤ 0 y empieza llena (`push_error`).
- **Escritura segura en Android** depende de que renombrar reemplace (§5.1 punto 3). → Plan B descrito ahí; se
  confirma en M2.
- **Sin `fsync`.** `FileAccess` no garantiza que los datos lleguen al disco antes del renombrado; tras un corte de
  alimentación, el archivo renombrado podría quedar vacío. → La copia de seguridad lo cubre (R-010-48).
- **`durability` y `uid` se pierden al apilar o tirar.** `InventoryRules` crea pilas nuevas y `DroppedItem.to_data()`
  (formato fijado por R-010-29) no los guarda. → Condición de entrada de la spec 014 (README §6, ampliada con el
  objeto caído). Esta spec solo los guarda y los carga en la ranura del inventario.
- **Una señal de hecho con nombre de estado en el futuro.** La convención `*_changed` = estado (D15, D19) se apoya en
  el nombre, pero la regla de R-010-09 se apoya en el significado. → El test de R-010-09 la vigila sea cual sea el
  nombre; la fila de architecture §7 da la convención para las señales nuevas.
- **Principal que se decodifica pero no valida** (revisión al implementar, 2026-11-17). Se carga la copia (R-010-48),
  pero para `LocalSaveStore` ese principal es "válido" (paso 2 de §1: solo mira que sea JSON), así que el primer
  guardado lo rota a copia y la copia buena se pierde hasta el siguiente guardado. → Aceptado: el siguiente guardado
  deja dos copias válidas; validar el documento en el almacén lo acoplaría al esquema.
- **Un aviso tapa a otro** en la etiqueta única del HUD (Perfil y Mundo dañados a la vez: solo se lee el del Mundo).
  → Aceptado hasta el sistema de notificaciones de la Tarea 4.1.
- **Cierre con guardado fallido.** El juego sale igualmente, así que el aviso `ERR_SAVE_FAILED` no llega a verse; los
  archivos anteriores siguen intactos (R-010-45). → Aceptado.
- **Archivo dañado que no se puede apartar** (revisión al implementar). Nunca se escribe encima (R-010-49): el
  Perfil nuevo queda solo en memoria y el Mundo nuevo se juega sin guardar en esa sesión, con `ERR_SAVE_FAILED`.
  Una cabecera cuyo `world_id` no es el del archivo se trata como copia no válida (R-010-18). Los dos con test.
- **D17 sobra en rigor**: las peticiones ya se agrupan al final del fotograma, así que "Fill base" daría un solo
  guardado sin retención. Se mantiene como defensa barata si `fill_base` deja algún día de ser síncrono.
- **Descartado**: guardar con `ResourceSaver` (`.tres` en `user://`), por seguridad (architecture §10.2).
- **Descartado**: un segundo grupo `world_persistent`; un solo grupo y el ámbito por ancestro bastan.
- **Descartado**: guardar en un hilo. El documento es pequeño; si M2 mide un tirón, se reabre.
- **Descartado**: retener también durante el modo colocación; su estado ya es el cancelado (§1).
- **Descartado**: guardar la posición y la vida de los enemigos vivos (pregunta 3, opción B).

### 7.1 Revisión de `architecture-guardian` (2026-11-17)

| Hallazgo | Nivel | Resolución |
|---|---|---|
| La retención de la muerte llega tarde: el autoload oye `player_died` antes que `Main` y guardaría batería 0 | Bloqueante | Peticiones resueltas al final del fotograma y agrupadas (§1); retenciones en `SaveFlow`; test R-010-42 con un solo guardado |
| `push_error` de `save_game` sin Mundo rompería tests existentes (GUT falla con errores no esperados) y el resultado dependería del orden | Bloqueante | `request_save` sin Mundo se ignora sin error; `use_store` reinicia todo; lista completa de tests que cambian (§5.2) |
| Los tests de `main.tscn` tendrían una semilla aleatoria | Bloqueante | `SaveTestSupport.start_world()` con `KNOWN_SEED` (D10) |
| `NoticeScreen` se cierra con el almacén | Importante | `Main` ignora el almacén con el juego bloqueado (D11); caso en R-010-55 |
| Perfil con versión más nueva sin definir | Importante | D16, con su test |
| La copia no queda igual si falla el último paso | Importante | Protocolo reordenado (§1): la copia se rota después de reemplazar el principal; test del fallo en el paso 3 |
| `restore_opened` perdería el contenido (la caja sin abrir tiene 0 ranuras) | Importante | Contrato precisado (§3) |
| `ZoneMemory` no sabe la visita del estado vivo | Importante | `FarmZone.get_visit()` |
| Cargar contadores emite `zone_visit_changed` | Importante | Regla general de señales de estado y de hecho (D15, R-010-09 precisado, architecture §7 y §10.2) con un test que la vigila; `ZoneMemory` comprueba la visita como refuerzo |
| Puntos (verificar) dejados para después de la revisión | Importante | Ejecutados (§5.1); quedan solo los que necesitan dispositivo o ventana, en M1-M3 |
| Retenciones que sobreviven a `Main` | Importante | `SaveFlow._exit_tree` las suelta; `use_store` / `load_game` / `create_world` las reinician |
| Tipos sin parámetro, señales de R-010-09, fila de `SaveManager` en §5, contradicción sobre §10.2, cómo entran los dueños en el grupo, motivo al agrupar, `request_save` sin resultado, conectar `save_notice` antes de cargar, modo en claro y copia, guardia de `Copy.BACKUP`, `begin_world` y la zona actual, R-004-08 / R-008-02 sustituidos, tamaño de `main.gd` | Menores | Todos aplicados en §1, D2, D4, D9, D14, D15, §3 y §5.2 |
| "Fill base" con un guardado por estructura; `DroppedItem` sin `durability`/`uid`; `fsync` | Otros | D17; §7 |
| Repetición de la lectura de pares (`SaveFields`) | Menor | Deduplicada con aprobación del usuario (D18) |
