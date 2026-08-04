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
import Scenes
import CommonPresentation


// MARK: - 표시 모델

struct PaywallPlanCellModel: Equatable {

    let planId: BillingPlanId
    let name: String
    // 스토어 조회 실패 시 nil — 화면이 안내 문구로 대체하고 구매를 막는다
    let priceText: String?
    // "/월" 같은 주기 꼬리표. 1회 결제·주기 불명이면 nil
    let periodText: String?
    let metricText: String
    // 정확히 지금 쓰고 있는 플랜 — "이용 중" 배지 표시 전용. 구매 가능 여부 판정에는 안 쓴다
    let isOwned: Bool
    // 지금 보유한 플랜이 이 플랜과 같거나 상위 등급이라 구매가 불필요함(BillingPlanId.covers)
    // — lifetime 보유자에게 standard 카드가 구매 가능으로 뜨는 걸 막는 판정이 여기 있다 (#739)
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


// MARK: - 카탈로그 로딩 상태

// selectedPlanDetail == nil 하나로 "아직 안 불러옴"·"로드 실패"·"구매 가능 플랜 없음"을 겸하지
// 않기 위한 명시 상태. View 가 이 값으로 세 갈래(loading/failed/loaded)를 가른다 (#739)
enum PaywallCatalogState: Equatable {
    case loading
    case failed
    case loaded([BillingPlanOffering])
}


// MARK: - 화면 렌더 게이트

// 유저 플랜 조회 상태 — currentPlanId(SharedDataStore 미러링)만으로는 "이번 prepare()에서
// refreshUserPlan()이 성공했는지"를 구분할 수 없다(과거 캐시된 값일 수 있어서). 화면 렌더
// 게이트 전용으로 별도 축을 둔다 (#739)
enum PaywallUserPlanLoadState: Equatable {
    case loading
    case failed
    case loaded
}

// 화면 전체 렌더 게이트 — userPlanState가 loaded여야만 본문(플랜 카드·CTA·고지문)을 그린다.
// catalogState(카탈로그 축)는 유저 플랜이 확인된 뒤에만 의미가 있어 .ready 안에 실린다.
// 두 축을 mutable var로 손으로 합치지 않고 CombineLatest로 선언적으로 합성한다
// (여러 상태 합성은 선언적으로 — presentations-rules.md §5, #739)
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
    func restore()
    func openTerms()
    func openPrivacyPolicy()
    func close()

    // presenter
    var currentPlan: AnyPublisher<BillingPlanId?, Never> { get }
    var currentPlanDescription: AnyPublisher<String, Never> { get }
    var screenState: AnyPublisher<PaywallScreenState, Never> { get }
    var catalogState: AnyPublisher<PaywallCatalogState, Never> { get }
    var cellModels: AnyPublisher<[PaywallPlanCellModel], Never> { get }
    var selectedPlanId: AnyPublisher<BillingPlanId?, Never> { get }
    var selectedPlanDetail: AnyPublisher<PaywallPlanDetailModel?, Never> { get }
    var isPurchasing: AnyPublisher<Bool, Never> { get }
}


// MARK: - PaywallViewModelImple

final class PaywallViewModelImple: PaywallViewModel, @unchecked Sendable {

    private let billingUsecase: any BillingUsecase
    var router: (any PaywallRouting)?

    private struct Subject {
        let catalogState = CurrentValueSubject<PaywallCatalogState, Never>(.loading)
        // 화면 렌더 게이트 축 — prepare()의 refreshUserPlan() 결과만 반영. currentPlanId와
        // 별개다(과거 캐시값과 이번 조회 성공을 구분해야 해서, #739)
        let userPlanState = CurrentValueSubject<PaywallUserPlanLoadState, Never>(.loading)
        // billingUsecase.currentUserPlan(비동기 스트림)을 동기로 들여다볼 수 있게 로컬 미러링
        // — selectPlan()/purchase() 같은 command가 "지금 보유 플랜이 뭔지"를 즉시 참조해야 한다
        let currentPlanId = CurrentValueSubject<BillingPlanId?, Never>(nil)
        // 유저가 명시적으로 고른 플랜. nil이면 defaultSelection(첫 구매가능 셀)이 대신한다
        let userSelectedPlanId = CurrentValueSubject<BillingPlanId?, Never>(nil)
        let isPurchasing = CurrentValueSubject<Bool, Never>(false)
    }
    private let subject = Subject()
    private var cancellables: Set<AnyCancellable> = []

    // catalogState 가 .loaded 가 아니면(로딩/실패) 구매 대상 오퍼링이 없다 — 두 곳(command 의
    // 동기 조회, publisher 합성)이 같은 판정을 쓰도록 한 곳에 모은다
    private func currentOfferings(_ state: PaywallCatalogState) -> [BillingPlanOffering] {
        guard case .loaded(let offerings) = state else { return [] }
        return offerings
    }

    init(billingUsecase: any BillingUsecase) {
        self.billingUsecase = billingUsecase
        self.billingUsecase.currentUserPlan
            .map { $0.planId }
            .sink { [weak self] planId in self?.subject.currentPlanId.send(planId) }
            .store(in: &self.cancellables)
    }
}


// MARK: - actions

extension PaywallViewModelImple {

    // 유저 플랜 재조회(refreshUserPlan)와 카탈로그 조회(loadPlanOfferings)를 동시에 태운다.
    // 전자가 화면 전체 렌더 게이트(screenState)이고 후자는 게이트 통과 후에만 의미가 있는
    // 하위 축이라 서로 값을 참조하지 않는 독립 실행 — async let으로 병렬화 (#739)
    func prepare() {
        self.subject.userPlanState.send(.loading)
        self.subject.catalogState.send(.loading)
        Task { [weak self] in
            guard let self else { return }
            async let planLoad: Void = self.loadUserPlan()
            async let catalogLoad: Void = self.loadCatalog()
            _ = await (planLoad, catalogLoad)
        }
    }

    // 실패해도 router.showError로 알리지 않는다 — 전면 에러 상태(screenState)가 이미 실패를
    // 드러내므로 토스트·알림까지 겹치면 중복 통지다 (#739)
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
            // 여기서 catch 하는 건 서버 카탈로그 요청(loadPlans) 실패다 — StoreKit 상품 조회
            // 실패는 loadPlanOfferings 내부(try?)가 이미 삼켜 product만 nil로 온다. 성격이
            // 다른 실패라 같은 근거로 묻지 않는다 (#739)
            let offerings = try await self.billingUsecase.loadPlanOfferings()
            self.subject.catalogState.send(.loaded(offerings))
        } catch {
            self.subject.catalogState.send(.failed)
            self.router?.showError(error)
        }
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
                    self.router?.closeScene()

                case .cancelled:
                    break   // 유저 취소 — 조용히 닫기(시트 유지)

                case .pending:
                    let info = ConfirmDialogInfo()
                        |> \.title .~ "billing::paywall::pending::title".localized()
                        |> \.message .~ "billing::paywall::pending::message".localized()
                        |> \.withCancel .~ false
                    self.router?.showConfirm(dialog: info)
                }
            } catch {
                self.router?.showError(error)
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
                // 플랜 반영 자체는 currentUserPlan 릴레이가 자동 처리(#739) — 여기선 유저 피드백만.
                // 버튼을 눌러도 화면에 아무 변화가 없으면 먹었는지 멈췄는지 유저가 알 수 없다
                let restored = try await self.billingUsecase.restorePurchases()
                self.router?.showToast(
                    restored != nil
                        ? "billing::paywall::restored".localized()
                        : "billing::paywall::restore::empty".localized()
                )
            } catch {
                self.router?.showError(error)
            }
        }
    }

    func openTerms() {
        // TODO: 약관 URL 확정 후 반영 — 리젝 직결 항목이라 진입점 개방 전 필수(이번 스코프 밖, #739)
        self.router?.openSafari("")
    }

    func openPrivacyPolicy() {
        // TODO: 개인정보처리방침 URL 확정 후 반영 — 리젝 직결 항목이라 진입점 개방 전 필수(이번 스코프 밖, #739)
        self.router?.openSafari("")
    }

    func close() {
        self.router?.closeScene()
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

    var catalogState: AnyPublisher<PaywallCatalogState, Never> {
        return self.catalogStatePublisher
    }

    // userPlanState(화면 렌더 게이트)와 catalogState(하위 축)를 한 곳에서 순수 합성한다.
    // 두 subject를 mutable var로 손으로 갱신·수동 통지하지 않고 CombineLatest로 — 어느 축이
    // 바뀌든 자동 재계산돼 통지 누락이 없다 (presentations-rules.md §5, #739)
    var screenState: AnyPublisher<PaywallScreenState, Never> {
        return Publishers.CombineLatest(self.subject.userPlanState, self.catalogStatePublisher)
            .map { [weak self] userPlanState, catalogState -> PaywallScreenState in
                self?.resolveScreenState(userPlanState: userPlanState, catalogState: catalogState) ?? .loading
            }
            // catalogState가 바뀌어도 userPlanState가 loaded가 아니면 결과값(.loading/.userPlanLoadFailed)은
            // 그대로다 — 같은 값 연속 방출로 다운스트림이 헛도는 걸 막는다 (catalogStatePublisher와 동일 근거)
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

    // prepare() 가 이미 .loading 인 상태에서 다시 .loading 을 보낼 수 있다(재시도 대비) —
    // 같은 값 연속 방출로 다운스트림(cellModels 등)이 헛도는 걸 막는 단일 지점
    private var catalogStatePublisher: AnyPublisher<PaywallCatalogState, Never> {
        return self.subject.catalogState.removeDuplicates().eraseToAnyPublisher()
    }

    // SharedDataStore.put은 값이 같아도 항상 재통지한다(dedupe 없음) — refreshUserPlan()이
    // 매 prepare()마다 같은 플랜을 재확인만 해도 currentUserPlan이 다시 방출되고, 그 미러(subject.
    // currentPlanId)도 같은 값을 재전송한다. 이 값을 그대로 CombineLatest에 흘리면 cellModels 등이
    // 값 변화 없이도 재계산·재방출된다 — 여기서 한 번 걸러 다운스트림엔 실제 변화만 전달한다 (#739)
    private var currentPlanIdPublisher: AnyPublisher<BillingPlanId?, Never> {
        return self.subject.currentPlanId.removeDuplicates().eraseToAnyPublisher()
    }

    // cellModels/selectedPlanId 등 여러 publisher 가 "로드된 오퍼링 배열"만 필요로 해서
    // catalogState 에서 그 부분만 순수하게 뽑아 재사용한다 (loading/failed 는 빈 배열)
    private var offeringsPublisher: AnyPublisher<[BillingPlanOffering], Never> {
        return self.catalogStatePublisher
            .map { [weak self] in self?.currentOfferings($0) ?? [] }
            .eraseToAnyPublisher()
    }
}


// MARK: - 표시 모델 조립

extension PaywallViewModelImple {

    // userPlanState/catalogState 합성 순수 함수 — CombineLatest.map이 이 함수 하나만 부른다
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
        // 미배포·미로그인 상태는 free 로 취급 — free 는 아무 유료 플랜도 커버하지 않는다
        let effectiveCurrentId = currentPlanId ?? .free
        return offerings
            // productId가 nil인 플랜(무료)은 구매 대상이 아니라 카드로 내지 않는다
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
                    // 지금은 standard 고정 — 서버가 추천 플래그를 내려주게 되면 이 조건이 그 값으로 바뀐다
                    isRecommended: offering.plan.id == .standard
                )
            }
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
            // 카탈로그를 아직 못 불러왔다 — 왼쪽 칩이 이미 플랜 이름을 그리므로
            // 여기서 이름을 다시 반환하면 "[Standard] Standard" 로 중복 표시된다
            return ""
        }
        return "billing::paywall::current::description".localized(with: plan.dailyLimit.formatted())
    }

    // 유저가 명시 선택한 게 있으면 그걸, 없으면 구매 가능한 첫 셀을 기본 선택으로 — 이 함수가
    // 유일한 소스다. selectedPlanId publisher(리액티브)와 purchase()(동기 command) 양쪽이 재사용해
    // "기본 선택 규칙"이 두 곳에 중복되지 않는다
    //
    // userSelected 는 선택 "시점"에만 검증된다(selectPlan(_:) 의 isPurchasable 가드) — 그 뒤 복원·
    // 가족공유·다른 기기 구매 등으로 보유 플랜이 올라오면 선택은 그대로인데 더 이상 구매 대상이
    // 아닐 수 있다. 매번 현재 cells 기준으로 재검증해야 CTA 활성·purchase() 가드가 최신 상태를
    // 따른다 — 안 그러면 이미 커버된 플랜을 다시 청구하게 된다 (C1, #739)
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

    private func detail(of offering: BillingPlanOffering) -> PaywallPlanDetailModel {
        let kind = offering.product?.kind
        return PaywallPlanDetailModel(
            sectionTitle: "billing::paywall::features::title".localized(with: offering.plan.id.name),
            features: self.features(of: offering.plan),
            disclosure: self.disclosureText(for: kind),
            ctaTitle: self.ctaTitle(for: kind, planName: offering.plan.id.name)
        )
    }

    // kind 가 nil 인 건 "1회 결제"가 아니라 "스토어 조회 실패"다 — oneTime 으로 떨어뜨리면
    // 구독 상품인데 사실과 다른 결제 조건이 표시된다. product 가 없을 때도 같은 이유로 여기로 온다
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

    // 이 배열이 앞으로 늘어나는 자리다. 혜택 항목이 추가되면 여기에만 붙는다 — 화면 구조는 안 바뀐다.
    // 서버가 기능 키 배열을 주게 되면 이 함수가 그걸 받아 문자열로 변환하는 형태로 바뀐다.
    private func features(of plan: BillingPlan) -> [String] {
        return [
            "billing::paywall::feature::dailyCredits".localized(with: plan.dailyLimit.formatted()),
            plan.isTopupAllowed ? "billing::paywall::feature::topup".localized() : nil
        ].compactMap { $0 }
    }
}
