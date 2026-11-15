---
name: sdd-plan
description: Write the technical plan and task list (plan.md, tasks.md) for an approved CyberScrap spec, checked against the constitution. Use when the user asks to plan a spec that is already approved.
argument-hint: "<spec number NNN>"
disable-model-invocation: true
---

Plan spec: $ARGUMENTS

1. Open `specs/NNN-*/spec.md`. If its state is not `Aprobado` or it has blocking open questions, stop and say
   what is missing.
2. Read `specs/README.md`, `specs/constitution.md`, the ADRs and the existing code under `game/` that the
   feature touches (delegate wide searches to the built-in `Explore` subagent). Reuse existing components,
   resources and helpers before proposing new ones.
3. Copy `specs/_templates/plan.md` and `specs/_templates/tasks.md` into the spec folder and fill them:
   - Files, public contracts (signatures, signals, resources) and data with the BALANCE.md source of each value.
   - Verification: every requirement maps to a GUT test (`test_r_nnn_xx_*`) or a written manual step.
   - Constitution check for every principle the feature touches; justify any ⚠️.
   - Any engine API, project setting or addon option you are not certain exists in Godot 4.7.2 is marked
     **(verificar)** and gets a task to check it in the official docs before use.
   - Tasks are small, ordered, test-first for logic, and each one cites the requirements it covers.
4. Run the `architecture-guardian` subagent with `plan NNN`. Fix its blocking findings in the plan; list the
   rest, and any you disagree with and why, for the user.
5. Set the plan to `Borrador`, update the spec state in `specs/README.md §6`, and stop for review. Only the user
   moves it to `Planificado`.
