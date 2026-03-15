# Testing Guide

This project uses two test frameworks depending on the test target and context.

## 1. XCTest (`BaseTestCase`)

Used for most existing tests. Subclass `BaseTestCase` (from `UnitTestHelpKit`), which extends `XCTestCase` with two pre-set timeout constants (`timeout`, `timeoutLong`):

```swift
import XCTest
import UnitTestHelpKit

class CalendarSettingRepositoryImpleTests: BaseTestCase {

    override func setUpWithError() throws { }
    override func tearDownWithError() throws { }

    private func makeRepository() -> CalendarSettingRepositoryImple { ... }
}

extension CalendarSettingRepositoryImpleTests {

    func testRepository_saveAndLoadTimeZone() {
        // given
        let repository = self.makeRepository()

        // when
        repository.saveTimeZone(TimeZone(abbreviation: "KST")!)
        let timeZone = repository.loadUserSelectedTimeZone()

        // then
        XCTAssertEqual(timeZone, TimeZone(abbreviation: "KST"))
    }
}
```

## 2. Swift Testing (`@Test` / `#expect`)

Used for newer tests. Classes conform directly to `PublisherWaitable` (no `XCTestCase` inheritance) and use the `Testing` framework's `@Test` attribute and `#expect` macro.

```swift
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

Representative example: `Domain/Tests/Usecases/DaysIntervalCountUsecaseImpleTests.swift`

---

## Test Double Conventions

### Stub

Stubs are configured **at creation time**. Behavior is controlled via properties set before the SUT is created, not mutated during the test body.

```swift
// shouldFail* flags control error paths
public var shouldFailMake: Bool = false

// stub* properties supply return values
public var stubCurrentTodoEvents: [TodoEvent] = []
```

When multiple scenarios require different stub behavior, the `make*(...)` factory function in the test class accepts parameters that branch the configuration:

```swift
private func makeViewModel(
    shouldFailMigration: Bool = false
) -> MainViewModelImple {
    self.stubMigrationUsecase.shouldFail = shouldFailMigration
    // ... create and return SUT
}
```

This keeps each test case free of setup mutation — the test only calls `makeViewModel(shouldFailMigration: true)` and proceeds straight to assertions.

### Mock

When a dependency's behavior genuinely needs to change **after** the SUT has been created (e.g., emitting a new value mid-test), the object is named `mock` rather than `stub`. This signals that dynamic mutation during the test is expected and intentional.

### Primary Testing Focus

The primary target of assertions is the **SUT's public interface** — return values, thrown errors, and emitted publisher values. Internal call sequences are only verified when they cannot be observed through the public interface.

### Spy (call verification as a last resort)

When a call test is unavoidable, two approaches are used:

**1. Extend the stub** with `did*` recording properties (used when the stub already exists):

```swift
// In StubTodoEventUsecase
public var didMakeTodoWithParams: TodoMakeParams?
open func makeTodoEvent(_ params: TodoMakeParams) async throws -> TodoEvent {
    self.didMakeTodoWithParams = params
    // ... stub logic
}

public var didRemoveTodoId: String?
open func removeTodo(_ id: String, onlyThisTime: Bool) async throws {
    self.didRemoveTodoId = id
    // ... stub logic
}
```

**2. Dedicated `Spy*` class** (used for routers, listeners, interactors — objects where call recording is the primary concern):

```swift
// Spy classes extend BaseSpyRouter or stand alone
final class SpyEventDetailRouter: BaseSpyRouter, EventDetailRouting {
    var didAttachInput: Bool?
    func attachInput(_ listener: EventDetailInputListener?) -> EventDetailInputInteractor? {
        self.didAttachInput = true
        return self.spyInteractor
    }

    var didShowJumpDaySelectDialogWith: CalendarDay?
    func showJumpDaySelectDialog(current: CalendarDay) {
        self.didShowJumpDaySelectDialogWith = current
    }
}
```

**Naming rule for recorded variables:** always `did<Action>...` — never `callCount`, `invokedCount`, or `wasCalled`.

```swift
// Correct
var didRequestedPath: String?
var didRouteToSetting: Bool?
var didFocusMovedToToday: Bool?
var didCalendarAttached: (() -> Void)?

// Avoid
var routeToSettingCallCount: Int
var wasRemoveCalled: Bool
```

---

## `PublisherWaitable` — Testing Publisher Emissions

`PublisherWaitable` is a protocol in `UnitTestHelpKit` that provides helpers for collecting values emitted by Combine publishers. It is **optional** — only needed when the subject under test exposes a publisher whose emissions need to be verified.

It works with both frameworks via separate extensions:

### With XCTest (`BaseTestCase`)

```swift
class MyViewModelTests: BaseTestCase, PublisherWaitable {
    var cancelBag: Set<AnyCancellable>!

    override func setUpWithError() throws {
        cancelBag = .init()
    }

    func test_publisher_emitsExpectedValues() {
        let expect = expectation(description: "emits")
        let vm = makeViewModel()

        let values = waitOutputs(expect, for: vm.somePublisher) {
            vm.triggerAction()
        }

        XCTAssertEqual(values, [expectedValue])
    }
}
```

| Method | Description |
|---|---|
| `waitOutputs(_:for:timeout:_:)` | Collects all emitted values until expectation is fulfilled |
| `waitFirstOutput(_:for:timeout:_:)` | Returns only the first emitted value |
| `waitError(_:for:timeout:_:)` | Captures the failure completion |

### With Swift Testing

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

| Method | Description |
|---|---|
| `expectConfirm(_:)` | Creates a `ConfirmationExpectation` (default count: 1, timeout: 100ms) |
| `outputs(_:for:_:)` | Async — collects emitted values via `confirmation` |
| `firstOutput(_:for:_:)` | Async — returns only the first emitted value |
| `failure(_:for:_:)` | Async — captures the failure completion |

Adjust `expect.count` and `expect.timeout` before passing to `outputs()` when multiple emissions or a longer wait is needed.

---

## Test Organization

### Group by Situation, Not by Method

Tests are grouped by **situation (given context)** rather than by the method or function being tested. Each group covers a distinct scenario, and within each group the test name describes the observable **behavior** being verified.

```swift
// MARK: - 마이그레이션 정상 수행
extension AppDataMigrationImpleTests {
    @Test func migration_movesAllDataToGoogleDB() ...
    @Test func migration_whenWriteFails_completesWithoutThrowing() ...
    @Test func migration_cleansUpOldDataAfterCompletion() ...
    @Test func migration_doesNotRunAgainAfterCompletion() ...
}

// MARK: - 마이그레이션 실패
extension AppDataMigrationImpleTests {
    @Test func migration_whenReadFails_throwsError() ...
}

// MARK: - 데이터 없는 엣지 케이스
extension AppDataMigrationImpleTests {
    @Test func migration_whenNoData_completesSuccessfully() ...
    @Test func migration_whenNoColors_migratesTagsAndEvents() ...
}
```

### Test Observable Behavior, Not Implementation Details

- **Assert on public interface only**: return values, thrown errors, emitted publisher values, and externally visible state changes (e.g., data written to DB, records deleted).
- **Avoid asserting on private state**: private flags, internal counters, or intermediate values that are not observable through the public API. If a flag flip matters, verify it through its downstream effect (e.g., "migration doesn't run again" is verified by observing that data count doesn't change — not by checking that a flag is `true`).
- **Avoid duplicating private keys or implementation details in tests**: if a key, constant, or intermediate value is private to the SUT, do not replicate it in the test file. Restructure the test to observe the behavior that the private value controls.

---

## Test Support Modules

| Module | Contents |
|---|---|
| `UnitTestHelpKit` | `BaseTestCase`, `PublisherWaitable`, `BaseStub`, `TestError` |
| `TestDoubles` | Stub repositories and stub usecases shared across test targets |
