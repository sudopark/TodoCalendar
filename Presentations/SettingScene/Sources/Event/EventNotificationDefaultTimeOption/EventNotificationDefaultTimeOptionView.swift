//
//  
//  EventNotificationDefaultTimeOptionView.swift
//  SettingScene
//
//  Created by sudo.park on 1/20/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//


import SwiftUI
import Combine
import Domain
import CommonPresentation


// MARK: - EventNotificationDefaultTimeOptionViewState

final class EventNotificationDefaultTimeOptionViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    func bind(_ viewModel: any EventNotificationDefaultTimeOptionViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
    }
}

// MARK: - EventNotificationDefaultTimeOptionViewEventHandler

final class EventNotificationDefaultTimeOptionViewEventHandler: ObservableObject {
    
    // TODO: add handlers
}


// MARK: - EventNotificationDefaultTimeOptionContainerView

struct EventNotificationDefaultTimeOptionContainerView: View {
    
    @StateObject private var state: EventNotificationDefaultTimeOptionViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: EventNotificationDefaultTimeOptionViewEventHandler
    
    var stateBinding: (EventNotificationDefaultTimeOptionViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: EventNotificationDefaultTimeOptionViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return EventNotificationDefaultTimeOptionView()
            .onAppear {
                self.stateBinding(self.state)
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
    }
}

// MARK: - EventNotificationDefaultTimeOptionView

struct EventNotificationDefaultTimeOptionView: View {
    
    @EnvironmentObject private var state: EventNotificationDefaultTimeOptionViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandlers: EventNotificationDefaultTimeOptionViewEventHandler
    
    var body: some View {
        Text("EventNotificationDefaultTimeOptionView")
    }
}


// MARK: - preview

struct EventNotificationDefaultTimeOptionViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let setting = AppearanceSettings(
            tagColorSetting: .init(holiday: "#ff0000", default: "#ff00ff"),
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
        let viewAppearance = ViewAppearance(
            setting: setting
        )
        let state = EventNotificationDefaultTimeOptionViewState()
        let eventHandlers = EventNotificationDefaultTimeOptionViewEventHandler()
        
        let view = EventNotificationDefaultTimeOptionView()
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}

