---
issue: "#755"
subdomain: Event
symptoms: [비반복 이벤트에 이번만 삭제, 컨텍스트 메뉴 깜빡임, 메뉴 탭 무반응, sync 호출 과다]
resolution: fixed
---

# 비반복 이벤트를 롱탭했는데 컨텍스트 메뉴에 "이번만 삭제"가 뜬다

- **증상**: AI 커맨드로 일정을 만들고 백그라운드 갔다 복귀한 직후, 비반복 이벤트를 롱탭하면 반복 이벤트 전용인 "이번만 삭제"가 메뉴에 뜬다. 메뉴가 갱신되듯 깜빡이고 항목을 눌러도 반응이 없다.

- **근본 원인**: `DayEventListViewModelImple`의 셀 목록 publisher가 내용이 같은 배열을 계속 재방출한다. `cellViewModels`·`foremostEventModel`·`uncompletedTodoEventModels` 어디에도 중복 제거가 없고, 상류인 `subject.currentDayAndEventLists`(Month → CalendarPaper → DayEventList 통지)와 `TodoEventUsecase.currentTodoEvents`(`ShareDataKeys.todos` dict 전체를 observe)가 무관한 갱신에도 매번 흘린다. 포그라운드 복귀는 전 범위 refresh + sync + syncEnd 후 재-refresh가 겹치는 구간이라 이 재방출이 몰린다.

  셀 목록이 갈아엎히면 `EventListCellView.contextMenu`의 `cellViewModel.moreActions`도 매 렌더 다시 계산된다. 롱탭 시작과 메뉴 표시 사이에 그 자리를 반복 이벤트가 차지하면 반복 이벤트의 메뉴가 그려진다. `isRepeating`은 `schedule.repeating != nil` / `todo.time != nil && todo.repeating != nil`로만 정해져서 비반복이 반복으로 계산될 경로 자체가 없다 — 값이 틀린 게 아니라 다른 이벤트의 메뉴다. 깜빡임·탭 무반응(`removeEvent`의 confirm alert present가 씹힘)도 같은 재평가에서 나온다.

- **해결**: `EventCellViewModel.customCompareKey`(셀이 그리는 값 전부 — 타입·id·이름·색 소스·기간 텍스트·isForemost·isRepeating·allday·moreActions)를 도입하고 위 세 publisher에 `removeDuplicates(by:)`를 건다. `CalendarEventListhUsecase`가 이미 쓰는 `compareKey` 기반 중복 제거와 같은 패턴. 값이 실제로 바뀌면 키가 달라져 그대로 방출된다.

  키는 **프로토콜 요구사항**이어야 한다 — `EventCellViewModel`이 프로토콜이라 공통 프로퍼티만 보는 extension 단독 구현으로는 각 타입이 따로 들고 있는 값이 키에 못 들어간다. `makeCustomCompareKey(_:)`가 공통 성분을 조립하고 타입이 고유 값을 얹는다: Todo·Schedule은 `eventTimeRawValue`("이번만 삭제"가 지울 회차를 정하는 값 — 표시 텍스트가 같아도 달라질 수 있다), Google·Apple은 라우팅에 쓰는 `accountId`·`calendarId`. 상류 `GoogleCalendarEvent.compareKey`에도 `accountId`가 빠져 있어 함께 채웠다 — 상류에서 걸리면 셀 키가 정확해도 발화하지 못한다. 이 구조는 #385에서 `ForEach(id:)` 오용을 고치며 같이 지워졌던 것(`a9e9583f`)이고, identity(안정적인 id)와 변경 감지(내용 키)는 별개 관심사라 `ForEach`는 `eventIdentifier`로 둔 채 키만 되살렸다.

- **기각 방향**:
  - Month → listener 통지 경로에 dedupe — 상류라 timezone·is24hourForm·pending todo 등 다른 축의 중복을 못 막는다
  - ViewState 대입 시점 비교 — View 레이어에 비교 로직이 새고 상태 세 개에 각각 심어야 한다
  - 포그라운드 복귀 sync/refresh 중복 정리 — 실재하지만(`CalendarViewModel.bindRefreshEvents`가 willEnterForeground 하나로 전 범위 refresh + sync를 동시에 걸고, sync 완료 후 `syncEnd`로 또 refresh) 이번 스코프에서 유저가 제외. 무한 재귀는 아님
  - `EventSyncUsecaseImple.runSyncTask`의 취소 태스크가 CancellationError를 먹고 끝까지 굴러가 가짜 `isSyncing=false`를 쏘는 건 별건 — 미수정
