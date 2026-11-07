#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export XDG_DATA_HOME="$PWD/.runtime/test-data"
export XDG_CACHE_HOME="$PWD/.runtime/cache"
export XDG_CONFIG_HOME="$PWD/.runtime/config"
mkdir -p "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"
python3 tools/art/check_assets.py
godot --headless --path godot --editor --import --quit > .runtime/import.log 2>&1
if rg 'SCRIPT ERROR|Parse Error|Compile Error' .runtime/import.log; then exit 1; fi
godot --headless --path godot --script tests/test_hospital.gd 2>&1 | tee .runtime/simulation.log
if rg 'SCRIPT ERROR|ERROR:|FAIL:' .runtime/simulation.log; then exit 1; fi
rg -q 'SIMULATION: [1-9][0-9]* checks, 0 failures' .runtime/simulation.log
# Animation/occupancy/save integration also runs without a display. It uses
# the actual imported meshes and an isolated --qa game, never player saves.
godot --headless --path godot --script tests/test_motion.gd -- --qa 2>&1 | tee .runtime/motion.log
if rg 'SCRIPT ERROR|ERROR:|FAIL:' .runtime/motion.log; then exit 1; fi
python3 - <<'PY'
import json
with open('artifacts/motion-unit/results.json') as f:
    result=json.load(f)
assert result['passed'] and not result['geometry_contacts'], result
PY
godot --headless --path godot --script tests/test_story.gd -- --qa --tutorial 2>&1 | tee .runtime/story.log
if rg 'SCRIPT ERROR|ERROR:|FAIL:' .runtime/story.log; then exit 1; fi
python3 - <<'PY'
import json
with open('artifacts/story-unit/results.json') as f:
    assert json.load(f)['passed']
PY

godot --headless --path godot --script tests/test_first_day_polish.gd -- --qa --tutorial 2>&1 | tee .runtime/first-day-polish.log
if rg 'SCRIPT ERROR|ERROR:|FAIL:' .runtime/first-day-polish.log; then exit 1; fi
python3 - <<'PYTEST'
import json
with open('artifacts/first-day-polish-unit/results.json') as f:
    assert json.load(f)['passed']
PYTEST

godot --headless --path godot --script tests/test_staff_admission.gd -- --qa --tutorial 2>&1 | tee .runtime/staff-unit.log
if rg 'SCRIPT ERROR|ERROR:|FAIL:' .runtime/staff-unit.log; then exit 1; fi
python3 - <<'PYTEST'
import json
with open('artifacts/staff-unit/results.json') as f:
    assert json.load(f)['passed']
PYTEST
