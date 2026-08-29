---
issue: "#934"
subdomain: Event
symptoms: [DayEventListViewModelImpleTests, whenLiveActivityUnregistered_cellViewModelsClearMark, Exceeded timeout of 2 seconds, 간헐 실패, CalendarScenes 플레이키]
resolution: deferred
---

# `testViewModel_whenLiveActivityUnregistered_cellViewModelsClearMark` 간헐 타임아웃

- **증상**: `CalendarScenesTests/DayEventListViewModelImpleTests/testViewModel_whenLiveActivityUnregistered_cellViewModelsClearMark` 가 간헐적으로 `Asynchronous wait failed: Exceeded timeout of 2 seconds` 로 실패한다. 크래시가 아니라 진짜 타임아웃이라, 실행 개수가 매번 달라지는 CalendarScenes 크래시 플레이키와는 다른 건이다.

- **측정치** (단일 TC 단독 실행, 같은 시뮬레이터·증분 빌드):
  - #934 item-3 변경 적용 상태: 8회 중 1회 실패 (별도 관측 3회 중 1회, 10회 중 1회)
  - item-3 소스·테스트 5파일을 직전 커밋(84135209)으로 되돌린 상태: 8회 중 0회 실패

- **근본 원인**: 미확정. 0/8 대 1/8 은 통계적으로 귀속을 가르지 못한다. 코드상으로는 #934 변경이 이 테스트에 중립이어야 한다 — 이 테스트 픽스처에서 구글 셀의 `isLiveActivityRegistered` 는 등록 대상이 `.todo(...)` 일 때도 `nil` 일 때도 `false` 라, `DayEventListViewModelImple.cellViewModels` 의 `removeDuplicates(by: customCompareKey)` 가 보는 키가 전이 전후로 바뀌지 않는다. 방출 개수가 달라질 이유를 못 찾았다.

- **테스트 자체의 레이스 정황**: 이 테스트만 timeout 이 2.0s 이고 같은 파일의 형제들은 0.1s 다 — 작성 시점에 이미 레이스가 있어 타임아웃을 올려 덮은 흔적으로 읽힌다. `cellViewModels` 가 `receive(on: cvmCombineScheduler)` 홉을 두 번 타는데 테스트는 `clearedState` 구독 직후 `registeredTargetSubject.send(nil)` 을 쏜다.

- **해결**: 보류. 유저 판단으로 PR #973 은 이대로 머지하고 증상만 기록한다. 확정하려면 양쪽 arm 을 각 20회 이상 돌려 실패율을 가른 뒤, 귀속이 서면 메커니즘을 규명하고 아니면 테스트를 결정적으로 고친다(구독 완료를 보장한 뒤 트리거).

- **재발 시 판별**: 이 TC 가 CI 에서 빨개지면 `Exceeded timeout of 2 seconds` 인지부터 본다. 그 문구면 이 레코드 건이고, 실행 개수가 들쭉날쭉한 크래시(`unrecognized selector` 류)면 CalendarScenes 스킴의 별도 플레이키다.
