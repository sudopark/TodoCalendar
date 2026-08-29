---
name: snapshot-check
description: Use when verifying implemented UI against a design spec or reference in this project — 구현 단계 디자인 검증용 스냅샷 캡처·대조 절차와, 캡처 테스트가 존재하는 뷰 수정 시의 재검증 절차. Triggers on "스냅샷 떠서 확인해", "디자인 스펙이랑 대조해", design 스킬 §5 검증 단계, 캡처 테스트가 있는 뷰·컴포넌트를 구현 중 수정했을 때(재검증). Does NOT trigger on 캡처 테스트 선제 신설(유저 지시 시에만), 외부 설명용 화면 카탈로그(app-catalog 스킬), CI 회귀 게이트(미도입).
---

# Snapshot Check — 구현 UI 스냅샷 검증

회귀 게이트가 아니다 — 테스트는 record 전용이라 항상 pass. 목적은 구현된 뷰를 이미지로 떠서 에이전트가 직접 보고 디자인 스펙·레퍼런스와 대조하는 것. **캡처 테스트 코드와 생성 이미지(`__Snapshots__/`) 모두 검증 대상 구현과 함께 커밋이 기본** — 같은 뷰를 다시 만질 때 재실행하는 재검증 자산이자 검증된 모습의 기록이다. 외부 설명용 화면 촬영(app-catalog)과는 완전 별개 스킬이다.

## 1. 대표 케이스 선정

- 뷰 상태는 주입 state(`XxxViewState`)·파라미터 조작으로 전부 시뮬레이션 가능 — 시뮬레이터 네비게이션 불필요.
- **케이스 폭발 금지.** 모든 상태 조합을 뜨지 않는다. 대표 케이스는:
  1. 매칭 ViewModel·VM 테스트에서 유추 (상태 분기·대표 시나리오)
  2. 유추가 제한되면(VM 없음, 분기 불명) **유저에게 반문**
- 라이트·다크는 케이스마다 자동 pair — 케이스 수에 세지 않는다.

## 2. 캡처 테스트 작성

- **신설은 유저가 지시할 때만.** 뷰를 구현·수정했다고 선제적으로 캡처 테스트를 만들지 않는다 — 이미 있는 대상은 §5 재검증만 탄다.
- 대상 프레임워크에 Snapshots 타겟이 없으면: Project.swift 팩토리 호출에 `snapshotTests: true` 추가 + `Snapshots/` 폴더 생성 + `mise exec -- tuist generate --no-open`.
- `Snapshots/`에 XCTestCase 작성 — SnapshotTestHelpKit의 `captureSnapshotPair(named:layout:makeView:)` 사용. `makeView`가 theme별 ViewAppearance를 구성한다 (`colorSetKey` 라이트/다크 키 + `isSystemDarkTheme`). 구성 패턴은 대상 뷰 파일의 #Preview/PreviewProvider와 기존 Snapshots 테스트(`CommonPresentation/Snapshots/`)를 재사용.
- layout: 컴포넌트 → `.component`(sizeThatFits) / 화면 → `.fullScreen` / 필요 시 `.fixed(width:height:)`.

## 3. 실행 — 촬영 규격

기본 기기 iPhone 17 / iOS 26.2, 언어 en 고정:

```bash
xcodebuild test -workspace TodoCalendar.xcworkspace \
  -scheme <Name>Snapshots \
  -destination 'platform=iOS Simulator,name=iPhone 17 - snapshot_ref,OS=26.2' \
  -testLanguage en -testRegion en_US | xcpretty
```

- 기기·OS 오버라이드: 유저 지정 시 `-destination`의 name/OS만 교체 (`xcrun simctl list devices available`로 가용 확인).
- 기본 시뮬레이터가 없으면 생성: `xcrun simctl create 'iPhone 17 - snapshot_ref' 'iPhone 17' iOS26.2`.
- **CI·run-all-tests.sh에 Snapshots 스킴을 등재하지 않는다** — 로컬 전용이 설계다 (CLAUDE.md 스킴 짝 규칙의 의도된 예외).

## 4. 확인·대조

- 이미지는 `<프레임워크>/Snapshots/__Snapshots__/<테스트클래스>/`에 `<테스트메서드>.<name>-light.png`/`<테스트메서드>.<name>-dark.png` pair로 생성된다 (예: `test_bottomConfirmButton.bottomConfirmButton-light.png`).
- Read로 이미지를 직접 보고 디자인 스펙·레퍼런스와 대조 — 어긋난 항목은 스펙 기준으로 수정 후 재캡처.
- 유저 확인이 필요하면 SendUserFile로 이미지 전달.

## 5. 재검증 — 캡처 대상 수정 시

구현 중 수정한 뷰(또는 그 뷰가 쓰는 공용 컴포넌트·토큰)에 캡처 테스트가 이미 있으면(`grep -rl "<ViewName>" Presentations/*/Snapshots/`) 해당 `<Name>Snapshots` 스킴을 §3대로 재실행한다. 단 **검증 스위트만 대상** — grep 히트가 `catalogSnapshotDirectory()`를 쓰는 카탈로그 스위트뿐이면 재검증 대상이 아니다 (카탈로그는 gitignored 경로에만 기록해 아래 git 비교가 성립하지 않는다).

- 검증 이미지가 커밋돼 있으므로 **git이 비교기다**: 실행 후 `git status --short -- '*__Snapshots__*'`로 png 변화를 확인한다.
- **변화 없음** → 외형 무영향. 그대로 진행.
- **변화 있음 + 이번 수정이 그 뷰의 외형 변경을 의도함** → 갱신 png를 Read로 열어 의도한 변화가 맞는지 확인 후, 구현 커밋에 함께 포함(재기록).
- **변화 있음 + 외형 변경 의도 없었음** → 이상 신호. 커밋하지 말 것 — 변경 전(`git show HEAD:<png 경로> > /tmp/old.png` 후 Read)·후 이미지를 비교해 원인을 추론(공용 컴포넌트 파급, ColorSet/Metric 토큰 변경, 레이아웃 부수효과 등)하고 **유저에게 보고** 후 판단을 기다린다. png는 `git restore`로 원복해 둔다.

## 6. 커밋 정책

- 캡처 테스트는 검증 대상 구현과 같은 작업 커밋에 포함한다 — 삭제하지 않는다. 이후 그 뷰를 수정할 때 재실행으로 재검증.
- 이미지(`__Snapshots__/`)도 캡처 테스트와 같은 커밋에 포함한다 — 재캡처 시 갱신분도 함께 커밋. 비커밋은 카탈로그(`snapshot-catalog/`)뿐.
- app-catalog로의 전환·승격 없음 — 기록 용도 촬영은 처음부터 app-catalog 경로로 작성한다.

## 7. 종료 기록 — skill_end

**유저가 이 스킬을 직접 호출한 독립 런에서만** 남긴다. 대조 결과(스펙과 어긋난 항목 / 이상 없음)를 보고한 직후 `log-record.py skill_end --name snapshot-check` (명령·compliance 규칙은 CLAUDE.md §1).

**다른 스킬 안에서 도구로 호출된 경우는 기록하지 않는다** — implement 구현 중 호출되는 위 §5 재검증, design 스킬 §5 검증 단계 등. 런을 마무리하는 전이는 호출한 스킬 쪽이고 종료 레코드도 거기서 남는다. 여기서 또 남기면 한 런에 종료가 두 겹으로 쌓여 호출 스킬의 준수 신호와 섞인다.

종속 호출로 뜨는 구조적 누락률은 `usage-thresholds.json`의 `missing_rate_exempt_skills`로 처리한다 — 누락률 숫자를 근거로 위 기록 범위를 넓히지 않는다.
