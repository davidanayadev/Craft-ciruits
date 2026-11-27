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
| [009](009-base-placement-charging/spec.md) | Escena de base, viaje entre zonas, colocación libre y estación de carga | 2.1, 2.8, 2.2 | Hecho |
| [010](010-save-profile-world/spec.md) | Guardado Perfil/Mundo, `IStore` | 2.3 | Hecho |
| [011](011-crafting-repair/spec.md) | Crafteo de piezas y reparación en el banco | 2.4 | Hecho |
| [012](012-wind-generator-chests/spec.md) | Generador eólico, baterías portátiles y cofres | 2.5, 2.6 | Hecho |
| [013](013-loot-box-sites-container-ui/spec.md) | Cajas de loot en sitios variables por visita y nueva pantalla de contenedor | Revisión de 1.1 y 2.6 | Hecho |
| [014](014-chassis-level/spec.md) | Nivel de chasis (10 niveles, ranuras de 5 a 8, máximo de pila de los materiales) | 2.7 | Hecho. La condición de entrada de la spec 010 (plan §7: al cargar, el nivel se aplica antes de que `InventoryComponent` lea sus ranuras) es R-014-16 (plan D5) |
| [015](015-pieces-slots-degradation/spec.md) | Piezas, ranuras y degradación | 3.1, 3.2 (y el punto pendiente de 1.5) | Hecho. La condición de entrada de las specs 008 y 010 (durabilidad y `uid` conservados al apilar, tirar, morir y guardar el objeto caído) la cumple la spec 011, que también crea `PieceData` y las tres piezas. Esta spec cierra las preguntas 6 y 8 de la 011 (reparar piezas equipadas, Core de repuesto al morir) y cambia la recogida de la 008: el objeto caído pasa a ser un contenedor (sustituye a R-008-13 y R-008-15). Una pieza que llega a 0 se quita de su ranura (BALANCE §4.1), no se queda a 0: `InventoryRules.is_valid_stack` rechaza una pieza a 0 al cargar (plan 011 §7) |
| [016](016-hostile-robot/spec.md) | Robot hostil y drops | 3.3 | Hecho. Condición de entrada (plan 011 §7): las piezas del loot se crean con `uid` y durabilidad (`CraftingSystem.create_result` o un equivalente al 50 %), nunca con `ItemStack.new(item, n)`, que `add_stacks` rechaza para una pieza (R-016-16) |
| 017 | Recuerdos, huecos del Core y fuentes nuevas de XP | 3.4 | Por crear. Depende de la 014 (niveles) y la 015 (`StatsComponent`, `StatModifier`, Core equipado). Decisiones en PMV §6.3 y §10 ("Progresión y recuerdos"), valores en BALANCE §6 |
| 018+ | Fases 4-6 (HUD, menús, audio, feedback, guía, export) | 4.x-6.x | Por crear |

La numeración de "Por crear" es orientativa; se fija al crear cada spec. La spec 013 (2026-11-21) corrió una
posición las siguientes (nivel de chasis 014, piezas 015, robot hostil 016) y las referencias de specs, docs y
código se cambiaron a la vez; un "spec 013" anterior a esa fecha en el historial de git es el nivel de chasis
(spec 013, pregunta 10).

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
