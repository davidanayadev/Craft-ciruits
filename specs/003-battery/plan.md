# Plan 003 — Batería: consumo, señales y HUD

| Campo | Valor |
|---|---|
| **Spec** | [spec.md](spec.md) (debe estar *Aprobado*) |
| **Estado** | Planificado (2026-11-15) |

## 1. Enfoque

`BatteryComponent` es un `Node` hijo del robot que guarda su batería (constitución P4) y no conoce escenas, input
ni zonas. No tiene `_physics_process`: el robot, que es la entidad dueña, le llama a `tick(delta, gait)` en cada
fotograma de física con la marcha que ya calcula para moverse. Así la regla de consumo es un método con todas sus
entradas por parámetro (architecture.md §3 regla 4) y se prueba sin física ni escena.

La **marcha** (`IDLE` / `WALK` / `RUN`) pasa a ser un concepto explícito de `LocomotionSystem` (spec 002). Hoy la
decisión "correr = intención de correr y piernas que pueden" vive dentro de `horizontal_velocity`; si la batería la
repitiera habría dos copias de la misma regla (P2). Se extrae a `LocomotionSystem.gait()` y `horizontal_velocity`
pasa a usarla, sin cambiar su firma ni sus tests.

**De dónde sale cada número** (R-003-13, P2):

| Valor | Dueño en el PMV | Por qué ahí |
|---|---|---|
| Batería máxima, consumo pasivo, consumo al correr, umbral de batería baja | `BatteryConfigData` (`robot_battery.tres`) | BALANCE §1.1 los da como valores generales del robot. La máxima es la del Core básico (§4.2); el spec 014 la moverá al Core |
| Consumo al andar | `MovementStatsData.walk_drain` (`basic_legs.tres`) | BALANCE §4.2 lo da por piernas (básicas +0.05, sin piernas +0.1) |

El componente recibe los dos recursos por `@export`. `robot.tscn` apunta al mismo `basic_legs.tres` desde el robot
y desde la batería; el spec 014 sustituye ambos por `StatsComponent` (architecture.md §9.4).

**Estado agotado sin bandera.** "Agotada" es `current == 0`. El componente emite `battery_depleted` en la
transición de `> 0` a `0`, y a 0 el consumo ya no cambia nada ni emite nada (R-003-08). `add()` y `recharge_full()`
sí funcionan a 0 (el respawn del spec 008 usará `recharge_full()`), y una nueva llegada a 0 vuelve a emitir.

**HUD** (`Hud`, architecture.md §9.5): se engancha al robot con `bind(player: Robot)`, escucha `battery_changed` y
no tiene `_process`. Al enlazar pinta una vez el estado actual llamando a su **mismo** manejador de
`battery_changed`: es la foto inicial (la batería ya estaba llena antes de que el HUD existiera), no un sondeo.

**Game over provisional** (R-003-12): `GameOverScreen` oculto en `UI`. Al recibir `battery_depleted`, `main.gd`
desactiva el nodo `World` (`process_mode = PROCESS_MODE_DISABLED`: el robot se congela) y abre la pantalla. El
botón emite `restart_requested` y `main.gd` recarga la escena. Se descarta pausar el árbol (§7). El spec 008
sustituye todo esto por el ruleset y el respawn.

## 2. Archivos

| Archivo (`game/…`) | Nuevo / Cambia | Responsabilidad |
|---|---|---|
| `scripts/data/battery_config_data.gd` | Nuevo | Resource: máxima, consumo pasivo, consumo al correr, umbral bajo |
| `resources/battery/robot_battery.tres` | Nuevo | Valores de BALANCE §1.1 y §4.2 (Core básico) |
| `scripts/data/movement_stats_data.gd` | Cambia | Añade `walk_drain` |
| `resources/movement/basic_legs.tres` | Cambia | `walk_drain = 0.05` (BALANCE §4.2) |
| `scripts/systems/locomotion_system.gd` | Cambia | Añade `enum Gait` y `gait()`; `horizontal_velocity` la usa (misma firma) |
| `scripts/components/battery_component.gd` | Nuevo | Estado de la batería, consumo por tiempo, señales, API para otros sistemas |
| `scenes/entities/robot.tscn` | Cambia | Nodo `BatteryComponent` (`%BatteryComponent`) con `config` y `legs` |
| `scenes/entities/robot.gd` | Cambia | Calcula la marcha una vez por fotograma, la usa para moverse y para `battery.tick()`; expone `battery` |
| `scenes/ui/hud.tscn` + `hud.gd` | Nuevo | Barra (`ProgressBar`) + número entero arriba a la izquierda; `bind(player)` |
| `scenes/ui/game_over_screen.tscn` + `game_over_screen.gd` | Nuevo | Pantalla provisional: fondo, título y botón reiniciar; señal `restart_requested` |
| `scenes/main.tscn` | Cambia | `World` con nombre único; `UI/Hud` y `UI/GameOverScreen` |
| `scenes/main.gd` | Cambia | Enlaza HUD → robot; `battery_depleted` → congelar `World` + abrir game over; `restart_requested` → recargar |
| `i18n/strings.csv` (+ `.translation` regenerados al importar) | Cambia | `GAME_OVER_TITLE`, `GAME_OVER_RESTART` |
| `tests/unit/test_battery_component.gd` | Nuevo | R-003-01..10, R-003-14 |
| `tests/unit/test_battery_resources.gd` | Nuevo | R-003-13 |
| `tests/unit/test_locomotion_system.gd` | Cambia | Tests de `gait()` (parte de R-003-03, R-003-04) |
| `tests/unit/test_hud.gd` | Nuevo | R-003-11 |
| `tests/unit/test_game_over_screen.gd` | Nuevo | R-003-12 (pantalla y textos) |
| `tests/integration/test_robot_battery.gd` | Nuevo | R-003-02..04 con física real e InputMap |
| `tests/integration/test_main_scene.gd` | Cambia | HUD enlazado (R-003-11) y game over al agotarse (R-003-12) |

No se crean `GameManager`, `EventBus` ni `UIManager` (§7).

## 3. Contratos

```gdscript
class_name BatteryConfigData
extends Resource

@export var maximum: float = 0.0               # puntos
@export var passive_drain: float = 0.0         # puntos/s, siempre mientras quede batería
@export var run_drain: float = 0.0             # puntos/s, sustituye a walk_drain al correr
@export var low_threshold_ratio: float = 0.0   # fracción de la máxima
```

```gdscript
class_name MovementStatsData
extends Resource

@export var walk_speed: float = 0.0
@export var run_speed: float = 0.0
@export var can_run: bool = false
@export var walk_drain: float = 0.0            # nuevo: puntos/s al andar con estas piernas
```

```gdscript
class_name LocomotionSystem
extends RefCounted

enum Gait { IDLE, WALK, RUN }

## IDLE sin dirección; RUN solo si run_intent y stats.can_run; si no, WALK.
static func gait(world_dir: Vector3, run_intent: bool, stats: MovementStatsData) -> Gait
# horizontal_velocity(), world_direction(), target_yaw(), rotate_toward_yaw(): sin cambios de firma
```

```gdscript
class_name BatteryComponent
extends Node

signal battery_changed(current: float, maximum: float)
signal battery_low
signal battery_depleted

@export var config: BatteryConfigData
@export var legs: MovementStatsData            # consumo al andar; lo sustituye StatsComponent en el spec 014

func get_current() -> float
func get_maximum() -> float
func is_depleted() -> bool                     # current == 0
func drain_per_second(gait: LocomotionSystem.Gait) -> float
func tick(delta: float, gait: LocomotionSystem.Gait) -> void
func consume(amount: float) -> void            # amount < 0 → push_error, sin cambios
func add(amount: float) -> void                # amount < 0 → push_error, sin cambios; tope en la máxima
func recharge_full() -> void
```

Reglas del componente (cada una con su test):

- Arranca con `current = maximum = config.maximum` en `_ready()` (R-003-01). Si `config` o `legs` faltan,
  `push_error()` con el nombre del nodo.
- `drain_per_second`: `passive_drain` + (`legs.walk_drain` si `WALK`, `config.run_drain` si `RUN`, 0 si `IDLE`).
  No recibe ni consulta la zona: el consumo es el mismo en la base y fuera (R-003-02).
- `tick` consume `drain_per_second(gait) * delta`: solo depende del tiempo transcurrido (R-003-05).
- Todo cambio pasa por un único método privado `_set_current(value)`, que recorta a `[0, maximum]` y, **solo si el
  valor cambia**, emite en este orden: `battery_changed` → `battery_low` (si cruza a `< umbral` y estaba armado) →
  `battery_depleted` (si cruza a 0). Umbral = `maximum * low_threshold_ratio`; el aviso se rearma cuando el valor
  sube a `> umbral` (R-003-06..08).
- `consume(0)` y `add(0)` no cambian nada y no emiten.
- No se usa `ActionResult`: ver el ⚠️ de §6.

```gdscript
class_name Robot
extends CharacterBody3D

@onready var battery: BatteryComponent = %BatteryComponent   # nuevo; lo enlazan HUD y main
```

```gdscript
class_name Hud
extends Control

func bind(player: Robot) -> void
static func display_value(current: float) -> int   # ceili(current): 87.5 → 88, 0.01 → 1, 0 → 0
```

```gdscript
class_name GameOverScreen
extends Control

signal restart_requested

func open() -> void                            # visible y foco en el botón reiniciar
```

**Eventos**: ninguno nuevo en `EventBus` (architecture.md §7). `battery_low`, `battery_changed` y
`battery_depleted` son señales locales del componente; `player_died` sigue siendo del spec 008.

## 4. Datos

No hace falta ningún valor nuevo en BALANCE.md.

| Recurso / `.tres` | Campos | Valores desde |
|---|---|---|
| `resources/battery/robot_battery.tres` | `maximum = 100.0` | BALANCE §1.1 "Batería máxima base" = §4.2 Core básico |
| | `passive_drain = 0.1` | BALANCE §1.1 "Consumo pasivo" |
| | `run_drain = 0.15` | BALANCE §1.1 "Consumo movimiento (correr)" (spec, pregunta 2) |
| | `low_threshold_ratio = 0.2` | BALANCE §1.1 "Umbral de batería baja" |
| `resources/movement/basic_legs.tres` | `walk_drain = 0.05` | BALANCE §4.2 Piernas básicas "Consumo al andar" |

Totales que comprueban los tests: quieto 0.1/s, andando 0.15/s, corriendo 0.25/s (BALANCE §1.1).

## 5. Verificación

| Requisito | Test (`game/tests/…`) o paso manual |
|---|---|
| R-003-01 | `unit/test_battery_component.gd::test_r_003_01_starts_full` |
| R-003-02 | `unit/test_battery_component.gd::test_r_003_02_idle_drains_passive_rate` + `integration/test_robot_battery.gd::test_r_003_02_idle_robot_drains` + revisión: `tick()` no recibe ni consulta la zona (la base no existe hasta el spec 009) |
| R-003-03 | `unit/test_battery_component.gd::test_r_003_03_walk_adds_legs_walk_drain`, `unit/test_locomotion_system.gd::test_r_003_03_gait_walk_*`, `integration/test_robot_battery.gd::test_r_003_03_walking_robot_drains_more` |
| R-003-04 | `unit/test_battery_component.gd::test_r_003_04_run_replaces_walk_drain`, `unit/test_locomotion_system.gd::test_r_003_04_gait_run_*` (sin piernas que puedan correr es `WALK`), `integration/test_robot_battery.gd::test_r_003_04_running_robot_drains_most` |
| R-003-05 | `unit/test_battery_component.gd::test_r_003_05_same_drain_at_any_frame_rate` (1 s en pasos de 1/30, 1/60, 1/144 y 1.0) |
| R-003-06 | `unit/test_battery_component.gd::test_r_003_06_emits_changed_with_values`, `::test_r_003_06_no_signal_without_change` |
| R-003-07 | `unit/test_battery_component.gd::test_r_003_07_low_emitted_once_below_threshold`, `::test_r_003_07_low_rearms_after_rising_above` |
| R-003-08 | `unit/test_battery_component.gd::test_r_003_08_depleted_clamps_and_emits_once`, `::test_r_003_08_no_drain_after_depleted`, `::test_r_003_08_signal_order` |
| R-003-09 | `unit/test_battery_component.gd::test_r_003_09_consume`, `::test_r_003_09_add_capped_at_maximum`, `::test_r_003_09_recharge_full` |
| R-003-10 | `unit/test_battery_component.gd::test_r_003_10_negative_consume_rejected`, `::test_r_003_10_negative_add_rejected` (`assert_push_error`) |
| R-003-11 | `unit/test_hud.gd::test_r_003_11_display_value_rounds_up`, `::test_r_003_11_follows_battery_changed`, `::test_r_003_11_does_not_poll` (`is_processing()` y `is_physics_processing()` en falso); `integration/test_main_scene.gd::test_r_003_11_hud_bound_to_robot`; manual (T-003-08): arriba a la izquierda y legible en el móvil |
| R-003-12 | `unit/test_game_over_screen.gd::test_r_003_12_hidden_until_opened`, `::test_r_003_12_restart_button_emits`, `::test_r_003_12_texts_in_es_and_en`; `integration/test_main_scene.gd::test_r_003_12_depletion_opens_game_over_and_freezes_world`; manual (T-003-08): reiniciar recarga la partida |
| R-003-13 | `unit/test_battery_resources.gd::test_r_003_13_robot_battery_matches_balance`, `::test_r_003_13_basic_legs_walk_drain_matches_balance` + revisión del diff: sin literales de gameplay en `battery_component.gd` |
| R-003-14 | `unit/test_battery_component.gd::test_r_003_14_two_components_do_not_share_state` (mismo `config`: consumir en uno no cambia el otro ni el recurso) |
| Criterio de hecho | T-003-08: PC y APK en Android real |

**Paso manual del game over.** Agotar 100 puntos tarda ~16 min quieto. Para verlo, se baja `maximum` en
`robot_battery.tres` en local (por ejemplo a 3), se prueba y se deshace. Si el cambio se colara en un commit,
`test_r_003_13_robot_battery_matches_balance` falla.

**APIs verificadas (2026-11-15)** contra el binario 4.7.2 en headless (`ClassDB` y propiedades de instancia) y el
GUT 9.7.1 vendorizado. No queda nada **(verificar)**:

1. `SceneTree.reload_current_scene()` existe.
2. `Control.auto_translate_mode` existe: `Label` y `Button` con el texto igual a la clave se traducen solos.
3. `ProgressBar.show_percentage` existe (se pone en falso: el número lo pinta el `Label`).
4. `Node.PROCESS_MODE_DISABLED` / `PROCESS_MODE_ALWAYS` existen.
5. `ceili()`: `ceili(0.0001) = 1`, `ceili(20.0) = 20`, `ceili(87.5) = 88`.
6. `physics/common/physics_ticks_per_second` = 60 (lo usan los tests de integración para calcular tolerancias).
7. GUT: `assert_push_error(text)` y `assert_push_error_count(n)` existen, y un `push_error` no esperado hace fallar
   el test (`failure_error_types` incluye `push_error`). GUT no cambia el `process_mode` de sus nodos, así que
   pausar el árbol dentro de un test dejaría GUT congelado; con `World` desactivado eso no pasa (§7).

## 6. Check de constitución

| Principio | Cumple | Nota |
|---|---|---|
| P2 Una fuente de verdad | ✅ | Números solo en `.tres` desde BALANCE §1.1 y §4.2. La regla de correr vive solo en `LocomotionSystem.gait()` |
| P3 Lógica separada | ✅ | El consumo es un método del componente con `delta` y marcha por parámetro; sin física ni escena en sus tests. El HUD y el game over solo pintan y emiten |
| P4 Estado por jugador | ✅ | La batería vive en el componente del robot. No se crea `GameManager` (§7) |
| P5 Datos como recursos | ✅ | `BatteryConfigData` nuevo; `MovementStatsData` gana `walk_drain` |
| P6 Señales | ✅ | `battery_changed` / `battery_low` / `battery_depleted` tipadas y en pasado. HUD y main por señales; referencias con `%` |
| P7 Tipado | ✅ | Todo tipado; los avisos-error de spec 001 lo fuerzan |
| P8 Plataforma | ✅ | Nada depende del dispositivo; la batería no lee input |
| P11 i18n | ✅ | `GAME_OVER_TITLE` y `GAME_OVER_RESTART` en ES y EN. El HUD solo pinta un número |
| P12 Presupuesto móvil | ✅ | HUD por señales, sin `_process`. `battery_changed` sale en cada fotograma de física al consumir (60/s); coste medido en T-003-08 |
| P13 Test primero | ✅ | Componente, marcha, recursos y HUD con test rojo primero; reinicio real y lectura en el móvil, paso manual |
| P14 Alcance | ✅ | Ni golpes, ni muerte real, ni estación, ni guardado, ni aviso "Batería baja" (spec §4). El cambio en `LocomotionSystem` es extraer una regla que ya existe, no un refactor de paso |
| architecture.md §3 regla 4 (`ActionResult`) | ⚠️ | `consume` / `add` / `recharge_full` devuelven `void`. `ActionResult` lleva una clave de error **para el jugador** (§9.2), y estas llamadas no fallan por algo que haga el jugador: una cantidad negativa es un fallo de programación, que la constitución §2 trata con `push_error()` y retorno explícito. Consumir más de lo que queda no es un fallo: es la muerte (R-003-08). Se creará `ActionResult` con la primera acción que pueda fallar ante el jugador (crafteo, spec 011). Aceptado por el usuario al aprobar el plan (2026-11-15) |
| architecture.md §9.5 (HUD por señales) | ✅ | La foto inicial al enlazar pasa por el mismo manejador de `battery_changed` (§1) |

## 7. Riesgos y alternativas descartadas

- **El spec 002 no está fusionado en `main`.** La rama `feat/003-battery` debe nacer de `main` con el 002 dentro
  (README §5). Lo bloquea T-003-00.
- **`battery_changed` 60 veces por segundo.** Cada emisión pone el valor de la barra y el texto de la etiqueta
  (`Label` no redibuja si el texto no cambia). Mitigación: se mide en el móvil (T-003-08). Si cuesta, el HUD
  ignora los cambios que no mueven ni la barra ni el número; el componente no cambia.
- **La marcha sale de la intención, no del desplazamiento real.** Empujar contra una pared consume como andar. Se
  acepta: las piernas trabajan, y medir el desplazamiento haría el consumo depender de la física. Si playtesting
  dice lo contrario, se cambia solo en `robot.gd`.
- **Dos `@export` apuntan a `basic_legs.tres`** (robot y batería). Podrían desalinearse al editar la escena a mano;
  `test_robot_battery.gd` usa la escena real y lo detectaría como velocidades o consumos raros. Desaparece con
  `StatsComponent` (spec 014).
- **Descartado: pausar el árbol (`get_tree().paused`) en el game over.** Obliga a marcar la pantalla como
  `PROCESS_MODE_ALWAYS`, la pausa sobrevive a `reload_current_scene()` (hay que quitarla antes) y congelaría GUT en
  los tests. Desactivar `World` congela al robot y la zona sin estado global.
- **Descartado: `BatteryComponent` con su propio `_physics_process` leyendo al robot.** Acoplaría el componente a
  `Robot` y obligaría a testear con física. Con `tick(delta, gait)` cualquier entidad (o el anfitrión del cooperativo)
  lo alimenta.
- **Descartado: crear `GameManager` ahora** (ACTION_PLAN 0.4 lo pide en esta tarea). No tendría estado: no hay
  mundo, ruleset ni zonas hasta los specs 004, 008 y 010. Se crea con el primero que lo necesite (P14).
- **Descartado: `UIManager` y `EventBus` ahora.** El game over es provisional (lo sustituye el spec 008) y no hay
  ningún evento global en este spec.
- **Descartado: `TextureProgressBar`** (ACTION_PLAN 0.4 la nombra). Sin texturas aún; `ProgressBar` cumple R-003-11 y
  el cambio a textura es visual (ACTION_PLAN 4.x).
- **Descartado: mostrar decimales o "87 / 100"** (spec, pregunta 4): solo el entero redondeado hacia arriba.
