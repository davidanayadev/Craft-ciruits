# Movimiento y cámara

> Cómo el robot se mueve en la escena isométrica: entrada unificada (teclado y joystick táctil), reglas puras de
> marcha y la cámara que lo sigue.
> Specs: [002](../../specs/002-iso-scene-player-movement/spec.md), [007](../../specs/007-melee-combat/spec.md)
> (entrada de ataque y sacudida de cámara), [009](../../specs/009-base-placement-charging/spec.md) (motivos de
> bloqueo, `place_at`), [015](../../specs/015-pieces-slots-degradation/spec.md) (velocidades de las piernas como stats) ·
> Última actualización: spec 015

## Piezas

| Pieza | Tipo | Archivo | Responsabilidad |
|---|---|---|---|
| `Robot` | CharacterBody3D | `game/scenes/entities/robot.gd` | Lee la entrada, aplica `LocomotionSystem`, mueve con física |
| `PlayerInput` | nodo | `game/scripts/components/player_input.gd` | Única fuente de entrada: teclado o joystick; se puede bloquear |
| `JoystickLogic` | sistema puro | `game/scripts/systems/joystick_logic.gd` | Zona muerta, umbral de correr con histéresis, `Sample` |
| `FloatingJoystick` | Control | `game/scenes/ui/floating_joystick.gd` | Eventos táctiles, aparece donde se toca; emite muestras |
| `TouchControls` | CanvasLayer | `game/scenes/ui/touch_controls.gd` | Decide si se muestra la UI táctil |
| `LocomotionSystem` | sistema puro | `game/scripts/systems/locomotion_system.gd` | Dirección relativa a cámara, marcha, velocidad, giro |
| `MovementStatsData` | Resource (objeto de valor) | `game/scripts/data/movement_stats_data.gd` | Velocidades y si puede correr; lo construye `StatsComponent.get_movement()`, sin `.tres` ([stats.md](stats.md)) |
| `ControlConfigData` | Resource | `game/scripts/data/control_config_data.gd` | Umbrales del joystick y giro (`resources/config/controls.tres`) |
| `CameraRig` | Node3D | `game/scenes/camera/camera_rig.gd` | Aplica la config, sigue al objetivo y sacude (`shake()`, spec 007) |
| `CameraConfigData` | Resource | `game/scripts/data/camera_config_data.gd` | Ángulos, distancia y tamaño ortográfico (`resources/config/camera.tres`) |

## Cómo funciona

1. **Entrada**. En PC, `PlayerInput.get_direction()` devuelve `Input.get_vector(move_left, move_right,
   move_forward, move_back)` y `is_run_intent()` mira la acción `run`. En táctil, `FloatingJoystick` convierte el
   toque en un `JoystickLogic.Sample` y emite `sample_changed`; `Main` lo pasa a
   `PlayerInput.set_joystick_sample()`. Mientras la muestra esté activa gana al teclado; `released` la limpia.
2. **Joystick**. Solo agarra toques de la mitad izquierda y solo sigue a un dedo (el resto se ignoran). Por debajo
   de la zona muerta no hay muestra activa. Correr empieza al superar el umbral de correr y termina al bajar del
   umbral de volver a andar (histéresis; `was_running` lo guarda el joystick). La dirección es analógica pero
   normalizada: la velocidad no depende de cuánto se empuja.
3. **UI táctil**. `TouchControls` se muestra si `DisplayServer.is_touchscreen_available()` o si
   `force_touch_debug` es true; con esa opción el botón izquierdo del ratón hace de dedo.
4. **Cada frame de física** (`Robot._physics_process`):
   1. Si se acaba de pulsar `interact`, `request_interact()`.
   2. `LocomotionSystem.world_direction(entrada, yaw de la cámara)` rota la dirección al marco del mundo.
   3. `LocomotionSystem.horizontal_velocity(...)` da velocidad fija: andar, correr (si hay intención y
      `can_run`) o cero. Los valores son `Robot._movement`, el `MovementStatsData` del último `stats_changed`
      (spec 015): con Piernas equipadas, sus velocidades; sin ellas, la velocidad sin piernas y nunca corre
      (`can_run` es `run_speed > 0`).
   4. `battery.tick(delta, LocomotionSystem.gait(...))`: la marcha sale de la intención, no del desplazamiento
      real ([battery.md](battery.md)).
   5. Si hay dirección, `rotate_toward_yaw` gira por el arco corto sin pasarse de `turn_speed_rad * delta`.
   6. `move_and_slide()`.
5. **Cámara**. `CameraRig` aplica `CameraConfigData` en `_ready()` (ortográfica, `size`, rotación Y y X, posición a
   `distance` del origen) y en cada `_physics_process` copia la posición global del `target`. `Main` asigna
   `robot.camera_rig` y `camera_rig.target`. `shake(strength_m, duration_s)` desplaza la cámara con
   `h_offset`/`v_offset` en el plano de la pantalla, sin tocar la posición que sigue al robot; la fuerza baja
   lineal a 0 y una sacudida nueva solo sustituye a la actual si no es más débil. Usa un RNG propio de semilla fija
   y solo procesa mientras sacude. Quien la pide es `CombatFeedback` ([combat.md](combat.md)).
6. **Ataque** (spec 007). `Robot` llama una vez por paso a `PlayerInput.poll_attack()` y se lo pasa a
   `melee.tick()` ([combat.md](combat.md)). `poll_attack()` devuelve `true` si la acción `attack` se mantiene, si el
   botón del HUD se mantiene o si hubo una pulsación desde la última llamada (así un toque más corto que un paso de
   física no se pierde; una pulsación durante la espera no se guarda). Con la entrada bloqueada devuelve `false`.

7. **Bloqueo por motivos** (spec 009). `PlayerInput.set_input_blocked(blocked, reason)` con `REASON_SCREEN`
   (`UIManager`), `REASON_DEATH` (muerte) y `REASON_TRAVEL` (viaje). Cada dueño enciende y apaga solo el suyo; la
   entrada queda bloqueada mientras haya alguno activo (`is_input_blocked()`). `blocked_changed(blocked)` se emite solo
   cuando "algún motivo" cambia: añadir un segundo motivo o quitar uno de dos no emite. Un motivo vacío es `push_error`.
   El `Hud` lo escucha para ocultar el botón Interact ([ui.md](ui.md)).
8. **Colocarse.** `Robot.place_at(posición)` pone al robot en un punto, quieto; es como llega a cada zona
   ([travel.md](travel.md)) y lo usa también `respawn_at`.

## Datos

| Recurso | Clase | Valores en |
|---|---|---|
| `resources/robot/robot_base_stats.tres` y `PieceData.modifiers` de las piernas | `RobotBaseStatsData`, `StatModifier` | `BALANCE.md` §4.2 ([stats.md](stats.md)) |
| `resources/config/controls.tres` | `ControlConfigData` | `BALANCE.md` §11 (el alcance de interacción es de la spec 004) |
| `resources/config/camera.tres` | `CameraConfigData` | `BALANCE.md` §11 |

El consumo al caminar es el stat `walk_drain`, que `Robot` entrega a la batería ([battery.md](battery.md)). El radio del joystick (en
píxeles) es de layout de UI, no de balance.

## Decisiones

| Decisión | Por qué | Fuente |
|---|---|---|
| Joystick flotante en la mitad izquierda | Decisión cerrada nov 2026 | [R-002-10](../../specs/002-iso-scene-player-movement/spec.md) |
| Velocidad fija por tramo, dirección analógica | Decisión cerrada nov 2026 | [R-002-17](../../specs/002-iso-scene-player-movement/spec.md) |
| El gameplay lee solo `PlayerInput`, nunca eventos | Constitución P8: no mirar el dispositivo | R-002-13 |
| Reglas de movimiento en una clase pura sin Node | Testeable y reutilizable por un anfitrión | [constitución P3](../../specs/constitution.md), comentario de `locomotion_system.gd` |
| El ataque no se lee de `Input.is_action_pressed(&"attack")`, sino de `_unhandled_input` y del botón del HUD | El estado de la acción cambia **antes** de que la GUI reparta el evento: un clic izquierdo en un botón del HUD (la acción `attack` incluye el ratón) contaría como golpe | R-007-15, [plan 007 §1](../../specs/007-melee-combat/plan.md) "Input" |
| Una sola regla de "correr" (`gait`) | Velocidad y drenaje de batería no pueden discrepar | Comentario de `locomotion_system.gd` |
| Cámara ortográfica que sigue rígidamente | La zona de 50x50 m no cabe en pantalla | R-002-02 |
| Todos los números en `.tres` | Constitución P2, P5 | R-002-14 |
| Las velocidades salen de `StatsComponent`; `Robot` las guarda en `_movement` | Movimiento no mira piezas | R-015-14, [plan 015 D5](../../specs/015-pieces-slots-degradation/plan.md) |
| Sin piernas es `run_speed = 0`, y `can_run` se deriva | Un `MULTIPLY` futuro sobre 0 sigue sin correr | R-015-15, [plan 015 D2](../../specs/015-pieces-slots-degradation/plan.md) |

## Relación con otros sistemas

Usa: [foundation.md](foundation.md) (acciones del InputMap). Lo usan: [battery.md](battery.md) (la marcha),
[interaction.md](interaction.md) (`request_interact`, alcance), [ui.md](ui.md) (`UIManager` bloquea la entrada
con `set_input_blocked`; el botón de atacar llama a `set_attack_button_held`), [enemies.md](enemies.md) (grupo
`players` del robot), [combat.md](combat.md) (`poll_attack`, `shake`), [death.md](death.md) (bloquea la entrada
y suelta el joystick durante la transferencia).

## Trampas y límites

- Con la entrada bloqueada `PlayerInput` no da dirección, correr ni interactuar, pero el robot sigue procesando:
  la batería sigue drenando (salvo durante un viaje o una muerte, que además congelan `World`).
- Un nuevo dueño del bloqueo debe usar su propio motivo: pasar el de otro puede levantarle el bloqueo.
- Mientras la colocación está abierta (incluido `EDIT_PICK`) el robot no se mueve: es una pantalla de `UIManager`.
- `force_touch_debug` es un flag exportado del nodo `TouchControls`; la UI táctil solo se oculta si no hay pantalla
  táctil y el flag está apagado.
- Si falta `config` en `CameraRig` solo se registra error; si falta `camera_rig` en `Robot` se usa el yaw 0.
- Un evento de ratón emulado desde un toque (`device = -1`) no casa con la acción `attack` (la del ratón es
  `device = 32`), así que tocar el joystick o el escenario en Android no es un golpe
  ([plan 007 §5.1](../../specs/007-melee-combat/plan.md), punto 1).
- Con `force_touch_debug` el clic izquierdo mueve el joystick y también golpea: `FloatingJoystick` no marca el
  evento como gestionado (plan 007 §7). Solo en depuración.
- `FloatingJoystick.cancel()` (spec 008) suelta el dedo que sigue, para cuando algo tapa la pantalla.
- Un mundo nuevo empieza con Piernas básicas equipadas; sin ellas el robot anda a la velocidad sin piernas y no corre
  ([equipment.md](equipment.md)).
- No hay salto, esquiva ni agacharse (agacharse es v1.1, SPECS §30).
- Los ajustes del jugador (sensibilidad del joystick) aún no existen; llegan con ACTION_PLAN 4.2.

## Cómo extenderlo

- **Otras piernas**: nueva `PieceData` de ranura `LEGS` con sus `StatModifier` (cifras antes a `BALANCE.md` §4.2);
  ver [stats.md](stats.md).
- **Otra sensación de control o de cámara**: editar `controls.tres` o `camera.tres` tras actualizar `BALANCE.md` §11.
- **Nueva fuente de entrada** (mando): alimentar `PlayerInput`; no leer eventos en el gameplay.

## Tests

| Archivo | Verifica |
|---|---|
| `game/tests/unit/test_locomotion_system.gd` | Dirección relativa a cámara, velocidades, sin piernas, giro, marcha |
| `game/tests/unit/test_joystick_logic.gd` | Zona muerta, histéresis de correr, límite de radio, dirección |
| `game/tests/unit/test_floating_joystick.gd` | Mitad izquierda, un solo dedo, liberación, UI táctil y debug |
| `game/tests/unit/test_player_input.gd` | Bloqueo de entrada (joystick, teclado, interactuar), motivos independientes y `blocked_changed`, `poll_attack` (pulsación no encolada, evento no gestionado, ratón emulado, sin quedarse pegado) |
| `game/tests/unit/test_camera_rig.gd` | Sacudida: desplaza, no supera la fuerza, vuelve a 0, gana la más fuerte |
| `game/tests/unit/test_movement_resources.gd` | Controles y cámara contra BALANCE |
| `game/tests/integration/test_robot_equipment.gd` | Con piernas anda y corre; sin ellas anda lento y nunca corre (R-015-15) |
| `game/tests/integration/test_robot_movement.gd` | Capsule, andar por InputMap, parada sin deslizar, obstáculo |
