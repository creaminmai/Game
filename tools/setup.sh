#!/usr/bin/env bash
# Cloud snapshot already contains the official Godot 4.6.3 binary.
set -euo pipefail
cd "$(dirname "$0")/.."
export XDG_DATA_HOME="$PWD/.runtime/data"
export XDG_CACHE_HOME="$PWD/.runtime/cache"
export XDG_CONFIG_HOME="$PWD/.runtime/config"
mkdir -p "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"
godot --version | rg '^4\.6\.3\.stable\.official\.'
godot --headless --path godot --editor --import --quit > .runtime/setup.log 2>&1
if rg 'SCRIPT ERROR|Parse Error|Compile Error' .runtime/setup.log; then exit 1; fi
printf 'Godot project imported successfully.\n'
