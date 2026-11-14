# ADR 0002 — Framework de tests: GUT 9.7.1

| Campo | Valor |
|---|---|
| **Estado** | Aceptada |
| **Fecha** | 2026-11-13 |

## Contexto

El proyecto fija Godot 4.7.2 (CLAUDE.md). La lógica pura (constitución P3, P13) necesita tests automáticos que
corran en local y en la CI sin pantalla. Los dos frameworks de GDScript maduros, consultados en nov 2026:

- **GUT** (bitwes/Gut): el README indica la **9.7.1, rama `godot_4_7`, para Godot 4.7.x**. La 9.7.0 avisa de un
  cambio: Godot 4.7 endureció la comprobación de tipos de retorno y los dobles devuelven un valor por defecto por
  tipo ([releases](https://github.com/bitwes/Gut/releases), [README](https://github.com/bitwes/Gut/blob/main/README.md)).
- **gdUnit4**: la estable 6.2.3 lista compatibilidad con Godot 4.5 a 4.7.1; la v7 (solo 4.7+) está en desarrollo
  y marcada inestable ([releases](https://github.com/godot-gdunit-labs/gdUnit4/releases),
  [issue #1354](https://github.com/godot-gdunit-labs/gdUnit4/issues/1354)).

## Decisión

**GUT 9.7.1** (rama `godot_4_7`), instalado como addon en `game/addons/gut/` y ejecutado en headless.

## Alternativas

| Opción | A favor | En contra |
|---|---|---|
| **GUT 9.7.1** (elegida) | Soporte declarado de 4.7.x en versión estable; simple; dobles y stubs; CLI headless; informe JUnit para la CI | Menos utilidades de escena que gdUnit4 |
| gdUnit4 6.2.3 | Scene runner, mocks, inspector en el editor, Action oficial | 4.7.2 no figura en su tabla; la línea para 4.7+ es inestable |

## Consecuencias

- Tests en `game/tests/unit/` (lógica pura, sin árbol de escena) y `game/tests/integration/` (escenas).
- Un fichero por clase bajo prueba: `test_<archivo>.gd`; métodos `test_r_nnn_xx_<caso>` para trazar al spec.
- Una guía de terceros probada con 4.7.2 + GUT 9.7.1 indica que en headless los clics sobre `Control` no llegan
  ([ziva.sh](https://ziva.sh/blogs/godot-gut-gdunit4-simulate-input)). Fuente única: tratarlo como provisional.
  Mitigación: la lógica de UI se testea por señales y métodos, no por clics simulados.
- El addon es código de terceros: no se edita a mano; se actualiza sustituyendo la carpeta completa.
- Revisar esta decisión si gdUnit4 v7 se estabiliza y se necesita su scene runner.
- Registrado también en `TOOLING.md §8`.
