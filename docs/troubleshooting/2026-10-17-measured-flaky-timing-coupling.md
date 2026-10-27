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
  3. **방출 횟수를 시나리오가 보장하지 못했다** — 정확 N회 단언 자체는 맞다. 깨진 자리는 시나리오가 그 횟수를 보장하지 못한 곳이다. 로딩 중인 상태를 구독 한 번에 1회로 반복 조회하거나, 즉시 끝나는 stub 으로 "진행 중 연타" 를 흉내 냈다. 콜백 1회 전제의 fulfill 은 초과 호출(API violation)로 터졌다. 초과 방출이 production 결함인 자리도 있었다 — `ForemostEventUsecaseImple` 은 강조 id 를 본문보다 먼저 저장해, 저장소 큐에서 id 가 먼저 닿으면 본문 조회가 일시적으로 nil 을 방출했다(`[nil, nil, id]`). 본문 조회에 중복 제거가 없어 다른 todo 가 바뀌어도 같은 강조 이벤트를 다시 방출했다.
  4. **서로 다른 스레드의 동시 send 가 CombineLatest 하류를 동시에 불러 조합값 순서를 뒤집는다 (production 결함)** — `PaywallViewModelImple.prepare` 의 async let 로드들은 각자 다른 스레드에서 조합 입력 subject 를 send 한다. CombineLatest 는 합친 값을 들어온 스레드에서 그대로 내려보내, `map`·`removeDuplicates` 가 동시에 불리고 마지막 수신값이 중간 상태로 굳는다. 화면은 로딩에 멈춘다. 스텁 진입 플래그 계측으로 "로드는 전부 돌았는데 최종값이 안 왔다" 를 확정했다 (`screenStateBecomesReady` 단독 12회 중 5회 재현, 수신 순서 역전 `[userPlanLoadFailed, loading]` 관측). `MainViewModelImple.bindColorThemeLicenseGate` 도 같은 꼴이다. `AddEventViewModelImple.prepare` 는 준비 결과를 백그라운드에서 send 하고 입력은 main 에서 send 해, `isSavable` 이 마지막에 엉뚱한 값으로 굳었다(`[false, true, false, true]`).
- **해결**: #1003 브랜치. 처방은 testability §9 (waitEffect 조건 폴링, "안 일어남"은 50ms 정착 후 확인, "정확히 N회"는 그대로 단언). 갈래별로는 아래와 같다.
  - 1 — confirm 을 저장보다 먼저 센다. 기대치는 정확 N회 그대로다.
  - 3 — 시나리오를 고친다. 로딩 대기는 prepare 전에 한 번 구독해 정확 횟수(`[]` → 셀)로 받는다. 연타 테스트는 stub 이 처리를 붙잡아 두 번째 탭이 진행 중에 들어오게 한다. `ForemostEventUsecaseImple` 은 본문을 id 보다 먼저 저장하고, 본문 조회에 `removeDuplicates` 를 건다 (적용 전 10회 중 1회 실패, 적용 후 40회 무재현).
  - 4 — production 에서 조합 입력을 main 으로 직렬화한다 (`receive(on:)`). AddEvent 는 준비 결과를 main 에서 받는다. 적용 전 Paywall 스위트 10회 중 2회 실패하던 것이 적용 후 20회 무재현이 됐다.
  - **T-7 `AIAgentOrchestrationUsecaseImpleTests.usecase_permissionRestricted_doesNotNotifySpeechPermissionDenied` 는 미재현·무변경** — 코드상 실패 경로를 못 찾았고 이번 런(전체 실행 다수 회)에서도 재현되지 않았다. 재발하면 이 레코드의 처방 갈래 중 1·4 를 먼저 본다 (4 = 동시 send 의 CombineLatest 조합값 유실).
- **기각 방향**: 방출 횟수 단언을 최소 N회·마지막 값으로 완화 — 초과 방출은 결함이나 과한 시나리오의 신호라, 풀면 그 신호를 지운다 / 정착 판정을 새 구독의 subject 현재값 리플레이로 대체 — 화면이 쓰는 기존 구독의 유실을 못 잡는다 / 전체 1113건 일괄 전환 — 실측 없는 전면 수정은 회귀 위험 대비 효익이 없어 실측 건만 고쳤다 / 타임아웃 일괄 상향 — 결합을 둔 채 올리면 플레이키를 가린다 (도달 대기 데드라인 상향은 결합 제거 뒤에만 썼다)
