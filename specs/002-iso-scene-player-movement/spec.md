# Spec 002 — Escena isométrica y movimiento del robot

| Campo | Valor |
|---|---|
| **Estado** | Hecho |
| **Tarea(s) ACTION_PLAN** | 0.2, 0.3 |
| **Fuentes** | ACTION_PLAN.md Tareas 0.2-0.3 · PMV.md §2.1 (movimiento, controles), §3.2, §12 (cámara) · BALANCE.md §4.2 (piernas) · ADR 0001 |
| **Depende de** | 001 |
| **Rama** | `feat/002-iso-scene-player-movement` |

## 1. Objetivo

Validar el *feel* 3D isométrico (PMV.md §5.2, F0): el robot se mueve por una escena vacía con joystick virtual en
Android y con teclado en PC, a la velocidad de las piernas básicas.

## 2. Historias

- Como jugador en el móvil, quiero mover el robot con un joystick en la parte izquierda de la pantalla, para
  explorar con una mano.
- Como desarrollador en PC, quiero mover el robot con WASD, para probar sin exportar.

## 3. Requisitos (EARS)

| ID | Requisito | Fuente |
|---|---|---|
| R-002-01 | THE main scene SHALL show the world through an isometric camera rotated 45° on Y and tilted about 35° on X. | ACTION_PLAN 0.2, PMV §12 |
| R-002-02 | WHILE the robot moves, THE camera SHALL follow it keeping the same angle and distance. | PMV §12 (inferido: zona de 50x50 m no cabe en pantalla) |
| R-002-03 | THE scene SHALL have one directional light with shadows, a ground and a basic sky, within the budget of PMV §3.2. | ACTION_PLAN 0.2, PMV §3.2 |
| R-002-04 | THE robot SHALL be a `CharacterBody3D` with a capsule collider and a low-poly model or a primitive placeholder. | ACTION_PLAN 0.3 y riesgos |
| R-002-05 | WHILE there is movement input, THE robot SHALL move in the input direction relative to the camera at the walking speed of the equipped legs. | ACTION_PLAN 0.3, BALANCE §4.2 |
| R-002-06 | WHILE the run input is active and the robot has legs, THE robot SHALL move at the running speed of the equipped legs. | PMV §2.1, BALANCE §4.2 |
| R-002-15 | WHILE the joystick is pushed less than the dead zone (15 % of its radius), THE joystick SHALL produce no movement. | PMV §2.1 (decisión nov 2026) |
| R-002-16 | WHEN the joystick is pushed beyond the run threshold (80 % of its radius by default), THE joystick SHALL activate the run input, and SHALL release it only when pushed back below 70 %. | PMV §2.1, ACTION_PLAN 0.3 |
| R-002-17 | THE movement speed SHALL be fixed per state (walk or run), never proportional to how far the joystick is pushed. | ACTION_PLAN 0.3 (decisión nov 2026) |
| R-002-18 | IF the robot has no legs, THEN THE robot SHALL not run, whatever the run input. | BALANCE §1.1, §4.2 |
| R-002-07 | WHILE the robot moves, THE robot SHALL turn smoothly toward its movement direction. | ACTION_PLAN 0.3 |
| R-002-08 | IF there is no movement input, THEN THE robot SHALL stop without sliding. | Inferido |
| R-002-09 | IF the robot runs into a static obstacle, THEN THE robot SHALL not pass through it. | Inferido |
| R-002-10 | WHERE the device has a touchscreen, WHEN a touch starts in the left half of the screen outside any other HUD control, THE HUD SHALL show a floating virtual joystick centred on that touch, producing the same movement input as the keyboard, and SHALL hide it when the finger lifts. | PMV §2.1 (joystick flotante, decisión nov 2026), ADR 0001 |
| R-002-11 | WHEN a touch starts inside the joystick area, THE joystick SHALL follow only that finger until it lifts, ignoring other touches. | Inferido: el botón de atacar (spec 007) usa otro dedo |
| R-002-12 | WHERE the game runs on PC, THE robot SHALL move with WASD/arrows and run with Shift, and THE joystick SHALL be hidden unless a debug option forces it for mouse testing. | ADR 0001, spec 001 R-001-08 |
| R-002-13 | THE movement code SHALL read only InputMap actions or the movement-input abstraction, never touch events or keys directly. | Constitución P8 |
| R-002-14 | THE walking speed, running speed, turn speed and joystick thresholds SHALL come from data resources, not script literals. | Constitución P2, P5 |

## 4. Fuera de alcance

- Batería y su consumo al moverse: spec 003.
- Botones de atacar, interactuar y demás: specs de cada mecánica.
- Animaciones de andar/correr: ACTION_PLAN 4.4 (en esta fase basta con el modelo estático).
- Piezas equipables (`PieceData`): spec 015. Aquí se usan los valores de las piernas básicas.
- Zoom de cámara (PMV §12 menciona 2-3 niveles): sin tarea en ACTION_PLAN; fuera hasta que se decida.

## 5. Criterio de hecho

El robot se mueve con joystick en un Android real y con teclado en PC, a 3.0 m/s andando y 4.8 m/s corriendo
(BALANCE §4.2), gira suave, choca con un obstáculo de prueba y la cámara lo sigue. ≥ 30 FPS en el Android de
pruebas.

Hasta spec 015 no hay piezas: el robot usa las piernas básicas y R-002-18 se verifica con un test que simula
"sin piernas".

## 6. Preguntas abiertas

| # | Pregunta | Propuesta | ¿Bloquea? |
|---|---|---|---|
| 1 | ~~Velocidad al correr y cómo se corre~~ | **Cerrada (nov 2026)**: 4.8 m/s (BALANCE §4.2); en móvil, empujar el joystick más del 80 %; en PC, Shift; sin piernas no se corre. | — |
| 2 | ~~¿Joystick fijo o flotante?~~ | **Cerrada (nov 2026)**: flotante, aparece donde tocas en la mitad izquierda (R-002-10). | — |
| 3 | ~~¿Dónde viven los parámetros de *feel*?~~ | **Cerrada (nov 2026)**: en BALANCE.md §11 "Controles y sensación" (BALANCE.md es dueño de todos los números); el código los lee de un `.tres`. Los ajustes que cambia el jugador van en `user://settings.cfg` (architecture.md §10.2). | — |
| 4 | ~~¿Velocidad analógica o fija?~~ | **Cerrada (nov 2026)**: dirección analógica, velocidad fija por tramo (R-002-17). | — |
