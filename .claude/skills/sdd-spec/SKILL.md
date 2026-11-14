---
name: sdd-spec
description: Create or update a feature spec (specs/NNN-slug/spec.md) for CyberScrap from an ACTION_PLAN task, following the project's spec-driven workflow. Use when the user asks to specify, spec out or start a new feature.
argument-hint: "<ACTION_PLAN task number or feature name>"
disable-model-invocation: true
---

Create the spec for: $ARGUMENTS

1. Read `specs/README.md` and `specs/constitution.md`. They define the workflow, EARS format, IDs and states.
   Do not restate them here or in the spec.
2. Find the matching ACTION_PLAN.md task and every source it depends on (PMV.md, BALANCE.md, SPECS.md, ONLINE.md,
   ADRs in `specs/decisions/`). Read them; do not work from memory.
3. Pick the next free `NNN` from `specs/README.md §6` and copy `specs/_templates/spec.md` to
   `specs/NNN-slug/spec.md`. Do not create `plan.md` or `tasks.md`.
4. Write requirements in EARS, one verifiable behaviour each, with a source per row. Cite numbers by their
   BALANCE.md section; never invent a value.
5. Every gap, ambiguity or contradiction between documents goes to "Preguntas abiertas" with a proposal and
   whether it blocks. Mark items in PMV.md §2.3 or tagged v1.1+ as out of scope.
6. Set the state to `Borrador`, update the table in `specs/README.md §6`, and stop. Summarise the open questions
   for the user; only the user moves a spec to `Aprobado`.
