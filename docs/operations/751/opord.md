# 작업 지침 (Operation Order) — DP-3.1 타임라인 위젯

> 용어 — DP: 결정적 지점(작업 지침 하나 = PR 하나) · LOE: 노력선(최종상태 한 관점을 담당하는 줄기) · FRAGO: 단편명령 · MOP / MOE: 과업 수행 여부 / 효과 발생 여부 · PIR / FFIR: 즉시보고 조건 중 환경·외부 정보 / 아군·내부 정보

```
작업 지침 — #751 타임라인 위젯       초안: 에이전트   재가: 유저   일자: 2026-09-09
상위: campaign.md #721 / LOE-2 / 3단계 / DP-3.1 / 선행 DP: DP-2.2 (머지 완료 — develop 2e30f9fe)
```

■ **확인보고**

**임무 (내 말로)** — 오늘 남은 시간을 세로 축으로 그리고 그 위에 일정을 블록으로 얹는 위젯을 홈 medium·large 에 띄운다. 축·블록·겹침 계산은 `WidgetScenes` 에 두어 테스트로 덮고, 확장엔 등록과 조회만 남긴다. 곁들여 셀 VM 매핑 중복 3곳을 걷는다.

**의도** — 라인업에 비어 있던 "하루가 어떻게 채워져 있는지" 축을 채워 DP-5.x 가 꾸밀 대상을 마저 만든다. 최종상태는 홈에 놓인 타임라인 위젯, `WidgetScenes` 안의 순수 뷰와 `.sample`, 스냅샷 기존 20장 무변화 + 신규 2장, 코드베이스의 셀 VM 매핑 중복 0 이다.

**자율로 정할 것** — 겹침 열 수 상한과 넘칠 때의 표현, 눈금 열의 라벨 간격, 종일 칩 띠의 잘림 처리, 커밋 시퀀스 조정.

**묻는 것** — 없음. Task 0-A 범위(확장 provider 3곳)는 2026-09-09 에 이미 재가받아 계획 7항에 반영했다.

## 1. 상황

### 가. 정찰 결과

**2026-08-03 정찰 브리프(#751 코멘트)가 여전히 정본이다.** 확정된 결정 7건(패밀리 medium·large / 축 현재~자정 / 짧으면 연장 / 종일은 상단 띠 / `EventTypeSelectIntent` 재사용 / 블록 딥링크 / `Date.nextUpdateTime` 관례)은 그대로 살아 있다. 아래는 DP-1.1·DP-2.1·DP-2.2 가 그 뒤로 바꿔놓은 것만이다.

**무효가 된 것 셋**

- **뷰 배치** — 순수 뷰는 확장이 아니라 `Presentations/WidgetScenes` 에 만든다 (campaign C1). 브리프의 "신규 3파일(View·TimelineProvider·ViewModelProvider)" 이 프레임워크 3파일 + 확장 3파일로 갈린다.
- **"위젯 뷰는 스냅샷 스위트가 없어 실기 확인 대상"** — 지금은 `TodoCalendarApp/AppExtensions/Widget/Snapshots/WidgetCatalogSnapshots.swift` 에 12 케이스가 있다. 타임라인 뷰도 스냅샷으로 덮인다.
- **딥링크 조립 위치** — `WidgetLink+Extensions.swift:14` 가 아니라 `Domain/Sources/Utils/EventDeepLink.swift` 의 `EventDeepLinkBuilder` 이고, 표시 모델에서 URL 을 뽑는 어댑터는 `Presentations/CalendarPresentation/Sources/DeepLink/EventCellViewModel+WidgetURL.swift` 다 (DP-2.2).

**전제가 반쯤 무너진 것 하나 — 브리프 플랜의 Task 0-A**

플랜은 이벤트 종류별 셀 VM 변환 switch 를 새로 추출한다고 했는데, DP-2.1 이 그걸 `Presentations/CalendarPresentation/Sources/EventListCell/EventCellViewModelMapper.swift:24` 의 `cellViewModel(from:)` 으로 이미 내려놨다. **추출할 게 아니라 소비하면 된다.** 다만 확장 provider 3곳에 같은 switch 가 그대로 남아 있다:

- `Widget/Sources/Widgets/EventListWidget/EventListWidgetViewModelProvider.swift:64`
- `Widget/Sources/Widgets/TodayAndNext/TodayAndNextWidgetViewModel+Provider.swift:124`
- `Widget/Sources/Widgets/NextEventWidget/NextEventWidgetViewModelProvider.swift:63`

셋은 원래 DP-3.1 소유 범위 밖이었고, 2026-09-09 유저 결심으로 범위에 들어왔다 (campaign 7항, `0d9c21a4`).

**모듈 경계 — 무엇이 어디서 보이나**

- `any CalendarEvent` 는 `Presentations/CalendarPresentation/Sources/CalendarEvents/CalendarEvent.swift:56` 에 있고 `eventTime: EventTime?` 를 노출한다. **`WidgetScenes` 에서 보인다** — 축·블록 산출이 프레임워크에서 돌 수 있는 근거다.
- `CalendarEvents`(복수형 컨테이너)는 `Widget/Sources/Usecases/CalendarEventFetchUsecase.swift:21` 의 internal struct 라 **확장 밖에서 안 보인다.** DP-2.2 에서 `EventListWidgetViewModel.SectionModel.Builder` 가 확장에 남은 이유와 같다.
- 그래서 분할 선은 **"조회 결과를 푸는 데까지가 확장, 푼 이벤트 배열로 좌표를 만드는 것부터가 프레임워크"** 다.

**동형 선례 file:line**

| 참고할 것 | 위치 |
|---|---|
| 확장 위젯 기본형 (엔트리 뷰 + `Widget` 선언) | `Widget/Sources/Widgets/DDayWidget/DDayWidget.swift:19`·`:79` |
| `EventTypeSelectIntent` 를 무는 타임라인 프로바이더 | `Widget/Sources/Widgets/EventListWidget/EventListWidgetTimeLineProvider.swift:20` |
| `EventTagId(_ entity:)` 변환 | 같은 파일 `:85` |
| 빌더 make 메서드 서식 | `Widget/Sources/Base+Factory/WidgetViewModelProviderBuilder.swift` 의 `makeEventListViewModelProvider` |
| 표시 모델이 색 재료를 싣는 형태 | `WidgetScenes/Sources/EventList/EventListWidgetViewModel.swift:68-73` |
| 뽑아낼 색 해석 원본 | `WidgetScenes/Sources/EventList/EventListWidgetViews.swift:137-165` |
| `.sample` 관례 | `WidgetScenes/Sources/EventList/EventListWidgetViewModel.swift:94` |
| 스냅샷 케이스 서식 | `Widget/Snapshots/WidgetCatalogSnapshots.swift:45`(`capture`)·`:78` |
| 위젯 이름 로케일 키 | `Supports/Extensions/Resources/en.lproj/Localizable.strings:544-549` |
| 셀 VM 매퍼 | `CalendarPresentation/Sources/EventListCell/EventCellViewModelMapper.swift:24`·`:45` |

### 나. 장애·마찰

- **유력한 양상** — 겹침 열 분할이 "몇 개까지 나눌 것인가" 에서 막힌다. medium 폭에 열을 넷 이상 두면 블록이 글자를 못 담는다. 열 수 상한과 넘칠 때의 표현을 정하지 않으면 뷰에서 즉흥 판단이 들어간다.
- **가장 위험한 양상** — 축 산출·블록 매핑을 확장 provider 에 두는 옛 플랜대로 가는 것. 그러면 계산이 확장에 갇혀 `WidgetScenes` 테스트 스킴에서 못 돌고, `.sample` 을 조립할 수 없어 C6 등재도 못 한다. DP-4.1 이 병행 중이라 그때 가서 되돌리는 비용이 크다.

### 다. 상위 인용

- **최종상태 관련 관점** (campaign 2항·5항 3단계) — "타임라인 위젯이 홈 medium·large 에 그려지고, 그 순수 뷰가 `WidgetScenes` 에 있다."
- **노력선 중간 목표** — LOE-2 라인업. "꾸밀 대상을 마저 채운다." MOE 는 "신규 위젯이 홈에 실제로 놓이고 갱신되나" 다.
- **인접 DP 관계** — DP-4.1(갤러리, #1069)이 `orthodox` 에서 병행 중이다. 접점은 C6 등재 하나이고, **내가 `.sample` 을 내면 DP-4.1 이 머지 후 rebase 해서 한 줄 얹는다.** 머지 순서는 내가 먼저다.
- **인터페이스 계약** — C1(무엇을 어디에), C2(배경은 순수 뷰 바깥), C6(`.sample` 을 낸다). 원문은 campaign.md 6항.

### 라. 가정

| ID | 가정 | 출처 | 깨지면 |
|---|---|---|---|
| G1 | 축·블록·겹침 산출이 `any CalendarEvent` 배열만으로 된다. `CalendarEvents` 컨테이너가 필요 없다 | 신규 — `CalendarEvent.swift:56` 이 `eventTime` 을 노출하는 것을 확인 | 산출을 확장 provider 로 되돌리고 `.sample` 은 손으로 조립한다. C6 등재는 살지만 계산이 테스트 밖으로 나가므로 즉시보고 |
| G2 | 색 해석을 뷰에서 떼어내도 EventList 위젯 픽셀이 안 바뀐다 | 신규 — `EventListWidgetViews.swift:137-165` 는 순수 함수다 | 스냅샷 바이트 비교가 잡는다. 다르면 추출을 되돌리고 타임라인만 자기 색 해석을 갖는다 |
| G3 | 확장 provider 3곳의 switch 가 `EventCellViewModelMapper.cellViewModel(from:)` 과 같은 결과를 낸다 | 신규 — 미확인. T-2 에서 코드 대조로 확정한다 | 다른 케이스가 있으면 그 provider 만 교체 대상에서 빼고 사유를 종결보고에 적는다 |
| G4 | A5 상속 — 브리프의 축·겹침 규칙이 지금 develop 에서 유효하다 | campaign 8항 A5 상속 | 뷰 배치 부분은 이미 무효로 판정했다. 축·겹침까지 안 맞으면 FFIR |
| G5 | 스냅샷 카탈로그에 케이스를 더해도 기존 20장이 안 바뀐다 | campaign 8항 A1 상속 (DP-1.1·DP-2.1·DP-2.2 에서 3회 확인) | 바이트 비교가 잡는다. FFIR |

### 마. 인접 작업

| 무엇 | 어디 | 겹침 |
|---|---|---|
| DP-4.1 갤러리 (#1069) | `orthodox` 워크트리, `features/1069-widget-gallery`, base develop | `Supports/Extensions/Resources/*.lproj/Localizable.strings` 31개. 내 신규 키는 `widget.timeline::name` 1개, 상대는 갤러리 화면 문구 몇 개. 각자 자기 키만 더한다 |
| 같은 DP-4.1 | 같음 | `WidgetScenes/Sources/{Composed,AICommand}/` 를 상대가 만진다. 나는 `Sources/{Timeline,Common,EventList}/` 다 — 파일이 안 겹친다 |

내가 만지는 확장 provider 3파일은 DP-4.1 소유 범위 밖이라고 상대에게 통보했다.

## 2. 임무

이 작업은 **타임라인 위젯이 홈 medium·large 에 놓여 오늘 남은 시간과 그 위의 일정을 그릴 때까지** 축·블록·겹침 산출을 `WidgetScenes` 에 세우고 순수 뷰와 확장 배선을 만들어, **LOE-2 가 "꾸밀 대상을 마저 채운다"는 중간 목표에 닿게 한다.**

## 3. 실시

### 가. 의도

**목적** — 위젯 라인업에 비어 있던 "하루가 어떻게 채워져 있는지" 축을 채운다. 기존 위젯 20종은 표현이 전부 목록·그리드다.

**핵심과업 (성립 조건)**

1. 축·블록·겹침 산출이 `WidgetScenes` 안에 있고 유닛 테스트로 덮인다 — 뷰에 시간 계산이 없다.
2. 순수 뷰가 `WidgetScenes` 에 있고 WidgetKit 을 안 문다 (C1).
3. `TimelineWidgetViewModel.sample` 이 있어 DP-4.1 이 한 줄로 등재할 수 있다 (C6).
4. 확장에 `Widget` 선언과 엔트리 뷰만 남고, 홈 medium·large 에 실제로 놓인다.
5. 셀 VM 매핑 중복이 코드베이스에서 사라진다.

**최종상태**

- *동작* — 홈에 medium·large 로 놓으면 현재 시각부터 자정까지가 세로 축으로 그려지고 그 위에 일정이 블록으로 얹힌다. 겹치는 일정은 열로 갈린다. 종일·공휴일은 축 위 상단 띠다. 태그 필터로 대상을 고르고, 블록을 탭하면 이벤트 상세로 간다. 남은 시간이 4시간 미만이면 축이 12시간으로 늘어난다.
- *코드* — `WidgetScenes/Sources/Timeline/` 3파일 + `Common/EventColorPalette.swift`, 확장 `Widgets/TimelineWidget/` 3파일.
- *구조* — `WidgetScenes` 의 WidgetKit·`CalendarScenes`·`Scenes` import 0건 유지.
- *검증* — `WidgetScenes` 스킴 신규 TC 전건 통과, `TodoCalendarAppWidget` 스킴 회귀 통과, 스냅샷 카탈로그 기존 20장 바이트 동일 + 신규 2장.
- *외부* — 실기에서 홈에 배치해 갱신을 확인한다 (유저 검증 인계).

### 나. 개념

**결정적 행동** — 축·블록·겹침 산출을 `[any CalendarEvent]` 만 받는 순수 계산으로 만들어 `WidgetScenes` 에 두는 것. 이 하나가 서면 테스트·`.sample`·갤러리 등재가 전부 따라온다.

**여건 조성** — 색 해석을 뷰에서 떼어내 두 위젯이 같은 코드를 부르게 한다(T-1). 셀 VM 매핑을 매퍼 소비로 통일해 신규 provider 가 네 번째 중복을 만들지 않게 한다(T-2).

**대안 경로 + 전환 조건** — G1 이 깨져 `CalendarEvents` 없이는 산출이 안 되면, 산출을 확장 provider 로 되돌리고 `.sample` 은 손으로 조립한 리터럴로 만든다. 전환 조건은 "T-3 착수 시점에 `any CalendarEvent` 만으로 축·블록이 안 서는 것" 이고, 그때는 즉시보고 후 진행한다.

**단계 (상태 조건)**

1. 여건 — 색 해석이 공용 타입이 됐고 셀 VM 매핑 중복이 0 이다.
2. 산출 — 축·블록·겹침이 `WidgetScenes` 에서 테스트로 덮였다.
3. 표현 — 순수 뷰와 `.sample` 이 있고 스냅샷이 찍힌다.
4. 배선 — 확장에 등록돼 홈에 놓인다.

### 다. 과업

- **T-1**: 색 해석을 `EventColorPalette` 로 뽑아 EventList 뷰가 그걸 부르게 하여, 타임라인이 같은 규칙을 재사용할 자리를 만든다.
- **T-2**: 확장 provider 3곳을 `EventCellViewModelMapper` 소비로 교체하여, 셀 VM 매핑 중복을 없앤다.
- **T-3**: 축 산출을 `TimelineLayoutBuilder` 에 세우고 `TimelineWidgetViewModel` 을 정의하여, 시간 범위 판정을 테스트로 고정한다.
- **T-4**: 블록 매핑과 겹침 열 분할을 같은 빌더에 얹어, 좌표 산출을 완성한다.
- **T-5**: 순수 뷰와 `.sample` 을 만들고 스냅샷 2장을 찍어, 표현을 확정하고 C6 등재 입력을 낸다.
- **T-6**: 확장 3파일·빌더 make 메서드·번들 등록·로케일 키를 배선하여, 홈에 놓이게 한다.

### 라. 협조지시

**개시 조건** — DP-2.2 머지 완료(`2e30f9fe`), 작전계획 재가, 소유 범위 확보. 셋 다 충족.

**인터페이스 계약 (상속)** — campaign C1·C2·C6. 추가 없음.

**제한**

- `CalendarEventFetchUsecase`·`EventTypeSelectIntent`·`EventDeepLinkBuilder`·`Date.nextUpdateTime` 의 **동작**을 안 바꾼다 (campaign 13항). import 경로 조정과 호출은 예외.
- 기존 위젯 20종의 모양·동작을 안 바꾼다. T-1·T-2 는 동작 보존 교체다 — 스냅샷 바이트 동일과 기존 provider 테스트가 그 증거다.
- `WidgetScenes` 의존 목록에 모듈을 더하지 않는다. WidgetKit·`CalendarScenes`·`Scenes` 를 안 문다 (C1).
- 잠금화면 패밀리·small 을 지원하지 않는다. 시간 축에 세로 공간이 필요하다.
- Pro 게이팅·paywall 을 안 건드린다 (campaign 13항).

**위임 범위 (좁히는 것만)** — campaign 12항 상속. 순수 뷰 내부 구현은 자율이나, **겹침 열 수 상한과 넘칠 때의 표현**은 자율로 정하되 종결보고에 결정과 근거를 적는다.

**수용 위험** — 겹침이 많은 날의 medium 가독성. 열 수 상한으로 자르고 넘치는 것은 표시하지 않는다. 실기 확인에서 유저가 판단한다.

**즉시보고 조건**

- **FFIR-1** — 축·블록 산출이 `any CalendarEvent` 만으로 안 선다 (G1 붕괴) → D-1
- **FFIR-2** — 색 해석 추출 후 EventList 스냅샷이 달라진다 (G2 붕괴) → D-2
- **FFIR-3** — 확장 provider 3곳의 switch 가 매퍼와 결과가 다르다 (G3 붕괴) → D-3
- **FFIR-4** — 순수 뷰가 WidgetKit 없이 안 그려진다 (C1 붕괴, campaign 14항 상속) → 중단
- **FFIR-5** — 이관·추출 전후 스냅샷 20장이 달라진다 (A1 붕괴, campaign 14항 상속) → 중단
- **PIR-1** — 확장 바이너리·메모리가 한도에 걸릴 낌새 (A7, campaign 14항 상속) → 보고 후 계속

**결정지점**

| ID | 결정 | 판단 정보 | 시한(조건) | 미결 시 기본 행동 |
|---|---|---|---|---|
| D-1 | 산출을 확장으로 되돌릴지 | `any CalendarEvent` 가 축·블록에 충분한가 | T-3 착수 시점 | 되돌리고 `.sample` 은 리터럴 조립. 계속 진행 |
| D-2 | 색 해석 추출을 유지할지 | 스냅샷 바이트 비교 결과 | T-1 완료 시점 | 추출을 되돌리고 타임라인만 자기 해석을 갖는다 |
| D-3 | provider 3곳 중 몇을 교체할지 | 각 switch 와 매퍼의 케이스 대조 | T-2 착수 시점 | 결과가 같은 것만 교체하고 나머지는 사유를 적고 남긴다 |

**우발계획**

| 조건 | 행동 | 결심자 | 상향 |
|---|---|---|---|
| 겹침 열이 medium 에서 글자를 못 담는다 | 열 수 상한을 두고 넘치는 블록은 표시하지 않는다 | 실행자 | 상한이 2 이하로 내려가면 유저 |
| PR 이 리뷰 단위를 넘긴다 | 부록 B 커밋 시퀀스로 나눈 상태를 유지하고 그대로 낸다 | 실행자 | 커밋 5개로도 안 나뉘면 DP 분할 계획 개정 |
| DP-4.1 이 먼저 머지 준비된다 | 순서는 그대로 — 내가 먼저 머지한다 (C5) | 컨트롤러 | 유저 |

## 4. 검증·자원

**테스트 스킴·검증 사다리** — 최소부터 올린다.

1. 개별 TC — `xcodebuild test -only-testing:WidgetScenesTests/<클래스>/<메서드>`
2. 파일 — `-only-testing:WidgetScenesTests/<클래스>`
3. 모듈 스킴 — `WidgetScenes`
4. 연결 스킴 — `TodoCalendarAppWidget`(확장 provider 회귀), `CalendarPresentation`(매퍼 소비처 변화 시). `impact-check.sh --base origin/develop` 산출을 상한으로 본다.

**스냅샷** — `TodoCalendarAppWidgetSnapshots` 스킴. `withSnapshotTesting(record: .all)` 이라 **스위트 통과는 동일의 증거가 아니다** (campaign 8항 A1). 착수 전에 develop 기준선 20장을 떠 두고, T-5 이후 바이트 비교한다. 산출 경로는 `snapshot-catalog/<모듈>/<스위트>/`.

**실기** — 홈 medium·large 배치와 갱신 확인. Claude 가 못 하므로 유저에게 인계한다 (implement §완료 판정 4).

**모델 티어·워크트리** — 부록 C. 인라인 실행이고 워크트리는 `southpaw`, 브랜치는 `features/751-timeline-widget`. 병렬 슬롯은 DP-4.1 이 `orthodox` 에서 쓰고 있다.

**외부 자원** — 없음. 심사·계정에 안 걸린다.

## 5. 보고

- **즉시** — 위 FFIR·PIR, 가정 붕괴, rules 갭. 봇 코멘트로 이슈에 게시하고 `@sudopark` 멘션.
- **정기** — 단계 전환(4개)과 태스크 완료마다 진행 파일 갱신 + 이슈 본문 미러 재조립.
- **유저 부재 시** — 의도 안이면 기본 행동으로 계속한다. FFIR-4·FFIR-5 는 중단한다.
- **종결 조건** — PR 생성 시 종결보고. 실기 확인은 PR 본문에 인계 항목으로 싣는다.

---

## 부록 A. 태스크 상세

### Task 1: 색 해석을 EventColorPalette 로 뽑는다

**Files**
- Create: `Presentations/WidgetScenes/Sources/Common/EventColorPalette.swift`
- Modify: `Presentations/WidgetScenes/Sources/EventList/EventListWidgetViews.swift`
- Test: `Presentations/WidgetScenes/Tests/Common/EventColorPaletteTests.swift`

**Interfaces**
- Produces: `EventColorPalette` — T-4·T-5 가 소비한다.

```swift
public struct EventColorPalette: Sendable {
    private let defaultSetting: DefaultEventTagColorSetting
    private let customTagMap: [String: any EventTag]
    private let googleColors: GoogleCalendar.Colors
    private let googleTags: [String: GoogleCalendar.Tag]
    private let appleTags: [String: AppleCalendar.Tag]

    public init(
        defaultSetting: DefaultEventTagColorSetting,
        customTagMap: [String: any EventTag],
        googleColors: GoogleCalendar.Colors,
        googleTags: [String: GoogleCalendar.Tag],
        appleTags: [String: AppleCalendar.Tag]
    )

    public func color(for source: any EventTagColorSource) -> UIColor
}
```

원본은 `EventListWidgetViews.swift:137-165` 의 `tagLineView` 안 클로저다. **판정 순서를 그대로 옮긴다** — 구글 → 애플 → `EventTagId`(holiday / default / custom) → 폴백. 폴백은 전부 `EventTagColorSet(defaultSetting).defaultColor` 다.

`static func` 를 쓰지 않는다 (CLAUDE.md §1). 설정값을 담은 struct 의 인스턴스 메서드로 둔다 — `EventCellViewModelMapper.swift:12` 가 같은 모양이다.

**엣지 케이스**
- `colorHex` 가 파싱 안 되는 값 → `defaultColor` 로 떨어진다 (`UIColor.from(hex:)` 가 nil).
- `customTagMap` 에 없는 custom id → `defaultColor`.
- `colorSource` 가 셋 중 어디에도 안 맞는 타입 → `defaultColor`.

**테스트 케이스 이름**
- `testPalette_whenSourceIsGoogle_resolveByAppearance`
- `testPalette_whenSourceIsApple_resolveByCalendarTagHex`
- `testPalette_whenSourceIsAppleAndHexUnparsable_fallbackToDefault`
- `testPalette_whenSourceIsHolidayTag_resolveHolidayColor`
- `testPalette_whenSourceIsCustomTag_resolveCustomHex`
- `testPalette_whenCustomTagNotFound_fallbackToDefault`

**Steps**
- [ ] Step 1 — `EventColorPaletteTests` 를 먼저 쓰고 RED 를 확인한다
- [ ] Step 2 — `EventColorPalette` 를 만들어 GREEN
- [ ] Step 3 — `EventListWidgetViews.tagLineView` 가 팔레트를 부르게 바꾼다. `EventListWidgetViewModel` 이 이미 재료 5종을 다 갖고 있으므로 뷰에서 조립한다
- [ ] Step 4 — 스냅샷 카탈로그를 돌려 EventList 관련 장이 기준선과 바이트 동일한지 확인한다 (D-2)
- [ ] Step 5 — 커밋 1 (부록 B)

### Task 2: 확장 provider 3곳을 매퍼 소비로 교체한다

**Files**
- Modify: `TodoCalendarApp/AppExtensions/Widget/Sources/Widgets/EventListWidget/EventListWidgetViewModelProvider.swift`
- Modify: `TodoCalendarApp/AppExtensions/Widget/Sources/Widgets/TodayAndNext/TodayAndNextWidgetViewModel+Provider.swift`
- Modify: `TodoCalendarApp/AppExtensions/Widget/Sources/Widgets/NextEventWidget/NextEventWidgetViewModelProvider.swift`
- Test: 기존 `Widget/Tests/ViewModelProviders/` 가 그물. 신규 TC 없음

**Interfaces**
- Consumes: `EventCellViewModelMapper(range:timeZone:is24hourForm:)` · `cellViewModel(from:)` · `cellViewModels(from:)`

**착수 전 대조 (D-3)** — 세 switch 를 `EventCellViewModelMapper.swift:24-44` 와 한 줄씩 맞춰본다. 확인할 것은 (a) 다루는 케이스 집합이 같은가 (todo·schedule·holiday·google·apple + default nil), (b) 각 케이스가 넘기는 인자가 같은가 (`in: dayRange`, `timeZone`, `is24Form`), (c) `default` 폴백이 같은가. 하나라도 다르면 그 provider 는 교체 대상에서 빼고 사유를 적는다.

**엣지 케이스**
- `NextEventWidgetViewModelProvider:63` 은 단건 변환이라 `cellViewModel(from:)` 을 쓰고, 나머지 둘은 배열이라 `cellViewModels(from:)` 을 쓴다. 후자는 `compactMap` 이 매퍼 안으로 들어가므로 nil 제거 동작이 같은지 본다.
- 각 provider 가 쓰는 `range` 가 다르다 — EventList 는 하루 단위 `dayRange`, TodayAndNext·NextEvent 는 오늘 범위다. 매퍼를 **호출 자리마다 그 range 로 새로 만든다.** 하나를 재사용하면 `periodText` 가 틀어진다.

**Steps**
- [ ] Step 1 — 세 switch 와 매퍼를 대조하고 결과를 한 줄씩 적는다 (D-3)
- [ ] Step 2 — 교체하고 기존 provider 테스트를 돌린다 (`TodoCalendarAppWidget` 스킴)
- [ ] Step 3 — 스냅샷 카탈로그 바이트 비교
- [ ] Step 4 — 커밋 2

### Task 3: 축 산출과 표시 모델을 세운다

**Files**
- Create: `Presentations/WidgetScenes/Sources/Timeline/TimelineWidgetViewModel.swift`
- Create: `Presentations/WidgetScenes/Sources/Timeline/TimelineLayoutBuilder.swift`
- Test: `Presentations/WidgetScenes/Tests/Timeline/TimelineLayoutBuilderTests.swift`

**Interfaces**
- Consumes: `any CalendarEvent`(CalendarPresentation), `EventCellViewModelMapper`, `EventColorPalette`
- Produces: `TimelineWidgetViewModel`·`TimelineAxis`·`TimelineBlock`·`TimelineAllDayChip` — T-4·T-5·T-6 이 소비한다

```swift
public struct TimelineAxis: Equatable, Sendable {
    /// 축 시작 — 자정 기준 분
    public let startMinutes: Int
    /// 축 끝 — 자정 기준 분. 다음날로 넘어가면 1440 을 넘는다
    public let endMinutes: Int
}

public struct TimelineWidgetViewModel {
    public var axis: TimelineAxis
    public var blocks: [TimelineBlock]
    public var allDayChips: [TimelineAllDayChip]
    public let defaultTagColorSetting: DefaultEventTagColorSetting
    public let customTagMap: [String: any EventTag]
    public var googleCalendarColors: GoogleCalendar.Colors
    public var googleCalendarTags: [String: GoogleCalendar.Tag]
    public var appleCalendarTags: [String: AppleCalendar.Tag]
    public var widgetSetting: WidgetAppearanceSettings
}
```

색 재료 5종 + `widgetSetting` 은 `EventListWidgetViewModel.swift:68-73` 의 형태를 그대로 따른다 — 형제와 갈릴 이유가 없다.

```swift
public struct TimelineLayoutBuilder {
    private let timeZone: TimeZone
    private let is24hourForm: Bool

    public init(timeZone: TimeZone, is24hourForm: Bool)

    public func axis(from refTime: Date) -> TimelineAxis
}
```

**축 규칙** (2026-08-03 브리프 확정 + 플랜 상수)
- 시작 = `refTime` 의 분 (자정 기준).
- 끝 = 그날 자정(1440).
- **남은 시간이 4시간 미만이면 끝을 `시작 + 12시간` 으로 늘린다.** 상수는 `private enum Constant` 에 모은다 (swift-style §1) — `minimumRemainMinutes = 240`, `extendedSpanMinutes = 720`.

**엣지 케이스**
- 정확히 4시간 남음 → 연장하지 않는다 (경계는 미만일 때만).
- 23:59 → 연장돼 끝이 `1439 + 720`.
- 00:00 → 하루가 통째로 남아 연장 없음, 끝은 1440.

**테스트 케이스 이름**
- `testAxis_whenEnoughRemains_endsAtMidnight`
- `testAxis_whenRemainsExactlyThreshold_endsAtMidnight`
- `testAxis_whenRemainsBelowThreshold_extendsToTwelveHours`
- `testAxis_atMidnight_spansWholeDay`
- `testAxis_respectsTimeZone`

**Steps**
- [ ] Step 1 — G1 을 확인한다. `any CalendarEvent` 가 축·블록에 충분한지 (D-1)
- [ ] Step 2 — 축 TC 5개를 쓰고 RED
- [ ] Step 3 — `TimelineAxis`·`TimelineLayoutBuilder.axis(from:)` 로 GREEN
- [ ] Step 4 — `TimelineWidgetViewModel` 골격 정의 (blocks 는 T-4 에서 채운다)

### Task 4: 블록 매핑과 겹침 열 분할을 얹는다

**Files**
- Modify: `Presentations/WidgetScenes/Sources/Timeline/TimelineLayoutBuilder.swift`
- Modify: `Presentations/WidgetScenes/Sources/Timeline/TimelineWidgetViewModel.swift`
- Test: `Presentations/WidgetScenes/Tests/Timeline/TimelineLayoutBuilderTests.swift`

```swift
public struct TimelineBlock: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let startMinutes: Int
    public let endMinutes: Int
    public let columnIndex: Int
    public let columnCount: Int
    public let colorSource: any EventTagColorSource
    public let link: URL?
}

public struct TimelineAllDayChip: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let colorSource: any EventTagColorSource
    public let link: URL?
}

extension TimelineLayoutBuilder {
    public func blocks(
        from events: [any CalendarEvent], in axis: TimelineAxis, on day: Range<TimeInterval>
    ) -> (blocks: [TimelineBlock], allDayChips: [TimelineAllDayChip])
}
```

`name`·`link` 는 `EventCellViewModelMapper` 로 만든 셀 VM 에서 가져온다 — `name` 은 `EventCellViewModel.name`, `link` 는 `EventCellViewModel.widgetURL`(`CalendarPresentation/Sources/DeepLink/EventCellViewModel+WidgetURL.swift`). 시간 좌표는 `event.eventTime` 에서 직접 뽑는다.

**블록 규칙** (브리프·플랜 확정)
- 종일·공휴일 → 블록이 아니라 `allDayChips` 로 간다.
- 기한 없는 current todo → 제외한다 (EventList 위젯이 이미 덮는다).
- 축 시작보다 먼저 시작한 진행 중 일정 → 시작을 축 시작으로 clamp 한다.
- 길이 0 인 시점 이벤트 → 최소 30분으로 그린다. 상수 `minimumBlockMinutes = 30`.
- 축 밖으로 나가는 끝 → 축 끝으로 clamp.
- 축과 아예 안 겹치는 이벤트 → 제외.

**겹침 열 분할**
- 시작 시각 순으로 훑으며, 이미 열에 놓인 블록과 시간이 겹치면 다음 열로 민다.
- 서로 겹치는 블록 묶음(클러스터) 안에서 `columnCount` 는 그 묶음의 최대 열 수다 — 전체 최대가 아니다. 안 그러면 겹침 없는 블록까지 좁아진다.
- 열 수 상한은 자율(협조지시). 넘치는 블록은 표시하지 않는다.

**엣지 케이스**
- 끝과 시작이 정확히 맞닿는 두 블록(10:00–11:00, 11:00–12:00) → 겹침이 아니다. 같은 열.
- 셋이 사슬로 겹침(A–B 겹침, B–C 겹침, A–C 안 겹침) → 같은 클러스터, 열 2개면 충분하다.
- 축을 통째로 덮는 블록 하나 + 짧은 블록 여럿 → 클러스터 하나, `columnCount` 는 최대 동시 겹침 수.

**테스트 케이스 이름**
- `testBlocks_allDayEvent_goesToChipsNotBlocks`
- `testBlocks_holiday_goesToChips`
- `testBlocks_currentTodoWithoutTime_excluded`
- `testBlocks_ongoingEvent_clampsStartToAxisStart`
- `testBlocks_zeroLengthEvent_expandsToMinimum`
- `testBlocks_eventOutsideAxis_excluded`
- `testBlocks_touchingEvents_shareSameColumn`
- `testBlocks_overlappingPair_splitIntoTwoColumns`
- `testBlocks_chainedOverlap_columnCountIsPerCluster`

**Steps**
- [ ] Step 1 — 블록 TC 6개를 쓰고 RED
- [ ] Step 2 — `blocks(from:in:on:)` 매핑으로 GREEN
- [ ] Step 3 — 겹침 TC 3개를 쓰고 RED
- [ ] Step 4 — 열 분할로 GREEN
- [ ] Step 5 — 커밋 3 (T-3 + T-4)

### Task 5: 순수 뷰와 샘플을 만든다

**Files**
- Create: `Presentations/WidgetScenes/Sources/Timeline/TimelineWidgetViews.swift`
- Modify: `Presentations/WidgetScenes/Sources/Timeline/TimelineWidgetViewModel.swift` (`.sample`)
- Modify: `TodoCalendarApp/AppExtensions/Widget/Snapshots/WidgetCatalogSnapshots.swift`

**Interfaces**
- Produces: `TimelineWidgetView(model:)`, `TimelineWidgetViewModel.sample()` — DP-4.1 이 C6 등재에 쓴다

```swift
public struct TimelineWidgetView: View {
    public init(model: TimelineWidgetViewModel, isLargeSize: Bool)
}
```

생성자는 C1 대로 `init(model:)` 계열이다. 패밀리 분기를 `Bool` 로 받는 것은 `SystemSizeForemostEventView(model:isSmallSize:)`(`WidgetScenes/Sources/Foremost/ForemostWidgetViews.swift`) 선례를 따른다 — `WidgetFamily` 를 받으면 WidgetKit 을 물게 되어 C1 위반이다.

`.sample()` 은 `EventListWidgetViewModel.sample(size:)`(`:94`) 서식을 따라 기존 `widget.events.sample::*` 로케일 키를 재사용한다. 신규 샘플 문구 키를 만들지 않는다 — 로케일 짝이 31개씩 늘어난다.

**뷰 구성** — 왼쪽 눈금 열(정시 라벨) + 오른쪽 블록 영역. `GeometryReader` 로 분당 높이를 산출하고 블록은 `ZStack` 안에 `offset` 으로 놓는다. **뷰에 시간 계산을 두지 않는다** — 받은 분 단위 정수를 픽셀로 곱하는 것만 한다. 배경은 그리지 않는다 (C2 — 확장이 `.containerBackground` 로 건다).

**엣지 케이스**
- 블록이 하나도 없는 날 → 축만 그린다. 빈 상태 문구를 새로 만들지 않는다.
- 종일 칩이 많을 때 → 상단 띠가 한 줄을 넘지 않게 자른다.

**스냅샷 케이스**
- `test_widgetTimelineMedium` — `family: .systemMedium`, `canvas: WidgetCanvas.medium`
- `test_widgetTimelineLarge` — `family: .systemLarge`, `canvas: WidgetCanvas.large`

**Steps**
- [ ] Step 1 — `.sample()` 을 만든다
- [ ] Step 2 — `TimelineWidgetView` 를 만든다
- [ ] Step 3 — 스냅샷 케이스 2개를 더하고 찍는다
- [ ] Step 4 — 기존 20장이 기준선과 바이트 동일한지 확인한다 (FFIR-5)
- [ ] Step 5 — 커밋 4

### Task 6: 확장에 배선한다

**Files**
- Create: `TodoCalendarApp/AppExtensions/Widget/Sources/Widgets/TimelineWidget/TimelineWidgetViewModelProvider.swift`
- Create: `TodoCalendarApp/AppExtensions/Widget/Sources/Widgets/TimelineWidget/TimelineWidgetTimeLineProvider.swift`
- Create: `TodoCalendarApp/AppExtensions/Widget/Sources/Widgets/TimelineWidget/TimelineWidget.swift`
- Modify: `TodoCalendarApp/AppExtensions/Widget/Sources/Base+Factory/WidgetViewModelProviderBuilder.swift`
- Modify: `TodoCalendarApp/AppExtensions/Widget/Sources/TodoCalendarWidgetBundle.swift`
- Modify: `Supports/Extensions/Resources/*.lproj/Localizable.strings` (31개)
- Test: `TodoCalendarApp/AppExtensions/Widget/Tests/ViewModelProviders/TimelineWidgetViewModelProviderTests.swift`

**Interfaces**
- Consumes: `TimelineWidgetViewModel`·`TimelineLayoutBuilder`·`TimelineWidgetView`

```swift
struct TimelineWidgetViewModelProvider {
    init(
        targetEventTagIds: [EventTagId]?,
        eventsFetchUsecase: any CalendarEventFetchUsecase,
        appSettingRepository: any AppSettingRepository,
        calendarSettingRepository: any CalendarSettingRepository
    )
    func getTimelineViewModel(for refTime: Date) async throws -> TimelineWidgetViewModel
}
```

`makeEventListViewModelProvider`(`WidgetViewModelProviderBuilder.swift`)와 같은 조립 서식을 따른다 — `targetEventTagIds` 를 받는 것도 같다.

타임라인 프로바이더는 `EventListWidgetTimeLineProvider.swift:20` 을 그대로 따른다. `Intent = EventTypeSelectIntent`, `Entry = ResultTimelineEntry<TimelineWidgetViewModel>`, `policy: .after(Date().nextUpdateTime)`, 배경은 `|> \.background .~ model.widgetSetting.background`.

`Widget` 선언은 `DDayWidget.swift:79` 서식. `supportedFamilies([.systemMedium, .systemLarge])`, `configurationDisplayName("widget.timeline::name".localized())`, `description("widget.common::explain".localized())`.

**로케일** — `widget.timeline::name` 1개 키. en 을 먼저 쓰고 ko 를 채운 뒤 나머지 29개는 en 값으로 채운다. `python3 scripts/check-localization-parity.py` 로 확인하고, `localization` 라벨 최신 열린 이슈에 번역 대기로 등록한다 (`.claude/rules/localization.md` §1).

**엣지 케이스**
- 태그 필터가 비었을 때(`configuration.eventTypes == nil`) → 전체. `EventListWidgetTimeLineProvider:70` 과 같다.
- 조회 실패 → `.failure(.init(error:))` 로 `FailView`.

**테스트 케이스 이름**
- `testProvider_whenLoadTimeline_axisFromRefTimeToMidnight`
- `testProvider_whenTagFilterGiven_fetchWithoutOffTagIds`
- `testProvider_whenFetchFails_throws`

**Steps**
- [ ] Step 1 — provider TC 를 쓰고 RED
- [ ] Step 2 — `TimelineWidgetViewModelProvider` 로 GREEN
- [ ] Step 3 — 타임라인 프로바이더·`Widget` 선언·엔트리 뷰를 만든다
- [ ] Step 4 — 빌더에 `makeTimelineViewModelProvider` 를 더하고 번들에 등록한다
- [ ] Step 5 — `mise exec -- tuist generate --no-open` 후 로케일 키 31개를 채우고 parity 확인
- [ ] Step 6 — 커밋 5

## 부록 B. 커밋 시퀀스

| # | 태스크 | 메시지 초안 |
|---|---|---|
| 1 | T-1 | `[#751] 위젯 색 해석을 EventColorPalette 로 뽑아 뷰에서 뗀다` |
| 2 | T-2 | `[#751] 확장 provider 3곳이 셀 VM 매핑을 EventCellViewModelMapper 에 위임하게 바꾼다` |
| 3 | T-3 + T-4 | `[#751] 타임라인 축·블록·겹침 산출을 WidgetScenes 에 세운다` |
| 4 | T-5 | `[#751] 타임라인 순수 뷰와 샘플을 만들고 카탈로그에 얹는다` |
| 5 | T-6 | `[#751] 타임라인 위젯을 확장에 등록해 홈 medium·large 에 띄운다` |

## 부록 C. 모델 티어

| 태스크 | 티어 | 근거 |
|---|---|---|
| T-1 | 표준 | 기존 클로저를 타입으로 옮기고 호출부를 바꾼다. 판정 순서 보존이 관건 |
| T-2 | 하위 | 시그니처·경로가 확정된 기계적 치환. 대조 결과만 확인하면 된다 |
| T-3 | 표준 | 축 규칙이 문장으로 확정돼 있고 경계 판정이 붙는다 |
| T-4 | 표준 | 겹침 열 분할이 이 명령에서 가장 판단이 필요한 자리다 |
| T-5 | 표준 | 레이아웃 조립. 형제 뷰 패턴 매칭 |
| T-6 | 표준 | 멀티 파일 조율. 선례가 명확하다 |

인라인 실행이라 dispatch 는 없다. 이 표는 태스크를 넘길 경우의 판정이다.

## 부록 D. 단편명령 누적

없음.
