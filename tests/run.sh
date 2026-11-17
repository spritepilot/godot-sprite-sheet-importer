#!/usr/bin/env bash
# Runs every check: the converter tests, then the right-click command inside a
# real (headless) editor. Needs Godot 4.4+ as `godot` on PATH (or set GODOT).
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path . --import >/dev/null 2>&1
"$GODOT" --headless --path . --script res://tests/run_tests.gd

cp project.godot /tmp/spritepilot-project.godot
trap 'cp /tmp/spritepilot-project.godot project.godot; rm -f demo/hero.tres' EXIT
sed -i.bak 's#enabled=PackedStringArray("res://addons/spritepilot_importer/plugin.cfg")#enabled=PackedStringArray("res://addons/spritepilot_importer/plugin.cfg", "res://tests/editor_check/plugin.cfg")#' project.godot && rm -f project.godot.bak
out="$("$GODOT" --headless --editor --path . 2>&1 || true)"
echo "$out" | grep -E "EDITOR_CHECK|SCRIPT ERROR" || true
echo "$out" | grep -q "EDITOR_CHECK PASS"
find tests/fixtures -name "sprite-sheet.tres" -delete
rm -rf tests/fixtures/errors
echo "All checks passed."
