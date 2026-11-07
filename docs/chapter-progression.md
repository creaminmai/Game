# 챕터 1·2 · 여러 날의 병원 운영

첫날 네 분을 안내한 경험을 다음 날의 업무 분담·별관 활용·누적 방문 일정으로 연결한다. 가로 3D, 안정적인 카메라, 환자 모션, 수동 계획 검토와 기존 경제를 유지한다.

## 플레이 흐름

1. 첫날 네 환자가 **실제로 모두 귀가**하면 1장 **다시 켜진 간판**이 완료된다. 기존 병원 일지에 작은 완료 도장을 남기며 새로운 첫날 대화는 추가하지 않는다.
2. 상단 목표를 누르면 **병원 성장 기록**에서 2장 **기다리는 의자들**의 세 조건을 확인한다. 별관 마련, 서로 다른 환자의 두 치료실 동시 사용, 방문 일정 12회 완료다.
3. 별관은 기존처럼 병원 밖에서 600만에 직접 구매한다. 두 환자의 계획을 맡겨 실제 치료가 겹치면 동시 운영 조건이 체크된다. 빈 침대·예약·이동만으로 완료되지 않는다.
4. 2일차 민지 접수 위임은 선택이다. 직접 접수해도 같은 챕터를 완료한다. **계획 맡기기**는 계속 플레이어의 업무다.
5. 첫날 4회를 포함해 12회의 귀가가 누적되고 나머지 조건도 달성되면 2장이 완료된다. 3일 제한·실패·추가 보상은 없다. 이후에도 자유 운영과 다음 날 진행을 계속할 수 있다.

목표 확인은 구매·접수·카메라 이동을 실행하지 않는다. 일일 실적은 일지의 오늘 수입/지출/완료 인원, 누적 실적은 일지 날짜 옆의 **누적 방문**과 성장 기록에서 구분한다. 작은 체크와 일지 도장을 사용하며 매 조건마다 팝업을 띄우지 않는다.

## 기록과 저장

`chapter_progress.gd`는 운영 명령을 실행하지 않는 별도 진행 기록이다. `HospitalSimulation.set_state(..., "complete")`에서 실제 귀가를 기록한다. 기존 `lifetime_completed`는 치료비 지급 시 증가하므로 새 방문 횟수로 사용하지 않는다. 마지막 환자의 비용을 받았어도 귀가 전이면 11회다.

- 현재 날짜의 `날짜:환자 ID` 키를 중복 없이 보관한다. 입금·대사·일지·불러오기는 방문을 추가하지 않는다.
- 기존 `all_done()` 검사를 통과한 다음 날 명령에서 네 개의 방문 키를 마감 수량으로 합산하고 날짜 경계를 보관한다. 마감한 날짜의 이벤트는 다시 세지 않는다. 같은 ID가 다른 날짜에 방문하면 새 일정으로 센다. 기록 크기가 날짜마다 무한히 늘어나지 않는다.
- 동시 치료는 별관 보유, 두 방의 서로 다른 예약 소유자, 각 환자의 실제 `treatment` 상태·해당 방 번호·미정산 상태를 모두 확인해 영구 기록한다. 영상 전용 상태나 화면 표시를 읽지 않는다.
- 완료 날짜, 동시 치료 경험, 누적/현재 방문 기록, 읽은 성장 대사, 진행 중인 대사와 일지 완료 소감 표시 여부를 저장 v2의 선택적인 `chapter_progress` v1에 저장한다.
- 저장 후보 전체를 검증한 뒤 적용한다. 잘못된/미래 버전 메타데이터는 기존 파일을 덮어쓰지 않는다. 일시정지·외부 화면·백그라운드 정책은 기존 시뮬레이션을 따른다.

### 이전 저장의 복원 범위

기존 코드는 네 명 모두 귀가해야 다음 날로 넘어간다. 따라서 날짜와 기존 누적 정산 수가 현재 환자의 지급 상태와 일치하면, **이미 마감한 날짜 × 4회 + 현재 `complete` 환자**를 복원한다. 현재 치료비만 지급받고 귀가 중인 환자는 포함하지 않는다. 날짜가 2일차 이상이면 첫날 완료도 복원한다.

이전 수치에 모순이 있으면 과거 횟수를 추정하지 않고 `legacy_partial`로 남기며 현재 확인 가능한 귀가부터 기록한다. 날짜·돈·환자·시설은 유지한다. 과거 `max_treating` 값이나 별관 보유만으로 동시 치료를 복원하지 않는다. 복원된 **현재 두 방에 실제 치료 환자가 존재**하는 경우는 현재 운영 증거로 인정한다.

이전 사용자의 성장 대사는 이미 확인한 것으로 처리해 과거 대사가 몰려 나오지 않는다. 새 목표는 바로 확인할 수 있다. 예전 저장의 수입/지출 미확인 처리와 접수 위임 기본 꺼짐도 유지한다. 사용자 저장을 지우거나 날짜를 되돌리지 않는다.

## 이야기와 작은 화면

기존 첫날 이야기·2일차 위임 제안을 우선하고 동일한 대사 패널에서 성장 이야기를 하나씩 보여준다. 별관이 없고 실제 치료 대기가 있으면 증축 가능성을, 이미 있으면 두 방의 활용을 제안한다. 동시 치료 경험은 짧은 과거형 소감으로 남긴다. 2장 완료 소감은 모든 환자가 귀가한 병원 일지에서 한 번 보여준다.

대사는 자동으로 넘기지 않는다. 건너뛰기·안내 끄기는 진행도를 바꾸지 않는다. 안내를 다시 켜면 과거 대사를 줄줄이 재생하지 않는다. 설정 문구를 **이야기 안내**로 바꿔 첫날 이후에도 적용됨을 명확히 했다.

성장 기록은 왼쪽에 배치하고 오른쪽 환자 카드를 유지한다. 기록이 열렸을 때 같은 영역의 줌·설정·알림과 일지 열기 버튼은 닫은 뒤 다시 사용할 수 있다. 카메라 값은 바뀌지 않는다. 한국어 폰트의 실제 줄 높이로 조건 행을 배치한다. 844×350에서 일지 버튼이 44 표시 픽셀에 못 미치던 문제도 고쳤다.

844×350, 844×390, 915×412, 1280×720에서 UI 경계·조건 행 간 간격·카드/대사/하단 메뉴 비겹침을 확인한다. 작은 화면에는 좌우 47/하단 21 포인트의 안전 영역을 주입한다. 이는 Linux 렌더링·입력 모사이며 실기기 검증이 아니다.

## 기획과 적용 차이

원문 [시즌 기획의 챕터 1·2](../reference/season-one-design-v1.0.md)를 기반으로 이번 사용자 요청을 우선한다. 원문의 챕터 자금·평판 보상은 적용하지 않았다. 초기 900만, 일정 완료 수입 200만, 별관 600만을 유지한다. 3일간 12회 완료 + 별관 한 번이면 **900 + 2400 − 600 = 2700만**이다.

김영수의 나무 장식은 후속 환자 이야기 보상으로 남긴다. 민지의 2일차 무료 접수 위임은 기존 구현을 보존하며 챕터 조건이 아니다. 연구소·지도·새 재화·채용·자동 계획·새 치료 체계는 추가하지 않았다. 3장 이후를 실행 버튼으로 제공하지 않는다. 여러 날 방문 횟수는 운영 기록이며 의학적 치료 결과나 완치 횟수가 아니다.

## 검증과 영상 재현

```sh
./tools/test-godot.sh
python3 tools/test-mobile-lifecycle.py
python3 tools/run-visual-qa.py --chapter-check --output-dir artifacts/chapter-ui
python3 tools/run-visual-qa.py --staff-check --output-dir artifacts/chapter-staff-regression
python3 tools/run-visual-qa.py --story-check --output-dir artifacts/chapter-story-regression
python3 tools/run-visual-qa.py --output-dir artifacts/chapter-scene-regression
python3 tools/run-visual-qa.py --movie --chapter journal --mobile-preview --output-dir artifacts/chapter-video-journal
python3 tools/run-visual-qa.py --movie --chapter annex --mobile-preview --output-dir artifacts/chapter-video-annex
python3 tools/run-visual-qa.py --movie --chapter completion --mobile-preview --output-dir artifacts/chapter-video-completion
python3 tools/export-game.py Android
python3 tools/verify-android.py
python3 tools/export-game.py Web
python3 tools/test-web.py --save-timeout 900
# 테스트 전용 체크포인트를 먼저 생성한다. 일반 사용자 저장은 건드리지 않는다.
python3 tools/run-visual-qa.py --movie --chapter completion --mobile-preview --rehearsal --output-dir artifacts/chapter-rehearsal-completion
python3 tools/test-web.py --touch --chapter --save-timeout 900
python3 tools/package-playtest.py
```

렌더링 작업은 순서대로 실행한다. 체크포인트는 `chapter_fixture.gd`와 녹화 스크립트에서 기존 접수·계획·구매·시뮬레이션·다음 날 명령으로 준비한다. 방문/자금/동시 치료 기록을 직접 만들어 넣지 않는다. 녹화 전 준비 루프만 빠르게 실행하고 녹화 프레임에서는 1배속을 유지한다.

- [① 첫날 일지 → 1장 완료 → 2장 목표](media/chapter-journal-1x.mp4): 첫날 마지막 환자가 귀가하기 직전부터 시작한다.
- [② 별관 구매 → 실제 동시 치료 → 목표 반영](media/chapter-annex-1x.mp4): 별관 없이 첫날을 마친 뒤, 2일차 본관 치료와 치료 대기가 발생한 체크포인트다.
- [③ 누적 12회 → 완료 일지 → 4일차·저장 복원](media/chapter-completion-1x.mp4): 첫날 별관 구매, 3일차 11회 귀가·마지막 환자 귀가 중부터 시작한다.

모두 **Linux Godot 4.6.3 Compatibility/OpenGL llvmpipe, 자동 입력, 정상 1배속**이다. 24fps는 영상 출력 형식이며 모바일 성능이 아니다. 세 번째 영상의 저장 복원은 QA가 실제 SaveStore 파일을 다시 읽는 동작이며 OS 프로세스 종료/재실행은 별도 테스트로 검증한다. 웹은 별도 Chromium 프로필의 IndexedDB에서 정상 운영 체크포인트를 불러와 실제 클릭/터치·귀가·일지·다음 날·페이지 새로고침을 검사한다.

확정 수치·소스 커밋·파일 해시는 [검사 기록](chapter-progression-results.json), 영상과 캡처는 [검토 페이지](chapter-progression.html)에 모은다. 단위 검사는 수동/위임 × 첫날/나중 증축의 네 경로, 증축만 하고 순차 치료한 경로, 늦은 증축, 11→12 경계와 중복 방지, 기존 저장·안내 끄기·건너뛰기·동시 대화 방지를 포함한다.

## Android / Web 전달과 제한

릴리스 기준은 `release.json`의 **0.4.0-dev / code 400**이다. Android와 Web은 동일한 깨끗한 소스 커밋에서 내보낸다. 첫날 이야기·병원 일지·별관·접수 위임·챕터 1·2를 양쪽에 포함한다. `package-playtest.py`가 버전·커밋·기능·파일 SHA-256·개발 서명 인증서 일치를 검사한다. 빌드·캐시·APK·ZIP·서명 키는 소스 저장소에 넣지 않는다.

- APK: `artifacts/android/SunshineHospital-0.4.0-dev.apk`. 기존 개발 키와 앱 식별자를 유지했다. 업데이트는 `adb install -r` 또는 기존 앱 위에 APK 설치로 진행하며 앱 삭제/저장 초기화를 하지 않는다.
- Web: `artifacts/mobile/SunshineHospital-Web-0.4.0-dev-<소스커밋7자리>.zip`. Mac의 `KMH/05_게임` 새 폴더에 풀어 `iPhone 체험 열기.command`를 연다. 같은 Wi-Fi의 iPhone Safari에 Mac 창에 표시된 주소를 입력한다. Mac Godot/웹/Android 저장은 자동 공유되지 않는다.
- 버전·크기·체크섬·소스 커밋: `artifacts/mobile/delivery-0.4.0-dev-<소스커밋7자리>.json`과 검토용 JSON에 기록한다.

Android는 개발 APK 생성·서명·패키지/정렬 검사와 실제 기기 실행을 구분한다. Android/iPhone 실기기 설치·성능·발열·배터리·실제 OS 전환은 **여전히 미검증**이다. iPhone Safari와 Mac LAN 연결도 이 Linux 환경에서 실기기 확인했다고 표시하지 않는다. iOS 네이티브는 기존 Team ID/Xcode/서명 준비 단계에 남는다. 공개 Pages URL은 접근·로딩이 검증되지 않았으며 클라우드 로컬 주소를 휴대폰 링크로 제공하지 않는다.

아직 임시인 부분은 기존 캐릭터 초상·기본 모션을 재사용한 짧은 성장 대사와 텍스트 체크 도장이다. 새로운 스토리 소품이나 연기·시설은 만들지 않았다. 기존 소프트웨어 렌더러의 낮은 프레임 속도를 휴대폰 성능으로 해석하지 않는다.
