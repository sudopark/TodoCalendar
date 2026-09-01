# 과금 상세 스펙

플랜 구독과 크레딧 top-up을 StoreKit 2로 구매하고, 서명된 트랜잭션을 서버가 검증해 플랜에 반영하는 경로.

서버가 믿는 값은 **서명 payload 안의 것뿐**이다. 앱이 판단한 productId는 올리지 않는다.

AI 사용 한도가 여기서 나오지만 방향은 단방향이다 — **Billing은 AI를 모른다.** 위젯 Pro도 같은 인프라를 쓸 예정이라 Billing은 AI 하위가 아닌 독립 context다.

---

## 1. 플랜

```swift
enum BillingPlanId: String {
    case free, standard, lifetime
}
```

등급은 `free(0) < standard(1) < lifetime(2)`. `covers(_:)`는 **등급 커버 판정**이지 일치 판정이 아니다 — lifetime은 standard를 covers 한다. 특정 플랜인지 물어야 하는 자리에서 `covers`를 쓰면 상위 플랜이 잘못 걸린다.

### `BillingPlan` — 카탈로그 항목 (`GET /v1/billing/plans`)

| 필드 | 설명 |
|---|---|
| `id` | 플랜 식별자 |
| `dailyLimit` | 일일 AI 크레딧 한도 |
| `productId` | App Store 상품 id. **free는 상품이 없어 nil** |
| `isTopupAllowed` | 이 플랜에서 top-up 구매 가능 여부 |

**가격은 없다.** 현지화 가격은 StoreKit이 답한다. `BillingPlanOffering = BillingPlan + BillingProduct?` 로 합쳐 화면에 내린다. 스토어 조회가 실패해도 카탈로그 전체를 잃지 않는다 — 가격만 비는 편이 낫다.

### `BillingUserPlan` — 현재 발효 플랜

`GET /v1/billing/plans`가 아니라 **`GET /v1/ai/usage`의 plan 필드**와 **`POST /v1/billing/purchases` 응답**이 같은 스키마로 내려준다.

| 필드 | 설명 |
|---|---|
| `planId` | 앱이 모르는 플랜 id면 `nil`. 신규 플랜이 서버에 먼저 배포돼도 나머지 필드는 살린다 |
| `scheduledChange` | 하향 예약 — `planId` + `effectiveAt`. 다음 차수부터 적용 |
| `topupRemaining` | 남은 top-up 크레딧 |

### `BillingTopup` — 크레딧 충전 (`GET /v1/billing/topups`)

`productId` + `credits` + `bonusRate`. 표시용 총량 `totalCredits = round(credits × (1 + bonusRate))` — 서버가 보너스를 반영해 적립하므로 표시도 같은 식으로 계산한다.

---

## 2. 구매 플로우

```
purchase(productId)
  │
  ├─ appAccountToken 확보 ──(없으면)──▶ GET /v1/billing/user-plan ──(그래도 없으면)──▶ throw
  │                                                                         (결제창 안 띄움)
  ▼
StoreKit purchase
  │
  ├─ .cancelled ──▶ BillingPurchaseResult.cancelled
  ├─ .pending   ──▶ .pending          (Ask to Buy 승인 대기)
  └─ .verified(transaction)
        │
        ▼
   POST /v1/billing/purchases  { signedTransaction: jws }
        │
        ├─ 실패 ──▶ BillingReflectFailure 로 감싸 throw   (finish 안 함 → 영수증 보존)
        └─ 성공 ──▶ finishTransaction ──▶ SharedDataStore 갱신 ──▶ .applied(userPlan)
```

두 가지가 순서에 걸려 있다.

- **`appAccountToken`은 결제 전에 확보한다.** 토큰 없이 산 트랜잭션은 주인을 표시할 값이 없어 서버가 거절한다. 청구부터 하고 실패를 알리느니 결제창을 안 띄운다.
- **`finish`는 서버 반영이 성공한 뒤에만 부른다.** 먼저 부르면 실패 시 영수증이 사라져 복구 불가다.

유저 취소와 승인 대기(Ask to Buy)는 **에러가 아니다.** `BillingPurchaseResult`로 결과를 구분해 반환한다.

### `appAccountToken` 캐시

`SharedDataStore`의 `billingAppAccountToken` 키에 보관한다. 계정 전환 시 이전 유저의 토큰이 남으면 남의 구매를 자기 것으로 주장하게 되므로, **값이 없는 응답에는 캐시를 지운다.**

---

## 3. 복원과 미완료 트랜잭션

| 경로 | 엔드포인트 | 트리거 |
|---|---|---|
| 구매 | `POST /v1/billing/purchases` | 사용자의 직접 구매 |
| 위임 반영 | `POST /v1/billing/transactions` | 복원·앱 밖 갱신·환불·가족 공유·승인 대기 통과 |

- `restorePurchases()` → `.applied(plan)` / `.nothingToRestore` / `.cancelled`
- `startObservingTransactions()` — `Transaction.updates` 스트림. 앱 밖에서 일어난 변화가 들어오는 **유일한 경로**다.
- `recoverUnfinishedTransactions()` — 미완료 트랜잭션을 다시 태운다. unfinished는 OS 전역이라 두 시도가 겹치면 같은 트랜잭션을 중복 전송하므로, 이전 복구 task를 취소하고 시작한다.

### 여러 건 반영은 fail-fast 하지 않는다

`applyEach`는 한 건이 영구 실패해도 나머지를 계속 반영하고, 첫 실패만 모아서 던진다. fail-fast면 앞의 실패가 매 시도마다 뒤 트랜잭션을 가려 영영 반영되지 않는다.

### 라이프사이클 배선 (`MainViewModelImple`)

| 시점 | 동작 |
|---|---|
| `prepare()` | `startObservingTransactions()` + `recoverUnfinishedTransactions()` |
| 포그라운드 복귀 | `recoverUnfinishedTransactions()` |

---

## 4. 플랜 전파

플랜은 `SharedDataStore`의 `billingUserPlan` 키 하나가 정본이다.

| 접근 | 용도 |
|---|---|
| `currentUserPlan` (Publisher) | 구독 가능한 자리 — 배너 노출 판정 등 |
| `latestUserPlan()` | 구독을 걸 수 없는 순간에 즉시 판정해야 하는 호출부. 같은 값을 본다 |
| `refreshUserPlan()` | paywall 진입 등에서 재확인. 성공하면 store에 반영돼 구독자에게 흐른다. 실패는 호출측이 처리 (`throws`) |

플랜 정보를 얻는 자리가 셋(플랜 카탈로그 / AI usage 응답 / 구매 응답)이라 어디서 온 값인지 헷갈리기 쉽다. **화면이 믿을 것은 `currentUserPlan` 하나**다.

---

## 5. Paywall 화면 (`BillingScenes`)

### 화면 상태

```swift
enum PaywallScreenState {
    case loading
    case userPlanLoadFailed          // 현재 플랜을 못 읽으면 카탈로그를 보여주지 않는다
    case ready(PaywallCatalogState)  // .loading / .failed / .loaded([BillingPlanOffering])
}
```

현재 플랜 조회가 먼저다. 내 플랜을 모르는 채 상품 목록을 띄우면 이미 산 플랜을 다시 팔게 된다.

### 액션

`selectPlan` · `purchase` · `purchaseTopup` · `restore` · `recoverUnfinished` · `manageSubscription` · `openTerms` · `openPrivacyPolicy`

### 실패 사유 (`PaywallFailReason`)

서버 에러 코드를 화면 문구로 접는다. 요청 취소(`cancelled`)는 **알릴 게 없어 `nil`** 로 초기화가 실패한다.

| 사유 | 서버 코드 |
|---|---|
| `invalidTransaction` | `invalidTransaction` |
| `unknownProduct` | `unknownProduct` |
| `planChangeNotAllowed` | `planChangeNotAllowed` |
| `ownedByAnotherAccount` | `transactionOwnedByAnotherAccount` |
| `reflectDelayed` | 그 외 반영 실패 |
| `purchaseFailed` | 반영 단계 이전(StoreKit 단계)의 실패 |

`BillingReflectFailure`로 감싸졌는지가 "결제는 됐는데 반영이 안 된 것"과 "결제 자체가 안 된 것"을 가른다.

### 진입점

| 위치 | `closesAfterPurchase` | 맥락 |
|---|---|---|
| 설정 > 플랜 (`SettingItemListRouter.routeToPaywall`) | `false` | 사용자가 플랜을 보러 들어옴 — 구매 후에도 화면 유지 |
| AI 크레딧 소진 (`CalendarViewRouter.routeToPaywall`) | `true` | 하던 일이 막혀서 들어옴 — 구매하면 닫고 돌아감 |

### 고지 문구

구독 화면의 법적 고지(기간·자동 갱신·해지 경로·약관/개인정보처리방침 링크)는 **축약하면 심사에서 리젝된다.** 문구를 줄이지 말 것.

구독 관리는 `AppStoreSubscriptionSheet`(`showManageSubscriptions(in:)`)로 연다.

---

## 6. 광고 노출 판정

무료 플랜에만 광고를 노출한다. Google Mobile Ads(`AdService`).

### 배너

```
isBannerAdAllowed = adAvailability.isStarted && userPlan.planId == .free
```

`covers`가 아니라 **`== .free` 일치 판정**이다. 유료 전환 시 배너가 차지하던 하단 자리까지 걷는다.

### 전면 광고 (`canExposeFullScreenAd`)

| 조건 | 값 |
|---|---|
| 플랜 | `.free` 여야 함 |
| 같은 scope 오늘 노출 이력 | 없어야 함 |
| (앱 시작 트리거일 때만) 오늘 첫 콜드런치 | 이어야 함 |
| (앱 시작 트리거일 때만) 누적 콜드런치 | 10회 이상 |
| (앱 시작 트리거일 때만) 첫 실행 후 경과일 | 7일 이상 |

`scope`는 `.application`(앱 시작)과 `.service(identifier:)`(기능 진입)로 나뉘고, 노출 이력은 scope별로 하루 한 번을 센다.

설정의 `adPrivacyOptions` 항목에서 광고 개인정보 옵션을 다시 열 수 있다.

---

## 7. API 엔드포인트

베이스: `{calendarAPIHost}/v1/billing`

| 메서드 | 경로 | 용도 |
|---|---|---|
| GET | `/plans` | 플랜 카탈로그 |
| GET | `/topups` | top-up 카탈로그 |
| POST | `/purchases` | 직접 구매 반영 |
| POST | `/transactions` | 복원·앱 밖 갱신 반영 |
| GET | `/user-plan` | 현재 플랜 + `appAccountToken` |

---

## 관련 파일

| 파일 | 역할 |
|---|---|
| `Domain/Sources/Models/Billing/` | 플랜·top-up·구매 결과·반영 실패 모델 |
| `Domain/Sources/Usecases/Billing/BillingUsecase.swift` | 카탈로그·구매·복원·트랜잭션 관찰 |
| `Domain/Sources/Usecases/Billing/NotNeedBillingUsecase.swift` | 과금이 필요 없는 조립에서 쓰는 no-op 구현 |
| `Services/StoreKitService/` | StoreKit 2 구매·구독 관리 시트 |
| `Presentations/BillingScenes/Sources/Paywall/` | paywall 화면 |
| `Domain/Sources/Usecases/Ad/AdExposureUsecase.swift` | 광고 노출 판정 |
| `Services/AdService/` | Google Mobile Ads 구현체 |
