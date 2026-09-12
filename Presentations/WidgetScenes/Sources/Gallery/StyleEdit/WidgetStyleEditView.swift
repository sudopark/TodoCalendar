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
    var toggleItem: (TodayStyleItem) -> Void = { _ in }
    var confirm: () -> Void = { }
    var close: () -> Void = { }
    
    func bind(_ viewModel: any WidgetStyleEditViewModel) {
        self.onAppear = viewModel.refresh
        self.selectStyle = viewModel.selectStyle
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
    
    private enum Constant {
        static let cardWidth: CGFloat = 160
        static let cardLabelHeight: CGFloat = 28
        static let selectedBorderWidth: CGFloat = 2
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        self.eventHandlers.confirm()
                    } label: {
                        Text("common.confirm".localized())
                            .font(appearance.fontSet.normal.asFont)
                            .foregroundStyle(appearance.colorSet.accent.asColor)
                    }
                }
            }
        }
        .id(appearance.navigationBarId)
    }
    
    private var styleCardsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Metric.SpacingToken.regular.value) {
                ForEach(state.styles, id: \.styleId) { style in
                    styleCard(style)
                }
            }
            .padding(.horizontal, spacing: .xlarge)
            .padding(.vertical, spacing: .large)
        }
        // 미리보기가 GeometryReader 기반이라 intrinsic 크기가 없다 — 높이를 안 주면 카드가 그려지지 않는다.
        .frame(height: self.cardAreaHeight)
        .background(appearance.colorSet.bg1.asColor)
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
                    RoundedRectangle(cornerRadius: Metric.Radius.regular)
                        .strokeBorder(
                            isSelected
                            ? appearance.colorSet.accent.asColor
                            : Color.clear,
                            lineWidth: Constant.selectedBorderWidth
                        )
                )
            
            Text(style.name)
                .font(appearance.fontSet.subNormal.asFont)
                .foregroundStyle(
                    isSelected
                    ? appearance.colorSet.text0.asColor
                    : appearance.colorSet.text2.asColor
                )
        }
        .frame(width: Constant.cardWidth)
        .onTapGesture {
            self.eventHandlers.selectStyle(style.styleId)
        }
    }
    
    private var itemListView: some View {
        List(state.items, id: \.item) { item in
            itemRow(item)
                .listRowBackground(appearance.colorSet.bg1.asColor)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(appearance.colorSet.bg0.asColor)
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
