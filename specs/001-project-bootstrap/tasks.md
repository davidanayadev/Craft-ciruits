# Tareas 001 — Proyecto Godot y arnés de desarrollo

> Orden de ejecución. Cada tarea deja el proyecto abriendo y los tests en verde. Marcar `[x]` al terminar.
> **(usuario)** = la hace el usuario en su máquina; Claude no instala software ni gestiona credenciales.

- [ ] **T-001-01 (usuario)** Instalar Godot 4.7.2 (estándar, no .NET) y definir la variable de entorno
  `GODOT_BIN` con la ruta del ejecutable. Verifica: `"$GODOT_BIN" --version` muestra `4.7.2`.
- [ ] **T-001-02 (usuario)** Instalar JDK 17 y Android SDK y configurarlos en *Editor Settings > Export >
  Android*. Verifica: el preset Android no muestra errores de configuración.
- [ ] **T-001-03** Crear rama `feat/001-project-bootstrap`, `.gitignore`, `.gitattributes`, `.editorconfig`.
  Cubre: R-001-12. Verifica: `git check-ignore game/.godot/x` lo ignora.
- [ ] **T-001-04** Verificar en la documentación de Godot 4.7 las claves marcadas **(verificar)** del plan §3 y
  anotar cualquier diferencia en el plan. Cubre: R-001-02/03/04/06. Verifica: plan actualizado.
- [ ] **T-001-05** Crear `game/project.godot` (nombre, renderer, pantalla, avisos), `icon.svg` y el árbol de
  carpetas. Cubre: R-001-01..06. Verifica: `"$GODOT_BIN" --headless --path game --import` sin errores.
- [ ] **T-001-06** Copiar GUT 9.7.1 (rama `godot_4_7`) a `game/addons/gut/`, activar el plugin y crear
  `.gutconfig.json`. Cubre: R-001-09. Verifica: un test vacío de ejemplo pasa desde la CLI.
- [ ] **T-001-07** Crear `tools/run_tests.sh`. Cubre: R-001-09. Verifica: sale con 0 en verde y ≠ 0 con un test
  roto a propósito (y se deshace).
- [ ] **T-001-08** Escribir `test_project_settings.gd` (rojo), comprobar que falla por la razón esperada, ajustar
  lo que falte hasta verde. Cubre: R-001-14 (02, 03, 06). Verifica: `tools/run_tests.sh`.
- [ ] **T-001-09** Añadir `i18n/strings.csv` (clave `APP_TITLE`), registrar traducciones y fallback, y su test.
  Cubre: R-001-07. Verifica: `test_r_001_07_*` en verde.
- [ ] **T-001-10** Escribir `test_input_map.gd` y definir las acciones en el InputMap. Cubre: R-001-08.
  Verifica: `test_r_001_08_*` en verde y el editor muestra las acciones.
- [ ] **T-001-11** Crear `export_presets.cfg` (Android debug con paquete `com.davidanaya.cyberscrap`, Windows Desktop) sin
  credenciales. Cubre: R-001-11, R-001-12. Verifica: export debug de ambos; `git status` limpio de builds.
- [ ] **T-001-12 (usuario + Claude)** Instalar el APK debug en un Android real. Verifica: arranca en retrato.
- [ ] **T-001-13** Crear `.github/workflows/ci.yml`. Cubre: R-001-10. Verifica: el PR muestra el check en verde.
- [ ] **T-001-14** Escribir `README.md`, actualizar `CLAUDE.md` (comandos y estado) y `.claude/settings.json`.
  Cubre: R-001-13. Verifica: seguir el README desde cero.

## Cierre

- [ ] Definición de hecho (constitución §4) revisada.
- [ ] Preguntas abiertas del spec cerradas o trasladadas a `PMV.md §10`.
- [ ] Estado del spec actualizado en `spec.md` y en `specs/README.md §6`.
