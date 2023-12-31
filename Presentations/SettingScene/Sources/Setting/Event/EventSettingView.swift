//
//  
//  EventSettingView.swift
//  SettingScene
//
//  Created by sudo.park on 12/31/23.
//  Copyright © 2023 com.sudo.park. All rights reserved.
//
//


import SwiftUI
import Combine
import Domain
import CommonPresentation


// MARK: - EventSettingViewState

final class EventSettingViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    func bind(_ viewModel: any EventSettingViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
    }
}

// MARK: - EventSettingViewEventHandler

final class EventSettingViewEventHandler: ObservableObject {
    
    // TODO: add handlers
}


// MARK: - EventSettingContainerView

struct EventSettingContainerView: View {
    
    @StateObject private var state: EventSettingViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: EventSettingViewEventHandler
    
    var stateBinding: (EventSettingViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: EventSettingViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return EventSettingView()
            .onAppear {
                self.stateBinding(self.state)
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
    }
}

// MARK: - EventSettingView

struct EventSettingView: View {
    
    @EnvironmentObject private var state: EventSettingViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandlers: EventSettingViewEventHandler
    
    var body: some View {
        Text("EventSettingView")
    }
}


// MARK: - preview

struct EventSettingViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let setting = AppearanceSettings(
            tagColorSetting: .init(holiday: "#ff0000", default: "#ff00ff"),
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
        let viewAppearance = ViewAppearance(
            setting: setting
        )
        let state = EventSettingViewState()
        let eventHandlers = EventSettingViewEventHandler()
        
        let view = EventSettingView()
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}

