# CLAUDE.md

## 1. 절대 규칙

- **파일을 수정하기 전에 반드시 먼저 읽어라.** 추측으로 수정하지 말 것.
- **파일을 추가하거나 삭제한 경우 `tuist generate`를 재실행해야 한다.**
- **Query와 Command를 분리하라.** 읽기(query)와 쓰기/사이드이팩트(command)를 한 흐름에 섞지 말 것.
- **코드 수정 시 TDD 워크플로우를 따른다.** 테스트 작성 → 실패 확인 → 구현 → 통과 확인.
- **child CLAUDE.md가 있는 프레임워크의 코드를 수정한 경우**, 스펙이 변경될 수 있으면 해당 child CLAUDE.md를 다시 분석하여 반영한다.
- **객체를 변경한 경우**, 이를 참조하는 다른 객체들을 탐색하여 변경사항에 영향이 없는지 확인한다 (빌드 및 테스트 모두).
- **`.claude/rules/*.md`의 규칙은 해당 path 파일을 건드릴 때 자동 로드된다.** 로드된 rules의 조항을 구현 결정 시점에 적극 invoke할 것 — 저장만 돼 있다고 반영되는 건 아님.

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
│   └── ProjectDescriptionHelpers/
├── Package.swift               — SPM 의존성 (Tuist 4, #if TUIST PackageSettings)
├── Tuist.swift                 — Tuist 설정 파일
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
| `TodoCalendarApp/Sources/Factories/ApplicationBase.swift` | Pool/Factory 인스턴스 생성 (다중 계정 인프라 포함) |
| `Tuist/ProjectDescriptionHelpers/Project+Templates.swift` | `Project.app()` / `Project.framework()` 팩토리 헬퍼 |

---

## 3. 빌드 / 테스트

### 초기 설정

```bash
./install/install.sh   # 더미 config 파일 복사 (최초 1회)
tuist install          # SPM 의존성 resolve (Package.swift 기반)
tuist generate --no-open
open TodoCalendar.xcworkspace
```

- 파일을 추가하거나 삭제한 경우 `tuist generate --no-open` 재실행 필요.
- SPM 의존성 변경 시 `tuist install` → `tuist generate --no-open` 순서로 재실행.
- Tuist 버전은 `mise.toml`로 관리됨 (`mise install`로 설치).

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

> 테스트 작성 원칙(프레임워크, 테스트 더블, 스터빙, 조직화 등)은 [`.claude/rules/testability.md`](.claude/rules/testability.md)로 관리. 해당 path 자동 로드.

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

**EventTagColorSource** — 태그 색상 결정 프로토콜:
- `EventTagId` → default/holiday/custom 태그 색상
- `GoogleCalendarEventColorSource` → calendarId + 이벤트별 colorId로 구글 캘린더 색상 결정
- UI에서 `EventTagColorView`가 타입 기반 디스패치로 색상을 렌더링

**보이기/숨기기**:
- 커스텀 태그는 생성 후 기본 보임.
- 외부 캘린더(구글 등)는 연동 시 기본 숨김 — 사용자가 명시적으로 활성화.
- 숨겨진 태그 ID 목록은 `offEventTagIdsOnCalendar`로 관리.

### 외부 캘린더 다중 계정 아키텍처

앱은 구글 캘린더 등 외부 서비스의 **다중 계정 동시 연동**을 지원한다.

**핵심 Pool 패턴** — 계정별(accountId) 리소스를 독립적으로 관리:

| Pool | 역할 | 위치 |
|---|---|---|
| `ExternalCalendarDBConnectionPool` | 서비스별 SQLite DB 연결 (참조 카운팅, lazy open) | Domain (protocol) → Repository (impl) |
| `GoogleCalendarRepositoryPool` | accountId별 Repository 캐싱 + lazy 생성 | Domain (protocol) → App (impl) |
| `ExternalCalendarAccountRemotePool` | accountId별 Remote API 클라이언트 + 토큰 갱신 | Repository |

**데이터 집계**:
- `GoogleCalendarLocalAggregatedRepositoryImple`: 모든 연동 계정의 이벤트/태그/색상을 투명하게 합산하여 반환
- `GoogleCalendarViewAppearanceStore`: 계정별 색상/태그를 UI에 반영

> DB 구조 상세는 [`Repository/CLAUDE.md`](Repository/CLAUDE.md)의 "외부 캘린더 DB 구조" 섹션 참조.
> 계정 연동/해제 플로우 상세는 [`Domain/CLAUDE.md`](Domain/CLAUDE.md)의 "외부 캘린더 계정 연동/해제 플로우" 섹션 참조.

### ForemostEvent (강조 이벤트)

사용자가 지정한 가장 중요한 이벤트 1개. 위젯·홈화면에서 강조 노출.
- `ForemostEventId`: eventId + isTodo 플래그로 구분.
- `TodoToggleIntent`: 위젯에서 직접 완료 처리 가능.

### SharedDataStore — 반응형 공유 상태

모든 Usecase가 하나의 `SharedDataStore` 싱글톤을 통해 상태를 공유. Combine 기반으로 변화가 즉시 전파됨.

주요 키: `todos`, `schedules`, `tags`, `googleCalendarEvents`, `googleCalendarTags`, `foremostEventId`

### DB 마이그레이션

**메인 DB** (`todo_calendar.db`):
1. `AppEnvironment.dbVersion` 증가
2. 해당 `Table` 타입의 `migrateStatement(for version:)`에 case 추가
— 두 가지를 반드시 함께 변경해야 마이그레이션이 실행됨.

**외부 캘린더 DB** (`google_calendar.db`):
1. `AppEnvironment.googleCalendarDBVersion` 증가
2. 외부 캘린더 테이블의 `migrateStatement(for version:)`에 case 추가
— DB 연결은 `ExternalCalendarDBConnectionPool`이 관리하며, `onFirstOpen` 시 테이블 생성 + 마이그레이션 실행.

---

## 5. 코딩 컨벤션

코딩 스타일, 설계 원칙, 개발 철학의 상세는 [`docs/coding-style-and-philosophy.md`](docs/coding-style-and-philosophy.md)를 참조.

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

- **동작 변화 중심으로 작성**: "무엇을 수정했나(파일/클래스 목록)"가 아니라 "동작이 어떻게 달라졌나"를 한눈에 파악할 수 있게 작성.

예시:
```
❌ [#563] AppleCalendarOAuth2ServiceUsecaseImple 로직 변경 및 테스트 추가
✅ [#563] AppleCalendar 권한 상태별 분기 체크 도입
   — fullAccess → 바로 성공, denied/restricted → 즉시 throw, notDetermined → 시스템 요청 후 재확인

[#508] GoogleCalendarRepositoryPool 도입 및 테스트 추가
docs: 테스트 조직화 원칙 추가
```

---

## 6. Scene 스펙

- 화면(Scene) 단위 작업의 상세 스펙: [`docs/scene-spec.md`](docs/scene-spec.md) (6파일 구성, 생성 순서, SwiftUI 통합 템플릿, Scene 간 통신)
- 구현 시 지킬 규칙(MUST/MUST NOT): [`.claude/rules/presentations-rules.md`](.claude/rules/presentations-rules.md) (ViewAppearance, 공용 컴포넌트, SwiftUI DI, ViewModel 책임 경계, Listener weak, 모듈 경계)

