# Stats del robot

> Los stats del robot (velocidades, consumos, daño, batería máxima, desgaste por golpe) son datos más un cálculo puro:
> una base sin piezas y los modificadores de las piezas equipadas. `Robot` entrega el resultado a movimiento, ataque y
> batería, que nunca miran las piezas.
> Specs: [015](../../specs/015-pieces-slots-degradation/spec.md) · Última actualización: spec 015

## Piezas

| Pieza | Tipo | Archivo | Responsabilidad |
|---|---|---|---|
| `StatIds` | Constantes (`RefCounted`) | `game/scripts/data/stat_ids.gd` | Un `StringName` por stat; `ALL` en el orden de los campos de `RobotBaseStatsData` |
| `StatModifier` | Resource | `game/scripts/data/stat_modifier.gd` | `stat`, `op` (`SET`, `ADD`, `MULTIPLY`) y `value` |
| `RobotBaseStatsData` | Resource | `game/scripts/data/robot_base_stats_data.gd` | Un `@export` por stat, mismo nombre que su id; `to_stats()` |
| `robot_base_stats.tres` | `.tres` | `game/resources/robot/robot_base_stats.tres` | El robot sin piezas (un brazo, sin piernas, sin Core) |
| `StatsCalculator` | Sistema puro (`RefCounted`, estático) | `game/scripts/systems/stats_calculator.gd` | `compute(base, modifiers)`: todos los `SET`, luego los `ADD`, luego los `MULTIPLY` |
| `StatsComponent` | Componente (`Node`, hijo del robot) | `game/scripts/components/stats_component.gd` | Dueño de los stats calculados; `recompute`, `get_stat`, `get_movement`, `get_attack`, `stats_changed` |
| `MovementStatsData`, `AttackStatsData` | Resources usados como objetos de valor | `game/scripts/data/` | Los construye `StatsComponent` en cada llamada; ya no tienen `.tres` |
| `Robot` | Escena | `game/scenes/entities/robot.gd` | Une equipo, stats y consumidores (cableado "push") |

## Cómo funciona

1. `StatsComponent._ready()` copia `base_stats.to_stats()`: hasta el primer `recompute` valen los stats sin piezas.
2. `Robot._ready()` conecta `equipment.equipment_changed` con `_on_equipment_changed` y `stats.stats_changed` con
   `_apply_stats`, llama una vez a `_on_equipment_changed()` (el equipo inicial ya está puesto) y después
   `battery.recharge_full()`: un robot nuevo empieza lleno.
3. `_on_equipment_changed` llama `stats.recompute(equipment.get_modifiers())`. Solo cuentan los modificadores de las
   piezas **equipadas**: una pieza en el inventario, un cofre o el suelo no cambian nada.
4. `StatsCalculator.compute` parte de una copia de la base y aplica los modificadores por operación y, dentro de cada
   una, en el orden de la lista. Un modificador nulo o de un stat que la base no tiene es `push_error` y se salta.
5. `recompute` emite `stats_changed` una vez. `Robot._apply_stats` entrega cada valor a su consumidor:
   - movimiento: `_movement = stats.get_movement()` (`can_run` es `run_speed > 0`, no un dato);
   - ataque: `melee.set_attack(stats.get_attack())` (el daño es `roundi(attack_damage)`);
   - batería: `set_drain_rates(passive, walk, run)` y `set_base_maximum(max_battery)`.
6. `Robot.receive_hit` lee `StatIds.DURABILITY_PER_HIT` de `StatsComponent` para el desgaste ([equipment.md](equipment.md)).
7. Cargar un Mundo también pasa por aquí: `EquipmentComponent.from_save_data` emite `equipment_changed`, así que los
   stats se recalculan; nada derivado se guarda.

```
PieceData.modifiers --> EquipmentComponent.get_modifiers --> Robot --> StatsComponent.recompute
                                                                          | stats_changed
                         Robot._apply_stats --> LocomotionSystem (_movement) / MeleeAttack.set_attack / Battery.set_*
```

## Datos

| Recurso | Clase | Valores en BALANCE |
|---|---|---|
| `resources/robot/robot_base_stats.tres` | `RobotBaseStatsData` | [§4.2](../../BALANCE.md) (filas "Un brazo", "Sin piernas", "Sin Core"), §1.1 (consumo al correr), §4.1 (desgaste por golpe) |
| `PieceData.modifiers` en `resources/pieces/*.tres` | `StatModifier` | [§4.2](../../BALANCE.md) (la fila de cada pieza básica) |

Cada celda de §4.2 vive en un solo `.tres`: la fila "sin pieza" en la base y la de la pieza en la pieza.

## Decisiones

| Decisión | Por qué | Fuente |
|---|---|---|
| Stats como datos más un cálculo puro | Recuerdos y piezas nuevas se añaden sin tocar movimiento, batería ni combate | R-015-03, [architecture §9.4](../../specs/architecture.md) |
| Cableado "push" en `Robot`, no "pull" desde cada componente | Los componentes hermanos no se conocen y se prueban solos con valores tipados | [plan 015 §1 y D5](../../specs/015-pieces-slots-degradation/plan.md) |
| Un campo `@export` por stat y ids en `StatIds` | Tipado y validable; un diccionario exportado aceptaría claves mal escritas | [plan 015 D1](../../specs/015-pieces-slots-degradation/plan.md) |
| Sin piernas, `run_speed = 0`; `can_run` se deriva | Un `MULTIPLY` futuro sobre 0 sigue en 0 y no hay stat booleano | [plan 015 D2](../../specs/015-pieces-slots-degradation/plan.md), R-015-15 |
| Cada pieza usa `SET` de toda su fila | Copia la tabla de BALANCE tal cual; un `ADD` escondería el número | [plan 015 D3](../../specs/015-pieces-slots-degradation/plan.md) |
| El desgaste por golpe es un stat | Un modificador (spec 017) puede cambiarlo | R-015-06 |
| Sin `DegradationComponent` | No tendría estado propio: la durabilidad vive en las pilas del equipo | [plan 015 D9](../../specs/015-pieces-slots-degradation/plan.md) |
| `MovementStatsData` y `AttackStatsData` siguen como objetos de valor | `LocomotionSystem` y `CombatSystem` no cambian de firma | [plan 015 D4](../../specs/015-pieces-slots-degradation/plan.md) |

## Relación con otros sistemas

Usa [equipment.md](equipment.md) (los modificadores). Lo usan [movement.md](movement.md), [battery.md](battery.md) y
[combat.md](combat.md) (reciben sus valores) y la pantalla de equipo ([equipment.md](equipment.md)), que los lista.

## Trampas y límites

- Un `StatModifier` con un id mal escrito no falla al cargar el `.tres`: se informa y se salta en `compute`. Hay un test
  que comprueba que cada modificador de pieza nombra un stat de la base.
- `get_attack().damage` es un entero (`roundi`): un modificador que dé 7.5 aplicaría 8 ([plan 015 §7](../../specs/015-pieces-slots-degradation/plan.md)).
- `get_movement()` y `get_attack()` crean un objeto nuevo en cada llamada; guardarlo no lo mantiene al día.
- `get_stat` con un id desconocido es `push_error` y devuelve 0.0.
- No hay stat de defensa (vale 0 en el PMV) ni recuerdos todavía (spec 017).

## Cómo extenderlo

- Stat nuevo: constante en `StatIds` (y en `ALL`), campo con el mismo nombre en `RobotBaseStatsData`, su valor en
  `robot_base_stats.tres` tras BALANCE, y un consumidor en `Robot._apply_stats`.
- Pieza o recuerdo nuevo: `StatModifier` en su `.tres`; ningún script cambia.

## Tests

| Archivo | Verifica |
|---|---|
| `tests/unit/test_stats_calculator.gd` | `SET` → `ADD` → `MULTIPLY`, entradas intactas, modificador desconocido o nulo |
| `tests/unit/test_stats_component.gd` | Solo cuentan los modificadores dados, una `stats_changed` por `recompute`, vistas de movimiento y ataque |
| `tests/unit/test_robot_base_stats.gd` | La base coincide con BALANCE; los `.tres` sueltos de movimiento y ataque ya no existen |
| `tests/unit/test_piece_resources.gd` | Ranura y modificadores de las piezas básicas, equipo inicial de `robot.tscn` |
| `tests/integration/test_robot_equipment.gd` | Cada cambio recalcula una vez; velocidad, daño y consumo siguen a los stats |
