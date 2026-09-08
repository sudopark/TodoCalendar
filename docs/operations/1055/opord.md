# 작전명령 (Operation Order) — DP

> 용어 — DP: 결정적 지점(작전명령 하나 = PR 하나) · LOE: 노력선(최종상태 한 관점을 담당하는 줄기) · FRAGO: 단편명령 · MOP / MOE: 과업 수행 여부 / 효과 발생 여부 · PIR / FFIR: 즉시보고 조건 중 환경·외부 정보 / 아군·내부 정보

```
작전명령 — #1055 WidgetScenes 신설과 D-day 위젯 뷰 이관       초안: 에이전트   재가:   일자: 2026-09-08
상위: campaign.md #721 / LOE-1 / 1단계 파일럿 / DP-1.1 / 선행 DP 없음
```

## ■ 확인보고

**임무 (내 말로)** — 위젯 뷰가 확장 타겟 안에만 있어서 앱이 못 그린다. 갤러리도 꾸미기도 여기서 막힌다. 그래서 `Presentations/WidgetScenes` 를 세우고 D-day 위젯의 순수 뷰·ViewModel 을 거기로 올린다. 옮긴 뒤에도 확장이 그리는 그림이 한 픽셀도 안 달라져야 하고, 그걸 스냅샷으로 증명한다. D-day 하나로 이관 계약(C1·C2)이 되는지 그림으로 확인하는 게 이 명령의 전부다.

**의도** — 목적은 나머지 위젯 18종을 옮기기 전에 이관 방식을 확정하는 것이다. 최종상태는 `WidgetScenes` 에 D-day 순수 뷰 5개가 있고 그 모듈이 WidgetKit 을 안 물며, 확장이 그걸 물어 그리고, 이관 전후 스냅샷 PNG 가 같은 상태다.

**자율로 정할 것** — `WidgetScenes` 안의 파일 분할·네이밍, `public` 을 어디까지 여는지, 스냅샷 테스트 케이스 이름, 커밋 묶음.

**묻는 것** — 하나 있다. 계약 C1 은 순수 뷰 생성자를 `init(model:style:)` 하나로 맞추라고 했는데, `style` 을 채울 `WidgetStyle` 은 DP-5.1 산출물이다. 지금 빈 타입을 먼저 만들면 소비자 없는 간접층이라 opord §신설 요소 최소 판정에 걸린다. **이번엔 `init(model:)` 로 두고 DP-5.1 이 `style` 을 붙이는 것으로 간다** — C1 의 최종형은 그대로다. 이견 있으면 재가 때 잡아 달라.

---

## 1. 상황

### 가. 정찰 결과

- `DDayWidget.swift` 한 파일에 층이 섞여 있다. 순수 뷰 5개(`DDaySmallWidgetView:64`·`DDayMediumWidgetView:98`·`DDayCircularWidgetView:146`·`DDayRectangularWidgetView:166`·`DDayInlineWidgetView:194`)와 공통 조각(`DDayTitleView:19`, `compactDetailText`/`detailText` 확장 `:46`)이 앞쪽에, WidgetKit 을 무는 `DDayWidgetEntryView:209`·`DDayWidget: Widget:251`·`PreviewProvider:274` 가 뒤쪽에 있다. 파일 머리에서 `import WidgetKit` 한다 (`:9`).
- 순수 뷰 5개는 WidgetKit API 를 안 쓴다. 단 `DDayCircularWidgetView:155` 가 `AccessoryWidgetBackground()` 를 쓰는데 이건 **WidgetKit 타입**이다 — 이관하면 `WidgetScenes` 가 WidgetKit 을 물게 되므로 처리가 필요하다 (T-3, 우발계획 참조).
- `DDayWidgetViewModelProvider.swift` 도 두 층이다. `DDayWidgetViewModel:19` 와 `.sample:40`·`noTarget():52` 가 앞, Domain 을 조회하는 `DDayWidgetViewModelProvider:66` 가 뒤다.
- `.sample:44` 가 `DDayTargetDateFormatter.dateText` 를 부르는데, 그 타입은 확장의 AppIntents 파일에 산다 (`Widget/Sources/Intents/DDayTargetSelectIntent.swift:62`). ViewModel 을 옮기면 이것도 따라와야 한다.
- 배경은 순수 뷰 **바깥**에서 그린다. `ResultTimelineEntry.backgroundShape:50` 이 `WidgetAppearanceSettings.Background` 를 `AnyShapeStyle` 로 해석하고, `DDayWidget.swift:262` 가 `.containerBackground(entry.backgroundShape, for: .widget)` 로 적용한다. 해석부는 `CommonPresentation`(`ColorSet`·`UIColor.from(hex:)`·`isLight`)에 기댄다.
- **D-day 는 스냅샷이 없다.** `WidgetCatalogSnapshots.swift` 에 `DDay` 케이스가 0건이다 (계획 4항의 "스냅샷도 붙어 있다"는 사실과 달라 2026-09-08 개정 `da68b475` 로 정정했다).
- 그 파일은 **카탈로그 스위트**다. `catalogSnapshotDirectory()` 로 gitignored 인 `snapshot-catalog/` 에만 기록하고 `record: .all` 이라 항상 pass 한다 (`SnapshotCapture.swift:72`). git 이 비교기가 되려면 `snapshotDirectory` 를 안 넘기는 **검증 스위트**를 따로 만들어야 한다 (snapshot-check §5).
- 확장 스냅샷 타겟 `TodoCalendarAppWidgetSnapshots` 는 확장 소스를 다시 컴파일하고 `.target(name: "TodoCalendarApp")` 을 문다 (`Project+Templates.swift:402`). 그래서 확장 소스가 `import WidgetScenes` 하려면 **앱 타겟 의존에 `WidgetScenes` 가 있어야** 한다 — 지금 `import CalendarScenes` 가 되는 것도 같은 경로다 (`TodoCalendarApp/Project.swift:19`).
- 확장 의존은 Extensions·Common3rdParty·Domain·Repository·CommonPresentation·CalendarScenes 6개다 (`TodoCalendarApp/Project.swift:113~137`). `CalendarScenes` 제거는 DP-2.3 이라 이번엔 `WidgetScenes` 를 **추가만** 한다.
- `"...".localized()` 는 `Extensions` 의 `Bundle.module` 을 본다 (`String+Extensions.swift:19`). 모듈이 바뀌어도 키 해석은 안 깨진다.
- 스킴 하드코딩은 5곳이다 — `pr_test.yml:36·37`(+detect-changes 매핑 `:135` 꼴, +Test step `:337` 꼴), `run-all-tests.sh:21`, `impact-check.sh:12·13`(+매핑 `:101`), `impact-check.test.sh:23·54`, `run-tests/SKILL.md:34·41`.

### 나. 장애·마찰

- **유력한 양상** — 이관 자체는 파일 가르기라 단순한데, 배선(Workspace·앱/확장 의존·스킴 5곳·`tuist generate`)이 길어 하나 빠뜨린다. 특히 `impact-check.test.sh` 의 기대값 배열이 손대는 걸 잊기 쉽다.
- **가장 위험한 양상** — `AccessoryWidgetBackground()` 처럼 순수 뷰인 줄 알았던 자리에 WidgetKit 타입이 숨어 있어, 그걸 피하려다 잠금화면 뷰의 렌더가 달라진다. 이관 무손실(A1)이 여기서 깨지면 계약 C1 의 "분리선이 이미 그어져 있다"는 전제 자체가 흔들린다.

### 다. 상위 인용

- **최종상태 관점 (계획 3항)** — 검증: "순수 뷰를 옮기기 전후 스냅샷이 같다". 구조: "`WidgetScenes` 가 WidgetKit 을 안 문다".
- **LOE-1 중간 목표** — 앱과 확장이 같은 뷰 코드를 그린다. 그 첫 증명이 이 DP다.
- **1단계 종료 조건 (계획 5항)** — `WidgetScenes` 에 D-day 순수 뷰가 있고 WidgetKit import 가 0건이며, 확장이 그걸 물어 그리고 스냅샷이 이관 전과 같다.
- **인터페이스 계약 C1** — `WidgetScenes` 로 가는 것: 패밀리별 순수 뷰, 그 ViewModel 과 `.sample`, 배경·스타일 해석. 확장에 남는 것: `ResultTimelineEntry`, 엔트리 뷰, `TimelineProvider`, ViewModelProvider, `Widget` 선언, `AppIntentConfiguration`. 쪼개는 자리 둘 — 뷰 파일은 순수 뷰 / 엔트리 뷰·`Widget` 선언, Provider 파일은 ViewModel·`.sample` / Provider.
- **인터페이스 계약 C2 (2026-09-08 확정)** — 배경 **해석**을 `WidgetScenes` 로 내려 확장과 갤러리가 같은 코드를 부른다. **적용**은 각자 — 확장은 `.containerBackground(for: .widget)`, 갤러리는 미리보기 프레임. 순수 뷰 안에서 배경을 그리지 않는다.
- **인접 DP** — DP-2.1 이 이 계약을 표시 모델 이관에 그대로 쓰고, DP-2.2·2.3 이 위젯군마다 반복한다. 전부 이 DP 머지가 선행이다.

### 라. 가정

| ID | 가정 | 출처 | 깨지면 |
|---|---|---|---|
| A-1 | 순수 뷰 5개를 옮겨도 확장 렌더가 안 바뀐다 | 계획 A1 상속 | T-5 스냅샷 PNG 가 달라진다 → 즉시보고, 달라진 자리를 찾아 원형 복원. 복원이 안 되면 계획 A1 붕괴로 상향 |
| A-2 | `"...".localized()` 가 모듈을 옮겨도 같은 문자열을 낸다 | 신규 — `String+Extensions.swift:19` 의 `Bundle.module` 이 `Extensions` 를 가리킨다 | 스냅샷에 키 원문이 찍힌다 → 옮긴 자리에서 `Extensions` import 를 확인 |
| A-3 | `AccessoryWidgetBackground()` 를 대체해도 잠금화면 원형 렌더가 유지된다 | 신규 — 미확인 | T-3 우발계획 발동 |
| A-4 | 앱 타겟에 `WidgetScenes` 를 물리면 확장 스냅샷 타겟에서도 import 가 풀린다 | 신규 — 현재 `CalendarScenes` 가 같은 경로로 풀린다 | 스냅샷 타겟 의존에 직접 추가한다 (`Project+Templates.swift` 손댐 → 사전승인) |

### 마. 인접 작업

- 다른 워크트리에서 #1054(e2e 타겟·스킴 신설)가 동시에 돈다. **소유 범위가 겹친다** — `pr_test.yml`·`run-all-tests.sh`·`impact-check.sh`+테스트·`run-tests/SKILL.md` 의 스킴 목록을 양쪽이 건드린다. 충돌은 텍스트 레벨이라 rebase 로 풀리지만, 먼저 머지된 쪽 기준으로 목록을 다시 읽고 넣는다.
- `develop` 은 이 명령 착수 시점에 `da68b475`(작전계획 개정)까지 와 있다.

## 2. 임무

이 작업은 **D-day 위젯의 이관 전후 스냅샷이 같다고 증명될 때까지**, `Presentations/WidgetScenes` 를 신설하고 D-day 순수 뷰·ViewModel·배경 해석을 그리로 옮겨, **앱과 확장이 같은 뷰 코드를 그리는 구조가 성립함을 그림으로 확인**한다.

## 3. 실시

### 가. 의도

**목적** — 위젯 18종을 마저 옮기기 전에 이관 방식이 무손실인지 확정한다. 이 DP 가 정한 답을 DP-2.x 가 그대로 반복하므로, 여기서 애매하게 넘어가면 뒤에서 18배로 되돌아온다.

**핵심과업** — 이관 전후 D-day 렌더가 같다는 것이 이미지로 남는다. (성립 조건이지 방법이 아니다 — 어떤 스위트로 어떻게 찍든 상관없다.)

**최종상태**

- 동작 — 확장이 그리는 D-day 위젯 5패밀리가 이관 전과 같다.
- 코드 — `Presentations/WidgetScenes/Sources` 에 순수 뷰 5개·`DDayWidgetViewModel`·`.sample`·`noTarget()`·날짜 포맷터·배경 해석이 있다. `DDayWidget.swift` 에는 엔트리 뷰와 `Widget` 선언만 남는다.
- 구조 — `WidgetScenes` 에 `import WidgetKit` 이 0건이고 `import CalendarScenes` 도 0건이다. 확장·앱 양쪽이 `WidgetScenes` 를 문다.
- 검증 — `DDayWidgetSnapshots` 의 PNG 10장(5패밀리 × 라이트/다크)이 커밋돼 있고, 이관 커밋 이후 재실행해도 `git status` 가 깨끗하다.
- 외부 — CI 가 `WidgetScenes` 스킴을 인식하고 실행한다.

### 나. 개념

**결정적 행동** — 이관 후 스냅샷 재실행에서 PNG 무변화를 확인하는 것. 이게 되면 계약 C1·C2 가 증명되고 DP-2.x 가 열린다.

**여건 조성** — 이관 전에 baseline PNG 를 먼저 커밋한다(T-1). 프레임워크와 배선을 먼저 세워 이관이 컴파일 가능한 상태를 만든다(T-2).

**대안 경로 + 전환 조건** — 스냅샷 PNG 가 달라졌는데 원인이 `AccessoryWidgetBackground()` 대체 하나로 좁혀지면, 잠금화면 3종(circular·rectangular·inline)은 확장에 남기고 홈 화면 2종만 옮긴다. 계약 C1 이 "패밀리별 순수 뷰 전부"라 계획 개정이 필요하므로 이 전환은 유저 결심 사안이다(D-2).

**단계**

1. baseline 이 커밋된 상태 — D-day PNG 10장이 트리에 있다.
2. 프레임워크가 선 상태 — `tuist generate` 가 통과하고 빈 `WidgetScenes` 가 빌드된다.
3. 이관된 상태 — 확장이 `WidgetScenes` 의 뷰를 그린다.
4. 증명된 상태 — 스냅샷 재실행 후 PNG 무변화.

### 다. 과업

- **T-1**: D-day 검증 스냅샷 스위트를 신설하여, 이관 전 렌더를 git 이 비교할 수 있는 자산으로 남긴다.
- **T-2**: `Presentations/WidgetScenes` 프레임워크를 세우고 앱·확장·CI 배선을 하여, 뷰가 올라갈 자리를 만든다.
- **T-3**: 순수 뷰 5개·공통 조각·ViewModel·`.sample`·날짜 포맷터를 이관하여, 앱과 확장이 같은 뷰 코드를 보게 한다.
- **T-4**: 배경 해석을 `WidgetScenes` 로 내려, 확장과 (이후) 갤러리가 같은 해석 코드를 부르게 한다.
- **T-5**: 스냅샷을 재실행해 PNG 무변화를 확인하고 영향 스킴 테스트를 돌려, 이관이 무손실임을 증명한다.

### 라. 협조지시

**개시 조건** — 작전계획 재가됨(2026-09-08). 선행 DP 없음. 소유 범위는 아래 파일 목록 + 스킴 하드코딩 5곳.

**인터페이스 계약** — 계약 C1·C2 상속(1-다). 추가: 이번 DP 는 순수 뷰 생성자를 `init(model:)` 로 둔다. `style` 파라미터는 DP-5.1 이 `WidgetStyle` 과 함께 붙인다.

**제한**

- `WidgetScenes` 는 `Scenes` 를 안 문다 — 갤러리 Scene 프로토콜이 오는 DP-4.1 에서 추가한다. 지금 물리면 확장 링크 표면에 `UIApplication.shared`(`Scenes/BaseComponents.swift:125`)가 다시 들어와 DP-2.3 의 의존 정리 효과가 반감된다.
- **옮기는 코드는 원형을 유지한다.** 이름·구조·주석을 바꾸지 않는다. `DDayTargetDateFormatter` 의 `static func` 도 그대로 옮긴다 — CLAUDE.md §1 의 `static func` 금지는 신규 작성에 걸리는 규칙이고, 여기서 리팩터하면 스냅샷 무변화 판정에 다른 변수가 섞인다.
- `CalendarScenes` 의존은 확장에서 **제거하지 않는다** (DP-2.3 소관).
- 표시 모델(`EventCellViewModel` 등)은 건드리지 않는다 (DP-2.1 소관).

**위임 범위** — `docs/operations/templates/delegation.md` 상속. 좁히는 것: 없음. 다만 이 명령은 사전승인 등급 사안 셋을 **미리 승인한 상태**다 — 프레임워크 신설(신규 타입·모듈), 의존성·스킴·CI 변경, 소유 범위 밖 파일 수정(`DDayTargetSelectIntent.swift`·`ResultTimelineEntry.swift`·`TodoCalendarApp/Project.swift`·`Workspace.swift`). 이 셋을 넘는 신설·수정은 중단하고 묻는다.

**수용 위험** — `WidgetScenes` 테스트 타겟이 지금은 얇다(ViewModel 문자열 조합 2건). DP-5.1 이 채운다.

**즉시보고 조건**

- PIR-1 — #1054 가 먼저 머지돼 스킴 목록 텍스트가 바뀐다 → D-1
- FFIR-1 — 이관 후 스냅샷 PNG 가 달라진다 → D-2
- FFIR-2 — `AccessoryWidgetBackground()` 말고 다른 WidgetKit 타입이 순수 뷰에서 더 나온다 → D-2
- FFIR-3 — `tuist generate` 나 확장 스냅샷 타겟 컴파일이 의존 경로 문제로 깨진다 → D-3

**결정지점**

| ID | 결정 | 판단 정보 | 시한(조건) | 미결 시 기본 행동 |
|---|---|---|---|---|
| D-1 | 스킴 목록을 어느 기준으로 넣나 | #1054 머지 여부 | T-2 착수 시 | `origin/develop` 을 다시 읽고 그 위에 넣는다 |
| D-2 | 잠금화면 3종을 옮길지 확장에 남길지 | 달라진 PNG 와 원인 | T-5 판정 시 | 중단하고 유저에게 이미지와 함께 보고 (계약 C1 변경이라 자율 아님) |
| D-3 | 확장 스냅샷 타겟 의존을 직접 손댈지 | 컴파일 에러 메시지 | T-2 검증 시 | 앱 타겟 의존 추가만으로 재시도 후, 그래도 안 풀리면 보고 |

**우발계획**

| 조건 | 행동 | 결심자 | 상향 |
|---|---|---|---|
| `AccessoryWidgetBackground()` 때문에 `WidgetScenes` 가 WidgetKit 을 물게 된다 | 순수 뷰에서 그 호출을 빼고, 잠금화면 배경은 엔트리 뷰가 감싸 넣는다 (배경은 뷰 바깥이라는 C2 와 같은 방향) | 실행자 | 렌더가 달라지면 D-2 |
| 스킴 목록 편집이 #1054 와 충돌한다 | rebase 후 목록을 다시 읽고 양쪽 스킴이 다 있는지 확인 | 실행자 | 없음 (사후보고) |
| `impact-check.test.sh` 기대값이 대량으로 어긋난다 | 기대 배열에 `WidgetScenes` 를 넣어 갱신. `Scenes → 전 Presentation` 블록이 `WidgetScenes` 를 포함하는 과대 매핑은 받아들인다 (CI 시간만 는다) | 실행자 | 없음 (사후보고) |

## 4. 검증·자원

- **테스트 스킴** — `bash .claude/skills/implement/scripts/impact-check.sh` 결과를 따른다. 예상은 `WidgetScenes`·`TodoCalendarApp`·`TodoCalendarAppWidget`.
- **검증 사다리** — ① `mise exec -- tuist generate --no-open` ② `impact-check.sh` 로 매핑 확인 ③ 영향 스킴 테스트 ④ 스냅샷 재실행 후 `git status --short -- '*__Snapshots__*'` 무변화.
- **스냅샷** — `TodoCalendarAppWidgetSnapshots` 스킴, iPhone 17 - snapshot_ref / iOS 26.2 / `-testLanguage en -testRegion en_US` (snapshot-check §3). 로컬 전용이라 CI 등재 금지.
- **실기** — 없음. 확장 실물 확인은 DP-6.1 노출 때.
- **모델 티어·슬롯** — 부록 C. 워크트리는 현재 `southpaw` 유지.
- **외부 자원** — 없음.

## 5. 보고

- **즉시** — 3-라 의 PIR/FFIR 발생 시. 스냅샷이 달라지면 이미지를 첨부한다.
- **정기** — 태스크 완료마다 진행 파일 갱신. 4단계(증명) 도달 시 요약 보고.
- **유저 부재 시** — 의도 안이면 기본 행동(결정지점 표)으로 계속한다. **D-2 가 걸리면 중단한다** — 계약 C1 변경이라 자율 밖이다.
- **종결 조건** — 최종상태 5항이 다 성립하고 PR 이 올라간 시점. 종결보고에 C2 적용 방식이 실제로 통했는지, 잠금화면 처리가 어떻게 됐는지를 싣는다 (DP-2.x 가 그대로 따른다).

---

## 부록 A. 태스크 상세

### Task 1: D-day 검증 스냅샷 baseline

**Files**
- Create: `TodoCalendarApp/AppExtensions/Widget/Snapshots/DDayWidgetSnapshots.swift`
- Create(생성물): `TodoCalendarApp/AppExtensions/Widget/Snapshots/__Snapshots__/DDayWidgetSnapshots/*.png` (10장)

**Interfaces**
- Consumes: `DDaySmallWidgetView`·`DDayMediumWidgetView`·`DDayCircularWidgetView`·`DDayRectangularWidgetView`·`DDayInlineWidgetView`(현재 internal, `@testable import TodoCalendarAppWidget` 로 본다), `DDayWidgetViewModel.sample`
- Produces: PNG 10장 — T-5 의 비교 대상

**참고 동형 구현** — `WidgetCatalogSnapshots.swift:44` 의 `capture(_:family:canvas:makeView:)` 와 `:132` 의 `captureLockScreen`. 캔버스 규격도 그 파일의 `WidgetCanvas`·`LockScreenCanvas` 를 그대로 쓴다.

**핵심 차이 — 카탈로그가 아니라 검증 스위트다.** `catalogSnapshotDirectory()` 를 **넘기지 않는다**. 넘기면 gitignored 인 `snapshot-catalog/` 로 빠져 git 비교가 성립하지 않는다 (snapshot-check §5).

- [ ] Step 1 — `DDayWidgetSnapshots: XCTestCase` 를 만들고 `WidgetCatalogSnapshots` 의 캔버스 규격·`capture` 헬퍼를 `snapshotDirectory` 인자 없이 옮겨 심는다
- [ ] Step 2 — 테스트 5개 작성: `test_ddaySmall`·`test_ddayMedium`·`test_ddayCircular`·`test_ddayRectangular`·`test_ddayInline`. 모델은 전부 `DDayWidgetViewModel.sample`, 홈 화면 2종은 `capture`, 잠금화면 3종은 `captureLockScreen` 계열 경로
- [ ] Step 3 — 스냅샷 스킴 실행(§4 규격)해 PNG 10장 생성. 이미지를 직접 열어 D-day 텍스트·날짜·레이아웃이 정상인지 확인한다 (깨진 baseline 을 기준 삼으면 T-5 판정이 무의미해진다)
- [ ] Step 4 — 커밋 (부록 B 커밋 1)

### Task 2: WidgetScenes 프레임워크 신설과 배선

**Files**
- Create: `Presentations/WidgetScenes/Project.swift`, `Presentations/WidgetScenes/WidgetScenes.h`, `Presentations/WidgetScenes/Sources/.gitkeep`(T-3 에서 대체), `Presentations/WidgetScenes/Tests/`
- Modify: `Workspace.swift`, `TodoCalendarApp/Project.swift`(앱 의존 + 확장 의존), `.github/workflows/pr_test.yml`, `scripts/run-all-tests.sh`, `.claude/skills/implement/scripts/impact-check.sh`, `.claude/skills/implement/scripts/impact-check.test.sh`, `.claude/skills/run-tests/SKILL.md`

**Interfaces**
- Produces: `WidgetScenes` 모듈 — T-3·T-4 가 파일을 넣을 자리

**참고 동형 구현** — `Presentations/AIAgentScene/Project.swift` 전체. 다만 **`Scenes` 의존은 뺀다**(3-라 제한).

```swift
Project.frameworkWithTest(name: "WidgetScenes",
                          destinations: [.iPhone],
                          iOSTargetVersion: "17.0",
                          dependencies: [Common3rdParty, CommonPresentation, Domain, Extensions])
```

- [ ] Step 1 — `Project.swift`·`WidgetScenes.h`·`Sources/`·`Tests/` 생성. 경로는 전부 `.relativeToRoot(...)` (add-framework §1, #794)
- [ ] Step 2 — `Workspace.swift` 의 `projects` 에 `"Presentations/WidgetScenes"` 추가
- [ ] Step 3 — `TodoCalendarApp/Project.swift` 앱 타겟 의존(`:18` 인접)과 위젯 확장 의존(`:134` 인접) 양쪽에 `WidgetScenes` 추가. 앱 쪽이 있어야 확장 스냅샷 타겟에서 import 가 풀린다(1-가)
- [ ] Step 4 — 스킴 하드코딩 5곳에 `WidgetScenes` 추가. `pr_test.yml` 은 `ALL_SCHEMES`·`ALL_PRESENTATION`·detect-changes 매핑(`Presentations/WidgetScenes/` → `WidgetScenes`)·`Test WidgetScenes` step 까지 4자리다. `impact-check.sh` 는 상수 2줄 + 매핑 블록, `impact-check.test.sh` 는 `ALL`·`ALL_WITH_EXTENSIONS` 배열과 영향 assertion, `run-tests/SKILL.md` 는 목록과 "14개" 문구
- [ ] Step 5 — `mise exec -- tuist generate --no-open` 통과 확인, `bash .claude/skills/implement/scripts/impact-check.test.sh` 통과 확인
- [ ] Step 6 — 커밋 (부록 B 커밋 2)

**테스트 케이스** — `impact-check.test.sh` 에 `assert_eq "WidgetScenes → 단독+App+Widget" ...` 한 줄 추가.

### Task 3: D-day 순수 뷰·ViewModel 이관

**Files**
- Create: `Presentations/WidgetScenes/Sources/DDay/DDayWidgetViews.swift`, `Presentations/WidgetScenes/Sources/DDay/DDayWidgetViewModel.swift`, `Presentations/WidgetScenes/Tests/DDay/DDayWidgetViewModelTests.swift`
- Modify: `TodoCalendarApp/AppExtensions/Widget/Sources/Widgets/DDayWidget/DDayWidget.swift`, `.../DDayWidgetViewModelProvider.swift`, `TodoCalendarApp/AppExtensions/Widget/Sources/Intents/DDayTargetSelectIntent.swift`, `TodoCalendarApp/AppExtensions/Widget/Snapshots/DDayWidgetSnapshots.swift`

**Interfaces**
- Produces: `public struct DDayWidgetViewModel`(+ `public static var sample`·`public static func noTarget()`), `public struct DDaySmallWidgetView`(외 4개, 전부 `public init(model:)`), `public enum DDayTargetDateFormatter`
- Consumes: `WidgetAppearanceSettings`(Domain), `DDayText`·`joinedNonEmpty`·`localized()`(Extensions), `EventTime`(Domain)

**가르는 자리**

| 원 파일 | `WidgetScenes` 로 | 확장에 남음 |
|---|---|---|
| `DDayWidget.swift` | `DDayTitleView`(private 유지), `compactDetailText`/`detailText` 확장, 순수 뷰 5개 | `DDayWidgetEntryView`, `DDayWidget: Widget`, `DDayWidgetView_Provider` |
| `DDayWidgetViewModelProvider.swift` | `DDayWidgetViewModel` 전체(+`sample`·`noTarget`) | `DDayWidgetViewModelProvider` 와 그 private 헬퍼 |
| `DDayTargetSelectIntent.swift` | `DDayTargetDateFormatter` | `DDayTargetEventEntity`·`DDayTargetEventQuery` 등 나머지 전부 |

**엣지 케이스**

- `DDayCircularWidgetView` 의 `AccessoryWidgetBackground()` 는 WidgetKit 타입이다. 순수 뷰에서 빼고 엔트리 뷰가 감싸도록 옮긴다 — 그래야 `WidgetScenes` 의 WidgetKit import 0건이 성립한다. 렌더가 달라지면 D-2.
- 옮긴 타입에 `public init` 을 열어야 한다. 현재 뷰들은 `init(model:)` 이 internal 이다.
- `DDayWidgetViewModel.widgetSetting` 은 확장의 Provider 가 쓴다 — `public var` 로 열어 둔다.
- 확장 쪽 파일에 `import WidgetScenes` 를 넣는다. `DDayWidgetTimeLineProvider.swift` 도 `.sample` 을 쓰므로(`:28`) 같이 본다.

**테스트 케이스** (`DDayWidgetViewModelTests`)
- `lockScreenInlineText_joinsDDayAndTitle`
- `lockScreenInlineText_whenTitleIsEmpty_returnsDDayOnly`
- `isRepeating_whenRepeatTextIsEmpty_returnsFalse`

- [ ] Step 1 — `DDayWidgetViewModel.swift` 를 `WidgetScenes` 에 만들고 ViewModel·`sample`·`noTarget`·`DDayTargetDateFormatter` 를 원형 그대로 옮긴다. `public` 을 연다
- [ ] Step 2 — `DDayWidgetViews.swift` 에 `DDayTitleView`·detail 확장·순수 뷰 5개를 옮긴다. `AccessoryWidgetBackground()` 는 빼고 엔트리 뷰로 넘긴다
- [ ] Step 3 — 확장의 세 파일에서 옮긴 코드를 지우고 `import WidgetScenes` 를 넣는다. `DDayWidgetEntryView` 의 circular 분기에서 `AccessoryWidgetBackground()` 를 감싸 준다
- [ ] Step 4 — `DDayWidgetSnapshots.swift` 를 `import WidgetScenes` 로 바꾼다 (`@testable import TodoCalendarAppWidget` 는 엔트리 뷰용으로 유지)
- [ ] Step 5 — `DDayWidgetViewModelTests` 작성
- [ ] Step 6 — `mise exec -- tuist generate --no-open` 후 빌드 통과 확인

### Task 4: 배경 해석 하향

**Files**
- Create: `Presentations/WidgetScenes/Sources/Style/WidgetBackgroundStyle.swift`
- Modify: `TodoCalendarApp/AppExtensions/Widget/Sources/Widgets/ResultTimelineEntry.swift`

**Interfaces**
- Produces: `public struct WidgetBackgroundStyle { public init(_ background: WidgetAppearanceSettings.Background); public var shape: AnyShapeStyle }`
- Consumes: `ColorSet`·`DefaultLightColorSet`·`DefaultDarkColorSet`·`UIColor.from(hex:)`·`isLight`·`asColor` (CommonPresentation)

**참고 동형 구현** — 현재 해석 로직 `ResultTimelineEntry.swift:50~71` 을 그대로 옮긴다. `backgroundShape` 는 `WidgetBackgroundStyle(self.background).shape` 한 줄로 남긴다 — 호출처 18곳(`.containerBackground(entry.backgroundShape, for: .widget)`)이 안 바뀐다.

**엣지 케이스** — `WidgetAppearanceSettings.Background.colorSet(_:)` 확장(`ResultTimelineEntry.swift:92`)은 이번에 안 옮긴다. 다른 위젯 뷰들이 쓰고 있어 DP-2.x 소관이다.

- [ ] Step 1 — `WidgetBackgroundStyle` 을 만들고 해석 로직을 옮긴다. 반환은 `AnyShapeStyle` 로 고정한다 (기존 `some ShapeStyle` 이 내부에서 `AnyShapeStyle` 을 돌려주고 있었다)
- [ ] Step 2 — `ResultTimelineEntry.backgroundShape` 를 위임 한 줄로 교체
- [ ] Step 3 — 커밋 (부록 B 커밋 3 = Task 3 + Task 4)

### Task 5: 무손실 증명

**Files**
- Modify(생성물): `TodoCalendarApp/AppExtensions/Widget/Snapshots/__Snapshots__/DDayWidgetSnapshots/*.png` — **변하면 안 된다**

- [ ] Step 1 — 스냅샷 스킴 재실행 (§4 규격, T-1 과 같은 기기·언어)
- [ ] Step 2 — `git status --short -- '*__Snapshots__*'` 확인. 변화 0 이면 A-1 성립
- [ ] Step 3 — 변화가 있으면 `git show HEAD:<png> > <스크래치패드>/old.png` 로 전후를 열어 비교하고 즉시보고 (FFIR-1 → D-2). PNG 는 커밋하지 않는다
- [ ] Step 4 — `impact-check.sh` 가 내놓은 스킴 전체 테스트 실행
- [ ] Step 5 — `grep -rn "import WidgetKit\|import CalendarScenes" Presentations/WidgetScenes/` 가 0건인지 확인 (최종상태 구조 항목)

## 부록 B. 커밋 시퀀스

| # | 태스크 | 메시지 |
|---|---|---|
| 1 | T-1 | `[#1055] D-day 위젯 스냅샷 baseline 5패밀리 추가 — 이관 전후 대조 기준선` |
| 2 | T-2 | `[#1055] WidgetScenes 프레임워크 신설 — 앱·확장 의존과 CI 스킴 배선` |
| 3 | T-3 + T-4 | `[#1055] D-day 순수 뷰·ViewModel·배경 해석을 WidgetScenes 로 이관` |

T-5 는 커밋을 만들지 않는다 — PNG 무변화가 성공 조건이라 변경이 없어야 정상이다.

## 부록 C. 모델 티어

| 태스크 | 티어 | 근거 |
|---|---|---|
| T-1 | 표준 (sonnet급) | 기존 스위트 패턴을 새 스위트로 옮기는 통합 작업 |
| T-2 | 표준 (sonnet급) | 배선 지점이 9곳이고 짝 규칙 누락이 조용히 지나간다 |
| T-3 | 표준 (sonnet급) | 파일 가르기 + 접근제어 조정 + WidgetKit 타입 회피 판단 |
| T-4 | 기계적 (haiku급) | 로직 이동 + 위임 한 줄. 결정이 다 박혀 있다 |
| T-5 | 표준 (sonnet급) | 이미지 판정과 실패 시 원인 추론 |

## 부록 D. 단편명령

없음.
