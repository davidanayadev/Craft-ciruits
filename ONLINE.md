# Online — Multijugador (CyberScrap)

> Documento de arquitectura multijugador. Implementación por fases, escalable sin rehacer el juego.

**Referencias cruzadas**:
- Cooperativo en parejas (especificación + opinión): ver **Fase 2** de este documento
- Habilidades desbloqueables (sistema general): ver **SPECS.md §6**
- Alcance del PMV: ver **PMV.md**
- Features futuras (post-PMV): ver **SPECS.md**
- Herramientas/servicios técnicos: ver **TOOLING.md**

---

## Filosofía de diseño

**Objetivo**: empezar con multijugador asíncrono (bajo coste, bajo riesgo) pero dejar el juego **preparado para escalar** a co-op y PvP sin tener que reescribir código.

**Principio clave**: separar lógica de juego (local) de lógica de red (servidor). El juego funciona 100% offline. El multijugador es una capa adicional.

**Decisión de arquitectura**: Godot como cliente permanente. Si el juego escala a Fase 3 (PvP masivo), el servidor se reescribe en tecnología profesional (Rust/Go) pero **el cliente Godot no se migra**. Solo se añade un backend más potente detrás.

**Decisiones de nov 2026** (ver SPECS.md §23 y §27):
- **El local es gratis tras pagar el desbloqueo**, incluido el cooperativo en red local de 4-6 jugadores sin servidor (Fase 2A).
- **El online por internet se cobra** con una suscripción opcional solo cuando haya coste de servidor. Nunca bloquea el juego base. Si es posible, se usan capas gratuitas de servicios.
- **Sin anuncios**: ninguna función online se financia con ads.
- **El modo Hardcore es solo individual y sin online** por ahora.
- Cada jugador es un robot consciente (la única clase jugable).

---

## Fase 1: Multijugador asíncrono (v1.5)

**Complejidad**: Baja-Media  
**Infraestructura**: Firebase / Supabase (gratis hasta ~1000 DAU)  
**Tiempo de implementación**: 10-14 semanas post-PMV  
**Coste mensual**: €0-25/mes

### Features

| Feature | Descripción | Implementación |
|---|---|---|
| **Leaderboards globales** | Ranking por: XP total, zombies matados, robots destruidos, piezas recolectadas, nivel de chasis. Actualización en tiempo real (al cerrar sesión). | Firebase Realtime Database. Sync al guardar partida. |
| **Fantasmas/asistentes** | Ves "fantasmas" de otros jugadores en zonas de farmeo (semitransparentes, no interactúas). Da sensación de mundo vivo. | Al entrar en zona, descargar posiciones de otros jugadores (últimos 5 min). Mostrar como sprites semitransparentes. |
| **Mercado asíncrono** | Subes piezas al mercado con un precio (en "créditos"). Otros las compran cuando están online. Transacción automática. | Firebase Firestore. Listado de ofertas. Compra = transferencia de créditos + pieza. |
| **Mensajes en el mundo** | Dejas mensajes tipo "Dark Souls" en zonas peligrosas ("Cuidado: robot eléctrico aquí", "Buen loot en esta caja"). Otros los leen y pueden votar (+/-). | Firebase Firestore. Mensajes geolocalizados (coordenadas X,Y). Mostrar en HUD al pasar cerca. |
| **Clanes con contribución** | Creas o te unes a un clan (máx 20 jugadores). Donas materiales al "tesoro del clan". Cuando se alcanza objetivo, todos reciben recompensa (pieza exclusiva, skin, etc.). | Firebase Firestore. Clan = documento con miembros + tesoro. Contribución = restar materiales del jugador, sumar al tesoro. |
| **Créditos (moneda del mercado)** | Moneda ganada jugando, solo para el mercado asíncrono. Se obtiene matando robots hostiles (1-5 créditos). **No se compra con dinero real ni se gana con anuncios** (decisión nov 2026, SPECS.md §23). | Variable local + sync con servidor. |
| **Semillas compartidas y reto diario/semanal** | Todos juegan la misma semilla de mundo (SPECS.md §26). Ranking del reto. La semilla del día se puede derivar de la fecha sin servidor; el ranking sí necesita servidor. | Firebase/Supabase para el ranking. Puntuaciones del Hardcore no verificables sin validación en servidor: marcarlas como "no verificado" o validarlas. |

### Arquitectura técnica

```
Cliente (Godot)                          Servidor (Firebase/Supabase)
┌─────────────────┐                      ┌─────────────────────┐
│ GameManager     │                      │ Realtime Database   │
│  - SaveManager  │───── Sync ──────────▶│  - Leaderboards     │
│  - TimeManager  │                      │  - Fantasmas        │
│                 │                      │                     │
│ OnlineManager   │                      │ Firestore           │
│  (nuevo)        │───── CRUD ───────────▶│  - Mercado          │
│  - Market       │                      │  - Mensajes         │
│  - Clan         │                      │  - Clanes           │
│  - Leaderboard  │                      │                     │
│                 │                      │ Auth                │
│                 │───── Login ──────────▶│  - Google/Anónimo   │
└─────────────────┘                      └─────────────────────┘
```

**Requisitos de código**:
- `OnlineManager` (autoload singleton): gestiona conexión, login, sync.
- `MarketSystem`: lógica de mercado (subir oferta, comprar, cancelar).
- `ClanSystem`: lógica de clanes (crear, unirse, contribuir, recompensas).
- `LeaderboardSystem`: lógica de rankings (submit score, fetch top).
- `GhostSystem`: lógica de fantasmas (fetch posiciones, renderizar).

**Preparación para escalar**:
- Usar **interfaces** para todos los sistemas online (`IMarket`, `IClan`, etc.). Así puedes cambiar el backend (Firebase → servidor propio) sin tocar el juego.
- **No hardcodear** llamadas a Firebase en el código del juego. Todo pasa por `OnlineManager`.
- **Queue de acciones offline**: si el jugador está offline, las acciones (subir al mercado, contribuir al clan) se encolan y se ejecutan al reconectar.

---

## Fase 2: Multijugador cooperativo (v2.0)

**Complejidad**: Media-Alta  
**Infraestructura**: red local (2A) sin servidor; por internet (2B) con Godot High-Level Multiplayer + servidor relay (o dedicado)  
**Tiempo de implementación**: 12-16 semanas post-Fase 1 (estimación anterior; revisar para 2A)  
**Coste mensual**: €0 en red local; €50-200/mes por internet (relay)

### 2A. Cooperativo en red local (decisión nov 2026)

| Aspecto | Detalle |
|---|---|
| **Jugadores** | 4-6 simultáneos, cada uno con su robot consciente. |
| **Red** | Misma Wi-Fi o punto de acceso del móvil, las dos si es posible (decisión nov 2026). Sin internet. |
| **Jugadores con la demo** | Pueden unirse a la partida de alguien que pagó, **con tiempo limitado**, para que no pague uno y jueguen cuatro gratis (decisión nov 2026): **1 hora por día**. Requiere que el cliente conozca sus derechos (`IStore`, Perfil) y que el anfitrión aplique el límite |
| **Anfitrión** | Un móvil hace de anfitrión autoritativo y además juega. Los demás se unen. |
| **Coste** | Sin servidor. **Gratis una vez pagado el desbloqueo** (SPECS.md §23). Sin condición de escala: no depende del número de usuarios. |
| **Semilla** | Los clientes regeneran cada zona desde la semilla y solo se sincronizan los cambios (cajas abiertas, enemigos, items). Reduce mucho el tráfico. |
| **Modo** | Solo modo Normal. El Hardcore es solo individual. |
| **Requisito de código** | Batería e inventario por jugador en componentes, nunca en autoloads (PMV.md §4.5, gancho 7). |
| **Tecnología** | Godot High-Level Multiplayer con ENet en red local (por verificar en la documentación oficial antes de empezar). |

**Riesgos y dudas**:
- **Rendimiento del anfitrión** (estimación): un móvil de gama media que hace de anfitrión, jugador e IA de 20-30 enemigos con 6 jugadores puede ir justo. Medir antes de prometer 6.
- Límite de 1 hora por día del jugador con la demo: sin servidor, el "día" sale del reloj del móvil y se puede trampear cambiándolo, igual que el generador eólico (specs/architecture.md §14). Se acepta hasta que haya servidor; entonces se usa su hora (`ITimeService`).

### 2B. Cooperativo por internet (si escala)

Jugar por internet tiene que atravesar routers (NAT) y necesita un servicio de apoyo (relay o servidor). Eso cuesta dinero, así que es la parte que se cobra con la suscripción online. Coste real por verificar cuando toque. El resto de esta sección (parejas, raids, intercambio) describe el co-op por internet.

### 2.1 Especificación del co-op en parejas (2 jugadores)

| Aspecto | Detalle |
|---|---|
| **Concepto** | Dos jugadores pueden jugar juntos en la misma zona (co-op local o online). |
| **Modalidad** | **Parejas**: 2 jugadores en misma partida. Cada uno controla su robot. |
| **Invitación** | Jugador genera código de sala. El otro se une por ese código. |
| **Mascota/NPC** | Posibilidad de manejar una mascota robot (controlada por IA o por segundo jugador). |
| **Habilidades en co-op** | Las habilidades desbloqueables (Overclock, Nadar, Correr mucho) funcionan igual en co-op. Cada jugador usa sus propias habilidades desbloqueadas. Ver **SPECS.md §6** para el sistema general de habilidades/progresión. |
| **Progresión en co-op** | La XP ganada en co-op cuenta para la progresión individual de cada jugador (mismos niveles que single-player). No hay "progresión de pareja" separada. |
| **Consumo de energía** | Habilidades consumen batería extra (balancear para que no sean spameables). |

**Opinión sobre el cooperativo**:

**Pros**:
- ✅ Aumenta retención (jugar con amigos = más diversión)
- ✅ Diferenciación en el mercado (pocos juegos de supervivencia móvil tienen coop)
- ✅ Eventos cooperativos futuros (raids, misiones especiales)
- ✅ Monetización justa (cosméticos para parejas, skins coordinadas)

**Contras/riesgos**:
- ❌ Complejidad técnica alta (sync de estado, lag, trampas)
- ❌ Balance difícil (2 jugadores = el doble de recursos, el doble de enemigos)
- ❌ Si solo 1 jugador tiene el juego, no puede jugar coop (barrera de entrada)

**Recomendación**:
- **NO en PMV**. Cooperativo en red local (2A) en **v2.0** sin condición de usuarios; co-op por internet (2B) cuando el juego tenga base de usuarios.
- Empezar con **co-op asíncrono** (Fase 1 de este documento): fantasmas, mercado, clanes.
- Luego **co-op en tiempo real** (Fase 2 de este documento): 2 jugadores en misma zona.
- **Mascota NPC** puede ser una alternativa más simple: un companion controlado por IA que ayuda pero no reemplaza a un jugador real.

### Features

| Feature | Descripción | Implementación |
|---|---|---|
| **Co-op en parejas** | 2 jugadores forman pareja fija. Juegan juntos en zonas de farmeo, comparten loot (cada uno ve su propio loot). Sistema de invitación entre jugadores. | Godot `MultiplayerPeer` + `RPC`. Host = jugador que crea la sala. Pareja se une por código de invitación. |
| **Habilidades en co-op** | Las habilidades desbloqueables (Overclock, Nadar, Correr mucho) funcionan igual en co-op. Cada jugador usa sus propias habilidades desbloqueadas individualmente. Ver SPECS.md §6 para detalles del sistema general. | Sistema de habilidades con cooldown. Cada jugador tiene su propio estado de habilidades. |
| **Progresión en co-op** | La XP ganada en co-op cuenta para la progresión individual de cada jugador (mismos niveles que single-player). No hay "progresión de pareja" separada. | Sistema de XP individual. XP de misiones cooperativas se reparte entre jugadores. |
| **Mascota/NPC** | Posibilidad de manejar mascota robot (controlada por IA o segundo jugador). Sigue al jugador, ataca, recoge loot. | NPC con IA básica o control remoto. Puede equipar piezas básicas. |
| **Co-op en zonas de farmeo** | 2-4 jugadores en la misma zona. Matan zombies/robots juntos, comparten loot (cada uno ve su propio loot, no se pisan). | Godot `MultiplayerPeer` + `RPC`. Host = jugador que crea la sala. Otros se unen por código de sala. |
| **Raids de jefe** | Cada semana, un jefe especial (robot gigante, zombie mutante) que requiere 4 jugadores para matar. Recompensa exclusiva (pieza legendaria). | Zona especial instanciada solo para el grupo. Jefe con HP masivo (10,000+). Loot table exclusiva. |
| **Intercambio directo** | Puedes dar piezas/materiales a otros jugadores en tiempo real (trade screen). | UI de trade: ambos jugadores seleccionan qué ofrecen, confirman. Intercambio atómico (o nada se intercambia). |
| **Misiones cooperativas** | Misiones diarias/semanales que requieren 2+ jugadores ("Matar 10 robots eléctricos en grupo", "Recolectar 50 hierro juntos"). | Sistema de quests con flag `cooperative`. Progreso compartido entre jugadores del grupo. |

### Arquitectura técnica

```
Cliente 1 (Host)                       Servidor Relay (opcional)
┌─────────────────┐                    ┌─────────────────────┐
│ GameManager     │                    │ Godot Server        │
│  - HostMode     │───── P2P ─────────▶│  - Matchmaking      │
│                 │                    │  - Relay (si P2P    │
│ Multiplayer     │                    │    no funciona)     │
│  Manager        │                    │                     │
│  - RPC calls    │◀──── P2P ──────────│                     │
│  - Sync entities│                    └─────────────────────┘
└─────────────────┘
         ▲
         │ P2P
         ▼
Cliente 2, 3, 4
```

**Requisitos de código**:
- `MultiplayerManager` (autoload): gestiona creación de salas, unirse, sincronización.
- `NetworkedEntity`: todos los entidades (jugadores, enemigos, objetos) deben soportar sync de posición/estado.
- **Autoritativo**: el host decide el estado del juego (para evitar trampas). Otros clientes interpolan.
- **Lag compensation**: interpolación de posiciones, predicción de movimiento local.

**Preparación para escalar**:
- Usar **Godot High-Level Multiplayer** (built-in) en lugar de soluciones custom.
- **Dedicated server mode**: Godot puede exportar como "dedicated server" (sin gráficos). Útil si escalas a servidores dedicados.
- **Matchmaking service**: para Fase 3, necesitarás un servicio de matchmaking. Puede ser Firebase Cloud Functions o servidor propio.

---

## Fase 3: Multijugador PvP masivo (v3.0, solo si factura)

**Complejidad**: Alta  
**Infraestructura**: Servidores dedicados + base de datos relacional + anti-cheat  
**Tiempo de implementación**: 20-30 semanas post-Fase 2  
**Coste mensual**: €500-2000/mes

**Decisión de arquitectura**: El cliente sigue siendo Godot. El servidor se reescribe en Rust/Go para escalabilidad. Esto permite soportar miles de jugadores sin migrar el motor.

**Qué mejora el servidor profesional**:
- ✅ Latencia multiplayer (reduce lag entre jugadores)
- ✅ Anti-cheat (valida acciones en servidor, cliente no puede mentir)
- ✅ Escalabilidad (soporta miles de jugadores simultáneos)
- ✅ Matchmaking (emparejamiento rápido por ELO/región)
- ✅ Leaderboards en tiempo real (sync instantánea)
- ✅ Persistencia de datos robusta (BD distribuida)

**Qué NO mejora** (sigue dependiendo del cliente Godot):
- ❌ FPS del cliente (rendimiento 3D local)
- ❌ Velocidad de carga de assets
- ❌ Física del juego (se calcula localmente)
- ❌ IA de zombies/robots (se ejecuta en cliente o servidor, pero no afecta velocidad)
- ❌ Animaciones y efectos visuales

### Features

| Feature | Descripción | Implementación |
|---|---|---|
| **Arena PvP** | 1v1 o 2v2 en zona cerrada. Ranking ELO. Temporadas mensuales con recompensas. | Servidor dedicado. Matchmaking por ELO. Zona instanciada por combate. |
| **Zona de comercio (player-driven)** | Mercado player-to-player con subastas. Economía controlada por jugadores. | Servidor dedicado + BD relacional (PostgreSQL). Subastas con timer. |
| **Clanes vs Clanes** | Guerra de clanes semanal. Clanes compiten por territorio o recursos. Recompensa exclusiva para el clan ganador. | Sistema de "guerras" programadas. Clan con mayor puntuación (kills, capturas) gana. |
| **Mundo abierto PvP** | Zonas donde puedes atacar a otros jugadores (zona roja PvP). Riesgo alto, loot alto. | Servidor dedicado. Zonas marcadas como "PvP enabled". Flag en jugador para activar/desactivar (con cooldown). |
| **Eventos mensuales** | Eventos temporales: "Invasión zombie" (todos cooperan contra horda masiva), "Carrera de robots" (PvP de velocidad). | Scripts de eventos programados. Instanciar zonas especiales con reglas modificadas. |

### Arquitectura técnica

```
Clientes (miles)                         Cluster de servidores
┌─────────────────┐                      ┌─────────────────────┐
│ Godot Client    │                      │ Load Balancer       │
│                 │───── HTTPS ─────────▶│  (Nginx/HAProxy)    │
│                 │                      │                     │
│                 │                      │ Game Servers        │
│                 │───── WebSocket ─────▶│  (Rust/Go)          │
│                 │                      │  - Autoritativo     │
│                 │                      │  - Zona verde       │
│                 │                      │  - Zona roja        │
│                 │                      │  - Arena PvP        │
│                 │                      │                     │
│                 │                      │ Database            │
│                 │                      │  - PostgreSQL       │
│                 │                      │  - Redis (cache)    │
│                 │                      │                     │
│                 │                      │ Anti-cheat          │
│                 │                      │  - Server-authoritative│
└─────────────────┘                      └─────────────────────┘
```

**Nota**: el cliente Godot NO se migra. Solo se añade un servidor profesional detrás. Esto permite escalar sin perder el trabajo de desarrollo del cliente.

**Requisitos de código**:
- **Server-authoritative**: el servidor decide TODO (movimiento, daño, loot). Clientes solo envían inputs.
- **Anti-cheat**: validación de acciones imposibles (moverse más rápido que la velocidad máxima, atacar sin arma, etc.).
- **Sharding**: dividir el mundo en "shards" (instancias de servidor). Cada shard soporta ~100-200 jugadores.
- **Base de datos relacional**: PostgreSQL para datos persistentes (jugadores, clanes, mercado). Redis para cache y sesiones.

**Preparación para escalar**:
- **Microservicios**: separar lógica en servicios independientes (auth, matchmaking, game logic, market).
- **Kubernetes/Docker**: para escalar horizontalmente según carga.
- **CDN**: para assets estáticos (modelos 3D, texturas).

---

## Plan de implementación recomendado

| Fase | Versión | Cuándo implementar | Condición |
|---|---|---|---|
| **Fase 1 (asíncrono)** | **v1.5** | Post-PMV (mes 7-8) | Juego publicado, 100+ usuarios diarios |
| **Fase 2A (co-op red local)** | **v2.0** | mes 12-15 | Ninguna condición de usuarios (sin servidor, incluido en el desbloqueo) |
| **Fase 2B (co-op internet)** | **v2.0+** | mes 12-15 o después | 1000+ usuarios diarios, jugadores piden co-op por internet |
| **Fase 3 (PvP masivo)** | **v3.0** | mes 18-24 | 10,000+ usuarios diarios, juego factura >€5000/mes |

**Nota**: si el juego no crece, **no implementes Fase 2 ni 3**. El multijugador asíncrono es suficiente para retener jugadores.

**Señales de que necesitas Fase 3 (servidor profesional)**:
- Más de 1000 usuarios diarios
- Jugadores piden PvP en tiempo real
- Quieres leaderboards globales en tiempo real
- Hay trampas/reportes de hacks
- El juego factura >€5000/mes y justifica la inversión

---

## Preparación del código desde el PMV

Para no "atarte las manos", desde el PMV debes:

1. **Usar interfaces para todo**: `ISaveManager`, `ITimeManager`, `IMarket`, `IClan`. Así puedes cambiar implementaciones sin tocar el juego.
2. **Separar lógica de red**: `OnlineManager` es el único que habla con el servidor. El resto del código no sabe si hay internet o no.
3. **Queue de acciones offline**: si el jugador está offline, las acciones se encolan y se ejecutan al reconectar.
4. **No hardcodear IDs de jugador**: usar UUIDs generados localmente. Cuando implementes auth, migrar a IDs del servidor.
5. **Event-driven architecture**: usar señales de Godot para todo. Así puedes añadir listeners de red sin tocar el código del juego.
6. **Estado por jugador en componentes** (nov 2026): batería en `BatteryComponent` e inventario en `InventoryComponent`, en la entidad de cada jugador. Ningún autoload guarda estado de un jugador. Sin esto, el cooperativo obliga a reescribir.
7. **Perfil y Mundo separados**: el Perfil (UUID, derechos, salón de la fama) es lo que se sincronizará con una cuenta; el Mundo es la partida.
8. **Aleatoriedad con semilla y `zone_id`**: permite que los clientes regeneren zonas en vez de recibirlas por red, y las semillas compartidas.
9. **Tienda detrás de una clase base** (`IStore`): igual que `IMarket`, la implementación local se cambia por la nativa (o RevenueCat) sin tocar el juego.

El detalle de estos ganchos está en PMV.md §4.5.

**Ejemplo de código preparado para escalar**:

GDScript no tiene interfaces: el contrato es una clase base que las implementaciones extienden. Cada `class_name` debe ir en su propio archivo.

```gdscript
# i_market.gd: contrato (clase base, no se instancia directamente)
class_name IMarket
extends RefCounted

func list_item(item_id: String, price: int) -> void:
    pass

func buy_item(offer_id: String) -> void:
    pass

func cancel_offer(offer_id: String) -> void:
    pass
```

```gdscript
# local_market.gd: implementación local (PMV, sin servidor)
class_name LocalMarket
extends IMarket

func list_item(item_id: String, price: int) -> void:
    # Guardar en archivo local
    pass
```

```gdscript
# firebase_market.gd: implementación online (Fase 1, con Firebase)
class_name FirebaseMarket
extends IMarket

func list_item(item_id: String, price: int) -> void:
    # Subir a Firebase Firestore
    pass
```

---

## Costes estimados por fase

| Fase | Infraestructura mensual | Tiempo de desarrollo | Coste total (1 año) |
|---|---|---|---|
| **Fase 1** | €0-25 (Firebase free tier) | 10-14 semanas | €0-300 |
| **Fase 2A** (red local) | €0 (sin servidor) | por estimar | €0 |
| **Fase 2B** (internet) | €50-200 (servidor relay) | 12-16 semanas | €600-2400 |
| **Fase 3** | €500-2000 (dedicados + BD) | 20-30 semanas | €6000-24,000 |

**Nota**: estos costes son solo de infraestructura. No incluyen tu tiempo de desarrollo.

**Financiación (nov 2026)**: los costes de servidor se cubren con capas gratuitas mientras se pueda y, cuando no, con la suscripción online opcional (SPECS.md §23). Sin anuncios. Las capas gratuitas tienen límites y pausas (p. ej. Supabase pausa proyectos gratuitos tras una semana sin actividad, ver TOOLING.md §4): el juego debe seguir funcionando aunque el backend esté parado.

---

## Riesgos y mitigaciones

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| **Servidor caído** | Media | Alto | Usar Firebase (99.9% uptime). Fallback a modo offline si no hay conexión. |
| **Trampas (hacks)** | Alta (en PvP) | Alto | Server-authoritative (Fase 3). Validar todas las acciones en servidor. |
| **Toxicidad (chat)** | Media | Medio | Chat predefinido (mensajes rápidos) en Fase 1-2. Moderación en Fase 3. |
| **Coste escalado** | Media | Alto | Monitorear costes de Firebase. Alertas si se supera umbral. Migrar a servidor propio si crece mucho. |
| **Latencia (Fase 2-3)** | Alta | Medio | Usar servidores relay cercanos a jugadores. Interpolación de posiciones. |

---

*Documento vivo. Revisar al inicio de cada fase de implementación.*