//
//  
//  EventTagSelectView.swift
//  SettingScene
//
//  Created by sudo.park on 1/1/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//


import SwiftUI
import Combine
import Domain
import CommonPresentation


// MARK: - EventTagSelectViewState

final class EventTagSelectViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    func bind(_ viewModel: any EventTagSelectViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
    }
}

// MARK: - EventTagSelectViewEventHandler

final class EventTagSelectViewEventHandler: ObservableObject {
    
    // TODO: add handlers
}


// MARK: - EventTagSelectContainerView

struct EventTagSelectContainerView: View {
    
    @StateObject private var state: EventTagSelectViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: EventTagSelectViewEventHandler
    
    var stateBinding: (EventTagSelectViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: EventTagSelectViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return EventTagSelectView()
            .onAppear {
                self.stateBinding(self.state)
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
    }
}

// MARK: - EventTagSelectView

struct EventTagSelectView: View {
    
    @EnvironmentObject private var state: EventTagSelectViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandlers: EventTagSelectViewEventHandler
    
    var body: some View {
        Text("EventTagSelectView")
    }
}


// MARK: - preview

struct EventTagSelectViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let setting = AppearanceSettings(
            tagColorSetting: .init(holiday: "#ff0000", default: "#ff00ff"),
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
        let viewAppearance = ViewAppearance(
            setting: setting
        )
        let state = EventTagSelectViewState()
        let eventHandlers = EventTagSelectViewEventHandler()
        
        let view = EventTagSelectView()
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}

