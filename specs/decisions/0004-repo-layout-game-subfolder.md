# ADR 0004 — El proyecto Godot vive en `game/`

| Campo | Valor |
|---|---|
| **Estado** | Aceptada |
| **Fecha** | 2026-11-13 |

## Contexto

La raíz del repo tiene los documentos de diseño, `specs/`, `CLAUDE.md` y tendrá la CI (`.github/`) y la
configuración de Claude Code (`.claude/`). Si `project.godot` estuviera en la raíz, todo eso entraría en
`res://`: el editor lo escanea y se mezcla con el contenido del juego.

## Decisión

`project.godot` en `game/`. Dentro de `game/` se aplica la estructura de PMV.md §4.2, más:

```
game/
├── addons/gut/          # framework de tests (ADR 0002), sin editar a mano
├── tests/
│   ├── unit/            # lógica pura, sin árbol de escena
│   └── integration/     # escenas y cableado de señales
└── i18n/                # traducciones ES + EN (CSV)
```

Raíz del repo:

```
/                        # docs de diseño (*.md), CLAUDE.md
├── specs/               # SDD
├── tools/               # scripts de desarrollo (ejecutar tests, etc.)
├── .github/workflows/   # CI
└── .claude/             # skills y ajustes de Claude Code
```

## Alternativas

| Opción | A favor | En contra |
|---|---|---|
| **`game/` subcarpeta** (elegida) | Separación limpia; `res://` solo contiene el juego; CI con `--path game` | Una ruta más en los comandos |
| Proyecto en la raíz + `.gdignore` en carpetas de docs | Rutas más cortas | Los `.md` de la raíz siguen dentro de `res://`; hay que mover los docs a una carpeta |

## Consecuencias

- Todos los comandos de Godot usan `--path game`.
- `i18n/` es una carpeta nueva respecto a PMV.md §4.2 (no tenía sitio para las traducciones).
