# Documentación de sistemas — CyberScrap

> Cómo funciona **hoy** el código ya implementado, organizado por sistema y no por spec, con enlaces al porqué.
> Para consultar como programador qué se ha hecho, dónde está y por qué se hizo así.

## Qué es y qué no es

| Esta carpeta | Dónde vive lo demás |
|---|---|
| Cómo funciona cada sistema de punta a punta: clases, escenas, recursos, flujo y señales | — |
| Por qué es así: **enlaces** a requisitos, planes, ADRs y arquitectura, con una frase de resumen | El porqué completo sigue en `specs/NNN-*/`, `specs/decisions/` y `specs/architecture.md` |
| Trampas conocidas, cómo extenderlo y qué tests lo cubren | — |
| — | **Números**: `BALANCE.md` (aquí solo se cita la sección) |
| — | **Requisitos**: `spec.md` de cada spec (aquí solo se citan sus IDs) |
| — | **Firma de cada método**: los docstrings `##` del código |

Si una página y el código no coinciden, manda el código y la página se corrige. Si el código no coincide con su
spec o su plan, es un hallazgo: se anota en la página y se avisa, no se documenta como si fuera lo previsto.

Las páginas las escribe y actualiza el subagente `system-documenter` al cerrar cada spec (`/sdd-implement`).

## Estructura de una página

Archivo `docs/systems/<sistema>.md` (`snake_case`), prosa en español e identificadores en inglés. Objetivo: menos
de 150 líneas.

```markdown
# <Sistema>

> Una o dos frases: qué hace y para qué sirve en el juego.
> Specs: [NNN](../../specs/NNN-slug/spec.md), … · Última actualización: spec NNN

## Piezas
| Pieza | Tipo | Archivo | Responsabilidad |
(clase de sistema, componente, escena, recurso .tres, autoload, pantalla…)

## Cómo funciona
Flujo de punta a punta en pasos numerados: qué lo dispara, quién llama a quién, qué señales se emiten y
quién las escucha. Un diagrama corto en texto si ayuda.

## Datos
Recursos que lo configuran (`.tres` y su clase) y la sección de BALANCE.md de cada valor. Sin copiar números.

## Decisiones
| Decisión | Por qué | Fuente |
(una frase por decisión; la fuente es un R-NNN-XX, una sección de plan.md, un ADR o architecture.md §x)

## Relación con otros sistemas
Qué usa y quién lo usa, con enlace a la página del otro sistema.

## Trampas y límites
Lo que es fácil hacer mal, lo que todavía no existe (y qué spec lo traerá).

## Cómo extenderlo
Dónde tocar para el cambio típico (por ejemplo, un enemigo o un ítem nuevo).

## Tests
Archivos de test que lo cubren y qué verifica cada uno.
```

Si el porqué de algo no está escrito en ninguna fuente, se pone **"Sin documentar"**; no se deduce ni se inventa.

## Índice

| Sistema | Página | Specs | Código principal |
|---|---|---|---|
| Base del proyecto | [foundation.md](foundation.md) | 001, 007 | `game/project.godot`, `tools/run_tests.sh`, `tools/check_scripts.gd`, `.github/workflows/ci.yml` |
| Catálogo de datos y autoloads | [data_catalog.md](data_catalog.md) | 004, 005, 006, 007, 008, 009, 010, 011, 012 | `EventBus`, `DataRegistry`, `GameManager`, `DataCatalog`, `ActionResult` |
| Movimiento y cámara | [movement.md](movement.md) | 002, 007, 009 | `Robot`, `PlayerInput`, `LocomotionSystem`, `JoystickLogic`, `FloatingJoystick`, `CameraRig` |
| Batería | [battery.md](battery.md) | 003, 007, 008, 010, 012 | `BatteryComponent` (`set_maximum_bonus`), `BatteryConfigData` |
| Mundo y zonas | [world_zones.md](world_zones.md) | 004, 006, 008, 009, 010 | `Main`, `FarmZone`, `ZoneData`, `ZonePopulation`, `SeededRng`, `ZoneMemory`, `GameManager` (Mundo y visitas), `Zone` |
| Interacción | [interaction.md](interaction.md) | 004, 008, 009 | `InteractableComponent`, `InteractorComponent` |
| Botín | [loot.md](loot.md) | 004, 005, 008, 010, 012 | `LootBox`, `LootSystem`, `LootTableData`, `ItemData` |
| Inventario | [inventory.md](inventory.md) | 005, 008, 009, 010, 011, 012 | `InventoryComponent`, `InventoryRules`, `ItemStack`, `QuantitySelector`, `ContainerScreen`, `InventoryScreen` |
| Interfaz (UI) | [ui.md](ui.md) | 002, 003, 005, 007, 008, 009, 010, 011, 012 | `UIManager`, `UIScreen`, `ContainerScreen`, `Hud`, `NoticeScreen`, `TransferScreen`, `AttackButton`, `QuantitySelector` |
| Enemigos | [enemies.md](enemies.md) | 006, 007, 008, 010 | `Zombie`, `HealthComponent`, `HurtboxComponent`, `EnemyBrain`, `ZombieSpawner`, `ObjectPool` |
| Combate y XP | [combat.md](combat.md) | 007, 008, 009, 010 | `MeleeAttackComponent`, `CombatSystem`, `HurtboxComponent`, `ExperienceComponent`, `CombatFeedback` |
| Muerte y objetos caídos | [death.md](death.md) | 008, 009, 010, 011 | `DeathController`, `RulesetData`, `DroppedItem`, `DroppedItemSpawner`, `DroppedItemRules`, `ITimeService`, `TransferScreen` |
| Viaje entre zonas | [travel.md](travel.md) | 009, 010 | `ZoneLoader`, `Zone`, `ExitPoint`, `LoadingScreen`, `LocationComponent`, `GameManager` (zona actual) |
| Base, construcción y estación de carga | [base.md](base.md) | 009, 010, 011, 012 | `BaseZone`, `BaseStructures`, `BuildGrid`, `BuildFlow`, `PlacementScreen`, `BenchBuildSection`, `RepairBench`, `ChargingStation` |
| Crafteo y reparación en el banco | [crafting.md](crafting.md) | 009, 011 | `CraftingSystem`, `RepairBench`, `BenchScreen`, `BenchEntry`, `PieceData`, `RepairCostData`, `InventoryComponent.craft/repair` |
| Guardado (Perfil, Mundo y tienda) | [save.md](save.md) | 010, 011, 012 | `SaveManager`, `SaveFlow`, `ISaveStore`, `LocalSaveStore`, `SaveCodec`, `SaveMigrations`, `SaveDocuments`, `ProfileData`, `IStore`, `LocalStore` |
| Generador eólico, baterías portátiles y cofres | [wind_generator_chests.md](wind_generator_chests.md) | 012 | `StructureStates`, `WindGeneratorComponent`, `WindGeneratorRules`, `WindGenerator`, `StorageChest`, `StructureUseFlow`, `ConsumableRules` |
