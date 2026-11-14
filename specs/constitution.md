# Constitución técnica — CyberScrap

> Principios no negociables del código. Cada `plan.md` se revisa contra esta lista (sección "Check de
> constitución"). Una violación solo se acepta justificada en el plan; si se repite, se cambia la constitución
> con un ADR.
>
> Este documento **no repite** el diseño: remite a la fuente de verdad de cada área (tabla de CLAUDE.md
> "Which document owns what").

**Versión**: 1.0 · **Fecha**: 2026-11-13

---

## 1. Principios

### P1. Spec primero
Ningún código de producción sin `spec.md` *Aprobado* y `plan.md` *Planificado* (excepciones en
[README §2](README.md#2-flujo)). El código implementa el spec; si el código necesita algo que el spec no dice, se
para y se actualiza el spec.

### P2. Una fuente de verdad (DRY)
- Alcance: `PMV.md §2`. Lo de `§2.3` o marcado v1.1+ en `SPECS.md` no se implementa en el PMV.
- Números de juego: `BALANCE.md` → recursos `.tres`. **Cero literales de gameplay en scripts.**
- Un mismo dato no se define en dos sitios: se deriva o se referencia.
- La lógica duplicada es un bug. Se abstrae a la **tercera** repetición clara, no a la primera.

### P3. Lógica separada de la presentación
- Reglas de juego en código sin dependencia de escena: `scripts/systems/` (clases `RefCounted` o estáticas) y
  métodos de componentes que reciben sus entradas por parámetro (por ejemplo `delta`), para poder testearlos
  sin árbol de escena.
- Escenas y nodos: entrada, presentación y cableado de señales. Una escena = una responsabilidad.

### P4. Estado por jugador en componentes
Batería, inventario, piezas y XP viven en componentes de la entidad del jugador. Los autoloads solo guardan
estado global de la partida (PMV.md §4.5 gancho 7). Condición para el cooperativo de v2.0.

### P5. Datos como recursos
`ItemData`, `PieceData`, `EnemyData`, `MaterialData`, `RecipeData`, `RulesetData`, `ChassisLevelData` y los que
añadan los specs: `extends Resource`, con `class_name`, instancias `.tres` en `resources/`.

### P6. Comunicación por señales
- Lo transversal va por señales; sistemas no relacionados nunca se llaman directamente.
- Señales en pasado o como evento (`battery_depleted`, `level_up`), con argumentos tipados.
- Prohibido `get_node()` / `$` con rutas largas hardcodeadas: `%UniqueName` o `@export`.

### P7. Tipado estático estricto
- Todo tipado: variables, parámetros, retornos, arrays (`Array[ItemData]`).
- Los avisos de GDScript que detectan código sin tipar o inseguro se configuran como **error** en
  `project.godot` (spec 001). No se bajan para que algo compile.

### P8. Independiente de la plataforma
Un solo código para Android (producto) y PC (desarrollo) (ADR 0001).
- El gameplay lee **acciones de InputMap** o una abstracción de input, nunca `InputEventScreenTouch` ni teclas.
- Nada de `OS.has_feature()` ni `OS.get_name()` en gameplay. Las diferencias de plataforma viven solo en la capa
  de input/UI y en overrides de `project.godot` por feature tag.
- El renderer es Compatibility en las dos plataformas, para que el PC enseñe lo mismo que el móvil.

### P9. Determinismo con semilla
Toda generación usa un `RandomNumberGenerator` sembrado con `semilla del mundo + zone_id`; nunca `randf()` /
`randi()` globales en generación. Posiciones persistidas como `(zone_id, posición local)` (PMV.md §4.5 ganchos
2-3).

### P10. Servicios detrás de una clase base
Guardado, tiempo, tienda y (más adelante) online: contrato en una clase base y una implementación local. Solo
`OnlineManager` hablará con un backend (ONLINE.md "Preparación del código desde el PMV"). Ninguna dependencia
externa antes de la fase que le asigna `TOOLING.md`.

### P11. i18n desde el día uno
Todo texto visible por el jugador pasa por `tr()` / claves de traducción (ES + EN). Cero strings visibles
hardcodeados.

### P12. Presupuesto móvil
Respetar PMV.md §3.2 (triángulos, luces, sombras, sin post-procesado pesado). Enemigos, proyectiles y partículas
con object pooling desde su primera versión. El rendimiento solo se da por bueno medido en un Android real; los
FPS del PC no cuentan.

### P13. Test primero en la lógica
- La lógica pura se escribe con su test antes o a la vez (GUT, ADR 0002).
- Cada requisito EARS tiene al menos un test o un paso de verificación manual escrito en el plan.
- Tests deterministas: sin dependencias de tiempo real ni RNG sin semilla.
- Nunca se debilita, salta ni borra un test para pasar la CI.

### P14. Disciplina de alcance
Hacer lo que dice el spec, nada más. Refactors, renombres o mejoras "de paso" requieren aprobación y, si son
grandes, su propio spec. El scope creep está identificado como riesgo alto (PMV.md §5.3).

---

## 2. Estilo de código

Se sigue la [guía de estilo oficial de GDScript](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
(orden de miembros, nombres, formato). Decisiones propias encima de la guía:

| Tema | Regla |
|---|---|
| Archivos | `snake_case`: `battery_component.gd`, `robot.tscn`. Evita fallos por mayúsculas/minúsculas en Android, que distingue y Windows no. Los nombres de ACTION_PLAN (`BatteryComponent.gd`, `Robot.tscn`) se leen como nombre de clase/escena |
| Clases | `class_name` en `PascalCase`, una por archivo. Contratos con prefijo `I` (`IStore`), como en ONLINE.md |
| Privado | Prefijo `_` para miembros que no forman parte del contrato |
| Funciones | Una responsabilidad, objetivo < 20 líneas (PMV.md §4.1) |
| Comentarios | En inglés, explican el **porqué**. Docstrings `##` en clases y métodos públicos |
| Errores | Nada de fallos silenciosos: `push_error()` con contexto y retorno explícito; `assert()` para invariantes de desarrollo |
| Código muerto | Ni bloques comentados, ni `print()` de depuración, ni `TODO` sin spec |

La estructura del código (capas, autoloads, flujo de escenas, patrones comunes y preparación para servidor) está
en [architecture.md](architecture.md). Todo plan la cita y la respeta.

## 3. Estructura del repositorio

ADR [0004](decisions/0004-repo-layout-game-subfolder.md): el proyecto Godot vive en `game/`; dentro, la
estructura de PMV.md §4.2 más `tests/` (unit e integration) y `addons/gut/`.

## 4. Definición de hecho (por feature)

- [ ] Todos los requisitos del spec verificados (test automático o paso manual documentado).
- [ ] Tests nuevos y existentes en verde en local y en la CI.
- [ ] Proyecto abre sin errores ni avisos nuevos en el editor.
- [ ] Sin literales de gameplay; textos visibles traducidos (ES + EN).
- [ ] Probado en PC; si toca input, rendimiento o UI, probado también en Android (APK debug).
- [ ] `tasks.md` marcado, estado del spec actualizado, preguntas abiertas cerradas o trasladadas a `PMV.md §10`.
- [ ] Diff revisado: un cambio lógico por commit, sin archivos ajenos.

## 5. Gobierno

- Cambiar esta constitución requiere un ADR en `decisions/` y subir la versión.
- En caso de conflicto: documento de producto dueño del área > constitución > plan > código.
