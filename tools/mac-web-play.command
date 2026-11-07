#!/bin/bash
set -euo pipefail
bundle="$(cd "$(dirname "$0")" && pwd)"
godot_bin="/Applications/Godot.app/Contents/MacOS/Godot"
if [[ ! -x "$godot_bin" ]]; then godot_bin="$(command -v godot || true)"; fi
if [[ ! -x "$godot_bin" ]]; then
  echo 'Godot 앱을 응용 프로그램 폴더에 넣고 다시 열어 주세요.'
  read -r -p '엔터를 누르면 닫습니다. '; exit 1
fi
lan_ip="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
echo '햇살병원 · iPhone 웹 체험 서버'
echo 'Mac과 iPhone을 같은 Wi-Fi에 연결하고 이 창을 열어 두세요.'
if [[ -n "$lan_ip" ]]; then echo "iPhone Safari 주소: http://$lan_ip:8765/"; else echo 'Mac의 시스템 설정 → Wi-Fi → 세부사항에서 IP 주소를 확인하고 http://해당IP:8765/ 를 여세요.'; fi
echo '공개 인터넷 링크가 아닙니다. 방화벽이 물으면 Godot의 로컬 네트워크 연결을 허용하세요.'
echo '웹과 Godot 앱의 저장은 별개입니다. 같은 Safari·주소로 다시 열어야 이어집니다.'
"$godot_bin" --headless --path "$bundle" --script "$bundle/serve-web.gd" -- "$bundle/web" 8765 &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true' EXIT
trap 'exit 0' INT TERM
for attempt in {1..20}; do
  kill -0 "$server_pid" 2>/dev/null || { wait "$server_pid"; exit 1; }
  if curl -fsS --max-time 1 http://127.0.0.1:8765/build.json >/dev/null; then open http://127.0.0.1:8765/; break; fi
  sleep .5
done
wait "$server_pid"
