---
issue: "#1003"
subdomain: Infra
symptoms: [플레이키, 전체 실행에서만 실패, Failing tests, confirmation 미달, fulfill 초과 호출, 방출 횟수 결합, 고정 sleep, 벽시계 타임아웃]
resolution: fixed
---

# 실측 플레이키 15건+런 중 편입 4건 — 타이밍 결합이 전체 실행 부하에서만 드러난다

- **증상**: 단독 실행은 전건 통과인데 전체 스킴 실행에서만 간헐 실패한다. 실패 이름이 회차마다 바뀌는 스킴(AICommand·CalendarScenes)도 있다.
- **근본 원인**: 다섯 갈래의 타이밍 결합이다.
  1. **공통 대기 헬퍼의 confirm 경합** — `PublisherWaitable.outputs`/`failure` 의 sink 가 `store.append` → `confirm()` 순서인데 대기 루프는 `store.count` 로 탈출해, 부하에서 confirmation 이 덜 선 채 판정이 반환됐다 (여러 스킴의 공통 뿌리).
  2. **고정 sleep·벽시계 창** — 10~50ms sleep 뒤 단언, `timeout: 0.1` 류 축소 타임아웃, 분리 `Task` 래핑이 부하에서 효과 도달보다 먼저 단언을 돌렸다.
  3. **방출 횟수·순서 결합** — `expectedFulfillmentCount`·배열 전체 비교가 부하에서 끼는 중복 방출·유실에 깨졌다. 콜백 1회 전제의 fulfill 은 초과 호출(API violation)로 터졌다.
  4. **도달 대기 데드라인 과소** — 부하에서 효과가 수 초 늦게 닿아 2~5초 도달 대기를 넘겼다. 도달 대기는 false pass 가 없어 데드라인을 10초로 올려 흡수했다 (PaywallViewModelImpleTests 의 waitUntil·waitScreenState, DayEventListViewModelImpleTests 의 라이브액티비티 해제 대기).
  5. **동시 send 의 CombineLatest 전달 역전** — 두 스레드가 거의 동시에 보낸 방출이 CombineLatest 체인(비직렬 removeDuplicates)을 지나며 전달 순서가 뒤집히고, 중복 판정도 어긋난다. 늦게 전달된 중간 상태가 그 구독의 마지막 값으로 남으면 최종 상태가 영영 안 온다 (Paywall 계열 미방출·순서 역전·초과 방출의 공통 뿌리 — 실패 시점 계측 `[userPlanLoadFailed, loading]` 으로 확정). 테스트 처방은 둘이다: 대기 헬퍼의 confirmation 을 정확 N 회에서 최소 N 회로(초과 방출 비위반), 최종 상태 단언은 기존 구독의 마지막 값 대신 subject 현재값을 리플레이하는 새 구독으로. **원천은 production 의 비직렬 CombineLatest 합성이라 이번 스코프(production 무변경) 밖이다** — 화면 동작엔 중간 상태가 잠깐 늦게 그려지는 수준이라 결함 보고 기준(관찰 가능한 결과)에 못 미치지만, 같은 서명이 재발하면 이 갈래를 먼저 본다.
- **해결**: #1003 브랜치 커밋 4개 — 헬퍼 confirm 선행·confirmation 최소 N 회 전환, Repository 취소·일시정지 경합 제거, Domain sleep·벽시계 결합 제거, Presentations 방출 결합 제거. 처방은 testability §9 (waitEffect 조건 폴링, "안 일어남"은 50ms 정착 후 확인, 단언은 최종 상태로). 해소 판정은 전 스킴 전체 실행 2회 연속 무재현.
  - **T-7 `AIAgentOrchestrationUsecaseImpleTests.usecase_permissionRestricted_doesNotNotifySpeechPermissionDenied` 는 미재현·무변경** — 코드상 실패 경로를 못 찾았고 이번 런(전체 실행 다수 회)에서도 재현되지 않았다. 재발하면 이 레코드의 처방 갈래 중 1·4 를 먼저 본다.
- **기각 방향**: 전체 1113건 일괄 전환 — 실측 없는 전면 수정은 회귀 위험 대비 효익이 없어 실측 건만 고쳤다 / 타임아웃 일괄 상향 — 결합을 둔 채 올리면 플레이키를 가린다 (도달 대기 데드라인 상향은 결합 제거 뒤에만 썼다)
