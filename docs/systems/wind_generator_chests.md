# Generador eólico, baterías portátiles y cofres

> Las dos estructuras que completan la base: el generador sube la batería máxima y fabrica baterías portátiles con el
> tiempo, y el cofre es el único almacén que sobrevive a la muerte. Su estado vive bajo `World`, no en la instancia.
> Specs: [012](../../specs/012-wind-generator-chests/spec.md) · Última actualización: spec 012

## Piezas

| Pieza | Tipo | Archivo | Responsabilidad |
|---|---|---|---|
| `StructureStates` | Nodo (hijo de `BaseStructures`) | `game/scenes/base/structure_states.gd` | Un `InventoryComponent` por cofre y un `WindGeneratorComponent` por generador, en un `Dictionary[String, Node]` por `uid` |
| `WindGeneratorComponent` | Componente (`Node`) | `game/scripts/components/wind_generator_component.gd` | Estado `(stored, since_unix)`, `collect`, `generator_changed`, guardado (`load_save_data` devuelve si era válido) |
| `WindGeneratorRules` | Sistema puro | `game/scripts/systems/wind_generator_rules.gd` | `settle`, `seconds_to_next`, `after_taking`, `elapsed_s`; la hora entra por parámetro |
| `WindGenerator` | Escena (`StaticBody3D`) | `game/scenes/base/wind_generator.gd`, `.tscn` | Modelo, aspas (`AnimationPlayer` `spin`, `autoplay`), rótulo `Label3D`, `RefreshTimer` de 1 s; emite `used` |
| `StorageChest` | Escena (`StaticBody3D`) | `game/scenes/base/storage_chest.gd`, `.tscn` | Modelo e `InteractableComponent` (`PROMPT_OPEN`); emite `used` |
| `StructureUseFlow` | Nodo de `Main` | `game/scenes/base/structure_use_flow.gd` | Abre `ContainerScreen` del cofre, pide recoger baterías, avisa y emite `chest_closed` |
| `ConsumableRules` | Sistema puro | `game/scripts/systems/consumable_rules.gd` | `check_use` y `first_consumable_slot` |
| `WindGeneratorData`, `StorageChestData`, `ContainerConfigData`, `ConsumableData` | Resources | `game/scripts/data/` | Ver Datos |

## Cómo funciona

**Construir y límites.** Igual que la estación ([base.md](base.md)). `BenchBuildSection.blocking_reason` devuelve
`MSG_STRUCTURE_LIMIT` antes que materiales y sitio si `BaseStructures.is_at_limit`; `place` lo comprueba primero, sin
cobrar. `place` sigue este orden: celdas, cobro, **estado** (`StructureStates.create_for` con la hora de ahora),
instancia, bonificación, `structure_built`. El estado existe antes que la instancia para que ésta nunca se enlace a
un estado ya liberado.

**Generador: reloj.**
1. El estado es `stored` y `since_unix` (inicio del periodo en curso). `settle(now)` suma un `stored` por periodo
   entero, sin pasar del máximo; lleno no acumula; tiempo negativo vale 0. Leer no cambia el estado.
2. Cuenta con la app cerrada y con la base descargada, porque solo depende de `(stored, since_unix, now)` y se
   guarda sin asentar.
3. `WindGenerator` pinta "n/máximo" y la cuenta atrás o "Lleno" con `generator_changed` y un `Timer` de 1 s (sin
   `_process`). Sin estado (la vista previa de colocación) deja el rótulo vacío.

**Generador: recoger.**
1. El robot interactúa; `WindGenerator.used` → `BaseStructures.structure_used(uid, user)`.
2. `StructureUseFlow` (solo para el robot local) llama a `BaseStructures.collect_batteries(player, uid)`.
3. `WindGeneratorComponent.collect` asienta y hace `inventory.add(battery_item.id, stored)`; lo que no cabe se queda.
   Si algo se movió, `EventBus.batteries_collected` (guarda el Mundo). Nada cabe: `MSG_INVENTORY_FULL` (el aviso lo
   da `overflowed` del inventario). Vacío: `MSG_GENERATOR_EMPTY`, y el flujo muestra `Hud.show_notice` con el tiempo.
4. Si estaba lleno, el periodo siguiente empieza al recoger; si no, el periodo en curso sigue.

**Batería máxima.** `BaseStructures._update_bonus` publica la mayor `max_battery_bonus` de los generadores
colocados con `max_battery_bonus_changed` (señal de estado: al colocar y al cargar). `Main._wire_battery_bonus` la
conecta a `BatteryComponent.set_maximum_bonus` y aplica el valor actual antes de cargar el Mundo ([battery.md](battery.md)).

**Usar una batería portátil.** `Robot.request_use_consumable(slot)` (tecla Q, acción `use_consumable`, o botón "Usar" de
`InventoryScreen`): `ConsumableRules.check_use` decide, `inventory.remove_from_slots` quita una unidad de **esa ranura** y
`battery.add(battery_points)`. Las negativas salen por `Robot.use_refused(error_key)` y las muestra el `Hud`. No guarda.

**Cofre.** `StorageChest.used` → `structure_used` → `StructureUseFlow` abre `container` con
`{container, inventory, title}` ([ui.md](ui.md)). Mientras está abierta vigila `inventory_changed` del cofre; al cerrarse
(`UIScreen.closed`, también por viaje o muerte) con cambios emite `EventBus.chest_closed` y se guarda.

**Guardado.** `BaseStructures.to_save_data` añade `chests: {uid: contenido}` y `generators: {uid: {stored, since_unix}}`
solo si no están vacías. `from_save_data`: cuadrícula, instancias viejas fuera, `StructureStates.load_data`, instancias
nuevas si la base está cargada, bonificación. Entrada inválida, de un `uid` no colocado o de otro tipo: `push_error` y
esa estructura empieza nueva. Sin las claves, cada cofre empieza vacío y cada generador cuenta desde la carga. No sube
`schema_version`. Cargar solo emite señales de estado ([save.md](save.md)).

## Datos

| Recurso | Clase | Valores en BALANCE |
|---|---|---|
| `resources/structures/wind_generator.tres` | `WindGeneratorData` | [§5.2](../../BALANCE.md) (bonificación, periodo, máximo almacenado, máximo en base), §5.6 (huella) |
| `resources/structures/storage_chest.tres` | `StorageChestData` | §5.4 (máximo), §5.6 (huella) |
| `resources/config/container.tres` | `ContainerConfigData` | §1.3, §5.4 (capacidad; la lee también `LootBox`, §7.2) |
| `resources/items/portable_battery.tres` | `ConsumableData` | §2 (pila), §1.1 (puntos) |
| `resources/recipes/wind_generator.tres`, `storage_chest.tres` | `RecipeData` | §5.1, §5.2, §5.4, §5.5 |

`StructureData.max_count` (0 = sin límite) es el límite de cada estructura; la estación lo lleva explícito en 0.

## Decisiones

| Decisión | Por qué | Fuente |
|---|---|---|
| Estado en `StructureStates` bajo `World`, no en la instancia | La instancia se libera al salir de la base | [plan 012 §1 y D5](../../specs/012-wind-generator-chests/plan.md) |
| `max_count` en `StructureData` | Sin literales de límite en scripts | R-012-03, plan D1 |
| La bonificación es "la mayor", no la suma | No da por decidido que varios generadores se acumulen | plan D9 |
| Reloj `(stored, since_unix)` sin asentar al guardar | Asentar es determinista; sin división por cero con datos malos | plan D7, R-012-16, R-012-17 |
| Uso de consumibles por ranura, no por id | `InventoryRules.remove` quita de la última ranura; sin id escrito en scripts | plan D4 |
| Cofres y generadores fuera del grupo `persistent` | Su carga depende de qué `uid` están colocados | plan D5, R-012-42 |
| Guardar al cerrar el cofre, no al usar una batería ni al cerrar una caja de loot | Pregunta cerrada de la spec | R-012-44, [spec 012 §6](../../specs/012-wind-generator-chests/spec.md) pregunta 9 |
| El generador no tiene pantalla: rótulo 3D y recoger al interactuar | Pregunta cerrada | spec 012 pregunta 7, plan D17 |
| Modelos de primitivas e icono SVG propio | Presupuesto 0 €; definitivos en ACTION_PLAN 4.4 | plan D20 |
| Mantenimiento del generador, bancos avanzados, cofres expandidos | Fuera del PMV | [spec 012 §4](../../specs/012-wind-generator-chests/spec.md) |

## Relación con otros sistemas

Usa [base.md](base.md) (`BaseStructures`, colocación), [inventory.md](inventory.md) (`move_to_slot`, `add`),
[battery.md](battery.md) (`set_maximum_bonus`, `add`), [ui.md](ui.md) (`ContainerScreen`, `Hud.show_notice`), [save.md](save.md)
y el reloj `ITimeService` de `GameManager.get_time_service()` ([death.md](death.md)). Interacción: [interaction.md](interaction.md).

## Trampas y límites

- La hora solo se lee por `ITimeService`; un test busca `Time.get_unix_time` fuera de `LocalTimeService`. Cambiar la hora del móvil adelanta el generador (aceptado en el PMV).
- `BaseStructures.time_service` se toma en `_ready()`; los tests asignan un `FakeTimeService` antes de colocar o enlazar la base.
- `WindGenerator.bind_state` guarda el servicio de hora: si un test lo cambia, hay que volver a enlazar la base.
- `StructureStates` lo crea `BaseStructures` en `_ready()`; no es un nodo de `main.tscn`.
- El aviso del generador vacío lleva el texto ya traducido: no cambia si cambia el idioma con el aviso visible.
- Cooperativo (v2.0): un robot que entra después debe conectarse a `max_battery_bonus_changed`; hoy solo `Main` lo hace con el local.
- Sin desmontar estructuras, sin botón de consumibles en el HUD (ACTION_PLAN 4.1) y, desde la spec 015, la máxima es el stat del Core más la bonificación del generador (`BatteryComponent.set_base_maximum` + `set_maximum_bonus`, [battery.md](battery.md)).
- Las aspas que giran y el toque en Android son pruebas manuales (M1, M3 del plan).

## Cómo extenderlo

Otra estructura con estado: subclase de `StructureData`, rama en `StructureStates.create_for`/`load_data` y claves nuevas
en su parte del Mundo. Otro consumible: `ConsumableData` en el catálogo; `ConsumableRules` y `Robot` lo usan sin cambios.

## Tests

| Archivo | Verifica |
|---|---|
| `tests/unit/test_wind_generator_rules.gd`, `test_wind_generator_component.gd` | Reloj puro (periodos, máximo, lleno, negativo, recoger), `collect`, datos malos |
| `tests/unit/test_wind_generator.gd`, `test_storage_chest.gd` | Rótulo, refresco sin `_process`, vista previa sin estado, aspas |
| `tests/unit/test_structure_states.gd` | Estado por `uid`, ida y vuelta, entradas inválidas, sin capacidades guardadas |
| `tests/unit/test_structure_resources.gd`, `test_consumable_resources.gd`, `test_consumable_rules.gd` | Datos contra BALANCE, límites, nombres ES/EN, reglas de uso |
| `tests/integration/test_base_structures.gd`, `test_structure_use_flow.gd`, `test_robot_consumable.gd` | Límite, mover con estado, bonificación, recoger, cofre, usar batería |
| `tests/integration/test_base_loop.gd`, `test_save_load.gd`, `test_save_triggers.gd`, `test_save_fixtures.gd` | Cofre tras viaje, muerte y reinicio; razones de guardado; Mundo anterior |
