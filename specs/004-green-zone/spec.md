# Spec 004 — Zona verde, `zone_id`, RNG con semilla y cajas de loot

| Campo | Valor |
|---|---|
| **Estado** | Hecho |
| **Tarea(s) ACTION_PLAN** | 1.1 (sin "añadir a inventario", que pasa a la 005) |
| **Fuentes** | ACTION_PLAN.md Tarea 1.1 · PMV.md §2.1 (zona de farmeo, botón interactuar), §2.3, §4.5 ganchos 2-3 · BALANCE.md §2, §2.1, §7.1, §11 · SPECS.md §26 · architecture.md §4, §5, §6, §8, §9.1, §9.3, §11, §12 · Constitución P2, P5, P8, P9, P11, P12 |
| **Depende de** | 001, 002 (robot, cámara, controles táctiles), 003 (HUD; la batería sigue drenando en la zona) |
| **Rama** | `feat/004-green-zone` |

## 1. Objetivo

Dar al robot el primer sitio al que ir: la zona verde del PMV, con cajas que se abren y generan materiales. A la
vez fija tres piezas que el resto del juego reutiliza y que son caras de cambiar después: la identidad de zona
(`zone_id` alineado a una cuadrícula), la aleatoriedad con semilla y el patrón de interacción.

Alcance decidido (nov 2026, opción A): la caja **genera** el loot y lo anuncia por señal, sin inventario. El
inventario, `InventoryComponent` y su UI son de la spec 005, que conecta esa señal.

## 2. Historias

- Como jugador, quiero recorrer una zona con cajas y abrirlas acercándome y pulsando un botón, para conseguir
  materiales.
- Como jugador, quiero que el mundo sea el mismo cada vez que lo cargo, para poder aprender dónde están las cosas.
- Como desarrollador de sistemas posteriores (inventario, cofres, banco, estación de carga), quiero un patrón de
  interacción y un catálogo de items ya hechos, para conectar mi objeto sin reprogramar proximidad, botón y texto.

## 3. Requisitos (EARS)

### 3.1 Zona

| ID | Requisito | Fuente |
|---|---|---|
| R-004-01 | THE game SHALL have a green farm zone scene with a ground of dirt and grass tiles, decoration (trees, rocks, scrap) and static colliders on every obstacle, with the size of BALANCE §7.1. | ACTION_PLAN 1.1, BALANCE §7.1 |
| R-004-02 | THE green zone SHALL have the `zone_id` `Vector2i(0, 0)`. | ACTION_PLAN 1.1, PMV §4.5 gancho 2 |
| R-004-03 | THE green zone SHALL fit entirely inside one cell of the global zone grid, whose cell size comes from a data resource. | ACTION_PLAN 1.1, PMV §4.5 gancho 2, SPECS §26 — ver pregunta 3 |
| R-004-04 | IF the robot moves toward the edge of the zone, THEN THE zone boundaries SHALL stop it from leaving the playable area. | ACTION_PLAN 1.1 |
| R-004-05 | WHEN the game starts, THE `Main` scene SHALL show the green zone in its `ZoneSlot` instead of the development zone, with the robot at the zone's spawn point. | architecture §6, ACTION_PLAN 1.1 |
| R-004-06 | THE green zone SHALL stay within the mobile budget of PMV §3.2 (triangles, lights, one shadowed directional light). | Constitución P12, PMV §3.2 |
| R-004-07 | THE zone models SHALL be free CC0/CC assets or primitive placeholders, with their licence recorded. | CLAUDE.md (presupuesto €0), ACTION_PLAN riesgos |

### 3.2 Semilla y RNG

| ID | Requisito | Fuente |
|---|---|---|
| R-004-08 | THE `GameManager` autoload SHALL hold the world seed of the current game. | architecture §5 — ver pregunta 1 |
| R-004-09 | THE `SeededRng` utility SHALL return a `RandomNumberGenerator` derived only from the world seed and a `zone_id`, so the same inputs always give the same sequence and different `zone_id`s give different sequences. | PMV §4.5 gancho 3, architecture §11, Constitución P9 |
| R-004-10 | THE zone generation code (box count, box positions, box contents) SHALL use only RNGs from `SeededRng`, never the global `randf()`, `randi()`, `randi_range()` or `randomize()`. | ACTION_PLAN 1.1, Constitución P9 |
| R-004-11 | WHEN the green zone is generated twice with the same world seed, THE boxes SHALL appear in the same number and at the same positions. | ACTION_PLAN 1.1 (test) |

### 3.3 Interacción

| ID | Requisito | Fuente |
|---|---|---|
| R-004-12 | THE `InteractorComponent` on the robot SHALL detect the nearest enabled `InteractableComponent` within the interaction range and emit `target_changed(target)` whenever that target changes, including to none. | architecture §9.1 |
| R-004-13 | WHILE the robot has an interaction target, THE HUD SHALL show one "Interact" button labelled with `tr(prompt_key)` of that target; WHILE it has none, THE HUD SHALL hide it. | architecture §9.1, PMV §2.1 (botón interactuar) |
| R-004-14 | WHEN the player presses the HUD "Interact" button or the `interact` InputMap action (E on PC), THE `InteractorComponent` SHALL call `interact` on its current target, passing the robot as interactor. | architecture §9.1, Constitución P8 |
| R-004-15 | IF an `InteractableComponent` is disabled, THEN it SHALL not emit `interacted` and THE `InteractorComponent` SHALL not offer it as a target. | architecture §9.1 |
| R-004-16 | WHILE the battery is depleted (game over), THE robot SHALL not interact. | Inferido de spec 003 R-003-12 |
| R-004-17 | THE interaction range SHALL come from a data resource, not a script literal. | Constitución P2 — ver pregunta 6 |

### 3.4 Items y catálogo

| ID | Requisito | Fuente |
|---|---|---|
| R-004-18 | THE game SHALL define `ItemData` resources for scrap, cables and iron, each with a stable `snake_case` id, a translated name key and the stack maximum of BALANCE §2. | BALANCE §2, ACTION_PLAN 1.2, architecture §8, Constitución P11 |
| R-004-19 | THE `DataRegistry` autoload SHALL load the `DataCatalog` resource at start-up, return each item by id, and report an error for an unknown id. | architecture §5, §8 |
| R-004-20 | THE catalog SHALL contain no repeated ids, and every `ItemData` under `resources/items/` SHALL be listed in it. | architecture §8 (verificación) |

### 3.5 Cajas de loot

| ID | Requisito | Fuente |
|---|---|---|
| R-004-21 | WHEN the green zone is generated, THE zone SHALL place a number of basic boxes within the range of BALANCE §7.1, chosen with its seeded RNG among candidate positions laid out in the scene. | ACTION_PLAN 1.1, BALANCE §7.1 — ver pregunta 4 |
| R-004-22 | THE basic box SHALL have a loot table as a data resource whose entries reference catalog items and give a quantity range per item, with the values of BALANCE §2.1. | ACTION_PLAN 1.1, BALANCE §2.1, Constitución P5 |
| R-004-23 | WHEN a closed box is interacted with, THE box SHALL roll its loot table once, with every quantity inside its range, and emit `loot_generated(stacks, opener)` with the resulting item stacks, leaving out items rolled as 0. | ACTION_PLAN 1.1, 1.2 (conectar al jugador que abre), architecture §9.3 — ver pregunta 5 |
| R-004-24 | WHEN a box has been opened, THE box SHALL show an opened state, disable its `InteractableComponent` and never generate loot again while the zone is loaded. | ACTION_PLAN 1.1 — ver pregunta 2 |
| R-004-25 | THE box's interaction prompt SHALL be the translation key `PROMPT_OPEN`, in Spanish and English. | architecture §9.1, Constitución P11 |
| R-004-26 | IF a loot table entry has a negative quantity, a minimum above its maximum or no item, THEN THE game SHALL report an error naming the table, and a test SHALL reject such a table in the catalog. | Constitución §2 (errores) |

Los valores numéricos (tamaño de zona, número de cajas, cantidades, stacks, tamaño de celda, radio de
interacción) se citan por su fuente; el spec no los fija.

## 4. Fuera de alcance

- `InventoryComponent`, reglas de apilado, UI de inventario y conectar `loot_generated` al jugador: spec 005.
- Spawns de zombies y robots en la zona, aunque la zona pueda reservar sus marcadores: specs 006 y 015.
- `ZoneData`, `ZoneLoader`, viaje entre base y zona, pantalla de carga y `EventBus.zone_changed`: spec 009 (la
  base es la zona `(0, -1)`, architecture §14 pregunta 1). En la 004 la zona se instancia directamente en `ZoneSlot`.
- Crear la semilla al crear un mundo y guardar qué cajas están abiertas (cambios por zona): spec 010.
- Reposición de cajas abiertas por visita (contador de visitas por zona, número de visita en la semilla del
  contenido): regla decidida en BALANCE §7.2, la aplica el spec 010. En la 004 no hay visitas: el contenido
  sigue saliendo de `semilla + zone_id + índice de la caja`.
- Animación pulida y sonido al abrir: ACTION_PLAN 4.3 y 4.4. Aquí basta con un cambio visible de estado.
- Minimapa: ACTION_PLAN 4.1. Paso "abre una caja" de la guía: ACTION_PLAN 5.4.
- Baterías portátiles en cajas (0 % en la caja básica, BALANCE §2.1) y `UIManager`: no hacen falta aquí.
- Generación procedural de zonas y varias zonas por mundo: v1.1 (PMV §2.3, SPECS §26).

## 5. Criterio de hecho

Al arrancar, el robot aparece en la zona verde, no puede salir de sus límites y ve entre 5 y 7 cajas (BALANCE
§7.1). Al acercarse aparece el botón "Abrir" (o "Open"); al pulsarlo o con E, la caja queda abierta, genera
materiales dentro de los rangos de BALANCE §2.1 y no vuelve a ofrecerse. Con la misma semilla las cajas están en
el mismo sitio. Tests en verde: RNG con semilla, colocación reproducible, tiradas dentro de rango, una sola
apertura, interactor (más cercano, desactivado), catálogo válido y ningún RNG global en la generación. ≥ 30 FPS en
el Android de gama media dentro de la zona.

## 6. Preguntas abiertas

| # | Pregunta | Propuesta | ¿Bloquea? |
|---|---|---|---|
| 1 | ~~Semilla del mundo antes del guardado~~ | **Cerrada (nov 2026)**: semilla fija de desarrollo en un `.tres` de configuración que lee `GameManager`. La spec 010 la sustituye por la semilla creada al empezar un mundo. | — |
| 2 | ~~¿Las cajas abiertas se reponen?~~ | **Cerrada (nov 2026)**: en la 004 una caja abierta sigue abierta hasta reiniciar la partida. La regla definitiva es la reposición por visita (PMV §10, BALANCE §7.2): el contador de visitas sube al salir de la zona y el número de visita entra en la semilla del contenido. La aplica la spec 010. | — |
| 3 | ~~Tamaño de la celda del mapa global~~ | **Cerrada (nov 2026)**: 80x80 m (BALANCE §7); la zona verde de 50x50 m va centrada en su celda. | — |
| 4 | ~~¿Posiciones libres o marcadores?~~ | **Cerrada (nov 2026)**: marcadores colocados a mano en la escena (más de 7) y el RNG con semilla elige cuántas cajas y en cuáles. | — |
| 5 | ~~Contenido con semilla y distribución de los rangos~~ | **Cerrada (nov 2026)**: RNG de `semilla + zone_id + índice de la caja`; cantidades enteras uniformes con ambos extremos incluidos (BALANCE §2.1). | — |
| 6 | ~~Radio de interacción~~ | **Cerrada (nov 2026)**: 2.0 m (BALANCE §11), ajustable en el móvil. | — |
| 7 | ~~Botón "Interactuar" en táctil~~ | **Cerrada (nov 2026)**: a la derecha, junto al futuro botón de atacar (PMV §2.1), fuera de la mitad izquierda del joystick (R-002-10). Se ajusta en el móvil. | — |
| 8 | ~~¿Límites visibles o invisibles?~~ | **Cerrada (nov 2026)**: vallas o rocas visibles con colisión en el borde, más una pared invisible de respaldo. | — |
