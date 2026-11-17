# CyberScrap

Mobile (Android first) 3D isometric survival game built with Godot 4.7.2 and GDScript. You play a modular
robot whose pieces change its stats, degrade and break.

The design lives in the Spanish documents at the repo root (`PMV.md`, `BALANCE.md`, `ACTION_PLAN.md`,
`SPECS.md`, `ONLINE.md`, `TOOLING.md`). Code is written spec-first: see [specs/README.md](specs/README.md).

## Layout

| Path | Content |
|---|---|
| `game/` | The Godot project (`project.godot`). Every Godot command uses `--path game` |
| `game/tests/` | GUT tests: `unit/` (pure logic) and `integration/` (scenes) |
| `game/addons/gut/` | GUT 9.7.1, third-party. Never edited by hand: replace the whole folder to update |
| `game/i18n/strings.csv` | Translation keys (`keys,en,es`). Every player-visible string goes through it |
| `specs/` | Specs, plans, architecture and decisions (ADRs) |
| `tools/` | Development scripts |
| `builds/` | Exported builds. Not tracked |

## Setup

1. Install [Godot 4.7.2](https://godotengine.org/download/archive/) (standard build, not .NET).
2. Set the `GODOT_BIN` environment variable to the Godot executable. On Windows use the `_console.exe` one, so
   the output shows up in the terminal. Check it from Git Bash:

   ```bash
   "$GODOT_BIN" --version
   ```

3. Scripts in `tools/` are Bash. On Windows run them from Git Bash (it ships with Git for Windows).
4. Only to export: install the 4.7.2 export templates (*Editor > Manage Export Templates*), and for Android
   also a JDK (17 is the recommended one; 21 works too) and the Android SDK (*Editor Settings > Export >
   Android*).

## Commands

Run them from the repo root.

Open the editor:

```bash
"$GODOT_BIN" --editor --path game
```

Run the game on the desktop (a 960x540 landscape window):

```bash
"$GODOT_BIN" --path game
```

Run every test headless. Exits with a non-zero code if a test fails or if any project script fails to load
(`tools/check_scripts.gd`). It writes a JUnit report to `game/test_results.xml`:

```bash
tools/run_tests.sh
```

Re-import assets without opening the editor (the test script already does it):

```bash
"$GODOT_BIN" --headless --path game --import
```

Export a debug build. The presets are "Android" and "Windows Desktop"; the output goes to `builds/`, which
must exist:

```bash
mkdir -p builds/android builds/windows
```

```bash
"$GODOT_BIN" --headless --path game --export-debug "Android"
```

```bash
"$GODOT_BIN" --headless --path game --export-debug "Windows Desktop"
```

Install the debug APK on a phone connected with USB debugging enabled:

```bash
"$ANDROID_HOME/platform-tools/adb" install -r builds/android/cyberscrap-debug.apk
```

## PowerShell (Windows)

The same commands from PowerShell, run from the repo root. PowerShell 5.1 has no `&&`: run the lines one by one.

### Run

Point `GODOT_BIN` to the Godot executable. The first line sets it for this window only. The second saves it for
your user, so new windows have it too:

```powershell
$env:GODOT_BIN = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
[Environment]::SetEnvironmentVariable("GODOT_BIN", "C:\Godot\Godot_v4.7.2-stable_win64_console.exe", "User")
```

Open the editor, or run the game on the desktop:

```powershell
& $env:GODOT_BIN --editor --path game
& $env:GODOT_BIN --path game
```

Run every test. `tools/run_tests.sh` is Bash, so call Git's own `bash.exe` (a bare `bash` can resolve to WSL):

```powershell
& "$env:ProgramFiles\Git\bin\bash.exe" tools/run_tests.sh
```

Export the debug builds and install the APK on a phone with USB debugging enabled:

```powershell
New-Item -ItemType Directory -Force builds/android, builds/windows | Out-Null
& $env:GODOT_BIN --headless --path game --export-debug "Android"
& $env:GODOT_BIN --headless --path game --export-debug "Windows Desktop"
& "$env:ANDROID_HOME\platform-tools\adb.exe" install -r builds/android/cyberscrap-debug.apk
```

### Version

Start a spec on its own branch from an up-to-date `main` (never commit to `main`):

```powershell
git switch main
git pull
git switch -c feat/NNN-slug
```

Commit everything and push. `.gitignore` already keeps out `game/.godot/`, `builds/`, the test report and signing
files, but check `git status` before adding:

```powershell
git status
git add -A
git commit -m "feat(scope): what changed (spec NNN)"
git push -u origin feat/NNN-slug
```

Open the pull request to `main` with the [GitHub CLI](https://cli.github.com/), and once it is merged, go back to
`main` and delete the local branch:

```powershell
gh pr create --base main --fill
git switch main
git pull
git branch -d feat/NNN-slug
```

## Continuous integration

`.github/workflows/ci.yml` runs `tools/run_tests.sh` on Linux for every pull request to `main` and every push
to `main`, and uploads the JUnit report as an artifact.

## Conventions

- Static typing is enforced: an untyped declaration or an unsafe access is a script error
  (`debug/gdscript/warnings/*` in `project.godot`). The same applies to test scripts.
- Project settings that the specs fix (renderer, resolution, translations, input actions) are covered by
  tests in `game/tests/unit/`. If you change one in the editor on purpose, update its spec and test.
- Branches are `feat/NNN-slug`, one per spec, merged through a pull request. Conventional commits in English.
