---
issue: "#990"
subdomain: Infra
symptoms: [unrecognized selector sent to instance 0x8000000000000000, member:, NSInvalidArgumentException, CalendarScenes 랜덤 크래시, Set AnyCancellable 동시 변이]
resolution: fixed
---

# 백그라운드 Task 에서 구독을 담다 Set 저장소가 깨진다

- **증상**: `CalendarScenes` 를 통째로 돌리면 랜덤한 테스트에서 프로세스가 죽는다 (3회 중 2회). `TodoCalendarApp` 도 매 회 죽었다. `Executed N tests, with 0 failures` 인데 `exit 65` 이고 실행 개수가 매번 다르다.

  ```
  -[__NSTaggedDate member:]: unrecognized selector sent to instance 0x8000000000000000
  -[NSTaggedPointerString member:]: unrecognized selector sent to instance 0x8000000000000000
  ```

  **수신 클래스가 런마다 바뀌는데 주소는 같다.** 태그드 포인터 난독화가 프로세스마다 달라서 그런 것이고, 같은 쓰레기 포인터를 읽고 있다는 뜻이다 — 로직 버그가 아니라 메모리 손상 신호다.

- **근본 원인**: 뷰모델·유스케이스가 `@unchecked Sendable` 인데 구독을 `Set<AnyCancellable>` 프로퍼티에 담는다. `Task` 본문 안에서 그 Set 을 변이하는 자리가 네 곳 있어, 메인 스레드의 `store(in:)` 과 겹치면 Set 저장소가 깨진다. 크래시 지점은 `viewModel.prepare()` 였고, 그 안에서 `Task { ... self?.bindRefreshHoliday() }` 가 백그라운드에서 같은 Set 을 건드렸다.

  | 위치 | 경로 |
  |---|---|
  | `CalendarViewModelImple.prepare` | `bindRefreshHoliday()` |
  | `EventListCellEventHanleViewModelImple` | `confirmAndRemoveEvent()` |
  | `ApplicationRootViewModelImple.prepareInitialScene` | `registerTokenIfNeed()` |
  | `ApplicationRootViewModelImple.handleUserSignedIn` | `registerTokenIfNeed()` |

- **해결**: `Extensions` 에 잠금으로 보호되는 `CancelBag` 을 두고 프로덕션 보관함을 전부 교체 (선언 138곳·호출 392곳). 담을 그릇 자체를 스레드 안전하게 만들어 네 곳을 개별로 고치는 대신 이 부류 자체를 없앴다.

- **기각 방향**: 네 곳만 MainActor 로 홉시킨다 — 새로 `Task { self.bindX() }` 를 쓰는 순간 재발한다. 잡을 자리가 계속 늘어난다.

- **재발 시 판별**: `member:` unrecognized selector 나 `0x8000000000000000` 이 보이면 Set 저장소 손상이다. 새 코드가 `Set<AnyCancellable>` 을 직접 두고 있지 않은지 본다 — 프로덕션은 `CancelBag` 만 쓴다.
