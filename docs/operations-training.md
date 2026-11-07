# 챕터 3 · 민지의 긴 하루 / 운영 교육

Godot 4.6.3 · 가로 3D · 0.5.0-dev / Android code 500. 챕터 2 다음에 **500만 운영 교육 → 사용자가 계획 위임 켜기 → 두 업무를 맡긴 방문 4회 귀가**를 연결했다. 무료 접수 위임과 수동 운영은 계속 사용할 수 있다.

## 실제 동작

- 설정의 업무 관리에서 접수(직접/민지), 교육(미완료/완료), 계획 지시(직접/직원)를 각각 표시한다. 잠긴 교육도 내용·가격·해금 이유를 읽을 수 있다.
- 교육은 챕터 2 완료 후 한 번만 구매한다. 확인창 취소·자금 부족·연속 구매는 비용이나 진행을 바꾸지 않는다. 구매 직후 계획 위임은 **꺼짐**이며 별도 버튼으로 켠다.
- `HospitalOperationsTraining`은 `plan_ready` 환자의 기존 순서(`queue_order`)로 한 명씩 3 **시뮬레이션 초** 준비한다. 이후 기존 `assign_plan`을 호출한다. 기존 계획 검토 5초, 담당자 예약, 계획/치료 FIFO, 치료 30초, 치료비 200만을 유지한다.
- 접수와 계획 명령은 성공한 순간만 방문에 `admission_source`(manual/minji/legacy/none), `plan_source`(manual/staff/legacy/none)를 기록한다. 수동 명령이 먼저 성공하면 해당 준비를 즉시 취소한다. 자동 설정을 꺼도 이미 시작한 정상 검토는 계속된다.
- 선택·환자 카드·카메라는 자동 명령의 대상이 아니다. 기존 민지 응대와 박 선생 응대 동작을 정상 명령 성공 신호에 연결했다. 준비, 시설 대기, 실제 검토를 카드에서 구분한다.
- 두 실행 출처가 minji/staff인 방문만 실제 `complete` 귀가 이벤트에서 기록한다. 치료비 입금(`leaving`) 시점에는 아직 포함하지 않는다. 날짜:환자 ID로 중복을 막고, 마감한 날짜는 누적 수와 날짜 경계로 보존한다. 여러 날짜의 방문을 합할 수 있다. 수동 도움에는 벌점이 없다.
- 교육 완료 + 위임 방문 4회로 챕터 3을 마친다. 성장 기록에 두 조건, 일지에 완료 도장을 남긴다. 이전 1·2장 기록도 다시 볼 수 있다. 돈·평판 보상과 챕터 4 버튼은 추가하지 않았다.

## 이야기와 화면

민지/박 선생의 소개 두 줄과 교육 후 민지 한 줄을 기존 대사 흐름에 연결했다. 박 선생은 현재 계획 담당 인물이며 박 원장과 합치지 않았다. 초상은 실제 기존 박 선생 3D 모델을 같은 조명에서 렌더링했다. 대사는 시간으로 넘기지 않으며 건너뛰기·안내 끄기는 구매나 업무 위임 동의가 아니다. 안내를 다시 켜면 과거 대사를 쌓아 재생하지 않는다. 완료 소감은 바쁜 운영 중 팝업 대신 모든 환자 귀가 후 병원 일지에서 한 번 보여준다.

설정이 길어져 큰 버튼 네 개를 세로로 배치하고, 설정을 읽는 동안 겹칠 수 있는 하단 도구를 숨긴다. 닫으면 돌아온다. 환자 카드와 상단 일시정지는 유지한다. 글씨·버튼을 줄이지 않았다. 자동 접수 상태의 긴 제목 때문에 844×350 환자 카드가 아래로 늘어나는 문제가 실제 검사에서 발견되어 제목을 줄이고 이유를 본문에 남겼다.

## 거래와 저장

저장 v2 안에 선택 필드 `operations_training` v1과 환자별 명령 출처를 추가했다. 일일 장부는 v2이며 `training_expense`를 증축 지출과 분리한다. 성공한 구매에서만 500만을 차감·기록한다. 일지의 시작 자금 + 진료 수입 − 증축 지출 − 운영 교육 지출 = 현재 자금이다. 4일간 16회 진료하고 별관/교육을 각 한 번 구매한 실제 운영 검사: **900 + 3200 − 600 − 500 = 3000만**.

다음 날에는 일일 수입/지출만 초기화한다. 교육, 위임 설정, 누적 귀가 기록, 완료 날짜와 표시 여부는 유지한다. 준비 대상과 경과 시간도 저장하여 복원 후 남은 시간부터 진행한다. 복원은 기존처럼 일시정지 상태로 시작하며 사용자 재생이 필요하다. 사용자 정지·병원 밖·앱 백그라운드에서 두 자동 업무 시계도 멈춘다. 임의 오프라인 수입은 없다.

이전 저장은 교육 미구매·자동 계획 꺼짐으로 이어간다. 기존 접수 위임 동의는 보존한다. 이미 실행된 출처를 확인할 수 없는 업무는 `legacy`로 남기며 과거 자동 방문으로 추정하지 않는다. 예전 장부 v1의 교육비는 당시 기능이 없으므로 0으로 이전하고, 기존 미확인 증축/시작 자금은 계속 ‘기록 없음’으로 취급한다. 잘못된 저장 후보는 전체 검증 후 거절하고 원본을 덮어쓰지 않는다. 테스트는 별도 저장 디렉터리를 사용한다.

## 원문과 이번 적용의 차이

[시즌 기획 직원·교육](../reference/season-one-design-v1.0.md)과 [박 선생 원래 설정](../reference/original-design.md)을 참고했다. 원문은 보존했다.

| 원문 | 이번 사용자 요청에 따른 적용 |
| --- | --- |
| 안내 직원 채용 후 자동 운영 | 기존 민지 무료 접수 위임 유지, 새 채용 없음 |
| 운영 교육 500만 | 같은 비용, 명시적 확인 후 한 번 구매 |
| 교육 소요/다음 날 반영, 일반 직원 성장 | 대기 타이머 없음. 교육 후 별도 계획 위임 켜기 |
| 다른 병원 방문 중 운영 위임 | 후속 범위. 병원 밖·백그라운드 정지 유지 |
| 채용·교육·자동 운영 하루 완료 | 교육 + 두 자동 업무를 거친 방문 4회 실제 귀가, 여러 날 누적 가능 |
| 챕터 자금·평판 보상 | 없음. 900/200/600 경제와 500 교육비만 적용 |
| 박 원장의 직원 교육 대화 | 현재 계획 담당 박 선생과 민지의 업무 분담 대화. 두 박 인물 구분 |

## 재현 검사와 영상

```sh
./tools/test-godot.sh
python3 tools/test-mobile-lifecycle.py
python3 tools/run-visual-qa.py --operations-check --output-dir artifacts/operations-ui
python3 tools/run-visual-qa.py --movie --operations education --mobile-preview --output-dir artifacts/operations-video-education
python3 tools/run-visual-qa.py --movie --operations flow --mobile-preview --output-dir artifacts/operations-video-flow
python3 tools/run-visual-qa.py --movie --operations completion --mobile-preview --output-dir artifacts/operations-video-completion
python3 tools/export-game.py Android
python3 tools/export-game.py Web
python3 tools/verify-android.py
python3 tools/package-playtest.py
python3 tools/test-web.py --save-timeout 900
godot --headless --path godot --script tests/prepare_operations_web.gd
python3 tools/test-web.py --touch --operations --save-timeout 900
```

브라우저 기능 검사는 별도 프로필에 **정상 운영으로 만든 두 체크포인트**를 사용한다. 첫 번째는 4일차 실제 접수 대기이며 Web에서 교육 취소·구매·두 위임 켜기·자동 접수를 확인한다. 두 번째는 정상 자동 접수·CT 이동·검사를 거쳐 실제 계획 준비 2.5/3초에 도달한 저장이며, Web에서 남은 준비·정상 지시·출처 저장·페이지 재실행을 확인한다. `tests/prepare_operations_web.gd`로 재현한다. 연속 Web 플레이 영상으로 표시하지 않으며, 전체 연속 흐름은 Linux 엔진 영상 ②에서 확인한다. 사용자 저장을 사용하거나 출처·자금을 강제로 맞추지 않는다.

결과 영상과 최종 검사 수·소스 커밋·파일 체크섬은 아래 전달 기록에서 확인한다. Linux 실제 엔진 영상은 자동 입력, 정상 1배속이다. 녹화 전에는 정상 접수·계획·증축·다음 날 명령으로 3일을 진행해 체크포인트를 만들었다. 완료 영상만 같은 방식으로 4일차 실제 위임 방문 3회 귀가 및 마지막 귀가 직전까지 준비한다. 영상 재생 중 돈·업무 출처·귀가 횟수를 강제로 설정하거나 배속하지 않는다. 녹화 24fps는 휴대폰 성능 측정치가 아니다.

## 남은 한계

- 교육/자동 계획의 직원 반응은 기존 짧은 고개·응대 제스처를 재사용한다. 전용 서류 작업 애니메이션, 실제 교육 장면은 후속 작업이다.
- 카메라·조명·모델·임시 진료 시간과 하루 네 명은 현재 프로토타입 기준을 유지했다. 임상 판단이나 계획 퍼즐을 새로 구현한 것이 아니다.
- Android APK 생성·서명/내용 검사와 실제 기기 설치·실행은 구분한다. Android/iPhone 실기기, Safari, Xcode 서명 앱, 모바일 FPS·발열·배터리는 **미검증**이다.
- Web 저장, Android 앱 저장, Mac Godot 저장은 자동 공유되지 않는다. 같은 개발 서명·식별자로 APK 업데이트하며 기존 앱 삭제나 데이터 초기화는 하지 않는다.

## 검토 화면과 전달 파일

[영상·화면 모아보기](operations-training.html). 작은 화면 캡처는 [844×350 업무 관리](images/operations-training/844x350-enabled.png), [구매 확인](images/operations-training/844x350-purchase.png), [귀가 집계](images/operations-training/844x350-growth.png), [일지](images/operations-training/844x350-journal.png)와 같은 폴더의 다른 세 해상도에 있다.

- ① `docs/media/operations-education-1x.mp4` · 25초
- ② `docs/media/operations-flow-1x.mp4` · 85초
- ③ `docs/media/operations-completion-1x.mp4` · 29초

Android와 Web의 공통 빌드 소스: **`e08a2b3668b6f3f800d62c4da7c0618bb28f158a`**. 검토 문서·영상·브라우저 검증 스크립트 추가 커밋은 이 빌드 이후이며 게임 실행 소스를 바꾸지 않는다.

| 파일 | 크기 | SHA-256 |
| --- | --- | --- |
| `artifacts/android/SunshineHospital-0.5.0-dev.apk` | 66,981,706 bytes | `5497d1fc2a8aff41afc5932266d9049c96f6e6fd6a97821b698c7dab29212796` |
| `artifacts/mobile/SunshineHospital-Web-0.5.0-dev-e08a2b3.zip` | 22,654,168 bytes | `ca314ea1cb7ee6b7e4b848f9dab9ec949f9b30aed6a6b77c9dae701afdf4bd87` |

Android 개발 서명 인증서 SHA-256은 기존 `58ef52f6279aedc86c8b4d59f6d68773e52dff19bad427ec75927bde24fec8c1`을 유지했다. 앱 ID는 `org.creaminmai.sunshinehospital.playtest`, 버전 code 500, ARM64/x86_64, 최소 API 24·대상 API 36, 가로 화면이다. 기존 키·저장은 삭제하지 않았다. APK ZIP 무결성, 코드/리소스 포함, 16KB 정렬, v2/v3 서명을 검사했다. 설치 가능한 개발 APK 생성 확인이며 스토어 출시나 실기기 실행 확인이 아니다.

Mac/iPhone: Web ZIP을 다운로드해 `KMH/05_게임` 아래 새 폴더에 풀고 `iPhone 체험 열기.command`를 연다. Mac과 iPhone을 같은 Wi-Fi에 연결하고 도우미가 보여 주는 **Mac의 LAN 주소**를 Safari 일반 탭으로 연다. 클라우드 localhost를 휴대폰 주소로 사용하지 않는다. 공개 Pages 접근·Safari 로딩 확인은 완료로 주장하지 않는다. 같은 주소와 브라우저의 웹 저장만 이어지며 Android/Mac 앱 저장과 자동 공유되지 않는다.

Android 업데이트: `adb install -r artifacts/android/SunshineHospital-0.5.0-dev.apk`. 기존 앱을 제거하거나 데이터를 초기화하지 않는다. 서명 충돌 시 삭제 대신 개발 키를 확인한다.

## 검사 결과

| 실제 확인 | 통과 검사 |
| --- | ---: |
| 기존 시뮬레이션·모션·첫날 이야기·일지·접수 위임·챕터 1·2 | 838 |
| 교육·자동 계획·실행 출처·다른 날짜 누적·이전 저장·경제 경계 | 251 |
| 교육·설정·환자 카드·성장 기록·일지, 네 해상도 실제 UI 입력 | 1,436 |
| 기존 챕터 UI | 1,076 |
| 기존 접수 위임 UI | 776 |
| 기존 첫날 이야기 UI | 265 |
| 기존 3D 장면·카메라·치료 자세 | 172 |
| 앱 알림 모사·실제 별도 프로세스 재실행 38회 | 478 |
| 합계 | **5,292** |

핵심 경계: 챕터 2 이전 구매 거절, 499만 자금 부족, 취소/반복 구매, 네 업무 설정 조합, 수동 먼저/자동 먼저 지시 경합, 기존 계획 FIFO, 3초 준비와 기존 5초 검토 분리, 끄기 후 진행 중 검토 유지, 치료비 지급과 실제 귀가의 구분, 3→4 경계의 단 한 번 완료, 서로 다른 날짜 누적, 다음 날 중복 입력, 2장 마감 당일 교육 구매, 교육을 미룬 수동 4일차와 5일차 재개, 이전 버전 진행 중 환자 이전을 확인했다.

별도 프로세스에서 구매 직후·준비 중·지시 직후·귀가 전·완료 일지·다음 날을 저장하고 실제 종료/재실행했다. 재개 전 정지, 두 준비 시계 정지, 설정·출처·장부·챕터 보존과 중복 차감/지시/집계 방지를 확인했다. 이는 Linux와 주입한 앱 알림의 결과이며 휴대폰 앱 전환 실측으로 표시하지 않는다.

도구: Godot `4.6.3.stable.official.7d41c59c4`, JDK `21.0.9+10`, Android build-tools `36.0.0`, platform-tools `37.0.2`. Linux Compatibility/OpenGL llvmpipe와 Chromium SwiftShader WebGL2에서 확인했다. 소프트웨어 렌더링 검사는 일부 녹화와 병행했다. 브라우저 기록의 로딩 소요 시간은 실기기 성능 자료로 사용하지 않는다.

최종 브라우저 검사·영상 프레임 검증·APK/ZIP 식별 정보는 [기계 판독 결과](operations-training-results.json)에 함께 보관한다. 녹화의 준비 프레임만 제거하며 게임 진행 프레임을 자르거나 재생 속도를 바꾸지 않는다. 영상 ②는 계획 지시를 카드로 확인한 뒤 실제 닫기 버튼을 눌러 두 치료실을 함께 보여준다.

Web의 1280×720 실제 접수/저장과 844×350 터치 에뮬레이션의 취소·구매·별도 활성화·자동 접수·자동 계획·실행 출처 저장·페이지 재실행이 통과했다. 두 개의 정상 운영 체크포인트를 쓴 구간 검사이며 연속 Web 플레이나 실기기 검사로 표시하지 않는다.

[카드를 닫고 두 치료실을 확인한 실제 녹화 화면](images/operations-training/dual-treatment-open.png). Web 배포용 `gh-pages` 원격 SHA는 `9ef3e293db69ee4c3f43e32eb69b1fa66cb77c8b`이며 빌드 소스 `e08a2b3`를 가리킨다. 공개 Pages 게시·접속·Safari 실행은 미확인이다.
