//
//  WidgetStyleEditView.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Combine
import Domain
import Extensions
import CommonPresentation


@Observable final class WidgetStyleEditViewState {
    
    @ObservationIgnored private var didBind = false
    @ObservationIgnored private let cancellables = CancelBag()
    
    var styles: [WidgetStyleCellViewModel] = []
    var selectedStyleId: WidgetStyleId?
    var editingName: String = ""
    var hasUnsavedChange: Bool = false
    var selectedSetting: (any WidgetStyleSetting)?
    var selectedBackground: WidgetAppearanceSettings.Background?
    
    func bind(_ viewModel: any WidgetStyleEditViewModel) {
        guard self.didBind == false else { return }
        self.didBind = true
        
        viewModel.styles
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] styles in
                self?.styles = styles
            })
            .store(in: self.cancellables)
        
        viewModel.selectedStyleId
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] styleId in
                self?.selectedStyleId = styleId
            })
            .store(in: self.cancellables)
        
        viewModel.editingName
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] name in
                self?.editingName = name
            })
            .store(in: self.cancellables)
        
        viewModel.hasUnsavedChange
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] hasChanges in
                self?.hasUnsavedChange = hasChanges
            })
            .store(in: self.cancellables)
        
        viewModel.selectedSetting
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] setting in
                self?.selectedSetting = setting
            })
            .store(in: self.cancellables)
        
        viewModel.selectedBackground
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] background in
                self?.selectedBackground = background
            })
            .store(in: self.cancellables)
    }
}

final class WidgetStyleEditViewEventHandler: Observable {
    
    var onAppear: () -> Void = { }
    var selectStyle: (WidgetStyleId) -> Void = { _ in }
    var addStyle: () -> Void = { }
    var appendStyle: (WidgetStyleId) -> Void = { _ in }
    var removeStyle: (WidgetStyleId) -> Void = { _ in }
    var resetStyle: (WidgetStyleId) -> Void = { _ in }
    var discard: () -> Void = { }
    var editName: (String) -> Void = { _ in }
    var updateSetting: (any WidgetStyleSetting) -> Void = { _ in }
    var updateBackground: (String) -> Void = { _ in }
    var confirm: () -> Void = { }
    var close: () -> Void = { }
    
    func bind(_ viewModel: any WidgetStyleEditViewModel) {
        self.onAppear = viewModel.refresh
        self.selectStyle = viewModel.selectStyle
        self.addStyle = viewModel.addStyle
        self.appendStyle = viewModel.appendStyle(copying:)
        self.removeStyle = viewModel.removeStyle
        self.resetStyle = viewModel.resetStyle
        self.discard = viewModel.discard
        self.editName = viewModel.editName
        self.updateSetting = viewModel.updateSetting
        self.updateBackground = viewModel.updateBackground
        self.confirm = viewModel.confirm
        self.close = viewModel.close
    }
}


// MARK: - WidgetStyleEditContainerView

struct WidgetStyleEditContainerView: View {
    
    @State private var state: WidgetStyleEditViewState = .init()
    private let variants: [WidgetVariant]
    private let setting: WidgetAppearanceSettings
    private let viewAppearance: ViewAppearance
    private let eventHandler: WidgetStyleEditViewEventHandler
    
    var stateBinding: (WidgetStyleEditViewState) -> Void = { _ in }
    
    init(
        variants: [WidgetVariant],
        setting: WidgetAppearanceSettings,
        eventHandler: WidgetStyleEditViewEventHandler,
        viewAppearance: ViewAppearance
    ) {
        self.variants = variants
        self.setting = setting
        self.eventHandler = eventHandler
        self.viewAppearance = viewAppearance
    }
    
    var body: some View {
        WidgetStyleEditView(variants: variants, setting: setting)
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandler.onAppear()
            }
            .environment(state)
            .environment(eventHandler)
            .environment(viewAppearance)
    }
}


// MARK: - WidgetStyleEditView

struct WidgetStyleEditView: View {
    
    @Environment(WidgetStyleEditViewState.self) private var state
    @Environment(WidgetStyleEditViewEventHandler.self) private var eventHandlers
    @Environment(ViewAppearance.self) private var appearance
    @Environment(\.self) private var environment
    @FocusState private var isNameFocused: Bool
    
    private enum Constant {
        static let cardWidth: CGFloat = 160
        static let cardLabelHeight: CGFloat = 28
        static let selectedBorderWidth: CGFloat = 2
        static let nameUnderlineHeight: CGFloat = 1
        static let focusedNameUnderlineHeight: CGFloat = 2
    }
    
    private let variants: [WidgetVariant]
    private let setting: WidgetAppearanceSettings
    
    init(variants: [WidgetVariant], setting: WidgetAppearanceSettings) {
        self.variants = variants
        self.setting = setting
    }
    
    private var previewVariant: WidgetVariant? {
        return self.variants.first
    }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                
                styleCardsView
                
                itemListView
            }
            .safeAreaInset(edge: .bottom) {
                bottomButtons
            }
            .background(appearance.colorSet.bg0.asColor)
            .navigationTitle("widget.style.edit::title".localized())
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
    
    private var bottomButtons: some View {
        HStack(spacing: Metric.Spacing.regular) {
            
            ConfirmButton(
                title: "widget.style.edit::discard".localized(),
                isEnable: state.hasUnsavedChange,
                textColor: state.hasUnsavedChange
                ? appearance.colorSet.text0.asColor
                : appearance.colorSet.text2.asColor,
                backgroundColor: appearance.colorSet.bg1.asColor
            )
            .eventHandler(\.onTap, self.eventHandlers.discard)
            
            ConfirmButton(
                title: "common.save".localized(),
                isEnable: state.hasUnsavedChange
            )
            .eventHandler(\.onTap, self.eventHandlers.confirm)
        }
        .padding()
        .background(
            Rectangle()
                .fill(appearance.colorSet.dayBackground.asColor)
                .ignoresSafeArea(edges: .bottom)
        )
    }
    
    private var styleCardsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Metric.SpacingToken.regular.value) {
                ForEach(state.styles, id: \.styleId) { style in
                    styleCard(style)
                }
                
                addStyleCard
            }
            .padding(.horizontal, spacing: .xlarge)
            .padding(.vertical, spacing: .large)
        }
        // 미리보기가 GeometryReader 기반이라 intrinsic 크기가 없다 — 높이를 안 주면 카드가 그려지지 않는다.
        .frame(height: self.cardAreaHeight)
        .background(appearance.colorSet.bg1.asColor)
    }
    
    /// 선택 테두리를 미리보기 판과 같은 모양으로 그리려면 판이 쓰는 배율을 그대로 써야 한다.
    private var previewScale: CGFloat {
        guard let previewVariant else { return 1 }
        return Constant.cardWidth / previewVariant.canvas.size.width
    }
    
    private var cardAreaHeight: CGFloat {
        return self.previewHeight + Constant.cardLabelHeight + Metric.Spacing.large * 2
    }
    
    private var previewHeight: CGFloat {
        guard let previewVariant else { return 0 }
        return Constant.cardWidth / previewVariant.canvas.previewAspect
    }
    
    private func styleCard(_ style: WidgetStyleCellViewModel) -> some View {
        let isSelected = state.selectedStyleId == style.styleId
        return VStack(spacing: Metric.SpacingToken.small.value) {
            
            WidgetVariantPreviewView(
                variant: style.styleId.variant,
                setting: setting.overridingBackground(style.background),
                style: style.setting
            )
                .frame(width: Constant.cardWidth, height: self.previewHeight)
                .overlay(
                    style.styleId.variant.canvas.previewPlateShape(self.previewScale)
                        .strokeBorder(
                            isSelected
                            ? appearance.colorSet.accent.asColor
                            : Color.clear,
                            lineWidth: Constant.selectedBorderWidth
                        )
                )
            
            HStack(spacing: Metric.Spacing.xxsmall) {
                if style.hasUnsavedChange {
                    Circle()
                        .fill(appearance.colorSet.accentWarn.asColor)
                        .frame(width: 5, height: 5)
                }
                
                Text(style.name)
                    .font(appearance.fontSet.subNormal.asFont)
                    .foregroundStyle(
                        isSelected
                        ? appearance.colorSet.text0.asColor
                        : appearance.colorSet.text2.asColor
                    )
            }
        }
        .frame(width: Constant.cardWidth)
        .onTapGesture {
            self.eventHandlers.selectStyle(style.styleId)
        }
        .contextMenu {
            Button {
                self.eventHandlers.appendStyle(style.styleId)
            } label: {
                HStack {
                    Text("widget.style.edit::duplicate".localized())
                    Image(systemName: "doc.on.doc")
                }
            }
            
            if style.styleId.style == .default {
                Button(role: .destructive) {
                    self.eventHandlers.resetStyle(style.styleId)
                } label: {
                    HStack {
                        Text("widget.style.edit::reset".localized())
                        Image(systemName: "arrow.counterclockwise")
                    }
                }
            } else {
                Button(role: .destructive) {
                    self.eventHandlers.removeStyle(style.styleId)
                } label: {
                    HStack {
                        Text("common.remove".localized())
                        Image(systemName: "trash")
                    }
                }
            }
        }
    }
    
    private var addStyleCard: some View {
        VStack(spacing: Metric.SpacingToken.small.value) {
            
            RoundedRectangle(cornerRadius: Metric.Radius.regular)
                .fill(appearance.colorSet.bg0.asColor)
                .overlay(
                    Image(systemName: "plus")
                        .font(appearance.fontSet.normal.asFont)
                        .foregroundStyle(appearance.colorSet.text2.asColor)
                )
                .frame(width: Constant.cardWidth, height: self.previewHeight)
            
            Text("widget.style.edit::add".localized())
                .font(appearance.fontSet.subNormal.asFont)
                .foregroundStyle(appearance.colorSet.text2.asColor)
        }
        .frame(width: Constant.cardWidth)
        .onTapGesture {
            self.eventHandlers.addStyle()
        }
    }
    
    private var itemListView: some View {
        List {
            if state.selectedStyleId?.style != .default {
                Section {
                    nameRow
                        .listRowBackground(Color.clear)
                } header: {
                    sectionHeader("widget.style.edit::name::section".localized())
                }
            }
            
            Section {
                backgroundRow
                    .listRowBackground(Color.clear)
            } header: {
                sectionHeader("widget.style.edit::background::section".localized())
            }
            
            if let previewVariant, let setting = state.selectedSetting {
                previewVariant.styleFormView(
                    setting: setting, onChange: self.eventHandlers.updateSetting
                )
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(appearance.colorSet.bg0.asColor)
    }
    
    private func sectionHeader(_ text: String) -> some View {
        return Text(text)
            .font(appearance.fontSet.subNormal.asFont)
            .foregroundStyle(appearance.colorSet.text2.asColor)
    }
    
    private var backgroundRow: some View {
        HStack {
            Text(self.backgroundSourceText)
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.text1.asColor)
            
            Spacer()
            
            ColorSelectView(self.backgroundColor)
                .eventHandler(\.colorSelected) { newColor in
                    guard let hex = newColor.hex(environment) else { return }
                    self.eventHandlers.updateBackground(hex)
                }
                .id(self.backgroundSwatchId)
        }
    }
    
    /// ColorSelectView 는 초기값을 한 번만 읽는다 — 카드가 바뀌거나 전역 따름으로 되돌아가면 다시 세워야 한다.
    /// 고른 색끼리는 구분하지 않는다 — 색을 고르는 동안 다시 세우면 시스템 피커가 끊긴다.
    private var backgroundSwatchId: [AnyHashable] {
        return [state.selectedStyleId, state.selectedBackground == nil]
    }
    
    private var backgroundSourceText: String {
        return state.selectedBackground == nil
        ? "widget.style.edit::background::following_global".localized()
        : "widget.style.edit::background::style_own".localized()
    }
    
    private var backgroundColor: Color {
        switch state.selectedBackground ?? setting.background {
        case .system: return appearance.colorSet.bg0.asColor
        case .custom(let hex): return UIColor.from(hex: hex)?.asColor ?? appearance.colorSet.bg0.asColor
        }
    }
    
    private var nameRow: some View {
        @Bindable var state = self.state
        return TextField(
            "",
            text: $state.editingName,
            prompt: Text("widget.style.edit::name".localized())
                .foregroundStyle(appearance.colorSet.placeHolder.asColor)
        )
        .font(appearance.fontSet.normal.asFont)
        .foregroundStyle(appearance.colorSet.text0.asColor)
        .focused($isNameFocused)
        .padding(.horizontal, spacing: .regular)
        .padding(.vertical, spacing: .small)
        .background(
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(
                        isNameFocused
                        ? appearance.colorSet.accent.asColor
                        : appearance.colorSet.text2.asColor
                    )
                    .frame(
                        height: isNameFocused
                        ? Constant.focusedNameUnderlineHeight
                        : Constant.nameUnderlineHeight
                    )
            }
        )
        .listRowInsets(
            .init(
                top: 0, leading: Metric.Spacing.regular,
                bottom: 0, trailing: Metric.Spacing.regular
            )
        )
        .onChange(of: state.editingName) { _, newValue in
            self.eventHandlers.editName(newValue)
        }
        .autocorrectionDisabled()
        .submitLabel(.done)
    }
}
