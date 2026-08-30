# Apple 캘린더 연동 상세 스펙

기기에 이미 있는 캘린더(EventKit)를 앱 달력에 합산하고, 쓰기 가능한 캘린더의 이벤트는 앱에서 바로 수정·삭제한다.

Google 캘린더와 같은 External Calendar context에 속하지만 성격이 다르다.

| | Google | Apple |
|---|---|---|
| 자격 | OAuth2 토큰 (Keychain) | 기기 권한 (EventKit) |
| 계정 | 다중 계정 (accountId별 Pool) | **단일** — 기기 하나 |
| 데이터 출처 | 원격 API + DB 캐시 | EventKit 로컬 store + DB 캐시 |
| 쓰기 | `readWrite` scope 재인증 필요 | `fullAccess` 권한이면 바로 |

상세 비교와 Google 쪽 절차는 [google-calendar.md](google-calendar.md).

---

## 1. 연동 — 권한 상태별 분기

Apple 캘린더의 "인증"은 OAuth 왕복이 아니라 EventKit 권한 확인이다. `AppleCalendarOAuth2ServiceUsecaseImple`이 `OAuth2ServiceUsecase` 인터페이스를 맞추되 내부는 권한 체크로 구현한다.

```swift
enum AppleCalendarAuthorizationStatus {
    case notDetermined, restricted, denied, fullAccess, writeOnly
}
```

| 상태 | 동작 |
|---|---|
| `fullAccess` | 조회 없이 바로 성공 |
| `denied` | `AppleCalendarPermissionFailReason.denied` → 설정 이동 유도 |
| `restricted` | `.restricted` → 기기 정책으로 지원 불가 안내 |
| `notDetermined` · `writeOnly` | 시스템 권한 요청 후 재확인 |

`writeOnly`는 승격을 시도하고, 실패하면 `.writeOnly`로 던져 설정 이동을 유도한다. 앱은 읽기가 되어야 하므로 `writeOnly`만으로는 연동이 성립하지 않는다.

`isAuthorized()`는 `fullAccess`만 참으로 본다.

`handle(open:)`은 항상 `false` — 리디렉션 URL을 쓰지 않는다.

---

## 2. 캘린더와 태그

기기의 각 캘린더가 `AppleCalendar.Tag` 하나가 되고, 태그 id는 `.externalCalendar(serviceId: AppleCalendarService.id, id: calendarId)`다.

| 필드 | 설명 |
|---|---|
| `id` | EventKit 캘린더 식별자 |
| `name` | 캘린더 이름 |
| `colorHex` | 캘린더 색 |
| `isWritable` | **`nil` = 캐시에서 올라온 태그라 EventKit 쓰기 가능 여부를 아직 확인 못함** |

외부 캘린더 태그는 다른 태그와 달리 **기본 숨김**이다. 이벤트 종류 목록에서 사용자가 캘린더 단위로 켠다. 연동을 해제해도 기기나 계정의 원본은 지워지지 않는다.

`isWritable`이 3-state인 게 핵심이다. `isCalendarWritable(_:)`이 `AnyPublisher<Bool?, Never>`를 내는 것도 같은 이유 — `nil`은 "아직 판정 불가"이고, 소비측은 판단을 미룬다. `false`로 뭉개면 캐시에서 막 올라온 순간에 편집 버튼이 잘못 사라진다.

---

## 3. 이벤트 모델

| 타입 | 용도 |
|---|---|
| `AppleCalendar.Event` | 목록·그리드용 축약 — 이름·시간·위치·반복 여부 |
| `AppleCalendar.EventOrigin` | 상세용 — 위에 더해 `recurrenceRules`·`attendees`·`url`·`notes` |

`EventOrigin.asEvent()`로 축약형을 파생한다.

참석자(`AppleCalendar.Attendee`)는 이름·이메일과 상태(`unknown`/`pending`/`accepted`/`declined`/`tentative`), 주최자 여부, 본인 여부를 담는다.

### 반복 인스턴스 식별자

```
{originalEventId}#occ:{timestamp}
```

`AppleCalendar.EventOccurrenceId`가 이 합성 id를 파싱한다. 마커를 **뒤에서부터** 찾는다 — 원본 id 자체에 `#occ:`가 들어 있어도 마지막 것이 회차 구분자다. 마커가 없으면 전체를 `originalEventId`로 보고 `occurrenceDate`는 `nil`.

---

## 4. 조회 — 캐시 먼저, 그 다음 EventKit

`AppleCalendarRepositoryImple`은 한 번의 구독에 값을 최대 두 번 흘린다.

```
loadEvents(in: period)
  ├─▶ DB 캐시가 비어있지 않으면 즉시 방출
  └─▶ EventKit에서 다시 읽어 방출 + 캐시 갱신
```

상세(`loadEventOrigin`)는 여기에 병합이 하나 더 붙는다. 캐시본을 먼저 내보내고, EventKit에서 **원본 이벤트**(`originalEventId` 기준)를 읽어 캐시본과 병합한 값을 다시 내보낸다. 반복 인스턴스는 자기 시간을 갖지만 반복 규칙·참석자 같은 정보는 원본에 있기 때문이다.

### 위젯용 read-only 구현체

`AppleCalendarLocalAggregatedRepositoryImple`은 **DB 캐시에서만** 읽는다. 위젯 확장에는 EventKit 접근 경로를 두지 않는다.

- `loadEventOrigin(id:)` → 항상 `Just(nil)`. 없음을 completion이 아니라 **명시적 nil**로 방출한다.
- `updateEvent` / `removeEvent` → `RuntimeError` throw. 쓰기는 지원 대상이 아니다.

### 저장소

App Group 안의 `{AppleCalendarService.id}__calendar.db`. 테이블은 `AppleCalendarTagTable`·`AppleCalendarEventTable` 둘이고, 반복 규칙과 참석자는 JSON 문자열 컬럼으로 직렬화한다. 외부 캘린더 DB 버전은 `AppEnvironment.appleCalendarDBVersion`으로 메인 DB와 따로 센다.

---

## 5. 쓰기 — 수정과 삭제

```swift
struct EventEditParams {
    var name, location, url, notes: String?
    var time: EventTime?
    var recurrenceRules: [String]?      // RRULE 문자열
}

enum EventEditScope {
    case thisEventOnly
    case thisAndFuture
}
```

`isEmpty`인 params는 보낼 게 없다. 모든 필드가 옵셔널이라 부분 수정(patch)이다.

`updateEvent` / `removeEvent` 는 EventKit에 먼저 쓰고, 성공한 결과로 DB 캐시를 갱신한다.

### 쓰기 가능 판정

캘린더 단위로 갈린다. `isCalendarWritable(calendarId)`가 `true`인 캘린더의 이벤트만 편집 UI를 연다. 앞서 말한 대로 `nil`이면 판단을 미룬다.

### RRULE 변환

`AppleCalendar+RecurrenceRule.swift`가 `EKRecurrenceRule` ↔ RRULE 문자열을 양방향 변환한다. 앱은 반복 규칙을 RRULE 문자열로 다루고, EventKit 경계에서만 `EKRecurrenceRule`로 바꾼다.

- `FREQ`, `INTERVAL`, `BYDAY`, `BYMONTHDAY`, `BYMONTH`, `WKST`, `UNTIL`/`COUNT`를 다룬다.
- 앱 자체 반복 모델(`EventRepeating`)로 접지 않는다 — Apple 이벤트의 반복은 원본 표현을 유지한 채 왕복시킨다.

---

## 6. 앱 달력에 합산되는 경로

```
AppleCalendarUsecase.prepare()
  ├─ refreshCalendarTags()   ──▶ EventTagUsecase · AppleCalendarViewAppearanceStore 에 반영
  └─ refreshEvents(in:)      ──▶ SharedDataStore 를 통해 캘린더 화면에 합산
```

- 색상은 `AppleCalendarEventColorSource`가 캘린더 색을 그대로 쓴다. 커스텀 태그처럼 앱에서 색을 바꾸지 않는다.
- 연동 해제 시 `AppleCalendarViewAppearanceStore.clearCalendarTags()`로 태그를 걷고, 캐시를 리셋한다.
- 태그·색상 체계 전반은 [tags-foremost-notifications.md](tags-foremost-notifications.md).

Live Activity 대상으로도 지정할 수 있다 — `LiveActivityTarget.appleCalendar(calendarId:eventId:)`.

---

## 관련 파일

| 파일 | 역할 |
|---|---|
| `Domain/Sources/Models/Events/ExternalCalendar/AppleCalendarEvent.swift` | Tag·Event·EventOrigin·Attendee·OccurrenceId |
| `Domain/Sources/Models/Events/ExternalCalendar/AppleCalendarEventEditParams.swift` | 수정 파라미터·범위 |
| `Domain/Sources/Models/Events/ExternalCalendar/AppleCalendarPermissionFailReason.swift` | 권한 실패 사유 |
| `Domain/Sources/Usecases/Events/ExternalCalendar/AppleCalendarUsecase.swift` | 태그·이벤트 갱신, 쓰기 가능 판정, 수정·삭제 |
| `Domain/Sources/Usecases/Account/OAuth2/AppleCalendarPermissionChecker.swift` | 권한 상태 조회·요청 |
| `Services/AuthService/Sources/AppleCalendarOAuth2ServiceUsecaseImple.swift` | 권한 상태별 연동 분기 |
| `Repository/Sources/Repository+Imple/Event/ExternalCalendar/Apple/` | EventKit 접근·캐시·RRULE 변환 |
