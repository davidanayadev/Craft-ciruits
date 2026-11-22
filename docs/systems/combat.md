# Combate cuerpo a cuerpo y XP

> El robot golpea con un brazo en la dirección que mira, cada golpe cuesta batería, los zombies mueren y el robot
> suma XP. Incluye el feedback del golpe (destello, sacudida, chispas, borde rojo).
> Specs: [007](../../specs/007-melee-combat/spec.md), [008](../../specs/008-death-recovery/spec.md) (solo
> `cancel_swing` y `ExperienceComponent.reset`), [009](../../specs/009-base-placement-charging/spec.md) (`release_all`) · [010](../../specs/010-save-profile-world/spec.md) (XP guardada) · Última actualización: spec 010

## Piezas

| Pieza | Tipo | Archivo | Responsabilidad |
|---|---|---|---|
| `CombatSystem` | Sistema puro (`RefCounted`) | `game/scripts/systems/combat_system.gd` | Cuándo puede empezar un golpe, cuándo llega el impacto, cuánto daña |
| `MeleeAttackComponent` | Componente (`Node3D`, hijo del robot) | `game/scripts/components/melee_attack_component.gd` | Estado del golpe y hitbox; `tick()`, `apply_impact()`, `cancel_swing()` |
| `HurtboxComponent` | Componente (`Area3D`) | `game/scripts/components/hurtbox_component.gd` | Lo que detecta el hitbox; recuerda al último atacante |
| `HitFlashComponent` | Componente | `game/scripts/components/hit_flash_component.gd` | Destello blanco (`material_overlay`) de una entidad golpeada |
| `ExperienceComponent` | Componente | `game/scripts/components/experience_component.gd` | XP total del jugador; `reward_kill()` |
| `EventBus.enemy_killed` | Señal de autoload | `game/scripts/autoload/event_bus.gd` | Una muerte provocada por un jugador, una vez por vida |
| `Uid` | Utilidad | `game/scripts/util/uid.gd` | `Uid.generate()`: 128 bits en hexadecimal, el `player_uid` del robot |
| `CombatFeedback` | Nodo de `main.tscn` | `game/scenes/feedback/combat_feedback.gd` | Único sitio que convierte señales de combate en feedback |
| `ImpactSparks` | Escena con pool | `game/scenes/effects/impact_sparks.gd`, `.tscn` | Ráfaga de `GPUParticles3D` de un solo disparo |
| `CameraRig.shake()` | Método | `game/scenes/camera/camera_rig.gd` | Sacudida con `h_offset`/`v_offset` |
| `AttackButton`, `DamageFlash` | Controles del HUD | `game/scenes/ui/attack_button.gd`, `damage_flash.gd` | Botón de mantener y borde rojo ([ui.md](ui.md)) |
| `PlayerInput.poll_attack()` | Método | `game/scripts/components/player_input.gd` | Entrada de ataque ([movement.md](movement.md)) |
| `AttackStatsData`, `CombatConfigData`, `CombatFeedbackData` | Recursos | `game/scripts/data/` | Daño y ritmo; hitbox e impacto; tiempos de feedback |
| `.tres` | Datos | `resources/combat/one_arm.tres`, `basic_arms.tres`, `resources/config/combat.tres`, `combat_feedback.tres`, `resources/materials/hit_flash.tres` | Valores reales |

## Cómo funciona

1. **Entrada.** Cada paso de física `Robot._physics_process` mueve y gira primero y después llama a
   `melee.tick(delta, player_input.poll_attack(), battery.is_depleted(), player_input.is_input_blocked())`.
2. **Empezar un golpe.** `tick()` suma `delta`; si `CombatSystem.can_start_swing()` lo permite, pone el contador a
   0, marca el impacto como pendiente y emite `swing_started(battery_cost)`. Una pulsación que no puede empezar
   golpe se descarta, no se encola.
3. **Coste y animación.** `Robot._on_swing_started` hace `battery.consume(cost)` (acierte o no, aunque lo agote) y
   reinicia la animación `attack`, que es solo presentación ([battery.md](battery.md)).
4. **Impacto.** Cuando `CombatSystem.impact_reached()` marca el paso del momento de impacto
   (`CombatConfigData.impact_time_s`), `find_targets()` hace **una** consulta instantánea
   `intersect_shape` con una caja delante del robot (`-Z`), con la transformación de ese mismo paso. La máscara es
   solo la capa 3 `hurtbox`, solo áreas: nunca ve al robot, cajas ni escenario. Un golpe empezado termina aunque se
   abra una pantalla o se agote la batería.
5. **Daño.** `apply_impact()` llama a `receive_attack(damage, attacker_uid)` una vez por hurtbox distinto y vivo y
   emite `hit_dealt(target)`. El hurtbox guarda el uid, llama a `HealthComponent.take_damage()` y emite `hurt`.
6. **Muerte y XP.** `HealthComponent.died` llega al `Zombie` ([enemies.md](enemies.md)): si el hurtbox recuerda un
   atacante, emite `EventBus.enemy_killed(enemy_id, killer_uid)`. Cada `Robot` escucha el bus y llama a
   `experience.reward_kill(id, killer_uid, player_uid, DataRegistry.get_catalog())`: solo suma si el asesino es él;
   suma `EnemyData.xp_reward` y emite `xp_changed`. El total solo se ve en `DebugHud`.
7. **Feedback.** `CombatFeedback.bind(robot, camera_rig, hud)` conecta dos señales:
   - `melee.hit_dealt` → `CameraRig.shake` con los valores de "golpe dado" y chispas en el hurtbox (de `%ImpactPool`;
     vuelven al pool, en diferido, con `finished`).
   - `robot.hit_received` → sacudida de "golpe recibido" y `Hud.flash_damage()`.
   El destello blanco del enemigo lo dispara el propio zombie con `hurtbox.hurt` → `HitFlashComponent.flash()`.
   `CombatFeedback.release_all()` (spec 009) devuelve al pool todas las chispas que siguen activas; `Main` la llama al
   empezar un viaje, porque las chispas cuelgan de `World` y no de la zona que se descarga ([travel.md](travel.md)).

```
Botón/Espacio/clic -> PlayerInput.poll_attack -> MeleeAttack.tick -> swing_started -> battery.consume
                                                       | (impacto)
                              intersect_shape (capa hurtbox) -> HurtboxComponent -> HealthComponent.died
                                      -> Zombie -> EventBus.enemy_killed -> ExperienceComponent.reward_kill
```

## Datos

| Recurso | Clase | Valores desde |
|---|---|---|
| `one_arm.tres`, `basic_arms.tres` | `AttackStatsData` | [BALANCE.md §4.2](../../BALANCE.md), coste por golpe en §1.1 |
| `combat.tres` | `CombatConfigData` | BALANCE.md §11 ("Combate") |
| `combat_feedback.tres` | `CombatFeedbackData` | BALANCE.md §11 ("Combate") |
| `zombie_slow.tres`, `zombie_fast.tres` (`xp_reward`) | `EnemyData` | BALANCE.md §3.1 y §6.2 |

El robot usa `one_arm.tres`. `basic_arms.tres` no lo usa nadie hasta la spec 015 (existe porque lo pide R-007-01).
El alto de la caja del hitbox y su altura son geometría de colisión en `robot.tscn`, no balance.

## Decisiones

| Decisión | Por qué | Fuente |
|---|---|---|
| `intersect_shape` en el impacto, no un `Area3D` encendido | Los solapes de un `Area3D` van un paso por detrás de la orientación del robot | [plan 007 §1](../../specs/007-melee-combat/plan.md) |
| `tick()` sin `_physics_process` propio | El ritmo se prueba con `delta` a mano | R-007-08, plan 007 §1 |
| Sin auto-apuntado: golpea hacia donde mira | Se quita esa facilidad a propósito | R-007-13, PMV §10 |
| Se mueve y gira libre durante el golpe | Decisión cerrada nov 2026 (pregunta 6) | R-007-14 |
| El robot nunca se queda sin ataque: un brazo | Red de seguridad hasta la spec 015 | R-007-02, spec 007 pregunta 1 |
| El coste se paga al empezar, acierte o no | BALANCE §1.1 | R-007-10 |
| `killer_uid` en `HurtboxComponent`, `take_damage` no cambia | `HealthComponent` no sabe de jugadores | plan 007 §1, spec pregunta 8 |
| `enemy_killed` por el bus; el golpe, por llamada directa | La XP, la guía y el audio no se conocen entre sí; atacante-objetivo sí | plan 007 §6 (P6), [architecture §7](../../specs/architecture.md) |
| XP en un componente del robot | Estado por jugador, sin autoload | R-007-19, PMV §4.5 gancho 7 |
| `CombatFeedback` es el único cableado de feedback | Los valores no se reparten entre dos sitios | plan 007 §1 |
| Chispas de `GPUParticles3D` con pool | Regla: se mantiene si funciona en Compatibility y los FPS aguantan | plan 007 §1, R-007-27 |
| `cancel_swing()` al morir | Un robot muerto no golpea ni deja un impacto pendiente tras la repoblación | [plan 008 §1](../../specs/008-death-recovery/plan.md) "Muerte" |
| Sin `ActionResult` en `tick`, `receive_attack`, `add_xp` | Entrada inválida es un error de programación | plan 007 §7 |

## Relación con otros sistemas

- Usa: [battery.md](battery.md) (coste), [enemies.md](enemies.md) (`HealthComponent`, `Zombie`),
  [data_catalog.md](data_catalog.md) (`EventBus`, `DataRegistry`), [movement.md](movement.md) (entrada, `CameraRig`),
  [ui.md](ui.md) (botón de atacar, borde rojo).
- Lo usa: [death.md](death.md) (`cancel_swing`, `ExperienceComponent.reset` según el ruleset).

## Trampas y límites

- El impacto ve la posición del hurtbox del zombie un paso de física atrás (≤ 6 cm a su velocidad): aceptado.
- No hay armas, degradación por golpe, retroceso, hit stop, SFX, HUD de XP ni nivel de chasis (specs 014, 015 y
  ACTION_PLAN 4.x). La XP solo se acumula.
- `player_uid` es aleatorio hasta que `Robot.set_player_uid` le da el `player_uuid` del Perfil (también al ataque, `melee.attacker_uid`). `ExperienceComponent` es dueño de guardado (`experience`: el total) y cargar emite `xp_changed` pero nunca repite una subida de nivel ([save.md](save.md)).
- `enemy_killed` sale dentro de un paso de física: un oyente que toque el árbol debe usar `call_deferred`.
- `reward_kill` con un id fuera del catálogo da un solo `push_error` y no suma.
- Con `force_touch_debug` el clic izquierdo mueve y también golpea (spec 007 plan §7).
- El botón de atacar se ve con una pantalla abierta, aunque no golpea.

## Cómo extenderlo

- Otro ataque: `AttackStatsData` `.tres` con su sección en BALANCE §4.2 y asignarlo a `Robot.melee.attack`.
- Otra entidad que reciba golpes: `HurtboxComponent` con su `HealthComponent` y forma, como en `zombie.tscn`.
- Otro feedback: conectarlo en `CombatFeedback.bind`, nunca en la lógica del golpe.

## Tests

| Archivo | Verifica |
|---|---|
| `tests/unit/test_combat_system.gd` | Puede empezar, enfriamiento, batería agotada, input bloqueado, 60 pasos = 1 s |
| `tests/unit/test_combat_resources.gd` | `.tres` de ataque y feedback frente a BALANCE, sin literales, golpes para matar |
| `tests/unit/test_melee_attack_component.gd` | Ritmo, coste, daño una vez por objetivo, máscara de la consulta |
| `tests/unit/test_hurtbox_component.gd` | Capa, último atacante, daño negativo |
| `tests/unit/test_experience_component.gd` | Suma, `reward_kill`, errores, `reset` |
| `tests/unit/test_event_bus.gd`, `test_uid.gd` | Firma del evento, bus sin estado, formato del uid |
| `tests/unit/test_hit_flash_component.gd`, `test_camera_rig.gd` | Destello y sacudida |
| `tests/integration/test_robot_combat.gd` | Golpe con física, sin auto-apuntado, XP de punta a punta |
| `tests/integration/test_combat_feedback.gd` | Sacudida, chispas con pool, el feedback no cambia estado |
| `tests/integration/test_hud_attack_input.gd` | Un clic en un botón del HUD no es un golpe |
