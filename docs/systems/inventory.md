# Inventario

> Ranuras de ítems por entidad (robot, cajas de loot, cofres), con reglas de apilado puras y las
> pantallas que las muestran. Es la primera pieza de estado por jugador después de la batería.
> Specs: [005](../../specs/005-inventory/spec.md), [008](../../specs/008-death-recovery/spec.md), [009](../../specs/009-base-placement-charging/spec.md), [010](../../specs/010-save-profile-world/spec.md), [011](../../specs/011-crafting-repair/spec.md), [012](../../specs/012-wind-generator-chests/spec.md) · Última actualización: spec 012 (mover entre ranuras y contenedores)

## Piezas

| Pieza | Tipo | Archivo | Responsabilidad |
|---|---|---|---|
| `InventoryRules` | Sistema puro (`RefCounted`, estático) | `game/scripts/systems/inventory_rules.gd` | Apila, cuenta y quita sobre un `Array[ItemStack]` recibido por parámetro (`null` = ranura vacía). Spec 011: `add_stack`, `is_valid_stack`, `index_of_uid`. Spec 012: `can_merge`, `move_to_slot`, `transfer` |
| `InventoryComponent` | Componente (`Node`) | `game/scripts/components/inventory_component.gd` | Dueño y único escritor de las ranuras; valida, delega en las reglas y devuelve resultados. Spec 011: `craft` y `repair` ([crafting.md](crafting.md)). Spec 012: `move_to_slot`, `transfer_to` |
| `ItemStack` | Dato (`RefCounted`) | `game/scripts/data/item_stack.gd` | `item`, `quantity`, `durability` (-1 si no aplica) y `uid` (vacío en pilas normales); `copy()` los conserva y no comparte estado. Una pieza (`PieceData`) siempre lleva ambos |
| `InventoryAddResult` | Dato (hereda de `ActionResult`) | `game/scripts/data/inventory_add_result.gd` | Resultado de añadir/mover: `ok`, `error_key` y `leftovers` |
| `ChassisLevelData` | Recurso | `game/scripts/data/chassis_level_data.gd` | Tabla de XP y ranuras por nivel de chasis |
| `chassis_levels.tres` | `.tres` | `game/resources/progression/chassis_levels.tres` | La tabla real |
| `InventoryGrid` | Presentación | `game/scenes/ui/inventory_grid.gd` | Una celda por ranura de un componente; se repinta con `inventory_changed` |
| `InventorySlotView` | Presentación | `game/scenes/ui/inventory_slot.gd` | Una celda (`Button`): icono y cantidad, o aspecto vacío |
| `InventoryScreen` | Pantalla | `game/scenes/ui/inventory_screen.gd` | Inventario del jugador; selecciona una pila y pide tirarla o, si es consumible, usarla (botón "Usar", spec 012) |
| `QuantitySelector` | Presentación | `game/scenes/ui/quantity_selector.gd`, `.tscn` | − / + y deslizador de 1 a la pila; solo informa del número |
| `ContainerScreen` | Pantalla | `game/scenes/ui/container_screen.gd` | Cofre o caja abierta junto al inventario del jugador: colocar, transferir, "Coger todo" (sustituye a `LootScreen`, spec 012) |

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
   `FarmZone` lo reemite como `box_opened` y `main.gd` abre `ContainerScreen` con
   `{container: caja, inventory: del que abre, title}` ([ui.md](ui.md)).
7. En `ContainerScreen`, tocar una pila la selecciona y tocar una ranura mueve la cantidad elegida (ver "Mover entre
   ranuras"); "Coger todo" pasa todas las ranuras ocupadas en orden con `take_from`. La pantalla no se cierra sola
   al vaciarse el contenedor.
8. `InventoryScreen` se abre con el botón de almacenamiento o Tab (`open_storage`).
9. `InventoryGrid.bind()` pinta el estado inicial y se repinta solo con `inventory_changed` (nunca por
   `_process`). Las rejillas de la caja y del inventario tienen `interactive = true`.

### Dividir y tirar (spec 008)

1. Tocar una pila en `InventoryScreen` la selecciona y muestra `QuantitySelector` (de 1 a la pila, por defecto
   entera). `%ThrowButton` está desactivado sin selección. Los controles solo se ven si el contexto trae
   `CONTEXT_THROWER` (el `Robot`).
2. El botón llama `Robot.request_throw(ranura, cantidad)`; la pantalla no toca el inventario. El robot emite
   `throw_requested` (nada con la batería a 0) y `Main` llama `DroppedItemSpawner.drop_from_slot`.
3. `drop_from_slot` valida con `InventoryRules.can_split` y mueve la parte con
   `InventoryComponent.take_amount_from(origen, ranura, cantidad)` a un `DroppedItem` ([death.md](death.md)). El resto
   se queda en la ranura. Tras cada `inventory_changed`, la pantalla quita la selección si la ranura quedó vacía o
   reajusta el selector.
4. `InventoryRules.split(slots, índice, cantidad)` devuelve la pila que sale (`null` y sin cambio si la ranura está
   vacía o la cantidad no está en 1..pila); es la regla pura que reutiliza `move_to_slot` (spec 012).
5. `InventoryComponent.clear(n)` vacía el componente y lo deja con `n` ranuras: lo usan los objetos caídos del pool.
6. Al morir, `DeathController` mueve todas las pilas a un `DroppedItem` con `take_from`; las ranuras del robot no
   cambian.

### Guardado (spec 010)

1. `InventoryComponent` está en el grupo `persistent` con clave `inventory` ([save.md](save.md)). `to_save_data` lista
   cada ranura en orden (`null` si vacía) con `item_id`, `quantity`, `durability` y `uid`; el número de ranuras no se
   guarda: sale del nivel de chasis al cargar.
2. `from_save_data` reemplaza las ranuras con un solo `inventory_changed`. Una ranura mala (ítem desconocido, cantidad
   fuera de 1..`stack_max`, campo mal formado) queda vacía con `push_error`; las que sobran del número de ranuras se
   pierden con `push_error`.
3. `get_saved_slot_count(data)` deja que un contenedor dimensionado por su contenido (una caja abierta) se ajuste antes
   de cargar ([loot.md](loot.md)).

### Mover entre ranuras (spec 012)

1. `InventoryRules.move_to_slot(from, i, to, j, cantidad)`: ranura vacía, la coloca; mismo ítem (`can_merge`), suma hasta
   `stack_max` y el resto se queda (sin sitio: `ERR_SLOT_FULL`); otro ítem, intercambia solo la pila entera
   (`ERR_PARTIAL_SWAP` si se eligió una parte). Reutiliza `split`. `from` y `to` pueden ser el mismo arreglo.
2. `InventoryRules.transfer(from, i, to, cantidad)`: como `add_stack` (primero pilas del mismo ítem, luego vacías), lo que
   quepa; nada cabe: `ERR_NO_ROOM`. Una petición inválida (ranura fuera de rango, cantidad fuera de 1..pila, misma
   ranura) es `push_error` y `ERR_INVALID_REQUEST`; toda negativa deja todo como estaba.
3. `can_merge` exige mismo id y ningún `uid`: dos piezas nunca se suman; se intercambian conservando durabilidad y `uid`.
4. `InventoryComponent.move_to_slot(i, destino, j, n)` y `transfer_to(destino, i, n)` calculan con la regla sobre copias de
   las ranuras de ambos, escriben **las dos** y emiten una `inventory_changed` por inventario cambiado, primero el propio.
   Es la excepción declarada a "cada componente escribe solo las suyas" (plan 012 D12, ver Decisiones).

### Piezas únicas (spec 011)

1. Una pieza es una pila de 1 con `durability` y `uid` propios. `stack_max` 1 hace que nunca se fusione: dos Brazos
   ocupan dos ranuras.
2. `InventoryRules.add(slots, item, n)` es `add_stack(slots, ItemStack.new(item, n))`; `add_stack` copia durabilidad y
   `uid` a cada ranura nueva y `split` devuelve la parte con ambos. Por eso `add_stacks`, `take_from`,
   `take_amount_from` y los sobrantes (`leftovers`) conservan la pieza al mover, tirar, morir y recoger.
3. `is_valid_stack` solo exige algo a las pilas cuyo ítem del catálogo es `PieceData`: cantidad 1, durabilidad entre 1
   y la máxima, `uid` no vacío. Los materiales siguen las reglas de la spec 005. Se valida después de cambiar el ítem
   por el del catálogo.
4. `add(id, n)` de una pieza y `add_stacks` con una pila de pieza inválida son `push_error` y `ERR_INVALID_REQUEST` sin
   cambios: una pieza solo entra creada por `CraftingSystem.create_result` o con su `uid`.
5. `craft(recipe)` y `repair(piece_uid, costs)` cambian las ranuras en un paso con un solo `inventory_changed`; la
   decisión es de `CraftingSystem` ([crafting.md](crafting.md)). `index_of_uid` localiza la pieza.
6. `from_save_data` descarta con `push_error` la ranura que no pase `is_valid_stack`; el resto carga.

## Datos

| Recurso | Clase | Valores desde |
|---|---|---|
| `resources/progression/chassis_levels.tres` | `ChassisLevelData` | [BALANCE.md §6.1](../../BALANCE.md) (XP y ranuras por nivel) |
| `resources/pieces/*.tres` (`durability_max`, `stack_max` 1) | `PieceData` | [BALANCE.md §4.1](../../BALANCE.md); ver [crafting.md](crafting.md) |
| `resources/items/*.tres` (`stack_max`, `icon`) | `ItemData` | BALANCE.md §2; iconos SVG de marcador en `assets/textures/icons/items/` (ver [data_catalog.md](data_catalog.md)) |
| `resources/ui/screens.tres` | `UIScreenCatalog` | No es balance; ver [ui.md](ui.md) |

La capacidad de una caja abierta y de un cofre sale de `container.tres` ([BALANCE §1.3, §5.4](../../BALANCE.md); [wind_generator_chests.md](wind_generator_chests.md)). Una batería portátil es un `ConsumableData` (pila en BALANCE §2).

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
| La caja ya no se desactiva al vaciarse: es un contenedor durante la visita | Se coge y se deja lo que se quiera; sustituye a R-005-21 | R-012-37 |
| `move_to_slot` y `transfer_to` escriben las dos partes | Intercambio atómico entre dos dueños de la misma clase; sin método público que reemplace ranuras | [plan 012 D12 y §6 P3](../../specs/012-wind-generator-chests/plan.md) |
| Iconos SVG propios de marcador | Elegir pack de Kenney es decisión del usuario | R-005-32, plan 005 §1 |
| Dividir una pila es una regla pura (`split`) | Testeable sin escena y reutilizable por cofres | R-008-40 |
| La pantalla solo pide tirar; lo cambia el dueño del estado | Un escritor por inventario | R-008-42, [architecture §3](../../specs/architecture.md) |
| `take_amount_from` hermano de `take_from`, sobre `split` | La regla de dividir se escribe una sola vez | [plan 008 §1](../../specs/008-death-recovery/plan.md) |
| El inventario no guarda su tamaño | Lo decide el chasis (`ChassisLevelData`) | R-010-24 |
| Cargar emite `inventory_changed` y nada más | Es una señal de estado | [plan 010 §1.1 D15](../../specs/010-save-profile-world/plan.md) |
| Un solo camino de llenado, `add_stack`, que copia durabilidad y `uid` | Arregla en un sitio lo que perdían `split` y los sobrantes | [plan 011 D3](../../specs/011-crafting-repair/plan.md), R-011-09 |
| Las pilas se siguen fusionando solo por id; una pieza no se funde por su `stack_max` 1 | Sin regla de apilado nueva | plan 011 D2, R-011-08 |
| Una pieza inválida no entra, ni por `add` ni por carga | Sin piezas sin identidad | plan 011 D1, R-011-07, R-011-11 |

## Relación con otros sistemas

- Usa: [data_catalog.md](data_catalog.md) (`DataCatalog`, `ItemData`).
- Lo usan: [loot.md](loot.md) (el contenido de cada caja), [ui.md](ui.md) (pantallas y HUD, que escucha
  `overflowed` para mostrar `MSG_INVENTORY_FULL` durante 3 s), [interaction.md](interaction.md) (el robot abre la
  caja con su `InteractorComponent`).
- [death.md](death.md): la muerte, tirar items y recoger usan `take_from` / `take_amount_from` entre inventarios.
- Lo guarda [save.md](save.md). [crafting.md](crafting.md) crea y repara piezas con `craft` y `repair`. Cofres y consumibles: [wind_generator_chests.md](wind_generator_chests.md).

## Trampas y límites

- `ok == false` no implica "no cambió nada": un añadido parcial deja las ranuras modificadas. Mira `leftovers`.
- `get_slots()` devuelve copias; para cambiar el inventario hay que llamar a los métodos del componente.
- `count()` de un id desconocido hace `push_error` y devuelve 0.
- `set_slot_count` no reduce (error y `ERR_INVALID_REQUEST`).
- No hay arrastrar, ordenar ni subida de nivel ([spec 005 §4](../../specs/005-inventory/spec.md)). Dividir y colocar por
  ranura solo existe en `ContainerScreen`; `InventoryScreen` (Tab) sigue solo con tirar y usar. Lo que queda en una caja
  se descarta al repoblar la zona.
- `durability` y `uid` se conservan en todos los caminos de una pila (spec 011). Quien cree una pieza (botín de la
  spec 015) debe usar `CraftingSystem.create_result`: `ItemStack.new` sin `uid` la haría rechazar.
- Al caer, las pilas parciales del mismo item se fusionan: se conserva el total por item, no la ranura.
- `remove_many(amounts)` (spec 009) cobra varios ítems a la vez, todo o nada y con un solo `inventory_changed`: ítem
  desconocido o cantidad no positiva es `ERR_INVALID_REQUEST`, falta de algo es `ERR_NOT_ENOUGH_ITEMS`. La regla pura
  está en `InventoryRules.can_remove_many`/`remove_many`; lo usa `BaseStructures.place` ([base.md](base.md)).
- `ChassisLevelData.xp_required` existe pero nadie lo lee todavía (ACTION_PLAN 2.7).
- Los controles de las pantallas tienen `focus_mode = NONE` para que Tab siga llegando a `open_storage`.

## Cómo extenderlo

- Nuevo ítem: `.tres` de `ItemData` con su icono; ver [data_catalog.md](data_catalog.md).
- Subida de nivel de chasis: llamar a `inventory.set_slot_count(chassis_levels.get_inventory_slots(nivel))`.
- Otro contenedor: un `InventoryComponent` y abrir `ContainerScreen` con su contexto ([ui.md](ui.md)).

## Tests

| Archivo | Verifica |
|---|---|
| `tests/unit/test_inventory_rules.gd` | Apilado, orden de relleno, `count`, `remove` de atrás hacia delante; `split` entero, parcial e inválido; `move_to_slot` y `transfer` (colocar, sumar, intercambio entero, parcial rechazado, piezas, inválidas); piezas que no se fusionan, `add_stack` y `split` con durabilidad y `uid`, `is_valid_stack`, `index_of_uid` |
| `tests/unit/test_inventory_component.gd` | Validación, señales una vez por operación, `take_from`, `take_amount_from`, `clear`, copias, `overflowed`, `move_to_slot` y `transfer_to` (una señal por inventario, rechazos sin cambio); piezas (rechazo, conservación, carga inválida), `craft` y `repair` |
| `tests/unit/test_quantity_selector.gd` | Rango 1..máximo, empieza en el máximo, − / + y deslizador |
| `tests/unit/test_chassis_level_data.gd` | Tabla y `validate()` |
| `tests/unit/test_item_stack.gd` | `durability`, `uid` y `copy()` |
| `tests/integration/test_save_contract.gd`, `test_save_load.gd` | Formato de ranuras, ranuras malas, una sola señal |
| `tests/unit/test_inventory_screen.gd`, `test_container_screen.gd` | Celdas, repintado por señal, selección, selector, botones "Tirar" y "Usar"; contenedor: seleccionar, colocar, transferir, coger todo, no se cierra al vaciarse |
| `tests/integration/test_robot_inventory.gd` | El robot tiene su inventario con las ranuras del nivel 1, ningún autoload guarda contenido y `request_throw` emite |
