//
//  
//  ColorThemeSelectView.swift
//  SettingScene
//
//  Created by sudo.park on 8/3/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//


import SwiftUI
import Combine
import Prelude
import Optics
import Extensions
import CommonPresentation
import SettingDomainInterface


// MARK: - ColorThemeSelectViewState

@Observable final class ColorThemeSelectViewState {
    
    @ObservationIgnored private var didBind = false
    @ObservationIgnored private let cancellables = CancelBag()
    
    fileprivate var sampleModel: CalendarAppearanceModel = .init(.sunday)
    fileprivate var themeModels: [BuiltInColorThemeModel] = []
    fileprivate var customThemeModels: [CustomColorThemeModel] = []
    
    func bind(_ viewModel: any ColorThemeSelectViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
        viewModel.sampleModel
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] model in
                self?.sampleModel = model
            })
            .store(in: self.cancellables)
        
        viewModel.colorThemeModels
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] models in
                self?.themeModels = models
            })
            .store(in: self.cancellables)
        
        viewModel.customColorThemeModels
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] models in
                self?.customThemeModels = models
            })
            .store(in: self.cancellables)
    }

    fileprivate var currentThemeModel: (any ColorThemeModel)? {
        let models: [any ColorThemeModel] = self.themeModels + self.customThemeModels
        guard let selected = models.first(where: { $0.isSelected }) else { return nil }
        switch selected.key {
        case .appTheme, .custom: return selected
        case .systemTheme, .defaultLight, .defaultDark: return nil
        }
    }
}

// MARK: - ColorThemeSelectViewEventHandler

final class ColorThemeSelectViewEventHandler: Observable {
    
    // TODO: add handlers
    var onAppear: () -> Void = { }
    var close: () -> Void = { }
    var selectTheme: (any ColorThemeModel) -> Void = { _ in }
    var createCustomTheme: () -> Void = { }
    var editCustomTheme: (CustomColorThemeModel) -> Void = { _ in }

    func bind(_ viewModel: any ColorThemeSelectViewModel) {
        // TODO: bind handlers
        
        self.onAppear = viewModel.prepare
        self.close = viewModel.close
        self.selectTheme = viewModel.selectTheme(_:)
        self.createCustomTheme = viewModel.createCustomTheme
        self.editCustomTheme = viewModel.editCustomTheme(_:)
    }
}


// MARK: - ColorThemeSelectContainerView

struct ColorThemeSelectContainerView: View {
    
    @State private var state: ColorThemeSelectViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: ColorThemeSelectViewEventHandler
    
    var stateBinding: (ColorThemeSelectViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: ColorThemeSelectViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return ColorThemeSelectView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .environment(state)
            .environment(eventHandlers)
            .environment(viewAppearance)
    }
}

// MARK: - ColorThemeSelectView

struct ColorThemeSelectView: View {
    
    @Environment(ColorThemeSelectViewState.self) private var state
    @Environment(ColorThemeSelectViewEventHandler.self) private var eventHandlers
    @Environment(ViewAppearance.self) private var appearance
    
    private let gridRow: [GridItem] = [
        .init(.flexible(minimum: 60, maximum: 100)),
        .init(.flexible(minimum: 60, maximum: 100)),
        .init(.flexible(minimum: 60, maximum: 100))
    ]
    
    var body: some View {
        NavigationStack {
            VStack {
                ColorThemeEditPreviewView(
                    model: state.sampleModel,
                    colorSet: appearance.colorSet
                )
                .padding(.vertical, spacing: .xlarge)
                
                ScrollView {
                    if let current = state.currentThemeModel {
                        self.currentThemeSection(current)
                    }

                    LazyVGrid(columns: gridRow) {
                        ForEach(state.themeModels, id: \.key.rawValue) { model in
                            ColorThemeItemView(model: model)
                                .onTapGesture {
                                    appearance.impactIfNeed()
                                    eventHandlers.selectTheme(model)
                                }
                        }
                    }
                    .padding(.top, 40)
                    
                    self.customThemeSection
                }
                .background(
                    appearance.colorSet.bg2.asColor
                        .shadow(
                            color: appearance.colorSet.text0.withAlphaComponent(0.4).asColor,
                            radius: 1
                        )
                        .ignoresSafeArea(.container)
                )
            }
            .background(appearance.colorSet.bg0.asColor)
            .navigationBarTitleDisplayMode(.inline)
            .if(condition: ProcessInfo.isAvailiOS26()) {
                $0.toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            }
            .if(condition: !ProcessInfo.isAvailiOS26()) {
                $0.toolbarBackground(appearance.colorSet.bg0.asColor, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("setting.appearance.calendar.colorTheme".localized())
                        .font(appearance.fontSet.size(17, weight: .semibold).asFont)
                        .foregroundStyle(appearance.colorSet.text0.asColor)
                }
                ToolbarItem(placement: .topBarLeading) {
                    NavigationBackButton {
                        eventHandlers.close()
                    }
                }
            }
        }
    }
}


extension ColorThemeSelectView {

    private func currentThemeSection(_ model: any ColorThemeModel) -> some View {
        VStack(alignment: .leading, spacing: Metric.Spacing.regular) {
            Text("setting.appearance.calendar.colorTheme::currentTheme".localized())
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.text1.asColor)
                .padding(.horizontal, spacing: .large)

            LazyVGrid(columns: gridRow) {
                ColorThemeItemView(model: model)
            }
        }
        .padding(.top, spacing: .xlarge)
    }
    
    private var customThemeSection: some View {
        VStack(alignment: .leading, spacing: Metric.Spacing.regular) {
            Text("setting.appearance.calendar.colorTheme::myThemes".localized())
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.text1.asColor)
                .padding(.horizontal, spacing: .large)
            
            LazyVGrid(columns: gridRow) {
                ForEach(state.customThemeModels, id: \.key.rawValue) { model in
                    ColorThemeItemView(model: model)
                        .onTapGesture {
                            appearance.impactIfNeed()
                            eventHandlers.selectTheme(model)
                        }
                        .contextMenu {
                            Button(
                                "setting.appearance.calendar.colorTheme::edit".localized()
                            ) {
                                eventHandlers.editCustomTheme(model)
                            }
                        }
                }
                
                NewColorThemeItemView()
                    .onTapGesture {
                        appearance.impactIfNeed()
                        eventHandlers.createCustomTheme()
                    }
            }
        }
        .padding(.top, spacing: .xlarge)
        .padding(.bottom, spacing: .xlarge)
    }
}


// MARK: - preview

struct ColorThemeSelectViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let setting = AppearanceSettings(
            calendar: .init(
                colorSetKey: .defaultLight,
                fontSetKey: .systemDefault
            ),
            defaultTagColor: .init(holiday: "#ff0000", default: "#ff00ff")
        )
        let viewAppearance = ViewAppearance(
            setting: setting, isSystemDarkTheme: false
        )
        let state = ColorThemeSelectViewState()
        state.themeModels = [
            .init(.systemTheme) |> \.isSelected .~ true,
            .init(.defaultLight),
            .init(.defaultDark)
        ]
        let eventHandlers = ColorThemeSelectViewEventHandler()
        
        let view = ColorThemeSelectView()
            .environment(state)
            .environment(eventHandlers)
            .environment(viewAppearance)
        return view
    }
}

