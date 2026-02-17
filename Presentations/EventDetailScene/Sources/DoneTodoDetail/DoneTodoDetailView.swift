//
//  
//  DoneTodoDetailView.swift
//  EventDetailScene
//
//  Created by sudo.park on 2/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//
//


import SwiftUI
import Combine
import Domain
import CommonPresentation


// MARK: - DoneTodoDetailViewState

@Observable final class DoneTodoDetailViewState {
    
    @ObservationIgnored private var didBind = false
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []
    
    func bind(_ viewModel: any DoneTodoDetailViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
    }
}

// MARK: - DoneTodoDetailViewEventHandler

final class DoneTodoDetailViewEventHandler: Observable {
    
    // TODO: add handlers
    var onAppear: () -> Void = { }
    var close: () -> Void = { }

    func bind(_ viewModel: any DoneTodoDetailViewModel) {
        // TODO: bind handlers
    }
}


// MARK: - DoneTodoDetailContainerView

struct DoneTodoDetailContainerView: View {
    
    @State private var state: DoneTodoDetailViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: DoneTodoDetailViewEventHandler
    
    var stateBinding: (DoneTodoDetailViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: DoneTodoDetailViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return DoneTodoDetailView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .environment(viewAppearance)
            .environment(state)
            .environment(eventHandlers)
    }
}

// MARK: - DoneTodoDetailView

struct DoneTodoDetailView: View {
    
    @Environment(ViewAppearance.self) private var appearance
    @Environment(DoneTodoDetailViewState.self) private var state
    @Environment(DoneTodoDetailViewEventHandler.self) private var eventHandlers
    
    var body: some View {
        Text("DoneTodoDetailView")
    }
}


// MARK: - preview

struct DoneTodoDetailViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let calendarSetting = CalendarAppearanceSettings(
            colorSetKey: .defaultLight, fontSetKey: .systemDefault
        )
        let setting = AppearanceSettings(
            calendar: calendarSetting,
            defaultTagColor: .init(holiday: "#ff0000", default: "#ff00ff")
        )
        let viewAppearance = ViewAppearance(
            setting: setting, isSystemDarkTheme: false
        )
        let state = DoneTodoDetailViewState()
        let eventHandlers = DoneTodoDetailViewEventHandler()
        
        let view = DoneTodoDetailView()
            .environment(viewAppearance)
            .environment(state)
            .environment(eventHandlers)
        return view
    }
}

