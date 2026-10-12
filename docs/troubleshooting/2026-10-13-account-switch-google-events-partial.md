---
issue: "#1277"
subdomain: ExternalCalendar
symptoms: [로그아웃 구글 이벤트 소실, 로그아웃 후 구글 이벤트 일부만, clearAll 공유 저장소 비움, googleCalendarEvents 재적재, syncEnd 복구 없음, cancelRefresh 범위 취소, refreshEventBag cancelAll]
resolution: fixed
---

# 로그아웃 뒤 구글 캘린더 이벤트가 사라지고 일부만 다시 보인다

- **증상**: 로그아웃하면 캘린더 화면의 구글 캘린더 이벤트가 전부 사라지고, 그 뒤 일부만 다시 나타난다. 로그인 방향에서는 나지 않는다 (유저 확인, 2026-10-13).
- **근본 원인**: 두 층이 겹쳤다.
  1. **비우는 쪽** — 계정 전환이 `ApplicationPrepareUsecase.prepareSignedIn`·`prepareSignedOut` 에서 `SharedDataStore.clearAll` 을 불러 `googleCalendarEvents`·`googleCalendarTags`·`googleCalendarColors`·`offEventTagSet` 을 비운다.
  2. **다시 채우는 쪽** — `GoogleCalendarUsecaseImple.refreshEvents(in:)` 가 첫 줄에서 `refreshEventBag.cancelAll()` 로 **모든 범위**의 진행 중 조회를 끊었다. 범위마다 들어오는 요청은 서로 덧붙는 것인데 마지막 요청만 살아남는다. `CalendarViewModel.refreshEvents(_ ranges:)` 가 범위를 하나씩 넘기므로, 범위가 둘 이상이거나 방출이 잇달으면 앞 범위의 조회가 응답을 받기 전에 죽고 그 범위의 이벤트는 영영 안 들어온다.

  로그인 방향에만 증상이 없는 이유는 덮는 쪽이 있기 때문이다 — `EventSyncUsecaseImple` 의 `syncEnd` 가 `checkedRange` 전체를 한 범위로 다시 요청해 빈 구간을 메운다. 로그아웃 방향은 `NotNeedEventSyncUsecase` 라 그 방출이 없다.

  활성 캘린더 방출은 `SharedDataStore.observe` 의 직렬 큐를 타고 비동기로 온다. 그래서 `cancelAll()` 과 조회 구독 보관이 엇갈리면 취소가 빗나가기도 해, 어느 범위가 살아남는지가 타이밍에 따라 갈린다 — "일부만 보인다" 가 회차마다 달라지는 까닭이다.
- **해결**: `CancelBag` 에 키별 보관·취소(`store(in:forKey:)`·`cancelAll(forKey:)`)를 더하고, `refreshEvents(in:)` 가 같은 범위의 앞선 요청만 끊게 했다. 같은 모양이던 `AppleCalendarUsecaseImple.refreshEvents(in:)` 도 함께 고쳤다. 회귀 테스트는 두 유즈케이스 테스트의 `refreshEvents_whenNextPeriodRequestedBeforeLoadArrives_keepsBothPeriods` 이고, 조회 지연을 주입해 앞 범위의 응답이 오기 전에 다음 범위를 요청하는 순서를 재현한다.
- **기각 방향**: 로그아웃 시 구글 토큰을 못 읽어 원격 로드가 실패한다 — 토큰과 계정 목록은 KeyChain 에 있고(`ExternalCalendarIntegrateRepositoryImple.swift:40-58`) `ExternalCalendarAccountRemotePool` 은 `ApplicationBase` 가 앱 수명으로 쥐어서, 로그아웃이 둘 중 어느 것도 지우지 않는다.
- **기각 방향**: `refreshEvents(_:accountId:in:)` 의 범위 재조정이 다른 범위의 캐시를 걷어낸다 — 재조정은 같은 `calendarId` 의 범위 내 캐시만 대상으로 삼아 다른 범위를 건드리지 않는다.
- **기각 방향**: 캐시 방출을 최종 목록으로 써서 원격 응답을 덮는다 / 지역 DB 갱신이 트랜잭션이 아니라 중간 상태가 보인다 / 해제된 옛 scene 이 전역 키에 쓴다 — 셋 다 재현 과정에서 취소 기전으로 수렴해 추적하지 않았다.
