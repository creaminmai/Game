# 민지 단순 3D 검토본

GitHub main의 `237ca7a`에서 [시트 원본](../reference/art/minji-simple-v1/minji-character-sheet.png)과 [제작 지시](minji-simple-character-direction.md)를 가져왔다. 시트 파일의 SHA-256은 원격 manifest와 일치한다. 새 캐릭터는 운영 화면과 대화 화면에 같은 에디터 검토용 프리팹을 사용한다. 일반 플레이에서는 기존 캐릭터를 사용한다.

## 실제 캡처

![시안 오른쪽 위 정면과 Unity 전신](images/minji-simple-v1/front-comparison.png)

왼쪽은 제작 시트의 오른쪽 위 인물, 오른쪽은 Unity의 정사영 렌더다. 머리 높이를 약 194px로 맞춰 비교했다. 정면 시트의 머리가 2.0등신에 가까워 새 모델도 약 2.0등신으로 조정했다. 시트의 몸과 팔은 머리 대비 조금 더 넓고, 턱은 더 둥글게 이어진다. Unity 검토본은 단발 아래쪽이 더 수평에 가깝고 눈 간격이 조금 더 좁다.

- [Unity 정면·45도·후면](images/minji-simple-v1/angles.png)
- [Unity 기본 미소·기쁨·설명](images/minji-simple-v1/expressions.png)
- [인사하는 Unity 대화 화면](images/minji-simple-v1/dialogue.png)
- [접수대 옆 민지가 보이는 운영 화면](images/minji-simple-v1/operations.png)
- [Unity 인사 영상](media/minji-simple-wave.mp4) — 12초, 960×540, 정상 속도. 처음에 손을 들고 두 번 흔든 뒤 설명과 기쁨을 보여 준다. 기존 대화 흐름을 호출한 자동 시연이다.
- [Blender 정면 전신과 45도 얼굴](images/minji-simple-v1/blender-model.png)

## 형태와 제작 파일

둥근 머리, 턱 옆까지 오는 매끈한 갈색 단발, 한쪽으로 흐르는 앞머리, 작은 몸과 짧은 목을 새 메시로 만들었다. 민트 A자 근무복에 아이보리 칼라, 단추, 해바라기 배지, 크림 바지와 청록 신발을 넣었다. 손은 장갑 형태의 손바닥과 둥근 엄지를 사용한다. Blender 초안과 시트를 비교해 귀의 돌출, 머리 안쪽 면의 정수리 침범, 소매 아래의 피부 경계를 바꿨다.

눈·반사점·입·볼은 얼굴 곡면을 따르는 얕은 그래픽 메시다. Unity에서도 일정한 대비를 유지하도록 glTF 무광·비조명 재질로 가져온다. 코는 작은 둥근 삼각형이다. 기쁨은 닫힌 곡선 눈과 작은 입, 설명은 눈썹 하나가 올라가는 표정이다. 어깨·팔꿈치·손목·머리 피벗의 동작을 Blender에서 만들고 `MinjiWave` 클립으로 내보냈다.

[편집 가능한 Blender 원본](../art/source/minji-simple-v1.blend) · [제작 스크립트](../tools/art/build_minji_simple.py) · [Unity GLB](../unity/Assets/Editor/HospitalArt/minji-simple-v1.glb) · [Unity 검토 프리팹](../unity/Assets/Editor/HospitalArt/MinjiSimpleReview.prefab)

## 실행 확인

Blender 4.5.16 LTS 앱에서 초안과 수정본을 렌더하고 새 `.blend`를 저장·재열기했다. Unity 6000.6.9f1 URP Metal의 `Hospital` 씬을 Play하고 Game 뷰에서 `Option+F1`을 눌렀다. 임시 첫날 상태에서 같은 모델을 큰 초상과 접수대 옆의 약 120px 운영 캐릭터로 확인했다. 촬영 뒤 시작 화면으로 복귀했다. 최종 Play의 Console은 경고 0건, 오류 0건이었다. Chrome에서 영상 재생을 확인했고 최종 MP4의 재생 길이는 12.035초였다.

병원 로직 검사 272개와 에디터·플레이어 독립 컴파일이 통과했다. 검토에서 환자 이동, 클릭 범위, 저장 코드와 기존 캐릭터 자산에 변경이 없다. 새 디자인의 모바일 기기 재생과 사용자 승인 여부는 남아 있다.
