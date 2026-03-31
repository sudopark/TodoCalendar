# TodoCalendar 제품 기획서

> 코드베이스 기반 기능/정책 명세. 최종 갱신: 2026-03-31

---

## 1. 앱 개요

| 항목 | 내용 |
|---|---|
| 플랫폼 | iOS 17+ |
| 아키텍처 | 오프라인 우선 (Offline-First), MVVM + Router + Builder |
| UI | SwiftUI + UIKit 하이브리드 |
| 빌드 | Tuist v3, Swift 6.0 |
| App Scheme | `tc.app://` |

**핵심 가치**: 캘린더와 할일을 하나의 앱에서 통합 관리. 로그인 없이도 모든 핵심 기능 사용 가능하며, 로그인 시 클라우드 동기화 제공.

---

## 2. 화면 구성

### 2.1 메인 캘린더 (`CalendarScene`)

월별 캘린더 그리드 + 선택일 이벤트 목록으로 구성된 메인 화면.

**캘린더 그리드**
- 좌우 스와이프로 월 이동 (UIPageViewController 기반 무한 페이징)
- 날짜 셀에 이벤트 색상 바 표시, "+N개 더보기" 인디케이터
- 공휴일/주말 강조 표시
- 오늘 날짜 하이라이트
- "오늘" 버튼으로 현재 날짜 복귀
- 날짜 롱프레스 → 날짜 선택 다이얼로그 (빠른 이동)

**일별 이벤트 목록 (`DayEventList`)**
- 선택 날짜의 모든 이벤트 표시 (할일, 일정, 공휴일, 구글 캘린더 이벤트)
- 날짜 정보: 양력 + 음력 날짜, 공휴일명
- 강조 이벤트(Foremost Event) 상단 고정 표시
- 미완료 할일 목록 섹션
- 이벤트 셀: 타입 아이콘, 이름, 시간, 태그 색상
- 인라인 빠른 할일 입력
- "+일정" / "+할일" 버튼
- "완료 목록" 버튼 → 완료 할일 목록으로 이동

### 2.2 이벤트 상세 (`EventDetailScene`)

하나의 화면에서 생성/수정/조회를 모두 처리. ViewModel 변형으로 모드 분기.

**모드**
| 모드 | 설명 |
|---|---|
| 생성 (Add) | 할일/일정 타입 선택 후 새 이벤트 생성 |
| 할일 수정 (EditTodo) | 기존 할일 편집 |
| 일정 수정 (EditSchedule) | 기존 일정 편집 |
| 공휴일 상세 (Holiday) | 읽기 전용, D-Day 카운트다운 |
| 구글 캘린더 상세 (GoogleCalendar) | 읽기 전용, 구글에서 편집 링크 제공 |
| 완료 할일 상세 (DoneTodo) | 읽기 전용, 완료 취소(되돌리기) 가능 |

**입력 필드**
| 필드 | 할일 | 일정 | 필수 여부 |
|---|---|---|---|
| 이름 | O | O | 필수 |
| 날짜/시간 | 선택 | 필수 | — |
| 하루종일 토글 | O | O | — |
| 기간 (duration) | — | O | — |
| 반복 | O | O | — |
| 알림 (복수) | O | O | — |
| 태그/색상 | O | O | — |
| 위치 | O | O | — |
| URL | O | O | — |
| 메모 | O | O | — |

**추가 액션 (수정 모드)**
- 삭제 (반복 이벤트: 이번만/전체 범위 선택)
- 복사 (기존 이벤트를 템플릿으로 새 이벤트 생성)
- 타입 변환 (할일 ↔ 일정)
- 강조 이벤트 토글 (Foremost 지정/해제)
- 공유

**하위 모달**
- 반복 옵션 선택 (`SelectEventRepeatOptionViewController`)
- 태그 선택 (`SelectEventTagViewController`) → 태그 생성/관리 가능
- 알림 시간 선택 (`SelectEventNotificationTimeViewController`)
- 지도 앱 선택 (`SelectMapAppDialog`) — Apple/Google/Naver/Kakao

### 2.3 완료 할일 목록 (`DoneTodoEventListViewController`)

- 완료 날짜 기준 그룹핑 (오늘, 어제, 이번 달, 월별, 연별)
- 무한 스크롤 페이지네이션
- 셀 탭 → 완료 할일 상세
- 완료 취소 (되돌리기) — 1초 취소 기회 제공
- 일괄 삭제: 전체 / 1개월 / 3개월 / 6개월 / 1년 이전

### 2.4 설정 (`SettingItemListViewController`)

**메뉴 구조**
```
설정
├── 계정 (로그인/계정 관리)
├── 외형 설정
│   ├── 캘린더 외형
│   ├── 컬러 테마
│   ├── 타임존
│   └── 위젯 외형
├── 이벤트 설정
│   ├── 기본 태그
│   ├── 기본 알림 시간
│   └── 기본 지도 앱
├── 공휴일 설정
│   └── 국가 선택
├── 피드백 전송
├── 도움말 (외부 링크)
├── 앱 공유
├── 앱스토어 리뷰
└── 소스코드 (GitHub)
```

### 2.5 인증 (`MemberScenes`)

| 화면 | 설명 |
|---|---|
| 로그인 | 바텀시트 모달, 구글 OAuth2 |
| 계정 관리 | 로그인 방법, 이메일, 최종 로그인 시간 표시. 로그아웃/계정 삭제/데이터 마이그레이션 |

---

## 3. 이벤트 모델

### 3.1 할일 (TodoEvent)

> **상세 스펙**: [spec/todo-event.md](spec/todo-event.md) — 유효성 검증, 완료/수정/삭제 상태 전이, 조회 필터링

| 속성 | 타입 | 설명 |
|---|---|---|
| uuid | String | 고유 식별자 (자동 생성) |
| name | String | 이벤트 이름 (**필수 — 유일한 필수값**) |
| creatTimeStamp | TimeInterval? | 생성 시각 |
| eventTagId | EventTagId? | 태그/색상 |
| time | EventTime? | 시간 (없으면 "현재 할일") |
| repeating | EventRepeating? | 반복 설정 |
| repeatingTurn | Int? | 현재 반복 회차 (nil = turn 1) |
| notificationOptions | [EventNotificationTimeOption] | 알림 시간 목록 |

**생명주기**
```
[미완료] ──완료──→ [DoneTodoEvent 생성]
                       │
                   완료 취소
                       │
                       ↓
                  [TodoEvent 복원]
```

**완료 처리 규칙**
| 시간 | 반복 | 원본 | 다음 반복 |
|---|---|---|---|
| 없음 | 없음 | 삭제 | — |
| 있음 | 없음 | 삭제 | — |
| 없음/있음 | 있음 | 삭제 | 새 인스턴스 생성 (다음 turn) |

**수정 방식**: `.put` (전체 교체, name 필수) / `.patch` (부분 수정, 1개 이상 필드)
**반복 수정 범위**: `.all` (전체) / `.onlyThisTime` (새 할일 생성 + 원본 전진)
**건너뛰기**: `.next` (1회 건너뛰기) / `.until(EventTime)` (지정 시간까지)

### 3.2 일정 (ScheduleEvent)

> **상세 스펙**: [spec/schedule-event.md](spec/schedule-event.md) — 3가지 수정 범위 상세, 캐시 시스템, 제외 목록

| 속성 | 타입 | 설명 |
|---|---|---|
| uuid | String | 고유 식별자 (자동 생성) |
| name | String | 이벤트 이름 (**필수**) |
| time | EventTime | 시간 (**필수** — 할일과 다름) |
| eventTagId | EventTagId? | 태그/색상 |
| repeating | EventRepeating? | 반복 설정 |
| showTurn | Bool | 회차 표시 여부 (기본: false) |
| notificationOptions | [EventNotificationTimeOption] | 알림 시간 목록 |
| nextRepeatingTimes | [RepeatingTimes] | 사전 계산된 반복 시간들 |
| repeatingTimeToExcludes | Set\<String\> | 제외된 반복 시간의 customKey 집합 |

**할일과의 차이**: time 필수, 완료 없음(삭제만), 반복 시간 사전 계산, 제외 목록으로 개별 회차 관리

**수정 범위 (3가지)**:
| 범위 | 동작 | 결과 |
|---|---|---|
| `.all` | 전체 시리즈 수정 | 원본 갱신, 캐시 무효화(시간 변경 시) |
| `.onlyThisTime` | 해당 시간 제외 + 새 이벤트 생성 | 원본 시리즈에 "구멍" + 새 단독 이벤트 |
| `.fromNow` | 원본 `.until` 종료 + 새 시리즈 시작 | 원본은 과거만, 새 시리즈가 미래 담당 |

### 3.3 EventTime (시간 표현)

| 형태 | 설명 | 경계값 |
|---|---|---|
| `.at(TimeInterval)` | 특정 시점 | lower=upper=t |
| `.period(Range<TimeInterval>)` | 시작~종료 기간 | lower=start, upper=end |
| `.allDay(Range<TimeInterval>, secondsFromGMT)` | 하루종일 + 타임존 오프셋 | lower=start, upper=end |

**겹침 판정 (2종)**:
- `isRoughlyOverlap`: 하루종일을 전 세계 타임존 커버로 확장 (캘린더 표시용)
- `isOverlap(in: TimeZone)`: 특정 타임존 기준 정밀 판정

**고유 키 (customKey)**: 반복 이벤트의 특정 회차 식별에 사용 → `repeatingTimeToExcludes`에 저장

### 3.4 DoneTodoEvent (완료 할일)

| 속성 | 타입 | 설명 |
|---|---|---|
| uuid | String | 완료 기록 고유 ID (원본과 다른 UUID) |
| originEventId | String | 원본 TodoEvent.uuid |
| name, eventTagId, eventTime, notificationOptions | — | 원본에서 복사 |
| doneTime | Date | 실제 완료 시각 |

**삭제 범위**: `.pastThan(TimeInterval)` (지정 시점 이전만) / `.all` (전체)
**페이지네이션**: 커서(시점) 기반, 무한 스크롤

### 3.5 이벤트 상세 데이터 (EventDetailData)

모든 이벤트 타입에 공통으로 첨부 가능한 부가 정보. 이벤트와 별도 저장.

| 속성 | 타입 | 설명 |
|---|---|---|
| eventId | String | 연결된 이벤트 ID |
| place | Place? | 장소명 + 좌표(위도/경도) + 주소 |
| url | String? | 링크 |
| memo | String? | 메모 |

---

## 4. 반복 이벤트

> **상세 스펙**: [spec/repeating-events.md](spec/repeating-events.md) — 옵션별 파라미터 제약, 다음 시간 계산 알고리즘, 겹침 판정, turn 생명주기

### 4.1 반복 옵션 (6가지)

| 옵션 | 파라미터 | 타임존 | 예시 |
|---|---|---|---|
| 매일 (EveryDay) | interval: 1~999일 | 불필요 | 3일마다 |
| 매주 (EveryWeek) | interval: 1~5주, 요일 선택 | 필수 | 격주 월·수·금 |
| 매월 (EveryMonth) | interval: 1~11개월, 일자 **또는** N번째 요일 | 필수 | 매월 15일 / 첫째 화요일 |
| 매년 (EveryYear) | interval: 1~99년, 월+요일 서수 | 필수 | 3월 마지막 금요일 |
| 매년 특정일 (EveryYearSomeDay) | interval: 1~99년, 고정 월/일 | 필수 | 매년 12월 25일 |
| 음력 매년 (LunarCalendarEveryYear) | 음력 월/일, interval 고정 1 | 필수 | 음력 1월 1일 (설날) |

**매월 모드 A (일자)**: 해당 월에 없는 일자는 마지막 날로 내림 (31→2월28일)
**매월 모드 B (요일 서수)**: `.seq(1)`~`.seq(4)` 또는 `.last` + 요일
**음력**: Chinese Calendar로 변환, interval 설정 불가 (매년 고정)

### 4.2 종료 조건

| 조건 | 종료 판정 | 상호 배타 |
|---|---|---|
| 없음 (nil) | 무한 반복 | — |
| `.until(TimeInterval)` | `nextTime.upperBound > endTime` | `.count`와 동시 사용 불가 |
| `.count(Int)` | `turn > endCount` (turn 1부터 시작) | `.until`과 동시 사용 불가 |

### 4.3 반복 수정 범위

| 범위 | 할일 | 일정 |
|---|---|---|
| `.all` | 원본 직접 수정 | 원본 직접 수정 |
| `.onlyThisTime` | 새 할일 + 원본 다음 turn 전진 | 새 이벤트 + 원본 excludes 추가 |
| `.fromNow` | — (지원 안 함) | 원본 until 종료 + 새 시리즈 |

핵심 차이: 할일은 "현재 turn 전진", 일정은 "제외 목록(excludes) 관리"

### 4.4 건너뛰기 (할일 전용)

| 옵션 | 동작 | 에러 |
|---|---|---|
| `.next` | 다음 1회 건너뛰기 (turn 증가) | 반복 아님 → `notARepeatingEvent` |
| `.until(EventTime)` | 지정 시간까지 건너뛰기 | 반복 종료 → `repeatingIsEnd` |

건너뛰기도 count에서 turn을 **소비**함 (실행 안 해도 1회 차감)

### 4.5 Turn 규칙

- turn은 **1부터 시작**, `TodoEvent.repeatingTurn: nil` = turn 1
- 완료/수정/삭제/건너뛰기마다 turn + 1
- count 종료 판정: `turn > endCount`
- 건너뛰기도 turn 소비 → count=5에서 2회 건너뛰면 실제 실행 3회

### 4.6 다음 반복 시간 계산 (EventRepeatTimeEnumerator)

1. 현재 시간에서 옵션별 다음 날짜 계산
2. **제외 시간 체크**: customKey가 excludes에 있으면 → 재귀적으로 그 다음 계산
3. turn 증가, 종료 조건 체크
4. 통과 → 다음 RepeatingTimes 반환, 미통과 → nil

---

## 5. 이벤트 태그

### 5.1 태그 식별자 (EventTagId)

| 타입 | 설명 | 직렬화 형식 |
|---|---|---|
| `.default` | 기본 태그 (시스템) | `"default"` |
| `.holiday` | 공휴일 태그 (시스템) | `"holiday"` |
| `.custom(String)` | 사용자 생성 태그 (UUID) | `"uuid값"` (plain string) |
| `.externalCalendar(serviceId, calendarId)` | 외부 캘린더 태그 (구글 등) | `"external::{serviceId}::{calendarId}"` |

**헬퍼 프로퍼티**:
- `customTagId: String?` — `.custom` 케이스일 때 UUID 추출
- `externalServiceId: String?` — `.externalCalendar` 케이스일 때 서비스 ID 추출

### 5.2 태그 모델

**프로토콜** (`EventTag`):
| 프로퍼티 | 타입 | 설명 |
|---|---|---|
| `tagId` | `EventTagId` | 식별자 |
| `name` | `String` | 표시 이름 |
| `colorHex` | `String?` | 색상 hex 값 |

**구현체**:

| 타입 | 용도 | 추가 프로퍼티 |
|---|---|---|
| `DefaultEventTag` | 시스템 기본/공휴일 | enum (`.default`/`.holiday`), 색상 내장 |
| `CustomEventTag` | 사용자 생성 | `uuid: String` |
| `ExternalCalendarEventTag` | 구글 캘린더 | `foregroundColorHex`, `colorId`, `ownerId` |

**이벤트와의 관계**: `TodoEvent`/`ScheduleEvent`의 `eventTagId: EventTagId?` 프로퍼티로 연결. 태그 없이 이벤트 생성 가능 (nil).

### 5.3 태그 CRUD

#### 생성

| 파라미터 | 타입 | 필수 | 설명 |
|---|---|---|---|
| `name` | `String` | O | 태그 이름 |
| `colorHex` | `String` | O | 색상 hex 값 |

**중복 이름 검사**:
- Repository 레이어에서 `loadTag(match: name)` 쿼리로 확인
- 동일 이름 존재 시 `RuntimeError("EvnetTag_Name_Duplicated")` throw
- 생성 후 SharedDataStore의 `tags` 맵에 즉시 반영

#### 수정

| 파라미터 | 타입 | 설명 |
|---|---|---|
| `name` | `String?` | 변경할 이름 (nil이면 유지) |
| `colorHex` | `String?` | 변경할 색상 (nil이면 유지) |

**중복 이름 검사**: 수정 대상 태그 자신은 검사에서 제외 (`filter { $0.uuid != tagId }`)

#### 삭제 — 두 가지 전략

| 전략 | 동작 | cascade 범위 |
|---|---|---|
| **태그만 삭제** (`deleteTag`) | 태그 레코드 삭제 | 이벤트의 `eventTagId`는 남아있으나 색상 해석 불가 → 기본 색상 표시 |
| **이벤트 포함 삭제** (`deleteTagWithAllEvents`) | 태그 + 관련 이벤트 일괄 삭제 | TodoEvent, ScheduleEvent 삭제 + 이벤트 상세 데이터(메모, 위치 등) 삭제 |

**이벤트 포함 삭제의 상세 플로우**:
1. Repository에서 해당 태그의 `todoIds`, `scheduleIds` 조회 → `RemoveCustomEventTagWithEventsResult` 반환
2. `TodoEventUsecase.handleRemovedTodos(todoIds)` 호출 → SharedDataStore에서 제거
3. `ScheduleEventUsecase.handleRemovedSchedules(scheduleIds)` 호출 → SharedDataStore에서 제거

**삭제 후 공통 정리**:
- SharedDataStore `tags` 맵에서 해당 태그 제거
- `offEventTagSet`에서 해당 태그 ID 제거 (숨김 목록 정리)
- 로컬 저장소의 off-tag ID 목록에서 삭제

**엣지 케이스**:

| 상황 | 동작 |
|---|---|
| 완료된 할일(DoneTodo)이 연결된 태그 삭제 | 이벤트 포함 삭제 시 해당 todo도 삭제 대상에 포함 |
| 삭제된 태그 ID를 가진 이벤트 조회 | 태그 정보 없음 → 기본(default) 색상으로 표시 |
| 외부 캘린더 태그 삭제 시도 | 직접 삭제 불가 — 계정 연동 해제로만 제거 |

### 5.4 태그 보이기/숨기기

숨김 태그 ID 집합(`offEventTagIdsOnCalendar`)을 UserDefaults(`EnvironmentStorage`)에 저장.

**저장 키**: `"off_eventtagIds_on_calendar"` — `[String]` (직렬화된 EventTagId 배열)

#### 조작 API

| 메서드 | 동작 | 용도 |
|---|---|---|
| `toggleEventTagIsOnCalendar(tagId)` | XOR 토글 (보임↔숨김) | 개별 태그 보기 전환 |
| `addEventTagOffIds(ids)` | 집합 합집합 (숨김 추가) | 일괄 숨기기 |
| `removeEventTagOffIds(ids)` | 집합 차집합 (숨김 해제) | 일괄 보이기 |
| `resetExternalCalendarOffTagId(serviceId)` | 해당 서비스의 외부 태그 전부 제거 | 외부 캘린더 계정 연동 해제 시 정리 |

#### 기본 보이기/숨기기 상태

| 태그 유형 | 생성/연동 시 기본 | 이유 |
|---|---|---|
| 커스텀 태그 | **보임** | 사용자가 직접 만든 태그 |
| 외부 캘린더 태그 | **숨김** | 구글 캘린더에서 `isSelected != true`인 캘린더는 기본 숨김. 사용자가 명시적 활성화 필요 |

#### 숨김 태그의 영향 범위

| 영역 | 영향 |
|---|---|
| 캘린더 월간 그리드 | 해당 태그의 이벤트 색상 바 미표시 |
| 일별 이벤트 목록 | 해당 태그의 이벤트 필터링 |
| 위젯 | 이벤트 렌더링에서 제외 |
| 이벤트 상세 | 태그 자체는 표시 (이벤트에 진입한 경우) |

**변경 전파**: SharedDataStore `offEventTagSet` 키를 통해 Combine으로 실시간 전파 → 구독 중인 모든 화면에 즉시 반영

### 5.5 색상 결정

#### 색상 소스 구조

`EventTagColorSource` 마커 프로토콜을 기반으로 런타임에 타입 디스패치:

```
EventTagColorSource (protocol)
├── EventTagId          → default/holiday/custom 태그 색상
└── GoogleCalendarEventColorSource → calendarId + colorId 기반 색상
```

#### 일반 태그 (EventTagId) 색상 우선순위

```
1. allEventTagColorMap[tagId]    — 커스텀 태그의 colorHex 또는 기본 태그 색상 설정값
2. tagColors.holiday / .default  — 시스템 기본 색상 (DefaultEventTagColorSetting)
3. 최종 fallback: .default 태그 색상
```

**기본 태그 색상** (`DefaultEventTagColorSetting`):
| 태그 | 기본 hex |
|---|---|
| `holiday` | `#D6236A` |
| `default` | `#088CDA` |

사용자가 설정에서 변경 가능 (`UISettingUsecase.changeDefaultEventTagColor`).

#### 구글 캘린더 색상 우선순위

구글 캘린더 이벤트는 **이벤트별 색상**과 **캘린더 색상** 두 단계로 결정:

```
1. 이벤트에 colorId 있음 → 계정 palette의 event colors[colorId].backgroundHex
2. 이벤트에 colorId 없음:
   a. 캘린더(태그)의 backgroundColorHex
   b. 캘린더(태그)의 colorId → 계정 palette의 calendar colors[colorId].backgroundHex
3. 최종 fallback: .clear
```

#### UI 렌더링 (`EventTagColorView`)

SwiftUI View가 `@Environment(ViewAppearance.self)`에서 색상을 해석:
- `source`가 `GoogleCalendarEventColorSource`이면 → `appearance.googleEventColor(colorId, calendarId)`
- `source`가 `EventTagId`이면 → `appearance.color(tagId)`
- 그 외 → `.clear`

### 5.6 태그 자동 갱신

EventTagUsecase는 `prepare()` 시점에 SharedDataStore의 `todos`/`schedules` 변경을 구독하여, 새로 추가된 이벤트에 아직 로드되지 않은 태그가 있으면 자동으로 해당 태그 정보를 조회하여 `tags` 맵에 추가한다.

---

## 6. 강조 이벤트 (Foremost Event)

사용자가 가장 중요한 이벤트 **1개**를 지정하는 기능. 캘린더 상단과 위젯에서 강조 표시.

### 6.1 데이터 모델

| 프로퍼티 | 타입 | 설명 |
|---|---|---|
| `eventId` | `String` | 이벤트 고유 ID |
| `isTodo` | `Bool` | true: 할일, false: 일정 |

`ForemostMarkableEvent` 프로토콜: `TodoEvent`와 `ScheduleEvent` 모두 채택. `ForemostEventId(event:)` 팩토리 이니셜라이저로 이벤트 타입을 자동 판별.

### 6.2 지원 이벤트 타입

| 이벤트 타입 | 지원 여부 | 비고 |
|---|---|---|
| TodoEvent (비반복) | O | |
| TodoEvent (반복) | O | |
| ScheduleEvent (비반복) | O | |
| ScheduleEvent (반복) | **X** | UI에서 명시적으로 안내 (ForemostEventGuideView) |

### 6.3 상태 전이

```
          update(eventId)              remove()
  idle ──────────────────► marking ─────────X (별도 흐름)
   │                         │
   │    remove()             │ 성공/실패
   ├──────────────► unmarking│
   │                  │      ▼
   │                  │    idle
   │    성공/실패      │
   │◄─────────────────┘
```

| 상태 | 의미 | UI 표시 |
|---|---|---|
| `idle` | 대기 | 일반 상태 |
| `marking(eventId)` | 지정 진행 중 | 로딩 표시 |
| `unmarking` | 해제 진행 중 | 로딩 표시 |

**안전성**: `defer` 블록으로 성공/실패 모두 반드시 `idle`로 복귀.

### 6.4 지정/해제 플로우

**지정 (update)**:
1. 상태 → `.marking(eventId:)`
2. `repository.updateForemostEvent(eventId)` 호출
3. SharedDataStore에 `foremostEventId` 저장
4. 반환된 이벤트 객체를 SharedDataStore의 `todos`/`schedules`에 업데이트
5. 상태 → `.idle`

**해제 (remove)**:
1. 상태 → `.unmarking`
2. `repository.removeForemostEvent()` 호출
3. SharedDataStore에서 `foremostEventId` 키 삭제
4. 상태 → `.idle`

**새로고침 (refresh)**:
- `repository.foremostEvent()` (Publisher) 구독
- 결과: `foremostEventId` + 전체 이벤트 객체 모두 SharedDataStore에 업데이트
- 이벤트 없음(nil) → SharedDataStore 키 삭제

### 6.5 엣지 케이스

| 상황 | 동작 |
|---|---|
| 강조 이벤트가 삭제됨 | ForemostLocalStorage가 이벤트 조회 시 `notExists` 에러 catch → nil 반환 → UI "모두 완료" 표시 |
| 강조 이벤트(할일) 완료 처리 | 자동 해제 없음 — 위젯 다음 새로고침 시 재조회하여 반영 |
| 위젯에서 과거 일정 | 위젯 provider가 `schedule.time.lowerBoundWithFixed < dayRange.lowerBound` 체크 → nil 반환 (비존재 처리) |
| 강조 이벤트 ID는 있으나 이벤트 타입 변경 | 불가능 — `isTodo` 플래그로 타입이 고정됨 |

### 6.6 저장소

| 저장소 | 키 | 용도 |
|---|---|---|
| SharedDataStore | `foremostEventId` | 앱 내 실시간 전파 (Combine) |
| EnvironmentStorage (UserDefaults) | `"foremoset_event_id"` | 로컬 영속화 |
| Remote API | `GET/PUT/DELETE /event` | 서버 동기화 |

**Remote 캐시 전략**: 캐시된 값 먼저 emit → 서버 응답으로 갱신 (2회 방출). 캐시 로드 실패는 무시, 서버 실패는 전파.

### 6.7 UI 노출 위치

| 위치 | 컴포넌트 | 기능 |
|---|---|---|
| 캘린더 메인 상단 | `ForemostEventView` (CalendarPaperView 내) | 이벤트 셀 표시, 할일 완료/취소, 상세 이동, 더보기 액션 |
| 위젯 | `ForemostEventWidget` | `.accessoryInline`, `.systemSmall`, `.systemMedium` 3가지 사이즈 |
| 이벤트 상세 | `ForemostEventGuideView` | 기능 설명 + 지원 타입 안내 (바텀 시트) |

**위젯 상태별 표시**:
| 상태 | 표시 내용 |
|---|---|
| 이벤트 없음 | 랜덤 이모지 + "모두 완료" 메시지 |
| 할일 이벤트 | 이름 + 시간 + 완료/취소 토글 버튼 |
| 일정 이벤트 | 이름 + 시간 (읽기 전용, 토글 없음) |

### 6.8 위젯 할일 토글 (`TodoToggleIntent`)

위젯에서 강조 할일의 완료 상태를 직접 전환하는 App Intent.

**파라미터**: `todoId: String`, `isForemost: Bool`

**동작**:
1. 할일 완료 처리 (DB 업데이트)
2. `isForemost == true`이면 `EnvironmentKeys.needCheckResetWidgetCache = true` 플래그 설정
3. 할일 토글 관련 위젯 6종 일괄 리로드

---

## 7. 알림

### 7.1 알림 시간 옵션 (`EventNotificationTimeOption`)

6가지 케이스로 구성된 enum:

**시간 지정 이벤트용**

| 케이스 | 파라미터 | 설명 |
|---|---|---|
| `.atTime` | — | 이벤트 시각에 정확히 알림 |
| `.before(seconds:)` | `TimeInterval` | 이벤트 시각 N초 전 |

`.before`의 사전 정의 옵션:

| 표시 | 초(seconds) |
|---|---|
| 1분 전 | 60 |
| 5분 전 | 300 |
| 10분 전 | 600 |
| 15분 전 | 900 |
| 30분 전 | 1,800 |
| 1시간 전 | 3,600 |
| 2시간 전 | 7,200 |
| 1일 전 | 86,400 |
| 2일 전 | 172,800 |
| 7일 전 | 604,800 |

**하루종일 이벤트용**

| 케이스 | 파라미터 | 설명 |
|---|---|---|
| `.allDay9AM` | — | 이벤트 당일 오전 9시 |
| `.allDay12AM` | — | 이벤트 당일 정오 12시 |
| `.allDay9AMBefore(seconds:)` | `TimeInterval` | N일 전 오전 9시 |

`.allDay9AMBefore`의 사전 정의 옵션:

| 표시 | 초(seconds) |
|---|---|
| 1일 전 9시 | 86,400 |
| 2일 전 9시 | 172,800 |
| 7일 전 9시 | 604,800 |

**커스텀**

| 케이스 | 파라미터 | 설명 |
|---|---|---|
| `.custom(DateComponents)` | `DateComponents` | 사용자가 자유 지정한 날짜/시간 |

### 7.2 알림 fire date 계산

이벤트의 `EventTime` + `EventNotificationTimeOption` 조합으로 실제 알림 시각을 결정.

#### 시간 지정 이벤트 (at / period)

| 옵션 | 계산 공식 | 예시 (이벤트 14:00) |
|---|---|---|
| `.atTime` | `startTime` | 14:00 |
| `.before(seconds: 900)` | `startTime - seconds` | 13:45 (15분 전) |
| `.custom(compos)` | `DateComponents` 직접 사용 | 사용자 지정 |

> `period` 이벤트는 `startTime` (시작 시각) 기준으로 계산.

#### 하루종일 이벤트 — 타임존 보정

하루종일 이벤트는 `EventTime.allDay`에 저장된 `secondsFromGMT` 오프셋을 사용하여 올바른 시간대에서 계산:

1. `TimeZone(secondsFromGMT: Int(secondsFromGMT))` 생성
2. 이벤트 시작일을 해당 타임존 기준 `DateComponents`(year, month, day)로 분해
3. 옵션별 시/분 설정:

| 옵션 | 계산 | 예시 (3월 15일 하루종일, KST) |
|---|---|---|
| `.allDay9AM` | 당일 09:00 (이벤트 타임존) | 3/15 09:00 KST |
| `.allDay12AM` | 당일 12:00 (이벤트 타임존) | 3/15 12:00 KST |
| `.allDay9AMBefore(86400)` | (시작일 - 1일) 09:00 | 3/14 09:00 KST |
| `.allDay9AMBefore(172800)` | (시작일 - 2일) 09:00 | 3/13 09:00 KST |

> 결과는 `DateComponents`로 반환 → iOS가 디바이스 타임존에서 `UNCalendarNotificationTrigger`로 변환.

### 7.3 반복 이벤트의 알림 생성

**범위**: 현재 시점부터 **365일** 이내의 반복 인스턴스만 대상.

**생성 과정**:
1. `ScheduleEvent.repeatingTimes` 배열에서 각 반복 인스턴스(`RepeatingTimes`)의 `time` 추출
2. 각 인스턴스별로 설정된 모든 `notificationOptions`에 대해 fire date 계산
3. 인스턴스 × 옵션 수만큼 개별 `UNNotificationRequest` 생성

**예시**: 매주 반복 일정(52회/년) + 알림 2개(정시, 15분 전) → 최대 104개 알림 생성

### 7.4 알림 동기화 아키텍처

앱 시작 시 `MainViewModel.prepare()`에서 `EventNotificationUsecase.runSyncEventNotification()` 호출.

**동기화 플로우**:

```
runSyncEventNotification()
  ├─ todoEvents(in: now..+365일) 구독
  │    └─ .scan()으로 EventChanges 추적 (added/updated/removed)
  └─ scheduleEvents(in: now..+365일) 구독
       └─ .scan()으로 EventChanges 추적

EventChanges 감지 시:
  1. 변경/삭제된 이벤트의 기존 알림 ID 조회 (EventNotificationIdTable)
  2. UNUserNotificationCenter에서 해당 알림 제거
  3. 변경/추가된 이벤트의 새 알림 생성 (미래 시점만)
  4. 새 알림 ID를 EventNotificationIdTable에 저장
```

**알림 갱신 트리거 전체 목록**:

| 트리거 | 감지 방식 |
|---|---|
| 이벤트 생성 | EventChanges scan — added |
| 이벤트 시간 변경 | EventChanges scan — updated |
| 이벤트 삭제 | EventChanges scan — removed |
| 알림 옵션 변경 | EventChanges scan — updated (notificationOptions 포함) |
| 반복 옵션 변경 | repeatingTimes 배열이 달라짐 → updated |
| 할일 완료 | todos에서 제거됨 → removed |
| 앱 시작 / 포그라운드 복귀 | MainViewModel.prepare()에서 전체 재동기화 |

### 7.5 알림 ID 관리

**DB 테이블** (`EventNotificationIds`):

| 컬럼 | 타입 | 설명 |
|---|---|---|
| `event_id` | `TEXT` | 이벤트 ID (FK) |
| `not_req_id` | `TEXT` | `UNNotificationRequest` 식별자 |

**1:N 관계**: 하나의 이벤트 → 복수 알림 (옵션 수 × 반복 인스턴스 수)

**정리 플로우**:
1. `removeAllSavedNotificationId(of: eventIds)` → DB에서 해당 이벤트의 `not_req_id` 목록 조회
2. 조회된 ID 목록으로 `UNUserNotificationCenter.removePendingNotificationRequests(withIdentifiers:)` 호출
3. DB 레코드 삭제

**이벤트 삭제 시**: EventChanges가 removed로 감지 → 위 정리 플로우 자동 실행

### 7.6 기본 알림 설정

사용자가 이벤트 종류별로 기본 알림 시간을 지정할 수 있음. 새 이벤트 생성 시 자동 적용.

| 설정 | 저장 키 (UserDefaults) | 적용 대상 |
|---|---|---|
| 시간 이벤트 기본 알림 | `"default_event_notification_time"` | `.at`/`.period` 이벤트 |
| 하루종일 이벤트 기본 알림 | `"default_allday_event_notification_time"` | `.allDay` 이벤트 |

**저장 형식**: `EventNotificationTimeOption`을 JSON 직렬화하여 저장 (`EventNotificationTimeOptionMapper`)

### 7.7 iOS 64개 알림 제한

현재 구현은 iOS의 64개 pending notification 제한에 대한 **명시적 우선순위 처리를 하지 않음**. 365일 범위 내 모든 이벤트에 대해 알림을 등록하며, 64개 초과 시 iOS가 자동으로 오래된 알림부터 무시.

> **잠재적 이슈**: 반복 이벤트가 많고 알림 옵션을 복수 설정한 경우 64개를 초과할 수 있음.

### 7.8 FCM 푸시 알림

로그인 상태에서 서버 푸시 알림을 위한 FCM 토큰 관리.

**등록 플로우**:
1. `UserNotificationUsecase.register(fcmToken:)` 호출
2. `DeviceInfoFetchService`로 디바이스 정보 수집 (모델명 등)
3. 이전 저장 토큰과 비교 → **동일하면 스킵** (중복 요청 방지)
4. `PUT /notification` 엔드포인트로 `{ fcm_token, device_model }` 전송
5. 성공 시 로컬 SQLite(`KeyValueTable`)에 토큰 저장

**해제**: `DELETE /notification` → 로컬 토큰 삭제

### 7.9 알림 권한

`UNUserNotificationCenter` 기반 권한 관리.

| 상태 | 의미 | 대응 |
|---|---|---|
| `.notDetermined` | 미결정 (최초) | 권한 요청 다이얼로그 표시 |
| `.denied` | 거부됨 | 시스템 설정으로 이동 안내 |
| `.authorized` | 허용됨 | 알림 정상 동작 |

**권한 요청 옵션**: `.alert`, `.badge`, `.sound`

설정 화면에서 시스템 알림 설정으로 바로 이동 가능.

---

## 8. 구글 캘린더 연동

### 8.1 개요

- **읽기 전용** 연동 (조회만 가능, 편집 불가)
- **다중 계정** 동시 지원
- Google OAuth2로 인증 (GoogleSignIn SDK + Firebase 통합)
- 연동 후 캘린더 목록/이벤트/색상 자동 동기화

### 8.2 데이터 모델

#### GoogleCalendar.Colors (계정별 색상 팔레트)

| 프로퍼티 | 타입 | 설명 |
|---|---|---|
| `ownerId` | `String` | 계정 이메일 |
| `calendars` | `[String: ColorSet]` | 캘린더 colorId → 전경/배경 hex |
| `events` | `[String: ColorSet]` | 이벤트 colorId → 전경/배경 hex |

#### GoogleCalendar.Tag (캘린더 = 태그)

| 프로퍼티 | 타입 | 설명 |
|---|---|---|
| `id` | `String` | 캘린더 ID (예: `primary`, `user@gmail.com`) |
| `name` | `String` | 표시 이름 |
| `ownerId` | `String?` | 계정 이메일 (조회 후 설정) |
| `backgroundColorHex` | `String?` | 캘린더 배경 색상 |
| `foregroundColorHex` | `String?` | 캘린더 전경 색상 |
| `colorId` | `String?` | Colors 팔레트 참조 키 |
| `isSelected` | `Bool?` | Google 측 기본 보이기 여부 |

#### GoogleCalendar.Event (앱용 간소화 이벤트)

| 프로퍼티 | 타입 | 설명 |
|---|---|---|
| `eventId` | `String` | 이벤트 ID |
| `calendarId` | `String` | 소속 캘린더 ID |
| `accountId` | `String` | 계정 이메일 |
| `name` | `String` | 이벤트명 |
| `eventTagId` | `EventTagId` | `.externalCalendar(serviceId, calendarId)` |
| `colorId` | `String?` | 이벤트별 색상 ID (Colors.events 참조) |
| `eventTime` | `EventTime` | `.at`/`.period`/`.allDay` |
| `nextRepeatingTimes` | `[RepeatingTimes]` | 시리즈 인스턴스 목록 |
| `repeatingTimeToExcludes` | `Set<String>` | 제외된 반복 일시 |
| `htmlLink` | `String?` | 구글 캘린더 웹 링크 |
| `status` | `EventStatus` | `.confirmed`/`.tentative`/`.cancelled` |
| `location` | `String?` | 위치 |

#### GoogleCalendar.EventOrigin (API 원본 전체)

| 카테고리 | 필드 |
|---|---|
| 핵심 | `id`, `summary`, `htmlLink`, `description`, `location`, `colorId` |
| 시간 | `start`/`end` (`GoogleEventTime`: date 또는 dateTime + timeZone), `endTimeUnspecified` |
| 사람 | `creator`, `organizer`, `attendees[]` (responseStatus, organizer/optional/resource 플래그) |
| 반복 | `recurrence[]` (RRULE 문자열 배열), `recurringEventId`, `sequence` |
| 첨부 | `attachments[]` (fileUrl, title, mimeType, iconLink, fileId) |
| 회의 | `conferenceData` (conferenceId, solution, entryPoints[]), `hangoutLink` |
| 메타 | `eventType`, `status` (.confirmed/.tentative/.cancelled), `visibility` (.default/.public/.private/.confidential) |

### 8.3 OAuth 인증

| 항목 | 내용 |
|---|---|
| SDK | GoogleSignIn (Firebase 통합) |
| 스코프 | `calendar.readonly` (`https://www.googleapis.com/auth/calendar.readonly`) |
| 반환 | `GoogleOAuth2Credential` (idToken, accessToken, refreshToken, 만료 시각, email) |
| 저장 | Keychain (`IntegratedAPICredentialStore`) — `(serviceId, accountId)` 쌍 기준 |

**토큰 갱신 전략** (`GoogleAPIAuthenticator`):
1. API 요청 시 401 응답 감지
2. refresh token으로 `POST /oauth2/v4/token` 호출 (client_id + refresh_token + grant_type)
3. 성공 → 새 access_token + expires_in 수신 → credential 업데이트
4. 실패 → credential 삭제 → 사용자 재인증 필요

### 8.4 다중 계정 아키텍처

계정별 리소스를 3계층 Pool로 독립 관리:

```
GoogleCalendarRepositoryPool (계정별 Repository 캐싱 + lazy 생성)
  ↓
GoogleCalendarRepositoryImple (단일 계정 — colors/tags/events 접근)
  ├→ ExternalCalendarAccountRemotePool (계정별 RemoteAPI + 토큰 갱신)
  └→ GoogleCalendarLocalStorageImple
       ↓
       ExternalCalendarDBConnectionPool (참조 카운팅 DB 연결)
```

#### ExternalCalendarDBConnectionPool

Actor 기반 참조 카운팅으로 SQLite 연결 관리:

| 메서드 | 동작 |
|---|---|
| `open(serviceId)` | 참조 카운트 +1. 최초 오픈 시 `onFirstOpen` 콜백 (테이블 생성 + 마이그레이션) |
| `close(serviceId)` | 참조 카운트 -1. 카운트 0이면 연결 종료 + 풀에서 제거 |

서비스 ID → DB 파일 경로 매핑 (예: `google_calendar.db`). 동일 DB에 대한 중복 연결 방지.

#### ExternalCalendarAccountRemotePool

`NSLock` 기반 스레드 안전 풀. `serviceId-accountId` 키로 `RemoteAPI` 인스턴스 관리.

| 메서드 | 동작 |
|---|---|
| `setup(service, account, credential)` | RemoteAPI 생성/갱신 + 토큰 갱신 리스너 연결 |
| `remove(service, account)` | credential 삭제 + 풀에서 제거 |

### 8.5 연동 플로우

```
사용자: "구글 캘린더 연결"
  ↓
GoogleOAuth2ServiceUsecase.requestAuthentication()
  ↓ (GoogleSignIn SDK → 사용자 인증 → credential 반환)
  ↓
ExternalCalendarIntegrationUsecase.integrate()
  ├→ credentialStore.saveCredential() [Keychain]
  ├→ remotePool.setup() [RemoteAPI 생성]
  ├→ keyChainStore.update(account) [계정 목록 갱신]
  ├→ dbConnectionPool.open() [DB 연결 (최초: 테이블 생성 + 마이그레이션)]
  ├→ SharedDataStore.update(externalCalendarAccounts)
  └→ integrationStatus → .integrated(...)
       ↓
  GoogleCalendarUsecase.prepare()
    ├→ loadColors() → SharedDataStore + ViewAppearanceStore
    ├→ loadCalendarTags() → SharedDataStore + ViewAppearanceStore
    └→ (비선택 캘린더 → offEventTagIds에 자동 추가)
```

### 8.6 연동 해제 플로우

```
사용자: "구글 캘린더 연결 해제"
  ↓
ExternalCalendarIntegrationUsecase.stopIntegrate()
  ├→ credentialStore.removeCredential() [Keychain]
  ├→ remotePool.remove() [API 클라이언트 제거]
  ├→ keyChainStore.remove(account) [계정 목록 갱신]
  ├→ dbConnectionPool.close() [참조 카운트 -1, 0이면 연결 종료]
  ├→ SharedDataStore.update(externalCalendarAccounts)
  └→ integrationStatus → .disconnected(...)
       ↓
  GoogleCalendarUsecase.clearAccountCache()
    ├→ ViewAppearanceStore.clearColors(accountId)
    ├→ ViewAppearanceStore.clearCalendarTags(accountId)
    ├→ SharedDataStore에서 googleCalendarTags[accountId] 제거
    ├→ SharedDataStore에서 해당 계정의 googleCalendarEvents 제거
    ├→ EventTagUsecase.resetExternalCalendarOffTagId(serviceId) [태그 숨김 정리]
    └→ repositoryPool.removeRepository(accountId) [캐시 정리]
```

### 8.7 데이터 로딩 순서

계정별로 순차 실행:

| 단계 | API 엔드포인트 | 캐시 테이블 | 전략 |
|---|---|---|---|
| 1. 색상 | `GET /calendar/v3/colors` | `google_calendar_colors` | 캐시 우선 → 원격 갱신 |
| 2. 캘린더 목록 | `GET /calendar/v3/users/me/calendarList` | `google_calendar_event_tag` | 캐시 우선 → 원격 갱신 |
| 3. 이벤트 | `GET /calendar/v3/calendars/{id}/events` | `google_calendar_event_origin` + `event_time` | 캐시 우선 → 원격으로 대체 |

**캐시 전략**: 캐시된 값 먼저 emit → 원격 조회 → 캐시 갱신 → 새 값 emit (2회 방출 패턴)

**캐시 무효화 트리거**:
| 트리거 | 시점 |
|---|---|
| 앱 시작 | `prepareIntegratedAccounts()` |
| 계정 연동 상태 변경 | `.integrated()` / `.disconnected()` |
| 캘린더 탭 전환 | `refreshEvents(in:)` |
| 수동 새로고침 | UI 새로고침 버튼 |

**이벤트 쿼리 파라미터**: `timeMin`/`timeMax` (ISO8601), `pageToken` (페이지네이션)

### 8.8 RRULE 파싱

Google Calendar 반복 규칙(RFC 5545)을 앱의 반복 모델로 변환.

**파서**: `RRuleParser` — RRULE 문자열 파싱

```
입력: "RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;UNTIL=20251231T235959Z"
```

| RRULE 필드 | 파싱 결과 | 앱 모델 매핑 |
|---|---|---|
| `FREQ` | `.DAILY`/`.WEEKLY`/`.MONTHLY`/`.YEARLY` | `EventRepeatingOption` |
| `INTERVAL` | 반복 간격 (기본 1) | 반복 옵션의 interval |
| `BYDAY` | 요일 목록 (MO, TU, +1MO 등) | EveryWeek 요일 지정, EveryMonth 서수 요일 |
| `UNTIL` | 종료 날짜 | `.until(TimeInterval)` |
| `COUNT` | 반복 횟수 | `.count(Int)` |

### 8.9 캘린더 보이기/숨기기

| 조건 | 기본 상태 | 변경 방법 |
|---|---|---|
| `isSelected == true` | 보임 | 태그 토글로 숨기기 가능 |
| `isSelected != true` (false/nil) | **숨김** (offEventTagIds에 자동 추가) | 사용자가 명시적으로 활성화 |

**활성 캘린더 필터링**: `activeCalendars()` = 전체 캘린더 태그 중 offIds에 포함되지 않은 것만 반환. 이벤트 로딩은 활성 캘린더에 대해서만 수행.

### 8.10 데이터 집계 (다중 계정)

`GoogleCalendarLocalAggregatedRepositoryImple`: 위젯/인텐트 확장 등 읽기 전용 컨텍스트에서 모든 연동 계정의 데이터를 투명하게 합산.

| 쿼리 | 집계 방식 |
|---|---|
| 색상 | 모든 계정 병합 (후순위가 덮어씀) |
| 캘린더 태그 | 모든 계정 concatenate |
| 이벤트 | 모든 계정 concatenate (캘린더 ID 필터 가능) |
| 이벤트 상세 | 계정 순회하며 첫 번째 매칭 반환 |

### 8.11 이벤트 상세 (읽기 전용)

`GoogleCalendarEventDetailView`에서 EventOrigin의 전체 필드를 표시:

| 표시 항목 | 소스 필드 |
|---|---|
| 이벤트명 | `summary` |
| 시간 | `start`/`end` |
| D-Day | 시간으로부터 계산 |
| 반복 옵션 | `recurrence` (RRULE 파싱 → 읽기 가능 텍스트) |
| 위치 | `location` |
| 캘린더 | `calendarId` → 태그 이름으로 매핑 |
| 회의 | `conferenceData` (솔루션명, 진입점 목록) |
| 참석자 | `attendees[]` (이름, 응답 상태) |
| 설명 | `description` (HTML 렌더링) |
| 첨부파일 | `attachments[]` (제목, URL) |

**사용자 액션**:
| 액션 | 동작 |
|---|---|
| "구글 캘린더에서 편집" | `htmlLink` → Safari 오픈 |
| 위치 복사 | UIPasteboard |
| 회의 코드 복사 | entryPoints의 accessCode/meetingCode 등 |
| 링크 선택 | description 내 URL 오픈 |
| 첨부파일 선택 | fileUrl 오픈 |
| 새로고침 | API에서 이벤트 상세 재조회 |

### 8.12 에러 처리

| 에러 상황 | 대응 |
|---|---|
| 토큰 만료 (401) | 자동 refresh → 실패 시 credential 삭제 → 재인증 필요 |
| API 제한 | 명시적 처리 없음 — 에러가 UI까지 전파 |
| 네트워크 오류 | 캐시 데이터 반환 가능 시 캐시 사용, 불가 시 에러 전파 |
| 데이터 파싱 실패 | `compactMap`으로 유효하지 않은 이벤트 건너뜀 (무시) |
| RRULE 파싱 실패 | nil 반환 → 반복 옵션 없이 표시 |

### 8.13 DB 구조 (google_calendar.db)

메인 DB와 분리된 별도 SQLite 파일. `ExternalCalendarDBConnectionPool`이 관리.

| 테이블 | 용도 | 주요 컬럼 |
|---|---|---|
| `google_calendar_colors` | 계정별 색상 팔레트 | `account_id`, `color_type`, `color_key`, `background`, `foreground` |
| `google_calendar_event_tag` | 계정별 캘린더 목록 | `account_id`, `id`, `name`, `backgroundColorHex`, `colorId`, `isSelected` |
| `google_calendar_event_origin` | 이벤트 원본 데이터 | `account_id`, `calendarId`, `id`, `summary`, `status`, `visibility`, ... |
| `event_time` | 시간 범위 (overlap 조회용) | `event_id`, `start_timestamp`, `end_timestamp` |

**마이그레이션**: `AppEnvironment.googleCalendarDBVersion`으로 버전 관리. `AppDataMigrationImple`에서 단일계정→다중계정 마이그레이션 포함.

---

## 9. 위젯 (18종)

### 9.1 위젯 목록 및 지원 사이즈

3개 번들로 구성된 총 18종 위젯:

#### 기본 위젯 (BaseWidgetBundle — 7종)

| 위젯 | 설명 | 지원 사이즈 |
|---|---|---|
| TodayWidget | 오늘 날짜 + 이벤트 카운트 | systemSmall |
| MonthWidget | 월 캘린더 그리드 | systemSmall |
| TodayAndNextWidget | 오늘 요약 + 다음 이벤트 | systemMedium |
| EventListWidget | 이벤트 스크롤 목록 (태그 필터) | systemSmall, systemMedium, systemLarge |
| ForemostEventWidget | 강조 이벤트 표시 | accessoryInline, systemSmall, systemMedium |
| NextEventWidget | 다음 예정 이벤트 | accessoryInline, accessoryRectangular |
| NextRemainEventWidget | 다음 이벤트 (남은 시간 강조) | accessoryRectangular |

#### 주/월 이벤트 위젯 (WeeksWidgetBundle — 7종)

| 위젯 | 기간 | 지원 사이즈 |
|---|---|---|
| OneWeekEventsWidget | 7일 | systemMedium |
| TwoWeekEventsWidget | 14일 | systemMedium |
| ThreeWeekEventsWidget | 21일 | systemLarge |
| FourWeekEventsWidget | 28일 | systemLarge |
| CurrentMonthEventsWidget | 이번 달 | systemLarge |
| LastMonthEventsWidget | 지난 달 | systemLarge |
| NextMonthEventsWidget | 다음 달 | systemLarge |

#### 조합 위젯 (ComposedWidgetBundle — 4종)

| 위젯 | 구성 | 지원 사이즈 |
|---|---|---|
| TodayAndMonthWidget | 오늘 요약 + 월 캘린더 | systemMedium |
| EventAndMonthWidget | 이벤트 목록 + 월 캘린더 | systemMedium |
| EventAndForemostWidget | 이벤트 목록 + 강조 이벤트 | systemMedium |
| DoubleMonthWidget | 연속 2개월 캘린더 | systemMedium |

### 9.2 데이터 소스 및 조회 범위

모든 위젯은 `CalendarEventFetchUsecase`를 통해 데이터를 조회. 앱의 Usecase와 달리 **async/await 기반**, **SharedDataStore 미사용**, **SQLite 직접 조회**.

#### 데이터 소스

| 소스 | 데이터 | Repository |
|---|---|---|
| TodoCalendarEvent | 현재 할일 + 기간 내 할일 | `TodoEventRepository` |
| ScheduleCalendarEvent | 단일/반복 일정 | `ScheduleEventRepository` |
| HolidayCalendarEvent | 공휴일 | `HolidaysFetchUsecase` |
| GoogleCalendarEvent | 구글 캘린더 이벤트 (연동 시) | `GoogleCalendarRepository` |

#### 위젯별 조회 범위

| 위젯 유형 | 조회 범위 |
|---|---|
| Today / TodayAndNext | 오늘 (자정~자정, 사용자 타임존) |
| NextEvent / NextRemainEvent | 오늘 범위 내 미래 이벤트 |
| ForemostEvent | 강조 이벤트 1개 (ID로 직접 조회) |
| EventList | 오늘부터 (사이즈별 표시 건수 차이) |
| Month / DoubleMonth | 해당 월 전체 |
| 주간 위젯 (1~4주) | 오늘부터 7/14/21/28일 |
| 월간 위젯 (이번/지난/다음 달) | 해당 월 전체 |

### 9.3 Timeline 갱신 정책

```swift
policy: .after(Date().nextUpdateTime)
```

**nextUpdateTime 계산**:
- 하루 종료까지 1시간 이상 → **다음 정시** (시간 경계)
- 하루 종료까지 1시간 미만 → **다음 날 시작** (자정)

**추가 갱신 트리거**:
| 트리거 | 방식 |
|---|---|
| 할일 토글 (위젯) | `WidgetCenter.shared.reloadTimelines(ofKind:)` — 토글 가능 위젯 7종 일괄 리로드 |
| 앱에서 이벤트 변경 | 백그라운드 동기화 완료 후 위젯 갱신 |
| 강조 이벤트 토글 | `needCheckResetWidgetCache` 플래그 설정 → 다음 리로드 시 전체 캐시 리셋 |

### 9.4 Intent Configuration

#### TodoToggleIntent (할일 완료 토글)

위젯에서 직접 할일 완료 상태를 전환하는 App Intent. **7개 위젯**에서 지원:
- EventListWidget, ForemostEventWidget, NextEventWidget, NextRemainEventWidget
- EventAndMonthWidget, EventAndForemostWidget, TodayAndNextWidget

| 파라미터 | 타입 | 설명 |
|---|---|---|
| `todoId` | `String` | 할일 ID |
| `isForemost` | `Bool` | 강조 이벤트 여부 (전체 캐시 리셋 결정) |

**토글 후 동작**:
1. DB에서 할일 완료 처리
2. `isForemost == true` → `needCheckResetWidgetCache = true` (전체 리셋)
3. `isForemost == false` → `needCheckResetCurrentTodo = true` (할일만 리셋)
4. 토글 가능 위젯 7종 `reloadTimelines` 호출

#### EventTypeSelectIntent (이벤트 필터)

EventListWidget에서 표시할 태그를 선택하는 Configuration Intent.

| 파라미터 | 타입 | 설명 |
|---|---|---|
| `eventTypes` | `[EventTypeEntity]?` | 선택된 태그 목록 (nil = 전체) |

**EventTypeEntity 필드**: `id`, `name`, `externalServiceId?`, `externalServiceName?`, `isDefaultTag`

**태그 소스**: 기본 태그 + 커스텀 태그 (`EventTagRepository`) + 구글 캘린더 태그 (`GoogleCalendarRepository`)

#### EventListComponentSelectIntent (TodayAndNextWidget 전용)

EventTypeSelectIntent 확장:

| 추가 파라미터 | 타입 | 설명 |
|---|---|---|
| `excludeAllDayEvent` | `Bool` | 하루종일 이벤트 제외 여부 |

### 9.5 앱 ↔ 위젯 데이터 공유

#### App Group 메커니즘

App Group ID (`group.com.sudo.park.todocalendar`)를 통한 공유 저장소:

| 저장소 | 용도 | 접근 방식 |
|---|---|---|
| SQLite DB | 이벤트, 태그, 이벤트 상세 데이터 | 위젯: **읽기 전용** / 앱: 읽기+쓰기 |
| UserDefaults (suite) | 설정, 캐시 리셋 플래그, 타임존 | 양방향 접근 |
| Keychain (shared group) | 인증 정보, 계정 목록 | 양방향 접근 |

#### 위젯에서 접근하는 DB 테이블

`todos_table`, `schedules_table`, `event_tags_table`, `foremost_events_table`, `event_details_table`

#### UserDefaults 공유 키 (EnvironmentKeys)

| 키 | 타입 | 용도 |
|---|---|---|
| `needCheckResetWidgetCache` | `Bool` | 전체 위젯 캐시 리셋 플래그 |
| `needCheckResetCurrentTodo` | `Bool` | 할일 캐시만 리셋 플래그 |
| `userSelectedTImeZone` | `String` | 사용자 타임존 설정 |
| `userFirstWeekDay` | `Int` | 첫째 요일 설정 |
| 캘린더 외형 설정 | 다수 | 폰트, 색상, 표시 옵션 |
| 태그 on/off 상태 | `[String]` | 숨김 태그 ID 목록 |

### 9.6 위젯 캐시

#### 캐시 구조

`FetchCacheStores` 싱글톤 — Actor 기반 스레드 안전 캐시:

| 캐시 항목 | 설명 |
|---|---|
| `currentTodos` | 현재 할일 목록 |
| `allCustomTagsMap` | 커스텀 태그 맵 |
| `externalAccountMap` | 외부 계정 정보 |
| `googleCalendarColors` | 구글 캘린더 색상 팔레트 |
| `googleCalendarTags` | 구글 캘린더 태그 맵 |
| `eventDetails` | 이벤트 상세 (위치 등) |

#### 캐시 리셋 플로우

`WidgetViewModelProviderBuilder.checkShouldReset()`:

| 플래그 조합 | 동작 |
|---|---|
| `needCheckResetWidgetCache == true` | 전체 캐시 리셋 (`FetchCacheStores.reset()`) |
| `needCheckResetCurrentTodo == true` | 할일 캐시만 리셋 (`resetCurrentTodo()`) |
| 둘 다 false | 캐시 유지 |

캐시 hit 시 즉시 반환, miss 시 Repository 조회 → 캐시 저장 → 반환. 명시적 TTL 없음 — Timeline 갱신 시점에 전체 재조회.

### 9.7 딥링크 URL

위젯 탭 시 앱으로 이동하는 딥링크. `EventDeepLinkBuilder` enum으로 구성.

**기본 형식**: `todocal://calendar/event/{type}?{params}`

| 이벤트 타입 | URL 경로 | 쿼리 파라미터 |
|---|---|---|
| 할일 | `/event/todo` | `event_id` |
| 일정 | `/event/schedule` | `event_id`, `start_time`, `end_time`, `is_allday`, `repeat_rule` |
| 공휴일 | `/event/holiday` | `event_id` |
| 구글 캘린더 | `/event/google` | `event_id`, `calendar_id`, `account_id` |

**캘린더 날짜 선택**: `todocal://calendar?select=YYYY_MM_DD` (월 캘린더 위젯의 날짜 탭)

### 9.8 위젯 외형 설정

#### WidgetAppearanceSettings

| 프로퍼티 | 타입 | 설명 |
|---|---|---|
| `background` | `.system` / `.custom(hex:)` | 위젯 배경 |

**배경 렌더링**:
- `.system` → 시스템 기본 배경
- `.custom(hex)` → hex 색상 + 밝기 기반 자동 그라데이션 (밝은색/어두운색 판별 → 그림자 방향 결정)

#### 에러 처리

`ResultTimelineEntry<T>`: `Result<T, WidgetErrorModel>`을 감싸는 Timeline Entry.
- 성공 → 정상 위젯 렌더링
- 실패 → `FailView` (사용자 친화적 에러 메시지). 다음 Timeline 갱신 시 재시도.

### 9.4 위젯 인터랙션

- **할일 완료 토글**: `TodoToggleIntent`로 위젯에서 직접 완료/미완료 전환
- **이벤트 타입 필터**: `EventTypeSelectIntent`로 위젯 표시 내용 필터링
- **딥링크**: 위젯 탭 → `tc.app://` 스킴으로 앱 내 해당 날짜/이벤트로 이동
- **자동 갱신**: 앱 백그라운드 진입 시 `WidgetCenter.reloadAllTimelines()`

### 9.5 위젯 외형 설정

- 배경: 시스템 기본 (`.system`) 또는 커스텀 색상 (`.custom(hex)`)
- App Group을 통한 앱-위젯 데이터 공유

---

## 10. 계정 & 인증

### 10.1 인증 방식

| 방식 | 설명 |
|---|---|
| 오프라인 (비로그인) | 로컬 DB만 사용. 모든 핵심 기능 사용 가능 |
| 구글 로그인 | OAuth2 → Firebase Auth → 서버 동기화 활성화 |

### 10.2 계정 상태 전환

```
[비로그인] ──로그인──→ [로그인]
    ↑                     │
    └──로그아웃/삭제──────┘
```

**로그인 시**:
1. OAuth2 자격증명 획득
2. Firebase Auth 인증
3. FCM 토큰 등록
4. SharedDataStore에 계정 정보 저장
5. UseCase Factory 전환 (NonLogin → Login)
6. 서버 동기화 시작

**로그아웃 시**:
1. FCM 토큰 해제
2. Auth 삭제
3. SharedDataStore 초기화
4. UseCase Factory 전환 (Login → NonLogin)

**계정 삭제 시**: 로그아웃과 동일 + 서버 데이터 삭제

### 10.3 데이터 마이그레이션

로그인 전 로컬에 쌓인 데이터를 클라우드로 업로드.

- 마이그레이션 대상: 이벤트 태그, 할일, 일정, 이벤트 상세, 완료 할일
- 마이그레이션 필요 건수 표시
- 순차 처리: 태그 → 할일 → 일정 → 상세 → 완료 할일
- 완료 후 로컬 임시 데이터 정리

---

## 11. 동기화

### 11.1 오프라인 우선 아키텍처

```
[사용자 액션] → LocalRepository (즉시 저장)
                    ↓
              UploadDecorateRepository (오프라인 큐에 추가)
                    ↓
              EventUploadService (백그라운드 업로드)
                    ↓
              RemoteRepository (서버 전송)
```

- 비로그인: `LocalRepository`만 사용
- 로그인: `UploadDecorateRepository`가 로컬 저장 + 오프라인 큐 관리

### 11.2 서버 동기화

| 항목 | 내용 |
|---|---|
| 동기화 대상 | EventTag, TodoEvent, ScheduleEvent |
| 페이지 크기 | 30건/요청 |
| 방식 | 타임스탬프 기반 증분 동기화 |
| 페이지네이션 | 커서 기반 |

**동기화 체크 응답**
| 응답 | 동작 |
|---|---|
| `.noNeedToSync` | 건너뛰기 |
| `.needToSync` | 타임스탬프부터 증분 동기화 |
| `.migrationNeeds` | 처음부터 전체 동기화 |

### 11.3 오프라인 큐

- 변경사항(생성/수정/삭제)을 SQLite 큐에 저장
- 백그라운드에서 자동 업로드 시도
- 최대 **10회** 재시도 (`AppEnvironment.eventUploadMaxFailCount`)
- 실패 시 다음 동기화 사이클에서 재시도

### 11.4 백그라운드 동기화

- `BGAppRefreshTask` (식별자: `com.sudo.park.TodoCalendarApp.bgSync`)
- 매시간 스케줄링
- 동기화 완료 후 위젯 자동 갱신
- 타임아웃 시 다음 사이클로 재스케줄링

### 11.5 강제 동기화

- 타임스탬프 초기화 → 전체 재동기화
- 설정 화면에서 수동 트리거 가능

---

## 12. 설정

### 12.1 캘린더 외형 설정

| 설정 | 옵션 | 기본값 |
|---|---|---|
| 첫째 요일 | 일~토 | 일요일 |
| 이벤트 있는 날 밑줄 | on/off | — |
| 행 높이 | 소/중/대 | — |
| 캘린더 내 이벤트 텍스트 크기 | 추가 크기 조절 | 0 |
| 캘린더 내 이벤트 볼드 | on/off | — |
| 캘린더 내 태그 색상 표시 | on/off | — |
| 이벤트 목록 텍스트 크기 | 추가 크기 조절 | 0 |
| 공휴일 표시 | on/off | — |
| 음력 날짜 표시 | on/off | — |
| 12/24시간 표시 | 12h/24h | 디바이스 설정 |
| 미완료 할일 상단 표시 | on/off | — |
| 햅틱 피드백 | on/off | — |
| 애니메이션 효과 | on/off | — |

### 12.2 이벤트 기본값 설정

| 설정 | 옵션 |
|---|---|
| 기본 이벤트 길이 | 0분/5분/10분/15분/30분/45분/1시간/2시간/하루종일 |
| 기본 태그 | 태그 선택 |
| 기본 알림 (시간 이벤트) | 알림 시간 옵션 선택 |
| 기본 알림 (하루종일) | 알림 시간 옵션 선택 |
| 기본 지도 앱 | Apple Maps / Google Maps / Naver / Kakao |

### 12.3 공휴일 설정

- 국가 선택 (디바이스 지역 코드 기반 자동 선택)
- 연도별 공휴일 lazy 로딩
- 캐시: `[countryCode][year][holidays]` 중첩 구조
- 12월 → 다음해, 1월 → 전년도 공휴일도 함께 로드

### 12.4 타임존 설정

- 기본: 시스템 타임존
- 전체 타임존 목록에서 선택
- 하루종일 이벤트는 타임존에 따라 시간 조정

### 12.5 컬러 테마

사용 가능: systemTheme, defaultLight, defaultDark

### 12.6 기본 태그 색상

- 기본(default) 태그 색상: hex 값으로 설정
- 공휴일(holiday) 태그 색상: hex 값으로 설정

---

## 13. 공유 상태 관리 (SharedDataStore)

모든 Usecase가 하나의 SharedDataStore 싱글톤을 통해 상태를 공유. Combine 기반 실시간 전파.

### 13.1 주요 키

| 키 | 타입 | 관리 주체 |
|---|---|---|
| `accountInfo` | AccountInfo? | AccountUsecase |
| `todos` | [String: TodoEvent] | TodoEventUsecase |
| `uncompletedTodos` | [TodoEvent] | TodoEventUsecase |
| `schedules` | MemorizedEventsContainer | ScheduleEventUsecase |
| `tags` | [EventTagId: EventTag] | EventTagUsecase |
| `offEventTagSet` | Set\<EventTagId\> | EventTagUsecase |
| `defaultEventTagColor` | DefaultEventTagColorSetting | EventTagUsecase |
| `foremostEventId` | ForemostEventId | ForemostEventUsecase |
| `googleCalendarTags` | [String: [Tag]] | GoogleCalendarUsecase |
| `googleCalendarEvents` | [String: Event] | GoogleCalendarUsecase |
| `externalCalendarAccounts` | [String: [AccountInfo]] | ExternalCalendarIntegrationUsecase |
| `calendarAppearance` | CalendarAppearanceSettings | UISettingUsecase |
| `eventSetting` | EventSettings | EventSettingUsecase |
| `timeZone` | TimeZone | CalendarSettingUsecase |
| `firstWeekDay` | DayOfWeeks | CalendarSettingUsecase |
| `currentCountry` | HolidaySupportCountry | HolidayUsecase |
| `holidays` | [Int: [Holiday]] | HolidayUsecase |

### 13.2 화면 간 통신

| 방향 | 메커니즘 | 용도 |
|---|---|---|
| 간접 공유 | SharedDataStore (Usecase 경유) | 같은 데이터를 구독하는 독립 화면 간 |
| Parent → Child | Interactor | 부모가 자식에게 명령 |
| Child → Parent | Listener (weak) | 자식이 부모에게 이벤트 전달 |

---

## 14. 딥링크

| 항목 | 내용 |
|---|---|
| 스킴 | `tc.app://` |
| 호스트 | `calendar` |
| 처리 | `ApplicationDeepLinkHandlerImple` |

- 앱 실행 시 / 위젯 탭 시 딥링크 수신
- Calendar 화면 미초기화 시 대기 큐에 보관
- 미지원 링크 → 앱 업데이트 안내 (`.needUpdate`)

---

## 15. 피드백

- 연락처 이메일 (선택)
- 피드백 메시지
- 디바이스 정보 자동 수집 (OS 버전, 앱 버전, 디바이스 모델, Mac 실행 여부)

---

## 16. 미완료 할일 정책

> **상세 스펙**: [spec/uncompleted-todos.md](spec/uncompleted-todos.md) — 자동 갱신 트리거 전체 목록, 경계값 판정, 엣지 케이스

**정의**: 시간이 설정되어 있고, `time.upperBoundWithFixed <= 현재시각`인 할일 (기한 초과)

**분류**:
| 조건 | 분류 | 미완료 목록 |
|---|---|---|
| time == nil | 현재 할일 | 제외 |
| time.upperBound <= now | 기한 초과 | **포함** |
| time.upperBound > now | 예정 할일 | 제외 |

**자동 관리**: 생성/수정/완료/삭제/건너뛰기/일괄 제거 시마다 자동 갱신
- 시간이 과거가 되면 자동 추가, 미래가 되면 자동 제거
- 시간을 nil로 변경하면 "현재 할일"로 전환 → 목록에서 제거
- 캘린더 메인 화면에서 별도 섹션으로 상단 표시 (설정으로 토글 가능)

---

## 17. D-Day 카운트다운

`DaysIntervalCountUsecase` — 이벤트/공휴일까지 남은 일수를 실시간 계산.

- 매초 업데이트 (타이머 기반)
- 타임존 인지
- 공휴일 상세 화면에서 사용

---

## 18. DB 마이그레이션

### 메인 DB (`todo_calendar.db`)
1. `AppEnvironment.dbVersion` 증가 (현재 v6)
2. 해당 Table 타입의 `migrateStatement(for version:)`에 case 추가

### 외부 캘린더 DB (`google_calendar.db`)
1. `AppEnvironment.googleCalendarDBVersion` 증가 (현재 v0)
2. 외부 캘린더 테이블의 `migrateStatement(for version:)`에 case 추가
3. DB 연결은 `ExternalCalendarDBConnectionPool`이 관리 (참조 카운팅, lazy open)

---

## 19. 주요 외부 의존성

| 라이브러리 | 용도 |
|---|---|
| Alamofire | HTTP 클라이언트 |
| Combine | 반응형 스트림 (메인) |
| RxSwift | 반응형 스트림 (일부) |
| PreludeSwift | 함수형 프로그래밍 연산자 (렌즈, `\|>`, `.~`) |
| SQLiteService | SQLite 래퍼 |
| FirebaseMessaging | 푸시 알림 |
| AppAuth | Google OAuth2 |
