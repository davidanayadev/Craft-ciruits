# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository state

Specs 001 (project bootstrap), 002 (isometric scene and robot movement, ACTION_PLAN Tareas 0.2-0.3) and 003
(battery, ACTION_PLAN Tarea 0.4) are done and merged. Spec 004 (green zone, ACTION_PLAN Tarea 1.1) is done on
`feat/004-green-zone`: `game/`
has its settings, i18n, InputMap, GUT 9.7.1 (ADR `specs/decisions/0002-test-framework-gut.md`), export presets, CI,
and a playable prototype (`game/scenes/main.tscn`: the green farm zone generated from the world seed, isometric
camera rig, `Robot` moved by keyboard or a floating touch joystick, a `BatteryComponent` that drains by gait, loot
boxes opened with the HUD "Interact" button or E, a battery `Hud` and a provisional game over screen that spec 008
replaces). The `GameManager` and `DataRegistry` autoloads exist. Boxes only announce their loot
(`loot_generated`): there is no inventory, combat or real death yet. The next spec is 005.

## Commands

Run from the repo root. `GODOT_BIN` points to the Godot 4.7.2 executable; every Godot command uses
`--path game`. `tools/*.sh` are Bash scripts (Git Bash on Windows).

| Task | Command |
|---|---|
| Run every test (headless; imports first and fails if any script does not load) | `tools/run_tests.sh` |
| Run the game on the desktop | `"$GODOT_BIN" --path game` |
| Re-import assets | `"$GODOT_BIN" --headless --path game --import` |
| Open the editor | `"$GODOT_BIN" --editor --path game` |
| Export a debug build to `builds/` | `"$GODOT_BIN" --headless --path game --export-debug "Android"` (or `"Windows Desktop"`) |
| CI | `.github/workflows/ci.yml`: runs `tools/run_tests.sh` on Linux for PRs and pushes to `main` |

Things that are easy to get wrong:
- `unsafe_call_argument` is an error, so a `Variant` (for example the result of `ProjectSettings.get_setting()`)
  cannot go straight into a GUT assert: assign it to a typed variable first.
- Tests live in `game/tests/unit/` and `game/tests/integration/`, one `test_<file>.gd` per class, with methods
  named `test_r_nnn_xx_<case>`.
- `project.godot` values fixed by a spec are guarded by `game/tests/unit/test_project_settings.gd` and
  `test_input_map.gd`.
- `game/addons/gut/` is third-party: never edit it; replace the whole folder to update.

## Spec-driven workflow

No production code without an approved spec. Read `specs/README.md` (flow, EARS, IDs, branches) and
`specs/constitution.md` (principles, Definition of Done) before any implementation work. Skills:
`/sdd-spec`, `/sdd-plan`, `/sdd-implement`; each one stops at its human review gate. Technical decisions live as
ADRs in `specs/decisions/`:
- 0001: one codebase and one main branch. Android is the product, Windows is the dev/test target only.
- 0002: GUT 9.7.1 for tests.
- 0003: lightweight in-repo SDD; specs in Spanish with English identifiers and EARS keywords.
- 0004: the Godot project lives in `game/`.
- 0005 (accepted): client architecture in `specs/architecture.md` (layers, persistent `Main` scene with one
  zone loaded at a time, interaction components, `ItemStack` inventory, stat modifiers, per-component JSON save,
  `EventBus` with a closed event list, `DataRegistry` catalog, `UIManager` screen stack, server readiness).
  Read it before planning any feature.

## The game

**CyberScrap** is a mobile (Android first, iOS later) 3D isometric survival game in the style of
*Last Day on Earth*. You play a modular robot whose arm, leg and core pieces change its stats,
degrade, and break. Engine: **Godot 4.7.2, GDScript**, **Compatibility renderer (OpenGL ES 3.0)**,
landscape 1920x1080 (portrait until Nov 14, 2026). It is local-first: the MVP has no server. The MVP budget is €0, so it uses only
free CC0/CC assets (Kenney, Quaternius, itch.io, Sketchfab, freesound).

The repo directory is named `Craft-ciruits`, but the game and project are called "CyberScrap" (renamed from
"Scrap Circuit" in November 2026). The Android package name is `com.davidanaya.cyberscrap`.

Post-MVP vision (decided November 2026, details in SPECS.md §19–§29):
- **Worlds by seed:** each save is a world with a random seed. A global map of cells, where each
  cell is a bounded zone generated from `seed + zone coordinate`. It is not a continuous world.
- **Modes:** Normal is the main mode. Hardcore is optional, single-player and offline only: death
  ends the world unless the player holds a craftable "Respaldo de consciencia". A hall of fame in the
  cross-world Profile grants cosmetics or blueprints.
- **Factions and lore:** rebel AI (telepathic), intelligent hive-mind infected, hostile or friendly
  humans. The player is a conscious robot from a failed consciousness-transfer experiment, and it is
  the only playable kind.
- **Fuel** is a craftable mobility item, not a travel timer. **Vehicles** can be electric or fuel.
- **Crafting** has three tiers: by hand, nanobots, workbench.
- **Business model:** the MVP ships as a free demo with no purchases. A one-time unlock arrives in
  v1.1, cosmetics are optional, and an online subscription exists only if servers cost money.
  **No ads.** LAN co-op for 4–6 players is free after the unlock.

## Which document owns what

The documents cross-reference each other. Treat each one as the source of truth for its own area:

| Doc | Owns |
|---|---|
| `PMV.md` | MVP scope (§2.1 includes, **§2.3 excludes**), code architecture and conventions (§4, future-proofing hooks in §4.5), MVP progression, **roadmap (§9)**, **open questions (§10)** |
| `BALANCE.md` | **All numeric values**: battery drain, enemy stats, drop tables, recipes, costs, XP curve |
| `ACTION_PLAN.md` | Ordered implementation tasks (Fase 0–6), with the script and scene names and the "done" criteria for each |
| `SPECS.md` | Post-MVP features (v1.1+): advanced pieces, red zone, abilities, vehicles, fuel, lore, business model (§23), worlds by seed (§26), Normal/Hardcore modes (§27), factions (§28), crafting tiers (§29) |
| `ONLINE.md` | Multiplayer roadmap (async, then co-op, then PvP) and the decoupling rules the MVP code must follow now |
| `TOOLING.md` | Third-party services and **the phase in which each one may be introduced** |

Rules that follow from this:
- **Scope:** anything listed in PMV.md §2.3, or tagged v1.1+ in SPECS.md, is out of scope for the MVP.
  Don't implement it unless asked. The docs name scope creep as a high-probability risk.
- **Numbers:** gameplay values come from BALANCE.md and live in data resources (`.tres`), never as
  literals in scripts. Balance changes go to BALANCE.md first, then to code (ACTION_PLAN Tarea 5.2).
- **Dependencies:** don't add Firebase, store billing, RevenueCat, Sentry or similar before the phase
  that TOOLING.md assigns to them. Never add an ad network.

## Architecture (planned, from PMV.md §4 and ONLINE.md)

- **Battery is the player's health.** The robot has no separate HP. It drains passively, from
  movement, from attacks and from enemy hits. Each hit also takes -5 durability from the first
  intact equipped piece, in the order Arms → Legs → Core. At 0 battery the robot dies. In Normal mode
  it loses everything except the Core and XP, items drop at the death position for later recovery,
  and it respawns at the base with 100% battery. The world's `RulesetData` decides the death reaction
  (only `NORMAL` exists in the MVP). The battery drains everywhere, the base included. Entering the base
  autosaves but does not recharge: only interacting with a Charging Station recharges to 100% (instant).
  Stations are crafted at the repair bench (unlimited, base only) and the base starts without one.
  Running needs legs: joystick pushed past 80% on touch, Shift on PC. Most systems connect to the battery.
- **No weapons in the MVP.** Damage comes from the equipped arms. XP is awarded directly on kill and
  is not an inventory item. Chassis level-ups (XP threshold, then more inventory slots) are applied
  by ACTION_PLAN Tarea 2.7 from a `ChassisLevelData` `.tres`.
- **Autoloads (singletons):** `GameManager` (global game state, not per-player state), `SaveManager`
  (JSON encrypted with `EncryptionContext`, with a backup copy and fallback to it on corruption),
  `AudioManager`, plus `TutorialManager`. The architecture (ADR 0005) adds `EventBus` and `DataRegistry`
  (closed list in `specs/architecture.md` §5). Later: `OnlineManager`, `MultiplayerManager`.
- **Per-player state lives in components, never in autoloads:** battery in `BatteryComponent`,
  inventory in `InventoryComponent`, both on the player entity. LAN co-op (v2.0) depends on this.
- **Components** attached to entities: `BatteryComponent`, `HealthComponent` (enemies),
  `InventoryComponent`, `DegradationComponent`. The architecture (ADR 0005) adds `EquipmentComponent`,
  `StatsComponent`, `InteractableComponent` and `InteractorComponent` (`specs/architecture.md` §6, §9).
- **Data as custom Resources:** `ItemData`, `PieceData`, `EnemyData` (with a `faction` field),
  `MaterialData`, `RecipeData` (`station`, `tier`, `requires`), `RulesetData`, `ChassisLevelData`,
  each as a `.tres` file under `resources/`.
- **Two save levels:** a *Profile* (anonymous player UUID, purchase entitlements, hall of fame,
  unlocked cosmetics and blueprints) that outlives worlds, and one *World* file per save (seed,
  ruleset, `schema_version`, player, base, per-zone deltas). The backup copy protects against
  corruption only, never against a Hardcore death.
- **Seeded worlds:** positions are stored as `(zone_id, local position)`. World generation uses a
  `RandomNumberGenerator` seeded from `world seed + zone_id`, never the global `randf()`.
- **Store behind a base class:** `IStore` with `LocalStore` (demo only, no purchases) in the MVP and
  native store billing from v1.1. Entitlements live in the Profile.
- **Pure logic in `scripts/systems/`** (`CraftingSystem`, `CombatSystem`, `DegradationSystem`),
  separated from scenes and presentation ("MVC-lite") so it can be tested.
- **Enemy AI** is a state machine (Idle/Patrol/Chase/Attack) using `NavigationAgent3D`. Enemies,
  projectiles and particles are **object-pooled** from the start.
- **Online readiness (ONLINE.md "Preparación del código desde el PMV"):** put swappable services
  (save, time, and later market and clan) behind a base-class contract with a local implementation.
  Only `OnlineManager` may talk to a backend. Use locally generated UUIDs for player IDs. Queue
  actions taken while offline. GDScript has no interfaces, so use a base class that the
  implementations extend, with one `class_name` per file.

## Code conventions (PMV.md §4.4)

- Code identifiers are in English. Design docs and discussion are in Spanish.
- Use static typing everywhere (`var battery: float`, `func take_damage(amount: int) -> void`).
- **i18n is mandatory from day one:** every player-visible string goes through Godot translation
  files (ES + EN). Never hardcode UI text.
- Don't use `get_node()` with hardcoded paths. Use `%UniqueName` or `@export` references.
- Use signals for anything cross-cutting. Unrelated systems never call each other directly.
- One responsibility per scene. Functions are short (the doc targets fewer than 20 lines).

## Mobile performance budget (PMV.md §3.2)

The targets are 30–60 FPS on mid-range Android and 60 FPS on high-end devices. Budget limits:

- about 50K–100K triangles on screen
- 2–3 dynamic lights
- one directional light with shadows
- no heavy post-processing

Use ETC2 texture compression, lightmaps for static lighting, LOD, and texture atlases. Keep these
limits in mind when adding scenes or effects.

## Open design gaps

The full list of open questions lives in **PMV.md §10** ("Preguntas abiertas"). Ask before
implementing anything that depends on one of them. None blocks the MVP. The ones closest to code:

- **Runtime navmesh on mobile.** Whether zones can be generated procedurally in v1.1, and whether
  player-built walls (v1.1, SPECS.md §32) can update enemy navigation, depends on the Tarea 0.5 spike.
- **Overclock duration and levels 6–10 (v1.1).** See SPECS.md §6.2–§6.3.
