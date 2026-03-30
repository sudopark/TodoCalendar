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

| 타입 | 설명 |
|---|---|
| `.default` | 기본 태그 (시스템) |
| `.holiday` | 공휴일 태그 (시스템) |
| `.custom(String)` | 사용자 생성 태그 |
| `.externalCalendar(serviceId, calendarId)` | 외부 캘린더 태그 (구글 등) |

### 5.2 태그 CRUD

- **생성**: 이름 + 색상(hex) 지정. 중복 이름 체크 옵션 (`skipCheckDuplicationName`)
- **수정**: 이름/색상 변경
- **삭제**: 빈 태그 삭제 또는 관련 이벤트 일괄 삭제 선택

### 5.3 태그 보이기/숨기기

- 커스텀 태그: 생성 시 기본 **보임**
- 외부 캘린더 태그: 연동 시 기본 **숨김** (사용자가 명시적으로 활성화)
- 숨김 태그 ID 목록은 `offEventTagIdsOnCalendar`로 관리
- 토글/일괄 추가/일괄 제거/서비스별 초기화 지원

### 5.4 색상 결정

| 태그 유형 | 색상 소스 |
|---|---|
| default/holiday | `DefaultEventTagColorSetting`의 hex 값 |
| custom | `CustomEventTag.colorHex` |
| 구글 캘린더 | `GoogleCalendarEventColorSource` (calendarId + 이벤트별 colorId) |

---

## 6. 강조 이벤트 (Foremost Event)

사용자가 가장 중요한 이벤트 **1개**를 지정하는 기능.

- `ForemostEventId`: eventId + isTodo 플래그로 식별
- 캘린더 일별 목록 상단에 고정 표시
- 위젯에서 강조 노출 (`ForemostEventWidget`)
- 지정/해제 시 상태 표시: idle / marking / unmarking
- 위젯에서 할일 완료 토글 가능 (`TodoToggleIntent`)

---

## 7. 알림

### 7.1 알림 시간 옵션

**시간 지정 이벤트용**
| 옵션 | 설명 |
|---|---|
| 정시 (atTime) | 이벤트 시각에 알림 |
| N초 전 (before) | 1분/5분/10분/15분/30분/1시간/2시간/24시간/48시간/168시간 전 |

**하루종일 이벤트용**
| 옵션 | 설명 |
|---|---|
| 당일 9시 (allDay9AM) | 이벤트 당일 오전 9시 |
| 당일 12시 (allDay12AM) | 이벤트 당일 정오 |
| N일 전 9시 (allDay9AMBefore) | 1일/2일/7일 전 오전 9시 |

**커스텀**: `DateComponents`로 자유 지정

### 7.2 알림 정책

- 이벤트당 **복수** 알림 시간 설정 가능
- 기본 알림 시간: 시간 이벤트 / 하루종일 이벤트 별도 설정
- 로컬 알림 스케줄링 범위: 향후 **365일**
- 반복 일정: 각 반복 인스턴스마다 알림 생성
- 이벤트 변경 시: 기존 알림 제거 → 새 알림 등록
- 알림 ID는 DB에 저장하여 추후 제거에 사용
- FCM 푸시 알림: 서버 연동(로그인) 시 토큰 등록

### 7.3 알림 권한

- `UNUserNotificationCenter` 기반 권한 요청
- 상태: `.notDetermined` / `.denied` / `.authorized`
- 설정 화면에서 시스템 알림 설정으로 이동 가능

---

## 8. 구글 캘린더 연동

### 8.1 개요

- **읽기 전용** 연동 (조회만 가능, 편집 불가)
- **다중 계정** 동시 지원
- Google OAuth2로 인증
- 연동 후 캘린더 목록/이벤트/색상 자동 동기화

### 8.2 데이터 모델

| 모델 | 설명 |
|---|---|
| `GoogleCalendar.Colors` | 계정별 캘린더/이벤트 색상 맵 |
| `GoogleCalendar.Tag` | 캘린더 = 태그 (이름, 색상, 소유자) |
| `GoogleCalendar.Event` | 앱용 간소화 이벤트 (ID, 이름, 시간, 색상, 반복) |
| `GoogleCalendar.EventOrigin` | API 원본 (참석자, 회의 링크, 첨부파일, 상태 등 전체) |

### 8.3 연동 플로우

```
OAuth 인증 → 자격증명 저장 → DB 연결 (참조 카운팅)
  → 색상 로드 → 캘린더 목록 로드 → 이벤트 동기화
```

### 8.4 연동 해제 플로우

```
자격증명 삭제 → DB 연결 해제 (ref count 감소)
  → SharedDataStore에서 제거 → 캐시 정리 → 태그 off 상태 정리
```

### 8.5 캘린더 보이기/숨기기

- 구글 캘린더에서 `isSelected != true`인 캘린더는 기본 숨김
- 사용자가 명시적으로 활성화 필요
- 태그 토글로 캘린더별 표시 제어

### 8.6 이벤트 상세 (읽기 전용)

표시 항목: 이벤트명, 시간, 위치, 참석자 목록, 회의 링크, 첨부파일, 설명, 색상, 상태(확정/미정/취소), 공개 범위

"구글 캘린더에서 편집" 버튼 → Safari로 이동

---

## 9. 위젯 (18종)

### 9.1 기본 위젯 (7종)

| 위젯 | 설명 |
|---|---|
| TodayAndNext | 오늘 요약 + 다음 이벤트 |
| Today | 오늘 일정 요약 (완료/미완료 카운트) |
| NextEvent | 다음 예정 이벤트 + 카운트다운 |
| NextRemainEvent | 다음 이벤트 (남은 시간 강조) |
| ForemostEvent | 강조 이벤트 표시 |
| Month | 월 캘린더 그리드 |
| EventList | 다가오는 이벤트 스크롤 목록 (태그 필터) |

### 9.2 주/월 이벤트 위젯 (7종)

| 위젯 | 기간 |
|---|---|
| OneWeekEvents | 7일 |
| TwoWeekEvents | 14일 |
| ThreeWeekEvents | 21일 |
| FourWeekEvents | 28일 |
| CurrentMonthEvents | 이번 달 |
| LastMonthEvents | 지난 달 |
| NextMonthEvents | 다음 달 |

### 9.3 조합 위젯 (4종)

| 위젯 | 구성 |
|---|---|
| TodayAndMonth | 오늘 요약 + 월 캘린더 |
| EventAndMonth | 이벤트 목록 + 월 캘린더 |
| EventAndForemost | 이벤트 목록 + 강조 이벤트 |
| DoubleMonth | 연속 2개월 캘린더 |

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
