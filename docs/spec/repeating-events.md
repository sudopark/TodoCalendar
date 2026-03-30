# 반복 이벤트 상세 스펙

> 메인 기획서 [섹션 4](../product-specification.md#4-반복-이벤트) 참조

---

## 1. 반복 옵션 (6가지)

### 1.1 매일 (EveryDay)

| 파라미터 | 범위 | 설명 |
|---|---|---|
| interval | 1~999 | N일 간격 |

- **타임존**: 불필요 (Gregorian 캘린더 기본)
- **다음 시간 계산**: 현재 날짜 + interval일, 시/분/초 유지
- **예시**: interval=3 → 1/1, 1/4, 1/7, 1/10, ...

---

### 1.2 매주 (EveryWeek)

| 파라미터 | 범위 | 설명 |
|---|---|---|
| interval | 1~5 | N주 간격 |
| dayOfWeeks | [DayOfWeeks] | 반복할 요일 (일=1, 월=2, ..., 토=7) |
| timeZone | TimeZone | **필수** (주 경계 판단) |

- **다음 시간 계산**:
  1. 같은 주 내에서 다음 반복 요일 검색
  2. 없으면 → 다음 주(+interval 주)의 첫 반복 요일
- **헬퍼**: `isEveryWeekDays` — 월~금 전체 선택 시 `true`
- **예시**: interval=2, dayOfWeeks=[월,수,금]
  ```
  1주차: 월, 수, 금
  2주차: (건너뜀)
  3주차: 월, 수, 금
  4주차: (건너뜀)
  ...
  ```

---

### 1.3 매월 (EveryMonth)

| 파라미터 | 범위 | 설명 |
|---|---|---|
| interval | 1~11 | N개월 간격 |
| selection | DateSelector | 일자 또는 요일 서수 |
| timeZone | TimeZone | **필수** (월 경계 판단) |

#### 모드 A: 일자 지정 (`days([Int])`)

- 1~31 중 복수 선택 가능
- **월 끝자리 처리**: 해당 월에 없는 일자는 마지막 날로 내림
  - 예: day=31 + 2월 → 28일 (윤년이면 29일)
  - 예: day=30 + 2월 → 28일
- **다음 시간 계산**:
  1. 같은 달 내 다음 반복 일자 검색
  2. 없으면 → 다음 달(+interval 개월)의 첫 반복 일자

**예시**: interval=1, days=[15, 31]
```
1월: 15일, 31일
2월: 15일, 28일 (31→28 내림)
3월: 15일, 31일
4월: 15일, 30일 (31→30 내림)
```

#### 모드 B: 요일 서수 지정 (`week([WeekOrdinal], [DayOfWeeks])`)

- **WeekOrdinal**: `.seq(1)` ~ `.seq(4)` 또는 `.last`
- 복수 서수 + 복수 요일 조합 가능
- **다음 시간 계산**:
  1. Calendar의 `weekdayOrdinal` 컴포넌트로 판정
  2. 같은 달 내 다음 서수/요일 조합 검색
  3. 없으면 → 다음 달(+interval 개월)의 첫 조합

**예시**: interval=1, ordinals=[.seq(1)], weekDays=[.tuesday]
```
매월 첫째 화요일: 1/7, 2/4, 3/4, 4/1, ...
```

**예시**: interval=1, ordinals=[.last], weekDays=[.friday]
```
매월 마지막 금요일: 1/31, 2/28, 3/28, 4/25, ...
```

---

### 1.4 매년 (EveryYear)

| 파라미터 | 범위 | 설명 |
|---|---|---|
| interval | 1~99 | N년 간격 |
| months | [Months] | 반복할 월 (1월=1, 12월=12) |
| weekOrdinals | [WeekOrdinal] | 월 내 요일 서수 |
| dayOfWeek | [DayOfWeeks] | 반복할 요일 |
| timeZone | TimeZone | **필수** |

- 월 + 서수 + 요일의 3단계 조합
- **다음 시간 계산**: 같은 해 → 다음 해(+interval 년) 순서로 검색
- **예시**: months=[3], weekOrdinals=[.last], dayOfWeek=[.friday], interval=1
  ```
  매년 3월 마지막 금요일
  ```

---

### 1.5 매년 특정일 (EveryYearSomeDay)

| 파라미터 | 범위 | 설명 |
|---|---|---|
| interval | 1~99 | N년 간격 |
| month | Int | 월 (고정) |
| day | Int | 일 (고정) |
| timeZone | TimeZone | **필수** |

- 고정된 월/일 조합
- **다음 시간 계산**: 같은 날짜 + interval년
- **예시**: month=12, day=25, interval=1 → 매년 12월 25일

---

### 1.6 음력 매년 (LunarCalendarEveryYear)

| 파라미터 | 범위 | 설명 |
|---|---|---|
| month | Int | 음력 월 |
| day | Int | 음력 일 |
| timeZone | TimeZone | **필수** |

- **interval**: 항상 1 (설정 불가, 매년 고정)
- **달력**: Chinese Calendar (`Calendar(identifier: .chinese)`) 사용
- 음력 날짜 → 양력 날짜 변환하여 반복 시간 결정
- **예시**: month=1, day=1 → 음력 설날
  ```
  2025: 1/29 (양력)
  2026: 2/17 (양력)
  2027: 2/6 (양력)
  ```

---

## 2. 종료 조건 (RepeatEndOption)

| 조건 | 설명 | 종료 판정 |
|---|---|---|
| 없음 (nil) | 무한 반복 | 수동 삭제 전까지 |
| `.until(TimeInterval)` | 특정 시점까지 | `nextTime.upperBoundWithFixed > endTime` |
| `.count(Int)` | 총 N회 | `turn > endCount` |

- `.until`과 `.count`는 **상호 배타적**
- 하루종일 이벤트의 `.until` 판정: `latestTimeZoneInterval` 사용하여 타임존 확장

### count 동작 예시

```
count=3:
  turn 1 → 1번째 발생 (유효)
  turn 2 → 2번째 발생 (유효)
  turn 3 → 3번째 발생 (유효)
  turn 4 → 종료 (4 > 3)
```

### until 동작 예시

```
until=2026-06-30, 매월 15일 반복:
  1/15 → 유효
  2/15 → 유효
  ...
  6/15 → 유효 (upperBound <= until)
  7/15 → 종료 (7/15 > 6/30)
```

---

## 3. 다음 반복 시간 계산 (EventRepeatTimeEnumerator)

### 입력/출력

| | 타입 | 설명 |
|---|---|---|
| 입력 | `RepeatingTimes` | 현재 EventTime + turn 번호 |
| 출력 | `RepeatingTimes?` | 다음 EventTime + turn+1, 또는 nil (종료) |

### 초기화

```
EventRepeatTimeEnumerator(
  option: EventRepeatingOption,    // 6가지 중 하나
  endOption: RepeatEndOption?,     // 종료 조건
  without: Set<String>             // 제외할 시간의 customKey 집합
)
```

- 반복 옵션에 따라 적절한 Calendar 설정 (Gregorian or Chinese)
- TimeZone을 옵션에서 가져와 Calendar에 적용

### 계산 절차

```
1. 현재 시간(lowerBoundWithFixed)에서 시작
2. 옵션 타입별 다음 날짜 계산
3. 제외 시간 체크:
   if 계산된 시간의 customKey ∈ 제외 목록:
     → 재귀적으로 그 다음 시간 계산 (이 시간을 건너뜀)
4. turn 증가: turn + 1
5. 종료 조건 체크:
   if .until: nextTime.upperBoundWithFixed > endTime → nil
   if .count: newTurn > endCount → nil
6. → RepeatingTimes(time: nextTime, turn: newTurn)
```

### 제외 시간 재귀 처리

`.onlyThisTime`으로 제외된 시간은 자동으로 건너뜀:

```
매주 월요일, 3/17 제외됨:
  현재: 3/10 (turn=2)
  → 계산: 3/17 → customKey가 제외 목록에 있음
  → 재귀: 3/24 → 제외 아님 → turn=3
  결과: 3/24 (turn=3)
```

여러 연속 시간이 제외된 경우에도 재귀적으로 유효한 시간까지 탐색.

### EventTime 시프트

다음 시간 계산 시 원본 EventTime의 **형태를 유지**:
- `.at(t)` → `.at(newT)`
- `.period(range)` → `.period(newRange)` (duration 유지)
- `.allDay(range, offset)` → `.allDay(newRange, offset)` (offset 유지)

---

## 4. EventTime 겹침 판정

### isRoughlyOverlap (대략적 판정)

캘린더 표시용으로 사용. 하루종일 이벤트의 타임존을 **최대한 넓게** 잡음.

| EventTime | 판정 방식 |
|---|---|
| `.at(t)` | `period ~= t` (포함 여부) |
| `.period(r)` | `r.overlaps(period)` (범위 교차) |
| `.allDay(r, offset)` | 범위를 타임존 전 세계 커버로 확장 후 비교 |

**하루종일 확장 범위**:
- 하한: `offset - 14시간` (UTC+14 대응, 키리바시 등)
- 상한: `offset + 12시간` (UTC-12 대응, 베이커 섬 등)

### isOverlap (정밀 판정)

특정 타임존 기준으로 정확하게 판정.

| EventTime | 판정 방식 |
|---|---|
| `.at(t)` | `period ~= t` |
| `.period(r)` | `r.overlaps(period)` |
| `.allDay(r, offset)` | `r`을 저장된 offset → 대상 타임존으로 시프트 후 비교 |

**시프트 공식**:
```
UTC 범위 = r.lower + offset ..< r.upper + offset
대상 TZ 범위 = UTC.lower - targetOffset ..< UTC.upper - targetOffset
```

### EventRepeating.isOverlap

반복 시리즈 전체가 기간과 겹치는지 판정:
- 반복 시작 시간 ~ 반복 종료 시간 범위로 겹침 체크
- 종료 시간 없음(무한) → 시작 시간 < period.upperBound 이면 겹침

---

## 5. EventTime.customKey (고유 키)

반복에서 특정 회차를 식별하는 문자열 키:

| EventTime | customKey 형식 | 예시 |
|---|---|---|
| `.at(1710000000)` | `"1710000000"` | 시점의 정수부 |
| `.period(100..<200)` | `"100..<200"` | 범위의 정수부 |
| `.allDay(100..<200, +32400)` | `"100..<200+32400"` | 범위 + 오프셋 |

- `repeatingTimeToExcludes: Set<String>`에 저장
- `EventRepeatTimeEnumerator`에서 제외 체크에 사용

---

## 6. Turn 규칙 — 전체 생명주기

### 기본 규칙

- turn은 **1부터 시작** (첫 번째 발생 = turn 1)
- `TodoEvent.repeatingTurn`: nil은 turn 1로 취급 (`origin.repeatingTurn ?? 1`)
- `ScheduleEvent`: `RepeatingTimes(time:, turn: 1)`로 첫 번째 표현
- 다음 반복 계산 시 turn은 항상 `+1`

### Turn 변경 시점

| 이벤트 타입 | 액션 | Turn 변화 |
|---|---|---|
| 할일 | 완료 (completeTodo) | 다음 할일의 turn = 현재 + 1 |
| 할일 | 건너뛰기 (.next) | turn + 1 |
| 할일 | 이번만 삭제 | 다음 회차로 전진, turn + 1 |
| 할일 | 이번만 수정 | 원본 다음으로 전진, turn + 1 |
| 일정 | 시간 제외 (exclude) | turn 변화 없음 (제외 목록으로 관리) |

### Count 종료와의 상호작용

건너뛰기(skip)도 turn을 소비:

```
count=5 반복 할일:
  turn 1 → 완료 (실행)
  turn 2 → 건너뛰기 (미실행, turn 소비)
  turn 3 → 완료 (실행)
  turn 4 → 건너뛰기 (미실행, turn 소비)
  turn 5 → 완료 (실행)
  turn 6 → 종료
  결과: 실제 실행 3회, 건너뜀 2회, 총 5회 소비
```

### 일정과 할일의 Turn 관리 차이

| | 할일 (TodoEvent) | 일정 (ScheduleEvent) |
|---|---|---|
| Turn 저장 | `repeatingTurn` 프로퍼티 | `RepeatingTimes.turn` (계산 결과에 포함) |
| Turn 추적 | 이벤트 자체에 현재 turn 저장 | 캐시(MemorizedEventsContainer)에서 계산 |
| 이번만 제외 | turn 전진 | `repeatingTimeToExcludes`에 추가 |
| Count 종료 | turn > endCount | turn > endCount (계산 시 체크) |

---

## 7. 수정 범위 비교 — 할일 vs 일정

| 범위 | 할일 (TodoEvent) | 일정 (ScheduleEvent) |
|---|---|---|
| 전체 (.all) | 원본 직접 수정 | 원본 직접 수정 |
| 이번만 (.onlyThisTime) | 새 할일 생성 + 원본 다음 turn으로 전진 | 새 이벤트 생성 + 원본 excludes에 추가 |
| 이후 (.fromNow) | **없음** | 원본 until 종료 + 새 시리즈 생성 |

**핵심 차이**: 할일은 "단일 인스턴스"를 추적(현재 turn)하므로 전진으로 처리. 일정은 "전체 시리즈"를 관리하므로 제외 목록으로 처리.
