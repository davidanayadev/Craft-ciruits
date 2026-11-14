# Plan 001 — Proyecto Godot y arnés de desarrollo

| Campo | Valor |
|---|---|
| **Spec** | [spec.md](spec.md) (debe estar *Aprobado*) |
| **Estado** | Planificado |

## 1. Enfoque

Configurar todo por texto versionado (`project.godot`, `export_presets.cfg`, `.gutconfig.json`, workflow) y
comprobarlo con tests que leen `ProjectSettings` e `InputMap`: si alguien cambia un ajuste crítico desde el
editor, un test falla (R-001-14). Un único script de tests (`tools/run_tests.sh`) sirve en local (Git Bash en
Windows) y en la CI (Linux), para no mantener dos.

Las claves de `project.godot` marcadas con **(verificar)** se comprueban contra la documentación de Godot 4.7
antes de escribirlas: no se da ninguna por buena de memoria.

## 2. Archivos

| Archivo | Nuevo / Cambia | Responsabilidad |
|---|---|---|
| `game/project.godot` | Nuevo | Nombre, renderer, pantalla, avisos de GDScript, traducciones, InputMap |
| `game/icon.svg` | Nuevo | Icono por defecto de Godot hasta tener el definitivo (6.1) |
| `game/{scenes,scripts,assets,resources}/…` | Nuevo | Árbol de PMV.md §4.2 con `.gitkeep` en carpetas vacías |
| `game/i18n/strings.csv` | Nuevo | Claves de traducción, columnas `keys,en,es` |
| `game/addons/gut/` | Nuevo (terceros) | GUT 9.7.1 de la rama `godot_4_7`, copiado tal cual |
| `game/.gutconfig.json` | Nuevo | Directorios de tests, prefijo, salida y código de salida |
| `game/tests/unit/test_project_settings.gd` | Nuevo | R-001-02, 03, 06, 07 |
| `game/tests/unit/test_input_map.gd` | Nuevo | R-001-08 |
| `game/export_presets.cfg` | Nuevo | Presets "Android" (debug, paquete `com.davidanaya.cyberscrap`) y "Windows Desktop" |
| `tools/run_tests.sh` | Nuevo | Importa y ejecuta GUT en headless; usa `$GODOT_BIN` (por defecto `godot`) |
| `.github/workflows/ci.yml` | Nuevo | Job Linux: descarga Godot 4.7.2, importa, ejecuta `tools/run_tests.sh`, publica el JUnit |
| `.gitignore` | Nuevo | `game/.godot/`, `builds/`, keystores, credenciales de export |
| `.gitattributes` | Nuevo | Finales de línea LF para texto (Godot y Git en Windows) |
| `.editorconfig` | Nuevo | Tabulador en `.gd`/`.tscn`/`.tres` (guía de estilo de GDScript), LF, UTF-8 |
| `README.md` | Nuevo | Requisitos, instalación y comandos |
| `CLAUDE.md` | Cambia | Sección de comandos reales; estado del repo |
| `.claude/settings.json` | Nuevo | Permiso para ejecutar `tools/run_tests.sh` sin confirmación |

## 3. Contratos

**`project.godot`** (valores; las claves exactas se verifican):

| Ajuste | Valor | Requisito |
|---|---|---|
| `application/config/name` | `"CyberScrap"` | R-001-01 |
| `rendering/renderer/rendering_method` y `.mobile` | `"gl_compatibility"` | R-001-02 |
| `rendering/textures/vram_compression/import_etc2_astc` | `true` (necesario para Android) **(verificar)** | R-001-11 |
| `display/window/size/viewport_width` / `viewport_height` | `1080` / `1920` | R-001-03 |
| `display/window/handheld/orientation` | retrato | R-001-03 |
| `display/window/stretch/mode` / `aspect` | `canvas_items` / `expand` | R-001-03, pregunta 2 |
| `display/window/size/window_width_override` / `window_height_override` | `540` / `960` (solo afecta a ventana de escritorio) **(verificar)** | R-001-04 |
| `debug/gdscript/warnings/untyped_declaration` | error | R-001-06 |
| `debug/gdscript/warnings/unsafe_property_access`, `unsafe_method_access`, `unsafe_call_argument` | error | R-001-06 |
| Exclusión de `addons/` de los avisos | activada, para que GUT no rompa la compilación **(verificar el mecanismo en 4.7)** | R-001-06 |
| `internationalization/locale/translations` | `strings.en.translation`, `strings.es.translation` | R-001-07 |
| `internationalization/locale/fallback` | `"en"` | R-001-07, pregunta 1 |

**InputMap** (R-001-08). Solo se fija el nombre de la acción y su tecla de PC; el táctil llega en spec 002:

| Acción | PC |
|---|---|
| `move_forward` / `move_back` / `move_left` / `move_right` | W/S/A/D y flechas |
| `run` | Shift izquierdo |
| `attack` | Espacio y clic izquierdo |
| `use_consumable` | Q |
| `interact` | E |
| `open_storage` | Tab |
| `pause` | Escape |

**`tools/run_tests.sh`**: `"$GODOT_BIN" --headless --path game --import` y después
`"$GODOT_BIN" --headless --path game -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json`.
Sale con el código de GUT. Opciones de GUT (`-gexit`, `-gjunit_xml_file`) **(verificar en el README de 9.7.1)**;
`--import` **(verificar en la ayuda de la CLI de 4.7)**.

**CI**: `ubuntu-latest`; Godot 4.7.2 Linux descargado de las releases oficiales de `godotengine/godot` con caché;
se ejecuta en `pull_request` a `main` y en `push` a `main`. Sin secretos.

## 4. Datos

Ninguno: esta feature no tiene valores de gameplay.

## 5. Verificación

| Requisito | Test o paso manual |
|---|---|
| R-001-01 | Manual: el editor 4.7.2 abre `game/` sin errores; `test_project_settings.gd::test_r_001_01_project_name` |
| R-001-02 | `test_project_settings.gd::test_r_001_02_compatibility_renderer` (lee el valor base y el override `.mobile`) |
| R-001-03 | `test_project_settings.gd::test_r_001_03_portrait_1080x1920_expand` |
| R-001-04 | Manual: ejecutar en Windows, la ventana abre a 540x960 |
| R-001-05 | Manual: revisión del árbol en el PR |
| R-001-06 | `test_project_settings.gd::test_r_001_06_typing_warnings_are_errors` + manual: un script sin tipar provoca error de carga |
| R-001-07 | `test_project_settings.gd::test_r_001_07_translations_es_en` (comprueba que `tr()` devuelve el texto ES y EN de una clave) |
| R-001-08 | `test_input_map.gd::test_r_001_08_actions_exist_with_keyboard_binding` (recorre la lista de acciones) |
| R-001-09 | Manual: romper un test a propósito → el script sale con código ≠ 0 |
| R-001-10 | Manual: PR de esta feature con el check verde; un commit con un test roto lo pone rojo |
| R-001-11 | Manual: exportar APK debug, instalar en Android real, arranca en retrato; exportar Windows y arrancar |
| R-001-12 | Manual: `git status` tras exportar no muestra builds ni credenciales |
| R-001-13 | Manual: seguir el README desde cero en esta máquina |

## 6. Check de constitución

| Principio | Cumple | Nota |
|---|---|---|
| P2 Una fuente de verdad | ✅ | La lista de acciones de `test_input_map.gd` duplica la del InputMap; es intencionado: el test es la especificación ejecutable de R-001-08 |
| P7 Tipado | ✅ | Lo hace cumplir R-001-06 |
| P8 Plataforma | ✅ | Presets Android y Windows; nada específico de plataforma en código |
| P10 Dependencias | ✅ | GitHub Actions está asignado al PMV en TOOLING.md §8; GUT se registra allí (ADR 0002) |
| P11 i18n | ✅ | Traducciones desde el primer commit |
| P13 Test primero | ✅ | Los ajustes críticos quedan cubiertos por tests |

## 7. Riesgos y alternativas descartadas

- **Avisos como error rompen GUT**: si la exclusión de `addons/` no existe o no funciona igual en 4.7, el addon
  no cargará. Mitigación: verificar el mecanismo antes; si no hay forma, poner los avisos en *warning* en la CI y
  documentarlo como ⚠️ en P7.
- **Clics en `Control` no funcionan en headless** (ADR 0002): no afecta a esta feature.
- **Android SDK/JDK sin instalar**: el preset existe pero no exporta. Es una tarea del usuario (T-001-02).
- **Descartado**: `chickensoft-games/setup-godot` en la CI. Funciona, pero descargar el binario oficial es un
  paso con menos dependencias de terceros; se reconsidera si la descarga manual da problemas.
- **Descartado**: dos scripts de tests (`.ps1` y `.sh`). Git Bash ya está en la máquina de desarrollo.
