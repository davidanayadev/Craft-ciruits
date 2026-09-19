# Plan de Acción — Scrap Circuit (PMV simplificado)

> Plan de ejecución detallado por fases con subtareas específicas.
> **Tiempo total estimado**: 17 semanas (4 meses) a tiempo completo.
> **Objetivo**: PMV publicable en Android con mecánicas core funcionales.
> **Alcance simplificado**: 1 zona, 2-3 enemigos, 3 piezas, 2 bancos.

**Referencias cruzadas**:
- Para alcance del PMV: ver **PMV.md**
- Para balance numérico: ver **BALANCE.md**
- Para features futuras (post-PMV): ver **SPECS.md**

---

## Fase 0 — Configuración y prototipo básico (Semana 1-2)

**Objetivo**: entorno de desarrollo listo + robot se mueve en escena 3D vacía.

### Tarea 0.1: Configuración del proyecto (4h)
- [ ] Instalar Godot 4.7.2
- [ ] Crear proyecto "Scrap Circuit" con configuración 3D
- [ ] Configurar renderer Compatibility (OpenGL ES 3.0)
- [ ] Configurar resolución móvil (1080x1920, aspect ratio 16:9)
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
  - [ ] Input: joystick virtual (izquierda)
  - [ ] Movimiento relativo a cámara (WASD mapeado a isométrico)
  - [ ] Rotación suave hacia dirección de movimiento
- [ ] Crear UI de joystick virtual (CanvasLayer + TextureRect)
- [ ] Probar movimiento en escena

**Entregable**: robot se mueve con joystick virtual en escena 3D.

### Tarea 0.4: Sistema de batería (core) (8h)
- [ ] Crear autoload `GameManager.gd`:
  - [ ] Variables globales: `battery_current`, `battery_max`
  - [ ] Métodos: `consume_battery(amount)`, `recharge_battery()`
- [ ] Crear componente `BatteryComponent.gd` (attachable a Robot):
  - [ ] Signals: `battery_depleted`, `battery_low`
  - [ ] Consumo pasivo: 0.1/s
  - [ ] Consumo movimiento: +0.05/s (andar), +0.15/s (correr)
  - [ ] Lógica: si `battery_current <= 0` → emitir señal `battery_depleted`
- [ ] Crear HUD de batería (TextureProgressBar + Label)
- [ ] Conectar señales a HUD (actualizar en tiempo real)
- [ ] Test: batería baja al moverse, game over al llegar a 0

**Entregable**: sistema de batería funcional con HUD. Robot muere si batería = 0.

**Tiempo total Fase 0**: ~30h (1.5 semanas)  
**Criterio de "hecho"**: robot se mueve con joystick, batería funciona, HUD visible.

---

## Fase 1 — Core loop de juego (Semana 3-5)

**Objetivo**: bucle completo base → zona de farmeo → combate → muerte → base.

### Tarea 1.1: Zona verde (farmeo básico) (16h)
- [ ] Crear escena `FarmZoneGreen.tscn`:
  - [ ] GridMap con tiles de suelo (tierra, hierba)
  - [ ] Decoración: árboles, rocas, chatarra (modelos 3D low poly)
  - [ ] Límites de zona (paredes invisibles o visibles)
- [ ] Sistema de cajas de loot:
  - [ ] Crear escena `LootBox.tscn` (Area3D + MeshInstance)
  - [ ] Script `LootBox.gd`:
    - [ ] Variables: `loot_table` (Array de items con probabilidades)
    - [ ] Método `open()`: generar loot según tabla, emitir señal `loot_generated`
    - [ ] Interacción: botón "Abrir" cuando jugador está cerca
  - [ ] Colocar 5-7 cajas en zona verde
- [ ] Sistema de recolección:
  - [ ] Crear UI de interacción (botón "Abrir" aparece cerca de caja)
  - [ ] Al abrir: mostrar animación, generar items, añadir a inventario
- [ ] Test: abrir cajas genera materiales

**Entregable**: zona verde con cajas de loot recolectables.

### Tarea 1.2: Sistema de inventario (12h)
- [ ] Crear autoload `InventoryManager.gd`:
  - [ ] Variables: `inventory_slots = []` (Array de 5 slots)
  - [ ] Métodos: `add_item(item_id, quantity)`, `remove_item(item_id, quantity)`, `has_item(item_id, quantity)`
  - [ ] Lógica: stack máximo por item (chatarra: 99, cables: 50, hierro: 50)
- [ ] Crear recurso `ItemData.gd` (extends Resource):
  - [ ] Variables: `id`, `name`, `icon`, `stack_max`, `description`
- [ ] Crear items básicos (chatarra, cables, hierro):
  - [ ] Archivos `.tres` para cada item
- [ ] Crear UI de inventario (GridContainer + TextureRect):
  - [ ] Mostrar slots (5 en PMV)
  - [ ] Mostrar icono + cantidad
- [ ] Conectar LootBox con InventoryManager
- [ ] Test: abrir cajas añade items al inventario

**Entregable**: inventario funcional con UI. Items se acumulan correctamente.

### Tarea 1.3: Zombies (2 tipos) (16h)
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
- [ ] Crear 2 tipos de zombies:
  - [ ] Lento: HP 20, daño 5, velocidad 1.5
  - [ ] Rápido: HP 15, daño 4, velocidad 3.5
- [ ] Spawner de zombies:
  - [ ] Crear escena `ZombieSpawner.tscn` (Node3D)
  - [ ] Script: spawnear 5-8 zombies en posiciones aleatorias al cargar zona
- [ ] Test: zombies persiguen y atacan al jugador

**Entregable**: 2 tipos de zombies funcionales con IA básica.

### Tarea 1.4: Sistema de combate (16h)
- [ ] Crear arma básica (tubería):
  - [ ] Crear escena `Weapon.tscn` (MeshInstance + Area3D para hitbox)
  - [ ] Attach al robot (BoneAttachment3D o nodo hijo)
- [ ] Sistema de ataque:
  - [ ] Input: botón de atacar (derecha)
  - [ ] Animación de ataque (AnimationPlayer)
  - [ ] Hitbox: Area3D que se activa durante animación
  - [ ] Detección de enemigos en hitbox
  - [ ] Aplicar daño a HealthComponent del enemigo
  - [ ] Consumo de batería: 1 punto/golpe
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

### Tarea 1.5: Mecánica de muerte (8h)
- [ ] Lógica de muerte del jugador:
  - [ ] Cuando `battery_current <= 0`:
    - [ ] Emitir señal `player_died`
    - [ ] Guardar posición de muerte (coordenadas X, Y, Z)
    - [ ] Guardar items del inventario (para drop)
    - [ ] Limpiar piezas equipadas (conservar solo core)
    - [ ] Transición a base
  - [ ] Mostrar pantalla de "Transferencia de Consciencia" (animación)
- [ ] Drop de items al morir:
  - [ ] Crear escena `DroppedItem.tscn` (Area3D + MeshInstance)
  - [ ] Spawner: crear dropped items en posición de muerte
  - [ ] Timer: items desaparecen después de X minutos (configurable)
- [ ] Recuperación de items:
  - [ ] Viajar de vuelta a zona de muerte (viaje instantáneo en PMV)
  - [ ] Interactuar con dropped items para recuperar
- [ ] Test: al morir, jugador reaparece en base sin piezas, items dropeados en zona

**Entregable**: mecánica de muerte funcional con drop y recuperación de items.

**Tiempo total Fase 1**: ~68h (2 semanas)  
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
  - [ ] Zona de bancos (espacio para 2 bancos)
  - [ ] Zona de cofres (espacio para 5 cofres)
  - [ ] Zona de estación de carga (siempre presente)
- [ ] Test: jugador puede moverse por la base

**Entregable**: escena de base con layout definido.

### Tarea 2.2: Estación de carga (guardado) (8h)
- [ ] Crear escena `ChargingStation.tscn` (Area3D + MeshInstance):
  - [ ] Modelo 3D: panel con pantalla + cables
  - [ ] Interacción: botón "Cargar" cuando jugador está cerca
- [ ] Lógica de carga:
  - [ ] Al interactuar:
    - [ ] Recargar batería al 100% (animación de carga)
    - [ ] Guardar partida (llamar a SaveManager)
    - [ ] Mostrar mensaje "Partida guardada"
- [ ] Test: estación de carga recarga batería y guarda partida

**Entregable**: estación de carga funcional.

### Tarea 2.3: Sistema de guardado (12h)
- [ ] Crear autoload `SaveManager.gd`:
  - [ ] Métodos: `save_game()`, `load_game()`, `delete_save()`
  - [ ] Guardar en archivo JSON encriptado:
    - [ ] Datos del jugador: batería, inventario, piezas equipadas
    - [ ] Datos de base: bancos construidos, cofres, items en cofres
    - [ ] Progresión: nivel de chasis, XP
    - [ ] Timestamp: última vez que se guardó
  - [ ] Encriptación: usar `EncryptionContext` de Godot (AES-256)
- [ ] Autosave:
  - [ ] Guardar automáticamente al entrar en base
  - [ ] Guardar automáticamente al cerrar juego (notification NOTIFICATION_WM_CLOSE_REQUEST)
- [ ] Backup de save:
  - [ ] Crear copia de seguridad antes de sobrescribir
  - [ ] Si save principal está corrupto, cargar backup
- [ ] Test: cerrar y reabrir juego conserva progreso

**Entregable**: sistema de guardado funcional con encriptación y backup.

### Tarea 2.4: Banco de reparaciones (crafteo de piezas) (20h)
- [ ] Crear escena `RepairBench.tscn` (Area3D + MeshInstance):
  - [ ] Modelo 3D: mesa de trabajo con herramientas
  - [ ] Interacción: botón "Usar" cuando jugador está cerca
- [ ] UI de crafteo (popup):
  - [ ] Lista de piezas craftables (con icono + nombre)
  - [ ] Mostrar materiales necesarios (chatarra, cables, hierro)
  - [ ] Botón "Crear" (deshabilitado si no hay materiales)
  - [ ] Botón "Reparar" (para piezas dañadas en inventario)
- [ ] Lógica de crafteo:
  - [ ] Método `craft_piece(piece_id)`:
    - [ ] Verificar materiales suficientes (InventoryManager.has_item)
    - [ ] Restar materiales (InventoryManager.remove_item)
    - [ ] Crear pieza nueva (con durabilidad 100%)
    - [ ] Añadir a inventario (InventoryManager.add_item)
- [ ] Lógica de reparación:
  - [ ] Método `repair_piece(piece_id)`:
    - [ ] Verificar materiales (2 hierro + 1 cable)
    - [ ] Restar materiales
    - [ ] Restaurar durabilidad a 100%
- [ ] Recetas de crafteo básicas:
  - [ ] Brazos básicos: 4 chatarra + 2 cables
  - [ ] Piernas básicas: 4 chatarra + 2 hierro
  - [ ] Core básico: 6 chatarra + 3 cables + 2 hierro
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
    - [ ] Activar efecto: +20 batería máxima, +50% velocidad recarga
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
  - [ ] Al construir: spawnear cofre en posición libre de base
  - [ ] Límite: máximo 5 cofres en base (PMV simplificado)
- [ ] Test: construir cofres, guardar items, recuperar items

**Entregable**: cofres funcionales con UI de almacenamiento.

**Tiempo total Fase 2**: ~74h (2 semanas)  
**Criterio de "hecho"**: base con 2 bancos + cofres + estación de carga. Crafteo funcional.

---

## Fase 3 — Piezas y personalización (Semana 9-10)

**Objetivo**: sistema de piezas intercambiables con stats y degradación.

### Tarea 3.1: Sistema de ranuras de piezas (16h)
- [ ] Crear recurso `PieceData.gd` (extends Resource):
  - [ ] Variables: `id`, `name`, `slot_type` (Brazo/Pierna/Core), `icon`, `stats` (Dictionary)
  - [ ] Stats: `damage`, `attack_speed`, `movement_speed`, `battery_consumption`
- [ ] Crear 3 piezas básicas:
  - [ ] Brazos básicos: daño 10, velocidad 1.0 golpe/s
  - [ ] Piernas básicas: velocidad 3.0 m/s
  - [ ] Core básico: batería máxima 100
  - [ ] Archivos `.tres` para cada pieza
- [ ] Sistema de ranuras en jugador:
  - [ ] Variables: `slot_arm`, `slot_leg`, `slot_core` (referencias a PieceData)
  - [ ] Métodos: `equip_piece(piece)`, `unequip_piece(slot)`, `get_total_stats()`
  - [ ] Lógica: calcular stats totales según piezas equipadas
- [ ] UI de equipamiento (popup):
  - [ ] Mostrar 3 ranuras (Brazo, Pierna, Core)
  - [ ] Mostrar pieza equipada en cada ranura (icono + nombre)
  - [ ] Botón "Cambiar" (abre inventario de piezas)
  - [ ] Mostrar stats totales (daño, velocidad, consumo batería)
- [ ] Test: equipar y desequipar piezas altera stats

**Entregable**: sistema de ranuras funcional con UI.

### Tarea 3.2: Degradación de piezas (12h)
- [ ] Sistema de durabilidad:
  - [ ] Variables en PieceData: `durability_current`, `durability_max = 100`
  - [ ] Degradación por golpe recibido: -5 puntos
  - [ ] Lógica de rotura:
    - [ ] Si `durability_current <= 0`:
      - [ ] Pieza se rompe (se elimina de ranura)
      - [ ] Emitir señal `piece_broken`
      - [ ] Mostrar notificación "Pieza rota"
      - [ ] Stats vuelven a valor base (sin pieza)
- [ ] UI de durabilidad:
  - [ ] En UI de equipamiento: barra de durabilidad bajo cada pieza
  - [ ] Color: verde (>50%), amarillo (25-50%), rojo (<25%)
- [ ] Test: piezas se degradan y rompen con el uso

**Entregable**: sistema de degradación funcional con UI.

### Tarea 3.3: Robot hostil básico (drops de piezas) (16h)
- [ ] Crear escena `HostileRobot.tscn` (CharacterBody3D + MeshInstance):
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
    - [ ] 100% probabilidad: drop 1-2 núcleos de datos (XP)
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
  - [ ] Abajo izquierda: joystick virtual
  - [ ] Abajo derecha: botón atacar (grande), botón agacharse
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
  - [ ] Controles: sensibilidad de joystick
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
  - [ ] Configurar package name: `com.tunombre.scrapcircuit`
  - [ ] Configurar version code y version name
  - [ ] Habilitar arquitecturas: arm64-v8a, armeabi-v7a
- [ ] Configurar iconos:
  - [ ] Icono de app (512x512 PNG)
  - [ ] Iconos adaptativos (Android 8+)
- [ ] Configurar splash screen:
  - [ ] Imagen de logo (Scrap Circuit)
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
  - [ ] Nombre: Scrap Circuit
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
  - [ ] Gratis (F2P)
- [ ] Enviar para revisión:
  - [ ] Revisión tarda 1-7 días
  - [ ] Si hay rechazo: analizar feedback, corregir, reenviar
- [ ] Test: app aparece en Play Store (después de aprobación)

**Entregable**: Scrap Circuit publicado en Google Play Store.

**Tiempo total Fase 6**: ~48h (1.5 semanas)  
**Criterio de "hecho"**: app publicada y descargable en Play Store.

---

## Resumen de tiempos

| Fase | Semanas | Horas | Entregable principal |
|---|---|---|---|
| **F0: Configuración** | 1-2 | 30h | Robot se mueve, batería funciona |
| **F1: Core loop** | 3-5 | 68h | Bucle completo: base → zona → combate → muerte |
| **F2: Base y crafteo** | 6-8 | 74h | Base con 2 bancos + cofres + estación de carga |
| **F3: Piezas** | 9-10 | 44h | Sistema de piezas con degradación |
| **F4: UI/UX** | 11-13 | 64h | HUD, menús, audio, animaciones |
| **F5: QA** | 14-15 | 64h | Juego estable y optimizado |
| **F6: Export** | 16-17 | 48h | Publicado en Play Store |
| **TOTAL** | **17 semanas** | **392h** | **PMV publicado** |

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
| **Scope creep** | Alta | +20-40% tiempo | Respetar fases, no añadir features "solo una cosita más" |

---

## Siguiente paso inmediato

**Semana 1, Día 1**:
1. Instalar Godot 4.7.2
2. Crear repositorio Git privado
3. Crear proyecto "Scrap Circuit" con configuración 3D
4. Crear estructura de carpetas
5. Commit inicial

**¿Listo para empezar?**