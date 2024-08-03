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
import Domain
import CommonPresentation


// MARK: - ColorThemeSelectViewState

final class ColorThemeSelectViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    func bind(_ viewModel: any ColorThemeSelectViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
    }
}

// MARK: - ColorThemeSelectViewEventHandler

final class ColorThemeSelectViewEventHandler: ObservableObject {
    
    // TODO: add handlers
    var onAppear: () -> Void = { }
    var close: () -> Void = { }

    func bind(_ viewModel: any ColorThemeSelectViewModel) {
        // TODO: bind handlers
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
    
    var body: some View {
        Text("ColorThemeSelectView")
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
        let eventHandlers = ColorThemeSelectViewEventHandler()
        
        let view = ColorThemeSelectView()
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}

