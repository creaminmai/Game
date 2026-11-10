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

godot --headless --path godot --script tests/test_chapters.gd -- --qa --tutorial 2>&1 | tee .runtime/chapters.log
if rg 'SCRIPT ERROR|ERROR:|FAIL:' .runtime/chapters.log; then exit 1; fi
python3 - <<'PYTEST'
import json
with open('artifacts/chapter-unit/results.json') as f:
    assert json.load(f)['passed']
PYTEST

godot --headless --path godot --script tests/test_operations.gd -- --qa --tutorial 2>&1 | tee .runtime/operations-unit.log
if rg 'SCRIPT ERROR|ERROR:|FAIL:' .runtime/operations-unit.log; then exit 1; fi
python3 - <<'PYTEST'
import json
with open('artifacts/operations-unit/results.json') as f:
    assert json.load(f)['passed']
PYTEST

godot --headless --path godot --script tests/test_research.gd 2>&1 | tee .runtime/research-unit.log
if rg 'SCRIPT ERROR|ERROR:|FAIL:' .runtime/research-unit.log; then exit 1; fi
python3 - <<'PYTEST'
import json
with open('artifacts/research-unit/results.json') as f:
    assert json.load(f)['passed']
PYTEST

godot --headless --path godot --script tests/test_research_motion.gd -- --qa 2>&1 | tee .runtime/research-motion.log
if rg 'SCRIPT ERROR|ERROR:|FAIL:' .runtime/research-motion.log; then exit 1; fi
python3 - <<'PYTEST'
import json
with open('artifacts/research-motion/results.json') as f:
    assert json.load(f)['passed']
PYTEST

# Variable-day bookings, actual receipts and isolated 0.6.0 migration.
godot --headless --path godot --script tests/test_daily_capacity.gd 2>&1 | tee .runtime/capacity-unit.log
if rg 'SCRIPT ERROR|ERROR:|FAIL:' .runtime/capacity-unit.log; then exit 1; fi
for mode in held streaming auto; do
 godot --headless --path godot --script tests/test_capacity_motion.gd -- --qa --mode="$mode" 2>&1 | tee ".runtime/capacity-motion-$mode.log"
 if rg 'SCRIPT ERROR|ERROR:|FAIL:' ".runtime/capacity-motion-$mode.log"; then exit 1; fi
done
python3 - <<'PYTEST'
import json, os, subprocess
from pathlib import Path
for path in [Path('artifacts/daily-capacity-unit/results.json'),*Path('artifacts').glob('capacity-motion-*/results.json')]:
 assert json.loads(path.read_text())['passed'], path
reports=[]
for checkpoint in sorted(Path('artifacts/capacity-restart-checkpoints').glob('*.json')):
 result=subprocess.run(['godot','--headless','--path','godot','--script','tests/test_capacity_restart.gd','--','--checkpoint='+str(checkpoint.resolve())],capture_output=True,text=True)
 assert result.returncode==0 and 'RESTART PASS' in result.stdout and 'ERROR' not in result.stdout+result.stderr, result.stdout+result.stderr
 reports.append({'checkpoint':checkpoint.name,'passed':True})
Path('artifacts/capacity-restart-results.json').write_text(json.dumps({'passed':True,'separate_processes':len(reports),'results':reports},indent=2))
print('CAPACITY PROCESS RESTART:',len(reports),'isolated saves passed')
PYTEST
