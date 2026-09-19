# PMV — Scrap Circuit (Android/iOS)

> Documento de Producto Mínimo Viable. Godot 4.7+ / GDScript. Local-first.
> **Estado: En diseño. Decisión: 3D isométrico estilo LDOE.**
> **Objetivo PMV: €0 de inversión (solo assets gratuitos).**
> **Nombre decidido: Scrap Circuit**
> **Duración estimada: 12-15 semanas (3-4 meses)**

**Referencias cruzadas**:
- Para features futuras (post-PMV): ver **SPECS.md**
- Para implementación paso a paso: ver **ACTION_PLAN.md**
- Para balance numérico: ver **BALANCE.md**
- Para arquitectura multijugador: ver **ONLINE.md**
- Para herramientas/servicios técnicos: ver **TOOLING.md**

---

## 1. Concepto en una línea

Supervivencia 3D isométrica estilo *Last Day on Earth* donde controlas un robot modular: farmeo de materiales, combate contra zombies y robots hostiles, personalización por piezas intercambiables (brazos/piernas/core) que alteran batería y rendimiento, y base con bancos de trabajo.

---

## 2. Alcance del PMV simplificado

### 2.1 Qué INCLUYE el PMV

| Sistema | Detalle |
|---|---|
| **Personaje robot** | 3 ranuras: Brazos, Piernas, Core. Cada pieza altera batería + rendimiento. Degradación hasta rotura. |
| **Batería** | Recurso principal. Llega a 0 = muerte. Se recarga en base (instantáneo) o con baterías portátiles (+20 puntos). Consumo pasivo: 0.1/s, movimiento: +0.05/s, correr: +0.15/s. |
| **Movimiento** | Viaje entre zonas = instantáneo con animación. Dentro de zona = joystick virtual (andar/correr). |
| **Zona de farmeo** | **1 zona** (verde). Recolecta: chatarra, cables, hierro. Spawns de zombies y robots. |
| **Zombies (2 tipos)** | Lento, Rápido. No sueltan piezas. |
| **Robots hostiles (1 tipo)** | Básico (daño físico). Suelta piezas al morir. |
| **Sistema de daño por partes** | Robots hostiles destruyen piezas en orden: Brazos (pierdes ataque) → Piernas (movimiento muy lento) → Core (drena batería). |
| **Mecánica de muerte** | Al morir (batería = 0): pierdes TODO excepto el Core. Reapareces en la base. Ventana temporal para volver a la zona y recuperar piezas. |
| **Base** | Safe zone, sin muros ni ataques dentro. Contiene: |
| — Banco de reparaciones | Reparar o crear piezas básicas. |
| — Generador eólico | Aumenta capacidad de batería (+20 máx) y velocidad de recarga. **Genera baterías portátiles con el tiempo** (1 batería cada 4h, máx 3 almacenadas). En v1.1 se añadirán bancos avanzados que requieren baterías portátiles (horno, ensamblador, reciclador). Ver SPECS.md §3. |
| — Estación de carga | Guardado + batería al máximo. |
| — Cofres | 5 slots inventario personaje. Hasta 5 cofres, 4 slots cada uno. |
| **XP / Progresión** | El personaje gana XP mejorando slots de inventario (ver §6). |
| **Piezas intercambiables** | **3 piezas básicas** (brazos, piernas, core). Cada una con ventaja/desventaja clara. |
| **Persistencia** | Guardado local en dispositivo (JSON/encriptado). |
| **Controles táctiles** | Joystick virtual (izquierda), Botón atacar grande (derecha), Botón agacharse/sigilo (debajo de atacar), Minimapa (arriba derecha), HUD batería + estado piezas (arriba izquierda), Botón consumibles (junto a atacar), Botón interactuar (bancos/objetos), Botón almacenamiento (abajo). |
| **Guía básica** | 3-4 pasos iniciales (muévete, abre caja, ataca, vuelve a base). |

### 2.2 Piezas básicas del PMV

| Pieza | Ranura | Ventaja | Desventaja |
|---|---|---|---|
| Brazos básicos | Brazo | Daño 10, velocidad 1.0 golpe/s | Sin habilidades especiales |
| Piernas básicas | Piernas | Velocidad 3.0 m/s | Sin habilidades especiales |
| Core básico | Core | Batería máxima 100 | Sin habilidades especiales |

**Nota**: piezas avanzadas (minería, cuchillas, orugas, propulsores, overclockeado) en v1.1.

### 2.3 Qué NO incluye el PMV

- Más de 1 zona de farmeo (solo zona verde)
- Más de 2 tipos de zombies (solo lento y rápido)
- Más de 1 tipo de robot hostil (solo básico)
- Más de 3 piezas básicas (brazos, piernas, core básicos)
- Banco de armas (armas en v1.1)
- Habilidad Overclock (ver SPECS.md §6.2, en v1.1)
- Gasolina / sistema de viajes limitado (viajes ilimitados en PMV)
- Multijugador / servidores
- Muros o defensa de base
- Eventos temporales
- IAP (compras in-app)
- Cloud save
- Leaderboards
- Tienda in-game
- Tutorial complejo (solo guía básica)

### 2.4 Mecánica de muerte y recuperación

**Al morir (batería = 0 en zona de farmeo)**:

1. **Pierdes**: todas las piezas equipadas (brazos, piernas), armas, materiales del inventario.
2. **Conservas**: el Core (siempre), progresión de base, cofres almacenados.
3. **Reaparición**: en la base, con animación de "Transferencia de Consciencia".
4. **Ventana de recuperación**: tus piezas quedan dropeadas en la zona donde moriste. Tienes tiempo limitado para volver y recuperarlas.
5. **Safety net**: si no tienes NADA (sin piezas, sin materiales), la zona verde garantiza drops mínimos (chatarra básica, piezas medio rotas) para que puedas reconstruirte.

**Diseño intencional**: la muerte duele pero no es permanente. El jugador siempre puede recuperarse.

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
│   ├── data/              # Recursos: PieceData, EnemyData, MaterialData (.tres)
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
| **Autoload (Singleton)** | GameManager (estado global), SaveManager (persistencia) |
| **Componentes** | BatteryComponent, InventoryComponent, DegradationComponent — attachables a cualquier entidad |
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

---

## 5. Estimación de tiempos

### 5.1 Perfil asumido

Desarrollador solo, tiempo completo (40h/semana), con experiencia previa en Godot o motores similares.

### 5.2 Fases y duración (PMV simplificado)

| Fase | Semanas | Entregable |
|---|---|---|
| **F0 — Prototipo jugable** | 2 | Robot 3D se mueve, cámara isométrica, batería funciona, 1 zombie, 1 zona vacía. Validar feel 3D. |
| **F1 — Core loop** | 3 | Farmeo completo: recolectar materiales, combatir, morir, volver a base. 2 tipos zombie + 1 robot. Sistema de daño por partes. |
| **F2 — Base y crafteo** | 3 | 2 bancos funcionales (reparaciones + generador). Reparar/crear piezas básicas. Cofres (máx 5). Estación de carga/guardado. |
| **F3 — Piezas y personalización** | 2 | 3 piezas básicas con stats. Degradación. Equipar/desequipar. |
| **F4 — UI/UX y pulido** | 3 | HUD completo, inventario, menús, feedback visual/sonoro, animaciones 3D. |
| **F5 — QA y balance** | 2 | Playtesting, ajuste de dificultad, fix de bugs, optimización 3D móvil. |
| **F6 — Export y publicación** | 2 | Build Android (Play Store). Testing en dispositivos reales. |
| **TOTAL** | **~17 semanas (4 meses)** | |

**Nota**: PMV simplificado vs original: 17 semanas vs 25 semanas. Ahorro: 8 semanas.

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
| 6 | **30% comisión tiendas** — sobre un juego de $2.99, recibes ~$2. Necesitas mucho volumen. |

---

## 9. Roadmap post-PMV

> **Ver SPECS.md** para especificaciones completas de features futuras.

| Fase | Contenido |
|---|---|
| **v1.1** | 2ª zona (roja), 2 zombies nuevos (eléctrico, ácido), 1 robot eléctrico, 3 piezas avanzadas, banco de armas, overclock, gasolina, tutorial completo, cofres expandidos (20). |
| **v1.2** | Eventos temporales, misiones diarias, leaderboards, sistema de invitaciones (refer rewards), Google Play Games (logros). |
| **v1.5** | Co-op asíncrono (ONLINE Fase 1: leaderboards globales, fantasmas, mercado, clanes), página web (política, FAQ), analíticas (ver TOOLING.md). |
| **v2.0** | Co-op en tiempo real (ONLINE Fase 2: parejas, raids de jefe), cloud save, vehículos, companion robot. |
| **v2.5** | Nanorobots, cabeza mejorable, historia con IA. |
| **v3.0** | PvP masivo (ONLINE Fase 3, solo si factura). |

---

## 10. Decisiones pendientes

### Críticas (antes de programar)

- [x] **2D cenital vs 3D isométrico** — ✅ Decidido: 3D isométrico estilo LDOE.
- [x] **Arte propio o packs de assets** — ✅ Decidido: packs gratuitos (Kenney, itch.io, Sketchfab). €0.
- [x] **Balance numérico (spreadsheet)** — ✅ Creado: BALANCE.md con valores iniciales.
- [x] **Nombre del juego** — ✅ Decidido: **Scrap Circuit**. Disponible en Play Store.

### Importantes (antes de publicar)

- [ ] **Android primero o ambas plataformas** — Recomendado: Android primero, iOS 4-6 semanas después.
- [ ] **Mac para iOS** — Si no tienes: MacStadium/cloud (~$50/mes) o descartar iOS en PMV.
- [ ] **Audio** — Crear o comprar. Imprescindible: SFX combate, música zonas, UI feedback.
- [ ] **Identidad visual final** — Moodboard con 3-5 referencias visuales concretas.

### Post-PMV

> **Ver SPECS.md** para especificaciones completas de features futuras.

- [ ] **Tienda e IAP** — Solo si el juego funciona.
- [ ] **Multijugador / servidores** — Solo si escala.
- [ ] **Legal / privacidad** — Política de privacidad, GDPR, COPPA.
- [ ] **Google Play Games** — Cloud save, logros, leaderboards.
- [ ] **Analíticas** — Firebase Analytics + Crashlytics.

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

*Documento actualizado: septiembre 2026. Revisar al inicio de cada fase.*