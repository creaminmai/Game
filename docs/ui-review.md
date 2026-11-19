# 햇살병원 Unity UI 검토

기준은 로컬 `6508ad8`과 GitHub의 민지 지침 `aeae265`다. Unity 6000.6.9f1 (8c45277fb9c5), URP, Metal에서 실행했다. 시안 보관은 `eb6acfa`, 알파·UI 구현은 `3e41ac6`이다.

## 참조와 제작

- [승인된 시안 원본](../reference/art/minji-dialogue-concept.png)은 Mac Downloads에서 파일명을 NFC로 비교해 찾았다. 원본과 복사본을 바이트 단위로 대조했다. SHA-256은 `533cecda9ce90308ec951fc86498df433375ae8fec9adb5cd4ecbf529e6d3f0a`다. [민지 연출 지침](minji-dialogue-art-direction.md)에서 원본을 볼 수 있다.
- 저장소의 [이전 UI 아트 검토](art-review.md), [Godot 환영 화면](images/first-day-polish/desktop-01-welcome.png), [Godot 접수 화면](images/first-day-polish/desktop-03-admission.png), `godot/assets/ui/`의 초상과 SVG를 참조했다. 메뉴에는 기존 그림과 `art/ui/`의 신규 SVG를 PNG로 가져왔다.
- 민지 전경 초상은 승인 UI 이미지에서 인물의 헤어·의상·배지를 참조해 인사와 설명 두 포즈를 별도의 투명 PNG로 제작했다. 실제 3D 장면과 골드 테두리 프레임, 이름·직책 배지, 대사, 다음 버튼을 Unity에서 조합했다. 인사와 설명에 다른 표정을 연결했다. 별도 기쁨·걱정 이미지는 제작 대기다.
- 주아체는 제목·주요 행동·금액에 적용했다. 본문·안내·환자 상태는 기존 Noto Sans CJK KR을 사용한다. 주아는 [공식 제작자 안내](https://www.woowahan.com/fonts), [Google Fonts 배포본](https://github.com/google/fonts/blob/main/ofl/jua/Jua-Regular.ttf), [OFL 1.1 원문](https://raw.githubusercontent.com/google/fonts/main/ofl/jua/OFL.txt)을 확인했다. OFL은 폰트 단독 판매를 제한하며 저작권과 라이선스를 함께 제공할 때 상업용 앱에 포함할 수 있도록 허용한다. 배포 폰트와 [라이선스](../unity/Assets/Resources/Jua-OFL.txt)를 함께 넣었다. [기존 Noto 라이선스](../unity/Assets/Resources/FONT-LICENSE.txt)도 유지했다.
- IMGUI 동적 폰트에 필요한 글리프를 사용하고 Jua에 기존 Noto를 대체 글꼴로 지정했다. 숫자 캡슐은 폭과 오른쪽 정렬을 고정했다. 이름, 접수·계획, `900만`, `1,100만`, `0/6`, `00:30`을 글리프 검사에 넣었다. 가운데점은 Noto가 제공한다. 실기기 폰트 메모리는 미측정이다.

## 화면과 영상

| 범위 | 검토 자료 |
| --- | --- |
| 승인 시안과 실행 결과 | [왼쪽 시안 / 오른쪽 실제 Unity](images/unity-ui-review/minji-concept-and-unity.png) |
| 같은 첫날 상태의 UI 비교 | [변경 전 구성](images/unity-ui-review/welcome-before.png) · [인사](images/unity-ui-review/welcome.png) · [다음 줄과 설명 표정](images/unity-ui-review/welcome-next.png) |
| 운영과 환자 | [기본 병원](images/unity-ui-review/interior.png) · [접수](images/unity-ui-review/selected.png) · [예약 목록](images/unity-ui-review/patients.png) · [계획 지시](images/unity-ui-review/plan.png) · [치료 진행](images/unity-ui-review/treatment.png) |
| 관리 | [증축](images/unity-ui-review/expansion.png) · [직원](images/unity-ui-review/staff.png) · [연구](images/unity-ui-review/research.png) · [하루 결과](images/unity-ui-review/day-result.png) · [설정](images/unity-ui-review/settings.png) · [꾸미기](images/unity-ui-review/decor.png) |
| 세 병원 | [지도](images/unity-ui-review/three-hospital-map.png) · [본원 외부](images/unity-ui-review/main-exterior.png) · [물빛 외부](images/unity-ui-review/riverside-exterior.png) · [바다빛 외부](images/unity-ui-review/coast-exterior.png) · [바다빛 내부](images/unity-ui-review/coast-interior.png) |
| 실제 입력 | [정상 속도 키보드 영상](media/minji-dialogue-input.mp4) · 약 29.1초 · 구간 생략 및 배속 없음 |

전후 비교 두 장은 같은 첫날 상태와 2560×1440 Game 뷰에서 기존 HUD 구성과 새 HUD를 전환해 촬영했다. 고정 카메라 방향은 유지하고 HUD가 차지하던 렌더 영역 크기를 바꿨다. 저장소 검토용 PNG는 1280×720이다. 원본 캡처는 Mac의 `artifacts/unity-overnight/alpha-ui/`, 입력 원본 MP4는 `artifacts/unity-overnight/minji-dialogue/input.mp4`에 있다.

## 검증

- **직접 입력.** Unity Game 뷰에서 테스트 슬롯을 연 뒤 Enter로 인사 두 줄을 넘기고 접수 안내를 닫았다. 1로 김영수를 선택하고 Enter로 접수했다. 로그는 `Input action confirmed for patient 1: WalkingToCt`를 기록했다. 영상은 이 실제 키 입력으로 녹화했다. 마우스 클릭은 Computer Use의 `noWindowsAvailable` 이후 반복하지 않았다.
- **에디터 자동.** 두 표정 렌더, 격리 저장에서 두 번째 인사 줄 복원, 환영 종료 후 일시정지 값 유지, 환자 목록·계획·치료·정산·설정·연구·지도·꾸미기 화면을 확인했다. 후반 화면은 운영 함수를 가속 호출해 조건에 도달했다. 세 병원 선택을 포함한 격리 슬롯 복원을 확인했다.
- **독립 검사.** 병원 체크 240개와 설치된 Unity 어셈블리를 이용한 Player·Editor C# 검사를 통과했다. 버전 5의 두 병원 저장 이전, 버전 6의 세 병원 상태, 구매 1회 결제, 기존 저장 보관을 검사했다.
- **독립 Mac 빌드.** arm64 개발 빌드가 오류 0으로 끝났다. 이전 QA 플레이어를 닫고 Finder에서 새 앱을 실행해 시작 화면의 주아 제목과 한글 본문·버튼을 직접 확인했다. Mac 앱 전체 플레이와 앱 재실행 후 복원은 미확인이다.
- **남은 범위.** 마우스와 모바일 터치로 지도·연구·꾸미기·저장을 끝까지 조작하는 검사, 긴 가로 비율의 실제 실행 캡처와 기기 UI, 대화 퇴장 페이드, 추가 민지 표정, 전체 시즌 평가·챕터 보상이 남아 있다. 이번에 사용자가 직접 확인한 항목은 없다.

Mac 개발 앱은 `artifacts/unity-overnight/builds/SunshineHospital.app`에 있다. Android·iOS 플레이어 지원 디렉터리는 이 설치에서 찾지 못했으며 Xcode CLI 경로는 Command Line Tools다.

GitHub 커넥터로 `main`의 `aeae265` 원문을 확인해 이 작업에 반영했다. 로컬의 `git fetch origin main`은 `Could not resolve host: github.com`으로 실패했다. 로컬 Git 이력과 원격 커밋의 병합 및 푸시는 보류 상태다. 이 문서의 영상과 PNG는 로컬 커밋에 있으며 원격에서 아직 볼 수 없다.
