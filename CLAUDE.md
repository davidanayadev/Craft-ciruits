# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository state

Specs 001 (project bootstrap), 002 (isometric scene and robot movement, ACTION_PLAN Tareas 0.2-0.3), 003
(battery, ACTION_PLAN Tarea 0.4), 004 (green zone, ACTION_PLAN Tarea 1.1), 005 (inventory, ACTION_PLAN
Tarea 1.2), 006 (zombies, ACTION_PLAN Tarea 1.3), 007 (melee combat and XP on kill, ACTION_PLAN Tarea 1.4) and
008 (death, dropped items and recovery, ACTION_PLAN Tarea 1.5) are done and merged. Spec 009 (base scene, travel
between zones, free placement and charging station, ACTION_PLAN Tareas 2.1, 2.8, 2.2) is done. Spec 010 (save in two
levels, Profile and World, and `IStore`, ACTION_PLAN Tarea 2.3) is done. Spec 011 (crafting pieces and repair at the
bench, ACTION_PLAN Tarea 2.4) is done. Spec 012 (wind generator, portable batteries and chests, ACTION_PLAN
Tareas 2.5, 2.6) is done. Spec 013 (loot boxes on sites that change per visit and the reworked container screen, a
revision of ACTION_PLAN Tareas 1.1 and 2.6) is done. Spec 014 (chassis level, ACTION_PLAN Tarea 2.7) is done. Spec 015
(pieces, slots and degradation, ACTION_PLAN Tareas 3.1, 3.2) is done.
`game/` has its
settings, i18n, InputMap, GUT 9.7.1 (ADR
`specs/decisions/0002-test-framework-gut.md`), export presets, CI, and a playable prototype
(`game/scenes/main.tscn`: a persistent `Main` that starts in the base, the green farm zone generated from the world
seed and the visit, isometric camera rig, `Robot` moved
by keyboard or a floating touch joystick, a `BatteryComponent` that drains by gait, loot boxes opened with the HUD
"Interact" button or E and a battery `Hud`). The robot owns
an `InventoryComponent` (its slots grow with the chassis level, stacking rules in `InventoryRules`). The zone's box markers are grouped in sites (`%BoxMarkers`, one
`Node3D` per site), and `ZonePopulation.pick_box_markers` picks how many boxes and which markers from world seed +
`zone_id` + visit, with at most `box_max_per_site` per site. A box keeps its roll
in its own `InventoryComponent` and opens the `ContainerScreen`, where stacks move between the box and the
inventory (a box is never disabled, also when empty); the storage button (Tab)
opens the inventory screen. Both screens go through `UIManager` (a node under `UI`, not an autoload), which blocks
the robot's input while one is open without pausing the game. Slow and fast zombies (`EnemyData`, a
`HealthComponent`, the pure `EnemyBrain` state machine and a `NavigationAgent3D` on the zone's baked navmesh)
patrol, chase and hit the robot, which loses battery through `Robot.receive_hit`. `ZombieSpawner` places them
from the world seed and the visit number, taking them from an `ObjectPool` under `World`. The zombie model is a
placeholder made of primitives. The robot fights with the stats of its equipped arms, or with one bare arm
(`AttackStatsData` from `StatsComponent.get_attack`, rules in the pure `CombatSystem`): its `MeleeAttackComponent` swings on the HUD attack button, Space or left click (read through
`PlayerInput.poll_attack`, never from the action state, so HUD clicks are not attacks), each swing costs battery
and its impact is one shape query that only sees `HurtboxComponent`s. A zombie killed by a player emits
`EventBus.enemy_killed` and the killer's `ExperienceComponent` adds the XP of its `EnemyData`. The chassis level
(spec 014) is derived from the total XP with the pure `ChassisLevelSystem` and the 10-level table in
`chassis_levels.tres` (`ChassisLevelData`); it lives in the `ExperienceComponent`, which emits `level_changed` (state)
and `level_up` (fact, never on load), never goes down, and is never saved: only the XP is. `Robot` sets the inventory
slots from the level (5 to 8), and `Experience` sits before `InventoryComponent` in `robot.tscn` so the level is
applied before the saved slots load. XP and level show in the debug HUD only, which has a "Level up" button. `CombatFeedback` wires the white hit flash, camera shake, pooled impact sparks and the red screen edge.
Death is real (spec 008): at 0 battery `DeathController` applies the world's `RulesetData` (only `normal.tres`),
the inventory falls where the robot died as a pooled `DroppedItem`, the zone's visit counter (in `GameManager`)
goes up and the zone is repopulated (new zombies, boxes closed with the contents of the new visit), the
`TransferScreen` covers the game for 2 s and the robot reappears with full battery in the base. A dropped item is a container (spec 015): "Interact" opens it in the `ContainerScreen` (`DroppedItemFlow`), expires after 5 minutes of real time
(`DroppedItemRules`, read through `ITimeService` / `LocalTimeService` from `GameManager.get_time_service()`) and
live under `World/DroppedItems`, outside the zone. Killed zombies roll a seeded drop table, and the inventory
screen throws a chosen quantity of a stack (`QuantitySelector`, `InventoryRules.split`). Seeds that depend on the
visit use `SeededRng.derive_seed_for_visit`. Zones are `ZoneData` resources (`BASE` or `FARM`, with their scene
path) and `ZoneLoader` keeps exactly one loaded under `World/ZoneSlot`: an `ExitPoint` ("Travel") loads the other
zone in a thread behind the `LoadingScreen`, with `World` frozen; leaving a farm zone by its exit counts a visit,
and the dropped items of an unloaded zone are kept and restored. The base (`scenes/base/base.tscn`, `BaseZone`) has
a repair bench and a build area on a pure `BuildGrid`. The bench opens the `BenchScreen` (spec 011, tabs Build, Craft
and Repair). Build lists the charging station recipe, paid with `CraftingSystem` and `InventoryRules.remove_many`;
Craft makes the three basic pieces (`PieceData`, `stack_max` 1, unique `ItemStack`s with `uid` and durability) and
Repair restores a damaged piece with the tiers of `RepairCostData`. `CraftingSystem` decides (`check_craft`,
`check_repair`) and `InventoryComponent.craft` / `repair` change the slots; `RepairBench.craft` / `repair` emit
`EventBus.item_crafted` / `piece_repaired`, which save the World. Every path that moves a stack (`add_stack`, split,
take, drop, death, the dropped item's save) keeps a piece's durability and `uid`, and `add` of a piece id is
rejected. The `PlacementScreen` places, or with the
HUD "Edit base" button moves, structures on the grid with a valid/invalid preview while the robot stands still.
`BaseStructures` under `World` owns the placed structures. A `ChargingStation` recharges the robot to 100%
instantly; the base itself does not recharge. The game saves (spec 010): the `SaveManager` autoload writes a Profile
(`player_uuid`, entitlements) and one World (header with seed as text, per-player and world parts) through
`ISaveStore` / `LocalSaveStore` (encrypted JSON under `user://saves/`, safe write with backup). Every owner of
persisted state is in the `persistent` group with `get_save_key()` / `to_save_data()` / `from_save_data()`, and
loading emits state signals only, never fact signals. `SaveFlow` in `Main` loads at start-up and holds saves during a
travel or a death; saves happen on entering the base, recharging, dying, building or moving, crafting or repairing,
collecting batteries, closing a chest that changed, closing and going to the background. Tests never touch real saves: a GUT pre-run hook installs a `MemorySaveStore` and tests that start `Main`
call `SaveTestSupport.start_world()` / `reset()`. `IStore` / `LocalStore` (always demo) come from
`GameManager.get_store()`. The bench also builds a wind generator and storage chests (spec 012), each kind with a
`max_count` in its `StructureData`. While a generator is placed, `BaseStructures` raises the maximum of every robot's
`BatteryComponent` (`set_maximum_bonus`), and the generator makes portable batteries (`ConsumableData`) on the real
clock (pure `WindGeneratorRules`, time from `ITimeService`); interacting collects them. A portable battery is used
from the inventory screen's "Use" button or Q (`ConsumableRules`, `Robot.use_consumable`). The state of chests
(an `InventoryComponent` each) and generators (`WindGeneratorComponent`) lives in `StructureStates` under
`BaseStructures`, keyed by structure `uid`, so it outlives the base scene and is saved in its part.
`StructureUseFlow` in `Main` opens a chest in the `ContainerScreen` (spec 013: a header with name and occupancy over each grid,
a fixed action card; a tap only selects, the move button names its destination, "Place..." is an explicit mode left
with Cancel or back, "Take all", and the receiving slots light up; moves through `InventoryRules.move_to_slot` /
`transfer`) or collects from a generator. Bench, inventory
and container screens close with a tap outside their panel (`UIScreen.closes_on_outside_tap`). The `EventBus`,
`GameManager`, `DataRegistry` and `SaveManager` autoloads exist. Pieces are equipped (spec 015): the robot's
`EquipmentComponent` (first of the `persistent` group in `robot.tscn`) holds an Arms, a Legs and a Core slot, the inventory
screen's `EquipmentPanel` equips and unequips with durability bars and the resulting stats, and `StatsComponent`
computes the final stats from `robot_base_stats.tres` and the pieces' `StatModifier`s (pure `StatsCalculator`) for the
battery, movement and attack. Each hit takes the wear of the pure `DegradationSystem` from the first intact piece in
the order Arms, Legs, Core, and a piece at 0 breaks and leaves its slot. On death the Normal ruleset keeps the Core;
arms and legs fall with the inventory. The bench repairs equipped pieces too, and the HUD battery bar turns orange
below the low-battery threshold. A new world starts with the basic Core and Legs. The next spec is 016 (hostile
robot, ACTION_PLAN Tarea 3.3).

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

## Subagents

Delegate to save cost: cheap models for mechanical work, fresh eyes at review gates. Details and rationale:
`.claude/SUBAGENTS.md`.

| When | Use |
|---|---|
| After each task, before saying something is done, or when CI fails | `godot-runner` (instead of running `tools/run_tests.sh` in the main session) |
| Test-first step of `/sdd-implement` for a task with several requirements | `gut-test-writer` (pass the spec and R/T ids) |
| Before a plan passes its review gate | `architecture-guardian plan NNN` |
| Definition of Done | `godot-runner`, `i18n-auditor` and `balance-auditor` in parallel, then `architecture-guardian` once |
| A fix attempt failed, or the bug is intermittent or unclear | `deep-debugger` |
| Wide search across many files | built-in `Explore` |
| Closing a spec, after the auditors and before marking it `Hecho` | `system-documenter spec NNN` (updates `docs/systems/`) |

Do not delegate tasks of 1–3 tool calls, commit messages or PRs (the main session knows why the code changed), or
work another subagent already reported on. Run Opus agents (`architecture-guardian`, `deep-debugger`) only at the
points above, not after every change.

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
| `docs/systems/` | How the implemented code works today, one page per system, linking to the why in specs and ADRs (never numbers or requirements) |

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
  (JSON encrypted with `FileAccess` file encryption, AES-256, with a backup copy and fallback to it on corruption),
  `AudioManager`, plus `TutorialManager`. The architecture (ADR 0005) adds `EventBus` and `DataRegistry`
  (closed list in `specs/architecture.md` §5). Later: `OnlineManager`, `MultiplayerManager`.
- **Per-player state lives in components, never in autoloads:** battery in `BatteryComponent`,
  inventory in `InventoryComponent`, both on the player entity. LAN co-op (v2.0) depends on this.
- **Components** attached to entities: `BatteryComponent`, `HealthComponent` (enemies),
  `InventoryComponent`, `EquipmentComponent` (slots and the wear of pieces), `StatsComponent` (final stats),
  `InteractableComponent` and `InteractorComponent` (`specs/architecture.md` §6, §9). There is no
  `DegradationComponent`: the wear rule is the pure `DegradationSystem` (spec 015).
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
- **XP values for crafting, repairing and emptying a box site, and the level 6–10 curve.** Pending in
  BALANCE.md §6.2; review with `balance-auditor` and an in-game test before closing them.
