//
//  PaywallView.swift
//  BillingScenes
//
//  Created by sudo.park on 8/3/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Combine
import Domain
import CommonPresentation


// MARK: - ViewState

@Observable final class PaywallViewState {

    @ObservationIgnored private var didBind = false
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []

    var currentPlan: BillingPlanId?
    var currentPlanDescription: String = ""
    var scheduledChange: BillingUserPlan.ScheduledChange?
    var screenState: PaywallScreenState = .loading
    var catalogState: PaywallCatalogState = .loading
    var cellModels: [PaywallPlanCellModel] = []
    var topupCellModels: [PaywallTopupCellModel] = []
    var selectedPlanId: BillingPlanId?
    var selectedPlanDetail: PaywallPlanDetailModel?
    var isPurchasing: Bool = false
    var hasUnfinishedTransactions: Bool = false
    var showsManageSubscription: Bool = false

    func bind(_ viewModel: any PaywallViewModel) {
        guard self.didBind == false else { return }
        self.didBind = true

        viewModel.currentPlan
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.currentPlan = $0 }
            .store(in: &self.cancellables)

        viewModel.currentPlanDescription
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.currentPlanDescription = $0 }
            .store(in: &self.cancellables)

        viewModel.scheduledChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.scheduledChange = $0 }
            .store(in: &self.cancellables)

        viewModel.screenState
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.screenState = $0 }
            .store(in: &self.cancellables)

        viewModel.catalogState
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.catalogState = $0 }
            .store(in: &self.cancellables)

        viewModel.cellModels
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.cellModels = $0 }
            .store(in: &self.cancellables)

        viewModel.topupCellModels
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.topupCellModels = $0 }
            .store(in: &self.cancellables)

        viewModel.selectedPlanId
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.selectedPlanId = $0 }
            .store(in: &self.cancellables)

        viewModel.selectedPlanDetail
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.selectedPlanDetail = $0 }
            .store(in: &self.cancellables)

        viewModel.isPurchasing
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.isPurchasing = $0 }
            .store(in: &self.cancellables)

        viewModel.hasUnfinishedTransactions
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.hasUnfinishedTransactions = $0 }
            .store(in: &self.cancellables)

        viewModel.showsManageSubscription
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.showsManageSubscription = $0 }
            .store(in: &self.cancellables)
    }
}


// MARK: - EventHandler

final class PaywallViewEventHandler: Observable {

    var onAppear: () -> Void = { }
    var retry: () -> Void = { }
    var selectPlan: (BillingPlanId) -> Void = { _ in }
    var purchase: () -> Void = { }
    var purchaseTopup: (String) -> Void = { _ in }
    var restore: () -> Void = { }
    var recoverUnfinished: () -> Void = { }
    var manageSubscription: () -> Void = { }
    var openTerms: () -> Void = { }
    var openPrivacyPolicy: () -> Void = { }
    var close: () -> Void = { }

    func bind(_ viewModel: any PaywallViewModel) {
        self.onAppear = viewModel.prepare
        self.retry = viewModel.prepare
        self.selectPlan = viewModel.selectPlan(_:)
        self.purchase = viewModel.purchase
        self.purchaseTopup = viewModel.purchaseTopup(_:)
        self.restore = viewModel.restore
        self.recoverUnfinished = viewModel.recoverUnfinished
        self.manageSubscription = viewModel.manageSubscription
        self.openTerms = viewModel.openTerms
        self.openPrivacyPolicy = viewModel.openPrivacyPolicy
        self.close = viewModel.close
    }
}


// MARK: - ContainerView

struct PaywallContainerView: View {

    @State private var state: PaywallViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: PaywallViewEventHandler

    var stateBinding: (PaywallViewState) -> Void = { _ in }

    init(
        viewAppearance: ViewAppearance,
        eventHandlers: PaywallViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }

    var body: some View {
        PaywallView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .environment(state)
            .environment(eventHandlers)
            .environment(viewAppearance)
    }
}


// MARK: - View

private struct PaywallView: View {

    @Environment(ViewAppearance.self) private var appearance
    @Environment(PaywallViewState.self) private var state
    @Environment(PaywallViewEventHandler.self) private var eventHandlers

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                SheetHeaderView(title: "billing::paywall::title".localized())
                    .eventHandler(\.onClose) { self.eventHandlers.close() }
                    .padding(.horizontal, spacing: .xlarge)

                switch self.state.screenState {
                case .loading:
                    self.userPlanLoadingView
                case .userPlanLoadFailed:
                    self.userPlanLoadFailedView
                case .ready:
                    self.planSelectionView
                }
            }

            if self.state.isPurchasing {
                self.processingOverlay
            }
        }
        .background(self.appearance.colorSet.bg0.asColor.ignoresSafeArea())
    }

    // MARK: - 결제 처리 중 오버레이

    // 스크림이 헤더의 닫기 버튼까지 덮어 이탈 경로를 막는다 — paywall 은 .overFullScreen 이라
    // 스와이프 다운·딤 탭 dismiss 가 따로 없다
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { }

            FullScreenLoadingView(
                isLoading: true,
                message: "billing::paywall::processing::message".localized()
            )
        }
    }

    // MARK: - 본문 (유저 플랜 확인 완료)

    private var planSelectionView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Metric.Spacing.large) {
                    self.currentPlanStrip
                    self.planCards
                    Divider()
                    self.featureSection
                    if !self.state.topupCellModels.isEmpty {
                        Divider()
                        self.topupSection
                    }
                    self.linksRow
                }
                .padding(.horizontal, spacing: .xlarge)
                .padding(.top, spacing: .regular)
            }

            if self.state.hasUnfinishedTransactions {
                self.unfinishedRecoveryBanner
            }

            BottomConfirmButton(
                title: self.state.selectedPlanDetail?.ctaTitle
                    ?? "billing::paywall::cta::unavailable".localized(),
                isEnable: self.state.selectedPlanId != nil,
                isProcessing: self.state.isPurchasing
            )
            .eventHandler(\.onTap) { self.eventHandlers.purchase() }
        }
    }

    // MARK: - 미완료 결제 복구 배너

    private var unfinishedRecoveryBanner: some View {
        HStack(alignment: .top, spacing: Metric.Spacing.small) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(self.appearance.colorSet.accentWarn.asColor)

            VStack(alignment: .leading, spacing: Metric.Spacing.xxsmall) {
                Text("billing::paywall::unfinished::title".localized())
                    .font(self.appearance.fontSet.subNormalWithBold.asFont)
                    .foregroundStyle(self.appearance.colorSet.text0.asColor)
                Text("billing::paywall::unfinished::message".localized())
                    .font(self.appearance.fontSet.subSubNormal.asFont)
                    .foregroundStyle(self.appearance.colorSet.text2.asColor)
            }

            Spacer(minLength: Metric.Spacing.small)

            Text("billing::paywall::unfinished::action".localized())
                .font(self.appearance.fontSet.subNormalWithBold.asFont)
                .foregroundStyle(self.appearance.colorSet.accentAI.asColor)
                .opacity(self.state.isPurchasing ? 0.5 : 1)
                .allowsHitTesting(!self.state.isPurchasing)
                .onTapGesture { self.eventHandlers.recoverUnfinished() }
        }
        .padding(spacing: .regular)
        .background(
            RoundedRectangle(cornerRadius: Metric.Radius.regular)
                .fill(self.appearance.colorSet.bg1.asColor)
        )
        .padding(.horizontal, spacing: .xlarge)
    }

    // MARK: - 유저 플랜 조회 게이트 (로딩·전면 에러)

    private var userPlanLoadingView: some View {
        VStack {
            Spacer()
            LoadingCircleView(self.appearance.colorSet.accentAI.asColor, lineWidth: 2)
                .frame(width: 32, height: 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var userPlanLoadFailedView: some View {
        VStack(spacing: Metric.Spacing.regular) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(self.appearance.colorSet.accentWarn.asColor)
            Text("billing::paywall::userPlan::loadFailed".localized())
                .font(self.appearance.fontSet.normal.asFont)
                .foregroundStyle(self.appearance.colorSet.text1.asColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, spacing: .xlarge)
            ConfirmButton(title: "billing::paywall::retry".localized())
                .eventHandler(\.onTap) { self.eventHandlers.retry() }
                .padding(.horizontal, spacing: .xlarge)
                .padding(.top, spacing: .small)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 현재 플랜 스트립

    private var currentPlanStrip: some View {
        VStack(alignment: .leading, spacing: Metric.Spacing.xsmall) {
            HStack(spacing: Metric.Spacing.small) {
                BillingPlanChipView(plan: self.state.currentPlan ?? .free)
                Text(self.state.currentPlanDescription)
                    .font(self.appearance.fontSet.subNormal.asFont)
                    .foregroundStyle(self.appearance.colorSet.text2.asColor)

                if self.state.showsManageSubscription {
                    Spacer(minLength: Metric.Spacing.small)
                    self.manageSubscriptionLink
                }
            }

            if let change = self.state.scheduledChange {
                BillingScheduledChangeView(change: change)
            }
        }
    }

    private var manageSubscriptionLink: some View {
        HStack(spacing: Metric.Spacing.xxsmall) {
            Text("billing::paywall::manageSubscription".localized())
            Image(systemName: "chevron.right")
        }
        .font(self.appearance.fontSet.subSubNormal.asFont)
        .foregroundStyle(self.appearance.colorSet.accentAI.asColor)
        .opacity(self.state.isPurchasing ? 0.5 : 1)
        .allowsHitTesting(!self.state.isPurchasing)
        .onTapGesture { self.eventHandlers.manageSubscription() }
    }

    // MARK: - 플랜 카드

    private var planCards: some View {
        VStack(spacing: Metric.Spacing.small) {
            ForEach(self.state.cellModels, id: \.planId) { cell in
                PaywallPlanCellView(
                    model: cell,
                    isSelected: cell.planId == self.state.selectedPlanId
                )
                .eventHandler(\.onTap) { self.eventHandlers.selectPlan(cell.planId) }
            }
        }
    }

    // MARK: - 선택 플랜 기능 섹션

    @ViewBuilder
    private var featureSection: some View {
        switch self.state.catalogState {
        case .loading:
            self.catalogLoadingView

        case .failed:
            Text("common.errorMessage".localized())
                .font(self.appearance.fontSet.subNormal.asFont)
                .foregroundStyle(self.appearance.colorSet.accentWarn.asColor)

        case .loaded:
            self.loadedFeatureSection
        }
    }

    private var catalogLoadingView: some View {
        HStack {
            Spacer()
            LoadingCircleView(self.appearance.colorSet.accentAI.asColor, lineWidth: 2)
                .frame(width: 24, height: 24)
            Spacer()
        }
    }

    @ViewBuilder
    private var loadedFeatureSection: some View {
        if let detail = self.state.selectedPlanDetail {
            VStack(alignment: .leading, spacing: Metric.Spacing.small) {
                Text(detail.sectionTitle)
                    .font(self.appearance.fontSet.subNormalWithBold.asFont)
                    .foregroundStyle(self.appearance.colorSet.text0.asColor)

                ForEach(detail.features, id: \.self) { feature in
                    HStack(alignment: .firstTextBaseline, spacing: Metric.Spacing.xsmall) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(self.appearance.colorSet.accentAI.asColor)
                        Text(feature)
                            .font(self.appearance.fontSet.subNormal.asFont)
                            .foregroundStyle(self.appearance.colorSet.text1.asColor)
                    }
                }

                Text(detail.disclosure)
                    .font(self.appearance.fontSet.subSubNormal.asFont)
                    .foregroundStyle(self.appearance.colorSet.text2.asColor)
            }
        } else if self.state.cellModels.contains(where: { $0.isCovered == false }) {
            Text("billing::paywall::disclosure::storeUnavailable".localized())
                .font(self.appearance.fontSet.subNormal.asFont)
                .foregroundStyle(self.appearance.colorSet.text2.asColor)
        } else {
            // 구매 가능한 플랜이 없다(평생 보유) — 안내 문구로 대체
            Text("billing::paywall::allPlansOwned".localized())
                .font(self.appearance.fontSet.subNormal.asFont)
                .foregroundStyle(self.appearance.colorSet.text2.asColor)
        }
    }

    // MARK: - top-up 추가 구매

    private var topupSection: some View {
        VStack(alignment: .leading, spacing: Metric.Spacing.small) {
            Text("billing::paywall::topup::title".localized())
                .font(self.appearance.fontSet.subNormalWithBold.asFont)
                .foregroundStyle(self.appearance.colorSet.text0.asColor)

            ForEach(self.state.topupCellModels, id: \.productId) { cell in
                PaywallTopupCellView(model: cell)
                    .eventHandler(\.onTap) { self.eventHandlers.purchaseTopup(cell.productId) }
            }

            Text("billing::paywall::topup::description".localized())
                .font(self.appearance.fontSet.subSubNormal.asFont)
                .foregroundStyle(self.appearance.colorSet.text2.asColor)
        }
    }

    // MARK: - 약관·개인정보·복원 링크

    private var linksRow: some View {
        HStack(spacing: Metric.Spacing.xsmall) {
            Text("billing::paywall::terms".localized())
                .onTapGesture { self.eventHandlers.openTerms() }
            Text("·")
            Text("billing::paywall::privacyPolicy".localized())
                .onTapGesture { self.eventHandlers.openPrivacyPolicy() }
            Text("·")
            Text("billing::paywall::restore".localized())
                .font(self.appearance.fontSet.subNormalWithBold.asFont)
                .foregroundStyle(self.appearance.colorSet.text0.asColor)
                .opacity(self.state.isPurchasing ? 0.5 : 1)
                .allowsHitTesting(!self.state.isPurchasing)
                .onTapGesture { self.eventHandlers.restore() }
        }
        .font(self.appearance.fontSet.subSubNormal.asFont)
        .foregroundStyle(self.appearance.colorSet.text2.asColor)
    }
}


// MARK: - PaywallPlanCellView

private struct PaywallPlanCellView: View {

    @Environment(ViewAppearance.self) private var appearance
    private let model: PaywallPlanCellModel
    private let isSelected: Bool

    var onTap: () -> Void = { }

    init(model: PaywallPlanCellModel, isSelected: Bool) {
        self.model = model
        self.isSelected = isSelected
    }

    private var borderColor: Color {
        return self.isSelected
            ? self.appearance.colorSet.accentAI.asColor
            : self.appearance.colorSet.line.asColor
    }

    private var backgroundColor: Color {
        return self.isSelected
            ? self.appearance.colorSet.bg1.asColor
            : self.appearance.colorSet.bg0.asColor
    }

    var body: some View {
        HStack(alignment: .top, spacing: Metric.Spacing.small) {
            Image(
                systemName: self.model.isOwned
                    ? "checkmark.circle.fill"
                    : (self.isSelected ? "largecircle.fill.circle" : "circle")
            )
            .foregroundStyle(
                self.model.isCovered
                    ? self.appearance.colorSet.text2.asColor
                    : self.borderColor
            )

            VStack(alignment: .leading, spacing: Metric.Spacing.xxsmall) {
                HStack(spacing: Metric.Spacing.xsmall) {
                    Text(self.model.name)
                        .font(self.appearance.fontSet.subNormalWithBold.asFont)
                        .foregroundStyle(self.appearance.colorSet.text0.asColor)

                    if self.model.isRecommended {
                        self.badge(
                            "billing::paywall::badge::recommended".localized(),
                            background: self.appearance.colorSet.accentAI.asColor,
                            text: self.appearance.colorSet.primaryBtnText.asColor
                        )
                    }

                    if self.model.isOwned {
                        Text("billing::paywall::badge::owned".localized())
                            .font(self.appearance.fontSet.size(10, weight: .semibold).asFont)
                            .foregroundStyle(self.appearance.colorSet.text2.asColor)
                    }

                    Spacer()

                    self.priceView
                }

                Text(self.model.metricText)
                    .font(self.appearance.fontSet.subSubNormal.asFont)
                    .foregroundStyle(self.appearance.colorSet.text2.asColor)
            }
        }
        .padding(spacing: .regular)
        .background(
            RoundedRectangle(cornerRadius: Metric.Radius.large)
                .fill(self.backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: Metric.Radius.large)
                        .stroke(self.borderColor, lineWidth: 1)
                )
        )
        .onTapGesture { self.onTap() }
    }

    @ViewBuilder
    private var priceView: some View {
        if let price = self.model.priceText {
            HStack(spacing: Metric.Spacing.xxsmall) {
                Text(price)
                    .font(self.appearance.fontSet.subNormalWithBold.asFont)
                    .foregroundStyle(self.appearance.colorSet.text0.asColor)
                if let period = self.model.periodText {
                    Text(period)
                        .font(self.appearance.fontSet.subSubNormal.asFont)
                        .foregroundStyle(self.appearance.colorSet.text2.asColor)
                }
            }
        } else {
            Text("billing::paywall::price::unavailable".localized())
                .font(self.appearance.fontSet.subSubNormal.asFont)
                .foregroundStyle(self.appearance.colorSet.accentWarn.asColor)
        }
    }

    private func badge(_ text: String, background: Color, text textColor: Color) -> some View {
        Text(text)
            .font(self.appearance.fontSet.size(10, weight: .semibold).asFont)
            .foregroundStyle(textColor)
            .padding(.horizontal, spacing: .xsmall)
            .padding(.vertical, spacing: .xxsmall)
            .background(
                RoundedRectangle(cornerRadius: Metric.Radius.chip)
                    .fill(background)
            )
    }
}


// MARK: - PaywallTopupCellView

private struct PaywallTopupCellView: View {

    @Environment(ViewAppearance.self) private var appearance
    private let model: PaywallTopupCellModel

    var onTap: () -> Void = { }

    init(model: PaywallTopupCellModel) {
        self.model = model
    }

    var body: some View {
        HStack(spacing: Metric.Spacing.small) {
            VStack(alignment: .leading, spacing: Metric.Spacing.xxsmall) {
                Text(self.model.creditsText)
                    .font(self.appearance.fontSet.subNormalWithBold.asFont)
                    .foregroundStyle(self.appearance.colorSet.text0.asColor)

                if let bonus = self.model.bonusText {
                    Text(bonus)
                        .font(self.appearance.fontSet.subSubNormal.asFont)
                        .foregroundStyle(self.appearance.colorSet.accentAI.asColor)
                }
            }

            Spacer(minLength: Metric.Spacing.small)

            Text(self.model.priceText)
                .font(self.appearance.fontSet.subNormalWithBold.asFont)
                .foregroundStyle(self.appearance.colorSet.primaryBtnText.asColor)
                .padding(.horizontal, spacing: .regular)
                .padding(.vertical, spacing: .xsmall)
                .background(
                    RoundedRectangle(cornerRadius: Metric.Radius.regular)
                        .fill(self.appearance.colorSet.accentAI.asColor)
                )
        }
        .padding(spacing: .regular)
        .background(
            RoundedRectangle(cornerRadius: Metric.Radius.large)
                .fill(self.appearance.colorSet.bg0.asColor)
                .overlay(
                    RoundedRectangle(cornerRadius: Metric.Radius.large)
                        .stroke(self.appearance.colorSet.line.asColor, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { self.onTap() }
    }
}
