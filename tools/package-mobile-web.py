#!/usr/bin/env python3
"""Package the verified Web export with a Godot-powered Mac LAN launcher."""
import hashlib, json, zipfile
from pathlib import Path
repo=Path(__file__).resolve().parents[1]
web=repo/'artifacts/web'
manifest=json.loads((web/'build.json').read_text())
output=repo/'artifacts/mobile'
output.mkdir(parents=True,exist_ok=True)
target=output/f"SunshineHospital-Web-{manifest['version']}-{manifest['source_commit'][:7]}.zip"
root='햇살병원-iPhone체험/'
with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(web.iterdir()):
        if path.is_file(): archive.write(path,root+'web/'+path.name)
    archive.write(repo/'tools/serve-web.gd',root+'serve-web.gd')
    info=zipfile.ZipInfo(root+'iPhone 체험 열기.command');info.create_system=3;info.external_attr=0o100755 << 16
    archive.writestr(info,(repo/'tools/mac-web-play.command').read_bytes())
    archive.writestr(root+'project.godot','config_version=5\n[application]\nconfig/name="햇살병원 웹 전달 서버"\n')
    archive.writestr(root+'먼저 읽어주세요.txt','''1. 압축을 KMH/05_게임 아래 새 폴더에 풀어 주세요. 기존 게임 폴더는 덮어쓰지 않습니다.
2. Godot 앱을 Mac의 응용 프로그램 폴더에 넣고, iPhone 체험 열기.command를 엽니다.
3. Mac과 iPhone을 같은 Wi-Fi에 연결합니다. 열린 창에 나온 IP 주소를 iPhone Safari에 입력합니다.
4. iPhone을 가로로 돌립니다. 서버 창은 열어 두세요. 새로 접속할 때도 이 창을 엽니다.
5. 접수 → 계획 맡기기 → 치료 완료 → 별관 증축 → 병원 일지 → 다시 열어 저장 확인.
복원 직후에는 상단 재생을 누르세요. Safari 일반 탭을 사용하고 웹사이트 데이터를 삭제하지 마세요.
같은 주소/브라우저의 로컬 저장만 이어집니다. Mac Godot·Android 앱·웹은 저장이 자동 공유되지 않습니다.
공개 인터넷 서비스나 iOS 설치 앱이 아닙니다. 이 묶음의 Linux 서버/Chromium 확인과 실제 Mac/iPhone 검증은 구분합니다.
Mac에서 .command 열기가 막히면 우클릭 → 열기를 사용하세요. 관리 기기의 제한은 관리자에게 확인하세요.
''')
sha=hashlib.sha256(target.read_bytes()).hexdigest()
target.with_suffix('.zip.sha256').write_text(sha+'  '+target.name+'\n')
print(json.dumps({'path':str(target),'bytes':target.stat().st_size,'sha256':sha,'source_commit':manifest['source_commit']},indent=2))
