# Batería

> La batería es la salud del robot: se gasta sola, al moverse y al recibir golpes, y al llegar a 0 el robot muere.
> Specs: [003](../../specs/003-battery/spec.md), [007](../../specs/007-melee-combat/spec.md), [008](../../specs/008-death-recovery/spec.md) · [010](../../specs/010-save-profile-world/spec.md) · [012](../../specs/012-wind-generator-chests/spec.md) · [015](../../specs/015-pieces-slots-degradation/spec.md) · Última actualización: spec 015 (máxima y consumos como stats, `is_low`)

## Piezas

| Pieza | Tipo | Archivo | Responsabilidad |
|---|---|---|---|
| `BatteryComponent` | Componente (`Node`) | `game/scripts/components/battery_component.gd` | Estado (actual/máximo), tasas de consumo que le da su dueño, señales, `is_low()` |
| `BatteryConfigData` | Resource | `game/scripts/data/battery_config_data.gd` | Solo el umbral de batería baja (`low_threshold_ratio`) |
| `robot_battery.tres` | Recurso | `game/resources/battery/robot_battery.tres` | Valores del robot |
| `LocomotionSystem.gait()` | Sistema puro | `game/scripts/systems/locomotion_system.gd` | Convierte dirección + intención de correr en `Gait` (IDLE/WALK/RUN) |
| `Robot` | Escena | `game/scenes/entities/robot.gd` | Alimenta `tick()` cada frame de física; `receive_hit()` consume |
| `Hud` | Escena | `game/scenes/ui/hud.gd` | Barra y número de batería |
| `DeathController` | Nodo | `game/scenes/death/death_controller.gd` | Escucha `battery_depleted` y aplica el ruleset ([death.md](death.md)) |
| `Main` | Escena | `game/scenes/main.gd` | Muestra la transferencia y congela `World` al morir el robot local |

## Cómo funciona

1. `BatteryComponent._ready()` solo comprueba `config` (`push_error` si falta). Arranca **vacía y con máxima 0**: la máxima y
   los consumos son stats y llegan de `Robot` (`set_base_maximum`, `set_drain_rates`, ver [stats.md](stats.md)), que después
   llama a `recharge_full()` una vez. El componente nunca mira piezas.
2. Cada `_physics_process`, `Robot` calcula la marcha con `LocomotionSystem.gait(...)` (a partir de la **intención**, no del
   desplazamiento real: empujar contra una pared gasta como caminar) y llama `battery.tick(delta, gait)`.
3. `tick()` gasta `drain_per_second(gait) * delta`: pasivo siempre, más el de caminar o el de correr (que **sustituye**
   al de caminar), con las tasas dadas por `set_drain_rates` (los stats `passive_drain`, `walk_drain` y `run_drain`; sin
   Core el pasivo es el de "Sin Core", también en la base). Depende solo del tiempo, no de los FPS, y no consulta la zona.
4. Todo cambio pasa por `_set_current()` (clamp a [0, máximo]) y emite en este orden: `battery_changed(current, maximum)`,
   `battery_low` y `battery_depleted`.
5. `battery_low` se emite una vez al cruzar por debajo del umbral y se rearma al subir por encima. `battery_depleted`
   se emite una vez por llegada a 0; en 0 `tick()` ya no hace nada.
6. Otros sistemas usan `consume(amount)`, `add(amount)` y `recharge_full()`. Cantidad negativa: `push_error`, sin cambio.
   Consumir más de lo que queda no es error: agota la batería.
7. `Hud.bind(robot)` se conecta a `battery_changed` y pinta el estado inicial; muestra `ceili(current)` para no enseñar 0
   mientras quede carga. No lee estado en `_process`. Con `is_low()` (carga por debajo de máxima × `low_threshold_ratio`,
   la regla de `battery_low` leída como estado) la barra cambia su estilo `fill` a `Hud.low_battery_fill` (naranja) y
   si no lo quita. Sigue a `battery_changed`, no a `battery_low`, así sale bien tras cargar, recargar o cambiar la máxima.
8. `DeathController` escucha `battery_depleted` y aplica el ruleset (suelta el inventario, sube la visita, emite
   `player_died`); `Main` cierra las pantallas, muestra `TransferScreen` y congela `World` (`process_mode = DISABLED`,
   diferido) sin pausar el árbol. Ya no hay game over ni recarga de escena. Al reaparecer, `Robot.respawn_at` carga la
   batería con `add()`. Ver [death.md](death.md).
9. Coste de ataque (spec 007): `MeleeAttackComponent` emite `swing_started(battery_cost)` y `Robot` lo conecta a
   `battery.consume()`, acierte o no. `BatteryComponent` no cambió; un golpe propio puede agotar la batería.

```
Robot._physics_process -> BatteryComponent.tick -> battery_changed -> Hud
Robot.receive_hit ------> consume -------------> battery_depleted -> DeathController -> player_died -> Main (TransferScreen)
MeleeAttackComponent.swing_started -> Robot -> consume
```

### Guardado (spec 010)

`BatteryComponent` está en el grupo `persistent` con clave `battery` ([save.md](save.md)): guarda solo la carga actual; el
máximo sale de los stats, por eso `Equipment` carga antes en `robot.tscn` ([equipment.md](equipment.md)). `from_save_data` emite `battery_changed` si la carga cambia, rearma el aviso de batería
baja y nunca emite `battery_low` ni `battery_depleted` (cargar no es un hecho). Una carga `<= 0` es `push_error` y no
cambia nada. Una carga por encima del máximo (spec 012) carga en el máximo y queda **pendiente**; ver más abajo.

### Máxima = stat + bonificación (spec 015, spec 012)

`_maximum = _base_maximum + _maximum_bonus`. `set_base_maximum` (el stat `max_battery`, del Core equipado o del valor sin
Core) y `set_maximum_bonus` (el generador) comparten un solo método privado, `_apply_maximum`, con la regla de abajo.

1. `set_maximum_bonus(bonus)` suma la bonificación al stat. La carga se queda (baja solo si superara el
   máximo), se emite una sola `battery_changed` si algo cambió y nunca `battery_low` ni `battery_depleted`: nada se
   consumió. El aviso de batería baja se rearma como al cargar. Una bonificación negativa es `push_error`.
2. Quien la llama es `Main` (`_wire_battery_bonus`), con `BaseStructures.max_battery_bonus_changed` y el valor actual
   antes de cargar el Mundo ([wind_generator_chests.md](wind_generator_chests.md)).
3. El umbral bajo, `recharge_full()` y la carga al reaparecer usan el máximo con bonificación.
4. Para no depender del orden en que cargan los dueños `persistent`, una carga guardada por encima del máximo actual
   se aplica en el máximo y se recuerda como pendiente. `set_maximum_bonus` la aplica si el nuevo máximo la admite. Cualquier
   otro cambio de carga (`_set_current`) o un nuevo `from_save_data` la borra con `push_error` si no se aplicó.

## Datos

| Recurso | Clase | Valores en BALANCE |
|---|---|---|
| `resources/battery/robot_battery.tres` | `BatteryConfigData` | [§1.1](../../BALANCE.md) (umbral de batería baja) |
| `resources/robot/robot_base_stats.tres` y las piezas | `RobotBaseStatsData`, `PieceData.modifiers` | Máxima y consumos: [§1.1](../../BALANCE.md), §4.2 ([stats.md](stats.md)) |

## Decisiones

| Decisión | Por qué | Fuente |
|---|---|---|
| El estado vive en un componente, no en un autoload | Dos entidades no comparten batería; necesario para el co-op | R-003-14, [constitución P4](../../specs/constitution.md) |
| `BatteryComponent` no tiene `_process` ni lee input | Las reglas se prueban sin escena y un host puede alimentar a cualquier entidad | [plan 003 §1](../../specs/003-battery/plan.md) |
| `consume`/`add`/`recharge_full` devuelven `void`, no `ActionResult` | Un importe negativo es un fallo de programación, no un fallo del jugador; consumir de más es la muerte | [plan 003 §6](../../specs/003-battery/plan.md) |
| `ProgressBar` en lugar de `TextureProgressBar` | Aún no hay texturas | [plan 003 §7](../../specs/003-battery/plan.md) |
| Número entero redondeado hacia arriba en el HUD | Pregunta cerrada en nov 2026 | [spec 003](../../specs/003-battery/spec.md) (preguntas abiertas, nº 4) |
| La muerte real sustituye al game over provisional | `GameOverScreen` y la recarga de escena se borraron | R-008-33, R-003-12 |
| La bonificación del generador es un dato aplicado a la máxima, no se guarda | La spec 015 la suma a la del Core sin rehacerla | R-012-11, R-012-40 |
| Máxima y consumos los da `Robot` desde `StatsComponent`; el componente no lee piezas | Los componentes hermanos no se conocen | R-015-14, [plan 015 D5](../../specs/015-pieces-slots-degradation/plan.md) |
| Una sola regla para la máxima del stat y la del generador | Un cambio de máxima nunca corta la carga ni emite `battery_low` | R-015-19, [plan 015 D6](../../specs/015-pieces-slots-degradation/plan.md) |
| Barra naranja con `is_low()` desde `battery_changed` | Es estado, no depende de un hecho único | R-015-43, [plan 015 D18](../../specs/015-pieces-slots-degradation/plan.md) |
| Carga guardada por encima de la máxima: pendiente, sin error todavía | Independiente del orden de carga y sin tocar `SaveManager` | [plan 012 D11](../../specs/012-wind-generator-chests/plan.md), R-012-14 |
| El coste de ataque se descuenta en `Robot`, no en el componente de combate | Sin documentar (R-007-10 solo exige el coste por golpe) | R-007-10, [plan 007](../../specs/007-melee-combat/plan.md) |

## Relación con otros sistemas

- Usa [movement.md](movement.md): `LocomotionSystem.Gait`. Sus tasas y su máxima vienen de [stats.md](stats.md); el Core
  equipado marca la máxima ([equipment.md](equipment.md)).
- Lo usan [enemies.md](enemies.md) (el golpe llega por `Robot.receive_hit`, que llama `consume`) e [interaction.md](interaction.md)
  (un robot con batería agotada no interactúa).
- `Robot.use_consumable` usa `add()` para las baterías portátiles ([wind_generator_chests.md](wind_generator_chests.md)).
- Las pantallas (`Hud`, `TransferScreen`, `UIManager`) se describen en [ui.md](ui.md); la muerte, en [death.md](death.md). Datos en [data_catalog.md](data_catalog.md).

## Trampas y límites

- Fuera de un `Robot` un `BatteryComponent` nace con máxima 0: hay que llamar a `set_base_maximum` y `set_drain_rates`
  (los tests lo hacen con un helper) y a `recharge_full()`.
- Con los valores del PMV, quitar o romper el Core no cambia la máxima, así que no recorta la carga; sin Core el consumo
  pasivo es el doble ([stats.md](stats.md)).
- La estación de carga recarga a la máxima con bonificación (spec 009). El desgaste de piezas va antes de `consume` en
  `Robot.receive_hit` ([equipment.md](equipment.md)).
- La batería al reaparecer sale de `RulesetData.respawn_battery_ratio`, no de `BatteryConfigData`.
- `battery_low` no tiene oyentes todavía.
- Un valor guardado absurdo (por ejemplo 1e9) se informa más tarde que antes: al borrar la pendiente, no al cargar.
- Con la batería agotada `receive_hit()` no hace nada (R-006-18).

## Cómo extenderlo

- Otra fuente de gasto o recarga: llamar a `consume()` / `add()` / `recharge_full()` desde el sistema nuevo, nunca escribir el valor.
- Otro consumo por marcha: un stat nuevo ([stats.md](stats.md)), su tasa en `set_drain_rates` y en `drain_per_second()`.
- Una entidad nueva con batería: añadir un `BatteryComponent` con su `config`.

## Tests

| Archivo | Verifica |
|---|---|
| `tests/unit/test_battery_component.gd` | R-003-01..10, R-003-14: arranque, tasas, independencia de FPS, señales y su orden, clamp; R-012-11..14: máxima con bonificación, una sola señal, carga pendiente en cualquier orden; R-015-15, 18, 19, 43, 44: tasas por marcha, máxima stat + bonificación, sin `battery_low`, `is_low` |
| `tests/unit/test_battery_resources.gd` | R-003-13: `.tres` coinciden con BALANCE |
| `tests/unit/test_locomotion_system.gd` | `gait()` |
| `tests/unit/test_hud.gd` | R-003-11: redondeo, sigue a `battery_changed`, sin polling; R-015-43: barra naranja |
| `tests/integration/test_robot_battery.gd` | Consumo con física real e InputMap |
| `tests/integration/test_main_scene.gd` | HUD enlazado; al agotarse, transferencia y reaparición ([death.md](death.md)) |
| `tests/integration/test_robot_combat.gd` | Un golpe cuesta batería, también si falla (R-007-10) |
