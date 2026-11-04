# 햇살병원 3D 소스

병원 내부·치료 별관·환자·간호사의 원본 Blender 파일을 `source/`에 보관한다. 게임은 `godot/assets/models/`의 GLB를 실제 3D 공간에서 사용한다. 사용자가 보여 준 이미지는 미술 방향의 참고이며 배경 그림으로 게임에 붙이지 않았다.

이번 모델과 표면 패턴은 이 저장소의 Blender Python 코드로 작성했다. 외부 에셋 팩·생성 이미지·외부 텍스처를 포함하지 않는다. `.blend`에는 원본 메시와 텍스처가 패킹되어 있다. 정적 병원 파일에는 게임용으로 합쳐진 메시와 별도로 `editable parts` 컬렉션의 가구별 원본이 들어 있다. 원본 편집 시 컬렉션의 모니터·렌더 표시를 켜고 합쳐진 메시를 숨긴다. 제작 코드로도 재생성할 수 있다.

| 모델 | 편집 원본 | 게임 파일 |
| --- | --- | --- |
| 병원 내부 | [hospital-interior.blend](source/hospital-interior.blend) | [GLB](../godot/assets/models/hospital-interior.glb) |
| 치료 별관 | [treatment-annex.blend](source/treatment-annex.blend) | [GLB](../godot/assets/models/treatment-annex.glb) |
| 민지 | [nurse.blend](source/nurse.blend) | [GLB](../godot/assets/models/nurse.glb) |
| 환자 | [patient.blend](source/patient.blend) | [GLB](../godot/assets/models/patient.glb) |

## 재생성

Blender 4.3.2와 Godot 4.6.3으로 확인한다. 일반 게임 실행에는 Blender가 필요 없다.

```sh
blender -b --factory-startup -t 8 --python tools/art/build_assets.py
blender -b --factory-startup -t 8 --python tools/art/build_characters.py
blender -b --factory-startup -t 8 --python tools/art/preview_sources.py
python3 tools/art/build_ui.py
./tools/setup.sh
python3 tools/run-visual-qa.py --art-capture --portraits --output-dir="$PWD/artifacts/art-review"
cp artifacts/art-review/portrait-*.png godot/assets/ui/
./tools/setup.sh
```

저장된 정적 Blender 소스만 다시 내보낼 때:

```sh
blender -b --factory-startup -t 8 --python tools/art/export_models.py
```

## 게임용 처리

- 내부 정적 메시: 최대 300,000 삼각형. 원본은 보존하고 작은 반복 부품을 베이크 전에 감량한다. CT 외장·쿠션·접수대·치료 헤드의 큰 곡면을 보호한다. 현재 내부는 264,470 삼각형이다. 실제 수치는 `godot/assets/models/asset-report.json`에 기록한다.
- UV0: 목재·직물의 표면 색. UV1: 별도 펼침으로 구운 접촉 음영(AO), 내부 2048² / 별관 1024². Godot에서 사용하는 두 UV 채널을 넘어가지 않도록 제작 과정에서 확인한다.
- Godot 4.6.3에서 별도 AO 텍스처를 가져올 때 UV 설정이 기본값으로 남는 현상을 `import_hospital.gd` 후처리로 보정한다. 실제 엔진 재질 검사도 유지한다. 중간 베이크 PNG가 있는 `assets/textures/`는 웹 배포에서 제외하고 모델에 연결된 텍스처만 사용한다.
- 캐릭터: 머리·팔·다리의 명명된 피벗, 별도 앉은 다리와 책·안경. 접촉 음영은 정점 색에 굽는다. 이는 뼈대/스킨을 갖춘 최종 리깅이나 표정 애니메이션은 아니다.
- 화면 전달: Blender 미리보기 대신 실제 Godot 렌더와 실제 입력 시연 영상을 사용한다.

모바일 GPU의 프레임 속도·발열·메모리 예산은 실기기에서 추가 확인해야 한다. 삼각형 상한과 브라우저 입력 검사는 iPhone 성능 검증을 대신하지 않는다.

최신 재질·그림자 진단·UI 적용 기준과 목표 시안에 남은 차이는 [아트 검토](../docs/art-review.md), 동일 카메라 전후 화면은 [비교 페이지](../docs/art-review.html)에 정리한다. Blender 검토 카메라와 조명은 편집용이며 최종 캡처는 실제 Godot에서 만든다.

## 치료 자세·표면 보정

본원·별관의 치료기와 침대는 -35° 방향으로 배치한다. 원본 편집 파트·게임 메시·구운 AO가 같은 배치를 사용한다. `build_assets.py`로 새로 만들 때도 이 각도를 적용한다. `turn_treatment_couches.py`는 3119d2f의 원본을 이전하는 일회성 도구이며, 현재 원본에 다시 적용할 필요는 없다. 실행할 경우 `--python-exit-code 1`로 Blender Python 오류를 셸에 전달한다.

현재 Godot 외형은 `assets/models/import_hospital.gd`의 재질별 보정도 사용한다. 원본 기본색을 보존하면서 코팅 외장·목재·직물의 거칠기와 반사, 텍스처 색의 배율을 엔진에서 구분한다. [적용 값과 검증](../docs/play-feedback.md)을 참고한다.
