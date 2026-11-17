# Botín

> Las cajas de botín de una zona se tiran una vez desde una tabla con semilla y guardan el resultado en su propio inventario.
> Specs: [004](../../specs/004-green-zone/spec.md), [005](../../specs/005-inventory/spec.md), [008](../../specs/008-death-recovery/spec.md) · [010](../../specs/010-save-profile-world/spec.md) · Última actualización: spec 010 (caja restaurada abierta)

## Piezas

| Pieza | Tipo | Archivo | Responsabilidad |
|---|---|---|---|
| `LootBox` | Escena (`StaticBody3D`) | `game/scenes/entities/loot_box.gd`, `loot_box.tscn` | Tira el botín una vez, lo guarda en `%Contents`, emite `opened` |
| `LootSystem` | Sistema puro | `game/scripts/systems/loot_system.gd` | `validate()` y `roll()` de una tabla con un RNG recibido |
| `LootTableData` | Resource | `game/scripts/data/loot_table_data.gd` | Lista ordenada de entradas |
| `LootEntryData` | Resource | `game/scripts/data/loot_entry_data.gd` | Ítem y rango de cantidad |
| `ItemData` | Resource | `game/scripts/data/item_data.gd` | Id, clave de nombre, `stack_max`, icono |
| `ItemStack` | Resource | `game/scripts/data/item_stack.gd` | Ítem + cantidad que devuelve la tirada |
| `basic_box.tres` | Recurso | `game/resources/loot/basic_box.tres` | Tabla de la caja básica |
| `zombie_drop.tres` | Recurso | `game/resources/loot/zombie_drop.tres` | Tabla de material de los dos zombis (`EnemyData.drop_table`) |
| `scrap/cables/iron.tres` | Recursos | `game/resources/items/` | Ítems del MVP |

## Cómo funciona

1. `FarmZone._place_box()` instancia la caja y llama `box.setup(loot_seed)` con
   `SeededRng.derive_seed_for_visit(world_seed, zone_id, STREAM_BOX_LOOT, visit, marker_index)` (ver
   [world_zones.md](world_zones.md)). La semilla depende de la visita y del marcador, no del orden de apertura ni del
   número de cajas.
2. El jugador interactúa ([interaction.md](interaction.md)); `Interactable.interacted` llama a `_on_interacted`.
3. Primera vez: `_roll()` crea un `RandomNumberGenerator` con esa semilla y llama `LootSystem.roll(loot_table, rng)`.
   Sin `setup()` previo: `push_error` y no tira.
4. `roll()` valida la tabla (entrada vacía, sin ítem, cantidad negativa, mínimo > máximo). Si es inválida: `push_error`
   con la ruta y devuelve `[]`. Si es válida, hace un `randi_range(min, max)` por entrada, en orden de tabla, y descarta las de 0.
5. La caja cambia de malla (`ClosedMesh` → `OpenedMesh`), fija un hueco por stack en su `InventoryComponent`
   (`set_slot_count`), añade los stacks y emite `loot_generated(stacks, opener)` una sola vez.
6. Tras conectar `inventory_changed` (después de la tirada, para no deshabilitarse vacía), la caja se deshabilita
   (`Interactable.enabled = false`) cuando `%Contents` queda vacío.
7. Cada interacción mientras la caja conserva ítems emite `opened(opener)`; `FarmZone` lo reenvía como `box_opened`
   y `Main` abre la pantalla de botín con `box.get_contents()` (ver [ui.md](ui.md)).
8. Coger ítems mueve stacks de la caja al inventario del jugador: ver [inventory.md](inventory.md).
9. Nueva visita (spec 008): `FarmZone.repopulate` libera cada caja y pone otra cerrada en el mismo marcador con la
   semilla de la visita nueva; lo que quedaba dentro se descarta. Las cajas no se reinician: se sustituyen.

### Material de los zombis (spec 008)

`Zombie._drop_loot()` tira `EnemyData.drop_table` (`null` = nada) con `LootSystem.roll` y un RNG sembrado con
`drop_seed`, solo si lo mató un jugador. Si sale algo, emite `loot_dropped(stacks, posición)`, que sube por
`ZombieSpawner` y `FarmZone` hasta `Main`, que lo convierte en un `DroppedItem` ([death.md](death.md)). La semilla sale
del flujo `enemy_drop` con visita e índice de aparición, así que no depende del orden de las muertes
([enemies.md](enemies.md)).

## Datos

| Recurso | Clase | Valores en BALANCE |
|---|---|---|
| `resources/loot/basic_box.tres` | `LootTableData` | [§2.1](../../BALANCE.md) |
| `resources/loot/zombie_drop.tres` | `LootTableData` | [§3.1](../../BALANCE.md), regla de rangos de §2.1 |
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
| Un hueco por stack tirado | Ninguna entrada tira más de lo que cabe en un hueco | comentario de `_fill_contents` |
| El contenido depende de la visita; número y posición de cajas, no | Cada muerte repone botín nuevo sin mover las cajas | R-008-08, R-008-09 |
| Una tabla (`zombie_drop`) compartida por los dos zombis | Sin duplicar datos | [plan 008 §1](../../specs/008-death-recovery/plan.md) |
| El drop del zombi sube por tres señales locales, no por `EventBus` | No abrir la lista cerrada para algo que solo interesa a quien carga la zona | [plan 008 §7](../../specs/008-death-recovery/plan.md) |

## Relación con otros sistemas

- Usa [interaction.md](interaction.md), [world_zones.md](world_zones.md) (semilla y colocación), [inventory.md](inventory.md) (`%Contents`, `ItemStack`) y [data_catalog.md](data_catalog.md).
- Lo muestra [ui.md](ui.md) (pantalla de botín). Los zombis reutilizan `LootTableData` ([enemies.md](enemies.md)) y su material cae como `DroppedItem` ([death.md](death.md)).

## Trampas y límites

- Reordenar `entries` o cambiar el orden de llamadas al RNG cambia el botín de mundos guardados.
- Una caja a medio vaciar sigue abierta (`opened` se emite de nuevo); solo se deshabilita cuando está vacía.
- El estado de una caja abierta (`LootBox.get_save_state`, `restore_opened`) lo guarda `ZoneMemory` solo durante la visita en curso; al repoblar se pierde. Restaurar no tira ni emite `loot_generated` ni `opened` ([world_zones.md](world_zones.md), [save.md](save.md)).
- Hay dos tablas (`basic_box`, `zombie_drop`); sus ítems deben estar en el catálogo (R-004-22).
- El contenido de las cajas de la visita 0 cambió respecto a la spec 004 por la derivación con visita.
- `ItemData.icon` es obligatorio (lo comprueba el test del catálogo, R-005-31).

## Cómo extenderlo

- Ítem nuevo: `.tres` de `ItemData` (BALANCE §2 primero), icono, claves ES/EN, y registrarlo en el catálogo.
- Tabla nueva: `LootTableData` con sus `LootEntryData` y añadir los casos al test del catálogo.
- Otro tipo de caja: nueva escena con otro `loot_table`.

## Tests

| Archivo | Verifica |
|---|---|
| `tests/unit/test_loot_system.gd` | Rango de cantidades, ceros fuera, validación y errores (R-004-23, 26) |
| `tests/unit/test_loot_box.gd` | Tirada única, estado abierto, deshabilitada al vaciarse, prompt ES/EN (R-004-23..25) |
| `tests/unit/test_data_catalog.gd` | Ítems y `basic_box` coinciden con BALANCE; tablas válidas (R-004-18..22, 26) |
| `tests/integration/test_green_zone.gd` | Misma semilla, mismas cajas; contenido distinto por visita; `repopulate` las cierra y descarta lo que quedaba |
| `tests/integration/test_zombie.gd`, `test_zombie_spawner.gd` | Tirada única del zombi, sin atacante o sin tabla no cae nada, semilla independiente del orden de muertes |
