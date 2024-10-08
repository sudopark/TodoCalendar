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
import Domain
import CommonPresentation


// MARK: - ColorThemeSelectViewState

final class ColorThemeSelectViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    @Published fileprivate var sampleModel: CalendarAppearanceModel = .init(.sunday)
    @Published fileprivate var themeModels: [ColorThemeModel] = []
    
    func bind(_ viewModel: any ColorThemeSelectViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
        viewModel.sampleModel
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] model in
                self?.sampleModel = model
            })
            .store(in: &self.cancellables)
        
        viewModel.colorThemeModels
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] models in
                self?.themeModels = models
            })
            .store(in: &self.cancellables)
    }
}

// MARK: - ColorThemeSelectViewEventHandler

final class ColorThemeSelectViewEventHandler: ObservableObject {
    
    // TODO: add handlers
    var onAppear: () -> Void = { }
    var close: () -> Void = { }
    var selectTheme: (ColorThemeModel) -> Void = { _ in }

    func bind(_ viewModel: any ColorThemeSelectViewModel) {
        // TODO: bind handlers
        
        self.onAppear = viewModel.prepare
        self.close = viewModel.close
        self.selectTheme = viewModel.selectTheme(_:)
    }
}


// MARK: - ColorThemeSelectContainerView

struct ColorThemeSelectContainerView: View {
    
    @StateObject private var state: ColorThemeSelectViewState = .init()
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
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
    }
}

// MARK: - ColorThemeSelectView

struct ColorThemeSelectView: View {
    
    @EnvironmentObject private var state: ColorThemeSelectViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandlers: ColorThemeSelectViewEventHandler
    
    private let gridRow: [GridItem] = [
        .init(.flexible(minimum: 60, maximum: 100)),
        .init(.flexible(minimum: 60, maximum: 100)),
        .init(.flexible(minimum: 60, maximum: 100))
    ]
    
    var body: some View {
        NavigationStack {
            VStack {
                
                CalendarAppearanceSampleView(model: self.$state.sampleModel)
                    .padding(.vertical, 60)
                
                ScrollView {
                    LazyVGrid(columns: gridRow) {
                        ForEach(0..<state.themeModels.count, id: \.self) { index in
                            ColorThemeItemView(model: state.themeModels[index])
                                .onTapGesture {
                                    appearance.impactIfNeed()
                                    eventHandlers.selectTheme(state.themeModels[index])
                                }
                        }
                    }
                    .padding(.top, 40)
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
            .navigationTitle("setting.appearance.calendar.colorTheme".localized())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationBackButton {
                        eventHandlers.close()
                    }
                }
            }
        }
            .id(appearance.navigationBarId)
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
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}

