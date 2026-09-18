//
//  WidgetGalleryDetailView.swift
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


@Observable final class WidgetGalleryDetailViewState {

    @ObservationIgnored private var didBind = false
    @ObservationIgnored private let cancellables = CancelBag()

    var itemName: String = ""
    var variants: [WidgetVariant] = []
    var setting: WidgetAppearanceSettings = .init()
    var selectedVariantId: String?
    var previewStyles: [String: WidgetPreviewStyleStack] = [:]

    func bind(_ viewModel: any WidgetGalleryDetailViewModel) {
        guard self.didBind == false else { return }
        self.didBind = true

        viewModel.itemName
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] name in
                self?.itemName = name
            })
            .store(in: self.cancellables)

        viewModel.variants
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] variants in
                self?.variants = variants
                self?.selectedVariantId = variants.first?.id
            })
            .store(in: self.cancellables)

        viewModel.setting
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] setting in
                self?.setting = setting
            })
            .store(in: self.cancellables)
        
        viewModel.previewStyles
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] styles in
                self?.previewStyles = styles
            })
            .store(in: self.cancellables)
    }
}

final class WidgetGalleryDetailViewEventHandler: Observable {

    var onAppear: () -> Void = { }
    var editStyle: (WidgetVariant) -> Void = { _ in }
    var close: () -> Void = { }

    func bind(_ viewModel: any WidgetGalleryDetailViewModel) {
        self.onAppear = viewModel.refresh
        self.editStyle = viewModel.editStyle
        self.close = viewModel.close
    }
}


// MARK: - WidgetGalleryDetailContainerView

struct WidgetGalleryDetailContainerView: View {

    @State private var state: WidgetGalleryDetailViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandler: WidgetGalleryDetailViewEventHandler

    var stateBinding: (WidgetGalleryDetailViewState) -> Void = { _ in }

    init(
        eventHandler: WidgetGalleryDetailViewEventHandler,
        viewAppearance: ViewAppearance
    ) {
        self.eventHandler = eventHandler
        self.viewAppearance = viewAppearance
    }

    var body: some View {
        WidgetGalleryDetailView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandler.onAppear()
            }
            .environment(state)
            .environment(eventHandler)
            .environment(viewAppearance)
    }
}


// MARK: - WidgetGalleryDetailView

struct WidgetGalleryDetailView: View {

    @Environment(WidgetGalleryDetailViewState.self) private var state
    @Environment(WidgetGalleryDetailViewEventHandler.self) private var eventHandlers
    @Environment(ViewAppearance.self) private var appearance

    private enum Constant {
        static let previewHorizontalInset: CGFloat = 40
        static let overlayOffsetStep: CGFloat = 16
        static let overlayAngle: CGFloat = 20
        static let overlayScale: CGFloat = 0.88
        static let labelAreaHeight: CGFloat = 44
        static let indicatorAreaHeight: CGFloat = 40
    }

    /// 페이저가 가리키는 변형이 꾸미기 대상일 때만 하단 버튼이 선다.
    private var customizableSelectedVariant: WidgetVariant? {
        return state.variants
            .first { $0.id == state.selectedVariantId }
            .flatMap { $0.isCustomizable ? $0 : nil }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {

                explainView

                pagerView

                if let variant = self.customizableSelectedVariant {
                    BottomConfirmButton(title: "widget.style.edit::entry".localized())
                        .eventHandler(\.onTap, { self.eventHandlers.editStyle(variant) })
                }
            }
            .background(appearance.colorSet.bg0.asColor)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
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

    private var explainView: some View {
        VStack(alignment: .leading, spacing: Metric.SpacingToken.xxsmall.value) {
            Text(state.itemName)
                .font(appearance.fontSet.bigBold.asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)

            Text("widget.common::explain".localized())
                .font(appearance.fontSet.subNormal.asFont)
                .foregroundStyle(appearance.colorSet.text2.asColor)
        }
        .padding(.horizontal, spacing: .xlarge)
        .padding(.vertical, spacing: .large)
    }

    private var pagerView: some View {
        @Bindable var state = self.state
        // 넘길 때 출렁이지 않게 모든 페이지가 가장 높은 변형의 비율을 함께 쓴다.
        let pageAspect = state.variants.map { $0.canvas.previewAspect }.min() ?? 1

        return TabView(selection: $state.selectedVariantId) {
            ForEach(state.variants) { variant in
                variantPage(variant, pageAspect: pageAspect)
                    .tag(Optional(variant.id))
            }
        }
        .tabViewStyle(
            .page(indexDisplayMode: state.variants.count > 1 ? .always : .never)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appearance.colorSet.bg1.asColor)
    }

    private func variantPage(
        _ variant: WidgetVariant, pageAspect: CGFloat
    ) -> some View {
        VStack(spacing: 0) {

            Spacer(minLength: 0)

            previewStackView(variant, pageAspect: pageAspect)

            labelView(variant)
                .frame(height: Constant.labelAreaHeight)

            Spacer(minLength: 0)

            // 페이지 인디케이터가 앉는 자리 — 라벨과 겹치지 않게 비워 둔다.
            Color.clear.frame(height: Constant.indicatorAreaHeight)
        }
    }

    private func previewStackView(
        _ variant: WidgetVariant, pageAspect: CGFloat
    ) -> some View {
        let stack = state.previewStyles[variant.id]
        let overlayStyles = stack?.overlays ?? []

        return ZStack {

            ForEach(Array(overlayStyles.enumerated()).reversed(), id: \.offset) { index, style in
                overlayCardView(variant, style: style, depth: index)
            }

            WidgetVariantPreviewView(
                variant: variant,
                setting: state.setting.overridingBackground(stack?.base.background),
                style: stack?.base.setting
            )
            .if(condition: overlayStyles.isEmpty == false) { $0.cardDepthShadow() }
        }
        .aspectRatio(pageAspect, contentMode: .fit)
        .padding(.horizontal, Constant.previewHorizontalInset)
    }

    /// 뒷장을 좌우로 번갈아 눕혀야 앞장에 가리지 않고 카드로 읽힌다.
    private func overlayCardView(
        _ variant: WidgetVariant, style: WidgetStyle, depth: Int
    ) -> some View {
        let direction: CGFloat = depth.isMultiple(of: 2) ? -1 : 1
        return WidgetVariantPreviewView(
            variant: variant,
            setting: state.setting.overridingBackground(style.background),
            style: style.setting
        )
        .cardDepthShadow()
        .scaleEffect(Constant.overlayScale)
        .rotationEffect(.degrees(Constant.overlayAngle * direction))
        .offset(x: Constant.overlayOffsetStep * direction)
    }

    private func labelView(_ variant: WidgetVariant) -> some View {
        HStack(spacing: Metric.SpacingToken.xxsmall.value) {
            Text(variant.detailLabel)
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.text1.asColor)
        }
    }
}


private enum CardShadow {
    static let radius: CGFloat = 12
    static let opacity: CGFloat = 0.2
    static let offsetY: CGFloat = 4
}

private extension View {

    /// 앱은 그림자를 쓰지 않지만, 겹친 카드가 층으로 안 갈려 미리보기에만 준다 (presentations-rules §8 예외).
    func cardDepthShadow() -> some View {
        return self.shadow(
            color: .black.opacity(CardShadow.opacity),
            radius: CardShadow.radius,
            x: 0,
            y: CardShadow.offsetY
        )
    }
}


// MARK: - preview

struct WidgetGalleryDetailViewPreview_Provider: PreviewProvider {

    static var previews: some View {
        let state = WidgetGalleryDetailViewState()
        let item = WidgetGalleryItem.dday
        state.itemName = item.name
        state.variants = item.variants
        state.selectedVariantId = item.variants.first?.id

        let handler = WidgetGalleryDetailViewEventHandler()
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultLight, fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#D6236A", default: "#088CDA")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        return WidgetGalleryDetailView()
            .environment(state)
            .environment(handler)
            .environment(viewAppearance)
    }
}
