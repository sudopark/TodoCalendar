---
issue: "#991"
subdomain: Billing
symptoms: [PaywallViewModelImpleTests, Confirmation was confirmed, screenState 방출 개수, BillingScenes 간헐 실패, outputs 창]
resolution: deferred
---

# Paywall `screenState` 테스트가 방출 개수로 흔들린다

- **증상**: `BillingScenes` 의 `PaywallViewModelImpleTests` 중 `screenState` 를 관찰하는 테스트가 간헐 실패한다. 깨지는 테스트가 회차마다 바뀌고 방출이 모자라기도 넘치기도 한다.

  ```
  viewModel_retryAfterUserPlanLoadFailed_reentersLoadingBeforeFailingAgain
    Confirmation was confirmed 4 times, but expected to be confirmed 3 times
    Confirmation was confirmed 2 times, but expected to be confirmed 3 times
  viewModel_whenUserPlanLoadFails_screenStateIsUserPlanLoadFailed
    Confirmation was confirmed 3 times, but expected to be confirmed 2 times
  ```

- **귀속**: #990 브랜치 5회 중 2회, **develop 5회 중 1회**. 같은 테스트·같은 시그니처라 #990 의 회귀가 아니다.

- **근본 원인**: 미확정. 테스트가 `outputs(_:for:)` 창을 개수로만 끊는 게 직접 원인으로 보인다. `retryAfter...` 는 창을 두 번 여는데, 첫 창이 닫히는 시점에 첫 `prepare()` 의 로드가 아직 방출 중이면 잔여가 두 번째 창에 섞인다. 두 번째 구독이 CombineLatest 직전 정착 상태를 리플레이하는 타이밍도 얽혀 있다.

- **해결**: 보류. 확정된 방향은 개수 기반 창을 걷어내는 것 — 한 구독으로 두 `prepare()` 를 모두 관찰하거나, `screenState` 가 중간 상태를 몇 번 방출하는지를 계약으로 확정한다. 후속은 #991.

- **기각 방향**: 첫 창 뒤 100ms 정착 대기 — 실패 지점이 형제 테스트로 옮겨갈 뿐이라 해소로 볼 수 없다. 되돌렸다.

- **재발 시 판별**: `Confirmation was confirmed` (뒤에 붙는 숫자는 회차마다 다르다) 가 `PublisherWaitable.swift` 를 가리키면 이 건이다. `BillingScenes` 가 이 문구로 빨개지면 재실행하고, 계속 깨져도 브랜치 실패로 판정하지 않는다.
