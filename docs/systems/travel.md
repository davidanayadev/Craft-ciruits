# Viaje entre zonas

> `ZoneLoader` mantiene exactamente una zona cargada en `ZoneSlot`, viaja entre zonas con una pantalla de carga y
> hace que el estado del mundo (objetos caídos, estructuras, contador de visitas) sobreviva a cada descarga.
> Specs: [009](../../specs/009-base-placement-charging/spec.md) · Última actualización: spec 009

## Piezas

| Pieza | Tipo | Archivo | Responsabilidad |
|---|---|---|---|
| `ZoneLoader` | Nodo de `Main` (fuera de `World`) | `game/scenes/zones/zone_loader.gd` | Carga en segundo plano, descarga, puebla, coloca a los robots y emite las señales del viaje |
| `Zone` | Clase base (`Node3D`) | `game/scenes/zones/zone.gd` | Contrato común: `data`, `get_spawn_position()`, `exit_requested`; exige `%SpawnPoint` y `%ExitPoint` |
| `ExitPoint` | Escena | `game/scenes/zones/exit_point.gd`, `.tscn` | `InteractableComponent` con `PROMPT_TRAVEL`; el destino es un `ZoneData` exportado en cada instancia |
| `ZoneData` | Resource | `game/scripts/data/zone_data.gd` | `kind` (`BASE`/`FARM`), `scene_path`, `counts_visits()` |
| `LoadingScreen` | `Control` | `game/scenes/ui/loading_screen.gd`, `.tscn` | Cubre el juego durante el viaje; fuera de `UIManager` |
| `Main` | Escena | `game/scenes/main.gd` | Muestra la pantalla, congela `World` y bloquea la entrada mientras dura el viaje |
| `GameManager` | Autoload | `game/scripts/autoload/game_manager.gd` | Zona actual (`set_current_zone`, `get_current_zone_id`, `has_current_zone`) |
| `EventBus.zone_changed` | Señal | `game/scripts/autoload/event_bus.gd` | Una vez por viaje terminado, también el de arranque |

## Cómo funciona

1. **Disparo.** Interactuar con el `ExitPoint` emite `travel_requested`; la `Zone` lo reenvía como `exit_requested`;
   `ZoneLoader` lo recibe en `_on_exit_requested` y llama a `_start_travel(destino, por_salida = true)`. `Main`
   llama a `travel_to` en el arranque y al reaparecer. Nadie más debe llamarlo (lo vigila un test).
2. **Validación.** Viaje en curso, `zone_id` desconocido o petición de carga rechazada: `push_error` y
   `ERR_INVALID_REQUEST`, sin cambios. No se emite `travel_started`.
3. **Inicio.** `ResourceLoader.load_threaded_request(scene_path)`, `travel_started` y `set_process` en diferido.
   `Main._on_travel_started` cierra las pantallas, bloquea la entrada (`REASON_TRAVEL`), suelta el joystick y el
   botón de atacar, llama a `CombatFeedback.release_all()`, muestra `LoadingScreen` y congela `World` en diferido.
4. **Sondeo.** `ZoneLoader._process` (activo solo durante el viaje) lee el estado de la carga. Fallo: `push_error`,
   `travel_failed`, la zona actual queda intacta y `Main` descongela.
5. **Comprobación.** `_instantiate` exige que la raíz sea la `Zone` de ese mismo `ZoneData` y de la clase de su
   `kind` (`FarmZone` con `FARM`, `BaseZone` con `BASE`); si no, es un fallo como el anterior.
6. **Descarga.** `_unload_current`: `FarmZone.despawn_enemies()`, `DroppedItemSpawner.unbind_zone()` (guarda y
   devuelve al pool), `BaseStructures.unbind_base()` si era la base, `remove_child` + `queue_free`. Solo entonces,
   si el viaje es una salida y la zona `counts_visits()`, sube su contador de visitas.
7. **Carga.** `_load`: añade la zona a `ZoneSlot`, `GameManager.set_current_zone`, puebla una `FarmZone`
   (precalienta `ZombiePool`, `ImpactPool` y `DroppedItemPool`; `generate` y `spawn_enemies` con la visita actual) o
   enlaza la base con `BaseStructures.bind_base`, y `DroppedItemSpawner.bind_zone` restaura y caduca los objetos de
   esa zona. Conecta `exit_requested`.
8. **Fin.** `_finish`: cada `Robot` de `Players` va a `place_at(spawn)` quieto, `zone_loaded`, `zone_changed` en el
   bus y `travel_finished`. `Main` oculta la pantalla y quita el bloqueo y el congelado de `REASON_TRAVEL`.

`travel_to` hacia la zona ya cargada la recarga (descarga y vuelve a cargar): es el camino de la muerte dentro de la
base ([death.md](death.md)).

### Reposición
`ZoneLoader` escucha `GameManager.zone_visit_changed`; si la zona cuyo contador sube es la `FarmZone` cargada y no
hay viaje, la repuebla en diferido (muerte en la zona, [world_zones.md](world_zones.md)). Al salir, el contador sube
cuando la zona ya no está cargada, así que no hay nada que repoblar; la siguiente carga trae la visita nueva.

### Congelado de `World`
`Main` lleva un diccionario de motivos (`DEATH`, `TRAVEL`, los mismos nombres que `PlayerInput`): `World` se
desactiva con `process_mode` mientras haya alguno, sin pausar el árbol. Una muerte y un viaje no se pisan.

## Datos

`green_zone.tres` y `base.tres` (`ZoneData`, en `resources/zones/`) llevan `kind` y `scene_path` (ruta `res://`, no un
`PackedScene`); ambas están en `data_catalog.tres`. Tamaño y cajas: [BALANCE §7.1](../../BALANCE.md) y §5.6; viajar no
cuesta batería ni tiene límite: [BALANCE §1.2](../../BALANCE.md). La pantalla de carga no tiene duración mínima.

## Decisiones

| Decisión | Por qué | Fuente |
|---|---|---|
| `scene_path` y no `PackedScene` en `ZoneData` | Evita un ciclo de recursos con `Zone.data` y cargar todas las zonas al arrancar | [plan 009 §1](../../specs/009-base-placement-charging/plan.md) "Zonas como datos" |
| Clase base `Zone` | El cargador necesita un tipo común; es un contrato con dos implementaciones | plan 009 §1 y §6 (P14 a) |
| El destino del `ExitPoint` es un `ZoneData` | El `zone_id` vive solo en su `ZoneData` | plan 009 §1 "Salir por un punto de salida" |
| El contador sube al descargar la zona de origen | Un fallo de carga no deja el contador en N+1 | [plan 009 §7.1](../../specs/009-base-placement-charging/plan.md) |
| Solo las zonas `FARM` cuentan visitas (`counts_visits()`) | Una sola regla para la salida y la muerte | plan 009 §1 (pregunta 12) |
| Carga asíncrona y sondeo solo durante el viaje | architecture pide carga en segundo plano; sin `_process` en juego | plan 009 §7, [architecture §6](../../specs/architecture.md) |
| `LoadingScreen` fuera de `UIManager` | Escape y atrás no deben cerrarla (como `TransferScreen`) | plan 009 §3 |
| `release_all()` lo llama `Main`, no `ZoneLoader` | Las chispas cuelgan de `World` y el cargador no conoce `CombatFeedback` | plan 009 §5.3 |

## Relación con otros sistemas

Usa [world_zones.md](world_zones.md) (`FarmZone`, `generate`, `repopulate`), [base.md](base.md) (`BaseZone`,
`BaseStructures`), [death.md](death.md) (`DroppedItemSpawner.bind_zone`/`unbind_zone`) y [movement.md](movement.md)
(`REASON_TRAVEL`). Lo usan [death.md](death.md) (reaparición) y `BuildFlow` (`zone_loaded`).

## Trampas y límites

- Una ruta de escena inexistente: la petición devuelve `OK` y el fallo llega en el sondeo, con errores del motor.
- Con una ventana de, como mucho, el resto del paso de física de la salida un zombi aún puede golpear (el congelado
  es en diferido). Si el robot muere en ese mismo paso, la zona de origen suma dos visitas (muerte y salida):
  aceptado en [plan 009 §5.3](../../specs/009-base-placement-charging/plan.md).
- Los objetos caídos guardados de una zona sin cargar no caducan hasta volver a cargarla.
- La resolución de `scene_path` en el APK exportado (`.remap`) no se probó en headless: queda para T-009-17.
- Nada se guarda en disco; la spec 010 guardará al entrar en la base con `zone_changed`.

## Cómo extenderlo

Zona nueva: escena con raíz `Zone` (`%SpawnPoint`, `%ExitPoint` con su `destination`), `ZoneData` con `kind` y
`scene_path`, y añadirlo a `zones` de `data_catalog.tres`. Otro `kind` exige tocar la comprobación de `_instantiate`
y `_load`.

## Tests

| Archivo | Verifica |
|---|---|
| `tests/integration/test_zone_loader.gd` | Una zona en el slot, llegada, enemigos y objetos al pool, fallo de carga, visitas al salir y no al entrar, objetos de vuelta, quién llama a `travel_to` |
| `tests/unit/test_exit_point.gd` | Prompt de viaje y destino exportado |
| `tests/unit/test_loading_screen.gd` | Textos como claves, oculta hasta `show_loading()` |
| `tests/integration/test_main_scene.gd` | Arranque en la base, pantalla de carga y congelado, viajes seguidos sin coste de batería |
| `tests/unit/test_game_manager.gd` | Zona actual, solo la escribe `ZoneLoader` |
