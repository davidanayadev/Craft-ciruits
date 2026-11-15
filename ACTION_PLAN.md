# Plan de Acción — CyberScrap (PMV simplificado)

> Plan de ejecución detallado por fases con subtareas específicas.
> **Tiempo total estimado**: 17 semanas (4 meses) a tiempo completo.
> **Objetivo**: PMV publicable en Android con mecánicas core funcionales.
> **Alcance simplificado**: 1 zona, 2-3 enemigos, 3 piezas, 2 bancos.

**Referencias cruzadas**:
- Para alcance del PMV: ver **PMV.md**
- Para balance numérico: ver **BALANCE.md**
- Para features futuras (post-PMV): ver **SPECS.md**

> **Actualización nov 2026**: las tareas incluyen los ganchos de arquitectura de PMV.md §4.5 (Perfil/Mundo, zona y semilla, ruleset, recetas, facción, estado por jugador, tienda). Se añaden la Tarea 0.5 (spike de navmesh) y la Tarea 2.7 (subida de nivel de chasis). Total: 392h → 426h. Después se añade la Tarea 2.8 (colocación libre en la base): 446h.

---

## Fase 0 — Configuración y prototipo básico (Semana 1-2)

**Objetivo**: entorno de desarrollo listo + robot se mueve en escena 3D vacía.

### Tarea 0.1: Configuración del proyecto (4h)
- [ ] Instalar Godot 4.7.2
- [ ] Crear proyecto "CyberScrap" con configuración 3D
- [ ] Configurar renderer Compatibility (OpenGL ES 3.0)
- [ ] Configurar resolución móvil (1920x1080 apaisada desde 2026-11-14, aspect ratio 16:9)
- [ ] Crear estructura de carpetas según PMV.md §4.2
- [ ] Inicializar repositorio Git (privado)
- [ ] Crear README.md con instrucciones de setup

**Entregable**: proyecto Godot vacío pero configurado, commiteado a Git.

### Tarea 0.2: Escena base 3D (6h)
- [ ] Crear escena `Main.tscn` con cámara isométrica (45° Y, 35° X)
- [ ] Configurar luz direccional (sol) con sombras
- [ ] Crear plano de suelo (GridMap o MeshInstance)
- [ ] Configurar entorno (WorldEnvironment) con cielo básico
- [ ] Probar renderizado en vista isométrica

**Entregable**: escena 3D vacía con cámara isométrica funcional.

### Tarea 0.3: Robot jugador (movimiento) (12h)
- [ ] Crear escena `Robot.tscn` con CharacterBody3D
- [ ] Importar modelo 3D low poly de robot (Kenney o similar)
- [ ] Configurar colisiones (CapsuleShape)
- [ ] Crear script `RobotController.gd`:
  - [ ] Variables: `speed`, `rotation_speed`, `velocity`
  - [ ] Input: joystick virtual flotante (aparece donde tocas en la mitad izquierda y desaparece al soltar). Zona muerta hasta el 15 % del radio; andar del 15 % al 80 %; correr por encima del 80 % (vuelve a andar al bajar del 70 %, para no alternar en el borde). Velocidad fija por tramo, no proporcional
  - [ ] Input en PC: WASD/flechas para mover, Shift mantenido para correr
  - [ ] Sin piernas no se puede correr (BALANCE.md §4.2)
  - [ ] Movimiento relativo a cámara (WASD mapeado a isométrico)
  - [ ] Rotación suave hacia dirección de movimiento
- [ ] Crear UI de joystick virtual (CanvasLayer + TextureRect)
- [ ] Probar movimiento en escena

**Entregable**: robot se mueve con joystick virtual en escena 3D.

### Tarea 0.4: Sistema de batería (core) (8h)
- [ ] Crear autoload `GameManager.gd`:
  - [ ] Solo estado global de la partida (mundo actual, ruleset). **No guarda la batería** ni ningún estado de un jugador (PMV.md §4.5, gancho 7: cooperativo futuro)
- [ ] Crear componente `BatteryComponent.gd` (attachable a Robot):
  - [ ] Variables: `battery_current`, `battery_max` (cada jugador tiene la suya)
  - [ ] Métodos: `consume_battery(amount)`, `recharge_battery()`
  - [ ] Signals: `battery_depleted`, `battery_low`
  - [ ] Consumo pasivo: 0.1/s
  - [ ] Consumo movimiento: +0.05/s (andar), +0.15/s (correr)
  - [ ] El consumo no se detiene dentro de la base (BALANCE.md §1.1)
  - [ ] Lógica: si `battery_current <= 0` → emitir señal `battery_depleted`
- [ ] Crear HUD de batería (TextureProgressBar + Label)
- [ ] Conectar señales a HUD (actualizar en tiempo real)
- [ ] Test: batería baja al moverse, game over al llegar a 0

**Entregable**: sistema de batería funcional con HUD. Robot muere si batería = 0.

### Tarea 0.5: Spike de navmesh en tiempo de ejecución (12h)
Prueba desechable para decidir la generación procedural de zonas de v1.1 (SPECS.md §26). No es código de producción.
- [ ] Generar una zona de 50x50 m con un GridMap colocado por código (tiles y obstáculos aleatorios con semilla)
- [ ] Generar su navmesh en tiempo de ejecución (`NavigationRegion3D`)
- [ ] Medir en un Android de gama media real: tiempo de generación, pico de memoria, tirones durante la carga
- [ ] Probar 5-8 agentes `NavigationAgent3D` moviéndose por la zona generada
- [ ] Anotar el resultado en SPECS.md §26 (viable, viable con navmesh precalculado por piezas, o no viable)

**Entregable**: medición documentada y decisión sobre la generación procedural.

**Tiempo total Fase 0**: ~42h (2 semanas)  
**Criterio de "hecho"**: robot se mueve con joystick, batería funciona, HUD visible, spike de navmesh medido.

---

## Fase 1 — Core loop de juego (Semana 3-5)

**Objetivo**: bucle completo base → zona de farmeo → combate → muerte → base.

### Tarea 1.1: Zona verde (farmeo básico) (18h)
- [ ] Crear escena `FarmZoneGreen.tscn`:
  - [ ] GridMap con tiles de suelo (tierra, hierba)
  - [ ] Decoración: árboles, rocas, chatarra (modelos 3D low poly)
  - [ ] Límites de zona (paredes invisibles o visibles)
  - [ ] Asignar un `zone_id` (Vector2i; la zona verde del PMV es `(0, 0)`) y alinear la zona a la cuadrícula del futuro mapa global (PMV.md §4.5, gancho 2)
- [ ] RNG con semilla (PMV.md §4.5, gancho 3):
  - [ ] Utilidad que devuelve un `RandomNumberGenerator` sembrado con `semilla del mundo + zone_id`
  - [ ] Prohibido usar `randf()`/`randi()` globales en la generación de la zona
- [ ] Sistema de cajas de loot:
  - [ ] Crear escena `LootBox.tscn` (Area3D + MeshInstance)
  - [ ] Script `LootBox.gd`:
    - [ ] Variables: `loot_table` (Array de items con probabilidades)
    - [ ] Método `open()`: generar loot según tabla, emitir señal `loot_generated`
    - [ ] Interacción: botón "Abrir" cuando jugador está cerca
  - [ ] Colocar 5-7 cajas en zona verde, en posiciones elegidas con el RNG con semilla de la zona
- [ ] Sistema de recolección:
  - [ ] Crear UI de interacción (botón "Abrir" aparece cerca de caja)
  - [ ] Al abrir: mostrar animación, generar items, añadir a inventario
- [ ] Test: abrir cajas genera materiales
- [ ] Test: con la misma semilla, las cajas aparecen en las mismas posiciones

**Entregable**: zona verde con cajas de loot recolectables.

### Tarea 1.2: Sistema de inventario (14h)
- [ ] Crear componente `InventoryComponent.gd` en la entidad del jugador (no un autoload: cada jugador tiene su inventario, PMV.md §4.5, gancho 7):
  - [ ] Variables: `inventory_slots = []` (Array de 5 slots; el tamaño crece con el nivel de chasis, Tarea 2.7)
  - [ ] Métodos: `add_item(item_id, quantity)`, `remove_item(item_id, quantity)`, `has_item(item_id, quantity)`
  - [ ] Lógica: stack máximo por item (chatarra: 99, cables: 50, hierro: 50)
- [ ] Crear recurso `ItemData.gd` (extends Resource):
  - [ ] Variables: `id`, `name`, `icon`, `stack_max`, `description`
- [ ] Crear items básicos (chatarra, cables, hierro):
  - [ ] Archivos `.tres` para cada item
- [ ] Crear UI de inventario (GridContainer + TextureRect):
  - [ ] Mostrar slots (5 en PMV)
  - [ ] Mostrar icono + cantidad
- [ ] Conectar LootBox con el `InventoryComponent` del jugador que la abre (por señal)
- [ ] Test: abrir cajas añade items al inventario

**Entregable**: inventario funcional con UI. Items se acumulan correctamente.

### Tarea 1.3: Zombies (2 tipos) (17h)
- [ ] Crear escena `Zombie.tscn` (CharacterBody3D + MeshInstance):
  - [ ] Importar modelo 3D low poly de zombie
  - [ ] Configurar colisiones
  - [ ] AnimationPlayer: idle, walk, attack
- [ ] Crear componente `HealthComponent.gd`:
  - [ ] Variables: `hp_current`, `hp_max`
  - [ ] Métodos: `take_damage(amount)`, `heal(amount)`
  - [ ] Signals: `health_changed`, `died`
- [ ] Crear script `ZombieAI.gd`:
  - [ ] State machine: Idle, Patrol, Chase, Attack
  - [ ] Detección de jugador (Area3D con radio de visión)
  - [ ] Pathfinding básico (NavigationAgent3D)
  - [ ] Ataque: cada 1.5s si está en rango, emitir daño al jugador
- [ ] Crear recurso `EnemyData.gd` (extends Resource) con stats y campo `faction` (enum: `INFECTED`, `MACHINE`, `HUMAN`; PMV.md §4.5, gancho 6)
- [ ] Crear 2 tipos de zombies (`.tres`, facción `INFECTED`):
  - [ ] Lento: HP 20, daño 5, velocidad 1.5
  - [ ] Rápido: HP 15, daño 4, velocidad 3.5
- [ ] Spawner de zombies:
  - [ ] Crear escena `ZombieSpawner.tscn` (Node3D)
  - [ ] Script: spawnear 5-8 zombies en posiciones elegidas con el RNG con semilla de la zona (Tarea 1.1) al cargar zona. Reaparecen con el contador de visitas de la zona (BALANCE.md §7.2)
- [ ] Test: zombies persiguen y atacan al jugador

**Entregable**: 2 tipos de zombies funcionales con IA básica.

### Tarea 1.4: Sistema de combate (16h)
- [ ] Ataque cuerpo a cuerpo con los brazos (sin armas en el PMV; armas en v1.1, ver SPECS.md §18):
  - [ ] Hitbox de ataque (Area3D) en los brazos del robot (BoneAttachment3D o nodo hijo)
  - [ ] Daño y velocidad de ataque según los brazos equipados (BALANCE.md §4.2). Hasta la Fase 3, usar los valores de Brazos básicos
  - [ ] Sin brazos: no puede atacar
- [ ] Sistema de ataque:
  - [ ] Input: botón de atacar (derecha)
  - [ ] Animación de ataque (AnimationPlayer)
  - [ ] Hitbox: Area3D que se activa durante animación
  - [ ] Detección de enemigos en hitbox
  - [ ] Aplicar daño a HealthComponent del enemigo
  - [ ] Consumo de batería: 1 punto/golpe
  - [ ] Al matar: otorgar XP directa (zombie lento 2, rápido 3; BALANCE.md §6.2)
- [ ] Feedback visual/sonoro:
  - [ ] Screen shake al golpear (Camera3D shake)
  - [ ] Partículas de impacto (GPUParticles3D)
  - [ ] SFX de golpe (AudioStreamPlayer3D)
  - [ ] Flash blanco en enemigo (modulate temporal)
- [ ] Sistema de daño al jugador:
  - [ ] Cuando zombie ataca: restar batería
  - [ ] Feedback: screen shake, SFX de daño, flash rojo en HUD
- [ ] Test: jugador puede matar zombies, zombies pueden matar al jugador

**Entregable**: combate funcional con feedback visual/sonoro.

### Tarea 1.5: Mecánica de muerte (10h)
- [ ] Ruleset como dato (PMV.md §4.5, gancho 4):
  - [ ] Crear recurso `RulesetData.gd` y el `.tres` `NORMAL` (el único del PMV)
  - [ ] La reacción a `player_died` la decide el ruleset del mundo, no código fijo. El Hardcore (v1.1) será otro `.tres` con otra reacción
- [ ] Lógica de muerte del jugador (ruleset `NORMAL`):
  - [ ] Cuando `battery_current <= 0`:
    - [ ] Emitir señal `player_died`
    - [ ] Guardar posición de muerte como `(zone_id, posición local)`; también si muere dentro de la base, con las mismas reglas (PMV.md §2.4)
    - [ ] Morir cuenta como salir de la zona: subir su contador de visitas, de modo que cajas y enemigos se repongan antes de la recuperación (BALANCE.md §7.2)
    - [ ] Guardar items del inventario (para drop)
    - [ ] Limpiar piezas equipadas (conservar solo core)
    - [ ] Transición a base, con la batería al 100% (BALANCE.md §1.1). Hasta la Fase 2 no hay estaciones de carga: reaparecer es la única recarga completa
  - [ ] Mostrar pantalla de "Transferencia de Consciencia" (animación)
- [ ] Drop de items al morir:
  - [ ] Crear escena `DroppedItem.tscn` (Area3D + MeshInstance)
  - [ ] Spawner: crear dropped items en posición de muerte
  - [ ] Caducidad: los items desaparecen tras 5 minutos (valor en BALANCE.md §7.2, configurable) contados desde la hora de la muerte con `ITimeService`, también con la app cerrada. Al cargar la partida se descartan los caducados; tiempo transcurrido negativo = 0 (PMV.md §10)
- [ ] Recuperación de items:
  - [ ] Viajar de vuelta a zona de muerte (viaje instantáneo en PMV, desde el punto de salida de la base). Encuentra enemigos repuestos
  - [ ] Interactuar con dropped items para recuperar
- [ ] Test: al morir, jugador reaparece en base sin piezas y con la batería al 100%, items dropeados en zona

**Entregable**: mecánica de muerte funcional con drop y recuperación de items.

**Tiempo total Fase 1**: ~75h (2 semanas)  
**Criterio de "hecho"**: bucle completo funcional: base → zona verde → matar zombies → abrir cajas → morir → volver a base.

---

## Fase 2 — Base y crafteo (Semana 6-8)

**Objetivo**: base con bancos de trabajo funcionales.

### Tarea 2.1: Escena de la base (12h)
- [ ] Crear escena `Base.tscn`:
  - [ ] GridMap con tiles de suelo (metal, hormigón)
  - [ ] Paredes y techo (estructura de almacén)
  - [ ] Iluminación: luces puntuales (lámparas)
  - [ ] Decoración: cajas, barriles, herramientas (modelos 3D)
- [ ] Zonas de la base:
  - [ ] Zona de entrada (spawn point)
  - [ ] Punto de salida a la zona: `InteractableComponent` con prompt propio (`PROMPT_TRAVEL`), que inicia el viaje (PMV.md §10). La zona tiene el suyo de vuelta
  - [ ] Banco de reparaciones en posición fija; no se mueve en la demo (PMV.md §10)
  - [ ] Área edificable: cuadrícula dentro de los límites de la base donde el jugador coloca estaciones, generador y cofres (Tarea 2.8). Empieza vacía
- [ ] Test: jugador puede moverse por la base

**Entregable**: escena de base con límites y cuadrícula edificable definidos.

### Tarea 2.2: Estación de carga (recarga + guardado) (8h)
Decisión nov 2026: la base empieza sin estación; se craftean (todas las que quieras, solo en la base) y la batería se consume también dentro de la base (BALANCE.md §5.3). Depende de la Tarea 2.4 para la receta.
- [ ] Crear escena `ChargingStation.tscn` (Area3D + MeshInstance):
  - [ ] Modelo 3D: panel con pantalla + cables
  - [ ] Interacción: botón "Recargar" cuando jugador está cerca
- [ ] Construcción:
  - [ ] En banco de reparaciones: opción "Construir estación de carga" (receta `RecipeData`, coste en BALANCE.md §5.3)
  - [ ] Al construir: el jugador la coloca en la cuadrícula de la base (modo colocación, Tarea 2.8)
  - [ ] Sin límite de cantidad; no se pueden colocar fuera de la base
- [ ] Lógica:
  - [ ] Al interactuar: recargar batería al 100% de la máxima, instantáneo (animación de carga) + guardar partida + mensaje "Partida guardada"
  - [ ] Al entrar en la base (automático): solo guardar partida (llamar a SaveManager). **No recarga**
  - [ ] Las estaciones construidas se guardan en el Mundo (Tarea 2.3)
- [ ] Test: entrar en la base guarda pero no recarga; interactuar con una estación recarga al 100% y guarda; sin materiales no se puede construir

**Entregable**: estaciones de carga crafteables y funcionales.

### Tarea 2.3: Sistema de guardado (20h)
- [ ] Crear autoload `SaveManager.gd` con dos niveles de guardado (PMV.md §4.5, gancho 1):
  - [ ] Métodos: `save_game()`, `load_game()`, `delete_save()`, `load_profile()`, `save_profile()`
  - [ ] **Archivo de Perfil** (global, sobrevive a los mundos), JSON encriptado:
    - [ ] `player_uuid` generado localmente (anónimo)
    - [ ] Derechos de compra (`entitlements`, vacío en el PMV)
    - [ ] Salón de la fama, cosméticos y planos desbloqueados (vacíos en el PMV)
  - [ ] **Archivo de Mundo** (uno por partida; en el PMV se crea uno automáticamente), JSON encriptado:
    - [ ] Cabecera: `world_id`, nombre, `seed`, `ruleset`, `schema_version`
    - [ ] Datos del jugador: batería, inventario, piezas equipadas
    - [ ] Datos de base: bancos construidos, estaciones de carga, cofres, items en cofres
    - [ ] Cambios por zona, indexados por `zone_id` (cajas abiertas de la visita en curso, items dropeados) y contador de visitas de la zona, que sube al salir (BALANCE.md §7.2)
    - [ ] Progresión: nivel de chasis, XP
    - [ ] Timestamp: última vez que se guardó
  - [ ] Encriptación: usar `EncryptionContext` de Godot (AES-256)
  - [ ] `schema_version` + función de migración, para que los guardados del PMV sigan cargando en v1.1
- [ ] Tienda detrás de una clase base (PMV.md §4.5, gancho 8):
  - [ ] Crear `IStore` (clase base, sin instanciar) con `has_entitlement(id)`, `purchase(sku)`, `restore()`
  - [ ] Crear `LocalStore` (PMV): sin compras reales, siempre en modo demo
  - [ ] Los derechos se leen y escriben en el Perfil
- [ ] Autosave:
  - [ ] Guardar automáticamente al entrar en base
  - [ ] Guardar automáticamente al cerrar juego (notification NOTIFICATION_WM_CLOSE_REQUEST)
- [ ] Backup de save:
  - [ ] Crear copia de seguridad antes de sobrescribir (Perfil y Mundo)
  - [ ] Si save principal está corrupto, cargar backup
  - [ ] El backup solo protege contra corrupción: en el Hardcore de v1.1 nunca debe servir para deshacer una muerte (SPECS.md §27)
- [ ] Test: cerrar y reabrir juego conserva progreso
- [ ] Test: borrar el Mundo no borra el Perfil

**Entregable**: sistema de guardado funcional con encriptación y backup.

### Tarea 2.4: Banco de reparaciones (crafteo de piezas) (22h)
- [ ] Crear recurso `RecipeData.gd` (PMV.md §4.5, gancho 5): ingredientes, resultado, `station` (`SELF`, `NANOBOTS`, `WORKBENCH`), `tier`, `requires` (plano o tecnología). En el PMV todas las recetas son `WORKBENCH`, tier 1, sin requisitos
- [ ] Crear escena `RepairBench.tscn` (Area3D + MeshInstance):
  - [ ] Modelo 3D: mesa de trabajo con herramientas
  - [ ] Interacción: botón "Usar" cuando jugador está cerca
- [ ] UI de crafteo (popup):
  - [ ] Lista de piezas craftables (con icono + nombre)
  - [ ] Mostrar materiales necesarios (chatarra, cables, hierro)
  - [ ] Botón "Crear" (deshabilitado si no hay materiales)
  - [ ] Botón "Reparar" (para piezas dañadas en inventario)
- [ ] Lógica de crafteo:
  - [ ] Método `craft_piece(recipe: RecipeData)` en `CraftingSystem` (lógica pura):
    - [ ] Verificar materiales suficientes (`InventoryComponent.has_item` del jugador)
    - [ ] Restar materiales (`InventoryComponent.remove_item`)
    - [ ] Crear pieza nueva (con durabilidad 100%)
    - [ ] Añadir a inventario (`InventoryComponent.add_item`)
- [ ] Lógica de reparación:
  - [ ] Método `repair_piece(piece_id)`:
    - [ ] Verificar materiales (2 hierro + 1 cable)
    - [ ] Restar materiales
    - [ ] Restaurar durabilidad a 100%
- [ ] Recetas de crafteo básicas (un `.tres` de `RecipeData` cada una, valores de BALANCE.md §4.3):
  - [ ] Brazos básicos: 4 chatarra + 2 cables
  - [ ] Piernas básicas: 4 chatarra + 2 hierro
  - [ ] Core básico: 6 chatarra + 3 cables + 2 hierro
  - [ ] Estación de carga: 4 chatarra (BALANCE.md §5.3; la usa la Tarea 2.2)
- [ ] Test: crear y reparar piezas funciona correctamente

**Entregable**: banco de reparaciones funcional con UI de crafteo.

### Tarea 2.5: Generador eólico (mejora de batería + generación de baterías) (10h)
- [ ] Crear escena `WindGenerator.tscn` (Area3D + MeshInstance):
  - [ ] Modelo 3D: generador con aspas (animación de rotación)
  - [ ] Interacción: botón "Construir" (primera vez)
- [ ] Lógica de construcción:
  - [ ] Coste: 5 chatarra + 3 cables + 2 hierro
  - [ ] Al construir:
    - [ ] Restar materiales
    - [ ] Activar efecto: +20 batería máxima
    - [ ] Guardar estado en SaveManager
- [ ] Lógica de generación de baterías:
  - [ ] Timer: genera 1 batería portátil cada 4 horas
  - [ ] Máximo 3 baterías almacenadas en el generador
  - [ ] UI: mostrar baterías disponibles para recoger
  - [ ] Interacción: botón "Recoger" para tomar baterías generadas
- [ ] Test: generador aumenta batería máxima y genera baterías portátiles

**Entregable**: generador eólico funcional con generación de baterías.

### Tarea 2.6: Cofres de almacenamiento (12h)
- [ ] Crear escena `StorageChest.tscn` (Area3D + MeshInstance):
  - [ ] Modelo 3D: caja metálica
  - [ ] Interacción: botón "Abrir" cuando jugador está cerca
- [ ] Lógica de cofre:
  - [ ] Variables: `chest_id`, `items = []` (Array de 4 slots)
  - [ ] Métodos: `add_item()`, `remove_item()`, `is_full()`
- [ ] UI de cofre (popup):
  - [ ] Grid 2x2 (4 slots)
  - [ ] Mostrar icono + cantidad
  - [ ] Botón "Transferir" (mover items entre cofre e inventario)
- [ ] Construcción de cofres:
  - [ ] En banco de reparaciones: opción "Construir cofre"
  - [ ] Coste: 3 chatarra + 1 hierro
  - [ ] Al construir: el jugador lo coloca en la cuadrícula de la base (modo colocación, Tarea 2.8)
  - [ ] Límite: máximo 5 cofres en base (PMV simplificado)
- [ ] Test: construir cofres, guardar items, recuperar items

**Entregable**: cofres funcionales con UI de almacenamiento.

### Tarea 2.7: Subida de nivel de chasis (5h)
Depende de la Tarea 1.2 (inventario) y la Tarea 2.3 (guardado). Antes no existía ninguna tarea que aplicara la subida: la XP se acumulaba sin efecto.
- [ ] Crear recurso `ChassisLevelData.gd` y un `.tres` con los umbrales de XP y los slots por nivel de BALANCE.md §6.1 (niveles 1-5: 0/50/150/300/500 XP; 5/7/10/15/20 slots). Sin literales en el código
- [ ] Lógica pura (`scripts/systems/`): calcular el nivel a partir de la XP total
- [ ] Al ganar XP: si se supera el siguiente umbral, subir de nivel (también varios niveles de golpe) y emitir la señal `level_up(new_level)`
- [ ] Al subir: ampliar los slots del `InventoryComponent` del jugador
- [ ] Conectar `level_up` a la notificación "Nivel up" (Tarea 4.1) y al SFX de nivel (Tarea 4.3)
- [ ] El nivel y la XP se guardan con la Tarea 2.3; al cargar, recalcular los slots desde el nivel
- [ ] Test: con 49 XP nivel 1 y 5 slots; con 50 XP nivel 2 y 7 slots; con 500 XP nivel 5 y 20 slots; ganar XP de sobra no pasa del nivel 5

**Entregable**: la XP sube de nivel el chasis y amplía el inventario.

### Tarea 2.8: Colocación libre en la base (20h, estimación)
Decisión nov 2026 (PMV.md §2.1): el jugador decide dónde va cada estructura que construye, dentro de los límites de la base. La base en cualquier sitio del mundo llega en v1.1 (SPECS.md §32). Antes de la Tarea 2.2, que la usa.
- [ ] Cuadrícula de la base: tamaño de celda y límites como dato (no literales)
- [ ] Modo colocación al construir: vista previa de la estructura sobre la cuadrícula, verde si cabe y roja si no; confirmar o cancelar (táctil y PC)
- [ ] Modo edición: mover una estructura ya construida
- [ ] Ocupación: una celda no admite dos estructuras; nada fuera de los límites
- [ ] Base llena: si no queda sitio en la cuadrícula, el botón de construir se desactiva con un aviso antes de gastar materiales (PMV.md §10)
- [ ] Guardar posiciones como `(zone_id, celda)` en el Mundo (Tarea 2.3; PMV.md §4.5 gancho 2)
- [ ] La navegación de los enemigos no entra en la base (zona segura), así que las estructuras no necesitan rehacer el navmesh
- [ ] Test (lógica pura): ocupación de celdas, límites, mover libera la celda anterior, guardar y cargar conserva las posiciones

**Entregable**: el jugador coloca y mueve estaciones, generador y cofres en su base.

**Tiempo total Fase 2**: ~109h (2.5 semanas)  
**Criterio de "hecho"**: base con banco de reparaciones, generador, cofres y estaciones de carga colocados por el jugador. Crafteo funcional. La XP sube de nivel el chasis.

---

## Fase 3 — Piezas y personalización (Semana 9-10)

**Objetivo**: sistema de piezas intercambiables con stats y degradación.

### Tarea 3.1: Sistema de ranuras de piezas (16h)
> Sigue `specs/architecture.md` §9.3-§9.4 (ADR 0005): la pieza es un objeto único en un `ItemStack` (con
> `uid` y durabilidad propia) y sus stats son modificadores, no un diccionario.

- [ ] Crear recurso `PieceData.gd` (extends `ItemData`):
  - [ ] Variables: `slot_type` (Brazo/Pierna/Core), `durability_max`, `modifiers: Array[StatModifier]`
  - [ ] Stats como `StatModifier` (`attack_damage`, `attack_speed`, `move_speed`, `run_speed`, `walk_drain`…)
- [ ] Crear `RobotBaseStats.tres` (robot sin piezas) y 3 piezas básicas, con valores de BALANCE.md §4.2:
  - [ ] Brazos básicos: daño 10, velocidad 1.0 golpe/s
  - [ ] Piernas básicas: andar 3.0 m/s, correr 4.8 m/s
  - [ ] Core básico: batería máxima 100
  - [ ] Archivos `.tres` para cada pieza
- [ ] `EquipmentComponent` en el jugador:
  - [ ] Tres ranuras (brazo, pierna, core) que guardan `ItemStack`
  - [ ] Métodos: `equip(stack) -> ActionResult`, `unequip(slot) -> ActionResult`; señal `equipment_changed`
- [ ] `StatsCalculator.compute(base, modifiers)` (puro, `SET` → `ADD` → `MULTIPLY`) y `StatsComponent`, que
  recalcula con `equipment_changed` y emite `stats_changed`
- [ ] UI de equipamiento (popup):
  - [ ] Mostrar 3 ranuras (Brazo, Pierna, Core)
  - [ ] Mostrar pieza equipada en cada ranura (icono + nombre)
  - [ ] Botón "Cambiar" (abre inventario de piezas)
  - [ ] Mostrar stats totales (daño, velocidad, consumo batería)
- [ ] Test: equipar y desequipar piezas altera stats

**Entregable**: sistema de ranuras funcional con UI.

### Tarea 3.2: Degradación de piezas (12h)
- [ ] Sistema de durabilidad:
  - [ ] La durabilidad actual vive en el `ItemStack` de cada pieza (instancia); `PieceData` solo guarda
    `durability_max = 100`. Así dos piezas iguales se degradan por separado
  - [ ] Degradación por golpe recibido: -5 puntos a la primera pieza equipada intacta, en orden Brazos → Piernas → Core (BALANCE.md §4.1)
  - [ ] Lógica de rotura:
    - [ ] Si la durabilidad del `ItemStack` llega a 0 (cálculo en `DegradationSystem`, puro):
      - [ ] Pieza se rompe (se elimina de ranura)
      - [ ] Emitir señal `piece_broken`
      - [ ] Mostrar notificación "Pieza rota"
      - [ ] Stats vuelven a valor base (sin pieza): `StatsComponent` recalcula
- [ ] UI de durabilidad:
  - [ ] En UI de equipamiento: barra de durabilidad bajo cada pieza
  - [ ] Color: verde (>50%), amarillo (25-50%), rojo (<25%)
- [ ] Test: piezas se degradan y rompen con el uso

**Entregable**: sistema de degradación funcional con UI.

### Tarea 3.3: Robot hostil básico (drops de piezas) (16h)
- [ ] Crear escena `HostileRobot.tscn` (CharacterBody3D + MeshInstance):
  - [ ] Datos en un `.tres` de `EnemyData` con facción `MACHINE` (IA rebelde, SPECS.md §28)
  - [ ] Modelo 3D: robot hostil (diferente de jugador)
  - [ ] AnimationPlayer: idle, walk, attack
- [ ] IA de robot hostil:
  - [ ] State machine: Patrol, Chase, Attack
  - [ ] Detección de jugador (Area3D)
  - [ ] Pathfinding (NavigationAgent3D)
  - [ ] Ataque: cada 2s, daño 8
- [ ] Sistema de drops:
  - [ ] Al morir:
    - [ ] 100% probabilidad: drop 2-4 chatarra + 1-2 cables + 1-2 hierro
    - [ ] 15% probabilidad: drop pieza dañada (50% durabilidad)
    - [ ] Otorgar 10 XP directa al jugador (no es un item)
  - [ ] Crear escena `DroppedPiece.tscn` (Area3D + MeshInstance)
  - [ ] Interacción: recoger pieza la añade a inventario
- [ ] Spawner de robots hostiles:
  - [ ] Zona verde: 0-1 robot básico
- [ ] Test: robot hostil suelta piezas y materiales al morir

**Entregable**: robot hostil básico funcional con drops de piezas.

**Tiempo total Fase 3**: ~44h (1.5 semanas)  
**Criterio de "hecho"**: sistema de piezas completo con degradación, robot hostil dropea piezas.

---

## Fase 4 — UI/UX y pulido (Semana 11-13)

**Objetivo**: UI completa, feedback visual/sonoro, animaciones.

### Tarea 4.1: HUD completo (16h)
- [ ] Diseño de HUD (CanvasLayer):
  - [ ] Arriba izquierda: batería (TextureProgressBar + Label)
  - [ ] Arriba derecha: minimapa (SubViewport con cámara cenital)
  - [ ] Mitad izquierda: joystick virtual flotante
  - [ ] Abajo derecha: botón atacar (grande). Sin botón agacharse en la demo (sigilo en v1.1, SPECS.md §30)
  - [ ] Derecha: botón consumibles, botón interactuar
  - [ ] Abajo centro: botón almacenamiento
- [ ] Minimapa:
  - [ ] SubViewport con cámara ortográfica (cenital)
  - [ ] Mostrar jugador (icono verde)
  - [ ] Mostrar enemigos (iconos rojos)
  - [ ] Mostrar cajas/objetos (iconos amarillos)
- [ ] Notificaciones:
  - [ ] Sistema de notificaciones temporales (3 segundos)
  - [ ] Ejemplos: "Pieza rota", "Batería baja", "Nivel up"
- [ ] Test: HUD muestra toda la información necesaria

**Entregable**: HUD completo con minimapa y notificaciones.

### Tarea 4.2: Menús (12h)
- [ ] Menú principal:
  - [ ] Botones: Jugar, Continuar, Opciones, Salir
  - [ ] Fondo: imagen de robot en entorno post-apocalíptico
  - [ ] Música de fondo (loop)
- [ ] Menú de pausa:
  - [ ] Botones: Continuar, Guardar, Opciones, Salir al menú
  - [ ] Overlay oscuro sobre juego
- [ ] Menú de opciones:
  - [ ] Volumen: música, SFX, master
  - [ ] Gráficos: calidad (baja, media, alta)
  - [ ] Controles: sensibilidad de joystick (umbral a partir del cual se corre; por defecto 80 %, Tarea 0.3)
- [ ] Pantalla de carga:
  - [ ] Barra de progreso
  - [ ] Tips aleatorios (lore del juego)
- [ ] Test: navegación entre menús funciona

**Entregable**: menús funcionales con opciones.

### Tarea 4.3: Audio (SFX + música) (20h)
- [ ] SFX (15-20 sonidos):
  - [ ] Combate: golpes, impactos, muerte zombie, muerte robot
  - [ ] UI: click botón, abrir menú, crafteo exitoso
  - [ ] Movimiento: pasos robot, viaje
  - [ ] Ambiente: viento, máquinas en base, zombies lejanos
  - [ ] Feedback: batería baja, pieza rota, nivel up
- [ ] Música (3 tracks):
  - [ ] Menú principal: tema épico/post-apocalíptico
  - [ ] Base: tema tranquilo/industrial
  - [ ] Zona verde: tema de exploración/tensión baja
- [ ] Sistema de audio:
  - [ ] Autoload `AudioManager.gd`:
    - [ ] Métodos: `play_sfx(sound_id)`, `play_music(track_id)`, `set_volume(category, value)`
    - [ ] Pool de AudioStreamPlayer (para SFX simultáneos)
    - [ ] Fade in/out para música
- [ ] Integración:
  - [ ] Conectar SFX a acciones (golpes, UI, etc.)
  - [ ] Conectar música a estados (base, zona, combate)
- [ ] Test: audio funciona en todas las situaciones

**Entregable**: audio completo con SFX y música.

### Tarea 4.4: Animaciones y feedback visual (16h)
- [ ] Animaciones de personaje:
  - [ ] Robot: idle, walk, attack, hurt, death
  - [ ] Zombies: idle, walk, attack, death
  - [ ] Robot hostil: idle, walk, attack, death
- [ ] Partículas:
  - [ ] Impacto de golpe (chispas)
  - [ ] Muerte de enemigo (explosión de piezas)
  - [ ] Recolección de items (brillo)
  - [ ] Carga de batería (energía fluyendo)
- [ ] Feedback visual:
  - [ ] Screen shake al recibir daño
  - [ ] Hit stop (50ms) al golpear enemigo
  - [ ] Flash blanco en enemigo al recibir daño
  - [ ] Flash rojo en bordes de pantalla al recibir daño
- [ ] Test: animaciones y feedback mejoran game feel

**Entregable**: animaciones y feedback visual completos.

**Tiempo total Fase 4**: ~64h (2 semanas)  
**Criterio de "hecho"**: UI completa, audio funcional, animaciones y feedback pulidos.

---

## Fase 5 — QA y balance (Semana 14-15)

**Objetivo**: playtesting, ajuste de dificultad, fix de bugs, optimización.

### Tarea 5.1: Playtesting interno (20h)
- [ ] Jugar 10 sesiones completas (base → zona → muerte → base)
- [ ] Anotar problemas:
  - [ ] Bugs (crashes, errores de lógica)
  - [ ] Balance (muy difícil, muy fácil, muy lento)
  - [ ] UX (confuso, poco claro, frustrante)
  - [ ] Rendimiento (FPS bajos, lag)
- [ ] Priorizar problemas:
  - [ ] Críticos: crashes, pérdida de progreso
  - [ ] Mayores: bugs de gameplay, balance roto
  - [ ] Menores: problemas cosméticos, optimización
- [ ] Fix de bugs críticos y mayores
- [ ] Test: 5 sesiones sin bugs críticos

**Entregable**: lista de bugs fixes, juego estable.

### Tarea 5.2: Ajuste de balance (16h)
- [ ] Revisar BALANCE.md con datos de playtesting:
  - [ ] ¿Batería dura demasiado/poco?
  - [ ] ¿Zombies son muy fáciles/difíciles?
  - [ ] ¿Drops de materiales son suficientes/insuficientes?
  - [ ] ¿Coste de crafteo es justo?
  - [ ] ¿Degradación de piezas es muy rápida/lenta?
  - [ ] ¿La primera estación de carga (4 chatarra) sale en los primeros minutos? (PMV.md §10)
  - [ ] ¿Bastan 5 minutos para volver a la zona y recuperar los items soltados, con enemigos y cajas repuestos? (BALANCE.md §7.2)
  - [ ] ¿Entrar y salir de la zona en bucle sale gratis? Comprobar que los enemigos y el recorrido hasta las cajas hacen que cada visita cueste batería y riesgo, ya que cada visita repone cajas y enemigos (BALANCE.md §7.2, PMV.md §10)
- [ ] Ajustar valores en BALANCE.md
- [ ] Implementar cambios en código
- [ ] Test: 5 sesiones con nuevo balance

**Entregable**: balance ajustado según playtesting.

### Tarea 5.3: Optimización 3D móvil (20h)
- [ ] Perfilado (Godot built-in profiler):
  - [ ] Identificar cuellos de botella (CPU, GPU)
  - [ ] Medir FPS en dispositivo real (Android gama media)
- [ ] Optimizaciones:
  - [ ] LOD (Level of Detail): reducir polígonos en objetos lejanos
  - [ ] Texturas: comprimir a ETC2 (Android), reducir resolución si es necesario
  - [ ] Luces: limitar a 2-3 luces dinámicas, usar lightmaps para estáticas
  - [ ] Sombras: solo 1 luz direccional con sombras
  - [ ] Object pooling: reutilizar instancias de enemigos, proyectiles, partículas
  - [ ] Draw calls: agrupar meshes estáticos, usar atlas de texturas
- [ ] Test: 60 FPS en gama alta, 30 FPS en gama media

**Entregable**: juego optimizado para móvil.

### Tarea 5.4: Guía básica (8h)
- [ ] Diseño de guía básica:
  - [ ] Paso 1: "Muévete con el joystick" (highlight joystick)
  - [ ] Paso 2: "Abre esta caja" (highlight caja + botón interactuar)
  - [ ] Paso 3: "Ataca al zombie" (highlight botón atacar)
  - [ ] Paso 4: "Vuelve a la base" (highlight botón mapa)
  - [ ] Paso 5: "Craftea tu primera estación de carga" (highlight banco de reparaciones; PMV.md §10)
- [ ] Implementación:
  - [ ] Sistema de pasos guiados (TutorialManager)
  - [ ] Highlights: overlay oscuro con zona iluminada
  - [ ] Flechas: apuntan a elemento interactivo
  - [ ] Texto: explicación de cada paso
  - [ ] Recompensa: al completar guía, dar 5 chatarra + 2 cables
- [ ] Test: guía básica funciona sin ser intrusiva

**Entregable**: guía básica funcional con recompensa.

**Tiempo total Fase 5**: ~64h (2 semanas)  
**Criterio de "hecho"**: juego estable, balanceado, optimizado, con guía básica.

---

## Fase 6 — Export y publicación (Semana 16-17)

**Objetivo**: build Android publicable, testing en dispositivos reales.

### Tarea 6.1: Configuración de export Android (8h)
- [ ] Instalar JDK 17+ y Android SDK
- [ ] Configurar Godot para Android export:
  - [ ] Project > Export > Add Android preset
  - [ ] Configurar keystore de firma (debug y release)
  - [ ] Configurar package name: `com.davidanaya.cyberscrap` (ya usado en los APK debug desde spec 001)
  - [ ] Configurar version code y version name
  - [ ] Habilitar arquitecturas: arm64-v8a, armeabi-v7a
- [ ] Configurar iconos:
  - [ ] Icono de app (512x512 PNG)
  - [ ] Iconos adaptativos (Android 8+)
- [ ] Configurar splash screen:
  - [ ] Imagen de logo (CyberScrap)
  - [ ] Fondo: color oscuro
- [ ] Test: exportar APK debug y probar en dispositivo

**Entregable**: configuración de export lista, APK debug funciona.

### Tarea 6.2: Testing en dispositivos reales (20h)
- [ ] Dispositivos de test:
  - [ ] Android gama media (Samsung A-series, Xiaomi Redmi)
  - [ ] Android gama alta (Samsung S-series, Pixel)
  - [ ] Android gama baja (si es posible)
- [ ] Test en cada dispositivo:
  - [ ] Instalación: APK se instala sin errores
  - [ ] Rendimiento: FPS estables (30-60)
  - [ ] Controles táctiles: joystick y botones responden bien
  - [ ] Guardado: cerrar y reabrir app conserva progreso
  - [ ] Audio: SFX y música suenan correctamente
  - [ ] UI: se adapta a diferentes resoluciones/aspect ratios
- [ ] Anotar problemas específicos de dispositivo
- [ ] Fix de problemas críticos
- [ ] Test: 3 dispositivos sin bugs críticos

**Entregable**: juego funciona en múltiples dispositivos Android.

### Tarea 6.3: Preparación para Play Store (12h)
- [ ] Crear cuenta de desarrollador en Google Play ($25)
- [ ] Preparar assets de Play Store:
  - [ ] Icono de app (512x512)
  - [ ] Capturas de pantalla (mínimo 2, máximo 8)
  - [ ] Gráfico de funciones (1024x500)
  - [ ] Video de gameplay (opcional pero recomendado)
- [ ] Escribir descripción de app:
  - [ ] Descripción corta (80 caracteres)
  - [ ] Descripción completa (4000 caracteres)
  - [ ] Palabras clave: robot, supervivencia, zombies, crafting
- [ ] Clasificación de contenido:
  - [ ] Cuestionario IARC (clasificación por edad)
  - [ ] Probablemente: PEGI 12 o ESRB E10+
- [ ] Política de privacidad:
  - [ ] Generar con herramienta online (privacypolicygenerator.info)
  - [ ] Subir a URL pública (GitHub Pages o similar)
- [ ] Test: completar todos los campos de Play Console

**Entregable**: assets y textos listos para Play Store.

### Tarea 6.4: Subida a Play Store (8h)
- [ ] Crear app en Play Console:
  - [ ] Nombre: CyberScrap
  - [ ] Idioma principal: Español
  - [ ] Categoría: Juegos > Acción
- [ ] Subir AAB (Android App Bundle):
  - [ ] Exportar desde Godot como AAB (no APK)
  - [ ] Firmar con keystore de release
  - [ ] Subir a Play Console
- [ ] Completar ficha de tienda:
  - [ ] Descripciones
  - [ ] Capturas
  - [ ] Icono
  - [ ] Gráfico de funciones
- [ ] Configurar pricing:
  - [ ] Gratis. El PMV se publica como demo / acceso anticipado **sin compras**. El desbloqueo de pago llega en v1.1 (SPECS.md §23); el contenido del PMV seguirá siendo la demo gratuita
- [ ] Enviar para revisión:
  - [ ] Revisión tarda 1-7 días
  - [ ] Si hay rechazo: analizar feedback, corregir, reenviar
- [ ] Test: app aparece en Play Store (después de aprobación)

**Entregable**: CyberScrap publicado en Google Play Store.

**Tiempo total Fase 6**: ~48h (1.5 semanas)  
**Criterio de "hecho"**: app publicada y descargable en Play Store.

---

## Resumen de tiempos

| Fase | Semanas | Horas | Entregable principal |
|---|---|---|---|
| **F0: Configuración** | 1-2 | 42h | Robot se mueve, batería funciona, spike de navmesh medido |
| **F1: Core loop** | 3-5 | 75h | Bucle completo: base → zona → combate → muerte |
| **F2: Base y crafteo** | 6-8 | 109h | Base con colocación libre, 2 bancos + cofres + estaciones de carga + subida de nivel |
| **F3: Piezas** | 9-10 | 44h | Sistema de piezas con degradación |
| **F4: UI/UX** | 11-13 | 64h | HUD, menús, audio, animaciones |
| **F5: QA** | 14-15 | 64h | Juego estable y optimizado |
| **F6: Export** | 16-17 | 48h | Publicado en Play Store (demo gratis) |
| **TOTAL** | **17 semanas** | **446h** | **PMV publicado** |

**Nota (nov 2026)**: +34h por los ganchos de PMV.md §4.5, la Tarea 0.5 y la Tarea 2.7, y +20h por la colocación libre en la base (Tarea 2.8). Las 17 semanas (680h a 40h/semana) siguen teniendo margen sobre las horas estimadas.

**Comparación con PMV original**: 17 semanas vs 25 semanas. Ahorro: 8 semanas (2 meses).

---

## Hitos verificables

| Hito | Semana | Criterio de "hecho" |
|---|---|---|
| **M1: Prototipo jugable** | 2 | Robot se mueve, batería funciona, escena 3D vacía |
| **M2: Core loop funcional** | 5 | Bucle completo: base → zona verde → matar zombies → morir → base |
| **M3: Base completa** | 8 | 2 bancos funcionales, crafteo works |
| **M4: Personalización** | 10 | Piezas equipables, degradación, robot hostil dropea piezas |
| **M5: Pulido** | 13 | UI completa, audio, animaciones, guía básica |
| **M6: Estable** | 15 | Sin bugs críticos, balanceado, optimizado |
| **M7: Publicado** | 17 | App en Play Store |

---

## Riesgos y mitigaciones

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| **Curva de aprendizaje Godot** | Media | +2-4 semanas | Dedicar tiempo a tutoriales antes de empezar |
| **Assets 3D gratuitos insuficientes** | Media | +1-2 semanas | Usar placeholders (cubos) hasta encontrar assets adecuados |
| **Rendimiento 3D en móvil** | Alta | +2-3 semanas | Optimizar desde Fase 0, testear en dispositivo real cada semana |
| **Bugs de guardado** | Media | +1 semana | Backup de save, testing exhaustivo en Fase 5 |
| **Rechazo de Play Store** | Media | +1-2 semanas | Leer guidelines de Play Store antes de enviar, corregir feedback |
| **Scope creep** | Alta | +20-40% tiempo | Respetar fases, no añadir features "solo una cosita más". Las ideas de nov 2026 (mundos por semilla, Hardcore, facciones, vehículos) entran en el PMV solo como ganchos de datos (PMV.md §4.5) |
| **Generación procedural en móvil (v1.1)** | Media | Replantear zonas | Spike de navmesh en Tarea 0.5 antes de comprometer la generación procedural |

---

## Siguiente paso inmediato

**Semana 1, Día 1**:
1. Instalar Godot 4.7.2
2. Crear repositorio Git privado
3. Crear proyecto "CyberScrap" con configuración 3D
4. Crear estructura de carpetas
5. Commit inicial

**¿Listo para empezar?**