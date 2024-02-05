//
//  
//  SelectEventNotificationTimeView.swift
//  EventDetailScene
//
//  Created by sudo.park on 1/31/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//


import SwiftUI
import Combine
import Domain
import CommonPresentation


// MARK: - SelectEventNotificationTimeViewState

final class SelectEventNotificationTimeViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    func bind(_ viewModel: any SelectEventNotificationTimeViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
    }
}

// MARK: - SelectEventNotificationTimeViewEventHandler

final class SelectEventNotificationTimeViewEventHandler: ObservableObject {
    
    // TODO: add handlers
}


// MARK: - SelectEventNotificationTimeContainerView

struct SelectEventNotificationTimeContainerView: View {
    
    @StateObject private var state: SelectEventNotificationTimeViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: SelectEventNotificationTimeViewEventHandler
    
    var stateBinding: (SelectEventNotificationTimeViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: SelectEventNotificationTimeViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return SelectEventNotificationTimeView()
            .onAppear {
                self.stateBinding(self.state)
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
    }
}

// MARK: - SelectEventNotificationTimeView

struct SelectEventNotificationTimeView: View {
    
    @EnvironmentObject private var state: SelectEventNotificationTimeViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandlers: SelectEventNotificationTimeViewEventHandler
    
    var body: some View {
        Text("SelectEventNotificationTimeView")
    }
}


// MARK: - preview

struct SelectEventNotificationTimeViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let setting = AppearanceSettings(
            tagColorSetting: .init(holiday: "#ff0000", default: "#ff00ff"),
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
        let viewAppearance = ViewAppearance(
            setting: setting
        )
        let state = SelectEventNotificationTimeViewState()
        let eventHandlers = SelectEventNotificationTimeViewEventHandler()
        
        let view = SelectEventNotificationTimeView()
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}

