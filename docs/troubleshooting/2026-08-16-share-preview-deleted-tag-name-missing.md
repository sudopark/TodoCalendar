---
issue: "#872"
subdomain: Event
resolution: fixed
symptoms: [공유 미리보기 태그명 안나옴, 일부 기본 이벤트만 태그명 누락, 태그 드롭다운 빈 항목, 삭제된 태그, tagName nil]
---

# 공유 미리보기에서 일부 기본 이벤트의 태그명이 안 나온다

- **증상**: 공유 미리보기에서 "태그명 함께 표시"를 켜도 일부 이벤트만 행 끝에 태그명이 안 붙는다. 태그 드롭다운에도 이름 없는 빈 항목이 하나 생긴다. 태그를 안 단 이벤트는 정상적으로 "기본"이 나온다.

- **근본 원인**: 삭제된 커스텀 태그를 참조하는 이벤트를 SharePreview만 폴백 없이 처리했다.
  - `EventTagUsecaseImple.handleTagDeleted`(`Domain/Sources/Usecases/Events/EventTagUsecase.swift:95-102`)는 태그를 공유 맵에서 지우지만 그 태그를 단 이벤트의 `eventTagId`는 그대로 둔다 — 이벤트에 dangling `.custom(id)`가 남는다.
  - 앱 전반은 이런 id를 기본 태그로 간주한다 (`ViewAppearance.color(_:)` `Presentations/CommonPresentation/Sources/Appearance/ViewAppearance.swift:47-51`).
  - `SharePreviewViewModelImple.applyTagNames`에는 그 폴백이 없어 `tagMap` 미스 시 `tagName`을 nil로 남겼다. 본문 행은 이름이 안 붙고, `makeTagCellViewModels`는 `line.tagName ?? ""`로 이름 빈 셀을 만들었다.
  - `eventTagId`가 nil인 이벤트는 `TodoCalendarEvent.init`(`CalendarEvent.swift:113`)에서 `.default`로 승격돼 정상 동작 — 그래서 "일부 기본 이벤트만" 깨져 보였다.

- **왜 테스트가 못 잡았나**: `StubEventTagUsecase.eventTags(_:)`가 요청한 id마다 태그를 즉석에서 만들어 돌려줬다. 실제 구현은 `SharedDataStore`를 필터링만 해서 미스가 나는데, stub은 미스를 만들 수 없었다.

- **해결**: `SharePreviewViewModelImple.resolveTags`(구 `applyTagNames`)가 이름뿐 아니라 tagId를 정규화한다 — `tagMap`에 없는 `.custom(...)`은 `.default`로 치환. 조회 id에 `.default`를 항상 포함시켜 범위에 순수 기본 이벤트가 없어도 이름을 얻는다. stub도 실제 동작(커스텀·기본·공휴일만, 미존재 id는 미스)에 맞췄다.

- **기각 방향**: `tagName`만 폴백 — 드롭다운에 "기본"이 두 줄 뜨고 유령 id를 따로 토글해야 하는 문제가 남는다
- **기각 방향**: `EventTagUsecase.eventTags(_:)`가 폴백 책임 — Domain 계약 변경인데 소비처가 SharePreview 하나뿐이라 과하다
- **기각 방향**: `.externalCalendar`도 폴백 대상에 포함 — 별도 스트림이라 미도착과 미존재를 구분 못 해 오탐이 난다
