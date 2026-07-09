---
name: app-catalog
description: Use when producing full-screen snapshot images of app scenes for external communication — 디자인 목업·기능 설명 등 앱의 모양을 외부에 보여줄 화면 카탈로그 촬영·확장 절차. Triggers on "앱 화면 카탈로그 떠줘", "화면 스샷 모아줘", "이 화면 카탈로그에 추가해". Does NOT trigger on 구현 검증용 스냅샷(snapshot-check 스킬).
---

# App Catalog — 화면 카탈로그 촬영

앱이 제공하는 화면들을 대표 더미 데이터로 렌더한 풀스크린 이미지 세트 — **기록 용도**(디자인 목업·기능 소개 등 외부에 앱 모양을 설명). 구현 검증(snapshot-check)과 완전 별개 스킬. 이미지는 전용 경로 `snapshot-catalog/<Framework>/<스위트>/`(gitignored)에 생성 — 비커밋, 요청 시마다 재생성. **카탈로그 테스트 코드는 커밋 유지** — 재생성 가능성이 자산이다.

## 1. 스위트 위치

- 각 Scene 프레임워크의 `Snapshots/<Name>CatalogSnapshots.swift`. 시범 구축분: SettingScene(설정 목록·국가 선택), MemberScenes(로그인).
- 새 화면 추가: 대상 프레임워크에 Snapshots 타겟이 없으면 snapshot-check §2와 동일하게 활성화 후 카탈로그 테스트 파일에 케이스 추가.

## 2. 화면 구성 — 더미 데이터

- 화면당 대표 상태 1개(정보가 풍부한 상태)로 구성. 상태 조합 나열 금지 — 그건 snapshot-check의 검증 영역.
- 구성 소스 우선순위: ① 대상 뷰 파일의 #Preview/PreviewProvider (더미 구성 그대로 재사용) ② TestDoubles의 Dummies·Stub ③ 직접 구성.
- 라이트·다크 pair 자동(captureSnapshotPair), 언어 en 고정, layout은 `.fullScreen`.
- **캡처 호출에 `snapshotDirectory: catalogSnapshotDirectory()` 필수** — 검증용 기본 경로(`__Snapshots__/`)와 격리해 `snapshot-catalog/<Framework>/<스위트>/`에 기록한다.

## 3. 촬영·수집

기본 규격은 snapshot-check §3과 동일 (기기 iPhone 17 / iOS 26.2, en 고정):

```bash
xcodebuild test -workspace TodoCalendar.xcworkspace -scheme <Name>Snapshots \
  -destination 'platform=iOS Simulator,name=iPhone 17 - snapshot_ref,OS=26.2' \
  -testLanguage en -testRegion en_US | xcpretty
```

- **기기 변경 가능**: 유저가 다른 기기·OS로 요청하면 `-destination`의 name/OS 교체 (`xcrun simctl list devices available`로 가용 확인). 여러 기기 세트 요청이면 destination만 바꿔 반복 실행.
- 기본 시뮬레이터가 없으면 생성: `xcrun simctl create 'iPhone 17 - snapshot_ref' 'iPhone 17' iOS26.2`.
- 결과는 `snapshot-catalog/<Framework>/<스위트>/`에서 수집 — SendUserFile로 전달하거나 유저 지정 위치로 복사.
- 요청마다 재생성 — 이미지 보관·커밋 금지 (`snapshot-catalog/` gitignored).

## 4. 확장 원칙

- 화면 확장은 점진 — 요청된 화면만 추가, 한 번에 전 화면 배선 금지.
- 풀스크린 뷰가 ContainerView(ViewModel 직접 참조) 형태면 내부 View + state 주입 경로로 렌더한다 — 각 뷰의 프리뷰가 이미 그 경로를 쓴다.
