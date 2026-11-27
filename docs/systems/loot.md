# Botín

> Las cajas de botín de una zona se tiran una vez desde una tabla con semilla y guardan el resultado en su propio inventario.
> Specs: [004](../../specs/004-green-zone/spec.md), [005](../../specs/005-inventory/spec.md), [008](../../specs/008-death-recovery/spec.md) · [010](../../specs/010-save-profile-world/spec.md) · [012](../../specs/012-wind-generator-chests/spec.md) · [013](../../specs/013-loot-box-sites-container-ui/spec.md) · [016](../../specs/016-hostile-robot/spec.md) · Última actualización: spec 016 (drop de pieza del robot hostil)

## Piezas

| Pieza | Tipo | Archivo | Responsabilidad |
|---|---|---|---|
| `LootBox` | Escena (`StaticBody3D`) | `game/scenes/entities/loot_box.gd`, `loot_box.tscn` | Tira el botín una vez, lo guarda en `%Contents` (con la capacidad de un cofre) y emite `opened` en cada interacción; nunca se desactiva |
| `LootSystem` | Sistema puro | `game/scripts/systems/loot_system.gd` | `validate()` y `roll()` de una tabla con un RNG recibido; desde la 016 `validate_piece_drop()`, `roll_piece()` y `roll_enemy_drop()` |
| `PieceDropData` | Resource | `game/scripts/data/piece_drop_data.gd` | Probabilidad, piezas posibles y durabilidad con que sale la pieza de un enemigo (`EnemyData.piece_drop`) |
| `hostile_robot_drop.tres`, `hostile_robot_piece_drop.tres` | Recursos | `game/resources/loot/`, `game/resources/piece_drops/` | Materiales y pieza del robot hostil (carpeta propia: `resources/loot/` solo guarda `LootTableData`) |
| `LootTableData` | Resource | `game/scripts/data/loot_table_data.gd` | Lista ordenada de entradas |
| `LootEntryData` | Resource | `game/scripts/data/loot_entry_data.gd` | Ítem y rango de cantidad |
| `ItemData` | Resource | `game/scripts/data/item_data.gd` | Id, clave de nombre, `stack_max`, icono |
| `ItemStack` | Resource | `game/scripts/data/item_stack.gd` | Ítem + cantidad que devuelve la tirada |
| `basic_box.tres` | Recurso | `game/resources/loot/basic_box.tres` | Tabla de la caja básica |
| `zombie_drop.tres` | Recurso | `game/resources/loot/zombie_drop.tres` | Tabla de material de los dos zombis (`EnemyData.drop_table`) |
| `scrap/cables/iron.tres`, `portable_battery.tres` | Recursos | `game/resources/items/` | Ítems del MVP (la batería portátil no está en ninguna tabla, BALANCE §2.1) |
| `container.tres` | Recurso | `game/resources/config/container.tres` | Capacidad; `LootBox.container_config` y el cofre leen el mismo recurso |

## Cómo funciona

1. `FarmZone._place_box()` instancia la caja y llama `box.setup(loot_seed)` con
   `SeededRng.derive_seed_for_visit(world_seed, zone_id, STREAM_BOX_LOOT, visit, marker_index)` (ver
   [world_zones.md](world_zones.md), que explica cómo se eligen los marcadores por sitios). `marker_index` es el
   índice plano (sitios, luego marcadores, en orden de escena). La semilla depende de la visita y del marcador, no
   del orden de apertura ni del número de cajas.
2. El jugador interactúa ([interaction.md](interaction.md)); `Interactable.interacted` llama a `_on_interacted`.
3. Primera vez: `_roll()` crea un `RandomNumberGenerator` con esa semilla y llama `LootSystem.roll(loot_table, rng)`.
   Sin `setup()` previo: `push_error` y no tira.
4. `roll()` valida la tabla (entrada vacía, sin ítem, cantidad negativa, mínimo > máximo). Si es inválida: `push_error`
   con la ruta y devuelve `[]`. Si es válida, hace un `randi_range(min, max)` por entrada, en orden de tabla, y descarta las de 0.
5. La caja cambia de malla (`ClosedMesh` → `OpenedMesh`), fija en su `InventoryComponent` la capacidad de
   `container_config` (`set_slot_count`), añade los stacks y emite `loot_generated(stacks, opener)` una sola vez.
6. Desde la spec 012 la caja abierta es un contenedor: **no se deshabilita nunca**, tampoco vacía.
7. Cada interacción, también la primera y también con la caja vacía, emite `opened(opener)`; `FarmZone` lo reenvía como
   `box_opened` y `Main` abre `ContainerScreen` con `box.get_contents()` (ver [ui.md](ui.md)).
8. Coger y dejar ítems mueve pilas entre la caja y el inventario del jugador: ver [inventory.md](inventory.md). Lo dejado se
   queda en la caja el resto de la visita, también tras guardar y cargar, y se pierde con la visita siguiente.
9. Nueva visita (spec 008, 013): `FarmZone.repopulate` libera cada caja y coloca otras cerradas en los marcadores que
   elige la visita nueva (no necesariamente los mismos), con la semilla de esa visita; lo que quedaba dentro se
   descarta. Las cajas no se reinician: se sustituyen.

### Material de los zombis (spec 008)

`Enemy._drop_loot()` llama a `LootSystem.roll_enemy_drop(drop_table, piece_drop, rng)` con un RNG sembrado con
`drop_seed`, solo si lo mató un jugador. Si sale algo, emite `loot_dropped(stacks, posición)`, que sube por
`EnemySpawner` y `FarmZone` hasta `Main`, que lo convierte en un `DroppedItem` ([death.md](death.md)). La semilla sale
del flujo de drop de su población (`enemy_drop` o `hostile_robot_drop`) con visita e índice de aparición, así que no
depende del orden de las muertes ([enemies.md](enemies.md)).

### Pieza del robot hostil (spec 016)

1. `roll_enemy_drop` tira la tabla (`roll`, si hay) y después `roll_piece` (si hay `piece_drop`) **con el mismo RNG**;
   la pieza va al final de la lista. Sin `piece_drop` hace exactamente las llamadas de `roll`, así que el drop de un
   zombie no cambia.
2. `roll_piece` valida el `PieceDropData` (`validate_piece_drop`; inválido: `push_error` y `null`, sin tocar el RNG).
   Hace un `randi_range(1, CraftingSystem.PERCENT)` contra `chance_percent`; si cae, otro `randi_range` elige la pieza.
   Sin pieza, `null` y no hay segunda llamada. Ese orden de llamadas es un contrato con los mundos guardados.
3. La pieza es `CraftingSystem.create_result(pieza)` (unidad única con `uid` nuevo, nunca `ItemStack.new`) con la
   durabilidad `durability_percent` de su máximo, con división entera y mínimo 1 (una pieza a 0 no es válida).
4. Materiales y pieza salen en **una** señal y caen en **un** `DroppedItem`, que se abre en `ContainerScreen`
   ([death.md](death.md), [equipment.md](equipment.md)).

## Datos

| Recurso | Clase | Valores en BALANCE |
|---|---|---|
| `resources/loot/basic_box.tres` | `LootTableData` | [§2.1](../../BALANCE.md) |
| `resources/loot/zombie_drop.tres` | `LootTableData` | [§3.1](../../BALANCE.md), regla de rangos de §2.1 |
| `resources/loot/hostile_robot_drop.tres` | `LootTableData` | §2.1 (fila "Robot hostil básico"), §3.2 |
| `resources/piece_drops/hostile_robot_piece_drop.tres` | `PieceDropData` | §3.2 |
| `resources/items/*.tres` | `ItemData` | [§2](../../BALANCE.md) (`stack_max`) |
| `PROMPT_OPEN`, `ITEM_*` | claves en `game/i18n/strings.csv` | ES + EN |

Los ítems y las tablas se registran en el catálogo ([data_catalog.md](data_catalog.md)).

## Decisiones

| Decisión | Por qué | Fuente |
|---|---|---|
| La tirada es pura: tabla y RNG por parámetro | Testeable y reproducible desde la semilla | [plan 004](../../specs/004-green-zone/plan.md), R-004-23 |
| El orden de entradas y de llamadas al RNG es un contrato | Una semilla guardada debe dar siempre el mismo botín | comentarios de `loot_system.gd` y `loot_table_data.gd` |
| La caja guarda su botín en su propio `InventoryComponent` | Permite coger por partes y reabrir | R-005-17, [spec 005](../../specs/005-inventory/spec.md) |
| La caja no conoce el inventario del jugador ni la UI | Una responsabilidad por escena | comentario de `loot_box.gd` |
| La capacidad de la caja es la de un cofre (un recurso) | Se puede dejar algo en ella; sustituye al hueco por stack | R-012-06, R-012-37 |
| La caja nunca se desactiva | Es un contenedor durante la visita; sustituye a R-005-16, R-005-18 y R-005-21 | R-012-37, [BALANCE §7.2](../../BALANCE.md) |
| Contenido, número y marcadores de las cajas dependen de la visita | Cada visita cambia el recorrido y el botín; sustituye "sin mover las cajas" de R-008-09 | R-013-01, R-013-07, R-008-08 |
| Una tabla (`zombie_drop`) compartida por los dos zombis | Sin duplicar datos | [plan 008 §1](../../specs/008-death-recovery/plan.md) |
| El drop del zombi sube por tres señales locales, no por `EventBus` | No abrir la lista cerrada para algo que solo interesa a quien carga la zona | [plan 008 §7](../../specs/008-death-recovery/plan.md) |
| La pieza es un recurso propio (`PieceDropData`) y la tirada es pura en `LootSystem` | Datos más una tirada testeable; mismo RNG que la tabla | [plan 016 D10, D11](../../specs/016-hostile-robot/plan.md) |
| Porcentajes enteros en la escala de `CraftingSystem.PERCENT` | Exactos, sin depender de `randf` ni de redondeos de `float` | plan 016 D10, §7 |
| Un solo objeto caído por muerte, sin escena `DroppedPiece` | Reutiliza el camino de los zombies | plan 016 §7 (pregunta 5 de la spec) |

## Relación con otros sistemas

- Usa [interaction.md](interaction.md), [world_zones.md](world_zones.md) (semilla y colocación), [inventory.md](inventory.md) (`%Contents`, `ItemStack`) y [data_catalog.md](data_catalog.md).
- Lo muestra [ui.md](ui.md) (`ContainerScreen`). Los enemigos reutilizan `LootTableData` y `PieceDropData` ([enemies.md](enemies.md)) y su botín cae como `DroppedItem` ([death.md](death.md)); la pieza usa `CraftingSystem.create_result` ([crafting.md](crafting.md)).

## Trampas y límites

- Reordenar `entries` o cambiar el orden de llamadas al RNG cambia el botín de mundos guardados.
- Una caja abierta emite `opened` en cada interacción y no se deshabilita. Lo que se deja dentro no se guarda al cerrar la pantalla: va con el siguiente guardado normal (R-012-44).
- El estado de una caja abierta (`LootBox.get_save_state`, `restore_opened`) lo guarda `ZoneMemory` solo durante la visita en curso; al repoblar se pierde. Restaurar no tira ni emite `loot_generated` ni `opened`, y da a la caja la capacidad de un cofre (una lista guardada más larga pierde lo de más con `push_error`) ([world_zones.md](world_zones.md), [save.md](save.md)).
- Hay tres tablas (`basic_box`, `zombie_drop`, `hostile_robot_drop`); sus ítems deben estar en el catálogo (R-004-22).
- El orden de `PieceDropData.pieces` y el de llamadas de `roll_enemy_drop` (tabla, luego pieza) cambian el drop de robots vivos de una visita guardada.
- El `uid` de la pieza es aleatorio (identidad, no juego): "misma semilla, mismo drop" compara id, cantidad y durabilidad.
- El contenido de las cajas de la visita 0 cambió respecto a la spec 004 por la derivación con visita.
- `ItemData.icon` es obligatorio (lo comprueba el test del catálogo, R-005-31).

## Cómo extenderlo

- Ítem nuevo: `.tres` de `ItemData` (BALANCE §2 primero), icono, claves ES/EN, y registrarlo en el catálogo.
- Tabla nueva: `LootTableData` con sus `LootEntryData` y añadir los casos al test del catálogo.
- Otro tipo de caja: nueva escena con otro `loot_table`.

## Tests

| Archivo | Verifica |
|---|---|
| `tests/unit/test_loot_system.gd` | Rango de cantidades, ceros fuera, validación y errores (R-004-23, 26); probabilidad y reparto de la pieza, pieza única y dañada, misma semilla mismo drop, secuencia del zombie intacta (R-016-14..17) |
| `tests/unit/test_loot_box.gd` | Tirada única, estado abierto, capacidad de cofre, nunca deshabilitada, restaurada con capacidad, prompt ES/EN (R-004-23..25, R-012-37) |
| `tests/unit/test_data_catalog.gd` | Ítems y `basic_box` coinciden con BALANCE; tablas válidas (R-004-18..22, 26) |
| `tests/integration/test_green_zone.gd` | Misma semilla y visita, mismas cajas; contenido y marcadores distintos por visita; `repopulate` las cierra, las recoloca y descarta lo que quedaba |
| `tests/integration/test_enemy.gd`, `test_enemy_spawner.gd`, `test_hostile_robot.gd` | Tirada única, sin atacante o sin tabla no cae nada, semilla independiente del orden de muertes, una señal con todos los stacks |
