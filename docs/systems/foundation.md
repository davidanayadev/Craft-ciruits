# Base del proyecto

> Configuración de Godot, InputMap, traducciones, arnés de tests, CI y exportación sobre los que se apoya todo lo
> demás. No contiene gameplay.
> Specs: [001](../../specs/001-project-bootstrap/spec.md) · Última actualización: spec 006 (backfill de la 001)

## Piezas

| Pieza | Tipo | Archivo | Responsabilidad |
|---|---|---|---|
| Ajustes de proyecto | config | `game/project.godot` | Renderer, pantalla, avisos como error, autoloads, InputMap, traducciones |
| Traducciones | datos | `game/i18n/strings.csv` | Claves `keys,en,es`; Godot lo importa a `strings.en.translation` y `strings.es.translation` |
| Arnés de tests | script | `tools/run_tests.sh` | Importa el proyecto, comprueba que cargan todos los scripts y ejecuta GUT |
| Comprobador de scripts | script | `tools/check_scripts.gd` | Sale con 1 si algún `.gd` del proyecto no carga |
| Config de GUT | config | `game/.gutconfig.json` | Directorios de tests, prefijo `test_`, informe JUnit |
| CI | workflow | `.github/workflows/ci.yml` | Ejecuta `tools/run_tests.sh` en Linux |
| Export presets | config | `game/export_presets.cfg` | Presets `Android` y `Windows Desktop` |
| GUT | addon | `game/addons/gut/` | Framework de tests de terceros; no se edita |

## Cómo funciona

1. **Proyecto**: `project.godot` vive en `game/` (ADR 0004). Escena principal `res://scenes/main.tscn`.
2. **Render y pantalla**: `gl_compatibility` también para móvil; viewport 1920x1080, `stretch/mode=canvas_items`,
   `aspect=expand`; orientación `4` (apaisado con sensor, ambas rotaciones). En PC la ventana se abre a 960x540
   (`window_width_override` / `window_height_override`).
3. **Avisos como error**: `untyped_declaration`, `unsafe_property_access`, `unsafe_method_access` y
   `unsafe_call_argument` valen `2` (error). Por eso un `Variant` no entra directo en un assert de GUT.
4. **InputMap**: acciones `move_forward/back/left/right` (WASD y flechas), `run` (Shift izq.), `attack` (Espacio y
   botón izquierdo), `use_consumable` (Q), `interact` (E), `open_storage` (Tab), `pause` (Esc). El gameplay lee
   solo acciones o `PlayerInput`, nunca teclas ([movement.md](movement.md)).
5. **i18n**: `strings.csv` tiene una fila por clave; `locale/translations` apunta a los dos `.translation`
   generados. Si el idioma del dispositivo no es ES ni EN, se usa inglés (fallback por defecto de Godot). El texto
   visible va siempre por `tr()` sobre una clave de este CSV.
6. **Tests** (`tools/run_tests.sh`): (a) `--import` para crear `.godot/`, (b) `check_scripts.gd` recorre `res://`
   salvo `addons` y `.godot` y falla si un script no se puede instanciar, (c) GUT con `.gutconfig.json`. Los pasos
   (b) y (c) se ejecutan siempre; el código de salida es distinto de 0 si falla alguno.
7. **CI**: en PR a `main` y push a `main`, descarga Godot 4.7.2 (con caché), define `GODOT_BIN`, ejecuta el script y
   sube `game/test_results.xml` como artefacto.
8. **Exportación**: `Android` (APK debug a `builds/android/`, paquete `com.davidanaya.cyberscrap`) y
   `Windows Desktop` (x86_64, `builds/windows/`). `builds/`, keystores y `export_credentials.cfg` están en
   `.gitignore` (R-001-12).

## Datos

Sin `.tres` propios. Los valores de pantalla y orientación son de plataforma, no de balance.

## Decisiones

| Decisión | Por qué | Fuente |
|---|---|---|
| Una base de código; Android es el producto, Windows solo desarrollo | Iterar en PC sin exportar cada vez | [ADR 0001](../../specs/decisions/0001-single-codebase-pc-dev-android-product.md) |
| GUT 9.7.1 como framework de tests | Soporte declarado de Godot 4.7.x en versión estable | [ADR 0002](../../specs/decisions/0002-test-framework-gut.md) |
| SDD propio y ligero (spec, plan, tasks) | Decisiones cerradas antes de programar, sin dependencias | [ADR 0003](../../specs/decisions/0003-lightweight-sdd.md) |
| El proyecto Godot en `game/` | Que docs, CI y config de Claude no entren en `res://` | [ADR 0004](../../specs/decisions/0004-repo-layout-game-subfolder.md) |
| Script de comprobación aparte de GUT | GUT sale con 0 si un script no compila | `tools/check_scripts.gd` (R-001-09) |
| Orientación apaisada | Enmienda del 2026-11-14 (antes retrato) | [plan 001 §3](../../specs/001-project-bootstrap/plan.md) |
| Sin linter externo; el tipado lo exigen los avisos de Godot | R-001-06 | [spec 001](../../specs/001-project-bootstrap/spec.md) |

## Relación con otros sistemas

Todos los sistemas dependen de estos ajustes. Autoloads registrados: ver [data_catalog.md](data_catalog.md).
Los ajustes fijados por una spec los vigilan `test_project_settings.gd` y `test_input_map.gd`.

## Trampas y límites

- `game/addons/gut/` es de terceros: se actualiza reemplazando la carpeta entera.
- `unsafe_call_argument` es error: asignar el `Variant` a una variable tipada antes de usarlo en un assert.
- `check_scripts.gd` comprueba la carga en `_initialize()` y no en `_init()`, porque los autoloads se registran
  después de `_init()`.
- Un `.gd` que no compila pasa GUT con aviso y solo lo detecta `check_scripts.gd`.
- `test_project_settings.gd` también vigila ajustes de specs posteriores (autoloads, capa de física `interaction`,
  `quit_on_go_back=false`).
- Solo vale la medición de rendimiento en Android real; el PC es un entorno de desarrollo (ADR 0001).

## Cómo extenderlo

- **Nueva acción de input**: añadirla en `project.godot` (InputMap) y en `test_input_map.gd`.
- **Nueva cadena de texto**: añadir una fila ES+EN a `strings.csv` y reimportar (`--import`).
- **Nueva carpeta de tests**: añadirla a `dirs` en `.gutconfig.json`.
- **Nueva plataforma**: preset en `export_presets.cfg` y decisión previa en `PMV.md` (ADR 0001).

## Tests

| Archivo | Verifica |
|---|---|
| `game/tests/unit/test_project_settings.gd` | Nombre, escena principal, renderer, 1920x1080 expand, avisos, traducciones y fallback |
| `game/tests/unit/test_input_map.gd` | Cada acción existe y tiene tecla de teclado |
