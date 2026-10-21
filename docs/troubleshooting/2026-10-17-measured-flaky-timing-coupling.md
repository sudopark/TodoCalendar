---
issue: "#1003"
subdomain: Infra
symptoms: [플레이키, 전체 실행에서만 실패, Failing tests, confirmation 미달, fulfill 초과 호출, 방출 횟수 결합, 고정 sleep, 벽시계 타임아웃]
resolution: fixed
---

# 실측 플레이키 15건+런 중 편입 4건 — 타이밍 결합이 전체 실행 부하에서만 드러난다

- **증상**: 단독 실행은 전건 통과인데 전체 스킴 실행에서만 간헐 실패한다. 실패 이름이 회차마다 바뀌는 스킴(AICommand·CalendarScenes)도 있다.
- **근본 원인**: 네 갈래의 타이밍 결합이다.
  1. **공통 대기 헬퍼의 confirm 경합** — `PublisherWaitable.outputs`/`failure` 의 sink 가 `store.append` → `confirm()` 순서인데 대기 루프는 `store.count` 로 탈출해, 부하에서 confirmation 이 덜 선 채 판정이 반환됐다 (여러 스킴의 공통 뿌리).
  2. **고정 sleep·벽시계 창** — 10~50ms sleep 뒤 단언, `timeout: 0.1` 류 축소 타임아웃, 분리 `Task` 래핑이 부하에서 효과 도달보다 먼저 단언을 돌렸다.
  3. **방출 횟수·순서 결합** — `expectedFulfillmentCount`·배열 전체 비교가 부하에서 끼는 중복 방출·유실에 깨졌다. 콜백 1회 전제의 fulfill 은 초과 호출(API violation)로 터졌다.
  4. **서로 다른 스레드의 동시 send 가 기존 구독의 CombineLatest 조합값을 유실시킨다** — `PaywallViewModelImple.prepare` 의 async let 로드들은 각자 다른 스레드에서 조합 입력 subject 를 send 한다. 그러면 이미 걸린 구독은 최종 조합값(`.ready(.loaded)` 등)을 영영 못 받는다. 스텁 진입 플래그 계측으로 "로드는 전부 돌았는데 방출이 안 왔다" 를 확정했다 (`screenStateBecomesReady` 단독 12회 중 5회 재현). `MainViewModelImple.prepare` 도 같은 꼴이다 — 외형 설정 refresh Task 의 send 가 사용권 게이트 구독과 겹치면 게이트 검사가 안 일어난다 (CI 에서만 재현). 데드라인 상향은 이걸 가리는 마스킹이라 폐기했다. **production 코드는 바꾸지 않았다.** 테스트 처방은 둘이다: Paywall 은 정착 상태를 매번 새 구독이 리플레이하는 subject 현재값으로 폴링해 판정하고(`waitReplayedValue`), MainViewModel 게이트 테스트는 production 기동 순서대로 외형 설정을 먼저 실어 둔 뒤 `prepare()` 를 부른다 — refresh 의 send 는 같은 값이라 `removeDuplicates` 에서 걸러져 조합에 닿지 않는다.
- **해결**: #1003 브랜치 커밋 2개 — 테스트 결정화, 규명 레코드. 처방은 testability §9 (waitEffect 조건 폴링, "안 일어남"은 50ms 정착 후 확인, 단언은 최종 상태로). 해소 판정은 전 스킴 전체 실행 2회 연속 무재현이고, 4 갈래 재수정 뒤에는 Paywall 스위트 단독 30회·MainViewModel 게이트 테스트 부하 30회 무재현을 더했다.
  - **T-7 `AIAgentOrchestrationUsecaseImpleTests.usecase_permissionRestricted_doesNotNotifySpeechPermissionDenied` 는 미재현·무변경** — 코드상 실패 경로를 못 찾았고 이번 런(전체 실행 다수 회)에서도 재현되지 않았다. 재발하면 이 레코드의 처방 갈래 중 1·4 를 먼저 본다 (4 = 동시 send 의 CombineLatest 조합값 유실).
- **기각 방향**: 전체 1113건 일괄 전환 — 실측 없는 전면 수정은 회귀 위험 대비 효익이 없어 실측 건만 고쳤다 / 타임아웃 일괄 상향 — 결합을 둔 채 올리면 플레이키를 가린다 (도달 대기 데드라인 상향은 결합 제거 뒤에만 썼다)
