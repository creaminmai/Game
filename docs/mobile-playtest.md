# 모바일 체험 빌드 · 0.3.0-dev

**최신 전달은 [0.4.0-dev 챕터 1·2 빌드](chapter-progression.md)**다. Android와 Web에 접수 위임·챕터 진행을 함께 포함한다. 아래 0.3.0 수치와 파일은 최초 모바일 준비 당시의 기록이며 최신 버전의 파일/체크섬은 챕터 검토 문서를 따른다. 실기기 미완료 상태는 유지한다.

2026-11-08 KST. Android·iOS 동시 출시 목표를 유지하는 개발용 체험 준비다. 스토어 출시판이 아니다. 아래 검증 범위에서 Linux 엔진, 브라우저 에뮬레이션, 실제 휴대폰을 구분한다.

## 직접 해보기

**iPhone + Mac**

1. 전달된 `SunshineHospital-Web-0.3.0-*.zip`을 Mac의 `KMH/05_게임` 아래 새 폴더에 푼다. 기존 프로젝트는 덮어쓰지 않는다.
2. 설치한 Godot을 응용 프로그램 폴더에 넣고, 묶음 안의 `iPhone 체험 열기.command`를 연다. 막히면 우클릭 → 열기.
3. Mac과 iPhone을 같은 Wi-Fi에 연결한다. 열린 창에 나온 `http://Mac의IP:8765/` 주소를 iPhone Safari에 입력하고 가로로 돌린다. Mac의 서버 창은 열어 둔다.
4. Safari 일반 탭을 사용한다. 복원 후에는 상단 재생을 누른다. 같은 주소·같은 브라우저의 저장만 이어진다.

이 주소는 **Mac이 켜져 있는 같은 로컬 네트워크에서만** 사용한다. 이 클라우드의 `127.0.0.1` 주소를 휴대폰 링크로 사용하지 않는다. Mac LAN 실행과 iPhone Safari는 사용자 기기에서 확인해야 한다. Godot이 없으면 [Mac 프로젝트 실행 안내](mac-play.md)를 참고한다. 공유기에서 기기 간 통신을 차단한 게스트 Wi-Fi는 피한다. Mac 방화벽이 물으면 Godot의 로컬 네트워크 연결을 허용한다. IP 주소가 바뀌면 웹 저장의 주소도 달라지므로 같은 주소를 유지한다.

**Android**

- APK: `artifacts/android/SunshineHospital-0.3.0-dev.apk`. 전송한 APK를 Android에서 열고 해당 파일 앱의 ‘이 출처의 앱 설치’를 허용한다.
- USB 개발 설치: `adb install -r artifacts/android/SunshineHospital-0.3.0-dev.apk`. `-r`은 기존 데이터를 보존한다. 기존 앱을 삭제하거나 `adb shell pm clear`를 실행하지 않는다.
- 서명이 달라 업데이트가 거절되면 **삭제해서 해결하지 말고** 기존 개발 키로 다시 빌드한다. 개발 키는 `.runtime/android-debug.keystore`에 유지하며 소스/공개 ZIP에 넣지 않는다. 다른 환경으로 옮길 때 개발자가 별도로 안전하게 보관해야 한다.
- Android 7/API 24 이상, ARM64 또는 x86_64, OpenGL ES 3.0. 지원 선언과 실제 기기 호환 검증은 다르다.
- 앱 이름 **햇살병원 체험**, 버전 **0.3.0-dev / code 300**, 가로 고정. 임시 식별자 `org.creaminmai.sunshinehospital.playtest`는 출시 전에 확정하고 출시용 서명은 별도로 준비한다.

Android와 웹, Mac Godot의 저장은 자동 공유되지 않는다. APK 설치/웹 체험 준비가 기존 Mac 저장을 지우지 않는다. 웹사이트 데이터 삭제·시크릿 탭·앱 삭제는 저장을 잃을 수 있으므로 이번 확인에 사용하지 않는다.

## 5분 확인 순서

1. 실행 → 민지·김영수의 짧은 이야기 → 김영수 선택 → **접수하기**. 선택만으로 접수되지 않는지 본다.
2. 이동 중 다른 앱을 잠깐 열었다가 돌아온다. CT가 끝나면 **계획 맡기기**. 치료 중에도 한 번 전환한다. 백그라운드 시간만큼 진료가 건너뛰지 않아야 한다.
3. 첫 일정 완료 후 **병원 밖 → 별관 예정지 → 600만 확인 → 별관 짓기**. 처음에는 ‘다음에’를 눌러 자금이 유지되는지도 본다. 구매 직후 앱을 닫았다 다시 열어 별관과 비용이 한 번만 반영됐는지 확인한다.
4. 나머지 환자도 접수·계획을 지시한다. 두 치료실에 서로 다른 환자가 들어가는지 본다. 4명이 귀가하면 **병원 일지**의 수입 800만 / 지출 600만 / 현재 1100만을 확인한다. 별관을 안 샀다면 지출 0 / 현재 1700만이다.
5. 일지에서 앱을 다시 열어 기록이 같은지 확인 → **다음 날 시작** → 다시 열어 2일차·시설·자금이 유지되는지 확인. 마지막으로 직접 일시정지한 뒤 앱 전환을 해도 일시정지가 풀리지 않는지 본다.

운영 속도에 따라 5분보다 길어질 수 있다. 저장 복원은 의도적으로 일시정지 상태이며 상단 재생으로 이어간다. 웹은 Safari를 다시 열 때도 Mac 서버가 실행 중이어야 한다. 확인 메모에는 기종, OS, Safari 버전 또는 APK 버전, 문제 장면을 함께 남긴다.

## 빌드 재현

Linux x86_64, Python 3.12 이상, Godot **4.6.3.stable.official.7d41c59c4** 기준:

```sh
python3 tools/export-game.py Android
python3 tools/verify-android.py
python3 tools/export-game.py Web
python3 tools/package-mobile-web.py
```

`setup-android.py`가 프로젝트 전용 `.runtime/`에 SHA-256을 고정한 JDK Temurin 21.0.9+10, Android build-tools 36.0.0, platform-tools 37.0.2와 개발 키를 준비한다. 공식 Godot 템플릿은 기존 SHA-512 검증을 유지한다. Gradle 없는 공식 APK 템플릿 방식이므로 별도 Gradle/NDK/Android platform SDK 컴파일이나 SDK 라이선스 자동 동의가 필요하지 않다. 대상 SDK 36, 최소 SDK 24는 실제 APK 매니페스트에서 검사한다. 템플릿 내보내기 전에 Godot 편집기 최초 가져오기를 완료해야 한다.

```sh
XDG_DATA_HOME="$PWD/.runtime/data" XDG_CACHE_HOME="$PWD/.runtime/cache" \
XDG_CONFIG_HOME="$PWD/.runtime/config" godot --headless --path godot --editor --import --quit
./tools/test-godot.sh
python3 tools/test-mobile-lifecycle.py
python3 tools/run-visual-qa.py --mobile-check --output-dir artifacts/mobile-ui
python3 tools/run-visual-qa.py --performance --output-dir artifacts/mobile-performance
python3 tools/test-web.py --touch --dpr 3 --mobile-preflight --save-timeout 900
python3 tools/test-web.py --save-timeout 900
python3 tools/run-visual-qa.py --movie --polish welcome --mobile-preview --output-dir artifacts/mobile-video
```

시각 검사와 영상은 같은 Xorg `:98`을 사용하므로 순서대로 실행한다. 소프트웨어 렌더링 성능 측정 중 다른 렌더링 작업을 동시에 실행하지 않는다. 최초 웹 로딩은 다운로드·WASM 초기화·셰이더 컴파일 때문에 기다릴 수 있다.

## 이번 수정

- 병원 3D는 화면을 채우고 HUD·대화·확인창·일지만 안전 영역 안에 배치한다. 웹 CSS `env(safe-area-inset-*)`, Android/iOS의 네이티브 안전 영역을 구분한다.
- CSS 픽셀/플랫폼 포인트와 Retina 프레임버퍼 픽셀을 구분한다. 주요 버튼은 실제 표시 기준 최소 44, 작은 화면 대사는 약 16 이상을 목표로 한다. 확대/축소, 닫기, 목록·환자 보기, 배속 버튼도 함께 조정했다.
- 작은 환자 카드의 4단계 표시는 가로 아이콘으로 정리해, 본문·현재 행동을 읽기 쉽게 하고 하단 행동 버튼 공간을 확보했다. 상태·선택·업무 규칙은 유지한다.
- 웹 `visibilitychange`/`pagehide`/`pageshow`는 별도의 정지 사유로 처리해 사용자 일시정지·병원 밖 정지를 덮어쓰지 않는다. 저장 형식과 경제 수치는 그대로다.
- 모바일 GPU용 ETC2/ASTC 가져오기를 켰다. 광원·재질·모델 품질을 낮추는 변경은 하지 않았다.
- 테스트는 고유한 `.runtime/mobile-lifecycle-*` 저장 및 새 브라우저 프로필을 사용한다. 기존 사용자 저장 초기화 없이 검사한다.

## 플랫폼별 범위

| 플랫폼 | 확인 가능한 단계 | 아직 확인하지 못한 단계 |
| --- | --- | --- |
| Android | 개발 APK 생성, v2/v3 서명 검증, ZIP 무결성·16KB 정렬, 이름·버전·가로 방향·아키텍처·SDK | 기기/에뮬레이터 설치·실행, 네이티브 터치·백그라운드, FPS·발열·배터리 |
| iPhone 웹 | Web 빌드, Mac용 LAN 전달 묶음, Linux 서버의 실제 자산 응답, Chromium 터치/Retina 에뮬레이션 | 실제 Mac LAN 연결, iPhone Safari·노치·홈 표시줄·앱 전환·성능 |
| iOS 네이티브 | 공식 템플릿 설치 및 iOS 프리셋·버전·임시 bundle ID 준비, 실제 내보내기 명령 실행 | Team ID 미지정으로 Xcode 프로젝트 생성 중단; Xcode 빌드·서명·IPA·기기 설치 모두 미완료 |
| Linux Godot | 실제 3D 실행·입력·세 해상도·안전 영역 모사·운영 회귀·저장 재실행·영상·프레임 측정 | 모바일 하드웨어의 동작을 대신하지 않음 |

공개 후보 주소 `https://creaminmai.github.io/Game/`와 GitHub Pages 설정 API는 이 환경에서 CONNECT 403(네트워크 허용 목록)으로 차단됐다. Pages 게시 여부와 공개 게임 로딩을 확인하지 못했으며, 위 주소를 검증된 iPhone 링크로 제공하지 않는다. `gh-pages` 백업은 게시 확인과 별개다. 공개 체험을 원하면 저장소 Settings → Pages에서 `gh-pages`의 `/`를 게시하고 실제 Safari에서 확인해야 한다.

iOS는 Mac의 Godot에서 공식 iOS 템플릿을 설치한 뒤 프리셋의 Team ID를 본인 Apple 개발 팀으로 채운다. 내보낸 Xcode 프로젝트에서 Bundle ID·Signing & Capabilities·연결된 iPhone을 설정하고 빌드한다. 유효한 Apple 팀과 프로비저닝을 확보하기 전에는 iOS 프로젝트·설치 앱을 완성했다고 보지 않는다. Mac 소스 ZIP과 iOS IPA는 별개다.

## 검사·성능·전달 기록

최종 검사 수, 빌드 소스 커밋, 파일 체크섬, 영상/캡처 및 남은 제한은 [검사 원자료](mobile-playtest-results.json)에 기록한다. [영상·캡처 보기](mobile-playtest.html)에서 실제 실행 화면을 확인한다. 전달용 APK/ZIP 및 원본 로그는 `artifacts/`에 두고 소스 Git에는 넣지 않는다. 선택한 영상·캡처와 검사 요약만 `docs/media/`, `docs/images/mobile-playtest/`에 보관한다.

정상 1배속 영상은 **Linux Godot 실제 엔진의 자동 입력**이다. 844×390 화면과 안전 영역을 모사한 것이며 Android/iPhone 녹화가 아니다. 녹화 24fps를 실행 성능으로 사용하지 않는다.

별도 측정 환경: Debian 13, AMD EPYC 9V74 가상 CPU, Mesa llvmpipe(LLVM 19.1.7) 소프트웨어 OpenGL, 915×412, Godot Linux 소스 런타임, Movie Maker/고정 FPS 사용 안 함. 가져오기/렌더러 캐시가 있는 소스 런타임의 초기 첫 그리기 약 1.26초, 기본 운영 40프레임 평균 약 291.7ms(3.43fps), 두 치료실 동시 치료 40프레임 평균 약 346.5ms(2.89fps), p95 각각 319.4/382.9ms. 이는 GPU 없는 클라우드의 CPU 렌더링 측정이며 모바일 성능 예측치가 아니다. 실기기 FPS·발열·배터리는 미측정이다. 이 수치를 근거로 휴대폰의 조명·아트를 일괄 낮추지 않았다.

남은 확인은 실제 Android 설치, iPhone Safari 저장 지속성과 OS 강제 종료, 실제 노치/홈 표시줄, Mac 실행 도우미·LAN 방화벽, 공개 URL 게시, 기기별 초기 로딩·발열·배터리다. iOS 네이티브는 Apple 팀·Xcode 작업이 필요하다. 짧은 앱 전환과 강제 종료 직전 브라우저가 IndexedDB 쓰기를 완료했는지는 실기기에서 추가 확인한다.


## 확정 전달 파일과 검증 결과

빌드 기준 커밋: **`73e24c76222cf5dac1f407cf4370a71a3ab84498`**. 게임 구현은 `9aeb22e`와 같으며 후속 커밋은 실행 중인 adb를 덮어쓰지 않도록 빌드 도구를 고쳤다. 재설정을 연속 두 번 실행해 확인했다. 각 빌드의 `build.json`에서 커밋·도구 버전·파일 해시를 확인한다. APK/ZIP은 이 대화의 파일 링크로 다운로드하며 Git main에는 넣지 않았다.

| 파일 | 크기 | SHA-256 |
| --- | ---: | --- |
| `artifacts/android/SunshineHospital-0.3.0-dev.apk` | 66,927,577 bytes | `6bcd2597029feed5633dd67bac29dc14ea593237e9da2dd397fcb13d844182db` |
| `artifacts/mobile/SunshineHospital-Web-0.3.0-73e24c7.zip` | 22,605,197 bytes | `7894264fa6502d8a09d0502f5cb591050863d50f137602221c4c37628bc817f4` |

같은 위치의 `.sha256` 파일을 함께 전달한다. Mac에서는 `shasum -a 256 파일이름`으로 위 값과 비교한다. ZIP의 전체 CRC와 포함된 웹 파일의 SHA-256을 확인했다. 개발 인증서 SHA-256은 검사 원자료의 `apk.certificate_sha256`에 있다.

- 기존 운영 51, 모션 48, 이야기 84, 첫날/장부 70, 이야기 UI 271, 운영 장면 172, 최종 모바일 화면 630, 저장·중단 모델 및 16회 실제 프로세스 실행 148: **1,474개 통과**.
- 844×390 / 915×412 / 1280×720 실제 Linux 렌더링. 좌우 47·하단 21 안전 영역을 모사하고, 축소된 높이·버튼 입력·드래그/선택·줌·확인창·결산·동시 치료를 검사했다.
- Chromium 터치 **DPR 3**에서 접수·IndexedDB 저장, 위 세 크기와 **844×350** 리사이즈, CSS 안전 영역·설정·확대/축소, 사용자 일시정지 후 freeze/resume, 실제 페이지 재로딩/저장 복원 통과. 데스크톱 1280×720 DPR 1의 실제 접수·저장도 통과. 둘 다 별도 브라우저 프로필이다.
- 최종 Web의 `index.pck`, `index.wasm`, `index.html`은 터치 검사를 통과한 파일과 **SHA-256 일치**. 웹 엔진 시작 완료까지 약 6.8~6.9초, 첫 환자 도착과 저장까지 약 100~115초의 벽시계를 기록했다. 후자는 소프트웨어 렌더링의 게임 진행·비동기 저장 대기까지 포함하므로 ‘초기 로딩 시간’이나 모바일 성능으로 사용하지 않는다.
- [24초 플레이 영상](media/mobile-preflight-linux-1x.mp4): Linux Godot, **자동 입력·정상 1배속**, 844×390. 환자 선택 → 접수 → CT 이동·검사. Movie Maker가 초기 프로젝트 창 크기로 영상을 고정하는 점을 확인해, 녹화용 복사 설정에서 창 크기만 844×390으로 바꿨다. 게임 소스·에셋은 원본을 사용했고 플레이 프레임은 잘라내지 않았다.
- `main` 소스와 `gh-pages` 웹 백업의 원격 SHA를 확인했다. Web 백업 커밋은 `2863a8f5d74d74acb86c61b8244b51b52894e001`이다. **Pages 공개 게시·접속 확인과는 다르다.**

이전 테스트 녹화 중 해상도가 고정되어 잘린 파일은 전달하지 않는다. 최종 영상·캡처만 아래 검토 자료에 포함했다. APK는 생성/정적 검증까지, iPhone은 체험 경로 준비까지이며 실제 휴대폰 검증은 위 5분 순서로 이어간다.
