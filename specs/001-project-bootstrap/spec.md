# Spec 001 — Proyecto Godot y arnés de desarrollo

| Campo | Valor |
|---|---|
| **Estado** | Planificado |
| **Tarea(s) ACTION_PLAN** | 0.1 (+ CI de TOOLING.md §8, tests de ADR 0002, input de ADR 0001) |
| **Fuentes** | ACTION_PLAN.md Tarea 0.1 · PMV.md §2.1 (controles), §3.1, §4.2, §4.4, §11 · TOOLING.md §8 · ADR 0001-0004 |
| **Depende de** | — |
| **Rama** | `feat/001-project-bootstrap` |

## 1. Objetivo

Dejar un proyecto Godot vacío pero listo para programar con red de seguridad: configuración móvil, estructura
de carpetas, tipado estricto, i18n, acciones de input para móvil y PC, tests automáticos y CI. Todo lo que viene
después se apoya en esto; arreglarlo más tarde cuesta más.

## 2. Historias

- Como desarrollador, quiero ejecutar todos los tests con un comando, para saber en segundos si rompí algo.
- Como desarrollador, quiero que cada PR pase tests en la CI, para no fusionar código roto en `main`.
- Como desarrollador, quiero probar el juego en PC con teclado y exportarlo a Android sin tocar el código, para
  iterar rápido y validar en el dispositivo real.

## 3. Requisitos (EARS)

| ID | Requisito | Fuente |
|---|---|---|
| R-001-01 | THE repo SHALL contain a Godot 4.7.2 project named "CyberScrap" in `game/`. | ACTION_PLAN 0.1, ADR 0004 |
| R-001-02 | THE project SHALL use the Compatibility renderer (OpenGL ES 3.0) on desktop and on mobile. | PMV §3.1, ADR 0001 |
| R-001-03 | THE project SHALL run in portrait with a 1080x1920 base resolution and SHALL adapt to other aspect ratios without distorting the image. | ACTION_PLAN 0.1 |
| R-001-04 | WHERE the game runs on PC, THE window SHALL open in portrait at a reduced size that fits a desktop screen. | ADR 0001 |
| R-001-05 | THE project SHALL follow the folder layout of PMV §4.2 plus `tests/unit`, `tests/integration` and `i18n`. | PMV §4.2, ADR 0004 |
| R-001-06 | IF a script has an untyped declaration or an unsafe property/method access, THEN THE editor and the headless run SHALL report it as an error. | PMV §4.4, constitución P7 |
| R-001-07 | THE project SHALL load Spanish and English translations, SHALL pick the device language when it is one of them and SHALL fall back to English otherwise. | PMV §4.4, §11 |
| R-001-08 | THE InputMap SHALL define one action per PMV control (move ×4, run, attack, use consumable, interact, open storage, pause; crouch is v1.1, SPECS §30), each with a keyboard binding for PC. | PMV §2.1, ADR 0001 |
| R-001-09 | WHEN the developer runs the test command, THE harness SHALL run every GUT test headless and SHALL exit with a non-zero code if any test fails or any script fails to load. | ADR 0002 |
| R-001-10 | WHEN a pull request targets `main` or a commit is pushed to `main`, THE CI SHALL import the project, run every test and fail the check on any failure. | TOOLING.md §8 |
| R-001-11 | THE project SHALL have an Android export preset (debug) and a Windows Desktop export preset. | ADR 0001 |
| R-001-12 | IF a file holds signing credentials, a keystore or generated build output, THEN THE repo SHALL NOT track it. | CLAUDE.md global §4 |
| R-001-13 | THE repo SHALL have a README with setup steps and the commands to open, test and export the project, and CLAUDE.md SHALL list the same commands. | ACTION_PLAN 0.1, CLAUDE.md |
| R-001-14 | THE test suite SHALL include checks that fail if R-001-02, R-001-03, R-001-06, R-001-07 or R-001-08 stop being true. | Constitución P13 |

## 4. Fuera de alcance

- Escena 3D, cámara, robot y joystick virtual: spec 002.
- Keystore de release, AAB y Play Console: ACTION_PLAN 6.1-6.4.
- Export de Android en la CI: se decide en 6.1 (necesita SDK y secretos en GitHub).
- iOS: fuera del PMV (PMV.md §10).
- Linter externo (gdtoolkit/gdstyle): no se añade; el tipado lo exigen los avisos de Godot (R-001-06).

## 5. Criterio de hecho

El proyecto abre en Godot 4.7.2 sin errores, los tests pasan con un comando en local y en la CI de un PR, y un
APK debug se instala y arranca (pantalla vacía en retrato) en un Android real.

## 6. Preguntas abiertas

| # | Pregunta | Propuesta | ¿Bloquea? |
|---|---|---|---|
| 1 | ~~Idioma de reserva~~ | **Cerrada (nov 2026)**: inglés si el dispositivo no está en ES ni EN (R-001-07). | — |
| 2 | ~~Aspect ratio 16:9 frente a móviles más alargados~~ | **Cerrada (nov 2026)**: base 1080x1920 con estiramiento `expand`; en pantallas más altas se ve más mapa en vertical, sin bandas negras. | — |
| 3 | ~~Nombre de paquete Android~~ | **Cerrada**: `com.davidanaya.cyberscrap` desde el primer APK debug. | — |
| 4 | ~~Cuota de minutos de Actions si el repo es privado~~ | **Cerrada (nov 2026)**: CI ligera, solo tests en Linux. | — |
