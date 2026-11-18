# Balance Numérico — CyberScrap (PMV simplificado)

> Spreadsheet de referencia para balance del juego. Todos los valores son iniciales y ajustables en playtesting.
> **Alcance PMV**: 1 zona, 2 zombies, 1 robot, 3 piezas básicas, 2 bancos.

**Referencias cruzadas**:
- Para alcance del PMV: ver **PMV.md**
- Para features futuras (post-PMV): ver **SPECS.md**
- Para implementación paso a paso: ver **ACTION_PLAN.md**

---

## 1. Recursos del jugador

### 1.1 Batería (recurso principal)

| Parámetro | Valor | Notas |
|---|---|---|
| **Batería máxima base** | 100 puntos | Sin mejoras de core |
| **Consumo pasivo (encendido)** | 0.1 puntos/segundo | 1 punto cada 10 segundos |
| **Consumo movimiento (andar)** | +0.05 puntos/segundo | Total: 0.15/s moviéndose. Valor de las Piernas básicas (ver §4.2) |
| **Consumo movimiento (correr)** | +0.15 puntos/segundo | Total: 0.25/s corriendo. Solo con piernas equipadas: sin piernas no se puede correr (§4.2) |
| **Consumo ataque (golpe básico)** | 1 punto/golpe | Un brazo y Brazos básicos (sin armas en PMV; §4.2). Se cobra por golpe lanzado, también si falla, y aunque vacíe la batería (decisión nov 2026, spec 007) |
| **Recarga en base** | Instantánea al 100% | Al interactuar con una Estación de carga (ver §5.3). Sin recarga automática: la batería se consume también dentro de la base (decisión nov 2026) |
| **Batería al reaparecer** | 100% | Tras morir, en la base (PMV.md §2.4) |
| **Umbral de batería baja** | 20% de la batería máxima | Dispara el aviso "Batería baja" (decisión nov 2026). Con la máxima base, 20 puntos |
| **Baterías portátiles (item)** | +20 puntos | Usar en zona de farmeo |
| **Tiempo máximo en zona (quieto)** | ~16 minutos | 100 / 0.1 = 1000s ≈ 16.6 min |
| **Tiempo máximo en zona (moviéndose)** | ~6.6 minutos | 100 / 0.25 = 400s ≈ 6.6 min |

### 1.2 Viajes entre zonas

| Parámetro | Valor | Notas |
|---|---|---|
| **Sistema en PMV** | Viajes ilimitados | Sin coste. Instantáneo (decisión nov 2026): no se adelanta el coste de batería de v1.1 |
| **Cómo se inicia el viaje (PMV)** | Punto de salida físico | Uno en la zona y otro en la base (decisión nov 2026). Cada visita a una zona repone sus cajas y enemigos (§7.2) |
| **Zonas disponibles** | 1 (zona verde) | Zona roja en v1.1, como tipo de zona de los mundos por semilla (SPECS.md §26) |
| **Viaje a pie entre zonas (v1.1)** | Coste de batería según la distancia | Decisión nov 2026. Valor por punto de distancia por definir al diseñar v1.1 |
| **Gasolina (v1.2)** | Item crafteable, sin regeneración | Complemento de movilidad para vehículos y movimiento asistido, no un limitador de viajes (SPECS.md §19). Valores (stack, receta, consumo por distancia) por definir aquí |

### 1.3 Inventario

| Parámetro | Valor | Notas |
|---|---|---|
| **Slots personaje** | 5 | A nivel 1 de chasis; crecen con el nivel (§6.1) |
| **Slots por cofre** | 4 | Fijo en PMV |
| **Cofres máximos en base** | 5 | Límite duro en PMV (20 en v1.1) |
| **Slots totales (base)** | 5 + (5 × 4) = 25 | Personaje + cofres |

---

## 2. Materiales (loot)

| Material | Drop fuente | Uso principal | Stack máximo |
|---|---|---|---|
| **Chatarra** | Cajas, robot hostil | Crafteo básico (piezas) | 99 |
| **Cables** | Cajas, robot hostil | Reparación, crafteo | 50 |
| **Hierro** | Cajas, robot hostil | Reparación de piezas, estructura | 50 |
| **Baterías (item)** | Cajas raras, generador eólico | Recargar batería (+20 puntos) | 10 |

> **XP (núcleos de datos)**: no es un item. Se otorga directamente al matar un enemigo (ver §6.2), no ocupa slot y no se pierde al morir. "Núcleos" es solo el nombre de la unidad de XP.

### 2.1 Tasas de drop (por contenedor/enemigo)

| Fuente | Chatarra | Cables | Hierro | Batería |
|---|---|---|---|---|
| **Caja básica (zona verde)** | 2-5 | 0-2 | 0-1 | 0% |
| **Robot hostil básico** | 2-4 | 1-2 | 1-2 | 0% |

> **Cómo se tira un rango** (decisión nov 2026, spec 004): cantidad entera uniforme entre ambos extremos, incluidos ("2-5" da 2, 3, 4 o 5 con la misma probabilidad). El contenido de cada caja sale del RNG con semilla de su zona (semilla del mundo + `zone_id` + índice de la caja + número de visita, §7.2), así que no depende del orden en que se abren ni cambia al recargar la partida. Un material que sale 0 no se entrega.

---

## 3. Enemigos

### 3.1 Zombies (2 tipos en PMV)

| Tipo | HP | Daño | Velocidad | Habilidad especial | XP |
|---|---|---|---|---|---|
| **Lento** | 20 | 5 | 1.5 m/s | Ninguna | 2 |
| **Rápido** | 15 | 4 | 3.5 m/s | Ninguna | 3 |

**Notas**:
- Zombies no sueltan piezas, solo materiales básicos (0-1 chatarra). Se tira con la regla de rangos de §2.1, así que la mitad de las veces no cae nada, y cae al suelo como objeto caído (§7.2; decisión nov 2026, spec 008).
- Daño de zombie se aplica cada 1.5 segundos (si está en rango de ataque). El primer golpe llega tras un intervalo completo en rango; salir y volver a entrar reinicia la espera (decisión nov 2026, spec 006).
- **El daño son puntos de batería, 1:1** (decisión nov 2026, spec 006): un golpe de zombie lento quita 5 puntos de batería y uno rápido, 4. Sin defensa del jugador en el PMV (la `defensa_jugador` de §9.2 vale 0).
- XP se otorga al jugador al matar.

**IA de zombies** (valores iniciales, decisión nov 2026, spec 006; iguales para los dos tipos y ajustables en el móvil):

| Parámetro | Valor | Notas |
|---|---|---|
| **Radio de visión** | 8 m | Al entrar el jugador, pasa a perseguir |
| **Rango de ataque** | 1.5 m | Dentro, se para y golpea cada intervalo |
| **Radio de patrulla** | 5 m | Alrededor de su punto de aparición |
| **Pausa entre patrullas** | 2-4 s | Rango uniforme, con el RNG de la zona |
| **Distancia de abandono** | 12 m | Más lejos, deja de perseguir y vuelve a patrullar |

### 3.2 Robots hostiles (1 tipo en PMV)

| Tipo | HP | Daño | Velocidad | Habilidad especial | XP | Piezas que suelta |
|---|---|---|---|---|---|---|
| **Básico** | 50 | 8 | 2.0 m/s | Daño físico normal | 10 | Pieza dañada (50% durabilidad), 15% probabilidad |

**Notas**:
- Robot hostil tiene un 15% de probabilidad de soltar 1 pieza al morir (aleatoria entre las equipadas en el robot).
- La pieza suelta está **dañada** (50% durabilidad). Requiere reparación en banco.
- XP se otorga al jugador al matar.

---

## 4. Piezas del robot

### 4.1 Durabilidad y degradación

| Parámetro | Valor | Notas |
|---|---|---|
| **Durabilidad máxima (pieza nueva)** | 100 puntos | Todas las piezas |
| **Degradación por golpe recibido** | -5 puntos | Cada golpe recibido (zombies y robots) degrada solo la primera pieza equipada intacta, en orden: Brazos → Piernas → Core |
| **Pieza rota** | 0 puntos | Se pierde, queda ranura vacía |
| **Reparación (banco)** | Coste según el estado (§4.3.2) | Restaura a 100% |

### 4.2 Estadísticas de piezas básicas (PMV)

#### Brazos

| Pieza | Daño ataque | Velocidad ataque | Consumo batería/golpe | Efecto especial |
|---|---|---|---|---|
| **Un brazo (sin Brazos básicos)** | 5 | 1.0 golpe/s | 1 | Estado base del robot, no es una pieza: no se degrada ni se pierde al morir. Se empieza con él y se vuelve a él al romper o perder los Brazos básicos. El robot nunca se queda sin ataque (decisión nov 2026, spec 007) |
| **Brazos básicos** | 10 | 1.0 golpe/s | 1 | Ninguno |

#### Piernas

| Pieza | Velocidad andando | Velocidad corriendo | Consumo al andar | Efecto especial |
|---|---|---|---|---|
| **Sin piernas** | 0.5 m/s (muy lento) | No puede correr | +0.1/s | Movimiento a una pierna |
| **Piernas básicas** | 3.0 m/s | 4.8 m/s | +0.05/s | Ninguno |

> El consumo al andar sustituye al "consumo movimiento (andar)" de §1.1 según las piernas equipadas. Solo se aplica mientras el robot se mueve; quieto, solo cuenta el consumo pasivo (0.1/s).

> **Por qué 4.8 m/s al correr** (decisión nov 2026, 1.6 × andar): andando (3.0) no se escapa del zombie rápido (3.5, §3.1); corriendo sí, a cambio de un 67 % más de consumo (0.25/s frente a 0.15/s). Correr por debajo de 3.5 m/s haría imposible huir de él.

#### Core

| Pieza | Batería máxima | Efecto especial |
|---|---|---|
| **Core básico** | 100 | Ninguno |

### 4.3 Materiales para crear y reparar piezas

#### 4.3.1 Creación de piezas básicas (en banco de reparaciones)

| Pieza | Chatarra | Cables | Hierro | Total |
|---|---|---|---|---|
| **Brazos básicos** | 4 | 2 | 0 | 6 |
| **Piernas básicas** | 4 | 0 | 2 | 6 |
| **Core básico** | 6 | 3 | 2 | 11 |

#### 4.3.2 Reparación de piezas (en banco de reparaciones)

El coste va por tramos según la durabilidad que le queda a la pieza, en porcentaje de su máxima (decisión nov
2026, spec 011): reparar pronto sale más barato. Una pieza intacta (100 %) no se repara.

| Estado de la pieza | Durabilidad que queda | Coste de reparación | Notas |
|---|---|---|---|
| **Pieza dañada** | Más del 25 % y menos del 100 % | 2 hierro + 1 cable | Restauración completa |
| **Pieza muy dañada** | Del 25 % para abajo, sin llegar a 0 | 3 hierro + 2 cables | Restauración completa |
| **Pieza rota** | 0 | No reparable | Se pierde, hay que crear otra |

---

## 5. Crafteo (bancos de la base)

### 5.1 Banco de reparaciones

| Acción | Coste | Resultado |
|---|---|---|
| **Reparar pieza (a 100%)** | Según el estado (§4.3.2) | Pieza restaurada |
| **Crear Brazos básicos** | 4 chatarra + 2 cables | Brazos básicos (100% durabilidad) |
| **Crear Piernas básicas** | 4 chatarra + 2 hierro | Piernas básicas (100% durabilidad) |
| **Crear Core básico** | 6 chatarra + 3 cables + 2 hierro | Core básico (100% durabilidad) |
| **Construir cofre** | 3 chatarra + 1 hierro | Cofre (4 slots) |
| **Construir estación de carga** | 4 chatarra | Estación de carga (§5.3) |

### 5.2 Generador eólico

| Parámetro | Valor | Notas |
|---|---|---|
| **Coste de construcción** | 5 chatarra + 3 cables + 2 hierro | Banco de reparaciones |
| **Efecto** | +20 batería máxima | Permanente mientras exista |
| **Generación de baterías** | 1 batería portátil cada 4 horas | Máximo 3 almacenadas |
| **Mantenimiento** | Ninguno en PMV | Funciona siempre |

**Nota**: en v1.1, el generador puede requerir mantenimiento (1 cable cada 24h).

### 5.3 Estación de carga (recarga batería + guardado)

> **Decisión nov 2026**: la base **empieza sin estación**. Hay que craftear la primera, y la batería se consume también dentro de la base: tensión desde el minuto 0. Por eso la receta es barata (solo chatarra, el material más común: 2-5 por caja, §2.1).

| Parámetro | Valor | Notas |
|---|---|---|
| **Coste de construcción** | 4 chatarra | Banco de reparaciones. Valor inicial: ajustar en playtesting manteniéndolo fácil |
| **Cantidad** | Sin límite de diseño | Todas las que quieras; el límite práctico es el espacio de la base (ver PMV.md §10) |
| **Ubicación** | Solo dentro de la base | No se pueden colocar en zonas de farmeo |
| **Efecto** | Recarga batería al 100% (de la batería máxima) + guardado | Instantáneo, al interactuar. Sin coste por uso |
| **Autoguardado** | Al entrar en la base | Se mantiene, pero ya **no recarga** la batería |
| **Mantenimiento** | Ninguno | Funciona siempre |

### 5.4 Cofres de almacenamiento

| Parámetro | Valor | Notas |
|---|---|---|
| **Coste de construcción** | 3 chatarra + 1 hierro | Banco de reparaciones |
| **Capacidad** | 4 slots | Fijo en PMV |
| **Máximo en base** | 5 cofres | Límite duro en PMV (20 en v1.1) |
| **Mantenimiento** | Ninguno | Funciona siempre |

### 5.5 Resumen de costes de construcción (bancos + estructuras)

| Estructura | Chatarra | Cables | Hierro | Total materiales |
|---|---|---|---|---|
| **Banco de reparaciones** | Incluido | - | - | 0 |
| **Generador eólico** | 5 | 3 | 2 | 10 |
| **Estación de carga (x1)** | 4 | 0 | 0 | 4 |
| **Cofre (x1)** | 3 | 0 | 1 | 4 |
| **Total base completa** (1 estación) | 5 + 4 + (5×3) = 24 | 3 | 2 + (5×1) = 7 | 34 materiales |

**Nota**: la base empieza solo con el Banco de reparaciones. La Estación de carga, el generador eólico y los cofres se construyen desde él.

### 5.6 Base y cuadrícula de colocación (decisión nov 2026, spec 009)

Valores iniciales; ajustar en el móvil. Si el área edificable se queda corta, se amplía.

| Parámetro | Valor | Notas |
|---|---|---|
| **Tamaño de la base** | 20x20 m | Escena fija, centrada en su celda del mapa global (§7) |
| **Tamaño de celda** | 1.0 m | Cuadrícula de colocación (ACTION_PLAN Tarea 2.8) |
| **Área edificable** | 12x8 celdas | 96 celdas, menos las reservadas (punto de aparición, frente del banco y del punto de salida), que son dato de la escena de la base |
| **Huella de la estación de carga** | 1x1 celdas | La huella es dato de cada estructura. La del generador y la del cofre se fijan con la spec 012 |
| **Rotación de estructuras** | No | En el PMV no se giran |
| **Mover una estructura** | Sin coste | Modo edición |
| **Desmontar una estructura** | No | En el PMV las estructuras se mueven, no se quitan |

---

## 6. Progresión (XP / Mejora de chasis)

### 6.1 Niveles de chasis

| Nivel | XP requerida | Beneficio |
|---|---|---|
| **1** | 0 | Base: 5 slots inventario |
| **2** | 50 núcleos | +2 slots inventario (7 total) |
| **3** | 150 núcleos | +3 slots inventario (10 total) |
| **4** | 300 núcleos | +5 slots inventario (15 total) |
| **5** | 500 núcleos | +5 slots inventario (20 total) |

> XP **acumulada** (umbral total, no XP adicional por nivel; decisión nov 2026). Estos valores van a un `.tres` de `ChassisLevelData` y los aplica ACTION_PLAN.md Tarea 2.7.

### 6.2 Fuentes de XP (núcleos de datos)

| Fuente | XP |
|---|---|
| Matar zombie lento | 2 |
| Matar zombie rápido | 3 |
| Matar robot hostil básico | 10 |

> **Nota**: Para el sistema de progresión extendido (10 niveles con habilidades desbloqueables), ver SPECS.md §6 (v1.1+).

---

## 7. Zona de farmeo (diseño de encounter)

| Parámetro | Valor | Notas |
|---|---|---|
| **Celda del mapa global** | 80x80 m | Decisión nov 2026 (spec 004). Cada zona cabe en una celda de la cuadrícula (SPECS.md §26 prevé zonas de 50-80 m) y se centra en ella. **No cambiar** una vez haya partidas guardadas: las posiciones se guardan como `(zone_id, posición local)` |

### 7.1 Zona Verde (fácil, safety net)

| Parámetro | Valor |
|---|---|
| **Tamaño** | Pequeño (50x50m) |
| **Zombies** | 5-8 (lentos y rápidos). Primero uno de cada tipo; cada uno de los demás es lento o rápido al 50 %. Número, tipo y posición salen de semilla del mundo + `zone_id` + número de visita, así que cambian en cada visita (decisión nov 2026, spec 006) |
| **Robots hostiles** | 0-1 (básico) |
| **Cajas** | 5-7 (básicas) |
| **Materiales principales** | Chatarra, cables (poco hierro) |
| **Riesgo** | Bajo. Jugador sin piezas puede sobrevivir. |

### 7.2 Reposición por visita (decisión nov 2026)

Las cajas y los enemigos se reponen **por visita**, nunca por tiempo: el reloj real no interviene (se saltaría cambiando la hora, y el PMV no tiene servidor). La única excepción es la caducidad de los items soltados al morir (abajo), que solo quita una ventana al jugador.

| Parámetro | Regla |
|---|---|
| **Contador de visitas** | Uno por zona, guardado en el mundo. Empieza en 0 |
| **Cuándo sube** | Al **salir** de la zona, y también al **morir** en ella: la muerte cuenta como salir. No sube al entrar ni al cargar la partida |
| **Items soltados al morir** | No dependen del contador: siguen en la zona hasta que se recuperan o caducan (ACTION_PLAN Tarea 1.5) |
| **Caducidad de los items soltados** | Por tiempo de juego, que sigue contando con la app cerrada. Medido con la hora del dispositivo desde la muerte (`ITimeService`), con el tiempo negativo tratado como 0. **Duración: 5 minutos** (valor inicial, decisión nov 2026; ajustable en playtesting, PMV.md §10) |
| **Items tirados del inventario** | Misma regla que los soltados al morir: siguen en la zona hasta que se recogen o caducan, con la misma duración (decisión nov 2026) |
| **Cajas abiertas** | Se guardan mientras dura la visita: cerrar y abrir la app devuelve la misma visita con las mismas cajas abiertas |
| **Loot que no cabe en el inventario** | Se queda en la caja durante la visita; se recoge al volver a interactuar, sin nueva tirada. Se pierde al empezar la visita siguiente (decisión nov 2026) |
| **Caja vaciada** | Sigue en la zona como contenedor, con la capacidad de un cofre (§5.4), para dejar items del inventario. Lo depositado se pierde al empezar la visita siguiente: no es un almacén entre visitas (decisión nov 2026) |
| **Contenido de cada caja** | Semilla del mundo + `zone_id` + índice de la caja + número de visita (§2.1). Recargar no lo cambia |
| **Número y posición de las cajas** | Solo semilla del mundo + `zone_id`. No cambian entre visitas |
| **Enemigos** | Reaparecen con el mismo contador de visitas (spec 006) |
| **Enemigos muertos** | Se guardan mientras dura la visita: cerrar y abrir la app no los resucita ni repite su drop. Los vivos vuelven a su punto de aparición con la vida completa (decisión nov 2026, spec 010) |
| **Material soltado por los enemigos** | Misma regla que los soltados al morir: cae al suelo como objeto caído, no depende del contador y caduca con la misma duración (decisión nov 2026, spec 008) |
| **Quién lo aplica** | El contador y la reposición de cajas y enemigos: spec 008 (al morir) y spec 009 (al salir por el punto de salida). El guardado del contador, de las cajas abiertas, de los enemigos muertos y de los objetos caídos: spec 010 (decisión nov 2026, spec 008) |

Entrar y salir en bucle no debe salir gratis: cada visita tiene que costar batería y riesgo (ACTION_PLAN Tarea 5.2). Morir tampoco es una vía segura de recuperación: al volver a por las piezas, la zona ya está repuesta, con los enemigos de nuevo en pie (decisión nov 2026).

---

## 8. Economía (balance de recursos por sesión)

### 8.1 Sesión típica (15-20 minutos de juego)

| Acción | Resultado esperado |
|---|---|
| Viajar a zona verde | Sin coste (viajes ilimitados en PMV), desde el punto de salida de la base |
| Matar 5 zombies | +10-15 XP, +0-5 chatarra (0-1 por zombie, §3.1) |
| Abrir 3 cajas | +6-15 chatarra, +0-6 cables, +0-3 hierro |
| Morir (50% probabilidad) | Pierdes piezas equipadas, materiales del inventario |
| Volver a base | Sin coste |
| Reparar piezas | -2 hierro, -1 cable por pieza |

### 8.2 Progresión esperada

| Día | Estado del jugador |
|---|---|
| **Día 1** | Sin piezas (pelea con un brazo, §4.2), 5 slots, zona verde. Aprende mecánicas. Guía básica. Craftea su primera Estación de carga. |
| **Día 2-3** | Consigue brazos básicos y piernas básicas. Empieza a explorar con más confianza. |
| **Día 4-7** | Tiene piezas básicas. Aprende a reparar. Generador eólico genera baterías. |
| **Día 7-14** | Nivel de chasis 2-3. Tiene combinación de piezas. Optimiza rutas de farmeo. |
| **Día 14-30** | Nivel 4-5. Tiene piezas reparadas. Explora zona verde con estrategia. Espera v1.1 (zona roja). |

---

## 9. Fórmulas de cálculo

### 9.1 Tiempo de muerte en zona (sin curación)

```
Tiempo_muerte = Batería_actual / Consumo_total_por_segundo

Donde:
Consumo_total = consumo_pasivo + consumo_movimiento + (consumo_ataque × frecuencia_ataque)
```

### 9.2 Daño recibido por minuto

```
Daño_recibido = (daño_enemigo × ataques_por_minuto) - (defensa_jugador)

Donde:
defensa_jugador = suma de defensa de piezas equipadas (si aplica)
```

### 9.3 Durabilidad restante después de encounter

```
Por cada golpe recibido:
  pieza = primera pieza equipada con durabilidad > 0, en orden Brazos → Piernas → Core
  pieza.durabilidad -= degradación_por_golpe

Si pieza.durabilidad <= 0 → Pieza rota; el siguiente golpe degrada la siguiente pieza del orden
```

---

## 10. Ajustes recomendados en playtesting

| Parámetro | Si el juego es muy difícil | Si el juego es muy fácil |
|---|---|---|
| **Batería máxima** | +20% | -10% |
| **Consumo pasivo** | -20% | +15% |
| **HP zombies** | -20% | +25% |
| **Daño zombies** | -25% | +20% |
| **Drop de materiales** | +30% | -20% |
| **Degradación de piezas** | -30% | +25% |
| **Coste de reparación** | -50% | +30% |

---

## 11. Controles y sensación

> Decisión nov 2026: BALANCE.md es dueño de todos los números, también los de sensación de juego. El código los lee de un `.tres` de configuración. Los ajustes que cambia el jugador en Opciones se guardan aparte, en `user://settings.cfg` (specs/architecture.md §10.2), y parten de estos valores.

| Parámetro | Valor | Notas |
|---|---|---|
| **Zona del joystick** | Mitad izquierda de la pantalla | Joystick flotante: aparece donde tocas (PMV.md §2.1) |
| **Zona muerta del joystick** | 15 % del radio | Por debajo no hay movimiento |
| **Umbral de correr** | 80 % del radio | Valor por defecto; lo ajusta la opción "sensibilidad de joystick" (ACTION_PLAN 4.2) |
| **Umbral para volver a andar** | 70 % del radio | Margen para no alternar andar/correr en el borde |
| **Cámara: rotación Y** | 45° | PMV.md §12, ACTION_PLAN 0.2 |
| **Cámara: inclinación X** | 35° | PMV.md §12 da 35-45°; ACTION_PLAN 0.2 fija 35° |
| **Cámara: tamaño ortográfico** | 10.0 m | Metros visibles en vertical (plan 002: cámara ortográfica, *keep height*; 14.0 hasta pasar a apaisado el 2026-11-14). Ajustar en el móvil (T-002-08) |
| **Cámara: distancia física** | 20.0 m | Solo afecta a near/far y sombras; con cámara ortográfica no cambia el encuadre |
| **Velocidad de giro del robot** | 10.0 rad/s | Media vuelta en ~0.3 s (plan 002). Ajustar en el móvil (T-002-08) |
| **Radio de interacción** | 2.0 m | Distancia a la que aparece el botón "Interactuar" para el objeto más cercano (spec 004, decisión nov 2026). Ajustar en el móvil |
| **Rango de la sensibilidad en Opciones** | Por definir | Se fija con la Tarea 4.2 |

**Combate** (valores iniciales, decisión nov 2026, spec 007; ajustar en el móvil):

| Parámetro | Valor | Notas |
|---|---|---|
| **Auto-apuntado** | No | El robot golpea hacia donde mira; apuntar es cosa del jugador |
| **Alcance del golpe** | 2.0 m | Caja delante del robot. Debe superar los 1.5 m a los que se para el zombie para atacar (§3.1) |
| **Ancho del golpe** | 1.0 m | Daña una vez a cada enemigo vivo dentro |
| **Momento del impacto** | 0.2 s | Desde el inicio del golpe. Menor que 1 / velocidad de ataque (§4.2) |
| **Destello blanco del enemigo** | 0.1 s | Al recibir un golpe del robot |
| **Sacudida de cámara al golpear** | 0.05 m durante 0.1 s | |
| **Sacudida de cámara al recibir un golpe** | 0.15 m durante 0.2 s | |
| **Borde rojo del HUD al recibir un golpe** | 0.3 s | |

**Muerte** (valores iniciales, decisión nov 2026, spec 008; ajustar en el móvil):

| Parámetro | Valor | Notas |
|---|---|---|
| **Pantalla de "Transferencia de Consciencia"** | 2.0 s | Termina sola, sin botón. Después el robot reaparece con la batería de §1.1 |

---

*Documento vivo. Ajustar según playtesting. Valores iniciales para PMV simplificado.*