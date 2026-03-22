# Domain Framework

앱의 모든 **비즈니스 모델**, **Repository 프로토콜**, **Usecase 구현**이 위치하는 프레임워크.
Repository 구현체는 여기 없고 프로토콜만 정의한다. 구현은 `Repository/` 프레임워크에 있다.

## 폴더 구조

```
Domain/Sources/
├── Models/
│   ├── Account/        — OAuth2, Auth+Account, ExternalServiceAccountinfo
│   ├── Calendar/       — CalendarComponent, CalendarMonth, Holiday, Times
│   ├── Common/         — ClientErrorKeys, LinkPreview, ServerErrorModel, SupportMapApp
│   ├── Events/
│   │   ├── ExternalCalendar/  — GoogleCalendar.Event/Tag/Colors
│   │   ├── Repeating/  — EventRepeating, EventRepeatingOption (6종)
│   │   ├── Schedule/   — ScheduleEvent, RepeatingTimes
│   │   ├── Todo/       — TodoEvent, DoneTodoEvent
│   │   ├── EventTag.swift          — EventTagId enum + EventTag 프로토콜
│   │   ├── EventTime.swift         — at/period/allDay 3가지 시간 표현
│   │   ├── EventDetailData.swift
│   │   ├── EventSync.swift
│   │   ├── EventUploadingTask.swift
│   │   └── ForemostEvent.swift
│   ├── Notifications/  — EventNotification, EventNotificationTimeOption
│   └── Settings/       — AppearanceSettings, EventSettings, FeedbackPostMessage
├── Repositories/       — Repository 프로토콜 (구현 없음, 15개)
│   ├── Auth/           — AuthRepository, ExternalServiceIntegrateRepository
│   ├── Calendar/       — CalendarSettingRepository, HolidayRepository
│   ├── Events/         — TodoEventRepository, ScheduleEventRepository, EventTagRepository,
│   │                     ForemostEventRepository, GoogleCalendarRepository, EventDetailDataRepository,
│   │                     EventSyncRepository
│   ├── Notification/   — EventNotificationRepository
│   └── Setting/        — AppSettingRepository, FeedbackRepository, TemporaryUserDataMigrationRepository
├── Usecases/           — Usecase 구현
│   ├── Account/
│   │   ├── ExternalServiceIntegration/  — ExternalCalendarIntegrationUsecase (protocol + Imple)
│   │   ├── OAuth2/     — OAuth2ServiceUsecase, Apple/Google OAuth2 Imple
│   │   ├── AuthUsecase, AccountUsecase, AccountUsecaseImple
│   ├── Calendar/       — CalendarUsecase, CalendarSettingUsecase, HolidayUsecase
│   ├── Common/         — PagingUsecase, LinkPreviewFetchUsecase, PlaceSuggestUsecase
│   ├── Events/
│   │   ├── ExternalCalendar/  — GoogleCalendarUsecase (protocol + Imple)
│   │   ├── TodoEventUsecase, ScheduleEventUsecase, EventTagUsecase
│   │   ├── ForemostEventUsecase, EventSyncUsecase
│   │   ├── DaysIntervalCountUsecase, DoneTodoEventsPagingUsecase
│   │   ├── EventDetailDataUsecase (typealias)
│   │   └── MemorizedEventsContainer.swift
│   ├── Notification/   — EventNotificationUsecase, NotificationPermissionUsecase, UserNotificationUsecase
│   ├── Setting/        — UISettingUsecase, AppSettingUsecase, EventSettingUsecase, EventNotificationSettingUsecase
│   └── Support/        — FeedbackUsecase
└── Utils/
    ├── SharedDataStore.swift
    ├── SharedEventNotifyService.swift
    ├── EventRepeatTimeEnumerator.swift
    ├── FeatureFlag.swift
    └── RRuleParser.swift
```

## Usecase 작성 규칙

### 서브도메인 분리 기준
응집도가 높고 결합도가 낮은 기능끼리 묶는다. 폴더 구조가 이를 반영한다.

각 Usecase는 Presentation layer에서 **재사용**된다. 이때 공유되는 것은 두 가지:
- **로직**: Usecase 인스턴스 자체
- **상태**: `SharedDataStore`를 통해 공유 (서로 다른 VM이 같은 Usecase를 쓰면 상태가 자동으로 공유됨)

### typealias Usecase
비즈니스 로직 없이 Repository를 그대로 노출하면 되는 경우, typealias로 정의한다.

```swift
// EventDetailDataUsecase.swift — 현재 유일한 typealias Usecase
public typealias EventDetailDataUsecase = EventDetailDataRepository
```

새 Usecase를 추가할 때 "이 Usecase가 Repository 결과를 bypass만 하는가?"를 먼저 따져볼 것.

---

## SharedDataStore

모든 Usecase가 공유하는 중앙 상태 저장소. Combine 기반으로 변화가 즉시 전파된다.
`Domain/Sources/Utils/SharedDataStore.swift`

### 주요 키 (ShareDataKeys)

| 키 | 타입 | 담당 Usecase |
|---|---|---|
| `accountInfo` | `AccountInfo` | AccountUsecase |
| `todos` | `[String: TodoEvent]` | TodoEventUsecase |
| `uncompletedTodos` | `[TodoEvent]` | TodoEventUsecase |
| `schedules` | `MemorizedEventsContainer<ScheduleEvent>` | ScheduleEventUsecase |
| `tags` | `[EventTagId: any EventTag]` | EventTagUsecase |
| `offEventTagSet` | `Set<EventTagId>` | EventTagUsecase |
| `defaultEventTagColor` | `[EventTagId: String]` | EventTagUsecase |
| `foremostEventId` | `ForemostEventId` | ForemostEventUsecase |
| `foremostMarkingStatus` | `ForemostMarkingStatus` | ForemostEventUsecase |
| `googleCalendarTags` | `[String: [GoogleCalendar.Tag]]` | GoogleCalendarUsecase |
| `googleCalendarEvents` | `[String: GoogleCalendar.Event]` | GoogleCalendarUsecase |
| `externalCalendarAccounts` | `[String: [ExternalServiceAccountinfo]]` | ExternalCalendarIntegrationUsecase |
| `calendarAppearance` | `CalendarAppearanceSettings` | UISettingUsecase |
| `eventSetting` | `EventSettings` | EventSettingUsecase |
| `timeZone` | `TimeZone` | CalendarSettingUsecase |
| `firstWeekDay` | `DayOfWeeks` | CalendarSettingUsecase |
| `currentCountry` | `String` | HolidayUsecase |
| `availableCountries` | `[String]` | HolidayUsecase |
| `holidays` | `[Int: [Holiday]]` | HolidayUsecase |

### 사용 패턴

```swift
// 전체 저장 (replace)
sharedDataStore.put([TodoEvent].self, key: ShareDataKeys.uncompletedTodos.rawValue, todos)

// 부분 업데이트 (mutation) — update는 저장 전용, 결과를 밖으로 캡처하지 말 것
sharedDataStore.update([String: TodoEvent].self, key: shareKey) {
    ($0 ?? [:]) |> key(event.uuid) .~ event
}

// 구독
sharedDataStore.observe([TodoEvent].self, key: shareKey)
    .map { $0 ?? [] }
    .eraseToAnyPublisher()

// 현재값 동기 조회
let current = sharedDataStore.value([TodoEvent].self, key: shareKey)
```

---

## SharedEventNotifyService

이벤트 로딩 진행 상태처럼 **SharedDataStore로 표현하기 어려운 일시적 이벤트**를 전파할 때 사용한다.
`Domain/Sources/Utils/SharedEventNotifyService.swift`

### RefreshingEvent (5가지)
- `refreshingTodo(Bool)` — Todo 목록 로딩
- `refreshingSchedule(Bool)` — 일정 목록 로딩
- `refreshingCurrentTodo(Bool)` — 오늘의 Todo 로딩
- `refreshingUncompletedTodo(Bool)` — 미완료 Todo 로딩
- `refreshForemostEvent(Bool)` — 강조 이벤트 로딩

### 사용 패턴

```swift
// Publisher extension으로 간편하게 — subscription 시 true, completion 시 false 발송
self.todoRepository.loadCurrentTodoEvents()
    .handleNotify(self.eventNotifyService) {
        $0 ? RefreshingEvent.refreshingCurrentTodo(true) : .refreshingCurrentTodo(false)
    }
    .sink(...)

// 직접 구독
self.eventNotifyService.event<RefreshingEvent>()
    .sink { event in ... }
```

---

## MemorizedEventsContainer

반복 이벤트(ScheduleEvent)의 발생 인스턴스를 기간별로 캐싱하는 컨테이너.
`Domain/Sources/Usecases/Events/MemorizedEventsContainer.swift`

- **ScheduleEvent에만 사용**. TodoEvent는 평면 딕셔너리(`[String: TodoEvent]`)로 충분.
- **Immutable**: 모든 변경 메서드가 새 컨테이너를 반환.
- `refresh(_:in:)` — 특정 기간의 이벤트 목록으로 캐시 갱신
- `append(_:)` — 새 이벤트 추가
- `invalidate(_:)` — 특정 이벤트 캐시 제거
- `replace(_:ifExists:)` — 특정 이벤트 교체 또는 제거
- `events(in:)` — 기간 내 이벤트 조회
- `evnet(_:)` — 단일 이벤트 ID로 조회

---

## 서브도메인별 주요 Usecase 한눈에 보기

| 서브도메인 | Usecase | 역할 |
|---|---|---|
| Account | `AuthUsecase` | 로그인/로그아웃 |
| Account | `AccountUsecase` | 사용자 계정 정보 관리 |
| Account | `ExternalCalendarIntegrationUsecase` | 구글 계정 연동/해제 |
| Account | `OAuth2ServiceUsecase` | OAuth2 요청/응답 (Apple/Google Imple) |
| Events | `TodoEventUsecase` | Todo CRUD, 완료/되돌리기/스킵 |
| Events | `ScheduleEventUsecase` | 일정 CRUD, 반복 수정/제외/분기 |
| Events | `EventTagUsecase` | 태그 관리, On/Off 토글 |
| Events | `ForemostEventUsecase` | 강조 이벤트 1개 관리 |
| Events | `GoogleCalendarUsecase` | 구글 캘린더 태그·이벤트 로드 |
| Events | `EventDetailDataUsecase` | 이벤트 상세(메모·위치) — typealias |
| Events | `EventSyncUsecase` | 서버 동기화 |
| Events | `DaysIntervalCountUsecase` | 날짜 간 일수 계산 |
| Events | `DoneTodoEventsPagingUsecase` | 완료된 Todo 페이징 조회 |
| Calendar | `CalendarUsecase` | 월별 캘린더 컴포넌트 계산 |
| Calendar | `CalendarSettingUsecase` | 첫 요일, 타임존 설정 |
| Calendar | `HolidayUsecase` | 공휴일 로드 |
| Notification | `EventNotificationUsecase` | 로컬 알림 동기화 |
| Notification | `NotificationPermissionUsecase` | 알림 권한 요청/확인 |
| Notification | `UserNotificationUsecase` | 사용자 알림 수신/전달 |
| Setting | `UISettingUsecase` | 앱 외관 설정 |
| Setting | `AppSettingUsecase` | 일반 앱 설정 |
| Setting | `EventSettingUsecase` | 이벤트 동작 설정 |
| Setting | `EventNotificationSettingUsecase` | 이벤트별 알림 기본값 |
| Common | `PagingUsecase` | 범용 페이징 로직 |
| Common | `LinkPreviewFetchUsecase` | 링크 미리보기 메타데이터 |
| Common | `PlaceSuggestUsecase` | 장소 자동완성 |
| Support | `FeedbackUsecase` | 사용자 피드백 제출 |
