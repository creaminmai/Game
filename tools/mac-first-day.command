#!/bin/bash
# Optional preview after importing the project: never loads or writes player saves.
set -euo pipefail
project_dir="$(cd "$(dirname "$0")" && pwd)"
if [[ "$(uname -s)" != Darwin ]]; then
  printf '%s\n' 'Mac용 체험 도우미입니다.'
  exit 1
fi
if [[ ! -f "$project_dir/project.godot" || ! -d "$project_dir/.godot/imported" ]]; then
  osascript -e 'display dialog "먼저 이 폴더의 project.godot을 Godot으로 가져오고 첫 리소스 가져오기가 끝날 때까지 기다려 주세요. 그다음 이 체험 도우미를 다시 여세요." buttons {"확인"} default button "확인"'
  exit 1
fi
printf '%s\n' '첫날 이야기 체험: 기존 저장을 읽거나 변경하지 않습니다. 종료하면 체험 진행은 저장되지 않습니다.'
if ! open -n -a Godot --args --path "$project_dir" -- --no-save; then
  printf '%s\n' 'Godot 앱을 찾지 못했습니다. Godot 앱 이름과 설치 위치를 확인하세요.'
  exit 1
fi
