# 작업 지침 (Operation Order) — DP-2.1

> 용어 — DP: 결정적 지점(작업 지침 하나 = PR 하나) · LOE: 노력선(최종상태 한 관점을 담당하는 줄기) · FRAGO: 단편명령 · MOP / MOE: 과업 수행 여부 / 효과 발생 여부 · PIR / FFIR: 즉시보고 조건 중 환경·외부 정보 / 아군·내부 정보

```
작업 지침 — #1060 CalendarPresentation 신설과 표시 모델 하향     초안: 에이전트   재가: 유저   일자: 2026-09-09
상위: campaign.md #721 / LOE-1 / 2단계 매듭 풀기 / DP-2.1 / 선행 DP-1.1 (PR #1058 머지 완료)
```

## 1. 상황

### 가. 정찰 결과

- 위젯 확장이 무는 `CalendarScenes` public 심볼은 23개다. 안 쓰는 것은 `CalendarSceneBuilderImple` 하나뿐이고, 나머지 23개는 전부 아래 5파일 안에 있다. `CalendarScenes` 에는 public 뷰 타입이 하나도 없어서 확장이 화면 코드를 볼 여지 자체가 없다.
- `Common/CalendarEvents/CalendarEvent.swift` 는 `EventTimeOnCalendar`(:16)·`CalendarEvent` 프로토콜(:52)과 `TodoCalendarEvent`(:95)·`ScheduleCalendarEvent`(:146)·`HolidayCalendarEvent`(:184)·`GoogleCalendarEvent`(:218)·`AppleCalendarEvent`(:273) 를 담는다. 확장에서 이 계열의 사용이 135건으로 가장 많다.
- `Common/EventListCell/EventCellViewModel.swift` 는 `EventCellViewModel` 프로토콜(:165)과 준수 타입 7종을 담고, 같은 파일에 `EventTimeText`(:17)·`EventPeriodText`(:40)·`EventListRemoveScope`(:142)·`EventListMoreAction`(:148)·`EventListMoreActionModel`(:159) 이 함께 있다.
- `Month/MonthViewModel.swift` 는 표시 모델 5종(`WeekDayModel`:19·`DayCellViewModel`:53·`WeekRowModel`:98·`EventMoreModel`:115·`WeekEventStackViewModel`:125)과 `MonthViewModelImple`(:177) 이 한 파일에 있다. 표시 모델 구간은 1~158줄이다.
- `Month/WeekEventStackBuilder.swift` 는 `EventOnWeek`(:17)·`WeekEventStack`(:70)·`WeekEventStackBuilder`(:79) 를 담는다.
- **표시 모델과 이벤트 모델은 분리할 수 없다.** `EventOnWeek.event` 의 타입이 `any CalendarEvent`(`WeekEventStackBuilder.swift:18`)이고, 셀 뷰모델 7종의 생성자가 전부 `TodoCalendarEvent`·`ScheduleCalendarEvent` 같은 구체 이벤트 타입을 받는다(`EventCellViewModel.swift:50`·`:369`·`:436`·`:478`·`:536`). 계획 7항이 적은 "표시 모델 6종"만 내리면 컴파일이 되지 않는다.
- 이동 대상 5파일이 하는 import 는 Foundation·Combine·Domain·Extensions·Prelude·Optics·CommonPresentation 뿐이다. `Scenes` 를 물지 않으므로 신설 모듈도 `Scenes` 를 물 필요가 없다.
- `WeekDayModel.allModels()` 가 쓰는 `R.String` 은 `Supports/Extensions/Sources/Type+Extensions/String+Extensions.swift:13` 에 있고, `localized()` 가 `Bundle.module`(:23)로 문자열을 찾는다. 번들이 `Extensions` 모듈에 고정돼 있어 호출부가 어느 모듈로 옮겨가도 문자열 조회 결과가 달라지지 않는다.
- 모듈 밖에서 `CalendarScenes` 를 무는 것은 앱 루트 2파일(`ApplicationDeepLinkHandler.swift`·`ApplicationRootRouter.swift`)뿐이고 둘 다 Scene 빌더·딥링크를 쓴다. `EventListScenes` 는 `CalendarScenes` 를 아예 물지 않는다. 계획 8항 A2 가 예상한 파급보다 좁다.
- 이동 후에도 `CalendarScenes` 가 계속 써야 하는데 지금 internal 인 선언이 넷이다. `PendingTodoEventCellViewModel`(`EventCellViewModel.swift:294`, 소비처 `DayEventListView.swift:806`·`DayEventListViewModel.swift:136`), `EventCellViewModelMapper`(소비처 `ShareImageContentModel.swift:201`·`DayEventListViewModel.swift:469`), `EventListMoreActionModel` 의 `basicActions`·`removeActions`(:160~161, 소비처 `EventListCellView.swift:103`), `EventOnWeek.eventStartDayIdentifierOnWeek`(`WeekEventStackBuilder.swift:29`, 소비처 `MonthView.swift:441`) 다.
- 선행 DP-1.1 이 세운 `Presentations/WidgetScenes/Project.swift` 가 신설 매니페스트의 동형 선례다.

### 나. 장애·마찰

- **유력한 양상** — 이동 대상이 5파일 1,700여 줄이고 소비처가 세 덩어리(`CalendarScenes` 15파일·확장 45파일·앱 루트)라, 접근 제어 승격을 하나 빠뜨리면 빌드가 깨진다. 컴파일러가 전수로 잡아주므로 진단은 쉽지만 반복 빌드 시간이 든다.
- **가장 위험한 양상** — `MonthViewModel.swift` 에서 표시 모델을 떼는 도중 `MonthViewModelImple` 이 참조하던 private 헬퍼가 함께 딸려가 Month 화면이 조용히 달라지는 것이다. 계획 9항이 이 위험을 "떼는 커밋과 옮기는 커밋을 나눈다"로 완화하라고 지정했다.

### 다. 상위 인용

- **최종상태 관련 관점** — LOE-1 공유 뷰 층. "앱과 확장이 같은 뷰를 그린다"가 이 노력선의 목표이고, 그 전제가 표시 모델을 양쪽이 함께 볼 수 있는 자리로 내리는 것이다.
- **노력선 중간 목표** — 2단계 매듭 풀기의 종료 조건은 "표시 모델 6종이 `CalendarPresentation` 에 있고, 전 위젯 순수 뷰가 `WidgetScenes` 에 있으며, 확장 의존에서 `CalendarScenes` 가 빠졌다"이다. 이 작업이 그중 첫째와 셋째를 담당한다.
- **인접 DP 관계·인터페이스 계약** — C1 이 정한 배치대로 표시 모델은 `CalendarPresentation` 으로 내려간다. 의존 방향은 `WidgetScenes → CalendarPresentation`·`CalendarScenes → CalendarPresentation` 이고 `WidgetScenes` 와 `CalendarScenes` 는 서로 물지 않는다. DP-2.2·2.3 이 위젯 뷰를 옮길 때 이 모듈에서 표시 모델을 가져다 쓴다.
- **계획 개정** — 확장의 `CalendarScenes` 의존 제거는 원래 DP-2.3 의 마지막 과업이었으나 이 작업으로 앞당긴다. 5파일을 내리고 나면 확장이 `CalendarScenes` 에서 가져다 쓸 것이 남지 않아, 미루면 같은 45파일을 두 번 여는 일이 되기 때문이다. 2026-09-09 유저 재가로 확정했다.

### 라. 가정

| ID | 가정 | 출처 | 깨지면 |
|---|---|---|---|
| A-1 | 표시 모델과 이벤트 모델을 `CalendarPresentation` 으로 내려도 캘린더·Month·DayEventList·SharePreview 화면 동작이 달라지지 않는다 | 상속 (계획 8항 A2) | 2단계를 하위 캠페인으로 올린다 |
| A-2 | 확장이 무는 `CalendarScenes` 심볼 23개가 전부 이동 5파일 안에 있어서, 내리고 나면 확장에서 `CalendarScenes` 의존을 뗄 수 있다 | 상속 개정 (계획 8항 A3 — 범위 문언이 "표시 모델뿐"에서 "5파일 전체"로 넓어졌다. 2026-09-09 즉시보고로 보고) | 못 떼는 심볼이 남으면 확장의 `CalendarScenes` 의존을 유지한 채 T-5 만 되돌린다. 나머지 태스크는 그대로 성립한다 |
| A-3 | `R.String` 로컬라이즈가 모듈 이동 후에도 같은 문자열을 찾는다 | 신규 (`String+Extensions.swift:23` 의 `Bundle.module` 이 근거) | `WeekDayModel.allModels()` 만 `CalendarScenes` 에 남기고 나머지를 내린다 |
| A-4 | 신설 모듈이 `Scenes` 를 물지 않아도 이동 5파일이 컴파일된다 | 신규 (이동 대상 5파일의 import 실측) | `Scenes` 를 무는 대신 그 심볼을 `CalendarScenes` 에 남긴다. C1 이 `WidgetScenes` 의 `Scenes` 의존을 DP-4.1 까지 막고 있어 즉시보고 대상이다 |

### 마. 인접 작업

- `orthodox` 워크트리에서 #1057 e2e stub server 가 진행 중이다. 소유 범위가 `TodoCalendarApp/E2E/**` 와 스크립트라 이 작업과 겹치지 않는다.
- 이 작업의 base 는 `origin/develop` 의 `c0768b2b` 다. 하네스 문서 커밋이라 코드 충돌이 없다.

## 2. 임무

이 작업은 캘린더 화면과 위젯이 함께 쓰는 표시·이벤트 모델을 `Presentations/CalendarPresentation` 으로 내리고 위젯 확장의 `CalendarScenes` 의존을 떼어, 뒤따르는 DP-2.2·2.3 이 위젯 뷰를 `WidgetScenes` 로 옮길 때 물어야 할 모델 층을 먼저 세운다.

## 3. 실시

### 가. 의도

- **목적** — 위젯이 캘린더 화면 모듈을 물지 않고도 같은 모델을 쓰게 만든다. 지금은 표시 모델이 화면 모듈 안에 있어서, 위젯이 그 모델을 쓰려면 화면 전체를 딸려 물어야 한다. 그 매듭을 푸는 것이 2단계의 첫 과업이다.
- **핵심과업** — 모델을 옮기는 동안 옮기기만 한다. 타입 이름·프로퍼티·생성자 시그니처·구현 내용을 하나도 바꾸지 않고, 파일이 사는 모듈만 달라지게 한다. 접근 제어 승격은 모듈 경계를 넘느라 불가피한 만큼만 한다.
- **최종상태**
  - *동작* — 캘린더 화면·Month 그리드·일별 이벤트 목록·공유 이미지 미리보기가 지금과 똑같이 그려지고 똑같이 반응한다.
  - *코드* — `Presentations/CalendarPresentation` 이 서고 그 안에 5파일이 있다. `CalendarScenes` 와 위젯 확장이 그 모듈을 문다.
  - *구조* — 위젯 확장의 의존 목록과 소스 45파일 어디에도 `CalendarScenes` 가 없다. `CalendarPresentation` 은 `Scenes` 를 물지 않는다.
  - *검증* — `CalendarPresentation`·`CalendarScenes`·`TodoCalendarApp`·`TodoCalendarAppWidget` 네 스킴이 통과하고, `CalendarScenes` 스냅샷이 이관 전과 같다.
  - *외부* — 없음.

### 나. 개념

- **결정적 행동** — 5파일을 새 모듈로 옮기고 소비처 세 덩어리의 import 를 한 번에 맞춘다.
- **여건 조성** — 옮기기 전에 두 가지를 먼저 해둔다. 프레임워크 골격을 세워 빈 모듈이 빌드되는 것을 확인하고(T-1), `MonthViewModel.swift` 에서 표시 모델을 같은 모듈 안의 새 파일로 떼어 화면이 안 깨지는 것을 확인한다(T-2). 둘 다 통과한 뒤에야 모듈 경계를 넘는다.
- **대안 경로와 전환 조건** — 확장에서 `CalendarScenes` 를 뗐는데 컴파일이 안 되는 심볼이 남으면(A-2 붕괴), T-5 만 되돌려 확장 의존을 유지한 채 나머지를 완성한다. 그 경우 확장 의존 제거는 계획대로 DP-2.3 이 맡는다.
- **단계** — ① 골격이 서고 빈 모듈이 빌드된다 ② 표시 모델이 같은 모듈 안에서 분리되고 `CalendarScenes` 스킴이 통과한다 ③ 5파일이 새 모듈로 넘어가고 `CalendarScenes` 스킴이 다시 통과한다 ④ 확장이 새 모듈만 물고 위젯 스킴이 통과한다.

### 다. 과업

- **T-1**: `Presentations/CalendarPresentation` 프레임워크를 신설하고 워크스페이스·앱 타겟·스킴 하드코딩 다섯 곳에 등록하여, 옮길 자리를 만든다.
- **T-2**: `MonthViewModel.swift` 에서 표시 모델 5종을 같은 모듈 안의 `MonthDisplayModels.swift` 로 떼어내어, 모듈 경계를 넘기 전에 파일 분리만으로 화면이 안 깨지는 것을 확인한다.
- **T-3**: 5파일을 `CalendarPresentation` 으로 옮기고 접근 제어를 승격한 뒤 `CalendarScenes` 소비처 15파일의 import 를 맞추어, 화면 모듈이 새 모듈을 물게 한다.
- **T-4**: 이동한 타입의 테스트 4종을 `CalendarPresentation/Tests` 로 옮겨, 테스트가 검증 대상과 같은 모듈에 있게 한다.
- **T-5**: 위젯 확장 45파일의 import 를 치환하고 확장 타겟 의존에서 `CalendarScenes` 를 제거하여, 확장이 화면 모듈에서 독립하게 한다.

### 라. 협조지시

- **개시 조건** — 계획 재가 완료, 선행 DP-1.1 머지 완료(`e1021764`), 소유 범위 확보. 셋 다 충족했다.
- **인터페이스 계약** — 상속: C1(무엇을 어디에 두나)·C5(머지 순서). 추가: `CalendarPresentation` 의 의존은 `Common3rdParty`·`CommonPresentation`·`Domain`·`Extensions` 넷으로 고정한다. `Scenes` 를 추가하지 않는다.
- **제한**
  - 이동 대상 타입의 이름·프로퍼티·생성자 시그니처·구현을 바꾸지 않는다. 계획 13항이 "옮길 땐 옮기기만 한다"를 상시 제한으로 두고 있고, 동작 변화가 섞이면 스냅샷 대조가 판정 수단으로 못 쓰이게 된다.
  - 접근 제어 승격은 컴파일 에러가 요구하는 선언에만 한다. 미리 열어두면 모듈 공개 표면이 근거 없이 넓어진다.
  - `CalendarEventListhUsecase` 와 Scene 계층은 건드리지 않는다. 이동 대상이 아니고 확장도 쓰지 않는다.
  - 위젯 뷰 파일을 `WidgetScenes` 로 옮기지 않는다. DP-2.2·2.3 의 소유 범위다.
- **위임 범위** — 계획 12항을 상속한다. 좁히는 것은 없다. 신설 모듈 안의 디렉토리 구조와 분리 파일명은 자율이다.
- **수용 위험** — 확장 45파일의 import 치환이 한 줄씩 45번 반복되는 기계적 변경이라 PR diff 가 커진다. 위젯 스킴 테스트가 그물이므로 크기를 수용한다.
- **버퍼** — 실행자는 파일 배치·분리 파일명·커밋 내 작업 순서를 재량으로 정한다. 그 밖은 아래 결정지점과 우발계획을 따른다.

**즉시보고 조건**

- **FFIR-1** — 이동 5파일이 `Scenes` 나 `CalendarScenes` 의 다른 심볼을 물어야 컴파일된다 (A-4·C1 붕괴) → D-1
- **FFIR-2** — 확장에서 `import CalendarScenes` 를 지웠는데 컴파일이 안 되는 심볼이 남는다 (A-2 붕괴) → D-2
- **FFIR-3** — `CalendarScenes` 스냅샷이 이관 전과 달라진다 (A-1 붕괴) → D-3
- **PIR-1** — base 인 `origin/develop` 에 이 작업의 소유 범위를 건드리는 커밋이 들어온다 → D-4

**결정지점**

| ID | 결정 | 판단 정보 | 시한(조건) | 미결 시 기본 행동 |
|---|---|---|---|---|
| D-1 | 그 심볼을 함께 내릴지, 아니면 그 타입만 `CalendarScenes` 에 남길지 | 컴파일 에러 지점과 해당 심볼의 소비처 목록 | T-3 진행 중 | 유저에게 즉시보고하고 답이 올 때까지 T-3 을 멈춘다. 모듈 공개 표면을 임의로 넓히지 않는다 |
| D-2 | 확장 의존을 유지한 채 갈지, 남은 심볼도 내릴지 | 남은 심볼 목록과 그 심볼이 사는 파일 | T-5 진행 중 | 확장 의존을 유지하고 T-5 를 되돌린다. 나머지 태스크는 완성하고 잔여를 DP-2.3 으로 넘긴다 |
| D-3 | 이관 방식을 고칠지, 계획을 개정할지 | 달라진 스냅샷 이미지와 원인 지점 | T-3 완료 직후 | 즉시보고하고 멈춘다. 스냅샷 차이는 A-1 붕괴 신호라 자율 판단 대상이 아니다 |
| D-4 | 리베이스할지 기다릴지 | 들어온 커밋의 변경 파일 목록 | 발견 즉시 | 리베이스하고 영향 범위를 다시 확인한다 |

**우발계획**

| 조건 | 행동 | 결심자 | 상향 |
|---|---|---|---|
| `tuist generate` 후 새 스킴이 안 잡힌다 | `Workspace.swift` 등록과 `.h` 헤더 존재를 확인하고 다시 생성한다 | 실행자 | 두 번 실패하면 유저 |
| 접근 제어 승격 대상이 정찰한 넷 말고 더 나온다 | 컴파일 에러가 가리키는 선언만 승격하고 종결보고에 목록으로 싣는다 | 실행자 | 승격 대상이 타입 자체의 신설·분할을 요구하면 유저 |
| 스킴 하드코딩 다섯 곳 중 일부가 이미 다른 형태로 바뀌어 있다 | add-framework 스킬 §3 목록을 정본으로 삼아 맞춘다 | 실행자 | 없음 |
| 확장 테스트가 이동 후 실패한다 | 실패가 import 누락인지 동작 변화인지 가른다. 동작 변화면 FFIR-3 으로 본다 | 실행자 | 동작 변화면 유저 |

## 4. 검증·자원

- **테스트 스킴** — `CalendarPresentation`(신규)·`CalendarScenes`·`TodoCalendarApp`·`TodoCalendarAppWidget`. 최종 확인은 `impact-check.sh` 가 산출하는 목록을 따른다.
- **검증 사다리** — 태스크별로 최소 범위에서 멈춘다. T-1 은 빌드 확인, T-2 는 `CalendarScenes` 스킴, T-3 은 `CalendarPresentation`+`CalendarScenes` 두 스킴, T-5 는 `TodoCalendarAppWidget`+`TodoCalendarApp`. PR 직전에 네 스킴을 한 번 묶어 돌린다.
- **스냅샷** — `CalendarScenes` 스냅샷 스위트(`Presentations/CalendarScenes/Snapshots/`)를 T-3 전후로 각각 찍어 이미지를 대조한다. 이 스위트는 커밋되는 검증 스위트라 `swift-snapshot-testing` 의 기존 baseline 과 그대로 비교된다.
- **실기 확인** — 필요 없다. 모듈 이동이라 런타임 동작이 달라질 자리가 없고, 달라지면 스냅샷이 먼저 잡는다.
- **모델 티어·병렬 슬롯·워크트리** — 부록 C 표를 따른다. 병렬 슬롯은 두지 않는다. 워크트리는 `southpaw` 하나를 쓴다.
- **외부 자원** — 없음.

## 5. 보고

- **즉시** — FFIR-1~3·PIR-1 이 성립하거나, 우발계획의 상향 조건에 걸리거나, rules 에 조항이 없어 판단이 막히면 `report-immediate.md` 서식으로 이슈에 봇 코멘트를 올리고 `@sudopark` 를 멘션한다.
- **정기** — 태스크가 끝날 때마다 진행 파일(`.operations/1060/progress.md`)의 태스크 표를 갱신하고 이슈 본문 미러를 재조립한다.
- **유저 부재 시** — 의도(3-가) 안에 있는 판단은 기본안으로 계속한다. 결정지점 D-1·D-3 에 걸리면 멈춘다. 그 둘은 모듈 공개 표면과 화면 동작이라 되돌리는 비용이 크다.
- **종결 조건** — 네 스킴이 통과하고 스냅샷이 같으며 확장 의존 목록에서 `CalendarScenes` 가 빠지면, PR 을 만들고 종결보고를 낸다.

---

## 부록 A. 태스크 상세

### Task 1: CalendarPresentation 프레임워크 신설

**Files**
- Create: `Presentations/CalendarPresentation/Project.swift`, `Presentations/CalendarPresentation/CalendarPresentation.h`, `Presentations/CalendarPresentation/Sources/.gitkeep`, `Presentations/CalendarPresentation/Tests/.gitkeep`
- Modify: `Workspace.swift`, `TodoCalendarApp/Project.swift`, `.github/workflows/pr_test.yml`, `scripts/run-all-tests.sh`, `.claude/skills/implement/scripts/impact-check.sh`, `.claude/skills/implement/scripts/impact-check.test.sh`, `.claude/skills/run-tests/SKILL.md`

**Interfaces**
- Produces: `CalendarPresentation` 프레임워크 타겟과 `CalendarPresentationTests` 테스트 타겟, 같은 이름의 스킴.

**동형 선례** — `Presentations/WidgetScenes/Project.swift` (DP-1.1 이 만든 것). 매니페스트 형태·`.relativeToRoot` 사용·헤더 파일 배치가 그대로 적용된다.

**시그니처**

```swift
let project = Project.frameworkWithTest(name: "CalendarPresentation",
                                        destinations: [.iPhone],
                                        iOSTargetVersion: "17.0",
                                        dependencies: [ Common3rdParty, CommonPresentation, Domain, Extensions ])
```

의존 넷의 실제 표기는 `.project(target:path: .relativeToRoot(...))` 형식이다. `.relativeToCurrentFile` 은 쓰지 않는다 (#794).

**적용 rules 발췌 (add-framework 스킬 §3)** — 새 스킴 이름을 아래 전부에 넣는다. 하나라도 빠지면 CI 가 감지만 하고 실행하지 않는다.
- `pr_test.yml` 세 곳: `ALL_SCHEMES`(+`ALL_PRESENTATION`), detect-changes 의 경로→스킴 매핑, test job 의 `Test <Scheme>` 실행 step
- `run-all-tests.sh` 의 `ALL_SCHEMES` 배열
- `impact-check.sh` 의 `ALL_SCHEMES`/`ALL_PRESENTATION` 상수 + 경로→스킴 매핑 + **이 모듈에 의존하는 상위 레이어 블록에 파급 추가**(`CalendarScenes`·`TodoCalendarApp`·`TodoCalendarAppWidget`) + `impact-check.test.sh` 의 배열·assertion
- `run-tests` 스킬의 스킴 목록과 개수 문구

**엣지 케이스** — `impact-check.test.sh` 에는 develop 시점부터 실패하는 assertion 이 하나 있다(`Services/FirstPartyServices → App`). 이번 변경과 무관하므로 손대지 않고, 통과 개수만 늘어나는지 확인한다.

- [ ] Step 1: `Project.swift`·`.h`·디렉토리를 만든다
- [ ] Step 2: `Workspace.swift` 의 projects 배열과 `TodoCalendarApp/Project.swift` 의 dependencies 에 등록한다
- [ ] Step 3: 스킴 하드코딩 다섯 곳을 갱신한다
- [ ] Step 4: `mise exec -- tuist generate --no-open` 을 돌리고 새 스킴이 잡히는지 확인한다
- [ ] Step 5: 부록 B 커밋 1

### Task 2: MonthViewModel.swift 에서 표시 모델 분리

**Files**
- Create: `Presentations/CalendarScenes/Sources/Month/MonthDisplayModels.swift`
- Modify: `Presentations/CalendarScenes/Sources/Month/MonthViewModel.swift`

**Interfaces**
- Consumes: 없음
- Produces: 같은 모듈 안에서 파일만 갈린 표시 모델 5종. 접근 제어와 시그니처는 그대로다.

**옮길 것** — `MonthViewModel.swift:19~158` 의 `WeekDayModel`·`DayCellViewModel`·`WeekRowModel`·`EventMoreModel`·`WeekEventStackViewModel` 과 `extension WeekEventStackViewModel`(:138). `MonthViewModel` 프로토콜(:161) 이후는 원래 파일에 남긴다.

**엣지 케이스** — `WeekEventStackViewModel.init` 이 `HolidayCalendarEvent`(:133) 를 참조한다. 같은 모듈 안이라 이 단계에선 import 추가가 필요 없다.

**파일 헤더** — file-conventions §1 의 최신형 템플릿을 쓰고 타겟명은 `CalendarScenes` 로 적는다. import 순서는 §2 를 따른다.

- [ ] Step 1: 표시 모델 5종과 extension 을 새 파일로 옮긴다
- [ ] Step 2: `CalendarScenes` 스킴을 돌려 통과를 확인한다
- [ ] Step 3: 부록 B 커밋 2

### Task 3: 5파일을 CalendarPresentation 으로 이동

**Files**
- Create: `Presentations/CalendarPresentation/Sources/CalendarEvents/CalendarEvent.swift`, `.../Sources/EventListCell/EventCellViewModel.swift`, `.../Sources/EventListCell/EventCellViewModelMapper.swift`, `.../Sources/Month/MonthDisplayModels.swift`, `.../Sources/Month/WeekEventStackBuilder.swift`
- Delete: 위 다섯의 `CalendarScenes` 쪽 원본
- Modify: `Presentations/CalendarScenes/Project.swift`(의존에 `CalendarPresentation` 추가), `CalendarScenes` 소비처 15파일, 스냅샷 3파일

**Interfaces**
- Consumes: T-1 이 세운 모듈, T-2 가 분리한 `MonthDisplayModels.swift`
- Produces: `CalendarPresentation` 의 public 표면 — `CalendarEvent` 계열 7종, `EventCellViewModel` 계열 13종, Month 표시 모델 5종, `WeekEventStack` 계열 3종, `EventCellViewModelMapper`

**import 를 더해야 하는 `CalendarScenes` 소비처** — `Month/MonthView.swift`, `Month/MonthViewModel.swift`, `Month/MonthScene+Builder.swift`, `CalendarPaper/CalendarPaperViewModel.swift`, `CalendarPaper/ForemostEventView.swift`, `CalendarPaper/UncompletedTodoView.swift`, `Common/CalendarEvents/CalendarEventListhUsecase.swift`, `Common/EventListCell/EventListCellView.swift`, `Common/EventListCell/EventListCellEventHanleViewModel.swift`, `DayEventList/DayEventListView.swift`, `DayEventList/DayEventListViewModel.swift`, `DayEventList/DayEventListScene+Builder.swift`, `SharePreview/ShareImageCardView.swift`, `SharePreview/ShareImageContentModel.swift`, `SharePreview/SharePreviewLineModel.swift`, `SharePreview/SharePreviewViewModel.swift`. 스냅샷 쪽은 `CalendarScenesSnapshots.swift`, `CalendarScenesCatalogSnapshots.swift`, `SharePreviewSnapshots.swift` 다.

**접근 제어 승격 — 실측으로 확정된 넷**

| 선언 | 위치 | 승격 이유 (소비처) |
|---|---|---|
| `PendingTodoEventCellViewModel` 과 그 `init` | `EventCellViewModel.swift:294`·`:307` | `DayEventListView.swift:806`, `DayEventListViewModel.swift:136`·`:176`·`:196`·`:416` |
| `EventCellViewModelMapper` 와 그 프로퍼티·메서드·생성자 | `EventCellViewModelMapper.swift:12` | `ShareImageContentModel.swift:201`, `DayEventListViewModel.swift:469` |
| `EventListMoreActionModel.basicActions`·`.removeActions` 와 memberwise 생성자 | `EventCellViewModel.swift:160`~`:161` | `EventListCellView.swift:103`·`:107`·`:111` |
| `EventOnWeek.eventStartDayIdentifierOnWeek` | `WeekEventStackBuilder.swift:29` | `MonthView.swift:441` |

이 넷 외에 컴파일러가 더 가리키면 그 선언만 승격하고 종결보고에 목록으로 싣는다. 미리 열지 않는다.

**엣지 케이스**
- public struct 의 memberwise 생성자는 자동으로 public 이 되지 않는다. 모듈 밖에서 생성하는 타입은 명시 `public init` 이 필요하다.
- `extension Array where Element == any CalendarEvent`(:67)·`extension CalendarEvent`(:83)·`extension Publisher`(:308) 의 멤버는 이미 public 이라 그대로 옮기면 된다.
- 파일 헤더의 타겟명 줄을 `CalendarPresentation` 으로 고친다 (file-conventions §1).

- [ ] Step 1: 5파일을 새 모듈로 옮기고 헤더 타겟명을 고친다
- [ ] Step 2: `CalendarScenes/Project.swift` 의존에 `CalendarPresentation` 을 넣는다
- [ ] Step 3: `mise exec -- tuist generate --no-open`
- [ ] Step 4: 소비처 15파일과 스냅샷 3파일에 `import CalendarPresentation` 을 넣고, 컴파일 에러가 가리키는 선언을 승격한다
- [ ] Step 5: 두 스킴(`CalendarPresentation`·`CalendarScenes`)을 돌리고 스냅샷을 대조한다
- [ ] Step 6: 부록 B 커밋 3

### Task 4: 테스트 4종 이동

**Files**
- Create: `Presentations/CalendarPresentation/Tests/CalendarEvents/CalendarEventTests.swift`, `.../Tests/EventListCell/EventCellViewModelTests.swift`, `.../Tests/EventListCell/EventCellViewModelMapperTests.swift`, `.../Tests/Month/WeekEventStackBuilderTests.swift`
- Delete: `Presentations/CalendarScenes/Tests/Common/CalendarEventTests.swift`, `.../Tests/Common/EventCellViewModelTests.swift`, `.../Tests/Common/EventCellViewModelMapperTests.swift`, `.../Tests/Month/WeekEventStackBuilderTests.swift`

**Interfaces**
- Consumes: T-3 이 옮긴 타입들
- Produces: `CalendarPresentationTests` 타겟의 테스트 케이스

**적용 rules 발췌 (testability §8)** — 테스트 소스는 각 프레임워크의 `Tests/` 밑에 두고, `Tests/` 는 `Sources/` 의 폴더 구조를 미러링한다. 그래서 위 경로가 `Sources/` 구조를 그대로 따른다.

**엣지 케이스**
- `@testable import CalendarScenes` 를 `@testable import CalendarPresentation` 으로 바꾼다. 옮긴 타입이 전부 public 이라 `@testable` 없이도 되지만, 원본 파일의 표기를 그대로 유지해 diff 를 이동으로 읽히게 한다.
- `MonthViewModelImpleTests.swift` 는 `MonthViewModelImple` 의 테스트라 `CalendarScenes` 에 남는다. 표시 모델을 생성하는 부분이 있으면 `import CalendarPresentation` 만 더한다.
- 테스트 타겟의 `UnitTestHelpKit`·`TestDoubles` 의존은 `frameworkWithTest` 팩토리가 자동 주입한다. `Project.swift` 에 손으로 쓰지 않는다.

- [ ] Step 1: 테스트 4파일을 옮기고 import 와 헤더 타겟명을 고친다
- [ ] Step 2: `CalendarPresentation`·`CalendarScenes` 두 스킴을 돌린다
- [ ] Step 3: 부록 B 커밋 3 에 함께 담는다

### Task 5: 위젯 확장의 CalendarScenes 의존 제거

**Files**
- Modify: 위젯 확장 소스 36파일과 테스트 9파일의 import 줄, `TodoCalendarApp/Project.swift` 의 위젯 확장 타겟 dependencies

**Interfaces**
- Consumes: T-3 이 만든 `CalendarPresentation` public 표면
- Produces: `CalendarScenes` 를 물지 않는 위젯 확장

**치환 규칙** — `import CalendarScenes` 를 `import CalendarPresentation` 으로 바꾼다. 확장이 `CalendarScenes` 에서 쓰던 심볼 23개가 전부 새 모듈로 갔으므로 한 줄 치환으로 끝난다. 파일 목록은 `grep -rl 'import CalendarScenes' TodoCalendarApp/AppExtensions/Widget` 로 뽑는다.

**엣지 케이스**
- `WidgetLink+Extensions.swift` 는 `extension EventCellViewModel` 을 확장 쪽에서 선언한다. 프로토콜이 새 모듈로 갔어도 확장 선언 자체는 확장에 남는다.
- 확장 타겟이 이미 `WidgetScenes` 를 문다(DP-1.1). 거기에 `CalendarPresentation` 을 더하고 `CalendarScenes` 를 뺀다.
- 치환 후 `grep -rn 'CalendarScenes' TodoCalendarApp/AppExtensions/Widget` 의 출력이 비어야 한다. 안 비면 FFIR-2 다.

- [ ] Step 1: 45파일의 import 를 치환한다
- [ ] Step 2: `TodoCalendarApp/Project.swift` 의 확장 타겟 의존을 교체하고 `tuist generate` 를 돌린다
- [ ] Step 3: `TodoCalendarAppWidget`·`TodoCalendarApp` 스킴을 돌린다
- [ ] Step 4: `grep` 으로 잔여 참조가 0 인지 확인한다
- [ ] Step 5: 부록 B 커밋 4

## 부록 B. 커밋 시퀀스

| 커밋 | 대응 태스크 | 메시지 초안 |
|---|---|---|
| 1 | T-1 | `[#1060] CalendarPresentation 프레임워크를 신설하고 스킴 배선을 잇는다` |
| 2 | T-2 | `[#1060] Month 표시 모델 5종을 MonthViewModel 에서 떼어 별도 파일로 가른다` |
| 3 | T-3 + T-4 | `[#1060] 표시·이벤트 모델 5파일과 그 테스트를 CalendarPresentation 으로 내린다` |
| 4 | T-5 | `[#1060] 위젯 확장이 CalendarScenes 대신 CalendarPresentation 을 물게 한다` |

## 부록 C. 모델 티어

| 태스크 | 티어 | 근거 |
|---|---|---|
| T-1 | 표준 | 매니페스트는 기계적이지만 스킴 하드코딩 다섯 곳의 파급 매핑에 판단이 든다 |
| T-2 | 하위 | 같은 모듈 안에서 줄 범위를 옮기는 기계적 분리다 |
| T-3 | 표준 | 접근 제어 승격 판정과 소비처 15파일 조율이 든다 |
| T-4 | 하위 | 경로와 import 만 바뀌는 이동이다 |
| T-5 | 하위 | 45파일 한 줄 치환이다 |

이번 작업은 인라인으로 실행한다. 병렬 슬롯을 두지 않으므로 티어 표는 dispatch 로 전환할 때의 기준이다.

## 부록 D. 단편명령

없음.
