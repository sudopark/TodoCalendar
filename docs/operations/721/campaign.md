# 작전계획 (Campaign Plan) — L

> 용어 — DP: 결정적 지점(작전명령 하나 = PR 하나) · LOE: 노력선(최종상태 한 관점을 담당하는 줄기) · FRAGO: 단편명령 · MOP / MOE: 과업 수행 여부 / 효과 발생 여부 · PIR / FFIR: 즉시보고 조건 중 환경·외부 정보 / 아군·내부 정보

```
작전계획 — #721 프리미엄 위젯 팩        작성: 유저   개정:
```

## 0. 전략 지침

- **목적**: #721 — Pro 구독이 파는 시각적 가치를 위젯으로 만든다. 상위 전략 문서는 없다.
- **수단·제한 출처**: #721 본문 확정사항(이 계획을 재가하면 1항 "범위 밖"대로 갱신한다), `docs/operations/templates/delegation.md`, `.claude/rules/presentations-rules.md`, `.claude/rules/localization.md`, `.claude/rules/swift-style.md`, add-framework 스킬.
- **위임 상한**: delegation.md 를 상속한다. 좁히는 건 12항에 적었다.

## 1. 문제 정의

**현 상태**

- 위젯 뷰가 확장 타겟에만 있다. 앱 타겟이 컴파일하는 경로는 `Sources/**` 와 `AppExtensions/Base/**` 뿐이다 (`Tuist/ProjectDescriptionHelpers/Project+Templates.swift:285`). 앱은 위젯 뷰를 못 본다.
- 그렇다고 `AppExtensions/Base/` 로 옮겨도 안 된다. 그러면 이번엔 Presentations 쪽 Scene 이 그걸 못 본다. 의존 방향이 반대다.
- 순수 뷰와 WidgetKit 코드가 **한 파일에 같이 있다.** `DDayWidget.swift` 는 순수 뷰 5개(`DDaySmallWidgetView` 등)와 엔트리 뷰·`DDayWidget: Widget` 선언을 함께 담고, 파일 맨 위에서 `import WidgetKit` 한다.
- ViewModel 과 그걸 만드는 Provider 도 한 파일에 있다. 갤러리가 쓸 `.sample` 팩토리 8개가 전부 Provider 파일 안에 산다 (`DDayWidgetViewModelProvider.swift:40` 등).
- **확장은 이미 Scene 프레임워크를 문다.** 위젯 확장 의존에 `CalendarScenes` 가 있다 (`TodoCalendarApp/Project.swift`). `CalendarScenes` 는 `Scenes` 를 물고, `Scenes/BaseComponents.swift:125` 는 `UIApplication.shared` 를 쓴다. 그런데도 빌드된다 — `APPLICATION_EXTENSION_API_ONLY` 가 어디에도 안 걸려 있다.
- 위젯 `Widget` 선언 20개 중 18개가 `CalendarScenes` 를 문다. 소스 36파일과 테스트 9파일이 `import CalendarScenes` 한다. 안 무는 건 D-day 와 AICommand 둘뿐이다. 쓰는 표시 모델은 `EventCellViewModel`(프로토콜, 준수 타입 7개)·`WeekRowModel`·`WeekDayModel`·`DayCellViewModel`·`EventOnWeek` 다.
- 커스터마이징은 배경 하나뿐이다. `WidgetAppearanceSettings` 가 `background` 만 갖고(`Domain/Sources/Models/Settings/AppearanceSettings.swift:112`) 그 값이 전 위젯에 똑같이 걸린다. 배경은 `ResultTimelineEntry.backgroundShape` 를 거쳐 `.containerBackground(for: .widget)` 로 들어간다. 순수 뷰 **바깥**이다 (`DDayWidget.swift:262`).
- 신규 라인업이 아직 안 나갔다. D-day 는 완성됐지만 `BaseWidgetBundle` 등록 줄이 주석 처리돼 있고(`TodoCalendarWidgetBundle.swift:37`) `FeatureFlag.ddayWidget` 도 꺼져 있다. 타임라인은 시작을 안 했다 (#751 — 스펙 브리프와 플랜은 있다).
- Free 와 Pro 를 가르는 선이 코드 어디에도 없다.

**원하는 상태**

앱 안에 위젯 갤러리가 있고 **전 위젯이 거기 다 들어간다.** 미리보기를 확장이 쓰는 것과 **같은 순수 뷰**가 그린다. 유저는 위젯 종류별로 꾸미고, 꾸미기는 **전 위젯에 걸린다.** 프리셋까지는 무료고 세부조정부터 Pro 다. 신규 위젯인 타임라인과 D-day 를 노출한다.

**막는 것**

순수 뷰가 확장 타겟에 갇혀 있어서 앱이 못 쓴다. 게다가 그 뷰는 WidgetKit 코드와 한 파일에 섞여 있다. 그래서 옮기는 일이 파일 이동이 아니라 파일 쪼개기다.

더 큰 벽은 표시 모델이다. 위젯 18종이 `CalendarScenes` 의 표시 모델을 쓴다. 그 뷰들을 공용 층으로 올리면 `WidgetScenes → CalendarScenes` 로 의존이 이어져, CLAUDE.md §2 가 막는 "Presentation 모듈끼리 직접 import" 를 우회로 어기게 된다.

**범위 밖**

- paywall 을 띄우거나 구매를 검증하거나 잠금 뱃지를 붙이는 일. 과금 트랙(#707·#899)이 할 일이다. 이 캠페인은 "이게 Pro 전용인가"를 **판정**하는 데까지만 만들고 잠그진 않는다.
- 기존 위젯의 무료 동작과 모양. 꾸미기를 안 건드린 상태의 기본값은 지금과 같아야 한다.
- 잠금화면 위젯 추가. #741 로 충분하다.
- **신규 위젯을 Pro 로 잠그는 것.** #721 본문은 "Pro = 신규 위젯 + 커스터마이징" 이라고 적어놨는데 이 계획이 그걸 바꾼다. 신규 위젯은 무료로 풀고, **Pro 가 파는 건 전 위젯 꾸미기 깊이 하나**다.

## 2. 최종상태

| 관점 | 상태 | 판정 |
|---|---|---|
| 동작 | 갤러리에서 전 위젯(기존 19종 + D-day + 타임라인)을 둘러보고 미리본다 | 실기 — 갤러리 목록 수가 `Widget` 선언 수와 맞는다 |
| 동작 | 갤러리 미리보기를 확장이 쓰는 것과 같은 순수 뷰가 그린다 | 갤러리와 `WidgetCatalogSnapshots` 이 같은 뷰 타입을 부른다 — 코드 경로 확인 + 육안 대조 |
| 동작 | 프리셋을 바꾸면 미리보기가 바로 바뀌고 홈 위젯도 다음 갱신에 같은 모양이 된다 | 실기 — 갤러리에서 바꾸고 홈으로 나가서 확인 |
| 동작 | 세부조정 4축이 프리셋 값을 덮고, 조정이 걸린 위젯은 `requiresPro` 가 true 다 | 유닛 테스트(합성·판정) + 실기 |
| 동작 | 꾸미기가 전 위젯에 걸린다. 어느 위젯을 골라도 프리셋·조정이 먹는다 | 실기 — 위젯군마다 하나씩 확인 |
| 동작 | 타임라인 위젯을 홈 medium·large 에 놓으면 시간 축 위에 일정이 블록으로 그려진다 | 실기 + ViewModelProvider 테스트 |
| 동작 | D-day 위젯이 시스템 위젯 갤러리와 일정 상세 후보 등록 메뉴에 보인다 | 실기 |
| 코드 | 전 위젯 순수 뷰와 ViewModel 이 `WidgetScenes` 에 있고, 그 모듈은 WidgetKit 을 안 쓴다 | `grep -rn "import WidgetKit" Presentations/WidgetScenes/` 가 0건 |
| 코드 | 표시 모델 6종이 `CalendarPresentation` 에 있고, `CalendarScenes` 와 `WidgetScenes` 가 거기서 가져다 쓴다 | 두 Project.swift 의존 목록 |
| 코드 | 확장이 `CalendarScenes` 를 안 문다. `WidgetScenes` 만 문다 | `TodoCalendarApp/Project.swift` 확장 의존 목록 + `grep -rn "import CalendarScenes" TodoCalendarApp/AppExtensions/Widget/` 가 0건 |
| 코드 | `SettingScene` 이 `WidgetScenes` 를 직접 안 문다. `Scenes` 프로토콜로만 갤러리를 부른다 | `SettingScene/Project.swift` + `grep -rn "import WidgetScenes" Presentations/SettingScene/` 가 0건 |
| 구조 | `WidgetStyle` 합성과 `requiresPro` 판정이 Domain 에 있고, 저장은 위젯 종류별 전역이다 | 코드 + 유닛 테스트 |
| 검증 | 순수 뷰를 옮기기 전후 스냅샷이 같다 | `WidgetCatalogSnapshots` 이미지 대조 |
| 검증 | 신규 스킴 `WidgetScenes`·`CalendarPresentation` 이 CI 와 로컬 스크립트에서 돈다 | `pr_test.yml` 에서 감지·실행 둘 다 확인 |
| 품질 | 기존 위젯의 모양과 동작이 안 바뀐다 (꾸미기를 안 건드린 기본 상태 기준) | 기존 위젯 테스트 + 스냅샷 대조 |
| 품질 | `CalendarScenes`·`EventListScenes` 동작이 안 바뀐다 | 두 스킴 테스트 통과 |
| 외부 | 없음 | — |

## 3. 중심 분석

**힘의 원천**

유저가 꾸미기에 시간을 쓰게 만드는 건 "지금 보고 있는 이 모양이 홈에 그대로 놓인다"는 확신이다. 확신이 서야 조정을 만지고, 만진 시간이 결제 이유가 된다.

그런데 확신은 갤러리가 **다 보여줄 때만** 선다. 내가 쓰는 위젯이 목록에 없으면 그 화면은 나와 상관없는 화면이 된다.

**장애의 중심**

표시 모델이 `CalendarScenes` 에 갇혀 있다. 위젯 18종이 그걸 쓰기 때문에, 뷰를 공용 층으로 올리는 순간 Scene 프레임워크가 딸려 온다. 이 매듭을 안 풀면 갤러리에 신규 몇 종밖에 못 올리고, 그러면 갤러리가 갤러리가 아니다.

**취약점**

1. **분리선이 이미 그어져 있다.** 순수 뷰는 ViewModel 하나만 받고 WidgetKit 을 안 쓰며 `.sample` 까지 갖고 있다. `PreviewProvider` 와 `WidgetCatalogSnapshots` 가 이미 위젯 밖에서 그린다. 다만 뷰가 WidgetKit 코드와, ViewModel 이 Provider 와 한 파일에 있어서 먼저 쪼개야 한다.
2. **확장이 Scene 프레임워크를 무는 길이 이미 뚫려 있다.** 확장이 `CalendarScenes` 를 문다. 그래서 순수 뷰를 담을 모듈을 따로 세우지 않아도 된다. 갤러리 Scene 과 같은 모듈에 두고 확장이 그걸 물면 끝이다.
3. **표시 모델은 다섯 자리에만 있다.** `EventCellViewModel` 은 자기 파일에 있고(`Common/EventListCell/EventCellViewModel.swift`), 나머지 넷은 `Month/MonthViewModel.swift` 와 `Month/WeekEventStackBuilder.swift` 안에 섞여 있다. 파일 셋만 손대면 뽑힌다.
4. **무손실을 증명할 파일럿이 있다.** D-day 는 `CalendarScenes` 를 안 물고, 이미 완성돼 있고, 스냅샷도 붙어 있다. 표시 모델을 건드리기 전에 이관 계약만 따로 검증할 수 있다.
5. **미리보기 데이터가 대부분 있다.** `.sample` 팩토리가 8개다 — Foremost·EventList·NextEvent·NextRemain·WeekEvents·D-day·TodayAndNext·Today. 새로 만들 건 Composed 4종과 AICommand 뿐이다.
6. **문자열은 안 깨진다.** `localized()` 가 `Extensions` 프레임워크의 `Bundle.module` 을 쓴다. 뷰를 어느 모듈로 옮겨도 위젯 문구는 그대로 찾아진다.

**접근 — 잠식**

취약점 4가 준 파일럿부터 쓴다. D-day 하나로 `WidgetScenes` 를 세우고 이관 계약이 되는지 그림으로 확인한다(1단계). 표시 모델은 그다음에 뽑는다(2단계) — 계약이 안 선 상태에서 45파일짜리 매듭을 건드리지 않는다.

매듭이 풀리면 나머지 뷰는 같은 계약을 반복 적용하는 일이라 배치로 나눠 옮긴다. 그다음에야 타임라인을 만들고(3단계) 갤러리를 세운다(4단계).

## 4. 노력선

**LOE-1 공유 뷰 층** — 담당 관점: 코드·검증·품질

① `WidgetScenes` 가 서고 D-day 순수 뷰가 거기로 가도 모양이 안 바뀐다 → ② 표시 모델이 `CalendarScenes` 밖으로 나온다 → ③ 전 위젯 순수 뷰가 `WidgetScenes` 에 있고 확장은 `WidgetScenes` 만 문다

**LOE-2 라인업** — 담당 관점: 동작(위젯)

① 타임라인 위젯이 홈 medium·large 에 그려진다 → ② D-day 가 시스템 갤러리와 상세 메뉴에 보인다

**LOE-3 꾸미기** — 담당 관점: 동작(꾸미기)·구조

① 갤러리에서 전 위젯을 둘러보고 미리본다 → ② 프리셋이 전 위젯에 반영된다 → ③ 세부조정 4축과 `requiresPro` 판정이 붙는다

## 5. 단계

| 단계 | 종료 조건 (상태) | 주노력 LOE | 목적 |
|---|---|---|---|
| 1. 파일럿 | `WidgetScenes` 에 D-day 순수 뷰가 있고 WidgetKit import 가 0건이다. 확장이 그걸 물어 그리고 스냅샷이 이관 전과 같다 | LOE-1 | 6항 C1·C2 계약이 되는지 그림으로 확인한다 |
| 2. 매듭 풀기 | 표시 모델 6종이 `CalendarPresentation` 에 있고, 전 위젯 순수 뷰가 `WidgetScenes` 에 있으며, 확장 의존에서 `CalendarScenes` 가 빠졌다 | LOE-1 | 갤러리가 전 위젯을 그릴 수 있게 만든다 |
| 3. 라인업 | 타임라인 위젯이 홈 medium·large 에 그려지고, 그 순수 뷰가 `WidgetScenes` 에 있다 | LOE-2 | 꾸밀 대상을 마저 채운다 |
| 4. 그릇 | 갤러리 Scene 이 서고, 설정에서 들어가 전 위젯 미리보기가 실뷰로 그려진다 | LOE-3 | 꾸미기 UI 가 놓일 자리를 만든다 |
| 5. 깊이 | `WidgetStyle` 프리셋·조정 2층이 전 위젯에 저장·합성·반영되고 `requiresPro` 판정이 Domain 에 있다 | LOE-3 | Pro 가 파는 것을 만든다 |
| 6. 노출 | D-day 가 시스템 위젯 갤러리와 일정 상세 후보 등록 메뉴에 보인다 | LOE-2 | 감춘 것을 푼다 |

## 6. 노력선 × 단계 격자 → DP 좌표

| | 1 파일럿 | 2 매듭 풀기 | 3 라인업 | 4 그릇 | 5 깊이 | 6 노출 |
|---|---|---|---|---|---|---|
| LOE-1 공유 뷰 층 | DP-1.1 | DP-2.1 · DP-2.2 · DP-2.3 | — | (DP-4.1 이 겸한다) | — | — |
| LOE-2 라인업 | — | — | DP-3.1 | — | — | DP-6.1 |
| LOE-3 꾸미기 | — | — | — | DP-4.1 | DP-5.1 · DP-5.2 | — |

DP-4.1 은 LOE-3 이 주인이지만 LOE-1 ③도 같이 채운다. 갤러리가 순수 뷰를 실제로 소비해야 "앱과 확장이 같은 뷰를 그린다"가 증명되기 때문이다.

### 통제수단 — DP 사이 인터페이스 계약

#### C1. 뭘 어디에 두나

DP-1.1 이 이 선을 긋고, DP-2.x 가 나머지 위젯에 반복 적용한다.

| 위치 | 들어가는 것 | 왜 |
|---|---|---|
| `Presentations/CalendarPresentation` (신설) | `CalendarScenes` 에서 뽑은 표시 모델 6종 — `EventCellViewModel` 과 준수 타입, `WeekRowModel`·`WeekDayModel`·`DayCellViewModel`·`EventOnWeek` | 캘린더 화면과 위젯이 함께 쓰는 것이라 둘 다 아래에서 물 수 있는 자리가 필요하다 |
| `Presentations/WidgetScenes` (신설) | 패밀리별 순수 뷰, 그게 받는 ViewModel 과 `.sample`, 배경·스타일 해석, 갤러리 Scene, 프리셋·조정 UI | 앱과 확장이 같은 뷰를 그리려면 둘 다 볼 수 있는 곳에 있어야 한다. 갤러리와 한 모듈에 두면 뷰가 갈라질 여지가 없다 |
| 확장에 남김 | `ResultTimelineEntry`, 엔트리 뷰(`widgetFamily` 로 분기), `TimelineProvider`, ViewModelProvider(Domain 조회), `Widget` 선언, `AppIntentConfiguration` | WidgetKit·AppIntents 전용이고 확장 밖에선 등록도 안 된다 |

- 의존 방향은 `WidgetScenes → CalendarPresentation` 이고 `CalendarScenes → CalendarPresentation` 이다. `WidgetScenes` 와 `CalendarScenes` 는 서로 안 문다.
- **`WidgetScenes` 는 `CalendarScenes` 를 안 문다.** 물어야 할 것 같으면 그건 아직 안 뽑은 표시 모델이 있다는 뜻이다. 몰래 import 하지 말고 DP-2.1 로 되돌려 뽑는다.
- `WidgetScenes` 는 WidgetKit 도 안 문다. 순수 뷰가 WidgetKit 을 쓰기 시작하면 앱에서 그릴 수 없게 되고 갤러리가 죽는다.
- 확장은 최종적으로 `WidgetScenes` 만 문다. `CalendarScenes` 의존은 DP-2.3 에서 뗀다.
- **쪼개는 자리가 둘이다.** 뷰 파일은 순수 뷰 / 엔트리 뷰·`Widget` 선언으로, Provider 파일은 ViewModel·`.sample` / Provider 로 가른다. 앞엣것이 `WidgetScenes` 로 가고 뒤엣것이 확장에 남는다.
- 옮기는 타입은 `public` 이 되고 `public init` 을 연다. 지금은 internal 이고 `WidgetCatalogSnapshots` 이 `@testable import TodoCalendarAppWidget` 으로 본다. 이관하면 그 경로가 끊기므로 스냅샷도 `import WidgetScenes` 로 바꾼다.
- 순수 뷰 생성자는 `init(model:style:)` 하나로 맞춘다. 엔트리 뷰든 갤러리 미리보기든 같은 걸 부른다. `style` 은 DP-5.1 전까지 기본값을 받는다.

#### C2. 배경을 어디서 그리나

DP-1.1 이 정하고 DP-2.x·DP-5.1 이 따른다.

지금은 배경을 순수 뷰 **바깥**에서 그린다. `ResultTimelineEntry.backgroundShape` 를 `.containerBackground(for: .widget)` 에 넘긴다. 이러면 갤러리 미리보기가 배경을 못 그린다. 미리보기와 실물이 달라 보이니 1단계부터 중심이 깨진다.

그래서 배경·스타일 해석을 `WidgetScenes` 로 내리고 **순수 뷰가 자기 배경을 직접 그리게** 한다. 그러면 확장에서 `.containerBackground` 와 겹칠 수 있다. 컨테이너를 투명으로 둘지 같은 값을 넘길지는 DP-1.1 이 실제로 돌려보고 정해서 종결보고에 적는다. 정해진 답을 DP-2.x 가 그대로 반복한다.

#### C3. 꾸미기 값을 어떻게 담고 흘리나

DP-5.1 이 만들고 DP-5.2 가 채운다.

```
WidgetStyle
  preset: WidgetStylePreset          // 무료. 이름 붙은 값 묶음
  adjustment: WidgetStyleAdjustment  // Pro. 4축 각각 Optional, 기본은 전부 nil
  resolved: WidgetStyleValues        // preset 위에 adjustment 의 non-nil 만 덮은 결과
  requiresPro: Bool                  // adjustment 에 non-nil 축이 하나라도 있으면 true
```

- 조정 축은 **배경·투명도·글자크기·강조색 4개**로 자른다.
- 순수 뷰는 `resolved` 만 받는다. 그 값이 프리셋에서 왔는지 조정에서 왔는지는 모른다.
- **스타일은 뷰 트리 최상단에서 environment 로 흘리고 공통 modifier 가 적용한다.** 위젯 21종의 뷰를 하나씩 고쳐 축을 반영하지 않는다. 뷰마다 개별 대응하면 어느 하나를 빠뜨려도 티가 안 나고, 축이 늘 때마다 21곳을 다시 돌아야 한다.
- 저장은 위젯 종류별 전역이다. 키는 위젯 종류 식별자, 값은 `WidgetStyle`. `WidgetAppearanceSettings` 와 같은 App Group 을 쓴다.
- `requiresPro` 는 Domain 에 둔다. **이 캠페인은 판정만 만든다.** 그 값을 보고 잠그는 건 범위 밖이다.

#### C4. 갤러리를 어떻게 부르나

DP-4.1 이 세운다.

- `Presentations/Scenes/Sources/Scenes+WidgetGallery.swift` 에 `WidgetGalleryScene`·`WidgetGallerySceneBuilder` 프로토콜을 둔다. 기존 `Scenes+Setting.swift` 와 같은 서식이다.
- `SettingScene` 은 그 프로토콜만 물고 구체 타입을 모른다. CLAUDE.md §2 의 "Presentation 모듈끼리 직접 import 금지" 를 이렇게 지킨다.
- 조립은 앱 루트에서 한다. `ApplicationRootBuilder` 계열이 `WidgetScenes` 의 구현체를 주입한다.
- 진입점은 설정 > 외관 > 위젯이다. 기존 `WidgetAppearanceSettingScene` 에서 갤러리로 넘어간다.

#### C5. 머지 순서

DP 번호 순으로 간다. 각 DP 의 base 는 바로 앞 DP 를 머지한 develop 이다. 병렬 슬롯은 안 둔다 (10항).

## 7. DP 목록

| DP | LOE | 단계 | 산출물 | 선행 DP | 소유 범위 (모듈·파일) | 사이즈 |
|---|---|---|---|---|---|---|
| DP-1.1 | LOE-1 | 1 | `Presentations/WidgetScenes` 프레임워크를 세운다. `DDayWidget.swift` 와 `DDayWidgetViewModelProvider.swift` 를 C1 대로 쪼개 순수 뷰 5개·ViewModel·`.sample` 을 옮기고 `public` 을 연다. 확장이 `WidgetScenes` 를 물게 배선한다. C2 의 배경 겹침을 정리한다. 스냅샷 import 경로를 바꾸고 이관 전후 이미지를 대조한다 | — | `Presentations/WidgetScenes/**`(신규), `Widget/Sources/Widgets/DDayWidget/**`, `Widget/Snapshots/WidgetCatalogSnapshots.swift`, `Workspace.swift`, `TodoCalendarApp/Project.swift`, 스킴 하드코딩(`pr_test.yml`·`run-all-tests.sh`·`impact-check.sh`+테스트·run-tests 스킬) | M |
| DP-2.1 | LOE-1 | 2 | `Presentations/CalendarPresentation` 프레임워크를 세우고 표시 모델 6종을 옮긴다. `EventCellViewModel` 은 파일째, 나머지 넷은 `MonthViewModel.swift`·`WeekEventStackBuilder.swift` 에서 떼어낸다. `CalendarScenes` 가 새 모듈을 물게 바꾼다. 캘린더·이벤트 목록 화면 동작은 안 바뀐다 | DP-1.1 | `Presentations/CalendarPresentation/**`(신규), `Presentations/CalendarScenes/Sources/{Common/EventListCell,Month}`, `CalendarScenes/Project.swift`, `Workspace.swift`, 스킴 하드코딩 | M |
| DP-2.2 | LOE-1 | 2 | 단일 위젯군 순수 뷰를 `WidgetScenes` 로 옮긴다 — AICommand·Today·Foremost·NextEvent·NextRemain·TodayAndNext. C1 의 쪼개는 자리 둘을 그대로 적용한다 | DP-2.1 | `Presentations/WidgetScenes/**`, `Widget/Sources/Widgets/{AICommandWidget,TodayWidget,ForemostWidget,NextEventWidget,TodayAndNext}`, `Widget/Snapshots/` | M |
| DP-2.3 | LOE-1 | 2 | 복합 위젯군 순수 뷰를 옮긴다 — Month·WeekEvents·EventList·Composed 4종. 마지막에 확장 의존에서 `CalendarScenes` 를 뗀다 | DP-2.2 | `Presentations/WidgetScenes/**`, `Widget/Sources/Widgets/{MonthWidget,WeekEventsWidget,EventListWidget,ComposedWidget}`, `Widget/Sources/{Usecases,Base+Factory,Intents}`, `TodoCalendarApp/Project.swift`, `Widget/Tests/**` | M |
| DP-3.1 | LOE-2 | 3 | 타임라인 위젯. 시간 축을 산출하고(현재~자정, 남은 시간이 4시간 미만이면 12시간으로 연장) 일정을 블록으로 얹고 겹치면 열을 나눈다. medium·large 와 `EventTypeSelectIntent` 연결까지. 순수 뷰는 처음부터 `WidgetScenes` 에 만든다 | DP-2.3 | `Presentations/WidgetScenes/**`, `Widget/Sources/Widgets/TimelineWidget/**`(신규), `Widget/Sources/Base+Factory/`, `TodoCalendarWidgetBundle.swift`, `Widget/Tests/ViewModelProviders/`, `Supports/Extensions/Resources/*.lproj` | M |
| DP-4.1 | LOE-3 (LOE-1 겸) | 4 | 갤러리 Scene 을 `WidgetScenes` 안에 세운다. `Scenes+WidgetGallery.swift` 프로토콜, 전 위젯 목록, `.sample` ViewModel 을 넣은 실뷰 미리보기, 설정 > 외관 > 위젯 진입, 앱 루트 조립까지. Composed 4종과 AICommand 의 `.sample` 을 새로 만든다 | DP-3.1 | `Presentations/WidgetScenes/Sources/Gallery/**`, `Presentations/Scenes/Sources/Scenes+WidgetGallery.swift`, `SettingScene` 진입 라우팅, `TodoCalendarApp/Sources/Root/`, `Supports/Extensions/Resources/*.lproj` | M |
| DP-5.1 | LOE-3 | 5 | C3 의 프리셋 층을 만든다. `WidgetStyle`·`WidgetStylePreset` 과 `resolved` 합성, 위젯 종류별 저장·조회 usecase, environment 전파와 공통 modifier, 확장 진입에서 값 주입, 갤러리 프리셋 선택 UI | DP-4.1 | `Domain/Sources/Models/Settings/`, `Domain/Sources/Usecases/`, `Repository`(App Group 저장), `Presentations/WidgetScenes/**`, `Widget/Sources/Widgets/**` 진입, `Domain/Tests` | M |
| DP-5.2 | LOE-3 | 5 | C3 의 조정 층을 채운다. `WidgetStyleAdjustment` 4축(배경·투명도·글자크기·강조색), `requiresPro` 판정, 갤러리 세부조정 UI. 판정만 하고 잠그진 않는다 | DP-5.1 | `Domain` 모델·판정, `WidgetScenes` 조정 UI·공통 modifier, `Domain/Tests`, `WidgetScenes/Tests` | M |
| DP-6.1 | LOE-2 | 6 | D-day 를 노출한다. `BaseWidgetBundle` 등록 줄을 되살리고 `FeatureFlag.ddayWidget` 을 기본 on 으로 바꾼 뒤 일정 상세 후보 등록 메뉴를 확인한다 | DP-5.2 | `TodoCalendarWidgetBundle.swift`, `Domain/Sources/Utils/FeatureFlag.swift` | S |

## 8. 가정

| ID | 가정 | 검증 방법 | 깨지면 |
|---|---|---|---|
| A1 | 순수 뷰를 `WidgetScenes` 로 옮겨도 확장이 그리는 모양이 안 바뀐다. C2 대로 배경 그리는 자리를 옮기는 것까지 포함해서다 | DP-1.1 에서 D-day 로 먼저 확인하고, DP-2.2·2.3 에서 위젯군마다 스냅샷을 대조한다 | 배경은 확장에 남기고 갤러리는 미리보기용 배경을 따로 그린다. 중심이 약해지므로 즉시보고한다 |
| A2 | 표시 모델 6종을 `CalendarPresentation` 으로 옮겨도 `CalendarScenes`·`EventListScenes` 동작이 안 바뀐다 | DP-2.1 착수 전에 참조하는 곳을 다 세고, 두 스킴 테스트로 확인한다 | 2단계를 하위 캠페인으로 올린다 |
| A3 | 확장의 `CalendarScenes` 참조가 표시 모델뿐이라, 뽑고 나면 의존을 뗄 수 있다 | DP-2.1 에서 확장의 45파일 참조를 표시 모델 / 그 외로 분류한다. `CalendarEventFetchUsecase`·`WidgetLink+Extensions`·`DDayTargetSelectIntent` 를 특히 본다 | 표시 모델 외에 뽑을 게 더 있으면 DP-2.1 범위를 넓힌다. 못 뗄 정도면 확장의 `CalendarScenes` 의존을 남긴 채 간다 — 갤러리는 그래도 선다 |
| A4 | 조정 4축을 environment + 공통 modifier 로 걸면 위젯 21종에 다 먹는다 | DP-5.1 에서 프리셋을 그렇게 걸어보고 위젯군마다 확인한다 | 축별로 뷰가 직접 받는 자리를 만든다. DP-5.2 를 위젯군별로 쪼개는 계획 개정으로 간다 |
| A5 | #751 플랜(`docs/superpowers/plans/2026-08-04-751-timeline-widget.md`)의 축 산출·겹침 배치 부분이 지금 develop 에서 유효하다 | 파일 6개와 `EventListWidget.tagLineView` 앵커를 2026-09-07 에 확인했다. DP-3.1 착수 때 다시 본다 | opord 로 새로 쓴다. **뷰 배치 부분은 이미 무효다** — 그 플랜은 순수 뷰를 확장에 두는 전제로 쓰였고 DP-1.1 이 전제를 바꾼다 |
| A6 | 꾸미기 값을 App Group 에 저장하면 위젯 타임라인 갱신에 반영된다. `WidgetAppearanceSettings.background` 가 이미 그렇게 한다 | DP-5.1 에서 실기로 확인한다 | 설정을 바꿀 때 `WidgetCenter.reloadAllTimelines` 를 부른다 |
| A7 | 확장이 `WidgetScenes` 를 물어도 위젯 확장 메모리 한도(약 30MB)에 안 걸린다. `CalendarScenes` 를 떼는 만큼 상쇄된다 | DP-1.1 에서 실기로 배치하고, DP-4.1 에서 갤러리가 들어간 뒤 다시 본다 | 갤러리 Scene 을 별도 모듈로 떼고 `WidgetScenes` 엔 뷰만 남긴다 |
| A8 | `SettingScene` → `Scenes` 프로토콜 → `WidgetScenes` 배선이 기존 Scene 간 참조 패턴대로 된다 | `Scenes+Setting.swift` 서식을 따라 DP-4.1 에서 만든다 | 갤러리를 `SettingScene` 안에 두고 뷰만 `WidgetScenes` 에서 가져다 쓴다 |
| A9 | 신규 위젯을 무료로 풀어도 Pro 가치가 안 죽는다. Pro 가 파는 건 전 위젯 꾸미기 깊이다 | 출시 후 지표로 본다 | 위젯 자체를 잠그는 쪽으로 되돌린다. 계획을 개정한다 |

## 9. 위험

| 위험 | 영향 LOE | 수용·완화·회피 | 근거 |
|---|---|---|---|
| 표시 모델 넷이 `MonthViewModel.swift` 에 섞여 있어서 떼어내다 Month 화면이 깨진다 | LOE-1 | 완화 — DP-2.1 에서 떼어내는 커밋과 옮기는 커밋을 나눈다. Month Scene 테스트가 그물이다 | `MonthViewModel.swift:19`·`:53`·`:98` 에 세 개가, `WeekEventStackBuilder.swift:17` 에 하나가 있다 |
| `EventCellViewModel` 이 준수 타입 7개를 거느린 프로토콜이라 이동 범위가 파일 하나를 넘는다 | LOE-1 | 완화 — DP-2.1 착수 전에 참조처를 전수 조사해 작전명령에 목록으로 싣는다 | `EventCellViewModel.swift:165` 아래 `Todo`·`PendingTodo`·`GuideTodo`·`Schedule`·`Holiday`·`AppleCalendar`·`GoogleCalendar` 가 준수한다 |
| 배경을 순수 뷰 안으로 옮겼는데 확장에서 컨테이너 배경과 겹쳐 모양이 바뀐다 | LOE-1 | 완화 — DP-1.1 완료 판정에 이관 전후 스냅샷 대조를 넣는다 | `DDayWidget.swift:262` 가 `.containerBackground(entry.backgroundShape, for: .widget)` 를 부른다 |
| 파일을 쪼개다 접근 제어가 어긋난다. `private struct DDayTitleView` 처럼 같은 파일이라 보이던 타입이 안 보이게 된다 | LOE-1 | 완화 — 쪼개는 커밋과 옮기는 커밋을 나눈다. 쪼갠 뒤 확장 빌드가 통과하는 걸 먼저 확인한다 | `DDayWidget.swift:19` 가 `private struct DDayTitleView` 다 |
| 글자크기 조정을 키우면 작은 패밀리에서 레이아웃이 넘친다 | LOE-3 | 완화 — DP-5.2 에서 축의 상하한을 패밀리별로 자르고, 스냅샷으로 극단값을 찍어본다 | 위젯 캔버스가 small 170×170 로 고정이다 (`WidgetCatalogSnapshots.swift`) |
| 타임라인 위젯이 PR 하나를 넘긴다. 축 산출·겹침 배치·패밀리 둘·Intent 연결이 한 DP 에 있다 | LOE-2 | 완화 — opord 에서 커밋 시퀀스를 계산·뷰·등록으로 나눈다. 그래도 넘치면 DP 를 쪼개는 계획 개정으로 간다 | #751 플랜이 1692줄 44 체크박스다 |
| 프레임워크 둘을 신설하니 스킴 하드코딩 짝을 두 번 맞춰야 한다. 한쪽만 넣으면 감지만 되고 실행이 안 된다 | 검증 | 완화 — DP-1.1·DP-2.1 각각 add-framework 스킬 절차를 탄다 | CLAUDE.md §1 짝규칙 |
| 프리셋·조정 문구와 갤러리 위젯 이름이 31개 로케일 짝을 요구한다 | 품질 | 완화 — `check-localization-parity.py` 로 확인하고 `localization` 라벨 최신 열린 이슈에 등록한다 | `.claude/rules/localization.md` §1 |

## 10. 자원

| 단계 | 주노력 자원 | 부노력 자원 |
|---|---|---|
| 1~6 | 순차로 한 세션이 간다. DP 마다 앞 DP 의 계약(C1~C4)을 입력으로 받는다 | 유저 시간 — DP 마다 작전명령 재가. DP-1.1·DP-2.3·DP-5.1 은 실기 확인도 필요하다 |

DP 가 9개라 이전보다 길다. 그래도 병렬 슬롯은 안 둔다. DP 마다 재가 게이트가 있어 병렬 이득이 작고, DP-2.x 는 같은 계약을 반복 적용하는 줄이라 소유 범위가 `WidgetScenes` 에서 계속 겹친다.

외부 계정이나 심사에 안 걸린다. 워크트리는 지금 쓰는 `southpaw` 하나로 충분하다.

## 11. 평가

**MOP** — DP 종결보고 1항으로 본다. 소유 범위 안에서 작전명령 최종상태를 채웠나.

**MOE**

- LOE-1 — 갤러리 미리보기와 확장 실물이 같은 뷰 타입에서 나오나. 코드 경로를 보고 스냅샷으로 대조한다. `WidgetScenes` 의 WidgetKit·`CalendarScenes` 의존 0건과, 확장의 `CalendarScenes` 의존 0건이 유지되나.
- LOE-2 — 신규 위젯이 홈에 실제로 놓이고 갱신되나.
- LOE-3 — 갤러리 목록이 `Widget` 선언 수와 맞나. 갤러리에서 바꾼 값이 홈 위젯에 반영되나. 프리셋과 조정이 `requiresPro` 로 갈리나.

**평가 시점** — DP 종결보고를 받을 때(PR 생성), 그리고 단계가 바뀔 때.

## 12. 위임

delegation.md 를 상속한다. 좁히는 것만 적는다.

| 사안 | 등급 |
|---|---|
| 프레임워크 신설, Tuist 매니페스트·스킴 하드코딩 변경 | 사전승인 — DP-1.1·DP-2.1 이 이걸 전제로 해서 명시한다 |
| `WidgetScenes`·`CalendarPresentation` 의존 목록에 모듈을 더하는 것 | 사전승인 — C1 이 `CalendarScenes`·WidgetKit 을 막는다 |
| 위젯 뷰를 옮기면서 모양이나 동작을 바꾸는 것 | 사전승인 — 옮기기는 그대로 옮기는 게 원칙이다 |
| `CalendarPresentation` 으로 내리는 대상을 더하거나 빼는 것 | 사전승인 — 남의 도메인 공개 API 다 |
| C1~C4 계약을 바꾸는 것 | 사전승인 — 계획을 개정할 사안이다 |
| 갤러리 Scene 내부 구성, 순수 뷰 내부 구현, 조정 축의 상하한 값 | 자율 |

## 13. 상시 제한

**해야**

- 기존 위젯의 기본 모양과 동작을 그대로 둔다. 꾸미기를 안 건드린 상태는 지금과 같아야 한다. #721 이 "기존 유저 것을 안 빼앗는다" 를 확정사항으로 박아놨다.
- 뷰를 옮길 땐 옮기기만 한다. 옮기는 커밋에 개선을 섞지 않는다.
- 쪼개는 커밋과 옮기는 커밋을 나눈다 (C1).
- `WidgetScenes` 에서 WidgetKit 과 `CalendarScenes` 를 안 문다 (C1).
- 조정 축은 environment 와 공통 modifier 로 건다. 위젯 뷰를 하나씩 고쳐 반영하지 않는다 (C3).
- `SettingScene` 은 `Scenes` 프로토콜로만 갤러리를 부른다 (C4).
- CommonPresentation 컴포넌트를 새로 만들면 `.claude/rules/presentations-rules.md` §2 카탈로그에 올린다.

**하지 말아야**

- paywall 을 부르거나 구매를 검증하거나 잠금 뱃지를 붙이지 않는다. 과금 트랙이 할 일이고, 손대면 #899 라는 외부 게이트에 이 캠페인이 묶인다.
- 신규 위젯을 Pro 로 잠그지 않는다. 1항에서 범위 밖으로 뺐다.
- `ResultTimelineEntry` 를 안 바꾼다. 아직 안 옮긴 위젯이 그 경로를 쓴다 (C2).
- 잠금화면 위젯을 새로 만들지 않는다. #741 로 충분하다.
- `CalendarEventFetchUsecase`·`EventTypeSelectIntent`·`EventDeepLinkBuilder`·`Date.nextUpdateTime` 의 동작을 안 바꾼다. import 경로 조정은 예외다.

## 14. 상시 즉시보고 조건

- **기본** — 제한이나 위임을 판단해야 하는데 rules 에 조항이 없으면 하네스 갭으로 기록한다.
- **FFIR** — 표시 모델을 뽑았는데도 `WidgetScenes` 가 `CalendarScenes` 를 물어야 한다 (C1 붕괴).
- **FFIR** — 확장의 `CalendarScenes` 참조에 표시 모델 아닌 게 섞여 있다 (A3 붕괴).
- **FFIR** — 표시 모델을 내렸더니 `CalendarScenes` 나 `EventListScenes` 가 깨진다 (A2 붕괴).
- **FFIR** — 순수 뷰가 WidgetKit 을 안 쓰고는 그려지지 않는다 (C1 붕괴).
- **FFIR** — 이관 전후 스냅샷이 달라진다 (A1 붕괴).
- **FFIR** — 조정 축이 공통 modifier 로는 안 걸려 위젯 뷰를 개별로 고쳐야 한다 (A4 붕괴).
- **FFIR** — `SettingScene` 이 `WidgetScenes` 를 직접 물지 않고는 진입을 못 만든다 (A8·C4 붕괴).
- **FFIR** — #751 플랜의 축 산출·겹침 배치가 지금 develop 과 안 맞는다 (A5 붕괴).
- **PIR** — 위젯 확장 메모리나 바이너리가 한도에 걸릴 낌새가 보인다 (A7 붕괴).

## 15. 원장

`.operations/721/campaign-progress.md` 에 둔다. 이슈 본문의 `<!-- progress -->` 블록으로 미러한다.
