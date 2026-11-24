# Plan 014 — Nivel de chasis

| Campo | Valor |
|---|---|
| **Spec** | [spec.md](spec.md) (debe estar *Aprobado*) |
| **Estado** | Planificado (2026-11-23) |

## 1. Enfoque

El nivel es un valor **derivado** de la XP total (R-014-15), así que lo guarda el mismo dueño de la XP:
`ExperienceComponent` gana el nivel actual, la tabla `ChassisLevelData` (por parámetro) y dos señales, `level_changed`
(estado) y `level_up` (hecho). El cálculo vive en un sistema puro nuevo, `ChassisLevelSystem`, que lee la tabla y no
conoce escenas. `Robot`, que ya dimensionaba el inventario con el nivel 1, pasa la tabla a su `ExperienceComponent` y
cambia el número de ranuras de su `InventoryComponent` en cada `level_changed`. Al cargar, `ExperienceComponent`
emite `xp_changed` y `level_changed`, nunca `level_up`; el nodo `Experience` pasa a estar antes que
`InventoryComponent` en `robot.tscn`, y como `SaveManager` aplica las partes en el orden del árbol (comprobado,
§5.1), el inventario ya tiene las ranuras del nivel cuando lee las suyas (R-014-16).

Las pantallas no cambian de código: la rejilla ya repinta su número de celdas y la cabecera de ocupación en cada
`inventory_changed`, que `set_slot_count` emite. Se añaden tests de que lo hacen y de que 8 ranuras caben.

El máximo de pila baja en los tres `.tres` de materiales, y un test del catálogo comprueba que toda receta y
reparación cabe en una pila.

**Alternativa principal descartada**: un `ChassisLevelComponent` aparte que escuche `xp_changed`. No puede
distinguir una ganancia (que emite `level_up`) de una carga (que no debe, R-014-17) sin una bandera de "cargando" o
una señal de hecho nueva en la XP; las dos cosas reparten entre dos nodos un estado que es uno solo (D1).

### 1.1 Decisiones del plan

| # | Decisión | Por qué |
|---|---|---|
| D1 | El nivel vive en `ExperienceComponent` (`_level`, `get_level()`), no en un componente nuevo ni en `Robot`. Sin renombrar la clase (P14). | R-014-06 (componente de la entidad, derivado de su XP). Solo el dueño sabe si un cambio de XP es una ganancia (`add_xp`, emite `level_up`) o una carga (`from_save_data`, solo estado), que es lo que pide R-014-17 (architecture §10.2). `Robot` es cableado (P3). |
| D2 | `ChassisLevelSystem` (estático, `scripts/systems/`): `level_for_xp(total_xp, levels)` y `xp_to_next_level(total_xp, levels)`. La tabla entra por parámetro. | R-014-03 a R-014-05, R-014-20. architecture §3 ya nombra `ChassisLevelSystem`. Testeable con tablas hechas a mano (P13), lo que además prueba que el número de niveles sale de la tabla (R-014-01). |
| D3 | La tabla se asigna una sola vez, en el `@export chassis_levels` que `Robot` ya tiene (`robot.tscn`). `Robot._ready()` la pasa con `experience.set_level_table(chassis_levels)` y conecta `experience.level_changed` a su `_on_level_changed`, que llama a `inventory.set_slot_count(chassis_levels.get_inventory_slots(level))`. `ExperienceComponent` no conoce el inventario. | Una fuente (P2): sin un segundo `@export` en `ExperienceComponent` con el mismo `.tres`. Componentes hermanos no se llaman entre sí; los une su entidad (P6, como ya hace `Robot` con la batería y el ataque). `ExperienceComponent` sigue sin leer autoloads. |
| D4 | Orden de señales en `add_xp`: `xp_changed` → `level_changed` → `level_up`, y como mucho una de cada por llamada, con el nivel final (R-014-07). | El inventario crece en `level_changed`, así que quien escuche `level_up` (notificación 4.1, sonido 4.3, recuerdos 017) ve ya las ranuras nuevas. |
| D5 | **Orden de carga (R-014-16).** En `robot.tscn` el nodo `Experience` se mueve justo antes de `InventoryComponent`. `SaveManager._apply_world` recorre `get_nodes_in_group(&"persistent")`, que devuelve los nodos en el orden del árbol, no en el de alta en el grupo, y sigue a `move_child` (comprobado en Godot 4.7.2, §5.1). Al cargar la XP se emite `level_changed`, `Robot` amplía el inventario y después `InventoryComponent.from_save_data` lee sus ranuras. Lo vigilan dos tests: uno de comportamiento (una partida con 8 pilas carga las 8) y otro que arranca `Main` y comprueba que `Experience` va antes que `InventoryComponent` en `get_nodes_in_group(&"persistent")`, el orden que de verdad recorre `SaveManager`. El invariante se escribe en architecture §10.2 y en el docstring de `SaveManager._apply_world` (D13). | Es el cambio más pequeño que cumple la condición de entrada de la spec 010 (plan 010 §7). Descartado: una prioridad de carga explícita en el contrato `persistent` (cambia `SaveManager` y architecture §10.2 por una sola dependencia; se puede añadir si aparece una segunda). Descartado: que el inventario crezca hasta el número de ranuras guardado (el número de ranuras saldría del archivo y no del nivel, en contra de R-010-24). |
| D6 | **XP que baja (R-014-11).** `reset()` y `from_save_data()` con un total menor cambian la XP (como hoy, R-008-28, R-010-09) pero dejan el nivel y las ranuras, con `push_error` que nombra el total anterior y el nuevo. Vale para cualquier bajada, como dice la spec (pregunta 6), también la de un ruleset de prueba sin `keeps_xp`. | En el PMV la XP nunca baja (`normal.tres` la conserva y solo se carga al arrancar, con un robot nuevo). Los tests que bajan la XP a propósito pasan a afirmar ese error con `assert_push_error` (§5.3): se añade una aserción, no se quita ninguna. |
| D7 | **Señales al cargar (R-014-17).** Toda carga válida de `from_save_data` emite `xp_changed(total)` y `level_changed(level)` una vez cada una, también si el valor no cambió, y nunca `level_up`. Una carga no válida (R-010-11) no emite nada, como hoy. | R-014-17 lo pide sin condición. Son señales de estado: repetirlas no tiene efecto (`Robot._on_level_changed` con el mismo nivel llama a `set_slot_count` con el mismo número, que no hace nada). Cambia `test_r_010_09_load_same_total_emits_nothing`, que pasa a esperar una emisión de cada (§5.3): lo pide un requisito nuevo, no es debilitarlo. |
| D8 | `ChassisLevelData.validate()` añade "el primer umbral no es 0" (R-014-02) y pasa de pedir ranuras **crecientes** a ranuras **no decrecientes**. Se añade `get_xp_required(level) -> int`, simétrico de `get_inventory_slots`. | BALANCE §6.1 repite 5 ranuras en los niveles 1-4 y 8 en los 7-10: con la regla de spec 005 la tabla nueva no sería válida. El test `test_r_005_02_validate_rejects_bad_tables` deja de rechazar `[5, 5]` porque cambia la regla, no por debilitarlo (§5.3). Los umbrales siguen estrictamente crecientes. |
| D9 | `ExperienceComponent` sin tabla o con una no válida: la XP se acumula como hoy y el nivel se queda en 1, con el `push_error` de `ChassisLevelSystem` (R-014-05). | Errores visibles, sin fallo silencioso (constitución §2). `Robot` siempre la pasa; el helper de `test_experience_component.gd` también (§5.3). |
| D10 | Debug HUD: `%LevelLabel` ("Level: n") junto a `%XpLabel`, que sigue `level_changed`, y `%LevelUpButton` ("Level up") que hace `add_xp(ChassisLevelSystem.xp_to_next_level(total, player.chassis_levels))`. En el último nivel la cantidad es 0 y `add_xp(0)` no cambia nada. Textos en inglés sin traducir, como "Fill base". | R-014-19, R-014-20. El debug HUD solo se ve en builds de depuración (`visible = OS.is_debug_build()`, spec 007), así que no es texto del jugador (P11). Pasar por `add_xp` prueba el camino real de subida. |
| D11 | Pantallas sin cambio de código. `InventoryGrid._refresh` ajusta las celdas al número de ranuras y `ContainerScreen._refresh_headers` repinta "n/total" en cada `inventory_changed`. La pantalla de inventario no muestra ocupación (spec 005: título y rejilla), así que de R-014-13 le toca mostrar las celdas nuevas; el "n/total" es el de la pantalla de contenedor (R-013-12). | R-014-13. Con 8 ranuras la rejilla de 5 columnas (`inventory_grid.tscn`) tiene 2 filas de 104 px, la misma altura que el lado del contenedor (2 × 2): cabe de sobra en 1080 px (**inferencia** por los tamaños de las escenas; lo confirman el test de R-014-14 y M3). Si el test falla, se ajusta la escena, nunca el test. |
| D12 | `stack_max` de `scrap.tres`, `cables.tres` e `iron.tres` a los de BALANCE §2. El test de R-014-22 recorre `get_recipes()` y los tramos de `repair_costs` del catálogo y compara cada cantidad con el `stack_max` del item. | R-014-21, R-014-22. El catálogo es la fuente: una receta nueva queda cubierta sin tocar el test. |
| D13 | Sin `schema_version` nueva, sin migración (pregunta 10), sin evento nuevo en `EventBus` (pregunta 3). Se corrige architecture §10.2 (el ejemplo de la carga del nivel dice `stats_changed`; pasa a `level_changed`), se añade a §10.2 "`SaveManager` aplica las partes en el orden del árbol del grupo `persistent`; un dueño cuyo estado se deriva de otro va después de él en la escena (spec 014)", con la misma línea en el docstring de `SaveManager._apply_world`, y se añade `level_changed` a la lista de señales de estado de §7, con una nota: las señales viven en `robot.experience`, como `xp_changed`, y de ahí se enganchan las Tareas 4.1, 4.3 y la spec 017. | R-014-15, spec pregunta 7, D5. `level_up` ya está en §7 como ejemplo de señal de hecho. "En el robot" (historia 3, R-014-07) es en un componente de la entidad, como la batería. |

## 2. Archivos

| Archivo | Nuevo / Cambia | Responsabilidad |
|---|---|---|
| `game/scripts/systems/chassis_level_system.gd` | Nuevo | Nivel de una XP total y XP que falta para el siguiente, con la tabla por parámetro (D2) |
| `game/scripts/data/chassis_level_data.gd` | Cambia | `validate()` con primer umbral 0 y ranuras no decrecientes; `get_xp_required()`; docstrings (D8) |
| `game/resources/progression/chassis_levels.tres` | Cambia | Los 10 niveles de BALANCE §6.1 |
| `game/resources/items/scrap.tres`, `cables.tres`, `iron.tres` | Cambia | `stack_max` de BALANCE §2 (D12) |
| `game/scripts/components/experience_component.gd` | Cambia | Nivel, tabla, `level_changed`, `level_up`; XP que baja y carga (D1, D4, D6, D7, D9) |
| `game/scenes/entities/robot.gd` | Cambia | Pasa la tabla; ranuras del inventario en cada `level_changed`; docstrings (D3) |
| `game/scenes/entities/robot.tscn` | Cambia | `Experience` antes de `InventoryComponent` (D5) |
| `game/scenes/ui/debug_hud.gd`, `debug_hud.tscn` | Cambia | `%LevelLabel` y `%LevelUpButton` (D10) |
| `specs/architecture.md` | Cambia | §7 y §10.2 (D13) |
| `game/scripts/autoload/save_manager.gd` | Cambia (solo comentario) | Docstring de `_apply_world`: orden del árbol (D5, D13) |
| `game/tests/unit/test_chassis_level_system.gd` | Nuevo | R-014-01, 03, 04, 05, 20 (cálculo) |
| Tests existentes | Cambia | Ver §5.2 y §5.3 |

No cambian: `InventoryComponent`, `InventoryGrid`, `InventoryScreen`, `ContainerScreen`, el código de `SaveManager`,
`SaveMigrations`, `SaveDocuments`, `DeathController`, `EventBus`, `strings.csv`.

## 3. Contratos

```gdscript
# ChassisLevelSystem (new) — scripts/systems/chassis_level_system.gd
class_name ChassisLevelSystem
extends RefCounted

## Highest level whose total-XP threshold is <= total_xp (accumulated XP, R-014-03);
## above the last threshold, the last level (R-014-04). Negative XP, a null table or one
## whose validate() is not empty → push_error and ChassisLevelData.FIRST_LEVEL (R-014-05).
static func level_for_xp(total_xp: int, levels: ChassisLevelData) -> int

## XP to add to total_xp to reach the threshold of the next level; 0 at the last level.
## Same invalid inputs as level_for_xp() → push_error and 0 (R-014-20).
static func xp_to_next_level(total_xp: int, levels: ChassisLevelData) -> int


# ChassisLevelData (changed)
## Total XP to reach level; outside 1..get_level_count() → push_error and 0.
func get_xp_required(level: int) -> int
## Empty when valid: same size, at least one level, first threshold 0 (R-014-02),
## thresholds strictly increasing, slots never decreasing (D8).
func validate() -> PackedStringArray


# ExperienceComponent (changed)
## State: the chassis level now (spec 014, R-014-10); on a level-up and on load.
signal level_changed(level: int)
## Fact: the level went up (R-014-07); once per gain, with the final level, after
## level_changed. Never on load (R-014-17).
signal level_up(new_level: int)

## The level table; the level is recomputed from the current total, emitting
## level_changed only if it went up (never down) and never level_up. Robot calls it in _ready().
func set_level_table(levels: ChassisLevelData) -> void
## ChassisLevelData.FIRST_LEVEL until a table and XP raise it.
func get_level() -> int
# add_xp(): after xp_changed, a higher level → level_changed then level_up (D4).
# reset() / from_save_data() with a lower total: total changes, level stays, push_error (D6).
# from_save_data(): every valid load emits xp_changed and level_changed once each, even unchanged; never level_up (D7).
# to_save_data(): unchanged, {"total": n} only (R-014-15).


# Robot (changed)
# _ready(): experience.set_level_table(chassis_levels); experience.level_changed → _on_level_changed;
#           _on_level_changed(experience.get_level()) (the slot rule lives in one place)
# private:
func _on_level_changed(level: int) -> void   # inventory.set_slot_count(chassis_levels.get_inventory_slots(level))


# DebugHud (changed)
# bind(player): also follows player.experience.level_changed into %LevelLabel.
## Adds the XP the bound player lacks for the next level (R-014-20); nothing at the last level or unbound.
func level_up_player() -> void
```

Señales nuevas (architecture §7): `level_changed` es **de estado** (se emite al cargar) y `level_up` **de hecho**
(nunca al cargar). Ninguna va al `EventBus` (pregunta 3).

## 4. Datos

| Recurso / `.tres` | Campos | Valores desde |
|---|---|---|
| `ChassisLevelData` (`resources/progression/chassis_levels.tres`) | `xp_required`, `inventory_slots` (10 entradas cada uno) | BALANCE §6.1 (umbrales 0…2000; ranuras 5, 5, 5, 5, 6, 7, 8, 8, 8, 8). Los umbrales 6-10 son provisionales; cambiarlos solo toca el `.tres` y el test que lo espeja |
| `ItemData` `scrap.tres`, `cables.tres`, `iron.tres` | `stack_max` | BALANCE §2 (20, 10, 10) |
| `ConsumableData` `portable_battery.tres` | `stack_max` | BALANCE §2 (5), sin cambio |

Sin claves de texto nuevas: el debug HUD no es texto del jugador (D10).

## 5. Verificación

### 5.1 Comprobaciones de motor (hechas al planificar)

| # | Qué | Resultado |
|---|---|---|
| 1 | Orden de `SceneTree.get_nodes_in_group()` (D5) | ✅ La referencia de clases de 4.7.2 (`--doctool`) no lo describe, así que se comprobó con un script headless en Godot 4.7.2: dos hijos dados de alta en el grupo en orden inverso salen en el orden del árbol (`["X", "Y"]`), y tras `move_child` siguen el orden nuevo (`["Y", "X"]`). El test de R-014-16 lo vigila en el juego |
| 2 | Tamaño de la ventana raíz en los tests headless (R-014-14) | ✅ Comprobado en T-014-01 (GUT headless, Godot 4.7.2): la ventana es de 64×64 y `get_viewport().get_visible_rect().size` da 1920×1920 (stretch `expand` con ventana cuadrada), **no** el tamaño de diseño. El test de R-014-14 coloca la pantalla dentro de un `Control` del tamaño de diseño leído de `ProjectSettings` (`display/window/size/viewport_width` / `_height`) |

### 5.2 Requisitos

| Requisito | Test (`game/tests/…`) o paso manual |
|---|---|
| R-014-01 | `unit/test_chassis_level_data.gd::test_r_005_02_levels_match_balance` (arrays de BALANCE §6.1 actualizados, 10 niveles) · `unit/test_chassis_level_system.gd::test_r_014_01_level_count_comes_from_table` (tabla de 3 niveles) · `balance-auditor` (sin literales de umbral, ranuras ni número de niveles) |
| R-014-02 | `unit/test_chassis_level_data.gd::test_r_014_02_first_threshold_must_be_zero`, `::test_r_014_02_equal_slots_are_valid` |
| R-014-03 | `unit/test_chassis_level_system.gd::test_r_014_03_levels_of_balance_table` (0→1, 49→1, 50→2, 499→4, 500→5, 999→6, 1000→7, 2000→10, con la tabla de `chassis_levels.tres`), `::test_r_014_03_threshold_is_accumulated_xp` |
| R-014-04 | `unit/test_chassis_level_system.gd::test_r_014_04_xp_above_last_threshold_is_last_level` |
| R-014-05 | `unit/test_chassis_level_system.gd::test_r_014_05_negative_xp_reports_error`, `::test_r_014_05_invalid_table_reports_error` (null, vacía, primer umbral ≠ 0) · `unit/test_experience_component.gd::test_r_014_05_no_table_stays_level_one` (D9) |
| R-014-06 | `unit/test_experience_component.gd::test_r_014_06_each_component_has_its_own_level` · revisión: ningún autoload guarda nivel (`architecture-guardian`) |
| R-014-07 | `unit/test_experience_component.gd::test_r_014_07_level_up_at_threshold`, `::test_r_014_07_several_levels_one_signal_final_level`, `::test_r_014_07_level_changed_before_level_up` |
| R-014-08 | `integration/test_robot_inventory.gd::test_r_014_08_slots_grow_keeping_stacks` (materiales y una pieza con `uid` y durabilidad, hasta el nivel de 6 ranuras), `::test_r_014_08_same_slot_level_leaves_inventory` (nivel 1→2, sin `inventory_changed`) |
| R-014-09 | `unit/test_experience_component.gd::test_r_014_09_below_threshold_no_level_up` · `integration/test_robot_inventory.gd::test_r_014_09_below_threshold_same_slots` |
| R-014-10 | `unit/test_experience_component.gd::test_r_014_10_level_changed_on_level_up`, `::test_r_014_10_level_changed_on_load`, `::test_r_014_10_set_level_table_recomputes_without_level_up` |
| R-014-11 | `unit/test_experience_component.gd::test_r_014_11_reset_keeps_level_and_reports`, `::test_r_014_11_lower_load_keeps_level_and_reports` · `integration/test_robot_inventory.gd::test_r_014_11_xp_down_keeps_slots` |
| R-014-12 | `integration/test_death_controller.gd::test_r_014_12_death_keeps_level_and_slots` (`normal.tres`, nivel con 6+ ranuras; tras morir y reaparecer, mismo nivel y ranuras, inventario vacío) |
| R-014-13 | `unit/test_inventory_screen.gd::test_r_014_13_new_slots_shown_while_open` · `unit/test_container_screen.gd::test_r_014_13_new_slots_and_occupancy_while_open` |
| R-014-14 | `unit/test_inventory_screen.gd::test_r_014_14_last_level_slots_fit_screen` · `unit/test_container_screen.gd::test_r_014_14_last_level_slots_fit_screen` (con las ranuras del último nivel de `chassis_levels.tres`: cada celda dentro de 1920×1080, sin solaparse, con `mouse_filter = STOP`) · manual M3 |
| R-014-15 | `unit/test_experience_component.gd::test_r_014_15_save_data_has_only_total` · `integration/test_save_load.gd::test_r_014_15_level_recomputed_on_load` · revisión del diff: `SaveMigrations.WORLD_VERSION` y `SaveDocuments` sin cambios |
| R-014-16 | `integration/test_save_load.gd::test_r_014_16_saved_stacks_beyond_level_one_load` (Mundo con la XP del último umbral y una pila en cada ranura de ese nivel; carga las 8) · `integration/test_save_load.gd::test_r_014_16_experience_loads_before_inventory` (con `Main` arrancado, orden de los dos nodos del robot en `get_nodes_in_group(&"persistent")`) |
| R-014-17 | `unit/test_experience_component.gd::test_r_014_17_load_emits_state_never_level_up` · `integration/test_save_load.gd::test_r_014_17_load_never_emits_level_up` |
| R-014-18 | `integration/test_save_load.gd::test_r_014_18_new_world_level_one` |
| R-014-19 | `unit/test_debug_hud.gd::test_r_014_19_shows_level_and_follows`, `::test_r_014_19_level_next_to_xp` |
| R-014-20 | `unit/test_debug_hud.gd::test_r_014_20_button_reaches_next_threshold`, `::test_r_014_20_button_does_nothing_at_last_level` · `unit/test_chassis_level_system.gd::test_r_014_20_xp_to_next_level` · manual M4 (no se ve en release) |
| R-014-21 | `unit/test_data_catalog.gd::test_r_004_18_items_match_balance` (`EXPECTED_ITEMS` con 20/10/10/5) · `balance-auditor` |
| R-014-22 | `unit/test_data_catalog.gd::test_r_014_22_every_cost_fits_one_stack` |

**Pasos manuales** (spec §5), en PC y en Android (APK debug):

- **M1** Matar zombies hasta pasar 50 XP: el debug HUD muestra "Level: 2" y el inventario sigue con 5 ranuras.
- **M2** "Level up" hasta el nivel 5: el inventario tiene 6 ranuras con lo que llevaba en su sitio. Morir: mismo
  nivel y 6 ranuras. Cerrar y volver a abrir: mismo nivel, y las pilas guardadas en la ranura 6 siguen ahí.
- **M3** "Level up" hasta el 10: 8 ranuras que se ven y se tocan (dedo y ratón) en la pantalla de inventario y en la
  de contenedor (caja y cofre), sin desplazamiento. (Subir con una pantalla abierta no se prueba a mano: pulsar el
  botón de depuración cierra la pantalla, que se cierra al tocar fuera; lo cubren los `test_r_014_13_*`.)
- **M4** Una visita a la zona verde llena varias pilas de chatarra de 20. Un APK de release no muestra el debug HUD.

Resultado (2026-11-24): el usuario hizo M1-M4 en PC y en Android (APK debug) y todos dieron el resultado esperado.

### 5.3 Tests existentes que cambian

| Test | Cambio | Por qué |
|---|---|---|
| `unit/test_chassis_level_data.gd` | `EXPECTED_XP` y `EXPECTED_SLOTS` con BALANCE §6.1; en `test_r_005_02_validate_rejects_bad_tables`, `[5, 5]` pasa de rechazada a válida (lo cubre `test_r_014_02_equal_slots_are_valid`) y las tablas válidas empiezan en 0 | D8: cambia la regla de BALANCE, no se debilita el test |
| `unit/test_data_catalog.gd` | `EXPECTED_ITEMS` con 20 / 10 / 10 | R-014-21 |
| `unit/test_experience_component.gd` | `before_each` asigna `chassis_levels.tres` con `set_level_table`; `test_r_010_09_round_trip_experience` también se la asigna a su segundo componente (`other`); `test_r_008_28_reset_sets_total_to_zero` afirma el `push_error` de D6 (la XP baja de 7 a 0); `test_r_010_09_load_same_total_emits_nothing` pasa a esperar un `xp_changed` y un `level_changed` (se renombra `test_r_014_17_load_same_total_emits_state_again`) | D6, D7, D9 |
| `integration/test_death_controller.gd` | El caso del ruleset sin `keeps_xp` afirma el `push_error` de D6 | D6: la XP baja de 40 a 0 |
| Tests que llenan inventarios o cuentan pilas con el catálogo real | Se revisan con la suite completa tras T-014-03; los que suponían 99 / 50 pasan a leer `stack_max` del catálogo y `get_slot_count()`, como ya hacen `test_main_scene.gd` y `test_structure_use_flow.gd` (pregunta 11) | Revisado al planificar: `test_death_controller.gd` llena 25 chatarra, 20 hierro y 7 cables (5 ranuras con 20/10/10, justo las del nivel 1); `test_inventory_component.gd`, `test_inventory_rules.gd` y `test_crafting_system.gd` usan catálogos propios |
| `integration/test_base_structures.gd::test_r_009_42_place_until_full` | Paga estación a estación en vez de dar toda la chatarra de golpe; mismas aserciones | R-014-21: 368 de chatarra no caben en 5 ranuras de 20 (encontrado en T-014-03) |
| Cualquier test que cargue en un robot con más XP que la guardada | Afirma el `push_error` de D6 o usa un robot nuevo | D6 (no se ha encontrado ninguno al planificar) |

## 6. Check de constitución

| Principio | Cumple | Nota |
|---|---|---|
| P1 Spec primero | ✅ | Spec *Aprobado* (2026-11-23), sin preguntas abiertas |
| P2 Una fuente de verdad | ✅ | Umbrales, ranuras y número de niveles solo en `chassis_levels.tres`; `stack_max` solo en los `.tres`; la tabla se asigna una vez, en `robot.tscn` (D3); el nivel no se guarda, se deriva (R-014-15) |
| P3 Lógica separada | ✅ | `ChassisLevelSystem` puro; `ExperienceComponent` recibe la tabla por parámetro; `Robot` solo cablea; la UI no cambia estado (el botón de depuración pide `add_xp`) |
| P4 Estado por jugador | ✅ | Nivel en el `ExperienceComponent` de cada robot; ningún autoload lo guarda (R-014-06) |
| P5 Datos como recursos | ✅ | `ChassisLevelData` ya existe; solo cambia su `.tres` y su validación |
| P6 Señales | ✅ | `level_changed` (estado) y `level_up` (hecho), en pasado o `*_changed`, tipadas; `Robot` une sus componentes; sin evento de bus nuevo |
| P7 Tipado | ✅ | Todo tipado; los `Variant` de los tests se asignan a variables tipadas antes de un assert |
| P8 Plataforma | ✅ | Nada de plataforma en gameplay; el debug HUD ya decide su visibilidad con `OS.is_debug_build()` (capa de UI, spec 007) |
| P11 i18n | ✅ | Sin texto nuevo del jugador; el debug HUD está exento (D10) |
| P12 Presupuesto móvil | ✅ | Sin nodos nuevos de juego ni sondeo: todo por señales; 3 celdas más de UI como mucho |
| P13 Test primero | ✅ | Cada requisito tiene test o paso manual (§5.2); el sistema puro y el componente se escriben con su test antes; ningún test se debilita (§5.3) |
| P14 Alcance | ✅ | Sin notificación, SFX, recuerdos, evento de bus ni fuentes nuevas de XP (spec §4); sin renombrar `ExperienceComponent` |

## 7. Riesgos y alternativas descartadas

- **Alguien reordena los hijos de `robot.tscn`** y el inventario carga antes que la XP: se perderían las pilas de las
  ranuras 6-8 al cargar. → Dos tests (D5): el de comportamiento de R-014-16 y el del orden de los hijos. El docstring
  de `Robot` lo explica.
- **Tests que suponían pilas de 99 / 50.** → T-014-03 corre la suite entera tras bajar los `.tres` y corrige los
  que lean literales para que lean el catálogo (pregunta 11), nunca bajando una aserción.
- **`push_error` nuevo al bajar la XP** (D6) en tests que ya lo hacían. → Inventario en §5.3; se afirma el error.
- **8 ranuras no caben** en alguna pantalla en Android por el escalado. → Test de R-014-14 con la resolución de
  diseño y M3 en el dispositivo. Si falla, se ajusta la escena (D11).
- **XP que baja y luego se guarda** (D6 con R-014-15): el siguiente guardado escribe la XP menor y, al cargar, el
  nivel se recalcula más bajo y se pierden las pilas de las ranuras de más. Ningún ruleset del PMV baja la XP. → La
  spec que cree ese ruleset (Hardcore, v1.1) decide la regla (spec pregunta 6).
- **Umbrales 6-10 provisionales** (BALANCE §6.1). → El código no tiene literales; cambiarlos toca el `.tres` y el
  test que lo espeja.
- Descartado: `ChassisLevelComponent` aparte (§1, D1), prioridad de carga en el contrato `persistent` y crecer el
  inventario hasta lo guardado (D5), guardar el nivel (pregunta 1).
