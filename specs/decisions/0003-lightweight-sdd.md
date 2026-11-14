# ADR 0003 — Spec-driven development propio y ligero

| Campo | Valor |
|---|---|
| **Estado** | Aceptada |
| **Fecha** | 2026-11-13 |

## Contexto

Claude programa el juego. Para que el código salga de decisiones cerradas y no de suposiciones, se adopta
spec-driven development (SDD). Referencias consultadas en nov 2026:

- **GitHub Spec Kit**: constitución → specify → (clarify) → plan → tasks → implement; una carpeta por feature con
  `spec.md`, `plan.md`, `tasks.md` y otros (`research.md`, `data-model.md`, `contracts/`). CLI en Python con `uv`;
  `specify init --ai claude` genera comandos en `.claude/commands/` y la constitución en `.specify/memory/`
  ([guía](https://www.augmentcode.com/guides/github-spec-kit-practical-guide-sdd-workflow),
  [CLI](https://www.mintlify.com/github/spec-kit/cli/overview)). GitHub lo presenta como experimento.
- **Kiro**: tres archivos por spec (`requirements.md` con historias y criterios en notación **EARS**,
  `design.md`, `tasks.md` enlazadas a requisitos), con aprobación humana entre fases
  ([docs](https://kiro.dev/docs/specs/concepts)).

El proyecto ya tiene seis documentos de diseño que hacen de "spec de producto", y en esta máquina no hay Python.

## Decisión

SDD propio inspirado en ambos, sin dependencias:

- Constitución (Spec Kit) + `spec.md` con requisitos EARS (Kiro) + `plan.md` + `tasks.md`, en `specs/`.
- Las fases tienen puerta humana: el usuario aprueba spec y plan.
- Skills de Claude Code en `.claude/skills/` (`sdd-spec`, `sdd-plan`, `sdd-implement`) que remiten a
  `specs/README.md` para no duplicar el flujo. Solo las invoca el usuario: cada una para en su puerta de revisión.
- Idioma: prosa en español, identificadores y palabras clave EARS en inglés.

## Alternativas

| Opción | A favor | En contra |
|---|---|---|
| **SDD propio** (elegida) | Cero dependencias; plantillas hechas para Godot; reutiliza los 6 docs como fuente | Mantenimiento propio de plantillas y skills |
| GitHub Spec Kit | Estándar con comunidad | Python + uv; plantillas orientadas a web/API; más archivos por feature; duplicaría los docs de producto |
| Kiro | EARS y diseño integrados | Es un IDE propio; no aplica a Claude Code |

## Consecuencias

- Los specs referencian los docs de producto en vez de copiarlos (constitución P2).
- Si el flujo se queda corto (p. ej. hace falta `research.md`), se amplía la plantilla con un ADR.
