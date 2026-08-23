---
issue: "#990"
subdomain: Event
symptoms: [라이브액티비티 placeName nil, memo nil, EventLiveActivityUsecaseImpleTests 간헐 실패, Publishers.Timeout, DispatchQueue.global, 동기 방출 유실]
resolution: fixed
---

# `.timeout` 이 concurrent 큐에서 동기 방출값을 흘린다

- **증상**: `EventLiveActivityUsecaseImpleTests` 의 "상세에서 place·memo 를 채운다" 계열 4개가 전체 실행에서 간헐 실패한다. 상세가 통째로 안 들어온다.

  ```
  Expectation failed: (content.placeName → nil) == "회의실 A"
  Expectation failed: (content.placeName → nil) == "3층 라운지"
  Expectation failed: (content.memo → nil) == "준비물"
  ```

  전체 스킴 6회 중 4회, 스위트 단독 5회 중 2회. **단일 테스트 단독 실행은 10회 전부 통과** 한다.

- **근본 원인**: `EventLiveActivityUsecaseImple.eventDetail(for:)` 이 `.timeout(.seconds(1), scheduler: DispatchQueue.global())` 을 탄다. `Publishers.Timeout` 은 **concurrent 큐**를 스케줄러로 받으면 구독 즉시 도착한 값을 흘린다.

  측정 (`Just(1)` 기준, 시뮬레이터에서 5000회):

  | 구성 | 유실 |
  |---|---|
  | `.timeout(30s, DispatchQueue.global()) → .values.first` | 389 / 5000 |
  | `.timeout(30s, DispatchQueue.global()) → .first().sink` | 1046 / 5000 |
  | `.timeout(30s, DispatchQueue(label:)) → .values.first` | 0 / 5000 |
  | `.timeout(30s, DispatchQueue.main) → .values.first` | 0 / 5000 |
  | `.timeout(30s, RunLoop.main) → .values.first` | 0 / 2000 |
  | timeout 없이 `.values.first` | 0 / 5000 |

  소비 방식(`values` vs `sink`)과 무관하고 스케줄러 종류만 가른다. 타임아웃 값과도 무관하다 — 30초로 늘려도 유실률이 그대로다.

- **해결**: 타임아웃 스케줄러를 `DispatchQueue.main` 으로 교체. `AICommandUsecase.notFinishJobTimeout` 이 이미 쓰던 것과 같은 스케줄러라 코드베이스 안에서 일관된다. 프로덕션 결함이기도 하다 — 상세가 캐시에서 즉시 오면 그 확률로 라이브액티비티가 place·memo 없이 등록된다.

- **기각 방향**:
  - 병렬 부하로 1초 타임아웃을 넘긴다 — 타임아웃을 30초로 주입해도 유실률이 안 변해 기각. 1초 블로킹 테스트의 소요 시간도 매 회차 1.002초로 일정해 풀 포화 근거가 없었다
  - `@Suite(.serialized)` 로 병렬을 줄인다 — 동시 실행 깊이를 4에서 3으로 낮췄을 뿐 실패가 계속됐다
  - `.values` 브리지의 demand 레이스 — 단독 실행 10/10 통과로 한 번 기각했다가, timeout 을 뺀 구성이 0/5000 인 것으로 `.timeout` 쪽이 원인임이 확정됐다

- **재발 시 판별**: `.timeout(_:scheduler:)` 에 넘기는 스케줄러가 concurrent 큐면 의심한다. 프로덕션에서 `DispatchQueue.global()` 을 쓰던 자리는 여기 하나였고, `AICommandUsecase.notFinishJobTimeout` 은 `DispatchQueue.main` 이라 무관하다.
