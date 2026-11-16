# Spec 007 — Combate cuerpo a cuerpo y XP por muerte

| Campo | Valor |
|---|---|
| **Estado** | Hecho (2026-11-16) |
| **Tarea(s) ACTION_PLAN** | 1.4 |
| **Fuentes** | ACTION_PLAN.md Tarea 1.4 (y 2.7, 4.1, 4.3, 4.4 para los límites) · PMV.md §2.1 (controles táctiles, XP), §2.2, §2.3 (sin armas), §2.4, §3.2, §4.5 gancho 7, §10 (combate), §11 (game feel) · BALANCE.md §1.1, §3.1, §4.2, §6.2, §8.1, §8.2, §9.1, §11 · SPECS.md §18 (armas, v1.1) · architecture.md §3, §5, §7, §9.4, §9.5, §10.3, §11, §13 · Constitución P2, P3, P4, P6, P8, P11, P12, P13 |
| **Depende de** | 003 (`BatteryComponent`), 005 (`UIManager` y bloqueo de input), 006 (`HealthComponent`, `Zombie`, `EnemyData`, `ObjectPool`, `Robot.receive_hit`) |
| **Rama** | `feat/007-melee-combat` |

## 1. Objetivo

Cerrar el bucle de amenaza que abrió la 006: el robot golpea, los zombies mueren y el jugador gana XP. Cada
golpe cuesta batería, así que pelear es una decisión con coste, igual que huir. El robot nunca se queda sin
ataque: sin los Brazos básicos pelea con un brazo, más débil. Con esto, la zona verde ya es un combate de verdad
y queda lista la base para la muerte (spec 008) y el nivel de chasis (spec 013).

## 2. Historias

- Como jugador, quiero atacar con un botón grande a la derecha, para pelear con el pulgar mientras me muevo
  con el joystick.
- Como jugador, quiero apuntar yo moviendo el robot, para que acertar dependa de mi habilidad.
- Como jugador, quiero poder pelear siempre, aunque sea con un brazo, para no quedarme indefenso al empezar o
  después de morir.
- Como jugador, quiero que cada golpe me cueste batería, para decidir cuándo luchar y cuándo huir.
- Como jugador, quiero notar el golpe (destello, sacudida, chispas) y notar cuándo me golpean a mí, para
  entender el combate sin leer números.
- Como jugador, quiero ganar XP al matar zombies, para progresar aunque muera (PMV §2.4).
- Como desarrollador del nivel de chasis (spec 013), quiero la XP total en un componente del robot con una
  señal, para aplicar los umbrales sin tocar el combate.

## 3. Requisitos (EARS)

### 3.1 Datos

| ID | Requisito | Fuente |
|---|---|---|
| R-007-01 | THE game SHALL define an attack-stats data resource with damage per hit, attacks per second and battery cost per hit, and two `.tres` with the values of BALANCE §4.2: one arm (the robot's base attack) and the basic arms. | ACTION_PLAN 1.4, BALANCE §4.2, architecture §9.4 — pregunta 1 |
| R-007-02 | THE robot SHALL attack with the one-arm values until spec 014 derives its attack from `StatsComponent`. | BALANCE §4.2, §8.2 — pregunta 1 |
| R-007-03 | THE `EnemyData` resource SHALL gain an XP reward field, and the slow and fast zombie `.tres` SHALL carry the XP of BALANCE §3.1 and §6.2. | ACTION_PLAN 1.4, BALANCE §3.1, §6.2 |
| R-007-04 | THE combat values (hitbox reach and width, impact moment of the swing) and the feedback values (shake strength and duration, flash durations) SHALL come from data resources with the values of BALANCE §11, not script literals. | Constitución P2, BALANCE §11 — preguntas 4 y 10 |
| R-007-05 | THE tests SHALL reject attack data with zero or negative damage or attacks per second, so no data can leave the robot without an attack. | BALANCE §4.2 (un brazo como base) — pregunta 1 |

### 3.2 Ataque

| ID | Requisito | Fuente |
|---|---|---|
| R-007-06 | WHEN the player presses the `attack` action or the HUD attack button and the robot can attack, THE robot SHALL start a swing: play its attack animation and, at the impact moment, hit the enemies inside its hitbox. | ACTION_PLAN 1.4 — preguntas 2 y 4 |
| R-007-07 | WHILE the attack input is held, THE robot SHALL keep swinging at the attacks per second of its arms; a press during a swing or before the next swing is allowed SHALL be ignored, not queued. | BALANCE §4.2 — pregunta 2 |
| R-007-08 | THE rules that decide whether a swing may start (time since the last swing, battery, blocked input) and the damage it deals SHALL live in pure code (`CombatSystem`), testable without a scene tree. | ACTION_PLAN 1.4, architecture §3, Constitución P3 |
| R-007-09 | WHILE the robot's battery is depleted or a `UIManager` screen is open, THE robot SHALL not start a swing. | Spec 003 (batería agotada), spec 005 R-005-27 |
| R-007-10 | WHEN a swing starts, THE robot's `BatteryComponent` SHALL lose the battery cost per hit of its arms, whether or not the swing hits anything, even if that empties the battery. | BALANCE §1.1, §4.2, §9.1 — preguntas 3 y 12 |
| R-007-11 | WHEN a swing reaches its impact moment, THE robot SHALL deal the damage of its arms once to each living enemy inside the hitbox, through that enemy's `HealthComponent.take_damage`. | ACTION_PLAN 1.4, BALANCE §11 — pregunta 4 |
| R-007-12 | THE hitbox SHALL be active only during the impact of the swing and SHALL detect only enemies: never the robot itself, loot boxes, the scenery or other players. | ACTION_PLAN 1.4 |
| R-007-13 | WHEN a swing starts, THE robot SHALL hit in the direction it faces, with no auto-aim toward enemies. | PMV §10 (combate) — pregunta 5 |
| R-007-14 | WHILE a swing is in progress, THE robot SHALL keep moving and turning with the movement input as usual, and the hitbox SHALL follow its facing. | PMV §10 (combate) — pregunta 6 |
| R-007-15 | WHEN the player clicks or taps a HUD button, THE game SHALL not take it as an attack, even though the left mouse button is bound to `attack`. | Constitución P8, spec 001 (InputMap) |
| R-007-16 | THE HUD SHALL show a large attack button at the bottom right on every platform, whose text comes only from translation keys in ES and EN. | PMV §2.1, ACTION_PLAN 4.1, ADR 0001, Constitución P11 — pregunta 11 |

### 3.3 Muerte del enemigo y XP

| ID | Requisito | Fuente |
|---|---|---|
| R-007-17 | WHEN an enemy's `HealthComponent` emits `died` after a player's hit, THE game SHALL emit `EventBus.enemy_killed(enemy_id, killer_uid)` exactly once, with the id of the enemy's `EnemyData` and the uid of the player who dealt the final hit. | architecture §7 — pregunta 8 |
| R-007-18 | THE robot SHALL carry a `player_uid` generated at startup, which spec 010 replaces with the Profile's `player_uuid`. | architecture §10.3 — pregunta 8 |
| R-007-19 | THE robot SHALL own an `ExperienceComponent` that holds its total XP as an integer starting at 0, with `add_xp(amount)`, `get_total()` and a typed `xp_changed(total)` signal; no autoload SHALL hold the XP. | PMV §4.5 gancho 7, Constitución P4 — pregunta 7 |
| R-007-20 | WHEN `enemy_killed` arrives with this robot's uid as killer, THE robot's `ExperienceComponent` SHALL add the XP reward of that enemy's `EnemyData`, looked up in `DataRegistry`. | ACTION_PLAN 1.4, BALANCE §6.2, architecture §8 |
| R-007-21 | IF the XP to add is negative or the enemy id is not in the catalog, THEN THE `ExperienceComponent` SHALL report an error with context and change nothing. | Constitución §2 (errores) |
| R-007-22 | THE XP SHALL keep accumulating with no other effect until spec 013 applies the chassis levels, and SHALL show in the debug HUD. | ACTION_PLAN 2.7, BALANCE §6.1 — pregunta 7 |
| R-007-23 | WHEN a killed zombie comes back from the pool, THE zombie SHALL carry nothing from its previous life: full HP, no flash and no record of who hit it. | Spec 006 R-006-22, Constitución P12 |

### 3.4 Feedback

| ID | Requisito | Fuente |
|---|---|---|
| R-007-24 | WHEN a robot's hit damages an enemy, THE enemy SHALL flash white, THE camera SHALL shake with the "hit dealt" values and pooled impact particles SHALL play at the enemy. | ACTION_PLAN 1.4, BALANCE §11 — pregunta 10 |
| R-007-25 | WHEN the robot emits `hit_received`, THE camera SHALL shake with the "hit received" values and THE HUD SHALL flash red at the screen edges. | ACTION_PLAN 1.4, 4.4, BALANCE §11 — pregunta 10 |
| R-007-26 | THE feedback SHALL only listen to combat signals and SHALL never change battery, HP or XP. | architecture §3 regla 2, Constitución P6 |
| R-007-27 | THE impact particles SHALL come from an `ObjectPool`, work in the Compatibility renderer and stay within the mobile budget of PMV §3.2. | PMV §3.2, architecture §11, Constitución P12 |

### 3.5 Bucle completo

| ID | Requisito | Fuente |
|---|---|---|
| R-007-28 | WHEN the robot fights the green zone's zombies with one arm, THE player SHALL be able to kill both types, and the zombies SHALL still be able to deplete the battery, which shows the provisional game over of spec 003. | ACTION_PLAN 1.4 (test) |
| R-007-29 | WHILE the robot fights with the green zone's maximum of zombies around it, THE game SHALL keep ≥ 30 FPS on the mid-range Android device. | PMV §3.2, Constitución P12 |

Los valores numéricos (daño, velocidad de ataque, coste por golpe, XP, alcance y tiempos de feedback) se citan
por su fuente; el spec no los fija.

## 4. Fuera de alcance

- Armas y banco de armas: v1.1 (PMV §2.3, SPECS §18). En el PMV el daño lo dan los brazos.
- `EquipmentComponent`, `StatsComponent`, `RobotBaseStats.tres`, equipar los Brazos básicos y volver a un brazo
  al romperse o perderse: spec 014 (ACTION_PLAN 3.1-3.2). Degradación de piezas por golpe recibido: spec 014.
- Auto-apuntado: no existe en el PMV (decisión nov 2026, PMV §10).
- Subida de nivel de chasis y más ranuras de inventario: spec 013 (ACTION_PLAN 2.7). Mostrar la XP o el nivel
  en el HUD de juego y la notificación "Nivel up": ACTION_PLAN 4.1.
- Guardar la XP y el `player_uuid` persistente: spec 010. Conservar la XP al morir: spec 008 (PMV §2.4).
- Material que sueltan los zombies (BALANCE §3.1, "0-1 chatarra"): spec 008 (pregunta 9).
- SFX de golpe y de daño: ACTION_PLAN 4.3, que crea `AudioManager` (pregunta 10).
- Hit stop, animaciones de muerte y de daño, partículas de explosión al morir: ACTION_PLAN 4.4. En la 007 el
  zombie desaparece al morir, como en la 006.
- Retroceso (knockback) de los zombies al recibir un golpe: no lo pide ningún documento.
- XP del robot hostil (BALANCE §3.2): spec 015; el campo de XP de `EnemyData` ya le sirve.
- Overclock y habilidades: v1.1 (SPECS §6).
- Vibración del móvil al golpear: no la pide ningún documento.
- Fuego amigo y PvP: ONLINE.md.
- Barra de vida sobre los enemigos: no la pide el PMV.

## 5. Criterio de hecho

En la zona verde, con un brazo (BALANCE §4.2), el robot golpea al pulsar el botón grande de atacar (abajo a la
derecha) o Espacio o clic izquierdo en PC, sin disparar golpes al pulsar otros botones del HUD. Mantener el
botón golpea una vez por segundo y cada golpe gasta 1 punto de batería aunque falle. El robot golpea hacia
donde mira, sin girarse solo, y puede moverse mientras golpea. Un zombie lento muere en 4 golpes y uno rápido
en 3 (HP de BALANCE §3.1), con destello blanco, sacudida de cámara y chispas, y suma 2 o 3 de XP (BALANCE §6.2),
visible en el HUD de depuración. Al recibir un golpe la cámara se sacude y el borde de la pantalla parpadea en
rojo. Con la batería a 0 o una pantalla abierta no se ataca. Los zombies siguen pudiendo vaciar la batería.
Tests en verde: `CombatSystem` (puede atacar, enfriamiento, sin batería, input bloqueado), datos de ataque
válidos (un brazo y Brazos básicos), coste por golpe, daño a todos los enemigos del hitbox y solo a enemigos,
`enemy_killed` una sola vez, XP sumada por enemigo, errores de XP, zombie reutilizado limpio. ≥ 30 FPS en el
Android de gama media peleando con todos los zombies de la zona.

## 6. Preguntas abiertas

| # | Pregunta | Propuesta | ¿Bloquea? |
|---|---|---|---|
| 1 | ~~¿Con qué brazos empieza el robot?~~ | **Cerrada (nov 2026)**: el robot nunca se queda sin ataque. Sin Brazos básicos pelea con **un brazo**, que es su estado base (como "una pierna" en las piernas): no es un item, no se degrada ni se pierde al morir. Daño 5, 1.0 golpe/s, 1 de batería por golpe (BALANCE §4.2). Es la red de seguridad: se empieza con él y se vuelve a él al romper o perder los Brazos básicos. En la 007 el robot pelea con un brazo. | — |
| 2 | ~~Pulsar y mantener~~ | **Cerrada (nov 2026)**: mantener = golpear a la velocidad de los brazos; una pulsación durante la espera se ignora, sin cola. | — |
| 3 | ~~¿"1 punto/golpe" por golpe lanzado o acertado?~~ | **Cerrada (nov 2026)**: por golpe lanzado, también si falla (BALANCE §1.1). | — |
| 4 | ~~Hitbox~~ | **Cerrada (nov 2026)**: caja delante del robot de 2.0 m de alcance y 1.0 m de ancho, para llegar al zombie que se para a 1.5 m; impacto a 0.2 s del inicio del golpe; daña una vez a cada enemigo vivo dentro (BALANCE §11, "Combate"). | — |
| 5 | ~~Auto-apuntado~~ | **Cerrada (nov 2026)**: no existe en el PMV. El jugador apunta moviendo el robot; se quita esa facilidad a propósito (PMV §10). | — |
| 6 | ~~Moverse mientras golpea~~ | **Cerrada (nov 2026)**: se mueve y gira libre durante el golpe. El riesgo de golpear y alejarse del zombie lento se revisa en el playtesting (ACTION_PLAN 5.2). | — |
| 7 | ~~Dónde vive la XP~~ | **Cerrada (nov 2026)**: `ExperienceComponent` en el robot; sin HUD de XP hasta ACTION_PLAN 4.1, visible en el HUD de depuración. | — |
| 8 | ~~`EventBus` y `killer_uid`~~ | **Cerrada (nov 2026)**: la 007 crea `EventBus` solo con `enemy_killed`. La muerte cuenta para el último golpe. El robot lleva un `player_uid` generado al arrancar hasta que la spec 010 traiga el del Perfil. El enemigo guarda el uid del último atacante sin cambiar la firma de `take_damage`; el plan elige el mecanismo. | — |
| 9 | ~~Material de los zombies~~ | **Cerrada (nov 2026)**: pasa a la spec 008, que crea el objeto caído; la tirada saldrá de `SeededRng` con semilla + `zone_id` + visita + índice de aparición del zombie. BALANCE §8.1 corregido a "+0-5 chatarra". | — |
| 10 | ~~Feedback y valores~~ | **Cerrada (nov 2026)**: destello blanco 0.1 s, sacudida al golpear 0.05 m durante 0.1 s, al recibir 0.15 m durante 0.2 s, borde rojo 0.3 s, chispas placeholder con pool (BALANCE §11). Los SFX pasan a ACTION_PLAN 4.3. El plan comprueba si `GPUParticles3D` funciona en Compatibility en el Android de gama media; si no, `CPUParticles3D`. | — |
| 11 | ~~Botón de atacar en PC~~ | **Cerrada (nov 2026)**: visible en las dos plataformas, con la clave `HUD_ATTACK` hasta que la Tarea 4.1 ponga iconos. | — |
| 12 | ~~Atacar con poca batería~~ | **Cerrada (nov 2026)**: se permite; el golpe sale y, si vacía la batería, el robot muere. | — |
