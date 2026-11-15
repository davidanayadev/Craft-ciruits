# PMV — CyberScrap (Android/iOS)

> Documento de Producto Mínimo Viable. Godot 4.7+ / GDScript. Local-first.
> **Estado: En diseño. Decisión: 3D isométrico estilo LDOE.**
> **Objetivo PMV: €0 de inversión (solo assets gratuitos).**
> **Nombre decidido: CyberScrap** (antes Scrap Circuit; cambio nov 2026)
> **Duración estimada: ~17 semanas (4 meses)** (ver §5.2 y ACTION_PLAN.md)

**Referencias cruzadas**:
- Para features futuras (post-PMV): ver **SPECS.md**
- Para implementación paso a paso: ver **ACTION_PLAN.md**
- Para balance numérico: ver **BALANCE.md**
- Para arquitectura multijugador: ver **ONLINE.md**
- Para herramientas/servicios técnicos: ver **TOOLING.md**

---

## 1. Concepto en una línea

Supervivencia 3D isométrica estilo *Last Day on Earth* donde controlas un robot modular: farmeo de materiales, combate contra zombies y robots hostiles, personalización por piezas intercambiables (brazos/piernas/core) que alteran batería y rendimiento, y base con bancos de trabajo.

**Visión post-PMV (nov 2026)**: eres un robot con consciencia, fruto fallido de un experimento de transferencia de consciencia humana a máquinas, en un mundo dividido entre una IA rebelde telepática, infectados con mente de colmena y humanos (SPECS.md §21, §28). Cada partida es un mundo generado por semilla (SPECS.md §26), con modo Normal y modo Hardcore opcional (SPECS.md §27). Modelo de negocio: demo gratis + desbloqueo único, sin anuncios (SPECS.md §23).

---

## 2. Alcance del PMV simplificado

### 2.1 Qué INCLUYE el PMV

| Sistema | Detalle |
|---|---|
| **Personaje robot** | 3 ranuras: Brazos, Piernas, Core. Cada pieza altera batería + rendimiento. Degradación hasta rotura. |
| **Batería** | Recurso principal. Llega a 0 = muerte. Se consume en todas partes, también dentro de la base. Se recarga al 100% al interactuar con una Estación de carga (instantáneo) o +20 puntos con baterías portátiles. Consumo pasivo: 0.1/s, movimiento: +0.05/s, correr: +0.15/s. |
| **Movimiento** | Viaje entre zonas = instantáneo con animación, y se inicia en un punto de salida físico de la zona o de la base (§10). Dentro de zona = joystick virtual: empujado hasta el 80 % de su radio anda, más allá corre (umbral ajustable en opciones). En PC: WASD y Shift para correr. Sin piernas no se puede correr. Velocidades en BALANCE.md §4.2. |
| **Zona de farmeo** | **1 zona** (verde). Recolecta: chatarra, cables, hierro. Spawns de zombies y robots. |
| **Zombies (2 tipos)** | Lento, Rápido. No sueltan piezas. |
| **Robots hostiles (1 tipo)** | Básico (daño físico). Suelta piezas al morir. |
| **Sistema de daño por partes** | Cada golpe recibido (zombies y robots) degrada -5 la primera pieza equipada intacta, en orden: Brazos (al romperse pierdes ataque) → Piernas (movimiento muy lento) → Core (drena batería). Ver BALANCE.md §4.1. |
| **Mecánica de muerte** | Al morir (batería = 0): pierdes TODO excepto el Core. Reapareces en la base. Ventana temporal para volver a la zona y recuperar piezas. |
| **Base** | Safe zone, sin muros ni ataques dentro. **Colocación libre en cuadrícula** dentro de los límites de la escena de la base: el jugador elige dónde va cada estructura que construye (estaciones, generador, cofres) y puede moverla después (decisión nov 2026; base en cualquier sitio del mundo en v1.1, SPECS.md §32). Contiene: |
| — Banco de reparaciones | Incluido desde el inicio (lo único que trae la base). Reparar o crear piezas básicas; construir estaciones de carga, generador eólico y cofres. |
| — Generador eólico | Aumenta capacidad de batería (+20 máx). **Genera baterías portátiles con el tiempo** (1 batería cada 4h, máx 3 almacenadas). En v1.1 se añadirán bancos avanzados que requieren baterías portátiles (horno, ensamblador, reciclador). Ver SPECS.md §3. |
| — Estación de carga | **Crafteable** (receta barata, BALANCE.md §5.3), todas las que quieras, solo dentro de la base. La base empieza sin ninguna. Al interactuar: batería al 100% (instantáneo) + guardado. Al entrar en la base hay autoguardado, pero no recarga (decisión nov 2026: tensión desde el minuto 0). |
| — Cofres | 5 slots inventario personaje. Hasta 5 cofres, 4 slots cada uno. |
| **XP / Progresión** | El personaje gana XP al matar enemigos, mejorando slots de inventario (ver §6). |
| **Piezas intercambiables** | **3 piezas básicas** (brazos, piernas, core). Cada una con ventaja/desventaja clara. |
| **Persistencia** | Guardado local en dispositivo (JSON/encriptado), separado en **Perfil** (global) y **Mundo** (por partida; en el PMV solo hay uno). Ver §4.5. |
| **Controles táctiles** | Joystick virtual flotante (aparece donde tocas en la mitad izquierda de la pantalla), Botón atacar grande (derecha), Minimapa (arriba derecha), HUD batería + estado piezas (arriba izquierda), Botón consumibles (junto a atacar), Botón interactuar (bancos/objetos), Botón almacenamiento (abajo). |
| **Guía básica** | 5 pasos iniciales (muévete, abre caja, ataca, vuelve a base, craftea tu primera estación de carga). |

### 2.2 Piezas básicas del PMV

| Pieza | Ranura | Ventaja | Desventaja |
|---|---|---|---|
| Brazos básicos | Brazo | Daño 10, velocidad 1.0 golpe/s | Sin habilidades especiales |
| Piernas básicas | Piernas | Velocidad 3.0 m/s andando, 4.8 m/s corriendo | Sin habilidades especiales |
| Core básico | Core | Batería máxima 100 | Sin habilidades especiales |

**Nota**: piezas avanzadas (minería, cuchillas, orugas, propulsores, overclockeado) en v1.1.

### 2.3 Qué NO incluye el PMV

- Más de 1 zona de farmeo (solo zona verde)
- Más de 2 tipos de zombies (solo lento y rápido)
- Más de 1 tipo de robot hostil (solo básico)
- Más de 3 piezas básicas (brazos, piernas, core básicos)
- Armas y banco de armas (v1.1). En el PMV el daño lo dan los brazos equipados.
- Habilidad Overclock (ver SPECS.md §6.2, en v1.1)
- Mundos por semilla con varias zonas y creación de partidas (v1.1, SPECS.md §26). En el PMV hay un solo mundo y una sola zona, aunque el código ya usa los ganchos de §4.5
- Modo Hardcore, salón de la fama y Respaldo de consciencia (v1.1, SPECS.md §27)
- Gasolina y vehículos (v1.2, SPECS.md §19 y §7). Viajes ilimitados en el PMV
- Facciones con contenido propio: humanos, colmena inteligente, IA telepática (v1.2, SPECS.md §28). En el PMV la facción solo existe como dato
- Crafteo "uno mismo" y por nanobots, árbol de crafteo ampliado (v1.2+, SPECS.md §29)
- Multijugador / servidores (cooperativo en red local en v2.0)
- Muros o defensa de base (muros crafteables en v1.1, SPECS.md §32)
- Sigilo/agacharse y salto (v1.1, SPECS.md §30-31). En la demo no hay botón de agacharse
- Base en cualquier sitio del mundo (v1.1, SPECS.md §32). En el PMV la base es una escena fija con colocación libre dentro de sus límites
- Eventos temporales
- Compras de cualquier tipo: el PMV se publica como **demo gratis sin compras**. El desbloqueo de pago llega en v1.1 (SPECS.md §23)
- Cloud save
- Leaderboards
- Tienda in-game
- Tutorial complejo (solo guía básica)

### 2.4 Mecánica de muerte y recuperación

**Al morir (batería = 0, en la zona de farmeo o dentro de la base)**:

1. **Pierdes**: todas las piezas equipadas (brazos, piernas) y los materiales del inventario. La XP no se pierde.
2. **Conservas**: el Core (siempre), progresión de base, cofres almacenados.
3. **Reaparición**: en la base, con la batería al 100% y animación de "Transferencia de Consciencia".
4. **Ventana de recuperación**: tus piezas quedan dropeadas en la zona donde moriste (si fue en la base, en la base). Tienes tiempo limitado para volver y recuperarlas.
5. **Safety net**: si no tienes NADA (sin piezas, sin materiales), la zona verde garantiza drops mínimos (chatarra básica, piezas medio rotas) para que puedas reconstruirte.

**Diseño intencional**: la muerte duele pero no es permanente. El jugador siempre puede recuperarse.

**Modo de juego**: todo lo anterior es el modo **Normal**, el principal. En v1.1 llega el modo **Hardcore**, opcional y solo individual: si mueres, pierdes el mundo, salvo que tengas un Respaldo de consciencia (SPECS.md §27). Por eso, desde el PMV, la reacción a la muerte la decide el ruleset del mundo (§4.5), aunque solo exista `NORMAL`.

### 2.5 Decisión tomada: 3D isométrico estilo LDOE

**Decisión**: Godot 4.7 3D con perspectiva isométrica, estilo low poly cartoon gritty.

**Justificación**:
- Referencia visual: Last Day on Earth (3D low poly isométrico).
- Perfil: programador con experiencia, publicación propia, hobby hasta validar futuro.
- Presupuesto PMV: €0 (solo assets gratuitos).
- Viabilidad: Godot 4.7 3D funciona para low poly en móvil. Gama media/alta sin problemas. Gama baja requiere optimización.

**Assets gratuitos para 3D low poly**:
- **Kenney.nl** — Packs 3D low poly gratuitos (CC0): robots, vehículos, edificios, naturaleza.
- **itch.io** — Sección "3D" con filtros "free" y "low poly".
- **Sketchfab** — Modelos CC Attribution. Buscar "low poly robot", "low poly zombie".
- **OpenGameArt.org** — Modelos 3D gratuitos (ver licencias).
- **Quaternius** — Packs low poly gratuitos (animales, naturaleza, edificios).

**Limitaciones Godot 3D móvil**:
- Renderer Compatibility (OpenGL ES 3.0) para máxima compatibilidad.
- Evitar post-procesado pesado (glow, DOF) en gama baja.
- Limitar polígonos en pantalla: ~50K-100K triángulos máximo.
- Usar LOD (Level of Detail) para objetos lejanos.
- Texturas comprimidas (ETC2 para Android, PVRTC para iOS).

---

## 3. Viabilidad técnica

### 3.1 Motor: Godot 4.7+

| Aspecto | Evaluación |
|---|---|
| **3D en móvil** | Godot 4.7 3D funciona para low poly en gama media/alta. Usar renderer **Compatibility** (OpenGL ES 3.0) para máxima compatibilidad. Evitar post-procesado pesado en gama baja. |
| **GDScript** | Suficiente para el PMV. No necesitas C#/GDExtension. Si el juego escala, migrar sistemas críticos a GDExtension (C++). |
| **Export Android** | Necesitas: JDK 17+, Android SDK, keystore de firma. Google Play exige AAB (no APK). Cuenta developer: $25 (una vez). Nuevo requisito: 12 testers durante 14 días antes de publicar en producción. |
| **Export iOS** | **Requiere Mac con Xcode** para compilar y firmar. No hay workaround. Apple Developer Program: $99/año. Prepararse para al menos 1 rechazo en el primer envío. |
| **Guardado local** | `FileAccess` de Godot con JSON. Encriptar con `EncryptionContext` o AES para evitar trampas simples. |
| **Tamaño APK esperado** | 100-250 MB (3D low poly, modelos, texturas). Aceptable para el mercado. |

### 3.2 Rendimiento esperado (3D low poly)

- **Objetivo**: 30-60 FPS en gama media (Samsung A-series, Xiaomi Redmi). 60 FPS en gama alta.
- **Polígonos en pantalla**: máximo ~50K-100K triángulos (low poly permite esto).
- **Enemigos simultáneos**: máximo ~20-30 en pantalla (usar LOD y frustum culling).
- **Object Pooling**: obligatorio para balas, proyectiles, partículas, enemigos.
- **GridMap**: para el mapa de farmeo (equivalente 3D de TileMap). Usar meshes simples.
- **Texturas**: atlas para reducir draw calls. Compresión ETC2 (Android) / PVRTC (iOS).
- **Luces**: máximo 2-3 luces dinámicas en pantalla. Usar lightmaps para estáticas.
- **Sombras**: solo 1 luz direccional con sombras. Desactivar en gama baja.

### 3.3 Riesgos técnicos

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| Rendimiento pobre en gama baja Android | Media | Alto | Usar renderer Compatibility, limitar sprites on-screen, testear en 3-4 dispositivos reales. |
| Bugs de export iOS por falta de Mac | Alta | Alto | Usar Mac en la nube (MacStadium ~$50/mes) o CI con runners macOS (GitHub Actions). |
| Savegame corrupto | Baja | Alto | Sistema de autosave + backup del slot anterior. |

---

## 4. Arquitectura de código

### 4.1 Principios

- **Clean Code**: nombres descriptivos, funciones cortas (<20 líneas), una responsabilidad por clase/nodo.
- **Escalable**: sistemas modulares que se puedan extender sin romper lo existente.
- **Reutilización**: señales, recursos custom (`.tres`), scenes instanciables.
- **Testeable**: lógica de negocio separada de la presentación (patrón MVC-lite).

### 4.2 Estructura de proyecto propuesta

```
res://
├── scenes/
│   ├── base/              # Escena de la base (bancos, cofres, estación de carga)
│   ├── farm_zone/         # Zona de farmeo (GridMap 3D, spawns, recolección)
│   ├── ui/                # HUD, menús, inventario (2D overlay sobre 3D)
│   └── entities/          # Robot jugador, zombies, robots hostiles (modelos 3D)
├── scripts/
│   ├── autoload/          # Singletons: GameManager, SaveManager, AudioManager
│   ├── components/        # Componentes reutilizables: HealthComponent, BatteryComponent, InventoryComponent, DegradationComponent
│   ├── data/              # Recursos: PieceData, EnemyData, MaterialData, RecipeData, RulesetData, ChassisLevelData (.tres)
│   ├── systems/           # Lógica pura: CraftingSystem, CombatSystem, DegradationSystem
│   └── util/              # Helpers: MathUtils, EncryptionHelper
├── assets/
│   ├── models/            # Modelos 3D: robots, zombies, items, edificios (FBX/glTF)
│   ├── textures/          # Texturas y materiales
│   ├── animations/        # Animaciones 3D (AnimationPlayer)
│   ├── audio/             # SFX y música
│   └── fonts/
├── resources/             # Definiciones de datos (.tres): piezas, enemigos, materiales
└── project.godot
```

### 4.3 Patrones clave

| Patrón | Uso |
|---|---|
| **Autoload (Singleton)** | GameManager (estado global de la partida, no del jugador), SaveManager (persistencia) |
| **Componentes** | BatteryComponent, InventoryComponent, DegradationComponent — attachables a cualquier entidad. El estado de cada jugador (batería, inventario) vive en sus componentes, no en autoloads (§4.5) |
| **Recursos custom** | `PieceData extends Resource` — definir piezas en el editor, sin hardcodear |
| **Señales** | Comunicación entre sistemas sin acoplamiento directo |
| **Object Pool** | Enemigos, proyectiles, partículas de recolección |
| **State Machine** | IA de zombies/robots (Idle, Patrol, Chase, Attack, Flee) |
| **Strategy** | Cada pieza define su comportamiento (Strategy pattern) para alterar stats del robot |

### 4.4 Convenciones

- GDScript con tipado estático (`var battery: float`, `func take_damage(amount: int) -> void`).
- Nombres en inglés para código.
- **i18n obligatorio**: todos los textos del juego en archivos de traducción (ES + EN). No hardcodear strings visibles.
- Escenas: 1 escena = 1 responsabilidad.
- No usar `get_node()` con rutas hardcodeadas; usar `%UniqueNode` o referencias exportadas.
- Señales para todo lo transversal; nunca llamadas directas entre sistemas no relacionados.

### 4.5 Ganchos de arquitectura para el futuro (decisión nov 2026)

Decisiones que cuestan poco en el PMV y semanas si se retrofitan después. Cubren el mundo por semilla, el Hardcore, el cooperativo, el crafteo por niveles y el modelo de pago (SPECS.md §23, §26-29). Se reparten entre tareas existentes de ACTION_PLAN.md (estimación total: ~2-4 días).

| # | Gancho | Por qué | Tarea |
|---|---|---|---|
| 1 | **Dos niveles de guardado**: *Perfil* (UUID anónimo del jugador, derechos de compra, salón de la fama, cosméticos y planos desbloqueados; sobrevive a los mundos) y *Mundo* (un archivo por partida: semilla, ruleset, versión de esquema, jugador, base, cambios por zona) | Hardcore, salón de la fama y compras necesitan algo que sobreviva a un mundo | 2.3 |
| 2 | **Identidad de zona**: todo se guarda como `(zone_id, posición local)`, con zonas alineadas a una cuadrícula | Varias zonas por mundo y, en el futuro, carga de zonas vecinas | 1.1, 1.5, 2.3 |
| 3 | **Aleatoriedad con semilla**: la generación (colocación de cajas, spawns) usa `RandomNumberGenerator` con semilla derivada de `semilla del mundo + zone_id`, nunca `randf()` global | Mundo reproducible desde la semilla; imposible de arreglar después sin romper partidas | 1.1, 1.3 |
| 4 | **Ruleset como dato** (`RulesetData`): la reacción a la muerte la decide el ruleset del mundo. En el PMV solo existe `NORMAL` | Hardcore sin reescribir la mecánica de muerte | 1.5 |
| 5 | **Receta como dato** (`RecipeData` con `station`, `tier`, `requires`) | El árbol de crafteo se rellena con datos | 2.4 |
| 6 | **Facción como dato**: campo `faction` en `EnemyData`; tabla de relaciones en el mundo | Facciones de v1.2 sin tocar enemigos existentes | 1.3 |
| 7 | **Estado por jugador en componentes**: batería en `BatteryComponent` e inventario en `InventoryComponent`, ambos en la entidad del jugador; ningún autoload guarda estado de un jugador | Cooperativo en red local (v2.0) sin reescribir | 0.4, 1.2 |
| 8 | **Tienda detrás de una clase base** (`IStore` + `LocalStore` que siempre devuelve "demo") y derechos (`entitlements`) en el Perfil | Desbloqueo de pago en v1.1 sin tocar el juego | 2.3 |

`VehicleData` (propulsión `ELECTRIC` o `FUEL`) no se crea en el PMV: llega con los vehículos en v1.2.

---

## 5. Estimación de tiempos

### 5.1 Perfil asumido

Desarrollador solo, tiempo completo (40h/semana), con experiencia previa en Godot o motores similares.

### 5.2 Fases y duración (PMV simplificado)

| Fase | Semanas | Entregable |
|---|---|---|
| **F0 — Prototipo jugable** | 2 | Robot 3D se mueve, cámara isométrica, batería funciona, 1 zombie, 1 zona vacía. Validar feel 3D. |
| **F1 — Core loop** | 3 | Farmeo completo: recolectar materiales, combatir, morir, volver a base. 2 tipos zombie + 1 robot. Sistema de daño por partes. |
| **F2 — Base y crafteo** | 3 | 2 bancos funcionales (reparaciones + generador). Reparar/crear piezas básicas. Cofres (máx 5). Estaciones de carga crafteables. |
| **F3 — Piezas y personalización** | 2 | 3 piezas básicas con stats. Degradación. Equipar/desequipar. |
| **F4 — UI/UX y pulido** | 3 | HUD completo, inventario, menús, feedback visual/sonoro, animaciones 3D. |
| **F5 — QA y balance** | 2 | Playtesting, ajuste de dificultad, fix de bugs, optimización 3D móvil. |
| **F6 — Export y publicación** | 2 | Build Android (Play Store). Testing en dispositivos reales. |
| **TOTAL** | **~17 semanas (4 meses)** | |

**Nota**: PMV simplificado vs original: 17 semanas vs 25 semanas. Ahorro: 8 semanas.

**Nota (nov 2026)**: los ganchos de §4.5, la tarea de subida de nivel (ACTION_PLAN Tarea 2.7) y el spike de navmesh (Tarea 0.5) suman ~34h (de 392h a 426h). La colocación libre en la base (Tarea 2.8) añade ~20h más: 446h. Caben en las 17 semanas, que ya tenían margen sobre las horas estimadas (estimación).

### 5.3 Factores de riesgo en el timeline

- Sin experiencia previa en Godot: +3-4 semanas de curva de aprendizaje.
- Sin assets propios (compra de packs): +1 semana de integración y adaptación visual.
- iOS sin Mac disponible: +2-3 semanas de configuración de CI o Mac cloud.
- Scope creep (añadir "solo una cosita más"): +20-40% del tiempo total. **Riesgo real y frecuente.**

---

## 6. Progresión (XP / Inventario)

### 6.1 Niveles de chasis

| Nivel | XP requerida | Beneficio |
|---|---|---|
| **1** | 0 | Base: 5 slots inventario |
| **2** | 50 núcleos | +2 slots inventario (7 total) |
| **3** | 150 núcleos | +3 slots inventario (10 total) |
| **4** | 300 núcleos | +5 slots inventario (15 total) |
| **5** | 500 núcleos | +5 slots inventario (20 total) |

### 6.2 Fuentes de XP (núcleos de datos)

| Fuente | XP |
|---|---|
| Matar zombie lento | 2 |
| Matar zombie rápido | 3 |
| Matar robot hostil básico | 10 |

La XP se otorga directamente al matar; los "núcleos de datos" no son un item (ver BALANCE.md §2).

La subida de nivel (umbral de XP → nuevo nivel → más slots de inventario) la implementa ACTION_PLAN.md Tarea 2.7, con los umbrales y slots en un `.tres` según BALANCE.md §6.

> **Nota**: Para el sistema de progresión extendido (10 niveles con habilidades desbloqueables), ver SPECS.md §6 (v1.1+).

---

## 7. Costes

### 7.1 Costes directos PMV (objetivo: €0)

| Concepto | Coste | Notas |
|---|---|---|
| Godot Engine | €0 | Open source, sin royalties. |
| Assets 3D (modelos, texturas) | €0 | Packs gratuitos: Kenney.nl, itch.io (free), Sketchfab (CC), Quaternius. |
| Audio (SFX, música) | €0 | Packs gratuitos: freesound.org (CC0), OpenGameArt, itch.io audio. |
| Dispositivos de test | €0 | Asumiendo que tienes Android para testear. iOS opcional en PMV. |
| **TOTAL PMV** | **€0** | Solo inversión de tiempo. |

### 7.2 Costes de publicación (cuando decidas publicar)

| Concepto | Coste | Notas |
|---|---|---|
| Google Play Developer | $25 | Una vez. |
| Apple Developer Program | $99/año | Recurrente. Si no hay Mac, MacStadium ~$50/mes. |
| Dominio web (landing) | €10-15/año | Opcional. |
| **TOTAL publicación** | **$25-124** | Solo si decides publicar. |

### 7.3 Coste real contando tu tiempo

Si valoras tu tiempo como freelance GDScript dev ($30-80/h, referencia mercado 2026):

| Escenario | Horas | Coste tiempo | + Gastos directos | **Total** |
|---|---|---|---|---|
| Optimista (con experiencia) | 680h (17 sem × 40h) | $20,400 - $54,400 | €0 | **$20,400 - $54,400** |
| Realista (curva aprendizaje) | 850h (21 sem × 40h) | $25,500 - $68,000 | €0 | **$25,500 - $68,000** |

---

## 8. Pros y contras

### Pros

| # | Ventaja |
|---|---|
| 1 | **Godot es gratuito y sin royalties** — no hay coste de motor. |
| 2 | **3D low poly es viable en Godot 4.7** — rendimiento aceptable en gama media/alta. Assets gratuitos disponibles. |
| 3 | **Mecánica de batería + piezas = loop adictivo** — el dilema "¿arriesgo batería por esta pieza?" genera tensión y rejugabilidad. |
| 4 | **Personalización no lineal** — cada pieza cambia el estilo de juego. |
| 5 | **Local-first reduce costes infraestructura** — sin servidores, sin backend, sin BD. |
| 6 | **Nicho poco explorado** — robots personalizables + supervivencia 3D no tiene un referente dominante en móvil. |
| 7 | **Escalable por diseño** — la arquitectura por componentes permite añadir piezas, zonas, enemigos sin reescribir. |
| 8 | **PMV simplificado = publicar rápido** — 4 meses vs 6 meses. Validas antes. |

### Contras

| # | Desventaja |
|---|---|
| 1 | **Godot 3D en móvil tiene limitaciones** — rendimiento en gama baja requiere optimización. |
| 2 | **iOS requiere Mac** — si no tienes uno, es un coste y fricción adicionales. |
| 3 | **Mercado móvil saturado** — sin marketing, nadie encontrará el juego. |
| 4 | **Solo 20% de juegos indie recuperan inversión el primer año** — estadística dura. |
| 5 | **Sin multijugador en PMV** — limita retención a largo plazo. |
| 6 | **Comisión de tiendas** — ~10-15% para desarrolladores pequeños (datos de nov 2026, ver SPECS.md §23.2; antes se asumía 30%). Con un desbloqueo único y pocas conversiones (0,5-4% orientativo), necesitas mucho volumen. |

---

## 9. Roadmap post-PMV

> **Ver SPECS.md** para especificaciones completas de features futuras.

> **Reorganizado en nov 2026.** Esta tabla es la fuente de verdad del roadmap; SPECS.md §25 la resume.

| Fase | Contenido |
|---|---|
| **PMV (v1.0)** | Alcance de §2.1 + ganchos de §4.5. Se publica como **demo gratis sin compras**. |
| **v1.1 — Mundos y versión completa** | Mundos por semilla y creación de partidas (SPECS §26), 2ª zona (roja) como tipo de zona, modo Hardcore + salón de la fama + Respaldo de consciencia (SPECS §27), **desbloqueo de pago** (SPECS §23), cosméticos básicos como recompensa del salón de la fama. Contenido ya previsto: 2 zombies nuevos (eléctrico, ácido), 1 robot eléctrico, 5 piezas avanzadas (SPECS §15), bancos avanzados (SPECS §3), banco de armas, overclock, tutorial completo, cofres expandidos (20), sigilo y agachado (SPECS §30), salto (SPECS §31), base libre en el mundo con muros, banco de reparaciones crafteable a mano y punto de aparición en tu estación de carga (SPECS §29, §32). |
| **v1.2 — Movilidad y facciones** | Gasolina crafteable (SPECS §19), vehículos eléctricos y de gasolina para viajar por el mapa global (SPECS §7), crafteo "uno mismo" y árbol ampliado (SPECS §29), facciones: humanos hostiles/amistosos, colmena inteligente, IA telepática (SPECS §28). |
| **v1.3** | Eventos temporales, misiones diarias, sistema de invitaciones (refer rewards), Google Play Games (logros, leaderboards de la tienda), tienda de cosméticos. |
| **v1.5** | Co-op asíncrono (ONLINE Fase 1: leaderboards globales, fantasmas, mercado, clanes, semillas compartidas), página web (política, FAQ), analíticas (ver TOOLING.md). Suscripción online si hay coste de servidor. |
| **v2.0** | Cooperativo en red local 4-6 jugadores, sin servidor y gratis tras el desbloqueo (ONLINE Fase 2). Co-op por internet y raids de jefe solo si escala. Cloud save, companion robot. |
| **v2.5** | Vehículos conducibles en 3D, nanorobots, cabeza mejorable, historia con IA. |
| **v3.0** | PvP masivo (ONLINE Fase 3, solo si factura). |

**Por qué este reparto**: v1.1 es la primera versión de pago y necesita contenido que justifique el precio (mundos, Hardcore, segunda zona). Gasolina, vehículos y facciones van juntos en v1.2 porque dependen del mapa global y del árbol de crafteo. **Riesgo**: v1.1 sigue siendo pesada; si se alarga, mover banco de armas, overclock y tutorial completo a v1.2 (el paso 5-6 del tutorial depende del banco de armas).

---

## 10. Decisiones pendientes

### Críticas (antes de programar)

- [x] **2D cenital vs 3D isométrico** — ✅ Decidido: 3D isométrico estilo LDOE.
- [x] **Arte propio o packs de assets** — ✅ Decidido: packs gratuitos (Kenney, itch.io, Sketchfab). €0.
- [x] **Balance numérico (spreadsheet)** — ✅ Creado: BALANCE.md con valores iniciales.
- [x] **Nombre del juego** — ✅ Decidido (nov 2026): **CyberScrap**, sustituye a Scrap Circuit. Paquete Android: `com.davidanaya.cyberscrap` (permanente una vez subido a Play Console).
- [ ] **Disponibilidad de "CyberScrap"** — Hay al menos dos proyectos pequeños con ese nombre en itch.io (uno en desarrollo con Unity y uno de una game jam). Comprobar en Play Store y en un registro de marcas (p. ej. TMview) antes de publicar.

### Importantes (antes de publicar)

- [x] **Android primero o ambas plataformas** — ✅ Decidido (nov 2026): Android primero; es el único producto del PMV (specs/decisions/0001).
- [x] **Mac para iOS** — ✅ Decidido (nov 2026): sin iOS en el PMV. Se decide cuando haya ingresos.
- [x] **Audio** — ✅ Decidido (nov 2026): packs gratuitos CC0 (freesound, OpenGameArt, itch.io), como en §11. Imprescindible: SFX combate, música zonas, UI feedback.
- [ ] **Identidad visual final** — Moodboard con 3-5 referencias visuales concretas.

### Post-PMV

> **Ver SPECS.md** para especificaciones completas de features futuras.

- [x] **Modelo de negocio** — ✅ Decidido (nov 2026): demo gratis + desbloqueo único en v1.1, cosméticos opcionales, suscripción online solo si hay coste de servidor, sin anuncios (SPECS.md §23).
- [x] **Mundo** — ✅ Decidido: mapa de zonas generado por semilla, no mundo continuo (SPECS.md §26).
- [x] **Modos** — ✅ Decidido: Normal principal; Hardcore opcional, solo individual y sin online (SPECS.md §27).
- [x] **Gasolina** — ✅ Decidido: complemento de movilidad, solo crafteable, no se vende en el lanzamiento (SPECS.md §19).
- [x] **Vehículos** — ✅ Decidido: eléctricos y de gasolina; primero aceleran el viaje por el mapa global, en 3D en el futuro (SPECS.md §7).
- [x] **Multijugador local** — ✅ Decidido: cooperativo en red local 4-6, gratis tras el desbloqueo; el online por internet se cobra si cuesta (ONLINE.md Fase 2).
- [x] **Cuenta** — ✅ Decidido: UUID anónimo hasta que haya online.
- [x] **Multijugador / servidores por internet** — ✅ Decidido: solo si el juego escala (ONLINE.md Fase 2B y 3).
- [x] **Legal / privacidad** — ✅ Decidido: generador gratuito de política de privacidad antes de publicar; asesor legal si hay ingresos significativos (TOOLING.md §9). GDPR y COPPA se revisan con esa política.
- [x] **Google Play Games** — ✅ Decidido: v1.3 (TOOLING.md §5).
- [x] **Analíticas** — ✅ Decidido: Firebase Analytics + Crashlytics en v1.5 (TOOLING.md §1-2).

### Preguntas abiertas (nov 2026)

Anotadas para no implementar nada sobre una suposición. Preguntar antes de implementar lo que dependa de ellas.

Ninguna bloquea el PMV (la subida de nivel quedó resuelta con ACTION_PLAN Tarea 2.7).
- [x] **XP de §6.1**: ✅ Decidido (nov 2026): XP **acumulada** (50, 150, 300, 500 en total), no XP adicional por nivel.

**Estación de carga crafteable** (todas decididas en nov 2026)
- [x] **Morir dentro de la base**: ✅ mismas reglas que en zona (los items caen donde mueres, aquí fáciles de recuperar) y reapareces al 100% (§2.4).
- [x] **Morir como recarga gratis**: ✅ se acepta. Antes de tener la primera estación no tienes nada que perder; es la red de seguridad de §2.4 punto 5.
- [x] **Colocación**: ✅ la elige el jugador, en cuadrícula, dentro de los límites de la base (ACTION_PLAN Tarea 2.8).
- [x] **Base llena**: ✅ si no queda sitio en la cuadrícula, el botón de construir se desactiva con un aviso antes de gastar materiales.
- [x] **Banco de reparaciones**: ✅ fijo e incluido en la demo; no se mueve. En v1.1 se craftea a mano, sin límite de cantidad, para fundar bases donde quieras (SPECS.md §29, §32).
- [x] **Guía básica (Tarea 5.4)**: ✅ se añade el paso "Craftea tu primera estación de carga", tras "Vuelve a la base".
- [x] **Coste**: ✅ 4 chatarra como valor inicial (BALANCE.md §5.3). Tarea de playtesting (5.2): comprobar que la primera estación sale en los primeros minutos.

**Cajas de loot y viaje entre zonas (specs 004, 006, 009, 010)**
- [x] **Reposición de cajas abiertas**: ✅ Decidido (nov 2026): **por visita, nunca por tiempo** (no se usa el reloj real). Cada zona guarda en el mundo un contador de visitas que sube **al salir** de la zona, no al entrar ni al cargar la partida. Las cajas abiertas se guardan mientras dura la visita: cerrar y abrir la app devuelve la misma visita con las mismas cajas abiertas. El contenido de cada caja sale de semilla del mundo + `zone_id` + índice de la caja + número de visita, así que recargar no lo cambia; el número y la posición de las cajas siguen saliendo solo de la semilla y el `zone_id`. Los enemigos reaparecen con el mismo contador (spec 006). La regla está en BALANCE.md §7.2 y la aplica el guardado por zona (spec 010). Descartado: temporizador real (se salta cambiando la hora del móvil y no hay servidor que lo impida) y no reponer nunca (con una sola zona el jugador se queda sin materiales).
- [x] **Coste del viaje en el PMV**: ✅ Decidido (nov 2026): se mantiene instantáneo, ilimitado y sin coste (§2.1, BALANCE.md §1.2). No se adelanta el coste de batería de v1.1.
- [x] **Cómo se dispara el viaje**: ✅ Decidido (nov 2026): con un **punto de salida físico** en la zona (y otro en la base), no con un botón disponible en cualquier sitio. Es un `InteractableComponent` con su propio prompt (por ejemplo `PROMPT_TRAVEL`), que lo implementa el spec 009.
- [x] **Morir en la zona y el contador de visitas**: ✅ Decidido (nov 2026): morir **cuenta como salir**, así que sube el contador de visitas de la zona. Al volver a recuperar las piezas (§2.4) las cajas están repuestas y los enemigos han reaparecido: es intencionado, para complicar la recuperación. Los items soltados por la muerte no se reponen ni desaparecen por la visita nueva (BALANCE.md §7.2). Los aplican el spec 008 (muerte) y el 010 (guardado).

**Decidir antes de empezar v1.1**
- [x] **Número de piezas avanzadas de v1.1**: ✅ Decidido (nov 2026): las **5** de SPECS.md §15 (más el Core Estándar). Los enemigos de v1.1 quedan en 2 zombies + 1 robot (SPECS §17).
- [x] **Viaje a pie entre zonas** en mundos por semilla: ✅ Decidido (nov 2026): cuesta batería según la distancia (valor en BALANCE.md §1.2 al diseñar v1.1). La gasolina y los vehículos lo abaratan después (SPECS §26).

**Pueden esperar**
- [x] **"Local"** en el cooperativo: ✅ Decidido (nov 2026): misma Wi-Fi o punto de acceso del móvil, las dos si es posible; sin internet.
- [x] **Demo y cooperativo**: ✅ Decidido (nov 2026): un jugador con la demo **puede unirse** a la partida de alguien que pagó, pero **con tiempo limitado**, para que no pague uno y jueguen cuatro gratis (ONLINE.md Fase 2A).
- [x] **Tiempo del jugador demo en cooperativo**: ✅ Decidido (nov 2026): **1 hora por día**.
- [ ] **Rendimiento del anfitrión** en cooperativo de 6 con 20-30 enemigos en gama media: medir antes de prometer 6.
- [ ] **Respaldo de consciencia**: receta, banco, dónde debe llevarse (equipado, inventario o base) y si su uso tiene penalización extra.
- [ ] **Salón de la fama**: campos de la entrada y cómo se aplican los planos ganados a mundos nuevos.
- [ ] **Corte exacto de la demo** y **precio** del desbloqueo (estimación: 3,99-4,99 €; decidir cerca de v1.1).
- [x] **Pase de temporada cosmético**: ✅ Decidido (nov 2026): no. SPECS §25 promete contenido sin FOMO.
- [x] **Recompensas de invitación** (SPECS §14): ✅ Decidido (nov 2026): solo cosméticas; sin plano exclusivo ni ventajas de juego.
- [ ] **Gasolina**: materia prima, banco que la refina, si aparece como loot y qué piezas de movimiento la usan.
- [ ] **Vehículos**: qué propulsión usa cada vehículo y sus costes en BALANCE.md.
- [ ] **Nanobots**: ¿se adelanta el nivel de crafteo con nanobots (hoy v2.5)?
- [ ] **Crafteo "uno mismo"**: coste (tiempo o batería) y qué recetas permite.
- [ ] **Humanos**: ¿reputación por asentamiento o relación fijada por la semilla?
- [ ] **Lore**: nombre del programa de transferencia de consciencia y origen de la infección.
- [ ] **Overclock (v1.1)**: SPECS §6.2 dice que dura hasta desactivarlo o batería < 10%; §6.3 nivel 7 dice "15s en vez de 10s".
- [ ] **Niveles 6-10 (v1.1)**: SPECS §6.3 no da umbrales de XP y el nivel 8 no tiene recompensa.
- [ ] **Multiplataforma**: el desbloqueo es por tienda hasta que haya cuentas; unificar Android e iOS requiere servidor.

---

## 11. Requisitos técnicos confirmados

| Requisito | Detalle |
|---|---|
| **Git** | Control de versiones obligatorio desde día 1. Repo privado (GitHub/GitLab). |
| **i18n** | Español + Inglés desde el inicio. No hardcodear textos. Usar sistema de traducción de Godot. |
| **Audio** | Imprescindible. SFX + música. Presupuesto PMV: €0 (freesound.org CC0, OpenGameArt, itch.io audio gratuito). |
| **Game feel** | Screen shake, hit stop, partículas, feedback visual. Imprescindible para combate satisfactorio. |

---

## 12. Estilo visual (3D low poly isométrico)

**Referencia**: *Last Day on Earth* — Modelado 3D estilizado low poly, tono cartoon gritty, perspectiva isométrica.

| Elemento | Descripción |
|---|---|
| **Personajes** | Robots modulares con piezas visibles. Estilo mecánico/industrial. Modelos 3D low poly (~500-1000 triángulos por robot). |
| **Zombies** | Orgánicos, degradados, contraste con los robots. Modelos 3D low poly (~300-800 triángulos). |
| **Entorno** | Post-apocalíptico: edificios en ruinas, vegetación reclaimando, chatarra esparcida. Tiles 3D modulares. |
| **Colores** | Paleta desaturada con acentos neón (cyberpunk sutil). |
| **UI** | 2D overlay sobre 3D. Limpia, industrial, con elementos mecánicos. |
| **Cámara** | Isométrica (45° rotación Y, ~35-45° tilt X). Zoom fijo o 2-3 niveles. |

**Assets 3D gratuitos recomendados**:
- **Kenney.nl** — Packs "Robot Kit", "Urban Planning Kit", "Nature Kit" (CC0).
- **Quaternius** — "Low Poly Animals", "Low Poly Buildings" (CC0).
- **itch.io** — Buscar "low poly robot free", "low poly zombie free".
- **Sketchfab** — Modelos CC Attribution. Filtrar por "downloadable" y "low poly".

---

*Documento actualizado: noviembre 2026. Revisar al inicio de cada fase.*