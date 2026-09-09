//
//  WidgetGalleryView.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Combine
import Domain
import Extensions
import CommonPresentation


@Observable final class WidgetGalleryViewState {

    @ObservationIgnored private var didBind = false
    @ObservationIgnored private let cancellables = CancelBag()

    var items: [WidgetGalleryItem] = []
    var setting: WidgetAppearanceSettings = .init()
    var isSystemTheme: Bool = true
    var customBackground: Color?

    func bind(_ viewModel: any WidgetGalleryViewModel) {
        guard self.didBind == false else { return }
        self.didBind = true

        viewModel.items
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] items in
                self?.items = items
            })
            .store(in: self.cancellables)

        viewModel.setting
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] setting in
                self?.setting = setting
                switch setting.background {
                case .system:
                    self?.isSystemTheme = true
                case .custom(let hex):
                    self?.isSystemTheme = false
                    self?.customBackground = UIColor.from(hex: hex)?.asColor
                }
            })
            .store(in: self.cancellables)
    }
}

final class WidgetGalleryViewEventHandler: Observable {

    var onAppear: () -> Void = { }
    var selectItem: (String) -> Void = { _ in }
    var selectSystemTheme: () -> Void = { }
    var selectCustomColorHex: (String) -> Void = { _ in }
    var close: () -> Void = { }

    func bind(_ viewModel: any WidgetGalleryViewModel) {
        self.selectItem = viewModel.selectItem(_:)
        self.selectSystemTheme = viewModel.selectSystemTheme
        self.selectCustomColorHex = viewModel.selectCustomBackground(hex:)
        self.close = viewModel.close
    }
}


// MARK: - WidgetGalleryContainerView

struct WidgetGalleryContainerView: View {

    @State private var state: WidgetGalleryViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandler: WidgetGalleryViewEventHandler

    var stateBinding: (WidgetGalleryViewState) -> Void = { _ in }

    init(
        eventHandler: WidgetGalleryViewEventHandler,
        viewAppearance: ViewAppearance
    ) {
        self.eventHandler = eventHandler
        self.viewAppearance = viewAppearance
    }

    var body: some View {
        WidgetGalleryView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandler.onAppear()
            }
            .environment(state)
            .environment(eventHandler)
            .environment(viewAppearance)
    }
}


// MARK: - WidgetGalleryView

struct WidgetGalleryView: View {

    @Environment(\.self) private var environment
    @Environment(WidgetGalleryViewState.self) private var state
    @Environment(WidgetGalleryViewEventHandler.self) private var eventHandlers
    @Environment(ViewAppearance.self) private var appearance

    private enum Constant {
        static let thumbnailSide: CGFloat = 52
        static let visibleChipCount: Int = 3
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {

                    themeSectionView

                    listSectionView
                }
            }
            .background(appearance.colorSet.bg0.asColor)
            .navigationTitle("setting.appearance.widget::gallery::title".localized())
            .if(condition: ProcessInfo.isAvailiOS26()) {
                $0.toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationBackButton {
                        self.eventHandlers.close()
                    }
                }
            }
        }
        .id(appearance.navigationBarId)
    }
}


// MARK: - theme section

extension WidgetGalleryView {

    private var themeSectionView: some View {
        VStack(spacing: Metric.Spacing.small) {

            sectionTitleView("setting.appearance.widget::title".localized())

            VStack(spacing: Metric.Spacing.small) {

                settingRow(
                    "setting.appearance.widget::useSystemTheme::title".localized(),
                    subTitle: "setting.appearance.widget::useSystemTheme::background".localized(),
                    systemThemeToggleView
                )

                if state.isSystemTheme == false {
                    settingRow(
                        "setting.appearance.widget::useCustomTheme::title".localized(),
                        subTitle: nil,
                        colorSelectView
                    )
                }
            }
        }
        .padding(.horizontal, spacing: .xlarge)
        .padding(.bottom, spacing: .large)
    }

    private func settingRow(
        _ title: String, subTitle: String?, _ content: some View
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: Metric.Spacing.xxsmall) {
                Text(title)
                    .font(appearance.fontSet.normal.asFont)
                    .foregroundStyle(appearance.colorSet.text0.asColor)

                if let subTitle {
                    Text(subTitle)
                        .font(appearance.fontSet.size(10).asFont)
                        .foregroundStyle(appearance.colorSet.text2.asColor)
                }
            }

            Spacer()

            content
        }
        .padding(.horizontal, spacing: .large)
        .padding(.vertical, spacing: .regular)
        .background(
            RoundedRectangle(cornerRadius: Metric.Radius.regular)
                .fill(appearance.colorSet.bg1.asColor)
        )
    }

    private var systemThemeToggleView: some View {
        @Bindable var state = self.state
        return Toggle("", isOn: $state.isSystemTheme)
            .controlSize(.small)
            .labelsHidden()
            .onChange(of: state.isSystemTheme) { old, new in
                guard old != new, new else { return }
                eventHandlers.selectSystemTheme()
            }
    }

    private var colorSelectView: some View {
        ColorSelectView(
            state.customBackground ?? appearance.colorSet.bg0.asColor
        )
        .eventHandler(\.colorSelected) { newColor in
            guard let hex = newColor.hex(environment) else { return }
            eventHandlers.selectCustomColorHex(hex)
        }
    }

    private func sectionTitleView(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.text1.asColor)
            Spacer()
        }
        .padding(.top, spacing: .large)
    }
}


// MARK: - widget list section

extension WidgetGalleryView {

    private var listSectionView: some View {
        VStack(spacing: 0) {

            sectionTitleView("setting.appearance.widget::gallery::section".localized())
                .padding(.horizontal, spacing: .xlarge)
                .padding(.bottom, spacing: .small)

            LazyVStack(spacing: 0) {
                ForEach(state.items) { item in
                    itemRow(item)

                    Divider()
                        .background(appearance.colorSet.line.asColor)
                        .padding(.leading, spacing: .xlarge)
                }
            }
        }
    }

    private func itemRow(_ item: WidgetGalleryItem) -> some View {
        HStack(spacing: Metric.Spacing.large) {

            thumbnailView(item)

            VStack(alignment: .leading, spacing: Metric.Spacing.xsmall) {
                Text(item.name)
                    .font(appearance.fontSet.normal.asFont)
                    .foregroundStyle(appearance.colorSet.text0.asColor)

                variantChipsView(item)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13))
                .foregroundStyle(appearance.colorSet.text2.asColor)
        }
        .padding(.horizontal, spacing: .xlarge)
        .padding(.vertical, spacing: .large)
        .contentShape(Rectangle())
        .onTapGesture {
            self.eventHandlers.selectItem(item.id)
        }
    }

    @ViewBuilder
    private func thumbnailView(_ item: WidgetGalleryItem) -> some View {
        let side = Constant.thumbnailSide
        // 잠금화면 변형은 가로로 납작해 썸네일에서 실오라기가 된다 — 홈 화면 변형을 먼저 고른다.
        let thumbnailVariant = item.variants.first(where: { $0.canvas.isLockScreen == false })
            ?? item.variants.first
        if let thumbnailVariant {
            WidgetVariantPreviewView(variant: thumbnailVariant, setting: state.setting)
                .frame(width: side, height: side)
        } else {
            Color.clear.frame(width: side, height: side)
        }
    }

    private func variantChipsView(_ item: WidgetGalleryItem) -> some View {
        let shown = item.variants.prefix(Constant.visibleChipCount)
        let restCount = item.variants.count - shown.count

        return HStack(spacing: Metric.Spacing.xsmall) {
            ForEach(shown) { variant in
                chipView(variant.label)
            }
            if restCount > 0 {
                chipView("+\(restCount)")
            }
        }
    }

    private func chipView(_ text: String) -> some View {
        Text(text)
            .font(appearance.fontSet.size(11).asFont)
            .foregroundStyle(appearance.colorSet.text1.asColor)
            .lineLimit(1)
            .padding(.horizontal, spacing: .small)
            .padding(.vertical, spacing: .xxsmall)
            .background(
                RoundedRectangle(cornerRadius: Metric.Radius.chip)
                    .fill(appearance.colorSet.bg1.asColor)
            )
    }
}


// MARK: - preview

struct WidgetGalleryViewPreview_Provider: PreviewProvider {

    static var previews: some View {
        let state = WidgetGalleryViewState()
        state.items = WidgetGalleryItem.allCases

        let handler = WidgetGalleryViewEventHandler()
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultLight, fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#D6236A", default: "#088CDA")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        return WidgetGalleryView()
            .environment(state)
            .environment(handler)
            .environment(viewAppearance)
    }
}
