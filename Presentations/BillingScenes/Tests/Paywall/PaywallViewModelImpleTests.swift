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
        userPlan: BillingUserPlan? = nil,
        restoreResult: BillingRestoreResult = .nothingToRestore,
        restoreError: (any Error)? = nil,
        userPlanLoadError: (any Error)? = nil,
        hasUnfinished: Bool = false,
        applyUnfinishedResult: Result<BillingUserPlan?, any Error> = .success(nil)
    ) -> (PaywallViewModelImple, StubBillingUsecase, SpyPaywallRouter) {
        let stub = StubBillingUsecase(
            offerings: offerings,
            catalogLoadError: catalogLoadError,
            purchaseResult: purchaseResult,
            userPlan: userPlan,
            restoreResult: restoreResult,
            restoreError: restoreError,
            userPlanLoadError: userPlanLoadError,
            hasUnfinished: hasUnfinished,
            applyUnfinishedResult: applyUnfinishedResult
        )
        let viewModel = PaywallViewModelImple(billingUsecase: stub)
        let router = SpyPaywallRouter()
        viewModel.router = router
        return (viewModel, stub, router)
    }

    // purchase()·restore() 둘 다 isPurchasing 을 true → false 로 토글한다(I4 — restore() 도
    // 재진입 가드 겸 진행 신호로 이 subject 를 공유한다, #739). 3회(초기 false → true →
    // 완료 후 false) 관찰해 Task 완료(=stub 호출 반영)까지 기다린다.
    private func waitProcessingCompleted(
        _ viewModel: any PaywallViewModel, action: @escaping () -> Void
    ) async throws {
        let expect = expectConfirm("처리 완료")
        expect.count = 3
        _ = try await self.outputs(expect, for: viewModel.isPurchasing) { action() }
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

    private func waitUntil<P: Publisher>(
        _ source: P,
        matching predicate: @escaping @Sendable (P.Output) -> Bool
    ) async throws -> P.Output? where P.Output: Sendable {
        let expect = expectConfirm("조건 도달 대기")
        expect.timeout = .seconds(5)
        return try await self.firstOutput(expect, for: source.filter(predicate))
    }

    private func waitScreenState(
        _ viewModel: any PaywallViewModel,
        until predicate: @escaping @Sendable (PaywallScreenState) -> Bool
    ) async throws -> PaywallScreenState {
        let state = try await self.waitUntil(viewModel.screenState, matching: predicate)
        return state ?? .loading
    }

    private func waitUnfinishedBannerReady(
        _ viewModel: any PaywallViewModel
    ) async throws {
        let expect = expectConfirm("배너 노출 대기")
        expect.count = 2
        _ = try await self.outputs(expect, for: viewModel.hasUnfinishedTransactions) {
            viewModel.prepare()
        }
    }

    private func waitUnfinishedCheckPerformed(_ stub: StubBillingUsecase) async {
        let deadline = ContinuousClock.now + .seconds(5)
        while !stub.didCheckUnfinishedCalled, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        if !stub.didCheckUnfinishedCalled {
            Issue.record("hasUnfinishedTransactions() 가 바운드 시간 안에 호출되지 않았다")
        }
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
    // 드러난다. 단 화면이 그 상태를 이미 그리므로 showError 로 중복 통지하지 않는다
    @Test func viewModel_whenCatalogLoadFails_setsFailedStateWithoutErrorPopup() async throws {
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
        #expect(router.didShowError == nil)
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

    // C2 회귀 — 월간(monthly) 이외의 구독 주기는 "매월"로 고정된 문구가 아니라 기간을
    // 단정하지 않는 공용 고지문을 써야 한다. 안 그러면 연간 상품에 "매월 자동 갱신됩니다"가
    // 붙어 구독 기간을 잘못 표기하게 된다(App Store 리젝 사유). 변칙 주기(period == nil)도 동일
    @Test(
        "월간 외 구독 주기는 공용 고지문",
        arguments: [BillingSubscriptionPeriod?.some(.weekly), .some(.yearly), .none]
    )
    func viewModel_whenNonMonthlySubscriptionSelected_showsGenericDisclosure(
        _ period: BillingSubscriptionPeriod?
    ) async throws {
        // given
        let standard = self.purchasableOffering(
            .standard, productId: "product.standard", kind: .subscription(period: period)
        )
        let (viewModel, _, _) = self.makeViewModel(offerings: [standard])

        // when
        _ = try await self.waitOfferingsLoaded(viewModel)
        viewModel.selectPlan(.standard)
        let detailExpect = expectConfirm("공용 고지문")
        let detail = try await self.firstOutput(detailExpect, for: viewModel.selectedPlanDetail) ?? nil

        // then
        #expect(detail?.disclosure == "billing::paywall::disclosure::subscription::generic".localized())
    }
}


// MARK: - 구매

extension PaywallViewModelImpleTests {

    @Test func viewModel_purchase_passesSelectedPlanProductId() async throws {
        // given
        let standard = self.purchasableOffering(.standard, productId: "product.standard")
        let (viewModel, stub, _) = self.makeViewModel(
            offerings: [standard], purchaseResult: .success(.cancelled)
        )
        _ = try await self.waitOfferingsLoaded(viewModel)
        viewModel.selectPlan(.standard)

        // when
        try await self.waitProcessingCompleted(viewModel) { viewModel.purchase() }

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
        try await self.waitProcessingCompleted(viewModel) { viewModel.purchase() }

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
        try await self.waitProcessingCompleted(viewModel) { viewModel.purchase() }

        // then
        #expect(router.didShowConfirmWith?.title == "billing::paywall::pending::title".localized())
        #expect(router.didClosed == nil)
    }

    @Test func viewModel_whenPurchaseFailedAtStore_showsPurchaseFailedMessage() async throws {
        // given
        let standard = self.purchasableOffering(.standard, productId: "product.standard")
        let (viewModel, _, router) = self.makeViewModel(
            offerings: [standard], purchaseResult: .failure(TestError())
        )
        _ = try await self.waitOfferingsLoaded(viewModel)
        viewModel.selectPlan(.standard)

        // when
        try await self.waitProcessingCompleted(viewModel) { viewModel.purchase() }

        // then
        #expect(
            router.didShowConfirmWith?.message == "billing::paywall::fail::purchase".localized()
        )
    }

    @Test func viewModel_whenServerReflectFailed_showsReflectDelayedMessage() async throws {
        // given
        let standard = self.purchasableOffering(.standard, productId: "product.standard")
        let (viewModel, _, router) = self.makeViewModel(
            offerings: [standard],
            purchaseResult: .failure(BillingReflectFailure(RuntimeError("network down")))
        )
        _ = try await self.waitOfferingsLoaded(viewModel)
        viewModel.selectPlan(.standard)

        // when
        try await self.waitProcessingCompleted(viewModel) { viewModel.purchase() }

        // then
        #expect(
            router.didShowConfirmWith?.message
                == "billing::paywall::fail::reflectDelayed".localized()
        )
    }

    @Test(
        "서버 에러 코드별로 다른 문구를 보여준다",
        arguments: [
            (ServerErrorModel.ErrorCode.invalidTransaction, "billing::paywall::fail::invalidTransaction"),
            (.unknownProduct, "billing::paywall::fail::unknownProduct"),
            (.planChangeNotAllowed, "billing::paywall::fail::planChangeNotAllowed")
        ]
    )
    func viewModel_whenServerReflectFailedWithCode_showsCodeSpecificMessage(
        _ code: ServerErrorModel.ErrorCode, _ expectedKey: String
    ) async throws {
        // given
        let serverError = ServerErrorModel() |> \.code .~ code
        let standard = self.purchasableOffering(.standard, productId: "product.standard")
        let (viewModel, _, router) = self.makeViewModel(
            offerings: [standard],
            purchaseResult: .failure(BillingReflectFailure(serverError))
        )
        _ = try await self.waitOfferingsLoaded(viewModel)
        viewModel.selectPlan(.standard)

        // when
        try await self.waitProcessingCompleted(viewModel) { viewModel.purchase() }

        // then
        #expect(router.didShowConfirmWith?.message == expectedKey.localized())
    }

    // 요청 취소는 유저가 만든 상태다 — 알림을 띄우면 취소했는데 에러를 본 꼴이 된다
    @Test func viewModel_whenRequestCancelled_showsNothing() async throws {
        // given
        let cancelled = ServerErrorModel() |> \.code .~ ServerErrorModel.ErrorCode.cancelled
        let standard = self.purchasableOffering(.standard, productId: "product.standard")
        let (viewModel, _, router) = self.makeViewModel(
            offerings: [standard],
            purchaseResult: .failure(BillingReflectFailure(cancelled))
        )
        _ = try await self.waitOfferingsLoaded(viewModel)
        viewModel.selectPlan(.standard)

        // when
        try await self.waitProcessingCompleted(viewModel) { viewModel.purchase() }

        // then
        #expect(router.didShowConfirmWith == nil)
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
        try await self.waitProcessingCompleted(viewModel) { viewModel.purchase() }

        // then
        #expect(router.didShowToastWithMessage == "billing::paywall::purchase::applied".localized())
        #expect(router.didClosed == true)
    }

    // C1 회귀 — 선택 시점엔 구매 가능했더라도, 그 뒤 복원 등으로 보유 플랜이 선택 플랜을
    // 커버하게 되면 CTA(selectedPlanId)가 무효화되고 purchase() 는 청구를 시도하지 않는다.
    // 구 코드는 userSelectedPlanId 를 재검증 없이 그대로 신뢰해 이미 보유한 상위 플랜에
    // 하위 플랜을 중복 청구했다
    @Test func viewModel_whenSelectedPlanBecomesCoveredAfterRestore_blocksPurchase() async throws {
        // given: free 로 진입해 standard 선택
        let standard = self.purchasableOffering(.standard, productId: "product.standard")
        let lifetime = self.purchasableOffering(.lifetime, productId: "product.lifetime", kind: .oneTime)
        let (viewModel, stub, router) = self.makeViewModel(
            offerings: [standard, lifetime],
            restoreResult: .applied(BillingUserPlan() |> \.planId .~ .lifetime)
        )
        _ = try await self.waitOfferingsLoaded(viewModel)
        viewModel.selectPlan(.standard)

        // when: 복원으로 lifetime 이 잡힌다 — standard 는 이제 covered.
        // 같은 구독으로 선택 직후 값과 복원 후 값을 함께 관찰해, "복원 완료를 먼저 기다린 뒤
        // 새로 구독"하는 2단계 방식의 타이밍 경합 없이 상태 전이를 그대로 잡아낸다
        viewModel.restore()

        let currentAfter = try await self.waitUntil(viewModel.currentPlan) { $0 == .lifetime }
        #expect(currentAfter == .some(.lifetime))

        let selectedAfter = try await self.waitUntil(viewModel.selectedPlanId) { $0 == nil }
        // then: 선택 직후엔 standard, 복원 후엔 covered 라 무효화된다
        #expect(selectedAfter == .some(nil))

        // and: purchase() 를 눌러도 청구를 시도하지 않는다
        viewModel.purchase()
        #expect(stub.didPurchasedProductId == nil)
        #expect(router.didClosed == nil)
    }
}


// MARK: - 복원 (I4)

extension PaywallViewModelImpleTests {

    @Test func viewModel_restore_whenPurchaseFound_showsRestoredToast() async throws {
        // given
        let (viewModel, stub, router) = self.makeViewModel(
            restoreResult: .applied(BillingUserPlan() |> \.planId .~ .standard)
        )

        // when
        try await self.waitProcessingCompleted(viewModel) { viewModel.restore() }

        // then
        #expect(stub.didRestoreCalled == true)
        #expect(router.didShowToastWithMessage == "billing::paywall::restored".localized())
    }

    @Test func viewModel_restore_whenNothingToRestore_showsEmptyGuide() async throws {
        // given: 복원할 구매가 없음
        let (viewModel, stub, router) = self.makeViewModel(restoreResult: .nothingToRestore)

        // when
        try await self.waitProcessingCompleted(viewModel) { viewModel.restore() }

        // then
        #expect(stub.didRestoreCalled == true)
        #expect(router.didShowToastWithMessage == "billing::paywall::restore::empty".localized())
    }

    // App Store 로그인 시트를 닫은 것뿐 — 토스트도 다이얼로그도 남지 않는다
    @Test func viewModel_restore_whenUserCancelled_showsNothing() async throws {
        // given
        let (viewModel, stub, router) = self.makeViewModel(restoreResult: .cancelled)

        // when
        try await self.waitProcessingCompleted(viewModel) { viewModel.restore() }

        // then
        #expect(stub.didRestoreCalled == true)
        #expect(router.didShowToastWithMessage == nil)
        #expect(router.didShowConfirmWith == nil)
    }

    // I4 회귀 — 진행 중 재호출은 무시된다(AppStore.sync() 병렬 실행 방지).
    // 가드가 없다면 두 번째 호출도 곧바로 true 를 재전송해 (false, true, true) 로 3회가
    // 동기적으로 채워지고, 첫 호출의 완료(defer 의 false)를 기다리지 않게 된다
    @Test func viewModel_restore_whenAlreadyInProgress_ignoresDuplicateCall() async throws {
        // given
        let (viewModel, _, _) = self.makeViewModel(
            restoreResult: .applied(BillingUserPlan() |> \.planId .~ .standard)
        )

        // when
        let expect = expectConfirm("재호출 무시")
        expect.count = 3
        let states = try await self.outputs(expect, for: viewModel.isPurchasing) {
            viewModel.restore()
            viewModel.restore()
        }

        // then: 세 번째 값이 첫 호출 Task 완료의 false 다 — 두 번째 호출이 별도로
        // true 를 재전송하지 않았다
        #expect(states == [false, true, false])
    }

    // 애플 ID 는 같고 앱 계정이 다른 복원 — 기다리면 반영된다고 안내하면 거짓말이 된다
    @Test func viewModel_restore_whenOwnedByAnotherAccount_showsOwnershipGuide() async throws {
        // given
        let serverError = ServerErrorModel() |> \.code .~ .transactionOwnedByAnotherAccount
        let (viewModel, _, router) = self.makeViewModel(
            restoreError: BillingReflectFailure(serverError)
        )

        // when
        try await self.waitProcessingCompleted(viewModel) { viewModel.restore() }

        // then
        #expect(
            router.didShowConfirmWith?.message
                == "billing::paywall::fail::ownedByAnotherAccount".localized()
        )
    }

    @Test func viewModel_restore_whenServerReflectFails_showsDelayedMessage() async throws {
        // given
        let (viewModel, _, router) = self.makeViewModel(
            restoreError: BillingReflectFailure(RuntimeError("network down"))
        )

        // when
        try await self.waitProcessingCompleted(viewModel) { viewModel.restore() }

        // then
        #expect(
            router.didShowConfirmWith?.message
                == "billing::paywall::fail::reflectDelayed".localized()
        )
    }
}


// MARK: - 화면 렌더 게이트 (유저 플랜 조회, #739)

extension PaywallViewModelImpleTests {

    @Test func viewModel_beforePrepared_screenStateIsLoading() async throws {
        // given
        let (viewModel, _, _) = self.makeViewModel()

        // when
        let expect = expectConfirm("초기 상태")
        let state = try await self.firstOutput(expect, for: viewModel.screenState)

        // then
        #expect(state == .loading)
    }

    // 유저 플랜 조회(refreshUserPlan) 실패 → 전면 에러 상태로 게이트가 막힌다.
    // 카탈로그 조회는 기본(성공)이라 두 축이 독립적으로 판정됨을 함께 확인
    @Test func viewModel_whenUserPlanLoadFails_screenStateIsUserPlanLoadFailed() async throws {
        // given
        let (viewModel, _, _) = self.makeViewModel(userPlanLoadError: TestError())

        // when — 초기 .loading + 최종 .userPlanLoadFailed(카탈로그 축 변화는 같은 결과라 dedupe됨)
        let expect = expectConfirm("유저 플랜 조회 실패")
        expect.count = 2
        let states = try await self.outputs(expect, for: viewModel.screenState) {
            viewModel.prepare()
        }

        // then
        #expect(states.last == .userPlanLoadFailed)
    }

    // 재시도(prepare() 재호출)는 같은 로드를 다시 태워 로딩 상태를 다시 거친다 — 재시도 중엔
    // 이전 실패 화면이 아니라 로딩이 보여야 한다
    @Test func viewModel_retryAfterUserPlanLoadFailed_reentersLoadingBeforeFailingAgain() async throws {
        // given: 첫 prepare()로 실패 상태를 만든다
        let (viewModel, _, _) = self.makeViewModel(userPlanLoadError: TestError())
        let firstExpect = expectConfirm("첫 로드 실패")
        firstExpect.count = 2
        _ = try await self.outputs(firstExpect, for: viewModel.screenState) { viewModel.prepare() }

        // when: 재시도 — 새 구독은 CombineLatest 특성상 직전 정착 상태(.userPlanLoadFailed)를
        // 먼저 리플레이하고, prepare()가 그 뒤로 .loading → .userPlanLoadFailed 순서로 이어진다
        let retryExpect = expectConfirm("재시도")
        retryExpect.count = 3
        let states = try await self.outputs(retryExpect, for: viewModel.screenState) {
            viewModel.prepare()
        }

        // then — 가운데 값이 재시도가 로딩을 다시 거쳤다는 증거
        #expect(states == [.userPlanLoadFailed, .loading, .userPlanLoadFailed])
    }

    // 유저 플랜 조회 성공 + 카탈로그 조회 성공 → 본문이 렌더되는 .ready(.loaded) 로 안착한다.
    // retry 버튼도 prepare() 를 그대로 재호출하므로(EventHandler.retry == onAppear) 이 성공
    // 경로가 "재시도 성공 → 본문 렌더" 계약을 동일하게 검증한다
    @Test func viewModel_whenUserPlanAndCatalogLoadSucceed_screenStateBecomesReady() async throws {
        // given
        let standard = self.purchasableOffering(.standard, productId: "product.standard")
        let (viewModel, _, _) = self.makeViewModel(offerings: [standard])

        // when
        viewModel.prepare()
        let final = try await self.waitScreenState(viewModel) {
            guard case .ready(.loaded) = $0 else { return false }
            return true
        }

        // then
        guard case .ready(.loaded(let offerings)) = final else {
            Issue.record("expected .ready(.loaded) but got \(final)")
            return
        }
        #expect(offerings.map { $0.plan.id } == [.standard])
    }

    // 유저 플랜 조회는 성공했는데 카탈로그만 실패하는 조합 — 화면은 그려지되(.ready) 카탈로그
    // 축만 .failed 로 드러난다. 어느 축이 실패하든 팝업은 띄우지 않는다
    @Test func viewModel_whenUserPlanSucceedsButCatalogFails_screenStateIsReadyWithFailedCatalog() async throws {
        // given
        let (viewModel, _, router) = self.makeViewModel(catalogLoadError: TestError())

        // when
        viewModel.prepare()
        let final = try await self.waitScreenState(viewModel) { $0 == .ready(.failed) }

        // then
        #expect(final == .ready(.failed))
        #expect(router.didShowError == nil)
    }
}


// MARK: - 미완료 결제 복구

extension PaywallViewModelImpleTests {

    @Test("미완료 거래가 있으면 복구 배너를 띄운다")
    func viewModel_whenPrepareWithUnfinishedTransaction_showsRecoveryBanner() async throws {
        // given
        let (viewModel, stub, _) = self.makeViewModel(hasUnfinished: true)

        // when
        let expect = expectConfirm("배너 노출 상태")
        expect.count = 2
        let states = try await self.outputs(expect, for: viewModel.hasUnfinishedTransactions) {
            viewModel.prepare()
        }

        // then
        #expect(states.last == true)
        #expect(stub.didCheckUnfinishedCalled == true)
    }

    @Test("미완료 거래가 없으면 복구 배너를 띄우지 않는다")
    func viewModel_whenPrepareWithoutUnfinishedTransaction_hidesRecoveryBanner() async throws {
        // given
        let (viewModel, stub, _) = self.makeViewModel(hasUnfinished: false)

        // when
        viewModel.prepare()
        await self.waitUnfinishedCheckPerformed(stub)

        // then
        let expect = expectConfirm("배너 미노출 상태")
        let hasUnfinished = try await self.firstOutput(
            expect, for: viewModel.hasUnfinishedTransactions
        )
        #expect(hasUnfinished == false)
        #expect(stub.didCheckUnfinishedCalled == true)
    }

    @Test("복구에 성공하면 배너를 내리고 완료를 알린다")
    func viewModel_whenRecoverUnfinishedSucceed_hidesBannerAndShowToast() async throws {
        // given
        let applied = BillingUserPlan() |> \.planId .~ .lifetime
        let (viewModel, stub, router) = self.makeViewModel(
            hasUnfinished: true, applyUnfinishedResult: .success(applied)
        )
        try await self.waitUnfinishedBannerReady(viewModel)

        // when
        try await self.waitProcessingCompleted(viewModel) { viewModel.recoverUnfinished() }

        // then
        let expect = expectConfirm("배너 내려간 상태")
        let hasUnfinished = try await self.firstOutput(
            expect, for: viewModel.hasUnfinishedTransactions
        )
        #expect(hasUnfinished == false)
        #expect(stub.didApplyUnfinishedTimes == 1)
        #expect(router.didShowToastWithMessage == "billing::paywall::unfinished::applied".localized())
    }

    @Test("다른 경로가 먼저 반영해 큐가 비어 돌아와도 반영 문안을 띄운다")
    func viewModel_whenRecoverUnfinishedReturnsNil_stillHidesBannerAndShowsAppliedToast() async throws {
        // given
        let (viewModel, stub, router) = self.makeViewModel(
            hasUnfinished: true, applyUnfinishedResult: .success(nil)
        )
        try await self.waitUnfinishedBannerReady(viewModel)

        // when
        try await self.waitProcessingCompleted(viewModel) { viewModel.recoverUnfinished() }

        // then
        let expect = expectConfirm("배너 내려간 상태")
        let hasUnfinished = try await self.firstOutput(
            expect, for: viewModel.hasUnfinishedTransactions
        )
        #expect(hasUnfinished == false)
        #expect(stub.didApplyUnfinishedTimes == 1)
        #expect(router.didShowToastWithMessage == "billing::paywall::unfinished::applied".localized())
    }

    @Test("복구에 실패하면 배너를 유지하고 반영 지연을 알린다")
    func viewModel_whenRecoverUnfinishedFails_keepsBannerAndShowsDelayedMessage() async throws {
        // given
        let (viewModel, _, router) = self.makeViewModel(
            hasUnfinished: true,
            applyUnfinishedResult: .failure(BillingReflectFailure(RuntimeError("failed")))
        )
        try await self.waitUnfinishedBannerReady(viewModel)

        // when
        try await self.waitProcessingCompleted(viewModel) { viewModel.recoverUnfinished() }

        // then
        let expect = expectConfirm("배너 유지 상태")
        let hasUnfinished = try await self.firstOutput(
            expect, for: viewModel.hasUnfinishedTransactions
        )
        #expect(hasUnfinished == true)
        #expect(
            router.didShowConfirmWith?.message
                == "billing::paywall::fail::reflectDelayed".localized()
        )
    }

    @Test("복구가 진행 중이면 연타해도 한 번만 반영한다")
    func viewModel_whenRecoverUnfinishedRepeatedly_appliesOnlyOnce() async throws {
        // given
        let (viewModel, stub, _) = self.makeViewModel(hasUnfinished: true)

        // when
        let expect = expectConfirm("연타 무시")
        expect.count = 3
        let states = try await self.outputs(expect, for: viewModel.isPurchasing) {
            viewModel.recoverUnfinished()
            viewModel.recoverUnfinished()
        }

        // then
        #expect(states == [false, true, false])
        #expect(stub.didApplyUnfinishedTimes == 1)
    }
}


// MARK: - 구독 관리 진입점 노출 조건

extension PaywallViewModelImpleTests {

    private func makeViewModelWithPlan(
        _ planId: BillingPlanId, kind: BillingProductKind?
    ) -> (PaywallViewModelImple, StubBillingUsecase, SpyPaywallRouter) {
        let offering = self.purchasableOffering(planId, productId: "product.\(planId)", kind: kind)
        let userPlan = BillingUserPlan() |> \.planId .~ planId
        return self.makeViewModel(offerings: [offering], userPlan: userPlan)
    }

    @Test("자동 갱신 구독을 보유하면 구독 관리 진입점이 노출된다")
    func viewModel_whenPlanIsSubscription_showsManageSubscription() async throws {
        // given
        let (viewModel, _, _) = self.makeViewModelWithPlan(
            .standard, kind: .subscription(period: .monthly)
        )

        // when
        _ = try await self.waitOfferingsLoaded(viewModel)
        let expect = expectConfirm("노출 여부 방출")
        let shows = try await self.firstOutput(expect, for: viewModel.showsManageSubscription)

        // then
        #expect(shows == true)
    }

    @Test("평생(1회 결제) 플랜은 구독 관리 진입점이 노출되지 않는다")
    func viewModel_whenPlanIsOneTime_hidesManageSubscription() async throws {
        // given
        let (viewModel, _, _) = self.makeViewModelWithPlan(.lifetime, kind: .oneTime)

        // when
        _ = try await self.waitOfferingsLoaded(viewModel)
        let expect = expectConfirm("노출 여부 방출")
        let shows = try await self.firstOutput(expect, for: viewModel.showsManageSubscription)

        // then
        #expect(shows == false)
    }

    @Test("스토어 상품을 못 받았으면 구독 관리 진입점이 노출되지 않는다")
    func viewModel_whenStoreProductMissing_hidesManageSubscription() async throws {
        // given
        let (viewModel, _, _) = self.makeViewModelWithPlan(.standard, kind: nil)

        // when
        _ = try await self.waitOfferingsLoaded(viewModel)
        let expect = expectConfirm("노출 여부 방출")
        let shows = try await self.firstOutput(expect, for: viewModel.showsManageSubscription)

        // then
        #expect(shows == false)
    }

    @Test("구독 관리를 탭하면 라우터에 관리 시트를 요청한다")
    func viewModel_manageSubscription_requestsSheetToRouter() async throws {
        // given
        let (viewModel, _, router) = self.makeViewModel()

        // when
        viewModel.manageSubscription()

        // then
        #expect(router.didShowManageSubscriptions == true)
    }

    @Test("관리 시트가 닫히면 유저 플랜을 재조회한다")
    func viewModel_whenManageSubscriptionSheetDismissed_refreshesUserPlan() async throws {
        // given
        let (viewModel, stub, router) = self.makeViewModel()

        // when
        viewModel.manageSubscription()
        router.didShowManageSubscriptionsWithDismissed?()

        // then
        _ = try await self.waitUntil(
            stub.didRefreshUserPlanPublisher, matching: { $0 }
        )
        #expect(stub.didRefreshUserPlanCalled == true)
    }
}
