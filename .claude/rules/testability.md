---
description: 테스트 프레임워크·테스트 더블·검증 원칙의 단일 가이드. production 코드를 테스트 때문에 훼손하지 않는다.
paths:
  - "Domain/**"
  - "Repository/**"
  - "Presentations/**"
---

# 테스트 작성 규칙

production 코드는 테스트 때문에 훼손하지 않는다.

## 1. 테스트 프레임워크

두 프레임워크를 상황에 따라 사용한다.

- **XCTest** — 기존 테스트 대다수. `UnitTestHelpKit.BaseTestCase` 상속. `setUpWithError` / `tearDownWithError` + `func testXxx_...()` 패턴.
- **Swift Testing** (신규) — `XCTestCase` 상속 없이 `PublisherWaitable` 직접 채택. `@Test` + `#expect` 매크로.

```swift
// Swift Testing 예시
import Testing
import Combine
import UnitTestHelpKit

final class DaysIntervalCountUsecaseImpleTests: PublisherWaitable {
    var cancelBag: Set<AnyCancellable>! = .init()
    private func makeUsecase() -> DaysIntervalCountUsecaseImple { ... }
}

extension DaysIntervalCountUsecaseImpleTests {
    @Test("count days -N, 0, N", arguments: [-4, -1, 0, 1, 4])
    func usecase_countDays(_ intervalDays: Int) async throws {
        // given
        let expect = expectConfirm("count days: \(intervalDays)")
        let usecase = self.makeUsecase()
        // when
        let interval = try await self.firstOutput(expect, for: usecase.countDays(to: time))
        // then
        #expect(interval == intervalDays)
    }
}
```

대표 예: `Domain/Tests/Usecases/DaysIntervalCountUsecaseImpleTests.swift`

---

## 2. 테스트 더블

### Stub — 생성 시점 고정
생성 시점에만 설정, 테스트 본문에서 **mutation 금지**. 시나리오별 분기는 `makeSUT(...)` 팩토리 파라미터로 주입.

```swift
public var shouldFailMake: Bool = false
public var stubCurrentTodoEvents: [TodoEvent] = []

private func makeViewModel(shouldFailMigration: Bool = false) -> MainViewModelImple {
    self.stubMigrationUsecase.shouldFail = shouldFailMigration
    // ... create SUT
}
```

테스트 본문에서 stub을 직접 건드리는 코드가 보이면 **즉시 리팩토링**. `makeXxx(shouldFail:)` 파라미터 또는 `makeXxxWith<State>` 헬퍼로 분리. 특수 초기 상태는 `makeXxxWithInitialLoaded()` 같은 파생 헬퍼.

### Mock — 동적 변경이 필요할 때만
생성 후 의도적으로 방출값/상태를 바꿔야 하는 경우만 `mock*` 네이밍. `stub*`과 구분해 의도 표시.

### Spy — 호출 검증 (최후 수단)
호출 자체 검증이 불가피할 때:

**1) 기존 스터브 확장 — `did*` 프로퍼티**
```swift
public var didMakeTodoWithParams: TodoMakeParams?
open func makeTodoEvent(_ params: TodoMakeParams) async throws -> TodoEvent {
    self.didMakeTodoWithParams = params
    // ...
}
```

**2) 전용 `Spy*` 클래스** — Router/Listener/Interactor처럼 호출 기록이 주 관심사인 객체
```swift
final class SpyEventDetailRouter: BaseSpyRouter, EventDetailRouting {
    var didShowJumpDaySelectDialogWith: CalendarDay?
    func showJumpDaySelectDialog(current: CalendarDay) {
        self.didShowJumpDaySelectDialogWith = current
    }
}
```

### 호출 기록 네이밍
항상 `did<Action>...`. `callCount` / `invokedCount` / `wasCalled` **금지**.

```swift
✅ var didRequestedPath: String?    var didRouteToSetting: Bool?
❌ var routeToSettingCallCount: Int   var wasRemoveCalled: Bool
```

### 검증 우선순위
- **1순위: SUT public interface** — 반환값, throw, publisher 방출, 외부 관찰 가능 상태(DB write 등)
- Spy 호출 추적은 public interface로 관찰 불가능할 때만.

---

## 3. Private 로직을 노출하지 말 것

내부 로직 테스트하려고 `internal/public static`으로 뚫지 않는다.

**Why:** 구현체(Imple)는 프로토콜의 한 구현. static 노출은 프로토콜 계약과 무관한 구현 세부에 테스트가 결합되고, 다른 구현체에선 그 로직이 없을 수 있어 "앱에서 동작한다"는 보장이 사라진다.

**대응:**
- 순수 로직이 독립 테스트 가치 있으면 → **별도 타입으로 추출** (예: `AppUpdateRequirement.init?(current:appUpdateInfo:)`)
- 그 외 → 공개 인터페이스로 간접 검증

---

## 4. 회귀테스트 우선

리액티브 스트림(Combine 등) 버그 수정 시 **수정 코드를 먼저 작성하지 말 것.**

순서: 버그 발견 → 회귀테스트 작성 → 현재 코드에서 **실패 확인** → 수정 → 통과 확인.

이유: 수정 먼저 하면 "버그가 진짜 존재하는지" / "수정이 정확히 그 버그를 고치는지" 검증이 빠진다.

---

## 5. `PublisherWaitable` — Publisher 방출 검증

`UnitTestHelpKit`의 프로토콜. SUT가 publisher를 노출할 때만 채택. `cancelBag: Set<AnyCancellable>!` 필수.

### Swift Testing
```swift
final class MyTests: PublisherWaitable {
    var cancelBag: Set<AnyCancellable>! = .init()

    @Test func someTest() async throws {
        let expect = expectConfirm("emits two values")
        expect.count = 2
        let values = try await outputs(expect, for: somePublisher) {
            triggerAction()
        }
        #expect(values == [a, b])
    }
}
```

| Method | 용도 |
|---|---|
| `expectConfirm(_:)` | `ConfirmationExpectation` 생성 (default count: 1, timeout: 100ms) |
| `outputs(_:for:_:)` | async — 방출값 수집 |
| `firstOutput(_:for:_:)` | async — 첫 방출만 |
| `failure(_:for:_:)` | async — 실패 completion |

다중 방출/긴 대기 필요 시 `expect.count`, `expect.timeout` 조정.

### XCTest
`BaseTestCase, PublisherWaitable` 채택, `setUpWithError`에서 `cancelBag = .init()`. 메서드는 `waitOutputs(_:for:timeout:_:)` / `waitFirstOutput(_:for:timeout:_:)` / `waitError(_:for:timeout:_:)` (XCTestExpectation 기반).

---

## 6. 테스트 조직

### 상황(given context) 기준 그룹화
메서드가 아니라 **상황 단위**로 `// MARK:`. 그룹 내 테스트 이름은 검증하는 **observable behavior**.

```swift
// MARK: - 마이그레이션 정상 수행
extension AppDataMigrationImpleTests {
    @Test func migration_movesAllDataToGoogleDB() ...
    @Test func migration_cleansUpOldDataAfterCompletion() ...
}

// MARK: - 마이그레이션 실패
extension AppDataMigrationImpleTests {
    @Test func migration_whenReadFails_throwsError() ...
}
```

### Observable behavior만 검증
- public interface로만 assert: 반환값, 에러, publisher 방출, 외부 관찰 가능 상태
- private state 검증 금지: 플래그·내부 카운터·중간 값. 플래그 flip이 중요하면 downstream effect로 검증 (예: "migration doesn't run again" → 플래그 체크가 아니라 "데이터 개수 변동 없음")
- private 키/상수를 테스트 파일에 복붙 금지 — behavior 관찰로 재구성

### given/when/then 주석 필수
모든 테스트 메서드에 `// given / when / then` 구조 표시.

---

## 7. 테스트 지원 모듈

| Module | Contents |
|---|---|
| `UnitTestHelpKit` | `BaseTestCase`, `PublisherWaitable`, `BaseStub`, `TestError` |
| `TestDoubles` | 공유 Stub repositories / stub usecases |
