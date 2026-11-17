# Guardado (Perfil, Mundo y tienda)

> `SaveManager` guarda y carga el estado en dos niveles: un Perfil que sobrevive a los mundos y un Mundo por partida.
> Cada dueño de estado serializa solo lo suyo; el guardado no conoce ningún campo. `IStore` es el contrato de la tienda
> (en el PMV, siempre la demo).
> Specs: [010](../../specs/010-save-profile-world/spec.md) · Última actualización: spec 010

## Piezas

| Pieza | Tipo | Archivo | Responsabilidad |
|---|---|---|---|
| `SaveManager` | Autoload (sin `class_name`) | `game/scripts/autoload/save_manager.gd` | Reúne las partes, escribe, carga, reparte, agrupa peticiones y retenciones; cierre y segundo plano |
| `SaveFlow` | Nodo de `Main` | `game/scenes/save/save_flow.gd` | Lado escena: arranca desde el guardado, retiene guardados en viaje y muerte, avisos, "Mundo nuevo" |
| `ISaveStore` | Contrato (`RefCounted`) | `game/scripts/services/i_save_store.gd` | Bytes planos del Perfil y de cada Mundo, con copia; no sabe qué hay dentro |
| `LocalSaveStore` | Servicio | `game/scripts/services/local_save_store.gd` | Archivos bajo `user://saves`: escritura segura, copia, cifrado AES-256 |
| `SaveReadResult` | Dato | `game/scripts/services/save_read_result.gd` | `FOUND` / `MISSING` / `UNREADABLE` + bytes |
| `SaveCodec` | Sistema puro | `game/scripts/systems/save_codec.gd` | Documento ↔ JSON UTF-8 con claves ordenadas |
| `SaveMigrations` | Sistema puro | `game/scripts/systems/save_migrations.gd` | Versión de cada formato y cadena de migraciones |
| `SaveDocuments` | Sistema puro | `game/scripts/systems/save_documents.gd` | Construye, valida y lee los documentos de Perfil y Mundo; define el grupo `persistent` |
| `SaveFields` | Util | `game/scripts/util/save_fields.gd` | Lecturas tipadas de lo que viene de JSON (enteros, `Vector2i`, `Vector3`); único sitio que sabe cómo se escriben |
| `ProfileData` | Dato (`RefCounted`) | `game/scripts/data/profile_data.gd` | Perfil en memoria: `player_uuid`, derechos, listas vacías en el PMV |
| `NoticeScreen` | `UIScreen` | `game/scenes/ui/notice_screen.gd`, `.tscn` | Aviso a pantalla completa que no se puede cerrar |
| `IStore`, `LocalStore` | Contrato y servicio | `game/scripts/services/i_store.gd`, `local_store.gd` | Tienda; `LocalStore` es la demo; la expone `GameManager.get_store()` |
| `MemorySaveStore`, `SaveTestSupport`, `save_test_hook.gd` | Apoyo de tests | `game/tests/support/` | Almacén en memoria, arranque de un Mundo conocido y gancho de GUT |

## Cómo funciona

**Dueños.** Todo nodo con estado guardable está en el grupo `persistent` y ofrece `get_save_key()`,
`to_save_data()` y `from_save_data(data)` (por nombre, no hay interfaz). Hoy: `BatteryComponent`, `InventoryComponent`,
`ExperienceComponent`, `LocationComponent` (bajo el robot); `DroppedItemSpawner`, `BaseStructures`, `ZoneMemory`
(bajo `World`) y `GameManager` (contadores de visita). Cada uno documenta su formato en su página.

**Ámbito.** Si el dueño cuelga de una entidad del grupo `Robot.PLAYER_GROUP`, su parte va en `players[player_uid]`;
si no, en `world`. Dos dueños con la misma clave en un ámbito: `push_error` y el segundo no se guarda.

**Guardar.**
1. Un hecho pide guardar: `EventBus.zone_changed` hacia la base, `player_recharged`, `player_died`,
   `structure_built`, `structure_moved`, o crear el Mundo. Se llama `request_save(reason)`.
2. `request_save` solo anota; se resuelve una vez al final del fotograma, todas las razones en un guardado con la
   primera. Con una retención (`hold_saves`) espera a que se suelte la última.
3. `save_game` construye el documento (`SaveDocuments.build_world`), lo codifica (`SaveCodec`) y llama a
   `write_world`. Si va bien emite `EventBus.game_saved(reason)`; si falla, deja los archivos como estaban, no emite
   y lanza `save_notice(ERR_SAVE_FAILED)`.
4. Cierre de ventana (`NOTIFICATION_WM_CLOSE_REQUEST`) y paso a segundo plano (`NOTIFICATION_APPLICATION_PAUSED`)
   guardan en el acto si nada retiene; con retención, el cierre espera y luego llama a `quit_action`.

**Escritura segura (`LocalSaveStore`).** Escribe `X.tmp` y lo relee; si `X` es válido lo copia a `X.bak.tmp`; renombra
`X.tmp` a `X` y luego `X.bak.tmp` a `X.bak`. Un fallo borra los temporales y deja `X` y `X.bak`. Un archivo dañado se
aparta como `X.damaged.<n>`, nunca se borra. El cifrado vive solo aquí: se mira la cabecera `GDEC` antes de descifrar
y el resto del juego ve bytes planos. El ajuste `cyberscrap/save/plain_json_in_debug` (en `project.godot`) permite
JSON plano solo en builds de depuración (`should_encrypt`).

**Cargar.**
1. `SaveFlow.start` conecta `save_notice` al HUD y llama `load_profile()`: principal, si no copia, si no Perfil nuevo
   escrito al momento. El robot toma el uuid (`Robot.set_player_uid`).
2. `load_game()`: busca el Mundo (`list_world_ids`; si hay varios juega el primero con `push_error`); lee principal y
   copia, decodifica, **migra antes de que nadie lo lea** y valida. Sin Mundo, `create_world(semilla nueva)`.
3. `_apply_world` da la cabecera a `GameManager.begin_world` y entrega cada parte a su dueño por clave. Una clave
   ausente deja al dueño en su estado de partida nueva.
4. `Main._travel_to_start` viaja a la posición guardada (`ZoneLoader.travel_to_position`) o a la base si no hay
   posición o no es usable ([travel.md](travel.md)).

**Daños y versiones.** Ambas copias dañadas: se apartan, se crea Mundo o Perfil nuevo y se avisa
(`MSG_WORLD_DAMAGED`, `MSG_PROFILE_DAMAGED`). Si no se pueden apartar, no se escribe encima y esa sesión juega un
Mundo en memoria sin guardar. Un `schema_version` más nuevo bloquea: `SaveManager` queda `_blocked`, no carga ni
escribe, y `SaveFlow` abre `NoticeScreen` con `MSG_SAVE_NEWER_VERSION`; `Main` congela `World`.

**Señales de estado y de hecho.** Cargar emite las señales de estado de cada dueño (`battery_changed`,
`inventory_changed`, `xp_changed`) pero nunca las de hecho (`battery_depleted`, `enemy_killed`, `structure_built`,
`zone_visit_counted`, `player_died`). Ver [plan 010 §1.1 D15](../../specs/010-save-profile-world/plan.md).

**Retenciones.** `SaveFlow` retiene (`REASON_TRAVEL`) desde `travel_started` hasta `travel_finished` o
`travel_failed`, y (`REASON_DEATH`) desde `player_died` hasta `player_respawned` del robot local. `DebugHud` retiene
mientras "Llenar base" coloca.

**Tienda.** `GameManager.get_store()` devuelve un `LocalStore`: `has_entitlement` es `false`, `purchase` termina con
`ERR_STORE_DEMO` y `restore` con éxito, ambos por señal en diferido.

## Datos

Sin `.tres` ni números de balance. Los formatos (`WORLD_VERSION`, `PROFILE_VERSION`) son versiones de formato, no de
juego. Claves de traducción en `game/i18n/strings.csv`: `ERR_SAVE_FAILED`, `MSG_WORLD_DAMAGED`,
`MSG_PROFILE_DAMAGED`, `MSG_SAVE_NEWER_VERSION`, `MSG_GAME_SAVED`. Ejemplos de archivos por versión en
`game/tests/fixtures/saves/`.

## Decisiones

| Decisión | Por qué | Fuente |
|---|---|---|
| Dos niveles: Perfil y Mundo | El Perfil sobrevive a los mundos | [architecture §10](../../specs/architecture.md), [spec 010](../../specs/010-save-profile-world/spec.md) §3.3-3.4 |
| `SaveManager` no conoce campos; cada dueño serializa lo suyo | Un dueño nuevo es una clave nueva, sin migración | R-010-03, R-010-10 |
| Semilla como texto decimal | JSON da todo número como `float` y pierde precisión en 64 bits | [plan 010 §1.1 D3](../../specs/010-save-profile-world/plan.md) |
| Lecturas por `SaveFields` | Mismo motivo: ya no hay `int` tras JSON | plan 010 D4, D18 |
| Clave de cifrado constante, comprobación de cabecera | Ofuscación contra ediciones casuales, no un secreto | plan 010 D5, spec 010 pregunta 1 |
| JSON plano solo en depuración, por ajuste de proyecto | Poder inspeccionar guardados sin debilitar release | R-010-64, plan 010 D6 |
| Peticiones agrupadas y diferidas | Un guardado coherente, nunca durante una emisión | R-010-43, plan 010 D14 |
| `SaveFlow` aparte de `main.gd` | Saca el arranque desde guardado de `Main` | plan 010 D14 |
| Perfil en memoria dentro de `SaveManager` | Evita cargarlo en cada uso | plan 010 D2 |
| Perfil o Mundo más nuevos bloquean sin sobrescribir | Una versión vieja no debe estropear un guardado nuevo | R-010-55, plan 010 D16 |
| Mundo nuevo: semilla de `Crypto`, nunca el RNG global | Crear no es generar, pero `test_no_global_rng` lo vigila | plan 010 D8 |
| `IStore` por `GameManager.get_store()` | Mismo patrón que el reloj | plan 010 D1 |
| Aviso bloqueante en pantalla que no se cierra | No hay menú principal aún | plan 010 D11, ACTION_PLAN 4.2 |
| "Mundo nuevo" borra y recarga la escena | Sin menús, con `delete_save()` probado | plan 010 D12 |
| Posición guardada como (`zone_id`, local) | Mundo de celdas acotadas | PMV §4.5 gancho 2, R-010-23 |

## Relación con otros sistemas

Cada dueño documenta su formato: [battery.md](battery.md), [inventory.md](inventory.md), [combat.md](combat.md) (XP),
[death.md](death.md) (objetos caídos), [base.md](base.md), [world_zones.md](world_zones.md) (`ZoneMemory`, visitas),
[travel.md](travel.md) (`LocationComponent`, llegada). Avisos y `NoticeScreen`: [ui.md](ui.md). `GameManager` y
`EventBus`: [data_catalog.md](data_catalog.md).

## Trampas y límites

- Solo `SaveManager` usa un `ISaveStore` y solo él llama a `GameManager.begin_world` (lo vigilan tests).
- `from_save_data` nunca emite señales de hecho; si un dueño nuevo las emite al cargar, repetirá efectos.
- Un guardado dentro de un viaje o una muerte espera a la retención; un `release_saves` olvidado lo bloquea para
  siempre (`SaveFlow._exit_tree` suelta las suyas).
- Una migración nueva necesita su archivo de ejemplo en `tests/fixtures/saves/` (R-010-54).
- Con el Perfil perdido entero, el `player_uuid` nuevo no casa con el del Mundo: ver
  [plan 010 D13](../../specs/010-save-profile-world/plan.md).
- El borrado conserva el Perfil; hall of fame, cosméticos y planos están vacíos en el PMV.
- Sin menú, sin varios mundos y sin nombre de Mundo (queda vacío). Compra real: v1.1.
- Todos los guardados son silenciosos salvo el de la estación de carga ([ui.md](ui.md)).

## Cómo extenderlo

Estado nuevo: añadir el nodo al grupo `persistent` y los tres métodos con una `SAVE_KEY` única; usar `SaveFields` al
leer; no emitir señales de hecho. Cambiar la forma de una clave existente: subir la versión en `SaveMigrations`, añadir
el paso `migrate_vN_to_vN1` y su fixture. Un disparador nuevo: señal de hecho en `EventBus` y conexión a
`request_save` en `SaveManager._ready`. Otro destino de guardado: nueva subclase de `ISaveStore` y `use_store`.

## Tests

| Archivo | Verifica |
|---|---|
| `tests/unit/test_save_codec.gd`, `test_save_fields.gd`, `test_save_documents.gd`, `test_save_migrations.gd` | JSON exacto, lecturas tipadas, documentos, cadena de migración |
| `tests/unit/test_i_save_store.gd`, `test_local_save_store.gd` | Contrato, escritura segura, copia, apartado, cifrado y JSON plano |
| `tests/unit/test_save_manager.gd` | Perfil, Mundo, copias, bloqueo, peticiones, retenciones, cierre |
| `tests/unit/test_i_store.gd`, `test_local_store.gd`, `test_no_network.gd` | Tienda demo, señales diferidas, sin red |
| `tests/unit/test_notice_screen.gd`, `test_location_component.gd`, `test_item_stack.gd` | Aviso, ubicación, durabilidad y uid |
| `tests/integration/test_save_contract.gd` | Todo dueño cumple el contrato y no repite claves |
| `tests/integration/test_save_load.gd`, `test_save_triggers.gd`, `test_zone_memory.gd` | Bucle completo, disparadores y retenciones, memoria de zonas |
| `tests/integration/test_save_fixtures.gd` | Archivos de ejemplo por versión |
