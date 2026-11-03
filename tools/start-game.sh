#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export XDG_DATA_HOME="$PWD/.runtime/data"
export XDG_CACHE_HOME="$PWD/.runtime/cache"
export XDG_CONFIG_HOME="$PWD/.runtime/config"
mkdir -p "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"
exec godot --path godot "$@"
