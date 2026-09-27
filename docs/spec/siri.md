# Siri·App Intents 연동 스펙 (초안)

> 상위: 캠페인 #801 (iOS 27 Siri). 이 문서는 DP-0.1(#1157) 실측으로 확정한 사실만 담는다. 기준 환경은 Xcode 27.0, iOS 27.0 SDK, iOS 27.0 실기다. 후속 DP 가 구현하면서 절을 채운다.

## 1. 역할 분담

- **앱 밖은 Siri 가 먼저 받는다.** 조회·생성·단건 수정이 Siri 몫이다. Siri 경로는 무료이고 로그인이 필요 없다.
- **앱 안은 지금 기능을 유지한다.**
- **Siri 가 못 받는 요청은 AI 커맨드가 받는다.** 여러 건 재배치나 정의되지 않은 질의가 여기 든다. `SendAICommandIntent` 가 와일드카드 intent 로 받고, 지금처럼 로그인과 일일 크레딧 한도를 유지한다.
- **스키마 CRUD 는 언어 지원에 묶인다.** App Schema intent 를 고르는 쪽은 Siri AI 다. iOS 27.0 의 Siri AI 는 영어 전용이고, 한국어는 iOS 27.2 부터 제공된다(§4).

## 2. 가정 판정

| 가정 | 내용 | 판정 | 근거 |
|---|---|---|---|
| A1 | reminders·calendar 스키마가 Todo·Schedule 의 핵심 필드(제목·시간 3형태·완료)를 담는다 | 성립 | §3. Todo 기간의 끝 시각과 알림만 추가 파라미터로 붙인다 |
| A2 | 한국어 발화가 우리 스키마 intent 로 라우팅된다 | 깨짐 (iOS 27.0) | §4. 한국어 생성 발화가 시스템 미리알림·캘린더로 갔다. 영어 라우팅은 미확인이다 |
| A3 | 스키마 밖 요청이 문구 없는 자연어로 AI 커맨드에 닿는다 | 판정 불가 | §4. 문구 없는 한국어 발화를 관찰하지 않았고, iOS 27.0 Siri AI 가 한국어를 지원하지 않아 27.2 전에는 판정할 수 없다. 등록 문구로는 닿지만 다른 앱과 되묻는다 |
| A4 | 앱이 꺼진 상태에서 앱 본체 intent 가 조립된 앱 위에서 돈다 | 성립 | §5. scene 이 연결되는 기동에서만 관찰했다 |
| A7 | 정적 프레임워크에 둔 AppEntity 가 시스템에 노출된다 | 성립 | §6 |

## 3. 스키마 슬롯과 우리 필드 매핑

### 3-1. 필수 슬롯 검사

- Swift 매크로(`@AppEntity(schema:)`·`@AppIntent(schema:)`)는 프로토콜 적합만 본다.
- 스키마 필수 슬롯은 빌드 단계의 `appintentsmetadataprocessor` 가 검사한다. 누락 슬롯, 타입 불일치, optional 강제, 필수 enum case 를 `파일:줄` 로 알려준다. 하나라도 걸리면 그 타깃의 App Intents metadata 전체가 빠진다.
- 스키마 타입만 `@available(iOS 27.0, *)` 로 가두면 배포 타깃 17.0 으로 빌드된다.
- 스키마 entity 가 참조하는 하위 entity·enum 도 같은 스키마로 구현해야 한다.
  - reminders: `list`·`section`·`locationTrigger` entity 와 `listType`·`locationTriggerEvent` enum
  - calendar: `calendar`·`attendee` entity 와 `eventStatus`·`eventSpan`·`attendeeType`·`attendeeStatus` enum
- 같은 스키마 enum 을 두 타입이 채택하면 앱 단위 중복 에러가 난다.
- intent 파라미터로 쓰는 entity 는 `IndexedEntity`·`UniqueAppEntity`·`TransientAppEntity` 중 하나이거나, 기본 query 가 `EntityStringQuery`·`IntentValueQuery` 여야 한다.
- create·update intent 는 `perform()` 이 `ReturnsValue<스키마 entity>` 를 돌려줘야 한다.
- 스키마에 없는 필드는 `@Parameter(title:)`·`@Property(title:)` 를 명시하면 metadata 에 실린다. 주석 없는 `var` 는 오류 없이 빠진다.
- 스키마 entity 의 저장 프로퍼티에는 기본값을 줄 수 없다. 매크로가 붙이는 property wrapper 가 초기값 인자를 받지 않으므로 init 에서 대입한다.

### 3-2. reminders ↔ Todo

필수 여부 칸의 `필수` 는 스키마가 선언을 요구한다는 뜻이다. 괄호의 `req` 는 non-optional 강제, `opt` 는 optional 강제다. 붙는 방식 칸의 `필수 슬롯` 은 우리 필드가 늘 값을 채우는 자리고, `선택 값으로 담는다` 는 필드가 없으면 nil 로 두는 자리다. `추가 파라미터` 는 스키마에 없는 필드를 `@Parameter`·`@Property` 로 명시해 붙인다는 뜻이다.

| 스키마 슬롯 (타입) | 필수 여부 | 우리 필드 | 붙는 방식 |
|---|---|---|---|
| reminder.title / createReminder.title (`String`) | 필수 | `name` | 필수 슬롯 |
| reminder.dueDate / createReminder.dueDate (`DateComponents?`) | 필수 | `time` — nil 이면 nil, `at` 은 날짜·시각, `allDay` 는 날짜만 | 선택 값으로 담는다 |
| (없음) | — | `time` 이 `period` 일 때의 끝 시각 | 추가 파라미터 |
| reminder.isCompleted / updateReminder.isCompleted (`Bool`) | 필수 | 완료 | 필수 슬롯 |
| reminder.recurrence (`Calendar.RecurrenceRule?`) | 필수 | `repeating` | 선택 값으로 담는다. 음력 반복은 표현할 수 없어 AI 커맨드 몫이다 |
| reminder.list (`ListEntity`) | 필수 | `eventTagId` (이벤트 타입) | 필수 슬롯 |
| reminder.note (`String?`) | 필수 | `EventDetailData.memo` | 선택 값으로 담는다 |
| (없음) | — | `notificationOptions` | 추가 파라미터 |
| reminder.isFlagged (`Bool?`) | 필수 (opt) | ForemostEvent 후보 | 선택 값으로 담는다 |
| (없음) | — | 반복 할 일 건너뛰기 | 별도 intent |
| reminder.urls·tags / createReminder.urls·tags·images (`[URL]`·`Set<String>`·`[IntentFile]`) | 필수 (파라미터는 req) | 없음 | 빈 값으로 받고 무시 |
| reminder.creationDate·completionDate (`Date?`) | 필수 | 없음 | 조회 전용 |
| reminder.locationTrigger / createReminder.section (하위 entity) | 필수 | 없음 | 선언만 |

- `list` entity 필수 슬롯: `name: String`, `type: listType`
- `section` entity 필수 슬롯: `name: String`, `list: ListEntity`
- `locationTrigger` entity 필수 슬롯: `event`(case `arrive`·`depart`), `place: PlaceDescriptor`
- updateReminder 는 대상 파라미터 `target` 과 위 슬롯들을 받는다. deleteReminders 는 `entities: [reminder]` 를 받는다(`DeleteIntent`).

### 3-3. calendar ↔ Schedule

| 스키마 슬롯 (타입) | 필수 여부 | 우리 필드 | 붙는 방식 |
|---|---|---|---|
| event.title / createEvent.title (`String`) | 필수 | `name` | 필수 슬롯 |
| event.startDate·endDate / createEvent.startDate·endDate (`Date` / `Date?`) | 필수 (createEvent.endDate 는 opt) | `time` — `at` 은 시작만, `period` 는 시작·끝 | 필수 슬롯 |
| event.isAllDay / createEvent.isAllDay (`Bool`) | 필수 (파라미터 req) | `time` 이 `allDay` | 필수 슬롯 |
| event.recurrence (`Calendar.RecurrenceRule?`) | 필수 | `repeating` | 선택 값으로 담는다. 음력 반복은 AI 커맨드 몫이다 |
| updateEvent.span / deleteEvent.span (`eventSpan` — `this`·`future`·`all`) | 필수 | 반복 일정 수정 범위(이번만·이후·전체) | 선택 값으로 담는다. 우리 범위와 1:1 이다 |
| event.calendar / createEvent.calendar (`CalendarEntity`) | 필수 (파라미터 req) | `eventTagId` (이벤트 타입) | 필수 슬롯. 발화에 없으면 기본 타입으로 채운다 |
| event.note (`String?`) | 필수 | `EventDetailData.memo` | 선택 값으로 담는다 |
| event.location (union `PlaceDescriptor \| String`) | 필수 | `EventDetailData.place` | 선택 값으로 담는다 |
| event.alarms (`[union Duration \| Date]`) | 필수 (entity 만) | `notificationOptions` | create·update 파라미터엔 없어 추가 파라미터로 받는다 |
| event.attendees / createEvent.attendees (`[AttendeeEntity]`) | 필수 (파라미터 req) | 없음 | 빈 배열로 받고 무시 |
| event.status·organizers·virtualLocation·travelTime (enum·`[IntentPerson]`·`URL?`·`Measurement<UnitDuration>?`) | 필수 (status 는 opt) | 없음 | 선언만 |

- `calendar` entity 필수 슬롯: `title: String`
- `attendee` entity 필수 슬롯: `person: IntentPerson`, `isAttendanceOptional: Bool`, `status`(case `accepted`·`declined`·`tentative`), `type`
- `eventStatus` 는 case `confirmed`·`tentative`·`cancelled` 가 필수다.
- updateEvent 는 대상 파라미터 `event` 와 `span` 을 받는다. deleteEvent 는 `entity` 와 `span` 을 받는다.

## 4. Siri 라우팅

iOS 27.0 실기, Siri 언어 한국어, Apple Intelligence 켬 상태에서 관찰했다.

| 발화 | 결과 |
|---|---|
| "투두캘린더에 내일 오후 3시 장보기 미리알림 추가해줘" | 시스템 미리알림 앱 |
| "투두캘린더에 금요일 저녁 7시 회의 일정 잡아줘" | 시스템 캘린더 앱 |
| "투두캘린더한테 부탁해" (등록된 App Shortcut 문구) | 지갑 앱과 To-do Calendar 중 어느 쪽인지 되물음 |
| 영어 발화 | Siri 언어가 한국어라 판정에서 뺐다 |

- iOS 27.0 의 Siri AI 는 영어 전용이다. 한국어는 iOS 27.2 에서 추가된다 ([MacRumors 2026-09-16](https://www.macrumors.com/2026/09/16/siri-ai-new-languages-ios-27-2/)).
- 한국어 발화가 스키마 intent 대신 시스템 앱으로 가는 동작은 이 언어 제약과 맞는다. 27.2 에서 한국어 스키마 라우팅이 되는지는 미확인이다.
- App Shortcut 문구 경로는 한국어로도 우리 앱까지 닿는다. 문구는 `ko.lproj/AppShortcuts.strings` 의 등록 문장과 거의 같아야 잡힌다.
- 시뮬레이터에는 Apple Intelligence 가 없어 라우팅을 관찰할 수 없다. 라우팅 확인은 실기에서만 한다.

## 5. 앱이 꺼진 상태의 기동 조립

- 앱 본체 intent(`openAppWhenRun = false`)를 앱이 완전히 종료된 상태에서 단축어로 실행했다. `perform()` 진입 시점에 connected scene 이 1 개였고, 로그인 상태별 usecase factory 가 이미 설정돼 있었다. 할 일 생성까지 끝났다.
- iOS 가 창 없이 기동할 때도 scene 을 연결하므로 `SceneDelegate` → `prepareInitialScene` 경로가 돈다.
- 이 순서는 관찰 결과일 뿐 코드가 보장하지 않는다. `prepareInitialScene` 은 비동기 `Task` 로 준비를 돌린다.
- 준비는 `SceneDelegate` → `prepareInitialScene` → `setupInitialScene` 한 경로에서만 돈다. scene 없이 백그라운드로 뜨는 경우는 관찰하지 못했다.
- `perform()` 안에서 `prepareLaunch()` 와 factory 설정을 직접 돌리는 우회는 관찰하지 못했다. 시험 intent 는 factory 가 없을 때만 우회하는데, 실행한 두 번 모두 factory 가 이미 서 있었다.
- factory 를 기다리는 방식, 대기 상한, 상한을 넘긴 뒤의 동작은 DP-1.1 에서 정한다.

## 6. 정적 프레임워크의 AppEntity

- `Scenes`(정적 프레임워크)에 둔 `AppEntity` 와 그것을 파라미터로 받는 `AppIntent` 가 `AppIntentsPackage` 등록 없이 앱의 `Metadata.appintents` 에 병합된다.
- `-dead_strip` 링크 뒤에도 타입 심볼이 앱 바이너리에 남는다.
- 실기 단축어 앱에서 그 intent 가 목록에 뜬다. 엔티티를 고를 수 있고, 실행까지 된다.
- 그래서 onscreen annotation 에 쓸 엔티티를 화면 코드가 있는 Presentation 프레임워크 쪽에 둘 수 있다.

## 관련 파일

- `TodoCalendarApp/Sources/AppIntents/SendAICommandIntent.swift` — AI 커맨드 와일드카드 intent
- `TodoCalendarApp/Sources/AppIntents/TodoCalendarAppShortcuts.swift` — AI 커맨드 호출 문구
- `TodoCalendarApp/Resources/Localize/ko.lproj/AppShortcuts.strings` — 한국어 호출 문구
- `TodoCalendarApp/Sources/Root/ApplicationRootViewModel.swift` — `prepareInitialScene`
- `TodoCalendarApp/Sources/Root/ApplicationRootRouter.swift` — `setupInitialScene`·`changeUsecaseFactroy`
