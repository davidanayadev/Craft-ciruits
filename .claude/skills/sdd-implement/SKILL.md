---
name: sdd-implement
description: Implement a planned CyberScrap spec task by task, test-first, on its own feature branch. Use when the user asks to implement or continue a spec whose plan is approved.
argument-hint: "<spec number NNN> [task id]"
disable-model-invocation: true
---

Implement spec: $ARGUMENTS

1. Open `specs/NNN-*/plan.md` and `tasks.md`. If the plan is not `Planificado`, stop.
2. Work on branch `feat/NNN-slug` (create it from `main` if missing). Never commit to `main`. Commit only when the
   user asks, using conventional commits with the spec id, e.g. `feat(battery): drain while moving (spec 003)`.
3. Take the first unchecked task (or the one given). For logic: write the failing GUT test, run
   `tools/run_tests.sh`, see it fail for the expected reason, implement, run again until green.
   - When the task covers several requirements or edge cases, delegate the failing tests to the
     `gut-test-writer` subagent (pass the spec number and the R/T ids) and review what it wrote.
   - Run the suite through the `godot-runner` subagent. Run `tools/run_tests.sh` directly only when you need the
     full log of one failure.
   - If a fix attempt fails, or a failure is intermittent or unclear, hand it to the `deep-debugger` subagent
     before trying again.
4. Follow `specs/constitution.md`: static typing, no gameplay literals (values in `.tres` from BALANCE.md), signals,
   i18n, no platform checks in gameplay, snake_case files.
5. Tick the task in `tasks.md`. If the code needs something the spec or plan does not say, stop and propose the
   spec/plan change instead of improvising.
6. Tasks marked **(usuario)** are for the user: explain what to do and wait.
7. When all tasks are done, run in parallel the `godot-runner`, `i18n-auditor` and `balance-auditor` subagents,
   then `architecture-guardian` once on the branch diff. Fix what they find or report it to the user.
8. Run the `system-documenter` subagent with `spec NNN` and tell it to update the index in
   `docs/systems/README.md`, so the pages land in the same PR that closes the spec. Fix the discrepancies it finds
   between code and spec or plan, or report them to the user.
9. Walk through the Definition of Done (constitution §4) with those reports, set the spec to `Hecho` in
   `spec.md` and `specs/README.md §6`, and report what was verified and what was not (e.g. not tested on Android).
