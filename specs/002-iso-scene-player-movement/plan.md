# Plan 002 — Escena isométrica y movimiento del robot

| Campo | Valor |
|---|---|
| **Spec** | [spec.md](spec.md) (debe estar *Aprobado*) |
| **Estado** | Planificado (2026-11-14) |

## 1. Enfoque

Se monta el esqueleto de escena de `architecture.md` §6 (raíz `Main` persistente con `World/ZoneSlot`,
`World/Players/Robot`, `CameraRig` y `UI`) con una zona de desarrollo provisional en `ZoneSlot` (suelo, luz,
cielo y un obstáculo) que el spec 004 sustituirá por zonas reales. Toda la lógica de movimiento es pura y
testeable sin escena (constitución P3): un módulo interpreta el joystick (zona muerta, histéresis 80/70) y otro
calcula marcha, velocidad y giro; las escenas solo capturan input y aplican resultados.

El robot no lee ni toques ni teclas: lee un `PlayerInput` (la "abstracción de input de movimiento" de R-002-13)
que funde las acciones del InputMap (PC) y el joystick virtual (táctil). Los números viven en `.tres` leídos de
BALANCE.md (§4.2 y §11); los dos valores "Por definir" de §11 se proponen en §4 de este plan y se escriben en
BALANCE.md al aprobarse, antes de crear los `.tres`.

**Cámara**: proyección **ortográfica** (isométrica clásica: sin distorsión de perspectiva, legibilidad estable
en móvil y sombras predecibles). "Distancia" de BALANCE §11 se concreta como *tamaño ortográfico* (metros
visibles en vertical) más una distancia física que solo afecta a near/far y sombras. Seguimiento rígido (sin
suavizado: un número menos que ajustar; se añadiría solo si el móvil lo pide). Alternativa descartada en §7.

**Modelo del robot**: primitivas (cápsula + caja frontal para ver el giro), que R-002-04 permite. Importar un
modelo low-poly de Kenney queda como mejora visual dentro de ACTION_PLAN 4.x; así este spec no mete binarios.

## 2. Archivos

| Archivo (`game/…`) | Nuevo / Cambia | Responsabilidad |
|---|---|---|
| `scenes/main.tscn` | Cambia | Esqueleto de architecture.md §6: `Main` → `World` (`ZoneSlot`, `Players/Robot`), `CameraRig`, `UI` (`TouchControls`) |
| `scenes/main.gd` | Nuevo | Cableado al arrancar: joystick → `PlayerInput`, robot → `CameraRig` |
| `scenes/dev/dev_zone.tscn` | Nuevo | Zona provisional: suelo 50x50, `DirectionalLight3D` con sombras, `WorldEnvironment` con cielo procedural, un obstáculo `StaticBody3D`. La sustituye el spec 004 |
| `scenes/entities/robot.tscn` + `robot.gd` | Nuevo | `CharacterBody3D` + `CapsuleShape3D` + malla placeholder. Lee `PlayerInput`, llama a `LocomotionSystem`, aplica `move_and_slide()` |
| `scenes/camera/camera_rig.tscn` + `camera_rig.gd` | Nuevo | `Node3D` + `Camera3D`; aplica `CameraConfigData` y sigue al objetivo en `_physics_process` |
| `scenes/ui/touch_controls.tscn` + `touch_controls.gd` | Nuevo | `CanvasLayer`; decide visibilidad (táctil o flag debug) — única capa con lógica de plataforma (P8) |
| `scenes/ui/floating_joystick.gd` (+ nodo en `touch_controls.tscn`) | Nuevo | Captura `InputEventScreenTouch/Drag` en la mitad izquierda, joystick flotante, sigue solo su dedo; delega la interpretación en `JoystickLogic`. Se llama `FloatingJoystick` porque 4.7 tiene un `VirtualJoystick` nativo (§7) |
| `scripts/components/player_input.gd` | Nuevo | Abstracción de input (R-002-13): funde InputMap y joystick; expone dirección y `run intent` |
| `scripts/systems/joystick_logic.gd` | Nuevo | Lógica pura del joystick: recorte al radio, zona muerta, histéresis correr 80/70 |
| `scripts/systems/locomotion_system.gd` | Nuevo | Lógica pura de marcha: dirección relativa a cámara, velocidad fija por tramo, giro suave |
| `scripts/data/movement_stats_data.gd` | Nuevo | Resource: `walk_speed`, `run_speed`, `can_run` |
| `scripts/data/control_config_data.gd` | Nuevo | Resource: umbrales del joystick y velocidad de giro |
| `scripts/data/camera_config_data.gd` | Nuevo | Resource: yaw, pitch, distancia, tamaño ortográfico |
| `resources/movement/basic_legs.tres` | Nuevo | Piernas básicas (BALANCE §4.2). El spec 015 lo migrará a modificadores de `StatsComponent` |
| `resources/config/controls.tres` | Nuevo | Valores de BALANCE §11 |
| `resources/config/camera.tres` | Nuevo | Valores de BALANCE §11 |
| `tests/unit/test_joystick_logic.gd` | Nuevo | R-002-15, 16, y seguimiento de dedo/centrado (parte lógica de 10, 11) |
| `tests/unit/test_locomotion_system.gd` | Nuevo | R-002-05..08, 17, 18 |
| `tests/unit/test_movement_resources.gd` | Nuevo | R-002-14: los `.tres` existen y sus valores son los de BALANCE |
| `tests/integration/test_main_scene.gd` | Nuevo | R-002-01..04: cámara, luz, cielo, seguimiento, robot bien construido |
| `tests/integration/test_robot_movement.gd` | Nuevo | R-002-09 (colisión con física simulada), parada sin deslizar |

## 3. Contratos

```gdscript
class_name MovementStatsData
extends Resource

@export var walk_speed: float      # m/s
@export var run_speed: float       # m/s
@export var can_run: bool
```

```gdscript
class_name ControlConfigData
extends Resource

@export var joystick_dead_zone_ratio: float    # 0.15
@export var joystick_run_ratio: float          # 0.80
@export var joystick_walk_back_ratio: float    # 0.70
@export var turn_speed_rad: float              # rad/s
```

```gdscript
class_name CameraConfigData
extends Resource

@export var yaw_degrees: float       # 45
@export var pitch_degrees: float     # 35
@export var distance: float          # m, solo near/far y sombras (ortográfica)
@export var ortho_size: float        # m visibles en vertical
```

```gdscript
class_name JoystickLogic            # estática, sin estado

class Sample:
    var direction: Vector2          # normalizada; ZERO si !active
    var active: bool                # false dentro de la zona muerta
    var run_intent: bool

static func clamp_to_radius(offset: Vector2, radius: float) -> Vector2
static func interpret(offset: Vector2, radius: float, was_running: bool, config: ControlConfigData) -> Sample
```

```gdscript
class_name LocomotionSystem         # estática, sin estado

static func world_direction(input_dir: Vector2, camera_yaw_rad: float) -> Vector3
static func horizontal_velocity(world_dir: Vector3, run_intent: bool, stats: MovementStatsData) -> Vector3
static func rotate_toward_yaw(current_yaw: float, target_yaw: float, turn_speed_rad: float, delta: float) -> float
```

```gdscript
class_name PlayerInput
extends Node                        # hijo del robot; única fuente de input de movimiento (R-002-13)

func get_direction() -> Vector2     # teclado (InputMap) o joystick; analógica, |v| <= 1
func is_run_intent() -> bool        # acción "run" o run_intent del joystick
func set_joystick_sample(sample: JoystickLogic.Sample) -> void
func clear_joystick() -> void
```

```gdscript
class_name FloatingJoystick
extends Control

signal sample_changed(sample: JoystickLogic.Sample)
signal released
```

```gdscript
class_name CameraRig
extends Node3D

@export var config: CameraConfigData
@export var target: Node3D          # asignado en main.tscn (nada de get_node con rutas)
```

Reglas de la marcha (en `LocomotionSystem` / `JoystickLogic`, cada una con su test):

- Correr = `run_intent and can_run` (R-002-06, R-002-18). El teclado da `run_intent` con la acción `run`; el
  joystick lo da por histéresis: se activa al superar `joystick_run_ratio` y se suelta por debajo de
  `joystick_walk_back_ratio` (R-002-16).
- La velocidad es `walk_speed` o `run_speed`, nunca proporcional a la fuerza del joystick (R-002-17); la
  dirección sí es analógica.
- `world_direction` rota el input 2D por el yaw de la cámara: empujar arriba mueve "pantalla arriba" (R-002-05).
- Sin input: velocidad horizontal cero en el mismo fotograma, sin inercia (R-002-08).

## 4. Datos

| Recurso / `.tres` | Campos | Valores desde |
|---|---|---|
| `resources/movement/basic_legs.tres` | `walk_speed = 3.0`, `run_speed = 4.8`, `can_run = true` | BALANCE §4.2 |
| `resources/config/controls.tres` | `0.15` / `0.80` / `0.70`, `turn_speed_rad` | BALANCE §11 |
| `resources/config/camera.tres` | `yaw 45`, `pitch 35`, `distance`, `ortho_size` | BALANCE §11 |

**Propuesta para los "Por definir" de BALANCE §11** (se escriben en BALANCE.md al aprobar este plan, T-002-02,
y se ajustan en el móvil, T-002-08):

| Parámetro | Valor inicial | Razón |
|---|---|---|
| Velocidad de giro | `10.0 rad/s` | Media vuelta en ~0.3 s: ágil sin teletransporte visual |
| Cámara: tamaño ortográfico | `10.0 m` | Apaisado desde 2026-11-14 (T-002-08): ~10 m de alto y ~17.8 m de ancho. (La propuesta original en retrato era `14.0 m`) |
| Cámara: distancia física | `20.0 m` | Margen de near/far y sombras; no cambia el encuadre ortográfico |

El test de R-002-14 compara los `.tres` con estos valores: si BALANCE cambia sin tocar el recurso, el test
avisa en la revisión (los valores de los tests se actualizan con BALANCE, como en `test_input_map.gd`).

## 5. Verificación

Los tests de UI no simulan clics (ADR 0002, headless): la geometría y la histéresis del joystick se prueban
como lógica pura y los eventos táctiles reales se verifican en el móvil (T-002-08).

| Requisito | Test (`game/tests/…`) o paso manual |
|---|---|
| R-002-01 | `integration/test_main_scene.gd::test_r_002_01_camera_isometric_angles` (ortográfica, yaw/pitch desde `camera.tres`) |
| R-002-02 | `integration/test_main_scene.gd::test_r_002_02_camera_follows_robot` (mueve el robot, el rig mantiene offset) |
| R-002-03 | `integration/test_main_scene.gd::test_r_002_03_light_shadows_and_sky` + manual móvil (presupuesto §3.2) |
| R-002-04 | `integration/test_main_scene.gd::test_r_002_04_robot_is_characterbody_with_capsule` |
| R-002-05 | `unit/test_locomotion_system.gd::test_r_002_05_*` (dirección relativa a cámara, velocidad andando 3.0) |
| R-002-06 | `unit/test_locomotion_system.gd::test_r_002_06_run_speed` |
| R-002-07 | `unit/test_locomotion_system.gd::test_r_002_07_smooth_turn` (converge sin sobrepasar) |
| R-002-08 | `unit/test_locomotion_system.gd::test_r_002_08_stops_without_input` + `integration/test_robot_movement.gd` |
| R-002-09 | `integration/test_robot_movement.gd::test_r_002_09_blocked_by_obstacle` (física simulada **(verificar)**) |
| R-002-10 | `unit/test_joystick_logic.gd` (centrado y recorte) + manual móvil: aparece donde tocas, se oculta al soltar |
| R-002-11 | `unit/test_joystick_logic.gd` + test del joystick llamando a su manejador con eventos sintetizados; manual móvil con dos dedos |
| R-002-12 | Manual PC: WASD/flechas + Shift; joystick oculto; flag debug lo fuerza con ratón |
| R-002-13 | Revisión del PR: `robot.gd` solo usa `PlayerInput`; nadie fuera de `virtual_joystick.gd` toca eventos táctiles |
| R-002-14 | `unit/test_movement_resources.gd::test_r_002_14_values_match_balance` |
| R-002-15 | `unit/test_joystick_logic.gd::test_r_002_15_dead_zone` |
| R-002-16 | `unit/test_joystick_logic.gd::test_r_002_16_run_hysteresis_80_70` |
| R-002-17 | `unit/test_locomotion_system.gd::test_r_002_17_fixed_speed_per_gait` |
| R-002-18 | `unit/test_locomotion_system.gd::test_r_002_18_no_legs_no_run` (stats con `can_run = false`) |
| Criterio de hecho | T-002-08: APK en Android real — joystick, velocidades, giro, colisión, cámara, ≥ 30 FPS |

**Verificación de APIs (T-002-01, 2026-11-14).** Comprobado contra el binario 4.7.2 (`ClassDB` /
`ProjectSettings` en headless) y el código vendorizado de GUT 9.7.1:

1. `DisplayServer.is_touchscreen_available()` — **(verificado)** existe.
2. `input_devices/pointing/emulate_touch_from_mouse` — **(verificado)** el ajuste existe, pero no se usa: el
   flag debug hace que el propio joystick trate el botón izquierdo del ratón como un toque, sin tocar ajustes
   globales (cambio 2026-11-14).
3. Física en GUT — **(verificado)**: `test.gd` ofrece `simulate(obj, times, delta)` (llama a
   `_physics_process` a mano, **sin** PhysicsServer) y `await wait_physics_frames(n)` (frames de física
   reales). R-002-09 usa `wait_physics_frames`, porque la colisión necesita física real.
4. `Camera3D.keep_aspect` — **(verificado)**: por defecto `1` (*KEEP_HEIGHT*): `ortho_size` = metros
   verticales, como asume §4.
5. `Input.get_vector()` — **(verificado)** existe (4 acciones + deadzone opcional del InputMap).
6. `ProceduralSkyMaterial` — **(verificado)** la clase existe; el render real bajo Compatibility se ve en
   T-002-06 al arrancar en PC (mismo renderer que Android).

## 6. Check de constitución

| Principio | Cumple | Nota |
|---|---|---|
| P2 Una fuente de verdad | ✅ | Números solo en `.tres` desde BALANCE; los dos "Por definir" se escriben en BALANCE §11 antes de crear los `.tres` |
| P3 Lógica separada | ✅ | `JoystickLogic` y `LocomotionSystem` puros y estáticos; escenas solo capturan input y aplican resultados |
| P4 Estado por jugador | ✅ | Ningún autoload nuevo; input y stats cuelgan del robot |
| P5 Datos como recursos | ✅ | `MovementStatsData`, `ControlConfigData`, `CameraConfigData` |
| P6 Señales | ✅ | Joystick → señales tipadas; referencias por `@export` / `%`, sin rutas hardcodeadas |
| P7 Tipado | ✅ | Todo tipado; los avisos-error de spec 001 lo fuerzan |
| P8 Plataforma | ✅ | Gameplay lee `PlayerInput`; lo táctil vive solo en `scenes/ui/` (capa input/UI, permitida); sin `OS.*` en gameplay |
| P11 i18n | ✅ | Este spec no añade texto visible (el joystick es gráfico) |
| P12 Presupuesto móvil | ✅ | 1 luz direccional con sombras, cielo procedural, primitivas; sin post-procesado; nada que poolear aún |
| P13 Test primero | ✅ | Lógica con test rojo primero; UI táctil cubierta por lógica pura + paso manual documentado |
| P14 Alcance | ✅ | Sin batería (003), sin HUD más allá del joystick, sin piezas (015), sin zoom |

## 7. Riesgos y alternativas descartadas

- **La cámara ortográfica puede sentirse plana** en el móvil. Mitigación: la decisión vive en `camera_rig.gd` +
  `camera.tres`; pasar a perspectiva con FOV bajo (~20°) es un cambio local que se decide en T-002-08. 
  **Descartado de inicio**: perspectiva — distorsiona bordes en pantallas altas y complica mantener "misma
  distancia aparente" (R-002-02).
- **Tests táctiles en headless no fiables** (ADR 0002): no se simulan clics; la lógica se prueba pura y el
  gesto real en el móvil. Riesgo residual: un fallo de cableado señal→input solo se vería manual; lo cubre el
  paso manual de T-002-08 antes de cerrar.
- **Descartado (2026-11-14)**: `emulate_touch_from_mouse` — es un ajuste global que convertiría todos los
  clics del juego en toques. En su lugar, el flag debug hace que `FloatingJoystick` acepte el botón izquierdo
  del ratón como si fuera un toque, acotado al propio control.
- **Descartado (2026-11-14)**: el nodo nativo `VirtualJoystick` de Godot 4.7 (descubierto en T-002-07 porque
  ocultaba el `class_name`). Empuja acciones del InputMap con `deadzone_ratio`/`clampzone_ratio`, pero no puede
  expresar la histéresis de correr 80/70 (R-002-16): teclado y joystick compartirían las mismas acciones y una
  tecla (fuerza 1.0) activaría correr sin Shift. La clase propia pasa a llamarse `FloatingJoystick`.
- **Spec 001 sin fusionar**: la rama `feat/002-…` debe nacer de `main` ya con el spec 001 dentro (README §5);
  si no, heredaría una base sin proyecto Godot. T-002-00 lo bloquea explícitamente.
- **Descartado**: histéresis del correr dentro de `PlayerInput` — mezclaría estado de dos fuentes; vive en
  `JoystickLogic` (joystick) y en la acción `run` (teclado), y `PlayerInput` solo funde.
- **Descartado**: `GridMap` para el suelo (ACTION_PLAN 0.2 lo menciona como opción) — un `MeshInstance3D` plano
  basta para una zona vacía; `GridMap` se valorará con las zonas reales (spec 004).
