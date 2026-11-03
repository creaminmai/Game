# 플레이 영상과 직접 체험

사용 기기: Mac 또는 iPhone. 브라우저 체험을 우선한다.

## 이번 전달

가로 화면을 기준으로 병원 공간이 창 전체를 차지하도록 갱신했다. 오른쪽 아래 아이콘으로 환자 목록·지시 필요·증축·안팎을 조작하고, 왼쪽 아래 버튼으로 확대·축소·전체 보기를 선택한다. 빈 공간 드래그로 시점을 이동한다. 환자를 선택했을 때만 진료 버튼이 열린다.

- `docs/media/playthrough.mp4`: 실제 Godot에서 자동 입력으로 진행한 플레이 시연. 약 55초, 1280×720, 24fps, 진료 4배속, 무음. 원본 AVI가 아닌 압축된 전달용 MP4를 소스와 함께 보관한다.
- Web 내보내기: Godot 4.6.3의 단일 스레드 WebGL 2 빌드. 캐시·저장·테스트 자료·원본 기획서는 웹 배포에 넣지 않는다.
- 데스크톱 Chromium에서 실제 캔버스 클릭 → 환자 목록 열기 → 환자 선택 → 접수 → CT로 이동과 IndexedDB 저장을 확인했다.
- 844×390 터치 에뮬레이션에서도 화면을 채우는 캔버스와 실제 탭 → 목록 → 접수 → 저장을 확인했다. 실제 iPhone/Safari의 성능·저장 유지·전체 진료는 아직 검증하지 않았다.

## 웹 링크 게시에 남은 작업

이전 작업에서 사이트 미리보기 릴레이를 사용할 수 없었고 GitHub API 요청도 Forbidden으로 차단됐다. 이번 실행 환경의 허용 도메인에도 api.github.com과 creaminmai.github.io가 포함되지 않았다. 저장소 브랜치 푸시와 공개 사이트 게시 상태를 구분한다. GitHub Pages 설정·저장소 공개 범위를 API로 확인했다고 주장하지 않는다.

준비한 웹 파일은 `gh-pages` 브랜치로 보관할 수 있다. 브랜치 푸시가 Pages 게시 완료를 의미하지 않는다. 사이트가 아직 없다면 저장소 관리자가 GitHub 저장소의 **Settings → Pages → Deploy from a branch → gh-pages / (root)** 를 설정해야 한다. GitHub가 표시한 실제 게시 URL에서 게임 로딩을 확인한다. 계정·저장소 조건에 따라 Pages 사용 가능 여부가 달라질 수 있다.

에이전트가 설정·접속 확인을 계속할 수 있도록 환경 초안에 `api.github.com`, `creaminmai.github.io`를 추가했다. 환경 설정에서 검토·저장·게시한 뒤 실제 접근을 다시 확인해야 한다. 도메인 설정 저장이 GitHub API 권한이나 Pages 게시를 보장하지는 않는다. 추가 토큰을 채팅에 요청하지 않는다.

## 다음 작업에서 갱신

```sh
./tools/setup.sh
./tools/test-godot.sh
python3 tools/run-visual-qa.py --movie --output-dir="$PWD/artifacts/playthrough"
python3 tools/export-game.py Web
python3 tools/test-web.py
python3 tools/test-web.py --touch
```

영상 `movie-results.json`이 passed이고 환자 4명·자금 1100만·동시 치료 2명·다음 날을 확인한 뒤 MP4를 검토한다. 위 수치는 현재 임시 밸런스에 대한 시나리오 기준이므로 게임 규칙을 바꾸면 의미 있는 기준으로 갱신한다.

선택한 MP4를 docs/media/로 복사하고 문서·소스를 main에 커밋·푸시한다. `python3 tools/push-web-build.py`는 현재 빌드를 별도 gh-pages 브랜치로 푸시하며 현재 checkout과 main index를 전환하지 않는다. 웹에 포함되는 파일을 확인한 뒤 실행한다. 빌드 소스 커밋은 build.json에 기록한다. 향후 정상 게시가 설정되면 같은 Pages 주소에서 최신 체험판을 유지한다.

공식 템플릿은 GitHub의 4.6.3 릴리스 SHA-512와 비교한 뒤 사용한다. 다운로드 크기는 약 1.2GB이며 .runtime/에 보관해 다음 내보내기에서 재사용한다. Git에는 엔진 템플릿과 원본 AVI를 넣지 않는다.
