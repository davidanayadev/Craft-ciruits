# Tareas 015 — Piezas, ranuras y degradación

> Orden de ejecución. Cada tarea deja el proyecto compilando y los tests en verde. Marcar `[x]` al terminar.

- [ ] **T-015-01** Comprobar en Godot 4.7.2 las tres APIs de plan §5.1 (`roundi` con medios, estilo `fill` de
  `ProgressBar` y su override en ejecución, enum de otra clase exportado en un `.tres`) y anotar el resultado en
  §5.1. Cubre: — (habilita R-015-21, R-015-43, R-015-01). Verifica: script headless o referencia de clases (`--doctool`).
- [ ] **T-015-02** Test primero: `StatIds`, `StatModifier`, `RobotBaseStatsData` + `robot_base_stats.tres`, y
  `PieceData.slot_type` / `modifiers` en las tres piezas (plan §4). Cubre: R-015-01, R-015-02 (datos nuevos), R-015-06.
  Verifica: `test_robot_base_stats.gd`, `test_piece_resources.gd` (nuevos casos).
- [ ] **T-015-03** Test primero: `StatsCalculator`. Cubre: R-015-03, R-015-04. Verifica: `test_stats_calculator.gd`.
- [ ] **T-015-04** Test primero: `DegradationSystem`. Cubre: R-015-21 (cálculo), R-015-22 (nada equipado). Verifica:
  `test_degradation_system.gd`.
- [ ] **T-015-05** Test primero: `StatsComponent` (`recompute`, `get_stat`, `get_movement` con `can_run` derivado,
  `get_attack`). Cubre: R-015-05, R-015-13 (componente). Verifica: `test_stats_component.gd`.
- [ ] **T-015-06** Test primero: `InventoryComponent.exchange_slot` y `EquipmentComponent` (ranuras, equipo inicial,
  `equip_from`, `unequip_to`, `apply_hit_wear`, rotura, `take_slots`, guardado y carga). Cubre: R-015-07 a R-015-12,
  R-015-20, R-015-21, R-015-23, R-015-37, R-015-39, R-015-40, R-015-41, R-015-53 (señal). Verifica:
  `test_equipment_component.gd`, `test_inventory_component.gd` (nuevos casos).
- [ ] **T-015-07** Test primero: **añadir** a `BatteryComponent` `set_base_maximum` (regla compartida de D6),
  `set_drain_rates` e `is_low`, y a `MeleeAttackComponent` `set_attack` con el golpe en curso y la forma construida
  solo con `config` (D11). Los `@export legs` y `attack`, el llenado en `_ready` y los campos viejos se quedan hasta
  T-015-08, para que `robot.tscn` y la suite sigan en verde. Cubre: R-015-17, R-015-18, R-015-19, R-015-43 (regla),
  R-015-44 (componente). Verifica: `test_battery_component.gd`, `test_melee_attack_component.gd`.
- [ ] **T-015-08** Cablear `Robot`: nodos `Equipment` (primero del grupo `persistent`) y `Stats` en `robot.tscn`,
  `_on_equipment_changed`, `_apply_stats`, `equip`, `unequip`, desgaste antes de la batería en `receive_hit`; **quitar**
  ahora `BatteryComponent.legs`, su llenado en `_ready`, el `@export attack` de `MeleeAttackComponent` y
  `Robot.movement_stats`; borrar los tres `.tres` de D4 y los campos de `BatteryConfigData`; adaptar los tests de §5.3
  que leen esos recursos (suite entera). Cubre: R-015-02, R-015-05, R-015-06, R-015-12 (robot), R-015-13 a R-015-16, R-015-18, R-015-19,
  R-015-22, R-015-23, R-015-44, R-015-54. Verifica: `integration/test_robot_equipment.gd` (nuevo) y suite completa con
  `godot-runner`.
- [ ] **T-015-09** Muerte: `DeathController` con `take_slots` según el ruleset y `drop_inventory` con piezas y una
  ranura por pila. Cubre: R-015-25 a R-015-28, R-015-47 (muerte), R-015-51, R-015-54 (golpe mortal). Verifica:
  `test_death_controller.gd` (nuevos casos y §5.3).
- [ ] **T-015-10** Objeto caído como contenedor: `DroppedItem.opened` y `slot_count` en `to_data`;
  `DroppedItemSpawner` con `item_opened`, `item_removed`, `release_if_empty` y restauración con `slot_count`;
  `ContainerScreen.Kind.DROPPED`; `UIManager.close(screen)`; `DroppedItemFlow` en `main.tscn`; prompt "Abrir" en
  `dropped_item.tscn` y `PROMPT_PICK_UP` borrado de `strings.csv` (D14). Cubre: R-015-45 a R-015-50, R-015-55. Verifica:
  `test_dropped_item.gd`, `test_dropped_item_spawner.gd`, `test_container_screen.gd`,
  `integration/test_dropped_item_flow.gd` (nuevo), `test_main_scene.gd` (§5.3).
- [ ] **T-015-11** Reparar lo equipado: `CraftingSystem.check_repair_stack`, `EquipmentComponent.repair`,
  `RepairBench.repair` por `uid`, `BenchRepairSection` y `BenchScreen`. Cubre: R-015-29, R-015-30. Verifica:
  `test_crafting_system.gd`, `test_equipment_component.gd`, `test_repair_bench.gd`, `test_bench_screen.gd`.
- [ ] **T-015-12** `DurabilityDisplayData` + `durability_display.tres` y panel de equipo en la pantalla de inventario
  (selección, Equipar / Quitar, ficha con durabilidad, aviso, stats). Cubre: R-015-31 a R-015-36, R-015-52, R-015-53
  (vista). Verifica: `test_durability_display_data.gd`, `test_inventory_screen.gd`.
- [ ] **T-015-13** HUD: aviso "Pieza rota" y barra naranja por debajo del umbral. Cubre: R-015-24, R-015-43. Verifica:
  `test_hud.gd`.
- [ ] **T-015-14** Guardado de punta a punta: orden de carga, carga con y sin parte `equipment`, mundo nuevo, objeto
  caído con ranuras vacías. Cubre: R-015-38, R-015-39, R-015-40, R-015-41, R-015-42, R-015-55. Verifica:
  `integration/test_save_load.gd`.
- [ ] **T-015-15** Claves de texto de plan §4 (ES + EN) y documentación: architecture §6, §7, §9.1, §9.3, §9.4, §9.5,
  §10.2 (D20) y docstrings (`Robot`, `hit_received`, `MovementStatsData`, `AttackStatsData`). PMV.md §4.2-§4.3,
  CLAUDE.md y ACTION_PLAN.md Tarea 3.1 (aprobado por el usuario el 2026-11-24, D20). Cubre: R-015-36. Verifica:
  `i18n-auditor`, revisión del diff.
- [ ] **T-015-16** Pasos manuales M1-M7 en PC y Android (APK debug), con el resultado anotado en plan §5.2. Cubre: los
  pasos manuales de §5.2. Verifica: el usuario.

## Cierre

- [ ] Definición de hecho (constitución §4) revisada: `godot-runner`, `i18n-auditor` y `balance-auditor` en
  paralelo, después `architecture-guardian`; `system-documenter spec 015`.
- [ ] Estado del spec actualizado en `spec.md` y en `specs/README.md §6`.
