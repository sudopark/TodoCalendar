---
issue: "#736"
subdomain: Event
symptoms: [반복 todo count 종료 안됨, 종료조건 n회 초과 반복, repeatingTurn 유실, 업로드 후 turn 리셋]
resolution: fixed
---

# 종료조건이 n회인 반복 할일이 n회를 훌쩍 넘겨서까지 반복된다

- **증상**: 로그인 상태에서 `.count(10)` 반복 할일이 10회를 넘겨 30회 가까이 반복되다 종료됨. 완료·스킵·이번만 삭제·이번만 수정 중 무엇으로 회차를 넘겨도 동일.

- **근본 원인**: `EventUploadServiceImple.uploadTodoEvent`가 로컬 할일을 서버로 올릴 때 `repeatingTurn`을 페이로드에서 빠뜨렸다. 이 업로드는 `TodoEditParams(.put)` = HTTP PUT(전체 교체)이라 서버의 `repeating_turn`이 비워진다. 이후 sync가 서버 우선(Last-Write-Wins)으로 로컬을 덮으면서(`EventSyncRepositoryImple.updateCreatedOrUpdated` → `updateTodoEvents`는 `shouldReplace: true`) 로컬 turn까지 nil이 되고, `origin.repeatingTurn ?? 1`이 turn 1로 되돌린다. 로컬 turn 전진(`TodoLocalRepositoryImple.replaceTodoNextEventTimeIfIsRepeating`)은 정상이었고, sync가 끼지 않은 구간에서만 회차가 누적돼 종료 시점이 들쭉날쭉했다.

- **해결**: `uploadTodoEvent` 페이로드에 `repeatingTurn`을 실었다. 바로 옆 `uploadScheduleEvent`가 일정의 반복 장부(`showTurn`·`repeatingTimeToExcludes`)를 이미 그대로 올리고 있어 규약 복원에 가깝다. 회귀 테스트는 `EventUploadServiceImpleTests.service_updateRepeatingTodo_uploadRepeatingTurn`.

  같은 누락이 서버로 나가는 페이로드 두 곳에 더 있어 함께 실었다 — `BatchTodoEventPayload.asJson`(비로그인 로컬 데이터의 로그인 시 이관)과 `RevertToggleTodoDoneParameter.asJson`(위젯 토글 되돌리기의 origin). 단 후자는 origin이 `PendingDoneTodoEventTable`에서 복원되는데 그 테이블에 `repeating_turn` 컬럼이 없어, 해당 컬럼이 생기기 전까지 실리는 값은 항상 nil이다 (#835 항목 2).

- **기각 방향**: sync 반영 시 서버 turn이 nil이면 로컬 turn 유지 — 서버 값은 계속 비어 있어 기기 교체·재설치에서 재발하는 증상 패치.
