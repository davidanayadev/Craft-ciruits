# Ideas: progresión por niveles, recuerdos y habilidades

| Campo | Valor |
|---|---|
| **Estado** | Aprobado (23 nov 2026). Las decisiones están trasladadas a los documentos fuente; este documento guarda el razonamiento |
| **Fuente de verdad** | Alcance en `PMV.md` §2.3, §6 y §10; habilidades de v1.1 en `SPECS.md` §6; números en `BALANCE.md` §6; tareas en `ACTION_PLAN.md` 2.7 y 3.4 |
| **Orden de trabajo** | Commit de documentación → spec 014 (solo amplía la tabla de niveles hasta el 10) → spec 015 (piezas y estadísticas) → spec 016 (recuerdos y huecos del Core) |

Si este documento y un documento fuente no coinciden, manda el documento fuente.

## 1. Decisiones

- Las mejoras pasivas se llaman **recuerdos**: fragmentos de memoria del humano cuya consciencia lleva el robot
  (ver §8).
- **El PMV llega al nivel 10.** 3 niveles abren un **hueco de recuerdo en el Core** (2, 6 y 10) y los otros 7
  enseñan un **recuerdo**.
- En el PMV los recuerdos son **sencillos y fijos** (cada nivel da siempre el mismo), para probar la dinámica de
  aprender, instalar y cambiar. **En v1.1 el sistema pasa a aleatorio o condicional** (ver §3).
- **Core**: el Core básico admite los 3 huecos. Si el Core se rompe, los recuerdos se desactivan pero no se
  pierden. El nivel 1 enseña un recuerdo y el nivel 2 abre el hueco para instalarlo.
- **Inventario**: se queda la tabla de BALANCE §6.1 (5, 7, 10, 15, 20 en los niveles 1-5); los niveles 6-10 no
  dan ranuras. No se baja el máximo de pila en el PMV.
- **XP**: además de matar, se gana al **craftear** una pieza, **reparar** una pieza y **vaciar un sitio de cajas**.
  Curva de los niveles 6-10: 750, 1000, 1300, 1650 y 2000. Objetivo: nivel 10 entre el día 30 y el 45. Los valores
  se revisan con `balance-auditor` y en una prueba en el juego antes de cerrarlos.
- **Habilidades activas (v1.1)**: vienen de las **piezas**, no del nivel. El Overclock lo da el Core
  Overclockeado, el Impulso los Propulsores Iónicos y el Pulso EMP unos brazos. El botón muestra la habilidad de
  la pieza equipada.
- **Nadar** pasa a una versión futura (necesita zonas con agua).
- **Overclock**: duración fija (ver §6.1).
- De StarCraft y Minecraft solo se apuntan el **repetidor de base** y las **mejoras de armas y armaduras** (§7).

## 2. Problemas del diseño anterior (SPECS §6) y cómo quedan

| Problema | Resolución |
|---|---|
| Overclock contradictorio: §6.2 decía que duraba hasta desactivarlo o batería < 10%; §6.3 nivel 7 decía "15 s en vez de 10 s" | Duración fija de 10 s; la mejora la da el Core Overclockeado (§6.1) |
| Nadar (nivel 6) necesitaba zonas con agua que no existen | Versión futura |
| Correr mucho (nivel 4) solapaba con correr y con los Propulsores Iónicos | Sustituido por Impulso, que dan los propios Propulsores |
| Nivel 8 "por definir" y nivel 1 "habilidades básicas" sin contenido | Tabla de §5 |
| Overclock en el nivel 2 era demasiado fuerte para empezar | Las activas salen de los niveles: vienen de las piezas |

## 3. Dinámica de las opciones

**PMV: fijo** (decidido). Para v1.1, a elegir entre aleatorio y condicional:

| Dinámica | Cómo funciona | Pro | Contra |
|---|---|---|---|
| **Fijo** (PMV) | Cada nivel da siempre el mismo recuerdo | Fácil de equilibrar, probar y enseñar; en co-op todos saben qué tiene cada uno | Todas las partidas progresan igual: el Hardcore y los mundos por semilla pierden variedad |
| **Aleatorio con semilla** | Al subir, se ofrecen 3 recuerdos sorteados con semilla del mundo + jugador + nivel; se elige 1 | Cada mundo da combinaciones distintas y recargar no cambia la oferta (como la mesa de encantar de Minecraft); `SeededRng` ya existe | Una mala oferta puede frustrar, y equilibrar exige que ninguna opción sea claramente mejor que las demás |
| **Condicional** | El sorteo se inclina hacia lo que haces: quien mata mucho ve más recuerdos de combate, quien saquea mucho, de saqueo | La progresión se siente hecha para tu forma de jugar | Hay que medir estadísticas (bajas, cajas, distancia) y guardarlas; el jugador no entiende por qué le sale lo que le sale y tiende a encasillarse |

Para que el paso a v1.1 sea barato, el PMV guarda los recuerdos **aprendidos** por id, no "el recuerdo del nivel
N": así cambiar a una oferta sorteada no rompe las partidas guardadas.

## 4. Inventario: por qué las ranuras no motivan

Hecho: el PMV tiene 4 ítems apilables (chatarra 99, cables 50, hierro 50, batería portátil 5) y 3 piezas
(`game/resources/items/`, `game/resources/pieces/`). Inferencia: con 7 ranuras (nivel 2) cabe un ejemplar de
cada cosa, así que las ranuras de los niveles 3-5 casi no cambian nada al jugar. Por eso la recompensa principal
del nivel pasa a ser el recuerdo o el hueco, y la tabla de ranuras se queda como está.

Idea para v1.1: un recuerdo "Compartimento de carga" (+ranuras) que compite por un hueco. Choca con R-014-08/11
(el inventario no encoge): solo se podría quitar con esas ranuras vacías.

## 5. Niveles 1-10 del PMV

Reglas:
- **Cada recuerdo aprendido es permanente** y se conserva al morir, como la XP.
- **Los huecos son lo escaso**: con 3 huecos y 7 recuerdos, siempre hay que decidir cuáles llevar.
- Los recuerdos se **instalan y cambian en el banco** de la base, nunca en la zona (sin ventanas en mitad de un
  combate).
- Los huecos los **sostiene el Core**: huecos activos = mínimo entre los que da el nivel y los que admite el Core
  (el básico admite 3). Si el Core se rompe, los recuerdos quedan inactivos hasta equipar otro; no se pierden.
  Encaja con la muerte en Normal, que conserva el Core.

Por qué los huecos en los niveles 2, 6 y 10: el nivel 1 enseña un recuerdo y la primera subida (50 XP) abre el
hueco para instalarlo, así el sistema se aprende pronto. Después, un hueco cada 4 niveles; el último, en el nivel
máximo, como premio final.

| Nivel | XP acumulada | Ranuras de inventario | Recompensa |
|---|---|---|---|
| 1 | 0 | 5 | Recuerdo: **Célula eficiente** |
| 2 | 50 | 7 | **1er hueco** |
| 3 | 150 | 10 | Recuerdo: **Servos ágiles** |
| 4 | 300 | 15 | Recuerdo: **Puño reforzado** |
| 5 | 500 | 20 | Recuerdo: **Golpe económico** |
| 6 | 750 | 20 | **2º hueco** |
| 7 | 1000 | 20 | Recuerdo: **Batería ampliada** |
| 8 | 1300 | 20 | Recuerdo: **Zancada eficiente** |
| 9 | 1650 | 20 | Recuerdo: **Chasis reforzado** |
| 10 | 2000 | 20 | **3er hueco** |

### 5.1 Recuerdos fijos del PMV

Elegidos por **sencillos**: todos son un modificador de una estadística, sin lógica propia, para probar la dinámica
sin coste.

| Nivel | Recuerdo | Efecto | Por qué ese valor |
|---|---|---|---|
| 1 | Célula eficiente | -20% consumo pasivo | — |
| 3 | Servos ágiles | +10% velocidad andando y corriendo | Andando (3,3 m/s) sigue sin escapar del zombie rápido (3,5 m/s) |
| 4 | Puño reforzado | +50% daño | Con +20% no cambiaban los golpes para matar. Con +50%, los Brazos básicos (15) matan al zombie rápido de 1 golpe y un brazo solo (7,5) mata al lento en 3 golpes en vez de 4 |
| 5 | Golpe económico | -50% batería por golpe | — |
| 7 | Batería ampliada | +15 batería máxima | — |
| 8 | Zancada eficiente | -30% consumo al andar y correr | — |
| 9 | Chasis reforzado | -1 durabilidad perdida por golpe (5 → 4) | — |

### 5.2 Candidatos para v1.1 (aleatorio o condicional)

Necesitan lógica propia, no solo un modificador.

| Área | Recuerdo | Efecto |
|---|---|---|
| Batería | Modo ahorro | Quieto más de 3 s, el consumo pasivo baja a la mitad |
| Batería | Recuperación cinética | Cada baja devuelve +1 de batería |
| Batería | Último aliento | Una vez por salida, al llegar a 0 te quedas en 1 durante 5 s |
| Combate | Contraataque | El golpe justo después de recibir uno hace +50% |
| Combate | Descarga estática | Al recibir un golpe, 20% de devolver daño |
| Combate | Golpe por la espalda | Más daño por detrás (necesita sigilo, SPECS §30) |
| Piezas | Blindaje adaptativo | El desgaste va a la pieza más entera, no en orden Brazos → Piernas → Core |
| Piezas | Desguace | Una pieza que se rompe devuelve parte de sus materiales |
| Saqueo | Ojo de chatarrero | Una tirada extra de material por caja, también con semilla |
| Saqueo | Manos rápidas | Abrir cajas más rápido (necesita tiempo de apertura) |
| Base | Estación optimizada | Recargar en la estación repara +5 de durabilidad |
| Con contrapartida | Overvolt | +25% de daño, +20% de consumo pasivo |

## 6. Habilidades activas (v1.1): vienen de las piezas

Un solo botón abajo a la izquierda (SPECS §6.1) que muestra la habilidad de la pieza equipada. Cuestan batería y
tienen espera. Equipar otra pieza cambia la habilidad.

| Activa | Pieza que la da | Efecto (estimación) |
|---|---|---|
| Overclock | Core Overclockeado | Ver §6.1 |
| Impulso | Propulsores Iónicos (piernas) | Esquiva de ~3 m, ~3 de batería, espera ~6 s |
| Pulso EMP | Unos brazos (por definir) | Aturde en ~3 m durante ~2 s, ~10 de batería |
| Nadar | — | **Versión futura**: no hay zonas con agua |

Otras ideas de activas para piezas futuras: Escudo de chatarra (absorbe el siguiente golpe y cuesta chatarra, no
batería) y Ping (muestra ~10 s cajas sin abrir y enemigos fuera de cámara).

### 6.1 Overclock: regla única

La contradicción venía de mezclar dos modelos: un interruptor sin límite de tiempo (§6.2) y una duración fija
mejorable (§6.3 nivel 7, y la nota de SPECS §15.2, que decía que el Core Overclockeado "extiende su duración").
Como §15.2 ya daba por hecho que tiene duración, la regla lógica es la de **duración fija**:

| Aspecto | Regla |
|---|---|
| Efecto | +100% velocidad, +100% daño, ×3 consumo de batería |
| Duración | 10 s fijos |
| Fin anticipado | Se apaga solo si la batería baja del 10% (protege de morir por el ×3: la batería es la vida) o si el jugador lo cancela |
| Espera | 30 s, contados desde que se apaga, también si se apagó antes de tiempo |
| Degradación | -2 de durabilidad por segundo a las piezas equipadas mientras está activo |

Por qué duración fija y no interruptor: en el móvil un interruptor con ×3 de consumo invita a olvidarlo encendido,
y con la batería como vida eso es morir sin entender por qué. Una duración fija se lee con una barra y se
equilibra con dos números.

## 7. Ideas externas apuntadas

### 7.1 Repetidor de base (inspirado en el faro de Minecraft), v1.1

- Estructura de base construida con materiales; da **un efecto en un radio a elegir** (menos consumo pasivo,
  crafteo más rápido…). Más inversión en materiales, más potencia o radio.
- Encaja con la base libre (SPECS §32) y con el co-op en red local: el efecto lo comparten los que están cerca.

### 7.2 Mejoras de armas y armaduras (inspirado en los encantamientos), v1.1

- Mejoras que se aplican a una pieza o a un arma (SPECS §18) concreta, no al robot.
- En Minecraft Dungeons cada nivel da un punto para encantar y se recupera al desmontar la pieza.
- **Problema con nuestra muerte**: en Normal se pierde todo menos el Core. Mejoras pagadas con puntos de nivel en
  unos brazos se perderían al morir. Opciones:
  - Pagar las mejoras con **materiales** en el banco: perderlas es como perder la pieza, no progreso.
  - Recuperar parte al desmontar en el Reciclador (SPECS §3).

## 8. Lore de los recuerdos

Cada recuerdo es un **fragmento de memoria** del humano cuya consciencia lleva el robot, que vuelve al subir de
nivel. Une la progresión con el experimento fallido (SPECS §21). El Core es donde vive esa consciencia, por eso
los huecos están en él.

## 9. Encaje técnico (inferencia, a validar en el plan de la spec 016)

- Recuerdos como `StatModifier` con su propio origen, sumados a los de las piezas en `StatsComponent`
  (architecture §9.4): **dependen de la spec 015**.
- Los 7 recuerdos del PMV son solo modificadores: necesitan que `StatsComponent` exponga consumo pasivo, consumo
  de movimiento, velocidad, daño, coste de ataque, batería máxima y desgaste por golpe.
- El identificador en código va en inglés y se elige en el plan (evitar `Memory`, que se confunde con memoria del
  sistema).
- Datos en `.tres`: tabla de niveles (umbral, ranuras y recompensa: recuerdo o hueco), catálogo de recuerdos,
  huecos máximos por Core.
- Estado por jugador en un componente del robot (co-op). Se guardan los ids aprendidos e instalados (ver §3).
- XP por craftear y reparar: `EventBus.item_crafted` y `piece_repaired` ya existen. Vaciar un sitio de cajas no
  tiene evento todavía.

## 10. Pendiente

1. XP por craftear, reparar y vaciar un sitio: valores por definir; revisar la curva con `balance-auditor` y en una
   prueba en el juego.
2. Qué brazos dan el Pulso EMP.
3. Dinámica de v1.1: aleatorio o condicional.

## 11. Fuentes

- [LDOE Wiki – New Skills](https://last-day-on-earth-survival.fandom.com/wiki/New_Skills)
- [Slay the Spire: Player control](https://buymeacoffee.com/lunajavier/slay-spire-player-control)
- [PC Gamer – Project Zomboid traits](https://www.pcgamer.com/best-traits-project-zomboid)
- [Minecraft Wiki – Enchanting mechanics](https://minecraft.wiki/w/Enchantment_Mechanics)
- [Minecraft Wiki (fandom) – Beacon](https://minecraft.fandom.com/wiki/Beacon)
- [GameSpot – Minecraft Dungeons enchantment system](https://www.gamespot.com/articles/minecraft-dungeons-guide-how-the-enchantment-syste/1100-6477733/)
