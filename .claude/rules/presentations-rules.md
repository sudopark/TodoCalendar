---
description: Presentations·App 타겟에서 Scene·SwiftUI 뷰 작성 시 지킬 규칙
paths:
  - "Presentations/**"
  - "TodoCalendarApp/**"
---

# Presentations 레이어 규칙

## 1. ViewAppearance 기반 색상·폰트

테마(다크/라이트/사용자 색상)와 폰트 스케일을 일관되게 바꾸기 위해 `ViewAppearance`로 통일. 하드코딩 값은 일관성을 깨뜨림.

- 환경 주입: `@Environment(ViewAppearance.self) private var appearance`
- **색상**: `appearance.colorSet.{bg0|text0|primaryBtnBackground|...}.asColor` ✅. SwiftUI 기본값(`.blue`, `.secondary`), 시스템 색상(`Color(.systemBackground)`), 하드코딩 ❌.
- **폰트**: `appearance.fontSet.{bigBold|normal|...}.asFont` ✅. 시스템 폰트(`.font(.headline)`, `.system(size:)`) ❌.

## 2. 공용 컴포넌트 재사용

새 UI 요소 작성 전 아래 카탈로그를 먼저 확인하고 재사용. 커스텀 `Button { ... } label: { ... }` 블록 작성 금지.

### CommonPresentation 컴포넌트 카탈로그

전부 `CommonPresentation/Sources/UIComponents/` 소속. `import CommonPresentation` 누락 주의.

| 컴포넌트 | 역할 | 이벤트 연결 |
|---|---|---|
| `ConfirmButton` | 표준 액션 버튼 — isEnable·isProcessing(로딩) 내장, 색 nil→appearance 폴백 | `.eventHandler(\.onTap)` |
| `BottomConfirmButton` | 화면 하단 고정 ConfirmButton 래퍼 (패딩+배경+safe-area) | `.eventHandler(\.onTap)` |
| `BottomSlideView` | 바텀시트 컨테이너 — 딤 영역 + 제네릭 content. 딤 탭 닫기는 자동 아님(아래 참고) | `.eventHandler(\.outsideTap)` |
| `SheetHeaderView` | 시트 상단 헤더 — 타이틀+닫기, iOS26 리퀴드 글래스 분기 | `.eventHandler(\.onClose)` |
| `CloseButton` | `xmark.circle.fill` 닫기 버튼 | `.eventHandler(\.onTap)` |
| `NavigationBackButton` | chevron 커스텀 뒤로가기 | `init(tapHandler:)` 클로저 |
| `DescriptionView` | 불릿(•) 안내문 목록 | 없음 (표시 전용) |
| `ColorSelectView` | 그라데이션 링 + 숨김 ColorPicker 색상 선택 도트 | `.eventHandler(\.colorSelected)` |
| `EventTagColorView` | 태그/외부캘린더 색 해석 전담 — content 클로저에 Color 전달 | render-prop `content: (Color) -> View` |
| `FullScreenLoadingView` | 반투명 로딩 오버레이 (스피너+메시지) | 없음 |
| `LoadingCircleView` | 회전 스피너 프리미티브 (ConfirmButton·FullScreenLoading이 재사용) | 없음 |
| `RemoteImageView` | Kingfisher 원격 이미지 — 다운샘플·캐시 | 체이닝 modifier (`resize` 등) |
| `VoiceWaveformView` | 음성 입력 레벨 파형 바 | 없음 |
| `LandmarkMapView` | 단일 마커 지도 (비인터랙티브) | 없음 |
| `SignInButtonProvider` | OAuth 로그인 버튼 팩토리 (프로토콜 — §4 custom provider 선례) | init property 주입 |
| `BillingPlanChipView` | 플랜 이름 칩 — 무료 회색/유료 accentAI (사용량 게이지·paywall 공유, #739) | 없음 (표시 전용) |
| `BillingScheduledChangeView` | 하향·만료 예정 안내 한 줄 — info 아이콘 + "N월 d일부터 X 플랜" (사용량 게이지·paywall 공유, #852) | 없음 (표시 전용) |
| `ImagePicker` | 사진 라이브러리(PHPicker)·카메라 피커 뷰컨트롤러 팩토리 — 선택 결과를 `Data`로 전달 | `makeViewController(source:onPick:)` 클로저 |
| `InAppWebViewController` | 인앱 웹뷰 화면 (UIKit) — 진행바·문서 타이틀·뒤로/앞으로·브라우저로 열기 + 로드 실패 폴백 (#806) | 모달은 `BaseRouterImple.showWebView(_:)` / `init` = push·child VC |
| `AdViewBuilder` | 배너 광고 뷰 팩토리 (프로토콜 — placement로 요청, 구현체는 앱 타겟. 씬은 SDK를 모른다, #898) | `makeBannerView(for:)` / `makeBannerUIView(for:)` |
| `FullScreenAdRouter` | 전면 광고 노출 커맨드 (프로토콜 — 씬 Router가 재위임, 구현체는 앱 타겟, #898) | `showFullScreenAd(from:)` |
| `PrivacyOptionsFormRouter` | UMP 개인정보 옵션 폼 진입점 (프로토콜 — 요구 여부 조회 + 폼 표시, 구현체는 앱 타겟, #958) | `isPrivacyOptionsRequired()` / `showPrivacyOptionsForm(from:)` |

- 이벤트 연결 주류는 `.eventHandler(\.키패스)` (기본값 있는 var 클로저) — 신규 컴포넌트도 이 패턴으로. 표의 예외(init 클로저·render-prop·체이닝)는 기존 API 존중.
- **컴포넌트를 새로 만들었으면 같은 커밋에서 이 표에 한 줄 추가한다** (CLAUDE.md §1 짝 규칙). 등재 안 된 컴포넌트는 다음 사람이 못 찾아 같은 걸 또 만든다.
- 읽는 쪽에서도 카탈로그가 낡았을 수 있다 — `ls Presentations/CommonPresentation/Sources/UIComponents/`로 실물 확인. 표에 없는 파일을 발견하면 이 표를 갱신한다.

#### BottomSlideView — 딤 영역 탭 닫기는 수동 배선

`BottomSlideView`를 쓰는 시트는 **`.eventHandler(\.outsideTap, ...)`를 직접 걸어야 딤 영역 탭에 닫힌다.** 안 걸면 no-op이라 아무 반응이 없다. 닫힘 동작은 다른 닫기 경로(헤더 X·닫기 버튼)와 같은 핸들러로 — ViewModel의 `close()` → `router.closeScene()` (rules §5 Navigation은 Router 경유).

```swift
BottomSlideView { ... }
    .eventHandler(\.outsideTap, eventHandlers.close)   // ← 없으면 딤 탭에 안 닫힘
```

- 반대로 **딤 탭에 닫히면 안 되는 시트**(진행 중 이탈이 위험한 경우 등)는 배선을 걸지 않는다 — 배선 여부가 곧 옵션이다.
- SwiftUI `@Environment(\.dismiss)`로 닫으려 하지 말 것. 이 시트들은 UIKit `present()`로 띄운 `UIHostingController`라 SwiftUI가 표시 주체를 몰라 no-op이다.

### 프레임워크 스코프 컴포넌트

- 한 프레임워크 안에서 2곳 이상이 공유하는 뷰는 전용 폴더에 격리: `Sources/Common/`(CalendarScenes 선례) 또는 `Sources/Components/`. Scene 폴더 안에 두지 말 것 — 배치와 사용처가 어긋난다.
- 프레임워크 스코프 컴포넌트는 **해당 프레임워크 child CLAUDE.md에 기록**한다. 새 화면 작업 전 child CLAUDE.md의 컴포넌트 목록도 확인.
- 유사 구현이 여러 프레임워크에서 반복되면 CommonPresentation 승격을 유저와 협의 (선례: AIAgentSheetHeader → SheetHeaderView).

## 3. Scene 구조 (6파일)

```
XXXScene+Builder.swift    — Scene/Interactor/Listener/Builder 프로토콜
XXXViewModel.swift        — VM 프로토콜 + Imple (Subject struct로 상태 관리)
XXXViewController.swift   — UIHostingController 래퍼 (SwiftUI 시)
XXXRouter.swift           — BaseRouterImple 상속, 화면 전환
XXXBuilderImple.swift     — 의존성 조립 (UsecaseFactory + ViewAppearance 주입)
XXXView.swift             — ViewState + ViewEventHandler + ContainerView + View
```

세부 템플릿·생성 순서·UsecaseFactory: `docs/scene-spec.md`.

### Scene 폴더 조직

- Scene 개수와 무관하게 **한 Scene = 한 폴더** — 프레임워크에 Scene이 하나뿐이어도 `Sources/<SceneName>/` 폴더를 만들고 시작한다. 화면군이 생기면 화면군 폴더 밑에 Scene 폴더 중첩 (예: SettingScene의 `EventTag/EventTagDetail/`).
- 기존 플랫 배치(예: AIAgentScene)는 일괄 이동 금지 — 그 프레임워크에 Scene을 추가하는 기회에 함께 폴더화.
- `Tests/`는 `Sources/`와 같은 트리로 미러링 (testability.md §8).

## 4. SwiftUI 의존 주입

ContainerView + `@Environment` 패턴. **ViewModel을 View에 직접 참조시키지 말 것.**

### ContainerView
- `ViewState`는 `@State`로 **ContainerView 내부에서 생성**. 외부 주입 ❌.
- `ViewAppearance`, `ViewEventHandler`는 init property로 수용.
- body에서 `.environment(state)` / `.environment(eventHandlers)` / `.environment(viewAppearance)`로 자식에 전파.
- `stateBinding: (XxxViewState) -> Void = { _ in }` 콜백을 `onAppear`에서 호출. ViewController가 `{ $0.bind(viewModel) }`를 주입해 VM ↔ State 연결.

```swift
struct XxxContainerView: View {
    @State private var state: XxxViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: XxxViewEventHandler
    var stateBinding: (XxxViewState) -> Void = { _ in }

    var body: some View {
        XxxView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .environment(state)
            .environment(eventHandlers)
            .environment(viewAppearance)
    }
}
```

### View
- `ViewState` / `ViewEventHandler` / `ViewAppearance`는 **`@Environment`로만** 주입. init property 금지.
- ViewModel을 View가 직접 참조하지 않음. State와 EventHandler가 중개.
- 환경값이 아닌 custom provider(`SignInButtonProvider` 등) / 자식 ContainerView는 init property로 받아도 됨.

### 금지 패턴 (drift)
- `@StateObject` / `@ObservedObject` viewModel — View가 ViewModel 직접 소유 ❌
- `@EnvironmentObject` — 레거시. `@Environment(Type.self)` 사용
- ContainerView 외부에서 ViewState 만들어 `init(viewState:)` 주입 ❌

### 조건부 표시 child view는 분기 시점에 생성

stage·상태로 분기되어 보여지는 child view는 부모에서 **미리 만들어 넘기지 말 것.** 분기(`switch`) 시점에 생성해, 그 뷰가 나타날 때 ViewState 바인딩(`onAppear`)도 시작한다.

부모 View는 ViewModel을 직접 참조하면 안 되므로(§4), vm·eventHandler를 보유한 **builder/provider를 init property로 주입**받아 분기 시점에 `make...View()`를 호출한다.

```swift
// builder가 vm·eventHandler 보유, View는 builder만 주입받음
struct XxxStageViewBuilder {
    @MainActor func makeInputView() -> some View {
        XxxInputContainerView(viewAppearance:, eventHandlers:)
            .eventHandler(\.stateBinding, { $0.bind(inputViewModel) })
    }
}
// 부모 View body
switch state.stage {
case .input:   builder.makeInputView()   // ← 이 시점에 생성 + 바인딩
case .command: builder.makeCommandView()
}
```

선례: `SignInButtonProvider`, `AIAgentStageViewBuilder`.

**Why:** 안 보이는 stage의 뷰·구독을 upfront로 띄우면 불필요한 바인딩/리소스. 분기 시점 생성으로 lazy 보장 + 코드상 "이 뷰는 이 stage에서만 산다"가 드러난다.

## 5. ViewModel 책임 경계

### Navigation은 Router 경유
```swift
❌ UIApplication.shared.topViewController?.present(...)
✅ self.router?.routeToSomewhere(param)
```

Router는 `BaseRouterImple` 상속 + `XxxRouting` 채택. 공통 메서드(`showError`, `showToast`, `closeScene`, `showConfirm`, `showActionSheet`, `openSafari`, `showWebView`, `showBottomSlide`, `dismissPresented`)는 먼저 재사용.

### SwiftUI 타입 직접 참조 금지
ViewModel에 `@Published` / `ObservableObject` / `@StateObject` ❌. 상태 노출은 **Combine `AnyPublisher`**, SwiftUI 변환은 `ViewState`가 담당.

```swift
❌ @Published var title: String = ""
✅ private let subject = Subject()
✅ var title: AnyPublisher<String, Never> { subject.title.eraseToAnyPublisher() }
```

**Why:** ViewModel이 SwiftUI에 결합되면 Preview·테스트가 어려워진다. 현 구조는 ViewState만 직접 설정해 Preview/테스트 가능.

### 여러 상태 합성은 선언적으로 (CombineLatest)

둘 이상의 상태(예: 입력 모드 × orchestrator 상태)를 합쳐 하나의 출력을 내야 하면, mutable `var`를 손으로 갱신하고 변화마다 통지 메서드(`resolveAndNotify()` 류)를 수동 호출하지 말 것. 각 상태를 `Subject`의 `CurrentValueSubject`로 두고 `CombineLatest(...).map`으로 한 곳에서 합성한다. orchestrator 같은 외부 스트림을 로컬 `subject`에 미러링할 땐 `handleEvents(receiveOutput:)`로 (CQS — 합성 query와 side effect 분리).

```swift
private struct Subject {
    let inputMode = CurrentValueSubject<InputMode?, Never>(nil)
    let state = CurrentValueSubject<AIAgentState?, Never>(nil)
}
✅ Publishers.CombineLatest(subject.inputMode, subject.state)
       .map { Self.resolveEntryMode(input: $0, state: $1) }   // 순수 합성
       .sink { [weak self] in self?.listener?.didChangeMode($0) }
❌ private var inputMode; private var latestState   // mutable var 2개
   // enter/stop/handle/구독마다 resolveAndNotify() 수동 호출 → 한 곳만 빠뜨려도 통지 누락
```

**Why:** 명령형 수동 통지는 호출 자리 중 하나만 빠뜨려도 누락이 생긴다. 선언적 합성은 어느 축이 바뀌든 자동 재계산돼 빠뜨릴 자리가 없고, 합성 함수가 순수해 테스트도 쉽다. 코드베이스 다수 VM이 이 패턴(`Subject` + `CombineLatest`).

## 6. Scene 간 통신

- **Parent → Child: Interactor (strong)** — Parent VM이 보관. 소유 관계.
  ```swift
  private var childInteractor: (any XxxSceneInteractor)?
  ```
- **Child → Parent: Listener (weak)** — Child VM이 **반드시 `weak`**. retain cycle 방지.
  ```swift
  weak var listener: (any XxxSceneListener)?
  ```
- Parent가 Child 생성 시 자기 자신을 Listener로 전달, Parent는 `XxxSceneListener` 채택. `weak` 누락은 메모리 누수.

## 7. Presentation 모듈 간 직접 import 금지

`import CalendarScenes`, `import EventDetailScene` 등 모듈 간 직접 참조 ❌. `Scenes` 프레임워크 공유 프로토콜로만:

| 파일 | 포함 프로토콜 |
|---|---|
| `Scenes/Sources/Scenes+Calendar.swift` | CalendarScene, SelectDayDialogScene |
| `Scenes/Sources/Scenes+EventDetail.swift` | EventDetailScene, HolidayEventDetailScene, GoogleCalendarEventDetailScene, DoneTodoDetailScene |
| `Scenes/Sources/Scenes+EventList.swift` | DoneTodoEventListScene |
| `Scenes/Sources/Scenes+Member.swift` | SignInScene, ManageAccountScene |
| `Scenes/Sources/Scenes+Setting.swift` | SettingItemListScene, EventTagDetailScene 등 |

다른 모듈에서 참조 필요한 신규 Scene 프로토콜은 위 파일에 추가. 모듈 내부 전용은 해당 모듈 `XxxScene+Builder.swift`.

**Why:** 모듈 간 결합을 끊어 빌드 시간·순환 의존을 관리. 공유 인터페이스만 노출해 구현 디테일 숨김.

## 8. 룩앤필 — 메트릭·그림자·모션

### 메트릭 토큰

corner radius·spacing에 숫자 하드코딩 ❌ → `Metric` 상수 ✅ (CommonPresentation 소속, 테마 무관 고정값이라 ViewAppearance 주입 아님):

- `Metric.Radius.{chip|regular|large|sheet}` = 4 / 8 / 12 / 16 — 칩·뱃지 / 카드·버튼 / 큰 카드·팝업 / 바텀시트·모달
- `Metric.Spacing.{xxsmall|xsmall|small|regular|large|xlarge|indent}` = 2 / 4 / 8 / 12 / 16 / 20 / 32 — `indent`는 계층 들여쓰기(leading) 전용
- **padding은 토큰 오버로드로**: `.padding(.top, spacing: .regular)` / `.padding(spacing: .xlarge)` (`View.padding(_:spacing:)`, `Metric.SpacingToken`) — 시스템 `.padding`에 숫자·CGFloat 직접 전달 금지. `Metric.Spacing` 상수는 stack `spacing:` 파라미터처럼 CGFloat가 필요한 자리에만.
- **Presentations 6개 프레임워크는 #674로 토큰 마이그레이션 완료** (CommonPresentation·AIAgentScene·MemberScenes·EventDetailScene·SettingScene·CalendarScenes·EventListScenes). 신규·수정 코드는 숫자 하드코딩 없이 처음부터 토큰으로. 미완: `TodoCalendarApp/**`(위젯·앱 타겟) — 스냅샷 게이트 불가라 후속.
- **제외값 정책 (토큰화 안 함)**: 값 `0`(간격 없음)·`1`·소수(`0.5` 등)·radius `≤3`(장식 프리미티브)·대표값과 차이 `>2`(토큰 격자 밖, 예: 24·40·120)은 숫자 그대로 둔다. 그 밖의 값은 ±2 이내 가장 가까운 대표값으로 스냅 (미세 시각 변화 허용).
- 대표값에 없는데 격자 안(±2)도 아닌 값이 반복 등장하면 임의 숫자를 박지 말고 유저와 협의해 토큰을 추가한다.

### 그림자·모션

- **그림자 지양** — 앱은 플랫 톤. 예외는 설정 미리보기류의 시각 강조뿐.
- **모션 절제** — 상태 전환에 필요한 최소한(easeInOut 계열)만. 장식적 애니메이션 금지.
