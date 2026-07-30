# StoreKitService Framework

**앱에서 `import StoreKit` 하는 유일한 타겟.** Domain 의 `AppStoreBillingService` 프로토콜을 StoreKit 2 로 구현한다.

```
TodoCalendarApp → Domain ← StoreKitService
                        ← Repository
```

**Repository 에 의존하지 않는다.** 서버 통신은 `BillingRepositoryImple`(Repository) 소관이고, 이 프레임워크는 애플 쪽만 안다. 두 갈래를 잇는 순서 책임은 `BillingUsecase`(Domain)가 진다.

`Services/*` 의 다른 service 프레임워크와 같은 규칙을 따른다 (#639, 분할 축·표준 의존 세트는 add-framework 스킬 §1). 이 프레임워크에만 해당하는 판단은 둘이다.

**테스트 타겟을 두지 않는다.** 실 StoreKit 샌드박스가 있어야만 의미 있는 검증이라 유닛 테스트 가치가 없다. 대신 **Domain 쪽 스텁으로 계약을 검증한다** — `StubAppStoreBillingService` + `BillingUsecaseImpleTests`. 어댑터를 SDK 호출 변환만 남을 만큼 얇게 유지하는 게 이 선택의 전제다. 로직이 붙기 시작하면 그 로직은 Domain 으로 올려야 한다.

**그래서 테스트 스킴도 없다.** `ALL_SCHEMES`·`run-all-tests.sh`·`run-tests` 스킬의 스킴 목록에 넣지 않는다. 대신 **경로→스킴 매핑에는 넣어** 변경이 앱 빌드를 트리거하게 한다 (`impact-check.sh`·`pr_test.yml` 의 테스트 없는 Services 묶음 alternation). 안 넣으면 이 프레임워크를 깨뜨려도 CI 가 아무것도 안 돈다.

**프로토콜은 Domain 에, 구현체만 여기.** 프로토콜 시그니처에 StoreKit 타입이 새어나오면 안 된다 — 경계 타입(`BillingProduct`·`BillingSignedTransaction`·`BillingTransactionOutcome`)으로 감싼다. 지켜졌는지는 **Domain 파일의 import 목록으로 검증된다** (`AppStoreBillingService.swift` 는 `import Foundation` 뿐).

---

## StoreKit 2 구현에서 지켜야 하는 것

`AppStoreBillingServiceImple` 이 이미 지키고 있고, 고칠 때 깨뜨리면 안 되는 불변식:

- **`.unverified` 는 절대 밖으로 내보내지 않는다.** 구매·복원·미완료복구·updates 네 경로가 전부 `verifiedTransaction(_:)` 을 통과한다. 서명이 깨진 트랜잭션이 서버로 올라가면 안 된다.
- **`verifiedTransaction(_:)` 은 타입 멤버가 아니라 파일 스코프 함수다.** `init` 의 리스너 Task 는 self 초기화 전이라 인스턴스 메서드를 못 부른다. static 메서드로 되돌리지 말 것 — 상태 없는 순수 변환이라 파일 스코프가 맞다.
- **`transactionUpdates` 는 `init` 에서 1회만 만든다.** computed property 로 두면 접근할 때마다 새 리스너가 생겨 같은 트랜잭션이 이중 post 된다.
- **리스너 Task 는 서비스가 소유하고 `deinit` 에서 취소한다.** `continuation.onTermination` 에 취소를 맡기면 순환이 닫히는데, `Transaction.updates` 는 끝나지 않아 소비자가 스트림을 취소하기 전엔 안 풀린다.
- **`finishTransaction` 은 서버 반영이 끝난 뒤에만 불린다** (호출 순서는 `BillingUsecase` 가 소유). 이 프레임워크는 그 계약을 깨는 자체 finish 를 하지 않는다.

## 알아둘 것

- **소모품(top-up)은 `Transaction.currentEntitlements` 에 안 잡힌다** — 애플이 보유 상태를 들고 있지 않다. 잔량 원장의 진실은 서버뿐이고, 여기서 잔량을 계산하지 않는다.
- **`.storekit` Configuration File 은 아직 없다.** 로컬 결제 시뮬레이션은 스킴 Run 액션 설정이라 파일만 추가해선 동작하지 않고, Tuist 가 스킴을 자동 생성하므로 Xcode UI 수동 지정은 `tuist generate` 에 덮인다. 구매 트리거 UI 가 생기는 Phase B 에서 커스텀 스킴과 함께 배선한다.
