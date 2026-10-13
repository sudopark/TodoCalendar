//
//  PaidFeatureAdGuideView.swift
//  BillingScenes
//
//  Created by sudo.park on 10/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Combine
import Domain
import Extensions
import CommonPresentation


// MARK: - 기능별 문구

private extension PaidFeature {

    var iconName: String {
        switch self {
        case .colorTheme: return "paintpalette.fill"
        case .customizeWidget: return "square.grid.2x2.fill"
        }
    }

    var titleKey: String {
        switch self {
        case .colorTheme: return "setting.appearance.calendar.colorTheme.adGuide::title"
        case .customizeWidget: return "widget.style.adGuide::title"
        }
    }

    var messageKey: String {
        switch self {
        case .colorTheme: return "setting.appearance.calendar.colorTheme.adGuide::message"
        case .customizeWidget: return "widget.style.adGuide::message"
        }
    }

    var planMessageKey: String {
        switch self {
        case .colorTheme: return "setting.appearance.calendar.colorTheme.adGuide::plan::message"
        case .customizeWidget: return "widget.style.adGuide::plan::message"
        }
    }

    var freeItemsMessageKey: String? {
        switch self {
        case .colorTheme: return "setting.appearance.calendar.colorTheme.adGuide::freeThemes::message"
        case .customizeWidget: return nil
        }
    }
}


// MARK: - PaidFeatureAdGuideViewState

@Observable final class PaidFeatureAdGuideViewState {

    @ObservationIgnored private var didBind = false
    @ObservationIgnored private let cancellables = CancelBag()

    var reason: PaidFeatureGateFailReason?
    var canUseDefault: Bool = false
    var canShowPlans: Bool = false

    func bind(_ viewModel: any PaidFeatureAdGuideViewModel) {
        guard self.didBind == false else { return }
        self.didBind = true

        viewModel.reason
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.reason = $0 }
            .store(in: self.cancellables)

        viewModel.canUseDefault
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.canUseDefault = $0 }
            .store(in: self.cancellables)

        viewModel.canShowPlans
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.canShowPlans = $0 }
            .store(in: self.cancellables)
    }
}


// MARK: - PaidFeatureAdGuideViewEventHandler

final class PaidFeatureAdGuideViewEventHandler: Observable {

    var watchAd: () -> Void = { }
    var showPlans: () -> Void = { }
    var close: () -> Void = { }
    var useDefault: () -> Void = { }

    func bind(_ viewModel: any PaidFeatureAdGuideViewModel) {
        self.watchAd = viewModel.watchAd
        self.showPlans = viewModel.showPlans
        self.close = viewModel.close
        self.useDefault = viewModel.useDefault
    }
}


// MARK: - PaidFeatureAdGuideContainerView

struct PaidFeatureAdGuideContainerView: View {

    @State private var state: PaidFeatureAdGuideViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: PaidFeatureAdGuideViewEventHandler

    var stateBinding: (PaidFeatureAdGuideViewState) -> Void = { _ in }

    init(
        viewAppearance: ViewAppearance,
        eventHandlers: PaidFeatureAdGuideViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }

    var body: some View {
        PaidFeatureAdGuideView()
            .onAppear {
                self.stateBinding(self.state)
            }
            .environment(state)
            .environment(eventHandlers)
            .environment(viewAppearance)
    }
}


// MARK: - PaidFeatureAdGuideView

private struct PaidFeatureAdGuideView: View {

    @Environment(PaidFeatureAdGuideViewState.self) private var state
    @Environment(PaidFeatureAdGuideViewEventHandler.self) private var eventHandlers
    @Environment(ViewAppearance.self) private var appearance

    var body: some View {
        // 빈 뷰면 onAppear 가 불리지 않아 상태 바인딩이 시작되지 않는다
        if let reason = self.state.reason {
            self.guideView(reason)
        } else {
            Color.clear
        }
    }

    private func guideView(_ reason: PaidFeatureGateFailReason) -> some View {
        BottomSlideView {
            VStack(alignment: .leading, spacing: Metric.Spacing.large) {

                HStack(spacing: Metric.Spacing.small) {
                    Image(systemName: reason.feature.iconName)
                        .foregroundStyle(appearance.colorSet.accentWarn.asColor)
                    Text(reason.feature.titleKey.localized())
                }
                .font(appearance.fontSet.bigBold.asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
                .padding(.top, spacing: .regular)

                VStack(alignment: .leading, spacing: Metric.Spacing.small) {
                    Text(reason.feature.messageKey.localized(with: reason.licenseDays))
                        .font(appearance.fontSet.normal.asFont)
                        .foregroundStyle(appearance.colorSet.text0.asColor)
                    if let freeItemsKey = reason.feature.freeItemsMessageKey {
                        Text(freeItemsKey.localized())
                            .font(appearance.fontSet.subNormal.asFont)
                            .foregroundStyle(appearance.colorSet.text2.asColor)
                    }
                }

                if self.state.canShowPlans {
                    self.planRow(reason)
                }

                VStack(spacing: Metric.Spacing.xsmall) {
                    ConfirmButton(
                        title: "paidFeature.adGuide::watchAd::button"
                            .localized(with: reason.licenseDays)
                    )
                    .eventHandler(\.onTap, eventHandlers.watchAd)

                    if self.state.canUseDefault {
                        self.useDefaultButton
                    } else {
                        self.cancelRow
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .eventHandler(\.outsideTap, self.state.canUseDefault ? { } : eventHandlers.close)
    }

    private var useDefaultButton: some View {
        ConfirmButton(
            title: "paidFeature.adGuide::useDefaultTheme::button".localized(),
            textColor: appearance.colorSet.secondaryBtnText.asColor,
            backgroundColor: appearance.colorSet.secondaryBtnBackground.asColor
        )
        .eventHandler(\.onTap, eventHandlers.useDefault)
    }

    private var cancelRow: some View {
        Text("common.cancel".localized())
            .font(appearance.fontSet.normal.asFont)
            .foregroundStyle(appearance.colorSet.text2.asColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, spacing: .regular)
            .contentShape(Rectangle())
            .onTapGesture(perform: eventHandlers.close)
    }

    private func planRow(_ reason: PaidFeatureGateFailReason) -> some View {
        HStack(spacing: Metric.Spacing.small) {
            Text(reason.feature.planMessageKey.localized())
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .font(appearance.fontSet.subNormal.asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
                .multilineTextAlignment(.leading)
            Spacer(minLength: Metric.Spacing.small)
            HStack(spacing: Metric.Spacing.xxsmall) {
                Text("paidFeature.adGuide::plan::button".localized())
                Image(systemName: "chevron.right")
            }
            .font(appearance.fontSet.subNormalWithBold.asFont)
            .foregroundStyle(appearance.colorSet.accent.asColor)
        }
        .padding(spacing: .regular)
        .background(
            RoundedRectangle(cornerRadius: Metric.Radius.large)
                .fill(appearance.colorSet.bg1.asColor)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: eventHandlers.showPlans)
    }
}
