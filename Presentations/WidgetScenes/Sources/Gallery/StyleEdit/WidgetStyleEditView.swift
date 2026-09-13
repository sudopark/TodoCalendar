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
    var items: [WidgetStyleItemCellViewModel] = []
    
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
        
        viewModel.items
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] items in
                self?.items = items
            })
            .store(in: self.cancellables)
    }
}

final class WidgetStyleEditViewEventHandler: Observable {
    
    var onAppear: () -> Void = { }
    var selectStyle: (WidgetStyleId) -> Void = { _ in }
    var appendStyle: (WidgetStyleId) -> Void = { _ in }
    var removeStyle: (WidgetStyleId) -> Void = { _ in }
    var resetStyle: (WidgetStyleId) -> Void = { _ in }
    var discard: () -> Void = { }
    var editName: (String) -> Void = { _ in }
    var toggleItem: (TodayStyleItem) -> Void = { _ in }
    var confirm: () -> Void = { }
    var close: () -> Void = { }
    
    func bind(_ viewModel: any WidgetStyleEditViewModel) {
        self.onAppear = viewModel.refresh
        self.selectStyle = viewModel.selectStyle
        self.appendStyle = viewModel.appendStyle(copying:)
        self.removeStyle = viewModel.removeStyle
        self.resetStyle = viewModel.resetStyle
        self.discard = viewModel.discard
        self.editName = viewModel.editName
        self.toggleItem = viewModel.toggleItem
        self.confirm = viewModel.confirm
        self.close = viewModel.close
    }
}


// MARK: - WidgetStyleEditContainerView

struct WidgetStyleEditContainerView: View {
    
    @State private var state: WidgetStyleEditViewState = .init()
    private let variant: WidgetVariant
    private let setting: WidgetAppearanceSettings
    private let viewAppearance: ViewAppearance
    private let eventHandler: WidgetStyleEditViewEventHandler
    
    var stateBinding: (WidgetStyleEditViewState) -> Void = { _ in }
    
    init(
        variant: WidgetVariant,
        setting: WidgetAppearanceSettings,
        eventHandler: WidgetStyleEditViewEventHandler,
        viewAppearance: ViewAppearance
    ) {
        self.variant = variant
        self.setting = setting
        self.eventHandler = eventHandler
        self.viewAppearance = viewAppearance
    }
    
    var body: some View {
        WidgetStyleEditView(variant: variant, setting: setting)
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
    @FocusState private var isNameFocused: Bool
    
    private enum Constant {
        static let cardWidth: CGFloat = 160
        static let cardLabelHeight: CGFloat = 28
        static let selectedBorderWidth: CGFloat = 2
        static let nameUnderlineHeight: CGFloat = 1
        static let focusedNameUnderlineHeight: CGFloat = 2
    }
    
    private let variant: WidgetVariant
    private let setting: WidgetAppearanceSettings
    
    init(variant: WidgetVariant, setting: WidgetAppearanceSettings) {
        self.variant = variant
        self.setting = setting
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
        return Constant.cardWidth / variant.canvas.size.width
    }
    
    private var cardAreaHeight: CGFloat {
        let previewHeight = Constant.cardWidth / variant.canvas.previewAspect
        return previewHeight + Constant.cardLabelHeight + Metric.Spacing.large * 2
    }
    
    private func styleCard(_ style: WidgetStyleCellViewModel) -> some View {
        let isSelected = state.selectedStyleId == style.styleId
        return VStack(spacing: Metric.SpacingToken.small.value) {
            
            WidgetVariantPreviewView(variant: variant, setting: setting, style: style.setting)
                .frame(
                    width: Constant.cardWidth,
                    height: Constant.cardWidth / variant.canvas.previewAspect
                )
                .overlay(
                    variant.canvas.previewPlateShape(self.previewScale)
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
                .frame(
                    width: Constant.cardWidth,
                    height: Constant.cardWidth / variant.canvas.previewAspect
                )
            
            Text("widget.style.edit::add".localized())
                .font(appearance.fontSet.subNormal.asFont)
                .foregroundStyle(appearance.colorSet.text2.asColor)
        }
        .frame(width: Constant.cardWidth)
        .onTapGesture {
            self.eventHandlers.appendStyle(.init(variant: self.variant, style: .default))
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
                ForEach(state.items, id: \.item) { item in
                    itemRow(item)
                        .listRowBackground(appearance.colorSet.bg1.asColor)
                }
            } header: {
                sectionHeader("widget.style.edit::items::section".localized())
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
    
    private func itemRow(_ item: WidgetStyleItemCellViewModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: Metric.SpacingToken.xxsmall.value) {
                Text(item.name)
                    .font(appearance.fontSet.normal.asFont)
                    .foregroundStyle(appearance.colorSet.text0.asColor)
                
                if let note = item.note {
                    Text(note)
                        .font(appearance.fontSet.subNormal.asFont)
                        .foregroundStyle(appearance.colorSet.text2.asColor)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: .init(get: { item.isOn }, set: { _ in
                self.eventHandlers.toggleItem(item.item)
            }))
            .controlSize(.small)
            .labelsHidden()
        }
    }
}
