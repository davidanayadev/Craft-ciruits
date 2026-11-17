# Spec-Driven Development — CyberScrap

> Cómo se pasa de los documentos de diseño a código. Nada de producción se programa sin un spec aprobado.
> Reglas de gobierno: **[constitution.md](constitution.md)**. Arquitectura: **[architecture.md](architecture.md)**.
> Decisiones técnicas: **[decisions/](decisions/)**.

## 1. Capas de documentación

| Capa | Dónde | Qué contiene | Cambia |
|---|---|---|---|
| **Producto** | `PMV.md`, `BALANCE.md`, `SPECS.md`, `ONLINE.md`, `TOOLING.md` | Qué es el juego, alcance, números, roadmap | Al decidir diseño (en chat primero) |
| **Ejecución** | `ACTION_PLAN.md` | Orden de tareas y criterio de "hecho" por fase | Al replanificar |
| **Gobierno** | `specs/constitution.md` + `specs/architecture.md` + `specs/decisions/` | Principios no negociables, estructura del código y decisiones técnicas (ADR) | Solo con un ADR nuevo |
| **Feature** | `specs/NNN-slug/` | `spec.md` (qué), `plan.md` (cómo), `tasks.md` (pasos) | Durante la feature |

Un spec **referencia** los documentos de producto, no los copia (DRY). Si un spec necesita un número, cita
`BALANCE.md §x.y`; si el número no existe, se anota como pregunta abierta y se resuelve en `BALANCE.md`
primero.

## 2. Flujo

```
ACTION_PLAN (tarea) ──▶ spec.md ──▶ plan.md + tasks.md ──▶ código + tests ──▶ PR ──▶ main
                         │ revisión     │ revisión            │ CI verde
                         ▼              ▼                     ▼
                       Aprobado      Planificado            Hecho
```

| Paso | Skill | Entrada | Salida | Puerta |
|---|---|---|---|---|
| 1. Especificar | `/sdd-spec <tarea o feature>` | Tarea de ACTION_PLAN + docs de producto | `spec.md` en estado *Borrador* | El usuario revisa requisitos y cierra preguntas abiertas → *Aprobado* |
| 2. Planificar | `/sdd-plan <NNN>` | `spec.md` *Aprobado* + constitución | `plan.md` + `tasks.md` → *Planificado* tras revisión | Check de constitución sin violaciones sin justificar |
| 3. Implementar | `/sdd-implement <NNN>` | `tasks.md` | Código, tests, tareas marcadas | Definición de hecho (constitución §4) |

El plan se escribe **justo antes** de implementar, no antes: un plan escrito semanas antes envejece. Por eso
solo el spec de la feature en curso tiene `plan.md`; los siguientes pueden tener solo `spec.md`.

**Excepciones** (sin spec): spikes desechables (como ACTION_PLAN Tarea 0.5; su resultado se anota donde diga la
tarea), arreglos de una línea y cambios de documentación.

## 3. Estados

`Borrador` → `Aprobado` → `Planificado` → `En curso` → `Hecho` (o `Descartado`).

El estado vive en la cabecera de `spec.md` y en la tabla de §6. Solo el usuario pasa un spec a *Aprobado* y un
plan a *Planificado*.

## 4. Convenciones de los specs

- **Idioma**: prosa en español; identificadores (clases, señales, archivos, acciones de input) y palabras clave
  EARS en inglés (ADR [0003](decisions/0003-lightweight-sdd.md)).
- **Requisitos en EARS** (Easy Approach to Requirements Syntax), uno por línea, cada uno verificable:

  | Patrón | Forma |
  |---|---|
  | Siempre | `THE <sistema> SHALL <respuesta>` |
  | Evento | `WHEN <disparador>, THE <sistema> SHALL <respuesta>` |
  | Estado | `WHILE <estado>, THE <sistema> SHALL <respuesta>` |
  | No deseado | `IF <condición>, THEN THE <sistema> SHALL <respuesta>` |
  | Opcional | `WHERE <característica>, THE <sistema> SHALL <respuesta>` |

- **IDs trazables**: requisito `R-NNN-XX`, tarea `T-NNN-XX`. Cada tarea cita los requisitos que cubre; cada
  requisito se verifica con al menos un test (`test_r_nnn_xx_*`) o con un paso manual descrito en el plan.
- **Preguntas abiertas**: todo hueco de diseño va a la sección "Preguntas abiertas" del spec. Si afecta a
  producto, también a `PMV.md §10`. Un spec con preguntas abiertas que bloquean no pasa a *Aprobado*.

## 5. Ramas, commits y PR

- **Una sola base de código y una sola rama principal** para móvil y PC (ADR [0001](decisions/0001-single-codebase-pc-dev-android-product.md)).
  No hay ramas por plataforma.
- **Una rama corta por spec**: `feat/NNN-slug` (o `fix/…`, `chore/…`), creada desde `main`, fusionada por PR
  con CI verde. Nunca se commitea directo a `main`.
- **Conventional commits** en inglés con el ID del spec: `feat(battery): drain battery while moving (spec 003)`.
- Una feature = un PR. Si un PR crece más allá de su spec, se parte.

## 6. Índice de specs

| ID | Feature | Tarea ACTION_PLAN | Estado |
|---|---|---|---|
| [001](001-project-bootstrap/spec.md) | Proyecto Godot y arnés de desarrollo | 0.1 (+ CI, tests, input) | Hecho |
| [002](002-iso-scene-player-movement/spec.md) | Escena isométrica y movimiento del robot | 0.2, 0.3 | Hecho |
| [003](003-battery/spec.md) | Batería: consumo, señales y HUD | 0.4 | Hecho |
| — | Spike de navmesh (sin spec, desechable) | 0.5 | — |
| [004](004-green-zone/spec.md) | Zona verde, `zone_id`, RNG con semilla y cajas de loot | 1.1 | Hecho |
| [005](005-inventory/spec.md) | Inventario (`InventoryComponent`, UI) y loot al jugador | 1.2 | Hecho |
| [006](006-zombies/spec.md) | Zombies: `HealthComponent`, IA, spawner con pool | 1.3 | Hecho |
| [007](007-melee-combat/spec.md) | Combate cuerpo a cuerpo y XP por muerte | 1.4 | Hecho |
| [008](008-death-recovery/spec.md) | Muerte, `RulesetData`, objetos caídos y recuperación | 1.5 | Hecho |
| [009](009-base-placement-charging/spec.md) | Escena de base, viaje entre zonas, colocación libre y estación de carga | 2.1, 2.8, 2.2 | Aprobado (plan en borrador) |
| [010](010-save-profile-world/spec.md) | Guardado Perfil/Mundo, `IStore` | 2.3 | Aprobado |
| 011 | Crafteo y `RecipeData` | 2.4 | Por crear |
| 012 | Generador eólico y cofres | 2.5, 2.6 | Por crear |
| 013 | Nivel de chasis | 2.7 | Por crear |
| 014 | Piezas, ranuras y degradación | 3.1, 3.2 | Por crear. Condición de entrada (spec 008, R-008-11): la durabilidad y el `uid` de `ItemStack` pasan por `InventoryRules` y `copy()`, para que el objeto caído los conserve |
| 015 | Robot hostil y drops | 3.3 | Por crear |
| 016+ | Fases 4-6 (HUD, menús, audio, feedback, guía, export) | 4.x-6.x | Por crear |

La numeración de "Por crear" es orientativa; se fija al crear cada spec.

## 7. Estructura

```
specs/
├── README.md               # este archivo
├── constitution.md         # principios y definición de hecho
├── architecture.md         # capas, flujo de escenas, patrones comunes, preparación para servidor
├── _templates/             # spec.md, plan.md, tasks.md, adr.md
├── decisions/              # ADRs numerados (NNNN-slug.md)
└── NNN-slug/               # una carpeta por feature
    ├── spec.md
    ├── plan.md             # solo cuando la feature va a implementarse
    └── tasks.md
```
