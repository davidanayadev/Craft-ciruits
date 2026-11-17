# Subagentes — CyberScrap

> Qué subagentes hay, cuándo usar cada uno y cuándo no, para gastar menos sin perder calidad.
> Las reglas cortas para Claude están en `CLAUDE.md` ("Subagents"); este documento es la explicación completa.
> Definiciones: `.claude/agents/*.md` (proyecto) y `~/.claude/agents/*.md` (global).

## 1. Cuándo compensa un subagente

Un subagente arranca **sin el contexto de la conversación**: solo con su prompt, el `CLAUDE.md` y lo que le pases.
Todo lo que necesite saber lo tiene que volver a leer, y eso cuesta tokens. Compensa en tres casos:

| Caso | Por qué ahorra o mejora | Ejemplo |
|---|---|---|
| **Salida grande, resumen pequeño** | Los logs y las búsquedas no llenan la sesión principal; vuelve un resumen | Pasar los tests, auditar todo el proyecto |
| **Modelo más barato para trabajo mecánico** | Haiku o Sonnet hacen el trabajo; Opus solo lee el resultado | Revisar claves de traducción |
| **Ojos frescos** | Quien no escribió el código no arrastra sus supuestos | Revisión de arquitectura antes del PR |

**No compensa:**
- Para tareas de 1–3 llamadas (leer un archivo, un grep, una edición): el arranque cuesta más que la tarea.
- Cuando la tarea necesita lo que ya sabe la sesión principal (por ejemplo, el mensaje de un commit: la sesión
  sabe *por qué* cambió el código; un subagente tendría que adivinarlo desde el diff).
- Para repetir un trabajo que ya hizo otro subagente: se reutiliza su informe.

Otras reglas de gasto:
- Los agentes de **Opus / high** (`architecture-guardian`, `deep-debugger`) se usan en las puertas del flujo, no
  después de cada cambio.
- Varios auditores de solo lectura se pueden lanzar **en paralelo**: no se pisan.
- Cada subagente carga el `CLAUDE.md` del proyecto y el global. Mantenerlos cortos abarata cada invocación.
- La sesión principal puede ir en Sonnet para implementación rutinaria y en Opus para diseño: cada subagente usa
  el modelo de su definición, sea cual sea el de la sesión.

## 2. Subagentes del proyecto

| Agente | Modelo / esfuerzo | Puede editar | Para qué |
|---|---|---|---|
| `godot-runner` | Haiku / low | No | Pasar los tests, exportar o leer un fallo de la CI y devolver un resumen corto |
| `gut-test-writer` | Sonnet / medium | Solo `game/tests/` | Escribir los tests GUT de un spec a partir de sus requisitos EARS |
| `i18n-auditor` | Haiku / low | No | Textos visibles sin traducir y claves que faltan, vacías o sin usar |
| `balance-auditor` | Sonnet / medium | No | `.tres` contra `BALANCE.md` y literales de gameplay en scripts |
| `architecture-guardian` | Opus / high | No | Revisar un diff o un `plan.md` contra la constitución, la arquitectura y el alcance |
| `system-documenter` | Sonnet / medium | Solo `docs/systems/` | Documentación de sistemas: cómo funciona hoy el código y por qué |

### `godot-runner`
- **Cuándo:** al terminar cada tarea de `tasks.md`, antes de dar algo por hecho, cuando falla la CI
  (`gh run view --log-failed`), para una exportación de debug.
- **Cuándo no:** cuando estás iterando sobre un solo test y necesitas el log completo; ahí es más directo pasarlo
  en la sesión principal.
- **Ojo:** no arregla nada. Si su resumen no basta para entender el fallo, se lee `game/test_results.xml` o se
  repite el comando en la sesión principal.

### `gut-test-writer`
- **Cuándo:** en `/sdd-implement`, en el paso de test primero (constitución P13), cuando una tarea cubre varios
  requisitos o casos borde. Pásale el número de spec y los IDs (`R-005-01..04` o `T-005-03`).
- **Cuándo no:** para un test de una línea o para retocar un test existente; es más barato en la sesión principal.
- **Ojo:** escribe a partir del spec y del contrato público, no de la implementación. Si el plan no define el
  contrato, para y lo dice en lugar de inventarlo.

### `i18n-auditor`
- **Cuándo:** al cerrar un spec (Definición de hecho) y después de añadir UI, ítems o textos de interacción.
- **Cuándo no:** después de cada cambio pequeño.

### `balance-auditor`
- **Cuándo:** cuando un spec añade o cambia recursos `.tres`, al cerrar un spec y cuando cambia `BALANCE.md`
  (ACTION_PLAN Tarea 5.2).
- **Ojo:** informa de las diferencias, pero no decide quién tiene razón: `BALANCE.md` se cambia primero y se
  discute en el chat.

### `architecture-guardian`
- **Cuándo:** una vez antes de abrir el PR de un spec, y con `plan NNN` antes de pasar un plan a *Planificado*.
- **Cuándo no:** después de cada commit, ni para buscar bugs genéricos (para eso está `/code-review`).

### `system-documenter`
- **Cuándo:** al cerrar un spec, con `spec NNN`: actualiza solo las páginas de los sistemas que tocó ese spec.
- **Cuándo no:** durante la implementación (el código aún cambia) ni para cambios pequeños fuera de un spec.
- **Por qué Sonnet y no Haiku:** explicar el porqué exige cruzar spec, plan y código; Haiku tiende a parafrasear
  y a rellenar huecos. El gasto se acota porque solo toca los sistemas del spec que se cierra.
- **Ojo:** si el porqué no está escrito en ninguna fuente, pone "Sin documentar" en lugar de inventarlo. Las
  discrepancias entre código y spec las informa; no las arregla.

## 3. Subagente global

| Agente | Modelo / esfuerzo | Puede editar | Para qué |
|---|---|---|---|
| `deep-debugger` | Opus / high | No | Encontrar la causa raíz de un bug difícil con evidencia |

- **Cuándo:** el primer intento de arreglo falló, el bug es intermitente o la traza no señala la causa.
- **Cuándo no:** si el error y su causa están claros en el mensaje; arreglarlo en la sesión principal es más barato.
- No toca el repositorio ni el estado de git. Devuelve la causa, la evidencia y un arreglo propuesto, que aplica la
  sesión principal.

## 4. Subagentes y skills integrados de Claude Code

| Nombre | Tipo | Para qué | Notas de coste |
|---|---|---|---|
| `Explore` | Subagente, solo lectura | Búsquedas amplias: "¿dónde se usa X?", "¿qué archivos tocan Y?" | Modelo de clase Haiku según la documentación. Localiza código pero no lo revisa: lee fragmentos, no archivos enteros |
| `Plan` | Subagente, solo lectura | Proponer un plan de implementación con archivos y riesgos | En este proyecto el plan lo hace `/sdd-plan`; `Plan` sirve para explorar alternativas antes |
| `general-purpose` | Subagente, todas las herramientas | Tareas de varios pasos que no encajan en otro agente | Usa el modelo de la sesión principal: no ahorra por modelo, solo por contexto |
| `claude-code-guide` | Subagente | Dudas sobre Claude Code, hooks, settings, subagentes, la API | Consulta la documentación oficial en lugar de responder de memoria |
| fork | Copia de la sesión | Tarea en segundo plano que necesita todo el contexto de la conversación | Mismo modelo que la sesión y hereda todo el contexto: es caro en conversaciones largas |
| `/code-review` | Skill | Buscar bugs en el diff | Tiene niveles de esfuerzo; `max` y `ultra` lanzan muchos revisores y son los más caros |
| `/security-review` | Skill | Revisión de seguridad de los cambios de la rama | Útil cuando lleguen guardado cifrado (spec 010), tienda u online |
| `/simplify` | Skill | Limpieza: reutilización, simplificación, eficiencia | No busca bugs |

## 5. Uso en el flujo SDD

Las skills `/sdd-spec`, `/sdd-plan` y `/sdd-implement` ya invocan estos agentes en los puntos de la tabla.

| Fase | Qué usar |
|---|---|
| `/sdd-spec` | Sesión principal (Opus). `Explore` si hay que localizar código existente |
| `/sdd-plan` | Sesión principal. Antes de la puerta: `architecture-guardian plan NNN` |
| `/sdd-implement`, por tarea | `gut-test-writer` (test primero) → sesión principal implementa → `godot-runner` |
| Bug que no cede | `deep-debugger` |
| Definición de hecho | En paralelo: `godot-runner`, `i18n-auditor`, `balance-auditor`. Después, una vez: `architecture-guardian` |
| Cierre del spec | `system-documenter spec NNN` |
| Antes del PR | `/code-review` (nivel bajo o medio) si el cambio es grande |
| Commit y PR | Sesión principal |

## 6. Mantenimiento

- La documentación de sistemas vive en `docs/systems/`; su `README.md` define qué contiene cada página.
- Campos del frontmatter usados: `name`, `description`, `tools`, `model`, `effort`, `color`. La `description` es lo
  que Claude lee para decidir cuándo delegar: corta y concreta.
- Los cambios en archivos existentes se detectan en caliente. Una carpeta `agents/` nueva necesita reiniciar la
  sesión.
- Un agente del proyecto con el mismo `name` que uno global gana sobre el global.
- Claude puede cambiar el modelo de un subagente en una invocación concreta; el `model` del archivo es el valor
  por defecto.
- Si un agente da resultados flojos con Haiku, se sube a Sonnet en su archivo antes de crear otro agente.
