# Plan 007 — Combate cuerpo a cuerpo y XP por muerte

| Campo | Valor |
|---|---|
| **Spec** | [spec.md](spec.md) (debe estar *Aprobado*) |
| **Estado** | Planificado (2026-11-16) |

## 1. Enfoque

**Capas (architecture §3).**

| Capa | Piezas |
|---|---|
| Datos | `AttackStatsData` (daño, golpes/s, coste), `CombatConfigData` (hitbox e impacto), `CombatFeedbackData` (destellos y sacudidas), `EnemyData.xp_reward` |
| Sistemas | `CombatSystem`: reglas puras de cuándo puede empezar un golpe, cuándo llega el impacto y cuánto daña. Sin nodos ni autoloads |
| Componentes | `MeleeAttackComponent` (en el robot): estado del golpe y hitbox. `HurtboxComponent` (en el enemigo): lo que el hitbox detecta, recuerda al último atacante. `ExperienceComponent` (en el robot): dueño único de la XP. `HitFlashComponent` (en el enemigo): destello blanco |
| Entidades | `Robot`: lee el input, cobra la batería, anima, escucha `enemy_killed`. `Zombie`: hurtbox, destello, emite `enemy_killed` |
| Presentación | `AttackButton` y `DamageFlash` en el HUD, sacudida en `CameraRig`, `ImpactSparks` (partículas con pool), `CombatFeedback` (cableado del feedback), XP en `DebugHud` |
| Autoload | `EventBus`, nuevo, solo con `enemy_killed` (architecture §5 y §7 ya lo listan) |

**El golpe (R-007-06 a 14).**
- El robot llama en cada paso de física a `melee.tick(delta, wants_to_swing, battery_depleted, input_blocked)`, igual
  que hace con `battery.tick`. El componente no tiene `_physics_process` propio, así que el ritmo se testea con
  `delta` a mano (P3).
- Estado: `_seconds_since_swing` (empieza en `INF`, así el primer golpe sale al instante) y `_impact_pending`.
- En cada `tick`, en este orden:
  1. Suma `delta`.
  2. Si hay impacto pendiente y `CombatSystem.impact_reached(antes, después, config.impact_time_s)`, aplica el impacto
     (abajo) y lo marca hecho.
  3. Si `wants_to_swing` y `CombatSystem.can_start_swing(_seconds_since_swing, attack, battery_depleted,
     input_blocked)`, empieza un golpe: pone el contador a 0, marca el impacto pendiente, activa el hitbox y emite
     `swing_started(attack.battery_cost)`.
- `can_start_swing` es `true` solo si la batería no está agotada, el input no está bloqueado y han pasado
  `1 / attacks_per_second` segundos desde el último inicio. Una pulsación antes de eso no hace nada y no se guarda
  (R-007-07). La comparación usa `CombatSystem.TIME_EPSILON` (técnico, `1e-6`), para que 60 pasos de `1/60` den un
  golpe exacto por segundo y no uno cada 61 pasos por el redondeo.
- Un golpe ya empezado termina aunque se abra una pantalla o se agote la batería: el coste ya está pagado. R-007-09
  solo impide **empezar**.
- **Coste (R-007-10).** El robot conecta `swing_started` y llama a `battery.consume(battery_cost)`, acierte o no. Si
  eso vacía la batería, salta el game over provisional de la 003 (pregunta 12).
- **Animación (R-007-06).** El robot reinicia su animación `attack` en `swing_started`. La animación es solo
  presentación (placeholder: la "nariz" avanza y vuelve). El momento del impacto sale de `CombatConfigData`, no de la
  animación.
- **Sin auto-apuntado (R-007-13) y con movimiento libre (R-007-14).** El golpe no toca la rotación del robot. El
  hitbox es hijo del robot, así que gira con él. El robot mueve y gira primero y después llama a `melee.tick`; la
  consulta del impacto usa la transformación global de ese momento, así que el hitbox mira hacia donde mira el robot
  en ese mismo paso.

**Hitbox (R-007-11, 12).**
- `MeleeAttackComponent extends Node3D`, hijo del robot. En `_ready` crea en código su `BoxShape3D`, como
  `InteractorComponent` crea su esfera, así ninguna instancia comparte la forma: ancho (X) y alcance (Z) de
  `CombatConfigData`, centrada en `z = -reach / 2` (el robot mira a `-Z`, `LocomotionSystem.target_yaw`). La caja va
  del centro del robot hasta 2.0 m por delante.
- El **alto** de la caja y su altura sobre el suelo no son de gameplay: es geometría de colisión que cubre el cuerpo
  del robot, con el mismo criterio que el radio del agente de navegación de la 006. Son dos `@export` del componente
  fijados en `robot.tscn` (2.0 m, centrada a 1.0 m, como la cápsula del robot); no van a BALANCE.
- **Activo solo en el impacto.** En el paso del impacto el componente hace una consulta instantánea
  `PhysicsDirectSpaceState3D.intersect_shape` con su caja y su transformación global de ese paso (verificar 4):
  `collision_mask` = solo la capa nueva `hurtbox` (3), `collide_with_areas = true`, `collide_with_bodies = false`. El
  robot no tiene hurtbox; las cajas de loot están en la capa 2 y el escenario en la 1. Así el hitbox **solo ve
  enemigos** por construcción y no existe fuera del impacto. Lo que no es `HurtboxComponent` se ignora.
- Por qué no un `Area3D` encendido al empezar el golpe (lo que sugiere ACTION_PLAN 1.4): sus solapes se calculan en
  el paso del servidor de física, después de `_physics_process`, así que en el impacto reflejarían la orientación del
  paso anterior (unos 10° con el giro de 10 rad/s). La consulta es exacta y no necesita encender ni apagar nada. El
  requisito R-007-12 se cumple igual.
- `apply_impact(targets)` aplica `CombatSystem.damage_per_hit(attack)` **una vez** a cada hurtbox distinto y vivo,
  con `receive_attack(damage, attacker_uid)`, y emite `hit_dealt(target)` por cada uno. Es público para testear la
  regla sin física.

**Muerte, `killer_uid` y XP (R-007-17 a 23).**
- `HurtboxComponent extends Area3D` (capa `hurtbox`, `monitorable`, sin `monitoring`) con `@export var health:
  HealthComponent`. `receive_attack(damage, attacker_uid)` guarda el uid como último atacante, llama a
  `health.take_damage(damage)` y emite `hurt(damage, attacker_uid)`. La firma de `take_damage` no cambia (pregunta
  8). Mismo patrón que `InteractableComponent`/`InteractorComponent`, y sirve tal cual para el robot hostil (spec 016).
- `Zombie` conecta `health.died`: si el hurtbox tiene último atacante, emite
  `EventBus.enemy_killed(data.id, uid)`. `died` sale una vez por vida (spec 006), así que el evento también
  (R-007-17). Una muerte sin atacante (no existe aún) no emite nada.
- `Robot.player_uid` se genera en `_ready` con `Uid.generate()`: 128 bits aleatorios en hexadecimal
  (architecture §10.3, `scripts/util/uid.gd`, que architecture §4 ya prevé). La spec 010 lo sustituirá por el
  `player_uuid` del Perfil (R-007-18).
- `ExperienceComponent` guarda el total (`int`, empieza en 0). `add_xp` rechaza negativos. `reward_kill(enemy_id,
  killer_uid, owner_uid, catalog)`: si el asesino no es el dueño, no hace nada; si `catalog.has_enemy(id)` es
  `false`, un solo `push_error` con contexto y nada cambia (no llama a `get_enemy`, que daría un segundo error); si no, `add_xp(enemy.xp_reward)`. El catálogo llega por parámetro, así el
  componente se testea con catálogos hechos a mano y no lee autoloads (R-007-19 a 21).
- El robot conecta `EventBus.enemy_killed` y pasa `DataRegistry.get_catalog()` y su `player_uid`. Con varios robots,
  cada uno suma solo sus muertes (cooperativo).
- **Reutilización (R-007-23).** `Zombie.activate` ya reinicia la vida. Añade `hurtbox.reset()` (olvida al último
  atacante) y `hit_flash.clear()`.

**Input (R-007-06, 07, 09, 15).**
- Problema: `Input.is_action_pressed(&"attack")` se actualiza **antes** de que la GUI reparta el evento, así que un
  clic izquierdo en "Almacén" pondría `attack` a `true`. Por eso `PlayerInput` no sondea `attack`:
  - Escucha `_unhandled_input`. Un clic que consume un botón del HUD no llega ahí (R-007-15).
  - No filtra los eventos de ratón emulados desde la pantalla táctil: no hace falta (§5.1 punto 1). El evento de
    ratón de `attack` tiene `device = 32` y un clic emulado (`device = -1`) no casa con la acción, así que tocar
    el joystick o el escenario en Android no es un golpe.
  - "Mantenido por acción" = pulsado en `_unhandled_input` **y** `Input.is_action_pressed(&"attack")`. La segunda
    condición evita que se quede pegado si la suelta llega a un control.
  - El botón del HUD llega aparte por `set_attack_button_held(held)`.
  - `poll_attack() -> bool` devuelve mantenido (acción o botón) **o** pulsado desde la última llamada, y borra esa
    marca. Así un toque más corto que un paso de física no se pierde, y una pulsación durante la espera no se
    guarda para después (R-007-07). El robot lo llama una vez por paso.
  - Con el input bloqueado devuelve `false` (R-007-09).
- Todo esto vive en la capa de input/UI (P8). El gameplay sigue sin leer eventos ni teclas.

**HUD (R-007-16, 25).**
- `AttackButton extends Button`, abajo a la derecha, grande, `focus_mode = NONE`, texto `HUD_ATTACK` (se traduce
  solo). Visible en PC y en móvil. Emite `held_changed(held)` con `button_down`/`button_up`. El HUD lo reemite como
  `attack_held_changed(held)` y `main.gd` lo conecta a `PlayerInput.set_attack_button_held`.
- **Multitáctil.** Lo normal es mover con un dedo y golpear con otro. En 4.7.2 `BaseButton` responde al toque de
  cualquier dedo (§5.1 punto 2), así que `AttackButton` solo usa `button_down`/`button_up` y no sigue su propio
  toque.
- El botón está siempre visible, como pide R-007-16. Con una pantalla abierta el robot no golpea porque
  `poll_attack()` devuelve `false` (R-007-09). Si el botón sigue pulsado cuando se oculta el HUD o se pierde el toque,
  emite `held_changed(false)`. El botón "Interactuar" sube por encima del de atacar; su anclaje abajo a la derecha no
  cambia.
- `DamageFlash extends TextureRect` (hijo del HUD): borde rojo con un `GradientTexture2D` radial, `mouse_filter =
  IGNORE`. `flash(duration_s)` lo enseña y lo desvanece. Solo procesa mientras dura, así que `Hud` sigue sin
  `_process` (test R-003-11).

**Feedback (R-007-24 a 27).**
- `CombatFeedback` (nodo de `main.tscn`) es el único sitio que conecta el feedback del jugador local. `bind(robot,
  camera_rig, hud)`:
  - `robot.melee.hit_dealt` → sacudida "al golpear" y chispas en el objetivo.
  - `robot.hit_received` → sacudida "al recibir" y `hud.flash_damage(...)`.
  - Lee los valores de `CombatFeedbackData`. Solo llama a métodos de presentación: nunca a batería, vida ni XP
    (R-007-26).
- `CameraRig.shake(strength_m, duration_s)` desplaza la cámara con `h_offset`/`v_offset` (verificar 7), en el plano
  de la pantalla, sin tocar la posición que sigue al robot. La fuerza baja lineal hasta 0 al acabar. Una sacudida
  nueva sustituye a la actual salvo que a la actual le quede más fuerza. La dirección sale de un
  `RandomNumberGenerator` propio con semilla fija (presentación, P9 no aplica, pero el test de RNG global sigue en
  verde). Solo procesa mientras sacude.
- `HitFlashComponent` (en el zombie): pone un material blanco sin sombreado en `material_overlay` de sus mallas
  durante `enemy_flash_s` (verificar 6). El material es un `.tres` compartido. Se dispara con `hurtbox.hurt`.
- `ImpactSparks` (`scenes/effects/impact_sparks.tscn`): `Node3D` con un emisor de una sola vez, `play()` y
  `finished(sparks)`. Sale de `%ImpactPool` (`ObjectPool` bajo `World`) y vuelve a él al acabar, con
  `call_deferred`. `main.gd` lo precalienta con el `enemy_count_max` de la zona: como mucho una chispa por enemigo
  y golpe, y duran menos que un golpe. Si faltan, el pool crea más.
- **Partículas (pregunta 10).** Se parte de `GPUParticles3D`, como piden el spec y ACTION_PLAN 1.4. T-007-01 mira
  en la documentación sus límites en Compatibility y T-007-16 la prueba en el Android. **Regla:** se queda
  `GPUParticles3D` si funciona en Compatibility, no hay tirón visible en el primer impacto (compilación del shader) y
  los FPS de R-007-29 se mantienen ≥ 30; si falla cualquiera de las tres, `CPUParticles3D`. Cambiar de una a otra es
  solo cambiar el nodo dentro de `impact_sparks.tscn`; `play()` y `finished` no cambian.

**XP en el HUD de depuración (R-007-22).** `DebugHud.bind(player)` conecta `experience.xp_changed` y pinta
`XP: n` bajo los FPS. Es solo de depuración, así que no se traduce (como `FPS`).

**Alternativas descartadas.**
- **Sondear `Input.is_action_pressed(&"attack")`.** Un clic en cualquier botón del HUD sería un golpe (R-007-15).
- **`Area3D` con `monitoring` encendido durante el golpe.** Sus solapes van un paso de física por detrás de la
  orientación del robot (§1 "Hitbox"). Queda como plan B si `intersect_shape` falla en la verificación 4, aceptando
  ese paso de retraso y escribiendo el test R-007-14 con esa tolerancia; no cambia ningún contrato.
- **Impacto con una pista de método en la animación.** Ataría un número de gameplay a la presentación y necesitaría
  árbol de escena para testear el ritmo.
- **Cambiar `take_damage(amount, attacker_uid)`.** La pregunta 8 lo descarta: `HealthComponent` no sabe de jugadores.
- **Destello con `health_changed`.** También salta con `reset` y `heal`. `hurtbox.hurt` es exacto.
- **XP en un autoload o en `GameManager`.** Contra P4 y PMV §4.5 gancho 7.
- **El HUD conecta `hit_received` en `bind()`.** Repartiría los valores de feedback entre dos sitios. `CombatFeedback`
  los tiene todos.

## 2. Archivos

| Archivo (`game/…`) | Nuevo / Cambia | Responsabilidad |
|---|---|---|
| `scripts/data/attack_stats_data.gd` | Nuevo | Daño, golpes/s y coste por golpe (BALANCE §4.2) |
| `scripts/data/combat_config_data.gd` | Nuevo | Alcance, ancho y momento del impacto (BALANCE §11 "Combate") |
| `scripts/data/combat_feedback_data.gd` | Nuevo | Destello, sacudidas y borde rojo (BALANCE §11 "Combate") |
| `scripts/data/enemy_data.gd` | Cambia | `xp_reward` |
| `scripts/systems/combat_system.gd` | Nuevo | Reglas puras del golpe |
| `scripts/components/melee_attack_component.gd` | Nuevo | Estado del golpe y hitbox |
| `scripts/components/hurtbox_component.gd` | Nuevo | Recibe golpes, recuerda al último atacante |
| `scripts/components/experience_component.gd` | Nuevo | XP total del jugador |
| `scripts/components/hit_flash_component.gd` | Nuevo | Destello blanco de una entidad |
| `scripts/components/player_input.gd` | Cambia | Ataque por eventos no gestionados, botón del HUD, `poll_attack` |
| `scripts/autoload/event_bus.gd` | Nuevo | `enemy_killed` |
| `scripts/util/uid.gd` | Nuevo | `Uid.generate()` |
| `scenes/entities/robot.gd` + `robot.tscn` | Cambia | `%MeleeAttack` con su caja, `%Experience`, `%AnimationPlayer` con `attack`, `player_uid`, cableado |
| `scenes/entities/zombie.gd` + `zombie.tscn` | Cambia | `%Hurtbox`, `%HitFlash`, `enemy_killed`, reinicio al reutilizar |
| `scenes/camera/camera_rig.gd` | Cambia | `shake()` |
| `scenes/effects/impact_sparks.tscn` + `impact_sparks.gd` | Nuevo | Chispas de un solo disparo |
| `scenes/feedback/combat_feedback.gd` | Nuevo | Conecta el feedback del jugador local |
| `scenes/ui/attack_button.gd` | Nuevo | Botón de mantener, multitáctil |
| `scenes/ui/damage_flash.gd` | Nuevo | Borde rojo |
| `scenes/ui/hud.gd` + `hud.tscn` | Cambia | `%AttackButton`, `%DamageFlash`, `attack_held_changed`, `flash_damage`, "Interactuar" más arriba |
| `scenes/ui/debug_hud.gd` + `debug_hud.tscn` | Cambia | `bind()` y `%XpLabel` |
| `scenes/main.gd` + `main.tscn` | Cambia | `%CombatFeedback`, `World/ImpactPool`, `%DebugHud`, cableado del botón de atacar |
| `resources/combat/one_arm.tres`, `basic_arms.tres` | Nuevo | BALANCE §4.2 |
| `resources/config/combat.tres`, `combat_feedback.tres` | Nuevo | BALANCE §11 "Combate" |
| `resources/materials/hit_flash.tres` | Nuevo | Material blanco sin sombreado del destello |
| `resources/enemies/zombie_slow.tres`, `zombie_fast.tres` | Cambia | `xp_reward` (BALANCE §3.1, §6.2) |
| `project.godot` | Cambia | Autoload `EventBus` (el primero) y `layer_names/3d_physics/layer_3="hurtbox"` |
| `i18n/strings.csv` | Cambia | `HUD_ATTACK` (ES + EN) |
| `tests/unit/test_combat_resources.gd` | Nuevo | R-007-01, 04, 05 |
| `tests/unit/test_enemy_resources.gd` | Cambia | R-007-03 |
| `tests/unit/test_combat_system.gd` | Nuevo | R-007-07, 08, 09 (lógica) |
| `tests/unit/test_hurtbox_component.gd` | Nuevo | R-007-11, 12, 17 (componente) |
| `tests/unit/test_experience_component.gd` | Nuevo | R-007-19 a 21 |
| `tests/unit/test_melee_attack_component.gd` | Nuevo | R-007-04, 06, 07, 10, 11, 13 (componente) |
| `tests/unit/test_player_input.gd` | Cambia | R-007-07, 09, 15 (input) |
| `tests/unit/test_uid.gd` | Nuevo | R-007-18 (formato) |
| `tests/unit/test_event_bus.gd` | Nuevo | R-007-17 (contrato), R-007-19 (sin estado) |
| `tests/unit/test_hit_flash_component.gd` | Nuevo | R-007-24 (destello), R-007-23 (limpio) |
| `tests/unit/test_camera_rig.gd` | Nuevo | R-007-24, 25 (sacudida) |
| `tests/unit/test_hud.gd` | Cambia | R-007-16, 25 (borde) |
| `tests/unit/test_debug_hud.gd` | Nuevo | R-007-22 |
| `tests/unit/test_project_settings.gd` | Cambia | Autoload `EventBus` y nombre de la capa `hurtbox` |
| `tests/integration/test_robot_combat.gd` | Nuevo | R-007-02, 06, 09 a 14, 18, 20 con física |
| `tests/integration/test_zombie.gd` | Cambia | R-007-17, 23, 24 (zombie) |
| `tests/integration/test_combat_feedback.gd` | Nuevo | R-007-24 a 27 |
| `tests/integration/test_hud_attack_input.gd` | Nuevo | R-007-15 (clic en el HUD, verificar 3) |
| `tests/integration/test_main_scene.gd` | Cambia | R-007-28 (cableado del bucle) |

## 3. Contratos

```gdscript
class_name AttackStatsData
extends Resource
@export var damage: int                       # HP per hit
@export var attacks_per_second: float
@export var battery_cost: float               # battery points per swing, hit or miss

class_name CombatConfigData
extends Resource
@export var hitbox_reach_m: float             # box depth in front of the robot
@export var hitbox_width_m: float
@export var impact_time_s: float              # from swing start; < 1 / attacks_per_second

class_name CombatFeedbackData
extends Resource
@export var enemy_flash_s: float
@export var hit_dealt_shake_m: float
@export var hit_dealt_shake_s: float
@export var hit_received_shake_m: float
@export var hit_received_shake_s: float
@export var screen_edge_flash_s: float

# EnemyData (added)
@export var xp_reward: int = 0                # BALANCE §3.1, §6.2

class_name CombatSystem
extends RefCounted
const TIME_EPSILON := 1e-6                    # float accumulation of physics steps, not gameplay
static func is_valid_attack(attack: AttackStatsData) -> bool          # damage > 0, attacks_per_second > 0, cost >= 0
static func swing_interval(attack: AttackStatsData) -> float          # 1 / attacks_per_second
static func can_start_swing(
	seconds_since_swing: float, attack: AttackStatsData, battery_depleted: bool, input_blocked: bool
) -> bool
static func impact_reached(seconds_before: float, seconds_after: float, impact_time_s: float) -> bool
static func damage_per_hit(attack: AttackStatsData) -> int

class_name MeleeAttackComponent
extends Node3D
signal swing_started(battery_cost: float)
signal hit_dealt(target: HurtboxComponent)
@export var attack: AttackStatsData           # one_arm.tres until spec 015 (R-007-02)
@export var config: CombatConfigData
@export var hitbox_height_m: float            # collision geometry covering the robot body, not gameplay
@export var hitbox_center_y_m: float
var attacker_uid: String = ""                 # set by the owner
func tick(delta: float, wants_to_swing: bool, battery_depleted: bool, input_blocked: bool) -> void
func apply_impact(targets: Array[HurtboxComponent]) -> void           # once per distinct living target
func is_impact_pending() -> bool
# Read-only helpers added during implementation, used by apply_impact's caller and by the tests:
func find_targets() -> Array[HurtboxComponent]                        # hurtboxes inside the box right now
func build_query() -> PhysicsShapeQueryParameters3D                   # the impact query (mask, areas only)
func get_hitbox_transform() -> Transform3D
func get_hitbox_shape() -> BoxShape3D

class_name HurtboxComponent
extends Area3D
const PHYSICS_LAYER := 3                      # "hurtbox" in project.godot; the only place the number lives
signal hurt(damage: int, attacker_uid: String)
@export var health: HealthComponent
func receive_attack(damage: int, attacker_uid: String) -> void        # < 0 → push_error; dead → nothing
func is_alive() -> bool
func get_last_attacker_uid() -> String        # "" when nobody hit it in this life
func reset() -> void

class_name ExperienceComponent
extends Node
signal xp_changed(total: int)
func add_xp(amount: int) -> void              # < 0 → push_error, no change; 0 → no signal
func reward_kill(enemy_id: StringName, killer_uid: String, owner_uid: String, catalog: DataCatalog) -> void
func get_total() -> int

class_name HitFlashComponent
extends Node
@export var meshes: Array[GeometryInstance3D] = []
@export var material: Material                # resources/materials/hit_flash.tres
@export var feedback: CombatFeedbackData
func flash() -> void
func clear() -> void
func is_flashing() -> bool
func advance(delta: float) -> void            # called by _process while flashing

# EventBus (autoload, no class_name)
signal enemy_killed(enemy_id: StringName, killer_uid: String)

class_name Uid
extends RefCounted
static func generate() -> String              # 32 lowercase hex chars (128 bits)

# PlayerInput (added)
func set_attack_button_held(held: bool) -> void
func poll_attack() -> bool                    # held, or pressed since the last poll; clears the press; false while blocked

# Robot (added)
var player_uid: String                        # Uid.generate() in _ready; spec 010 uses the Profile's player_uuid
@onready var melee: MeleeAttackComponent      # %MeleeAttack
@onready var experience: ExperienceComponent  # %Experience

# Zombie (added)
func get_hurtbox() -> HurtboxComponent

class_name CameraRig  # (added)
func shake(strength_m: float, duration_s: float) -> void
func is_shaking() -> bool
func advance_shake(delta: float) -> void      # called by _process while shaking

class_name AttackButton
extends Button
signal held_changed(held: bool)

class_name DamageFlash
extends TextureRect
func flash(duration_s: float) -> void
func is_flashing() -> bool
func advance(delta: float) -> void

# Hud (added)
signal attack_held_changed(held: bool)
func flash_damage(duration_s: float) -> void

# DebugHud (added)
func bind(player: Robot) -> void

class_name ImpactSparks
extends Node3D
signal finished(sparks: ImpactSparks)
func play() -> void

class_name CombatFeedback
extends Node
@export var config: CombatFeedbackData
@export var impact_pool: ObjectPool
@export var effects_root: Node3D              # %World
func bind(robot: Robot, camera_rig: CameraRig, hud: Hud) -> void
```

**`EventBus`.** Nuevo autoload, el primero de la lista para que los demás puedan conectarse en su `_ready`. Solo
`enemy_killed`, que ya está en la tabla de architecture §7 ("Lo emite: Enemigo"); no hace falta cambiarla. La señal
lleva `@warning_ignore("unused_signal")`, porque se declara en el bus y se emite fuera (verificar 9). El bus no tiene
variables (un test lo comprueba).

## 4. Datos

| Recurso / `.tres` | Campos | Valores desde |
|---|---|---|
| `combat/one_arm.tres` | `damage = 5`, `attacks_per_second = 1.0`, `battery_cost = 1.0` | BALANCE §4.2 "Un brazo", §1.1 |
| `combat/basic_arms.tres` | `damage = 10`, `attacks_per_second = 1.0`, `battery_cost = 1.0` | BALANCE §4.2 "Brazos básicos", §1.1 |
| `config/combat.tres` | `hitbox_reach_m = 2.0`, `hitbox_width_m = 1.0`, `impact_time_s = 0.2` | BALANCE §11 "Combate" |
| `config/combat_feedback.tres` | `enemy_flash_s = 0.1`, `hit_dealt_shake_m = 0.05`, `hit_dealt_shake_s = 0.1`, `hit_received_shake_m = 0.15`, `hit_received_shake_s = 0.2`, `screen_edge_flash_s = 0.3` | BALANCE §11 "Combate" |
| `enemies/zombie_slow.tres` | `xp_reward = 2` | BALANCE §3.1, §6.2 |
| `enemies/zombie_fast.tres` | `xp_reward = 3` | BALANCE §3.1, §6.2 |

Valores técnicos o de presentación que viven en la escena, no en BALANCE: alto y altura de la caja del hitbox
(cubren la cápsula del robot), forma del hurtbox del zombie (la misma `CapsuleShape3D` de su cuerpo, compartida, no
copiada), número y vida de las chispas, colores del destello y del borde, tamaño y posición de los botones, y la
animación placeholder del robot. `TIME_EPSILON` es técnico. `basic_arms.tres` no lo usa nadie hasta la spec 015; existe
porque R-007-01 lo pide y su test lo valida.

## 5. Verificación

| Requisito | Test (`game/tests/…`) o paso manual |
|---|---|
| R-007-01 | `unit/test_combat_resources.gd::test_r_007_01_one_arm_matches_balance`, `test_r_007_01_basic_arms_match_balance` |
| R-007-02 | `integration/test_robot_combat.gd::test_r_007_02_robot_attacks_with_one_arm` (`melee.attack` es `one_arm.tres`) |
| R-007-03 | `unit/test_enemy_resources.gd::test_r_007_03_zombies_xp_match_balance` |
| R-007-04 | `unit/test_combat_resources.gd::test_r_007_04_combat_config_matches_balance`, `test_r_007_04_feedback_matches_balance`, `test_r_007_04_reach_beyond_zombie_attack_range` (alcance > `attack_range` de `zombie_ai.tres`), `test_r_007_04_impact_before_next_swing` (impacto < intervalo de cada `.tres` de `resources/combat/`), `test_r_007_04_no_combat_literals_in_scripts` (busca los nombres de los campos asignados a números en los scripts nuevos, como R-006-03); `unit/test_melee_attack_component.gd::test_r_007_04_hitbox_size_from_config` |
| R-007-05 | `unit/test_combat_system.gd::test_r_007_05_rejects_zero_or_negative` y `unit/test_combat_resources.gd::test_r_007_05_every_attack_file_is_valid` (recorre `resources/combat/`) |
| R-007-06 | `unit/test_melee_attack_component.gd::test_r_007_06_swing_emits_started`, `test_r_007_06_impact_after_impact_time`; `integration/test_robot_combat.gd::test_r_007_06_button_starts_swing_and_animation`, `test_r_007_06_short_tap_not_lost` |
| R-007-07 | `unit/test_combat_system.gd::test_r_007_07_interval_from_attacks_per_second`, `test_r_007_07_sixty_steps_make_one_second`; `unit/test_melee_attack_component.gd::test_r_007_07_held_swings_at_rate`, `test_r_007_07_press_during_swing_not_queued`; `unit/test_player_input.gd::test_r_007_07_poll_clears_press` |
| R-007-08 | `unit/test_combat_system.gd::test_r_007_08_*` (puede empezar, espera, batería, input bloqueado, daño), sin árbol de escena |
| R-007-09 | `unit/test_combat_system.gd::test_r_007_09_depleted_or_blocked_cannot_start`; `unit/test_player_input.gd::test_r_007_09_blocked_reports_no_attack`; `integration/test_robot_combat.gd::test_r_007_09_no_swing_when_depleted_or_screen_open` |
| R-007-10 | `unit/test_melee_attack_component.gd::test_r_007_10_started_carries_cost`; `integration/test_robot_combat.gd::test_r_007_10_swing_costs_battery_on_miss`, `test_r_007_10_swing_can_deplete_battery` |
| R-007-11 | `unit/test_melee_attack_component.gd::test_r_007_11_damages_each_living_target_once` (repetidos y muertos fuera); `unit/test_hurtbox_component.gd::test_r_007_11_receive_attack_damages_health`, `test_r_007_11_negative_reports_error`; `integration/test_robot_combat.gd::test_r_007_11_hits_every_enemy_in_box` |
| R-007-12 | `unit/test_hurtbox_component.gd::test_r_007_12_on_hurtbox_layer`; `unit/test_melee_attack_component.gd::test_r_007_12_query_masks_only_hurtboxes` (parámetros de la consulta: máscara, solo áreas); `integration/test_robot_combat.gd::test_r_007_12_ignores_robot_boxes_and_scenery` (caja de loot, `StaticBody3D` y el propio robot dentro de la caja, sin daño ni error) |
| R-007-13 | `integration/test_robot_combat.gd::test_r_007_13_no_auto_aim` (enemigo a un lado: el robot no gira y no lo golpea) |
| R-007-14 | `integration/test_robot_combat.gd::test_r_007_14_moves_while_swinging`, `test_r_007_14_hitbox_follows_facing` |
| R-007-15 | `unit/test_player_input.gd::test_r_007_15_unhandled_attack_counts`, `test_r_007_15_emulated_mouse_ignored`, `test_r_007_15_not_stuck_after_release`; `integration/test_hud_attack_input.gd::test_r_007_15_click_on_hud_button_is_not_attack` (verificar 3). Paso manual en PC: clic en "Almacén" y en "Interactuar" junto a un zombie, sin golpe ni gasto de batería |
| R-007-16 | `unit/test_hud.gd::test_r_007_16_attack_button_bottom_right_without_focus`, `test_r_007_16_attack_key_translated`, `test_r_007_16_emits_attack_held_changed`, `test_r_007_16_visible_while_modal` (sigue visible; el bloqueo lo hace `PlayerInput`). Paso manual en Android (T-007-16): golpear con el pulgar derecho mientras el izquierdo mueve el joystick |
| R-007-17 | `unit/test_hurtbox_component.gd::test_r_007_17_remembers_last_attacker`; `unit/test_event_bus.gd::test_r_007_17_enemy_killed_signature`; `integration/test_zombie.gd::test_r_007_17_enemy_killed_once_with_last_hitter` (dos uids, gana el último; golpes sobre el muerto no emiten otra vez) |
| R-007-18 | `unit/test_uid.gd::test_r_007_18_*` (32 hex, dos distintos); `integration/test_robot_combat.gd::test_r_007_18_robot_has_player_uid`, `test_r_007_18_melee_uses_player_uid` |
| R-007-19 | `unit/test_experience_component.gd::test_r_007_19_*` (empieza en 0, suma, `xp_changed` una vez); `unit/test_event_bus.gd::test_r_007_19_bus_holds_no_state` |
| R-007-20 | `unit/test_experience_component.gd::test_r_007_20_reward_from_catalog`, `test_r_007_20_other_killer_ignored`; `integration/test_robot_combat.gd::test_r_007_20_kill_adds_xp` (cadena completa: golpes del robot hasta matar un zombie lento, XP = `xp_reward` del `.tres`) |
| R-007-21 | `unit/test_experience_component.gd::test_r_007_21_negative_reports_error`, `test_r_007_21_unknown_enemy_reports_error` |
| R-007-22 | `unit/test_debug_hud.gd::test_r_007_22_shows_xp`; paso manual en PC (XP visible tras matar) |
| R-007-23 | `unit/test_hurtbox_component.gd::test_r_007_23_reset_forgets_attacker`; `unit/test_hit_flash_component.gd::test_r_007_23_clear_removes_overlay`; `integration/test_zombie.gd::test_r_007_23_reused_zombie_is_clean` (vida llena, sin destello, sin atacante) |
| R-007-24 | `unit/test_hit_flash_component.gd::test_r_007_24_*` (pone y quita el material tras `enemy_flash_s`); `unit/test_camera_rig.gd::test_r_007_24_shake_*` (desplaza, nunca más que la fuerza, vuelve a 0, la más fuerte gana); `integration/test_zombie.gd::test_r_007_24_hurt_flashes`; `integration/test_combat_feedback.gd::test_r_007_24_hit_dealt_shakes_and_sparks` |
| R-007-25 | `unit/test_hud.gd::test_r_007_25_damage_flash_shows_and_fades`; `integration/test_combat_feedback.gd::test_r_007_25_hit_received_shakes_and_flashes` |
| R-007-26 | `integration/test_combat_feedback.gd::test_r_007_26_feedback_changes_no_state` (batería, vida y XP iguales antes y después de cada señal de feedback) |
| R-007-27 | `integration/test_combat_feedback.gd::test_r_007_27_sparks_from_pool_and_back` (sale del pool y vuelve al acabar); paso manual en Android dentro de R-007-29 |
| R-007-28 | `unit/test_combat_resources.gd::test_r_007_28_one_arm_kills_both_zombies` (golpes para matar = `ceil(hp_max / damage)`, finito, desde los `.tres`); `integration/test_robot_combat.gd::test_r_007_20_kill_adds_xp` (mata de verdad); `integration/test_main_scene.gd::test_r_007_28_main_wires_combat` (botón de atacar → `PlayerInput`, `CombatFeedback` y `DebugHud` enlazados). Paso manual en PC: matar un lento (4 golpes) y un rápido (3), y dejarse matar por los zombies hasta ver el game over |
| R-007-29 | Manual en el Android de gama media (APK debug): pelear 60 s con el máximo de zombies de la zona (la semilla de 8 de T-006-14, solo en local) golpeando sin parar. FPS del `DebugHud` ≥ 30 en todo momento. Anotar en `tasks.md` dispositivo, FPS mínimo, triángulos y la elección de partículas |

**(verificar)** antes de usar, en la documentación oficial de Godot 4.7.2 (referencia de clases del binario,
`--doctool`) y con scripts de prueba en headless:

1. `InputEvent.DEVICE_ID_EMULATION`: que exista y que los eventos de ratón emulados desde la pantalla táctil lo
   lleven en `device`. Valor por defecto de `input_devices/pointing/emulate_mouse_from_touch`. Además, si el
   `"device": 32` del evento de ratón de `attack` en `project.godot` hace que un evento emulado ya no case con la
   acción: si es así, el filtro de §1 sobra y se quita; si no, se queda. No se da ninguna de las dos por supuesta.
2. Si `BaseButton` responde a un `InputEventScreenTouch` que no es el primer dedo, y si un `Control` recibe esos
   eventos en `_gui_input`. Decide cómo sigue `AttackButton` su propio toque.
3. Que `Input.parse_input_event` de un `InputEventMouseButton` en headless llegue a la GUI (el botón lo consume) y no
   a `_unhandled_input`, y en cuántos fotogramas. Si no se puede reproducir en headless, R-007-15 se queda con los
   tests de `PlayerInput` y el paso manual, sin debilitar ninguno ya escrito.
4. `PhysicsDirectSpaceState3D.intersect_shape` con `PhysicsShapeQueryParameters3D` (`shape`, `transform`,
   `collision_mask`, `collide_with_areas`, `collide_with_bodies`) llamada desde `_physics_process`: que devuelva las
   `Area3D` solapadas en `"collider"` con la transformación de ese mismo paso, incluida un área que acaba de entrar al
   árbol. Si falla, plan B: `Area3D` con un paso de retraso (§1, alternativas).
5. `GPUParticles3D` en Compatibility (qué no soporta, compilación del shader en el primer uso) frente a
   `CPUParticles3D`; `one_shot`, `restart()` y la señal `finished` en el nodo elegido.
6. `GeometryInstance3D.material_overlay` en Compatibility, con un `StandardMaterial3D` sin sombreado.
7. `Camera3D.h_offset` y `v_offset` con proyección ortográfica.
8. `Crypto.generate_random_bytes()` y `PackedByteArray.hex_encode()`; que `Uid` no choque con una clase del motor.
9. `@warning_ignore("unused_signal")` sobre una señal, y si el aviso salta en un autoload que no la emite.
10. `Script.get_script_property_list()` para el test de "el bus no guarda estado".

### 5.1 Resultado de la verificación (T-007-01, 2026-11-16)

Hecho con Godot 4.7.2 en headless (scripts de prueba fuera del repo), la referencia de clases (`--doctool`) y la
documentación oficial en línea para los puntos 5 y 6.

| # | Resultado | Consecuencia |
|---|---|---|
| 1 | `DEVICE_ID_EMULATION = -1` existe y el ratón emulado desde un toque lo lleva. `emulate_mouse_from_touch` es `true` por defecto. El evento de ratón de `attack` tiene `device = 32` (`DEVICE_ID_MOUSE`), y un evento emulado (`device = -1`) **no** casa con la acción: tras un toque, `Input.is_action_pressed(&"attack")` sigue en `false` | El filtro de ratón emulado de §1 **sobra y no se escribe**. `test_r_007_15_emulated_mouse_ignored` se queda como test de comportamiento. Los tests de ratón usan `device = 32` |
| 2 | En 4.7.2 `BaseButton` responde a un `InputEventScreenTouch` de cualquier índice: con un dedo en el joystick, el segundo dedo da `button_down`, y `button_up` al levantar ese dedo (o el otro orden). Ocultar el botón mientras está pulsado **no** emite `button_up` | `AttackButton` no sigue su propio toque: usa `button_down`/`button_up`. Emite `held_changed(false)` al dejar de ser visible estando pulsado. Se confirma en el Android en T-007-16 |
| 3 | `Input.parse_input_event` de un `InputEventMouseButton` llega a la GUI en headless: el botón lo consume en 1 fotograma y no llega a `_unhandled_input`, aunque `Input.is_action_pressed(&"attack")` pasa a `true` (el problema que describe §1). La posición va en coordenadas de ventana: `get_viewport().get_final_transform() * posición` | `integration/test_hud_attack_input.gd` se escribe tal como dice §5 |
| 4 | `intersect_shape` desde `_physics_process` devuelve las `Area3D` en `"collider"`, con la transformación pasada en ese mismo paso (también girada), incluida un área que entró al árbol en ese paso. Ignora cuerpos y áreas de otra capa. **Matiz:** un área que se *movió* en ese mismo paso se ve todavía en su posición anterior | Se queda el plan A. El hurtbox de un zombie va un paso por detrás de su cuerpo (≤ 6 cm a 3.5 m/s), aceptado; la orientación del robot, que era lo que importaba, es exacta. Los tests de integración esperan un paso de física tras mover un enemigo |
| 5 | `GPUParticles3D` y `CPUParticles3D` tienen `one_shot`, `restart()` y `finished`; en headless `finished` sale una vez por cada `restart()`. La documentación solo excluye `emit_particle()` en Compatibility y no habla del tirón de compilación de shader | Se empieza con `GPUParticles3D` y `restart()`; T-007-16 decide en el Android con la regla de §1 |
| 6 | `material_overlay` existe en `GeometryInstance3D` y la documentación no le pone restricción de renderer | El aspecto del destello se mira en el paso manual de PC y en T-007-16 |
| 7 | Con proyección ortográfica, `h_offset`/`v_offset` desplazan `get_camera_transform()` en el plano de la pantalla sin tocar la transformación del nodo | `CameraRig.shake` como en §1 |
| 8 | `Crypto.new().generate_random_bytes(16).hex_encode()` da 32 caracteres hexadecimales en minúsculas. No hay clase `Uid` en el motor | `Uid.generate()` como en §3 |
| 9 | `@warning_ignore("unused_signal")` sobre una señal compila. El aviso está en nivel "warn" | Se pone la anotación en `enemy_killed` |
| 10 | `get_script_property_list()` devuelve las variables del script con `PROPERTY_USAGE_SCRIPT_VARIABLE` (4096); un script solo con señales no devuelve ninguna | El test del bus filtra por ese uso |

## 6. Check de constitución

| Principio | Cumple | Nota |
|---|---|---|
| P1 Spec primero | ✅ | Spec 007 *Aprobado*; el plan pasa a *Planificado* solo con el usuario |
| P2 Una fuente de verdad | ✅ | Daño, ritmo, coste, XP, alcance, ancho, impacto y feedback en `.tres` con su fuente en BALANCE. Un test busca literales. El alto del hitbox es técnico y vive en la escena (decisión para el revisor en §1). `basic_arms.tres` se reorganizará en la spec 015 con `StatModifier`; hoy no hay dos fuentes del mismo número |
| P3 Lógica separada | ✅ | `CombatSystem` puro. `MeleeAttackComponent`, `ExperienceComponent`, `HurtboxComponent` y `HitFlashComponent` reciben sus entradas por parámetro (`delta`, catálogo, uid) y se testean sin física. Robot, zombie y feedback solo cablean |
| P4 Estado por jugador | ✅ | XP en `ExperienceComponent`, `player_uid` en el robot, golpe en su componente. `EventBus` no guarda nada (test). Cada robot suma solo sus muertes |
| P5 Datos como recursos | ✅ | `AttackStatsData`, `CombatConfigData`, `CombatFeedbackData` con `class_name` y `.tres` en `resources/` |
| P6 Señales | ✅ | `swing_started`, `hit_dealt`, `hurt`, `xp_changed`, `held_changed`, `attack_held_changed`, `finished` tipadas y como evento. `enemy_killed` por el bus porque interesa a sistemas sin relación (XP ahora; guía y audio después). Robot → hurtbox es atacante-objetivo, como zombie → robot en la 006. Referencias por `%` y `@export` |
| P7 Tipado | ✅ | Todo tipado; los solapes se convierten con `as HurtboxComponent` y se comprueba `null` |
| P8 Plataforma | ✅ | El gameplay lee `PlayerInput.poll_attack()`. `PlayerInput` lee la acción `attack` del InputMap en la capa de input/UI; no hizo falta filtro de ratón emulado ni toque propio en `AttackButton` (§5.1). Sin `OS.has_feature()`. El botón se ve en PC y móvil |
| P9 Determinismo | ✅ | El combate no usa azar. La sacudida usa un RNG propio con semilla fija, nunca el global (el test existente lo vigila) |
| P11 i18n | ✅ | `HUD_ATTACK` en ES + EN. La XP del `DebugHud` es de depuración, como los FPS |
| P12 Presupuesto móvil | ✅ | Chispas con pool desde la primera versión, sin luces nuevas, destello por material compartido. `CombatFeedback`, destellos y sacudida solo procesan mientras duran. FPS medido en Android (R-007-29) |
| P13 Test primero | ✅ | Datos, `CombatSystem`, componentes e input con test antes del código. Tests deterministas: `delta` exactos en binario y sin tiempo real |
| P14 Alcance | ✅ | Sin armas, piezas, `StatsComponent`, niveles, guardado, drops, SFX, hit stop, retroceso ni muerte del robot. El botón de atacar no se oculta con una pantalla abierta porque el spec no lo dice (ver §7) |
| P10 Servicios | ✅ | No toca guardado, tiempo, tienda ni online. Ninguna dependencia nueva |
| architecture §3 regla 4 | ⚠️ | Sin `ActionResult` en `tick`, `receive_attack`, `add_xp` y `reward_kill`: desviación justificada en §7, con el mismo criterio que `consume` y `take_damage` |

## 7. Riesgos y alternativas descartadas

- **Botón de atacar con el segundo dedo** → es el uso normal en móvil y era lo más incierto (verificar 2).
  `BaseButton` ya lo resuelve en 4.7.2 (§5.1 punto 2); probado en Android en T-007-16.
- **Consulta del impacto** → si `intersect_shape` no devuelve las áreas como se espera (verificar 4), plan B con
  `Area3D` y un paso de retraso, dentro de `MeleeAttackComponent`. Los contratos no cambian.
- **Botón de atacar sobre una pantalla abierta** → `Hud` se dibuja encima de `UIManager`, así que el botón queda
  encima de las pantallas y puede tapar alguno de sus botones abajo a la derecha. R-007-16 no pide ocultarlo; si en
  T-007-15 tapa algo, se propone añadir "WHILE no screen is open" a R-007-16 (como R-005-27) antes de cambiar el
  código (P1).
- **Golpear y alejarse del zombie lento** (pregunta 6) → se mira en el playtesting (ACTION_PLAN 5.2), no se mitiga
  aquí.
- **Joystick de depuración con ratón en PC** (`force_touch_debug`) → el clic izquierdo en la mitad izquierda mueve
  y también golpea, porque `FloatingJoystick` no marca el evento como gestionado. Solo pasa en depuración; no se
  toca la 002. Si molesta, un cambio aparte de una línea.
- **Tres contadores de efecto** (destello, borde rojo, sacudida) con la misma forma → son pocas líneas y cada uno
  hace otra cosa; se abstraen si llega un cuarto (P2).
- **`enemy_killed` dentro de un paso de física** → los oyentes de hoy (XP) no tocan el árbol. Uno que lo haga
  tendrá que usar `call_deferred`, como el spawner en la 006.
- **Sin `ActionResult` (architecture §3 regla 4)** → `tick`, `receive_attack`, `add_xp` y `reward_kill` devuelven
  `void`, como `take_damage` y `consume`. No son acciones con mensaje para el jugador; una entrada inválida es un
  error de programación y va por `push_error`.
- **Coste por golpe con la batería casi vacía** (pregunta 12) → el golpe sale y el robot muere. El impacto pendiente
  no llega porque `World` se congela; nadie suma XP de un golpe que mató al robot. Aceptado.
