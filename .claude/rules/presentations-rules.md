---
description: Presentations·App 타겟에서 Scene·SwiftUI 뷰 작성 시 지킬 규칙
paths:
  - "Presentations/**"
  - "TodoCalendarApp/**"
---

# Presentations 레이어 규칙

새 Scene 또는 View를 만들거나 기존 Scene을 수정할 때 아래 원칙을 따른다.

## 1. ViewAppearance 기반 색상·폰트

앱 전체가 `ViewAppearance`로 테마(다크/라이트/사용자 색상)와 폰트 스케일을 일관되게 바꿀 수 있도록 설계돼 있다. 하드코딩된 값은 테마를 따르지 않아 UI 일관성을 깨뜨린다.

- **환경 주입 필수**:
  ```swift
  @Environment(ViewAppearance.self) private var appearance
  ```
- **색상: SwiftUI 기본값·시스템 색상·하드코딩 금지.**
  - `.blue`, `.secondary`, `Color.white`, `Color(.systemBackground)` → ❌
  - `appearance.colorSet.{bg0|bg1|bg2|text0|text1|primaryBtnBackground|primaryBtnText|secondaryBtnBackground|secondaryBtnText|...}.asColor` → ✅
- **폰트: 시스템 폰트 금지.**
  - `.font(.headline)`, `.font(.system(size: 14))` → ❌
  - `appearance.fontSet.{bigBold|normal|...}.asFont` → ✅

## 2. 공용 컴포넌트 재사용

`CommonPresentation` 프레임워크의 공용 컴포넌트를 먼저 찾아보고 재사용한다.

- 커스텀 `Button { ... } label: { ... }` 블록 작성 금지.
  ```swift
  ConfirmButton(
      title: "common.update".localized(),
      textColor: appearance.colorSet.primaryBtnText.asColor,
      backgroundColor: appearance.colorSet.primaryBtnBackground.asColor
  )
  .eventHandler(\.onTap) { ... }
  ```
- 그 외 공용 컴포넌트(`BottomConfirmButton`, `BottomSlideView`, `CloseButton`, `DescriptionView` 등)도 기존 사용처 참조 후 재사용.
- `import CommonPresentation` 누락 주의.

## 3. Scene 구조 (6개 파일)

새 Scene 추가 시 템플릿 기반 6개 파일 패턴을 따른다.

```
XXXScene+Builder.swift    — Scene/Interactor/Listener/Builder 프로토콜
XXXViewModel.swift        — VM 프로토콜 + Imple (Subject struct로 상태 관리)
XXXViewController.swift   — UIHostingController 래퍼 (SwiftUI 시)
XXXRouter.swift           — BaseRouterImple 상속, 화면 전환 담당
XXXBuilderImple.swift     — 의존성 조립 (UsecaseFactory + ViewAppearance 주입)
XXXView.swift             — ViewState + ViewEventHandler + ContainerView + View
```

세부 템플릿·생성 순서·UsecaseFactory 구조는 `docs/scene-spec.md` 참조.

## 4. SwiftUI View 의존 주입 구조

ContainerView + `@Environment` 패턴을 일관되게 따른다. ViewModel을 View에 직접 참조시키지 않는다.

### ContainerView 책임

- `ViewState`는 `@State`로 **ContainerView 내부에서 생성**. 외부에서 만들어 주입받지 말 것.
- `ViewAppearance`, `ViewEventHandler`(+ 필요 시 custom provider·자식 ContainerView)는 **init property**로 수용.
- body에서 `.environment(state)`, `.environment(eventHandlers)`, `.environment(viewAppearance)`로 자식에 전파.
- `stateBinding: (XxxViewState) -> Void = { _ in }` 콜백 선언. `onAppear`에서 호출. ViewController가 이 콜백에 `{ $0.bind(viewModel) }`를 주입해 VM ↔ State 연결.

```swift
struct XxxContainerView: View {

    @State private var state: XxxViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: XxxViewEventHandler

    var stateBinding: (XxxViewState) -> Void = { _ in }

    init(
        viewAppearance: ViewAppearance,
        eventHandlers: XxxViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }

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

### View 책임

- `ViewState` / `ViewEventHandler` / `ViewAppearance`는 **`@Environment`로만** 주입받음 — init property로 받지 말 것.
- ViewModel은 절대 View가 직접 참조하지 않음. State와 EventHandler가 중개.
- 환경값이 아닌 custom provider(예: `SignInButtonProvider`)나 자식 ContainerView는 init property로 받아도 됨.

```swift
struct XxxView: View {

    @Environment(XxxViewState.self) private var state
    @Environment(XxxViewEventHandler.self) private var eventHandlers
    @Environment(ViewAppearance.self) private var appearance

    var body: some View { ... }
}
```

### 금지 패턴 (drift)

- `@StateObject var viewModel: XxxViewModel` — View가 ViewModel 직접 소유 ❌
- `@ObservedObject var viewModel: XxxViewModel` — 위와 동일 ❌
- `@EnvironmentObject` — 레거시. `@Environment(Type.self)` 사용
- ContainerView 외부에서 ViewState를 만들어 `init(viewState:)`로 주입 ❌ — 반드시 ContainerView 내부 `@State`

## 5. ViewModel 책임 경계

### Navigation은 Router 경유
ViewModel이 직접 화면 전환(present/push/dismiss)을 호출하지 말 것. **반드시 Router**.

```swift
// ❌ ViewModel 내부
UIApplication.shared.topViewController?.present(...)

// ✅ ViewModel 내부
self.router?.routeToSomewhere(param)
```

Router는 `BaseRouterImple`를 상속하고 `XxxRouting` 프로토콜을 구현한다. `BaseRouterImple`이 공통 메서드(`showError`, `showToast`, `closeScene`, `showConfirm`, `showActionSheet`, `openSafari`, `showBottomSlide`, `dismissPresented`)를 제공하므로 먼저 재사용.

### SwiftUI 타입 직접 참조 금지
ViewModel에 `@Published`, `ObservableObject`, `@StateObject` 등 SwiftUI 전용 구조 직접 참조 금지. 상태 노출은 **Combine `AnyPublisher`**로, SwiftUI 전용 변환은 `ViewState`가 담당.

```swift
// ❌ ViewModel 안
@Published var title: String = ""

// ✅ ViewModel 안
private let subject = Subject()  // CurrentValueSubject/PassthroughSubject
var title: AnyPublisher<String, Never> { subject.title.eraseToAnyPublisher() }
```

**이유:** ViewModel이 SwiftUI에 결합되면 Preview에서 fake VM을 만들기 어렵고, 테스트도 어려워진다. 현재 구조는 ViewState만 직접 설정해 Preview/테스트 가능.

## 6. Scene 간 통신 (Interactor / Listener)

### Parent → Child: Interactor (strong)
Parent ViewModel이 Child Scene의 `Interactor`를 보관하고 호출. **strong 참조** (parent가 child 소유 관계이므로).

```swift
// Parent ViewModel
private var childInteractor: (any XxxSceneInteractor)?
```

### Child → Parent: Listener (**weak**)
Child ViewModel이 Listener를 **반드시 `weak`**로 보관. retain cycle 방지.

```swift
// Child ViewModel
weak var listener: (any XxxSceneListener)?
```

- Parent가 Child 생성 시 자기 자신을 Listener로 전달하고, Parent는 `XxxSceneListener` 프로토콜을 conform한다.
- Delegate 패턴 대체. `weak` 누락은 메모리 누수로 이어지므로 절대 놓치지 말 것.

## 7. Presentation 모듈 간 직접 import 금지

Presentation 모듈끼리 서로 **`import CalendarScenes`, `import EventDetailScene`** 등으로 직접 참조하지 **말 것.**

모듈 경계를 넘나드는 Scene 참조는 `Scenes` 프레임워크의 공유 프로토콜로만 가능:

| 파일 | 포함 프로토콜 |
|---|---|
| `Scenes/Sources/Scenes+Calendar.swift` | CalendarScene, SelectDayDialogScene |
| `Scenes/Sources/Scenes+EventDetail.swift` | EventDetailScene, HolidayEventDetailScene, GoogleCalendarEventDetailScene, DoneTodoDetailScene |
| `Scenes/Sources/Scenes+EventList.swift` | DoneTodoEventListScene |
| `Scenes/Sources/Scenes+Member.swift` | SignInScene, ManageAccountScene |
| `Scenes/Sources/Scenes+Setting.swift` | SettingItemListScene, EventTagDetailScene 등 |

- 다른 모듈에서 참조가 필요한 새 Scene 프로토콜은 위 파일들에 추가.
- 모듈 내부에서만 쓰이는 Scene 프로토콜은 해당 모듈 내 `XxxScene+Builder.swift`에 둔다.

**Why:** 모듈 간 결합을 끊어 빌드 시간과 순환 의존을 관리. 공유 인터페이스만 노출해 구현 디테일 숨김.
