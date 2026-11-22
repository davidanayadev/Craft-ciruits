# Tareas 010 — Guardado en dos niveles (Perfil y Mundo) e `IStore`

> Orden de ejecución. Cada tarea deja el proyecto compilando y los tests en verde. Marcar `[x]` al terminar.
> Requisito previo: las specs 007, 008 y 009 en estado *Hecho* y fusionadas; rama `feat/010-save-profile-world`
> desde `main`.

- [x] **T-010-01** Comprobar los puntos **(verificar)** de plan §5.1 en la referencia de clases de Godot 4.7.2
  (`--doctool`) y con un script en headless fuera del repo. Hecho al planificar (2026-11-17), como pedían las
  preguntas 1 y 2 de la spec; los que necesitan ventana o dispositivo (renombrado en Android, entrega de las
  notificaciones, `reload_current_scene`) quedan en M1-M3 (T-010-10). Cubre: — (prerrequisito de R-010-40, 41,
  47, 56, 64, 65 y de D3-D6). Verifica: plan §5.1 escrito.
- [x] **T-010-02** Test primero: `test_save_fields.gd`, `test_save_codec.gd`, `test_save_migrations.gd` y
  `test_save_documents.gd`. Después, `SaveFields`, `SaveCodec`, `SaveMigrations`, `ProfileData` y `SaveDocuments`.
  Con `SaveFields` en verde, deduplicar (D18): `BuildGrid._to_pair()` → `SaveFields.to_vector2i()`,
  `DroppedItemSpawner._restore()` y `DroppedItem.to_data()` con `SaveFields`, sin cambiar los formatos. Cubre:
  R-010-05, R-010-07 (claves repetidas), R-010-12, R-010-16, R-010-17 (cabecera), R-010-22, R-010-52, R-010-53
  (cadena), R-010-60. Verifica: tests sin árbol de escena ni archivos en verde, y `test_build_grid.gd`,
  `test_dropped_item.gd` y `test_dropped_item_spawner.gd` en verde sin cambios.
- [x] **T-010-03** Test primero: `test_i_save_store.gd` y `test_local_save_store.gd` (carpeta temporal
  `user://test_saves/<uid>/`, borrada en `after_each`; errores del motor afirmados con `assert_engine_error`).
  Después, `SaveReadResult`, `ISaveStore` y `LocalSaveStore` (rutas, cabecera `GDEC`, cifrado, modo en claro en
  depuración, escritura segura de plan §1, copia, apartar, borrar, listar mundos) y el ajuste
  `cyberscrap/save/plain_json_in_debug` en `project.godot` con su caso en `test_project_settings.gd`. Cubre:
  R-010-01, R-010-15, R-010-18 (almacén), R-010-45 (almacén), R-010-46, R-010-47, R-010-49 (apartar), R-010-51,
  R-010-56, R-010-57 (almacén), R-010-64. Verifica: tests en verde.
- [x] **T-010-04** Test primero: `test_i_store.gd`, `test_local_store.gd` y `test_no_network.gd`. Después,
  `IStore`, `LocalStore` y `GameManager.get_store()`; clave `ERR_STORE_DEMO` en `strings.csv`. Cubre: R-010-58,
  R-010-59, R-010-61, R-010-60 (la tienda no escribe en el Mundo). Verifica: tests en verde.
- [x] **T-010-05** Test primero: `test_item_stack.gd` (nuevo) y casos 010 de `test_battery_component.gd`,
  `test_inventory_component.gd`, `test_experience_component.gd`, `test_location_component.gd` (nuevo) y
  `test_zone_resources.gd`. Después, `durability` y `uid` en `ItemStack`, el contrato de guardado de los tres
  componentes (solo señales de estado: la batería carga sin `battery_low` ni `battery_depleted`, D15),
  `LocationComponent` y `ZoneData.contains_local_position()`. Cubre: R-010-06 (métodos), R-010-08,
  R-010-09, R-010-10, R-010-11, R-010-23 (componentes), R-010-24, R-010-36 (regla). Verifica: tests en verde.
- [x] **T-010-06** Test primero: casos 010 de `test_game_manager.gd` (sustituyendo los de R-004-08 y R-008-02, D9),
  `test_event_bus.gd`, `test_loot_box.gd`, `test_zombie_spawner.gd`, `test_zone_memory.gd` (nuevo),
  `test_dropped_item_spawner.gd` y `test_base_structures.gd`. Después, `GameManager.begin_world()` (también reinicia
  la zona actual) y su contrato de dueño sin señal (D15), sin mundo de desarrollo; `zone_visit_changed` →
  `zone_visit_counted` en código, tests y `docs/systems/` (D19); `EventBus.structure_moved`;
  `LootBox.get_save_state()` / `restore_opened()`; índices muertos en `ZombieSpawner`; `FarmZone.populate()`,
  `get_visit()` y `get_visit_state()`; `ZoneMemory`; el contrato de `DroppedItemSpawner` y de `BaseStructures` (y
  `structure_moved` al mover). Adaptar `test_green_zone.gd` y `test_death_controller.gd` (D9), borrar
  `DevWorldConfigData` y `dev_world.tres`, marcar R-004-08 y R-008-02 como sustituidos por R-010-20 en sus specs y
  añadir a architecture §7 `structure_moved` y la distinción entre señales de estado y de hecho (D15). Cubre: R-010-09, R-010-11, R-010-20, R-010-21 (sin setter),
  R-010-26, R-010-27, R-010-28, R-010-29, R-010-30, R-010-31, R-010-32. Verifica: suite completa en verde.
- [x] **T-010-07** Test primero: `test_save_manager.gd` con `MemorySaveStore` y `FakeTimeService`; el hook
  `save_test_hook.gd` en `.gutconfig.json` y `SaveTestSupport`. Después, el autoload `SaveManager` (Perfil con
  bloqueo por versión, cargar y crear Mundo, guardar, borrar, copia de seguridad, versión más nueva, `use_store`
  que reinicia todo, peticiones agrupadas al final del fotograma, retenciones, cierre y segundo plano con
  `quit_action`) y su entrada en `project.godot` después de `GameManager`; claves `ERR_SAVE_FAILED`,
  `MSG_WORLD_DAMAGED`, `MSG_PROFILE_DAMAGED` y `MSG_SAVE_NEWER_VERSION`. Actualizar architecture §5 (filas de
  `GameManager` con `IStore` y de `SaveManager` con el Perfil en memoria) y §10.2 (`from_save_data()` emite
  señales de estado y nunca de hecho, con el ejemplo del nivel de chasis: `xp_changed` / `stats_changed` sí,
  `level_up` no; dueños del mundo en `persistent`; semilla como texto; precisión completa). Cubre: R-010-02, R-010-03, R-010-04, R-010-13, R-010-14
  (uuid estable), R-010-17, R-010-18, R-010-40, R-010-41, R-010-43 (reinicio de retenciones), R-010-44
  (agrupar), R-010-45, R-010-48, R-010-49, R-010-50, R-010-53 (antes de los dueños), R-010-55 (almacén intacto),
  R-010-57, R-010-65 (`delete_save`). Verifica: suite completa en verde (los tests que disparan eventos sin `Main`
  no cambian).
- [x] **T-010-08** Test primero: `test_save_contract.gd`, `test_save_load.gd` (incluido
  `test_r_010_09_load_emits_no_fact_signal`) y `test_save_fixtures.gd` con los dos archivos de ejemplo. Después, `Robot.set_player_uid()` / `enter_zone()` y el nodo `Location` en
  `robot.tscn` (componentes persistentes en el grupo `persistent`), `ZoneLoader.travel_to_position()` y
  `ZoneMemory` en `ZoneLoader`, los nodos `ZoneMemory` y `SaveFlow` en `main.tscn` (con sus grupos), y el
  arranque: `SaveFlow.start()` (conecta `save_notice` antes de cargar, Perfil, uuid del robot, Mundo) y `Main`
  poniendo el ruleset después de cargar y viajando a la ubicación guardada o a la base. Poner
  `SaveTestSupport.start_world()` / `reset()` en `test_main_scene.gd`, `test_base_loop.gd`, `test_base_zone.gd` y
  `test_hud_attack_input.gd`. Cubre: R-010-06, R-010-07, R-010-08, R-010-09 (ningún hecho al cargar), R-010-10, R-010-14, R-010-19, R-010-21,
  R-010-22, R-010-23, R-010-24, R-010-25, R-010-26, R-010-33, R-010-34, R-010-35, R-010-36, R-010-37, R-010-54,
  R-010-63 (integración). Verifica: suite completa en verde.
- [x] **T-010-09** Test primero: `test_save_triggers.gd` y los casos 010 de `test_hud.gd` y `test_debug_hud.gd`.
  Después, retenciones de `SaveFlow` (viaje y muerte del jugador local, soltadas en `_exit_tree`) y
  `release_death_hold()` en la rama de reaparecer rechazado de `Main`; `NoticeScreen` en `screens.tres` con el
  bloqueo por versión más nueva (`World` congelado, almacén ignorado); `Hud.show_notice()` (también para
  "inventario lleno") y "Partida guardada" al recargar; semilla, "New world" y retención durante "Fill base" en el
  HUD de depuración, con "New world" manejado por `SaveFlow` (D12); clave `MSG_GAME_SAVED`. Cubre: R-010-38,
  R-010-39, R-010-42, R-010-43, R-010-44, R-010-45 (aviso), R-010-49 (aviso), R-010-55 (pantalla), R-010-62,
  R-010-65. Verifica: suite completa en verde.
- [x] **T-010-10** Pasos manuales M1, M3 y M4 en PC y M2 en el Android de gama media (APK debug), incluidos los
  puntos ⏳ de plan §5.1. Anotar el resultado en un §5.4 del plan, con las desviaciones de implementación si las
  hay. Cubre: R-010-40, R-010-41, R-010-47 (Android), R-010-63, R-010-65 y la parte manual de R-010-48, 49, 56.
  Verifica: §5.4 escrito.

## Cierre

- [x] Definición de hecho (constitución §4) revisada: `godot-runner`, `i18n-auditor` y `balance-auditor` en
  paralelo, después `architecture-guardian` una vez.
- [x] `system-documenter spec 010` (página nueva de guardado en `docs/systems/` y las que cambian: inventario,
  zonas, base, objetos caídos).
- [x] Condiciones de entrada en `specs/README.md §6`: spec 014 (el nivel de chasis se aplica antes de que el
  inventario lea sus ranuras) y spec 015 (ampliada: `DroppedItem.to_data()` también conserva `durability` y `uid`),
  plan §7.
- [x] Estado del spec actualizado en `spec.md` y en `specs/README.md §6`.
