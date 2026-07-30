//
//  BillingUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 7/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import UnitTestHelpKit

@testable import Domain


final class BillingUsecaseImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = .init()

    private func makeUsecase(
        shouldCancelPurchase: Bool = false,
        shouldPurchaseBePending: Bool = false,
        shouldFailApply: Bool = false,
        shouldFailLoadProducts: Bool = false,
        unfinished: [BillingSignedTransaction] = [],
        restored: [BillingSignedTransaction]? = nil,
        failingJWSTokens: Set<String> = []
    ) -> (BillingUsecaseImple, StubBillingRepository, StubAppStoreBillingService) {
        let repository = StubBillingRepository(
            shouldFailPurchase: shouldFailApply, failingJWSTokens: failingJWSTokens
        )
        let service = StubAppStoreBillingService(
            shouldCancelPurchase: shouldCancelPurchase,
            shouldPurchaseBePending: shouldPurchaseBePending,
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
        let (usecase, _, _) = self.makeUsecase()
        // when
        let plan = try await self.firstOutput(expect, for: usecase.currentUserPlan) {
            _ = try await usecase.purchase(productId: "plan.standard.monthly")
        }
        // then
        #expect(plan?.planId == .standard)
    }
}


// MARK: - 복원

extension BillingUsecaseImpleTests {

    @Test func usecase_restorePurchases_reappliesEntitlements() async throws {
        // given
        let (usecase, repository, service) = self.makeUsecase()
        // when
        let plan = try await usecase.restorePurchases()
        // then
        #expect(repository.didPostedSignedTransactions == ["jws:restored"])
        #expect(service.didFinishedTransactionIds == ["tx:restored"])
        #expect(plan?.planId == .standard)
    }

    // 복원은 유저가 직접 누른 액션이라 fail-fast 가 의도다 — 앞 건이 실패하면 그대로 던져
    // 화면에 노출하고 멈춘다. 미완료 복구 경로(best-effort)와 비대칭인 지점이라 잠가둔다
    @Test func usecase_restorePurchases_whenOneFails_throwsWithoutApplyingRest() async throws {
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
        #expect(repository.didPostedSignedTransactions == ["jws:bad"])
        #expect(service.didFinishedTransactionIds.isEmpty)
    }
}


// MARK: - 트랜잭션 감시

extension BillingUsecaseImpleTests {

    // 서버 반영 전에 앱이 죽은 트랜잭션은 기동 시 복구된다
    @Test func usecase_startObserving_recoversUnfinishedTransactions() async throws {
        // given
        let pending = BillingSignedTransaction(
            id: "tx:pending", productId: "plan.lifetime", jws: "jws:pending"
        )
        let expect = expectConfirm("미완료 트랜잭션이 복구된다")
        let (usecase, repository, _) = self.makeUsecase(unfinished: [pending])
        // when
        _ = try await self.firstOutput(expect, for: usecase.currentUserPlan) {
            usecase.startObservingTransactions()
        }
        // then
        #expect(repository.didPostedSignedTransactions == ["jws:pending"])
    }

    // 앞 건이 영구 실패해도 뒤 건은 반영돼야 한다 — fail-fast 면 매 기동마다 뒤가 가려진다
    @Test func usecase_startObserving_whenOneUnfinishedFails_stillAppliesTheRest() async throws {
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
            usecase.startObservingTransactions()
        }
        // then
        #expect(repository.didPostedSignedTransactions == ["jws:bad", "jws:pending"])
        // 서버 반영에 실패한 건은 finish 되지 않아 다음 기동에 다시 잡힌다
        #expect(service.didFinishedTransactionIds == ["tx:pending"])
    }

    // 앱 밖에서 일어난 갱신·환불·가족공유가 들어오는 유일한 경로
    @Test func usecase_startObserving_appliesTransactionFromStream() async throws {
        // given
        let expect = expectConfirm("스트림으로 들어온 트랜잭션이 반영된다")
        let (usecase, repository, service) = self.makeUsecase()
        usecase.startObservingTransactions()
        // when
        _ = try await self.firstOutput(expect, for: usecase.currentUserPlan) {
            service.sendTransactionUpdate(
                BillingSignedTransaction(id: "tx:renewal", productId: "plan.standard.monthly", jws: "jws:renewal")
            )
        }
        // then
        #expect(repository.didPostedSignedTransactions == ["jws:renewal"])
        #expect(service.didFinishedTransactionIds == ["tx:renewal"])
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
