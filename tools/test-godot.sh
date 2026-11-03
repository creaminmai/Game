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
