# 미완료 할일 정책 상세 스펙

> 메인 기획서 [섹션 16](../product-specification.md#16-미완료-할일-정책) 참조

---

## 1. 정의

**미완료 할일** = 시간이 설정되어 있고, 그 시간이 **현재 이전**(과거 또는 현재)인 할일.

```
분류 기준: time?.upperBoundWithFixed 와 현재 시각 비교

  time == nil                          → 현재 할일 (미완료 아님)
  time.upperBoundWithFixed <= now      → 미완료 (기한 초과)
  time.upperBoundWithFixed > now       → 예정 할일 (미완료 아님)
```

| 상태 | 조건 | 미완료 목록 |
|---|---|---|
| 시간 없는 할일 | `time == nil` | **제외** |
| 기한 초과 할일 | `time.upperBound <= 현재` | **포함** |
| 미래 예정 할일 | `time.upperBound > 현재` | **제외** |

---

## 2. 자동 갱신 트리거

미완료 할일 목록은 아래 액션마다 자동으로 갱신됨:

### 목록에 추가되는 경우

| 트리거 | 조건 |
|---|---|
| 할일 생성 | 생성된 할일의 time이 과거/현재 |
| 할일 수정 (시간 변경) | 변경된 time이 과거/현재 |
| 반복 할일 완료 후 다음 인스턴스 | 다음 인스턴스의 time이 과거/현재 |
| 반복 할일 삭제(이번만) 후 다음 인스턴스 | 다음 인스턴스의 time이 과거/현재 |
| 반복 할일 건너뛰기 후 | 건너뛴 후의 time이 과거/현재 |

### 목록에서 제거되는 경우

| 트리거 | 조건 |
|---|---|
| 할일 생성 | 생성된 할일의 time이 미래 또는 nil |
| 할일 수정 (시간 변경) | 변경된 time이 미래 또는 nil |
| 할일 완료 | 항상 제거 |
| 할일 삭제 | 항상 제거 |
| 반복 할일 건너뛰기 후 | 건너뛴 후의 time이 미래 |
| 일괄 제거 (handleRemovedTodos) | 해당 ID 필터링 |

### 전체 교체

| 트리거 | 동작 |
|---|---|
| 미완료 할일 로딩 (refreshUncompletedTodos) | Repository에서 전체 목록 새로 로드 → 기존 목록 교체 |

---

## 3. 경계값 판정 (upperBoundWithFixed)

EventTime 형태별 비교 기준값:

| EventTime | upperBoundWithFixed | 의미 |
|---|---|---|
| `.at(t)` | `t` | 마감 시각 그 자체 |
| `.period(lower..<upper)` | `upper` | 기간 종료 시각 |
| `.allDay(lower..<upper, _)` | `upper` | 하루종일 범위 종료 |

- `.at` 시점의 할일: 정확히 그 시각이 지나면 미완료
- `.period` 기간의 할일: 기간이 끝나야 미완료
- `.allDay` 할일: 하루종일 범위가 끝나야 미완료 (타임존 오프셋은 비교 시 미적용)

---

## 4. 목록 갱신 내부 동작

### updateOrAppendUncompletedTodoAtList

- 같은 UUID의 할일이 이미 목록에 있으면 → **교체** (최신 상태로 갱신)
- 없으면 → **추가**

### removeUncompletedTodoAtList

- UUID로 필터링하여 제거

---

## 5. SharedDataStore

| 키 | 타입 | 설명 |
|---|---|---|
| `uncompletedTodos` | [TodoEvent] | 미완료 할일 배열 |

- 독립 키로 관리 (`todos`와 별도)
- 로딩 시 `.put`으로 전체 교체, 개별 갱신 시 `.update`로 부분 수정

---

## 6. UI 표시

- 캘린더 메인 화면(DayEventList)에서 **별도 섹션**으로 상단 표시
- 설정 "미완료 할일 상단 표시" 토글로 표시 여부 제어 가능
- 로딩 중 `refreshingUncompletedTodo(true/false)` 브로드캐스트

---

## 7. 엣지 케이스

### 시간 정확히 현재인 경우

`time.upperBoundWithFixed == now` → **미완료에 포함** (`<=` 조건)

### 반복 할일 완료 후 다음 인스턴스가 이미 기한 초과

```
매주 월요일 반복, 현재 화요일:
  이번 월요일(turn=3) 완료 → DoneTodoEvent 생성
  다음 월요일(turn=4) 생성 → 아직 미래 → 미완료 아님
```

```
매일 반복, 3일간 방치:
  3일 전(turn=5) 완료 → DoneTodoEvent 생성
  2일 전(turn=6) 생성 → 이미 과거 → 미완료에 추가
```

### 시간을 nil로 변경

기존 미완료 할일의 시간을 제거하면 → "현재 할일"로 전환 → 미완료 목록에서 **제거**
