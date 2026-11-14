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

Las claves de `project.godot` marcadas con **(verificado)** se comprobaron contra la documentación de Godot 4.7
antes de escribirlas (T-001-04, resultado en §3): no se da ninguna por buena de memoria.

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
| `tools/run_tests.sh` | Nuevo | Importa, comprueba que los scripts cargan y ejecuta GUT en headless; usa `$GODOT_BIN` (por defecto `godot`) |
| `tools/check_scripts.gd` | Nuevo | Sale con 1 si algún `.gd` fuera de `addons/` no carga (R-001-09) |
| `game/scenes/main.tscn` | Nuevo | Escena principal provisional: nodo raíz `Main` vacío, para que el proyecto arranque (R-001-04, R-001-11) |
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
| `application/run/main_scene` | `"res://scenes/main.tscn"` (el editor lo cambiará por su UID cuando guarde la escena) | R-001-04, R-001-11 |
| `rendering/renderer/rendering_method` y `.mobile` | `"gl_compatibility"` | R-001-02 |
| `rendering/textures/vram_compression/import_etc2_astc` | `true` (necesario para Android) **(verificado)** | R-001-11 |
| `display/window/size/viewport_width` / `viewport_height` | `1080` / `1920` | R-001-03 |
| `display/window/handheld/orientation` | `1` (retrato, `DisplayServer.SCREEN_PORTRAIT`) **(verificado)** | R-001-03 |
| `display/window/stretch/mode` / `aspect` | `canvas_items` / `expand` | R-001-03, pregunta 2 |
| `display/window/size/window_width_override` / `window_height_override` | `540` / `960` (solo afecta a ventana de escritorio) **(verificado)** | R-001-04 |
| `debug/gdscript/warnings/untyped_declaration` | `2` (error) **(verificado)** | R-001-06 |
| `debug/gdscript/warnings/unsafe_property_access`, `unsafe_method_access`, `unsafe_call_argument` | `2` (error) **(verificado)** | R-001-06 |
| `debug/gdscript/warnings/directory_rules` | `{ "res://addons": 0 }` (`0` = *Exclude*). Es el valor por defecto de 4.7: excluye `addons/` de los avisos, para que GUT no rompa la compilación **(verificado)** | R-001-06 |
| `internationalization/locale/translations` | `strings.en.translation`, `strings.es.translation` | R-001-07 |
| `internationalization/locale/fallback` | `"en"` | R-001-07, pregunta 1 |

**Verificación de claves (T-001-04, 2026-11-14).** Fuentes: referencia de `ProjectSettings` de Godot 4.7
(docs.godotengine.org/en/4.7), `--doctool` y `ProjectSettings.get_property_list()` del binario 4.7.2, y la ayuda
de la CLI. Diferencias respecto al plan original:

- **`exclude_addons` ya no existe.** Lo sustituye `directory_rules` (diccionario ruta → *Exclude* `0` /
  *Include* `1`), que por defecto ya excluye `res://addons`. No hay que escribir nada en `project.godot`; el test
  de R-001-06 comprueba que la regla sigue ahí. El riesgo de §7 "avisos como error rompen GUT" queda mitigado.
- **Niveles de aviso**: enteros `0` *Ignore*, `1` *Warn*, `2` *Error*. En `project.godot` se escribe `2`.
- **`window_*_override`**: la documentación dice "On desktop platforms" e "ignored on iOS, Android, and Web".
- **`import_etc2_astc`**: existe (bool, por defecto `false`).
- **`stretch/mode` y `stretch/aspect`**: valores válidos confirmados; `canvas_items` y `expand` son además los
  valores con los que 4.7 crea los proyectos nuevos.
- **`internationalization/locale/translations`**: no aparece en la referencia online, pero el motor la registra
  (`PackedStringArray`). `fallback` existe y su valor por defecto ya es `"en"`.
- **`editor_plugins/enabled`** (activar GUT, T-001-06): no está en la referencia ni registrada por defecto; es la
  clave que escribe el editor al activar un plugin. Se comprueba en T-001-06 ejecutando GUT.

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

**`tools/run_tests.sh`**: tres pasos, cada uno un arranque headless con `--path game`:

1. `--import`.
2. `-s tools/check_scripts.gd`: carga cada `.gd` del proyecto fuera de `addons/` y sale con 1 si alguno no
   carga.
3. `-s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json`.

Los pasos 2 y 3 se ejecutan siempre (para ver todos los fallos de una vez) y el script sale con ≠ 0 si
cualquiera de los dos falla. Opciones de GUT (`-gexit`, `-gjunit_xml_file`, `-gconfig`) **(verificadas en la
documentación de la CLI de GUT: sale con 0 si todo pasa y 1 si algo falla)**; `--import` **(verificado en
`--help` de 4.7.2)**. Las claves JSON de `.gutconfig.json` salen de `-gprint_gutconfig_sample` (T-001-06).

**Cambio aprobado (2026-11-14): paso 2.** GUT 9.7.1 no cubre "any script fails to load" de R-001-09: un script
de test que no compila solo genera un aviso ("Ignoring script…", o "Nothing was run" si era el único) y GUT
sale con 0. Un script de producción sin test tampoco se cargaría nunca. `check_scripts.gd` cierra ese hueco con
`GDScript.can_instantiate()`, que devuelve `false` si el script tiene errores (comprobado en 4.7.2; devuelve
`true` para clases `@abstract`). Descartado: buscar `SCRIPT ERROR` en la salida (depende del texto y no ve los
scripts sin test).

**Cambio aprobado (2026-11-14): escena principal provisional.** Sin `application/run/main_scene` el proyecto
no arranca ("no main scene defined") y R-001-04 y R-001-11 no se pueden verificar. Se añade
`game/scenes/main.tscn` con un único nodo raíz `Main` (`Node`, sin script), que es la raíz que describe
`architecture.md` §6; el spec 002 la rellena. Lo cubre `test_r_001_01_main_scene_exists`.

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
| R-001-09 | Manual: romper un test a propósito → el script sale con código ≠ 0; añadir un script que no compila (de test y de producción) → sale con código ≠ 0 |
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
