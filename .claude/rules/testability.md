---
description: 테스트 프레임워크·테스트 더블·검증 원칙의 단일 가이드. production 코드를 테스트 때문에 훼손하지 않는다.
paths:
  - "Domain/**"
  - "Repository/**"
  - "Presentations/**"
---

# 테스트 작성 규칙

이 프로젝트의 모든 테스트는 아래 규칙을 따른다. production 코드는 테스트 때문에 훼손하지 않는다.

## 1. 테스트 프레임워크

프로젝트는 두 프레임워크를 상황에 따라 사용한다.

### XCTest (`BaseTestCase`)
기존 테스트의 대다수. `UnitTestHelpKit`의 `BaseTestCase`를 상속 — `XCTestCase` 확장에 `timeout`, `timeoutLong` 사전 설정.

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

### Swift Testing (`@Test` / `#expect`)
신규 테스트에서 사용. `XCTestCase` 상속 없이 `PublisherWaitable` 직접 채택. `@Test` + `#expect` 매크로.

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

대표 예: `Domain/Tests/Usecases/DaysIntervalCountUsecaseImpleTests.swift`

---

## 2. 테스트 더블

### Stub — 생성 시점 고정
생성 시점에 설정. 테스트 본문에서 **mutation 금지**.

```swift
public var shouldFailMake: Bool = false              // 실패 경로 제어
public var stubCurrentTodoEvents: [TodoEvent] = []   // 반환값 공급
```

**시나리오별 분기는 `makeSUT(...)` 팩토리 파라미터로**:

```swift
private func makeViewModel(
    shouldFailMigration: Bool = false
) -> MainViewModelImple {
    self.stubMigrationUsecase.shouldFail = shouldFailMigration
    // ... create SUT
}
```

테스트 메서드 본문에서 스터브 변수를 직접 건드리는 코드가 보이면 **즉시 리팩토링**. `makeXxx(shouldFail:)` 파라미터 또는 `makeXxxWith<State>` 별도 헬퍼로 분리.

특수한 초기 상태가 필요한 경우 `makeXxxWithInitialLoaded()` 같은 파생 헬퍼를 만들어 공통 setup을 감춘다.

### Mock — 동적 변경이 필요한 경우
생성 후 의도적으로 방출값/상태를 바꿔야 할 때만 이름을 `mock*`으로 한다. `stub*`과 구분되어 "동적 변경 의도적"임을 표시.

### Spy — 호출 검증 (최후 수단)
호출 자체를 검증하는 게 불가피할 때 두 가지 방식:

**1) 기존 스터브 확장 — `did*` 프로퍼티 추가**
```swift
// In StubTodoEventUsecase
public var didMakeTodoWithParams: TodoMakeParams?
open func makeTodoEvent(_ params: TodoMakeParams) async throws -> TodoEvent {
    self.didMakeTodoWithParams = params
    // ...
}

public var didRemoveTodoId: String?
open func removeTodo(_ id: String, onlyThisTime: Bool) async throws {
    self.didRemoveTodoId = id
    // ...
}
```

**2) 전용 `Spy*` 클래스** — Router / Listener / Interactor 등 호출 기록이 주 관심사인 객체

```swift
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

### 호출 기록 네이밍 규칙
항상 `did<Action>...`. `callCount` / `invokedCount` / `wasCalled` **금지**.

```swift
// ✅
var didRequestedPath: String?
var didRouteToSetting: Bool?
var didFocusMovedToToday: Bool?
var didCalendarAttached: (() -> Void)?

// ❌
var routeToSettingCallCount: Int
var wasRemoveCalled: Bool
```

### 검증 우선순위
- **1순위: SUT의 public interface** — 반환값, throw 에러, publisher 방출값, 외부 관찰 가능한 상태 변경 (DB write, record 삭제 등)
- **Spy 호출 추적은 최후 수단**. public interface로 관찰 불가능할 때만.

---

## 3. Private 로직을 노출하지 말 것

구현체 내부 로직을 테스트하려고 `internal static` / `public static` 메서드로 뚫지 않는다.

**Why:** 구현체(Imple)는 프로토콜의 한 구현일 뿐. static으로 노출하면 프로토콜 계약과 무관한 구현 세부사항에 테스트가 결합되고, 다른 구현체에서는 해당 로직이 없을 수 있어 "앱에서 동작한다"는 보장이 사라진다.

**대응:**
- 순수 로직이 독립 테스트 가치가 있으면 → **별도 타입으로 추출**해 테스트 (예: `AppUpdateRequirement.init?(current:appUpdateInfo:)`)
- 그렇지 않으면 → 공개 인터페이스를 통해 간접 검증

---

## 4. 회귀테스트 우선

리액티브 스트림(Combine 등) 버그 수정 시 **수정 코드를 먼저 작성하지 말 것.**

순서: 버그 발견 → 회귀테스트 작성 → 현재 코드에서 **실패 확인** → 수정 적용 → 테스트 통과 확인.

이유: 수정 먼저 하면 실패 상태를 확인하지 못한 채 넘어가 "버그가 진짜 존재하는지" / "수정이 정확히 그 버그를 고치는지" 검증이 빠진다.

---

## 5. `PublisherWaitable` — Publisher 방출 검증

`UnitTestHelpKit`의 프로토콜. Combine publisher의 방출값 수집 헬퍼 제공. **옵셔널** — SUT가 publisher를 노출할 때만 채택.

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
| `waitOutputs(_:for:timeout:_:)` | 방출된 모든 값을 expectation 충족까지 수집 |
| `waitFirstOutput(_:for:timeout:_:)` | 첫 방출값만 반환 |
| `waitError(_:for:timeout:_:)` | 실패 completion 캡처 |

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
| `expectConfirm(_:)` | `ConfirmationExpectation` 생성 (기본 count: 1, timeout: 100ms) |
| `outputs(_:for:_:)` | async — confirmation 기반 방출값 수집 |
| `firstOutput(_:for:_:)` | async — 첫 방출값만 반환 |
| `failure(_:for:_:)` | async — 실패 completion 캡처 |

다중 방출 / 긴 대기 필요 시 `outputs()` 호출 전 `expect.count`, `expect.timeout` 조정.

---

## 6. 테스트 조직

### 상황(given context) 기준 그룹화
메서드 단위가 아니라 **상황 단위**로 그룹화. 각 그룹은 distinct scenario를 커버하고, 그룹 내 테스트 이름은 검증하는 **observable behavior**를 묘사.

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

### Observable behavior만 검증
- **public interface로만 assert**: 반환값, 에러, publisher 방출, 외부 관찰 가능한 상태 변경
- **private state 검증 금지**: private 플래그, 내부 카운터, 중간 값. 플래그 flip이 중요하면 downstream effect로 검증 (예: "migration doesn't run again"은 플래그 체크가 아니라 "데이터 개수 변동 없음"으로 관찰)
- **테스트 파일에 private 키/상수 중복 복붙 금지**: 내부 값이 private이면 테스트도 그 값을 알지 말고, behavior를 관찰하도록 재구성

### given / when / then 주석 필수
모든 테스트 메서드에 `// given / when / then`으로 구조 표시.

---

## 7. 테스트 지원 모듈

| Module | Contents |
|---|---|
| `UnitTestHelpKit` | `BaseTestCase`, `PublisherWaitable`, `BaseStub`, `TestError` |
| `TestDoubles` | 공유 Stub repositories / stub usecases |
