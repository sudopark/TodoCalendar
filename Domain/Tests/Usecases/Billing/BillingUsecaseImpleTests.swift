//
//  BillingUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 7/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Prelude
import Optics
import Extensions
import UnitTestHelpKit

@testable import Domain


final class BillingUsecaseImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = .init()

    private func makeUsecase(
        shouldCancelPurchase: Bool = false,
        shouldCancelRestore: Bool = false,
        shouldPurchaseBePending: Bool = false,
        shouldFailPurchase: Bool = false,
        shouldFailApply: Bool = false,
        shouldFailLoadProducts: Bool = false,
        shouldFailLoadUserPlan: Bool = false,
        unfinished: [BillingSignedTransaction] = [],
        restored: [BillingSignedTransaction]? = nil,
        failingJWSTokens: Set<String> = [],
        appAccountToken: UUID? = UUID(uuidString: "8f14e45f-ceea-467a-9c8f-1b3a2e5d7c04")
    ) -> (BillingUsecaseImple, StubBillingRepository, StubAppStoreBillingService) {
        let repository = StubBillingRepository(
            shouldFailPurchase: shouldFailApply,
            failingJWSTokens: failingJWSTokens,
            shouldFailLoadUserPlan: shouldFailLoadUserPlan,
            appAccountToken: appAccountToken
        )
        let service = StubAppStoreBillingService(
            shouldCancelPurchase: shouldCancelPurchase,
            shouldCancelRestore: shouldCancelRestore,
            shouldPurchaseBePending: shouldPurchaseBePending,
            shouldFailPurchase: shouldFailPurchase,
            shouldFailLoadProducts: shouldFailLoadProducts,
            unfinished: unfinished,
            restored: restored
        )
        let usecase = BillingUsecaseImple(
            repository: repository,
            appStoreService: service,
            sharedDataStore: SharedDataStore()
        )
        return (usecase, repository, service)
    }

}


// MARK: - 카탈로그 + 스토어 가격 결합

extension BillingUsecaseImpleTests {

    @Test func usecase_loadPlanOfferings_combinesCatalogWithStorePrice() async throws {
        // given
        let (usecase, _, _) = self.makeUsecase()
        // when
        let offerings = try await usecase.loadPlanOfferings()
        // then
        #expect(offerings.map { $0.plan.id } == [.free, .standard])
        // free 는 상품이 없어 가격도 없다
        #expect(offerings.first?.product == nil)
        #expect(offerings.last?.product?.displayPrice == "$0.49")
    }

    // 스토어 조회 실패로 카탈로그 전체를 잃지 않는다 — 가격만 비는 편이 낫다
    @Test func usecase_loadPlanOfferings_whenStoreFails_keepsCatalogWithoutPrice() async throws {
        // given
        let (usecase, _, _) = self.makeUsecase(shouldFailLoadProducts: true)
        // when
        let offerings = try await usecase.loadPlanOfferings()
        // then
        #expect(offerings.count == 2)
        #expect(offerings.allSatisfy { $0.product == nil })
    }

    @Test func usecase_loadTopupOfferings_combinesCatalogWithStorePrice() async throws {
        // given
        let (usecase, _, _) = self.makeUsecase()
        // when
        let offerings = try await usecase.loadTopupOfferings()
        // then
        #expect(offerings.map { $0.topup.productId } == ["topup.tier.1"])
        #expect(offerings.first?.product?.displayPrice == "$0.49")
    }
}


// MARK: - 구매

extension BillingUsecaseImpleTests {

    @Test func usecase_purchase_uploadsJWSAndReturnsAppliedPlan() async throws {
        // given
        let (usecase, repository, _) = self.makeUsecase()
        // when
        let result = try await usecase.purchase(productId: "plan.standard.monthly")
        // then
        #expect(repository.didPostedSignedTransactions == ["jws:plan.standard.monthly"])
        guard case .applied(let plan) = result else {
            Issue.record("applied 결과가 아님")
            return
        }
        #expect(plan.planId == .standard)
        #expect(plan.topupRemaining == 12300)
    }

    // 이 값이 애플 서명 payload 에 실려야 서버가 구매의 주인을 가릴 수 있다.
    // 안 실으면 서버가 409 TransactionOwnedByAnotherAccount 로 거절한다 (Functions#323)
    @Test func usecase_purchase_sendsAppAccountTokenToStore() async throws {
        // given
        let token = UUID(uuidString: "8f14e45f-ceea-467a-9c8f-1b3a2e5d7c04")
        let (usecase, _, service) = self.makeUsecase(
            appAccountToken: token
        )
        // when
        _ = try await usecase.purchase(productId: "plan.standard.monthly")
        // then
        #expect(service.didPurchasedWithAppAccountToken == token)
    }

    // paywall 을 거치지 않은 진입점에서도 구매가 성립해야 한다 — 캐시가 비어 있으면
    // 결제창을 띄우기 전에 서버에서 확보한다
    @Test func usecase_purchase_whenTokenNotCached_securesFromServer() async throws {
        // given
        let (usecase, repository, service) = self.makeUsecase()
        // when
        _ = try await usecase.purchase(productId: "plan.standard.monthly")
        // then
        #expect(repository.didLoadUserAccountTimes == 1)
        #expect(service.didPurchasedWithAppAccountToken != nil)
    }

    // 확보된 토큰이 있으면 서버를 다시 치지 않는다
    @Test func usecase_purchase_whenTokenAlreadyCached_doesNotReloadAccount() async throws {
        // given
        let (usecase, repository, _) = self.makeUsecase()
        try await usecase.refreshUserPlan()
        // when
        _ = try await usecase.purchase(productId: "plan.standard.monthly")
        // then
        #expect(repository.didLoadUserAccountTimes == 1)
    }

    // 토큰 없이 사면 그 트랜잭션엔 주인을 표시할 값이 안 박혀 영영 반영되지 않는다 —
    // 청구부터 하고 실패를 알리느니 결제창을 아예 안 띄운다
    @Test func usecase_purchase_whenAccountTokenMissing_throwsWithoutCharging() async throws {
        // given
        let (usecase, _, service) = self.makeUsecase(
            appAccountToken: nil
        )
        // when
        await #expect(throws: (any Error).self) {
            _ = try await usecase.purchase(productId: "plan.standard.monthly")
        }
        // then
        #expect(service.didPurchasedProductId == nil)
    }

    // 유저 취소는 실패가 아니다 — 에러를 던지면 화면이 에러 팝업을 띄우게 된다
    @Test func usecase_purchase_whenUserCancels_returnsCancelledWithoutUpload() async throws {
        // given
        let (usecase, repository, _) = self.makeUsecase(shouldCancelPurchase: true)
        // when
        let result = try await usecase.purchase(productId: "plan.standard.monthly")
        // then
        guard case .cancelled = result else {
            Issue.record("cancelled 결과가 아님")
            return
        }
        #expect(repository.didPostedSignedTransactions.isEmpty)
    }

    // 승인대기(Ask to Buy)도 취소와 마찬가지로 서버에 아무것도 올리지 않는다 —
    // 실제 반영은 나중에 transactionUpdates 스트림으로 들어온다
    @Test func usecase_purchase_whenPurchasePending_returnsPendingWithoutUpload() async throws {
        // given
        let (usecase, repository, _) = self.makeUsecase(shouldPurchaseBePending: true)
        // when
        let result = try await usecase.purchase(productId: "plan.standard.monthly")
        // then
        guard case .pending = result else {
            Issue.record("pending 결과가 아님")
            return
        }
        #expect(repository.didPostedSignedTransactions.isEmpty)
    }

    @Test func usecase_purchase_finishesTransactionAfterServerApplied() async throws {
        // given
        let (usecase, _, service) = self.makeUsecase()
        // when
        _ = try await usecase.purchase(productId: "plan.lifetime")
        // then
        #expect(service.didFinishedTransactionIds == ["tx:plan.lifetime"])
    }

    // finish 를 먼저 부르면 서버 실패 시 영수증이 사라져 복구가 불가능해진다
    @Test func usecase_purchase_whenServerFails_doesNotFinishTransaction() async throws {
        // given
        let (usecase, _, service) = self.makeUsecase(shouldFailApply: true)
        // when
        _ = try? await usecase.purchase(productId: "plan.lifetime")
        // then
        #expect(service.didFinishedTransactionIds.isEmpty)
    }

    @Test func usecase_purchase_updatesSharedUserPlan() async throws {
        // given
        let expect = expectConfirm("구매 결과가 공유 상태에 반영된다")
        expect.count = 2
        let (usecase, _, _) = self.makeUsecase()
        // when
        let plans = try await self.outputs(expect, for: usecase.currentUserPlan) {
            _ = try await usecase.purchase(productId: "plan.standard.monthly")
        }
        // then: 토큰 확보를 위한 조회분(45600) 뒤에 구매 반영분이 온다
        #expect(plans.last?.planId == .standard)
        #expect(plans.last?.topupRemaining == 12300)
    }

    @Test func usecase_purchase_whenServerReflectFails_throwsReflectFailure() async throws {
        // given
        let (usecase, _, _) = self.makeUsecase(shouldFailApply: true)

        // when
        let failure: BillingReflectFailure? = await {
            do {
                _ = try await usecase.purchase(productId: "plan.lifetime")
                return nil
            } catch {
                return error as? BillingReflectFailure
            }
        }()

        // then
        #expect(failure != nil)
        #expect((failure?.underlying as? RuntimeError)?.message == "purchase apply failed")
    }

    // 결제 자체가 실패한 경우까지 감싸면 "결제는 완료됐다" 문구가 거짓말이 된다
    @Test func usecase_purchase_whenStoreFails_throwsRawErrorNotReflectFailure() async throws {
        // given
        let (usecase, _, _) = self.makeUsecase(shouldFailPurchase: true)

        // when
        let error: (any Error)? = await {
            do {
                _ = try await usecase.purchase(productId: "plan.lifetime")
                return nil
            } catch {
                return error
            }
        }()

        // then
        #expect(error is BillingReflectFailure == false)
        #expect((error as? RuntimeError)?.message == "store purchase failed")
    }

    @Test func usecase_restorePurchases_whenServerReflectFails_throwsReflectFailure() async throws {
        // given
        let (usecase, _, _) = self.makeUsecase(shouldFailApply: true)

        // when
        let failure: BillingReflectFailure? = await {
            do {
                _ = try await usecase.restorePurchases()
                return nil
            } catch {
                return error as? BillingReflectFailure
            }
        }()

        // then
        #expect(failure != nil)
    }
}


// MARK: - 유저 플랜 재조회

extension BillingUsecaseImpleTests {

    @Test func usecase_refreshUserPlan_returnsCurrentPlan() async throws {
        // given
        let (usecase, _, _) = self.makeUsecase()
        // when
        let plan = try await usecase.refreshUserPlan()
        // then
        #expect(plan.planId == .standard)
        #expect(plan.topupRemaining == 45600)
    }

    // 조회 실패는 결제와 무관하다 — 감싸면 "결제는 완료됐다" 로 오분류된다
    @Test func usecase_refreshUserPlan_whenFails_throwsRawErrorNotReflectFailure() async throws {
        // given
        let (usecase, _, _) = self.makeUsecase(shouldFailLoadUserPlan: true)

        // when
        let error: (any Error)? = await {
            do {
                _ = try await usecase.refreshUserPlan()
                return nil
            } catch {
                return error
            }
        }()

        // then
        #expect(error is BillingReflectFailure == false)
    }

    @Test func usecase_refreshUserPlan_updatesSharedUserPlan() async throws {
        // given
        let expect = expectConfirm("재조회 결과가 공유 상태에 반영된다")
        let (usecase, _, _) = self.makeUsecase()
        // when
        let plan = try await self.firstOutput(expect, for: usecase.currentUserPlan) {
            try await usecase.refreshUserPlan()
        }
        // then
        #expect(plan?.planId == .standard)
        #expect(plan?.topupRemaining == 45600)
    }

    // 실패는 호출측이 처리 — 이전에 반영돼 있던 공유 상태를 지우면 안 된다
    @Test func usecase_refreshUserPlan_whenFails_keepsExistingSharedPlan() async throws {
        // given
        let pending = BillingSignedTransaction(
            id: "tx:pending", productId: "plan.standard.monthly", jws: "jws:pending"
        )
        let (usecase, _, _) = self.makeUsecase(
            shouldFailLoadUserPlan: true, unfinished: [pending]
        )
        _ = try await usecase.applyUnfinishedTransactions()
        // when
        await #expect(throws: (any Error).self) {
            try await usecase.refreshUserPlan()
        }
        // then
        let expect = expectConfirm("기존 공유 상태가 유지된다")
        let plan = try await self.firstOutput(expect, for: usecase.currentUserPlan)
        #expect(plan?.planId == .standard)
        #expect(plan?.topupRemaining == 12300)
    }
}


// MARK: - 복원

extension BillingUsecaseImpleTests {

    @Test func usecase_restorePurchases_reappliesEntitlementsToDelegationEndpoint() async throws {
        // given
        let (usecase, repository, service) = self.makeUsecase()
        // when
        let result = try await usecase.restorePurchases()
        // then
        #expect(repository.didPostedTransactionUpdates == ["jws:restored"])
        #expect(repository.didPostedSignedTransactions == [])
        #expect(service.didFinishedTransactionIds == ["tx:restored"])
        guard case .applied(let plan) = result else {
            Issue.record("반영 결과가 아니다: \(result)")
            return
        }
        #expect(plan.planId == .standard)
    }

    // 시스템 로그인 시트를 닫은 것뿐이라 실패로 알리지 않는다 — 서버 왕복도 없다
    @Test func usecase_restorePurchases_whenUserCancelled_returnsCancelledWithoutPosting() async throws {
        // given
        let (usecase, repository, service) = self.makeUsecase(shouldCancelRestore: true)
        // when
        let result = try await usecase.restorePurchases()
        // then
        guard case .cancelled = result else {
            Issue.record("취소 결과가 아니다: \(result)")
            return
        }
        #expect(repository.didPostedTransactionUpdates == [])
        #expect(service.didFinishedTransactionIds == [])
    }

    @Test func usecase_restorePurchases_whenNothingRestored_returnsNothingToRestore() async throws {
        // given
        let (usecase, _, _) = self.makeUsecase(restored: [])
        // when
        let result = try await usecase.restorePurchases()
        // then
        guard case .nothingToRestore = result else {
            Issue.record("복원 없음 결과가 아니다: \(result)")
            return
        }
    }

    // 앞 건이 실패해도 뒤 건은 반영돼야 한다. 실패 사실은 첫 사유로 던져 화면에 노출된다
    @Test func usecase_restorePurchases_whenOneFails_stillAppliesTheRest() async throws {
        // given
        let (usecase, repository, service) = self.makeUsecase(
            restored: [
                BillingSignedTransaction(id: "tx:bad", productId: "plan.lifetime", jws: "jws:bad"),
                BillingSignedTransaction(id: "tx:good", productId: "plan.lifetime", jws: "jws:good")
            ],
            failingJWSTokens: ["jws:bad"]
        )
        // when
        await #expect(throws: (any Error).self) {
            try await usecase.restorePurchases()
        }
        // then
        #expect(repository.didPostedTransactionUpdates == ["jws:bad", "jws:good"])
        // 서버 반영에 실패한 건은 finish 되지 않아 다음 시도에 다시 잡힌다
        #expect(service.didFinishedTransactionIds == ["tx:good"])
    }
}


// MARK: - 동기 조회

extension BillingUsecaseImpleTests {

    @Test func usecase_whenPlanNotStored_latestUserPlanIsNil() {
        // given
        let (usecase, _, _) = self.makeUsecase()
        // when
        let plan = usecase.latestUserPlan()
        // then
        #expect(plan == nil)
    }

    @Test func usecase_whenPlanStored_latestUserPlanReturnsIt() {
        // given
        let store = SharedDataStore()
        store.put(
            BillingUserPlan.self,
            key: ShareDataKeys.billingUserPlan.rawValue,
            BillingUserPlan() |> \.planId .~ .standard
        )
        let usecase = BillingUsecaseImple(
            repository: StubBillingRepository(),
            appStoreService: StubAppStoreBillingService(),
            sharedDataStore: store
        )
        // when
        let plan = usecase.latestUserPlan()
        // then
        #expect(plan?.planId == .standard)
    }
}


// MARK: - 트랜잭션 감시

extension BillingUsecaseImpleTests {

    // 앱 밖에서 일어난 갱신·환불·가족공유가 들어오는 유일한 경로.
    // 종류를 판별하지 않고 위임 엔드포인트로 올린다 — 구매 확정 경로가 아니다
    @Test func usecase_startObserving_sendsStreamTransactionToDelegationEndpoint() async throws {
        // given
        let expect = expectConfirm("스트림으로 들어온 트랜잭션이 위임 경로로 반영된다")
        let (usecase, repository, service) = self.makeUsecase()
        usecase.startObservingTransactions()

        // when
        _ = try await self.firstOutput(expect, for: usecase.currentUserPlan) {
            service.sendTransactionUpdate(
                BillingSignedTransaction(id: "tx:renewal", productId: "plan.standard.monthly", jws: "jws:renewal")
            )
        }

        // then
        #expect(repository.didPostedTransactionUpdates == ["jws:renewal"])
        #expect(repository.didPostedSignedTransactions == [])
        #expect(service.didFinishedTransactionIds == ["tx:renewal"])
    }

    // 복구는 이 루틴에서 떨어져 나갔다 — startObserving 만으로는 미완료 건이 안 올라간다
    @Test func usecase_startObserving_doesNotRecoverUnfinished() async throws {
        // given
        let pending = BillingSignedTransaction(
            id: "tx:pending", productId: "plan.lifetime", jws: "jws:pending"
        )
        let (usecase, repository, service) = self.makeUsecase(unfinished: [pending])

        // when
        usecase.startObservingTransactions()
        try await Task.sleep(nanoseconds: 50_000_000)

        // then
        #expect(repository.didPostedTransactionUpdates == [])
        #expect(service.didFinishedTransactionIds == [])
    }

    // 취소 후 도착한 트랜잭션은 처리되지 않는다 — 로그아웃 구간에 이전 세션의
    // 리스너가 살아 있으면 같은 JWS 가 중복 post 된다
    @Test func usecase_afterStopObserving_ignoresIncomingTransaction() async throws {
        // given
        let (usecase, repository, service) = self.makeUsecase()
        usecase.startObservingTransactions()
        try await Task.sleep(nanoseconds: 50_000_000)

        // when
        usecase.stopObservingTransactions()
        try await Task.sleep(nanoseconds: 50_000_000)
        service.sendTransactionUpdate(
            BillingSignedTransaction(id: "tx:late", productId: "plan.lifetime", jws: "jws:late")
        )
        try await Task.sleep(nanoseconds: 100_000_000)

        // then
        #expect(repository.didPostedTransactionUpdates == [])
        #expect(service.didFinishedTransactionIds == [])
    }
}


// MARK: - 미완료 거래 복구

extension BillingUsecaseImpleTests {

    // 서버 반영 전에 앱이 죽은 트랜잭션은 독립 복구 경로로 올라간다
    @Test func usecase_recoverUnfinished_sendsToDelegationEndpoint() async throws {
        // given
        let pending = BillingSignedTransaction(
            id: "tx:pending", productId: "plan.lifetime", jws: "jws:pending"
        )
        let expect = expectConfirm("미완료 트랜잭션이 복구된다")
        let (usecase, repository, service) = self.makeUsecase(unfinished: [pending])

        // when
        _ = try await self.firstOutput(expect, for: usecase.currentUserPlan) {
            usecase.recoverUnfinishedTransactions()
        }

        // then
        #expect(repository.didPostedTransactionUpdates == ["jws:pending"])
        #expect(service.didFinishedTransactionIds == ["tx:pending"])
    }

    // 앞 건이 영구 실패해도 뒤 건은 반영돼야 한다 — fail-fast 면 매 시도마다 뒤가 가려진다
    @Test func usecase_recoverUnfinished_whenOneFails_stillAppliesTheRest() async throws {
        // given
        let failing = BillingSignedTransaction(
            id: "tx:bad", productId: "plan.lifetime", jws: "jws:bad"
        )
        let pending = BillingSignedTransaction(
            id: "tx:pending", productId: "plan.lifetime", jws: "jws:pending"
        )
        let expect = expectConfirm("실패한 트랜잭션 뒤 건이 반영된다")
        let (usecase, repository, service) = self.makeUsecase(
            unfinished: [failing, pending], failingJWSTokens: ["jws:bad"]
        )

        // when
        _ = try await self.firstOutput(expect, for: usecase.currentUserPlan) {
            usecase.recoverUnfinishedTransactions()
        }

        // then
        #expect(repository.didPostedTransactionUpdates == ["jws:bad", "jws:pending"])
        // 서버 반영에 실패한 건은 finish 되지 않아 다음 시도에 다시 잡힌다
        #expect(service.didFinishedTransactionIds == ["tx:pending"])
    }
}


// MARK: - 옵저버 생명주기

extension BillingUsecaseImpleTests {

    // observeTransactionUpdates() 를 self?. 로 호출하면 그 무한 for-await 동안
    // self 가 strong 으로 승격돼 스코프를 벗어나도 살아있다 — deinit 이 안 와 관찰 누수로 이어진다
    @Test func startObservingTransactions_afterScopeEnds_deallocatesUsecase() async throws {
        // given
        weak var weakUsecase: BillingUsecaseImple?
        // when
        do {
            let (usecase, _, _) = self.makeUsecase()
            weakUsecase = usecase
            usecase.startObservingTransactions()
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        // then
        #expect(weakUsecase == nil)
    }
}


// MARK: - 미완료 거래 조회·유저 요청 반영

extension BillingUsecaseImpleTests {

    @Test func usecase_hasUnfinishedTransactions_whenQueueEmpty_returnsFalse() async throws {
        // given
        let (usecase, _, _) = self.makeUsecase(unfinished: [])
        // when
        let hasUnfinished = await usecase.hasUnfinishedTransactions()
        // then
        #expect(hasUnfinished == false)
    }

    @Test func usecase_hasUnfinishedTransactions_whenQueueNotEmpty_returnsTrue() async throws {
        // given
        let pending = BillingSignedTransaction(
            id: "tx:pending", productId: "plan.lifetime", jws: "jws:pending"
        )
        let (usecase, _, _) = self.makeUsecase(unfinished: [pending])
        // when
        let hasUnfinished = await usecase.hasUnfinishedTransactions()
        // then
        #expect(hasUnfinished == true)
    }

    @Test func usecase_applyUnfinishedTransactions_sendsAllToDelegationEndpoint() async throws {
        // given
        let first = BillingSignedTransaction(
            id: "tx:first", productId: "plan.standard.monthly", jws: "jws:first"
        )
        let second = BillingSignedTransaction(
            id: "tx:second", productId: "plan.lifetime", jws: "jws:second"
        )
        let (usecase, repository, service) = self.makeUsecase(unfinished: [first, second])
        // when
        let applied = try await usecase.applyUnfinishedTransactions()
        // then
        #expect(repository.didPostedTransactionUpdates == ["jws:first", "jws:second"])
        #expect(service.didFinishedTransactionIds == ["tx:first", "tx:second"])
        #expect(applied?.planId == .standard)
    }

    @Test func usecase_applyUnfinishedTransactions_whenQueueEmpty_returnsNilWithoutThrowing() async throws {
        // given
        let (usecase, repository, service) = self.makeUsecase(unfinished: [])
        // when
        let applied = try await usecase.applyUnfinishedTransactions()
        // then
        #expect(applied == nil)
        #expect(repository.didPostedTransactionUpdates == [])
        #expect(service.didFinishedTransactionIds == [])
    }

    @Test func usecase_applyUnfinishedTransactions_whenOneFails_stillAppliesTheRest() async throws {
        // given
        let failing = BillingSignedTransaction(
            id: "tx:bad", productId: "plan.lifetime", jws: "jws:bad"
        )
        let pending = BillingSignedTransaction(
            id: "tx:pending", productId: "plan.lifetime", jws: "jws:pending"
        )
        let (usecase, repository, service) = self.makeUsecase(
            unfinished: [failing, pending], failingJWSTokens: ["jws:bad"]
        )
        // when
        await #expect(throws: (any Error).self) {
            _ = try await usecase.applyUnfinishedTransactions()
        }
        // then
        #expect(repository.didPostedTransactionUpdates == ["jws:bad", "jws:pending"])
        #expect(service.didFinishedTransactionIds == ["tx:pending"])
    }

    @Test func usecase_applyUnfinishedTransactions_whenServerReflectFails_throwsReflectFailure() async throws {
        // given
        let failing = BillingSignedTransaction(
            id: "tx:bad", productId: "plan.lifetime", jws: "jws:bad"
        )
        let (usecase, _, _) = self.makeUsecase(
            unfinished: [failing], failingJWSTokens: ["jws:bad"]
        )

        // when
        let failure: BillingReflectFailure? = await {
            do {
                _ = try await usecase.applyUnfinishedTransactions()
                return nil
            } catch {
                return error as? BillingReflectFailure
            }
        }()

        // then
        #expect(failure != nil)
        #expect(
            (failure?.underlying as? RuntimeError)?.message == "transaction update apply failed"
        )
    }
}
