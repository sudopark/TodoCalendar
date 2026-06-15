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

`CommonPresentation`의 공용 컴포넌트를 먼저 찾아 재사용. 커스텀 `Button { ... } label: { ... }` 블록 작성 금지.

```swift
ConfirmButton(
    title: "common.update".localized(),
    textColor: appearance.colorSet.primaryBtnText.asColor,
    backgroundColor: appearance.colorSet.primaryBtnBackground.asColor
)
.eventHandler(\.onTap) { ... }
```

기타: `BottomConfirmButton`, `BottomSlideView`, `CloseButton`, `DescriptionView` 등. `import CommonPresentation` 누락 주의.

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

Router는 `BaseRouterImple` 상속 + `XxxRouting` 채택. 공통 메서드(`showError`, `showToast`, `closeScene`, `showConfirm`, `showActionSheet`, `openSafari`, `showBottomSlide`, `dismissPresented`)는 먼저 재사용.

### SwiftUI 타입 직접 참조 금지
ViewModel에 `@Published` / `ObservableObject` / `@StateObject` ❌. 상태 노출은 **Combine `AnyPublisher`**, SwiftUI 변환은 `ViewState`가 담당.

```swift
❌ @Published var title: String = ""
✅ private let subject = Subject()
✅ var title: AnyPublisher<String, Never> { subject.title.eraseToAnyPublisher() }
```

**Why:** ViewModel이 SwiftUI에 결합되면 Preview·테스트가 어려워진다. 현 구조는 ViewState만 직접 설정해 Preview/테스트 가능.

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
