---
name: app-catalog
description: Use when producing full-screen snapshot images of app scenes for external communication — 디자인 목업·기능 설명 등 앱의 모양을 외부에 보여줄 화면 카탈로그 촬영·확장 절차. Triggers on "앱 화면 카탈로그 떠줘", "화면 스샷 모아줘", "이 화면 카탈로그에 추가해". Does NOT trigger on 구현 검증용 스냅샷(snapshot-check 스킬).
---

# App Catalog — 화면 카탈로그 촬영

앱이 제공하는 화면들을 대표 더미 데이터로 렌더한 풀스크린 이미지 세트 — **기록 용도**(디자인 목업·기능 소개 등 외부에 앱 모양을 설명). 구현 검증(snapshot-check)과 완전 별개 스킬. 이미지는 전용 경로 `snapshot-catalog/<Framework>/<스위트>/`(gitignored)에 생성 — 비커밋, 요청 시마다 재생성. **카탈로그 테스트 코드는 커밋 유지** — 재생성 가능성이 자산이다.

## 1. 스위트 위치

- 각 Scene 프레임워크의 `Snapshots/<Name>CatalogSnapshots.swift`.
- 새 화면 추가: 대상 프레임워크에 Snapshots 타겟이 없으면 snapshot-check §2와 동일하게 활성화 후 카탈로그 테스트 파일에 케이스 추가.
- 확장 타겟(위젯 등)은 `TodoCalendarApp/AppExtensions/<Ext>/Snapshots/`에 배치. `Project.makeAppExtensionTargets(..., snapshotTests: true)`로 활성화.

## 2. 화면 구성 — 더미 데이터

- 화면당 대표 상태 1개(정보가 풍부한 상태)로 구성. 상태 조합 나열 금지 — 그건 snapshot-check의 검증 영역.
- 구성 소스 우선순위: ① 대상 뷰 파일의 #Preview/PreviewProvider (더미 구성 그대로 재사용) ② TestDoubles의 Dummies·Stub ③ 직접 구성.
- 라이트·다크 pair 자동(captureSnapshotPair). layout은 풀스크린 화면이면 `.fullScreen`, 위젯·부분 컴포넌트면 `.fixed`.
- **더미 텍스트는 하드코딩하지 않는다.** 화면에 뜨는 문구는 두 갈래다:
  - 실제 화면에서 로컬라이즈된 값이 들어가는 자리(반복 주기·알림 시각·태그명·`Todo` 배지)는 **프로덕션 경로로 만든다** — 키를 `.localized()` 로 부르거나, 도메인 모델을 세워 프로덕션 이니셜라이저(`TodoEventCellViewModel(_:in:_:_:)` 등)에 넘긴다. 손으로 적은 문자열은 프로덕션이 실제로 그리는 값과 어긋나기 쉽다.
  - 유저가 입력했을 법한 콘텐츠(이벤트 이름·메모·AI 명령문)는 `SnapshotTestHelpKit` 의 `Resources/<lang>.lproj/CatalogStrings.strings` 에 넣고 `"키".catalogLocalized()` 로 부른다. **앱 lproj 에 넣지 않는다** — 프로덕션에 안 뜨는 문구가 앱 번들과 파리티 검사에 섞인다.
- **캡처 호출에 `snapshotDirectory: catalogSnapshotDirectory()` 필수** — 검증용 기본 경로(`__Snapshots__/`)와 격리해 `snapshot-catalog/<Framework>/<스위트>/`에 기록한다.

## 3. 촬영·수집

기본 규격은 snapshot-check §3과 동일 (기기 iPhone 17 / iOS 26.2, en 고정):

```bash
xcodebuild test -workspace TodoCalendar.xcworkspace -scheme <Name>Snapshots \
  -only-testing:<Name>Snapshots/<Name>CatalogSnapshots \
  -destination 'platform=iOS Simulator,name=iPhone 17 - snapshot_ref,OS=26.2' \
  -testLanguage <언어> -testRegion <언어>_<지역> | xcpretty
```

- **`-only-testing` 은 필수다.** 같은 스킴에 검증 스위트(`__Snapshots__/`, 커밋 대상)가 함께 살아서, 한정하지 않으면 그쪽이 이 언어·이 시점으로 재기록돼 워킹트리가 오염된다. 실행 후 `git status --short -- '*__Snapshots__*'` 가 비어 있어야 한다.
- **언어는 요청받은 것으로 바꾼다.** 지정이 없으면 en/en_US.
- 서비스 이용 가이드용 전 언어 촬영은 `scripts/capture-guide-screenshots.sh` 가 위 절차와 파일명 매핑을 감싼다 (`.claude/rules/localization.md` §1 가이드 절).

- **기기 변경 가능**: 유저가 다른 기기·OS로 요청하면 `-destination`의 name/OS 교체 (`xcrun simctl list devices available`로 가용 확인). 여러 기기 세트 요청이면 destination만 바꿔 반복 실행.
- 기본 시뮬레이터가 없으면 생성: `xcrun simctl create 'iPhone 17 - snapshot_ref' 'iPhone 17' iOS26.2`.
- 결과는 `snapshot-catalog/<Framework>/<스위트>/`에서 수집 — SendUserFile로 전달하거나 유저 지정 위치로 복사.
- 요청마다 재생성 — 이미지 보관·커밋 금지 (`snapshot-catalog/` gitignored).

## 4. 확장 원칙

- 화면 확장은 점진 — 요청된 화면만 추가, 한 번에 전 화면 배선 금지.
- 풀스크린 뷰가 ContainerView(ViewModel 직접 참조) 형태면 내부 View + state 주입 경로로 렌더한다 — 각 뷰의 프리뷰가 이미 그 경로를 쓴다.
