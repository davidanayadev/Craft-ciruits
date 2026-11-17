# Inventario

> Ranuras de ítems por entidad (robot, cajas de loot, más adelante cofres), con reglas de apilado puras y las
> pantallas que las muestran. Es la primera pieza de estado por jugador después de la batería.
> Specs: [005](../../specs/005-inventory/spec.md) · Última actualización: spec 005

## Piezas

| Pieza | Tipo | Archivo | Responsabilidad |
|---|---|---|---|
| `InventoryRules` | Sistema puro (`RefCounted`, estático) | `game/scripts/systems/inventory_rules.gd` | Apila, cuenta y quita sobre un `Array[ItemStack]` recibido por parámetro (`null` = ranura vacía) |
| `InventoryComponent` | Componente (`Node`) | `game/scripts/components/inventory_component.gd` | Dueño y único escritor de las ranuras; valida, delega en las reglas y devuelve resultados |
| `ItemStack` | Dato (`RefCounted`) | `game/scripts/data/item_stack.gd` | `item` + `quantity`; `copy()` no comparte estado |
| `InventoryAddResult` | Dato (hereda de `ActionResult`) | `game/scripts/data/inventory_add_result.gd` | Resultado de añadir/mover: `ok`, `error_key` y `leftovers` |
| `ChassisLevelData` | Recurso | `game/scripts/data/chassis_level_data.gd` | Tabla de XP y ranuras por nivel de chasis |
| `chassis_levels.tres` | `.tres` | `game/resources/progression/chassis_levels.tres` | La tabla real |
| `InventoryGrid` | Presentación | `game/scenes/ui/inventory_grid.gd` | Una celda por ranura de un componente; se repinta con `inventory_changed` |
| `InventorySlotView` | Presentación | `game/scenes/ui/inventory_slot.gd` | Una celda (`Button`): icono y cantidad, o aspecto vacío |
| `InventoryScreen` | Pantalla | `game/scenes/ui/inventory_screen.gd` | Inventario del jugador; solo se ve |
| `LootScreen` | Pantalla | `game/scenes/ui/loot_screen.gd` | Contenido de una caja junto al inventario del jugador, con "coger todo" |

## Cómo funciona

1. `Robot._ready()` llama a `inventory.set_slot_count(chassis_levels.get_inventory_slots(FIRST_LEVEL))`. El
   componente no conoce el chasis: solo sabe crecer (`set_slot_count` rechaza reducir).
2. `add(item_id, quantity)` valida el id contra un `DataCatalog` (el de `DataRegistry` por defecto), guarda el
   `ItemData` del catálogo y llama a `InventoryRules.add`: primero rellena pilas del mismo ítem por debajo de
   `stack_max`, luego ranuras vacías, en orden.
3. Si algo no cabe, devuelve `InventoryAddResult` con `ok == false`, `MSG_INVENTORY_FULL` y los `leftovers`, y
   emite `overflowed(leftovers)`. Lo que sí cabía ya está dentro: un fallo puede haber añadido una parte.
4. `inventory_changed` se emite una sola vez por operación que cambió algo, nunca sin cambio.
5. Mover entre inventarios: `destino.take_from(origen, indices)` copia las pilas, mete lo que cabe y pide a
   `origen.remove_from_slots(amounts)` quitar exactamente eso. Cada componente escribe solo las suyas; el origen
   emite primero y el destino después, con ambos ya escritos.
6. Caja: `LootBox` ([loot.md](loot.md)) guarda su tirada en un `InventoryComponent` hijo y emite `opened(opener)`;
   `FarmZone` lo reemite como `box_opened` y `main.gd` abre `LootScreen` con
   `{source: caja, inventory: del que abre}` ([ui.md](ui.md)).
7. En `LootScreen`, tocar una celda de la caja llama a `player.take_from(box, [i])`; "coger todo" pasa todas las
   ranuras ocupadas en orden. La pantalla pide cerrarse (`close_requested`) cuando la caja queda vacía.
8. `InventoryScreen` se abre con el botón de almacenamiento o Tab (`open_storage`); sus celdas no se pulsan.
9. `InventoryGrid.bind()` pinta el estado inicial y se repinta solo con `inventory_changed` (nunca por
   `_process`). Solo la rejilla de la caja tiene `interactive = true`.

## Datos

| Recurso | Clase | Valores desde |
|---|---|---|
| `resources/progression/chassis_levels.tres` | `ChassisLevelData` | [BALANCE.md §6.1](../../BALANCE.md) (XP y ranuras por nivel) |
| `resources/items/*.tres` (`stack_max`, `icon`) | `ItemData` | BALANCE.md §2; iconos SVG de marcador en `assets/textures/icons/items/` (ver [data_catalog.md](data_catalog.md)) |
| `resources/ui/screens.tres` | `UIScreenCatalog` | No es balance; ver [ui.md](ui.md) |

Las ranuras de una caja no salen de ninguna tabla: son tantas como pilas dio la tirada.

## Decisiones

| Decisión | Por qué | Fuente |
|---|---|---|
| Reglas de apilado en un sistema puro estático | Testeable sin `Node` ni autoload | R-005-01, [architecture §3, §9.3](../../specs/architecture.md) |
| Inventario por entidad, ningún autoload lo guarda | Co-op y estado por jugador | R-005-10, Constitución P4 |
| El componente no lee `ChassisLevelData`; solo `set_slot_count` | Si no, no serviría para cajas y cofres | [plan 005 §7](../../specs/005-inventory/plan.md) |
| `InventoryAddResult` hereda de `ActionResult` | Quien mira solo `ok`/`error_key` no nota la diferencia; añadir parcial exige `leftovers` | [plan 005 §1, §6](../../specs/005-inventory/plan.md) |
| `take_from` vive en el componente que recibe | Un escritor por inventario; los sistemas no conocen nodos | R-005-15, plan 005 §7 |
| `add`/`take_from` guardan copias de las pilas | Nadie puede cambiar las ranuras a través de una pila que pasó | Docstring de `InventoryComponent` |
| Ítems por `item_id` | Decisión de la pregunta 3 de la spec | R-005-05, [spec 005 §6](../../specs/005-inventory/spec.md) |
| La caja se desactiva al vaciarse, no al abrirse | Sustituye a R-004-24; coger es manual | R-005-21 |
| Iconos SVG propios de marcador | Elegir pack de Kenney es decisión del usuario | R-005-32, plan 005 §1 |

## Relación con otros sistemas

- Usa: [data_catalog.md](data_catalog.md) (`DataCatalog`, `ItemData`).
- Lo usan: [loot.md](loot.md) (el contenido de cada caja), [ui.md](ui.md) (pantallas y HUD, que escucha
  `overflowed` para mostrar `MSG_INVENTORY_FULL` durante 3 s), [interaction.md](interaction.md) (el robot abre la
  caja con su `InteractorComponent`).
- Todavía no lo usan: crafteo, cofres, muerte y guardado (specs posteriores).

## Trampas y límites

- `ok == false` no implica "no cambió nada": un añadido parcial deja las ranuras modificadas. Mira `leftovers`.
- `get_slots()` devuelve copias; para cambiar el inventario hay que llamar a los métodos del componente.
- `count()` de un id desconocido hace `push_error` y devuelve 0.
- `set_slot_count` no reduce (error y `ERR_INVALID_REQUEST`).
- No hay depositar, coger parte de una pila, arrastrar, ordenar, tirar, cofres, guardado ni subida de nivel
  ([spec 005 §4](../../specs/005-inventory/spec.md)). Lo que queda en una caja se pierde al reiniciar.
- `ChassisLevelData.xp_required` existe pero nadie lo lee todavía (ACTION_PLAN 2.7).
- Los controles de las pantallas tienen `focus_mode = NONE` para que Tab siga llegando a `open_storage`.

## Cómo extenderlo

- Nuevo ítem: `.tres` de `ItemData` con su icono; ver [data_catalog.md](data_catalog.md).
- Subida de nivel de chasis: llamar a `inventory.set_slot_count(chassis_levels.get_inventory_slots(nivel))`.
- Cofre: otro `InventoryComponent` y una pantalla que use `InventoryGrid` y `take_from` en ambos sentidos.

## Tests

| Archivo | Verifica |
|---|---|
| `tests/unit/test_inventory_rules.gd` | Apilado, orden de relleno, `count`, `remove` de atrás hacia delante |
| `tests/unit/test_inventory_component.gd` | Validación, señales una vez por operación, `take_from`, copias, `overflowed` |
| `tests/unit/test_chassis_level_data.gd` | Tabla y `validate()` |
| `tests/unit/test_inventory_screen.gd`, `test_loot_screen.gd` | Celdas, repintado por señal, coger una pila / todo, cierre al vaciarse |
| `tests/integration/test_robot_inventory.gd` | El robot tiene su inventario con las ranuras del nivel 1 y ningún autoload guarda contenido |
