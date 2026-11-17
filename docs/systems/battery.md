# Batería

> La batería es la salud del robot: se gasta sola, al moverse y al recibir golpes, y al llegar a 0 la partida termina.
> Specs: [003](../../specs/003-battery/spec.md) · Última actualización: spec 006 (el golpe de zombi entra por `Robot.receive_hit`)

## Piezas

| Pieza | Tipo | Archivo | Responsabilidad |
|---|---|---|---|
| `BatteryComponent` | Componente (`Node`) | `game/scripts/components/battery_component.gd` | Estado (actual/máximo), tasa de consumo por marcha, señales |
| `BatteryConfigData` | Resource | `game/scripts/data/battery_config_data.gd` | Máximo, consumo pasivo, consumo al correr, umbral de batería baja |
| `robot_battery.tres` | Recurso | `game/resources/battery/robot_battery.tres` | Valores del robot |
| `LocomotionSystem.gait()` | Sistema puro | `game/scripts/systems/locomotion_system.gd` | Convierte dirección + intención de correr en `Gait` (IDLE/WALK/RUN) |
| `Robot` | Escena | `game/scenes/entities/robot.gd` | Alimenta `tick()` cada frame de física; `receive_hit()` consume |
| `Hud` | Escena | `game/scenes/ui/hud.gd` | Barra y número de batería |
| `GameOverScreen` | Escena | `game/scenes/ui/game_over_screen.gd` | Pantalla provisional de fin de partida |
| `Main` | Escena | `game/scenes/main.gd` | Reacciona a `battery_depleted` |

## Cómo funciona

1. `BatteryComponent._ready()` copia `config.maximum` y arranca llena. Sin `config` o sin `legs` hace `push_error`.
2. Cada `_physics_process`, `Robot` calcula la marcha con `LocomotionSystem.gait(...)` (a partir de la **intención**, no del
   desplazamiento real: empujar contra una pared gasta como caminar) y llama `battery.tick(delta, gait)`.
3. `tick()` gasta `drain_per_second(gait) * delta`: pasivo siempre, más `legs.walk_drain` al caminar o `run_drain`
   (que **sustituye** al de caminar) al correr. Depende solo del tiempo, no de los FPS, y no consulta la zona.
4. Todo cambio pasa por `_set_current()` (clamp a [0, máximo]) y emite en este orden: `battery_changed(current, maximum)`,
   `battery_low` y `battery_depleted`.
5. `battery_low` se emite una vez al cruzar por debajo del umbral y se rearma al subir por encima. `battery_depleted`
   se emite una vez por llegada a 0; en 0 `tick()` ya no hace nada.
6. Otros sistemas usan `consume(amount)`, `add(amount)` y `recharge_full()`. Cantidad negativa: `push_error`, sin cambio.
   Consumir más de lo que queda no es error: agota la batería.
7. `Hud.bind(robot)` se conecta a `battery_changed` y pinta el estado inicial; muestra `ceili(current)` para no enseñar 0
   mientras quede carga. No lee estado en `_process`.
8. `Main._on_battery_depleted()` cierra las pantallas del `UIManager`, abre `GameOverScreen` y congela `World`
   (`process_mode = DISABLED`, diferido) sin pausar el árbol. El botón emite `restart_requested` y `Main` recarga la escena.

```
Robot._physics_process -> BatteryComponent.tick -> battery_changed -> Hud
Robot.receive_hit ------> consume -------------> battery_depleted -> Main -> GameOverScreen + World congelado
```

## Datos

| Recurso | Clase | Valores en BALANCE |
|---|---|---|
| `resources/battery/robot_battery.tres` | `BatteryConfigData` | [§1.1](../../BALANCE.md) (máximo del Core básico: §4.2) |
| `resources/movement/basic_legs.tres` | `MovementStatsData` | `walk_drain`: §4.2 (ver [movement.md](movement.md)) |

## Decisiones

| Decisión | Por qué | Fuente |
|---|---|---|
| El estado vive en un componente, no en un autoload | Dos entidades no comparten batería; necesario para el co-op | R-003-14, [constitución P4](../../specs/constitution.md) |
| `BatteryComponent` no tiene `_process` ni lee input | Las reglas se prueban sin escena y un host puede alimentar a cualquier entidad | [plan 003 §1](../../specs/003-battery/plan.md) |
| `consume`/`add`/`recharge_full` devuelven `void`, no `ActionResult` | Un importe negativo es un fallo de programación, no un fallo del jugador; consumir de más es la muerte | [plan 003 §6](../../specs/003-battery/plan.md) |
| `ProgressBar` en lugar de `TextureProgressBar` | Aún no hay texturas | [plan 003 §7](../../specs/003-battery/plan.md) |
| Número entero redondeado hacia arriba en el HUD | Pregunta cerrada en nov 2026 | [spec 003](../../specs/003-battery/spec.md) (preguntas abiertas, nº 4) |
| Game over provisional con reinicio | Lo sustituye el spec 008 | R-003-12, [spec 003](../../specs/003-battery/spec.md) |

## Relación con otros sistemas

- Usa [movement.md](movement.md): `LocomotionSystem.Gait` y `MovementStatsData.walk_drain`.
- Lo usan [enemies.md](enemies.md) (el golpe llega por `Robot.receive_hit`, que llama `consume`) e [interaction.md](interaction.md)
  (un robot con batería agotada no interactúa).
- Las pantallas (`Hud`, `GameOverScreen`, `UIManager`) se describen en [ui.md](ui.md). Datos en [data_catalog.md](data_catalog.md).

## Trampas y límites

- `legs` se asigna a mano en el componente; el spec 014 lo sustituye por `StatsComponent`. El máximo también pasará al Core equipado.
- No hay muerte real, drops ni respawn (spec 008), ni recarga en Estación de carga (specs 009 y 012). Solo el reinicio de escena.
- El consumo por golpe dado y la degradación de piezas aún no existen (specs 007 y 014; `Robot.hit_received` es el punto de enganche).
- `battery_low` no tiene oyentes todavía.
- Con la batería agotada `receive_hit()` no hace nada (R-006-18).

## Cómo extenderlo

- Otra fuente de gasto o recarga: llamar a `consume()` / `add()` / `recharge_full()` desde el sistema nuevo, nunca escribir el valor.
- Otro consumo por marcha: añadir el valor a un `.tres` (BALANCE primero) y a `drain_per_second()`.
- Una entidad nueva con batería: añadir un `BatteryComponent` con su `config`.

## Tests

| Archivo | Verifica |
|---|---|
| `tests/unit/test_battery_component.gd` | R-003-01..10, R-003-14: arranque, tasas, independencia de FPS, señales y su orden, clamp |
| `tests/unit/test_battery_resources.gd` | R-003-13: `.tres` coinciden con BALANCE |
| `tests/unit/test_locomotion_system.gd` | `gait()` |
| `tests/unit/test_hud.gd` | R-003-11: redondeo, sigue a `battery_changed`, sin polling |
| `tests/unit/test_game_over_screen.gd` | R-003-12: oculta hasta `open()`, botón, textos ES/EN |
| `tests/integration/test_robot_battery.gd` | Consumo con física real e InputMap |
| `tests/integration/test_main_scene.gd` | HUD enlazado y game over al agotarse |
