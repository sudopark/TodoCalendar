# Domain Notes

각 세션 시작 시 리캡용. 구현 세부사항보다 **설계 의도와 도메인 규칙** 중심으로 기록.

---

## 반복 이벤트 (Repeating Events)

### Turn 의미
- turn은 반복 이벤트의 순서 번호. **1부터 시작** (0이 아님)
- turn 1 = 첫 번째 발생, turn N = N번째 발생
- `MemorizedEventsContainer`에서 반복 시간 열거 시 항상 `turn: 1`에서 시작

### EventRepeatTimeEnumerator
- 역할: 현재 반복 시간 → 다음 반복 시간 계산
- `nextEventTime(from:until:)`: `from.turn + 1`을 next.turn으로 반환
- 반복 종료 판단:
  - `.until(endTime)`: next 이벤트 시간이 endTime 초과 → nil
  - `.count(endCount)`: `next.turn > endCount` → nil
  - 즉, `endCount = 3`이면 turn 1·2·3이 유효, turn 4부터 종료

### TodoEvent.repeatingTurn
- 해당 todo가 몇 번째 반복인지 저장
- `nil` = 첫 번째 발생 (turn 1로 취급)
- 완료 / 수정(onlyThisTime) / 삭제(onlyThisTime) / skip 처리마다 다음 turn으로 업데이트
- **이 값이 없으면** count 기반 반복 종료가 동작하지 않음
  - nextEventTime 호출 시 항상 turn 1에서 시작 → next.turn = 2 → endCount 체크 무의미

### 다음 반복 이벤트 계산 위치
- Local: `TodoLocalRepositoryImple.replaceTodoNextEventTimeIfIsRepeating`
- Remote: `TodoRemoteRepositoryImple.findNextRepeatingEvent`
- 두 곳 모두 동일한 규칙: `origin.repeatingTurn ?? 1`을 starting turn으로 사용하고,
  계산된 `next.turn`을 `nextTodo.repeatingTurn`에 저장

---

## DB 마이그레이션

- `AppEnvironment.dbVersion` 증가
- 해당 `Table` 타입의 `migrateStatement(for version:)` 에 case 추가
- 두 가지를 함께 변경해야 마이그레이션이 실행됨
