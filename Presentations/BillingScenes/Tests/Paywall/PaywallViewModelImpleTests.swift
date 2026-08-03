//
//  PaywallViewModelImpleTests.swift
//  BillingScenesTests
//
//  Created by sudo.park on 8/4/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Prelude
import Optics
import Domain
import Extensions
import UnitTestHelpKit

@testable import BillingScenes


final class PaywallViewModelImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = .init()

    private func makeViewModel(
        offerings: [BillingPlanOffering] = [],
        catalogLoadError: (any Error)? = nil,
        purchaseResult: Result<BillingPurchaseResult, any Error> = .success(.cancelled),
        userPlan: BillingUserPlan? = nil
    ) -> (PaywallViewModelImple, StubBillingUsecase, SpyPaywallRouter) {
        let stub = StubBillingUsecase(
            offerings: offerings,
            catalogLoadError: catalogLoadError,
            purchaseResult: purchaseResult,
            userPlan: userPlan
        )
        let viewModel = PaywallViewModelImple(billingUsecase: stub)
        let router = SpyPaywallRouter()
        viewModel.router = router
        return (viewModel, stub, router)
    }

    // restore()는 별도 퍼블리셔 토글이 없어(purchase()의 isPurchasing 같은 신호가 없다),
    // 라우터에 결과가 반영될 때까지 짧게 폴링해 async Task 완료를 기다린다.
    private func waitUntil(
        timeout: Duration = .seconds(1), _ condition: @Sendable () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while condition() == false, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    private func purchasableOffering(
        _ planId: BillingPlanId,
        productId: String,
        price: String = "$4.99",
        kind: BillingProductKind? = .subscription(period: .monthly),
        dailyLimit: Int = 100
    ) -> BillingPlanOffering {
        let plan = BillingPlan(id: planId, dailyLimit: dailyLimit) |> \.productId .~ productId
        var offering = BillingPlanOffering(plan: plan)
        offering.product = BillingProduct(productId: productId, displayName: "\(planId)", displayPrice: price)
            |> \.kind .~ kind
        return offering
    }

    private func offeringWithoutStoreProduct(
        _ planId: BillingPlanId, productId: String, dailyLimit: Int = 100
    ) -> BillingPlanOffering {
        let plan = BillingPlan(id: planId, dailyLimit: dailyLimit) |> \.productId .~ productId
        return BillingPlanOffering(plan: plan)  // product 은 nil — 스토어 조회 실패
    }

    private func freeOffering(dailyLimit: Int = 50) -> BillingPlanOffering {
        return BillingPlanOffering(plan: BillingPlan(id: .free, dailyLimit: dailyLimit))
    }

    // prepare() 는 offerings 를 async Task 로 실어 나른다 — cellModels 를 2회(초기 빈 값 →
    // 로드된 값) 관찰해 로딩 완료를 기다린다. 모든 테스트가 이 헬퍼로 로딩 시점을 동기화한다.
    private func waitOfferingsLoaded(
        _ viewModel: any PaywallViewModel
    ) async throws -> [PaywallPlanCellModel] {
        let expect = expectConfirm("offerings loaded")
        expect.count = 2
        let emitted = try await self.outputs(expect, for: viewModel.cellModels) {
            viewModel.prepare()
        }
        return emitted.last ?? []
    }
}


// MARK: - 카탈로그 표시

extension PaywallViewModelImpleTests {

    @Test func viewModel_whenPrepared_showsPurchasablePlansOnly() async throws {
        // given
        let free = self.freeOffering()
        let standard = self.purchasableOffering(.standard, productId: "product.standard")
        let lifetime = self.purchasableOffering(.lifetime, productId: "product.lifetime", kind: .oneTime)
        let (viewModel, _, _) = self.makeViewModel(offerings: [free, standard, lifetime])

        // when
        let cells = try await self.waitOfferingsLoaded(viewModel)

        // then
        // free 플랜(productId nil)은 셀에서 빠지고 standard·lifetime 만 남는다
        #expect(cells.map { $0.planId } == [.standard, .lifetime])
    }

    @Test func viewModel_whenStoreLookupFailed_showsPlanWithoutPrice() async throws {
        // given
        let standard = self.offeringWithoutStoreProduct(.standard, productId: "product.standard")
        let (viewModel, _, _) = self.makeViewModel(offerings: [standard])

        // when
        let cells = try await self.waitOfferingsLoaded(viewModel)

        // then
        let cell = try #require(cells.first)
        #expect(cell.priceText == nil)
        #expect(cell.isPurchasable == false)
    }

    @Test func viewModel_whenAlreadyStandard_marksOwnedAndSelectsNextPlan() async throws {
        // given
        let standard = self.purchasableOffering(.standard, productId: "product.standard")
        let lifetime = self.purchasableOffering(.lifetime, productId: "product.lifetime", kind: .oneTime)
        let (viewModel, _, _) = self.makeViewModel(
            offerings: [standard, lifetime],
            userPlan: BillingUserPlan() |> \.planId .~ .standard
        )

        // when
        let cells = try await self.waitOfferingsLoaded(viewModel)
        let selectedExpect = expectConfirm("초기 선택은 구매 가능한 첫 카드")
        let selected = try await self.firstOutput(selectedExpect, for: viewModel.selectedPlanId) ?? nil

        // then
        #expect(cells.first(where: { $0.planId == .standard })?.isOwned == true)
        #expect(selected == .lifetime)
    }

    // C1 회귀 — lifetime(최상위) 보유자에게 하위 등급(standard) 카드가 구매 가능으로 뜨면 안 된다
    @Test func viewModel_whenAlreadyLifetime_noCellIsPurchasable() async throws {
        // given
        let standard = self.purchasableOffering(.standard, productId: "product.standard")
        let lifetime = self.purchasableOffering(.lifetime, productId: "product.lifetime", kind: .oneTime)
        let (viewModel, _, _) = self.makeViewModel(
            offerings: [standard, lifetime],
            userPlan: BillingUserPlan() |> \.planId .~ .lifetime
        )

        // when
        let cells = try await self.waitOfferingsLoaded(viewModel)
        let selectedExpect = expectConfirm("선택 없음")
        let selected = try await self.firstOutput(selectedExpect, for: viewModel.selectedPlanId) ?? nil

        // then
        #expect(cells.allSatisfy { $0.isPurchasable == false })
        // standard 는 지금 쓰는 플랜이 아니라 isOwned 는 false — 상위 등급이 커버할 뿐이다
        #expect(cells.first(where: { $0.planId == .standard })?.isOwned == false)
        #expect(cells.first(where: { $0.planId == .standard })?.isCovered == true)
        #expect(cells.first(where: { $0.planId == .lifetime })?.isOwned == true)
        #expect(selected == nil)
    }
}


// MARK: - 카탈로그 로딩 상태

extension PaywallViewModelImpleTests {

    @Test func viewModel_beforePrepared_catalogStateIsLoading() async throws {
        // given
        let (viewModel, _, _) = self.makeViewModel()

        // when
        let expect = expectConfirm("초기 상태")
        let state = try await self.firstOutput(expect, for: viewModel.catalogState)

        // then
        #expect(state == .loading)
    }

    // I1/I2 회귀 — 서버 카탈로그 요청 실패는 .loaded([]) 로 조용히 삼키지 않고 .failed 로
    // 드러나며, purchase()/restore() 와 동일하게 showError 로 알린다
    @Test func viewModel_whenCatalogLoadFails_setsFailedStateAndShowsError() async throws {
        // given
        let (viewModel, _, router) = self.makeViewModel(catalogLoadError: TestError())

        // when — 초기 .loading 구독분 + 최종 .failed (같은 값 연속 방출은 dedupe 된다)
        let expect = expectConfirm("failed 상태 방출")
        expect.count = 2
        let states = try await self.outputs(expect, for: viewModel.catalogState) {
            viewModel.prepare()
        }

        // then
        #expect(states.last == .failed)
        #expect(router.didShowError is TestError)
    }
}


// MARK: - 선택·구매 가드 (I3 회귀)

extension PaywallViewModelImpleTests {

    @Test func viewModel_selectPlan_whenStoreProductUnavailable_doesNotSelect() async throws {
        // given: 서버 카탈로그엔 있지만 StoreKit 조회가 실패한(product == nil) 플랜
        let standard = self.offeringWithoutStoreProduct(.standard, productId: "product.standard")
        let (viewModel, _, _) = self.makeViewModel(offerings: [standard])
        _ = try await self.waitOfferingsLoaded(viewModel)

        // when
        viewModel.selectPlan(.standard)
        let expect = expectConfirm("선택 상태")
        let selected = try await self.firstOutput(expect, for: viewModel.selectedPlanId) ?? nil

        // then
        #expect(selected == nil)
    }
}


// MARK: - 고지문 분기

extension PaywallViewModelImpleTests {

    @Test func viewModel_whenSubscriptionSelected_showsAutoRenewDisclosure() async throws {
        // given
        let standard = self.purchasableOffering(
            .standard, productId: "product.standard", kind: .subscription(period: .monthly)
        )
        let (viewModel, _, _) = self.makeViewModel(offerings: [standard])

        // when
        _ = try await self.waitOfferingsLoaded(viewModel)
        viewModel.selectPlan(.standard)
        let detailExpect = expectConfirm("subscription 고지문")
        let detail = try await self.firstOutput(detailExpect, for: viewModel.selectedPlanDetail) ?? nil

        // then
        // kind 가 .subscription 이냐 .oneTime 이냐로 갈린다. plan id 로 가르지 않는다
        #expect(detail?.disclosure == "billing::paywall::disclosure::subscription".localized())
    }

    @Test func viewModel_whenOneTimeSelected_showsNoAutoRenewDisclosure() async throws {
        // given
        let lifetime = self.purchasableOffering(
            .lifetime, productId: "product.lifetime", kind: .oneTime
        )
        let (viewModel, _, _) = self.makeViewModel(offerings: [lifetime])

        // when
        _ = try await self.waitOfferingsLoaded(viewModel)
        viewModel.selectPlan(.lifetime)
        let detailExpect = expectConfirm("oneTime 고지문")
        let detail = try await self.firstOutput(detailExpect, for: viewModel.selectedPlanDetail) ?? nil

        // then
        #expect(detail?.disclosure == "billing::paywall::disclosure::oneTime".localized())
    }
}


// MARK: - 구매

extension PaywallViewModelImpleTests {

    // purchase() 는 isPurchasing 을 true → false 로 토글한다. 3회(초기 false → true →
    // 완료 후 false) 관찰해 Task 완료(=stub 호출 반영)까지 기다린다.
    private func waitPurchaseCompleted(
        _ viewModel: any PaywallViewModel
    ) async throws {
        let expect = expectConfirm("purchase 완료")
        expect.count = 3
        _ = try await self.outputs(expect, for: viewModel.isPurchasing) {
            viewModel.purchase()
        }
    }

    @Test func viewModel_purchase_passesSelectedPlanProductId() async throws {
        // given
        let standard = self.purchasableOffering(.standard, productId: "product.standard")
        let (viewModel, stub, _) = self.makeViewModel(
            offerings: [standard], purchaseResult: .success(.cancelled)
        )
        _ = try await self.waitOfferingsLoaded(viewModel)
        viewModel.selectPlan(.standard)

        // when
        try await self.waitPurchaseCompleted(viewModel)

        // then
        #expect(stub.didPurchasedProductId == "product.standard")
    }

    @Test func viewModel_whenPurchaseCancelled_doesNotCloseScene() async throws {
        // given
        let standard = self.purchasableOffering(.standard, productId: "product.standard")
        let (viewModel, _, router) = self.makeViewModel(
            offerings: [standard], purchaseResult: .success(.cancelled)
        )
        _ = try await self.waitOfferingsLoaded(viewModel)
        viewModel.selectPlan(.standard)

        // when
        try await self.waitPurchaseCompleted(viewModel)

        // then
        #expect(router.didClosed == nil)
    }

    @Test func viewModel_whenPurchasePending_showsWaitingApprovalGuide() async throws {
        // given
        let standard = self.purchasableOffering(.standard, productId: "product.standard")
        let (viewModel, _, router) = self.makeViewModel(
            offerings: [standard], purchaseResult: .success(.pending)
        )
        _ = try await self.waitOfferingsLoaded(viewModel)
        viewModel.selectPlan(.standard)

        // when
        try await self.waitPurchaseCompleted(viewModel)

        // then
        #expect(router.didShowConfirmWith?.title == "billing::paywall::pending::title".localized())
        #expect(router.didClosed == nil)
    }

    @Test func viewModel_whenPurchaseFailed_showsError() async throws {
        // given
        let standard = self.purchasableOffering(.standard, productId: "product.standard")
        let (viewModel, _, router) = self.makeViewModel(
            offerings: [standard], purchaseResult: .failure(TestError())
        )
        _ = try await self.waitOfferingsLoaded(viewModel)
        viewModel.selectPlan(.standard)

        // when
        try await self.waitPurchaseCompleted(viewModel)

        // then
        #expect(router.didShowError is TestError)
    }

    // I5 — 성공(applied)은 가장 중요한 계약인데 테스트가 없었다: 토스트 후 씬을 닫는다
    @Test func viewModel_whenPurchaseApplied_showsToastAndClosesScene() async throws {
        // given
        let standard = self.purchasableOffering(.standard, productId: "product.standard")
        let appliedPlan = BillingUserPlan() |> \.planId .~ .standard
        let (viewModel, _, router) = self.makeViewModel(
            offerings: [standard], purchaseResult: .success(.applied(appliedPlan))
        )
        _ = try await self.waitOfferingsLoaded(viewModel)
        viewModel.selectPlan(.standard)

        // when
        try await self.waitPurchaseCompleted(viewModel)

        // then
        #expect(router.didShowToastWithMessage == "billing::paywall::purchase::applied".localized())
        #expect(router.didClosed == true)
    }
}


// MARK: - 복원 (I4)

extension PaywallViewModelImpleTests {

    @Test func viewModel_restore_whenPurchaseFound_showsRestoredToast() async throws {
        // given
        let (viewModel, stub, router) = self.makeViewModel(
            userPlan: BillingUserPlan() |> \.planId .~ .standard
        )

        // when
        viewModel.restore()
        try await self.waitUntil { router.didShowToastWithMessage != nil }

        // then
        #expect(stub.didRestoreCalled == true)
        #expect(router.didShowToastWithMessage == "billing::paywall::restored".localized())
    }

    @Test func viewModel_restore_whenNothingToRestore_showsEmptyGuide() async throws {
        // given: 복원할 구매가 없음(userPlan nil)
        let (viewModel, stub, router) = self.makeViewModel(userPlan: nil)

        // when
        viewModel.restore()
        try await self.waitUntil { router.didShowToastWithMessage != nil }

        // then
        #expect(stub.didRestoreCalled == true)
        #expect(router.didShowToastWithMessage == "billing::paywall::restore::empty".localized())
    }
}
