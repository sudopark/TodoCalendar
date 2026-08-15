//
//  PaywallViewModel.swift
//  BillingScenes
//
//  Created by sudo.park on 8/3/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Extensions
import Scenes
import CommonPresentation


// MARK: - 표시 모델

struct PaywallPlanCellModel: Equatable {

    let planId: BillingPlanId
    let name: String
    let priceText: String?
    // "/월" 같은 주기 꼬리표. 1회 결제·주기 불명이면 nil
    let periodText: String?
    let metricText: String
    let isOwned: Bool
    let isCovered: Bool
    let isRecommended: Bool

    var isPurchasable: Bool { self.isCovered == false && self.priceText != nil }
}

struct PaywallPlanDetailModel: Equatable {

    let sectionTitle: String
    let features: [String]
    let disclosure: String
    let ctaTitle: String
}

struct PaywallTopupCellModel: Equatable {

    let productId: String
    let creditsText: String
    let priceText: String
    // 보너스가 없는 tier 는 nil
    let bonusText: String?
}


// MARK: - 카탈로그 로딩 상태

enum PaywallCatalogState: Equatable {
    case loading
    case failed
    case loaded([BillingPlanOffering])
}


// MARK: - 화면 렌더 게이트

enum PaywallUserPlanLoadState: Equatable {
    case loading
    case failed
    case loaded
}

enum PaywallScreenState: Equatable {
    case loading
    case userPlanLoadFailed
    case ready(PaywallCatalogState)
}


// MARK: - PaywallViewModel

protocol PaywallViewModel: AnyObject, Sendable, PaywallSceneInteractor {

    // event
    func prepare()
    func selectPlan(_ planId: BillingPlanId)
    func purchase()
    func purchaseTopup(_ productId: String)
    func restore()
    func recoverUnfinished()
    func manageSubscription()
    func openTerms()
    func openPrivacyPolicy()
    func close()

    // presenter
    var currentPlan: AnyPublisher<BillingPlanId?, Never> { get }
    var currentPlanDescription: AnyPublisher<String, Never> { get }
    var scheduledChange: AnyPublisher<BillingUserPlan.ScheduledChange?, Never> { get }
    var screenState: AnyPublisher<PaywallScreenState, Never> { get }
    var catalogState: AnyPublisher<PaywallCatalogState, Never> { get }
    var cellModels: AnyPublisher<[PaywallPlanCellModel], Never> { get }
    var topupCellModels: AnyPublisher<[PaywallTopupCellModel], Never> { get }
    var selectedPlanId: AnyPublisher<BillingPlanId?, Never> { get }
    var selectedPlanDetail: AnyPublisher<PaywallPlanDetailModel?, Never> { get }
    var isPurchasing: AnyPublisher<Bool, Never> { get }
    var hasUnfinishedTransactions: AnyPublisher<Bool, Never> { get }
    var showsManageSubscription: AnyPublisher<Bool, Never> { get }
}


// MARK: - PaywallViewModelImple

final class PaywallViewModelImple: PaywallViewModel, @unchecked Sendable {

    private let billingUsecase: any BillingUsecase
    private let closesAfterPurchase: Bool
    var router: (any PaywallRouting)?

    private struct Subject {
        let catalogState = CurrentValueSubject<PaywallCatalogState, Never>(.loading)
        let userPlanState = CurrentValueSubject<PaywallUserPlanLoadState, Never>(.loading)
        let currentPlanId = CurrentValueSubject<BillingPlanId?, Never>(nil)
        let scheduledChange = CurrentValueSubject<BillingUserPlan.ScheduledChange?, Never>(nil)
        let userSelectedPlanId = CurrentValueSubject<BillingPlanId?, Never>(nil)
        let isPurchasing = CurrentValueSubject<Bool, Never>(false)
        let hasUnfinished = CurrentValueSubject<Bool, Never>(false)
        let topupOfferings = CurrentValueSubject<[BillingTopupOffering], Never>([])
    }
    private let subject = Subject()
    private var cancellables: Set<AnyCancellable> = []

    private func currentOfferings(_ state: PaywallCatalogState) -> [BillingPlanOffering] {
        guard case .loaded(let offerings) = state else { return [] }
        return offerings
    }

    init(billingUsecase: any BillingUsecase, closesAfterPurchase: Bool) {
        self.billingUsecase = billingUsecase
        self.closesAfterPurchase = closesAfterPurchase
        self.billingUsecase.currentUserPlan
            .sink { [weak self] userPlan in
                self?.subject.currentPlanId.send(userPlan.planId)
                self?.subject.scheduledChange.send(userPlan.scheduledChange)
            }
            .store(in: &self.cancellables)
    }
}


// MARK: - actions

extension PaywallViewModelImple {

    func prepare() {
        self.subject.userPlanState.send(.loading)
        self.subject.catalogState.send(.loading)
        Task { [weak self] in
            guard let self else { return }
            async let planLoad: Void = self.loadUserPlan()
            async let catalogLoad: Void = self.loadCatalog()
            async let unfinishedLoad: Void = self.loadUnfinishedState()
            async let topupLoad: Void = self.loadTopupCatalog()
            _ = await (planLoad, catalogLoad, unfinishedLoad, topupLoad)
        }
    }

    private func loadUserPlan() async {
        do {
            try await self.billingUsecase.refreshUserPlan()
            self.subject.userPlanState.send(.loaded)
        } catch {
            self.subject.userPlanState.send(.failed)
        }
    }

    private func loadCatalog() async {
        do {
            let offerings = try await self.billingUsecase.loadPlanOfferings()
            self.subject.catalogState.send(.loaded(offerings))
        } catch {
            self.subject.catalogState.send(.failed)
        }
    }

    private func loadUnfinishedState() async {
        let hasUnfinished = await self.billingUsecase.hasUnfinishedTransactions()
        self.subject.hasUnfinished.send(hasUnfinished)
    }

    // top-up 은 부가 기능이라 조회 실패가 화면을 막지 않는다 — 섹션만 빠진다
    private func loadTopupCatalog() async {
        let offerings = (try? await self.billingUsecase.loadTopupOfferings()) ?? []
        self.subject.topupOfferings.send(offerings)
    }

    func selectPlan(_ planId: BillingPlanId) {
        let offerings = self.currentOfferings(self.subject.catalogState.value)
        // 구매 불가(보유·커버됨·가격 없음) 카드는 탭 무시
        guard let offering = offerings.first(where: { $0.plan.id == planId }),
              self.isPurchasable(offering, currentPlanId: self.subject.currentPlanId.value)
        else { return }
        self.subject.userSelectedPlanId.send(planId)
    }

    func purchase() {
        let offerings = self.currentOfferings(self.subject.catalogState.value)
        guard let planId = self.resolvedSelectedPlanId(
                  userSelected: self.subject.userSelectedPlanId.value,
                  currentPlanId: self.subject.currentPlanId.value,
                  offerings: offerings
              ),
              let offering = offerings.first(where: { $0.plan.id == planId }),
              offering.product != nil,
              let productId = offering.plan.productId
        else { return }

        self.subject.isPurchasing.send(true)
        Task { [weak self] in
            guard let self else { return }
            defer { self.subject.isPurchasing.send(false) }
            do {
                switch try await self.billingUsecase.purchase(productId: productId) {
                case .applied:
                    self.router?.showToast("billing::paywall::purchase::applied".localized())
                    self.closeAfterPurchaseIfNeeded()

                case .cancelled:
                    break   // 유저 취소 — 조용히 닫기(시트 유지)

                case .pending:
                    self.showPendingDialog()
                }
            } catch {
                self.showFailure(error)
            }
        }
    }

    func purchaseTopup(_ productId: String) {
        guard self.subject.isPurchasing.value == false else { return }
        self.subject.isPurchasing.send(true)
        Task { [weak self] in
            guard let self else { return }
            defer { self.subject.isPurchasing.send(false) }
            do {
                switch try await self.billingUsecase.purchase(productId: productId) {
                case .applied:
                    self.router?.showToast("billing::paywall::topup::applied".localized())
                    self.closeAfterPurchaseIfNeeded()

                case .cancelled:
                    break

                case .pending:
                    self.showPendingDialog()
                }
            } catch {
                self.showFailure(error)
            }
        }
    }

    func restore() {
        // AppStore.sync() 는 시스템 로그인 시트를 띄우고 수 초 걸린다 — purchase() 와 같은
        // isPurchasing 신호로 재진입을 막지 않으면 연타 시 sync() 가 병렬로 돈다 (I4, #739)
        guard self.subject.isPurchasing.value == false else { return }
        self.subject.isPurchasing.send(true)
        Task { [weak self] in
            guard let self else { return }
            defer { self.subject.isPurchasing.send(false) }
            do {
                switch try await self.billingUsecase.restorePurchases() {
                case .applied:
                    self.router?.showToast("billing::paywall::restored".localized())

                case .nothingToRestore:
                    self.router?.showToast("billing::paywall::restore::empty".localized())

                case .cancelled:
                    break
                }
            } catch {
                self.showFailure(error)
            }
        }
    }

    func recoverUnfinished() {
        guard self.subject.isPurchasing.value == false else { return }
        self.subject.isPurchasing.send(true)
        Task { [weak self] in
            guard let self else { return }
            defer { self.subject.isPurchasing.send(false) }
            do {
                _ = try await self.billingUsecase.applyUnfinishedTransactions()
                self.subject.hasUnfinished.send(false)
                self.router?.showToast("billing::paywall::unfinished::applied".localized())
            } catch {
                self.showFailure(error)
            }
        }
    }

    func manageSubscription() {
        self.router?.showManageSubscriptions { [weak self] in
            self?.reloadUserPlanAfterManage()
        }
    }

    // 시트에서 취소·플랜 변경을 했는지 앱은 알 수 없다 — 서버 원장이 정본이라 닫히면 다시 묻는다.
    // 실패는 알리지 않는다. paywall 재진입이 같은 조회를 다시 돌린다
    private func reloadUserPlanAfterManage() {
        Task { [weak self] in
            _ = try? await self?.billingUsecase.refreshUserPlan()
        }
    }

    func openTerms() {
        self.router?.showWebView(LegalLink.termsPath)
    }

    func openPrivacyPolicy() {
        self.router?.showWebView(LegalLink.privacyPolicyPath)
    }

    func close() {
        self.router?.closeScene()
    }

    // 반영 결과는 currentUserPlan 릴레이가 화면에 흘려보낸다 — 남는 판단은 닫을지 말지뿐이다
    private func closeAfterPurchaseIfNeeded() {
        guard self.closesAfterPurchase else { return }
        self.router?.closeScene()
    }

    private func showPendingDialog() {
        let info = ConfirmDialogInfo()
            |> \.title .~ "billing::paywall::pending::title".localized()
            |> \.message .~ "billing::paywall::pending::message".localized()
            |> \.withCancel .~ false
        self.router?.showConfirm(dialog: info)
    }

    private func showFailure(_ error: any Error) {
        guard let reason = PaywallFailReason(error) else { return }
        logger.log(level: .error, "paywall action failed: \(error)")
        let info = ConfirmDialogInfo()
            |> \.message .~ pure(reason.message)
            |> \.withCancel .~ false
        self.router?.showConfirm(dialog: info)
    }
}


// MARK: - outputs

extension PaywallViewModelImple {

    var currentPlan: AnyPublisher<BillingPlanId?, Never> {
        return self.currentPlanIdPublisher
    }

    var currentPlanDescription: AnyPublisher<String, Never> {
        return Publishers.CombineLatest(self.currentPlanIdPublisher, self.offeringsPublisher)
            .map { [weak self] currentPlanId, offerings -> String in
                self?.currentPlanDescriptionText(planId: currentPlanId, offerings: offerings) ?? ""
            }
            .eraseToAnyPublisher()
    }

    var scheduledChange: AnyPublisher<BillingUserPlan.ScheduledChange?, Never> {
        return self.subject.scheduledChange.removeDuplicates().eraseToAnyPublisher()
    }

    var catalogState: AnyPublisher<PaywallCatalogState, Never> {
        return self.catalogStatePublisher
    }

    var screenState: AnyPublisher<PaywallScreenState, Never> {
        return Publishers.CombineLatest(self.subject.userPlanState, self.catalogStatePublisher)
            .map { [weak self] userPlanState, catalogState -> PaywallScreenState in
                self?.resolveScreenState(userPlanState: userPlanState, catalogState: catalogState) ?? .loading
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var cellModels: AnyPublisher<[PaywallPlanCellModel], Never> {
        return Publishers.CombineLatest(self.currentPlanIdPublisher, self.offeringsPublisher)
            .map { [weak self] currentPlanId, offerings -> [PaywallPlanCellModel] in
                self?.makeCellModels(currentPlanId: currentPlanId, offerings: offerings) ?? []
            }
            .eraseToAnyPublisher()
    }

    var topupCellModels: AnyPublisher<[PaywallTopupCellModel], Never> {
        return Publishers.CombineLatest3(
            self.currentPlanIdPublisher, self.offeringsPublisher, self.subject.topupOfferings
        )
        .map { [weak self] currentPlanId, planOfferings, topupOfferings -> [PaywallTopupCellModel] in
            self?.makeTopupCellModels(
                currentPlanId: currentPlanId,
                planOfferings: planOfferings,
                topupOfferings: topupOfferings
            ) ?? []
        }
        .removeDuplicates()
        .eraseToAnyPublisher()
    }

    var selectedPlanId: AnyPublisher<BillingPlanId?, Never> {
        return Publishers.CombineLatest3(
            self.subject.userSelectedPlanId, self.currentPlanIdPublisher, self.offeringsPublisher
        )
        // self?.resolve(...) ?? userSelected 로 쓰면 "self 가 nil" 과 "선택이 무효라 nil" 이
        // 같은 nil 로 뭉개져, 커버된 선택이 userSelected 로 되살아난다 (C1, #739)
        .map { [weak self] userSelected, currentPlanId, offerings -> BillingPlanId? in
            guard let self else { return userSelected }
            return self.resolvedSelectedPlanId(
                userSelected: userSelected, currentPlanId: currentPlanId, offerings: offerings
            )
        }
        .eraseToAnyPublisher()
    }

    var selectedPlanDetail: AnyPublisher<PaywallPlanDetailModel?, Never> {
        return Publishers.CombineLatest(self.selectedPlanId, self.offeringsPublisher)
            .map { [weak self] planId, offerings -> PaywallPlanDetailModel? in
                guard let self, let planId,
                      let offering = offerings.first(where: { $0.plan.id == planId })
                else { return nil }
                return self.detail(of: offering)
            }
            .eraseToAnyPublisher()
    }

    var isPurchasing: AnyPublisher<Bool, Never> {
        return self.subject.isPurchasing.eraseToAnyPublisher()
    }

    var hasUnfinishedTransactions: AnyPublisher<Bool, Never> {
        return self.subject.hasUnfinished.removeDuplicates().eraseToAnyPublisher()
    }

    var showsManageSubscription: AnyPublisher<Bool, Never> {
        return Publishers.CombineLatest(self.currentPlanIdPublisher, self.offeringsPublisher)
            .map { [weak self] currentPlanId, offerings -> Bool in
                self?.isSubscribedPlan(currentPlanId, offerings: offerings) ?? false
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    private var catalogStatePublisher: AnyPublisher<PaywallCatalogState, Never> {
        return self.subject.catalogState.removeDuplicates().eraseToAnyPublisher()
    }

    private var currentPlanIdPublisher: AnyPublisher<BillingPlanId?, Never> {
        return self.subject.currentPlanId.removeDuplicates().eraseToAnyPublisher()
    }

    private var offeringsPublisher: AnyPublisher<[BillingPlanOffering], Never> {
        return self.catalogStatePublisher
            .map { [weak self] in self?.currentOfferings($0) ?? [] }
            .eraseToAnyPublisher()
    }
}


// MARK: - 표시 모델 조립

extension PaywallViewModelImple {

    private func resolveScreenState(
        userPlanState: PaywallUserPlanLoadState, catalogState: PaywallCatalogState
    ) -> PaywallScreenState {
        switch userPlanState {
        case .loading: return .loading
        case .failed: return .userPlanLoadFailed
        case .loaded: return .ready(catalogState)
        }
    }

    private func makeCellModels(
        currentPlanId: BillingPlanId?, offerings: [BillingPlanOffering]
    ) -> [PaywallPlanCellModel] {
        let effectiveCurrentId = currentPlanId ?? .free
        return offerings
            .filter { $0.plan.productId != nil }
            .map { offering in
                PaywallPlanCellModel(
                    planId: offering.plan.id,
                    name: offering.plan.id.name,
                    priceText: offering.product?.displayPrice,
                    periodText: self.periodText(of: offering.product?.kind),
                    metricText: "billing::paywall::metric::dailyCredits"
                        .localized(with: offering.plan.dailyLimit.formatted()),
                    isOwned: offering.plan.id == currentPlanId,
                    isCovered: effectiveCurrentId.covers(offering.plan.id),
                    isRecommended: offering.plan.id == .standard
                )
            }
    }

    // 살 수 있느냐는 서버 카탈로그가 답한다 — 플랜을 못 찾으면 노출하지 않는다(fail-closed)
    private func makeTopupCellModels(
        currentPlanId: BillingPlanId?,
        planOfferings: [BillingPlanOffering],
        topupOfferings: [BillingTopupOffering]
    ) -> [PaywallTopupCellModel] {
        let effectiveCurrentId = currentPlanId ?? .free
        let isAllowed = planOfferings
            .first(where: { $0.plan.id == effectiveCurrentId })?
            .plan.isTopupAllowed ?? false
        guard isAllowed else { return [] }
        return topupOfferings.compactMap { self.topupCellModel(of: $0) }
    }

    private func topupCellModel(of offering: BillingTopupOffering) -> PaywallTopupCellModel? {
        guard let price = offering.product?.displayPrice else { return nil }
        return PaywallTopupCellModel(
            productId: offering.topup.productId,
            creditsText: self.creditsText(of: offering.topup),
            priceText: price,
            bonusText: self.bonusText(of: offering.topup.bonusRate)
        )
    }

    private func creditsText(of topup: BillingTopup) -> String {
        guard topup.bonusRate > 0 else {
            return "billing::paywall::topup::credits".localized(with: topup.totalCredits.formatted())
        }
        let bonusCredits = topup.totalCredits - topup.credits
        return "billing::paywall::topup::credits::split"
            .localized(with: topup.credits.formatted(), bonusCredits.formatted())
    }

    private func bonusText(of rate: Double) -> String? {
        guard rate > 0 else { return nil }
        let percent = Int((rate * 100).rounded())
        return "billing::paywall::topup::bonus".localized(with: percent.formatted())
    }

    private func periodText(of kind: BillingProductKind?) -> String? {
        guard case .subscription(let period) = kind, let period else { return nil }
        switch period {
        case .weekly:  return "billing::paywall::period::weekly".localized()
        case .monthly: return "billing::paywall::period::monthly".localized()
        case .yearly:  return "billing::paywall::period::yearly".localized()
        }
    }

    private func currentPlanDescriptionText(
        planId: BillingPlanId?, offerings: [BillingPlanOffering]
    ) -> String {
        let effectiveId = planId ?? .free
        guard let plan = offerings.first(where: { $0.plan.id == effectiveId })?.plan else {
            return ""
        }
        return "billing::paywall::current::description".localized(with: plan.dailyLimit.formatted())
    }

    private func resolvedSelectedPlanId(
        userSelected: BillingPlanId?, currentPlanId: BillingPlanId?, offerings: [BillingPlanOffering]
    ) -> BillingPlanId? {
        let purchasables = offerings.filter { self.isPurchasable($0, currentPlanId: currentPlanId) }
        if let userSelected, purchasables.contains(where: { $0.plan.id == userSelected }) {
            return userSelected
        }
        return purchasables.first?.plan.id
    }

    // 구매 가능 판정의 유일한 소스 — 셀 모델(표시용 문자열까지 만드는)과 선택 해석이 함께 쓴다
    private func isPurchasable(
        _ offering: BillingPlanOffering, currentPlanId: BillingPlanId?
    ) -> Bool {
        // 미배포·미로그인 상태는 free 로 취급 — free 는 아무 유료 플랜도 커버하지 않는다
        let effectiveCurrentId = currentPlanId ?? .free
        return offering.plan.productId != nil
            && offering.product?.displayPrice != nil
            && effectiveCurrentId.covers(offering.plan.id) == false
    }

    // 평생(1회 결제)·무료는 애플 관리 시트에 표시될 항목이 없다 — 자동 갱신 구독만 진입시킨다
    private func isSubscribedPlan(
        _ planId: BillingPlanId?, offerings: [BillingPlanOffering]
    ) -> Bool {
        let kind = offerings.first(where: { $0.plan.id == planId })?.product?.kind
        guard case .subscription = kind else { return false }
        return true
    }

    private func detail(of offering: BillingPlanOffering) -> PaywallPlanDetailModel {
        let kind = offering.product?.kind
        return PaywallPlanDetailModel(
            sectionTitle: "billing::paywall::features::title".localized(with: offering.plan.id.name),
            features: self.features(of: offering.plan),
            disclosure: self.disclosureText(for: kind),
            ctaTitle: self.ctaTitle(for: kind, planName: offering.plan.id.name)
        )
    }

    private func disclosureText(for kind: BillingProductKind?) -> String {
        guard let kind else {
            return "billing::paywall::disclosure::storeUnavailable".localized()
        }
        switch kind {
        case .subscription(let period):
            return self.subscriptionDisclosureKey(for: period).localized()
        case .oneTime:
            return "billing::paywall::disclosure::oneTime".localized()
        }
    }

    // 월간(monthly)만 기존 키를 쓴다 — "매월 자동 갱신됩니다"가 정확한 유일한 주기라서다.
    // 주·년 구독이나 변칙 주기(period == nil)에 같은 키를 쓰면 연간 상품에 "매월"이 붙어
    // 구독 기간을 잘못 표기하게 된다 — App Store 리젝 사유(C2, #739). 카탈로그가 지금은
    // monthly 하나뿐이라 당장 드러나진 않지만, 서버가 연간 플랜을 추가하는 순간 이 분기가
    // 코드 변경 없이 올바른 문구로 갈린다
    private func subscriptionDisclosureKey(for period: BillingSubscriptionPeriod?) -> String {
        guard period == .monthly else {
            return "billing::paywall::disclosure::subscription::generic"
        }
        return "billing::paywall::disclosure::subscription"
    }

    private func ctaTitle(for kind: BillingProductKind?, planName: String) -> String {
        guard case .subscription = kind else {
            return "billing::paywall::cta::buy".localized(with: planName)
        }
        return "billing::paywall::cta::subscribe".localized(with: planName)
    }

    private func features(of plan: BillingPlan) -> [String] {
        return [
            "billing::paywall::feature::dailyCredits".localized(with: plan.dailyLimit.formatted()),
            plan.isTopupAllowed ? "billing::paywall::feature::topup".localized() : nil
        ].compactMap { $0 }
    }
}
