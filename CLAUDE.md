# CLAUDE.md

## 0. 단축어

| 사용자 말 | Claude 동작 |
|---|---|
| **커밋해줘** | 변경된 파일 전체를 `git add` → 커밋 메시지 작성 → `git commit` → 결과 출력 |
| **방금 작업한것만 골라서 커밋해줘** | 현재 대화에서 Claude가 수정한 파일만 선별해 `git add` → 커밋 메시지 작성 → `git commit` → 결과 출력 |

---

## 1. 절대 규칙

- **파일을 수정하기 전에 반드시 먼저 읽어라.** 추측으로 수정하지 말 것.
- **파일을 추가하거나 삭제한 경우 `tuist generate`를 재실행해야 한다.**
- **Query와 Command를 분리하라.** 읽기(query)와 쓰기/사이드이팩트(command)를 한 흐름에 섞지 말 것. 

---

## 2. 아키텍처

### 폴더 구조

```
TodoCalendar/
├── Domain/                     — Models, Repository protocols, Usecase implementations
│   ├── Sources/
│   │   ├── Models/
│   │   ├── Repositories/       — Repository protocols (interface only)
│   │   ├── Usecases/
│   │   └── Utils/
│   └── Tests/
├── Repository/                 — Local (SQLite) + Remote (Alamofire) implementations
│   ├── Sources/
│   │   ├── Local/              — SQLite tables, migrations
│   │   ├── Remote/             — Alamofire API clients
│   │   ├── Repository+Imple/   — Repository implementation classes
│   │   └── Extensions/
│   └── Tests/
├── Presentations/
│   ├── Scenes/                 — Shared Scene/Builder protocols, UsecaseFactory protocol
│   ├── CommonPresentation/     — Shared UI components, ViewAppearance
│   ├── CalendarScenes/         — Calendar + day-event list screens
│   ├── EventDetailScene/       — Event create/edit/detail screens
│   ├── EventListScenes/        — Done-todo list, standalone event lists
│   ├── MemberScenes/           — Login, account screens
│   └── SettingScene/           — Settings screens
├── Supports/
│   ├── Extensions/             — Swift extensions
│   ├── Common3rdParty/         — Shared 3rd-party wrappers
│   ├── UnitTestHelpKit/        — BaseTestCase, PublisherWaitable
│   └── TestDoubles/            — Stub repositories, mock usecases (공유)
├── TodoCalendarApp/            — App target
│   ├── Sources/
│   │   ├── Factories/          — UsecaseFactory 구현체 (Login/NonLogin)
│   │   ├── Root/               — ApplicationRootBuilder (전체 의존성 조립)
│   │   └── Main/
│   ├── AppExtensions/
│   │   ├── Base/               — AppExtensionBase (위젯/인텐트 공통 기반)
│   │   ├── IntentExtensions/   — App Intent extensions
│   │   └── Widget/             — Widget target (18종 위젯)
│   └── Resources/
├── Tuist/                      — 프로젝트 생성 설정
│   ├── ProjectDescriptionHelpers/
│   └── Dependencies.swift      — 모든 SPM 의존성
├── docs/                       — 아키텍처 문서 (한국어)
└── Template/                   — Xcode Scene 템플릿
```

### 의존성 방향

```
TodoCalendarApp → Presentations → Scenes / CommonPresentation → Domain ← Repository
```

- Presentation 모듈 간 직접 import 금지. `Scenes` 프레임워크의 공유 프로토콜로만 참조.

### 주요 파일

| 파일 | 역할 |
|---|---|
| `TodoCalendarApp/AppEnvironment.swift` | DB version, App Group ID, 외부 캘린더 서비스 목록 |
| `TodoCalendarApp/Sources/Root/ApplicationRootBuilder.swift` | 앱 시작 시 모든 Repository/Usecase/Factory 조립 |
| `Tuist/ProjectDescriptionHelpers/Project+Templates.swift` | `Project.app()` / `Project.framework()` 팩토리 헬퍼 |

---

## 3. 빌드 / 테스트

### 초기 설정

```bash
./install/install.sh   # 더미 config 파일 복사 (최초 1회)
tuist fetch            # SPM 의존성 resolve
tuist generate --no-open
open TodoCalendar.xcworkspace
```

파일을 추가하거나 삭제한 경우 `tuist generate --no-open` 재실행 필요.

### 테스트 실행

```bash
# 모듈 전체 테스트
xcodebuild test \
  -workspace TodoCalendar.xcworkspace \
  -scheme Domain \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0'

# 특정 클래스만
xcodebuild test \
  -workspace TodoCalendar.xcworkspace \
  -scheme Domain \
  -only-testing:DomainTests/CalendarSettingUsecaseImpleTests \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0'
```

주요 테스트 스킴: `Domain`, `Repository`, `CalendarScenes`, `EventDetailScene`, `EventListScenes`, `SettingScene`, `MemberScenes`

### 테스트 작성 원칙

**프레임워크 선택**
- XCTest: `BaseTestCase` (from `UnitTestHelpKit`) 상속
- Swift Testing: `@Test` / `#expect`, `PublisherWaitable` 직접 채택 (XCTestCase 불필요)

**구조**
- 테스트는 **상황(given context) 기준**으로 그룹화. 메서드 기준 아님.
- 각 테스트는 observable한 **동작(behavior)** 을 검증. 내부 구현 상태(private flag 등) 검증 금지.
- `// given / when / then` 주석으로 구조 명시.

**Test Double 네이밍**
- `stub*`: 생성 시점에 설정 고정. 테스트 중 변경 없음.
- `mock*`: 생성 후 동적 변경이 필요한 경우.
- 호출 기록 변수: `did<Action>...` 형태. (`didRouteToSetting`, `didRemoveTodoId`) `callCount` / `wasCalled` 사용 금지.

**Publisher 검증 — `PublisherWaitable`**

```swift
// XCTest
let values = waitOutputs(expect, for: vm.somePublisher) { vm.triggerAction() }
XCTAssertEqual(values, [expected])

// Swift Testing
let expect = expectConfirm("emits")
let values = try await outputs(expect, for: somePublisher) { triggerAction() }
#expect(values == [expected])
```

---

## 4. 도메인 컨텍스트

### 핵심 이벤트 모델

앱은 두 가지 이벤트 타입을 중심으로 동작한다.

| 타입 | 시간 | 완료 | 반복 |
|---|---|---|---|
| `TodoEvent` | 선택 (없으면 단순 할일) | DoneTodo 생성 | turn 추적으로 count 기반 종료 |
| `ScheduleEvent` | 필수 (period / allDay / at) | 삭제만 가능 | RepeatingTimes 배열로 사전 계산 |

**EventTime** — 세 가지 형태:
- `.at(TimeInterval)` — 순간 (할일 마감 등)
- `.period(Range<TimeInterval>)` — 기간
- `.allDay(Range<TimeInterval>, secondsFromGMT:)` — 하루종일 (타임존 오프셋 별도 저장)

### 반복 이벤트

**반복 옵션**: EveryDay / EveryWeek(요일 지정) / EveryMonth(일자 또는 "첫 번째 화요일") / EveryYear / EveryYearSomeDay / LunarCalendarEveryYear

**종료 조건**:
- `.until(TimeInterval)` — 특정 날짜까지
- `.count(Int)` — 총 N회 (`endCount=3`이면 turn 1·2·3 유효, turn 4부터 종료)

**turn 규칙** — `EventRepeatTimeEnumerator` 기준:
- turn은 **1부터 시작**. `nextEventTime`은 항상 `from.turn + 1`을 반환.
- `TodoEvent.repeatingTurn`: 해당 todo의 현재 반복 회차. `nil` = 첫 번째(turn 1로 취급).
- 완료·수정·삭제·스킵 처리마다 다음 turn으로 업데이트. 이 값이 없으면 count 기반 종료가 동작하지 않음.
- 다음 반복 계산 시 `origin.repeatingTurn ?? 1`을 starting turn으로 사용 (Local·Remote 동일).

**ScheduleEvent의 수정 범위**:
- `.onlyThisTime` — 현재 회차만 수정 (새 이벤트 생성 + 원본에서 해당 시간 제외)
- `.fromNow` — 현재부터 미래 반복을 새 시리즈로 분기
- 기본 — 전체 시리즈 수정

### 이벤트 태그 / 외부 캘린더

**EventTagId** — 태그의 식별자 enum:
- `.default` / `.holiday` — 시스템 태그
- `.custom(String)` — 사용자 생성 태그
- `.externalCalendar(serviceId, calendarId)` — 구글 캘린더 등 외부 서비스

**보이기/숨기기**:
- 커스텀 태그는 생성 후 기본 보임.
- 외부 캘린더(구글 등)는 연동 시 기본 숨김 — 사용자가 명시적으로 활성화.
- 숨겨진 태그 ID 목록은 `offEventTagIdsOnCalendar`로 관리.

### ForemostEvent (강조 이벤트)

사용자가 지정한 가장 중요한 이벤트 1개. 위젯·홈화면에서 강조 노출.
- `ForemostEventId`: eventId + isTodo 플래그로 구분.
- `TodoToggleIntent`: 위젯에서 직접 완료 처리 가능.

### SharedDataStore — 반응형 공유 상태

모든 Usecase가 하나의 `SharedDataStore` 싱글톤을 통해 상태를 공유. Combine 기반으로 변화가 즉시 전파됨.

주요 키: `todos`, `schedules`, `tags`, `googleCalendarEvents`, `googleCalendarTags`, `foremostEventId`

### DB 마이그레이션

1. `AppEnvironment.dbVersion` 증가
2. 해당 `Table` 타입의 `migrateStatement(for version:)`에 case 추가

두 가지를 반드시 함께 변경해야 마이그레이션이 실행됨.

---

## 5. 코딩 컨벤션

### 네이밍

| 개념 | 패턴 |
|---|---|
| ViewModel protocol | `XXXViewModel` |
| ViewModel implementation | `XXXViewModelImple` |
| Router protocol | `XXXRouting` |
| Router implementation | `XXXRouter` |
| Builder protocol | `XXXSceneBuilder` |
| Builder implementation | `XXXBuilderImple` |
| SwiftUI state holder | `XXXViewState` |
| SwiftUI event bridge | `XXXViewEventHandler` |
| Usecase protocol | `XXXUsecase` |
| Usecase implementation | `XXXUsecaseImple` |
| Repository protocol | `XXXRepository` (Domain에 위치) |
| Local implementation | `XXXLocalRepositoryImple` |
| Remote implementation | `XXXRemoteRepositoryImple` |

### 커밋 메시지

```
[#이슈번호] 변경 내용 요약
```

예시:
```
[#508] GoogleCalendarRepositoryPool 도입 및 테스트 추가
docs: 테스트 조직화 원칙 추가
```

### 코드 스타일

- **Higher-order functions 우선**: imperative loop 대신 `map` / `flatMap` / `compactMap` / `forEach` 사용.
- **Query/Command 분리**: 읽기 연산(map/flatMap/compactMap)을 먼저 완성한 뒤, 사이드이팩트(forEach/asyncForEach)를 별도로 실행.

```swift
// Good
let accounts = services.flatMap { $0.accountIds }.compactMap { makeAccount($0) }  // query
await accounts.asyncForEach { await setup($0) }                                    // command

// Bad
var accounts: [Account] = []
for service in services {
    for id in service.accountIds {
        accounts.append(makeAccount(id))  // query + command 혼재
        await setup(id)
    }
}
```

