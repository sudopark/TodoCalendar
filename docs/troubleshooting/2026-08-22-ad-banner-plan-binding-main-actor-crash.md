---
issue: "#954"
subdomain: Billing
symptoms: [배너 광고 크래시, _swift_task_checkIsolatedSwift, dispatch_assert_queue_fail, bindLoadWhenFreePlanConfirmed, swift_task_isCurrentExecutorWithFlags, MainActor 격리 위반]
resolution: fixed
---

# 캘린더 하단 배너를 붙이자 플랜 구독 합성에서 격리 어서션 크래시

- **증상**: 캘린더 화면 진입 후 `AdBannerUIView.bindLoadWhenFreePlanConfirmed`의 클로저에서 `dispatch_assert_queue_fail` 크래시. 스택 상단이 `_swift_task_checkIsolatedSwift` → `swift_task_isCurrentExecutorWithFlags`. `AIAgentUsageUsecaseImple.loadUsage()`가 `SharedDataStore.put`으로 `billingUserPlan` 키를 채우는 시점이 트리거.

- **근본 원인**: `AdBannerUIView`는 UIView라 `@MainActor` 격리 타입이고 그 메서드 안의 `.map` 클로저도 격리를 물려받는다. 그런데 `.receive(on: RunLoop.main)`이 `.map` **뒤에** 있어서 map은 upstream 방출 스레드에서 돌았다. upstream인 `SharedDataStore.observe`는 `serial-sharedDataStore-event` 백그라운드 큐로 방출하므로 Swift 6 런타임 격리 체크가 트랩했다. #898·#956이 만든 잠복 결함으로, #954가 첫 프로덕션 소비처를 붙이면서 드러났다.

- **해결**: `.receive(on: RunLoop.main)`을 `CombineLatest` 직후·`.map` 앞으로 옮겼다. map·removeDuplicates·sink·apply가 전부 메인에서 돈다.

- **기각 방향**: map 클로저를 `nonisolated`로 분리 — 체인에 연산자가 하나 더 붙으면 같은 함정이 재발해 자리마다 심어야 유지되는 증상 패치다. / `SharedDataStore.observe`를 메인 방출로 변경 — 전 도메인 소비자에 영향이 가는데 원인은 한 소비처의 훅 위치다.
