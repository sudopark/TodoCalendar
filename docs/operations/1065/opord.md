# 작업 지침 (Operation Order) — DP-2.2

> 용어 — DP: 결정적 지점(작업 지침 하나 = PR 하나) · LOE: 노력선(최종상태 한 관점을 담당하는 줄기) · FRAGO: 단편명령 · MOP / MOE: 과업 수행 여부 / 효과 발생 여부 · PIR / FFIR: 즉시보고 조건 중 환경·외부 정보 / 아군·내부 정보

```
작업 지침 — #1065 전 위젯군 순수 뷰 WidgetScenes 이관       초안: 에이전트   재가: 유저   일자: 2026-09-09
상위: campaign.md #721 / LOE-1 / 2단계 매듭 풀기 / DP-2.2 / 선행 DP-2.1 (#1060, PR #1062 머지 `e895d668`)
```

## 1. 상황

### 가. 정찰 결과

**분할선이 파라미터 형태로 이미 드러나 있다.** 뷰가 `model:` 을 받으면 순수 뷰고, `entry: ResultTimelineEntry<…>` 를 받으면 엔트리 뷰다. DP-1.1 이 D-day 에서 그은 선과 같다.

| 위젯군 | 이동할 순수 뷰 (현재 위치) | 이동할 ViewModel (현재 위치) | 확장에 남는 것 |
|---|---|---|---|
| Today | `TodaySummaryView` (`TodayWidget/TodayWidget.swift:21`) | `TodayWidgetViewModel` + `sample()` (`TodayWidgetViewModelProvider.swift:19`) | `TodayWidgetView:116`, `TodayWidget:136`, PreviewProvider, TimelineProvider, `TodayWidgetViewModelProvider:83` |
| Month | `SingleMonthView` (`MonthWidget/MonthWidget.swift:19`) | `MonthWidgetViewModel` (`MonthWidgetViewModelProvider.swift:19`) | `MonthWidgetView:114`, `MonthWidget:136`, PreviewProvider, TimelineProvider, `MonthWidgetViewModelProvider:118` |
| Foremost | `InlineSizeForemostEventView:22`, `SystemSizeForemostEventView:41` (내부 `ForemostTodoToggleButton:203` 포함, `ForemostWidget/ForemostEventWidget.swift`) | `ForemostEventWidgetViewModel` + `sample()` (`ForemostEventWidgetViewModel+Provider.swift:19`) | `ForemostEventWidgetView:239`, `ForemostEventWidget:268`, PreviewProvider, TimelineProvider, Provider:42 |
| EventList | `EventListView:21`, `TodoToggleButton:182`, `extension ViewAppearance:253` (`EventListWidget/EventListWidget.swift`) | `EventListWidgetViewModel` + `sample(size:)`, `EventListWidgetSize:20` (`EventListWidgetViewModelProvider.swift:35`) | `EventListWidgetView:212`, `EventListWidget:234`, PreviewProvider, TimeLineProvider, Provider:294, private extension 3개(:385·:389·:488) |
| WeekEvents | `WeekEventsView:18`, `extension ColorSet:224`, `private extension WeekEventsViewModel:235`, `private extension WeekEventsRange:268` (`WeekEventsWidget/WeekEventsView.swift`) | `WeekEventsRange:19`, `private struct WeeksWithRange:31`, `WeekEventsViewModel` + `sample(_:)` (`WeekEventsWidgetViewModelProvider.swift:44`) | `WeekEventsWidgetView:18`, `Widget` 선언 7종, PreviewProvider, TimelineProvider, Provider:196, `private extension Calendar:328`·`EventOnWeek:340`, `DummyCalendarEvent:351` |
| NextEvent | `NextEventWidgetInlineView:21`, `NextEventRectangleWidgetView:37` (`NextEventWidget/Next/NextEventWidget.swift`) | `NextEventWidgetViewModel` + `sample:19` (`NextEventWidgetViewModelProvider.swift`) | `NextEventWidgetEntryView:83`, `NextEventWidget:112`, PreviewProvider, TimeLineProvider, `NextEventWidgetViewModelBuilder:71`, Provider:155, `private extension EventTimeText:209` |
| NextRemain | `NextRemainEventVListiew:19` (`NextEventWidget/NextRemain/NextRemainEventWidget.swift`) | `NextEventListWidgetViewModel` + `sample:51` (`NextEventWidgetViewModelProvider.swift`) | `NextRemainEventWidgetView:57`, `NextRemainEventWidget:77`, PreviewProvider, TimeLineProvider |
| TodayAndNext | `TodayAndNextWidgetView:21`, `private extension EventPeriodText:461` (`TodayAndNext/TodayAndNextWidget.swift`) | `TodayAndNextWidgetViewModel` + extension 2개(:96·:168) + `sample()` (`TodayAndNextWidgetViewModel+Provider.swift:19`) | `TodayAndNextWidgetEntryView:420`, `TodayAndNextWidget:441`, PreviewProvider, TimeLineProvider, `Builder:194`(+:355·:431), `Provider:482`, `private extension Array<EventModel>:563` |
| AICommand | `AICommandShortcutWidgetView:45` (`AICommandWidget/AICommandShortcutWidget.swift`) | 없음 | `AICommandShortcutWidgetEntry:17`, TimeLineProvider:21, `AICommandShortcutWidget:91`, PreviewProvider, `AICommandControlWidget` |
| Composed 4종 | 없음 — 네 뷰(`DoubleMonthWidgetView`·`EventAndForemostWidgetView`·`EventAndMonthWidgetView`·`TodayAndMonthWidgetView`)는 전부 `entry:` 를 받는 엔트리 뷰다 | `DoubleMonthWidgetViewModel`(`DoubleMonthWidgetTimlineProvider.swift:20`)·`EventAndForemostWidgetViewModel`(`…TimelineProvider.swift:18`)·`EventAndMonthWidgetViewModel`(`…TimelineProvider.swift:18`)·`TodayAndMonthWidgetViewModel`(`…TimelineProvider.swift:18`) | 뷰 4개, `Widget` 선언 4개, PreviewProvider 4개, ViewModelProvider 4개, TimelineProvider 4개 |

**순수 뷰 안에 WidgetKit API 가 남은 자리가 셋이다.** `ForemostEventWidget.swift:33,36` 의 `.widgetAccentable()` 은 `InlineSizeForemostEventView` 안에 있고, `AICommandShortcutWidget.swift:47,64,68` 은 `@Environment(\.widgetFamily)`·`AccessoryWidgetBackground()`·`.widgetAccentable()` 를 셋 다 쓰며, `NextEventWidget.swift:87` 의 `widgetFamily` 는 엔트리 뷰(`NextEventWidgetEntryView`) 안이라 그대로 남는다. DP-1.1 이 `DDayWidget.swift:24,35` 에서 이 셋을 엔트리 뷰로 올려 처리한 선례가 있다 — `AccessoryWidgetBackground` 는 확장의 엔트리 뷰가 씌우고, 순수 뷰는 콘텐츠만 그린다.

**`WidgetLink+Extensions.swift:78` 의 `extension EventCellViewModel { var widgetURL: URL? }` 를 순수 뷰가 쓴다.** `ForemostEventWidget.swift:143` 의 `SystemSizeForemostEventView` 가 `event.widgetURL` 로 링크를 만든다. `.widgetURL(...)` modifier 자체는 WidgetKit 이라 엔트리 뷰에 남지만, URL 계산은 순수 뷰가 필요로 한다.

**스냅샷은 호출부를 안 바꿔도 된다.** `WidgetCatalogSnapshots.swift:17` 이 `@testable import TodoCalendarAppWidget` 으로 10 케이스를 찍는데, 그중 넷은 엔트리 뷰를(`TodayWidgetView`·`ForemostEventWidgetView`·`EventListWidgetView`·`WeekEventsWidgetView`) 부르고 셋은 순수 뷰를(`TodayAndNextWidgetView`·`InlineSizeForemostEventView`·`NextEventRectangleWidgetView`·`AICommandShortcutWidgetView`) 부른다. `@testable import` 를 유지한 채 `import WidgetScenes` 만 더하면 호출 코드는 그대로 컴파일된다. 이관 전후 이미지가 같아야 한다는 판정이 이 방식에서 가장 깨끗하다.

**스냅샷 png 는 `snapshot-catalog/Widget/WidgetCatalogSnapshots/` 에 떨어진다** (`SnapshotCapture.swift:99` 의 `catalogSnapshotDirectory`, gitignore 대상). 스위트는 `withSnapshotTesting(record: .all)` 로 도는 기록 전용이라 통과가 동일의 증거가 아니다.

**`WidgetScenes` 는 아직 `CalendarPresentation` 을 안 문다.** 현재 의존은 `Common3rdParty`·`CommonPresentation`·`Domain`·`Extensions` 넷이다 (`Presentations/WidgetScenes/Project.swift`). 이번에 옮기는 ViewModel 이 `EventCellViewModel`·`CalendarEvent`·`EventOnWeek`·`WeekRowModel` 계열을 쓰므로 의존을 더해야 한다.

**스킴 하드코딩 짝은 이번에 손댈 게 없다.** `WidgetScenes` 스킴은 DP-1.1 이 `pr_test.yml`·`run-all-tests.sh`·`impact-check.sh`+테스트·run-tests 스킬 다섯 자리에 이미 등록했다.

### 나. 장애·마찰

**유력한 양상** — 순수 뷰가 같은 파일 안에서만 보이던 `private` 조각(`ForemostTodoToggleButton`·`WeekEventsView` 의 `private extension` 셋·`TodayAndNextWidget.swift:461` 의 `private extension EventPeriodText`)에 기대고 있어서, 파일을 가르는 순간 접근 제어가 어긋난다. DP-2.1 이 같은 함정에서 예상 4건 대신 8건을 열었다.

**가장 위험한 양상** — `.widgetAccentable()` 을 순수 뷰에서 걷어내 엔트리 뷰로 올리는 과정에서 잠금화면 렌더가 달라지는 것이다. `InlineSizeForemostEventView` 는 accessoryInline 패밀리에서만 쓰이고 스냅샷 케이스(`test_widgetLockScreenForemost`)가 그걸 찍는데, 그 스냅샷은 `.previewContext` 로만 그려서 시스템 vibrancy 를 재현하지 못한다. 이미지가 같아도 실물이 같다는 증거는 아니다.

### 다. 상위 인용

- **최종상태 관련 관점** — campaign.md 2항: "전 위젯 순수 뷰와 ViewModel 이 `WidgetScenes` 에 있고, 그 모듈은 WidgetKit 을 안 쓴다" (판정: `grep -rn "import WidgetKit" Presentations/WidgetScenes/` 가 0건). 같은 항의 "기존 위젯의 모양과 동작이 안 바뀐다" 도 이 DP 가 받는다.
- **노력선 중간 목표** — LOE-1 ③ "전 위젯 순수 뷰가 `WidgetScenes` 에 있고 확장은 `WidgetScenes` 만 문다". 확장의 `CalendarScenes` 의존 제거는 DP-2.1 이 이미 끝냈으므로 이 DP 는 앞 절반을 채운다.
- **인접 DP 관계·인터페이스 계약** — C1 이 "패밀리별 순수 뷰, 그게 받는 ViewModel 과 `.sample`" 을 `WidgetScenes` 로, "`ResultTimelineEntry`·엔트리 뷰·`TimelineProvider`·ViewModelProvider·`Widget` 선언·`AppIntentConfiguration`" 을 확장에 두라고 못박았다. 같은 항이 "`WidgetScenes` 는 `CalendarScenes` 도 WidgetKit 도 `Scenes` 도 안 문다" 와 "순수 뷰 생성자는 DP-5.1 전까지 `init(model:)` 이다" 를 규정한다. C2 는 배경을 순수 뷰 바깥에서 그리는 현 구조를 유지하라고 한다. 다음 DP 인 DP-3.1 은 타임라인 위젯 순수 뷰를 처음부터 `WidgetScenes` 에 만들고, DP-4.1 이 여기 쌓인 `.sample` 로 갤러리 미리보기를 그린다.

### 라. 가정

| ID | 가정 | 출처 | 깨지면 |
|---|---|---|---|
| A-1 | 순수 뷰를 옮겨도 확장이 그리는 모양이 안 바뀐다 | 상속 — campaign 8항 A1 (DP-1.1·DP-2.1 에서 확인됨) | FFIR-1 로 즉시보고하고 D-1 로 간다 |
| A-2 | `model:` 을 받는 뷰는 전부 WidgetKit 없이 그려진다 | 상속 — campaign C1 | FFIR-2 로 즉시보고한다. 그 뷰만 확장에 남기고 나머지를 옮긴다 |
| A-3 | `.widgetAccentable()` 을 엔트리 뷰로 올려도 잠금화면 렌더가 같다 | 신규 — DP-1.1 이 `AccessoryWidgetBackground` 로 같은 이동을 했고 D-day 5패밀리 png 가 무변화였다 | 순수 뷰가 그 modifier 를 받을 수 있게 `isAccented` 같은 플래그를 뚫지 않고, 해당 뷰를 확장에 남긴다 (D-2) |
| A-4 | Composed 4종은 ViewModel 만 옮기면 끝난다 | 신규 — 네 뷰가 전부 `entry:` 를 받는 엔트리 뷰임을 정찰에서 확인했다 | 엔트리 뷰 안에 순수 조각이 섞여 있으면 그것도 갈라 옮긴다 |
| A-5 | 이동 대상 중 `public` 개방이 필요한 것은 컴파일러가 전부 지목한다 | 상속 — DP-2.1 에서 같은 방식으로 8건을 열었다 | 개방 범위가 계획을 넘으면 종결보고 3항에 목록으로 싣는다 |

### 마. 인접 작업

`develop` 에서 #826 DP-1.3(이슈 #1063, e2e 확장 격리)이 동시에 돈다. 그 DP 의 소유 범위는 `TodoCalendarApp/AppExtensions/Base/AppExtensionBase.swift`·`AppEnvironment.swift`·`TodoCalendarApp/E2E/**` 이고, 이 작업은 `AppExtensions/Widget/Sources/Widgets/**` 와 `Presentations/WidgetScenes/**` 라 파일이 겹치지 않는다. 다만 둘 다 `TodoCalendarApp/Project.swift` 를 건드릴 여지가 있으니 머지 순서에서 충돌이 나면 이 DP 가 rebase 한다.

## 2. 임무

이 작업은 D-day 를 뺀 위젯군 9개에 대해 순수 뷰와 그 ViewModel·`.sample` 을 `Presentations/WidgetScenes` 로 옮기고 확장에 엔트리 뷰·`Widget` 선언·Provider 만 남겨, 갤러리가 확장과 같은 뷰로 전 위젯을 그릴 수 있는 공유 뷰 층을 완성한다.

## 3. 실시

### 가. 의도

**목적** — 갤러리(DP-4.1)가 "내가 쓰는 위젯이 목록에 있다"를 만들려면 앱이 전 위젯의 뷰를 볼 수 있어야 한다. 그 뷰가 확장 타겟에 갇혀 있는 한 갤러리는 신규 몇 종밖에 못 그린다.

**핵심과업** — 위젯군 9개 각각에서 순수 뷰와 ViewModel 이 확장 타겟 밖으로 나오고, 확장이 `WidgetScenes` 의 그 타입을 그대로 부른다.

**최종상태**

- 동작 — 홈·잠금화면 위젯 21종의 모양과 동작이 이관 전과 같다.
- 코드 — `Presentations/WidgetScenes/Sources/` 아래 위젯군별 폴더에 순수 뷰와 ViewModel 이 있고, `grep -rn "import WidgetKit\|import CalendarScenes\|import Scenes" Presentations/WidgetScenes/Sources/` 가 0건이다.
- 구조 — 확장의 `Widgets/**` 에는 엔트리 뷰·`Widget` 선언·PreviewProvider·TimelineProvider·ViewModelProvider만 남는다.
- 검증 — `WidgetCatalogSnapshots` 10 케이스의 png 가 develop 기준선과 바이트 동일하고, `WidgetScenes`·`TodoCalendarAppWidget`·`TodoCalendarApp` 세 스킴이 통과한다.
- 외부 — 없음.

### 나. 개념

**결정적 행동** — 위젯군마다 뷰 파일을 순수 뷰와 엔트리 뷰로 가르고, Provider 파일을 ViewModel 과 Provider 로 가른다. 앞엣것을 `WidgetScenes` 로 옮기고 `public` 을 연다.

**여건 조성** — 옮기기 전에 `WidgetScenes` 가 `CalendarPresentation` 을 물게 하고, develop 기준 스냅샷 png 를 먼저 확보한다. 기준선이 없으면 무손실 판정 자체가 성립하지 않는다.

**대안 경로 + 전환 조건** — 특정 위젯군의 순수 뷰가 WidgetKit 없이는 안 그려지면(A-2 붕괴) 그 군만 확장에 남기고 나머지를 옮긴 뒤, 남긴 군을 종결보고 3항의 알려진 한계로 싣는다. 전환 조건은 "그 뷰에서 WidgetKit 심볼을 걷어낼 때 대체 표현이 없다" 하나다.

**단계** — ① `WidgetScenes` 가 `CalendarPresentation` 을 물고 기준 png 가 확보된 상태 → ② Composed 4종이 쓰는 기초 순수 뷰 넷(`TodaySummaryView`·`SingleMonthView`·`EventListView`·`SystemSizeForemostEventView`)이 `WidgetScenes` 에 있는 상태 → ③ 나머지 순수 뷰와 ViewModel 이 전부 옮겨진 상태 → ④ 스냅샷이 기준선과 동일함이 확인된 상태.

### 다. 과업

- **T-1**: `WidgetScenes` 에 `CalendarPresentation` 의존을 잇고 develop 기준 스냅샷 png 를 확보하여, 이관 작업의 컴파일 기반과 무손실 판정 기준선을 세운다.
- **T-2**: 앱 스킴 상수를 `Domain` 으로, 딥링크 계산식을 `CalendarPresentation` 으로 내려, 순수 뷰가 프레임워크 안에서도 링크를 그대로 계산하게 한다.
- **T-3**: Today·Month 의 순수 뷰와 ViewModel 을 옮겨, Composed 가 쓰는 기초 뷰 둘을 공유 층에 올린다.
- **T-4**: Foremost·EventList 의 순수 뷰와 ViewModel 을 옮기고 `EventCellViewModel.widgetURL` 을 함께 내려, Composed 가 쓰는 나머지 기초 뷰 둘을 공유 층에 올린다.
- **T-5**: WeekEvents 의 순수 뷰와 ViewModel·`WeekEventsRange` 를 옮겨, 주 단위 위젯 7종이 공유 뷰를 쓰게 한다.
- **T-6**: NextEvent·NextRemain·TodayAndNext 의 순수 뷰와 ViewModel 을 옮겨, 잠금화면·복합 라인업의 뷰를 공유 층에 올린다.
- **T-7**: AICommand 순수 뷰를 옮기면서 WidgetKit 심볼을 엔트리 뷰로 올려, 마지막 남은 WidgetKit 의존을 끊는다.
- **T-8**: Composed 4종의 ViewModel 을 옮겨, 갤러리가 복합 위젯 미리보기를 만들 재료를 갖게 한다.
- **T-9**: 스냅샷을 기준선과 대조하고 테스트 import 를 정리하여, 이관이 무손실임을 판정한다.

### 라. 협조지시

**개시 조건** — 작전계획 재가(`docs/operations/721/campaign.md`, develop `19e17684`)와 선행 DP-2.1 머지(`e895d668`)가 이미 섰다. 이 명령이 재가되면 `develop` 최신에서 `features/1065-widget-scenes-views` 브랜치를 딴다.

**인터페이스 계약 (상속 + 추가)**

- 상속 — campaign C1 의 배치 표와 셋 금지(`CalendarScenes`·WidgetKit·`Scenes` 를 `WidgetScenes` 가 안 문다), C2 의 "배경은 순수 뷰 바깥에서 그린다", "순수 뷰 생성자는 DP-5.1 전까지 `init(model:)` 이다".
- 추가 — 파일 배치는 `Presentations/WidgetScenes/Sources/<위젯군>/<위젯군>Views.swift` 와 `<위젯군>ViewModel.swift` 로 한다. DP-1.1 의 `Sources/DDay/DDayWidgetViews.swift`·`DDayWidgetViewModel.swift` 가 그 서식이다.
- 추가 — 옮긴 타입은 `public` 으로 열고 `public init` 을 명시한다. `public struct` 의 memberwise init 은 public 이 아니라 모듈 경계를 넘으면 안 보인다.

**제한 (이유)**

- 옮길 땐 옮기기만 한다. 뷰 본문의 레이아웃·색·폰트·분기를 고치지 않는다 — 모양이 바뀌면 A-1 판정이 성립하지 않고, campaign 13항이 "기존 유저 것을 안 빼앗는다"를 확정사항으로 박았다.
- `ResultTimelineEntry` 를 안 바꾼다. 아직 안 옮긴 경로가 그걸 쓴다 (campaign 13항).
- `FailView` 는 확장에 남긴다. 그걸 부르는 자리가 전부 엔트리 뷰의 에러 분기다.
- `WidgetScenes` 의존 목록에 `CalendarPresentation` 말고 다른 모듈을 더하지 않는다. C1 이 `CalendarScenes`·WidgetKit·`Scenes` 를 막았고, 그 밖의 추가는 사전승인 사안이다 (campaign 12항).
- `.sample` 을 새로 만들지 않는다. Composed 4종과 AICommand 의 `.sample` 신설은 DP-4.1 소관이다.
- `public` 개방은 컴파일러가 지목한 것만 한다. 미리 넓히지 않는다.

**위임 범위 (좁히는 것만)** — `delegation.md` 를 상속하고 campaign 12항을 그대로 받는다. 이 명령에서 더 좁히는 것은 없다. 파일 배치·네이밍·`public` 개방 범위·커밋 묶음은 자율이다.

**수용 위험** — 잠금화면 위젯의 vibrancy 렌더는 스냅샷으로 재현되지 않는다. `.widgetAccentable()` 이동(A-3)의 최종 확인은 실기로만 되고, 이 DP 는 그 확인을 유저에게 인계한 채 완료로 판정한다.

**버퍼** — 실행자는 위 제한 안에서 파일 배치·커밋 묶음·`public` 개방 범위를 자율로 정한다. 아래 우발계획이 그 폭의 바깥 경계다.

**즉시보고 조건**

- FFIR-1 — 이관 전후 스냅샷 png 가 달라진다 (A-1 붕괴) → D-1
- FFIR-2 — 순수 뷰가 WidgetKit 을 안 쓰고는 그려지지 않는다 (A-2·C1 붕괴) → D-2
- FFIR-3 — `WidgetScenes` 가 `CalendarScenes` 나 `Scenes` 를 물어야 한다 (C1 붕괴) → D-3
- FFIR-4 — `public` 개방이 계획 밖으로 번져 `WidgetScenes` 밖 모듈의 공개 API 를 바꿔야 한다 → D-4

**결정지점**

| ID | 결정 | 판단 정보 | 시한(조건) | 미결 시 기본 행동 |
|---|---|---|---|---|
| D-1 | 달라진 스냅샷을 회귀로 볼지 기준선 노후로 볼지 | 달라진 케이스 목록과 diff 이미지, develop 재기록 png 와의 비교 | T-9 중 차이를 발견한 즉시 | 회귀로 보고 그 위젯군 이관을 되돌린 뒤 유저에게 보고한다 |
| D-2 | WidgetKit 을 못 떼는 뷰를 확장에 남길지 계약을 고칠지 | 그 뷰가 쓰는 WidgetKit 심볼과 대체 표현 유무 | 해당 위젯군 태스크 안에서 | 그 뷰만 확장에 남기고 나머지를 옮긴다. 종결보고 3항에 싣는다 |
| D-3 | `CalendarPresentation` 에 안 내려온 타입이 발견되면 이 DP 에서 내릴지 DP-2.1 로 되돌릴지 | 그 타입의 참조처 수와 `CalendarScenes` 잔여 의존 | 발견 즉시 | 유저에게 보고하고 답을 기다린다. 임의로 모듈 경계를 옮기지 않는다 |
| D-4 | 계획 밖 `public` 개방을 수용할지 | 개방 대상 심볼과 그것을 요구하는 소비자 | 컴파일 오류가 난 시점 | `WidgetScenes` 안에서 해소되는 개방은 진행하고 종결보고 3항에 목록으로 싣는다. 다른 모듈의 공개 API 를 바꿔야 하면 멈추고 보고한다 |

**우발계획**

| 조건 | 행동 | 결심자 | 상향 |
|---|---|---|---|
| 파일을 가르자 접근 제어 오류가 예상보다 많이 난다 | 컴파일러가 지목한 것만 순차로 연다. 선제 개방은 안 한다 | 실행자 | 개방이 `WidgetScenes` 밖으로 번지면 D-4 |
| 스냅샷 스위트가 기준선 확보 단계에서 실패한다 | develop 체크아웃 상태로 재실행해 실패가 브랜치 탓인지 가른다 | 실행자 | develop 에서도 실패하면 유저에게 보고하고 대조를 생략한 채 진행 여부를 묻는다 |
| `TodoCalendarApp/Project.swift` 가 #826 DP-1.3 머지와 충돌한다 | 이 DP 가 develop 최신으로 rebase 한다 | 실행자 | 없음 |
| 특정 위젯군 태스크가 예상보다 커져 PR 이 리뷰 단위를 넘는다 | 남은 위젯군을 후속 DP 로 떼는 계획 개정을 제안한다 | 유저 | campaign 평가 모드 |

## 4. 검증·자원

**테스트 스킴·검증 사다리** — `bash .claude/skills/implement/scripts/impact-check.sh` 가 산출하는 스킴이 상한이다. 실행 범위는 최소부터 산정한다: 위젯군 이관 태스크는 빌드 통과까지, 모듈 경계가 바뀌는 T-1 과 마지막 T-9 에서 `WidgetScenes`·`TodoCalendarAppWidget`·`TodoCalendarApp` 스킴을 돌린다. TC·파일 단위는 `xcodebuild test -only-testing:<테스트타겟>/<클래스>[/<메서드>]`, 스킴 단위는 run-tests 스킬을 쓴다.

**스냅샷·실기** — `WidgetCatalogSnapshots` 은 `withSnapshotTesting(record: .all)` 로 도는 기록 전용이라 통과가 동일의 증거가 아니다. 판정은 바이트 비교로 한다. T-1 에서 develop 상태의 png 를 `snapshot-catalog/Widget/WidgetCatalogSnapshots/` 밖 임시 경로로 복사해 두고, T-9 에서 브랜치 png 와 `cmp` 로 대조한다. 잠금화면 vibrancy 는 스냅샷이 재현하지 못하므로 실기 확인을 유저에게 인계한다.

**모델 티어·병렬 슬롯·워크트리** — 부록 C 표를 따른다. 병렬 슬롯은 두지 않는다. 워크트리는 지금 쓰는 `southpaw` 하나다.

**외부 자원** — 없음.

## 5. 보고

- **즉시** — FFIR-1~4 발생 시, 우발계획의 상향 조건에 걸릴 때, 가정 A-1~A-5 중 하나가 깨질 때, rules 에 조항이 없어 판단이 막힐 때. 작전계획이 있는 런이라 `report-immediate.md` 서식으로 이슈에 봇 코멘트로도 게시한다.
- **정기** — 단계 ①~④ 전환 시점과 태스크 완료 시점에 진행 파일(`.operations/1065/progress.md`)을 갱신하고 이슈 본문 미러를 재조립한다.
- **유저 부재 시** — 의도(3-가) 안에 드는 판단은 결정지점의 기본 행동으로 계속한다. D-3 에 걸리거나 다른 모듈의 공개 API 를 바꿔야 하면 중단하고 기다린다.
- **종결 조건** — 최종상태 다섯 줄이 전부 서고 PR 이 생성되면 종결보고(`report-debrief.md`)를 낸다.

---

## 부록 A. 태스크 상세

### Task 1: WidgetScenes 의존 배선과 스냅샷 기준선 확보

**Files**
- Modify: `Presentations/WidgetScenes/Project.swift`
- Test: 없음 (기준선 확보는 기존 스위트 실행이다)

**Interfaces**
- Produces: `WidgetScenes` 타겟이 `CalendarPresentation` 을 링크하는 상태, 임시 경로의 develop 기준 png 20장(10 케이스 × light·dark)

**Steps**
- [ ] Step 1 — `Presentations/WidgetScenes/Project.swift` 의 `dependencies` 에 `.project(target: "CalendarPresentation", path: .relativeToRoot("Presentations/CalendarPresentation"))` 을 더한다. `Presentations/CalendarScenes/Project.swift:11` 이 같은 항목을 갖는 동형 예다. 배열 순서는 그 파일처럼 알파벳 순을 따른다.
- [ ] Step 2 — `mise exec -- tuist generate --no-open` 을 돌린다.
- [ ] Step 3 — 아직 뷰를 하나도 안 옮겼으므로 이 시점의 렌더 결과가 곧 develop 기준이다. `xcodebuild test -only-testing:TodoCalendarAppWidgetSnapshots/WidgetCatalogSnapshots` 로 스냅샷 스위트를 돌려 png 를 생성하고, `snapshot-catalog/Widget/WidgetCatalogSnapshots/` 전체를 스크래치패드의 `baseline/` 로 복사한다. 스킴·타겟명은 둘 다 `TodoCalendarAppWidgetSnapshots` 다 (`Project+Templates.swift:435`).
- [ ] Step 4 — 복사한 png 가 10 케이스분(잠금화면 4종 포함) 다 있는지 파일 수로 확인한다. 빠진 케이스가 있으면 그 케이스는 T-8 대조 대상에서 빠진다는 사실을 진행 파일에 적는다.
- [ ] Step 5 — 부록 B 커밋 1.

### Task 2: 앱 스킴과 딥링크 계산식 하향

**Files**
- Create: `Domain/Sources/Utils/AppDeepLink.swift`, `Presentations/CalendarPresentation/Sources/DeepLink/EventDeepLinkBuilder.swift`
- Modify: `TodoCalendarApp/Sources/AppEnvironment.swift`(`appScheme` 삭제), `TodoCalendarApp/Sources/Root/ApplicationDeepLinkHandler.swift`, `TodoCalendarApp/Sources/AppIntents/OpenAICommandInputIntent.swift`, `TodoCalendarApp/AppExtensions/Widget/Sources/Base+Factory/WidgetLink+Extensions.swift`(→ `LiveActivityLink+Extensions.swift` 로 rename, `LiveActivityEventTarget.eventDetailURL` 만 남긴다)

**Interfaces**
- Produces: `public enum AppDeepLink { public static var scheme: String }`, `public enum EventDeepLinkBuilder`, `public extension EventCellViewModel { var widgetURL: URL? }`, `public extension CalendarDay { var link: URL? }`, `public enum AICommandEntryLink`

**Steps**
- [ ] Step 1 — `Domain/Sources/Utils/AppDeepLink.swift` 를 만들어 `public enum AppDeepLink { private enum Constant { static let scheme: String = "tc.app" }; public static var scheme: String { Constant.scheme } }` 형태로 쓴다. 같은 폴더의 `WebAppLink.swift` 가 그 서식의 형제다 — `private enum Constant` 로 리터럴을 응집하고 public 접근자를 따로 둔다.
- [ ] Step 2 — `AppEnvironment.swift:63` 의 `appScheme` 을 지운다. 정본을 둘로 남기면 짝이 어긋나므로 원본을 남기지 않는다. 소비처 `ApplicationDeepLinkHandler.swift:38` 과 `OpenAICommandInputIntent.swift:46` 을 `AppDeepLink.scheme` 으로 바꾼다.
- [ ] Step 3 — `WidgetLink+Extensions.swift` 의 `EventDeepLinkBuilder`(`:14`~:50)·`EventCellViewModel.widgetURL`(`:78`~:103)·`CalendarDay.link`(`:106`~:115)·`AICommandEntryLink`(`:118`~:122)를 `EventDeepLinkBuilder.swift` 로 옮기고 `public` 을 연다. 넷 다 `EventCellViewModel`·`CalendarDay`·`EventTime` 을 아는 자리가 필요한데 `CalendarPresentation` 이 그 셋을 다 보는 최하위 모듈이다.
- [ ] Step 4 — 남은 `LiveActivityEventTarget.eventDetailURL`(`:53`~:75) 하나만 담도록 파일을 `LiveActivityLink+Extensions.swift` 로 `git mv` 하고 `import CalendarPresentation` 을 확인한다. `LiveActivityEventTarget` 은 `TodoCalendarApp/Sources/LiveActivity/LiveActivityEventTarget.swift:12` 의 확장 공용 소스라 이 extension 은 확장에 남는다.
- [ ] Step 5 — `mise exec -- tuist generate --no-open` 후 `TodoCalendarApp`·`TodoCalendarAppWidget` 빌드를 확인한다. `Domain` 스킴도 돌려 상수 신설이 기존 테스트를 안 깨는지 본다.
- [ ] Step 6 — 부록 B 커밋 2.

### Task 3: Today·Month 순수 뷰와 ViewModel 이관

**Files**
- Create: `Presentations/WidgetScenes/Sources/Today/TodayWidgetViews.swift`, `Presentations/WidgetScenes/Sources/Today/TodayWidgetViewModel.swift`, `Presentations/WidgetScenes/Sources/Month/MonthWidgetViews.swift`, `Presentations/WidgetScenes/Sources/Month/MonthWidgetViewModel.swift`
- Modify: `TodoCalendarApp/AppExtensions/Widget/Sources/Widgets/TodayWidget/TodayWidget.swift`, `.../TodayWidget/TodayWidgetViewModelProvider.swift`, `.../TodayWidget/TodayWidgetTimelineProvider.swift`, `.../MonthWidget/MonthWidget.swift`, `.../MonthWidget/MonthWidgetViewModelProvider.swift`, `.../MonthWidget/MonthWidgetTimelineProvider.swift`

**Interfaces**
- Consumes: T-1 이 세운 `WidgetScenes → CalendarPresentation` 의존
- Produces: `public struct TodaySummaryView`, `public struct TodayWidgetViewModel` (+ `public static func sample()`), `public struct SingleMonthView`, `public struct MonthWidgetViewModel`

**Steps**
- [ ] Step 1 — `TodaySummaryView`(`TodayWidget.swift:21`~:114)를 `TodayWidgetViews.swift` 로 옮긴다. 파일 머리는 `Presentations/WidgetScenes/Sources/DDay/DDayWidgetViews.swift:1-10` 의 헤더 서식을 따르고 타겟명은 `WidgetScenes` 로 쓴다. import 는 실제로 쓰는 것만 남긴다.
- [ ] Step 2 — `TodayWidgetViewModel`(`TodayWidgetViewModelProvider.swift:19`~:81, `sample()` 포함)을 `TodayWidgetViewModel.swift` 로 옮긴다. `DDayWidgetViewModel.swift:16`·`:51` 이 동형이다.
- [ ] Step 3 — 옮긴 타입과 그 프로퍼티·메서드·init 을 `public` 으로 연다. 컴파일러가 지목하는 것만 연다.
- [ ] Step 4 — `MonthWidget.swift:19`~:112 의 `SingleMonthView` 와 `MonthWidgetViewModelProvider.swift:19`~:116 의 `MonthWidgetViewModel` 에 같은 처리를 한다.
- [ ] Step 5 — 확장에 남은 네 파일(`TodayWidget.swift`·`TodayWidgetViewModelProvider.swift`·`MonthWidget.swift`·`MonthWidgetViewModelProvider.swift`)과 두 TimelineProvider 에 `import WidgetScenes` 를 더한다. 안 쓰게 된 import 는 지운다.
- [ ] Step 6 — `mise exec -- tuist generate --no-open` 후 `TodoCalendarAppWidget` 스킴 빌드가 통과하는지 확인한다.
- [ ] Step 7 — 부록 B 커밋 3.

### Task 4: Foremost·EventList 순수 뷰와 ViewModel 이관

**Files**
- Create: `Presentations/WidgetScenes/Sources/Foremost/ForemostWidgetViews.swift`, `Presentations/WidgetScenes/Sources/Foremost/ForemostEventWidgetViewModel.swift`, `Presentations/WidgetScenes/Sources/EventList/EventListWidgetViews.swift`, `Presentations/WidgetScenes/Sources/EventList/EventListWidgetViewModel.swift`
- Modify: `.../ForemostWidget/ForemostEventWidget.swift`, `.../ForemostWidget/ForemostEventWidgetViewModel+Provider.swift`, `.../ForemostWidget/ForemostEventWidgetTimelineProvider.swift`, `.../EventListWidget/EventListWidget.swift`, `.../EventListWidget/EventListWidgetViewModelProvider.swift`, `.../EventListWidget/EventListWidgetTimeLineProvider.swift`

**Interfaces**
- Produces: `public struct InlineSizeForemostEventView`, `public struct SystemSizeForemostEventView`, `public struct ForemostEventWidgetViewModel` (+ `sample()`), `public struct EventListView`, `public struct TodoToggleButton`, `public struct EventListWidgetViewModel` (+ `sample(size:)`), `public enum EventListWidgetSize`

**Steps**
- [ ] Step 1 — `InlineSizeForemostEventView`(`ForemostEventWidget.swift:22`~:39)를 옮기면서 `:33`·`:36` 의 `.widgetAccentable()` 을 걷어낸다. 그 modifier 는 `ForemostEventWidgetView`(`:239`)의 accessoryInline 분기가 뷰를 부른 자리에 붙인다. `DDayWidget.swift:24`~:38 이 같은 처리의 동형이다.
- [ ] Step 2 — `SystemSizeForemostEventView`(`:41`~:237, 내부 `ForemostTodoToggleButton:203` 포함)를 옮긴다. 이 뷰의 시그니처는 `init(model:isSmallSize:)` 다 — `EventAndForemostWidget.swift:35` 가 그렇게 부른다.
- [ ] Step 3 — `ForemostEventWidgetViewModel`(`ForemostEventWidgetViewModel+Provider.swift:19`~:40, `sample()` 포함)을 옮긴다.
- [ ] Step 4 — `EventListView`(`EventListWidget.swift:21`~:180)·`TodoToggleButton`(`:182`~:210)·`extension ViewAppearance`(`:253`~:269)를 `EventListWidgetViews.swift` 로 옮긴다. `extension ViewAppearance` 는 순수 뷰가 쓰는 경우에만 옮기고, 엔트리 뷰만 쓰면 확장에 남긴다 — 컴파일러가 판정한다.
- [ ] Step 5 — `EventListWidgetSize`(`EventListWidgetViewModelProvider.swift:20`~:33)와 `EventListWidgetViewModel`(`:35`~:292, `sample(size:)` 포함)을 `EventListWidgetViewModel.swift` 로 옮긴다. `EventListWidgetSize` 의 `init(_ family:)` 가 `WidgetFamily` 를 받으면 그 이니셜라이저만 확장에 extension 으로 남긴다 — `WidgetScenes` 는 WidgetKit 을 안 문다 (C1).
- [ ] Step 6 — 확장 파일들에 `import WidgetScenes` 를 더하고 안 쓰는 import 를 지운다.
- [ ] Step 7 — `mise exec -- tuist generate --no-open` 후 `TodoCalendarAppWidget` 빌드를 확인한다.
- [ ] Step 8 — 부록 B 커밋 4.

### Task 5: WeekEvents 순수 뷰와 ViewModel 이관

**Files**
- Create: `Presentations/WidgetScenes/Sources/WeekEvents/WeekEventsViews.swift`, `Presentations/WidgetScenes/Sources/WeekEvents/WeekEventsViewModel.swift`
- Modify: `.../WeekEventsWidget/WeekEventsView.swift`(삭제), `.../WeekEventsWidget/WeekEventsWidget.swift`, `.../WeekEventsWidget/WeekEventsWidgetViewModelProvider.swift`, `.../WeekEventsWidget/WeekEventsWidgetTimelineProvider.swift`
- Test: `TodoCalendarApp/AppExtensions/Widget/Tests/ViewModelProviders/WeekEventsWidgetViewModelProviderTests.swift`

**Interfaces**
- Produces: `public struct WeekEventsView`, `public enum WeekEventsRange`, `public struct WeekEventsViewModel` (+ `sample(_:)`)

**Steps**
- [ ] Step 1 — `WeekEventsView.swift` 전체(`:18` 뷰, `:224` `extension ColorSet`, `:235`·`:268` private extension 둘)를 `WeekEventsViews.swift` 로 옮긴다. 파일째 이동이라 `git mv` 를 쓰고 헤더의 타겟명만 고친다.
- [ ] Step 2 — `WeekEventsRange`(`WeekEventsWidgetViewModelProvider.swift:19`~:29)·`WeeksWithRange`(`:31`~:42)·`WeekEventsViewModel`(`:44`~:194, `sample(_:)` 포함)을 `WeekEventsViewModel.swift` 로 옮긴다. `WeeksWithRange` 는 `WeekEventsViewModel` 이 쓰면 함께 옮기고, Provider 만 쓰면 확장에 남긴다.
- [ ] Step 3 — `DummyCalendarEvent`(`:351`)는 `sample(_:)` 이 쓰면 함께 옮긴다. 그렇지 않으면 확장에 남긴다.
- [ ] Step 4 — `WeekEventsRange` 는 `WeekEventsWidgetTimelineProvider.swift:22`·`:23` 도 쓴다. 그 파일에 `import WidgetScenes` 를 더한다.
- [ ] Step 5 — 옮긴 타입을 `public` 으로 연다. `WeekEventsRange` 는 associated value 를 갖는 enum 이니 case 자체가 public 이 되고, 부수 메서드도 컴파일러가 지목하는 것만 연다.
- [ ] Step 6 — `WeekEventsWidgetViewModelProviderTests.swift` 가 옮긴 타입을 참조하면 `import WidgetScenes` 를 더한다.
- [ ] Step 7 — `mise exec -- tuist generate --no-open` 후 `TodoCalendarAppWidget` 빌드를 확인한다.
- [ ] Step 8 — 부록 B 커밋 5.

### Task 6: NextEvent·NextRemain·TodayAndNext 순수 뷰와 ViewModel 이관

**Files**
- Create: `Presentations/WidgetScenes/Sources/NextEvent/NextEventWidgetViews.swift`, `Presentations/WidgetScenes/Sources/NextEvent/NextEventWidgetViewModel.swift`, `Presentations/WidgetScenes/Sources/TodayAndNext/TodayAndNextWidgetViews.swift`, `Presentations/WidgetScenes/Sources/TodayAndNext/TodayAndNextWidgetViewModel.swift`
- Modify: `.../NextEventWidget/Next/NextEventWidget.swift`, `.../NextEventWidget/Next/NextEventWidgetTimeLineProvider.swift`, `.../NextEventWidget/NextRemain/NextRemainEventWidget.swift`, `.../NextEventWidget/NextRemain/NextRemainEventWidgetTimeLineProvider.swift`, `.../NextEventWidget/NextEventWidgetViewModelProvider.swift`, `.../TodayAndNext/TodayAndNextWidget.swift`, `.../TodayAndNext/TodayAndNextWidgetViewModel+Provider.swift`, `.../TodayAndNext/TodayAndNextWidgetTimeLineProvider.swift`
- Test: `Tests/ViewModelProviders/NextEventWidgetViewModelProviderTests.swift`, `Tests/ViewModelProviders/TodayAndNextWidgetViewModelProviderTests.swift`

**Interfaces**
- Produces: `public struct NextEventWidgetInlineView`, `public struct NextEventRectangleWidgetView`, `public struct NextRemainEventVListiew`, `public struct NextEventWidgetViewModel` (+ `sample`), `public struct NextEventListWidgetViewModel` (+ `sample`), `public struct TodayAndNextWidgetView`, `public struct TodayAndNextWidgetViewModel` (+ `sample()`)

**Steps**
- [ ] Step 1 — `NextEventWidgetInlineView`(`Next/NextEventWidget.swift:21`~:35)와 `NextEventRectangleWidgetView`(`:37`~:81)를 `NextEventWidgetViews.swift` 로 옮긴다. `NextRemainEventVListiew`(`NextRemain/NextRemainEventWidget.swift:19`~:55)도 같은 파일에 넣는다 — 셋 다 next 계열 모델을 받는 순수 뷰다.
- [ ] Step 2 — `NextEventWidgetViewModel`(`NextEventWidgetViewModelProvider.swift:19`~:49)과 `NextEventListWidgetViewModel`(`:51`~:69)을 `NextEventWidgetViewModel.swift` 로 옮긴다. `NextEventWidgetViewModelBuilder`(`:71`~:153)와 `private extension EventTimeText`(`:209`)는 Domain 모델을 ViewModel 로 바꾸는 조립기라 확장에 남긴다 — 갤러리는 `.sample` 만 쓴다.
- [ ] Step 3 — `TodayAndNextWidgetView`(`TodayAndNextWidget.swift:21`~:418)와 `private extension EventPeriodText`(`:461`~:475)를 `TodayAndNextWidgetViews.swift` 로 옮긴다. 그 extension 은 뷰가 쓰면 함께 가고 엔트리 뷰만 쓰면 남는다.
- [ ] Step 4 — `TodayAndNextWidgetViewModel`(`TodayAndNextWidgetViewModel+Provider.swift:19`~:94)과 그 extension 둘(`:96`·`:168`, `sample()` 포함)을 `TodayAndNextWidgetViewModel.swift` 로 옮긴다. `Builder`(`:194`~:480)와 `Provider`(`:482`~)와 `private extension Array<EventModel>`(`:563`)는 확장에 남긴다.
- [ ] Step 5 — 옮긴 타입을 `public` 으로 열고 확장 파일에 `import WidgetScenes` 를 더한다.
- [ ] Step 6 — 두 Provider 테스트가 옮긴 타입을 참조하면 `import WidgetScenes` 를 더한다.
- [ ] Step 7 — `mise exec -- tuist generate --no-open` 후 `TodoCalendarAppWidget` 빌드를 확인한다.
- [ ] Step 8 — 부록 B 커밋 6.

### Task 7: AICommand 순수 뷰 이관과 WidgetKit 심볼 이동

**Files**
- Create: `Presentations/WidgetScenes/Sources/AICommand/AICommandWidgetViews.swift`
- Modify: `.../AICommandWidget/AICommandShortcutWidget.swift`

**Interfaces**
- Produces: `public struct AICommandCircularView`, `public struct AICommandSmallView`

**Steps**
- [ ] Step 1 — `AICommandShortcutWidgetView`(`:45`~:88)를 패밀리별로 가른다. `circularView`(`:63`~:70)가 `AICommandCircularView` 로, `smallView`(`:72`~:87)가 `AICommandSmallView` 로 간다. DP-1.1 이 D-day 를 패밀리별 뷰 5개로 가른 것과 같은 형태다 (`DDayWidgetViews.swift:60`·`:94`·`:142`·`:158`·`:186`).
- [ ] Step 2 — 순수 뷰에서 WidgetKit 심볼 셋을 걷어낸다. `AccessoryWidgetBackground()`(`:64`)와 `.widgetAccentable()`(`:68`)은 확장에 남는 엔트리 뷰가 씌우고, `@Environment(\.widgetFamily)`(`:47`) 분기도 엔트리 뷰가 한다. `DDayWidget.swift:24`~:38 이 그 형태다.
- [ ] Step 3 — 확장에 `AICommandShortcutWidgetView` 를 엔트리 뷰로 남기되, 본문은 family 분기와 위 세 modifier 만 갖고 콘텐츠는 옮긴 두 뷰를 부른다.
- [ ] Step 4 — 이 뷰는 `WidgetCatalogSnapshots.swift:212` 가 `AICommandShortcutWidgetView()` 로 직접 부른다. 엔트리 뷰가 확장에 남고 이름도 유지되므로 스냅샷 호출부는 안 바뀐다.
- [ ] Step 5 — `mise exec -- tuist generate --no-open` 후 `TodoCalendarAppWidget` 빌드를 확인한다.
- [ ] Step 6 — 부록 B 커밋 7.

### Task 8: Composed 4종 ViewModel 이관

**Files**
- Create: `Presentations/WidgetScenes/Sources/Composed/ComposedWidgetViewModels.swift`
- Modify: `.../ComposedWidget/DoubleMonthWidget/DoubleMonthWidgetTimlineProvider.swift`, `.../ComposedWidget/EventAndForemostWidget/EventAndForemostWidgetTimelineProvider.swift`, `.../ComposedWidget/EventAndMonthWidget/EventAndMonthWidgetTimelineProvider.swift`, `.../ComposedWidget/TodayAndMonthWidget/TodayAndMonthWidgetTimelineProvider.swift`, 그리고 네 `…Widget.swift`

**Interfaces**
- Consumes: T-2·T-3 이 옮긴 `TodaySummaryView`·`SingleMonthView`·`EventListView`·`SystemSizeForemostEventView` 와 그 ViewModel
- Produces: `public struct DoubleMonthWidgetViewModel`, `public struct EventAndForemostWidgetViewModel`, `public struct EventAndMonthWidgetViewModel`, `public struct TodayAndMonthWidgetViewModel`

**Steps**
- [ ] Step 1 — 네 ViewModel(`DoubleMonthWidgetTimlineProvider.swift:20`~:24, `EventAndForemostWidgetTimelineProvider.swift:18`~:22, `EventAndMonthWidgetTimelineProvider.swift:18`~:22, `TodayAndMonthWidgetTimelineProvider.swift:18`~:22)을 `ComposedWidgetViewModels.swift` 한 파일에 모은다. 넷 다 다른 ViewModel 둘을 담는 5줄짜리 구조체라 파일을 넷으로 가르면 요소만 늘어난다.
- [ ] Step 2 — 각 ViewModel 을 `public` 으로 열고 `public init` 을 명시한다.
- [ ] Step 3 — 네 ViewModelProvider(`DoubleMonthWidgetViewModelProvider:26` 등)는 Domain 조회를 하므로 확장에 남긴다. 각 파일에 `import WidgetScenes` 를 더한다.
- [ ] Step 4 — 네 엔트리 뷰(`DoubleMonthWidgetView` 등)에도 `import WidgetScenes` 를 더한다. 뷰 본문은 안 바꾼다.
- [ ] Step 5 — `mise exec -- tuist generate --no-open` 후 `TodoCalendarAppWidget` 빌드를 확인한다.
- [ ] Step 6 — 부록 B 커밋 8.

### Task 9: 스냅샷 대조와 최종 검증

**Files**
- Modify: `TodoCalendarApp/AppExtensions/Widget/Snapshots/WidgetCatalogSnapshots.swift`
- Test: `Widget/Tests/ViewModelProviders/**` 중 import 보강이 필요한 파일

**Interfaces**
- Consumes: T-1 이 확보한 기준 png, T-2~T-7 의 이관 결과

**Steps**
- [ ] Step 1 — `WidgetCatalogSnapshots.swift` 에 `import WidgetScenes` 를 더한다. `@testable import TodoCalendarAppWidget` 은 유지한다 — 엔트리 뷰를 부르는 케이스가 넷 있다.
- [ ] Step 2 — `grep -rn "import WidgetKit\|import CalendarScenes\|import Scenes" Presentations/WidgetScenes/Sources/` 가 0건인지 확인한다. 걸리면 FFIR-2·FFIR-3 이다.
- [ ] Step 3 — 스냅샷 스위트를 실행해 png 를 다시 뽑고, T-1 의 기준 png 와 `cmp` 로 전수 비교한다. 다른 파일이 나오면 D-1 로 간다.
- [ ] Step 4 — `bash .claude/skills/implement/scripts/impact-check.sh` 를 돌려 tuist generate 필요 여부와 짝 경고를 확인하고, 산출된 스킴 중 `WidgetScenes`·`TodoCalendarAppWidget`·`TodoCalendarApp` 을 실행한다.
- [ ] Step 5 — 부록 B 커밋 9.

## 부록 B. 커밋 시퀀스

| # | 태스크 | 메시지 |
|---|---|---|
| 1 | T-1 | `[#1065] WidgetScenes 가 CalendarPresentation 을 물게 한다` |
| 2 | T-2 | `[#1065] 앱 스킴을 Domain 으로, 딥링크 계산식을 CalendarPresentation 으로 내린다` |
| 3 | T-3 | `[#1065] Today·Month 순수 뷰와 ViewModel 을 WidgetScenes 로 내린다` |
| 4 | T-4 | `[#1065] Foremost·EventList 순수 뷰와 ViewModel 을 WidgetScenes 로 내린다` |
| 5 | T-5 | `[#1065] WeekEvents 순수 뷰와 표시 모델을 WidgetScenes 로 내린다` |
| 6 | T-6 | `[#1065] NextEvent·NextRemain·TodayAndNext 순수 뷰와 ViewModel 을 WidgetScenes 로 내린다` |
| 7 | T-7 | `[#1065] AICommand 순수 뷰를 패밀리별로 가르고 WidgetKit 심볼을 엔트리 뷰로 올린다` |
| 8 | T-8 | `[#1065] Composed 4종 ViewModel 을 WidgetScenes 로 내린다` |
| 9 | T-9 | `[#1065] 스냅샷과 테스트가 WidgetScenes 를 보게 하고 이관 무손실을 확인한다` |

커밋 1 은 `Project.swift` 한 줄과 그에 따른 프로젝트 재생성만 담는다. 기준 png 는 gitignore 대상이라 커밋에 안 들어간다.

## 부록 C. 모델 티어

| 태스크 | 티어 | 근거 |
|---|---|---|
| T-1 | 하위 (haiku급) | 의존 한 줄 추가와 스위트 실행이다. 결정이 경로 수준까지 확정돼 있다 |
| T-2 | 표준 (sonnet급) | 정본을 옮기면서 소비처를 전수로 맞추는 조율이다 |
| T-3 | 표준 (sonnet급) | 파일을 가르고 접근 제어를 순차로 여는 멀티 파일 조율이다 |
| T-4 | 표준 (sonnet급) | 같은 성격에 `widgetURL` extension 판별이 붙는다 |
| T-5 | 표준 (sonnet급) | `WeekEventsRange` 가 양쪽에서 쓰여 경계 판정이 필요하다 |
| T-6 | 표준 (sonnet급) | 세 위젯군에 걸치고 Builder 잔류 판정이 붙는다 |
| T-7 | 표준 (sonnet급) | WidgetKit 심볼을 걷어내며 뷰를 가르는 판단이다 |
| T-8 | 하위 (haiku급) | 5줄짜리 구조체 넷을 옮기고 import 를 더한다 |
| T-9 | 표준 (sonnet급) | 대조 결과 판정과 스킴 실행이다 |

## 부록 D. 단편명령 누적

### FRAGO-1 (2026-09-09) — 딥링크 계산식의 하향 대상과 자리를 바꾼다

**3-다 과업** — T-2 를 신설하고 기존 T-2~T-8 을 T-3~T-9 로 민다. 나머지 변경 없음.

**부록 A Task 4(옛 Task 3) Step 1** — "`WidgetLink+Extensions.swift:78`~:90 의 `extension EventCellViewModel { var widgetURL }` 를 `EventCellViewModel+WidgetURL.swift` 로 옮기고 `public` 으로 연다" 를 삭제한다. 새 Task 2 가 그 일을 더 넓게 대신한다.

**사유** — 링크 계산이 `AppEnvironment.appScheme`(`TodoCalendarApp/Sources/AppEnvironment.swift:63`)에 걸려 있는데 그 파일은 확장 타겟이 직접 컴파일하는 소스라(`Project+Templates.swift:369`) 프레임워크에서 안 보인다. 원안대로 `WidgetScenes` 로 내리면 컴파일이 안 된다. 순수 뷰가 링크를 계산하는 자리가 6개 위젯군 16곳이라 이 매듭을 안 풀면 이관 대상이 절반 아래로 준다.

**결심** — 앱 스킴 상수를 `Domain/Sources/Utils/AppDeepLink.swift` 로, 계산식 넷을 `CalendarPresentation` 으로 내린다 (2026-09-09 유저 재가). `Domain/Sources/Utils/` 에 `WebAppLink`·`LegalLink`·`GuideLink` 가 이미 링크 상수 정본으로 살아 그 자리의 형제가 된다. 이러면 순수 뷰 코드가 한 줄도 안 바뀐 채 옮겨가 3-라 의 "옮길 땐 옮기기만 한다" 제한도 유지된다.

**나머지 항목** — 변경 없음.
