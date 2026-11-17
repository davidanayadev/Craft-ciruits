# Interacción

> Un robot detecta el objeto interactuable más cercano a su alcance y lo activa con la tecla E o con el botón "Interactuar" del HUD.
> Specs: [004](../../specs/004-green-zone/spec.md) · Última actualización: spec 005 (el botón se oculta con una pantalla abierta)

## Piezas

| Pieza | Tipo | Archivo | Responsabilidad |
|---|---|---|---|
| `InteractableComponent` | `Area3D` | `game/scripts/components/interactable_component.gd` | Marca un objeto como interactuable; emite `interacted(interactor)` |
| `InteractorComponent` | `Area3D` | `game/scripts/components/interactor_component.gd` | Mantiene el objetivo más cercano y emite `target_changed` |
| `ControlConfigData` | Resource | `game/scripts/data/control_config_data.gd` | `interaction_range_m` (radio de detección) |
| `Robot` | Escena | `game/scenes/entities/robot.gd` | `request_interact()`; nodo `%Interactor` |
| `Hud` | Escena | `game/scenes/ui/hud.gd` | Botón de interacción y señal `interact_pressed` |
| `PlayerInput` | Componente | `game/scripts/components/player_input.gd` | `is_interact_just_pressed()` |

## Cómo funciona

1. Un objeto (hoy `LootBox`) lleva un `InteractableComponent` con `prompt_key` (clave de traducción, `PROMPT_OPEN`)
   y una forma de colisión hija. En `_ready()` se pone solo en la capa de física 2 ("interaction"), sin máscara
   y con `monitorable = true`.
2. El robot lleva un `InteractorComponent`. En `_ready()` crea una esfera de radio `config.interaction_range_m`, con
   máscara solo sobre la capa 2 y `monitoring = true`.
3. En cada `_physics_process`, el interactor recoge las áreas solapadas que son `InteractableComponent` y elige con
   `pick_nearest()` el habilitado más cercano (distancia al cuadrado; empate: el primero).
4. Si el objetivo cambia (incluso porque el anterior se liberó), emite `target_changed(target)`; `null` significa sin objetivo.
5. `Hud.bind()` escucha `target_changed`: pone `prompt_key` como texto del botón (el botón lo traduce) y lo muestra
   solo si hay objetivo y no hay pantalla abierta (`set_modal_open`).
6. Dos caminos de entrada acaban en `Robot.request_interact()`: la acción `interact` (E, leída en `_physics_process`
   con `PlayerInput`) y `Hud.interact_pressed` (conectado en `main.gd`).
7. `request_interact()` no hace nada con la batería agotada o con el input bloqueado por una pantalla. Si no,
   llama `interactor.interact_with_target(self)` → `target.interact(robot)` → `interacted.emit(robot)`.
8. `enabled = false` hace que el objeto no se ofrezca como objetivo y que `interact()` no emita.

## Datos

| Recurso | Clase | Valores en BALANCE |
|---|---|---|
| `resources/config/controls.tres` | `ControlConfigData` | `interaction_range_m`: [§11](../../BALANCE.md) |

## Decisiones

| Decisión | Por qué | Fuente |
|---|---|---|
| Proximidad, botón y texto se resuelven una vez en dos componentes; cada objeto solo conecta `interacted` | Patrón común para cajas, bancos, estaciones y cofres | [architecture §9.1](../../specs/architecture.md) |
| El número de capa 2 vive solo en `InteractableComponent.PHYSICS_LAYER` | Fuente única del valor | comentario del código; capa nombrada en `project.godot` |
| El interactor es un `Area3D` por entidad, no un estado global | Estado por jugador para el co-op | [architecture §9.5](../../specs/architecture.md) |
| El alcance sale de un recurso | Sin literales de gameplay | R-004-17 |
| Sin objetivo, el botón se oculta | Un solo botón contextual | R-004-13 |

## Relación con otros sistemas

- [loot.md](loot.md): `LootBox` es el único objeto interactuable hoy.
- [ui.md](ui.md): `Hud` y bloqueo de input mientras hay pantallas (`UIManager`). [battery.md](battery.md): batería agotada bloquea.
- [movement.md](movement.md): `PlayerInput` y la acción `interact` del InputMap. Valores en [data_catalog.md](data_catalog.md).

## Trampas y límites

- El objetivo se recalcula en `_physics_process`, no al instante: un objeto liberado deja de ser objetivo vía `get_target()`.
- Un nuevo interactuable necesita su `CollisionShape3D` hijo; sin él el interactor no lo detecta.
- El interactor no filtra por línea de visión ni por dirección: solo distancia.
- Solo existe `PROMPT_OPEN`. `PROMPT_RECHARGE` y otras claves llegan con sus specs.
- Cada robot interactúa por separado; en co-op el `Hud` solo se enlaza al robot local.

## Cómo extenderlo

Objeto nuevo interactuable: añadir un `InteractableComponent` con su forma de colisión y un `prompt_key` (ES + EN en
`game/i18n/strings.csv`), y conectar `interacted` a su lógica. No hace falta tocar `Hud`, `Robot` ni el interactor.

## Tests

| Archivo | Verifica |
|---|---|
| `tests/unit/test_interactable_component.gd` | Emite solo si está habilitado (R-004-15) |
| `tests/unit/test_interactor_component.gd` | Más cercano, `target_changed` con física real, radio desde datos (R-004-12, 15, 17) |
| `tests/unit/test_hud.gd` | Botón con el `prompt_key` del objetivo, oculto sin objetivo, emite `interact_pressed` (R-004-13) |
| `tests/integration/test_robot_interaction.gd` | E y botón abren la caja; batería agotada no interactúa (R-004-14, 16) |
