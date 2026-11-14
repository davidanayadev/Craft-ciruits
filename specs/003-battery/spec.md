# Spec 003 — Batería: consumo, señales y HUD

| Campo | Valor |
|---|---|
| **Estado** | Aprobado |
| **Tarea(s) ACTION_PLAN** | 0.4 |
| **Fuentes** | ACTION_PLAN.md Tarea 0.4 · PMV.md §2.1 (batería, HUD), §4.5 gancho 7 · BALANCE.md §1.1, §4.2, §9.1 · CLAUDE.md "Battery is the player's health" |
| **Depende de** | 001, 002 (estado de movimiento andar/correr), arquitectura aprobada (`architecture.md` §5, §7, §9.4, §10.2) |
| **Rama** | `feat/003-battery` |

## 1. Objetivo

La batería es la vida del robot y la tensión del juego (PMV.md §8, pro 3). Esta feature crea el
`BatteryComponent` del que colgarán combate, muerte, base y piezas, con su HUD.

## 2. Historias

- Como jugador, quiero ver cuánta batería me queda, para decidir cuándo volver a la base.
- Como desarrollador de otros sistemas, quiero una API de batería con señales, para conectar ataques, golpes y
  recargas sin tocar el componente.

## 3. Requisitos (EARS)

| ID | Requisito | Fuente |
|---|---|---|
| R-003-01 | THE `BatteryComponent` SHALL hold the current and maximum battery of its own entity, starting full. | ACTION_PLAN 0.4, PMV §4.5 gancho 7 |
| R-003-02 | WHILE the robot is alive, THE `BatteryComponent` SHALL drain the passive rate per second, wherever the robot is, including inside the base. | BALANCE §1.1 (decisión nov 2026) |
| R-003-03 | WHILE the robot walks, THE `BatteryComponent` SHALL also drain the walking rate of the equipped legs. | BALANCE §1.1, §4.2 |
| R-003-04 | WHILE the robot runs, THE `BatteryComponent` SHALL drain the running rate instead of the walking rate. | BALANCE §1.1 — ver pregunta 2 |
| R-003-05 | THE drain SHALL depend only on elapsed time, not on frame rate. | BALANCE §9.1 |
| R-003-06 | WHEN the battery value changes, THE `BatteryComponent` SHALL emit `battery_changed(current, maximum)`. | ACTION_PLAN 0.4 (HUD en tiempo real) |
| R-003-07 | WHEN the battery drops below the low threshold, THE `BatteryComponent` SHALL emit `battery_low` once, and SHALL emit it again only after rising above the threshold. | ACTION_PLAN 0.4, BALANCE §1.1 (20 %) |
| R-003-08 | WHEN the battery reaches 0, THE `BatteryComponent` SHALL clamp it to 0, emit `battery_depleted` exactly once and stop draining. | ACTION_PLAN 0.4, PMV §2.1 |
| R-003-09 | THE `BatteryComponent` SHALL let other systems consume an amount, add an amount (capped at the maximum) and recharge to full. | BALANCE §1.1 (golpe, batería portátil, base) |
| R-003-10 | IF an amount passed to consume or add is negative, THEN THE `BatteryComponent` SHALL reject it, report an error and leave the battery unchanged. | Constitución §2 (errores) |
| R-003-11 | THE HUD SHALL show the battery at the top left as a bar and a whole number rounded up (never 0 while any charge remains), updated only through `battery_changed`. | PMV §2.1, ACTION_PLAN 0.4 |
| R-003-12 | WHEN `battery_depleted` is emitted, THE game SHALL show a provisional "game over" screen with a restart option. | ACTION_PLAN 0.4 ("game over al llegar a 0") |
| R-003-13 | THE maximum battery and every drain rate SHALL come from data resources, not script literals. | Constitución P2, P5 |
| R-003-14 | WHERE two entities each have a `BatteryComponent`, THE components SHALL not share state. | PMV §4.5 gancho 7 |

## 4. Fuera de alcance

- Coste de batería por golpe dado (1/golpe) y daño recibido: spec 007 (usa R-003-09).
- Reacción real a la muerte (drops, respawn al 100%, ruleset): spec 008. R-003-12 es provisional y se sustituye allí.
- Recarga en la Estación de carga y batería máxima +20 del generador: specs 009 y 012 (usan R-003-09).
- Notificación "Batería baja" y SFX: ACTION_PLAN 4.1 y 4.3 (escuchan `battery_low`).
- Batería máxima según el Core equipado: spec 014.

## 5. Criterio de hecho

Batería baja al estar quieto, más al andar y más al correr, a los ritmos de BALANCE §1.1; el HUD lo refleja; al
llegar a 0 aparece el "game over" provisional. Tests de la lógica en verde (ritmos, umbral, una sola emisión,
independencia de frame rate, valores negativos, dos instancias).

## 6. Preguntas abiertas

| # | Pregunta | Propuesta | ¿Bloquea? |
|---|---|---|---|
| 1 | ~~Umbral de batería baja~~ | **Cerrada (nov 2026)**: 20 % de la batería máxima (BALANCE §1.1). | — |
| 2 | ~~¿El consumo al correr depende de las piernas?~~ | **Cerrada (nov 2026)**: valor general en el PMV (BALANCE §1.1); si v1.1 trae piernas que lo cambian, será un modificador `run_drain` de la pieza (architecture.md §9.4). | — |
| 3 | ~~¿Se consume dentro de la base?~~ | **Cerrada (nov 2026)**: sí, en todas partes; solo recarga la Estación de carga al interactuar (BALANCE §1.1, §5.3). | — |
| 4 | ~~¿El HUD muestra decimales?~~ | **Cerrada (nov 2026)**: número entero redondeado hacia arriba; no enseña 0 mientras quede algo (R-003-11). | — |
| 5 | ~~En Fase 0 no existen piezas~~ | **Cerrada (nov 2026)**: se usan los valores de piernas básicas y Core básico desde datos hasta spec 014. | — |
