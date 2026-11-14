#!/usr/bin/env bash
# Runs every GUT test headless. Exits with 0 only if every project script
# loads and every test passes. Used both locally (Git Bash on Windows) and by
# the CI (Linux).
# Usage: tools/run_tests.sh
set -uo pipefail

GODOT_BIN="${GODOT_BIN:-godot}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_dir="$repo_root/game"

# A clean checkout has no .godot/ cache: without the import step, class_name
# lookups and imported resources (translations) are missing when the tests run.
"$GODOT_BIN" --headless --path "$project_dir" --import || exit $?

# Both checks always run, so one pass reports every failure.
status=0

# GUT exits with 0 when a script does not compile (it only warns), so script
# loading is checked on its own.
"$GODOT_BIN" --headless --path "$project_dir" -s "$repo_root/tools/check_scripts.gd" || status=$?

"$GODOT_BIN" --headless --path "$project_dir" \
	-s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json || status=$?

exit "$status"
