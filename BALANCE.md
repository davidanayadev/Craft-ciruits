# Balance Numérico — Scrap Circuit (PMV simplificado)

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
| **Consumo movimiento (andar)** | +0.05 puntos/segundo | Total: 0.15/s moviéndose |
| **Consumo movimiento (correr)** | +0.15 puntos/segundo | Total: 0.25/s corriendo |
| **Consumo ataque (golpe básico)** | 1 punto/golpe | Arma: tubería |
| **Regeneración en base** | Instantánea al 100% | Estación de carga |
| **Baterías portátiles (item)** | +20 puntos | Usar en zona de farmeo |
| **Tiempo máximo en zona (quieto)** | ~16 minutos | 100 / 0.1 = 1000s ≈ 16.6 min |
| **Tiempo máximo en zona (moviéndose)** | ~6.6 minutos | 100 / 0.25 = 400s ≈ 6.6 min |

### 1.2 Viajes entre zonas

| Parámetro | Valor | Notas |
|---|---|---|
| **Sistema en PMV** | Viajes ilimitados | Sin coste de gasolina |
| **Zonas disponibles** | 1 (zona verde) | Zona roja en v1.1 |
| **Nota** | Gasolina se añade en v1.1 | Ver SPECS.md para detalles |

### 1.3 Inventario

| Parámetro | Valor | Notas |
|---|---|---|
| **Slots personaje** | 5 | Sin mejoras |
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
| **Núcleos de datos** | Solo robot hostil | XP / mejora de chasis | 999 |

### 2.1 Tasas de drop (por contenedor/enemigo)

| Fuente | Chatarra | Cables | Hierro | Batería | Núcleo |
|---|---|---|---|---|---|
| **Caja básica (zona verde)** | 2-5 | 0-2 | 0-1 | 0% | 0% |
| **Robot hostil básico** | 2-4 | 1-2 | 1-2 | 0% | 1-2 |

---

## 3. Enemigos

### 3.1 Zombies (2 tipos en PMV)

| Tipo | HP | Daño | Velocidad | Habilidad especial | XP |
|---|---|---|---|---|---|
| **Lento** | 20 | 5 | 1.5 m/s | Ninguna | 2 |
| **Rápido** | 15 | 4 | 3.5 m/s | Ninguna | 3 |

**Notas**:
- Zombies no sueltan piezas, solo materiales básicos (0-1 chatarra).
- Daño de zombie se aplica cada 1.5 segundos (si está en rango de ataque).
- XP se otorga al jugador al matar.

### 3.2 Robots hostiles (1 tipo en PMV)

| Tipo | HP | Daño | Velocidad | Habilidad especial | XP | Piezas que suelta |
|---|---|---|---|---|---|---|
| **Básico** | 50 | 8 | 2.0 m/s | Daño físico normal | 10 | Pieza dañada (50% durabilidad) |

**Notas**:
- Robot hostil suelta 1 pieza al morir (aleatoria entre las equipadas en el robot).
- La pieza suelta está **dañada** (50% durabilidad). Requiere reparación en banco.
- XP se otorga al jugador al matar.

---

## 4. Piezas del robot

### 4.1 Durabilidad y degradación

| Parámetro | Valor | Notas |
|---|---|---|
| **Durabilidad máxima (pieza nueva)** | 100 puntos | Todas las piezas |
| **Degradación por golpe recibido** | -5 puntos | Cada vez que el jugador es golpeado |
| **Pieza rota** | 0 puntos | Se pierde, queda ranura vacía |
| **Reparación (banco)** | Coste: 2 hierro + 1 cable | Restaura a 100% |

### 4.2 Estadísticas de piezas básicas (PMV)

#### Brazos

| Pieza | Daño ataque | Velocidad ataque | Consumo batería/golpe | Efecto especial |
|---|---|---|---|---|
| **Sin brazos** | 0 | 0 | 0 | No puede atacar |
| **Brazos básicos** | 10 | 1.0 golpe/s | 1 | Ninguno |

#### Piernas

| Pieza | Velocidad movimiento | Consumo pasivo batería | Efecto especial |
|---|---|---|---|
| **Sin piernas** | 0.5 m/s (muy lento) | +0.1/s | Movimiento a una pierna |
| **Piernas básicas** | 3.0 m/s | +0.05/s | Ninguno |

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

| Estado de la pieza | Coste de reparación | Notas |
|---|---|---|
| **Pieza dañada (50% durabilidad)** | 2 hierro + 1 cable | Restauración completa |
| **Pieza muy dañada (25% durabilidad)** | 3 hierro + 2 cables | Restauración completa |
| **Pieza rota (0% durabilidad)** | No reparable | Se pierde, hay que crear otra |

---

## 5. Crafteo (bancos de la base)

### 5.1 Banco de reparaciones

| Acción | Coste | Resultado |
|---|---|---|
| **Reparar pieza (a 100%)** | 2 hierro + 1 cable | Pieza restaurada |
| **Crear Brazos básicos** | 4 chatarra + 2 cables | Brazos básicos (100% durabilidad) |
| **Crear Piernas básicas** | 4 chatarra + 2 hierro | Piernas básicas (100% durabilidad) |
| **Crear Core básico** | 6 chatarra + 3 cables + 2 hierro | Core básico (100% durabilidad) |
| **Construir cofre** | 3 chatarra + 1 hierro | Cofre (4 slots) |

### 5.2 Generador eólico

| Parámetro | Valor | Notas |
|---|---|---|
| **Coste de construcción** | 5 chatarra + 3 cables + 2 hierro | Banco de reparaciones |
| **Efecto 1** | +20 batería máxima | Permanente mientras exista |
| **Efecto 2** | +50% velocidad recarga | Permanente mientras exista |
| **Generación de baterías** | 1 batería portátil cada 4 horas | Máximo 3 almacenadas |
| **Mantenimiento** | Ninguno en PMV | Funciona siempre |

**Nota**: en v1.1, el generador puede requerir mantenimiento (1 cable cada 24h).

### 5.3 Estación de carga (guardado + recarga batería)

| Parámetro | Valor | Notas |
|---|---|---|
| **Coste de construcción** | Incluida en base al inicio | Ya existe |
| **Efecto** | Guardado automático + recarga batería al 100% | Automático al entrar en base |
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
| **Banco de reparaciones** | 5 | 3 | 2 | 10 |
| **Generador eólico** | 5 | 3 | 2 | 10 |
| **Estación de carga** | Incluida | - | - | 0 |
| **Cofre (x1)** | 3 | 0 | 1 | 4 |
| **Total base completa** | 10 + (5×3) = 25 | 6 | 4 + (5×1) = 9 | 40 materiales |

**Nota**: la base empieza con Estación de carga incluida. Los bancos deben construirse.

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

### 6.2 Fuentes de XP (núcleos de datos)

| Fuente | XP |
|---|---|
| Matar zombie lento | 2 |
| Matar zombie rápido | 3 |
| Matar robot hostil básico | 10 |

> **Nota**: Para el sistema de progresión extendido (10 niveles con habilidades desbloqueables), ver SPECS.md §6 (v1.1+).

---

## 7. Zona de farmeo (diseño de encounter)

### 7.1 Zona Verde (fácil, safety net)

| Parámetro | Valor |
|---|---|
| **Tamaño** | Pequeño (50x50m) |
| **Zombies** | 5-8 (lentos y rápidos) |
| **Robots hostiles** | 0-1 (básico) |
| **Cajas** | 5-7 (básicas) |
| **Materiales principales** | Chatarra, cables (poco hierro) |
| **Riesgo** | Bajo. Jugador sin piezas puede sobrevivir. |

---

## 8. Economía (balance de recursos por sesión)

### 8.1 Sesión típica (15-20 minutos de juego)

| Acción | Resultado esperado |
|---|---|
| Viajar a zona verde | Sin coste (viajes ilimitados en PMV) |
| Matar 5 zombies | +10-15 XP, +2-5 chatarra |
| Abrir 3 cajas | +6-15 chatarra, +0-6 cables, +0-3 hierro |
| Morir (50% probabilidad) | Pierdes piezas equipadas, materiales del inventario |
| Volver a base | Sin coste |
| Reparar piezas | -2 hierro, -1 cable por pieza |

### 8.2 Progresión esperada

| Día | Estado del jugador |
|---|---|
| **Día 1** | Sin piezas, 5 slots, zona verde. Aprende mecánicas. Guía básica. |
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
Durabilidad_restante = Durabilidad_actual - (golpes_recibidos × degradación_por_golpe)

Si Durabilidad_restante <= 0 → Pieza rota
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

*Documento vivo. Ajustar según playtesting. Valores iniciales para PMV simplificado.*