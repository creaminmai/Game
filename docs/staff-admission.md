# 2일차 접수 업무 위임

2일차부터 기존 민지에게 **접수만 무료로** 맡길 수 있다. 기본값은 직접 접수이며 계획 검토는 계속 플레이어가 맡긴다. 가로 3D·카메라·모션과 900만/200만/600만 경제를 유지한다.

## 사용 방법

1. 첫날 환자 네 명이 귀가하면 병원 일지에서 다음 날을 시작한다.
2. 민지의 **접수 맡기기**를 선택한다. **직접 할게요**와 **이번 제안 건너뛰기**는 위임을 켜지 않는다.
3. 하단 **설정 · 접수**에서 언제든 직접/민지에게 맡김을 바꾼다. 안내를 꺼둔 경우에도 이 경로를 사용할 수 있다.
4. CT를 마친 환자는 환자 목록이나 기존 진료 알림으로 찾아 **계획 맡기기**를 누른다.
5. 저장 복원 직후에는 재생을 누른다. 안내 설정과 접수 위임 설정은 별개다.

## 구현과 저장

- `admission_duty.gd`에 안내 직원의 접수 역할만 분리했다. 고용·급여·계획 자동화·새 경제·직원 관리 화면은 없다.
- 실제 `waiting` 환자 중 도착 순서(ID)대로 한 명을 골라 **시뮬레이션 시간 3초** 준비한 뒤 기존 `HospitalSimulation.admit()`를 호출한다. 다음 환자에게 새 3초를 적용한다. 입장 중인 환자는 대상이 아니다.
- 수동 접수가 먼저 성공하면 대상 변경 시 준비 시간이 초기화된다. 기존 상태 검사·CT 예약·FIFO가 중복을 막는다. 프레임마다 명령을 보내거나 비동기 예약을 쌓지 않는다.
- 수동·자동 성공의 공통 `admitted` 신호가 기존 민지 응대 모션을 실행한다. 자동 접수는 환자 선택·카드 열기·카메라 이동을 호출하지 않는다.
- 위임 중에는 `민지 접수 대기`와 짧은 말풍선을 표시하며 직접 먼저 접수하는 버튼도 유지한다. 진료 알림과 목록 강조는 직접 계획 검토가 필요한 환자를 가리킨다.
- 제안은 첫 표시 시 확인 여부를 저장한다. 읽다가 종료해도 자동 동의하거나 반복하지 않는다. 설정에서 선택을 바꿀 수 있다. 안내를 끈 경우 제안을 강제로 표시하지 않는다.
- 저장 v2에 선택적인 `staff_admission` v1(enabled, offer_seen, candidate_id, elapsed)을 추가했다. 기존 저장에 없으면 꺼짐이다. 전체 후보를 검증한 뒤 복원하며 잘못되거나 미래 버전인 메타데이터는 기존 파일을 덮어쓰지 않는다.
- 사용자 일시정지·병원 밖·앱/웹 비활성화가 기존 시뮬레이션 시간을 멈춘다. 복원은 기존처럼 일시정지 상태다. 위임을 끄면 준비 대상을 즉시 지운다. 다음 날은 설정만 유지하고 준비 시간은 새로 시작한다.

원문 [직원·자동 운영 기획](../reference/season-one-design-v1.0.md)의 역할 분리와 3초 준비를 사용했다. 원문의 채용·직원 챕터 해금보다 이번 사용자 요청인 **기존 민지·2일차·무료**를 우선했다. 일반 채용과 자동 계획은 별도 후속 범위다.

## 작은 화면

기존 `mobile-playtest/chromium-844x350-card.png`의 설정 버튼을 대화 아래에서 병원 밖 버튼 옆 하단 영역으로 옮겼다. 터치 크기를 줄이지 않았다. 설정/제안 패널이 열릴 때 같은 왼쪽 영역의 줌 버튼은 숨기고 닫으면 복원한다. 실제 카메라 확대 값은 유지한다.

844×350, 844×390, 915×412, 1280×720에서 렌더링·입력을 검사했다. 작은 화면에는 좌우 47·하단 21 포인트의 안전 영역을 주입했다. 주요 버튼 최소 44 표시 픽셀, 제안 본문 최소 16 표시 픽셀, 실제 줄 높이·패널 간 비겹침을 검사하고 캡처를 직접 확인했다. **Linux 입력·안전 영역 모사**이며 휴대폰 실기기 검증은 아니다.

## 재현 명령

```sh
./tools/test-godot.sh
python3 tools/test-mobile-lifecycle.py
python3 tools/run-visual-qa.py --staff-check --output-dir artifacts/staff-ui
python3 tools/run-visual-qa.py --story-check --output-dir artifacts/staff-story-regression
python3 tools/run-visual-qa.py --output-dir artifacts/staff-scene-regression
python3 tools/run-visual-qa.py --movie --staff offer --output-dir artifacts/staff-video-offer
python3 tools/run-visual-qa.py --movie --staff flow --output-dir artifacts/staff-video-flow
python3 tools/run-visual-qa.py --movie --staff restore --output-dir artifacts/staff-video-restore
python3 tools/export-game.py Web
python3 tools/test-web.py
python3 tools/test-web.py --touch --staff --save-timeout 900
python3 tools/package-mobile-web.py
python3 tools/package-mac-project.py
```

그래픽 검사·브라우저·녹화는 소프트웨어 렌더러 자원 경쟁을 피하도록 순서대로 실행한다. 테스트 저장은 별도 경로/프로필이며 사용자 저장은 초기화하지 않는다.

## 결과와 제한

최종 수치·빌드 커밋·체크섬은 [검사 기록](staff-admission-results.json), 영상과 캡처는 [검토 페이지](staff-admission.html)에 모은다. 첫날·모션·경제·카메라 회귀, 제안 수락/거절/건너뛰기, 수동/자동 경합, CT 순서, 일시정지·저장 재실행·기존 저장·다음 날 유지가 검증 대상이다.

영상은 **Linux Godot 4.6.3 Compatibility/OpenGL llvmpipe의 자동 입력, 정상 1배속**이다. 녹화 전에 정상 운영 명령으로 첫날을 완료하고 2일차 체크포인트를 준비한다. 플레이 프레임은 배속·생략하지 않는다. 세 번째 영상의 복원은 QA가 실제 저장 파일을 `SaveStore.load_into()`로 다시 읽는 동작이다. 실제 OS 프로세스 종료·재실행은 별도 테스트로 확인한다. 새 불러오기 UI를 추가한 것은 아니다.

민지는 기존 짧은 응대 모션을 재사용한다. 업무별 정교한 연기·직원 이동·채용·숙련도는 아직 없다. Android·iPhone 실기기 실행·성능·발열·OS 강제 종료·실제 Safari 저장 지속성은 **여전히 미완료**다. 이번 기능 검사를 실기기 검증 완료로 바꾸지 않는다. 기존 Android APK는 이전 모바일 준비 소스이며 이번 전달용 Web/Mac 프로젝트와 버전 범위를 구분한다.
