# TodoCalendar — 코딩 스타일, 설계 원칙, 개발 철학

> 코드베이스와 커밋 이력 분석을 통해 추출한 상세 문서 (2026-03-28 기준)

---

## 1. 설계 원칙 및 철학

### 1.1 Clean Architecture — 단방향 의존성

```
App → Presentations → Scenes/CommonPresentation → Domain ← Repository
```

- **Domain 레이어**는 순수 비즈니스 로직만. 외부 프레임워크 의존 금지 (Foundation, Combine만 허용).
- **Repository 레이어**는 Domain 프로토콜을 구현하되, Presentation을 절대 import하지 않는다.
- **Presentation 모듈 간 직접 import 금지**. 공유 프로토콜(`Scenes` 프레임워크)로만 참조.
- 상위 레이어는 하위 레이어의 **프로토콜(인터페이스)**에만 의존한다. 구체 타입 참조 금지.

### 1.2 Protocol-First 설계

- 모든 추상화는 **프로토콜로 먼저 정의**한 후 구현한다.
- Repository, Usecase, ViewModel, Router, Builder 모두 프로토콜 + `Imple` 구현 쌍.
- Usecase가 단순 프록시인 경우 `typealias`로 대체하여 보일러플레이트 제거.
- 프로토콜에 `any` 키워드를 사용한 타입 이레이저: `private let repo: any TodoEventRepository`

### 1.3 SOLID 원칙 적용

| 원칙 | 적용 방식 |
|---|---|
| **SRP** | Usecase 하나 = 하나의 비즈니스 도메인. ViewModel은 UI 상태만, Router는 화면 전환만. |
| **OCP** | Factory/Decorator 패턴으로 기존 코드 수정 없이 확장 (예: `UploadDecorateRepositoryImple`). |
| **LSP** | 모든 Repository 구현체는 프로토콜을 통해 교체 가능. 테스트 더블도 동일. |
| **ISP** | 큰 인터페이스를 작은 프로토콜 조합으로 분리 (`UsecaseFactory`는 8개 sub-protocol 합성). |
| **DIP** | ViewModel은 Local/Remote/Decorator 중 어떤 Repository인지 모른다. 앱 시작 시점에 주입. |

### 1.4 Query/Command 분리 (CQS)

- 읽기(query)와 쓰기/사이드이펙트(command)를 한 흐름에 섞지 않는다.
- 데이터 변환(map/flatMap/compactMap)을 먼저 완성한 뒤, 사이드이펙트(forEach/async)를 별도 실행.

```swift
// Good
let accounts = services.flatMap { $0.accountIds }.compactMap { makeAccount($0) }  // query
await accounts.asyncForEach { await setup($0) }                                    // command

// Bad — query + command 혼재
var accounts: [Account] = []
for service in services {
    for id in service.accountIds {
        accounts.append(makeAccount(id))
        await setup(id)
    }
}
```

### 1.5 Reactive + Async 하이브리드

- **Combine Publisher**: 상태 관찰 및 UI 바인딩 (SharedDataStore → Usecase → ViewModel → View).
- **async/await**: 명령형 비즈니스 로직 (생성/수정/삭제 등 일회성 작업).
- 두 패턴을 혼용하되, **상태 스트림은 Combine**, **일회성 커맨드는 async**로 일관되게 분리.

### 1.6 불변 데이터 흐름 (Prelude + Optics)

```swift
let updated = origin
    |> \.repeatingTimeToExcludes <>~ [currentTime.customKey]
    |> \.time .~ nextEventTime.time
    |> \.repeatingTurn .~ nextEventTime.turn
```

- 값 타입 업데이트에 렌즈 연산자(`|>`, `.~`, `<>~`)를 사용하여 불변성을 유지.
- `SharedDataStore.update()`도 클로저 기반 불변 업데이트 패턴.

### 1.7 Offline-First 설계

3-Layer Repository 패턴:

```
Domain Protocol (Single Interface)
  ├─ Local Repository (SQLite only, offline)
  ├─ Remote Repository (API + cache)
  └─ Upload Decorator (Local + background sync queue)
```

비즈니스 로직은 데이터 소스를 모른다. 온/오프라인 전환이 투명하게 이루어진다.

### 1.8 Scene 구성 패턴

화면 하나 = 6개 파일:

| 파일 | 역할 |
|---|---|
| `XXScene+Builder.swift` | Scene/Interactor/Listener/Builder 프로토콜 정의 |
| `XXViewModel.swift` | VM 프로토콜 + Imple (Subject struct로 상태 관리) |
| `XXViewController.swift` | UIHostingController 래퍼 |
| `XXRouter.swift` | BaseRouterImple 상속, 화면 전환 |
| `XXBuilderImple.swift` | 의존성 조립 (UsecaseFactory + ViewAppearance 주입) |
| `XXView.swift` | ViewState + ViewEventHandler + ContainerView + View |

Scene 간 통신:

| 방향 | 메커니즘 | 용도 |
|---|---|---|
| Parent → Child | **Interactor** | 부모가 자식에게 명령 |
| Child → Parent | **Listener** (weak) | 자식이 부모에게 이벤트 전달 |
| 간접 공유 | **SharedDataStore** | 같은 데이터를 구독하는 독립 Scene 간 |

### 1.9 점진적 리팩토링

- 큰 리팩토링은 레이어별/관심사별로 **여러 개의 응집력 있는 커밋**으로 분할.
- 각 커밋이 단독으로 의미를 가지면서, 전체적으로 하나의 아키텍처 변경을 이룬다.
- 예: 다중 계정 지원 시 Domain 모델 → Remote 레이어 → Local 레이어 → Usecase → Presentation 순서로 진행.

### 1.10 TDD 워크플로우

- **테스트 작성 → 실패 확인 → 구현 → 통과 확인** 순서.
- 테스트는 **상황(context) 기준** 그룹화. 메서드 기준이 아님.
- observable한 **동작(behavior)**만 검증. 내부 구현 상태 검증 금지.

### 1.11 합성 중심 설계 — 카테고리 이론의 교훈

카테고리 이론의 정수: **프로그래밍은 분해와 합성이다.**

좋은 설계란 복잡한 문제를 **조합 가능한 작은 단위로 분해**하고, 그것들을 **규칙에 따라 다시 합성**하는 것이다. 이 프로젝트의 설계 원칙들 — Protocol-First, CQS, Builder, Decorator, 함수형 스타일 — 은 모두 이 합성 원칙의 구체적 적용이다.

합성이 안전하게 동작하려면 세 가지 조건이 필요하다:

- **결합성(Associativity)**: `(f ∘ g) ∘ h = f ∘ (g ∘ h)` — 합성 순서를 괄호로 바꿔도 결과가 같아야 한다. `flatMap` 체이닝, 파이프라인 연결이 안전한 이유.
- **항등(Identity)**: 아무것도 하지 않는 변환이 존재해야 한다. 합성의 시작점이자 기본값.
- **구조 보존**: 합성 과정에서 내부 구조가 깨지지 않아야 한다. `map`이 안전한 이유 — 컨테이너 구조를 보존하면서 내부 값만 변환한다.

이 세 조건을 지키는 한, 작은 함수/프로토콜/모듈을 자유롭게 조합해서 복잡한 동작을 만들 수 있다. 설계 판단에서 "이 단위가 다른 것들과 안전하게 합성되는가?"를 기준으로 삼을 것.

---

## 2. Swift 코딩 스타일

### 2.1 네이밍

| 개념 | 규칙 | 예시 |
|---|---|---|
| 변수/프로퍼티 | camelCase, 약어 금지, 서술적 | `todoId`, `localStorage`, `cancellables` |
| 함수/메서드 | 동사 시작, 파라미터 레이블 명시 | `loadTodoEvent(_:)`, `updateTodoToggleState(_:_:)` |
| 타입 | PascalCase | `TodoEvent`, `SharedDataStore` |
| 프로토콜 | 역할/계약 기반 | `TodoEventRepository`, `CalendarSceneListener` |
| 구현체 | 프로토콜 + `Imple` | `TodoEventUsecaseImple`, `TodoLocalRepositoryImple` |
| Boolean | `is`/`has`/`can` 접두사 | `isValidForMaking`, `hasChanges` |
| 테스트 스파이 | `did<Action>...` | `didRouteToSetting`, `didRemoveTodoId` |
| Stub | 생성 시점 고정 | `stubTodoEvents` |
| Mock | 동적 변경 가능 | `mockRepository` |

### 2.2 코드 포맷

- **4-space 인덴트** (탭 아님)
- **Opening brace는 같은 줄** (1TBS 스타일)
- `// MARK: -` 로 extension과 논리 섹션 구분
- 함수 시그니처가 길면 파라미터별 줄바꿈
- import 순서: Foundation → 프레임워크 알파벳 순
- 비Sendable import에 `@preconcurrency` 부착
- 빈 줄: import 후, MARK 섹션 간, 논리 블록 간

### 2.3 Optional 처리

```swift
// guard let + 조기 반환 (선호)
guard let todo = try await self.findTodoEvent(eventId) else {
    throw RuntimeError(key: LocalErrorKeys.notExists.rawValue, "todo not exists")
}

// map/flatMap 체인
sender[Key.time.rawValue] = self.time.map { EventTimeMapper(time: $0) }.map { $0.asJson() }

// ?? 단순 기본값
let userDefaults = suiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
```

- Production 코드에서 **force unwrap 금지**

### 2.4 에러 처리

| 패턴 | 용도 |
|---|---|
| `throw RuntimeError(key:message:)` | 도메인 에러 (로컬라이제이션 키 포함) |
| `try?` (silent failure) | 실패해도 괜찮은 부수 작업 |
| `throws` 전파 | 실패하면 안 되는 핵심 작업 |

### 2.5 클로저

```swift
// Trailing closure
self.todoRepository.loadCurrentTodoEvents()
    .sink(receiveCompletion: { _ in }, receiveValue: updateCached)
    .store(in: &self.cancellables)

// [weak self] capture
let updateCached: ([TodoEvent]) -> Void = { [weak self] currents in
    self?.sharedDataStore.update(...)
}

// $0 축약
.map { $0.uuid }
.filter { !idSet.contains($0.uuid) }
```

### 2.6 타입 & 제네릭

- 프로퍼티 선언 시 **명시적 타입 어노테이션**: `let storage: any TodoLocalStorage`
- 함수 반환 타입 항상 명시
- Combine 스트림은 `AnyPublisher`로 타입 이레이저
- 프로토콜 타입 참조에 `any` 키워드: `private let repo: any TodoEventRepository`
- 제네릭은 storage/repository 레이어에서 다형적 load/save에 활용

### 2.7 Enum 패턴

```swift
// Associated value로 도메인 모델
public enum EventTime: Comparable, Sendable, Hashable {
    case at(TimeInterval)
    case period(Range<TimeInterval>)
    case allDay(Range<TimeInterval>, secondsFromGMT: TimeInterval)
}

// Switch는 exhaustive (불필요한 default 금지)
// Raw value는 CodingKey, 환경키 등에 활용
enum TodoCodingKeys: String, CodingKey {
    case uuid
    case name
    case createTime = "create_timestamp"
}
```

### 2.8 Extension 조직

```swift
public final class TodoLocalRepositoryImple: TodoEventRepository, Sendable {
    // init, properties
}

// MARK: - make
extension TodoLocalRepositoryImple { ... }

// MARK: - complete
extension TodoLocalRepositoryImple { ... }

// MARK: - remove
extension TodoLocalRepositoryImple { ... }
```

- **기능/관심사별** 분리 (프로토콜 적합성이 아닌 기능 단위)
- 타입 내 순서: init → 프로토콜 필수 메서드 → public 헬퍼 → private 헬퍼

### 2.9 접근 제어

| 수준 | 용도 |
|---|---|
| `public` | 프레임워크 경계 API |
| `internal` (기본) | 대부분의 구현 코드 |
| `private` | 타입 내부 상태 |
| `@unchecked Sendable` | 스레드 안전 보장된 mutable 상태에 한해 |

### 2.10 Functional 스타일

```swift
// Higher-order functions 우선
let refreshed = todos.asDictionary { $0.uuid }
let accounts = services.flatMap { $0.accountIds }.compactMap { makeAccount($0) }

// Prelude/Optics 렌즈 연산자
let updated = event |> \.name .~ "new name" |> \.eventTagId .~ tagId
sharedDataStore.update(...) { ($0 ?? [:]) |> key(event.uuid) .~ event }
```

- Imperative loop 지양
- 쿼리(변환)를 먼저 완성 → 커맨드(사이드이펙트) 별도 실행

### 2.11 주석

- 코드가 자명하면 **주석 최소화**
- `// MARK: -` 로 구조 조직화
- 주석은 *what*이 아닌 *why* 설명
- 문서화 주석(///) 거의 사용 안 함 — 네이밍과 파라미터 레이블이 문서 역할

### 2.12 Async/Concurrency

- **async/await** 전면 사용 (completion handler 미사용)
- Actor로 동시성 안전 보장 (`EventUploadServiceImple`)
- `@MainActor`는 UIKit 관련 메서드에만 부착
- Combine과 async/await 혼용: 상태 스트림은 Combine, 일회성 작업은 async

---

## 3. 커밋 이력에서 관찰된 패턴

### 3.1 커밋 메시지 컨벤션

```
[#이슈번호] 변경 내용 요약       — 기능/버그
docs: 변경 내용 요약              — 문서
v2.8.0                            — 릴리즈
```

- 제목은 액션 지향적이고 구체적 (generic한 "fix", "update" 지양)
- *what*보다 *why* 또는 아키텍처 결정을 설명

### 3.2 커밋 크기와 범위

- **대부분 3-5개 파일** 단위의 작고 집중된 커밋
- 아키텍처 리팩토링 시 14-18개 파일도 허용 — 응집력 있는 단위라면 의도적
- 이슈당 평균 8-16개 커밋으로 기능 완성

### 3.3 개발 순서

1. Domain 모델 업데이트
2. Remote 레이어 변경
3. Local 레이어 변경
4. Usecase 변경
5. Presentation 변경
6. 테스트 보강

### 3.4 리팩토링 전략

- 이름 변경 시 의도를 명확히 하는 방향 (예: `ReadOnly` → `Aggregated`)
- Decorator 패턴으로 기존 코드 감싸기
- Pool 패턴으로 다중 리소스 관리 (`DBConnectionPool`, `RepositoryPool`, `RemotePool`)
- 마이그레이션은 플래그 기반 멱등성 보장

---

## 4. 주요 디자인 패턴

| 패턴 | 적용 |
|---|---|
| **Pool Pattern** | 다중 계정 리소스 관리 (DB 연결, Repository, Remote API) |
| **Factory Pattern** | Usecase/Scene 생성 (인증 상태별 다른 구현 주입) |
| **Decorator Pattern** | `UploadDecorateRepositoryImple` (오프라인 큐 래핑) |
| **Observer/Publisher** | Combine 기반 SharedDataStore로 반응형 상태 전파 |
| **Builder Pattern** | Scene별 의존성 조립 (UsecaseFactory + ViewAppearance) |
| **Interactor/Listener** | 부모-자식 Scene 간 양방향 통신 (delegation 대신) |
