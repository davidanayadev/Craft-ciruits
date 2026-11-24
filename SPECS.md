# Especificaciones Generales — CyberScrap

> Documento de visión completa del juego (más allá del PMV). Aquí van todas las ideas y features futuras.
> **PMV = solo lo mínimo para publicar y validar.** Todo lo demás va aquí.

**Referencias cruzadas**:
- Para alcance del PMV: ver **PMV.md**
- Para balance numérico: ver **BALANCE.md**
- Para implementación paso a paso: ver **ACTION_PLAN.md**
- Para arquitectura multijugador (co-op, PvP): ver **ONLINE.md**
- Para herramientas/servicios técnicos (analíticas, monetización, backend): ver **TOOLING.md**

---

## Filosofía de diseño

**Objetivo**: juego divertido, que enganche, con progresión satisfactoria. Coop y eventos en el futuro, pero sin que sea absurdo ni pay-to-win. El jugador debe poder disfrutar su ritmo sin que el progreso sea mínimo o las recompensas requieran tiempo imposible.

**Principios**:
- Progresión clara y satisfactoria
- Coop opcional pero valioso
- Eventos accesibles, no frustrantes
- Monetización justa (sin pay-to-win, sin anuncios; ver §23)
- El jugador siempre puede recuperar progreso tras morir **en el modo Normal**. El modo Hardcore es opcional y el jugador acepta la muerte permanente (ver §27)

> **Decisiones de diseño de noviembre 2026**: mundo por semilla (§26), modos Normal/Hardcore y salón de la fama (§27), facciones y nuevo lore (§21, §28), crafteo por niveles (§29), gasolina como complemento de movilidad (§19), vehículos eléctricos y de gasolina (§7) y nuevo modelo de monetización (§23). Las preguntas abiertas están en PMV.md §10.

---

## 1. Nanorobots de construcción

| Aspecto | Detalle |
|---|---|
| **Función** | Permiten construir estructuras (muros, torretas, trampas) tanto en base como fuera de ella. |
| **En base** | Construyen estructuras básicas/estándar de la base (bancos, cofres, etc.). |
| **Fuera de base** | Con nanorobots puedes construir **más cosas** en zonas de farmeo: estructuras temporales avanzadas (cobertura, trampas, bloqueo de caminos). |
| **Restricción** | La construcción avanzada fuera de base requiere nanorobots (recurso limitado). Sin ellos, solo puedes construir piezas básicas. |
| **Coste** | Recurso especial "nanorobots" (dropean robots hostiles avanzados o se craftan con materiales raros). |
| **Uso** | Desplegar nanorobots en zona → construyen estructura en X segundos. Estructuras temporales (duran 1 sesión o hasta que te alejes). |
| **Estrategia** | Útil para crear cobertura temporal en zona roja, bloquear caminos de zombies, o asegurar ruta de escape. |
| **Crafteo** | Los nanobots son una de las tres vías de crafteo (uno mismo, nanobots, mesa de trabajo). Ver §29. |

**Estado**: Por desarrollar en detalle. Post-PMV (v2.5). Pregunta abierta: ¿se adelanta el nivel de crafteo con nanobots? (PMV.md §10).

---

## 2. Amigo robot ayudante (companion)

| Aspecto | Detalle |
|---|---|
| **Función** | Robot NPC que te sigue y ayuda en combate/farmeo. |
| **Obtención** | Craftar en banco especial (requiere planos raros + materiales avanzados). |
| **Comportamiento** | Sigue al jugador, ataca enemigos automáticamente, recoge loot básico. |
| **Personalización** | Puedes equiparle piezas básicas (brazos, piernas) para mejorar sus stats. |
| **Limitaciones** | Tiene su propia batería (se recarga en base). Si muere, debes repararlo en base (coste materiales). |
| **Niveles** | Puede subir de nivel (gana XP de combates), desbloqueando habilidades pasivas (más daño, más velocidad, auto-reparación). |

**Estado**: Idea. Post-PMV.

---

## 3. Bancos avanzados que requieren energía (v1.1+)

> **Nota**: El generador eólico con generación de baterías ya está incluido en el PMV (ver PMV.md §2.1). Esta sección describe bancos adicionales que requieren baterías portátiles para funcionar.

| Banco | Energía requerida | Función |
|---|---|---|
| **Horno de fundición** | 1 batería portátil por uso | Convierte chatarra en hierro (3 chatarra → 1 hierro). Necesario para crafteo avanzado. |
| **Ensamblador avanzado** | 2 baterías portátiles por uso | Crea piezas avanzadas (Cuchillas de Plasma, Propulsores Iónicos). |
| **Reciclador** | 1 batería portátil por uso | Descompone piezas rotas en materiales base (recupera 50% de materiales). |

**Nota**: el Ensamblador avanzado es el candidato natural para craftear el Respaldo de consciencia del modo Hardcore (§27). Receta y banco por definir.

**Estado**: v1.1+. Requiere rediseñar economía de recursos.

---

## 4. Truco de la pared (mecánica de combate estilo LDOE)

| Aspecto | Detalle |
|---|---|
| **Concepto** | Puedes usar una pared como escudo contra enemigos. |
| **Mecánica** | Si te colocas en una esquina específica (difícil de alcanzar), el enemigo queda golpeando la pared sin alcanzarte. |
| **Oportunidad** | Cuando el enemigo está en animación de ataque a la pared, puedes salir y golpearle (le haces daño). |
| **Riesgo** | Si golpeas o te golpea estando en esa esquina (detrás de la pared), ni le haces ni te hace daño. |
| **Estrategia** | Requiere posicionamiento preciso. Útil para enemigos lentos o cuando estás bajo de batería. |
| **Limitación** | No funciona contra todos los enemigos (robots eléctricos pueden darte a distancia). |

**Nota técnica (para cuando se implemente)**:
- **Detección "detrás de la pared"**: comprobar que una colisión/pared intercepta el `RayCast` entre jugador y enemigo. Si la pared está en la línea de ataque, el golpe no conecta (ni daña ni recibe daño).
- **Punto óptimo de posición**: definir una zona "sweet spot" en la esquina donde el enemigo queda bloqueado en su animación de ataque contra la pared.
- **Timing de contraataque**: la ventana para salir y golpear coincide con el final de la animación de ataque del enemigo (cuando "espera para volver a golpear"). Implementar como ventana de X ms tras el ataque fallido del enemigo.
- **Animación**: si el enemigo está en estado "ataque a pared", su hitbox de daño se desactiva → permite al jugador salir sin recibir daño.

**Estado**: v1.1+ (mecánica de combate opcional).

---

## 5. Cooperativo entre dos jugadores (parejas)

> **Especificación completa, opinión y recomendación movidas a ONLINE.md Fase 2.** El cooperativo en parejas es una feature de multijugador y vive en el documento de online.

- **Concepto**: 2 jugadores en pareja juegan juntos en la misma zona.
- **Mascota/NPC**: controlable por IA o segundo jugador.
- **Habilidades**: funcionan igual que en single-player (ver §6).
- **Progresión**: la XP cuenta para cada jugador individualmente.

**Estado**: v2.0. Ver **ONLINE.md Fase 2**.

---

## 6. Habilidades activas y recuerdos (v1.1)

> **Decisión nov 2026**: los niveles de chasis (1-10) y los **recuerdos** (mejoras pasivas, fijas por nivel) están en el PMV: ver PMV.md §6 y BALANCE.md §6. Esta sección cubre lo que llega en v1.1: las **habilidades activas**, que vienen de las piezas, y el **sorteo de recuerdos**. Aplica igual a single-player y a co-op. Razonamiento en `docs/ideas/progresion-habilidades.md`.

### 6.1 Habilidades activas

| Aspecto | Detalle |
|---|---|
| **Origen** | Las da una **pieza equipada**, no el nivel. Equipar otra pieza cambia la habilidad |
| **Botón** | Abajo-izquierda (accesible en todo momento). Muestra la habilidad de la pieza equipada |
| **Consumo** | Todas las habilidades consumen batería extra y tienen tiempo de espera |
| **Monetización** | Las habilidades se consiguen jugando (con las piezas). Las "skills" que se venden son **solo cosméticas** (variantes visuales y sonoras de una habilidad), nunca más poder. Ver §23 |

**Por decidir**: qué pasa si dos piezas equipadas dan habilidad (por ejemplo, Core Overclockeado y Propulsores Iónicos a la vez): un botón por habilidad o elegir cuál ocupa el botón.

### 6.2 Lista de habilidades

| Habilidad | Pieza que la da | Efecto | Duración | Cooldown |
|---|---|---|---|---|
| **Overclock temporal** | Core Overclockeado (§15) | +100% velocidad, +100% daño, x3 consumo batería | 10 s fijos | 30 s desde que se apaga |
| **Impulso** | Propulsores Iónicos (§15) | Esquiva corta (~3 m, estimación) | Instantánea | ~6 s (estimación) |
| **Pulso EMP** | Unos brazos (por definir) | Aturde a los enemigos cercanos (~3 m, ~2 s, estimación) | Instantánea | Por definir |

**Detalles de Overclock** (decisión nov 2026, resuelve la contradicción entre "hasta que el jugador lo desactive" y "dura 10 s"):
- Duración fija de 10 s. Se apaga antes si la batería baja del 10% (protege de morir por el x3: la batería es la vida) o si el jugador lo cancela.
- El cooldown de 30 s empieza al apagarse, también si se apagó antes de tiempo.
- Degradación: -2 puntos/segundo a piezas equipadas mientras está activo.
- Por qué duración fija y no interruptor: en el móvil un interruptor con x3 de consumo invita a olvidarlo encendido y morir sin entender por qué.

**Versión futura (después de v1.1)**: **Nadar** (cruzar zonas de agua, atajos en el mapa). Necesita zonas con agua, que no existen.

**Descartado**: "Correr mucho" (+200% de velocidad), que solapaba con correr y con los Propulsores Iónicos; lo sustituye el Impulso.

Los valores pasan a BALANCE.md cuando la feature entre en desarrollo.

### 6.3 Recuerdos en v1.1: aleatorios o condicionales

En el PMV cada nivel enseña siempre el mismo recuerdo (PMV.md §6.3). En v1.1 el sistema gana variedad con una de estas dinámicas (por decidir):

| Dinámica | Cómo funciona | Pro | Contra |
|---|---|---|---|
| **Aleatoria con semilla** | Al subir, se ofrecen 3 recuerdos sorteados con semilla del mundo + jugador + nivel; se elige 1 | Cada mundo da combinaciones distintas y recargar no cambia la oferta; encaja con los mundos por semilla (§26) | Una mala oferta frustra, y ninguna opción debe ser claramente mejor que las demás |
| **Condicional** | El sorteo se inclina hacia lo que hace el jugador (más combate, más recuerdos de combate) | La progresión se adapta a la forma de jugar | Hay que medir y guardar estadísticas, el jugador no entiende por qué le sale lo que le sale y tiende a encasillarse |

Candidatos con lógica propia (no solo un modificador): Modo ahorro, Recuperación cinética, Último aliento, Contraataque, Descarga estática, Golpe por la espalda (§30), Blindaje adaptativo, Desguace, Ojo de chatarrero, Manos rápidas, Estación optimizada, Overvolt. Lista y efectos en `docs/ideas/progresion-habilidades.md` §5.2.

### 6.4 Filosofía de diseño

- Cada nivel = nueva capacidad o mejora (no solo números más grandes)
- Habilidades consumen batería (balance para evitar spam)
- Progresión satisfactoria y visible
- Funciona igual en single-player y co-op

**Estado**: niveles 1-10 y recuerdos fijos en el PMV; habilidades activas y sorteo de recuerdos en v1.1; Nadar en una versión futura.

---

## 7. Vehículos

| Aspecto | Detalle |
|---|---|
| **Concepto** | Vehículos para moverte por el mapa global con ventajas (velocidad, almacenamiento). |
| **Tipos (decisión nov 2026)** | **Ambos**: eléctricos (baterías portátiles, se recargan en base) y de gasolina (gasolina crafteable, ver §19). Qué vehículo usa cada propulsión está por definir. |
| **Primera versión (v1.2)** | Los vehículos **aceleran el viaje entre zonas en el mapa global** (§26). No se conducen en 3D. El consumo (batería o gasolina) depende de la distancia. |
| **Meta futura (v2.5+)** | Conducir vehículos en 3D dentro de las zonas. Requiere física de vehículo y zonas más grandes, con coste de rendimiento en móvil. |
| **Ejemplo: Moto eléctrica** | Funciona con baterías portátiles. Recargas en base. |
| **Coste de creación** | Alto: 20 chatarra + 10 cables + 8 hierro + 3 baterías portátiles. (Valores iniciales; los definitivos irán a BALANCE.md.) |
| **Ventajas** | - Velocidad x3 en mapa global (viajes más rápidos).<br>- Almacena 5 slots extra (puedes guardar items en la moto).<br>- Puede llevar pasajero (co-op: 2 jugadores en moto). |
| **Mejoras** | - Motor mejorado: velocidad x4.<br>- Batería ampliada: +10 slots almacenamiento.<br>- Blindaje: reduce daño recibido mientras la usas. |
| **Limitaciones** | - En la primera versión solo se usa en el mapa global (no en zonas de farmeo).<br>- Si te quedas sin batería (eléctrico) o sin gasolina, se para (debes empujarla o abandonarla).<br>- Puede ser robada si mueres cerca (dropped item). |
| **Otros vehículos (futuro)** | - Buggy: más rápido, menos almacenamiento.<br>- Camión: lento, mucho almacenamiento, puede llevar 4 jugadores.<br>- Hovercraft: puede cruzar agua y tierra.<br>Propulsión de cada uno por definir. |

**Estado**: v1.2 (viaje acelerado en el mapa global). Conducción en 3D: v2.5+.

---

## 8. Google Play Games (cloud save y logros)

| Aspecto | Detalle |
|---|---|
| **Función** | Conectar con Google Play Games para no perder progreso. |
| **Cloud save** | Sincronizar partida guardada con cuenta de Google. Si cambias de dispositivo, continúas donde lo dejaste. |
| **Logros** | Desbloquear logros (primer zombie matado, nivel 10, 1000 chatarra recolectada, etc.). |
| **Leaderboards** | Rankings globales (XP total, zombies matados, tiempo de supervivencia). |
| **Implementación** | Plugin de Godot para Google Play Games. Requiere cuenta de desarrollador ($25). |
| **iOS** | Game Center (equivalente de Apple). |

**Estado**: Post-PMV. Requiere cuenta de desarrollador y backend (Firebase).

---

## 9. Creación de narrativa con herramientas de IA

| Aspecto | Detalle |
|---|---|
| **Concepto** | Usar herramientas de IA como **herramientas de producción** para crear assets narrativos **estáticos** una sola vez, ahorrando costes de ilustradores/escritores freelancers. |
| **Aplicación** | - Cómic introductorio (generado con Midjourney/DALL-E, coste único ~$20-50).<br>- Lore del mundo (generado con ChatGPT/Claude, coste único ~$5-10).<br>- Flavor text de zonas (generado con IA, coste único ~$5-10).<br>- Diálogos de NPCs futuros (generados con IA, coste único ~$10-20). |
| **Tecnología** | - Imágenes: Midjourney, DALL-E, Stable Diffusion (herramientas, no APIs).<br>- Texto: ChatGPT, Claude (herramientas, no APIs).<br>- Vídeo: Runway ML, Pika Labs (herramientas, no APIs). |
| **Coste** | **Coste único**: $40-90 (una sola vez) vs $50-200/mes (APIs). |
| **Diferencia con APIs** | NO se genera contenido procedural para cada jugador. Se crean assets estáticos una vez y se distribuyen a todos los jugadores. |

**Estado**: v1.1+. Conectar con §21 (Narrativa / Lore) para el contenido.

---

## 10. Cabeza mejorable (visión)

| Aspecto | Detalle |
|---|---|
| **Concepto** | Pieza de "cabeza" que mejora la visión del robot (rango de detección, minimapa, etc.). |
| **Ranura** | 4ª ranura de pieza (además de brazos, piernas, core). |
| **Piezas disponibles** | |
| — Cabeza básica | Visión normal. Sin bonus. |
| — Cabeza con sensor | +20% rango de detección de enemigos (los ves antes en minimapa). |
| — Cabeza con zoom | Minimapa muestra +50% área. |
| — Cabeza con visión nocturna | En zona roja, ves enemigos ocultos (zombies camuflados). |
| — Cabeza con radar | Muestra ubicación de cajas raras en minimapa. |
| **Coste** | Requiere materiales avanzados + plano (drop de robots hostiles eléctricos o jefe). |
| **Degradación** | Igual que otras piezas (se rompe con golpes). |

**Estado**: Idea. Post-PMV. Requiere rediseñar sistema de ranuras.

---

## 11. Página web (política, términos, FAQ)

| Aspecto | Detalle |
|---|---|
| **Función** | Página web con documentación legal, historia del juego y guía de mecánicas. |
| **Contenido** | - Política de privacidad.<br>- Términos de servicio.<br>- Proceso de borrado de cuenta.<br>- FAQ (preguntas frecuentes).<br>- Contacto / soporte.<br>- **Historia / Lore del juego** (mundo, personajes, contexto post-apocalíptico).<br>- **Guía / Manual del juego** (cómo moverte, golpear, craftear, y todas las mecánicas). |
| **Tecnología** | - Frontend: React (SPA).<br>- Backend: Firebase Hosting (gratis hasta 10GB/mes).<br>- Base de datos: Firestore (para FAQ dinámica). |
| **Dominio** | Por ahora: subdominio de Firebase (`scrap-circuit.web.app`). Evita coste de dominio. |
| **Idiomas** | Español + Inglés (i18n desde el inicio). |
| **GDPR** | Obligatorio para Play Store. Incluir: qué datos recopilas, cómo borrar cuenta, cómo contactar. |

**Estado**: Necesario antes de publicar en Play Store. Prioridad media.

---

## 12. Analíticas y monetización

> **Especificación completa movida a TOOLING.md.** Allí se detallan los programas/tecnologías con pros, contras, coste y fase de implementación recomendada. El modelo de negocio está en §23.

- **Analíticas**: Firebase Analytics (principal), GameAnalytics (alternativa).
- **Reporte de errores**: Firebase Crashlytics (automático), Sentry (alternativa).
- **Monetización**: facturación nativa de cada tienda detrás de una clase base; RevenueCat opcional. **Sin anuncios** (AdMob descartado).
- **A/B testing**: Firebase Remote Config.

**Estado**: v1.5+. Ver **TOOLING.md** para decisión y fases.

---

## 13. Eventos y contenido temporal

| Aspecto | Detalle |
|---|---|
| **Filosofía** | Eventos accesibles, no frustrantes. El jugador debe poder participar sin sentir que "se queda fuera" si no juega 24/7. |
| **Tipos de eventos** | |
| — Oleadas especiales | Zombies/robots modificados (más HP, drops raros). Duración: 3 días. |
| — Jefes mundiales | Jefe con HP masivo (10,000+). Todos los jugadores cooperan. Recompensa exclusiva. |
| — Misiones diarias | 3 misiones diarias (matar X zombies, recolectar Y materiales). Recompensa: créditos, materiales raros. |
| — Temporadas | Cada 3 meses: nueva zona, nuevas piezas, nueva historia. Progresión de temporada (pase opcional). |
| **Accesibilidad** | - Eventos duran mínimo 3 días (no 24h).<br>- Recompensas escaladas: puedes participar aunque no completes todo.<br>- No hay "FOMO" (fear of missing out). Si te pierdes un evento, vuelve en 2-3 meses. |
| **Monetización** | - Solo cosméticos opcionales (ver §23). Sin pase de temporada (decisión nov 2026: sin FOMO, §25).<br>- Sin aceleradores de progresión ni items de poder a la venta (descartado en nov 2026). |

**Estado**: Post-PMV (v1.5+).

---

## 14. Sistema de invitaciones (refer rewards)

| Aspecto | Detalle |
|---|---|
| **Concepto** | Si invitas a un amigo y se registra, ambos obtienen recompensas valiosas/únicas. |
| **Mecánica** | - Jugador genera código de invitación único (o link).<br>- Amigo descarga juego e introduce código en primeros 7 días.<br>- Ambos reciben recompensa automática. |
| **Recompensas (ambos jugadores)** | **Solo cosméticas** (decisión nov 2026): sin plano exclusivo ni ventajas de juego.<br>- **Skin exclusiva**: aspecto visual para tu robot (solo obtenible por invitación).<br>- **Mascota NPC exclusiva**: companion con aspecto único (no más fuerte que otros, solo visual).<br>- *(Los "créditos premium" se eliminan: no hay moneda premium en el modelo actual, ver §23.)* |
| **Límites** | - Máximo 10 invitaciones recompensadas por jugador (evita abuso).<br>- Amigo debe jugar mínimo 3 días para validar (evita fake accounts).<br>- Recompensa única por amigo (no acumulable si reinstala). |
| **Prevención de abuso** | - Verificar dispositivo único (device ID).<br>- Amigo debe alcanzar nivel 2 antes de validar invitación.<br>- Cooldown: 1 invitación cada 24h. |
| **Integración** | - Google Play Games: usar su sistema de invitaciones (si está implementado).<br>- Link directo: generar link profundo (deep link) que abre Play Store con código. |
| **Marketing** | - Notificación push: "Tu amigo X te ha invitado. Descarga y obtén recompensas."<br>- Share social: botón para compartir código por WhatsApp, Telegram, etc. |
| **Coste** | €0 (solo tiempo de desarrollo: 1-2 semanas). |

**Estado**: Post-PMV (v1.3+, antes v1.2). Requiere backend (Firebase) y Google Play Games.

---

## 15. Piezas avanzadas (v1.1)

> **Nota**: estas piezas estaban en el PMV original pero se movieron a v1.1 para simplificar el alcance.
>
> **Decisión nov 2026**: v1.1 trae las **5 piezas avanzadas** de abajo, más el Core Estándar.

### 15.1 Piezas avanzadas

| Pieza | Ranura | Ventaja | Desventaja |
|---|---|---|---|
| Brazos de Minería | Brazo | Rompe cajas 2x rápido | Ataque a zombies muy lento |
| Cuchillas de Plasma | Brazo | Mata zombie de 1 golpe | Cada golpe = 5% batería |
| Orugas de Tanque | Piernas | Inmune a ralentización zombie | -30% velocidad |
| Propulsores Iónicos | Piernas | 2x velocidad de movimiento; da la habilidad Impulso (§6.2) | -20% batería pasiva |
| Core Estándar | Core | Batería base equilibrada | Sin habilidades especiales |
| Core Overclockeado | Core | +capacidad batería; da la habilidad Overclock (§6.2) | Degradación más rápida |

### 15.2 Estadísticas detalladas

#### Brazos

| Pieza | Daño ataque | Velocidad ataque | Consumo batería/golpe | Efecto especial |
|---|---|---|---|---|
| **Brazos de Minería** | 5 | 0.8 golpe/s | 1 | Rompe cajas x2 rápido |
| **Cuchillas de Plasma** | 25 (1-shot zombie) | 1.2 golpe/s | 5 | Mata zombie básico de 1 golpe |

#### Piernas

| Pieza | Velocidad movimiento | Consumo al andar | Efecto especial |
|---|---|---|---|
| **Orugas de Tanque** | 2.1 m/s (-30%) | +0.08/s | Inmune a ralentización zombie |
| **Propulsores Iónicos** | 6.0 m/s (x2) | +0.15/s (+0.1 extra) | Velocidad doble, drena más |

#### Core

| Pieza | Batería máxima | Efecto especial |
|---|---|---|
| **Core Estándar** | 100 | Equilibrado |
| **Core Overclockeado** | 120 (+20%) | Overclock: +100% velocidad, +100% daño, x3 consumo batería |

> **Nota**: El Core Overclockeado **da** la habilidad Overclock (ver §6.2): sin él no hay Overclock (decisión nov 2026, las habilidades activas vienen de las piezas).

### 15.3 Materiales para crear piezas avanzadas

| Pieza | Chatarra | Cables | Hierro | Total | Notas |
|---|---|---|---|---|---|
| **Brazos de Minería** | 6 | 3 | 2 | 11 | Requiere plano (drop de robot) |
| **Cuchillas de Plasma** | 8 | 4 | 3 | 15 | Requiere plano (drop de robot eléctrico) |
| **Orugas de Tanque** | 7 | 2 | 4 | 13 | Requiere plano (drop de robot) |
| **Propulsores Iónicos** | 8 | 5 | 2 | 15 | Requiere plano (drop de robot eléctrico) |
| **Core Overclockeado** | 10 | 5 | 4 | 19 | Requiere plano (drop de jefe, post-PMV) |

### 15.4 Sistema de planos (drops de robots hostiles)

| Plano | Drop de | Probabilidad | Notas |
|---|---|---|---|
| **Plano: Brazos de Minería** | Robot hostil básico | 15% | Permite crear la pieza |
| **Plano: Orugas de Tanque** | Robot hostil básico | 15% | Permite crear la pieza |
| **Plano: Cuchillas de Plasma** | Robot hostil eléctrico | 20% | Permite crear la pieza |
| **Plano: Propulsores Iónicos** | Robot hostil eléctrico | 20% | Permite crear la pieza |
| **Plano: Core Overclockeado** | Jefe (post-PMV) | 5% | Pieza legendaria |

**Notas**:
- Los planos son items que ocupan 1 slot de inventario.
- No se consumen al usarse (se aprenden permanentemente).
- Si ya tienes el plano, el robot hostil suelta materiales extra en su lugar (+3 chatarra, +2 cables).

**Estado**: v1.1. Mover del PMV original a expansión.

---

## 16. Zona Roja (v1.1)

| Parámetro | Valor |
|---|---|
| **Tamaño** | Mediano (80x80m) |
| **Zombies** | 10-15 (todos los tipos, incluyendo ácidos) |
| **Robots hostiles** | 2-4 (básicos y eléctricos) |
| **Cajas** | 8-10 (avanzadas, con baterías) |
| **Materiales principales** | Chatarra, cables, hierro, baterías |
| **Riesgo** | Alto. Jugador necesita piezas decentes para sobrevivir. |

**Nota**: con el mundo por semilla (§26), "zona roja" pasa a ser un tipo de zona (parámetros de generación y tablas de spawn), no una escena única.

**Estado**: v1.1.

---

## 17. Nuevos enemigos (v1.1)

### 17.1 Zombies adicionales (2 tipos)

| Tipo | HP | Daño | Velocidad | Habilidad especial | XP |
|---|---|---|---|---|---|
| **Eléctrico** | 25 | 3 | 2.0 m/s | Drena 5 batería extra al golpear | 5 |
| **Ácido** | 30 | 6 | 1.8 m/s | Degrada piezas x2 más rápido (-10 puntos por golpe) | 5 |

### 17.2 Robot hostil eléctrico

| Tipo | HP | Daño | Velocidad | Habilidad especial | XP | Piezas que suelta |
|---|---|---|---|---|---|---|
| **Eléctrico** | 40 | 6 | 2.5 m/s | Drena 10 batería extra al golpear | 15 | Pieza dañada (50% durabilidad) |

**Estado**: v1.1.

---

## 18. Banco de armas (v1.1)

| Arma | Coste | Daño | Velocidad ataque | Consumo batería |
|---|---|---|---|---|
| **Tubería** | 3 chatarra | 10 | 1.0 golpe/s | 1/golpe |
| **Porra eléctrica** | 5 chatarra + 2 cables | 15 | 1.2 golpe/s | 2/golpe |
| **Martillo de hierro** | 8 chatarra + 3 hierro | 20 | 0.8 golpe/s | 3/golpe |

**Estado**: v1.1.

---

## 19. Gasolina: complemento de movilidad (v1.2)

> **Decisión nov 2026**: la gasolina **deja de ser un limitador de viajes con temporizador** al estilo LDOE. Pasa a ser un recurso del mundo que ayuda a moverse y a mover vehículos.

| Aspecto | Detalle |
|---|---|
| **Rol** | **Batería = vida. Gasolina = movilidad.** Son recursos separados. |
| **Tipo** | Item del inventario (con stack máximo en BALANCE.md cuando se defina). No regenera con el tiempo. |
| **Obtención** | **Crafteable.** Materia prima y banco (p. ej. una refinería) por definir. Es una de las anclas del árbol de crafteo (§29). ¿También aparece como loot? Por definir. |
| **Venta** | **No se vende** en el lanzamiento (decisión nov 2026: en un juego de pago, vender un consumible se percibe como pagar dos veces). El catálogo como dato (§23) permite reconsiderarlo más adelante con datos. |
| **Usos** | Vehículos de gasolina (§7) y movimiento asistido (p. ej. piernas propulsoras). Qué piezas la usan está por definir. |
| **Regla** | El movimiento base nunca requiere gasolina: quedarse sin ella no deja al jugador atrapado sin poder volver a pie. |
| **Coste por distancia** | En el mapa global (§26), el consumo de un vehículo depende de la distancia entre zonas. La fórmula irá a BALANCE.md. |

**Eliminado del diseño anterior** (versión con temporizador): regeneración pasiva (1 punto cada 3 min), tabla fija de costes por ruta, verificación de hora real (NTP, `NTPClient.gd`), gasolina por anuncios rewarded y gasolina por IAP. Ya no hace falta NTP: ningún sistema depende de la hora real.

**Estado**: v1.2.

---

## 20. Tutorial completo (v1.1)

| Paso | Descripción |
|---|---|
| **Paso 1** | "Muévete con el joystick" (highlight joystick) |
| **Paso 2** | "Abre esta caja" (highlight caja + botón interactuar) |
| **Paso 3** | "Ataca al zombie" (highlight botón atacar) |
| **Paso 4** | "Vuelve a la base" (highlight botón mapa) |
| **Paso 5** | "Construye un banco de armas" (highlight banco) |
| **Paso 6** | "Crea un arma" (highlight banco de armas) |

**Implementación**:
- Sistema de quests guiadas (TutorialManager)
- Highlights: overlay oscuro con zona iluminada
- Flechas: apuntan a elemento interactivo
- Texto: explicación de cada paso
- Recompensa: al completar tutorial, dar 5 chatarra + 2 cables

**Estado**: v1.1.

---

## 21. Narrativa / Lore

### 21.1 Lore principal (reescrito en nov 2026)

**Contexto**: un experimento para trasladar la consciencia humana a máquinas, con el fin de ganar poder, salió mal. El mundo quedó dividido entre facciones (estilo StarCraft, ver §28).

- **El experimento**: un programa de transferencia de consciencia humana a máquinas. Nombre del programa y responsables por definir.
- **IA rebelde**: nació del mismo programa. Tecnología superavanzada y poderes telepáticos. Se rebeló contra sus creadores.
- **Infectados**: humanos zombificados con **mente de colmena**. No son zombies tontos: son inteligentes y se coordinan. Origen de la infección por definir (puede reutilizarse el virus bio-tech del lore anterior).
- **Humanos**: supervivientes. Según el grupo, pueden ser hostiles o amistosos.
- **El jugador**: un robot con consciencia, fruto fallido del experimento de transferencia. Es la única clase jugable; en multijugador cada jugador es uno de estos robots.
- **Conexión con las mecánicas**: la pantalla de "Transferencia de Consciencia" al morir (PMV.md §2.4) es parte del lore. En modo Normal la consciencia vuelve a la base. En modo Hardcore la transferencia falla, salvo que el jugador tenga un Respaldo de consciencia (§27).

> **Lore anterior (sustituido)**: corporación bio-tech crea un virus que muta; robots/IA concluyen que la humanidad es el problema; humanos en bunkers; el jugador era un robot de asistencia reprogramado por un superviviente.

### 21.2 Elementos narrativos

| Elemento | Descripción | Implementación |
|---|---|---|
| **Escenas introductorias** | Cómic de 4-6 paneles que cuenta el origen del mundo. | Generado con IA (ver §9). Estático, no animado. |
| **Flavor text en zonas** | Descripciones ambientales al entrar en zonas ("Aquí cayó el primer robot", "Los humanos huían por aquí"). | Textos cortos (1-2 líneas) en HUD al entrar en zona. |
| **Diálogos de NPCs** | Si se añaden NPCs en futuro (comerciantes, sobrevivientes). | Textos generados con IA (ver §9). |
| **Historia del jugador** | Progresión narrada: "Tu robot ha alcanzado nivel 5", "Has sobrevivido 30 días". | Notificaciones de logros con contexto narrativo. |
| **Páginas de cómic desbloqueables** | Al alcanzar hitos, desbloqueas páginas de cómic que cuentan más del lore. | Imágenes generadas con IA (ver §9). Galería coleccionable. |

### 21.3 Método de producción

> **Referencia**: Ver §9 para detalles sobre cómo usar herramientas de IA para crear estos assets narrativos con coste único ($40-90).

**Estado**: v1.1+.

---

## 22. Costes ocultos y realistas

### 22.1 Costes ocultos que casi nadie calcula

| Coste oculto | Estimación | Por qué importa |
|---|---|---|
| **Marketing / UA** | $3,000 - $15,000+ | El 80% de juegos indie fracasan por falta de visibilidad, no por calidad. CPI Android 2026: $1.50-$2.50. Necesitas al menos $3K para un push inicial decente. |
| **Comisión tiendas** | ~10-15% para desarrolladores pequeños (antes 30%) | Datos de nov 2026 en §23.2: Google ~10% (estructura nueva, según región) o 15%; Apple 15% con el Small Business Program (inscripción anual). Verificar en las páginas oficiales. |
| **Impuestos** | 15-30% según país | Ingresos de apps tributan. Consulta fiscalista. |
| **Post-launch (año 1)** | 15-25% del coste de desarrollo | Bug fixes, updates de compatibilidad con nuevas versiones de Android/iOS, respuesta a reviews. |
| **Política de privacidad / Legal** | $200 - $1,000 | Obligatorio para Play Store y App Store. GDPR si hay usuarios EU. |
| **Seguros / autónomo** | Variable | Si te das de alta como autónomo para facturar ingresos. |
| **Actualizaciones de Godot** | 20-40h cada major update | Cada versión nueva de Godot puede romper compatibilidad. Hay que testear y adaptar. |
| **Respuesta a rechazos de store** | 1-2 semanas por rechazo | Apple rechaza ~30% de primeros envíos. Cada ciclo de revisión = 1-2 semanas. |
| **Analytics / Crash reporting** | $0 - $200/mes | Firebase (gratis hasta cierto punto), Sentry, GameAnalytics. |
| **Soporte al jugador** | 5-10h/semana post-launch | Emails, reviews negativas, bugs reportados. |

### 22.2 Coste total realista a 1 año

| Concepto | Rango |
|---|---|
| Desarrollo (4 meses PMV) | $20,400 - $68,000 (valorando tu tiempo) |
| Gastos directos | $500 - $1,500 |
| Marketing inicial | $3,000 - $10,000 |
| Post-launch año 1 | $4,000 - $15,000 |
| Legal / admin | $500 - $2,000 |
| **TOTAL 1 año** | **$28,400 - $96,500** |

**Estado**: Referencia para planificación.

---

## 23. Monetización (modelo completo)

### 23.1 Modelo decidido (nov 2026): demo gratis + desbloqueo único, en capas

Sustituye al modelo anterior (F2P + anuncios + IAP). Referencia: Minecraft móvil (juego de pago, local y red local gratis, servidores con suscripción aparte, cosméticos opcionales), pero con **demo gratis** en vez de pago directo, porque en móvil casi todas las descargas son de juegos gratuitos (§23.2).

| Capa | Qué incluye | Cuándo |
|---|---|---|
| **Demo gratis** | Modo Normal limitado **por contenido** (no por tiempo): un mundo, primera zona, chasis hasta cierto nivel. Propuesta: la demo es el contenido del PMV. Corte exacto por cerrar. | Desde el lanzamiento del PMV |
| **Desbloqueo único** | Juego completo: todas las zonas y mundos, modo Hardcore, cooperativo en red local (4-6, cuando llegue) y actualizaciones de contenido v1.x incluidas. | v1.1 |
| **Cosméticos** | Opcionales: skins, skills cosméticas (§6.1), decoración. Mismo `CosmeticData` con tres vías de obtención: compra, salón de la fama (§27) o logros. | v1.3 (los del salón de la fama, desde v1.1) |
| **Suscripción online** | Solo funciones con coste de servidor (juego por internet, nube, funciones asíncronas). Nunca bloquea el juego base. | Solo cuando exista una función con coste recurrente (ONLINE.md) |

**Reglas del modelo**:
- **Sin anuncios.**
- **Sin pay-to-win**: no se vende poder. Las skills de pago son solo cosméticas. La gasolina no se vende en el lanzamiento (§19). El Respaldo de consciencia nunca se vende: se craftea (§27).
- **El local es gratis tras pagar**: un solo jugador y cooperativo en red local, sin cuota.
- **Nunca se quita lo que ya era gratis**: el contenido publicado gratis en el PMV sigue siendo la demo.
- **Por qué prueba por contenido y no por tiempo**: un límite de tiempo en un juego local se burla cambiando la hora o reinstalando, y obligaría a volver a la verificación NTP.
- **Los mundos creados en la demo se conservan** al comprar el desbloqueo.

**Arquitectura que lo permite sin atarnos las manos** (detalle en PMV.md §4.5):
- **Catálogo como dato**: cada producto es un SKU que otorga un derecho (`entitlement`). El juego comprueba derechos, no productos. Permite cambiar de modelo (pago directo, paquetes, otro precio) sin tocar código.
- **Tienda detrás de una clase base** (`IStore` con implementación local en el PMV y nativa en v1.1). RevenueCat es opcional, no una dependencia.
- **Derechos en el Perfil** (guardado global, no por mundo). Cuenta opcional: UUID anónimo hasta que haya online; hasta entonces, lo no consumible se restaura con la tienda.
- **Multiplataforma**: sin cuenta, el desbloqueo es por tienda (Android e iOS se compran por separado). Unificarlo requiere cuentas y servidor.

### 23.2 Datos de mercado (consultados en nov 2026)

Fuentes mayormente de terceros; verificar en las páginas oficiales antes de decidir precios.

| Dato | Valor | Fuente |
|---|---|---|
| Descargas de juegos móviles gratuitas (2025) | 96% en total, 99% en Google Play | Sensor Tower, State of Gaming 2026 |
| Lanzamientos premium en móvil (2025) | +77% interanual (~750 títulos) | AppMagic vía gamedev.net |
| Conversión de demos con desbloqueo único (indie) | 0,5-4% según casos | Casos indie antiguos; solo orientativo |
| Comisión Google Play | ~10% sobre el primer millón anual en la estructura nueva (más tarifa de facturación donde aplique), 15% en regiones sin migrar | Ayuda de Google Play; varía por región |
| Comisión Apple | 15% con el Small Business Program (ingresos < 1 M$/año, inscripción anual) | Apple vía terceros |
| RevenueCat | Gratis hasta 2.500 $ de ingresos mensuales rastreados; 1% después | Terceros |
| Precio de referencia | Minecraft móvil ~6,99 $; Realms ~3,99 $/mes | Guías de terceros |

### 23.3 Pendiente

- Corte exacto de la demo.
- Precio del desbloqueo (estimación sin datos propios: 3,99-4,99 €). Se decide cerca del lanzamiento de v1.1.
- ~~Jugador con la demo en el cooperativo de otro que ha pagado~~: decidido nov 2026, puede unirse con un límite de 1 hora por día (ONLINE.md Fase 2A).
- ~~Pase de temporada cosmético~~: decidido nov 2026, no (sin FOMO, §25).

### 23.4 Descartado

Anuncios (rewarded incluidos), moneda premium ("créditos premium"), aceleradores de progresión, venta de gasolina (por ahora), venta del Respaldo de consciencia.

**Estado**: el PMV se publica como demo gratis **sin compras**. Desbloqueo en v1.1. Tienda de cosméticos en v1.3. Suscripción online solo cuando haya coste de servidor.

---

## 24. Fuentes y referencias

- Godot 4.7.2 stable (agosto 2026) — godotengine.org
- Godot Mobile Update abril 2026 — godotengine.org
- Google Play Developer: $25, 14-day testing requirement — developer.android.com
- Apple Developer Program: $99/year — developer.apple.com
- Costes indie 2026: juegostudio.com, vsquad.art, galaxy4games.com, innovecsgames.com
- Godot Android performance issues: github.com/godotengine/godot #100576, #109251
- Last Day on Earth (referencia visual y de mecánicas) — play.google.com
- Minecraft móvil (referencia del modelo de negocio en capas: juego de pago, Realms, Marketplace) — precios vía guías de terceros (thepricer.org, windowscentral.com), nov 2026
- Datos de mercado para §23.2 (consultados en nov 2026, verificar en fuentes oficiales):
  - Sensor Tower, State of Gaming 2026 — descargas gratuitas 96% (99% en Google Play)
  - gamedev.net (datos de AppMagic) — lanzamientos premium móviles +77% en 2025
  - Comisiones de Google Play — support.google.com/googleplay/android-developer/answer/112622
  - Apple App Store Small Business Program — developer.apple.com/app-store/small-business-program/
  - RevenueCat (precios vía terceros) — revenuecat.com/pricing
  - Supabase (límites del plan gratuito vía terceros) — supabase.com/pricing
  - Conversión de demos con desbloqueo único: casos indie en pocketgamer.biz y gamedeveloper.com (antiguos, orientativos)

**Estado**: Referencia.

---

## 25. Visión a largo plazo

**Objetivo**: juego divertido, que enganche, con progresión satisfactoria.

**Principios**:
- ✅ Coop opcional pero valioso
- ✅ Eventos accesibles, no frustrantes
- ✅ Progresión clara (cada nivel = nueva capacidad, no solo números más grandes)
- ✅ Monetización justa (sin pay-to-win, sin anuncios)
- ✅ El jugador siempre puede recuperar progreso tras morir (modo Normal; el Hardcore es opcional)
- ✅ Contenido temporal que no genere FOMO

**Roadmap**: la fuente de verdad es **PMV.md §9** (actualizado en nov 2026). Resumen:
- **PMV (v1.0)**: core loop, 1 zona, piezas básicas, guardado local con ganchos de arquitectura. Se publica como demo gratis.
- **v1.1**: mundos por semilla, zona roja, modo Hardcore + salón de la fama + Respaldo de consciencia, desbloqueo de pago, y el contenido ya previsto (2 zombies, 1 robot, piezas avanzadas, bancos avanzados, banco de armas, overclock, tutorial completo, cofres 20), sigilo y agachado (§30), salto contextual (§31) y base libre en el mundo con muros (§32).
- **v1.2**: gasolina crafteable, vehículos (viaje en mapa global), árbol de crafteo ampliado, facciones (humanos, colmena inteligente, IA telepática).
- **v1.3**: eventos temporales, misiones diarias, invitaciones, Google Play Games, tienda de cosméticos.
- **v1.5**: online asíncrono (Fase 1 ONLINE) y suscripción online si hay coste de servidor.
- **v2.0**: cooperativo en red local 4-6 (gratis tras el desbloqueo); co-op por internet si escala (Fase 2 ONLINE).
- **v2.5**: vehículos en 3D, nanorobots, cabeza mejorable.
- **v3.0**: PvP masivo (Fase 3 ONLINE, si el juego factura >€5000/mes).

---

## 26. Mundo por semilla (v1.1)

> **Decisión nov 2026**: cada partida es un mundo con semilla aleatoria, organizado como un mapa de zonas. No es un mundo continuo tipo Minecraft.

| Aspecto | Detalle |
|---|---|
| **Partida = mundo** | Cada slot de guardado es un mundo con nombre, semilla y ruleset (Normal o Hardcore, §27). El jugador puede crear varios mundos. |
| **Mapa global** | Cuadrícula o grafo de celdas, generado a partir de la semilla. Es una pantalla de mapa (nodos), no un 3D caminable. |
| **Zona** | Cada celda es una zona acotada (50-80 m, como las de BALANCE.md §7) generada de forma determinista con `semilla + coordenada de zona`. Se guarda solo lo que el jugador cambió (cajas abiertas, enemigos muertos, estructuras). |
| **Carga** | Una zona cargada a la vez. |
| **Viaje entre zonas** | Por el mapa global. A pie: cuesta batería según la distancia (decisión nov 2026; valor en BALANCE.md §1.2). En vehículo (§7): más rápido, consume batería o gasolina según la distancia. La base es una zona especial. |
| **Facciones** | Al crear el mundo se reparten territorios: zonas de colmena, de máquinas y asentamientos humanos (§28). La misma zona cambia de contenido según sus tablas de spawn. |
| **Rejugabilidad** | Nueva semilla = nuevo mundo. Da sentido al modo Hardcore. |
| **Semillas compartidas** | Una semilla se puede compartir con un código o QR. Reto diario o semanal en Hardcore con la misma semilla para todos (ranking en v1.5+, ver ONLINE.md). |

**Por qué no un mundo continuo**: cargar chunks y generar el navmesh de forma dinámica en GDScript, con un presupuesto de 50-100K triángulos, es un riesgo serio en Android de gama media (estimación). Un mundo de zonas aprovecha lo que SPECS ya describía (mapa global con distancias, vehículos en el mapa) y solo añade la semilla.

**Compatibilidad futura**: las zonas se alinean a una cuadrícula y las entidades se guardan como `(zone_id, posición local)`. Así, en el futuro se podrían cargar zonas vecinas sin costuras sin reescribir el guardado.

**Riesgo**: generar el navmesh de una zona en tiempo de ejecución en Android de gama media. Coste desconocido; lo mide el spike de ACTION_PLAN.md Tarea 0.5 antes de comprometer la generación procedural.

**PMV**: una sola zona (zona verde) y un solo mundo. La colocación de cajas y spawns ya usa el RNG con semilla (ver ganchos en PMV.md §4.5).

**Estado**: v1.1.

---

## 27. Modos de juego: Normal y Hardcore (v1.1)

| Aspecto | Normal | Hardcore |
|---|---|---|
| **Papel** | Modo principal. | **Opcional.** Nunca sustituye al Normal. |
| **Jugadores** | Un jugador; cooperativo en red local en v2.0. | **Solo individual.** |
| **Online** | Según ONLINE.md. | **Sin online** por ahora. |
| **Muerte** | No permanente (PMV.md §2.4): reapareces en la base, conservas Core y XP, tus items quedan en el lugar de la muerte. | **El mundo se pierde**, salvo que tengas un Respaldo de consciencia. |
| **Guardado de respaldo** | Copia contra corrupción. | Copia **solo** contra corrupción, nunca para deshacer una muerte. |

**Respaldo de consciencia** (segunda oportunidad):
- Objeto **crafteable** (nunca se vende). Al morir en Hardcore se consume y reapareces en la base con las mismas pérdidas que en el modo Normal; el mundo sigue vivo.
- Por definir: receta y banco (candidato: Ensamblador avanzado, §3), si debe estar equipado, en el inventario o en la base, y si su uso tiene una penalización extra.
- Es una de las anclas del árbol de crafteo (§29).

**Salón de la fama**:
- Cuando un mundo Hardcore muere, se escribe una entrada en el **Perfil** (guardado global que sobrevive a los mundos). Campos por definir (p. ej. días sobrevividos, nivel, enemigos eliminados, semilla).
- Recompensas: **cosméticos o planos** para el Perfil. Por definir cómo se aplican los planos a mundos nuevos.
- Es local y, sin servidor, no es verificable. Si se publica en un ranking global, debe marcarse como "no verificado" o validarse en servidor (ONLINE.md).

**Riesgos aceptados**: cerrar la app antes de morir permite esquivar la muerte (juego local de un jugador). Perder un mundo tras semanas puede hacer que algunos jugadores abandonen; el salón de la fama compensa en parte.

**Compras**: no afectan al Hardcore, porque no se venden consumibles (§23).

**Estado**: v1.1. El ruleset como dato ya existe en el PMV (solo `NORMAL`).

---

## 28. Facciones (v1.2)

Inspiración: StarCraft (tres razas). Las facciones son enemigos o NPC; el jugador es la única clase jugable.

| Facción | Descripción | Mecánicas propuestas |
|---|---|---|
| **IA rebelde** | Nacida del experimento de transferencia de consciencia. Tecnología superavanzada, poderes telepáticos. | Ataques telepáticos a distancia que afectan a la batería o a la interfaz (HUD), no solo daño directo. Encaja con el robot y el zombie eléctricos de v1.1. Los robots hostiles del PMV pertenecen a esta facción. |
| **Infectados (colmena)** | Humanos zombificados con mente de colmena. Inteligentes, no el zombie tonto típico. | IA de grupo ligera: aviso de aggro compartido, flanqueo, retirada táctica. Una capa de grupo encima de la máquina de estados, no IA compleja por unidad (barata para 20-30 enemigos en móvil, estimación). Los zombies del PMV pertenecen a esta facción. |
| **Humanos** | Supervivientes. | Pueden ser **hostiles o amistosos**: comercio y misiones, o saqueadores. Mecanismo por definir: reputación por asentamiento o relación fijada por la semilla. |
| **Robot consciente (jugador)** | Fruto fallido del experimento. | Única clase jugable. En multijugador, cada jugador es uno. |

**Datos**: campo `faction` en `EnemyData` y tabla de relaciones (hostil, neutral, amistosa) guardada en el mundo. Ambos existen desde el PMV como dato (ver PMV.md §4.5).

**Coste**: el arte puede salir de packs gratuitos (Kenney, Quaternius); lo caro es el código de comportamiento y la variedad de enemigos.

**Estado**: dato en el PMV; contenido en v1.2.

---

## 29. Crafteo por niveles (v1.2)

Objetos cada vez más complejos, con tres vías de crafteo:

| Vía | Dónde | Para qué |
|---|---|---|
| **Uno mismo** | En cualquier lugar, también fuera de la base | Recetas simples. Más lento o con coste de batería (por definir). |
| **Nanobots** | Fuera de la base | Estructuras y recetas intermedias (§1). |
| **Mesa de trabajo** | En la base | Recetas complejas: banco de reparaciones (PMV) y bancos avanzados (§3). |

**Árbol de crafteo**: todavía no diseñado. Método acordado: **diseñarlo hacia atrás desde tres anclas**:
1. Respaldo de consciencia (endgame, §27).
2. Gasolina (necesita materia prima y un banco que la refine, §19).
3. Primer vehículo (§7).

Cada ancla dicta qué materiales intermedios y bancos hacen falta. Con solo chatarra, cables y hierro no hay árbol: harán falta materiales intermedios (p. ej. el hierro fundido del horno, §3).

**Modelo de datos**: `RecipeData` con `station` (`SELF`, `NANOBOTS`, `WORKBENCH`), `tier` y `requires` (plano o tecnología previa). Así el árbol se rellena con datos sin tocar código. El modelo existe desde el PMV (ver PMV.md §4.5), con solo `WORKBENCH` (banco de reparaciones).

**Estado**: modelo de datos en el PMV; vía "uno mismo" y árbol ampliado en v1.2; nanobots en v2.5 (por confirmar si se adelanta).

**Adelanto a v1.1 (decisión nov 2026)**: un crafteo "uno mismo" mínimo, solo para el **Banco de reparaciones**, porque la base libre (§32) necesita poder fundarse en cualquier sitio. El resto de recetas "uno mismo" sigue en v1.2. La receta del banco es un `RecipeData` con `station = SELF`: el modelo de datos del PMV ya lo admite.

---

## 30. Sigilo y agachado (v1.1)

> **Decisión nov 2026**: fuera del PMV. En la demo no hay botón de agacharse.

| Aspecto | Valor |
|---|---|
| **Velocidad agachado** | La mitad de la velocidad al andar de las piernas equipadas (1.5 m/s con piernas básicas) |
| **Consumo agachado** | La mitad del consumo al andar de las piernas (+0.025/s con piernas básicas). El consumo pasivo no cambia |
| **Radio de detección de los enemigos** | La mitad mientras el robot va agachado |
| **Por la espalda** | Agachado y dentro del cono trasero de 90° de un enemigo, la detección es nula: permite acercarse para atacar por la espalda |
| **Requisitos** | Sin piernas no se puede ir agachado. No se puede correr agachado |
| **Control** | Botón agacharse/sigilo debajo de atacar (móvil); tecla C (PC) |
| **Ataque con sigilo** | Golpear a un enemigo que no te ha detectado (agachado y por la espalda) hace **más daño**: ×2 el daño de los brazos como valor inicial, a ajustar en playtesting (decisión nov 2026) |

**Preguntas abiertas**:
- ¿Solo el primer golpe hace daño extra (el enemigo te detecta al recibirlo) o todos mientras sigas sin ser detectado? Propuesta: solo el primero.

Los valores pasan a BALANCE.md cuando la feature entre en desarrollo.

**Estado**: v1.1.

---

## 31. Salto (v1.1)

> **Decisión nov 2026**: fuera del PMV. Diseño propuesto por Claude a petición del usuario; los números son valores iniciales a ajustar en playtesting.

**Tipo: salto contextual automático**, no un salto libre con botón.

| Aspecto | Diseño |
|---|---|
| **Cómo se activa** | Al **correr** contra un obstáculo saltable o el borde de un hueco saltable, el robot salta solo. Andando no salta, para que no haya saltos sin querer. Sin botón, ni en móvil ni en PC |
| **Qué se salta** | Solo lo marcado como saltable en el diseño de la zona: obstáculos bajos (hasta 1 m: vallas, escombros, coches volcados) y huecos (hasta 2 m) |
| **Qué no se salta** | Los muros que construye el jugador (§32) y las paredes del truco de la pared (§4). Si se pudieran saltar, dejarían de proteger |
| **Coste** | 2 puntos de batería por salto (valor inicial) |
| **Requisitos** | Piernas equipadas; no agachado; batería suficiente para pagar el coste |
| **Trayectoria** | Arco fijo de unos 0.5 s guiado por animación, no por física: siempre igual y fácil de leer con la cámara isométrica |
| **Durante el salto** | Sin invulnerabilidad: un proyectil puede alcanzarte en el aire |
| **Enemigos** | Zombies y robots hostiles **no saltan**: rodean por el camino largo si existe. Saltar es una vía de escape táctica que cuesta batería. Los enemigos a distancia (robot eléctrico, §17.2) sí pueden alcanzarte al otro lado |

**Por qué este diseño y no un salto libre**:
- En vista isométrica es difícil calcular profundidad y altura: un salto libre frustra en móvil.
- La pantalla táctil ya tiene muchos botones; correr ya existe.
- Un salto libre abre trampas difíciles de cerrar: subirse a objetos donde ningún enemigo llega o saltar los muros que protegen la base.
- Los saltos marcados se controlan con el diseño de la zona y con la navegación de los enemigos.

**Técnica (verificar al implementar)**: el obstáculo saltable lleva un componente que expone su punto de despegue y de aterrizaje. Para los enemigos sigue bloqueando la navegación. Si en el futuro algún enemigo debe saltar, se le añade un enlace de navegación (`NavigationLink3D`) solo para ese tipo.

**Preguntas abiertas**:
- ¿Saltar un hueco con el robot sin piernas está prohibido o se cae dentro? Propuesta: prohibido (no se activa).

**Estado**: v1.1.

---

## 32. Base libre en el mundo (v1.1)

> **Decisión nov 2026**: en el PMV la base es una escena fija, zona segura sin muros, y el jugador coloca estaciones, cofres y generador donde quiera **dentro de sus límites**, en una cuadrícula (PMV.md §2.1). En v1.1, con los mundos por semilla (§26), **la base está donde tú quieras**.

| Aspecto | Detalle |
|---|---|
| **Fundar una base** | En cualquier sitio: crafteas a mano un Banco de reparaciones, construyes con él una Estación de carga, interactúas con ella y **pasa a ser tu punto de aparición** |
| **Banco de reparaciones** | **Crafteable a mano** en v1.1 (decisión nov 2026), **sin límite** de cantidad. En la demo sigue siendo fijo y viene incluido. Receta en BALANCE.md al diseñar v1.1 |
| **Construir** | Misma colocación en cuadrícula del PMV, alrededor de tus estructuras |
| **Muros** | Crafteables, para protegerte de los enemigos: bloquean su paso. No se pueden saltar (§31) |
| **Guardado** | Estructuras como `(zone_id, posición local)` (PMV.md §4.5 gancho 2): el formato del PMV ya sirve |

**Consecuencia de diseño**: si hacen falta muros, la base de v1.1 ya **no es una zona segura**: los enemigos pueden llegar hasta ella. Cambia respecto al PMV.

**Preguntas abiertas** (con propuesta):
- Varias estaciones en sitios distintos: ¿cuál es el punto de aparición? Propuesta: la última con la que interactuaste.
- Si destruyen o quitas la estación de aparición: propuesta, pasa a la anterior; si no queda ninguna, al punto inicial del mundo.
- ¿Los enemigos dañan muros y estaciones? Propuesta: sí, los muros tienen durabilidad y se reparan en el banco; sin eso, un muro sería una protección permanente gratis.
- Receta y durabilidad del muro: en BALANCE.md al diseñar v1.1.
- ¿Se puede fundar base en cualquier zona, también en la roja? Propuesta: sí; el riesgo de la zona roja ya es el coste.
- Los muros cambian la navegación de los enemigos en tiempo de ejecución: depende del spike de navmesh (ACTION_PLAN Tarea 0.5). Alternativa si es caro: obstáculos dinámicos de navegación (`NavigationObstacle3D`, verificar).
- §1 (nanobots, v2.5) ya hablaba de construir muros fuera de la base. Con esta decisión los muros llegan antes, en v1.1, desde el banco; los nanobots quedan para torretas, trampas y construir sin banco.

**Estado**: v1.1.

---

*Documento vivo. Revisar cada mes. Priorizar features según feedback de jugadores.*