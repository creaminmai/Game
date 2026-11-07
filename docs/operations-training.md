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
python3 tools/test-web.py --touch --operations --save-timeout 900
```

브라우저 기능 검사는 `artifacts/operations-rehearsal-education/checkpoint.json` 또는 같은 영상의 정상 운영 체크포인트를 별도 브라우저 프로필에 넣는다. `--movie --operations education --mobile-preview --rehearsal --output-dir artifacts/operations-rehearsal-education`으로 생성할 수 있다. 사용자 저장은 사용하지 않는다.

결과 영상과 최종 검사 수·소스 커밋·파일 체크섬은 아래 전달 기록에서 확인한다. Linux 실제 엔진 영상은 자동 입력, 정상 1배속이다. 녹화 전에는 정상 접수·계획·증축·다음 날 명령으로 3일을 진행해 체크포인트를 만들었다. 완료 영상만 같은 방식으로 4일차 실제 위임 방문 3회 귀가 및 마지막 귀가 직전까지 준비한다. 영상 재생 중 돈·업무 출처·귀가 횟수를 강제로 설정하거나 배속하지 않는다. 녹화 24fps는 휴대폰 성능 측정치가 아니다.

## 남은 한계

- 교육/자동 계획의 직원 반응은 기존 짧은 고개·응대 제스처를 재사용한다. 전용 서류 작업 애니메이션, 실제 교육 장면은 후속 작업이다.
- 카메라·조명·모델·임시 진료 시간과 하루 네 명은 현재 프로토타입 기준을 유지했다. 임상 판단이나 계획 퍼즐을 새로 구현한 것이 아니다.
- Android APK 생성·서명/내용 검사와 실제 기기 설치·실행은 구분한다. Android/iPhone 실기기, Safari, Xcode 서명 앱, 모바일 FPS·발열·배터리는 **미검증**이다.
- Web 저장, Android 앱 저장, Mac Godot 저장은 자동 공유되지 않는다. 같은 개발 서명·식별자로 APK 업데이트하며 기존 앱 삭제나 데이터 초기화는 하지 않는다.
