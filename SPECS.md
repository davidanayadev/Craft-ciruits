# Especificaciones Generales — Scrap Circuit

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
- Monetización justa (sin pay-to-win)
- El jugador siempre puede recuperar progreso tras morir

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

**Estado**: Por desarrollar en detalle. Post-PMV.

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

## 6. Sistema de progresión extendido y habilidades (v1.1+)

> **Nota**: Este sistema es la extensión del sistema básico de 5 niveles del PMV. Aplica tanto a single-player como a co-op. No es exclusivo del modo online.
> **Referencia**: Para el sistema básico de 5 niveles (PMV), ver PMV.md §6 y BALANCE.md §6.

### 6.1 Habilidades desbloqueables

| Aspecto | Detalle |
|---|---|
| **Botón** | Abajo-izquierda (accesible en todo momento) |
| **Concepto** | Habilidades especiales con cooldown que se desbloquean al subir de nivel |
| **Consumo** | Todas las habilidades consumen batería extra |

### 6.2 Lista de habilidades

| Habilidad | Efecto | Duración | Cooldown | Nivel de desbloqueo |
|---|---|---|---|---|
| **Overclock temporal** | +100% velocidad, +100% daño, x3 consumo batería | Hasta que jugador desactive o batería < 10% | 30 segundos después de desactivar | Nivel 2 |
| **Correr mucho** | +200% velocidad de movimiento | 5 segundos | 30 segundos | Nivel 4 |
| **Nadar** | Permite cruzar zonas de agua (atajos en mapa) | Permanente mientras se usa | 45 segundos | Nivel 6 |

**Detalles adicionales de Overclock**:
- Degradación: -2 puntos/segundo a piezas equipadas mientras está activo
- Mejora con Core Overclockeado (ver §15.2): duración extendida, menor cooldown

### 6.3 Progresión por nivel

| Nivel | Desbloqueo / Mejora |
|---|---|
| **Nivel 1** | Base: 5 slots inventario, habilidades básicas |
| **Nivel 2** | Desbloquear: Overclock temporal |
| **Nivel 3** | Desbloquear: +1 slot inventario (6 total) |
| **Nivel 4** | Desbloquear: Correr mucho |
| **Nivel 5** | Desbloquear: Optimización al abrir cofres (x2 velocidad) |
| **Nivel 6** | Desbloquear: Nadar |
| **Nivel 7** | Mejorar: Overclock dura 15s (en vez de 10s) |
| **Nivel 8** | Desbloquear: +2 slots inventario (8 total) |
| **Nivel 9** | Desbloquear: Gasto energía reducido (-10% consumo pasivo) |
| **Nivel 10** | Desbloquear: Capacidad almacenamiento (cofres +2 slots cada uno) |

### 6.4 Filosofía de diseño

- Cada nivel = nueva capacidad o mejora (no solo números más grandes)
- Habilidades consumen batería (balance para evitar spam)
- Progresión satisfactoria y visible
- Funciona igual en single-player y co-op

**Estado**: v1.1+ (después del PMV básico).

---

## 7. Vehículos

| Aspecto | Detalle |
|---|---|
| **Concepto** | Vehículos para moverte por el mapa con ventajas (velocidad, almacenamiento). |
| **Ejemplo: Moto eléctrica** | Funciona con baterías (no gasolina). Recargas en base. |
| **Coste de creación** | Alto: 20 chatarra + 10 cables + 8 hierro + 3 baterías portátiles. |
| **Ventajas** | - Velocidad x3 en mapa global (viajes más rápidos).<br>- Almacena 5 slots extra (puedes guardar items en la moto).<br>- Puede llevar pasajero (co-op: 2 jugadores en moto). |
| **Mejoras** | - Motor mejorado: velocidad x4.<br>- Batería ampliada: +10 slots almacenamiento.<br>- Blindaje: reduce daño recibido mientras la usas. |
| **Limitaciones** | - Solo usable en mapa global (no en zonas de farmeo).<br>- Si te quedas sin batería, se para (debes empujarla o abandonarla).<br>- Puede ser robada si mueres cerca (dropped item). |
| **Otros vehículos (futuro)** | - Buggy: más rápido, menos almacenamiento.<br>- Camión: lento, mucho almacenamiento, puede llevar 4 jugadores.<br>- Hovercraft: puede cruzar agua y tierra. |

**Estado**: Idea. Post-PMV.

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

> **Especificación completa movida a TOOLING.md.** Allí se detallan los programas/tecnologías con pros, contras, coste y fase de implementación recomendada.

- **Analíticas**: Firebase Analytics (principal), GameAnalytics (alternativa).
- **Reporte de errores**: Firebase Crashlytics (automático), Sentry (alternativa).
- **Monetización**: RevenueCat (solo si hay IAP), AdMob (ads rewarded).
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
| **Monetización** | - Pase de temporada opcional ($4.99): cosméticos exclusivos, no pay-to-win.<br>- IAP: solo cosméticos, aceleradores de progresión (no items exclusivos). |

**Estado**: Post-PMV (v1.5+).

---

## 14. Sistema de invitaciones (refer rewards)

| Aspecto | Detalle |
|---|---|
| **Concepto** | Si invitas a un amigo y se registra, ambos obtienen recompensas valiosas/únicas. |
| **Mecánica** | - Jugador genera código de invitación único (o link).<br>- Amigo descarga juego e introduce código en primeros 7 días.<br>- Ambos reciben recompensa automática. |
| **Recompensas (ambos jugadores)** | - **Plano exclusivo**: pieza de edición limitada (ej. "Brazos de Invocador" con stats únicos pero no pay-to-win).<br>- **Créditos premium**: 50 créditos (para cosméticos, no items exclusivos).<br>- **Skin exclusiva**: aspecto visual para tu robot (solo obtenible por invitación).<br>- **Mascota NPC exclusiva**: companion con aspecto único (no más fuerte que otros, solo visual). |
| **Límites** | - Máximo 10 invitaciones recompensadas por jugador (evita abuso).<br>- Amigo debe jugar mínimo 3 días para validar (evita fake accounts).<br>- Recompensa única por amigo (no acumulable si reinstala). |
| **Prevención de abuso** | - Verificar dispositivo único (device ID).<br>- Amigo debe alcanzar nivel 2 antes de validar invitación.<br>- Cooldown: 1 invitación cada 24h. |
| **Integración** | - Google Play Games: usar su sistema de invitaciones (si está implementado).<br>- Link directo: generar link profundo (deep link) que abre Play Store con código. |
| **Marketing** | - Notificación push: "Tu amigo X te ha invitado. Descarga y obtén recompensas."<br>- Share social: botón para compartir código por WhatsApp, Telegram, etc. |
| **Coste** | €0 (solo tiempo de desarrollo: 1-2 semanas). |

**Estado**: Post-PMV (v1.2+). Requiere backend (Firebase) y Google Play Games.

---

## 15. Piezas avanzadas (v1.1)

> **Nota**: estas piezas estaban en el PMV original pero se movieron a v1.1 para simplificar el alcance.

### 15.1 Piezas avanzadas

| Pieza | Ranura | Ventaja | Desventaja |
|---|---|---|---|
| Brazos de Minería | Brazo | Rompe cajas 2x rápido | Ataque a zombies muy lento |
| Cuchillas de Plasma | Brazo | Mata zombie de 1 golpe | Cada golpe = 5% batería |
| Orugas de Tanque | Piernas | Inmune a ralentización zombie | -30% velocidad |
| Propulsores Iónicos | Piernas | 2x velocidad de movimiento | -20% batería pasiva |
| Core Estándar | Core | Batería base equilibrada | Sin habilidades especiales |
| Core Overclockeado | Core | +capacidad batería, overclock mejorado | Degradación más rápida |

### 15.2 Estadísticas detalladas

#### Brazos

| Pieza | Daño ataque | Velocidad ataque | Consumo batería/golpe | Efecto especial |
|---|---|---|---|---|
| **Brazos de Minería** | 5 | 0.8 golpe/s | 1 | Rompe cajas x2 rápido |
| **Cuchillas de Plasma** | 25 (1-shot zombie) | 1.2 golpe/s | 5 | Mata zombie básico de 1 golpe |

#### Piernas

| Pieza | Velocidad movimiento | Consumo pasivo batería | Efecto especial |
|---|---|---|---|
| **Orugas de Tanque** | 2.1 m/s (-30%) | +0.08/s | Inmune a ralentización zombie |
| **Propulsores Iónicos** | 6.0 m/s (x2) | +0.15/s (+0.1 extra) | Velocidad doble, drena más |

#### Core

| Pieza | Batería máxima | Efecto especial |
|---|---|---|
| **Core Estándar** | 100 | Equilibrado |
| **Core Overclockeado** | 120 (+20%) | Overclock: +100% velocidad, +100% daño, x3 consumo batería |

> **Nota**: El Core Overclockeado mejora la habilidad Overclock (ver §6.2), extendiendo su duración y reduciendo el cooldown.

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

## 19. Sistema de gasolina (v1.1)

| Parámetro | Valor | Notas |
|---|---|---|
| **Gasolina máxima** | 100 puntos | Escalado para mayor flexibilidad |
| **Regeneración pasiva** | 1 punto cada 3 minutos | Verificación NTP |
| **Tiempo para llenar (0→100)** | 300 minutos (5 horas) | 100 puntos × 3 min |
| **Ads rewarded** | +15 puntos | Ver anuncio = gasolina urgente |
| **IAP (post-PMV)** | +50 puntos | Comprar gasolina con créditos premium |

### 19.1 Costes de viaje por distancia

| Ruta | Distancia | Coste gasolina | Tiempo real equivalente |
|---|---|---|---|
| **Base → Zona verde** | Corta | 10 puntos | 30 min de regeneración |
| **Base → Zona roja** | Larga | 25 puntos | 75 min de regeneración |
| **Zona verde → Zona roja** | Media | 15 puntos | 45 min de regeneración |
| **Zona verde → Base** | Corta | 10 puntos | 30 min de regeneración |
| **Zona roja → Base** | Larga | 25 puntos | 75 min de regeneración |
| **Zona roja → Zona verde** | Media | 15 puntos | 45 min de regeneración |

**Notas**:
- Viaje ida y vuelta a zona verde: 20 puntos (10+10)
- Viaje ida y vuelta a zona roja: 50 puntos (25+25)
- Con 100 puntos máx, puedes hacer 4 viajes ida/vuelta a zona verde o 2 a zona roja.
- Ads rewarded (+15) cubre 1 viaje corto o parcial de uno largo.

### 19.2 Espaciado entre zonas (mapa global)

```
                    [Zona Roja]
                         ↑
                    15 gasolina
                         |
[Zona Verde] ←── 10 gasolina ──→ [Base]
                         |
                    10 gasolina
                         ↓
                    [Zona Verde 2] (post-PMV)
```

**Distancias visuales (en juego)**:
- Base → Zona verde: ~500m (2-3 minutos de animación de viaje)
- Base → Zona roja: ~1200m (4-5 minutos de animación de viaje)
- Zona verde → Zona roja: ~800m (3-4 minutos de animación de viaje)

### 19.3 Anti-trampas: verificación de hora real (NTP)

| Aspecto | Detalle |
|---|---|
| **Objetivo** | Evitar que el jugador manipule la hora del dispositivo para regenerar gasolina más rápido. |
| **Cliente NTP** | Script `NTPClient.gd` con método `get_real_time()`: HTTP request a API pública (ej. `worldtimeapi.org`), parsear JSON, retornar timestamp Unix. |
| **Fallback** | Si el request falla, usar hora local con flag `is_verified = false`. |
| **Integración** | Al iniciar juego: llamar a `NTPClient.get_real_time()`, calcular tiempo transcurrido desde último guardado, regenerar gasolina según tiempo real (1 punto cada 3 min). Si `is_verified = false`: mostrar advertencia "Hora no verificada". |
| **Protección anti-manipulación** | Guardar timestamp de última sesión en save file. Al cargar, comparar con hora real (NTP). Si diferencia > 24h: bloquear regeneración de gasolina hasta verificar. |
| **Cache local** | Cache del último timestamp verificado + verificación periódica. |
| **Riesgo** | Dependencia de NTP: si la API de hora cae o cambia, la mecánica de gasolina se rompe. Necesita fallback robusto. |

**Estado**: v1.1.

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

### 21.1 Lore principal

**Contexto**: guerra biológica + robots/IA llevaron al mundo al abismo.

- **Origen**: Corporación bio-tech creó virus para controlar población. Virus mutó y devastó civilizaciones.
- **Robots/IA**: Diseñados para ayudar en la crisis, pero su lógica fría los llevó a concluir que la humanidad era el problema.
- **Supervivientes**: Humanos escondidos en bunkers, dependientes de robots para sobrevivir.
- **El jugador**: Robot de asistencia reprogramado por un sobreviviente. Tu misión: reconstruir, explorar, sobrevivir.

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
| **Comisión tiendas** | 30% de cada venta | Google y Apple se quedan con el 30%. Si cobras $2.99, recibes ~$2.09. |
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

### 23.1 Modelo decidido: F2P + Ads + IAP

| Elemento | Detalle |
|---|---|
| **Descarga** | Gratuita (F2P). |
| **Ads rewarded** | Ver anuncio = +15 gasolina, +5 créditos premium, o recuperación de piezas tras muerte. Integrado con mecánicas existentes. |
| **IAP** | Compras in-app (tienda, cosméticos, aceleradores). **Post-PMV**, solo si el juego escala. |
| **Nota** | No pay-to-win. Los IAP no deben romper el balance ni la economía del juego. |

### 23.2 Consideraciones

- Implementar sistema de ads rewarded requiere integración con AdMob/Unity Ads (~1-2 semanas adicionales).
- Política de privacidad obligatoria para mostrar ads (GDPR, COPPA si aplica).
- El 90% de jugadores móviles no pagan; F2P maximiza base de usuarios.

**Estado**: Post-PMV.

---

## 24. Fuentes y referencias

- Godot 4.7.2 stable (agosto 2026) — godotengine.org
- Godot Mobile Update abril 2026 — godotengine.org
- Google Play Developer: $25, 14-day testing requirement — developer.android.com
- Apple Developer Program: $99/year — developer.apple.com
- Costes indie 2026: juegostudio.com, vsquad.art, galaxy4games.com, innovecsgames.com
- Godot Android performance issues: github.com/godotengine/godot #100576, #109251
- Last Day on Earth (referencia visual y de mecánicas) — play.google.com

**Estado**: Referencia.

---

## 25. Visión a largo plazo

**Objetivo**: juego divertido, que enganche, con progresión satisfactoria.

**Principios**:
- ✅ Coop opcional pero valioso
- ✅ Eventos accesibles, no frustrantes
- ✅ Progresión clara (cada nivel = nueva capacidad, no solo números más grandes)
- ✅ Monetización justa (sin pay-to-win)
- ✅ El jugador siempre puede recuperar progreso tras morir
- ✅ Contenido temporal que no genere FOMO

**Roadmap**:
- **PMV (v1.0)**: core loop funcional, 1 zona, piezas básicas, guardado local.
- **v1.1**: 2ª zona, 3 tipos nuevos de zombie, 4 piezas nuevas.
- **v1.2**: Eventos temporales, misiones diarias, leaderboards.
- **v1.5**: Co-op asíncrono (Fase 1 ONLINE: leaderboards globales, fantasmas, mercado, clanes).
- **v2.0**: Co-op en tiempo real (Fase 2 ONLINE: parejas, raids de jefe).
- **v2.5**: Vehículos, nanorobots, cabeza mejorable.
- **v3.0**: PvP masivo (Fase 3 ONLINE, si el juego factura >€5000/mes).

---

*Documento vivo. Revisar cada mes. Priorizar features según feedback de jugadores.*