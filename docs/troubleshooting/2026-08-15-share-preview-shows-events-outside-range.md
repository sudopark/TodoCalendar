---
issue: "#872"
subdomain: Event
symptoms: [공유 미리보기에 범위 밖 이벤트, 반복 일정 turn이 범위 밖인데 노출, 러프한 이벤트 조회, clamped 재판정 누락]
resolution: fixed
---

# 공유 미리보기에 조회 범위와 안 겹치는 이벤트가 섞여 나온다

- **증상**: 공유 미리보기 화면이 선택한 범위(하루)와 실제로 겹치지 않는 이벤트까지 목록에 올린다. 특히 반복 일정의 범위 밖 회차가 섞인다.

- **근본 원인**: `CalendarEventListhUsecase`가 주는 결과 자체가 범위 겹침을 보장하지 않는다. 두 단계에서 느슨해진다.
  1. `EventRepeating.isOverlap`(`Domain/Sources/Models/Events/EventRepeating.swift:150-157`)이 **반복 시리즈 전체가 범위와 겹치는지만** 판정한다 — 개별 회차는 보지 않는다.
  2. 그 뒤 `ScheduleCalendarEvent.events(from:in:foremostId:)`(`Presentations/CalendarScenes/Sources/Common/CalendarEvents/CalendarEvent.swift:160-180`)가 `ScheduleEvent.repeatingTimes`에 누적된 **모든 turn을 range 필터 없이** 이벤트로 펼친다.

  즉 usecase 결과는 "이 범위 근처의 이벤트"에 가깝고, 정확한 겹침 판정은 **소비하는 화면의 책임**으로 남아 있다. 기존 캘린더 화면은 그 책임을 이행한다 — `WeekEventStackBuilder`의 `EventOnWeek.init?`(`Sources/Month/WeekEventStackBuilder.swift:33-47`)가 `EventTimeOnCalendar.clamped(to:)`(`CalendarEvent.swift:31-40`)로 재판정해 걸러낸다. CalendarPaper·DayEventList는 그 결과를 중계만 한다. **신설된 공유 미리보기 화면에만 이 재판정 단계가 없었다.**

- **해결**: `SharePreviewViewModelImple`의 행 목록 조립에서 `events.filter { $0.eventTimeOnCalendar?.clamped(to: range) != nil }`로 재판정한다(`SharePreviewViewModel.swift:337`). `clamped(to:)`는 이미 `public`이고 `Range<TimeInterval>`을 받는 순수 함수라 `WeekEventStackBuilder`를 끌어올 필요가 없다.

  **시간 없는 현재 할일(`allCurrentTodoEvents()`)은 이 필터에서 제외한다** — `eventTimeOnCalendar`가 `nil`이라 필터를 걸면 전부 사라지고, Month·DayEventList도 그것들을 range로 거르지 않는다.

- **기각 방향**:
  - `EventRepeating.isOverlap`을 회차 단위 판정으로 바꾸기 — Domain 전역에 파급되고 캘린더·위젯의 기존 동작을 흔든다. 이 결함은 소비 측 누락이지 Domain 계약의 오류가 아니다.
  - `WeekEventStackBuilder`를 공유 미리보기에서 재사용 — 그 타입은 `CalendarComponent.Week`와 주간 레이아웃 스택 계산을 전제로 해 임의 범위에 안 맞는다. 필요한 건 겹침 판정 한 줄뿐이다.

- **교훈**: usecase가 `in range:` 시그니처를 갖는다고 결과가 그 범위로 정제됐다고 가정하면 안 된다. **같은 usecase를 쓰는 기존 화면이 결과를 그대로 쓰는지 한 번 더 거르는지 확인**하는 것이 새 소비자를 붙일 때의 점검 항목이다.
