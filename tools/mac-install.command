#!/bin/bash
# Distributed beside the portable 햇살병원 project. Uses only macOS built-ins.
set -euo pipefail

if [[ "$(uname -s)" != Darwin ]]; then
  printf '%s\n' '이 설치 도우미는 Mac에서 실행하세요. 프로젝트는 Godot에서 직접 가져올 수도 있습니다.'
  exit 1
fi

bundle_dir="$(cd "$(dirname "$0")" && pwd)"
source_dir="$bundle_dir/햇살병원"
if [[ ! -f "$source_dir/project.godot" ]]; then
  printf '%s\n' 'ZIP 전체를 압축 해제한 뒤 실행하세요. 설치 도우미 옆에 햇살병원 폴더가 필요합니다.'
  exit 1
fi

# A chooser avoids guessing whether KMH is on the Desktop or an external disk.
# Cancellation exits before making any directories.
if ! chosen_dir="$(osascript <<'APPLESCRIPT'
POSIX path of (choose folder with prompt "KMH 폴더를 선택하세요. 그 안의 05_게임에 햇살병원 폴더를 만듭니다. 이미 05_게임을 열었다면 그 폴더를 선택해도 됩니다.")
APPLESCRIPT
)"; then
  printf '%s\n' '취소했습니다. 파일을 변경하지 않았습니다.'
  exit 0
fi
chosen_dir="${chosen_dir%/}"
[[ -d "$chosen_dir" ]] || exit 1
# Compare filesystem identities: Korean paths may use decomposed Unicode on Mac.
ancestor="$(cd "$chosen_dir" && pwd -P)"
while [[ "$ancestor" != / ]]; do
  if [[ "$ancestor" -ef "$source_dir" ]]; then
    printf '%s\n' '압축을 푼 프로젝트 내부가 아닌 KMH 폴더를 선택하세요.'
    exit 1
  fi
  ancestor="$(dirname "$ancestor")"
done
if [[ "$chosen_dir" -ef "$(dirname "$chosen_dir")/05_게임" ]]; then
  games_dir="$chosen_dir"
else
  games_dir="$chosen_dir/05_게임"
fi
mkdir -p "$games_dir"

destination="$games_dir/햇살병원"
if [[ -e "$destination" || -L "$destination" ]]; then
  suffix="$(date +%Y%m%d_%H%M%S)"
  destination="$games_dir/햇살병원_$suffix"
  index=2
  while [[ -e "$destination" || -L "$destination" ]]; do
    destination="$games_dir/햇살병원_${suffix}_$index"
    index=$((index + 1))
  done
fi
# mkdir without -p reserves a NEW directory; never merge over an existing game.
mkdir "$destination"
ditto "$source_dir" "$destination"
printf '프로젝트 준비 완료: %s\n' "$destination"
open -R "$destination/project.godot" || true

if open -n -a Godot --args --editor --path "$destination"; then
  printf '%s\n' 'Godot의 첫 가져오기가 끝나면 오른쪽 위 ▶ 프로젝트 실행을 누르세요. 단축키는 F5(또는 fn+F5)입니다.'
else
  printf '%s\n' 'Godot을 직접 실행하고 가져오기(Import)에서 방금 열린 폴더의 project.godot을 선택하세요.'
fi
osascript - "$destination" <<'APPLESCRIPT'
on run argv
  display dialog "프로젝트를 준비했습니다." & return & (item 1 of argv) & return & return & "Godot에서 가져오기가 끝나면 오른쪽 위 ▶ 프로젝트 실행을 누르세요. Godot이 열리지 않았다면 가져오기(Import)로 project.godot을 선택하세요." buttons {"확인"} default button "확인"
end run
APPLESCRIPT
